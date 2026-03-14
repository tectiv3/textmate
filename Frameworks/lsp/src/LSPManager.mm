#import "LSPManager.h"
#import "LSPClient.h"
#import <settings/settings.h>
#import <text/types.h>
#import <io/path.h>
#import <ns/ns.h>

static NSDictionary<NSString*, NSString*>* scopeToLanguageId ()
{
	static NSDictionary* map = @{
		@"source.php"           : @"php",
		@"source.c"             : @"c",
		@"source.c++"          : @"cpp",
		@"source.objc"          : @"objective-c",
		@"source.objc++"       : @"objective-cpp",
		@"source.js"            : @"javascript",
		@"source.ts"            : @"typescript",
		@"source.python"        : @"python",
		@"source.go"            : @"go",
		@"source.rust"          : @"rust",
		@"source.ruby"          : @"ruby",
		@"source.java"          : @"java",
		@"source.json"          : @"json",
		@"source.css"           : @"css",
		@"source.html"          : @"html",
		@"source.shell"         : @"shellscript",
		@"source.yaml"          : @"yaml",
		@"source.swift"         : @"swift",
		@"text.html.markdown"   : @"markdown",
	};
	return map;
}

static NSString* languageIdForScope (NSString* fileType)
{
	if(!fileType)
		return @"plaintext";

	NSDictionary* map = scopeToLanguageId();

	// Try progressively shorter scope prefixes for best match
	NSString* scope = fileType;
	while(scope.length > 0)
	{
		NSString* langId = map[scope];
		if(langId)
			return langId;

		NSRange lastDot = [scope rangeOfString:@"." options:NSBackwardsSearch];
		if(lastDot.location == NSNotFound)
			break;
		scope = [scope substringToIndex:lastDot.location];
	}

	// Fallback: strip "source." prefix and use remainder
	if([fileType hasPrefix:@"source."])
		return [fileType substringFromIndex:7];

	return @"plaintext";
}

static NSString* languageIdForExtension (NSString* ext)
{
	if(!ext.length)
		return @"plaintext";

	static NSDictionary* map = @{
		@"php"  : @"php",
		@"c"    : @"c",
		@"h"    : @"c",
		@"cc"   : @"cpp",
		@"cpp"  : @"cpp",
		@"cxx"  : @"cpp",
		@"hpp"  : @"cpp",
		@"m"    : @"objective-c",
		@"mm"   : @"objective-cpp",
		@"js"   : @"javascript",
		@"jsx"  : @"javascript",
		@"ts"   : @"typescript",
		@"tsx"  : @"typescript",
		@"py"   : @"python",
		@"go"   : @"go",
		@"rs"   : @"rust",
		@"rb"   : @"ruby",
		@"java" : @"java",
		@"json" : @"json",
		@"css"  : @"css",
		@"html" : @"html",
		@"htm"  : @"html",
		@"sh"   : @"shellscript",
		@"bash" : @"shellscript",
		@"zsh"  : @"shellscript",
		@"yaml" : @"yaml",
		@"yml"  : @"yaml",
		@"xml"  : @"xml",
		@"sql"  : @"sql",
		@"lua"  : @"lua",
		@"swift": @"swift",
		@"md"   : @"markdown",
		@"vue"  : @"vue",
	};

	NSString* langId = map[ext.lowercaseString];
	return langId ?: ext.lowercaseString;
}

static std::vector<std::string> const& workspaceMarkers ()
{
	static std::vector<std::string> const markers = {
		".git", "composer.json", "package.json", "tsconfig.json",
		"CMakeLists.txt", "compile_commands.json", "go.mod",
		"Cargo.toml", "pyproject.toml", "setup.py", ".clangd"
	};
	return markers;
}

static std::string detectWorkspaceRoot (std::string const& filePath)
{
	std::string dir = path::parent(filePath);
	std::string previousDir;

	while(dir != previousDir && dir != "/")
	{
		for(auto const& marker : workspaceMarkers())
		{
			if(path::exists(path::join(dir, marker)))
				return dir;
		}
		previousDir = dir;
		dir = path::parent(dir);
	}

	// No marker found — use file's directory
	return path::parent(filePath);
}

@interface LSPManager () <LSPClientDelegate>
{
	NSMutableDictionary<NSString*, LSPClient*>*  _clients;
	NSMutableDictionary<NSUUID*, LSPClient*>*    _documentClients;
	NSMutableDictionary<NSUUID*, NSNumber*>*     _documentVersions;
	NSMutableSet<NSUUID*>*                       _openDocuments;
	NSMutableDictionary<NSUUID*, NSTimer*>*      _changeTimers;
}
@end

@implementation LSPManager
+ (instancetype)sharedManager
{
	static LSPManager* instance;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		instance = [LSPManager new];
	});
	return instance;
}

- (instancetype)init
{
	if(self = [super init])
	{
		_clients          = [NSMutableDictionary new];
		_documentClients  = [NSMutableDictionary new];
		_documentVersions = [NSMutableDictionary new];
		_openDocuments    = [NSMutableSet new];
		_changeTimers     = [NSMutableDictionary new];

		[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(applicationWillTerminate:) name:NSApplicationWillTerminateNotification object:nil];
	}
	return self;
}

- (void)applicationWillTerminate:(NSNotification*)notification
{
	[self shutdownAll];
}

- (LSPClient*)clientForDocument:(OakDocument*)document
{
	if(!document.path)
		return nil;

	std::string filePath  = to_s(document.path);
	std::string fileType  = to_s(document.fileType);
	std::string directory = to_s(document.directory ?: [document.path stringByDeletingLastPathComponent]);

	settings_t settings = settings_for_path(filePath, fileType, directory);

	std::string lspCommand = settings.get("lspCommand", "");
	if(lspCommand.empty())
		return nil;

	bool lspEnabled = settings.get("lspEnabled", true);
	if(!lspEnabled)
		return nil;

	// Determine workspace root
	std::string rootPath = settings.get("lspRootPath", "");
	if(rootPath.empty())
		rootPath = detectWorkspaceRoot(filePath);

	NSString* root = to_ns(rootPath);
	LSPClient* client = _clients[root];
	if(client)
		return client;

	// Parse command: first whitespace-delimited token is executable, rest are args
	std::vector<std::string> parts = path::unescape(lspCommand);
	if(parts.empty())
		return nil;

	NSString* executable = to_ns(parts[0]);
	NSMutableArray<NSString*>* args = [NSMutableArray new];
	for(size_t i = 1; i < parts.size(); ++i)
		[args addObject:to_ns(parts[i])];

	client = [[LSPClient alloc] initWithCommand:executable arguments:args workingDirectory:root];
	client.delegate = self;
	_clients[root] = client;
	return client;
}

- (void)documentDidOpen:(OakDocument*)document
{
	NSUUID* docId = document.identifier;
	if([_openDocuments containsObject:docId])
		return;

	LSPClient* client = [self clientForDocument:document];
	if(!client)
		return;

	[_openDocuments addObject:docId];
	_documentClients[docId]  = client;
	_documentVersions[docId] = @1;

	NSString* langId = languageIdForScope(document.fileType);
	if([langId isEqualToString:@"plaintext"] && document.path)
		langId = languageIdForExtension(document.path.pathExtension);
	[client openDocument:document languageId:langId];
}

- (void)documentDidChange:(OakDocument*)document
{
	NSUUID* docId = document.identifier;
	if(![_openDocuments containsObject:docId])
		return;

	[_changeTimers[docId] invalidate];

	__weak LSPManager* weakSelf = self;
	_changeTimers[docId] = [NSTimer scheduledTimerWithTimeInterval:0.3 repeats:NO block:^(NSTimer* timer) {
		[weakSelf sendDidChangeForDocument:document];
	}];
}

- (void)sendDidChangeForDocument:(OakDocument*)document
{
	NSUUID* docId = document.identifier;
	[_changeTimers removeObjectForKey:docId];

	LSPClient* client = _documentClients[docId];
	if(!client)
		return;

	int version = [_documentVersions[docId] intValue] + 1;
	_documentVersions[docId] = @(version);
	[client documentDidChange:document version:version];
}

- (void)documentDidSave:(OakDocument*)document
{
	NSUUID* docId = document.identifier;
	if(![_openDocuments containsObject:docId])
		return;

	// Flush any pending change notification
	if(_changeTimers[docId])
	{
		[_changeTimers[docId] invalidate];
		[self sendDidChangeForDocument:document];
	}

	LSPClient* client = _documentClients[docId];
	if(client)
		[client documentDidSave:document];
}

- (void)documentWillClose:(OakDocument*)document
{
	NSUUID* docId = document.identifier;
	if(![_openDocuments containsObject:docId])
		return;

	[_changeTimers[docId] invalidate];
	[_changeTimers removeObjectForKey:docId];

	LSPClient* client = _documentClients[docId];
	if(client)
		[client closeDocument:document];

	[_openDocuments removeObject:docId];
	[_documentClients removeObjectForKey:docId];
	[_documentVersions removeObjectForKey:docId];
}

- (void)shutdownAll
{
	for(NSTimer* timer in _changeTimers.allValues)
		[timer invalidate];
	[_changeTimers removeAllObjects];

	for(LSPClient* client in _clients.allValues)
		[client shutdown];

	[_clients removeAllObjects];
	[_documentClients removeAllObjects];
	[_documentVersions removeAllObjects];
	[_openDocuments removeAllObjects];
}

- (void)flushPendingChangesForDocument:(OakDocument*)document
{
	NSUUID* docId = document.identifier;
	if(![_openDocuments containsObject:docId])
		return;

	// Cancel any pending debounce timer
	[_changeTimers[docId] invalidate];
	[_changeTimers removeObjectForKey:docId];

	// Always send current content so server has latest state
	LSPClient* client = _documentClients[docId];
	if(!client)
		return;

	int version = [_documentVersions[docId] intValue] + 1;
	_documentVersions[docId] = @(version);
	[client documentDidChange:document version:version];
}

- (void)requestCompletionsForDocument:(OakDocument*)document line:(NSUInteger)line character:(NSUInteger)character prefix:(NSString*)prefix completion:(void(^)(NSArray<NSDictionary*>*))callback
{
	NSUUID* docId = document.identifier;
	LSPClient* client = _documentClients[docId];
	if(!client)
	{
		if(callback)
			callback(@[]);
		return;
	}

	NSString* path = document.path;
	if(!path)
	{
		if(callback)
			callback(@[]);
		return;
	}

	NSURL* fileURL = [NSURL fileURLWithPath:path];
	NSString* uri = fileURL.absoluteString;

	[client requestCompletionForURI:uri line:line character:character completion:^(NSArray<NSDictionary*>* suggestions) {
		if(callback)
			callback(suggestions);
	}];
}

- (void)requestDefinitionForDocument:(OakDocument*)document line:(NSUInteger)line character:(NSUInteger)character completion:(void(^)(NSArray<NSDictionary*>*))callback
{
	NSUUID* docId = document.identifier;
	LSPClient* client = _documentClients[docId];
	if(!client)
	{
		if(callback)
			callback(@[]);
		return;
	}

	NSString* path = document.path;
	if(!path)
	{
		if(callback)
			callback(@[]);
		return;
	}

	NSURL* fileURL = [NSURL fileURLWithPath:path];
	NSString* uri = fileURL.absoluteString;

	[client requestDefinitionForURI:uri line:line character:character completion:callback];
}

- (BOOL)hasClientForDocument:(OakDocument*)document
{
	return document && _documentClients[document.identifier] != nil;
}

#pragma mark - LSPClientDelegate

- (void)lspClient:(LSPClient*)client didReceiveDiagnostics:(NSArray<NSDictionary*>*)diagnostics forDocumentURI:(NSString*)uri
{
	NSURL* url = [NSURL URLWithString:uri];
	NSString* filePath = url.path;
	if(!filePath)
		return;

	OakDocument* doc = [OakDocument documentWithPath:filePath];
	if(!doc || !doc.isLoaded)
		return;

	[doc removeAllMarksOfType:@"error"];
	[doc removeAllMarksOfType:@"warning"];
	[doc removeAllMarksOfType:@"note"];

	for(NSDictionary* diag in diagnostics)
	{
		NSNumber* severity = diag[@"severity"];
		NSString* message  = diag[@"message"];
		NSNumber* line     = diag[@"line"];

		if(!message || !line)
			continue;

		NSString* markType;
		switch(severity.intValue)
		{
			case 1:  markType = @"error";   break;
			case 2:  markType = @"warning"; break;
			default: markType = @"note";    break;
		}

		text::pos_t pos(line.unsignedIntegerValue, 0);
		[doc setMarkOfType:markType atPosition:pos content:message];
	}
}
@end
