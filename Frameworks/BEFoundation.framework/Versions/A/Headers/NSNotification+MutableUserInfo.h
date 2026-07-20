/*!
 @header		NSNotification+MutableUserInfo.h
 @copyright		-© 2025 Delicense - @belisoful. All rights released.
 @date			2025-01-01
 @author		belisoful@icloud.com
 @abstract		Adds the ability to get the NSNotification userInfo as a NSMutableDictionary
 @discussion	This returns the userInfo of a NSNotification as a NSMutableDictionary if and only if
				it is an NSMutableDictionary.

				@code
				NSNotification *note = [NSNotification notificationWithName:@"Event"
																	object:nil
																  userInfo:[NSMutableDictionary dictionary]];
				NSMutableDictionary *info = note.mutableUserInfo;   // nil when userInfo is immutable
				info[@"count"] = @1;
				@endcode
*/

#ifndef NSNotification_MutableUserInfo_h
#define NSNotification_MutableUserInfo_h

#import <Foundation/Foundation.h>

/*!
 @category		NSNotification (MutableUserInfo)
 @abstract		Adds getting the userInfo as an NSMutableDictionary if it is one.
 @discussion	The following methods are provided by this category:

 `-mutableUserInfo`: Returns the userInfo as an NSMutableDictionary if it is one.

				@code
				NSNotification *note = [NSNotification notificationWithName:@"Event"
																	object:nil
																  userInfo:[NSMutableDictionary dictionary]];
				note.mutableUserInfo[@"count"] = @1;  // nil if userInfo is immutable
				@endcode
 */
@interface NSNotification (MutableUserInfo)

/*!
 @property		mutableUserInfo
 @abstract		Returns userInfo as an NSMutableDictionary if it is one.
 @discussion	A userInfo for a NSNotification can be a NSMutableDictionary, but rather than having to cast
				userInfo to make it a NSMutableDictionary, this method ensures it is a NSMutableDictionary
				and returns it already cast as a NSMutableDictionary.
 @result		Returns the userInfo as a NSMutableDictionary, or nil if userInfo is not mutable.
 */
@property (readonly, nonatomic, nullable) NSMutableDictionary* mutableUserInfo;

@end

#endif
