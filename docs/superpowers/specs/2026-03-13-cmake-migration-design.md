# TextMate Build System Migration: rave → CMake

**Date:** 2026-03-13
**Status:** Proposed (rev 2 — addresses architecture review)

## Summary

Replace TextMate's custom Ruby-based build system (`bin/rave` + `.rave` DSL) with CMake. Additionally, drop the Cap'n Proto dependency by replacing its two uses with native alternatives. Replace the two remaining Ruby scripts (`bin/expand_variables`, `bin/gen_html`) with CMake-native equivalents to fully eliminate the Ruby dependency.

## Motivation

The current build system has real friction:
- **Ruby dependency** — `bin/rave` (1,579 lines), `bin/expand_variables`, and `bin/gen_html` are all Ruby; Ruby no longer ships with Xcode/macOS
- **Broken on ARM Macs** — `configure` hardcodes `/usr/local` paths; Homebrew uses `/opt/homebrew` on Apple Silicon
- **Custom undocumented DSL** — the `.rave` format is understood only by reading `bin/rave` source
- **No IDE integration** — no LSP, no Xcode project, no CLion support
- **No CI/CD** — GitHub Actions workflow was removed from this fork
- **Cap'n Proto** — heavy dependency for two simple serialization use cases

## Architecture

### Project Structure

```
CMakeLists.txt                        # Root: project config, global flags, subdirectories
cmake/
  TextMateHelpers.cmake               # Custom functions: ragel, xib, assets, plist, codesign, markdown
  CMakePresets.json                    # Build presets (debug/release, signing identity)
Frameworks/<name>/CMakeLists.txt      # ~45 files, one per framework
Applications/<name>/CMakeLists.txt    # ~11 files, one per app/tool/service
vendor/<name>/CMakeLists.txt          # Onigmo + kvdb
PlugIns/<name>/CMakeLists.txt         # Dialog plugins
```

### Root CMakeLists.txt

Responsibilities (replaces `default.rave` + `configure` + `bin/rave`):

```cmake
cmake_minimum_required(VERSION 3.21)
project(TextMate LANGUAGES C CXX OBJC OBJCXX)

# Global settings (from default.rave)
set(CMAKE_OSX_DEPLOYMENT_TARGET "10.12")
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_C_STANDARD 99)
set(CMAKE_VISIBILITY_INLINES_HIDDEN ON)
set(CMAKE_CXX_VISIBILITY_PRESET hidden)

# ObjC flags — applied via generator expressions to avoid leaking to C/C++
add_compile_options(
  $<$<COMPILE_LANGUAGE:OBJC>:-fobjc-abi-version=3 -fobjc-arc>
  $<$<COMPILE_LANGUAGE:OBJCXX>:-fobjc-abi-version=3 -fobjc-arc -fobjc-call-cxx-cdtors>
)

# Common flags (all languages)
add_compile_options(
  -funsigned-char -Wall -Wwrite-strings -Wformat -Winit-self
  -Wmissing-include-dirs -Wno-parentheses -Wno-sign-compare
  -Wno-switch -Wno-c99-designator
)
add_compile_definitions(
  NULL_STR="\uFFFF"
  REST_API="https://api.textmate.org"
)

# Debug config: -Os + ASan (rave uses -Os even in debug)
set(CMAKE_C_FLAGS_DEBUG "-Os -g -fsanitize=address -fno-omit-frame-pointer")
set(CMAKE_CXX_FLAGS_DEBUG "-Os -g -fsanitize=address -fno-omit-frame-pointer")
set(CMAKE_OBJC_FLAGS_DEBUG "-Os -g -fsanitize=address -fno-omit-frame-pointer")
set(CMAKE_OBJCXX_FLAGS_DEBUG "-Os -g -fsanitize=address -fno-omit-frame-pointer")
set(CMAKE_EXE_LINKER_FLAGS_DEBUG "-fsanitize=address")

# Release config: LTO + dead stripping + LTO cache
set(CMAKE_C_FLAGS_RELEASE "-Os -DNDEBUG -flto=thin")
set(CMAKE_CXX_FLAGS_RELEASE "-Os -DNDEBUG -flto=thin")
set(CMAKE_OBJC_FLAGS_RELEASE "-Os -DNDEBUG -flto=thin")
set(CMAKE_OBJCXX_FLAGS_RELEASE "-Os -DNDEBUG -flto=thin")
set(CMAKE_EXE_LINKER_FLAGS_RELEASE "-flto=thin -Wl,-dead_strip -Wl,-dead_strip_dylibs -Wl,-cache_path_lto,${CMAKE_BINARY_DIR}/.lto-cache")

# Linker: ObjC runtime linking
add_link_options(-fobjc-link-runtime)

# Dependencies (replaces configure's manual path checks)
find_package(Boost REQUIRED)
find_program(RAGEL_EXECUTABLE ragel REQUIRED)
find_program(MULTIMARKDOWN multimarkdown REQUIRED)

# Version extraction (replaces rave `capture` command)
file(STRINGS "${CMAKE_SOURCE_DIR}/Applications/TextMate/about/Changes.md"
  TEXTMATE_VERSION REGEX "^## [0-9]" LIMIT_COUNT 1)
string(REGEX MATCH "[0-9]+\\.[0-9]+(\\.[0-9]+)?" TEXTMATE_VERSION "${TEXTMATE_VERSION}")

# Shared include path
include_directories(Shared/include)

# Custom build helpers
include(cmake/TextMateHelpers.cmake)

# Code signing identity (overridable: -DCS_IDENTITY="Developer ID Application: ...")
set(CS_IDENTITY "-" CACHE STRING "Code signing identity (- for ad-hoc)")

# Conditional OakDebug in debug builds (rave: `require OakDebug` in debug config)
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
  set(TEXTMATE_DEBUG_LIBS OakDebug)
endif()

# Subdirectories — order doesn't matter, CMake resolves deps
# Vendors
add_subdirectory(vendor/Onigmo)
add_subdirectory(vendor/kvdb)
# Frameworks (all ~45)
add_subdirectory(Frameworks/text)
add_subdirectory(Frameworks/buffer)
# ... etc
# Applications (all ~11)
add_subdirectory(Applications/TextMate)
# ... etc
# Plugins
add_subdirectory(PlugIns/Dialog)
add_subdirectory(PlugIns/Dialog2)
```

**Changes from rev 1:**
- Bumped CMake minimum to 3.21 (better ObjC++ support)
- ObjC flags use generator expressions to avoid leaking to C/C++ files
- Debug config includes `-Os` to match rave behavior
- Added `-fobjc-link-runtime` linker flag
- Added LTO cache path in release linker flags
- Added `TEXTMATE_VERSION` extraction via `file(STRINGS ...)` (replaces rave `capture`)
- Added conditional `OakDebug` dependency for debug builds
- Added `find_program(MULTIMARKDOWN ...)` for markdown compilation

### Custom Build Functions (cmake/TextMateHelpers.cmake)

Nine functions replacing `bin/rave`'s compiler classes AND the two Ruby helper scripts:

#### 1. Ragel (.rl → .cc/.mm)
```cmake
function(target_ragel_sources TARGET)
  foreach(rl_file ${ARGN})
    get_filename_component(name ${rl_file} NAME)
    string(REGEX REPLACE "\\.rl$" "" out_name "${name}")
    if(NOT out_name MATCHES "\\.(cc|mm)$")
      set(out_name "${out_name}.cc")
    endif()
    set(out_file "${CMAKE_CURRENT_BINARY_DIR}/${out_name}")
    add_custom_command(
      OUTPUT ${out_file}
      COMMAND ${RAGEL_EXECUTABLE} -o ${out_file} ${CMAKE_CURRENT_SOURCE_DIR}/${rl_file}
      DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/${rl_file}
      COMMENT "Ragel: ${rl_file}")
    target_sources(${TARGET} PRIVATE ${out_file})
    # Ragel output may reference sibling headers
    target_include_directories(${TARGET} PRIVATE
      ${CMAKE_CURRENT_SOURCE_DIR}/$<PATH:GET_PARENT_PATH,${rl_file}>)
  endforeach()
endfunction()
```

#### 2. Xib compilation (.xib → .nib)
```cmake
function(target_xib_sources TARGET RESOURCE_LOCATION)
  foreach(xib ${ARGN})
    get_filename_component(name ${xib} NAME_WE)
    set(nib "${CMAKE_CURRENT_BINARY_DIR}/${name}.nib")
    add_custom_command(
      OUTPUT ${nib}
      COMMAND xcrun ibtool --compile ${nib}
        --errors --warnings --notices
        --output-format human-readable-text
        ${CMAKE_CURRENT_SOURCE_DIR}/${xib}
      DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/${xib}
      COMMENT "Xib: ${xib}")
    target_sources(${TARGET} PRIVATE ${nib})
    set_source_files_properties(${nib} PROPERTIES
      MACOSX_PACKAGE_LOCATION "Resources/${RESOURCE_LOCATION}")
  endforeach()
endfunction()
```

#### 3. Asset catalog (.xcassets → .car)
```cmake
function(target_asset_catalog TARGET XCASSETS_DIR)
  # Collect all files inside .xcassets for proper rebuild tracking
  file(GLOB_RECURSE XCASSET_FILES "${CMAKE_CURRENT_SOURCE_DIR}/${XCASSETS_DIR}/*")
  set(car "${CMAKE_CURRENT_BINARY_DIR}/Assets.car")
  add_custom_command(
    OUTPUT ${car}
    COMMAND xcrun actool --compile ${CMAKE_CURRENT_BINARY_DIR}
      --errors --warnings --notices
      --output-format human-readable-text
      --minimum-deployment-target=${CMAKE_OSX_DEPLOYMENT_TARGET}
      --platform=macosx
      ${CMAKE_CURRENT_SOURCE_DIR}/${XCASSETS_DIR}
    DEPENDS ${XCASSET_FILES}
    COMMENT "AssetCatalog: ${XCASSETS_DIR}")
  target_sources(${TARGET} PRIVATE ${car})
  set_source_files_properties(${car} PROPERTIES
    MACOSX_PACKAGE_LOCATION Resources)
endfunction()
```

#### 4. UTF-16 string conversion (with BOM detection)
```cmake
function(target_utf16_strings TARGET RESOURCE_LOCATION)
  foreach(strings_file ${ARGN})
    get_filename_component(name ${strings_file} NAME)
    set(in_file "${CMAKE_CURRENT_SOURCE_DIR}/${strings_file}")
    set(out "${CMAKE_CURRENT_BINARY_DIR}/${name}")
    # Check BOM: copy if already UTF-16, convert if UTF-8
    add_custom_command(
      OUTPUT ${out}
      COMMAND sh -c "if head -c2 '${in_file}' | xxd -p | grep -q '^fffe\\|^feff'; then cp '${in_file}' '${out}'; else iconv -f UTF-8 -t UTF-16 '${in_file}' > '${out}'; fi"
      DEPENDS ${in_file}
      COMMENT "UTF-16: ${strings_file}")
    target_sources(${TARGET} PRIVATE ${out})
    set_source_files_properties(${out} PROPERTIES
      MACOSX_PACKAGE_LOCATION "Resources/${RESOURCE_LOCATION}")
  endforeach()
endfunction()
```

#### 5. Plist variable expansion (replaces bin/expand_variables Ruby script)
```cmake
function(textmate_expand_plist TARGET INPUT OUTPUT)
  # Uses CMake configure_file with @ONLY mode
  # Plist templates must use @VAR@ syntax (migration step: sed s/\${VAR}/@VAR@/g)
  set(YEAR "${CURRENT_YEAR}")
  string(TIMESTAMP CURRENT_YEAR "%Y")
  configure_file(${INPUT} ${OUTPUT} @ONLY)
  set_source_files_properties(${OUTPUT} PROPERTIES
    MACOSX_PACKAGE_LOCATION ".")
endfunction()
```

Note: Info.plist files must be converted from `${VAR}` to `@VAR@` syntax during migration. Per-config variables like `CS_GET_TASK_ALLOW` use generator expressions:
```cmake
set(CS_GET_TASK_ALLOW $<IF:$<CONFIG:Debug>,true,false>)
```

#### 6. Markdown compilation (replaces bin/gen_html Ruby script)
```cmake
function(target_markdown_sources TARGET RESOURCE_LOCATION)
  foreach(md_file ${ARGN})
    get_filename_component(name ${md_file} NAME_WE)
    set(html "${CMAKE_CURRENT_BINARY_DIR}/${name}.html")
    set(in_file "${CMAKE_CURRENT_SOURCE_DIR}/${md_file}")
    add_custom_command(
      OUTPUT ${html}
      COMMAND ${MULTIMARKDOWN} ${in_file} -o ${html}
      DEPENDS ${in_file}
      COMMENT "Markdown: ${md_file}")
    target_sources(${TARGET} PRIVATE ${html})
    set_source_files_properties(${html} PROPERTIES
      MACOSX_PACKAGE_LOCATION "Resources/${RESOURCE_LOCATION}")
  endforeach()
endfunction()
```

Note: The original `bin/gen_html` wraps multimarkdown output with HTML header/footer templates and applies text transforms (key equivalent formatting). The CMake version starts simple (raw multimarkdown). If the header/footer wrapping is needed, a small shell script or Python script replaces the Ruby ERB template logic.

#### 7. Code signing (with entitlements support)
```cmake
function(textmate_codesign TARGET IDENTITY)
  cmake_parse_arguments(CS "" "ENTITLEMENTS" "" ${ARGN})
  set(FLAGS --force --options runtime)
  if(CMAKE_BUILD_TYPE STREQUAL "Release")
    list(APPEND FLAGS --timestamp)
  else()
    list(APPEND FLAGS --timestamp=none)
  endif()
  if(CS_ENTITLEMENTS)
    list(APPEND FLAGS --entitlements "${CS_ENTITLEMENTS}")
  endif()
  add_custom_command(TARGET ${TARGET} POST_BUILD
    COMMAND xcrun codesign --sign "${IDENTITY}" ${FLAGS}
      "$<TARGET_BUNDLE_DIR:${TARGET}>"
    COMMENT "Codesign: ${TARGET}")
endfunction()
```

Usage with entitlements:
```cmake
# Expand entitlements plist (config-aware)
configure_file(Entitlements.plist.in
  ${CMAKE_CURRENT_BINARY_DIR}/Entitlements.plist @ONLY)
textmate_codesign(TextMate "${CS_IDENTITY}"
  ENTITLEMENTS ${CMAKE_CURRENT_BINARY_DIR}/Entitlements.plist)
```

#### 8. Embed tool/plugin in app bundle
```cmake
function(textmate_embed_tool APP_TARGET TOOL_TARGET LOCATION)
  add_dependencies(${APP_TARGET} ${TOOL_TARGET})
  add_custom_command(TARGET ${APP_TARGET} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy
      "$<TARGET_FILE:${TOOL_TARGET}>"
      "$<TARGET_BUNDLE_DIR:${APP_TARGET}>/Contents/${LOCATION}/$<TARGET_FILE_NAME:${TOOL_TARGET}>")
endfunction()

function(textmate_embed_plugin APP_TARGET PLUGIN_TARGET LOCATION)
  add_dependencies(${APP_TARGET} ${PLUGIN_TARGET})
  add_custom_command(TARGET ${APP_TARGET} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_directory
      "$<TARGET_BUNDLE_DIR:${PLUGIN_TARGET}>"
      "$<TARGET_BUNDLE_DIR:${APP_TARGET}>/Contents/${LOCATION}/$<TARGET_FILE_NAME:${PLUGIN_TARGET}>.bundle")
endfunction()
```

#### 9. Run target (developer convenience)
```cmake
function(textmate_add_run_target TARGET)
  add_custom_target(${TARGET}_run
    COMMAND ${CMAKE_COMMAND} -E env
      osascript -e "tell application \"TextMate\" to quit" 2>/dev/null || true
    COMMAND open "$<TARGET_BUNDLE_DIR:${TARGET}>"
    DEPENDS ${TARGET}
    COMMENT "Running ${TARGET}")
endfunction()
```

### Header Export Mechanism

**Critical detail:** The rave system exports headers into `_Include/<framework>/<framework>/header.h`, enabling `#include <buffer/buffer.h>` across frameworks.

The CMake equivalent uses a wrapper include directory. Each framework's `src/` directory must be exposed such that the existing `#include <buffer/buffer.h>` paths work. Two approaches:

**Option A: Symlink tree (matches rave exactly)**
```cmake
function(textmate_framework TARGET)
  # Create include/<target>/ symlink pointing to src/
  file(CREATE_LINK
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    ${CMAKE_CURRENT_BINARY_DIR}/include/${TARGET}
    SYMBOLIC)
  target_include_directories(${TARGET} PUBLIC ${CMAKE_CURRENT_BINARY_DIR}/include)
endfunction()
```
This makes `#include <buffer/buffer.h>` resolve to `build/include/buffer/` → `Frameworks/buffer/src/buffer.h`.

**Option B: Directory structure convention**
If sources are already at `src/<framework>/header.h` (e.g., `Frameworks/buffer/src/buffer/buffer.h`), then `target_include_directories(buffer PUBLIC src)` works directly.

Need to verify which structure the source tree uses. If it's flat (`src/buffer.h`), Option A is required.

### Framework Pattern

Each framework is a static library (or OBJECT library for internal-only code).

**Simple framework (buffer):**
```cmake
add_library(buffer STATIC)
file(GLOB SOURCES src/*.cc src/*.mm src/*.c src/*.m)
target_sources(buffer PRIVATE ${SOURCES})
textmate_framework(buffer)  # sets up include path
target_link_libraries(buffer PUBLIC bundles io ns parse regexp scope text)
target_link_libraries(buffer PUBLIC ${TEXTMATE_DEBUG_LIBS})
```

**Framework with Ragel (plist):**
```cmake
add_library(plist STATIC)
file(GLOB SOURCES src/*.cc src/*.mm)
target_sources(plist PRIVATE ${SOURCES})
textmate_framework(plist)
target_link_libraries(plist PUBLIC text cf io)
target_ragel_sources(plist src/ascii.rl)
```

**Framework with system libraries (OakAppKit):**
```cmake
add_library(OakAppKit STATIC)
file(GLOB SOURCES src/*.cc src/*.mm)
target_sources(OakAppKit PRIVATE ${SOURCES})
textmate_framework(OakAppKit)
target_link_libraries(OakAppKit PUBLIC
  OakFoundation bundles crash file io ns parse regexp settings text theme)
target_link_libraries(OakAppKit PRIVATE
  "-framework Cocoa" "-framework Carbon" "-framework AudioToolbox" "-framework Quartz"
  sqlite3)
```

**Framework with header-only dependency (require_headers):**
```cmake
# require_headers → include dirs only, no linking
target_include_directories(Preferences PRIVATE
  $<TARGET_PROPERTY:OakDebug,INTERFACE_INCLUDE_DIRECTORIES>)
```

**Note on GLOB vs explicit file lists:** `file(GLOB ...)` is used for pragmatism (this is a mature codebase with infrequent file additions). Developers must re-run `cmake -B build` after adding/removing source files. This is documented in the build commands section.

### Application Target Types

#### Standard app bundle (TextMate, NewApplication)
```cmake
add_executable(TextMate MACOSX_BUNDLE)
```

#### CLI tool (mate, bl, gtm, indent, tm_query, pretty_plist)
```cmake
add_executable(mate)
# No MACOSX_BUNDLE — produces flat binary
```

#### QuickLook generator (TextMateQL)
```cmake
add_library(TextMateQL MODULE)
set_target_properties(TextMateQL PROPERTIES
  BUNDLE TRUE
  BUNDLE_EXTENSION "qlgenerator"
  MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/Info.plist"
)
target_link_options(TextMateQL PRIVATE -bundle)
target_link_libraries(TextMateQL PRIVATE
  "-framework CoreFoundation" "-framework QuickLook"
  "-framework AppKit" "-framework OSAKit")
```
Embedded at `TextMate.app/Contents/Library/QuickLook/`.

#### XPC service (SyntaxMate)
```cmake
add_executable(SyntaxMate)
set_target_properties(SyntaxMate PROPERTIES
  MACOSX_BUNDLE TRUE
  MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/Info.plist"
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/SyntaxMate.xpc/Contents/MacOS"
)
```
Embedded at `TextMate.app/Contents/XPCServices/`.

### TextMate Main App (complete)

```cmake
add_executable(TextMate MACOSX_BUNDLE)
file(GLOB SOURCES src/*.cc src/*.mm)
target_sources(TextMate PRIVATE ${SOURCES})

# Internal framework dependencies (30+)
target_link_libraries(TextMate PRIVATE
  DocumentWindow BundleEditor BundleMenu BundlesManager CommitWindow
  CrashReporter Find HTMLOutputWindow MenuBuilder OakAppKit OakCommand
  OakFilterList OakFoundation OakSystem OakTextView Preferences
  SoftwareUpdate authorization bundles cf command crash document io
  kvdb license network ns plist regexp scm settings text theme
  ${TEXTMATE_DEBUG_LIBS}
)

# System frameworks
target_link_libraries(TextMate PRIVATE
  "-framework Cocoa" "-framework Carbon" "-framework AppKit"
  "-framework WebKit" "-framework Security"
)

# Info.plist with variable expansion
set(TARGET_NAME "TextMate")
set(APP_MIN_OS "${CMAKE_OSX_DEPLOYMENT_TARGET}")
set(APP_VERSION "${TEXTMATE_VERSION}")
string(TIMESTAMP YEAR "%Y")
set(CS_GET_TASK_ALLOW $<IF:$<CONFIG:Debug>,true,false>)
configure_file(Info.plist.in ${CMAKE_CURRENT_BINARY_DIR}/Info.plist @ONLY)
set_target_properties(TextMate PROPERTIES
  MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_BINARY_DIR}/Info.plist")

# Resources
file(GLOB RESOURCES resources/*.icns resources/*.png)
target_sources(TextMate PRIVATE ${RESOURCES})
set_source_files_properties(${RESOURCES} PROPERTIES
  MACOSX_PACKAGE_LOCATION Resources)

# Xib, assets
target_xib_sources(TextMate "English.lproj" resources/MainMenu.xib)
target_asset_catalog(TextMate resources/Assets.xcassets)

# Markdown → HTML for About window
target_markdown_sources(TextMate "About"
  about/About.md about/Changes.md about/Contributions.md
  about/Legal.md about/Registration.md)

# Embedded tools
textmate_embed_tool(TextMate mate "SharedSupport/bin")
textmate_embed_tool(TextMate commit "SharedSupport/bin")

# Embedded plugins
textmate_embed_plugin(TextMate Dialog "PlugIns")
textmate_embed_plugin(TextMate Dialog2 "PlugIns")

# QuickLook generator (non-standard bundle location)
add_dependencies(TextMate TextMateQL)
add_custom_command(TARGET TextMate POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_directory
    "${CMAKE_BINARY_DIR}/TextMateQL.qlgenerator"
    "$<TARGET_BUNDLE_DIR:TextMate>/Contents/Library/QuickLook/TextMateQL.qlgenerator")

# XPC service
add_dependencies(TextMate SyntaxMate)
add_custom_command(TARGET TextMate POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_directory
    "${CMAKE_BINARY_DIR}/SyntaxMate.xpc"
    "$<TARGET_BUNDLE_DIR:TextMate>/Contents/XPCServices/SyntaxMate.xpc")

# Entitlements + code signing
configure_file(Entitlements.plist.in
  ${CMAKE_CURRENT_BINARY_DIR}/Entitlements.plist @ONLY)
textmate_codesign(TextMate "${CS_IDENTITY}"
  ENTITLEMENTS ${CMAKE_CURRENT_BINARY_DIR}/Entitlements.plist)

# Developer convenience: build + run
textmate_add_run_target(TextMate)
```

### DefaultBundles Archive Pipeline

The rave system uses `CreateBundlesArchive` which builds the `bl` tool, then uses it to download bundles from a manifest. In CMake:

```cmake
# bl must be built first
add_executable(bl ...)

# Custom command: use bl to download bundles, then tar them
add_custom_command(
  OUTPUT ${CMAKE_BINARY_DIR}/DefaultBundles.tbz
  COMMAND $<TARGET_FILE:bl> --install ${CMAKE_CURRENT_SOURCE_DIR}/resources/DefaultBundles.tbz.bl
    --directory ${CMAKE_BINARY_DIR}/_bundles
  COMMAND tar -cjf ${CMAKE_BINARY_DIR}/DefaultBundles.tbz
    -C ${CMAKE_BINARY_DIR}/_bundles .
  DEPENDS bl ${CMAKE_CURRENT_SOURCE_DIR}/resources/DefaultBundles.tbz.bl
  COMMENT "Creating DefaultBundles archive")

add_custom_target(DefaultBundles DEPENDS ${CMAKE_BINARY_DIR}/DefaultBundles.tbz)
add_dependencies(TextMate DefaultBundles)

# Copy into app bundle
set_source_files_properties(${CMAKE_BINARY_DIR}/DefaultBundles.tbz PROPERTIES
  MACOSX_PACKAGE_LOCATION "Resources")
```

### Testing with CxxTest

The existing tests use CxxTest (`bin/CxxTest`), not standalone executables. The test pattern must account for this:

```cmake
function(textmate_add_tests FRAMEWORK_TARGET)
  file(GLOB TEST_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/tests/t_*.cc
                          ${CMAKE_CURRENT_SOURCE_DIR}/tests/t_*.mm)
  if(NOT TEST_SOURCES)
    return()
  endif()

  set(test_target ${FRAMEWORK_TARGET}_test)
  # CxxTest generates a runner from test headers
  add_custom_command(
    OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/test_runner.cc
    COMMAND ${CMAKE_SOURCE_DIR}/bin/CxxTest/bin/cxxtestgen --error-printer
      -o ${CMAKE_CURRENT_BINARY_DIR}/test_runner.cc
      ${TEST_SOURCES}
    DEPENDS ${TEST_SOURCES}
    COMMENT "CxxTest: generating runner for ${FRAMEWORK_TARGET}")

  add_executable(${test_target}
    ${CMAKE_CURRENT_BINARY_DIR}/test_runner.cc
    ${TEST_SOURCES})
  target_link_libraries(${test_target} PRIVATE ${FRAMEWORK_TARGET})
  target_include_directories(${test_target} PRIVATE
    ${CMAKE_SOURCE_DIR}/bin/CxxTest)
  add_test(NAME ${FRAMEWORK_TARGET} COMMAND ${test_target})
endfunction()

# GUI tests (cxx_tests) — ObjC++ tests needing AppKit
function(textmate_add_gui_tests FRAMEWORK_TARGET)
  file(GLOB GUI_TEST_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/tests/gui_*.mm)
  if(NOT GUI_TEST_SOURCES)
    return()
  endif()
  # Same pattern as above but links AppKit
  set(test_target ${FRAMEWORK_TARGET}_gui_test)
  add_executable(${test_target} ${GUI_TEST_SOURCES})
  target_link_libraries(${test_target} PRIVATE ${FRAMEWORK_TARGET} "-framework AppKit")
  add_test(NAME ${FRAMEWORK_TARGET}_gui COMMAND ${test_target})
endfunction()
```

### PCH Strategy (Concrete Plan)

The current layered PCH system cannot map 1:1 to CMake's per-target PCH. Here is the concrete plan:

**Phase 1: Build without PCH.** Get the entire project compiling with CMake and no precompiled headers. This is the correct first milestone — PCH is a compilation speed optimization, not a correctness requirement. All headers included by the preludes are already `#include`d (or should be) in individual source files.

**Phase 2: Add PCH per language group.** Create separate interface targets:

```cmake
# C/C++ PCH (prelude.c + prelude.cc content)
add_library(pch_cxx INTERFACE)
target_precompile_headers(pch_cxx INTERFACE
  <cstdlib> <cstring> <cmath>      # from prelude.c
  <string> <vector> <map>           # from prelude.cc
  <boost/variant.hpp>               # from prelude.cc
)

# ObjC++ PCH (everything)
add_library(pch_objcxx INTERFACE)
target_precompile_headers(pch_objcxx INTERFACE
  <cstdlib> <cstring>              # C
  <string> <vector> <map>          # C++
  <boost/variant.hpp>              # Boost
  # ObjC frameworks via __OBJC__ guard won't work in PCH
  # so ObjC-heavy frameworks get their own PCH target
)
```

**Phase 3 (if needed):** For frameworks with mixed `.cc` and `.mm` files, use source file properties to control which PCH applies:
```cmake
set_source_files_properties(src/foo.cc PROPERTIES
  COMPILE_OPTIONS "-include;${PCH_CXX_PATH}")
set_source_files_properties(src/bar.mm PROPERTIES
  COMPILE_OPTIONS "-include;${PCH_OBJCXX_PATH}")
```

**Fallback:** If PCH proves too complex to get right in CMake, the build time cost is acceptable — the project has ~500 source files, and modern Macs compile this in minutes without PCH.

### Cap'n Proto Removal

Two schemas replaced with native alternatives:

**1. plist/cache.capnp → ObjC++ bridge to NSKeyedArchiver**

The plist framework's cache code is C++ (`src/*.cc`). NSKeyedArchiver is ObjC-only. The migration requires:
- Create a thin ObjC++ wrapper file (`src/cache_storage.mm`) that implements the serialization using NSKeyedArchiver
- Expose a C++ interface matching the current capnp-based API
- The rest of the plist framework remains pure C++
- Rename the existing cache implementation file from `.cc` to `.mm` OR create a new `.mm` bridge file

This is a contained change — one new `.mm` file with ~50-80 lines wrapping NSKeyedArchiver behind the existing C++ interface.

**2. encoding/frequencies.capnp → Compiled-in C++ data**

Static frequency tables. Create a build-time script that converts the capnp data to a C++ source file with constexpr arrays. Zero runtime serialization needed.

**Result:** `capnp` compiler and `libcapnp`/`libkj` libraries no longer required.

### System Libraries & Frameworks Catalog

Per-target system dependencies (must be declared in each framework's CMakeLists.txt):

| Framework | System Libraries | System Frameworks |
|-----------|-----------------|-------------------|
| text | | CoreFoundation |
| cf | | CoreFoundation |
| ns | | Foundation, Cocoa |
| io | | |
| crash | | Foundation |
| OakFoundation | | Foundation, Cocoa |
| OakSystem | | Cocoa, Security |
| OakDebug | | Cocoa, ExceptionHandling |
| OakAppKit | sqlite3 | Cocoa, Carbon, AudioToolbox, Quartz |
| network | curl | SystemConfiguration, Security |
| CrashReporter | z | Foundation, UserNotifications |
| document | | ApplicationServices |
| kvdb | sqlite3 | |
| authorization | | Security |
| regexp | | (uses vendored Onigmo) |
| mate (app) | | ApplicationServices, Security |
| TextMateQL | | CoreFoundation, QuickLook, AppKit, OSAKit |

### CMake Presets (replaces local.rave)

```json
{
  "version": 6,
  "configurePresets": [
    {
      "name": "debug",
      "generator": "Ninja",
      "binaryDir": "${sourceDir}/build-debug",
      "cacheVariables": {
        "CMAKE_BUILD_TYPE": "Debug"
      }
    },
    {
      "name": "release",
      "generator": "Ninja",
      "binaryDir": "${sourceDir}/build-release",
      "cacheVariables": {
        "CMAKE_BUILD_TYPE": "Release",
        "CS_IDENTITY": "Developer ID Application: ..."
      }
    }
  ]
}
```

Users override settings via `CMakeUserPresets.json` (gitignored), replacing `local.rave`.

### Build Commands

```bash
# Configure (replaces ./configure)
cmake -B build -G Ninja

# Build main app
ninja -C build TextMate

# Build and run (replaces ninja TextMate/run)
ninja -C build TextMate_run

# Run framework tests
cd build && ctest -R buffer

# Run all tests
cd build && ctest

# Release build
cmake --preset release && ninja -C build-release TextMate

# Xcode project (free bonus)
cmake -B xcode -G Xcode && open xcode/TextMate.xcodeproj

# After adding/removing source files:
cmake -B build -G Ninja  # re-run configure
```

## Migration Order

The migration proceeds bottom-up through the dependency tree to allow incremental validation:

**Phase 1: Infrastructure**
1. Root `CMakeLists.txt` with global settings
2. `cmake/TextMateHelpers.cmake` with all custom functions
3. `CMakePresets.json`

**Phase 2: Leaf frameworks (no internal dependencies)**
4. text, scope, cf, ns, crash, OakFoundation, OakSystem, OakDebug, authorization
5. Verify: each compiles independently

**Phase 3: Vendor libraries**
6. vendor/Onigmo, vendor/kvdb

**Phase 4: Core engine frameworks**
7. regexp → parse → buffer → selection → editor
8. encoding (with capnp removal), io, undo
9. Verify: `ctest -R buffer` etc.

**Phase 5: Service frameworks**
10. plist (with capnp removal + ragel), settings (ragel), bundles
11. scm, theme, file, command, network, document

**Phase 6: GUI frameworks**
12. OakAppKit, OakTabBarView, OakFilterList, OakCommand
13. TMFileReference, FileBrowser, MenuBuilder
14. layout, HTMLOutput, HTMLOutputWindow, Find
15. BundlesManager, BundleEditor, BundleMenu
16. OakTextView, DocumentWindow
17. Preferences, SoftwareUpdate, CrashReporter, CommitWindow

**Phase 7: Applications**
18. CLI tools: mate, bl, gtm, indent, tm_query, pretty_plist
19. PrivilegedTool
20. TextMateQL (QuickLook), SyntaxMate (XPC)
21. TextMate main app (pulls everything together)
22. Plugins: Dialog, Dialog2

**Phase 8: Cleanup**
23. PCH optimization (Phase 2-3 of PCH strategy)
24. Remove old build files (bin/rave, *.rave, configure, bin/gen_build, bin/expand_variables)
25. Update .gitignore, README

## Files Removed

| File/Dir | Lines | Replaced By |
|----------|-------|-------------|
| `bin/rave` | 1,579 | CMake + TextMateHelpers.cmake |
| `bin/gen_build` | 33 | (dead code, just deleted) |
| `bin/expand_variables` | ~50 | CMake `configure_file()` |
| `bin/gen_html` | ~80 | CMake `target_markdown_sources()` + multimarkdown |
| `configure` | 36 | `cmake -B build` + `find_package()` |
| `local.rave` | varies | CMakePresets.json / CMakeUserPresets.json |
| `local-orig.rave` | ~30 | CMakePresets.json |
| 63 `default.rave` files | ~507 | 63 `CMakeLists.txt` files |
| 2 `.capnp` schemas | ~55 | NSKeyedArchiver bridge + compiled-in C++ data |

## Files Added

| File | Purpose |
|------|---------|
| `CMakeLists.txt` (root) | Project configuration, global flags |
| `cmake/TextMateHelpers.cmake` | Custom build functions (~250 lines) |
| `CMakePresets.json` | Debug/release presets |
| ~58 `CMakeLists.txt` files | One per framework/app/vendor/plugin |
| `.gitignore` update | Ignore `build*/`, `CMakeUserPresets.json` |
| `Info.plist.in` files | Renamed from `Info.plist` (use @VAR@ syntax) |
| `Entitlements.plist.in` | Template with @CS_GET_TASK_ALLOW@ |
| `Frameworks/plist/src/cache_storage.mm` | NSKeyedArchiver bridge |
| `Frameworks/encoding/src/frequencies_data.cc` | Compiled-in frequency tables |

## Dependencies After Migration

**Required:**
- CMake >= 3.21
- Ninja (build tool, same as before)
- ragel (state machine compiler, same as before)
- Boost (headers only, same as before)
- multimarkdown (for docs, same as before)
- google-sparsehash (headers only, same as before)

**Removed:**
- Ruby (fully eliminated — rave, expand_variables, gen_html all replaced)
- Cap'n Proto compiler + libraries (replaced)

## Testing Strategy

1. **Per-phase validation:** Each migration phase must produce compiling code before proceeding
2. **File list comparison:** For each framework, compare CMake's source list against rave's glob results
3. **CxxTest integration:** Run all existing test suites via `ctest`
4. **Bundle structure diff:** Compare `find TextMate.app -type f | sort` between rave and CMake builds
5. **Code signing verification:** `codesign -vvv TextMate.app`
6. **Smoke test:** Launch app, open file, edit, save, use find/replace, run a bundle command

## Risks

| Risk | Mitigation |
|------|------------|
| PCH removal breaks implicit includes | Phase 1: build without PCH, fix missing includes first |
| Cap'n Proto removal in plist crosses C++/ObjC boundary | Thin ObjC++ bridge file, keep C++ interface unchanged |
| GLOB misses files after add/remove | Document re-run requirement; compare against rave file lists |
| CMake ObjC++ support bugs | Minimum 3.21; test with latest CMake; use generator expressions for per-language flags |
| Header export path mismatch | Verify `#include <framework/header.h>` paths; use symlink approach if needed |
| gen_html Ruby replacement loses formatting | Compare HTML output; add header/footer wrapping if needed |
| QuickLook/XPC bundle structure wrong | Compare against rave-built bundle with `diff -r` |
| DefaultBundles download fails in CI | Make DefaultBundles target optional (`-DBUILD_DEFAULT_BUNDLES=OFF`) |
