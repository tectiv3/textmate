#import "LSPClient.h"
#import <nlohmann/json.hpp>
#import <oak/debug.h>
#import <ns/ns.h>
#import <signal.h>

using json = nlohmann::json;

@interface LSPClient ()
{
	NSTask* _task;
	NSPipe* _stdinPipe;
	NSPipe* _stdoutPipe;
	NSPipe* _stderrPipe;
	dispatch_queue_t _readQueue;
	int _nextRequestId;
	BOOL _initialized;
	NSString* _workingDirectory;
	NSMutableDictionary<NSNumber*, void(^)(id)>* _responseCallbacks;
}
- (void)openDocument:(OakDocument*)document languageId:(NSString*)languageId retryCount:(int)retryCount;
@end

@implementation LSPClient

- (BOOL)running
{
	return _task.isRunning;
}

- (instancetype)initWithCommand:(NSString*)command arguments:(NSArray<NSString*>*)arguments workingDirectory:(NSString*)workingDirectory
{
	if(self = [super init])
	{
		_workingDirectory = workingDirectory;
		_readQueue = dispatch_queue_create("com.macromates.lsp.read", DISPATCH_QUEUE_SERIAL);
		_nextRequestId = 1;
		_initialized = NO;
		_responseCallbacks = [NSMutableDictionary new];

		_stdinPipe  = [NSPipe pipe];
		_stdoutPipe = [NSPipe pipe];
		_stderrPipe = [NSPipe pipe];

		_task = [[NSTask alloc] init];
		_task.executableURL      = [NSURL fileURLWithPath:command];
		_task.arguments          = arguments ?: @[];
		_task.standardInput      = _stdinPipe;
		_task.standardOutput     = _stdoutPipe;
		_task.standardError      = _stderrPipe;
		_task.currentDirectoryURL = [NSURL fileURLWithPath:workingDirectory];

		// Inherit current environment and ensure homebrew paths are available
		NSMutableDictionary* env = [NSProcessInfo.processInfo.environment mutableCopy];
		NSString* path = env[@"PATH"] ?: @"/usr/bin:/bin";
		if(![path containsString:@"/opt/homebrew/bin"])
			env[@"PATH"] = [@"/opt/homebrew/bin:/opt/homebrew/sbin:" stringByAppendingString:path];
		_task.environment = env;

		// SIGPIPE kills the process before @try/@catch can handle broken pipe writes
		signal(SIGPIPE, SIG_IGN);

		__weak LSPClient* weakSelf = self;
		_task.terminationHandler = ^(NSTask* task){
			NSLog(@"[LSP] Server terminated with status %d", task.terminationStatus);
			dispatch_async(dispatch_get_main_queue(), ^{
				LSPClient* strongSelf = weakSelf;
				if(!strongSelf)
					return;
				strongSelf->_initialized = NO;
				[strongSelf cancelPendingCallbacks];
				if([strongSelf->_delegate respondsToSelector:@selector(lspClientDidTerminate:)])
					[strongSelf->_delegate lspClientDidTerminate:strongSelf];
			});
		};

		NSError* error = nil;
		if(![_task launchAndReturnError:&error])
		{
			NSLog(@"[LSP] Failed to launch server: %@", error.localizedDescription);
			return nil;
		}

		NSLog(@"[LSP] Server launched: %@ %@", command, [arguments componentsJoinedByString:@" "]);

		[self startReadLoop];
		[self startStderrLoop];
		[self sendInitialize];
	}
	return self;
}

// MARK: - JSON-RPC framing

- (void)cancelPendingCallbacks
{
	NSDictionary<NSNumber*, void(^)(id)>* callbacks = [_responseCallbacks copy];
	[_responseCallbacks removeAllObjects];
	for(NSNumber* key in callbacks)
	{
		void(^callback)(id) = callbacks[key];
		if(callback)
			callback(nil);
	}
}

- (void)sendMessage:(json const&)message
{
	if(!_task.isRunning)
		return;

	std::string body = message.dump();
	NSString* header = [NSString stringWithFormat:@"Content-Length: %lu\r\n\r\n", (unsigned long)body.size()];

	NSMutableData* data = [NSMutableData dataWithBytes:header.UTF8String length:strlen(header.UTF8String)];
	[data appendBytes:body.c_str() length:body.size()];

	@try {
		[_stdinPipe.fileHandleForWriting writeData:data];
	} @catch(NSException* e) {
		NSLog(@"[LSP] Write failed: %@", e.reason);
	}
}

- (void)sendRequest:(NSString*)method params:(json)params
{
	json msg = {
		{"jsonrpc", "2.0"},
		{"id",      _nextRequestId++},
		{"method",  method.UTF8String},
		{"params",  params}
	};
	NSLog(@"[LSP] --> %s (id=%d)", method.UTF8String, _nextRequestId - 1);
	[self sendMessage:msg];
}

- (void)sendNotification:(NSString*)method params:(json)params
{
	json msg = {
		{"jsonrpc", "2.0"},
		{"method",  method.UTF8String},
		{"params",  params}
	};
	NSLog(@"[LSP] --> %s", method.UTF8String);
	[self sendMessage:msg];
}

// MARK: - Read loop

- (void)startReadLoop
{
	NSFileHandle* handle = _stdoutPipe.fileHandleForReading;
	dispatch_async(_readQueue, ^{
		NSMutableData* buffer = [NSMutableData data];

		while(true)
		{
			// Read until we have a complete Content-Length header
			NSInteger contentLength = -1;
			while(true)
			{
				NSRange headerEnd = [buffer rangeOfData:[@"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding] options:0 range:NSMakeRange(0, buffer.length)];
				if(headerEnd.location != NSNotFound)
				{
					NSString* headers = [[NSString alloc] initWithData:[buffer subdataWithRange:NSMakeRange(0, headerEnd.location)] encoding:NSUTF8StringEncoding];
					for(NSString* line in [headers componentsSeparatedByString:@"\r\n"])
					{
						if([line hasPrefix:@"Content-Length: "])
							contentLength = [line substringFromIndex:16].integerValue;
					}

					[buffer replaceBytesInRange:NSMakeRange(0, headerEnd.location + headerEnd.length) withBytes:NULL length:0];
					break;
				}

				NSData* chunk = [handle availableData];
				if(chunk.length == 0)
				{
					NSLog(@"[LSP] Server stdout closed");
					return;
				}
				[buffer appendData:chunk];
			}

			if(contentLength < 0)
			{
				NSLog(@"[LSP] Missing Content-Length header");
				continue;
			}

			// Read until we have the full body
			while((NSInteger)buffer.length < contentLength)
			{
				NSData* chunk = [handle availableData];
				if(chunk.length == 0)
				{
					NSLog(@"[LSP] Server stdout closed mid-message");
					return;
				}
				[buffer appendData:chunk];
			}

			NSData* bodyData = [buffer subdataWithRange:NSMakeRange(0, contentLength)];
			[buffer replaceBytesInRange:NSMakeRange(0, contentLength) withBytes:NULL length:0];

			try {
				json msg = json::parse((const char*)bodyData.bytes, (const char*)bodyData.bytes + bodyData.length);
				dispatch_async(dispatch_get_main_queue(), ^{
					[self handleMessage:msg];
				});
			} catch(std::exception const& e) {
				NSLog(@"[LSP] JSON parse error: %s", e.what());
			}
		}
	});
}

- (void)startStderrLoop
{
	_stderrPipe.fileHandleForReading.readabilityHandler = ^(NSFileHandle* handle){
		NSData* data = handle.availableData;
		if(data.length > 0)
		{
			NSString* text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
			NSLog(@"[LSP][stderr] %@", text);
		}
	};
}

// MARK: - Message dispatch

- (void)handleMessage:(json const&)msg
{
	if(msg.contains("method"))
	{
		std::string method = msg["method"].get<std::string>();

		if(msg.contains("id"))
		{
			// Server-initiated request — must reply or server will hang
			NSLog(@"[LSP] <-- request: %s (id=%s)", method.c_str(), msg["id"].dump().c_str());
			json response = {
				{"jsonrpc", "2.0"},
				{"id",      msg["id"]},
				{"result",  json::object()}
			};
			[self sendMessage:response];
		}
		else if(method == "textDocument/publishDiagnostics")
		{
			[self handleDiagnostics:msg["params"]];
		}
		else
		{
			NSLog(@"[LSP] <-- notification: %s %s", method.c_str(), msg.contains("params") ? msg["params"].dump().c_str() : "");
		}
	}
	else if(msg.contains("id"))
	{
		int reqId = msg["id"].get<int>();
		NSLog(@"[LSP] <-- response id=%d", reqId);

		if(msg.contains("error"))
		{
			auto const& err = msg["error"];
			NSLog(@"[LSP] Error %d: %s", err["code"].get<int>(), err["message"].get<std::string>().c_str());

			NSNumber* key = @(reqId);
			void(^callback)(id) = _responseCallbacks[key];
			if(callback)
			{
				[_responseCallbacks removeObjectForKey:key];
				callback(nil);
			}
		}
		else if(!_initialized && msg.contains("result"))
		{
			_initialized = YES;
			NSLog(@"[LSP] Server initialized successfully");
			[self sendNotification:@"initialized" params:json::object()];
		}
		else if(msg.contains("result"))
		{
			NSNumber* key = @(reqId);
			void(^callback)(id) = _responseCallbacks[key];
			if(callback)
			{
				[_responseCallbacks removeObjectForKey:key];
				id result = [self convertJSON:msg["result"]];
				callback(result);
			}
		}
	}
}

- (void)handleDiagnostics:(json const&)params
{
	std::string uriStr = params["uri"].get<std::string>();
	auto const& diagnostics = params["diagnostics"];

	NSLog(@"[LSP] Diagnostics for %s: %lu items", uriStr.c_str(), (unsigned long)diagnostics.size());

	NSMutableArray<NSDictionary*>* results = [NSMutableArray arrayWithCapacity:diagnostics.size()];

	for(auto const& diag : diagnostics)
	{
		int line = diag["range"]["start"]["line"].get<int>();
		int col  = diag["range"]["start"]["character"].get<int>();
		int severity = diag.value("severity", 1);
		std::string message = diag["message"].get<std::string>();

		[results addObject:@{
			@"line":      @(line),
			@"character": @(col),
			@"severity":  @(severity),
			@"message":   to_ns(message)
		}];
	}

	[_delegate lspClient:self didReceiveDiagnostics:results forDocumentURI:to_ns(uriStr)];
}

// MARK: - LSP lifecycle

- (void)sendInitialize
{
	json params = {
		{"processId",    (int)NSProcessInfo.processInfo.processIdentifier},
		{"rootUri",      [NSURL fileURLWithPath:_workingDirectory].absoluteString.UTF8String},
		{"initializationOptions", json::object()},
		{"capabilities", {
			{"textDocument", {
				{"publishDiagnostics", {
					{"relatedInformation", true}
				}},
				{"synchronization", {
					{"didSave", true},
					{"dynamicRegistration", false}
				}},
				{"completion", {
					{"dynamicRegistration", false},
					{"completionItem", {
						{"snippetSupport", true}
					}}
				}},
				{"definition", {
					{"dynamicRegistration", false}
				}},
				{"hover", {
					{"dynamicRegistration", false},
					{"contentFormat", {"markdown", "plaintext"}}
				}}
			}}
		}}
	};
	[self sendRequest:@"initialize" params:params];
}

- (void)openDocument:(OakDocument*)document languageId:(NSString*)languageId retryCount:(int)retryCount
{
	if(!_initialized)
	{
		if(retryCount >= 5)
		{
			NSLog(@"[LSP] Server failed to initialize after %d retries, giving up on didOpen", retryCount);
			return;
		}
		NSLog(@"[LSP] Not yet initialized, deferring didOpen (attempt %d)", retryCount + 1);
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			[self openDocument:document languageId:languageId retryCount:retryCount + 1];
		});
		return;
	}

	NSString* path = document.path;
	if(!path)
		return;

	NSString* content = document.content;
	if(!content)
		return;

	NSURL* fileURL = [NSURL fileURLWithPath:path];
	std::string uri = fileURL.absoluteString.UTF8String;

	json params = {
		{"textDocument", {
			{"uri",        uri},
			{"languageId", languageId.UTF8String},
			{"version",    1},
			{"text",       content.UTF8String}
		}}
	};
	[self sendNotification:@"textDocument/didOpen" params:params];
}

- (void)openDocument:(OakDocument*)document languageId:(NSString*)languageId
{
	[self openDocument:document languageId:languageId retryCount:0];
}

- (void)documentDidChange:(OakDocument*)document version:(int)version
{
	NSString* path = document.path;
	if(!path)
		return;

	NSString* content = document.content;
	if(!content)
		return;

	NSURL* fileURL = [NSURL fileURLWithPath:path];
	std::string uri = fileURL.absoluteString.UTF8String;

	json params = {
		{"textDocument", {
			{"uri",     uri},
			{"version", version}
		}},
		{"contentChanges", {
			{{"text", content.UTF8String}}
		}}
	};
	[self sendNotification:@"textDocument/didChange" params:params];
}

- (void)documentDidSave:(OakDocument*)document
{
	NSString* path = document.path;
	if(!path)
		return;

	NSURL* fileURL = [NSURL fileURLWithPath:path];
	std::string uri = fileURL.absoluteString.UTF8String;

	json params = {
		{"textDocument", {
			{"uri", uri}
		}}
	};
	[self sendNotification:@"textDocument/didSave" params:params];
}

- (void)closeDocument:(OakDocument*)document
{
	NSString* path = document.path;
	if(!path)
		return;

	NSURL* fileURL = [NSURL fileURLWithPath:path];
	std::string uri = fileURL.absoluteString.UTF8String;

	json params = {
		{"textDocument", {
			{"uri", uri}
		}}
	};
	[self sendNotification:@"textDocument/didClose" params:params];
}

- (int)sendRequest:(NSString*)method params:(json)params callback:(void(^)(id))callback
{
	int reqId = _nextRequestId++;
	json msg = {
		{"jsonrpc", "2.0"},
		{"id",      reqId},
		{"method",  method.UTF8String},
		{"params",  params}
	};
	NSLog(@"[LSP] --> %s (id=%d) params=%s", method.UTF8String, reqId, params.dump().c_str());
	if(callback)
		_responseCallbacks[@(reqId)] = [callback copy];
	[self sendMessage:msg];
	return reqId;
}

- (id)convertJSON:(json const&)value
{
	if(value.is_null())
		return [NSNull null];
	if(value.is_boolean())
		return @(value.get<bool>());
	if(value.is_number_integer())
		return @(value.get<int64_t>());
	if(value.is_number_float())
		return @(value.get<double>());
	if(value.is_string())
		return to_ns(value.get<std::string>());
	if(value.is_array())
	{
		NSMutableArray* arr = [NSMutableArray arrayWithCapacity:value.size()];
		for(auto const& item : value)
			[arr addObject:[self convertJSON:item]];
		return arr;
	}
	if(value.is_object())
	{
		NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithCapacity:value.size()];
		for(auto it = value.begin(); it != value.end(); ++it)
			dict[to_ns(it.key())] = [self convertJSON:it.value()];
		return dict;
	}
	return [NSNull null];
}

- (void)requestCompletionForURI:(NSString*)uri line:(NSUInteger)line character:(NSUInteger)character completion:(void(^)(NSArray<NSDictionary*>*))callback
{
	if(!_initialized)
	{
		if(callback)
			callback(@[]);
		return;
	}

	json params = {
		{"textDocument", {{"uri", uri.UTF8String}}},
		{"position", {{"line", (int)line}, {"character", (int)character}}},
		{"context", {{"triggerKind", 1}}}
	};

	[self sendRequest:@"textDocument/completion" params:params callback:^(id result) {
		NSMutableArray<NSDictionary*>* suggestions = [NSMutableArray new];

		NSArray* items = nil;
		if([result isKindOfClass:[NSArray class]])
		{
			items = result;
		}
		else if([result isKindOfClass:[NSDictionary class]])
		{
			items = result[@"items"];
		}

	for(NSDictionary* item in items)
		{
			NSString* label = item[@"label"];
			if(label.length == 0)
				continue;

			NSString* insertText = item[@"insertText"];
			NSNumber* insertTextFormat = item[@"insertTextFormat"];

			// Servers use textEdit instead of insertText when snippetSupport is on
			if(!insertText && item[@"textEdit"])
			{
				NSDictionary* textEdit = item[@"textEdit"];
				insertText = textEdit[@"newText"];
			}
			if(!insertText)
				insertText = label;

			NSMutableDictionary* suggestion = [@{
				@"label":      label,
				@"filterText": label,
				@"insert":     insertText,
			} mutableCopy];

			if(item[@"kind"])
				suggestion[@"kind"] = item[@"kind"];
			if(item[@"detail"])
				suggestion[@"detail"] = item[@"detail"];
			if(insertTextFormat)
				suggestion[@"insertTextFormat"] = insertTextFormat;

			[suggestions addObject:suggestion];
		}

		if(callback)
			callback(suggestions);
	}];
}

- (void)requestDefinitionForURI:(NSString*)uri line:(NSUInteger)line character:(NSUInteger)character completion:(void(^)(NSArray<NSDictionary*>*))callback
{
	if(!_initialized)
	{
		if(callback)
			callback(@[]);
		return;
	}

	json params = {
		{"textDocument", {{"uri", uri.UTF8String}}},
		{"position", {{"line", (int)line}, {"character", (int)character}}}
	};

	[self sendRequest:@"textDocument/definition" params:params callback:^(id result) {
		NSMutableArray<NSDictionary*>* locations = [NSMutableArray new];

		// Response can be Location, Location[], or null
		NSArray* items = nil;
		if([result isKindOfClass:[NSArray class]])
			items = result;
		else if([result isKindOfClass:[NSDictionary class]])
			items = @[result];

		for(NSDictionary* item in items)
		{
			NSString* locationUri = item[@"uri"];
			NSDictionary* range = item[@"range"];
			if(!locationUri || !range)
				continue;

			NSDictionary* start = range[@"start"];
			[locations addObject:@{
				@"uri":       locationUri,
				@"line":      start[@"line"] ?: @0,
				@"character": start[@"character"] ?: @0
			}];
		}

		if(callback)
			callback(locations);
	}];
}

- (void)requestHoverForURI:(NSString*)uri line:(NSUInteger)line character:(NSUInteger)character completion:(void(^)(NSDictionary*))callback
{
	if(!_initialized)
	{
		if(callback)
			callback(nil);
		return;
	}

	json params = {
		{"textDocument", {{"uri", uri.UTF8String}}},
		{"position", {{"line", (int)line}, {"character", (int)character}}}
	};

	[self sendRequest:@"textDocument/hover" params:params callback:^(id result) {
		if(![result isKindOfClass:[NSDictionary class]])
		{
			if(callback)
				callback(nil);
			return;
		}

		NSDictionary* dict = (NSDictionary*)result;
		id contents = dict[@"contents"];
		if(!contents)
		{
			if(callback)
				callback(nil);
			return;
		}

		// contents can be: MarkedString, MarkedString[], or MarkupContent
		// MarkedString = string | {language, value}
		// MarkupContent = {kind, value}
		NSString* value = nil;
		NSString* language = nil;
		NSString* kind = nil;

		if([contents isKindOfClass:[NSString class]])
		{
			value = contents;
		}
		else if([contents isKindOfClass:[NSDictionary class]])
		{
			NSDictionary* contentsDict = contents;
			if(contentsDict[@"kind"])
			{
				// MarkupContent: {kind: "markdown"|"plaintext", value: "..."}
				kind = contentsDict[@"kind"];
				value = contentsDict[@"value"];
			}
			else if(contentsDict[@"language"])
			{
				// MarkedString object: {language: "php", value: "..."}
				language = contentsDict[@"language"];
				value = contentsDict[@"value"];
			}
			else if(contentsDict[@"value"])
			{
				value = contentsDict[@"value"];
			}
		}
		else if([contents isKindOfClass:[NSArray class]])
		{
			// MarkedString[] — concatenate values
			NSMutableString* combined = [NSMutableString new];
			for(id item in (NSArray*)contents)
			{
				if([item isKindOfClass:[NSString class]])
				{
					if(combined.length > 0) [combined appendString:@"\n\n"];
					[combined appendString:item];
				}
				else if([item isKindOfClass:[NSDictionary class]])
				{
					NSDictionary* d = item;
					NSString* v = d[@"value"];
					if(v.length > 0)
					{
						if(combined.length > 0) [combined appendString:@"\n\n"];
						[combined appendString:v];
					}
					if(!language && d[@"language"])
						language = d[@"language"];
				}
			}
			value = combined;
		}

		if(!value.length)
		{
			if(callback)
				callback(nil);
			return;
		}

		NSMutableDictionary* hover = [NSMutableDictionary new];
		hover[@"value"] = value;
		if(kind)
			hover[@"kind"] = kind;
		if(language)
			hover[@"language"] = language;

		if(callback)
			callback(hover);
	}];
}

- (void)shutdown
{
	if(!_task.isRunning)
		return;

	NSLog(@"[LSP] Shutting down server");
	[self sendRequest:@"shutdown" params:json::object()];

	// Give server 2s to respond, then send exit
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[self sendNotification:@"exit" params:json::object()];
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			if(self->_task.isRunning)
				[self->_task terminate];
		});
	});
}

@end
