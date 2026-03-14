# TextMate Project Overview

TextMate is a macOS-native text editor. The codebase is primarily **Objective-C++** — low-level data structures and algorithms use C++20, while GUI code uses Objective-C++ with AppKit/Cocoa. Licensed under GPL v3. Minimum deployment target: macOS 14.0.

## Repository Structure

- `Applications/` - 10 apps (TextMate, mate, commit, gtm, indent, NewApplication, pretty_plist, PrivilegedTool, QuickLookGenerator, tm_query). Note: `bl` exists but is disabled in CMake.
- `Frameworks/` - 49 self-contained frameworks (core logic + GUI), including new `lsp/` framework for Language Server Protocol support
- `PlugIns/` - Plugin system (dialog, dialog-1.x) — incorporated into repo
- `Shared/` - Shared PCH headers, oak utility includes
- `vendor/` - External deps (Onigmo, kvdb, nlohmann/json)
- `bin/` - Build tools (gen_test, CxxTest) and release scripts
- `cmake/` - CMake helper functions (TextMateHelpers.cmake)

## Key Frameworks

- **buffer/** - Text buffer (`ng::buffer_t`, chunked text via `oak::basic_tree_t`)
- **editor/** - Editing operations, clipboard, snippets, 40+ editor actions
- **layout/** - Text layout/rendering (`ng::layout_t`)
- **parse/** - Grammar/syntax parsing engine
- **lsp/** - Language Server Protocol client (Phase 1: config, document sync, diagnostics)
- **OakTextView** - Main text editor view + GutterView + OTVStatusBar
- **DocumentWindow** - Document/session management

## Entry Point

`Applications/TextMate/src/main.mm` — sets app support dir via `oak::application_t::set_support()`, registers signal handlers, calls `NSApplicationMain()`.

## App Support Path

Use `oak::application_t::support("relative/path")` (from `<OakSystem/application.h>`) instead of hardcoding `~/Library/Application Support/TextMate/`.

## Active Development

- LSP support is being built in `feature/lsp-client` branch (Phase 1 done: framework, config, document sync, diagnostics in gutter)
- Fork: `tectiv3/textmate`, based on upstream `textmate/textmate` (unmaintained)
