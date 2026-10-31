#import <Foundation/Foundation.h>
#import <EditorContextProtocol.h>
#include <stdio.h>

// Reports which candidate names validate_arguments handles. The drift test feeds
// it the names extracted from the description table and the tools/call
// allow-list, so the verdict comes from the compiled branches rather than from
// re-parsing this header's source.
int main(int argc, char const* argv[]) {
	@autoreleasepool {
		for(int i = 1; i < argc; ++i) {
			NSString* name = [NSString stringWithUTF8String:argv[i]];
			BOOL accepted = ![editor_context::validate_arguments(name, @{}) isEqual:@"Unknown tool"];
			printf("%s\t%s\n", argv[i], accepted ? "accepted" : "unknown");
		}
	}
	return 0;
}
