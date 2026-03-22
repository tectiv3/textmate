# Build Deprecation Warnings Status (2026-03-14)

Started at 576 warnings, fixed the low-hanging fruit.

## Fixed (trivial/mechanical)
- Deprecated `std::iterator` inheritance (~300 warnings) — explicit typedefs in 5 headers
- VLA → `std::vector` in 7 files
- `NSBackgroundStyleDark` → `NSBackgroundStyleEmphasized` (5 files)
- Pasteboard name constants modernized
- `NSApplicationActivateIgnoringOtherApps` → `activateWithOptions:0`
- `commitEditing` — added `<NSEditor>` protocol where needed
- Pasteboard types, NSUserNotification, mktemp→mkstemp, colorUsingColorSpaceName, openFile→openURL, iconForFileType→iconForContentType, kUTType constants

## Remaining — Moderate Refactors
- **FSEventStreamScheduleWithRunLoop → FSEventStreamSetDispatchQueue** (3 files: scm/fs_events, io/events, FileBrowser/FSEventsManager)
- **SecTransformRef/SecVerifyTransformCreate** (2 files) → SecKeyVerifySignature
- **SecKeychainItemCopyAttributesAndData** (1 file in license/keychain)
- **launchApplicationAtURL → openApplicationAtURL** (2 files, sync→async)
- **NSWorkspaceLaunch* flags → NSWorkspaceOpenConfiguration** (2 files)
- **LSOpenURLsWithRole / LSCopyItemInfoForURL** (2 files) → NSWorkspace/URL resource values
- **NSConnection** (dialog-1.x plugin only, 2 files) — requires NSXPCConnection migration

## Remaining — Major Refactors
- **WebView → WKWebView** (~80 warnings, ~1535 lines in HTMLOutput) — no WebScriptObject equivalent
- **QuickLook plugin** (~8 warnings) — requires complete rewrite as QL Extension

## Low Priority (still functional)
- `bezeled`, `alternateSelectedControlColor`, graphics context, currentAppearance, UNNotificationPresentationOptionAlert
