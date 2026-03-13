# CLAUDE.md - TextMate Development Guide

## Project Overview

TextMate is a macOS-native text editor written in **Objective-C++**. Low-level data structures and algorithms are C++14; GUI code uses Objective-C++ with AppKit/Cocoa. Licensed under GPL v3.

## Repository Structure

```
Applications/   - 11 apps (TextMate, mate, commit, gtm, bl, indent, etc.)
Frameworks/     - 45 self-contained frameworks (core logic + GUI)
PlugIns/        - Plugin system (dialog, dialog-1.x)
Shared/         - Shared PCH headers, oak utility includes
vendor/         - External deps (Onigmo, kvdb, MASPreferences, MGScopeBar, XcodeEditor)
bin/            - Build tools (gen_build, CxxTest)
```

## Build System

- **Build tool:** Ninja (generated from `target` files by `bin/gen_build` Ruby script)
- **Bootstrap:** `./configure && ninja`
- **Build dir:** `~/build/TextMate` (override with `builddir` env var)

### Key Build Commands

```bash
ninja TextMate           # Build main app
ninja TextMate/run       # Build and run
ninja <framework>/test   # Run tests for a framework (e.g., ninja io/test)
ninja -t clean           # Clean everything
```

### Dependencies

ragel, boost, multimarkdown, mercurial (for tests), Cap'n Proto, LibreSSL, google-sparsehash, ninja

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

`Applications/TextMate/src/main.mm` - Initializes curl, sets up app support dir, registers signal handlers, calls `NSApplicationMain()`.

## Code Conventions

- **Tab size:** 3 (hard tabs, no soft tabs)
- **Namespaces:** `oak::` (utilities), `ng::` (text/buffer engine)
- **Type suffix:** `_t` for type definitions, `_ptr` for smart pointers
- **Pointer style:** `type* var`
- **Visibility:** hidden by default (`-fvisibility=hidden`)
- **Memory:** std::shared_ptr, ARC for Objective-C
- **Header guards:** `#ifndef SOMETHING_H_RANDOMHASH`
- **Commit messages:** Summary < 70 chars, blank line, then reasoning

## Testing

- **Framework:** CxxTest (at `bin/CxxTest`)
- **Test files:** `Frameworks/<name>/tests/t_*.cc` or `t_*.mm`
- **Run tests:** `ninja <framework>/test`

## Upstream Status

This fork (`tectiv3/textmate`) is based on `textmate/textmate` at commit `69b5af7`. Upstream has **992 additional commits** since the fork point, including:
- Build system migration from `target` files to `.rave` files
- GitHub Actions CI workflow
- File browser refactoring (TMFileReference)
- Dark mode improvements
- Various bug fixes and code modernization
- 840 files changed (~21.5k insertions, ~20.9k deletions)

The fork has **no local divergence** from its own master — it is a clean snapshot of upstream at the fork point.
