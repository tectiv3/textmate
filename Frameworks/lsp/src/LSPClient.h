#ifndef LSP_CLIENT_H_POC
#define LSP_CLIENT_H_POC

#import <document/OakDocument.h>

@class LSPClient;

@protocol LSPClientDelegate <NSObject>
- (void)lspClient:(LSPClient*)client didReceiveDiagnostics:(NSArray<NSDictionary*>*)diagnostics forDocumentURI:(NSString*)uri;
@end

@interface LSPClient : NSObject
@property (nonatomic, weak) id<LSPClientDelegate> delegate;
@property (nonatomic, readonly) BOOL initialized;
@property (nonatomic, readonly) BOOL running;
- (instancetype)initWithCommand:(NSString*)command arguments:(NSArray<NSString*>*)arguments workingDirectory:(NSString*)workingDirectory;
- (void)openDocument:(OakDocument*)document languageId:(NSString*)languageId;
- (void)documentDidChange:(OakDocument*)document version:(int)version;
- (void)documentDidSave:(OakDocument*)document;
- (void)closeDocument:(OakDocument*)document;
- (void)shutdown;
- (void)requestCompletionForURI:(NSString*)uri line:(NSUInteger)line character:(NSUInteger)character completion:(void(^)(NSArray<NSString*>*))callback;
@end

#endif /* LSP_CLIENT_H_POC */
