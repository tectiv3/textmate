# Suggested Commands

## Build

```bash
./configure                # Bootstrap (generates build.ninja)
ninja TextMate             # Build main app
ninja TextMate/run         # Build and run
ninja <framework>/test     # Run tests for a framework (e.g., ninja io/test)
ninja -t clean             # Clean everything
```

Build output goes to `~/build/TextMate` (override with `builddir` env var).

## Testing

```bash
ninja <framework>/test     # Run tests for a specific framework
```

Test framework: CxxTest (`bin/CxxTest`). Test files: `Frameworks/<name>/tests/t_*.cc` or `t_*.mm`.

## Dependencies

ragel, boost, multimarkdown, mercurial (for tests), Cap'n Proto, LibreSSL, google-sparsehash, ninja

