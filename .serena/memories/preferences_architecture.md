# TextMate Preferences Framework Architecture

## Overview
The Preferences framework is located at `/Users/fenrir/code/textmate/Frameworks/Preferences/` and provides a tabbed preferences window with multiple preference panes. The system uses a base class pattern with NSViewController subclasses, data binding via dictionaries, and NSToolbar for navigation.

## Framework Structure

### Key Files
- **PreferencesPane.h/mm** - Base class for simple preference panes
- **Preferences.h/mm** - Main window controller and toolbar delegate
- **Keys.h/mm** - Constants for NSUserDefaults and settings keys
- **Individual pane files** (see below)

### Entry Point
`Preferences.mm` line 79-130: The `Preferences` class (NSWindowController) creates:
- PreferencesViewController (OakTransitionViewController subclass) that manages pane switching
- NSPanel window with NSToolbar (displayMode auto-detects if icons are available)
- Array of child view controllers (the panes)
- Toolbar delegate that creates toolbar items from pane identifiers and images

## All Preference Panes (8 total)

| Pane | Class | File | Image | Type |
|------|-------|------|-------|------|
| Files | FilesPreferences | FilesPreferences.h/.mm | NSImageNameMultipleDocuments | PreferencesPane subclass |
| Projects | ProjectsPreferences | ProjectsPreferences.h/.mm | @"Projects" (custom) | PreferencesPane subclass |
| Bundles | BundlesPreferences | BundlesPreferences.h/.mm | BundlesManager icon | NSViewController + protocol |
| Variables | VariablesPreferences | VariablesPreferences.h/.mm | @"Variables" (custom) | NSViewController + protocol |
| Formatters | FormattersPreferences | FormattersPreferences.h/.mm | @"hammer" (SF Symbol) | NSViewController + protocol |
| Terminal | TerminalPreferences | TerminalPreferences.h/.mm | NSImageNameShare | PreferencesPane subclass |
| Advanced | AdvancedPreferences | AdvancedPreferences.h/.mm | @"gearshape.2" (SF Symbol) | PreferencesPane subclass |

**Registration order** in Preferences.mm lines 98-106:
1. FilesPreferences
2. ProjectsPreferences
3. BundlesPreferences
4. VariablesPreferences
5. FormattersPreferences
6. TerminalPreferences
7. AdvancedPreferences

## Base Class System

### Pattern 1: PreferencesPane Subclass (Simpler)
Inherits from `PreferencesPane : NSViewController <PreferencesPaneProtocol>`

**Constructor pattern:**
```
- (id)init {
    if(self = [super initWithNibName:nil label:@"Pane Title" image:[NSImage imageNamed:@"Icon"]])
    {
        self.defaultsProperties = @{ @"viewKey": kUserDefaultsKey };
        self.tmProperties = @{ @"viewKey": @"settingsKey" };
    }
    return self;
}
```

**Key points:**
- Calls `initWithNibName:label:image:` (PreferencesPane.mm line 45)
- Sets identifier and title automatically
- `defaultsProperties` dict maps view properties → NSUserDefaults keys
- `tmProperties` dict maps view properties → settings_t keys
- `loadView` creates UI programmatically with NSGridView or NSView+constraints
- Data binding is automatic via `setValue:forUndefinedKey:` (PreferencesPane.mm lines 56-69)

**Examples:**
- FilesPreferences: Simple form with checkboxes, popups, popupbutton
- ProjectsPreferences: Mix of defaults and tm properties
- TerminalPreferences: XIB-based (rare), has custom IBOutlets
- AdvancedPreferences: Large NSGridView with section separators and hint labels

### Pattern 2: Custom NSViewController + Protocol (Complex/Table-based)
Directly implements `NSViewController <PreferencesPaneProtocol>`

**Constructor pattern:**
```
- (id)init {
    if(self = [self initWithNibName:nil bundle:nil])
    {
        self.identifier = @"Pane ID";
        self.title = @"Pane Title";
    }
    return self;
}
```

**Key points:**
- Must set `identifier` and `title` manually
- Optionally implement `toolbarItemImage` property (not inherited)
- Manually manage NSUserDefaults or data model
- `loadView` creates full UI
- Can implement NSTableViewDataSource/Delegate for table views
- Must implement `commitEditing` if using editable tables

**Examples:**
- FormattersPreferences: NSTableView with 5 columns (enabled checkbox, glob, name, command, status)
- VariablesPreferences: NSTableView with 3 columns (enabled, name, value) - fully editable, manual NSUserDefaults sync
- BundlesPreferences: Complex, uses BundlesManager and OakScopeBarView

## Data Binding Mechanism

PreferencesPane.mm lines 56-78 implement KVC binding:

```objc
- (void)setValue:(id)newValue forUndefinedKey:(NSString*)aKey {
    if(NSString* key = [_defaultsProperties objectForKey:aKey]) {
        [NSUserDefaults.standardUserDefaults setObject:newValue forKey:key];
    } else if(NSString* key = [_tmProperties objectForKey:aKey]) {
        settings_t::set(to_s(key), to_s(newValue));
    }
}

- (id)valueForUndefinedKey:(NSString*)aKey {
    if(NSString* key = [_defaultsProperties objectForKey:aKey])
        return [NSUserDefaults.standardUserDefaults objectForKey:key];
    else if(NSString* key = [_tmProperties objectForKey:aKey])
        return [NSString stringWithCxxString:settings_t::raw_get(to_s(key))];
}
```

**Used by:**
- IBOutlet properties in XIB files (auto-binding)
- Manual bindings in code via `-bind:toObject:withKeyPath:options:`

## Toolbar/Tab System

Preferences.mm lines 111-128:

**Toolbar setup:**
1. Create NSToolbar with delegate = Preferences instance
2. Auto-detect if any pane has `toolbarItemImage` property
3. Set displayMode: `.IconAndLabel` if images, `.LabelOnly` otherwise
4. Set toolbarStyle to `.Preference` on macOS 11+

**Toolbar delegate methods:**
- `toolbar:itemForItemIdentifier:willBeInsertedIntoToolbar:` (line 180)
  - Creates NSToolbarItem from view controller
  - Uses viewController.title as label
  - Uses viewController.toolbarItemImage if available
  
- `toolbarAllowedItemIdentifiers:` (line 196)
  - Returns all child view controller identifiers
  
- `toolbarDefaultItemIdentifiers:` (line 207)
  - Returns all items for toolbar (uses allowed)
  
- `toolbarSelectableItemIdentifiers:` (line 212)
  - Returns all selectable items (used for cycling via Cmd+}])

**Pane switching:**
- PreferencesViewController.setSelectedViewIdentifier: (Preferences.mm line 32)
  - Calls commitEditing on old pane (allows validation)
  - Updates toolbar.selectedItemIdentifier
  - Saves selection to NSUserDefaults (kMASPreferencesSelectedViewKey)
  - Swaps subview via OakTransitionViewController.subview
  - Restores first responder to appropriate view

## Window Management

Preferences.mm lines 90-92, 132-135:

- Window is NSPanel with windowCollectionBehavior:
  - NSWindowCollectionBehaviorMoveToActiveSpace
  - NSWindowCollectionBehaviorFullScreenAuxiliary
- hidesOnDeactivate = NO
- Window frame position saved/restored via kMASPreferencesFrameTopLeftKey
- Window move tracking via NSWindowDelegate.windowDidMove:

## UI Construction Patterns

### 1. NSGridView (Most Common)
Used in FilesPreferences, AdvancedPreferences:
- NSGridView.gridViewWithViews: creates rows from array of view arrays
- Each inner array = one row
- NSGridCell.emptyContentView for label columns
- OakSetupGridViewWithSeparators: adds section separators at specific rows
  - Sets column widths (label=200, value=400)
  - Sets padding/spacing
  - Merges separator cells horizontally
  - (PreferencesPane.mm lines 7-38)

### 2. NSTableView with NSScrollView (FormattersPreferences, VariablesPreferences)
- Columns created with `columnWithIdentifier:title:editable:width:resizingMask:`
- NSButtonCell for checkbox columns
- alternatingRowBackgroundColors = YES
- TableView delegate/datasource for rendering and editing
- Manual save to NSUserDefaults in tableView:setObjectValue:forTableColumn:row:

### 3. AutoLayout (Generic)
- Views added with OakAddAutoLayoutViewsToSuperview
- Constraints with NSLayoutConstraint constraintsWithVisualFormat:
- Spacer views for padding

## UI Construction Utilities

From OakAppKit:
- `OakCreateCheckBox(title)` → NSButton
- `OakCreatePopUpButton()` → NSPopUpButton
- `OakCreateLabel(text, font?)` → NSTextField (readonly)
- `OakCreateButton(title)` → NSButton
- `OakCreateNSBoxSeparator()` → visual separator
- `OakAddAutoLayoutViewsToSuperview(views, view)`

From MenuBuilder:
- `MBCreateMenu(items, menu)` - populates menu from item array
- Items use `.tag` for value mapping

## Settings/Defaults Constants (Keys.h)

Organized by section:
- **Files:** kUserDefaultsDisable{SessionRestore, NewDocumentAtStartup, NewDocumentAtReactivation}, kUserDefaultsShowFavoritesInsteadOfUntitled
- **Projects:** kUserDefaults{FoldersOnTop, ShowFileExtensions, InitialFileBrowserURL, FileBrowserPlacement, ...}
- **Bundles:** (empty, managed by BundlesManager)
- **Variables:** kUserDefaultsEnvironmentVariablesKey (NSArray of dicts)
- **Terminal:** kUserDefaults{MateInstallPath, MateInstallVersion, DisableRMateServer, RMateServerListen, RMateServerPort}
- **Appearance:** kUserDefaults{DisableAntiAlias, LineNumbers, LineNumberScaleFactor, LineNumberFontName}
- **Formatters:** kUserDefaultsFormatterConfigurationsKey
- **Advanced:** Various keys for editor, tabs, clipboard, find, file browser, bundles

Settings keys:
- kSettingsEncodingKey, kSettingsLineEndingsKey (FilesPreferences)
- kSettingsExcludeKey, kSettingsIncludeKey, kSettingsBinaryKey (ProjectsPreferences)
- Accessed via C++ settings_t API

## Creating a New Preference Pane

### Minimal Steps (PreferencesPane subclass)

1. Create header: `MyPreferences.h`
   ```objc
   #import "PreferencesPane.h"
   @interface MyPreferences : PreferencesPane
   @end
   ```

2. Create implementation: `MyPreferences.mm`
   ```objc
   #import "MyPreferences.h"
   #import "Keys.h"
   #import <OakAppKit/OakUIConstructionFunctions.h>

   @implementation MyPreferences
   - (id)init {
       if(self = [super initWithNibName:nil label:@"My Pane" image:[NSImage imageNamed:@"MyIcon"]]) {
           self.defaultsProperties = @{
               @"myCheckbox": kUserDefaultsMyKeyConstant,
           };
       }
       return self;
   }

   - (void)loadView {
       NSButton* myCheckbox = OakCreateCheckBox(@"My Option");
       NSGridView* gridView = [NSGridView gridViewWithViews:@[
           @[ OakCreateLabel(@"Settings:"), myCheckbox ],
       ]];
       self.view = OakSetupGridViewWithSeparators(gridView);
   }
   @end
   ```

3. Register in Preferences.mm (line 98):
   - Add import: `#import "MyPreferences.h"`
   - Add to viewControllers array:
     ```objc
     [[MyPreferences alloc] init],
     ```

4. Define constants in Keys.h/Keys.mm
   ```objc
   // Keys.h
   extern NSString* const kUserDefaultsMyKeyConstant;
   
   // Keys.mm
   NSString* const kUserDefaultsMyKeyConstant = @"MyKeyConstant";
   ```

5. Build: Files are auto-compiled via CMakeLists.txt glob pattern

### For Table-based Pane (Custom NSViewController)

1. Create header without inheriting from PreferencesPane
2. Adopt NSViewController + PreferencesPaneProtocol
3. Manually set identifier and title in init
4. Implement `toolbarItemImage` property
5. In loadView: create NSTableView with NSTableViewDataSource/Delegate
6. Implement table delegate/datasource methods
7. Call reloadData when data changes and save to NSUserDefaults
8. Optionally implement commitEditing for validation

## Pane Window Size

Dynamic: Window resizes to fit view's fittingSize (calculated from constraints)
- Preferences.mm: each pane's view determines its preferred size
- Grid views set fittingSize after layout
- Constraints use layout priorities for flexible sizing

## Icons

- System images: `[NSImage imageNamed:NSImageNameMultipleDocuments]`
- Custom bundle images: `[NSImage imageNamed:@"Projects" inSameBundleAsClass:[self class]]`
- SF Symbols: `[NSImage imageWithSystemSymbolName:@"hammer" accessibilityDescription:@"Formatters"]`
- All 2x retina variants provided as separate files (.png, @2x.png) in icons/ directory
