#ifndef LSP_MANAGER_H_POC
#define LSP_MANAGER_H_POC

#import <document/OakDocument.h>

@interface LSPManager : NSObject
+ (instancetype)sharedManager;
- (void)documentDidOpen:(OakDocument*)document;
- (void)documentDidChange:(OakDocument*)document;
- (void)documentDidSave:(OakDocument*)document;
- (void)documentWillClose:(OakDocument*)document;
- (void)shutdownAll;
- (void)flushPendingChangesForDocument:(OakDocument*)document;
- (void)requestCompletionsForDocument:(OakDocument*)document line:(NSUInteger)line character:(NSUInteger)character completion:(void(^)(NSArray<NSString*>*))callback;
@end

#endif /* LSP_MANAGER_H_POC */
