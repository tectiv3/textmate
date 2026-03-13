# TextMate Project Overview

TextMate is a macOS-native text editor. The codebase is primarily **Objective-C++** — low-level data structures and algorithms use C++14, while GUI code uses Objective-C++ with AppKit/Cocoa. Licensed under GPL v3.

## Repository Structure

- `Applications/` - 11 apps (TextMate, mate, commit, gtm, bl, indent, etc.)
- `Frameworks/` - 45 self-contained frameworks (core logic + GUI)
- `PlugIns/` - Plugin system (dialog, dialog-1.x)
- `Shared/` - Shared PCH headers, oak utility includes
- `vendor/` - External deps (Onigmo, kvdb, MASPreferences, MGScopeBar, XcodeEditor)
- `bin/` - Build tools (gen_build, CxxTest)

## Key Frameworks

- **buffer/** - Text buffer (`ng::buffer_t`, chunked text via `oak::basic_tree_t`)
- **editor/** - Editing operations, clipboard, snippets, 40+ editor actions
- **layout/** - Text layout/rendering (`ng::layout_t`)
- **parse/** - Grammar/syntax parsing engine
- **OakTextView** - Main text editor view + GutterView + OTVStatusBar
- **DocumentWindow** - Document/session management

## Entry Point

`Applications/TextMate/src/main.mm`
