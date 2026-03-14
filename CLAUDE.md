# CLAUDE.md - TextMate Development Guide

## Project Overview

TextMate is a macOS-native text editor written in **Objective-C++**. Low-level data structures and algorithms are C++20; GUI code uses Objective-C++ with AppKit/Cocoa. Licensed under GPL v3. Minimum deployment target: macOS 14.0.

## Repository Structure

```
Applications/   - 10 apps (TextMate, mate, commit, gtm, indent, etc.)
Frameworks/     - 45 self-contained frameworks (core logic + GUI)
PlugIns/        - Plugin system (dialog, dialog-1.x) — incorporated into repo
Shared/         - Shared PCH headers, oak utility includes
vendor/         - External deps (Onigmo, kvdb)
bin/            - Build tools (gen_test, CxxTest) and release scripts
cmake/          - CMake helper functions (TextMateHelpers.cmake)
```

## Build System

- **Build tool:** CMake + Ninja
- **Bundle ID:** `com.macromates.TextMate-dev` (coexists with production TextMate)

### Key Build Commands

```bash
make debug           # Incremental debug build (ASan enabled)
make release         # Incremental release build (LTO, no ASan)
make run             # Build debug and launch
make clean           # Remove all build dirs
```

### Dependencies

ninja, cmake

### Build Quirks

- `-ObjC` linker flag required to load ObjC categories from static libraries
- `network` framework include path is PRIVATE to avoid case-insensitive collision with Apple's Network.framework
- `Frameworks/updater` and `Applications/bl` disabled (not needed, avoids network collision)
- OakDebug linked unconditionally (symbols used in all build configs)
- Plugin `.tmplugin` bundles need ad-hoc codesigning before embedding in app
- gen_test runner inlines test source bodies — don't compile test files separately
- Framework resources (icons, images, plists) must be added to TextMate app CMakeLists since static libs can't carry resources

## Architecture

### Core Data Structures (Frameworks/)

- **buffer/** - Text buffer: `ng::buffer_t` built on `ng::detail::storage_t` (chunked text via `oak::basic_tree_t`)
- **editor/** - Editing operations, clipboard, snippets, 40+ editor actions
- **layout/** - Text layout/rendering: `ng::layout_t` wraps buffer + viewport
- **parse/** - Grammar/syntax parsing engine
- **scope/** - Scope management for syntax highlighting
- **text/** - String/text utilities

### GUI Frameworks

- **OakTextView** - Main text editor view + GutterView + OTVStatusBar
- **OakAppKit** - macOS AppKit utilities/extensions
- **DocumentWindow** - Document/session management
- **Preferences** - Settings UI
- **BundleEditor** / **BundlesManager** - Bundle editing and management

### Support Frameworks

- **command/** - Command execution
- **plist/** - Property list I/O
- **regexp/** - Regex (Onigmo-based)
- **scm/** - Source control (git, svn, hg)
- **theme/** - Theme loading
- **file/** - File I/O
- **io/** - I/O abstractions
- **network/** - Networking
- **undo/** - Undo/redo stack

### Entry Point

`Applications/TextMate/src/main.mm` - Sets app support dir via `oak::application_t::set_support()`, registers signal handlers, calls `NSApplicationMain()`.

### App Support Path

Use `oak::application_t::support("relative/path")` (from `<OakSystem/application.h>`) instead of hardcoding `~/Library/Application Support/TextMate/`. Set once in `main.mm`.

## Code Conventions

- **Tab size:** 3 (hard tabs, no soft tabs)
- **Namespaces:** `oak::` (utilities), `ng::` (text/buffer engine)
- **Type suffix:** `_t` for type definitions, `_ptr` for smart pointers
- **Pointer style:** `type* var`
- **Visibility:** hidden by default (`-fvisibility=hidden`)
- **Memory:** std::shared_ptr, ARC for Objective-C
- **Header guards:** `#ifndef SOMETHING_H_RANDOMHASH`
- **Commit messages:** Summary < 70 chars, blank line, then reasoning
- **No `@available` checks** for APIs available since macOS 14 (our minimum target)

## Testing

- **Framework:** CxxTest (at `bin/CxxTest`)
- **Test files:** `Frameworks/<name>/tests/t_*.cc` or `t_*.mm`
- **Run tests:** `cd build-debug && ctest --output-on-failure`

## Upstream Status

This fork (`tectiv3/textmate`) is based on `textmate/textmate` at the latest upstream commit. Upstream is unmaintained. Active community fork: `tagliala/textmate`.
