# TextMate Build System

## Overview
Custom build system centered on `bin/rave` (1,579 lines, Ruby), a DSL compiler that generates `build.ninja` from `.rave` declaration files.

## Pipeline
```
./configure → bin/rave → build.ninja → ninja
```

### configure (36 lines, shell)
1. Checks deps: capnp, ninja, ragel, multimarkdown, pgrep, pkill
2. Validates headers/libs in /usr/local (boost, capnp, sparsehash)
3. Creates `local.rave` with include/lib paths
4. Calls `bin/rave -crelease -tTextMate`

### bin/rave (Ruby)
- Parser: recursively loads .rave files, expands variables/globs
- Compiler plugins: CompileClang, CompileRagel, CompileCapnp, CompileXib, CompileAssetCatalog, ConvertToUTF16
- Handles linking, bundling, code signing, notarization
- Outputs build.ninja with depfile tracking

### .rave format (63 files, ~507 lines total)
Declarative DSL: target, config, require, sources, headers, tests, frameworks, libraries, prelude, prefix, executable, files, copy, define, expand, set/add, capture, load, notarize.

Example framework (buffer): 6 lines — target, headers, sources, tests.
Example app (TextMate): 37 lines — 20+ framework deps, resources, plugins, code signing.

## Dependencies
- **Vendored:** Onigmo (regex), kvdb (key-value DB over sqlite3)
- **System (Homebrew):** boost, capnp, ragel, multimarkdown, sparsehash, ninja
- **System frameworks:** Cocoa, AppKit, ApplicationServices, Security, etc.

## Build output (default ~/build/TextMate)
- `_Compile/` — object files
- `_PCH*/` — precompiled headers
- `_Include/` — symlinks to framework headers
- `release/` — final outputs (TextMate.app)

## Pain Points
- Ruby dependency for bin/rave (not shipped with modern Xcode)
- local.rave assumes /usr/local paths (breaks on ARM Homebrew /opt/homebrew)
- Custom undocumented DSL — must read bin/rave source
- CI/CD removed from this fork
- bin/gen_build is legacy/dead code (just calls configure)

## What's Custom vs Standard
- Custom: .rave format, bin/rave generator
- Standard: Ninja (build tool), Clang/LLVM (compiler), code signing (xcrun)
