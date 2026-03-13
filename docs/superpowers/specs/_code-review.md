# Code Review: CMake Migration Design Spec

**Reviewed:** 2026-03-13-cmake-migration-design.md
**Reviewer:** Architecture Review
**Date:** 2026-03-13

---

## Table of Contents

1. [Critical Issues](#1-critical-issues)
   - [1.1 Missing Compiler Transforms: Markdown, Bundle Archive, Variable Expansion](#11-missing-compiler-transforms-markdown-bundle-archive-variable-expansion)
   - [1.2 QuickLook Generator Is Not a Regular App Bundle](#12-quicklook-generator-is-not-a-regular-app-bundle)
   - [1.3 SyntaxMate Is an XPC Service, Not an App](#13-syntaxmate-is-an-xpc-service-not-an-app)
   - [1.4 PCH Strategy Underestimates Complexity](#14-pch-strategy-underestimates-complexity)
   - [1.5 Missing Header Export Mechanism](#15-missing-header-export-mechanism)
   - [1.6 Entitlements Handling Not Addressed](#16-entitlements-handling-not-addressed)
2. [Completeness Gaps](#2-completeness-gaps)
   - [2.1 Rave Commands Not Mapped to CMake](#21-rave-commands-not-mapped-to-cmake)
   - [2.2 Missing System Libraries](#22-missing-system-libraries)
   - [2.3 Missing System Frameworks Per-Target](#23-missing-system-frameworks-per-target)
   - [2.4 No Equivalent for the `run` Target](#24-no-equivalent-for-the-run-target)
   - [2.5 LTO Cache Path Dropped](#25-lto-cache-path-dropped)
   - [2.6 Debug Config Requires OakDebug Framework](#26-debug-config-requires-oakdebug-framework)
   - [2.7 `expand_variables` Script Is Also Ruby](#27-expand_variables-script-is-also-ruby)
   - [2.8 `gen_html` Script Is Also Ruby](#28-gen_html-script-is-also-ruby)
   - [2.9 DefaultBundles.tbz.bl Archive Pipeline Missing](#29-defaultbundlestbzbl-archive-pipeline-missing)
3. [Correctness Issues](#3-correctness-issues)
   - [3.1 GLOB_RECURSE Is Fragile and Discouraged](#31-glob_recurse-is-fragile-and-discouraged)
   - [3.2 ObjC Flags Approach Will Not Work Correctly](#32-objc-flags-approach-will-not-work-correctly)
   - [3.3 Test Pattern Assumes One-Test-Per-File; Misses CxxTest](#33-test-pattern-assumes-one-test-per-file-misses-cxxtest)
   - [3.4 Ragel Output Filename Logic Has an Edge Case](#34-ragel-output-filename-logic-has-an-edge-case)
   - [3.5 Asset Catalog DEPENDS Is on a Directory](#35-asset-catalog-depends-is-on-a-directory)
   - [3.6 UTF-16 Conversion Is Lossy vs. Rave](#36-utf-16-conversion-is-lossy-vs-rave)
   - [3.7 The `fobjc-link-runtime` Linker Flag Is Missing](#37-the-fobjc-link-runtime-linker-flag-is-missing)
   - [3.8 Missing `-Os` in Debug Config](#38-missing--os-in-debug-config)
4. [Risks](#4-risks)
   - [4.1 Cap'n Proto Removal via NSKeyedArchiver Crosses Language Boundaries](#41-capn-proto-removal-via-nskeyedarchiver-crosses-language-boundaries)
   - [4.2 No Incremental Migration Path](#42-no-incremental-migration-path)
   - [4.3 CMake Minimum Version 3.20 vs. ObjC/ObjCXX Support Maturity](#43-cmake-minimum-version-320-vs-obcobjcxx-support-maturity)
5. [Improvement Opportunities](#5-improvement-opportunities)
   - [5.1 Use Object Libraries for Shared Code](#51-use-object-libraries-for-shared-code)
   - [5.2 Deployment Target Is Outdated](#52-deployment-target-is-outdated)
   - [5.3 Consider FetchContent for Boost/sparsehash](#53-consider-fetchcontent-for-boostsparsehash)

---

## 1. Critical Issues

### 1.1 Missing Compiler Transforms: Markdown, Bundle Archive, Variable Expansion

The rave build system has seven compiler transforms. The spec accounts for four (Clang, Ragel, Xib, AssetCatalog, UTF-16 strings). Three are missing entirely:

**CompileMarkdown** (`.md` -> `.html`): TextMate's `about/` directory contains five `.md` files (`About.md`, `Changes.md`, `Contributions.md`, `Legal.md`, `Registration.md`) that are compiled to HTML via `bin/gen_html` and bundled into `Resources/About`. The TextMate rave file references `about/*` under `files`, and the rave system auto-transforms `.md` files through the Markdown compiler. The spec's CMake equivalent for TextMate bundling does not mention this pipeline at all.

**ExpandVariables** (`Info.plist` -> `Info.plist`, `InfoPlist.strings` -> `InfoPlist.strings`): The rave system runs `bin/expand_variables` on `Info.plist` files, substituting `${VARIABLE}` placeholders with build-time values including `APP_VERSION`, `TARGET_NAME`, `APP_MIN_OS`, `YEAR`, and `CS_GET_TASK_ALLOW`. The spec mentions `configure_file()` in the "Files Removed" table as replacing `bin/expand_variables` but never shows how it will be used, what variables will be defined, or how the conditional `CS_GET_TASK_ALLOW` (true for debug, false for release) will be handled.

**CreateBundlesArchive** (`.tbz.bl` -> `.tbz`): See section 2.9.

### 1.2 QuickLook Generator Is Not a Regular App Bundle

The spec proposes treating all Applications as `MACOSX_BUNDLE` executables. However, `TextMateQL` is a QuickLook generator (`.qlgenerator` bundle) which uses `-bundle` as a linker flag and has a non-standard prefix `TextMateQL.qlgenerator/Contents`. This is not an application bundle. CMake's `MACOSX_BUNDLE` property produces `.app` bundles, not `.qlgenerator` bundles.

The correct CMake approach is `add_library(TextMateQL MODULE)` with manual `BUNDLE_EXTENSION` and `BUNDLE` properties, or using `set_target_properties` with `SUFFIX .qlgenerator`. This is a distinct target type that the spec does not address.

Additionally, `TextMateQL` is embedded into the main TextMate app at `Library/QuickLook`, not `PlugIns`.

### 1.3 SyntaxMate Is an XPC Service, Not an App

`SyntaxMate` uses `prefix "${target}.xpc/Contents"` in its rave file, making it an XPC service bundle (`.xpc`). Like the QuickLook generator, this requires different CMake treatment than a standard `MACOSX_BUNDLE`. The spec does not account for XPC service bundles. The embedding location and `Info.plist` requirements for XPC services are different from standard applications.

### 1.4 PCH Strategy Underestimates Complexity

The spec acknowledges that the four prelude files "may need consolidation" but treats this as a minor detail. It is not. The current PCH system is carefully layered:

- `prelude.c` -- C system headers (50+ includes including curl, zlib, POSIX)
- `prelude-mac.h` -- macOS framework headers (Carbon, CoreFoundation, Security, etc.)
- `prelude.cc` -- C++ standard library + Boost + sparsehash (includes `prelude.c` and `prelude-mac.h`)
- `prelude.m` -- ObjC frameworks: Cocoa, WebKit, Quartz (includes `prelude.c` and `prelude-mac.h`)
- `prelude.mm` -- Includes all of the above

This layered structure means:
- Pure C files get only C system headers
- C++ files get C + macOS + C++ stdlib headers
- ObjC files get C + macOS + ObjC framework headers
- ObjC++ files get everything

CMake's `target_precompile_headers(... REUSE_FROM ...)` applies a single PCH to all source files in a target. If you create a unified header with `#ifdef __cplusplus`/`#ifdef __OBJC__` guards, the PCH binary itself is compiled once for one language. You cannot have a single PCH target that produces four different PCH binaries (one per language).

The practical consequence: either you create four separate interface targets (one per language combination) and selectively apply them -- which CMake does not natively support per-file within a target -- or you accept that pure C files will pull in C++ headers, which changes compilation semantics and may break code that relies on C-only behavior.

The spec's one-liner "consolidation into a single header" significantly understates this problem and should be expanded into a concrete plan.

### 1.5 Missing Header Export Mechanism

The rave system has a `headers` directive that copies public headers into a structured include directory (`_Include/<target>/<target>/header.h`), creating a "framework-like" public interface. This is how cross-framework includes work: `#include <buffer/buffer.h>`.

The spec's pattern uses `target_include_directories(buffer PUBLIC src)`, which would expose the entire `src/` directory. This differs from the rave system in two ways:

1. The rave system only exports headers explicitly listed in `headers src/buffer.h src/indexed_map.h src/storage.h`. The CMake pattern exposes everything in `src/`.
2. The include path changes. With rave, consumers include `<buffer/buffer.h>` because headers are exported under `_Include/buffer/buffer/buffer.h`. With `PUBLIC src`, consumers would include `<buffer.h>` directly -- unless the source tree already has headers nested under a subdirectory matching the framework name.

This needs verification. If the current include paths in source files use `#include <buffer/buffer.h>`, the proposed `target_include_directories(buffer PUBLIC src)` will break compilation unless `src/` contains a `buffer/` subdirectory, which it almost certainly does not.

### 1.6 Entitlements Handling Not Addressed

The TextMate rave file uses `expand CS_ENTITLEMENTS "${dir}/Entitlements.plist"` to process the entitlements plist through variable expansion, then passes it to codesign via `add CS_FLAGS "--entitlements '${CS_ENTITLEMENTS}'"`. The spec's `textmate_codesign` function does not accept or pass entitlements. The expanded entitlements differ between debug (`CS_GET_TASK_ALLOW=true`) and release (`CS_GET_TASK_ALLOW=false`), so this is not just a missing flag -- it requires build-configuration-aware plist generation.

---

## 2. Completeness Gaps

### 2.1 Rave Commands Not Mapped to CMake

The following rave DSL commands appear in the codebase but have no CMake equivalent described in the spec:

| Command | Usage | Impact |
|---------|-------|--------|
| `capture` | Extracts `TEXTMATE_VERSION` from `Changes.md` at configure time | Version string will be missing from Info.plist |
| `require_headers` | Used by Preferences, OakDebug, CommitWindow, TMFileReference | Weak dependency (headers-only) not modeled |
| `cxx_tests` | Used by layout, ns, OakAppKit for GUI tests (`gui_*.mm`) | GUI tests will not be built |
| `define` | Custom build actions (not currently used in .rave files, but supported) | Low impact |
| `notarize` | Full notarization pipeline | Not critical for development, but needed for release |
| `extend` | Extends an existing target definition | Low impact if unused |

The `require_headers` distinction matters: it creates a header-only (include-path) dependency without linking the library. Mapping everything to `target_link_libraries(... PUBLIC ...)` would over-link. The CMake equivalent is `target_include_directories` pointing at the dependency's public headers, without `target_link_libraries`.

### 2.2 Missing System Libraries

The spec's root CMakeLists.txt uses `libraries c++` from the rave global config, which translates to linking `libc++`. This is implicit with Clang on macOS, so it is fine. However, several per-target library dependencies are not mentioned in the spec's examples:

- `iconv` (text framework)
- `curl` (network framework)
- `z` (CrashReporter)
- `sqlite3` (kvdb, OakAppKit)

These need `find_library()` or direct `-l` flags in each framework's CMakeLists.txt. The spec only shows `capnp kj` being removed but does not confirm that all other `libraries` directives have been catalogued.

### 2.3 Missing System Frameworks Per-Target

The spec's TextMate app example shows some system frameworks but omits the full set used across all targets. Many frameworks link against system frameworks individually:

- `text` -> CoreFoundation
- `network` -> SystemConfiguration, Security
- `CrashReporter` -> Foundation, UserNotifications
- `OakAppKit` -> Carbon, Cocoa, AudioToolbox, Quartz
- `OakDebug` -> Cocoa, ExceptionHandling
- `QuickLookGenerator` -> CoreFoundation, QuickLook, AppKit, OSAKit
- `document` -> ApplicationServices
- `mate` -> ApplicationServices, Security

Each framework CMakeLists.txt needs to declare its own system framework dependencies. The spec only shows the pattern for the main TextMate app.

### 2.4 No Equivalent for the `run` Target

The rave system generates `TextMate/run` targets that build, sign, and launch the app (with relaunch logic including dialog prompts). The spec's "Build and run" equivalent is `ninja -C build TextMate && open build/TextMate.app`, which is a manual two-step command that lacks:

- Automatic kill/relaunch of running instance
- Code signing before launch
- Integration as a build target

This is a developer experience regression.

### 2.5 LTO Cache Path Dropped

The rave release config includes `-Wl,-cache_path_lto,'${builddir}/.cache'` which directs the LTO cache to the build directory. The spec's release flags omit this. Without it, the LTO cache goes to a system-wide default location, which can cause stale cache issues across builds or bloat the system cache.

### 2.6 Debug Config Requires OakDebug Framework

The rave debug config has `require OakDebug`, which adds the OakDebug framework (exception handling, debug utilities) to all targets built in debug mode. The spec does not address this conditional dependency. In CMake, this could be handled with a generator expression or an `if(CMAKE_BUILD_TYPE STREQUAL "Debug")` block, but it needs to be mentioned.

### 2.7 `expand_variables` Script Is Also Ruby

The spec's motivation section highlights removing the Ruby dependency. However, `bin/expand_variables` is a Ruby script (used for Info.plist processing), and `bin/gen_html` is also Ruby. Simply replacing `bin/rave` with CMake does not eliminate the Ruby dependency. The spec lists `bin/expand_variables` as replaced by `configure_file()` in the removal table, but `configure_file()` uses CMake variable syntax (`@VAR@` or `${VAR}`), not the `${VAR}` plist syntax that `expand_variables` handles. This requires either:

1. Converting all Info.plist files to use CMake's `@VAR@` syntax, or
2. Writing a non-Ruby replacement for `expand_variables`

### 2.8 `gen_html` Script Is Also Ruby

`bin/gen_html` converts Markdown to HTML with ERB templates, custom text transforms (key equivalent formatting, author credits), and multimarkdown integration. This is used for the About window content. If the goal is truly "no Ruby dependency," this script also needs replacement. The spec does not mention it.

### 2.9 DefaultBundles.tbz.bl Archive Pipeline Missing

`Applications/TextMate/resources/DefaultBundles.tbz.bl` is a manifest file that triggers the `CreateBundlesArchive` compiler transform in rave. This transform:
1. Uses the `bl` tool (built as part of the project) to download/install bundles listed in the manifest
2. Creates a `.tbz` archive of the downloaded bundles
3. Bundles the archive into the app's Resources

This is a self-referential build dependency (the `bl` application must be built first, then used during the TextMate build). The spec does not address this pipeline.

---

## 3. Correctness Issues

### 3.1 GLOB_RECURSE Is Fragile and Discouraged

The spec uses `file(GLOB_RECURSE SOURCES src/*.cc src/*.mm)` extensively. CMake's own documentation warns against this:

> We do not recommend using GLOB to collect a list of source files from your source tree. If no CMakeLists.txt file changes when a source is added or removed then the generated build system cannot know when to ask CMake to regenerate.

For a project with 45 frameworks, this means adding or removing a source file will not trigger a rebuild until someone manually re-runs `cmake`. The rave system handles this via its dependency-tracking glob system that regenerates the build file when the glob results change.

Given the project's stability (this is a mature codebase, not one with rapidly changing file lists), this is a tolerable tradeoff, but it should be called out explicitly as a known limitation with instructions for developers (e.g., "run `cmake --build build --target rebuild_cache` after adding files").

### 3.2 ObjC Flags Approach Will Not Work Correctly

The spec sets:
```cmake
set(CMAKE_OBJC_FLAGS "${CMAKE_OBJC_FLAGS} -fobjc-abi-version=3 -fobjc-arc")
set(CMAKE_OBJCXX_FLAGS "${CMAKE_OBJCXX_FLAGS} -fobjc-abi-version=3 -fobjc-arc -fobjc-call-cxx-cdtors")
```

There are two problems:

1. **CMake language support for OBJC/OBJCXX was added in 3.16 but is fragile with mixed-language targets.** When a target has both `.cc` and `.mm` files, CMake may not correctly distinguish which flags apply to which files if source file language properties are not set explicitly. The `LANGUAGE` source file property may need to be set on `.mm` files.

2. **The `add_compile_options()` block applies flags to ALL languages**, including OBJC and OBJCXX. This means flags like `-Wall` are applied correctly, but if any C/C++-specific flags are added later, they will also hit ObjC/ObjCXX files unless guarded with generator expressions like `$<$<COMPILE_LANGUAGE:CXX>:...>`.

### 3.3 Test Pattern Assumes One-Test-Per-File; Misses CxxTest

The spec's test pattern creates one executable per test file:
```cmake
foreach(test_src ${TEST_SOURCES})
    add_executable(${test_name} ${test_src})
```

The existing tests use CxxTest (`bin/CxxTest`), which is a test framework that requires a specific runner generation step. The spec does not mention CxxTest at all. If the tests use CxxTest macros (`TS_ASSERT`, test suite classes), they cannot be compiled as standalone executables without the CxxTest header generator.

Additionally, the `cxx_tests` rave command (used for GUI tests like `gui_*.mm`) is distinct from `tests` and is not addressed.

### 3.4 Ragel Output Filename Logic Has an Edge Case

The rave system handles `.mm.rl` -> `.mm` and `.cc.rl` -> `.cc` as distinct transforms. The spec's regex:
```cmake
string(REGEX REPLACE "\\.rl$" "" out_name "${name}")
if(NOT out_name MATCHES "\\.(cc|mm)$")
    set(out_name "${out_name}.cc")
endif()
```

This correctly handles `foo.mm.rl` -> `foo.mm` and `foo.rl` -> `foo.cc`, which matches the rave behavior. This part is sound.

However, the `target_include_directories(${TARGET} PRIVATE ${dir})` line uses `${dir}` from `get_filename_component(dir ${rl_file} DIRECTORY)` which is a relative path from the source's perspective. If `rl_file` is just a filename with no directory component, `${dir}` will be empty, and `target_include_directories` with an empty path is an error.

### 3.5 Asset Catalog DEPENDS Is on a Directory

```cmake
DEPENDS ${XCASSETS_DIR}
```

This depends on the directory itself, not its contents. If you modify an image inside the `.xcassets` directory, the modification time of the directory does not change and the asset catalog will not be rebuilt. The rave system handles this by expanding the directory contents: `Dir.glob("#{file}/**/*")`. The CMake function needs a `file(GLOB_RECURSE ...)` to collect all files inside the xcassets directory as dependencies, or use a stamp file approach.

### 3.6 UTF-16 Conversion Is Lossy vs. Rave

The rave system's `ConvertToUTF16` checks if the input is already UTF-16 (by checking the BOM) and copies it directly if so. The spec's CMake function unconditionally runs `iconv -f UTF-8 -t UTF-16`, which will corrupt files that are already UTF-16 encoded.

### 3.7 The `fobjc-link-runtime` Linker Flag Is Missing

`default.rave` sets `LN_FLAGS` with `-fobjc-link-runtime`, which ensures the ObjC runtime is linked. The spec's root CMakeLists.txt does not include this flag. CMake typically handles this implicitly when OBJC/OBJCXX languages are enabled, but it should be verified rather than assumed.

### 3.8 Missing `-Os` in Debug Config

The rave debug config includes `add FLAGS "-Os"` (optimize for size even in debug). The spec's debug config only adds ASan flags. This is a behavioral difference -- the rave debug builds are optimized, while the spec's debug builds would use CMake's default debug flags (`-g` with no optimization).

---

## 4. Risks

### 4.1 Cap'n Proto Removal via NSKeyedArchiver Crosses Language Boundaries

The plist framework's current Cap'n Proto usage is in C++ code (`src/*.cc` and `src/*.rl`). The proposed replacement (`NSKeyedArchiver`/`NSKeyedUnarchiver`) is an Objective-C API. This means either:

1. The C++ cache code must be rewritten in ObjC++ (`.mm`), or
2. An ObjC++ wrapper must be created to bridge between the C++ interface and NSKeyedArchiver

Both approaches require touching the plist framework's architecture, not just swapping serialization calls. The spec presents this as a simple replacement ("Replace capnp read/write calls with NSKeyedArchiver equivalents") without acknowledging the language boundary.

For the encoding framework's `frequencies.capnp`, the "compiled-in C++ data" approach is straightforward and low-risk.

### 4.2 No Incremental Migration Path

The spec proposes replacing the entire build system in one step. With 45 frameworks, 11 applications, and complex inter-dependencies, this is high-risk. A single misconfigured framework CMakeLists.txt will block the entire build.

A safer approach would be to define a migration order: start with leaf frameworks (no dependencies, e.g., `crash`, `text`, `OakDebug`), verify they compile, then work up the dependency tree. The spec should include a migration order or at least acknowledge that the 58+ CMakeLists.txt files cannot all be written and validated simultaneously.

### 4.3 CMake Minimum Version 3.20 vs. ObjC/ObjCXX Support Maturity

CMake's ObjC and ObjCXX language support has historically been rough. While basic compilation works, features like per-language PCH, proper flag separation, and `.mm` file detection have had bugs across versions. CMake 3.20 (released 2021) is reasonable, but testing against the latest CMake (3.29+) would be prudent. The spec should note the minimum tested version and any known CMake bugs with ObjC++.

---

## 5. Improvement Opportunities

### 5.1 Use Object Libraries for Shared Code

Rather than static libraries, consider `OBJECT` libraries for internal frameworks that are never used outside the project. Object libraries avoid the intermediate `.a` archive step and can be slightly faster to link. This is a minor optimization but aligns with CMake best practices for internal-only libraries.

### 5.2 Deployment Target Is Outdated

The spec carries forward `CMAKE_OSX_DEPLOYMENT_TARGET "10.12"` from the rave config. macOS 10.12 (Sierra, 2016) is long past end-of-life. If this migration is the right moment to modernize, bumping to at least 10.15 (Catalina) or 11.0 (Big Sur) would allow using newer APIs and dropping compatibility workarounds. This is an editorial note, not a build system concern.

### 5.3 Consider FetchContent for Boost/sparsehash

Since both Boost and google-sparsehash are headers-only, CMake's `FetchContent` could download them automatically, eliminating the need for developers to install them via Homebrew. This would further reduce external dependency friction, which is one of the spec's stated goals.

---

## Summary

The spec captures the high-level architecture of a CMake migration correctly and the motivation is sound. However, it has significant gaps in completeness that would block implementation:

- Three of seven compiler transforms are missing (Markdown, variable expansion, bundle archive)
- Two non-standard bundle types are not addressed (QuickLook generator, XPC service)
- The PCH strategy needs a concrete plan, not a hand-wave
- The header export mechanism (`headers` directive) is incorrectly mapped
- The Ruby dependency is not actually eliminated (two Ruby scripts remain)
- Code signing entitlements and several per-target flags are missing

The Cap'n Proto removal is feasible but the plist cache replacement crosses a C++/ObjC boundary that the spec does not acknowledge.

Before implementation begins, the spec needs a second pass to catalog every rave file's directives exhaustively and confirm each has a CMake equivalent. A spreadsheet mapping each of the 63 rave files to their CMake translation would be more reliable than the pattern-based approach currently described.
