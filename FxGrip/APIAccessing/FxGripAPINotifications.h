/*!
	@file       FxGripAPINotifications.h
	@copyright  Copyright © 2020-2023 Apple, Inc. All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripAPINotifications
	@abstract   The notification names and userInfo keys the FxGrip API wrappers post.
	@discussion Introduced in FxGrip 0.1.0. The parameter wrappers post a notification around each
	            creation, dynamic, get, and set call so extensions observe and amend the operation.
	            The *Pre names post before the host call and let an observer change or reject the
	            parameter payload. The userInfo keys address the parameter dictionary, result,
	            error, and parameter ID inside a notification's userInfo. The NSDictionary
	            categories read and write those keys.
*/

#ifndef FxGripAPINotifications_h
#define FxGripAPINotifications_h

#import <Foundation/Foundation.h>

//Notification post names
/*! The userInfo key for the parameter dictionary a notification carries. */
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterKey;
/*! The userInfo key for a call's result value. */
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ResultKey;
/*! The userInfo key for a call's error. */
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ErrorKey;
/*! The userInfo key for the parameter ID a notification targets. */
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterIDKey;

/*! Posted around parameter creation, dynamic edits, get, and set calls; *Pre variants post
	before the host call so an observer can amend or reject the parameter payload. */
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterAddPreName;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterAddName;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterStartGroupName;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterEndGroupName;

extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterRemoveName;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterGetNameName;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetNamePreName;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetNameName;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterGetTypeName;

extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetFloatBoundsName;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetIntBoundsName;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterGetMenuName;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetMenuPreName;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetMenuName;

extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterGetFlagsPreName;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterGetFlagsName;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterGetStringValueName;

extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetBoolName;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetCustomValueName;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetFloatName;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetHistogramName;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetIntName;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetFlagsPreName;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetFlagsName;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetPathIDName;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetRGBAName;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetRGBName;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetStringValuePreName;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetStringValueName;
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetXYName;



/*!
	@abstract	Reads the FxGrip notification userInfo values from a dictionary.
	@discussion	Introduced in FxGrip 0.1.0. The accessors return the parameter dictionary, its
				mutable form when it is mutable, the error, and the result stored under the
				notification keys.
*/
@interface NSDictionary (FxGripAPINotificationUserInfo)
/*! The parameter dictionary stored under FxGripNotifyAPI_ParameterKey. */
@property (readonly, nullable, nonatomic) NSDictionary* fxParameter;
/*! The parameter dictionary when it is an NSMutableDictionary; nil otherwise. */
@property (readonly, nullable, nonatomic) NSMutableDictionary* mutableFxParameter;
/*! The error stored under FxGripNotifyAPI_ErrorKey. */
@property (readonly, nullable) NSError* fxError;
/*! The result stored under FxGripNotifyAPI_ResultKey. */
@property (readonly, nullable) id fxResult;
@end

/*!
	@abstract	Writes the FxGrip notification userInfo values into a mutable dictionary.
	@discussion	Introduced in FxGrip 0.1.0. Setting a value to nil removes its key.
*/
@interface NSMutableDictionary (FxGripAPINotificationUserInfo)
@property (readwrite, nullable, nonatomic) NSDictionary* fxParameter;
@property (readwrite, nullable) id fxResult;
@property (readwrite, nullable) NSError* fxError;
@end

#endif
