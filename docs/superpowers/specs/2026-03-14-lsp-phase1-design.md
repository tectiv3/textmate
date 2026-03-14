# LSP Phase 1: Foundation + Diagnostics — Design Spec

## Goal

Extract the PoC LSP client into a proper framework, add `.tm_properties` configuration, document sync, and diagnostics displayed in the gutter — making LSP a first-class, visible feature in TextMate.

## Architecture

Three components in a new `Frameworks/lsp/` framework:

### LSPClient

Manages one language server process. Refined from the PoC (`OakTextView/src/LSPClient.mm`).

**Responsibilities:**
- Spawn server subprocess via NSTask with stdio pipes
- JSON-RPC 2.0 framing (Content-Length header, nlohmann/json)
- Background dispatch queue for reading, main thread for callbacks
- `initialize` / `initialized` handshake
- Send requests (with ID tracking) and notifications
- Dispatch incoming responses and notifications to registered handlers
- PATH setup for node-based servers (homebrew)

**Key improvement over PoC:** request/response tracking via ID → callback map, so callers can handle responses to specific requests.

### LSPManager

Singleton. Maps project root + server command → LSPClient instance. All document views go through this instead of creating their own client.

**Responsibilities:**
- Read `lspCommand` from `.tm_properties` via `settings_for_path()`
- Parse command string (split on whitespace: first token = executable, rest = args)
- Determine workspace root:
  1. Project folder if open → `rootUri`
  2. Otherwise walk upward for markers (`.git`, `composer.json`, `package.json`, `CMakeLists.txt`, `go.mod`, `Cargo.toml`, `pyproject.toml`)
  3. `lspRootPath` from `.tm_properties` overrides both
- Spawn LSPClient on first matching document open; reuse for same root
- Track open documents per client (reference counting)
- Shut down client when last document for that root closes
- Crash restart with backoff (1s → 2s → 4s → 8s, max 5 attempts, reset counter after 60s stable)
- Graceful shutdown all clients on app quit

**API:**
```objc
+ (instancetype)sharedManager;
- (void)documentDidOpen:(OakDocument*)document;
- (void)documentDidChange:(OakDocument*)document;
- (void)documentDidSave:(OakDocument*)document;
- (void)documentWillClose:(OakDocument*)document;
```

### LSPDiagnosticsManager

Receives `publishDiagnostics` notifications and stores them as buffer marks.

**Responsibilities:**
- Parse diagnostic JSON (uri, range, severity, message)
- Convert LSP positions (0-indexed line + UTF-16 column) to buffer byte offsets
  - Use `Frameworks/text/src/utf16.h` for UTF-16 → UTF-8 conversion
  - Negotiate `positionEncoding` capability with server (prefer UTF-8 if supported)
- Clear previous diagnostics for the file (`removeAllMarksOfType:`)
- Set new marks on the buffer using OakDocument's mark API:
  - Mark type: `diagnostic/error`, `diagnostic/warning`, `diagnostic/info`, `diagnostic/hint`
  - Mark payload: the diagnostic message text
- `OakDocumentMarksDidChangeNotification` fires automatically → gutter refreshes

## Gutter Display

**No new gutter column.** Diagnostics reuse the existing bookmarks column.

`enumerateBookmarksAtLine:` returns all mark types at a line. When a diagnostic mark has a non-empty payload, it gets priority 0 (highest) in the existing image selection logic. The mark type string is used as the image name.

**Required:** Register SF Symbol images for diagnostic mark types in the gutter images dictionary:
- `diagnostic/error` → `xmark.circle.fill` (red-tinted)
- `diagnostic/warning` → `exclamationmark.triangle.fill` (yellow-tinted)
- `diagnostic/info` → `info.circle.fill` (blue-tinted)
- `diagnostic/hint` → `lightbulb.fill` (gray-tinted)

**Click behavior:** When user clicks a diagnostic mark in the gutter, show the diagnostic message in a popover (same mechanism as bookmark payload display).

## Configuration

Using `.tm_properties`:

```properties
[ source.php ]
lspCommand = "intelephense --stdio"

[ source.c, source.c++, source.objc, source.objc++ ]
lspCommand = "clangd --background-index --clang-tidy"

[ source.js, source.ts ]
lspCommand = "typescript-language-server --stdio"

[ source.go ]
lspCommand = "gopls"

# Optional overrides
lspRootPath  = "/path/to/monorepo/backend"
lspEnabled   = true      # default: true when lspCommand is set
lspLogLevel  = "warning"  # off, error, warning, info, debug
```

Read via `settings_for_path()` with the document's path, scope, and directory. `lspCommand` is the trigger — if absent, no LSP for that file type.

## Document Sync

**Full sync** (`TextDocumentSyncKind.Full`): on content change, send entire buffer content.

**Lifecycle notifications:**
- `textDocument/didOpen` — on document open (when LSPManager sees a new document for an active client)
- `textDocument/didChange` — on content change, debounced ~300ms. Observe `OakDocumentContentDidChangeNotification`.
- `textDocument/didSave` — observe `OakDocumentDidSaveNotification`
- `textDocument/didClose` — observe `OakDocumentWillCloseNotification`

**Version tracking:** Maintain a per-document version counter, incremented on each `didChange` sent.

## Server Resilience

**Per-request timeouts** (for future request-based features, not needed for Phase 1 notifications):
- `initialize`: 10s
- Implicit requests (completion, hover): 2s
- Explicit requests (definition, rename): 5-10s

**On timeout:** cancel via `$/cancelRequest`, drop silently for implicit, status message for explicit.

**Malformed responses:** log and discard. Validate `id` matches pending request.

**Hung server:** if >5 timed-out requests in 30s window, kill and restart.

**Server stderr:** capture, route through NSLog with `[LSP][stderr]` prefix, filtered by `lspLogLevel`.

## File Structure

| File | Responsibility |
|------|---------------|
| `Frameworks/lsp/CMakeLists.txt` | Framework build config |
| `Frameworks/lsp/src/LSPClient.h` | Single server connection (JSON-RPC, process lifecycle) |
| `Frameworks/lsp/src/LSPClient.mm` | LSPClient implementation |
| `Frameworks/lsp/src/LSPManager.h` | Singleton: config → client mapping, document lifecycle |
| `Frameworks/lsp/src/LSPManager.mm` | LSPManager implementation |
| `Frameworks/lsp/src/LSPDiagnosticsManager.h` | Diagnostics → buffer marks |
| `Frameworks/lsp/src/LSPDiagnosticsManager.mm` | LSPDiagnosticsManager implementation |
| `Frameworks/OakTextView/src/OakDocumentView.mm` | Hook: register diagnostic images, wire LSPManager calls |

**Removed:** `Frameworks/OakTextView/src/LSPClient.{h,mm}` (PoC code moves to `Frameworks/lsp/`)

## Integration Points

### OakDocumentView

- Remove PoC LSPClient code
- In `setDocument:`: call `[LSPManager.sharedManager documentDidOpen:aDocument]`
- Register diagnostic gutter images in `initWithFrame:`
- Observe `OakDocumentContentDidChangeNotification` → `documentDidChange:`
- Already observes `OakDocumentMarksDidChangeNotification` → gutter refresh works automatically

### OakTextView

- Already observes `OakDocumentWillSaveNotification` / `OakDocumentDidSaveNotification`
- Wire `documentDidSave:` through to LSPManager

### CMake

- New `Frameworks/lsp/CMakeLists.txt` with `textmate_framework(lsp)`
- Dependencies: `document`, `settings`, `text`, `ns`, `oak`
- `target_include_directories` for `vendor/nlohmann`
- Add `lsp` to OakTextView's `target_link_libraries`

## Scope Exclusions

- No completion integration (Phase 2)
- No hover tooltips (Phase 2)
- No go-to-definition or navigation (Phase 3)
- No incremental document sync (optimization, later)
- No multi-root workspace support
- No UI beyond gutter icons and click-to-show-message
