# Copilot Phase 2: Inline Ghost Text Suggestions

## Overview
Auto-triggered inline suggestions rendered as dimmed ghost text at cursor position. User accepts with Tab, rejects with Esc or any keystroke.

## Trigger
- Auto-trigger: ~500ms debounce after typing stops
- Opt+Esc still available for explicit popup mode (Phase 1)

## Rendering
- Ghost text drawn inline in OakTextView at cursor position
- Dimmed/italic styling (theme's comment color at ~40% opacity)
- Multi-line: first line inline at cursor, additional lines rendered below
- Options: new rendering pass in OakTextView's drawing code, or SwiftUI overlay (CopilotGhostText.swift)
- Multiple results still trigger popup mode

## Keybindings
- **Tab**: Accept full suggestion (careful: conflicts with indentation, snippet navigation)
- **Cmd+Right**: Accept next word (partial acceptance)
- **Esc**: Reject / dismiss
- **Any other keystroke**: Dismiss and process keystroke normally


## Protocol (copilot-language-server native binary)
- `textDocument/inlineCompletion` with `triggerKind: 2` (Automatic, not Invoked)
- `textDocument/didShowCompletion` notification when ghost text appears
- `workspace/executeCommand` → `github.copilot.didAcceptCompletionItem` on Tab
- `textDocument/didPartiallyAcceptCompletion` for word-by-word accept (UTF-16 code units)
- `$/cancelRequest` to abort pending request when user types

## Architectural Considerations
- CopilotManager tracks "active suggestion" state (current ghost text items)
- Tab key interception only when ghost text is visible
- Tab conflicts: indentation (handled by checking if ghost text active), snippet placeholders (need priority logic)
- Ghost text must clear on: cursor movement, any edit, scroll, document switch
- The `statusNotification` from server already works reactively for status updates

## Server Info
- Latest github-copilot lsp
- Uses standard `textDocument/inlineCompletion` protocol
- Auth handled internally by server (reads ~/.config/github-copilot/)
- `editorInfo` passed in `initializationOptions` during `initialize`
- Auth methods: direct `checkStatus`/`signInInitiate` JSON-RPC
- Server sends `statusNotification` with `status: "Normal"` when ready

