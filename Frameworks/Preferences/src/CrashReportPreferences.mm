#import "CrashReportPreferences.h"
#import "Keys.h"
#import <OakAppKit/OakUIConstructionFunctions.h>

@implementation CrashReportPreferences
- (id)init
{
	if(self = [super initWithNibName:nil label:@"Crash Reports" image:[NSImage imageWithSystemSymbolName:@"exclamationmark.triangle" accessibilityDescription:@"Crash Reports"]])
	{
	}
	return self;
}

- (void)loadView
{
	NSButton* submitCrashReportsCheckBox = OakCreateCheckBox(@"Submit to MacroMates");

	NSFont* smallFont = [NSFont messageFontOfSize:[NSFont systemFontSizeForControlSize:NSControlSizeSmall]];
	NSTextField* contactTextField = [NSTextField textFieldWithString:@"Anonymous"];
	contactTextField.font        = smallFont;
	contactTextField.controlSize = NSControlSizeSmall;

	NSStackView* contactStackView = [NSStackView stackViewWithViews:@[
		OakCreateLabel(@"Contact:", smallFont), contactTextField
	]];
	contactStackView.alignment  = NSLayoutAttributeFirstBaseline;
	contactStackView.edgeInsets = { .left = 18 };
	[contactStackView setHuggingPriority:NSLayoutPriorityDefaultHigh-1 forOrientation:NSLayoutConstraintOrientationVertical];

	NSGridView* gridView = [NSGridView gridViewWithViews:@[
		@[ OakCreateLabel(@"Crash reports:"), submitCrashReportsCheckBox ],
		@[ NSGridCell.emptyContentView,       contactStackView          ],
	]];

	self.view = OakSetupGridViewWithSeparators(gridView, { });

	[submitCrashReportsCheckBox bind:NSValueBinding   toObject:NSUserDefaultsController.sharedUserDefaultsController withKeyPath:[NSString stringWithFormat:@"values.%@", kUserDefaultsDisableCrashReportingKey]   options:@{ NSValueTransformerNameBindingOption: NSNegateBooleanTransformerName }];
	[contactTextField           bind:NSValueBinding   toObject:NSUserDefaultsController.sharedUserDefaultsController withKeyPath:[NSString stringWithFormat:@"values.%@", kUserDefaultsCrashReportsContactInfoKey] options:nil];
	[contactTextField           bind:NSEnabledBinding toObject:NSUserDefaultsController.sharedUserDefaultsController withKeyPath:[NSString stringWithFormat:@"values.%@", kUserDefaultsDisableCrashReportingKey]   options:@{ NSValueTransformerNameBindingOption: NSNegateBooleanTransformerName }];
}
@end
