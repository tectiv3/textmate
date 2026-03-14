# OakSwiftUI Framework - Complete Analysis

## Overview
OakSwiftUI is a dynamic Swift library built with Swift Package Manager that provides SwiftUI UI primitives for TextMate. It's fully functional and integrated into the build system, not just planned.

**Location:** `/Users/fenrir/code/textmate/Frameworks/OakSwiftUI/`
**Build:** Swift Package Manager (SPM) — not CMake
**Version:** 0.1.0 (exposed as `oakVersion` in ObjC)
**Deployment Target:** macOS 14.0

## Build System

### Package.swift
- Product: `OakSwiftUI` (dynamic library)
- Single target with all sources in `Sources/OakSwiftUI/`
- Test target: `OakSwiftUITests` in `Tests/OakSwiftUITests/`

### Build Script (build.sh)
```bash
./build.sh [debug|release] [build-dir]
```
- Swift package build creates `.build/{config}/libOakSwiftUI.dylib`
- Script copies to `${BUILD_DIR}/lib/libOakSwiftUI.dylib`
- Sets install name to `@rpath/libOakSwiftUI.dylib` for runtime resolution

### CMake Integration
- **Finder:** `/Users/fenrir/code/textmate/CMakeLists.txt` line 75-82
  - Searches for `OakSwiftUI` in `${CMAKE_BINARY_DIR}/lib`
  - Optional: warns if not found, disables SwiftUI features
  
- **Header Path:** `/Users/fenrir/code/textmate/Frameworks/OakTextView/CMakeLists.txt`
  - Includes `.build/arm64-apple-macosx/debug/OakSwiftUI.build/include/`
  - Links `${OakSwiftUI_LIB}` if found
  
- **App Linking:** `/Users/fenrir/code/textmate/Applications/TextMate/CMakeLists.txt`
  - Links `${OakSwiftUI_LIB}` to TextMate executable

## Swift File Inventory (15 files total)

### Bridge Classes (ObjC-compatible, @objc marked)
1. **OakSwiftUI.swift** (1 file)
   - `OakSwiftUIFramework: NSObject` — version constant
   
2. **OakThemeEnvironment.swift**
   - `@MainActor @objc public class OakThemeEnvironment: NSObject, ObservableObject`
   - Published properties: fontName, fontSize, backgroundColor, foregroundColor, selectionColor, keywordColor, commentColor, stringColor
   - `font` computed property (returns NSFont)
   - `applyTheme(_ dict: NSDictionary)` — bulk theme update from ObjC
   
3. **OakCompletionItem.swift**
   - `@objc public class OakCompletionItem: NSObject, Identifiable`
   - Properties: label, insertText?, detail, kind, icon?, isSnippet
   - `effectiveInsertText` — computed property (insertText ?? label)
   - `kindSymbolName` — maps LSP CompletionItemKind to SF Symbol names
   - `kindLabel` — short text labels for kinds ("method", "func", etc.)
   
4. **OakCompletionPopup.swift**
   - `@MainActor @objc public class OakCompletionPopup: NSObject`
   - Delegate: `OakCompletionPopupDelegate?`
   - `show(in parentView: NSView, at point: NSPoint, items: [OakCompletionItem])`
   - `updateFilter(_ text: String)` — live filtering, resizes panel
   - `handleKeyEvent(_ event: NSEvent) -> Bool`
     - Arrow keys: navigate
     - Return/Tab: select and dismiss
     - Escape: dismiss
   - `dismiss()` — cleanup
   - `isVisible: Bool`
   - **Hosting:** NSPanel with `.borderless, .nonactivatingPanel` style mask
     - Fixed width calc: min(max(labelWidth + detailWidth + 60, 280), 650)
     - Height based on items (max 12, min 22pt row)
     - Auto-positions above cursor, flips below if off-screen
     - `.floating` level, opaque=false, hasShadow=true
     
5. **OakCompletionPopupDelegate.swift**
   - `@objc public protocol OakCompletionPopupDelegate: AnyObject`
   - `completionPopup(_ popup: OakCompletionPopup, didSelectItem item: OakCompletionItem)`
   - `completionPopupDidDismiss(_ popup: OakCompletionPopup)`
   
6. **OakInfoTooltip.swift**
   - `@MainActor @objc public class OakInfoTooltip: NSObject, NSPopoverDelegate`
   - Delegate: `OakInfoTooltipDelegate?`
   - `show(in view: NSView, at rect: NSRect, content: OakTooltipContent)`
   - `show(in view: NSView, at rect: NSRect, content: OakTooltipContent, preferredEdge edge: NSRectEdge)` — overload
   - `dismiss()` — calls popover.performClose(nil)
   - `reposition(to rect: NSRect)` — updates positioningRect
   - `isVisible: Bool`
   - **Hosting:** NSPopover with behavior=.semitransient
   
7. **OakInfoTooltipDelegate.swift**
   - `@objc public protocol OakInfoTooltipDelegate: AnyObject`
   - `infoTooltipDidDismiss(_ tooltip: OakInfoTooltip)`
   
8. **OakTooltipContent.swift**
   - `@objc public class OakTooltipContent: NSObject`
   - Properties: title?, body (NSAttributedString), codeSnippet?, language?
   - Two inits: minimal (body only) and convenience (all fields)
   
9. **OakFloatingPanel.swift**
   - `@MainActor @objc public class OakFloatingPanel: NSObject, NSWindowDelegate`
   - Delegate: `OakFloatingPanelDelegate?`
   - `show(content: NSView, title: String, parentWindow: NSWindow)`
     - 400x300 default size, .titled, .closable, .resizable, .utilityWindow
     - Added as child window
   - `close()` — cleanup
   - `isVisible: Bool`
   - **Hosting:** NSPanel with standard utility window style
   
10. **OakFloatingPanelDelegate.swift**
    - `@objc public protocol OakFloatingPanelDelegate: AnyObject`
    - `floatingPanelDidClose(_ panel: OakFloatingPanel)`

### Completion Popup UI (internal SwiftUI views)
11. **CompletionViewModel.swift**
    - `@MainActor public class CompletionViewModel: ObservableObject`
    - Published: filteredItems, selectedIndex
    - `setItems(_ items: [OakCompletionItem])`
    - `updateFilter(_ text: String)` → uses FuzzyMatcher
    - `selectNext()`, `selectPrevious()` with bounds checking
    - `selectedItem: OakCompletionItem?` computed getter
    
12. **CompletionListView.swift** (SwiftUI View)
    - Wraps CompletionViewModel in ScrollView with LazyVStack
    - Renders CompletionRowView for each filtered item
    - ScrollViewReader auto-scrolls selected item to center
    - Background: .ultraThinMaterial, RoundedRectangle(cornerRadius: 6)
    
13. **CompletionRowView.swift** (SwiftUI View)
    - Icon (SF Symbol) → Label → Spacer → Detail
    - Kind-based coloring (method/func=blue, class=purple, etc.)
    - Selected state: accentColor background, alternateSelectedControlTextColor text
    - Uses monospaced font for label, smaller for detail
    
14. **FuzzyMatcher.swift** (generic fuzzy scoring)
    - `score(_ candidate: String, query: String) -> FuzzyMatchResult?`
    - Returns nil if query not fully matched in candidate
    - Scoring: consecutive chars (+3), start of word (+5), char match (+1), exact match (+10)
    - Penalty: -count/5 (prefer shorter matches)
    - Strong bonus (+50) for prefix match
    - `filter<T>(_ items: [T], query: String, keyPath: KeyPath<T, String>) -> [T]`
      - Returns items sorted by score descending
      - Empty query returns all items unfiltered

### Tooltip UI (internal SwiftUI views)
15. **TooltipContentView.swift** (SwiftUI View)
    - VStack: title (semibold, monospaced) → body → codeSnippet
    - Code snippet: monospaced, dark background, cornerRadius=4
    - Max width: 500
    - Padding: 12pt

## Generated ObjC Bridge Header

**File:** `.build/arm64-apple-macosx/release/OakSwiftUI.build/include/OakSwiftUI-Swift.h`
**Generated by:** Swift compiler (Apple Swift 6.2.4)

All @objc classes and protocols exposed:
- `OakSwiftUIFramework` (+ class property: oakVersion)
- `OakThemeEnvironment` (all properties @objc, applyTheme method)
- `OakCompletionItem` (all properties, init)
- `OakCompletionPopup` (delegate, show/updateFilter/handleKeyEvent/dismiss/isVisible)
- `OakCompletionPopupDelegate` protocol (2 methods)
- `OakFloatingPanel` (delegate, show/close/isVisible)
- `OakFloatingPanelDelegate` protocol (1 method)
- `OakInfoTooltip` (delegate, show overloads/dismiss/reposition/isVisible)
- `OakInfoTooltipDelegate` protocol (1 method)
- `OakTooltipContent` (title/body/codeSnippet/language, 2 inits)

All nullability properly marked (_Nonnull, _Nullable), SWIFT_UNAVAILABLE where needed.

## Window/Panel Hosting Summary

| Component | Host | Style | Purpose |
|-----------|------|-------|---------|
| CompletionPopup | NSPanel | .borderless, .nonactivatingPanel, .floating | Floating code completion list |
| InfoTooltip | NSPopover | .semitransient | Hover information/docs |
| FloatingPanel | NSPanel | .titled, .closable, .resizable, .utilityWindow | Generic floating utility panel |

All use NSHostingView or NSHostingController to embed SwiftUI views.

## Integration in OakTextView

**File:** `/Users/fenrir/code/textmate/Frameworks/OakTextView/src/OakTextView.mm`

- `_lspTheme: OakThemeEnvironment` — shared theme instance
- `_lspCompletionPopup: OakCompletionPopup` — initialized once
- `_lspHoverTooltip: OakInfoTooltip` — initialized once
- Implements both delegate protocols
- OakTextView conforms to `OakCompletionPopupDelegate` and `OakInfoTooltipDelegate`

## What Exists vs. What's Planned

**FULLY IMPLEMENTED:**
- ✅ CompletionPopup (NSPanel hosting)
- ✅ InfoTooltip (NSPopover hosting)
- ✅ FloatingPanel (NSPanel hosting) — not just planned
- ✅ OakThemeEnvironment with full color/font management
- ✅ Fuzzy matching for completion filtering
- ✅ All ObjC bridge classes (@objc marked)
- ✅ Unit tests for all bridge classes

**INTERNAL SWIFTUI COMPONENTS (not exposed to ObjC):**
- CompletionListView, CompletionRowView, FuzzyMatcher
- TooltipContentView
- CompletionViewModel

## Key Design Patterns

1. **Bridge Pattern:** Objective-C++ (OakTextView) ↔ Swift (OakSwiftUI)
   - Bridge classes inherit NSObject, marked @objc
   - Delegates use @objc protocols for callback communication
   
2. **Environment Object:** OakThemeEnvironment
   - Published properties for SwiftUI reactivity
   - Shared singleton passed to all SwiftUI views via environmentObject()
   
3. **NSHostingView/NSHostingController:** SwiftUI embedding
   - CompletionPopup uses NSHostingView(rootView: CompletionListView)
   - InfoTooltip uses NSHostingController(rootView: TooltipContentView)
   
4. **MVVM:** CompletionViewModel
   - ViewModel holds state (filteredItems, selectedIndex)
   - Published properties drive UI updates
   - FuzzyMatcher encapsulates filtering logic
   
5. **MainActor:** Thread safety
   - All ObjC-visible classes marked @MainActor
   - Ensures UI updates happen on main thread

## Notes

- No explicit CMakeLists.txt in OakSwiftUI — uses Swift Package Manager
- Swift header generation automatic; stored in .build/ directory
- RC4 arch support: .build/arm64-apple-macosx/ only (apple silicon)
- Dynamic linking: libOakSwiftUI.dylib linked into TextMate and OakTextView
- The framework is NOT optional at runtime — the CMake optional find is just build-time elegance
