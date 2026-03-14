# TextMate Build System

## Overview
CMake + Ninja. The old rave/ninja system has been fully replaced.

## Build Commands

```bash
make debug           # Incremental debug build (ASan enabled)
make release         # Incremental release build (LTO, no ASan)
make run             # Build debug and launch TextMate.app
make clean           # Remove all build dirs
```

Under the hood:
```bash
cmake -B build-debug -G Ninja -DCMAKE_BUILD_TYPE=Debug
ninja -C build-debug
```

## Testing

```bash
cd build-debug && ctest --output-on-failure
```

Test framework: CxxTest (`bin/CxxTest`). Test files: `Frameworks/<name>/tests/t_*.cc` or `t_*.mm`.
gen_test runner inlines test source bodies — don't compile test files separately.

## Dependencies

- **Build tools:** cmake, ninja
- **Vendored:** Onigmo (regex), kvdb (key-value DB over sqlite3), nlohmann/json
- **System frameworks:** Cocoa, AppKit, ApplicationServices, Security, etc.

## Build Quirks

- `-ObjC` linker flag required to load ObjC categories from static libraries
- `network` framework include path is PRIVATE to avoid case-insensitive collision with Apple's Network.framework
- `Frameworks/updater` and `Applications/bl` disabled (not needed, avoids network collision)
- OakDebug linked unconditionally (symbols used in all build configs)
- Plugin `.tmplugin` bundles need ad-hoc codesigning before embedding in app
- Framework resources (icons, images, plists) must be added to TextMate app CMakeLists since static libs can't carry resources
- CMake helpers in `cmake/TextMateHelpers.cmake`

## Build Output

- `build-debug/` — debug build (ASan enabled)
- `build-release/` — release build (LTO)
