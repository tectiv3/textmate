# Projects Preferences Pane

On feature/projects-preferences-pane branch.

## Architecture
Hybrid AppKit shell (ProjectsPreferencesV2.mm) + SwiftUI content (OakSwiftUI bridge).
- Left: NSTableView project list in NSSplitView
- Right: NSHostingView with segmented picker tabs (LSP/Editor/Files/All)

## Project List Source
KVDB database at ~/Library/Application Support/TextMate/RecentProjects.db.
Each entry: key=project path, value dict with `lastRecentlyUsed`, documents, window state.
Sorted by lastRecentlyUsed descending. "Global Defaults" pinned at top (path = ~/.tm_properties).

## Settings Loading Flow
1. User selects project → `loadSettingsForProject:`
2. Reads .tm_properties via `tm_properties_editor_t` (C++ class in Frameworks/settings/)
3. Builds scope list from section names (e.g. `*.php`)
4. Reads cascade values via `settings_info_for_path()` for source attribution
5. Builds `[OakPropertyEntry]` array, passes to SwiftUI bridge

## SwiftUI Performance Lessons
- TabView eagerly renders ALL tabs — use segmented Picker + @ViewBuilder switch instead
- SwiftUI TextField causes render loops with reference-type models — use NSViewRepresentable
- ForEach with NSObject reference types needs `.id()` modifier
- `State(initialValue:)` only sets once, doesn't update on parent data change
- ASan debug builds make SwiftUI unusably slow

## Key Files
- `Frameworks/Preferences/src/ProjectsPreferencesV2.mm` — AppKit shell
- `Frameworks/settings/src/tm_properties_editor.{h,cc}` — per-file .tm_properties R/W
- `Frameworks/OakSwiftUI/Sources/OakSwiftUI/Bridge/ProjectSettingsBridge.swift`
- `Frameworks/OakSwiftUI/Sources/OakSwiftUI/ProjectSettings/`
- `Frameworks/lsp/src/LSPManager.{h,mm}` — `lspStatusForFileType:projectPath:`
