cmake_minimum_required(VERSION 3.21)
project(TextMate LANGUAGES C CXX OBJC OBJCXX)

set(CMAKE_OSX_DEPLOYMENT_TARGET "10.12")
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_C_STANDARD 99)
set(CMAKE_VISIBILITY_INLINES_HIDDEN ON)
set(CMAKE_CXX_VISIBILITY_PRESET hidden)

# ObjC flags — one flag per generator expression
add_compile_options(
  $<$<COMPILE_LANGUAGE:OBJC>:-fobjc-abi-version=3>
  $<$<COMPILE_LANGUAGE:OBJC>:-fobjc-arc>
  $<$<COMPILE_LANGUAGE:OBJCXX>:-fobjc-abi-version=3>
  $<$<COMPILE_LANGUAGE:OBJCXX>:-fobjc-arc>
  $<$<COMPILE_LANGUAGE:OBJCXX>:-fobjc-call-cxx-cdtors>
)

# Common flags (all languages) — from default.rave FLAGS
add_compile_options(
  -funsigned-char
  -Wall -Wwrite-strings -Wformat -Winit-self -Wmissing-include-dirs
  -Wno-parentheses -Wno-sign-compare -Wno-switch -Wno-c99-designator
)
add_compile_definitions(
  "NULL_STR=\"\\uFFFF\""
  "REST_API=\"https://api.textmate.org\""
)

# Debug: -Os + ASan (rave debug config uses -Os)
set(CMAKE_C_FLAGS_DEBUG "-Os -g -fsanitize=address -fno-omit-frame-pointer" CACHE STRING "" FORCE)
set(CMAKE_CXX_FLAGS_DEBUG "-Os -g -fsanitize=address -fno-omit-frame-pointer" CACHE STRING "" FORCE)
set(CMAKE_OBJC_FLAGS_DEBUG "-Os -g -fsanitize=address -fno-omit-frame-pointer" CACHE STRING "" FORCE)
set(CMAKE_OBJCXX_FLAGS_DEBUG "-Os -g -fsanitize=address -fno-omit-frame-pointer" CACHE STRING "" FORCE)
set(CMAKE_EXE_LINKER_FLAGS_DEBUG "-fsanitize=address" CACHE STRING "" FORCE)

# Release: LTO + dead stripping
set(CMAKE_C_FLAGS_RELEASE "-Os -DNDEBUG -flto=thin" CACHE STRING "" FORCE)
set(CMAKE_CXX_FLAGS_RELEASE "-Os -DNDEBUG -flto=thin" CACHE STRING "" FORCE)
set(CMAKE_OBJC_FLAGS_RELEASE "-Os -DNDEBUG -flto=thin" CACHE STRING "" FORCE)
set(CMAKE_OBJCXX_FLAGS_RELEASE "-Os -DNDEBUG -flto=thin" CACHE STRING "" FORCE)
set(CMAKE_EXE_LINKER_FLAGS_RELEASE
  "-flto=thin -Wl,-dead_strip -Wl,-dead_strip_dylibs -Wl,-cache_path_lto,${CMAKE_BINARY_DIR}/.lto-cache"
  CACHE STRING "" FORCE)

# ObjC runtime linking
add_link_options(-fobjc-link-runtime)

# Dependencies
find_package(Boost REQUIRED)
find_package(CapnProto REQUIRED)
find_program(RAGEL_EXECUTABLE ragel REQUIRED)

# Global include paths for PCH dependencies
include_directories(SYSTEM ${Boost_INCLUDE_DIRS})
find_path(SPARSEHASH_INCLUDE_DIR sparsehash/dense_hash_map REQUIRED)
include_directories(SYSTEM ${SPARSEHASH_INCLUDE_DIR})

# Version extraction (replaces rave `capture` command)
file(STRINGS "${CMAKE_SOURCE_DIR}/Applications/TextMate/about/Changes.md"
  _version_line REGEX "^## [0-9]" LIMIT_COUNT 1)
string(REGEX MATCH "[0-9]+\\.[0-9]+(\\.[0-9]+)?" TEXTMATE_VERSION "${_version_line}")

# Shared includes
include_directories(Shared/include)

# Precompiled headers — force-include per language (matches rave's PCH behavior)
include_directories(Shared/PCH)
add_compile_options(
  $<$<COMPILE_LANGUAGE:C>:-include${CMAKE_SOURCE_DIR}/Shared/PCH/prelude.c>
  $<$<COMPILE_LANGUAGE:CXX>:-include${CMAKE_SOURCE_DIR}/Shared/PCH/prelude.cc>
  $<$<COMPILE_LANGUAGE:OBJC>:-include${CMAKE_SOURCE_DIR}/Shared/PCH/prelude.m>
  $<$<COMPILE_LANGUAGE:OBJCXX>:-include${CMAKE_SOURCE_DIR}/Shared/PCH/prelude.mm>
)

# Helpers
include(cmake/TextMateHelpers.cmake)

# Code signing identity
set(CS_IDENTITY "-" CACHE STRING "Code signing identity (- for ad-hoc)")

# OakDebug provides oak::to_s and OakBadAssertion symbols used pervasively
# through header templates — needed in all build configs, not just debug
set(TEXTMATE_DEBUG_LIBS OakDebug)

# === Vendor ===
add_subdirectory(vendor/Onigmo)
add_subdirectory(vendor/kvdb)

# === Leaf Frameworks (no internal deps or only text) ===
add_subdirectory(Frameworks/text)
add_subdirectory(Frameworks/scope)
add_subdirectory(Frameworks/crash)
add_subdirectory(Frameworks/OakFoundation)
add_subdirectory(Frameworks/cf)
add_subdirectory(Frameworks/MenuBuilder)

# === Low-level frameworks ===
add_subdirectory(Frameworks/ns)
add_subdirectory(Frameworks/OakSystem)
add_subdirectory(Frameworks/OakDebug)
add_subdirectory(Frameworks/io)
add_subdirectory(Frameworks/authorization)
add_subdirectory(Frameworks/regexp)
add_subdirectory(Frameworks/encoding)

# === Core engine ===
add_subdirectory(Frameworks/parse)
add_subdirectory(Frameworks/bundles)
add_subdirectory(Frameworks/plist)
add_subdirectory(Frameworks/selection)
add_subdirectory(Frameworks/buffer)
add_subdirectory(Frameworks/undo)
add_subdirectory(Frameworks/editor)
add_subdirectory(Frameworks/settings)
add_subdirectory(Frameworks/theme)

# === Services ===
add_subdirectory(Frameworks/scm)
add_subdirectory(Frameworks/network)
# add_subdirectory(Frameworks/updater)  # disabled — not needed
add_subdirectory(Frameworks/file)
add_subdirectory(Frameworks/command)
add_subdirectory(Frameworks/layout)
add_subdirectory(Frameworks/license)

# === GUI frameworks ===
add_subdirectory(Frameworks/OakAppKit)
add_subdirectory(Frameworks/TMFileReference)
add_subdirectory(Frameworks/SoftwareUpdate)
add_subdirectory(Frameworks/Preferences)
add_subdirectory(Frameworks/OakTabBarView)
add_subdirectory(Frameworks/OakFilterList)
add_subdirectory(Frameworks/HTMLOutput)
add_subdirectory(Frameworks/HTMLOutputWindow)
add_subdirectory(Frameworks/OakCommand)
add_subdirectory(Frameworks/BundlesManager)
add_subdirectory(Frameworks/BundleMenu)
add_subdirectory(Frameworks/BundleEditor)
add_subdirectory(Frameworks/Find)
add_subdirectory(Frameworks/FileBrowser)
add_subdirectory(Frameworks/OakTextView)
add_subdirectory(Frameworks/CrashReporter)
add_subdirectory(Frameworks/document)
add_subdirectory(Frameworks/DocumentWindow)
add_subdirectory(Frameworks/CommitWindow)

# === Applications ===
add_subdirectory(Applications/mate)
# add_subdirectory(Applications/bl)  # disabled — depends on updater
add_subdirectory(Applications/gtm)
add_subdirectory(Applications/indent)
add_subdirectory(Applications/pretty_plist)
add_subdirectory(Applications/tm_query)
add_subdirectory(Applications/PrivilegedTool)
add_subdirectory(Applications/QuickLookGenerator)
add_subdirectory(Applications/SyntaxMate)
add_subdirectory(Applications/NewApplication)
add_subdirectory(Applications/TextMate)

# === PlugIns (submodules) ===
add_subdirectory(PlugIns/dialog)
add_subdirectory(PlugIns/dialog-1.x)
