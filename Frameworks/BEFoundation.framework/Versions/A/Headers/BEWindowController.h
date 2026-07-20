#import <TargetConditionals.h>
#if TARGET_OS_OSX
/*!
 @header        BEWindowController.h
 @copyright     -© 2025 Delicense - @belisoful. All rights released.
 @date          2025-11-11
 @author        belisoful@icloud.com
 @abstract      A base window controller class that supports parent/child relationships and document-wide closing.
 @discussion    BEWindowController extends NSWindowController to provide a framework for managing window
				controller hierarchies (parents and children) and for coordinating the closing of all windows
				associated with a single document.
 
				This class provides a default, built-in implementation for both the parent and child protocols.
				Subclasses explicitly opt-in to this functionality by conforming to BEParentWindowController
				and/or BEChildWindowController.
*/

#ifndef BEWindowController_h
#define BEWindowController_h

#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

/*!
 @const         BEWindowDidLoadNotification
 @abstract      A notification posted after the window has loaded, the delegate has been notified, and super has been called.
 @discussion    This supplements the standard NSWindowDelegate methods, allowing for observers to react to the window's load. The `object` of the notification is the `NSWindow` instance that has loaded.
*/
APPKIT_EXTERN NSNotificationName const BEWindowDidLoadNotification;

/*!
 @const         kBEIsPrimaryWindowControllerKey
 @abstract      An `NSCoding` key for persisting the `isPrimaryWindowController` property.
 @discussion    Used when encoding or decoding the window controller, such as when restoring a document's windows.
*/
#define kBEIsPrimaryWindowControllerKey         (@"BEIsPrimaryWindowController")


/*!
 @protocol      BEWindowDelegate
 @abstract      Extends `NSWindowDelegate` to include a `windowDidLoad:` notification-based callback.
 @discussion    This protocol provides a convenient hook for window delegates to respond to the `windowDidLoad` event, similar to how `NSViewController`'s `viewDidLoad` works.
*/
@protocol BEWindowDelegate <NSWindowDelegate>
@optional

/*!
 @method        windowDidLoad:
 @abstract      Called from within `-[BEWindowController windowDidLoad]` after `super` has been called.
 @discussion    This provides a convenient hook for delegates that need to perform setup *after* the window is loaded, similar to `-[NSViewController viewDidLoad]`.
 @param         notification The notification object containing the window as its `object`.
*/
- (void)windowDidLoad:(NSNotification *)notification NS_SWIFT_UI_ACTOR;
@end




/*!
 @protocol      BEParentWindowControllerBase
 @abstract      Base protocol defining the implementation interface for parent window controller functionality.
 @discussion    This protocol defines the actual methods and properties. BEWindowController implements this protocol.
				Subclasses should conform to BEParentWindowController (not this protocol directly) to activate the functionality.
*/
@protocol BEParentWindowControllerBase <NSObject>

/*!
 @property      childControllers
 @abstract      An array of all `NSWindowController` instances managed by this parent.
 @discussion    This array provides a snapshot of the children. It is read-only. Modifying the hierarchy should be done via `addChildWindowController:` and `removeChildWindowController:`.
*/
@property (nonnull, readonly, nonatomic) NSArray<NSWindowController*>    *childControllers;

/*!
 @method        containsChildWindowController:
 @abstract      Tests whether the given controller is in this parent's set of children.
 @param         childController The window controller to test for membership.
 @return		YES if the parent window controller contains @c childController.
*/
- (BOOL)containsChildWindowController:(NSWindowController *)childController;

/*!
 @method        addChildWindowController:
 @abstract      Adds a window controller to the parent's set of children.
 @param         childController The window controller to add.
*/
- (void)addChildWindowController:(NSWindowController *)childController;

/*!
 @method        removeChildWindowController:
 @abstract      Removes a window controller from the parent's set of children.
 @param         childController The window controller to remove.
 @result        `YES` if the child was successfully removed, `NO` if it was not found.
*/
- (BOOL)removeChildWindowController:(NSWindowController *)childController;
@end


/*!
 @protocol      BEParentWindowController
 @abstract      Activation protocol for parent window controller functionality.
 @discussion    Subclasses of BEWindowController should conform to this protocol to explicitly activate
				parent window controller capabilities. The implementation is inherited from BEWindowController.
*/
@protocol BEParentWindowController <BEParentWindowControllerBase>
@end




/*!
 @protocol      BEChildWindowControllerBase
 @abstract      Base protocol defining the implementation interface for child window controller functionality.
 @discussion    This protocol defines the actual methods and properties. BEWindowController implements this protocol.
				Subclasses should conform to BEChildWindowController (not this protocol directly) to activate the functionality.
*/
@protocol BEChildWindowControllerBase <NSObject>

/*!
 @property      parentController
 @abstract      The parent window controller that manages this window controller.
 @discussion    Setting this property detaches the controller from its current parent (if any) and then
				attaches it to the new parent, keeping both parents' `childControllers` sets consistent.
				Reparenting (A -> B) is safe: the child ends up in exactly one parent. Setting it to `nil`
				removes it from its current parent. The reference is weak to prevent retain cycles.
*/
@property (nullable, nonatomic) NSWindowController    *parentController;
@end


/*!
 @protocol      BEChildWindowController
 @abstract      Activation protocol for child window controller functionality.
 @discussion    Subclasses of BEWindowController should conform to this protocol to explicitly activate
				child window controller capabilities. The implementation is inherited from BEWindowController.
*/
@protocol BEChildWindowController <BEChildWindowControllerBase>
@end





/*!
 @class         BEWindowController
 @abstract      A base `NSWindowController` that implements parent/child tracking and document-wide closing logic.
 @discussion    This class provides the implementation for both BEParentWindowControllerBase and BEChildWindowControllerBase.
				Subclasses can explicitly activate this functionality by conforming to BEParentWindowController and/or
				BEChildWindowController. No additional implementation is required in subclasses - the functionality is
				inherited automatically.
 
				It also introduces the concept of a "primary" window controller. When a primary window is closed, it takes responsibility for closing all other windows associated with the same `NSDocument`.
 
				A subclass opts in to parent/child support by conforming to
				BEParentWindowController and/or BEChildWindowController; no implementation is
				needed — everything is inherited from BEWindowController.

				Building a hierarchy and persisting state. Because the class adopts
				NSSecureCoding and can be instantiated from a nib in Interface Builder
				(set the File's Owner / window controller class to a BEWindowController
				subclass), no extra wiring is required:
				@code
				MyWindowController *parent = [[MyWindowController alloc] initWithWindowNibName:@"Main"];
				MyWindowController *inspector = [[MyWindowController alloc] initWithWindowNibName:@"Inspector"];

				// Linking either side keeps both childControllers and parentController consistent.
				inspector.parentController = parent;     // parent.childControllers now contains inspector

				parent.isPrimaryWindowController = YES;  // closing parent cascades to the document's windows

				NSData *data = [NSKeyedArchiver archivedDataWithRootObject:parent
													requiringSecureCoding:YES
																	error:NULL];
				@endcode
*/
@interface BEWindowController : NSWindowController <BEParentWindowControllerBase, BEChildWindowControllerBase, NSSecureCoding>

/*!
 @property      isPrimaryWindowController
 @abstract      Indicates that this is the "primary" window for a document.
 @discussion    When the primary window controller is closed (via its `close` method), it will trigger `closeDocumentWindowControllers` to close all other window controllers associated with the same document. This is useful for main document windows.
*/
@property (nonatomic, assign) BOOL         isPrimaryWindowController;

/*!
 @method        closeDocumentWindowControllers
 @abstract      Closes all other window controllers that share the same `document` as this controller.
 @discussion    This method iterates over `self.document.windowControllers` and calls `close` on every controller except for `self`. This is typically triggered automatically when a controller with `isPrimaryWindowController = YES` is closed.
*/
- (void)closeDocumentWindowControllers;

@end

NS_ASSUME_NONNULL_END

#endif // !BEWindowController_h
#endif // TARGET_OS_OSX
