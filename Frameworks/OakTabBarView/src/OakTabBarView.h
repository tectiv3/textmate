#import <oak/misc.h>

typedef NS_ENUM(NSInteger, OakTabStatus) {
    OakTabStatusNone, OakTabStatusWorking, OakTabStatusBlocked, OakTabStatusDone, OakTabStatusError
};

@protocol OakTabBarViewDelegate, OakTabBarViewDataSource;

@interface OakTabBarView : NSView
@property (nonatomic, weak) id <OakTabBarViewDelegate> delegate;
@property (nonatomic, weak) id <OakTabBarViewDataSource> dataSource;
@property (nonatomic, readonly) NSInteger countOfVisibleTabs;
@property (nonatomic) NSUInteger selectedTabIndex;
- (void)reloadData;
- (void)performClose:(id)sender;
// Opens the in-place title editor on a visible tab; NO when the tab is in the overflow menu or the delegate declines.
- (BOOL)beginRenamingTabAtIndex:(NSUInteger)anIndex;

@property (nonatomic) BOOL neverHideLeftBorder;
@end

@protocol OakTabBarViewDelegate <NSObject>
@optional
- (BOOL)tabBarView:(OakTabBarView*)aTabBarView shouldSelectIndex:(NSUInteger)anIndex;
- (void)tabBarView:(OakTabBarView*)aTabBarView didDoubleClickIndex:(NSUInteger)anIndex;
- (void)tabBarViewDidDoubleClick:(OakTabBarView*)aTabBarView;
- (NSMenu*)menuForTabBarView:(OakTabBarView*)aTabBarView;

// Command-clicking a tab (or its VoiceOver "Rename" action) edits its title in place when the delegate returns YES.
// An empty title is passed through so the delegate can treat it as "revert to the default".
// aTitle is nil when the edit was cancelled: by Escape, or because the tab left the bar (overflow, close)
// while being edited. It is still sent so the delegate can restore focus. (Not annotated nullable: this
// header has no nullability audit, and one annotation would warn on every other pointer in it.)
- (BOOL)tabBarView:(OakTabBarView*)aTabBarView shouldRenameIndex:(NSUInteger)anIndex;
- (void)tabBarView:(OakTabBarView*)aTabBarView didRenameIndex:(NSUInteger)anIndex toTitle:(NSString*)aTitle;

// Methods sent to the delegate which the tab was dragged to
- (BOOL)performDropOfTabItem:(NSUUID*)tabItemUUID fromTabBar:(OakTabBarView*)sourceTabBar index:(NSUInteger)dragIndex toTabBar:(OakTabBarView*)destTabBar index:(NSUInteger)droppedIndex operation:(NSDragOperation)operation;

- (void)performCloseTab:(OakTabBarView*)sender;
- (void)performCloseOtherTabsXYZ:(OakTabBarView*)sender;
@end

@protocol OakTabBarViewDataSource <NSObject>
- (NSUInteger)numberOfRowsInTabBarView:(OakTabBarView*)aTabBarView;

- (NSString*)tabBarView:(OakTabBarView*)aTabBarView titleForIndex:(NSUInteger)anIndex;
- (NSString*)tabBarView:(OakTabBarView*)aTabBarView pathForIndex:(NSUInteger)anIndex;
- (NSUUID*)tabBarView:(OakTabBarView*)aTabBarView UUIDForIndex:(NSUInteger)anIndex;
- (BOOL)tabBarView:(OakTabBarView*)aTabBarView isEditedAtIndex:(NSUInteger)anIndex;
@optional

// Optional because the path is the sensible tooltip for a data source without a better description.
// Return an empty string for "no tooltip"; the tab then falls back to its path, which is empty too.
- (NSString*)tabBarView:(OakTabBarView*)aTabBarView toolTipForIndex:(NSUInteger)anIndex;
- (OakTabStatus)tabBarView:(OakTabBarView*)bar statusForIndex:(NSUInteger)index;
- (NSString*)tabBarView:(OakTabBarView*)bar statusDescriptionForIndex:(NSUInteger)index;
@end
