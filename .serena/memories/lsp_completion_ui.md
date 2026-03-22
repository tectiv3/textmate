# LSP Completion UI Implementation

## Key Binding
`"~\t" = "lspComplete:";` in KeyBindings.dict (Opt+Tab)

## OakTextView lspComplete: Action
- Extracts word prefix by walking back from caret to first non-alnum
- Calls `[LSPManager.sharedManager requestCompletionsForDocument:...]`
- Shows OakCompletionPopup at caret with suggestions

## Key Event Handling (when popup active)
- **Return/Tab** → accept: delete prefix, insert selected item's text. If isSnippet, use insertSnippetWithOptions:
- **Esc** → cancel popup
- **Letters/underscore** → filter: insert char then append to filterPrefix. Dismiss if no matches.
- **Backspace** → unfilter: shorten filterPrefix. Dismiss if empty.
- **Arrow keys** → popup navigation
- **Other chars** → dismiss popup

## Suggestion Dict Format
`{display, match, image, insert, isSnippet}`

## Popup Issues Found
- NSTextField needs explicit setup in dark vibrancy (not labelWithString:)
- Cell frames need proper width (not 1px)
- dialog2 TMDIncrementalPopUpMenu at `PlugIns/dialog/Commands/popup/TMDIncrementalPopUpMenu.mm` (~520 lines) is good reference

## IMPORTANT: LSP completion is SEPARATE from Esc/native completion
LSP uses Opt+Tab flow only. Never modify editor_t::completions() or completion.cc for LSP.
