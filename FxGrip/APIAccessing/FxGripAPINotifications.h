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

/*! Posted before a parameter is added through the creation API. An observer amends or rejects
	the parameter payload. */
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterAddPreName;
/*! Posted after a parameter is added through the creation API. */
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterAddName;
/*! Posted when a parameter group opens. */
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterStartGroupName;
/*! Posted when a parameter group closes. */
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterEndGroupName;

/*! Posted after a parameter is removed through the dynamic-parameter API. */
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterRemoveName;
/*! Posted after a parameter's name is read. */
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterGetNameName;
/*! Posted before a parameter's name is written. */
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetNamePreName;
/*! Posted after a parameter's name is written. */
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetNameName;
/*! Posted after a parameter's type is read. */
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterGetTypeName;

/*! Posted after a parameter's floating-point bounds are written. */
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetFloatBoundsName;
/*! Posted after a parameter's integer bounds are written. */
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetIntBoundsName;
/*! Posted after a menu parameter's entries are read. */
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterGetMenuName;
/*! Posted before a menu parameter's entries are written. */
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetMenuPreName;
/*! Posted after a menu parameter's entries are written. */
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetMenuName;

/*! Posted before a parameter's flags are read. An observer may serve the read from its own cache. */
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterGetFlagsPreName;
/*! Posted after a parameter's flags are read. */
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterGetFlagsName;
/*! Posted after a parameter's string value is read. */
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterGetStringValueName;

/*! Posted after a parameter's boolean value is written. */
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetBoolName;
/*! Posted after a custom parameter's value is written. */
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetCustomValueName;
/*! Posted after a parameter's floating-point value is written. */
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetFloatName;
/*! Posted after a histogram parameter's value is written. */
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetHistogramName;
/*! Posted after a parameter's integer value is written. */
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetIntName;
/*! Posted before a parameter's flags are written. An observer may absorb the write into its own cache. */
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetFlagsPreName;
/*! Posted after a parameter's flags are written. */
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetFlagsName;
/*! Posted after a parameter's path ID is written. */
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetPathIDName;
/*! Posted after a parameter's RGBA value is written. */
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetRGBAName;
/*! Posted after a parameter's RGB value is written. */
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetRGBName;
/*! Posted before a parameter's string value is written. */
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetStringValuePreName;
/*! Posted after a parameter's string value is written. */
extern NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetStringValueName;
/*! Posted after a point parameter's X and Y values are written. */
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
/*! The parameter dictionary stored under FxGripNotifyAPI_ParameterKey; nil removes the key. */
@property (readwrite, nullable, nonatomic) NSDictionary* fxParameter;
/*! The result stored under FxGripNotifyAPI_ResultKey; nil removes the key. */
@property (readwrite, nullable) id fxResult;
/*! The error stored under FxGripNotifyAPI_ErrorKey; nil removes the key. */
@property (readwrite, nullable) NSError* fxError;
@end

#endif
