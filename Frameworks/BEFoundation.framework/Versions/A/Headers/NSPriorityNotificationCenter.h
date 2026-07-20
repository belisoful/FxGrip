/*!
 @header        NSPriorityNotificationCenter.h
 @copyright     -© 2025 Delicense - @belisoful. All rights released.
 @date          2025-01-01
 @author		belisoful@icloud.com
 @abstract      A priority-based notification center that allows observers to be notified in order of priority
 @discussion    This class extends NSNotificationCenter to support priority-based notification delivery.
				Observers with higher priority (lower numerical values) are notified first.
				
				Priority values work like Unix process priorities where:
				- Negative values (-20 to -1) have the highest priority
				- Zero (0) has neutral priority
				- Positive values (1 to 20) have lower priority
				- Default priority is 10
				
				The notification center maintains backward compatibility with NSNotificationCenter
				while adding priority-based ordering and additional posting options like reverse
				ordering and post-processing blocks.
*/

#ifndef NSPriorityNotificationCenter_h
#define NSPriorityNotificationCenter_h

#import <Foundation/Foundation.h>
#import <BEFoundation/NSPriorityNotification.h>
#import <BEFoundation/BESingleton.h>

NS_ASSUME_NONNULL_BEGIN

/*!
 @var           NSPriorityNotificationDefaultPriority
 @abstract      The default priority for observers that don't specify their own priority.
 @discussion    Priority is an integer similar to Linux process priority where -20 is
				the highest priority and 20 is the lowest priority.
				The value is 10, which provides a moderate low priority suitable for
				most general-purpose observers.
 */
extern NSInteger const NSPriorityNotificationDefaultPriority;

#pragma mark - Priority Protocols

/*!
 @protocol      NSNotificationObjectPriorityItem
 @abstract      Protocol for objects that can provide their own notification priority dynamically
 @discussion    Objects conforming to this protocol can dynamically provide their priority
				for specific notification names. This allows objects to have different
				priorities for different types of notifications they observe.
				
				The priority returned by ncPriority: can change at runtime, allowing
				for dynamic priority adjustment based on application state.

				@code
				// AudioEngine conforms to NSNotificationObjectPriorityItem:
				- (NSInteger)ncPriority:(NSNotificationName)aName {
					// Urgent shutdown handled before everything else.
					return [aName isEqualToString:@"AppWillTerminate"] ? -20 : 0;
				}
				@endcode
 */
@protocol NSNotificationObjectPriorityItem <NSObject>

/*!
 @method        ncPriority:
 @abstract      Returns the notification priority for the given notification name
 @param         aName The notification name to get priority for, or nil for default priority
 @return        Priority value where lower numbers indicate higher priority
 @discussion    This method is called each time notifications are sorted for delivery.
				Return values should follow Unix priority conventions:
				- Negative values: High priority (urgent notifications)
				- Zero: Neutral priority
				- Positive values: Lower priority (background notifications)
				
				If aName is nil, return the default priority for this object.
 */
- (NSInteger)ncPriority:(nullable NSNotificationName)aName;
@end

/*!
 @protocol      NSNotificationObjectPriorityCapture
 @abstract      Protocol for objects that can store notification priority configuration
 @discussion    Objects conforming to this protocol can be configured with a priority
				for specific notification names. This is useful for objects that need
				to remember their priority settings between notification registrations.
				
				When an observer conforms to this protocol, the notification center
				will automatically call setNcPriority:name: when the observer is added.
 */
@protocol NSNotificationObjectPriorityCapture <NSObject>

/*!
 @method        setNcPriority:name:
 @abstract      Sets the notification priority for the given notification name
 @param         aPriority The priority value to assign
 @param         aName The notification name to set priority for, or nil for default priority
 @discussion    Implementing objects should store this priority value and use it
				in conjunction with NSNotificationObjectPriorityItem if both protocols
				are implemented.
				
				Priority values follow Unix conventions where lower numbers = higher priority.
 */
- (void)setNcPriority:(NSInteger)aPriority name:(nullable NSNotificationName)aName;
@end

/*!
 @protocol      NSNotificationObjectPriorityProperty
 @abstract      Combined protocol for objects that can both provide and store priority
 @discussion    This is a convenience protocol that combines both NSNotificationObjectPriorityItem
				and NSNotificationObjectPriorityCapture. Objects implementing this protocol
				can both receive priority configuration and provide dynamic priority values.
				
				This is the recommended protocol for observers that need full priority
				management capabilities.

				@code
				// Logger conforms to NSNotificationObjectPriorityProperty (stores + provides priority):
				- (void)setNcPriority:(NSInteger)aPriority name:(NSNotificationName)aName {
					_priority = aPriority;
				}
				- (NSInteger)ncPriority:(NSNotificationName)aName {
					return _priority;
				}
				@endcode
 */
@protocol NSNotificationObjectPriorityProperty <NSNotificationObjectPriorityItem, NSNotificationObjectPriorityCapture>
@end

#pragma mark - NSPriorityNotificationCenter

/*!
 @class         NSPriorityNotificationCenter
 @abstract      A notification center that delivers notifications in priority order
 @discussion    This class extends NSNotificationCenter to support priority-based notification
				delivery. Observers are notified in order of their priority, with lower
				numerical values having higher priority.

				The class provides:
				- Priority-based observer ordering (Unix-style priorities)
				- Backward compatibility with NSNotificationCenter
				- Support for reverse notification ordering
				- Post-processing blocks for notifications
				- Thread-safe observer management
				- Singleton pattern with defaultCenter
				- Automatic integration with NSNotificationCenter.defaultCenter
				
				The class intercepts notifications from the standard NSNotificationCenter
				and re-dispatches them with priority ordering when used as the defaultCenter.

				@code
				NSPriorityNotificationCenter *center = NSPriorityNotificationCenter.defaultCenter;

				// Higher priority (lower value) observer is notified first.
				[center addObserver:self
						   selector:@selector(handleLogin:)
							   name:@"UserLoggedIn"
							 object:nil
						   priority:-5];

				// Block observer with default priority.
				id token = [center addObserverForName:@"UserLoggedIn"
											   object:nil
											  queue:nil
										 usingBlock:^(NSNotification *note) {
					NSLog(@"login: %@", note.userInfo[@"name"]);
				}];

				// reverse:YES delivers lowest-priority observers first; the postBlock
				// runs after each observer.
				[center postNotificationName:@"UserLoggedIn"
									  object:self
									userInfo:@{@"name": @"alice"}
									 reverse:NO
								   postBlock:^(NSNotification *note) {
					NSLog(@"delivered to one observer");
				}];

				[center removeObserver:token];
				@endcode
 */
@interface NSPriorityNotificationCenter : NSNotificationCenter <NSNotificationObjectPriorityItem, BESingleton>

#pragma mark - Class Properties

/*!
 @property      defaultCenter
 @abstract      The shared priority notification center instance
 @discussion    Returns the singleton instance of NSPriorityNotificationCenter.
				This instance automatically intercepts notifications from the standard
				NSNotificationCenter.defaultCenter and re-dispatches them with priority ordering.
				
				This property is thread-safe and will always return the same instance.
 */
@property (class, readonly, strong) NSPriorityNotificationCenter *defaultCenter;

#pragma mark - Instance Properties

/*!
 @property      defaultPriority
 @abstract      The default priority assigned to new observers
 @discussion    This value is used when observers are added without specifying a priority.
				The default value is NSPriorityNotificationDefaultPriority (10).
				
				This can be changed at runtime to affect new observers. Existing observers
				retain their original priority values.
				
				Valid range is typically -20 to 20, following Unix priority conventions.
 */
@property (readwrite, assign) NSInteger defaultPriority;

#pragma mark - Class Methods

/*!
 @method        isSingleton
 @abstract      Returns whether this class uses singleton pattern
 @return        Always returns YES for NSPriorityNotificationCenter
 @discussion    This method is part of the BESingleton protocol and indicates that
				this class follows the singleton pattern. The singleton instance is
				accessed via the defaultCenter class property.
 */
+ (BOOL)isSingleton;

#pragma mark - Observer Management

/*!
 @method        addObserver:selector:name:object:
 @abstract      Adds an observer with default priority
 @param         observer The object that will receive notifications
 @param         aSelector The method to call on the observer
 @param         aName The notification name to observe, or nil for all notifications
 @param         anObject The object whose notifications to observe, or nil for all objects
 @discussion    This method maintains compatibility with NSNotificationCenter while adding
				priority support. The observer will be assigned the current defaultPriority value.
				
				If the observer conforms to NSNotificationObjectPriorityCapture, the default
				priority will be stored in the observer via setNcPriority:name:.
 */
- (void)addObserver:(nonnull id)observer
		   selector:(nonnull SEL)aSelector
			   name:(nullable NSNotificationName)aName
			 object:(nullable id)anObject;

/*!
 @method        addObserver:selector:name:object:queue:
 @abstract      Adds an observer with default priority and specified queue
 @param         observer The object that will receive notifications
 @param         aSelector The method to call on the observer
 @param         aName The notification name to observe, or nil for all notifications
 @param         anObject The object whose notifications to observe, or nil for all objects
 @param         queue The operation queue on which to execute the observer method, or nil for synchronous execution
 @discussion    This method adds queue-based execution to the standard observer pattern.
				If queue is nil, the observer method is called synchronously on the posting thread.
				If queue is provided, the observer method is executed asynchronously on that queue.
 */
- (void)addObserver:(nonnull id)observer
		   selector:(nonnull SEL)aSelector
			   name:(nullable NSNotificationName)aName
			 object:(nullable id)anObject
			  queue:(nullable NSOperationQueue *)queue;

/*!
 @method        addObserver:selector:name:object:priority:
 @abstract      Adds an observer with specified priority
 @param         observer The object that will receive notifications
 @param         aSelector The method to call on the observer
 @param         aName The notification name to observe, or nil for all notifications
 @param         anObject The object whose notifications to observe, or nil for all objects
 @param         priority The priority value (lower values = higher priority)
 @discussion    This is the core priority-aware observer registration method.
				Priority values follow Unix conventions where:
				- Negative values have highest priority
				- Zero is neutral priority
				- Positive values have lower priority
				
				If the observer conforms to NSNotificationObjectPriorityItem, the priority
				parameter is treated as an offset from the observer's dynamic priority.
 */
- (void)addObserver:(nonnull id)observer
		   selector:(nonnull SEL)aSelector
			   name:(nullable NSNotificationName)aName
			 object:(nullable id)anObject
		   priority:(NSInteger)priority;

/*!
 @method        addObserver:selector:name:object:priority:queue:
 @abstract      Adds an observer with specified priority and execution queue
 @param         observer The object that will receive notifications
 @param         aSelector The method to call on the observer
 @param         aName The notification name to observe, or nil for all notifications
 @param         anObject The object whose notifications to observe, or nil for all objects
 @param         priority The priority value (lower values = higher priority)
 @param         queue The operation queue for asynchronous execution, or nil for synchronous
 @discussion    This method combines priority-based ordering with queue-based execution.
				The observer method will be called in priority order, but if a queue is
				specified, the actual execution happens asynchronously on that queue.
				
				When using queues, notification objects may be copied to ensure thread safety.
 */
- (void)addObserver:(nonnull id)observer
		   selector:(nonnull SEL)aSelector
			   name:(nullable NSNotificationName)aName
			 object:(nullable id)anObject
		   priority:(NSInteger)priority
			  queue:(nullable NSOperationQueue *)queue;

/*!
 @method        addObserverForName:object:queue:usingBlock:
 @abstract      Adds a block-based observer with default priority
 @param         name The notification name to observe, or nil for all notifications
 @param         obj The object whose notifications to observe, or nil for all objects
 @param         queue The operation queue for block execution, or nil for synchronous execution
 @param         block The block to execute when notifications are received
 @return        An opaque object that can be used to remove the observer
 @discussion    This method provides block-based notification observing with default priority.
				The returned object should be retained and used with removeObserver: to
				unregister the observation.
				
				Block-based observers are particularly useful for one-off observations
				or when the observing code is localized.
 */
- (nonnull id <NSObject>)addObserverForName:(nullable NSNotificationName)name
									 object:(nullable id)obj
									  queue:(nullable NSOperationQueue *)queue
								 usingBlock:(void (NS_SWIFT_SENDABLE ^_Nonnull)(NSNotification *notification))block
	API_AVAILABLE(macos(10.6), ios(4.0), watchos(2.0), tvos(9.0));

/*!
 @method        addObserverForName:object:priority:queue:usingBlock:
 @abstract      Adds a block-based observer with specified priority
 @param         aName The notification name to observe, or nil for all notifications
 @param         anObject The object whose notifications to observe, or nil for all objects
 @param         priority The priority value (lower values = higher priority)
 @param         queue The operation queue for block execution, or nil for synchronous execution
 @param         block The block to execute when notifications are received
 @return        An opaque object that can be used to remove the observer
 @discussion    This method combines block-based observing with priority control.
				The block will be executed in priority order relative to other observers.
				
				The returned object should be retained and used with removeObserver:
				to unregister the observation.
 */
- (nonnull id<NSObject>)addObserverForName:(nullable NSNotificationName)aName
									object:(nullable id)anObject
								  priority:(NSInteger)priority
									 queue:(nullable NSOperationQueue *)queue
								usingBlock:(void (^ _Nonnull)(NSNotification *notification))block
	API_AVAILABLE(macos(10.6), ios(4.0), watchos(2.0), tvos(9.0));

#pragma mark - Posting Notifications

/*!
 @method        postNotification:
 @abstract      Posts a notification with priority ordering
 @param         notification The notification to post
 @discussion    This method posts the given notification to all registered observers
				in priority order. Observers with lower priority values are notified first.
				
				If the notification is an NSPriorityNotification, additional features
				like reverse ordering and post-processing blocks are supported.
 */
- (void)postNotification:(nonnull NSNotification *)notification;

/*!
 @method        postNotificationName:object:
 @abstract      Posts a notification with name and object
 @param         aName The notification name
 @param         anObject The object associated with the notification, or nil
 @discussion    Convenience method for posting simple notifications.
				Equivalent to creating an NSNotification and calling postNotification:.
 */
- (void)postNotificationName:(nonnull NSNotificationName)aName
					  object:(nullable id)anObject;

/*!
 @method        postNotificationName:object:userInfo:
 @abstract      Posts a notification with name, object, and user info
 @param         aName The notification name
 @param         anObject The object associated with the notification, or nil
 @param         aUserInfo Additional data to include with the notification, or nil
 @discussion    Standard notification posting method with user info dictionary.
				The userInfo dictionary is available to all observers and can contain
				arbitrary key-value pairs.
 */
- (void)postNotificationName:(nonnull NSNotificationName)aName
					  object:(nullable id)anObject
					userInfo:(nullable NSDictionary *)aUserInfo;

/*!
 @method        postNotificationName:object:postBlock:
 @abstract      Posts a notification with a post-processing block
 @param         aName The notification name
 @param         anObject The object associated with the notification, or nil
 @param         postBlock Block executed after each observer is notified, or nil
 @discussion    This method allows for post-processing after each observer handles
				the notification. The postBlock is called once per observer, after
				that observer's handler completes.
				
				The postBlock receives the same notification object that was sent
				to the observer, allowing for cleanup or additional processing.
 */
- (void)postNotificationName:(nonnull NSNotificationName)aName
					  object:(nullable id)anObject
				   postBlock:(void (NS_SWIFT_SENDABLE ^_Nullable)(NSNotification *notification))postBlock;

/*!
 @method        postNotificationName:object:userInfo:postBlock:
 @abstract      Posts a notification with user info and post-processing block
 @param         aName The notification name
 @param         anObject The object associated with the notification, or nil
 @param         aUserInfo Additional data to include with the notification, or nil
 @param         postBlock Block executed after each observer is notified, or nil
 @discussion    Combines user info dictionary with post-processing block functionality.
				The postBlock is executed after each observer processes the notification.
 */
- (void)postNotificationName:(nonnull NSNotificationName)aName
					  object:(nullable id)anObject
					userInfo:(nullable NSDictionary *)aUserInfo
				   postBlock:(void (NS_SWIFT_SENDABLE ^_Nullable)(NSNotification *notification))postBlock;

/*!
 @method        postNotificationName:object:reverse:
 @abstract      Posts a notification with optional reverse order
 @param         aName The notification name
 @param         anObject The object associated with the notification, or nil
 @param         reverse If YES, observers are called in reverse priority order (lowest priority first)
 @discussion    This method allows reversing the normal priority order for special cases.
				When reverse is YES, observers with higher priority values are notified first.
				
				This can be useful for cleanup operations or when you want to notify
				less critical observers before more critical ones.
 */
- (void)postNotificationName:(nonnull NSNotificationName)aName
					  object:(nullable id)anObject
					 reverse:(BOOL)reverse;

/*!
 @method        postNotificationName:object:userInfo:reverse:
 @abstract      Posts a notification with user info and optional reverse order
 @param         aName The notification name
 @param         anObject The object associated with the notification, or nil
 @param         aUserInfo Additional data to include with the notification, or nil
 @param         reverse If YES, observers are called in reverse priority order
 @discussion    Combines user info dictionary with reverse ordering capability.
 */
- (void)postNotificationName:(nonnull NSNotificationName)aName
					  object:(nullable id)anObject
					userInfo:(nullable NSDictionary *)aUserInfo
					 reverse:(BOOL)reverse;

/*!
 @method        postNotificationName:object:reverse:postBlock:
 @abstract      Posts a notification with reverse order and post-processing block
 @param         aName The notification name
 @param         anObject The object associated with the notification, or nil
 @param         reverse If YES, observers are called in reverse priority order
 @param         postBlock Block executed after each observer is notified, or nil
 @discussion    Combines reverse ordering with post-processing block functionality.
 */
- (void)postNotificationName:(nonnull NSNotificationName)aName
					  object:(nullable id)anObject
					 reverse:(BOOL)reverse
				   postBlock:(void (NS_SWIFT_SENDABLE ^_Nullable)(NSNotification *notification))postBlock;

/*!
 @method        postNotificationName:object:userInfo:reverse:postBlock:
 @abstract      Posts a notification with all available options
 @param         aName The notification name
 @param         anObject The object associated with the notification, or nil
 @param         aUserInfo Additional data to include with the notification, or nil
 @param         reverse If YES, observers are called in reverse priority order
 @param         postBlock Block executed after each observer is notified, or nil
 @discussion    This method supports every posting option:
				- User info dictionary for additional data
				- Reverse ordering for special notification patterns
				- Post-processing blocks for cleanup or additional handling
 */
- (void)postNotificationName:(nonnull NSNotificationName)aName
					  object:(nullable id)anObject
					userInfo:(nullable NSDictionary *)aUserInfo
					 reverse:(BOOL)reverse
				   postBlock:(void (NS_SWIFT_SENDABLE ^_Nullable)(NSNotification *notification))postBlock;

#pragma mark - Observer Removal

/*!
 @method        removeObserver:
 @abstract      Removes all observations for the given observer
 @param         observer The observer to remove
 @discussion    This method removes all notification observations for the specified observer,
				regardless of notification name or object filters. This is the safest way
				to ensure complete cleanup when an observer is being deallocated.
				
				For block-based observers, pass the object returned by addObserverForName:...
 */
- (void)removeObserver:(nonnull id)observer;

/*!
 @method        removeObserver:name:object:
 @abstract      Removes specific observations for the given observer
 @param         observer The observer to remove
 @param         aName The notification name to stop observing, or nil to remove all names
 @param         anObject The object to stop observing, or nil to remove all objects
 @discussion    This method provides fine-grained control over observer removal.
				Only observations matching the specified name and object filters are removed.
				
				Use nil for aName or anObject to match all notifications or all objects respectively.
 */
- (void)removeObserver:(nonnull id)observer
				  name:(nullable NSNotificationName)aName
				object:(nullable id)anObject;

#pragma mark - Cleanup

/*!
 @method        cleanup
 @abstract      Performs cleanup operations for the notification center
 @discussion    This method unregisters the notification center from the standard
				NSNotificationCenter.defaultCenter and performs other cleanup operations.
				
				This method is typically called during application shutdown or when
				the priority notification center is no longer needed.
 */
- (void)cleanup;

@end

NS_ASSUME_NONNULL_END

#endif
