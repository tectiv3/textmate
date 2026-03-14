#ifndef LSP_CLIENT_H_POC
#define LSP_CLIENT_H_POC

#import <document/OakDocument.h>

@interface LSPClient : NSObject
- (instancetype)initWithCommand:(NSString*)command arguments:(NSArray<NSString*>*)arguments workingDirectory:(NSString*)workingDirectory;
- (void)openDocument:(OakDocument*)document;
- (void)shutdown;
@end

#endif /* LSP_CLIENT_H_POC */
