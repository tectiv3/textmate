#import <Cocoa/Cocoa.h>
#import "ProjectChanges.h"

@interface ProjectChangesWindowController : NSWindowController
- (instancetype)initWithDirectory:(NSString*)directory buffers:(NSDictionary<NSString*, ProjectChangesBuffer*>* (^)(void))buffers openFile:(void (^)(NSString*, NSUInteger))openFile;
- (IBAction)refresh:(id)sender;
@end
