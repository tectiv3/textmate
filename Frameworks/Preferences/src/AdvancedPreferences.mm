#import "AdvancedPreferences.h"
#import "Keys.h"
#import <OakAppKit/OakUIConstructionFunctions.h>
#import <MenuBuilder/MenuBuilder.h>

@implementation AdvancedPreferences
- (id)init
{
	if(self = [super initWithNibName:nil label:@"Advanced" image:[NSImage imageWithSystemSymbolName:@"gearshape.2" accessibilityDescription:@"Advanced"]])
	{
		self.defaultsProperties = @{
			@"disableTypingPairs":                  kUserDefaultsDisableTypingPairsKey,
			@"disableAntiAlias":                    kUserDefaultsDisableAntiAliasKey,
			@"fontSmoothing":                       kUserDefaultsFontSmoothingKey,
			@"hideStatusBar":                       kUserDefaultsHideStatusBarKey,
			@"showFavoritesInsteadOfUntitled":      kUserDefaultsShowFavoritesInsteadOfUntitledKey,
			@"lineNumberFontName":                  kUserDefaultsLineNumberFontNameKey,
			@"lineNumberScaleFactor":               kUserDefaultsLineNumberScaleFactorKey,
			@"tabItemMinWidth":                     kUserDefaultsTabItemMinWidthKey,
			@"tabItemMaxWidth":                     kUserDefaultsTabItemMaxWidthKey,
			@"disablePersistentClipboardHistory":   kUserDefaultsDisablePersistentClipboardHistory,
			@"clipboardHistoryKeepAtLeast":          kUserDefaultsClipboardHistoryKeepAtLeast,
			@"clipboardHistoryKeepAtMost":           kUserDefaultsClipboardHistoryKeepAtMost,
			@"clipboardHistoryDaysToKeep":           kUserDefaultsClipboardHistoryDaysToKeep,
			@"keepSearchResultsOnDoubleClick":       kUserDefaultsKeepSearchResultsOnDoubleClick,
			@"alwaysFindInDocument":                 kUserDefaultsAlwaysFindInDocument,
			@"fileBrowserOpenAnimationDisabled":     kUserDefaultsFileBrowserOpenAnimationDisabled,
			@"disableFolderStateRestore":            kUserDefaultsDisableFolderStateRestore,
			@"disableBundleSuggestions":             kUserDefaultsDisableBundleSuggestionsKey,
		};
	}
	return self;
}

- (NSString*)grammarsToNeverSuggest
{
	NSArray* arr = [NSUserDefaults.standardUserDefaults stringArrayForKey:kUserDefaultsGrammarsToNeverSuggestKey];
	return [arr componentsJoinedByString:@", "];
}

- (void)setGrammarsToNeverSuggest:(NSString*)value
{
	NSArray* components = [value componentsSeparatedByString:@","];
	NSMutableArray* trimmed = [NSMutableArray array];
	for(NSString* s in components)
	{
		NSString* t = [s stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
		if(t.length)
			[trimmed addObject:t];
	}
	[NSUserDefaults.standardUserDefaults setObject:trimmed forKey:kUserDefaultsGrammarsToNeverSuggestKey];
}

- (void)loadView
{
	NSButton* disableTypingPairsCheckBox              = OakCreateCheckBox(@"Disable typing pairs");
	NSButton* disableAntiAliasCheckBox                = OakCreateCheckBox(@"Disable text anti-aliasing");
	NSPopUpButton* fontSmoothingPopUp                 = OakCreatePopUpButton();
	NSButton* hideStatusBarCheckBox                   = OakCreateCheckBox(@"Hide status bar");
	NSButton* showFavoritesCheckBox                   = OakCreateCheckBox(@"Show favorites instead of untitled");

	NSTextField* lineNumberFontField                  = [NSTextField textFieldWithString:@""];
	NSTextField* lineNumberScaleField                 = [NSTextField textFieldWithString:@""];
	NSTextField* tabMinWidthField                     = [NSTextField textFieldWithString:@""];
	NSTextField* tabMaxWidthField                     = [NSTextField textFieldWithString:@""];

	NSButton* disablePersistentClipboardCheckBox      = OakCreateCheckBox(@"Disable persistent clipboard history");
	NSTextField* clipboardKeepAtLeastField             = [NSTextField textFieldWithString:@""];
	NSTextField* clipboardKeepAtMostField              = [NSTextField textFieldWithString:@""];
	NSTextField* clipboardDaysToKeepField              = [NSTextField textFieldWithString:@""];

	NSButton* keepSearchResultsCheckBox               = OakCreateCheckBox(@"Keep search results on double-click");
	NSButton* alwaysFindInDocumentCheckBox             = OakCreateCheckBox(@"Always find in document");

	NSButton* disableOpenAnimationCheckBox             = OakCreateCheckBox(@"Disable open animation");
	NSButton* disableFolderStateRestoreCheckBox        = OakCreateCheckBox(@"Disable folder state restore");

	NSButton* disableBundleSuggestionsCheckBox         = OakCreateCheckBox(@"Disable bundle suggestions");
	NSTextField* grammarsToNeverSuggestField           = [NSTextField textFieldWithString:@""];

	MBMenu const fontSmoothingItems = {
		{ @"Disabled",                                      .tag = 0 },
		{ @"Enabled",                                       .tag = 1 },
		{ @"Disabled for dark themes",                      .tag = 2 },
		{ @"Disabled for dark themes on HiDPI (default)",   .tag = 3 },
	};
	MBCreateMenu(fontSmoothingItems, fontSmoothingPopUp.menu);

	for(NSTextField* field in @[ lineNumberFontField, lineNumberScaleField, tabMinWidthField, tabMaxWidthField, clipboardKeepAtLeastField, clipboardKeepAtMostField, clipboardDaysToKeepField, grammarsToNeverSuggestField ])
		[field.widthAnchor constraintEqualToConstant:360].active = YES;

	NSFont* hintFont = [NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:NSControlSizeSmall]];
	NSColor* hintColor = NSColor.secondaryLabelColor;

	NSTextField* (^makeHint)(NSString*) = ^NSTextField* (NSString* text) {
		NSTextField* label = OakCreateLabel(text, hintFont);
		label.textColor = hintColor;
		label.lineBreakMode = NSLineBreakByWordWrapping;
		label.maximumNumberOfLines = 2;
		return label;
	};

	NSGridView* gridView = [NSGridView gridViewWithViews:@[
		// Editor — rows 0-9
		@[ OakCreateLabel(@"Editor:"),       disableTypingPairsCheckBox ],                                                  // 0
		@[ NSGridCell.emptyContentView,      makeHint(@"Stops auto-closing of brackets, quotes, and other paired characters") ], // 1
		@[ NSGridCell.emptyContentView,      disableAntiAliasCheckBox ],                                                   // 2
		@[ NSGridCell.emptyContentView,      makeHint(@"Disables text anti-aliasing for a sharper, aliased look") ],       // 3
		@[ NSGridCell.emptyContentView,      fontSmoothingPopUp ],                                                         // 4
		@[ NSGridCell.emptyContentView,      makeHint(@"Controls subpixel font smoothing behavior by theme and display type") ], // 5
		@[ NSGridCell.emptyContentView,      hideStatusBarCheckBox ],                                                      // 6
		@[ NSGridCell.emptyContentView,      makeHint(@"Hides the status bar at the bottom of the editor window") ],       // 7
		@[ NSGridCell.emptyContentView,      showFavoritesCheckBox ],                                                      // 8
		@[ NSGridCell.emptyContentView,      makeHint(@"Shows the favorites dialog instead of an empty document at startup") ], // 9

		@[ ], // 10 — separator

		// Appearance — rows 11-18
		@[ OakCreateLabel(@"Line number font:"), lineNumberFontField ],                                                    // 11
		@[ NSGridCell.emptyContentView,      makeHint(@"PostScript font name for the gutter (e.g. Menlo-Regular)") ],      // 12
		@[ OakCreateLabel(@"Line number scale:"), lineNumberScaleField ],                                                  // 13
		@[ NSGridCell.emptyContentView,      makeHint(@"Scale factor relative to editor font size (default 0.8)") ],       // 14
		@[ OakCreateLabel(@"Min tab width:"), tabMinWidthField ],                                                          // 15
		@[ NSGridCell.emptyContentView,      makeHint(@"Minimum pixel width for document tabs (default 120)") ],           // 16
		@[ OakCreateLabel(@"Max tab width:"), tabMaxWidthField ],                                                          // 17
		@[ NSGridCell.emptyContentView,      makeHint(@"Maximum pixel width for document tabs (default 250)") ],           // 18

		@[ ], // 19 — separator

		// Clipboard — rows 20-27
		@[ OakCreateLabel(@"Clipboard:"),    disablePersistentClipboardCheckBox ],                                         // 20
		@[ NSGridCell.emptyContentView,      makeHint(@"Uses in-memory database only; clipboard history is lost on quit") ], // 21
		@[ OakCreateLabel(@"Keep at least:"), clipboardKeepAtLeastField ],                                                 // 22
		@[ NSGridCell.emptyContentView,      makeHint(@"Minimum number of clipboard entries to retain (default 25)") ],    // 23
		@[ OakCreateLabel(@"Keep at most:"), clipboardKeepAtMostField ],                                                   // 24
		@[ NSGridCell.emptyContentView,      makeHint(@"Maximum clipboard entries before pruning (default 500)") ],        // 25
		@[ OakCreateLabel(@"Days to keep:"), clipboardDaysToKeepField ],                                                   // 26
		@[ NSGridCell.emptyContentView,      makeHint(@"Entries older than this are pruned (default 30)") ],               // 27

		@[ ], // 28 — separator

		// Find — rows 29-32
		@[ OakCreateLabel(@"Find:"),         keepSearchResultsCheckBox ],                                                  // 29
		@[ NSGridCell.emptyContentView,      makeHint(@"Keeps the Find in Folder results window open after double-clicking a match") ], // 30
		@[ NSGridCell.emptyContentView,      alwaysFindInDocumentCheckBox ],                                               // 31
		@[ NSGridCell.emptyContentView,      makeHint(@"Find always searches the full document, even when text is selected") ], // 32

		@[ ], // 33 — separator

		// File Browser — rows 34-37
		@[ OakCreateLabel(@"File Browser:"), disableOpenAnimationCheckBox ],                                               // 34
		@[ NSGridCell.emptyContentView,      makeHint(@"Disables the expand/collapse animation in the file browser") ],    // 35
		@[ NSGridCell.emptyContentView,      disableFolderStateRestoreCheckBox ],                                          // 36
		@[ NSGridCell.emptyContentView,      makeHint(@"Stops restoring expanded/collapsed folder state when reopening projects") ], // 37

		@[ ], // 38 — separator

		// Bundles — rows 39-42
		@[ OakCreateLabel(@"Bundles:"),      disableBundleSuggestionsCheckBox ],                                           // 39
		@[ NSGridCell.emptyContentView,      makeHint(@"Stops suggesting bundle installation for unrecognized file types") ], // 40
		@[ OakCreateLabel(@"Never suggest for:"), grammarsToNeverSuggestField ],                                           // 41
		@[ NSGridCell.emptyContentView,      makeHint(@"Comma-separated list of grammar UUIDs to exclude from suggestions") ], // 42
	]];

	NSView* content = OakSetupGridViewWithSeparators(gridView, { 10, 19, 28, 33, 38 });

	NSScrollView* scrollView = [[NSScrollView alloc] init];
	scrollView.documentView = content;
	scrollView.hasVerticalScroller = YES;
	scrollView.drawsBackground = NO;
	scrollView.automaticallyAdjustsContentInsets = NO;
	scrollView.contentInsets = NSEdgeInsetsMake(0, 0, 0, 0);

	content.translatesAutoresizingMaskIntoConstraints = NO;
	[content.widthAnchor constraintEqualToAnchor:scrollView.contentView.widthAnchor].active = YES;

	[scrollView setFrameSize:NSMakeSize(content.fittingSize.width, 400)];

	self.view = scrollView;

	// Editor bindings
	[disableTypingPairsCheckBox bind:NSValueBinding toObject:self withKeyPath:@"disableTypingPairs" options:nil];
	[disableAntiAliasCheckBox   bind:NSValueBinding toObject:self withKeyPath:@"disableAntiAlias"   options:nil];
	[fontSmoothingPopUp         bind:NSSelectedTagBinding toObject:self withKeyPath:@"fontSmoothing" options:nil];
	[hideStatusBarCheckBox      bind:NSValueBinding toObject:self withKeyPath:@"hideStatusBar"      options:nil];
	[showFavoritesCheckBox      bind:NSValueBinding toObject:self withKeyPath:@"showFavoritesInsteadOfUntitled" options:nil];

	// Appearance bindings
	[lineNumberFontField  bind:NSValueBinding toObject:self withKeyPath:@"lineNumberFontName"      options:@{ NSNullPlaceholderBindingOption: @"Uses editor font when blank" }];
	[lineNumberScaleField bind:NSValueBinding toObject:self withKeyPath:@"lineNumberScaleFactor"    options:@{ NSNullPlaceholderBindingOption: @"0.8" }];
	[tabMinWidthField     bind:NSValueBinding toObject:self withKeyPath:@"tabItemMinWidth"          options:@{ NSNullPlaceholderBindingOption: @"120" }];
	[tabMaxWidthField     bind:NSValueBinding toObject:self withKeyPath:@"tabItemMaxWidth"          options:@{ NSNullPlaceholderBindingOption: @"250" }];

	// Clipboard bindings
	[disablePersistentClipboardCheckBox bind:NSValueBinding toObject:self withKeyPath:@"disablePersistentClipboardHistory" options:nil];
	[clipboardKeepAtLeastField bind:NSValueBinding toObject:self withKeyPath:@"clipboardHistoryKeepAtLeast" options:@{ NSNullPlaceholderBindingOption: @"25" }];
	[clipboardKeepAtMostField  bind:NSValueBinding toObject:self withKeyPath:@"clipboardHistoryKeepAtMost"  options:@{ NSNullPlaceholderBindingOption: @"500" }];
	[clipboardDaysToKeepField  bind:NSValueBinding toObject:self withKeyPath:@"clipboardHistoryDaysToKeep"  options:@{ NSNullPlaceholderBindingOption: @"30" }];

	// Find bindings
	[keepSearchResultsCheckBox    bind:NSValueBinding toObject:self withKeyPath:@"keepSearchResultsOnDoubleClick" options:nil];
	[alwaysFindInDocumentCheckBox bind:NSValueBinding toObject:self withKeyPath:@"alwaysFindInDocument"           options:nil];

	// File Browser bindings
	[disableOpenAnimationCheckBox       bind:NSValueBinding toObject:self withKeyPath:@"fileBrowserOpenAnimationDisabled" options:nil];
	[disableFolderStateRestoreCheckBox  bind:NSValueBinding toObject:self withKeyPath:@"disableFolderStateRestore"        options:nil];

	// Bundles bindings
	[disableBundleSuggestionsCheckBox bind:NSValueBinding toObject:self withKeyPath:@"disableBundleSuggestions"    options:nil];
	[grammarsToNeverSuggestField      bind:NSValueBinding toObject:self withKeyPath:@"grammarsToNeverSuggest"     options:@{ NSNullPlaceholderBindingOption: @"Comma-separated grammar UUIDs" }];
}
@end
