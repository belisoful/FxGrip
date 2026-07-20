#import <TargetConditionals.h>
#if TARGET_OS_OSX
/*!
 @header     BETabView.h
 @copyright  -© 2025 Delicense - @belisoful. All rights released.
 @date       2025-11-11
 @author     belisoful@icloud.com
 @abstract   Provides an NSTabView subclass that supports hiding and showing tabs.
 @discussion BETabView extends NSTabView to add the ability to hide and show individual
			 tab items while maintaining their position in the tab order. Hidden tabs
			 are removed from the visible interface but remain in memory and can be
			 shown again at any time. This is useful for conditional UI where certain
			 tabs should only be visible under specific circumstances.
			 
			 BETabView adds these behaviors to NSTabView:
			 - Hide/show individual tabs dynamically
			 - Maintain tab order when hiding/showing
			 - Delegate notifications for hide/show events
			 - Main-thread-only, like every NSView; @synchronized guards internal bookkeeping only
			 - Support for identifier-based lookups
			 
			 Example usage:
			 @code
			 BETabView *tabView = [[BETabView alloc] initWithFrame:frame];
			 [tabView addTabViewItem:advancedTab];
			 [tabView addTabViewItem:simpleTab];
			 
			 // Hide the advanced tab for beginner users
			 advancedTab.hidden = YES;
			 // Or: [tabView hideTabViewItem:advancedTab];
			 
			 // Show it when user clicks advanced
			 advancedTab.hidden = NO;
			 // Or: [tabView showTabViewItem:advancedTab];
			 @endcode
 */

#ifndef BETabView_h
#define BETabView_h

#import <Cocoa/Cocoa.h>
#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

@class BETabView;

#pragma mark - NSTabViewItem Hidden Support

/*!
 @category   NSTabViewItem (TabViewItemHidden)
 @abstract   Adds hidden state support to NSTabViewItem.
 @discussion This category extends NSTabViewItem to support a hidden property that
			 can be used to hide/show tabs in a BETabView. The hidden property is
			 stored using associated objects and automatically calls the appropriate
			 BETabView methods when changed.
			 
			 Important: This property only works with BETabView instances. Attempting
			 to use it with a standard NSTabView will raise an exception to prevent
			 programming errors.
			 
			 The hidden state is persistent across show/hide cycles and is maintained
			 even when the tab is not in the visible tabs array.
 */
@interface NSTabViewItem (TabViewItemHidden)

/*!
 @property   hidden
 @abstract   Whether this tab view item is currently hidden.
 @discussion Setting this property to YES hides the tab (removes it from the visible
			 tab bar and content area). Setting it to NO shows the tab (adds it back
			 to the visible interface at its preserved position).
			 
			 This property only works when the tab item is part of a BETabView. Using
			 it with a standard NSTabView will raise an NSInternalInconsistencyException
			 to prevent misuse.
			 
			 The hidden state is preserved using associated objects and persists across
			 show/hide operations. When a tab is hidden, it remains in the allTabViewItems
			 array but is removed from the inherited tabViewItems array.
			 
			 Example:
			 @code
			 // Hide a tab
			 myTab.hidden = YES;
			 
			 // Show it again later
			 myTab.hidden = NO;
			 
			 // Check visibility
			 if (myTab.hidden) {
				 NSLog(@"Tab is hidden");
			 }
			 @endcode
 */
@property (nonatomic) BOOL hidden;

/*!
 @property   hiddenTabView
 @abstract   The BETabView that owns this item when it is hidden.
 @discussion Internal property used to maintain a weak reference to the owning BETabView
			 when the item is hidden. When a tab is visible, tabView returns the owning
			 NSTabView. When hidden, tabView returns nil, so hiddenTabView provides
			 access to the owner.
			 
			 This property is managed automatically by BETabView and should not be set
			 manually by client code. It is a zeroing-weak reference (stored via a retained
			 wrapper holding a __weak pointer): it does not retain the tab view, so there is
			 no retain cycle, and it becomes nil automatically if the tab view deallocates,
			 so there is no dangling pointer.
			 
			 The hidden property setter uses this to determine which BETabView to call
			 hide/show methods on, even when the tab is currently hidden.
 */
@property (nullable, nonatomic, weak) BETabView *hiddenTabView;

@end


#pragma mark - NSTabView Identifier Support

/*!
 @category   NSTabView (TabViewItemIdentifier)
 @abstract   Adds convenience method for finding tab items by identifier.
 @discussion Provides a simple method to retrieve a tab view item using its identifier,
			 similar to how UIKit handles view lookups by tag. This complements the
			 existing indexOfTabViewItemWithIdentifier: method by returning the actual
			 tab item instead of just its index.
			 
			 This category works with both NSTabView and BETabView instances.
 */
@interface NSTabView (TabViewItemIdentifier)

/*!
 @method     tabViewItemWithIdentifier:
 @abstract   Returns the visible tab view item with the specified identifier.
 @param      identifier The identifier to search for (compared using isEqual:).
 @discussion Searches through the visible tab view items (tabViewItems array) to find
			 one whose identifier matches the provided value. This is a convenience
			 method that combines indexOfTabViewItemWithIdentifier: and tabViewItemAtIndex:.
			 
			 For BETabView, this only searches visible tabs. To search all tabs including
			 hidden ones, use allTabViewItemWithIdentifier: instead.
			 
			 The identifier comparison uses isEqual:, so any object type can be used
			 as an identifier (NSString, NSNumber, custom objects, etc.).
			 
			 Example:
			 @code
			 // Find a tab by its identifier
			 NSTabViewItem *settingsTab = [tabView tabViewItemWithIdentifier:@"settings"];
			 if (settingsTab) {
				 [tabView selectTabViewItem:settingsTab];
			 }
			 @endcode
 @return     The matching NSTabViewItem, or nil if not found or if identifier is nil.
 */
- (nullable NSTabViewItem *)tabViewItemWithIdentifier:(nonnull id)identifier;

@end


#pragma mark - BETabView Delegate Protocol

/*!
 @protocol   BETabViewDelegate
 @abstract   Extended delegate protocol for BETabView with hide/show notifications.
 @discussion Extends NSTabViewDelegate to add delegate methods that are called when
			 tabs are hidden or shown. These methods allow the delegate to respond
			 to visibility changes, update UI, save preferences, or perform other
			 actions in response to tab visibility changes.
			 
			 All methods are optional and are called on the main thread (as indicated
			 by NS_SWIFT_UI_ACTOR). Delegates can implement any subset of these methods
			 as needed.
			 
			 The will/did method pairs follow the standard Cocoa pattern:
			 - will methods are called before the change occurs
			 - did methods are called after the change is complete
			 
			 Example implementation:
			 @code
			 - (void)tabView:(NSTabView *)tabView didHideTabViewItem:(NSTabViewItem *)item {
				 NSLog(@"Tab '%@' was hidden", item.label);
				 [self updateUserPreferences];
			 }
			 @endcode
 */
@protocol BETabViewDelegate <NSTabViewDelegate>

@optional

/*!
 @method     tabView:willHideTabViewItem:
 @abstract   Notifies delegate that a tab item is about to be hidden.
 @param      tabView The BETabView containing the tab item.
 @param      tabViewItem The tab item that will be hidden.
 @discussion Called immediately before the tab item is removed from the visible tabs.
			 At this point, the tab is still in the tabViewItems array and visible
			 in the UI. The delegate can use this opportunity to save state, update
			 UI, or perform cleanup before the tab disappears.
			 
			 This method is always followed by didHideTabViewItem: unless an exception
			 occurs during the hide operation.
 */
- (void)tabView:(nonnull NSTabView *)tabView willHideTabViewItem:(nullable NSTabViewItem *)tabViewItem NS_SWIFT_UI_ACTOR;

/*!
 @method     tabView:didHideTabViewItem:
 @abstract   Notifies delegate that a tab item was hidden.
 @param      tabView The BETabView containing the tab item.
 @param      tabViewItem The tab item that was hidden.
 @discussion Called immediately after the tab item is removed from the visible tabs.
			 At this point, the tab is no longer in the tabViewItems array and is
			 not visible in the UI. The tab's hidden property is now YES.
			 
			 The delegate can use this to update application state, refresh UI that
			 depends on tab visibility, or notify other components that the tab is
			 no longer accessible.
 */
- (void)tabView:(nonnull NSTabView *)tabView didHideTabViewItem:(nullable NSTabViewItem *)tabViewItem NS_SWIFT_UI_ACTOR;

/*!
 @method     tabView:willShowTabViewItem:
 @abstract   Notifies delegate that a tab item is about to be shown.
 @param      tabView The BETabView containing the tab item.
 @param      tabViewItem The tab item that will be shown.
 @discussion Called immediately before the tab item is added back to the visible tabs.
			 At this point, the tab is still hidden (not in the tabViewItems array).
			 The delegate can use this opportunity to prepare the tab's content,
			 update state, or perform other setup before the tab becomes visible.
			 
			 This method is always followed by didShowTabViewItem: unless an exception
			 occurs during the show operation.
 */
- (void)tabView:(nonnull NSTabView *)tabView willShowTabViewItem:(nullable NSTabViewItem *)tabViewItem NS_SWIFT_UI_ACTOR;

/*!
 @method     tabView:didShowTabViewItem:
 @abstract   Notifies delegate that a tab item was shown.
 @param      tabView The BETabView containing the tab item.
 @param      tabViewItem The tab item that was shown.
 @discussion Called immediately after the tab item is added back to the visible tabs.
			 At this point, the tab is now in the tabViewItems array and visible in
			 the UI at its preserved position. The tab's hidden property is now NO.
			 
			 The delegate can use this to refresh the tab's content, update application
			 state, or perform other actions now that the tab is accessible to the user.
 */
- (void)tabView:(nonnull NSTabView *)tabView didShowTabViewItem:(nullable NSTabViewItem *)tabViewItem NS_SWIFT_UI_ACTOR;

@end


#pragma mark - BETabView

/*!
 @class      BETabView
 @abstract   NSTabView subclass that supports hiding and showing individual tabs.
 @discussion BETabView extends NSTabView to add dynamic tab visibility control. Tabs
			 can be hidden and shown while preserving their position in the tab order.
			 This is useful for applications that need to conditionally display tabs
			 based on user permissions, application state, or user preferences.
			 
			 Architecture:
			 - Maintains two conceptual arrays: visible tabs (tabViewItems) and all
			   tabs (allTabViewItems)
			 - Hidden state is stored on NSTabViewItem instances using associated objects
			 - Position preservation: hidden tabs remember their position and return
			   to the same location when shown

			 Threading:
			 Like every NSView, BETabView must be used on the main thread. The
			 @synchronized(self) regions in this class guard only the internal
			 _allTabViewItems bookkeeping array; the underlying AppKit operations
			 (super add/remove, selection, drawing) are not thread-safe and
			 @synchronized does not change that.

			 Key differences from NSTabView:
			 - The inherited tabViewItems property only contains visible tabs
			 - The allTabViewItems property contains all tabs (visible and hidden)
			 - Tabs can be hidden/shown using dedicated methods or the hidden property
			 - Delegate receives will/did notifications for hide/show events
			 
			 Common use cases:
			 - Progressive disclosure (show advanced tabs only when needed)
			 - Permission-based tab visibility
			 - Wizard-style interfaces with conditional steps
			 - Dynamic tab bars that adapt to context
			 
			 Example usage:
			 @code
			 BETabView *tabView = [[BETabView alloc] initWithFrame:frame];
			 tabView.delegate = self;
			 
			 // Add tabs
			 NSTabViewItem *basicTab = [[NSTabViewItem alloc] initWithIdentifier:@"basic"];
			 NSTabViewItem *advancedTab = [[NSTabViewItem alloc] initWithIdentifier:@"advanced"];
			 [tabView addTabViewItem:basicTab];
			 [tabView addTabViewItem:advancedTab];
			 
			 // Hide advanced tab initially
			 advancedTab.hidden = YES;
			 
			 // Show it when user upgrades
			 if (userIsPro) {
				 advancedTab.hidden = NO;
			 }
			 
			 // Access all tabs including hidden ones
			 NSLog(@"Total tabs: %ld", tabView.numberOfAllTabViewItems);
			 @endcode
 */
@interface BETabView : NSTabView

#pragma mark - Properties

/*!
 @property   allTabViewItems
 @abstract   All tab view items, including both visible and hidden tabs.
 @discussion This property provides access to all tabs that have been added to the
			 tab view, regardless of their visibility state. The order of items in
			 this array determines the position where tabs will appear when shown.
			 
			 The inherited tabViewItems property returns only visible tabs, while
			 allTabViewItems returns all tabs.
			 
			 The getter returns an immutable snapshot (a copy), so the internal store cannot
			 be mutated behind the class's back.

			 Setting this property replaces all tabs (both visible and hidden) with
			 the provided array. Tabs with hidden=YES remain hidden; the rest become
			 visible. Each item's hiddenTabView back-pointer is set automatically, and the
			 superclass's visible tabs are rebuilt in order. After the rebuild, the delegate
			 receives tabViewDidChangeNumberOfTabViewItems: once if the all-tabs count
			 changed, and tabView:didSelectTabViewItem: once if the selected tab changed.

			 Like all of BETabView, this must be used on the main thread.

			 Example:
			 @code
			 // Get count of all tabs
			 NSInteger totalTabs = tabView.allTabViewItems.count;
			 
			 // Iterate over all tabs
			 for (NSTabViewItem *tab in tabView.allTabViewItems) {
				 NSLog(@"Tab: %@, Hidden: %d", tab.label, tab.hidden);
			 }
			 @endcode
 */
@property (nonnull, copy) NSArray<__kindof NSTabViewItem *> *allTabViewItems;

/*!
 @property   numberOfAllTabViewItems
 @abstract   The total count of all tab view items (visible and hidden).
 @discussion Returns the count of items in allTabViewItems. This is a convenience
			 property equivalent to allTabViewItems.count.
			 
			 Compare with the inherited numberOfTabViewItems property, which returns
			 only the count of visible tabs.
			 
			 Example:
			 @code
			 NSInteger total = tabView.numberOfAllTabViewItems;
			 NSInteger visible = tabView.numberOfTabViewItems;
			 NSInteger hidden = total - visible;
			 NSLog(@"Tabs: %ld total, %ld visible, %ld hidden", total, visible, hidden);
			 @endcode
 */
@property (readonly) NSInteger numberOfAllTabViewItems;

#pragma mark - Display Index Methods

/*!
 @method     displayIndexAtIndex:
 @abstract   Returns the display index for a tab at the given index in allTabViewItems.
 @param      index The index in the allTabViewItems array (0-based).
 @discussion Converts an index in the allTabViewItems array to the corresponding
			 index in the tabViewItems (visible tabs) array. This accounts for any
			 hidden tabs that come before the specified index.
			 
			 This method is useful for determining where a tab appears in the visible
			 tab bar, or for converting between the two coordinate systems.
			 
			 Example:
			 If allTabViewItems contains [Tab0, Tab1(hidden), Tab2, Tab3(hidden), Tab4]
			 - displayIndexAtIndex:0 returns 0 (Tab0 is first visible)
			 - displayIndexAtIndex:1 returns NSNotFound (Tab1 is hidden)
			 - displayIndexAtIndex:2 returns 1 (Tab2 is second visible)
			 - displayIndexAtIndex:4 returns 2 (Tab4 is third visible)
 @return     The display index (position in tabViewItems), or NSNotFound if the tab
			 at the given index is hidden or the index is out of range.
 */
- (NSInteger)displayIndexAtIndex:(NSInteger)index;

/*!
 @method     displayIndexAtIndex:insertMode:
 @abstract   Returns the display index with optional insert mode.
 @param      index The index in the allTabViewItems array (0-based).
 @param      insertMode If YES, allows index to equal count (for inserting at end).
 @discussion Extended version of displayIndexAtIndex: that supports getting the
			 insertion point for adding new tabs. When insertMode is YES, the index
			 can equal allTabViewItems.count to get the insertion point after all
			 visible tabs.
			 
			 Insert mode behavior:
			 - insertMode=NO: Returns NSNotFound for hidden tabs and out-of-range indices
			 - insertMode=YES: Allows index==count and returns where to insert a new tab
			 
			 This is primarily used internally by insertTabViewItem:atIndex: but can
			 be useful for custom tab management logic.
 @return     The display index, or NSNotFound if out of range (respecting insertMode).
 */
- (NSInteger)displayIndexAtIndex:(NSInteger)index insertMode:(BOOL)insertMode;

#pragma mark - Hiding Tabs

/*!
 @method     hideTabViewItem:
 @abstract   Hides the specified tab view item.
 @param      tabViewItem The tab item to hide (must not be nil).
 @discussion Removes the tab from the visible interface but keeps it in allTabViewItems.
			 The tab's position is preserved so it can be shown again at the same location.
			 
			 Process:
			 1. Validates the tab is in allTabViewItems and not already hidden
			 2. Calls delegate's willHideTabViewItem: if implemented
			 3. Removes tab from visible tabs (with delegate temporarily disabled)
			 4. Sets the hidden property to YES
			 5. Calls delegate's didHideTabViewItem: if implemented
			 6. Sends tabView:didSelectTabViewItem: once if hiding the selected tab
				moved the selection

			 If the tab is already hidden, not in the tab view, or nil, this method
			 does nothing and returns silently.

			 Example:
			 @code
			 // Hide a specific tab
			 [tabView hideTabViewItem:advancedTab];
			 
			 // The tab is now hidden but still in allTabViewItems
			 NSLog(@"Hidden: %d", advancedTab.hidden); // YES
			 NSLog(@"Still in all tabs: %d", [tabView.allTabViewItems containsObject:advancedTab]); // YES
			 @endcode
 */
- (void)hideTabViewItem:(nonnull NSTabViewItem *)tabViewItem;

/*!
 @method     hideTabViewItemAtIndex:
 @abstract   Hides the tab view item at the specified index.
 @param      index The index in the allTabViewItems array (0-based).
 @discussion Convenience method that hides the tab at the given index in allTabViewItems.
			 Equivalent to calling hideTabViewItem: with allTabViewItemAtIndex:.
			 
			 Does nothing if the index is out of range.
			 
			 Example:
			 @code
			 // Hide the second tab (index 1)
			 [tabView hideTabViewItemAtIndex:1];
			 @endcode
 */
- (void)hideTabViewItemAtIndex:(NSInteger)index;

/*!
 @method     hideTabViewItemWithIdentifier:
 @abstract   Hides the tab view item with the specified identifier.
 @param      identifier The identifier to search for (must not be nil).
 @discussion Finds the tab with the matching identifier in allTabViewItems and hides it.
			 Uses isEqual: for comparison, so any object type can be used as an identifier.
			 
			 Does nothing if no matching tab is found or if identifier is nil.
			 
			 Example:
			 @code
			 // Hide the advanced tab by identifier
			 [tabView hideTabViewItemWithIdentifier:@"advanced"];
			 @endcode
 */
- (void)hideTabViewItemWithIdentifier:(nonnull id)identifier;

#pragma mark - Showing Tabs

/*!
 @method     showTabViewItem:
 @abstract   Shows a previously hidden tab view item.
 @param      tabViewItem The tab item to show (must not be nil).
 @discussion Adds the tab back to the visible interface at its preserved position.
			 The tab is inserted into tabViewItems at the appropriate index based
			 on its position in allTabViewItems and the visibility of other tabs.
			 
			 Process:
			 1. Validates the tab is in allTabViewItems and currently hidden
			 2. Calls delegate's willShowTabViewItem: if implemented
			 3. Calculates the correct insertion position
			 4. Inserts tab into visible tabs (with delegate temporarily disabled)
			 5. Sets the hidden property to NO
			 6. Calls delegate's didShowTabViewItem: if implemented
			 
			 If the tab is already visible, not in the tab view, or nil, this method
			 does nothing and returns silently.

			 Example:
			 @code
			 // Show a hidden tab
			 [tabView showTabViewItem:advancedTab];
			 
			 // The tab is now visible at its original position
			 NSLog(@"Hidden: %d", advancedTab.hidden); // NO
			 NSLog(@"Display index: %ld", [tabView indexOfTabViewItem:advancedTab]);
			 @endcode
 */
- (void)showTabViewItem:(nonnull NSTabViewItem *)tabViewItem;

/*!
 @method     showTabViewItemAtIndex:
 @abstract   Shows the tab view item at the specified index.
 @param      index The index in the allTabViewItems array (0-based).
 @discussion Convenience method that shows the tab at the given index in allTabViewItems.
			 Equivalent to calling showTabViewItem: with allTabViewItemAtIndex:.
			 
			 Does nothing if the index is out of range.
			 
			 Example:
			 @code
			 // Show the second tab (index 1)
			 [tabView showTabViewItemAtIndex:1];
			 @endcode
 */
- (void)showTabViewItemAtIndex:(NSInteger)index;

/*!
 @method     showTabViewItemWithIdentifier:
 @abstract   Shows the tab view item with the specified identifier.
 @param      identifier The identifier to search for (must not be nil).
 @discussion Finds the tab with the matching identifier in allTabViewItems and shows it.
			 Uses isEqual: for comparison, so any object type can be used as an identifier.
			 
			 Does nothing if no matching tab is found or if identifier is nil.
			 
			 Example:
			 @code
			 // Show the advanced tab by identifier
			 [tabView showTabViewItemWithIdentifier:@"advanced"];
			 @endcode
 */
- (void)showTabViewItemWithIdentifier:(nonnull id)identifier;

#pragma mark - Accessing All Tabs

/*!
 @method     indexOfAllTabViewItem:
 @abstract   Returns the index of a tab in allTabViewItems.
 @param      tabViewItem The tab item to find (must not be nil).
 @discussion Searches allTabViewItems for the specified tab item. This searches both
			 visible and hidden tabs.
			 
			 Compare with the inherited indexOfTabViewItem: method, which only searches
			 visible tabs.
 @return     The index in allTabViewItems (0-based), or NSNotFound if not found.
 */
- (NSInteger)indexOfAllTabViewItem:(nonnull NSTabViewItem *)tabViewItem;

/*!
 @method     allTabViewItemAtIndex:
 @abstract   Returns the tab at the specified index in allTabViewItems.
 @param      index The index in the allTabViewItems array (0-based).
 @discussion Provides access to any tab (visible or hidden) by its index in the
			 complete array. This is useful for iterating over all tabs or accessing
			 tabs by their absolute position.
			 
			 Compare with the inherited tabViewItemAtIndex: method, which only accesses
			 visible tabs.
 @return     The tab item at the specified index, or nil if index is out of bounds.
 */
- (nullable NSTabViewItem *)allTabViewItemAtIndex:(NSInteger)index;

/*!
 @method     indexOfAllTabViewItemWithIdentifier:
 @abstract   Returns the index of the tab with the specified identifier.
 @param      identifier The identifier to search for (must not be nil).
 @discussion Searches allTabViewItems for a tab whose identifier matches using isEqual:.
			 This searches both visible and hidden tabs.
			 
			 The search is performed linearly, so for large numbers of tabs, consider
			 caching the result if multiple lookups are needed.
			 
			 Compare with the inherited indexOfTabViewItemWithIdentifier: method, which
			 only searches visible tabs.
 @return     The index in allTabViewItems (0-based), or NSNotFound if not found or
			 identifier is nil.
 */
- (NSInteger)indexOfAllTabViewItemWithIdentifier:(nonnull id)identifier;

/*!
 @method     allTabViewItemWithIdentifier:
 @abstract   Returns the tab with the specified identifier.
 @param      identifier The identifier to search for (must not be nil).
 @discussion Searches allTabViewItems for a tab whose identifier matches using isEqual:.
			 This is a convenience method that combines indexOfAllTabViewItemWithIdentifier:
			 and allTabViewItemAtIndex:.
			 
			 Searches both visible and hidden tabs.
			 
			 Example:
			 @code
			 // Find a tab by identifier (works whether visible or hidden)
			 NSTabViewItem *settingsTab = [tabView allTabViewItemWithIdentifier:@"settings"];
			 if (settingsTab) {
				 if (settingsTab.hidden) {
					 NSLog(@"Settings tab exists but is hidden");
				 } else {
					 [tabView selectTabViewItem:settingsTab];
				 }
			 }
			 @endcode
 @return     The matching tab item, or nil if not found or identifier is nil.
 */
- (nullable NSTabViewItem *)allTabViewItemWithIdentifier:(nonnull id)identifier;

@end

#endif /* BETabView_h */
#endif // TARGET_OS_OSX
