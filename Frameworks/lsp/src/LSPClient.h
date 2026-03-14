#ifndef LSP_CLIENT_H_POC
#define LSP_CLIENT_H_POC

#import <document/OakDocument.h>

@class LSPClient;

@protocol LSPClientDelegate <NSObject>
- (void)lspClient:(LSPClient*)client didReceiveDiagnostics:(NSArray<NSDictionary*>*)diagnostics forDocumentURI:(NSString*)uri;
@optional
- (void)lspClientDidTerminate:(LSPClient*)client;
@end

@interface LSPClient : NSObject
@property (nonatomic, weak) id<LSPClientDelegate> delegate;
@property (nonatomic, readonly) BOOL initialized;
@property (nonatomic, readonly) BOOL running;
- (instancetype)initWithCommand:(NSString*)command arguments:(NSArray<NSString*>*)arguments workingDirectory:(NSString*)workingDirectory initOptions:(NSString*)initOptionsJSON;
- (void)openDocument:(OakDocument*)document languageId:(NSString*)languageId;
- (void)documentDidChange:(OakDocument*)document version:(int)version;
- (void)documentDidSave:(OakDocument*)document;
- (void)closeDocument:(OakDocument*)document;
- (void)shutdown;
- (void)requestCompletionForURI:(NSString*)uri line:(NSUInteger)line character:(NSUInteger)character completion:(void(^)(NSArray<NSDictionary*>*))callback;
- (void)requestDefinitionForURI:(NSString*)uri line:(NSUInteger)line character:(NSUInteger)character completion:(void(^)(NSArray<NSDictionary*>*))callback;
- (void)requestHoverForURI:(NSString*)uri line:(NSUInteger)line character:(NSUInteger)character completion:(void(^)(NSDictionary*))callback;
@end

#endif /* LSP_CLIENT_H_POC */
