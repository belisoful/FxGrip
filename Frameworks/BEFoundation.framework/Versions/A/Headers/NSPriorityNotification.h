/*!
 @header		NSPriorityNotification.h
 @copyright		-© 2025 Delicense - @belisoful. All rights released.
 @date			2025-01-01
 @author		belisoful@icloud.com
 @abstract		Extends NSNotification to include priority-based notification processing with reverse ordering and post-processing blocks.
 @discussion	NSPriorityNotification provides the following notification functionality:
				- Priority-based observer ordering
				- Reverse enumeration support
				- Per-notification post-processing blocks
				- Secure coding support
				- Compatibility with standard NSNotification
*/

#ifndef NSPriorityNotification_h
#define NSPriorityNotification_h

#import <Foundation/Foundation.h>
#import <Foundation/NSNotification.h>

NS_ASSUME_NONNULL_BEGIN

/*!
 @class			NSPriorityNotification
 @superclass	NSNotification
 @abstract		A notification class that extends NSNotification with priority-based processing capabilities.
 @discussion	NSPriorityNotification adds functionality to the standard notification system:
 
				- Reverse Processing: Observers can be processed in reverse priority order using the `reverse` property
				- Post-Processing Blocks: Each notification can have a block that executes after each observer
				- Priority Support: Designed to work with NSPriorityNotificationCenter for priority-based observer management
				- Secure Coding: Full support for NSSecureCoding protocol
				- Global Registry: Supports object persistence through global registry system
 
				@code
				// Create a reverse-order notification
				NSPriorityNotification *notification = [NSPriorityNotification
					notificationWithName:@"MyNotification"
					object:self
					reverse:YES];
				
				// Create notification with post-processing block
				NSPriorityNotification *notification = [NSPriorityNotification
					notificationWithName:@"MyNotification"
					object:self
					postBlock:^(NSNotification *note) {
						NSLog(@"Processed notification: %@", note.name);
					}];
				@endcode
 */
@interface NSPriorityNotification : NSNotification <NSSecureCoding>
{
	NSNotificationName	_name;
	id					_object;
	NSDictionary 		*_userInfo;
	BOOL				_reverse;
	id					_postBlock;
}

#pragma mark - Properties

/*!
 @property		reverse
 @abstract		Determines whether observers should be processed in reverse order.
 @discussion	When set to YES, the notification center delivers the notification in reverse
				priority order (lowest priority first): observers with higher numeric priority
				values are notified before observers with lower values. Observers of equal
				priority are notified in reverse registration order.
 @note			This property is read-only and must be set during initialization.
 */
@property (nonatomic, readonly, assign) BOOL reverse;

/*!
 @property		postBlock
 @abstract		A block that executes after each observer processes the notification.
 @discussion	This block is called after each observer's selector or block is executed.
				It receives the notification object as a parameter and can be used for:
				- Logging observer execution
				- Cleanup operations
				- State validation
				- Performance monitoring
 @note			The block is copied during initialization and released during deallocation.
 */
@property (nonatomic, readonly, nullable) void (^postBlock)(NSNotification *note);

#pragma mark - Class Factory Methods

/*!
 @method		notificationWithName:object:
 @abstract		Creates a new notification with the specified name and object.
 @param			aName		The name for the notification. Must not be nil.
 @param			anObject	The object associated with the notification. May be nil.
 @return		A new NSPriorityNotification instance.
 @discussion	This is the simplest factory method for creating a priority notification.
				The notification will have no user info, reverse processing disabled,
				and no post-processing block.
 */
+ (instancetype)notificationWithName:(NSNotificationName)aName
							  object:(nullable id)anObject;

/*!
 @method		notificationWithName:object:userInfo:
 @abstract		Creates a new notification with the specified name, object, and user info.
 @param			aName		The name for the notification. Must not be nil.
 @param			anObject	The object associated with the notification. May be nil.
 @param			userInfo	A dictionary containing additional information. May be nil.
 @return		A new NSPriorityNotification instance.
 @discussion	This method creates a standard priority notification with user information.
				Reverse processing is disabled and no post-processing block is set.
 */
+ (instancetype)notificationWithName:(NSNotificationName)aName
							  object:(nullable id)anObject
							userInfo:(nullable NSDictionary *)userInfo;

/*!
 @method		notificationWithName:object:postBlock:
 @abstract		Creates a new notification with a post-processing block.
 @param			aName		The name for the notification. Must not be nil.
 @param			anObject	The object associated with the notification. May be nil.
 @param			postBlock	A block to execute after each observer. May be nil.
 @return		A new NSPriorityNotification instance.
 @discussion	The post-processing block is called after each observer processes the notification.
				This is useful for logging, cleanup, or state validation operations.
 */
+ (instancetype)notificationWithName:(NSNotificationName)aName
							  object:(nullable id)anObject
						   postBlock:(void (NS_SWIFT_SENDABLE ^_Nullable)(NSNotification *notification))postBlock;

/*!
 @method		notificationWithName:object:userInfo:postBlock:
 @abstract		Creates a new notification with user info and a post-processing block.
 @param			aName		The name for the notification. Must not be nil.
 @param			anObject	The object associated with the notification. May be nil.
 @param			userInfo	A dictionary containing additional information. May be nil.
 @param			postBlock	A block to execute after each observer. May be nil.
 @return		A new NSPriorityNotification instance.
 @discussion	This method combines user information with post-processing capabilities.
				The block is executed after each observer handles the notification.
 */
+ (instancetype)notificationWithName:(NSNotificationName)aName
							  object:(nullable id)anObject
							userInfo:(nullable NSDictionary *)userInfo
						   postBlock:(void (NS_SWIFT_SENDABLE ^_Nullable)(NSNotification *notification))postBlock;

/*!
 @method		notificationWithName:object:reverse:
 @abstract		Creates a new notification with reverse processing enabled or disabled.
 @param			aName		The name for the notification. Must not be nil.
 @param			anObject	The object associated with the notification. May be nil.
 @param			reverse		Whether to process observers in reverse order.
 @return		A new NSPriorityNotification instance.
 @discussion	When reverse is YES, observers are notified in reverse priority order
				(lowest priority first).
 */
+ (instancetype)notificationWithName:(NSNotificationName)aName
							  object:(nullable id)anObject
							 reverse:(BOOL)reverse;

/*!
 @method		notificationWithName:object:userInfo:reverse:
 @abstract		Creates a new notification with user info and reverse processing option.
 @param			aName		The name for the notification. Must not be nil.
 @param			anObject	The object associated with the notification. May be nil.
 @param			userInfo	A dictionary containing additional information. May be nil.
 @param			reverse		Whether to process observers in reverse order.
 @return		A new NSPriorityNotification instance.
 @discussion	This method combines user information with reverse processing capabilities.
				Observers are notified in reverse priority order if reverse is YES.
 */
+ (instancetype)notificationWithName:(NSNotificationName)aName
							  object:(nullable id)anObject
							userInfo:(nullable NSDictionary *)userInfo
							 reverse:(BOOL)reverse;

/*!
 @method		notificationWithName:object:reverse:postBlock:
 @abstract		Creates a new notification with reverse processing and a post-processing block.
 @param			aName		The name for the notification. Must not be nil.
 @param			anObject	The object associated with the notification. May be nil.
 @param			reverse		Whether to process observers in reverse order.
 @param			postBlock	A block to execute after each observer. May be nil.
 @return		A new NSPriorityNotification instance.
 @discussion	This method combines reverse processing with post-processing capabilities.
				The block is executed after each observer, regardless of processing order.
 */
+ (instancetype)notificationWithName:(NSNotificationName)aName
							  object:(nullable id)anObject
							 reverse:(BOOL)reverse
						   postBlock:(void (NS_SWIFT_SENDABLE ^_Nullable)(NSNotification *notification))postBlock;

/*!
 @method		notificationWithName:object:userInfo:reverse:postBlock:
 @abstract		Creates a new notification with full configuration options.
 @param			aName		The name for the notification. Must not be nil.
 @param			anObject	The object associated with the notification. May be nil.
 @param			userInfo	A dictionary containing additional information. May be nil.
 @param			reverse		Whether to process observers in reverse order.
 @param			postBlock	A block to execute after each observer. May be nil.
 @return		A new NSPriorityNotification instance.
 @discussion	This factory method configures all
				NSPriorityNotification features including user info, reverse processing,
				and post-processing blocks.
 */
+ (instancetype)notificationWithName:(NSNotificationName)aName
							  object:(nullable id)anObject
							userInfo:(nullable NSDictionary *)userInfo
							 reverse:(BOOL)reverse
						   postBlock:(void (NS_SWIFT_SENDABLE ^_Nullable)(NSNotification *notification))postBlock;

#pragma mark - Initialization Methods

/*!
 @method		initWithName:object:userInfo:reverse:
 @abstract		Initializes a notification with reverse processing option.
 @param			name		The name for the notification. Must not be nil.
 @param			object		The object associated with the notification. May be nil.
 @param			userInfo	A dictionary containing additional information. May be nil.
 @param			reverse		Whether to process observers in reverse order.
 @return		An initialized NSPriorityNotification instance.
 @discussion	This designated initializer allows configuration of reverse processing.
				No post-processing block is set.
 */
- (instancetype)initWithName:(NSNotificationName)name
					  object:(nullable id)object
					userInfo:(nullable NSDictionary *)userInfo
					 reverse:(BOOL)reverse;

/*!
 @method		initWithName:object:userInfo:postBlock:
 @abstract		Initializes a notification with a post-processing block.
 @param			name		The name for the notification. Must not be nil.
 @param			object		The object associated with the notification. May be nil.
 @param			userInfo	A dictionary containing additional information. May be nil.
 @param			postBlock	A block to execute after each observer. May be nil.
 @return		An initialized NSPriorityNotification instance.
 @discussion	This designated initializer allows configuration of post-processing behavior.
				Reverse processing is disabled. The block is copied and retained.
 */
- (instancetype)initWithName:(NSNotificationName)name
					  object:(nullable id)object
					userInfo:(nullable NSDictionary *)userInfo
				   postBlock:(void (NS_SWIFT_SENDABLE ^ _Nullable)(NSNotification *notification))postBlock;

/*!
 @method		initWithName:object:userInfo:reverse:postBlock:
 @abstract		Initializes a notification with full configuration options.
 @param			name		The name for the notification. Must not be nil.
 @param			object		The object associated with the notification. May be nil.
 @param			userInfo	A dictionary containing additional information. May be nil.
 @param			reverse		Whether to process observers in reverse order.
 @param			postBlock	A block to execute after each observer. May be nil.
 @return		An initialized NSPriorityNotification instance.
 @discussion	This designated initializer configures all NSPriorityNotification features.
				The block is copied and retained.
 */
- (instancetype)initWithName:(NSNotificationName)name
					  object:(nullable id)object
					userInfo:(nullable NSDictionary *)userInfo
					 reverse:(BOOL)reverse
				   postBlock:(void (NS_SWIFT_SENDABLE ^ _Nullable)(NSNotification *notification))postBlock NS_DESIGNATED_INITIALIZER;

#pragma mark - NSSecureCoding Protocol

/*!
 @method		supportsSecureCoding
 @abstract		Indicates whether the class supports secure coding.
 @return		YES, indicating NSPriorityNotification supports secure coding.
 @discussion	NSPriorityNotification fully supports NSSecureCoding for safe archiving
				and unarchiving. Objects that conform to GlobalRegistryProtocol are
				handled specially to maintain object identity across coding operations.
 */
+ (BOOL)supportsSecureCoding;

/*!
 @method		initWithCoder:
 @abstract		Initializes a notification by decoding from an archive.
 @param			aDecoder	The decoder containing the archived notification data.
 @return		An initialized NSPriorityNotification instance, or nil if decoding fails.
 @discussion	This method supports both keyed and non-keyed coding. Objects that conform
				to GlobalRegistryProtocol are restored using their global registry UUID.
				Post-processing blocks are not archived and will be nil after decoding.
 */
- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder NS_DESIGNATED_INITIALIZER;

/*!
 @method		encodeWithCoder:
 @abstract		Encodes the notification to an archive.
 @param			aCoder		The encoder to write the notification data to.
 @discussion	This method supports both keyed and non-keyed coding. Objects that conform
				to GlobalRegistryProtocol are automatically registered globally if needed,
				and their UUID is encoded for later restoration. Post-processing blocks
				are not encoded due to security considerations.
 */
- (void)encodeWithCoder:(NSCoder *)aCoder;

/*!
 @method		classForCoder
 @abstract		Returns the class to use for encoding with non-keyed archivers.
 @return		The NSPriorityNotification class.
 @discussion	This method ensures proper class identity during non-keyed archiving operations.
 */
- (Class)classForCoder;

/*!
 @method		classForKeyedArchiver
 @abstract		Returns the class to use for encoding with keyed archivers.
 @return		The NSPriorityNotification class.
 @discussion	This method ensures proper class identity during keyed archiving operations.
 */
- (Class)classForKeyedArchiver;

@end

#pragma mark - NSNotification Priority Extension

/*!
 @category		NSNotification(PriorityExtension)
 @abstract		Extends NSNotification to be compatible with NSPriorityNotificationCenter.
 @discussion	This category adds priority notification system compatibility to standard
				NSNotification objects. It enables NSNotification instances to be processed
				by NSPriorityNotificationCenter while maintaining backward compatibility.
 
				The category provides:
				- Priority Post Tracking: Prevents duplicate processing by NSPriorityNotificationCenter
				- Reverse Processing: Always returns NO for standard notifications
				- Post-Processing: Always returns NULL for standard notifications
				- Mixed Use: Allows mixed use of NSNotification and NSPriorityNotification
 
				@code
				// Standard NSNotification works with NSPriorityNotificationCenter
				NSNotification *notification = [NSNotification
					notificationWithName:@"StandardNotification"
					object:self];
				
				// The priority center can process both types
				[[NSPriorityNotificationCenter defaultCenter] postNotification:notification];
				@endcode
 */
@interface NSNotification (PriorityExtension)

/*!
 @property		isPriorityPost
 @abstract		Indicates whether this notification has been processed by NSPriorityNotificationCenter.
 @discussion	This property is used internally by NSPriorityNotificationCenter to track
				whether a notification has already been processed through the priority system.
				This prevents infinite loops when NSPriorityNotificationCenter observes
				the system NSNotificationCenter.
 
				- Setting to YES: Marks the notification as having been processed by the priority system
				- Setting to NO: Clears the priority processing flag
				- Default Value: NO for new notifications
 @note			This property uses associated objects for storage and is automatically managed
				by NSPriorityNotificationCenter. Manual manipulation is rarely necessary.
 @warning		The flag is set/cleared around delivery, so a single notification instance must not be posted on two threads concurrently.
 */
@property (nonatomic, readwrite) BOOL isPriorityPost;

/*!
 @property		postBlock
 @abstract		The post-processing block for standard NSNotification objects.
 @discussion	Standard NSNotification objects do not support post-processing blocks,
				so this property always returns NULL. This provides compatibility with
				NSPriorityNotification's postBlock property.
 @return		Always returns NULL for NSNotification objects.
 @note			To use post-processing blocks, create an NSPriorityNotification instead.
 */
@property (nonatomic, readonly, nullable) void (^postBlock)(NSNotification *note);

/*!
 @property		reverse
 @abstract		The reverse processing flag for standard NSNotification objects.
 @discussion	Standard NSNotification objects do not support reverse processing,
				so this property always returns NO. This provides compatibility with
				NSPriorityNotification's reverse property.
 @return		Always returns NO for NSNotification objects.
 @note			To use reverse processing, create an NSPriorityNotification instead.
 */
@property (nonatomic, readonly, assign) BOOL reverse;

@end

NS_ASSUME_NONNULL_END

#endif /* NSPriorityNotification_h */
