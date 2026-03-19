# TextMate .tm_properties System - Complete Research

## Overview
The `.tm_properties` system is TextMate's configuration mechanism for file and folder-targeted settings. It uses INI-style syntax with support for:
- Global key=value settings
- File-type/scope-specific sections with `[ ... ]` headers
- Format string expansion with variable interpolation
- Cascading from home directory down to project directories

---

## 1. PARSING FRAMEWORK

### Parser Location
**File:** `/Users/fenrir/code/textmate/Frameworks/settings/src/parser.{h,cc}`

### Key Classes

#### `ini_file_t` (parser.h)
- Represents a parsed .tm_properties file
- Contains sections (see below)
- **Members:**
  - `std::string path` - file path
  - `std::vector<section_t> sections` - parsed sections

#### `ini_file_t::section_t`
- Each section represents either global settings or file-type/scope rules
- **Members:**
  - `std::vector<std::string> names` - section header names (e.g., `["*.py"]`, `["text.python"]`)
  - `std::vector<value_t> values` - key-value pairs

#### `ini_file_t::section_t::value_t`
- Individual setting assignment
- **Members:**
  - `std::string name, value` - key and value
  - `size_t line_number` - for error reporting

### Parser Function
```cpp
char const* parse_ini(char const* p, char const* pe, ini_file_t& iniFile);
```
- Recursive descent parser
- Handles comments (`#`), sections (`[ ... ]`), and assignments
- Supports escaped characters and quoted strings

### Grammar (Complete)
```
file:          ( «line» )*
line:          ( «comment» | ( «section» | «assignment» )? ( «comment» )? ) ( '\n' | EOF )
section:       '[' «name» ( ";" «name» )* ']'
name:          ( /[^\] \t\n]/ | /\\[\] \t\n\\]/ )+
assignment:    «key» '=' «value»
key:           ( /[^= \t\n]/ | /\\[= \t\n\\]/ )+
value:         ( «single_string» | «double_string» | «bare_string» )
single_string: "'" ( /[^']/ | /\\['\\]/ )* "'"
double_string: '"' ( /[^"]/ | /\\["\\]/ )* '"'
bare_string:   ( /[^ \t\n]/ | /\\[ \t\n\\]/ )+
comment:       '#' ( /[^\n]/ )*
```

---

## 2. SETTINGS DATA STRUCTURES

### Main Settings Class
**File:** `/Users/fenrir/code/textmate/Frameworks/settings/src/settings.h`

#### `settings_t`
- Template-based wrapper around `std::map<std::string, std::string>`
- Handles type conversion and retrieval
- **Key Methods:**
  - `T get(key, defaultValue)` - retrieve with type conversion (bool, int32_t, double, string)
  - `has(key)` - check if setting exists
  - `set(key, value, fileType, path)` - static method to save settings
  - `raw_get(key, section)` - get without expanding format strings
  - `all_settings()` - return all settings map

#### `setting_info_t`
- Metadata for a single setting (where it came from, which line, section)
- **Members:**
  - `std::string variable, value` - name and value
  - `std::string path` - .tm_properties file it came from
  - `size_t line_number` - line in the file
  - `std::string section` - section it appeared in

#### Internal Section Structure
```cpp
struct section_t {
    bool has_file_glob = false;       // section is a glob pattern like [ *.py ]
    bool has_scope_selector = false;  // section is a scope like [ text.python ]
    
    std::string path;                 // .tm_properties file path
    path::glob_t file_glob;           // compiled glob pattern
    scope::selector_t scope_selector; // compiled scope selector
    std::vector<assignment_t> variables;
    std::string section;              // original header text
};
```

---

## 3. SETTINGS RESOLUTION (CASCADING)

### Location
**File:** `/Users/fenrir/code/textmate/Frameworks/settings/src/settings.cc`

### Cascade Order

The system searches for settings in this precise order:

1. **Default Settings File** (`default_settings_path()`)
   - Unscoped settings (top-level)
   - Scope-matched sections

2. **Global Settings File** (`global_settings_path()`)
   - Unscoped settings
   - Scope-matched sections

3. **Path-based .tm_properties Files** (bottom-up)
   - Walk directory tree from file location to home directory
   - Each directory's `.tm_properties` is processed:
     - Unscoped settings
     - Scope-matched sections
     - File-glob matched sections

### Processing Categories (Priority)

Within each .tm_properties file, settings are applied in priority order:

1. **Unscoped (top-level)** - lowest priority
   - Direct key=value pairs outside any section
   - **Code constant:** `kUnscoped = (1 << 2)`

2. **Scope Selectors** - medium priority
   - Sections matching `[ text ]`, `[ source.python ]`, etc.
   - Ranked by specificity (longest matching scope wins)
   - **Code constant:** `kScopeSelector = (1 << 1)`

3. **File Globs** - highest priority
   - Sections matching `[ *.py ]`, `[ /path/to/file ]`, etc.
   - **Code constant:** `kGlob = (1 << 0)`

### Key Functions

#### `settings_for_path()`
```cpp
settings_t settings_for_path(
    std::string const& path = NULL_STR,           // file path
    scope::scope_t const& scope = "",             // scope (e.g., "text.python")
    std::string const& directory = NULL_STR,      // explicit directory override
    std::map<std::string, std::string> variables = {}  // base variables
);
```
- Returns fully resolved `settings_t` with all variables expanded
- Expands format strings like `${TM_VARIABLE}`
- Uses `expanded_variables_for()` internally

#### `variables_for_path()`
```cpp
std::map<std::string, std::string> variables_for_path(
    std::map<std::string, std::string> const& base = {},
    std::string const& path = NULL_STR,
    scope::scope_t const& scope = "",
    std::string const& directory = NULL_STR
);
```
- Returns only **uppercase** variables (shell environment variables)
- Filters out lowercase settings

#### `settings_info_for_path()`
```cpp
std::vector<setting_info_t> settings_info_for_path(
    std::string const& path = NULL_STR,
    scope::scope_t const& scope = "",
    std::string const& directory = NULL_STR
);
```
- Returns metadata about where each setting came from
- Used for debugging/UI (e.g., "this setting is from ~/.tm_properties:42")

### Directory Traversal
```cpp
static std::vector<std::string> paths(std::string const& directory)
{
    // Walks from directory (or home) up to home
    // Returns: [~/.tm_properties, ~/proj/.tm_properties, ~/proj/sub/.tm_properties]
}
```

---

## 4. COMPLETE LIST OF SUPPORTED PROPERTY KEYS

### Source File
**File:** `/Users/fenrir/code/textmate/Frameworks/settings/src/keys.{h,cc}`

All keys are defined as C++ string constants (extern in .h, defined in .cc).

#### Editor Display Keys
- `tabSize` - number of spaces per tab (int)
- `softTabs` - use spaces instead of tabs (bool)
- `softWrap` - wrap long lines (bool)
- `wrapColumn` - column to wrap at (int)
- `showWrapColumn` - show visual wrap marker (bool)
- `showIndentGuides` - show indent guide lines (bool)
- `showInvisibles` - show tabs/spaces/line endings (bool)
- `invisiblesMap` - how to render invisible chars (string dict)

#### Font & Theme
- `fontName` - font family (string)
- `fontSize` - font size in points (int)
- `theme` - theme UUID/name (string)

#### File Type Detection
- `fileType` - grammar scope (e.g., "source.python") (string)
- `relatedFilePath` - path to related file (e.g., test file) (string)

#### Text Processing
- `encoding` - character encoding (string, e.g., "UTF-8")
- `lineEndings` - line ending style (string: "\n", "\r", "\r\n")
- `spellChecking` - enable spell check (bool)
- `spellingLanguage` - spell check language (string, e.g., "en")

#### File I/O
- `binary` - treat as binary file (bool/glob pattern)
- `saveOnBlur` - save when window loses focus (bool)
- `atomicSave` - use atomic write (bool)
- `storeEncodingPerFile` - remember encoding per file (bool)
- `disableExtendedAttributes` - don't use xattr (bool)

#### Project Structure
- `projectDirectory` - project root (string, path)
- `windowTitle` - window title format string (string)
- `tabTitle` - tab title format string (string)

#### Formatting
- `formatCommand` - command to format code (string)
- `formatOnSave` - auto-format on save (bool)

#### File Browser Filters
- `include` - glob pattern to include (string)
- `includeDirectories` - include dirs in browser (string/glob)
- `includeDirectoriesInBrowser` - include dirs in file browser (string/glob)
- `includeFilesInBrowser` - include files in file browser (string/glob)
- `includeFilesInFileChooser` - include in file picker (string/glob)
- `includeInBrowser` - general include (string/glob)
- `includeInFileChooser` - general include in file picker (string/glob)

#### Exclusion Patterns
- `exclude` - glob to exclude (string)
- `excludeDirectories` - exclude dirs (string/glob)
- `excludeDirectoriesInBrowser` - hide from browser (string/glob)
- `excludeDirectoriesInFileChooser` - hide from file picker (string/glob)
- `excludeDirectoriesInFolderSearch` - hide from search (string/glob)
- `excludeFilesInBrowser` - hide files from browser (string/glob)
- `excludeFilesInFileChooser` - hide from file picker (string/glob)
- `excludeFilesInFolderSearch` - hide from search (string/glob)
- `excludeInBrowser` - general exclude (string/glob)
- `excludeInFileChooser` - general exclude in picker (string/glob)
- `excludeInFolderSearch` - general exclude in search (string/glob)

#### SCM & Misc
- `scmStatus` - show SCM status in browser (bool)
- `followSymbolicLinks` - follow symlinks (bool)
- `excludeSCMDeleted` - exclude deleted files (bool)
- `scopeAttributes` - extra scope attributes (string)

---

## 5. FILE-TYPE AND SCOPE-SPECIFIC RULES

### Section Syntax
Sections in `.tm_properties` use `[ ... ]` syntax with three types:

#### Type 1: File Globs
```
[ *.py ]
tabSize = 4
softTabs = true

[ *.{cc,mm,h} ]
tabSize = 3

[ /path/to/specific/file ]
someKey = value
```
- Matched via `path::glob_t` class
- Applied to file paths
- Can use `*`, `**`, `{}` syntax

#### Type 2: Scope Selectors
```
[ text ]
softWrap = true

[ source.python ]
tabSize = 4

[ text.markup.html ]
lineEndings = "\r\n"
```
- Matched via `scope::selector_t` class
- Matched against document's syntax scope
- Root scopes: `text`, `source`, `attr`
- Ranked by specificity (most specific wins)

#### Type 3: Multiple Names (Semicolon-Separated)
```
[ *.txt ; *.md ]
softWrap = true
```
- Each name applies same settings
- Can mix globs and scopes
- Used when multiple patterns need identical settings

### Special Scope: `attr.untitled`
```
[ attr.untitled ]
fileType = source.python
```
- Applied to unsaved/new documents
- Used to auto-detect file type for untitled docs

### Path Anchoring
```
[ "/System/Library/Frameworks/**/Headers/**" ]
encoding = "MACROMAN"

[ "hg-editor-*.txt" ]
fileType = "text.hg-commit"
```
- Absolute paths: `/` anchored
- Relative paths: glob pattern style

---

## 6. VARIABLE EXPANSION & FORMAT STRINGS

### Global Variables
Variables come from:
1. **System environment** (inherited by TextMate)
2. **User preferences** (environmentVariables in NSUserDefaults)
3. **.tm_properties files** (uppercase keys = shell env vars)

### Special Variables

#### `CWD`
- Current working directory of the .tm_properties file
- Available during expansion ONLY, removed afterward
- Used to make relative path references

#### `TM_PROPERTIES_PATH`
- Path to the .tm_properties file being processed
- Colon-separated list (accumulates as cascade builds)
- Removed from final settings

### Format String Expansion
Uses `format_string::expand()` from `<regexp/format_string.h>`:

```
windowTitle = "$TM_DISPLAYNAME — ${projectDirectory/^.*\///}"
```

Syntax:
- `$VAR` - simple substitution
- `${VAR}` - safe (if VAR empty, use empty)
- `${VAR:+value}` - conditional (if VAR set, use value)
- `${VAR/pattern/replacement}` - regex substitution

### Variable Shadowing
- Later files/sections override earlier ones
- Variables expanded with current state (previous expansions available)

---

## 7. CACHING & FILE WATCHING

### Cache Implementation
**File:** `/Users/fenrir/code/textmate/Frameworks/settings/src/track_paths.h`

#### `track_paths_t`
- Watches .tm_properties files for changes
- Uses `dispatch_source_t` (Grand Central Dispatch)
- Monitors: WRITE, EXTEND, DELETE, RENAME, REVOKE events
- File descriptors tracked per path

#### Section Cache
```cpp
static std::vector<section_t> const& sections(std::string const& path)
{
    static std::map<std::string, std::vector<section_t> > cache;
    // Caches up to 64 files
    // Auto-reloads when `is_changed(path)` returns true
}
```

---

## 8. RUNTIME SETTINGS RESOLUTION

### Usage in Documents
**File:** `/Users/fenrir/code/textmate/Frameworks/document/src/OakDocument.mm`

Documents call:
```cpp
settings_t const settings = settings_for_path(
    to_s(_virtualPath ?: _path),           // document path
    to_s(_fileType),                       // scope (e.g., "text.python")
    to_s([_path stringByDeletingLastPathComponent] ?: _directory)  // directory
);
```

### Usage in Editor View
**File:** `/Users/fenrir/code/textmate/Frameworks/OakTextView/src/OakTextView.mm`

Editor calls:
```cpp
settings_t const settings = settings_for_path(
    logical_path(),
    file_type() + " " + scopeAttributes,  // combined scope
    path::parent(path())
);
```

Then retrieves:
```cpp
settings.get(kSettingsTabSizeKey, 4)
settings.get(kSettingsSoftTabsKey, false)
settings.get(kSettingsFontNameKey, "Menlo")
```

---

## 9. SAVING SETTINGS

### Function: `settings_t::set()`
```cpp
static void set(
    std::string const& key,
    std::string const& value,
    std::string const& fileType = "",      // e.g., "source.python"
    std::string const& path = NULL_STR     // file path
);
```

### Behavior
1. Determines which .tm_properties file to write to (global or default)
2. Creates section names based on fileType:
   - If fileType is "source.python.django":
     - Creates sections: `[ source.python.django ]`, `[ source.python ]`, `[ source ]`
3. Adds path-specific section if path provided
4. Sorts sections by type and writes to file

### File Organization (in output)
```
# Version 1.0 -- Generated content!

# Top-level settings first
tabSize = 4
fontName = "Menlo"

# Then scope selectors
[ source ]
...
[ text ]
...

# Then file globs
[ *.py ]
...
```

---

## 10. UI FOR EDITING .tm_properties

### Preferences Framework
**Location:** `/Users/fenrir/code/textmate/Frameworks/Preferences/src/`

#### PreferencesPane (Base Class)
- Properties:
  - `defaultsProperties` - NSDictionary mapping UI keys → NSUserDefaults keys
  - `tmProperties` - NSDictionary mapping UI keys → .tm_properties keys

#### Value Binding
- When UI control changes, PreferencesPane intercepts via `setValue:forUndefinedKey:`
- Routes to either NSUserDefaults or `settings_t::set()` based on which dict has the key

### Preference Panes Using .tm_properties

#### FilesPreferences
```
@"encoding"    ↔ kSettingsEncodingKey ("encoding")
@"lineEndings" ↔ kSettingsLineEndingsKey ("lineEndings")
```

#### ProjectsPreferences
```
@"excludePattern" ↔ kSettingsExcludeKey ("exclude")
@"includePattern" ↔ kSettingsIncludeKey ("include")
@"binaryPattern"  ↔ kSettingsBinaryKey ("binary")
```

#### VariablesPreferences
- Manages environment variables in NSUserDefaults
- Not directly .tm_properties but provides variables that get expanded

### Flow: Setting a Property
1. User changes preference in UI
2. KVO binding fires
3. PreferencesPane.setValue:forUndefinedKey: called
4. Looks up key in tmProperties dictionary
5. Calls: `settings_t::set(kSettingsEncodingKey, newValue)`
6. writes to: `~/.textmate/properties` (global settings file)
7. Next document load will read new settings

---

## 11. DEFAULT PROPERTIES

### Default Properties File
**Location:** `/Users/fenrir/code/textmate/Applications/TextMate/resources/Default.tmProperties`

**Key Defaults:**
```
fontSize = 12
encoding = "UTF-8"

# File filtering
exclude  = "{*.{o,pyc},Icon\r,CVS,_darcs,_MTN,...}"
include  = "{*,.tm_properties,.htaccess}"
binary   = "{*.{ai,bz2,flv,gif,...},...}"

# Window titles and UI
windowTitle = '$TM_DISPLAYNAME$windowTitleProject$windowTitleSCM'

# Per-language defaults
[ source.python ]
softTabs = true
tabSize = 4

[ source.ruby ]
softTabs = true
tabSize = 2

[ source.makefile ]
softTabs = false
```

---

## 12. HELP DOCUMENTATION

**Location:** `/Users/fenrir/code/textmate/Applications/TextMate/resources/TextMate Help/properties.md`

- Explains cascading from home to project directories
- Documents section syntax
- Shows format string examples
- Explains special sections like `[ attr.untitled ]`

---

## Key Implementation Files Summary

| File | Purpose |
|------|---------|
| `Frameworks/settings/src/settings.h` | Main settings_t class |
| `Frameworks/settings/src/settings.cc` | Resolution algorithm, caching |
| `Frameworks/settings/src/parser.h/.cc` | INI file parser |
| `Frameworks/settings/src/keys.h/.cc` | All property key constants |
| `Frameworks/settings/src/track_paths.h` | File system watcher |
| `Frameworks/Preferences/src/PreferencesPane.mm` | UI binding to .tm_properties |
| `Frameworks/Preferences/src/ProjectsPreferences.mm` | Project-level property UI |
| `Frameworks/Preferences/src/FilesPreferences.mm` | File-level property UI |
| `Frameworks/document/src/OakDocument.mm` | Document settings lookup |
| `Frameworks/OakTextView/src/OakTextView.mm` | Editor settings usage |
