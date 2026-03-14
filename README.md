# TextMate

## Download

You can [download TextMate from here](https://macromates.com/download).

## Feedback

You can use [the TextMate mailing list](https://lists.macromates.com/listinfo/textmate) or [#textmate][] IRC channel on [freenode.net][] for questions, comments, and bug reports.

You can also [contact MacroMates](https://macromates.com/support).

Before you submit a bug report please read the [writing bug reports](https://github.com/textmate/textmate/wiki/writing-bug-reports) instructions.

## Screenshot

![textmate](https://raw.github.com/textmate/textmate/gh-pages/images/screenshot.png)

# Building

## Setup

To build TextMate, you need the following:

 * [ninja][]            — build system similar to `make`
 * [cmake][]            — meta build system

All this can be installed using [Homebrew][]:

```sh
brew install ninja cmake
```

After installing dependencies, make sure you have a full checkout and then build:

```sh
git clone https://github.com/tectiv3/textmate.git
cd textmate
make run
```

## Build Commands

```sh
make debug           # Incremental debug build (ASan enabled)
make release         # Incremental release build (LTO, no ASan)
make run             # Build debug and launch
make clean           # Remove all build dirs
```

## Dependencies Removed

| Dependency | Status | Replacement |
|-----------|--------|-------------|
| Old rave build system (62 files) | Removed | CMake + Ninja |
| multimarkdown + bin/gen_html | Removed | Pre-converted HTML |
| Cap'n Proto | Replaced | NSKeyedArchiver |
| google-sparsehash | Replaced | `std::unordered_map` |
| ragel | Replaced | Hand-written parser |
| boost (variant + crc) | Replaced | `std::variant` + zlib `crc32` |

# Legal

The source for TextMate is released under the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

TextMate is a trademark of Allan Odgaard.

[ninja]:         https://ninja-build.org/
[cmake]:         https://cmake.org/
[MacPorts]:      http://www.macports.org/
[Homebrew]:      http://brew.sh/
[NinjaBundle]:   https://github.com/textmate/ninja.tmbundle
[#textmate]:     irc://irc.freenode.net/#textmate
[freenode.net]:  http://freenode.net/
