#ifndef LSP_CLIENT_H_POC
#define LSP_CLIENT_H_POC

#import <document/OakDocument.h>

@class LSPClient;

@protocol LSPClientDelegate <NSObject>
- (void)lspClient:(LSPClient*)client didReceiveDiagnostics:(NSArray<NSDictionary*>*)diagnostics forDocumentURI:(NSString*)uri;
@optional
- (void)lspClientDidTerminate:(LSPClient*)client;
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
- (void)prepareRenameForURI:(NSString*)uri line:(NSUInteger)line character:(NSUInteger)character completion:(void(^)(NSDictionary* _Nullable))callback;
- (void)requestRenameForURI:(NSString*)uri line:(NSUInteger)line character:(NSUInteger)character newName:(NSString*)newName completion:(void(^)(NSDictionary* _Nullable))callback;
- (void)cancelRequest:(int)requestId;
@end

#endif /* LSP_CLIENT_H_POC */
