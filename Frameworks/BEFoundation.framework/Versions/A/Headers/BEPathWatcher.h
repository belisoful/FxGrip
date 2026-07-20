/*!
 * @header		BEPathWatcher.h
 * @copyright 	-© 2025 Delicense - @belisoful. All rights released.
 * @date		2025-01-01
 * @author		belisoful@icloud.com
 * @abstract	A Grand Central Dispatch-based file system monitoring utility.
 * @discussion	This class monitors file system paths for changes using GCD's dispatch sources. It provides flexible callback mechanisms including blocks, target-action, and protocol-based notifications.
 */

#import <Foundation/Foundation.h>

@class BEPathWatcher;

NS_ASSUME_NONNULL_BEGIN

/*!
 * @protocol BEPathWatcher
 * @abstract Protocol for receiving internal path change notifications.
 * @discussion This protocol provides an internal hook that subclasses can implement to receive notifications before public callbacks are executed. This is useful for implementing custom logic that should always run regardless of the callback mechanism used.
 */
@protocol BEPathWatcher

@optional

/*!
 * @method pathDidChangeWithFlags:
 * @abstract Internal method called whenever a change is detected in the watched path.
 * @discussion This method is called before any public callback (block, target/selector) is executed. Subclasses can override this method to implement custom logic that should always run on a change event.
 * @param flags The dispatch source event flags indicating the type of change that occurred. This is a bitmask of DISPATCH_VNODE_* constants.
 */
- (void)pathDidChangeWithFlags:(unsigned long)flags;

@end

/*!
 * @const BEPathWatcherDefaultEventMask
 * @abstract The default event mask used when no specific mask is provided.
 * @discussion This mask includes DISPATCH_VNODE_WRITE, DISPATCH_VNODE_DELETE, DISPATCH_VNODE_EXTEND, and DISPATCH_VNODE_RENAME events, covering the most common file system changes.
 */
extern unsigned long const BEPathWatcherDefaultEventMask;

/*!
 * @class BEPathWatcher
 * @abstract A class to monitor file system paths for changes using Grand Central Dispatch.
 * @discussion This class uses GCD's dispatch sources to monitor a file or directory for various types of changes. It provides three mechanisms for receiving notifications: blocks, target-action selectors, and protocol methods. The watcher automatically starts monitoring when both a path and callback mechanism are configured.
 *
 * ## Usage Examples
 *
 * **Block-based monitoring:**
 * ```objc
 * BEPathWatcher *watcher = [BEPathWatcher watcherForPath:@"/path/to/watch"
 *                                             withBlock:^(BEPathWatcher *w, unsigned long flags) {
 *     NSLog(@"Path changed: %@", w.path);
 * }];
 * ```
 *
 * **Target-action monitoring:**
 * ```objc
 * BEPathWatcher *watcher = [BEPathWatcher watcherForPath:@"/path/to/watch"
 *                                               target:self
 *                                             selector:@selector(pathChanged:)];
 * ```
 *
 * The watcher automatically stops monitoring when the watched path itself is deleted, renamed, or
 * revoked, since the underlying file descriptor becomes invalid.
 *
 * Callbacks (the block, the target-selector, and the subclass `pathDidChangeWithFlags:` hook) are
 * delivered on the main queue. They are invoked without the watcher's internal lock held, so a
 * callback may safely call back into the watcher — including from another thread — without
 * deadlocking. Configuration methods are safe to call from any thread.
 */
@interface BEPathWatcher : NSObject <BEPathWatcher>

#pragma mark - Properties

/*!
 * @property path
 * @abstract The file system path currently being watched.
 * @discussion Setting this property will stop any current monitoring and restart it with the new path if monitoring was previously active. Setting to nil will stop monitoring. The path is copied when set. If a start fails because the path cannot be opened (e.g. it does not exist), the path is cleared back to nil.
 */
@property (nonatomic, copy, nullable) NSString *path;

/*!
 * @property eventMask
 * @abstract The bitmask of DISPATCH_VNODE_* events to monitor.
 * @discussion Changing this property will restart monitoring with the new event mask if monitoring was previously active. Common values include DISPATCH_VNODE_WRITE, DISPATCH_VNODE_DELETE, DISPATCH_VNODE_EXTEND, and DISPATCH_VNODE_RENAME.
 */
@property (nonatomic, assign) unsigned long eventMask;

/*!
 * @property eventHandler
 * @abstract The block to execute when a file system event occurs.
 * @discussion Setting this property clears any previously set target and selector. The block receives the watcher instance and the event flags as parameters.
 */
@property (nonatomic, copy, nullable) void (^eventHandler)(BEPathWatcher *watcher, unsigned long event);

/*!
 * @property target
 * @abstract The target object for selector-based callbacks.
 * @discussion This property is read-only. Use setTarget:selector: to set both target and selector together. The target is stored as a weak reference.
 */
@property (nonatomic, readonly, nullable) id target;

/*!
 * @property selector
 * @abstract The selector to call on the target when events occur.
 * @discussion This property is read-only. Use setTarget:selector: to set both target and selector together. The selector should accept either just the watcher, or the watcher and event flags.
 */
@property (nonatomic, readonly, nullable) SEL selector;

/*!
 * @property isActive
 * @abstract Whether the watcher is currently monitoring the file system.
 * @discussion Setting this property to YES will start monitoring if a path and callback mechanism are configured. Setting to NO will stop monitoring. This property is automatically managed by the watch* methods.
 */
@property (nonatomic, assign) BOOL isActive;

#pragma mark - Configuration

/*!
 * @method setTarget:selector:
 * @abstract Sets the target and selector for callback notifications.
 * @discussion This method clears any previously set event handler block. The target is stored as a weak reference. The selector should have one of these signatures:
 * - `-(void)methodName:(BEPathWatcher *)watcher;`
 * - `-(void)methodName:(BEPathWatcher *)watcher flags:(unsigned long)flags;`
 * - `-(void)methodName:(unsigned long)flags;`
 * @param target The object to receive notifications, stored as a weak reference.
 * @param selector The selector to call on the target.
 */
- (void)setTarget:(nullable id)target selector:(nullable SEL)selector;

#pragma mark - Class Factory Methods

/*!
 * @method watcherForPath:target:selector:
 * @abstract Creates a new watcher with a path, target, and selector.
 * @discussion This method creates a new watcher instance and immediately starts monitoring the specified path. Monitoring begins automatically when both path and callback mechanism are provided.
 * @param path The file system path to monitor.
 * @param target The object to receive notifications.
 * @param selector The selector to call on the target.
 * @return A new watcher instance, or nil if monitoring could not be started.
 */
+ (nullable instancetype)watcherForPath:(NSString *)path target:(id)target selector:(SEL)selector;

/*!
 * @method watcherForPath:eventMask:target:selector:
 * @abstract Creates a new watcher with a path, event mask, target, and selector.
 * @discussion This method creates a new watcher instance with a custom event mask and immediately starts monitoring the specified path.
 * @param path The file system path to monitor.
 * @param eventMask The bitmask of DISPATCH_VNODE_* events to monitor.
 * @param target The object to receive notifications.
 * @param selector The selector to call on the target.
 * @return A new watcher instance, or nil if monitoring could not be started.
 */
+ (nullable instancetype)watcherForPath:(NSString *)path eventMask:(unsigned long)eventMask target:(id)target selector:(SEL)selector;

/*!
 * @method watcherForPath:withBlock:
 * @abstract Creates a new watcher with a path and event handler block.
 * @discussion This method creates a new watcher instance and immediately starts monitoring the specified path using a block callback.
 * @param path The file system path to monitor.
 * @param block The block to execute when events occur.
 * @return A new watcher instance, or nil if monitoring could not be started.
 */
+ (nullable instancetype)watcherForPath:(NSString *)path withBlock:(void (^_Nonnull)(BEPathWatcher *watcher, unsigned long event))block;

/*!
 * @method watcherForPath:eventMask:withBlock:
 * @abstract Creates a new watcher with a path, event mask, and event handler block.
 * @discussion This method creates a new watcher instance with a custom event mask and immediately starts monitoring the specified path using a block callback.
 * @param path The file system path to monitor.
 * @param eventMask The bitmask of DISPATCH_VNODE_* events to monitor.
 * @param block The block to execute when events occur.
 * @return A new watcher instance, or nil if monitoring could not be started.
 */
+ (nullable instancetype)watcherForPath:(NSString *)path eventMask:(unsigned long)eventMask withBlock:(void (^_Nonnull)(BEPathWatcher *watcher, unsigned long event))block;

#pragma mark - Initializers

/*!
 * @method initWithPath:
 * @abstract Initializes a watcher with a path using the default event mask.
 * @discussion This initializer creates a watcher but does not start monitoring. Call one of the watch* methods or set isActive to YES to begin monitoring.
 * @param path The file system path to monitor.
 * @return An initialized watcher instance.
 */
- (nullable instancetype)initWithPath:(NSString *)path;

/*!
 * @method initWithPath:eventMask:
 * @abstract Initializes a watcher with a path and custom event mask.
 * @discussion This initializer creates a watcher but does not start monitoring. Call one of the watch* methods or set isActive to YES to begin monitoring.
 * @param path The file system path to monitor.
 * @param mask The bitmask of DISPATCH_VNODE_* events to monitor.
 * @return An initialized watcher instance.
 */
- (nullable instancetype)initWithPath:(NSString *)path eventMask:(unsigned long)mask;

/*!
 * @method initWithTarget:selector:
 * @abstract Initializes a watcher with a target and selector using the default event mask.
 * @discussion This initializer creates a watcher but does not start monitoring. Set a path and call one of the watch* methods to begin monitoring.
 * @param target The object to receive notifications.
 * @param selector The selector to call on the target.
 * @return An initialized watcher instance.
 */
- (nullable instancetype)initWithTarget:(id)target selector:(SEL)selector;

/*!
 * @method initWithBlock:
 * @abstract Initializes a watcher with an event handler block using the default event mask.
 * @discussion This initializer creates a watcher but does not start monitoring. Set a path and call one of the watch* methods to begin monitoring.
 * @param block The block to execute when events occur.
 * @return An initialized watcher instance.
 */
- (nullable instancetype)initWithBlock:(void (^_Nonnull)(BEPathWatcher *watcher, unsigned long event))block;

/*!
 * @method initWithEventMask:target:selector:
 * @abstract Initializes a watcher with an event mask, target, and selector.
 * @discussion This initializer creates a watcher but does not start monitoring. Set a path and call one of the watch* methods to begin monitoring.
 * @param eventMask The bitmask of DISPATCH_VNODE_* events to monitor.
 * @param target The object to receive notifications.
 * @param selector The selector to call on the target.
 * @return An initialized watcher instance.
 */
- (nullable instancetype)initWithEventMask:(unsigned long)eventMask target:(id)target selector:(SEL)selector;

/*!
 * @method initWithEventMask:withBlock:
 * @abstract Initializes a watcher with an event mask and event handler block.
 * @discussion This initializer creates a watcher but does not start monitoring. Set a path and call one of the watch* methods to begin monitoring.
 * @param eventMask The bitmask of DISPATCH_VNODE_* events to monitor.
 * @param block The block to execute when events occur.
 * @return An initialized watcher instance.
 */
- (nullable instancetype)initWithEventMask:(unsigned long)eventMask withBlock:(void (^_Nonnull)(BEPathWatcher *watcher, unsigned long event))block;

/*!
 * @method initWithPath:target:selector:
 * @abstract Initializes a watcher with a path, target, and selector, then starts monitoring.
 * @discussion This initializer creates a watcher and immediately starts monitoring the specified path. Returns nil if monitoring cannot be started.
 * @param path The file system path to monitor.
 * @param target The object to receive notifications.
 * @param selector The selector to call on the target.
 * @return An initialized and active watcher instance, or nil if monitoring failed.
 */
- (nullable instancetype)initWithPath:(NSString *)path target:(id)target selector:(SEL)selector;

/*!
 * @method initWithPath:withBlock:
 * @abstract Initializes a watcher with a path and event handler block, then starts monitoring.
 * @discussion This initializer creates a watcher and immediately starts monitoring the specified path. Returns nil if monitoring cannot be started.
 * @param path The file system path to monitor.
 * @param block The block to execute when events occur.
 * @return An initialized and active watcher instance, or nil if monitoring failed.
 */
- (nullable instancetype)initWithPath:(NSString *)path withBlock:(void (^_Nonnull)(BEPathWatcher *watcher, unsigned long event))block;

/*!
 * @method initWithPath:eventMask:target:selector:
 * @abstract Initializes a watcher with a path, event mask, target, and selector, then starts monitoring.
 * @discussion This initializer creates a watcher and immediately starts monitoring the specified path with a custom event mask. Returns nil if monitoring cannot be started.
 * @param path The file system path to monitor.
 * @param eventMask The bitmask of DISPATCH_VNODE_* events to monitor.
 * @param target The object to receive notifications.
 * @param selector The selector to call on the target.
 * @return An initialized and active watcher instance, or nil if monitoring failed.
 */
- (nullable instancetype)initWithPath:(NSString *)path eventMask:(unsigned long)eventMask target:(id)target selector:(SEL)selector;

/*!
 * @method initWithPath:eventMask:withBlock:
 * @abstract Initializes a watcher with a path, event mask, and event handler block, then starts monitoring.
 * @discussion This initializer creates a watcher and immediately starts monitoring the specified path with a custom event mask. Returns nil if monitoring cannot be started.
 * @param path The file system path to monitor.
 * @param eventMask The bitmask of DISPATCH_VNODE_* events to monitor.
 * @param block The block to execute when events occur.
 * @return An initialized and active watcher instance, or nil if monitoring failed.
 */
- (nullable instancetype)initWithPath:(NSString *)path eventMask:(unsigned long)eventMask withBlock:(void (^_Nonnull)(BEPathWatcher *watcher, unsigned long event))block;

#pragma mark - Watching Methods

/*!
 * @method watchPath:
 * @abstract Starts monitoring the specified path with the current callback configuration.
 * @discussion This method stops any current monitoring and starts watching the new path. Monitoring begins automatically if a callback mechanism is configured.
 * @param path The file system path to monitor.
 * @return YES if monitoring started successfully, NO otherwise.
 */
- (BOOL)watchPath:(NSString *)path;

/*!
 * @method watchPath:target:selector:
 * @abstract Starts monitoring the specified path with target-selector callbacks.
 * @discussion This method stops any current monitoring, configures the target and selector, and starts watching the path. The current event mask is preserved.
 * @param path The file system path to monitor.
 * @param target The object to receive notifications.
 * @param selector The selector to call on the target.
 * @return YES if monitoring started successfully, NO otherwise.
 */
- (BOOL)watchPath:(NSString *)path target:(id)target selector:(SEL)selector;

/*!
 * @method watchPath:withBlock:
 * @abstract Starts monitoring the specified path with block callbacks.
 * @discussion This method stops any current monitoring, configures the event handler block, and starts watching the path. The current event mask is preserved.
 * @param path The file system path to monitor.
 * @param block The block to execute when events occur.
 * @return YES if monitoring started successfully, NO otherwise.
 */
- (BOOL)watchPath:(NSString *)path withBlock:(void (^_Nonnull)(BEPathWatcher *watcher, unsigned long event))block;

/*!
 * @method watchPath:eventMask:target:selector:
 * @abstract Starts monitoring the specified path with a custom event mask and target-selector callbacks.
 * @discussion This method stops any current monitoring, configures all parameters, and starts watching the path.
 * @param path The file system path to monitor.
 * @param eventMask The bitmask of DISPATCH_VNODE_* events to monitor.
 * @param target The object to receive notifications.
 * @param selector The selector to call on the target.
 * @return YES if monitoring started successfully, NO otherwise.
 */
- (BOOL)watchPath:(NSString *)path eventMask:(unsigned long)eventMask target:(id)target selector:(SEL)selector;

/*!
 * @method watchPath:eventMask:withBlock:
 * @abstract Starts monitoring the specified path with a custom event mask and block callbacks.
 * @discussion This method stops any current monitoring, configures all parameters, and starts watching the path.
 * @param path The file system path to monitor.
 * @param eventMask The bitmask of DISPATCH_VNODE_* events to monitor.
 * @param block The block to execute when events occur.
 * @return YES if monitoring started successfully, NO otherwise.
 */
- (BOOL)watchPath:(NSString *)path eventMask:(unsigned long)eventMask withBlock:(void (^_Nonnull)(BEPathWatcher *watcher, unsigned long event))block;

/*!
 * @method watchWithTarget:selector:
 * @abstract Starts monitoring the current path with target-selector callbacks.
 * @discussion This method stops any current monitoring, configures the target and selector, and starts watching the current path. The path and event mask are preserved.
 * @param target The object to receive notifications.
 * @param selector The selector to call on the target.
 * @return YES if monitoring started successfully, NO otherwise.
 */
- (BOOL)watchWithTarget:(id)target selector:(SEL)selector;

/*!
 * @method watchWithBlock:
 * @abstract Starts monitoring the current path with block callbacks.
 * @discussion This method stops any current monitoring, configures the event handler block, and starts watching the current path. The path and event mask are preserved.
 * @param block The block to execute when events occur.
 * @return YES if monitoring started successfully, NO otherwise.
 */
- (BOOL)watchWithBlock:(void (^_Nonnull)(BEPathWatcher *watcher, unsigned long event))block;

/*!
 * @method watchWithEventMask:target:selector:
 * @abstract Starts monitoring the current path with a custom event mask and target-selector callbacks.
 * @discussion This method stops any current monitoring, configures the event mask and callbacks, and starts watching the current path. The path is preserved.
 * @param eventMask The bitmask of DISPATCH_VNODE_* events to monitor.
 * @param target The object to receive notifications.
 * @param selector The selector to call on the target.
 * @return YES if monitoring started successfully, NO otherwise.
 */
- (BOOL)watchWithEventMask:(unsigned long)eventMask target:(id)target selector:(SEL)selector;

/*!
 * @method watchWithEventMask:withBlock:
 * @abstract Starts monitoring the current path with a custom event mask and block callbacks.
 * @discussion This method stops any current monitoring, configures the event mask and block, and starts watching the current path. The path is preserved.
 * @param eventMask The bitmask of DISPATCH_VNODE_* events to monitor.
 * @param block The block to execute when events occur.
 * @return YES if monitoring started successfully, NO otherwise.
 */
- (BOOL)watchWithEventMask:(unsigned long)eventMask withBlock:(void (^_Nonnull)(BEPathWatcher *watcher, unsigned long event))block;

#pragma mark - Monitoring Control

/*!
 * @method startMonitoring
 * @abstract Starts monitoring the configured path with the current settings.
 * @discussion This method starts monitoring if a path and callback mechanism are configured. It's automatically called by the watch* methods and when setting isActive to YES. If the path cannot be opened, the path is cleared and NO is returned.
 * @return YES if monitoring started successfully, NO otherwise.
 */
- (BOOL)startMonitoring;

/*!
 * @method stopMonitoring
 * @abstract Stops monitoring the file system.
 * @discussion This method stops all monitoring activity and cleans up resources. It's automatically called when the watcher is deallocated and when the watched path is deleted, renamed, or revoked.
 */
- (void)stopMonitoring;

@end

NS_ASSUME_NONNULL_END
