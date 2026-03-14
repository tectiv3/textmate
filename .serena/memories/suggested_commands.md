# Suggested Commands

## Build

```bash
make debug           # Incremental debug build
make release         # Incremental release build
make run             # Build debug and launch
make clean           # Remove all build dirs
```

## Testing

```bash
cd build-debug && ctest --output-on-failure    # Run all tests
cd build-debug && ctest -R buffer              # Run tests for a specific framework
```

Test framework: CxxTest (`bin/CxxTest`). Test files: `Frameworks/<name>/tests/t_*.cc` or `t_*.mm`.

## Dependencies

cmake, ninja
