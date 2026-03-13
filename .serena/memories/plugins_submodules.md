# PlugIns are Git Submodules

The PlugIns directory contains two git submodules that must be initialized:
- `PlugIns/dialog/` → Dialog2.tmplugin + tm_dialog2 CLI tool
- `PlugIns/dialog-1.x/` → Dialog.tmplugin + tm_dialog CLI tool

Both have their own `default.rave` files with dual targets (CLI tool + plugin bundle).
Plugin bundles use `-bundle` linker flag and `.tmplugin` extension.

Other submodules in the repo:
- `Applications/SyntaxMate/resources/SyntaxMate.tmBundle`
- `Applications/TextMate/icons`
- `bin/CxxTest`
- `vendor/Onigmo/vendor`
- `vendor/kvdb/vendor`

Always run `git submodule update --init` when working with this repo.
