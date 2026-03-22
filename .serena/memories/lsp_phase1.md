# LSP Phase 1 — Foundation

Native LSP integration via `Frameworks/lsp/` framework.

## What Works
- LSPClient: JSON-RPC over stdio, NSTask process management, delegate pattern
- LSPManager: singleton, reads `lspCommand` from `.tm_properties`, one client per project root
- Document sync: didOpen, didChange (300ms debounce, full sync), didSave, didClose
- Diagnostics: stored as buffer marks (`error`, `warning`, `note`), displayed in existing gutter column
- Server request handling: responds to `client/registerCapability` etc.
- App quit: graceful shutdown via NSApplicationWillTerminateNotification

## Key Findings
- `document.fileType` is nil during `setDocument:` — use file extension fallback for languageId
- `oak` is not a CMake target (header-only in Shared/include) — don't link it
- Marks system already supports gutter icons via `enumerateBookmarksAtLine:` — no new column needed
- `mate --set-mark error/warning/note` uses same mark types — we reuse them
