# OakSwiftUI Framework

## Status
OakSwiftUI framework implemented on branch `feature/add-ui-swiftui-framework`. Provides SwiftUI-based UI primitives for TextMate.

## Architecture
- SPM dynamic library at `Frameworks/OakSwiftUI/`
- Built via `build.sh` before CMake (two-phase build)
- Optional dependency — TextMate builds without Swift installed
- `@objc` bridge classes expose API to ObjC++ consumers
- `HAVE_OAK_SWIFTUI` compile-time flag for conditional features

## Primitives
1. **OakCompletionPopup** — borderless NSPanel with LazyVStack, keyboard nav, fuzzy filtering
2. **OakInfoTooltip** — NSPopover with SwiftUI content (attributed string, code snippets)
3. **OakFloatingPanel** — NSPanel utility window, child of parent editor window

## Key Classes (Bridge/)
- `OakCompletionPopup` + `OakCompletionPopupDelegate` — completion popup with `show(in:at:items:)`, `updateFilter(_:)`, `handleKeyEvent(_:)`, `dismiss()`
- `OakInfoTooltip` + `OakInfoTooltipDelegate` — tooltip with `show(in:at:content:)`, `reposition(to:)`, `dismiss()`
- `OakFloatingPanel` + `OakFloatingPanelDelegate` — panel with `show(content:title:parentWindow:)`, `close()`
- `OakThemeEnvironment` — ObservableObject bridging TextMate theme to SwiftUI
- `OakCompletionItem` — completion item data model

## Build
- `make debug` runs `build.sh` then cmake+ninja
- 19 Swift tests via `cd Frameworks/OakSwiftUI && swift test`
- Dylib copied to `TextMate.app/Contents/Frameworks/`

## Swift 6 Notes
- Bridge classes use `@MainActor` for AppKit/SwiftUI interaction
- NSDelegate callbacks use `nonisolated` + `MainActor.assumeIsolated`
- `OakSwiftUIFramework.version` uses `@objc(oakVersion)` to avoid NSObject collision
