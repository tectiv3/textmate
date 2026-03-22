#ifndef LSP_CLIENT_H_POC
#define LSP_CLIENT_H_POC

#import <document/OakDocument.h>

@class LSPClient;

@protocol LSPClientDelegate <NSObject>
- (void)lspClient:(LSPClient*)client didReceiveDiagnostics:(NSArray<NSDictionary*>*)diagnostics forDocumentURI:(NSString*)uri;
@optional
- (void)lspClientDidTerminate:(LSPClient*)client;
- (void)lspClient:(LSPClient*)client didReceiveApplyEditRequest:(NSDictionary*)workspaceEdit requestId:(int)requestId;
- (void)lspClientDidInitialize:(LSPClient*)client;
- (id)lspClient:(LSPClient*)client handleServerRequest:(NSString*)method params:(NSDictionary*)params;
- (void)lspClient:(LSPClient*)client didReceiveNotification:(NSString*)method params:(NSDictionary*)params;
@end

extern NSString* const LSPLogNotification;
extern NSString* const LSPShowMessageNotification;
extern NSString* const LSPProgressNotification;

@interface LSPClient : NSObject
@property (nonatomic, weak) id<LSPClientDelegate> delegate;
@property (nonatomic, readonly) BOOL initialized;
@property (nonatomic, readonly) BOOL running;
@property (nonatomic, readonly) BOOL documentFormattingProvider;
@property (nonatomic, readonly) BOOL documentRangeFormattingProvider;
@property (nonatomic, readonly) BOOL completionResolveProvider;
@property (nonatomic, readonly) BOOL renameProvider;
@property (nonatomic, readonly) BOOL codeActionProvider;
@property (nonatomic, readonly) BOOL codeActionResolveProvider;
- (instancetype)initWithCommand:(NSString*)command arguments:(NSArray<NSString*>*)arguments workingDirectory:(NSString*)workingDirectory initOptions:(NSString*)initOptionsJSON;
- (void)openDocument:(OakDocument*)document languageId:(NSString*)languageId;
- (void)documentDidChange:(OakDocument*)document version:(int)version;
- (void)documentDidSave:(OakDocument*)document;
- (void)closeDocument:(OakDocument*)document;
- (void)shutdown;
- (void)requestCompletionForURI:(NSString*)uri line:(NSUInteger)line character:(NSUInteger)character completion:(void(^)(NSArray<NSDictionary*>*))callback;
- (void)requestDefinitionForURI:(NSString*)uri line:(NSUInteger)line character:(NSUInteger)character completion:(void(^)(NSArray<NSDictionary*>*))callback;
- (int)requestHoverForURI:(NSString*)uri line:(NSUInteger)line character:(NSUInteger)character completion:(void(^)(NSDictionary*))callback;
- (void)requestReferencesForURI:(NSString*)uri line:(NSUInteger)line character:(NSUInteger)character completion:(void(^)(NSArray<NSDictionary*>*))callback;
- (void)requestFormattingForURI:(NSString*)uri tabSize:(NSUInteger)tabSize insertSpaces:(BOOL)insertSpaces completion:(void(^)(NSArray<NSDictionary*>*))callback;
- (void)requestRangeFormattingForURI:(NSString*)uri startLine:(NSUInteger)startLine startCharacter:(NSUInteger)startCharacter endLine:(NSUInteger)endLine endCharacter:(NSUInteger)endCharacter tabSize:(NSUInteger)tabSize insertSpaces:(BOOL)insertSpaces completion:(void(^)(NSArray<NSDictionary*>*))callback;
- (void)resolveCompletionItem:(NSDictionary*)item completion:(void(^)(NSDictionary*))callback;
- (void)prepareRenameForURI:(NSString*)uri line:(NSUInteger)line character:(NSUInteger)character completion:(void(^)(NSDictionary*))callback;
- (void)requestRenameForURI:(NSString*)uri line:(NSUInteger)line character:(NSUInteger)character newName:(NSString*)newName completion:(void(^)(NSDictionary*))callback;
- (void)requestCodeActionsForURI:(NSString*)uri line:(NSUInteger)line character:(NSUInteger)character endLine:(NSUInteger)endLine endCharacter:(NSUInteger)endCharacter diagnostics:(NSArray<NSDictionary*>*)diagnostics completion:(void(^)(NSArray<NSDictionary*>*))callback;
- (void)resolveCodeAction:(NSDictionary*)codeAction completion:(void(^)(NSDictionary*))callback;
- (void)executeCommand:(NSString*)command arguments:(NSArray*)arguments completion:(void(^)(id))callback;
- (void)cancelRequest:(int)requestId;
- (void)respondToApplyEdit:(int)requestId applied:(BOOL)applied failureReason:(NSString*)reason;

// Generic JSON-RPC methods for non-standard LSP extensions (e.g., Copilot)
- (int)sendCustomRequest:(NSString*)method params:(NSDictionary*)params completion:(void(^)(id))callback;
- (void)sendCustomNotification:(NSString*)method params:(NSDictionary*)params;
@end

#endif /* LSP_CLIENT_H_POC */
