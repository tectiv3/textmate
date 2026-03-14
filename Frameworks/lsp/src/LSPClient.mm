#import "LSPClient.h"
#import <nlohmann/json.hpp>
#import <oak/debug.h>
#import <ns/ns.h>

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

		_task.terminationHandler = ^(NSTask* task){
			NSLog(@"[LSP] Server terminated with status %d", task.terminationStatus);
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

- (void)sendMessage:(json const&)message
{
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
		}
		else if(!_initialized && msg.contains("result"))
		{
			_initialized = YES;
			NSLog(@"[LSP] Server initialized successfully");
			[self sendNotification:@"initialized" params:json::object()];
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
		{"capabilities", {
			{"textDocument", {
				{"publishDiagnostics", {
					{"relatedInformation", true}
				}},
				{"synchronization", {
					{"didSave", true},
					{"dynamicRegistration", false}
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
