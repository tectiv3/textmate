# Self-Update System Removal

The entire self-update system was removed from the codebase on the `develop` branch:

- `Frameworks/SoftwareUpdate/` — deleted (auto-updater, update badge)
- `Frameworks/network/` — deleted (libcurl download, only used by updater)
- `Frameworks/updater/` — deleted (C++ bundle updater, was already disabled)
- `Applications/bl/` — deleted (CLI bundle tool, was already disabled)

## Relocated Utilities
- `OakCompareVersionStrings` → `Frameworks/OakFoundation/` (used by BundlesManager, TerminalPreferences)
- `OakDownloadManager` → `Frameworks/BundlesManager/` (its only consumer)
- `tbz_t` → `Frameworks/io/` (namespace changed from `network::` to `io::`, bug fix included)

## UI Changes
- "Check for Update" menu items removed from TextMate menu
- SoftwareUpdatePreferences pane replaced with CrashReportPreferences
- TMSigningKeys removed from Info.plist (BundlesManager has its own hardcoded keys)

## Impact
The `network` framework no longer exists. DocumentWindow now links SystemConfiguration directly (was previously transitive via network). BundlesManager links Security framework for signature verification. ~3400 lines of dead code removed.
