#import <TargetConditionals.h>
#if TARGET_OS_OSX
/*!
 @header        BEWindowControllerManager.h
 @copyright     -© 2025 Delicense - @belisoful. All rights released.
 @date          2025-11-11
 @author        belisoful@icloud.com
 @abstract      An application singleton that tracks all active BEWindowController instances.
 @discussion    BEWindowControllerManager listens for window load and close notifications
				(specifically `BEWindowDidLoadNotification` and `NSWindowWillCloseNotification`)
				to automatically maintain a list of all active `BEWindowController`
				instances.

				This provides a centralized way to query for windows, such as finding
				all windows of a certain class or the first available window. It
				also enables advanced behaviors, like the cascade-closing of child
				windows when a parent window is closed.

				The manager also supports fast enumeration (for...in) and subscripting
				for convenient access.

				Use the application-wide instance via `+sharedManager`. Because every instance
				observes the global load/close notifications, you should normally use the
				shared instance rather than creating your own; `-init` remains available mainly
				for isolated/testing scenarios. The manager is intended to be used on the main
				thread (it is driven by AppKit notifications, which are delivered on the main
				thread).

				Example:
				@code
				BEWindowControllerManager *manager = BEWindowControllerManager.sharedManager;

				// Find the first editor window
				EditorWC *editor = manager[EditorWC.class];

				// Iterate over all known window controllers
				for (NSWindowController *wc in manager) {
					// ...
				}
				@endcode
*/

#ifndef BEWindowControllerManager_h
#define BEWindowControllerManager_h

#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

/*!
 @class         BEWindowControllerManager
 @abstract      Manages and tracks all active `BEWindowController` instances.
 @discussion    This class conforms to `NSFastEnumeration` to allow direct iteration,
				e.g., `for (NSWindowController *wc in manager)`. It also supports
				indexed (`manager[0]`) and keyed (`manager[MyClass.class]`) subscripting.

				Controllers register themselves automatically: any `BEWindowController`
				whose window loads is added on `BEWindowDidLoadNotification`, and removed
				on `NSWindowWillCloseNotification`. There is no explicit "register" call.

				@code
				BEWindowControllerManager *manager = BEWindowControllerManager.sharedManager;

				// Showing a BEWindowController loads its window, which registers it.
				[myEditorWindowController showWindow:self];

				// Iterate the immutable snapshot so closing a controller mid-loop is safe;
				// iterating the manager directly raises if the list mutates during the loop.
				for (NSWindowController *wc in manager.windowControllers) {
					NSLog(@"Tracking: %@", wc.window.title);
				}

				EditorWindowController *editor = manager[EditorWindowController.class];
				@endcode
*/
NS_SWIFT_NAME(WindowControllerManager)
@interface BEWindowControllerManager : NSObject <NSFastEnumeration>

/*!
 @property      sharedManager
 @abstract      The application-wide shared manager instance.
 @discussion    Lazily created on first access via `dispatch_once`. This is the canonical
				instance to use; it begins observing window load/close notifications as soon as
				it is created. `-init` is also available for isolated instances (e.g. unit
				tests), but be aware that every instance reacts to the same global notifications.
*/
@property (class, readonly, strong) BEWindowControllerManager *sharedManager NS_SWIFT_NAME(shared);

/*!
 @property      windowControllers
 @abstract      A snapshot array of all currently tracked window controllers.
 @discussion    This property is `copy`, so it returns an immutable snapshot of the
				current list of controllers, safe to iterate even if the manager's list
				subsequently changes. The manager is intended for main-thread use.

				Iterating the manager directly (`for (wc in manager)`) follows standard
				NSMutableArray semantics: mutating the manager during that loop raises
				"mutated while being enumerated". If you need to add/close controllers while
				iterating, iterate THIS snapshot instead: `for (wc in manager.windowControllers)`.
*/
@property (readonly, copy) NSArray<NSWindowController*> *windowControllers;

/*!
 @method        firstWindowControllerOfKind:
 @abstract      Finds the first window controller that is an instance of a given class.
 @param         wcClass The `Class` to search for (e.g., `MyWindowController.class`). A nil
				class returns nil.
 @discussion    Iterates through the tracked controllers and returns the first object
				for which `[wc isKindOfClass:wcClass]` is true.
 @return        The matching `NSWindowController`, or `nil` if not found.
*/
- (nullable NSWindowController*)firstWindowControllerOfKind:(nullable Class)wcClass
NS_SWIFT_NAME(firstWindowController(ofKind:));

/*!
 @method        windowControllersOfKind:
 @abstract      Finds all window controllers that are instances of a given class.
 @param         wcClass The `Class` to search for (e.g., `MyWindowController.class`). A nil
				class returns an empty array.
 @discussion    Iterates through all tracked controllers and returns an array of all
				objects for which `[wc isKindOfClass:wcClass]` is true.
 @return        An array of matching `NSWindowController` instances. Returns an
				empty array if none are found.
*/
- (NSArray<NSWindowController*> *)windowControllersOfKind:(nullable Class)wcClass
NS_SWIFT_NAME(windowControllers(ofKind:));

/*!
 @method        objectAtIndexedSubscript:
 @abstract      Provides support for indexed subscripting (e.g., `manager[0]`).
 @param         idx The index of the window controller to retrieve.
 @return        The `NSWindowController` at the specified index.
*/
- (nullable NSWindowController *)objectAtIndexedSubscript:(NSUInteger)idx;

/*!
 @method        objectForKeyedSubscript:
 @abstract      Provides support for keyed subscripting (e.g., `manager[MyClass.class]`).
 @param         key A `Class` object.
 @discussion    This method is a convenience wrapper for `firstWindowControllerOfKind:`.
 @return        The first matching `NSWindowController`, or `nil`.
*/
- (nullable NSWindowController *)objectForKeyedSubscript:(nonnull Class)key;

/*!
 @method        countByEnumeratingWithState:objects:count:
 @abstract      Provides support for `NSFastEnumeration` (e.g., `for...in` loops).
 @param         state A structure to hold the state of the enumeration.
 @param         stackbuf A C-style array buffer for returned objects.
 @param         len The maximum number of objects to return in `stackbuf`.
 @return        The number of objects returned in `stackbuf`.
*/
- (NSUInteger)countByEnumeratingWithState:(nonnull NSFastEnumerationState *)state objects:(__unsafe_unretained id _Nonnull [_Nonnull])stackbuf count:(NSUInteger)len;

@end

NS_ASSUME_NONNULL_END

#endif // !BEWindowControllerManager_h
#endif // TARGET_OS_OSX
