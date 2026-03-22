#import "CopilotManager.h"
#import "LSPClient.h"
#import <settings/settings.h>
#import <ns/ns.h>



NSNotificationName const CopilotStatusDidChangeNotification = @"CopilotStatusDidChangeNotification";
NSNotificationName const CopilotLogNotification             = @"CopilotLogNotification";

// copilot-node-server is a Node.js script that speaks JSON-RPC with custom Copilot methods
// The newer @github/copilot binary is a CLI agent (ACP), NOT an LSP server

@interface CopilotManager () <LSPClientDelegate>
{
	LSPClient* _client;
	NSMutableDictionary<NSString*, NSNumber*>* _documentVersions;
	NSMutableSet<NSString*>* _openURIs;
	NSMutableDictionary<NSString*, NSTimer*>* _changeTimers;
	NSHashTable<OakDocument*>* _pendingDocuments; // docs opened before server initialized
	NSInteger _restartCount;
	CopilotStatus _status;
	NSString* _username;
}
@end

@implementation CopilotManager

@synthesize status   = _status;
@synthesize username = _username;

// MARK: - Singleton

+ (instancetype)sharedManager
{
	static CopilotManager* instance;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		instance = [[CopilotManager alloc] init];
	});
	return instance;
}

- (instancetype)init
{
	if(self = [super init])
	{
		_documentVersions = [NSMutableDictionary new];
		_openURIs         = [NSMutableSet new];
		_pendingDocuments = [NSHashTable weakObjectsHashTable];
		_changeTimers     = [NSMutableDictionary new];
		_restartCount     = 0;
		_status           = CopilotStatusDisabled;
	}
	return self;
}

// MARK: - Binary Detection

- (NSString*)detectServerPath
{
	// Native arm64 binary from @github/copilot-language-server (preferred)
	static NSString* const nativeSuffix = @"node_modules/@github/copilot-language-server-darwin-arm64/copilot-language-server";
	NSArray<NSString*>* nativeRoots = @[
		@"/opt/homebrew/lib/node_modules/@github/copilot-language-server",
		[NSHomeDirectory() stringByAppendingPathComponent:@".config/yarn/global/node_modules/@github/copilot-language-server"],
		@"/usr/local/lib/node_modules/@github/copilot-language-server",
	];

	NSFileManager* fm = NSFileManager.defaultManager;
	for(NSString* root in nativeRoots)
	{
		NSString* candidate = [root stringByAppendingPathComponent:nativeSuffix];
		if([fm isExecutableFileAtPath:candidate])
		{
			[self log:[NSString stringWithFormat:@"Native server found at %@", candidate]];
			return candidate;
		}
	}

	// Fallback: copilot-node-server (legacy Node.js server)
	NSArray<NSString*>* legacyCandidates = @[
		@"/opt/homebrew/bin/copilot-node-server",
		@"/usr/local/bin/copilot-node-server",
	];
	for(NSString* candidate in legacyCandidates)
	{
		if([fm isExecutableFileAtPath:candidate])
		{
			[self log:[NSString stringWithFormat:@"Legacy server found at %@", candidate]];
			return candidate;
		}
	}

	[self log:@"Copilot language server not found"];
	return nil;
}

- (NSString*)serverPathForDocument:(OakDocument*)document
{
	if(document.path)
	{
		std::string filePath  = to_s(document.path);
		std::string fileType  = to_s(document.fileType ?: @"");
		std::string directory = to_s(document.directory ?: [document.path stringByDeletingLastPathComponent]);
		settings_t settings   = settings_for_path(filePath, fileType, directory);

		std::string customCmd = settings.get("copilotCommand", "");
		if(!customCmd.empty())
		{
			[self log:[NSString stringWithFormat:@"Using copilotCommand from settings: %s", customCmd.c_str()]];
			return to_ns(customCmd);
		}

		bool enabled = settings.get("copilotEnabled", true);
		if(!enabled)
		{
			[self log:@"Copilot disabled via copilotEnabled setting"];
			return nil;
		}
	}

	return [self detectServerPath];
}

// MARK: - Client Lifecycle

- (void)ensureClientForDocument:(OakDocument*)document
{
	if(_client.running)
		return;

	NSString* serverPath = [self serverPathForDocument:document];
	if(!serverPath)
	{
		[self log:@"Cannot start Copilot — copilot-node-server not found"];
		_status = CopilotStatusError;
		[NSNotificationCenter.defaultCenter postNotificationName:CopilotStatusDidChangeNotification object:self];
		return;
	}

	[self log:[NSString stringWithFormat:@"Starting Copilot server: %@", serverPath]];
	_status = CopilotStatusConnecting;
	[NSNotificationCenter.defaultCenter postNotificationName:CopilotStatusDidChangeNotification object:self];

	// Native copilot-language-server requires editorInfo in initializationOptions
	NSString* initOpts = @"{\"editorInfo\":{\"name\":\"TextMate\",\"version\":\"2.1\"},\"editorPluginInfo\":{\"name\":\"textmate-copilot\",\"version\":\"1.0\"}}";

	_client = [[LSPClient alloc] initWithCommand:serverPath
	                                   arguments:@[@"--stdio"]
	                            workingDirectory:NSHomeDirectory()
	                                 initOptions:initOpts];
	_client.delegate = self;

	if(!_client.running)
	{
		[self log:@"Copilot agent failed to launch"];
		_client = nil;
		_status  = CopilotStatusError;
		[NSNotificationCenter.defaultCenter postNotificationName:CopilotStatusDidChangeNotification object:self];
	}
}

- (void)shutdown
{
	[self log:@"Shutting down Copilot agent"];

	for(NSTimer* timer in _changeTimers.allValues)
		[timer invalidate];

	[_client shutdown];
	_client = nil;

	[_openURIs removeAllObjects];
	[_documentVersions removeAllObjects];
	[_changeTimers removeAllObjects];

	_status   = CopilotStatusDisabled;
	_username = nil;

	[NSNotificationCenter.defaultCenter postNotificationName:CopilotStatusDidChangeNotification object:self];
}

// MARK: - LSPClientDelegate

- (void)lspClientDidInitialize:(LSPClient*)client
{
	[self log:@"Copilot server initialized"];
	[self checkAuthStatus];
	[self flushPendingDocuments];
}

- (void)lspClientDidTerminate:(LSPClient*)client
{
	[self log:@"Copilot agent terminated"];

	_client = nil;
	[_openURIs removeAllObjects];
	[_documentVersions removeAllObjects];

	for(NSTimer* timer in _changeTimers.allValues)
		[timer invalidate];
	[_changeTimers removeAllObjects];

	_status = CopilotStatusError;
	[NSNotificationCenter.defaultCenter postNotificationName:CopilotStatusDidChangeNotification object:self];

	if(_restartCount <= 3)
	{
		_restartCount++;
		[self log:[NSString stringWithFormat:@"Scheduling restart attempt %ld in 5s", (long)_restartCount]];
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
			// Re-launch without a document — binary detection uses the cached path
			[self ensureClientForDocument:nil];
		});
	}
	else
	{
		[self log:@"Copilot agent crashed too many times — giving up"];
	}
}

- (void)lspClient:(LSPClient*)client didReceiveDiagnostics:(NSArray<NSDictionary*>*)diagnostics forDocumentURI:(NSString*)uri
{
	// Copilot does not send diagnostics; this method is required by the protocol
}

- (id)lspClient:(LSPClient*)client handleServerRequest:(NSString*)method params:(NSDictionary*)params
{
	if([method isEqualToString:@"workspace/configuration"])
	{
		[self log:@"Responding to workspace/configuration request"];

		// Copilot expects an array of configuration objects, one per requested section.
		// We reply with a single object covering the sections it typically asks for.
		NSArray* items = params[@"items"];
		NSUInteger count = items ? items.count : 1;

		NSMutableArray* configs = [NSMutableArray arrayWithCapacity:count];
		NSDictionary* config = @{
			@"github.copilot.enable": @{@"*": @YES},
			@"github.copilot.editor.enableAutoCompletions": @YES,
			@"github.copilot.advanced": @{},
		};
		for(NSUInteger i = 0; i < count; i++)
			[configs addObject:config];

		return configs;
	}

	[self log:[NSString stringWithFormat:@"Unhandled server request: %@", method]];
	return nil;
}

- (void)lspClient:(LSPClient*)client didReceiveNotification:(NSString*)method params:(NSDictionary*)params
{
	if([method isEqualToString:@"statusNotification"])
	{
		NSString* status = params[@"status"] ?: params[@"kind"];
		[self log:[NSString stringWithFormat:@"Status notification: %@", status]];

		if([status isEqualToString:@"Normal"])
		{
			if(_status != CopilotStatusReady)
				[self checkAuthStatus];
		}
		else if([status isEqualToString:@"Error"])
		{
			_status = CopilotStatusError;
			[NSNotificationCenter.defaultCenter postNotificationName:CopilotStatusDidChangeNotification object:self];
		}
	}
}

// MARK: - Authentication

- (void)checkAuthStatus
{
	[self log:@"Checking Copilot auth status"];

	// copilot-node-server uses direct JSON-RPC methods, not workspace/executeCommand
	[_client sendCustomRequest:@"checkStatus" params:@{} completion:^(id result) {
		if(![result isKindOfClass:[NSDictionary class]])
		{
			[self log:@"checkStatus returned unexpected result"];
			self->_status = CopilotStatusError;
			[NSNotificationCenter.defaultCenter postNotificationName:CopilotStatusDidChangeNotification object:self];
			return;
		}

		NSString* statusStr = result[@"status"];
		NSString* user      = result[@"user"];

		BOOL authenticated = [statusStr isEqualToString:@"OK"] || [statusStr isEqualToString:@"AlreadySignedIn"];
		if(authenticated)
		{
			self->_username = user;
			self->_status   = CopilotStatusReady;
			self->_restartCount = 0;
			[self log:[NSString stringWithFormat:@"Authenticated as %@", user ?: @"(unknown)"]];
		}
		else
		{
			self->_status = CopilotStatusAuthRequired;
			[self log:[NSString stringWithFormat:@"Auth required — status: %@", statusStr]];
		}

		[NSNotificationCenter.defaultCenter postNotificationName:CopilotStatusDidChangeNotification object:self];
	}];
}

- (void)signIn
{
	[self log:@"Starting Copilot sign-in flow"];

	[_client sendCustomRequest:@"signInInitiate" params:@{} completion:^(id result) {
		if(![result isKindOfClass:[NSDictionary class]])
		{
			[self log:@"signIn returned unexpected result"];
			return;
		}

		NSString* statusStr = result[@"status"];
		if([statusStr isEqualToString:@"AlreadySignedIn"])
		{
			[self log:@"Already signed in — refreshing status"];
			[self checkAuthStatus];
			return;
		}

		NSString* userCode        = result[@"userCode"];
		NSString* verificationUri = result[@"verificationUri"];

		if(userCode && verificationUri)
			[self showAuthPanelWithCode:userCode uri:verificationUri];
		else
			[self log:[NSString stringWithFormat:@"Unexpected signIn response: %@", result]];
	}];
}

- (void)showAuthPanelWithCode:(NSString*)code uri:(NSString*)uriString
{
	[self log:[NSString stringWithFormat:@"Showing auth panel — code: %@  uri: %@", code, uriString]];

	[[NSPasteboard generalPasteboard] clearContents];
	[[NSPasteboard generalPasteboard] setString:code forType:NSPasteboardTypeString];

	NSAlert* alert = [NSAlert new];
	alert.messageText = @"GitHub Copilot";
	alert.informativeText = [NSString stringWithFormat:
		@"Enter this code at github.com/login/device:\n\n%@\n\nThe code has been copied to your clipboard.", code];
	[alert addButtonWithTitle:@"Open Browser"];
	[alert addButtonWithTitle:@"Cancel"];

	NSWindow* window = NSApp.keyWindow ?: NSApp.mainWindow;
	if(window)
	{
		[alert beginSheetModalForWindow:window completionHandler:^(NSModalResponse response) {
			if(response == NSAlertFirstButtonReturn)
			{
				[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:uriString]];
				[self pollAuthStatusWithRetries:20 interval:3.0];
			}
		}];
	}
	else
	{
		if([alert runModal] == NSAlertFirstButtonReturn)
		{
			[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:uriString]];
			[self pollAuthStatusWithRetries:20 interval:3.0];
		}
	}
}

- (void)pollAuthStatusWithRetries:(NSInteger)remaining interval:(NSTimeInterval)interval
{
	if(remaining <= 0)
	{
		[self log:@"Auth polling timed out"];
		return;
	}

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(interval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[self log:[NSString stringWithFormat:@"Polling auth status (%ld retries left)", (long)remaining]];
		[_client sendCustomRequest:@"checkStatus" params:@{} completion:^(id result) {
			if(![result isKindOfClass:[NSDictionary class]])
			{
				[self pollAuthStatusWithRetries:remaining - 1 interval:interval];
				return;
			}

			NSString* status = result[@"status"];
			if([status isEqualToString:@"OK"] || [status isEqualToString:@"AlreadySignedIn"])
			{
				self->_username = result[@"user"];
				self->_status = CopilotStatusReady;
				self->_restartCount = 0;
				[self log:[NSString stringWithFormat:@"Authenticated as %@", self->_username ?: @"(unknown)"]];
				[NSNotificationCenter.defaultCenter postNotificationName:CopilotStatusDidChangeNotification object:self];
			}
			else
			{
				[self pollAuthStatusWithRetries:remaining - 1 interval:interval];
			}
		}];
	});
}

// MARK: - Static Helpers

static NSString* uriForDocument(OakDocument* doc)
{
	if(!doc.path)
		return nil;
	return [NSURL fileURLWithPath:doc.path].absoluteString;
}

static NSString* languageIdForDocument(OakDocument* doc)
{
	NSString* ext = doc.path.pathExtension.lowercaseString;
	static NSDictionary* map;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		map = @{
			@"py": @"python", @"js": @"javascript", @"ts": @"typescript",
			@"jsx": @"javascriptreact", @"tsx": @"typescriptreact",
			@"rb": @"ruby", @"go": @"go", @"rs": @"rust",
			@"c": @"c", @"cc": @"cpp", @"cpp": @"cpp", @"h": @"c",
			@"m": @"objective-c", @"mm": @"objective-cpp",
			@"swift": @"swift", @"java": @"java", @"php": @"php",
			@"sh": @"shellscript", @"bash": @"shellscript",
			@"json": @"json", @"yaml": @"yaml", @"yml": @"yaml",
			@"xml": @"xml", @"html": @"html", @"css": @"css",
			@"md": @"markdown", @"sql": @"sql", @"lua": @"lua",
		};
	});
	return map[ext] ?: @"plaintext";
}

// MARK: - Telemetry

- (void)sendAcceptanceTelemetry:(NSDictionary*)completionItem
{
	if(!_client.initialized || !completionItem)
		return;

	// Native server: completion item has "command" with command name + arguments
	NSDictionary* command = completionItem[@"command"];
	if(command)
	{
		NSString* cmd = command[@"command"];
		NSArray* args = command[@"arguments"];
		if(cmd)
			[_client executeCommand:cmd arguments:args completion:nil];
	}
}

- (void)sendDidShowCompletion:(NSDictionary*)completionItem
{
	if(!_client.initialized || !completionItem)
		return;

	[_client sendCustomNotification:@"textDocument/didShowCompletion" params:@{@"item": completionItem}];
}

- (void)flushPendingDocuments
{
	if(_pendingDocuments.count == 0)
		return;

	[self log:[NSString stringWithFormat:@"Flushing %lu pending documents", (unsigned long)_pendingDocuments.count]];
	for(OakDocument* doc in [_pendingDocuments allObjects])
	{
		NSString* uri = uriForDocument(doc);
		if(uri)
			[self sendDidOpenForDocument:doc uri:uri];
	}
	[_pendingDocuments removeAllObjects];
}

// MARK: - Document Sync

- (void)documentDidOpen:(OakDocument*)document
{
	[self ensureClientForDocument:document];

	NSString* uri = uriForDocument(document);
	if(!uri)
		return;

	if(!_client.initialized)
	{
		[_pendingDocuments addObject:document];
		[self log:[NSString stringWithFormat:@"Queued pending document: %@", uri.lastPathComponent]];
		return;
	}

	[self sendDidOpenForDocument:document uri:uri];
}

- (void)sendDidOpenForDocument:(OakDocument*)document uri:(NSString*)uri
{
	if([_openURIs containsObject:uri])
		return;

	[_openURIs addObject:uri];
	_documentVersions[uri] = @1;

	NSDictionary* params = @{
		@"textDocument": @{
			@"uri":        uri,
			@"languageId": languageIdForDocument(document),
			@"version":    @1,
			@"text":       document.content ?: @"",
		}
	};
	[_client sendCustomNotification:@"textDocument/didOpen" params:params];
	[self log:[NSString stringWithFormat:@"didOpen %@ (%@)", uri.lastPathComponent, languageIdForDocument(document)]];
}

- (void)documentDidChange:(OakDocument*)document
{
	NSString* uri = uriForDocument(document);
	if(!uri || ![_openURIs containsObject:uri])
		return;

	[_changeTimers[uri] invalidate];

	NSTimer* timer = [NSTimer scheduledTimerWithTimeInterval:0.3
	                                                 repeats:NO
	                                                   block:^(NSTimer* t) {
		[self flushChangeForDocument:document uri:uri];
	}];
	_changeTimers[uri] = timer;
}

- (void)flushChangeForDocument:(OakDocument*)document uri:(NSString*)uri
{
	NSInteger version = [_documentVersions[uri] integerValue] + 1;
	_documentVersions[uri] = @(version);

	NSDictionary* params = @{
		@"textDocument": @{
			@"uri":     uri,
			@"version": @(version),
		},
		@"contentChanges": @[ @{ @"text": document.content ?: @"" } ],
	};
	[_client sendCustomNotification:@"textDocument/didChange" params:params];
}

- (void)documentDidSave:(OakDocument*)document
{
	NSString* uri = uriForDocument(document);
	if(!uri || ![_openURIs containsObject:uri])
		return;

	// Flush any pending debounced change before the save notification
	NSTimer* pending = _changeTimers[uri];
	if(pending.valid)
	{
		[pending invalidate];
		[self flushChangeForDocument:document uri:uri];
	}
	[_changeTimers removeObjectForKey:uri];

	NSDictionary* params = @{
		@"textDocument": @{ @"uri": uri }
	};
	[_client sendCustomNotification:@"textDocument/didSave" params:params];
}

- (void)documentWillClose:(OakDocument*)document
{
	NSString* uri = uriForDocument(document);
	if(!uri)
		return;

	[_changeTimers[uri] invalidate];
	[_changeTimers removeObjectForKey:uri];
	[_openURIs removeObject:uri];
	[_documentVersions removeObjectForKey:uri];

	if(!_client.initialized)
		return;

	NSDictionary* params = @{
		@"textDocument": @{ @"uri": uri }
	};
	[_client sendCustomNotification:@"textDocument/didClose" params:params];
}

- (void)documentDidFocus:(OakDocument*)document
{
	[self ensureClientForDocument:document];
	if(!_client.initialized)
		return;

	NSString* uri = uriForDocument(document);
	if(!uri)
		return;

	NSDictionary* params = @{
		@"textDocument": @{ @"uri": uri }
	};
	[_client sendCustomNotification:@"textDocument/didFocus" params:params];
}

// MARK: - Completion

- (void)requestCompletionForDocument:(OakDocument*)document
                                line:(NSUInteger)line
                           character:(NSUInteger)character
                          completion:(void(^)(NSArray<NSDictionary*>* items))callback
{
	NSString* uri = uriForDocument(document);
	if(!uri || !_client.initialized)
	{
		[self log:[NSString stringWithFormat:@"Cannot request completion: uri=%@ initialized=%d", uri, _client.initialized]];
		if(callback)
			callback(nil);
		return;
	}

	if(![_openURIs containsObject:uri])
	{
		[self log:[NSString stringWithFormat:@"Document not open on server, opening now: %@", uri.lastPathComponent]];
		[self sendDidOpenForDocument:document uri:uri];
	}

	// Flush any pending debounced change so the server sees the latest content
	NSTimer* pending = _changeTimers[uri];
	if(pending.valid)
	{
		[pending invalidate];
		[self flushChangeForDocument:document uri:uri];
		[_changeTimers removeObjectForKey:uri];
	}

	[self log:[NSString stringWithFormat:@"Requesting inlineCompletion at %lu:%lu %@", (unsigned long)line, (unsigned long)character, uri.lastPathComponent]];

	NSDictionary* params = @{
		@"textDocument": @{@"uri": uri},
		@"position":     @{@"line": @(line), @"character": @(character)},
		@"context":      @{@"triggerKind": @1},
	};

	[_client sendCustomRequest:@"textDocument/inlineCompletion"
	                    params:params
	                completion:^(id result) {
		NSArray* items = nil;
		if([result isKindOfClass:[NSDictionary class]])
			items = result[@"items"];
		else if([result isKindOfClass:[NSArray class]])
			items = result;

		[self log:[NSString stringWithFormat:@"Completion result: %lu items", (unsigned long)items.count]];

		if(callback)
			callback(items);
	}];
}

// MARK: - Logging

- (void)log:(NSString*)message
{
	NSLog(@"[Copilot] %@", message);
	[NSNotificationCenter.defaultCenter postNotificationName:CopilotLogNotification
	                                                  object:self
	                                                userInfo:@{@"message": message}];
}

@end
