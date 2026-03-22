# LSP Feature Status and Roadmap

## Feature Checklist

| Feature | Status |
|---|---|
| Document sync (open/change/save/close) | Done |
| Diagnostics (publishDiagnostics) | Done |
| Completion (textDocument/completion) | Done — OakSwiftUI popup |
| Completion snippet params from detail | Done |
| Go to Definition (Cmd+Opt+D + Cmd+Click) | Done |
| Hover (mouse 500ms + Cmd+Ctrl+I) | Done |
| textEdit support in completions | Done |
| Find References (Cmd+Ctrl+R) | Done — OakSwiftUI panel |
| Hover caching (word-based, 60s TTL) | Done |
| Hover request cancellation | Done |
| Signature Help | Skipped — user prefers completion |
| Document Symbols | Skipped |
| Rename (F2) | Done — inline field + preview panel, multi-file WorkspaceEdit |
| Code Actions (Cmd+.) | Done — NSMenu picker, lightbulb gutter, workspace/applyEdit |
| Formatting (Text → Format Code, lspFormatOnSave) | Done, merged to develop |
| completionItem/resolve | Done — doc side panel + data update, merged to develop |

## Architecture
- LSP completion uses Opt+Tab, NOT the Esc pipeline
- OakSwiftUI linked directly to OakTextView (no conditional guards)
- Backend: LSPClient (JSON-RPC) → LSPManager (routing) → OakTextView (bridge)
- snippetSupport: true declared, Intelephense returns $0 only — we generate snippets from detail
- Hover capability declares contentFormat: ["markdown", "plaintext"]
- LSPClient.cancelRequest: removes callback + sends $/cancelRequest notification

## Key Implementation Details
- Rename: prepareRename → OakRenameField → rename request → OakRenamePreviewPanel → apply
- Code Actions: NSMenu sections (Quick Fix, Refactor, Source, Other), isPreferred bold, lightbulb gutter
- completionItem/resolve: 150ms debounce, doc panel slides in beside completion list (262pt extra)
- Find References: grouped by file, single result navigates directly, panel stays open for multiple
