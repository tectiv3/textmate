# LSP Formatting Integration Research

## Current State - No Formatting Support

### LSP Framework Status (Frameworks/lsp/)

**LSPClient.h/mm:**
- Current capabilities declared in `sendInitialize()` (line 333-357):
  - `textDocument.publishDiagnostics`
  - `textDocument.synchronization` (didSave)
  - `textDocument.completion`
  - `textDocument.definition`
  - `textDocument.hover`
- **NO formatting capabilities declared** (no formatting, rangeFormatting, onTypeFormatting)

**LSPClient public interface (LSPClient.h):**
- Request methods available:
  - `requestCompletionForURI:line:character:completion:`
  - `requestDefinitionForURI:line:character:completion:`
  - `requestHoverForURI:line:character:completion:`
  - `requestReferencesForURI:line:character:completion:`
  - `cancelRequest:`
- **NO formatting request methods**

**LSPManager.h/mm:**
- Routes requests to LSPClient via document UUID
- Current public methods:
  - `requestCompletionsForDocument:line:character:prefix:completion:`
  - `requestDefinitionForDocument:line:character:completion:`
  - `requestHoverForDocument:line:character:completion:`
  - `requestReferencesForDocument:line:character:completion:`
- **NO formatting methods**

### How Text Edits Currently Work (for completion)

**Completion Flow:**
1. User selects item from OakCompletionPopup
2. `completionPopup:didSelectItem:` (OakTextView.mm:5231) is called
3. For LSP completions, the item has `item.effectiveInsertText` and `item.isSnippet` flag
4. Code directly inserts via:
   - `documentView->insert(to_s(item.effectiveInsertText))` for text
   - `[self insertSnippetWithOptions:@{@"content": ...}]` for snippets
5. **No TextEdit application** — only the insertText/insert property is used

**Underlying insertion mechanism:**
- `documentView->insert()` calls `editor_t::insert()` in Frameworks/editor/src/
- For structured text edits: `editor_t::perform_replacements()` (editor.cc:1188) accepts:
  - `std::multimap<std::pair<size_t, size_t>, std::string>` (offset ranges → replacement text)
  - Converts to `multimap<range_t, std::string>` and calls `this->replace()`

### OakTextView Integration Points

**Current structure:**
- LSP completion popup: `_lspCompletionPopup` (OakTextView.mm:517)
- Delegate: `OakCompletionPopupDelegate` protocol (OakTextView.mm:5228)
- Selection handling: When item selected, code sets range then inserts:
  ```objc
  size_t caret = documentView->ranges().last().last.index;
  NSUInteger deleteCount = _lspInitialPrefixLength + _lspFilterPrefix.length;
  size_t from = caret - deleteCount;
  documentView->set_ranges(ng::range_t(from, caret));
  documentView->insert(to_s(item.effectiveInsertText));
  ```

### What Needs to be Added for Formatting

1. **LSPClient.h/.mm:**
   - Add formatting capabilities to `sendInitialize()` (line 333):
     - `textDocument.formatting` → `{...}`
     - `textDocument.rangeFormatting` → `{...}`
     - `textDocument.onTypeFormatting` → `{...}`
   - Add request methods:
     - `requestFormattingForURI:options:completion:` (full document)
     - `requestRangeFormattingForURI:range:options:completion:` (range)
     - `requestOnTypeFormattingForURI:line:character:ch:options:completion:` (on-type)

2. **LSPManager.h/.mm:**
   - Add public routing methods:
     - `requestFormattingForDocument:completion:`
     - `requestRangeFormattingForDocument:range:completion:`
     - `requestOnTypeFormattingForDocument:line:character:ch:completion:`

3. **OakTextView.mm:**
   - Add key binding/action to trigger formatting
   - Parse TextEdit[] response from server
   - Use existing `perform_replacements()` mechanism to apply multi-range edits
   - For on-type: hook into character insertion to trigger async formatting

### Key Implementation Detail

TextEdit is LSP's standard format for multiple text changes:
```json
{
  "range": {"start": {"line": 0, "character": 0}, "end": {"line": 0, "character": 10}},
  "newText": "replacement text"
}
```

Conversion needed:
- LSP line/character → buffer offset (use buffer.convert())
- Range pairs {start_offset, end_offset} → entry in multimap
- Call `documentView->perform_replacements()`

### Related Editor Framework

- **write.h:** Contains text insertion/deletion mechanisms
- **editor.h:** Contains `perform_replacements()` and buffer manipulation
- **indent.h:** Smart indentation available for use
