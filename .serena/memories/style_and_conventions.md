# Code Style and Conventions

## Formatting
- **Indentation:** Hard tabs, tab size 3
- **Pointer style:** `type* var` (pointer attached to type)
- **Visibility:** Hidden by default (`-fvisibility=hidden`)

## Naming
- **Namespaces:** `oak::` (utilities), `ng::` (text/buffer engine)
- **Type suffix:** `_t` for type definitions, `_ptr` for smart pointers
- **Header guards:** `#ifndef SOMETHING_H_RANDOMHASH`

## Memory Management
- `std::shared_ptr` for C++ objects
- ARC for Objective-C objects

## C++ Standard
- C++20

## Commits
- Summary < 70 chars
- Blank line, then reasoning

## No `@available` Checks
APIs available since macOS 14 (minimum deployment target) don't need availability checks.
