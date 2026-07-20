/*!
 @header		NSNotification+ExtraProperties.h
 @copyright		-© 2025 Delicense - @belisoful. All rights released.
 @date			2025-11-22
 @author		belisoful@icloud.com
 @abstract		Extends NSNotification with additional tag and identifier properties.
 @discussion	This category extends NSNotification to provide additional properties for tagging and identifying notifications. The tag and identifier properties provide a way to attach metadata to notifications, which can be useful for filtering or handling specific notification types.
 
				These properties allow for better organization and categorization of notifications by providing:
				- A numeric tag for quick identification
				- An identifier object for logical grouping
				- Automatic fallback to object properties when the notification's own properties are not set
 
				Example usage:
				@code
				// Setting a tag on notification
				notification.tag = 123;
				
				// Setting an identifier on notification
				notification.identifier = @"myIdentifier";
				
				// Using with standard notifications
				NSNotification *notification = [NSNotification notificationWithName:@"MyNotification" object:nil];
				notification.tag = 456;
				notification.identifier = @"userLogin";
				@endcode
 */

#ifndef NSNotification_ExtraProperties_h
#define NSNotification_ExtraProperties_h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/*!
 @category		NSNotification (ExtraProperties)
 @abstract		Extension to NSNotification to provide additional tag and identifier properties.
 @discussion	This category extends NSNotification with additional properties that allow for better identification and categorization of notifications. The tag and identifier properties provide a way to attach metadata to notifications, which can be useful for filtering or handling specific notification types.
 
				- Tag property: Returns a NSInteger value for quick identification
				- Identifier property: Returns an object for logical grouping and categorization
				- Automatic fallback: If the notification's own properties are not set, they fall back to the object's properties, then to the matching userInfo entry, if available

				@code
				// Tag and identify a notification for later filtering.
				NSNotification *note = [NSNotification notificationWithName:@"MyNotification" object:nil];
				note.tag = 456;
				note.identifier = @"userLogin";

				NSInteger tag = note.tag;       // falls back to note.object.tag, then userInfo[@"tag"], when unset
				id ident = note.identifier;     // falls back to note.object.identifier, then userInfo[@"identifier"], when unset
				@endcode
 */
@interface NSNotification (ExtraProperties)

/*!
 @property		tag
 @abstract		Returns the set tag or the notification.object.tag, if the object has a tag.
 @discussion	If the tag of the notification is set, the set tag is returned,
 				otherwise the notification object's tag if the object has a tag property,
 				otherwise the NSNumber value of userInfo[@"tag"] when present, otherwise 0.
 @result		NSInteger of the notification tag.
 */
@property (nonatomic) NSInteger tag;

/*!
 @property		identifier
 @abstract		Returns the set identifier or the notification.object.identifier, if the object has an identifier.
 @discussion	If the identifier of the notification is set, the set identifier is returned,
				otherwise the notification object's identifier if the object has an identifier property,
				otherwise userInfo[@"identifier"] when present, otherwise nil.
 @result		object of the notification identifier.
 */
@property (nonatomic, nullable) id identifier;

@end

NS_ASSUME_NONNULL_END

#endif
