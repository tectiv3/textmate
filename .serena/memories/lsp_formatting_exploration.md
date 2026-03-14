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

## Implementation Pattern Details

### How LSP Actions are Currently Wired

**Action Declaration Pattern (OakTextView.mm:4569):**
```objc
#define ACTION(NAME) (void)NAME:(id)sender { [self handleAction:ng::to_action(#NAME ":") forSelector:@selector(NAME:)]; }
```

**LSP-specific Actions** (not using ACTION macro, custom implementations):
- `lspShowHoverInfo:(id)sender` (OakTextView.mm:5271)
- `lspFindReferences:(id)sender` (OakTextView.mm:4798)

**Pattern for LSP Actions:**
1. Validate documentView exists
2. Get caret position and convert to pos_t: `documentView->convert(caret)`
3. Call LSPManager methods with callbacks
4. Flush pending changes first: `[[LSPManager sharedManager] flushPendingChangesForDocument:doc]`
5. Handle response (may be async, uses weak/strong self pattern)

**Key Implementation Details:**
- pos_t has: `size_t line, column, offset`
- LSP uses: `line` and `character` (same as column)
- Buffer conversion: `text::pos_t pos = documentView->convert(index.index);`

### How TextEdits Would Be Applied

**Path to text modification:**
1. LSPClient receives formatting response with TextEdit[]
2. LSPManager routes to OakTextView
3. OakTextView action method (e.g., `lspFormatDocument:`) processes TextEdits:
   ```objc
   NSArray* textEdits = result[@"textEdits"] // or result if response is TextEdit[]
   std::multimap<std::pair<size_t, size_t>, std::string> replacements;
   for(NSDictionary* edit in textEdits) {
       // Convert LSP range to buffer offsets
       NSDictionary* range = edit[@"range"];
       text::pos_t start(startLine, startChar);
       text::pos_t end(endLine, endChar);
       size_t from = documentView->convert(start);
       size_t to = documentView->convert(end);
       std::string newText = to_s(edit[@"newText"]);
       replacements.insert({{from, to}, newText});
   }
   [document performReplacements:replacements checksum:0];
   ```

4. `OakDocument::performReplacements:checksum:` calls `OakDocumentEditor::performReplacements:`
5. Which calls `editor_t::perform_replacements()` wrapped in undo grouping

### Object Model for Formatting Requests

**LSPClient additions needed:**
```objc
- (int)requestFormattingForURI:(NSString*)uri 
                      options:(NSDictionary*)options 
                   completion:(void(^)(NSArray<NSDictionary*>*))callback;

- (int)requestRangeFormattingForURI:(NSString*)uri 
                              range:(NSDictionary*)range  // {start: {line, character}, end: {line, character}}
                            options:(NSDictionary*)options 
                         completion:(void(^)(NSArray<NSDictionary*>*))callback;

- (int)requestOnTypeFormattingForURI:(NSString*)uri 
                                line:(NSUInteger)line 
                           character:(NSUInteger)character 
                                  ch:(NSString*)ch 
                             options:(NSDictionary*)options 
                          completion:(void(^)(NSArray<NSDictionary*>*))callback;
```

**LSPManager additions needed:**
```objc
- (int)requestFormattingForDocument:(OakDocument*)document 
                          completion:(void(^)(NSArray<NSDictionary*>*))callback;

- (int)requestRangeFormattingForDocument:(OakDocument*)document 
                                   range:(text::range_t)range 
                             completion:(void(^)(NSArray<NSDictionary*>*))callback;

- (int)requestOnTypeFormattingForDocument:(OakDocument*)document 
                                     line:(NSUInteger)line 
                                character:(NSUInteger)character 
                                       ch:(NSString*)ch 
                              completion:(void(^)(NSArray<NSDictionary*>*))callback;
```

**OakTextView.mm additions needed:**
```objc
- (void)lspFormatDocument:(id)sender;      // Ctrl-K Ctrl-F or similar
- (void)lspFormatSelection:(id)sender;     // Format selected range
- (void)lspFormatOnType;                   // Called after character insertion
```

### Capabilities Declaration

Current capabilities in `sendInitialize()` (LSPClient.mm:327-359):
- None for formatting. Need to add:
```cpp
{"textDocument", {
    ...existing capabilities...,
    {"formatting", {
        {"dynamicRegistration", false}
    }},
    {"rangeFormatting", {
        {"dynamicRegistration", false}
    }},
    {"onTypeFormatting", {
        {"dynamicRegistration", false}
    }}
}}
```

## Key Classes and Methods for Implementation

### document_view_t (OakTextView.mm:238)
Local struct inside OakTextView.mm that wraps OakDocumentEditor. Key methods:
- `convert(text::pos_t)` → `size_t` offset
- `convert(size_t)` → `text::pos_t`
- `substr(from, to)` → buffer content
- Access to `_editor`, `_layout`, `_document` 
- Holds `_document_editor` (OakDocumentEditor*)

The documentView is a `std::shared_ptr<document_view_t>` (line 468)

### Object Access Chain
1. OakTextView has `documentView` (shared_ptr<document_view_t>)
2. documentView has `_document_editor` (OakDocumentEditor*)
3. OakDocumentEditor has `_editor` (ng::editor_t*)
4. ng::editor_t has `perform_replacements(multimap<pair<size_t,size_t>, string>)`

### Document Access
1. OakTextView.document → OakDocument*
2. OakDocument has:
   - `.path` (NSString*)
   - `.fileType` (NSString*)
   - `.tabSize` (NSUInteger)
   - `.softTabs` (BOOL)
   - `.performReplacements:checksum:` → calls OakDocumentEditor

### Critical Implementation Point
To apply TextEdits from LSP formatting response:
1. Parse TextEdit array from response
2. For each TextEdit: convert LSP range to buffer offsets:
   ```objc
   text::pos_t start(lspLine, lspCharacter);
   text::pos_t end(endLine, endCharacter);
   size_t from = documentView->convert(start);
   size_t to = documentView->convert(end);
   replacements.insert({{from, to}, newText});
   ```
3. Call on document: `[document performReplacements:replacements checksum:0];`
4. This triggers: OakDocument → OakDocumentEditor → ng::editor_t::perform_replacements()
5. Wrapped in undo grouping for user convenience

### Formatting Options Construction
Can pass from document properties:
```objc
NSDictionary* options = @{
    @"tabSize": @(document.tabSize),
    @"insertSpaces": @(!document.softTabs),
    @"trimTrailingWhitespace": @(YES),  // or from settings
    @"insertFinalNewline": @(YES),
};
```

### Key LSP Method Names
- `textDocument/formatting` → full document format
- `textDocument/rangeFormatting` → range format (requires range param)
- `textDocument/onTypeFormatting` → format after char insertion
