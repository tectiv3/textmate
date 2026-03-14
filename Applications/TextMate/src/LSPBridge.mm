#import "LSPBridge.h"
#import "OakSwiftUI-Swift.h"
#import <lsp/LSPClient.h>

@implementation LSPBridge

+ (void)toggleLogPanel
{
	[[OakLogPanel shared] toggle];
}

+ (void)setup
{
	static LSPBridge* instance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		instance = [[LSPBridge alloc] init];
	});
}

- (instancetype)init
{
	if(self = [super init])
	{
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleLog:) name:LSPLogNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleShowMessage:) name:LSPShowMessageNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleProgress:) name:LSPProgressNotification object:nil];
	}
	return self;
}

- (void)handleLog:(NSNotification*)note
{
	NSString* message = note.userInfo[@"message"];
	if(!message) return;

	NSNumber* type = note.userInfo[@"type"];
	int level = type ? type.intValue : 3; // Default to Info
	NSString* source = note.userInfo[@"source"] ?: @"LSP";

	dispatch_async(dispatch_get_main_queue(), ^{
		[OakLogPanel.shared logWithMessage:message level:level source:source];

		if([message containsString:@"Server initialized successfully"])
			[OakNotificationManager.shared showWithMessage:@"LSP Server Initialized" type:4];
	});
}

- (void)handleShowMessage:(NSNotification*)note
{
	NSString* message = note.userInfo[@"message"];
	NSNumber* type = note.userInfo[@"type"];
	if(!message) return;

	dispatch_async(dispatch_get_main_queue(), ^{
		[OakNotificationManager.shared showWithMessage:message type:type ? type.intValue : 3];
	});
}

- (void)handleProgress:(NSNotification*)note
{
	NSString* kind = note.userInfo[@"kind"];
	NSString* title = note.userInfo[@"title"];
	NSString* message = note.userInfo[@"message"];
	NSNumber* percentage = note.userInfo[@"percentage"];

	if([kind isEqualToString:@"end"])
		return;

	NSMutableString* display = [NSMutableString string];
	if(title) [display appendString:title];
	if(message) {
		if(display.length > 0) [display appendString:@": "];
		[display appendString:message];
	}
	if(percentage) {
		if(display.length > 0) [display appendString:@" "];
		[display appendFormat:@"(%d%%)", percentage.intValue];
	}

	if(display.length > 0)
	{
		dispatch_async(dispatch_get_main_queue(), ^{
			[OakNotificationManager.shared showWithMessage:display type:3];
		});
	}
}

@end
