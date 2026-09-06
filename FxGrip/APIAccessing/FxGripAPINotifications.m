/*!
	@file       FxGripAPINotifications.m
	@copyright  Copyright © 2020-2023 Apple, Inc. All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripAPINotifications
	@abstract   Defines the FxGrip API notification names, userInfo keys, and userInfo accessors.
	@discussion Introduced in FxGrip 0.1.0. The constants hold the notification names posted by the
	            parameter wrappers and the keys under which each notification stores its parameter,
	            result, and error. The NSDictionary categories read those keys, and the
	            NSMutableDictionary category writes them, removing a key when its value is nil.
*/

#import "FxGripAPINotifications.h"

NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterKey = @"Parameter";
NSNotificationName const _Nonnull FxGripNotifyAPI_ResultKey = @"Result";
NSNotificationName const _Nonnull FxGripNotifyAPI_ErrorKey = @"Error";
NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterIDKey = @"ID";

//Creation
NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterAddPreName = @"FxGripNotify_ParameterAddPre";
NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterAddName = @"FxGripNotify_ParameterAdd";
NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterStartGroupName = @"FxGripNotify_ParameterStartGroup";
NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterEndGroupName = @"FxGripNotify_ParameterEndGroup";

//Dynamic
NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterRemoveName = @"FxGripNotify_ParameterRemove";
NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterGetNameName = @"FxGripNotify_ParameterGetName";
NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetNamePreName = @"FxGripNotify_ParameterSetNamePre";
NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetNameName = @"FxGripNotify_ParameterSetName";
NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterGetTypeName = @"FxGripNotify_ParameterGetType";

NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetFloatBoundsName = @"FxGripNotify_ParameterSetFloatBounds";
NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetIntBoundsName = @"FxGripNotify_ParameterSetIntBounds";
NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterGetMenuName = @"FxGripNotify_ParameterGetMenu";
NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetMenuPreName = @"FxGripNotify_ParameterSetMenuPre";
NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetMenuName = @"FxGripNotify_ParameterSetMenu";

//Get API
NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterGetFlagsPreName = @"FxGripNotify_ParameterGetFlagsPre";
NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterGetFlagsName = @"FxGripNotify_ParameterGetFlags";
NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterGetStringValueName = @"FxGripNotify_ParameterGetStringValue";

// Set API
NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetBoolName = @"FxGripNotify_ParameterSetBool";
NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetCustomValueName = @"FxGripNotify_ParameterSetCustomValue";
NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetFloatName = @"FxGripNotify_ParameterSetFloat";
NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetHistogramName = @"FxGripNotify_ParameterSetHistogram";
NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetIntName = @"FxGripNotify_ParameterSetInt";
NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetFlagsPreName = @"FxGripNotify_ParameterSetFlagsPre";
NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetFlagsName = @"FxGripNotify_ParameterSetFlags";
NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetPathIDName = @"FxGripNotify_ParameterSetPathID";
NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetRGBAName = @"FxGripNotify_ParameterSetRGBA";
NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetRGBName = @"FxGripNotify_ParameterSetRGB";
NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetStringValuePreName = @"FxGripNotify_ParameterSetStringValuePre";
NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetStringValueName = @"FxGripNotify_ParameterSetStringValue";
NSNotificationName const _Nonnull FxGripNotifyAPI_ParameterSetXYName = @"FxGripNotify_ParameterSetXY";


#pragma mark -
#pragma mark NSDictionary FxPlug Notification UserInfo Access

/*!
	@abstract	Reads the FxGrip notification userInfo values by key.
	@discussion	Introduced in FxGrip 0.1.0. mutableFxParameter returns the parameter only when it
				is an NSMutableDictionary.
*/
@implementation NSDictionary (FxGripAPINotificationUserInfo)

- (nullable NSDictionary *)fxParameter { //NSDictionary or NSMutableDictionary
	return self[FxGripNotifyAPI_ParameterKey];
}

-(nullable NSMutableDictionary *)mutableFxParameter
{
	if ([self[FxGripNotifyAPI_ParameterKey] isKindOfClass:NSMutableDictionary.class]) {
		return self[FxGripNotifyAPI_ParameterKey];
	}
	return nil;
}

- (nullable id)fxResult {
	return self[FxGripNotifyAPI_ResultKey];
}

- (nullable NSError *)fxError {
	return self[FxGripNotifyAPI_ErrorKey];
}

@end



/*!
	@abstract	Writes the FxGrip notification userInfo values by key.
	@discussion	Introduced in FxGrip 0.1.0. Each setter removes its key when the value is nil.
*/
@implementation NSMutableDictionary (FxGripAPINotificationUserInfo)

- (void)setFxParameter:(nullable NSDictionary *)fxParameter {
	if (!fxParameter) {
		[self removeObjectForKey:FxGripNotifyAPI_ParameterKey];
	} else {
		self[FxGripNotifyAPI_ParameterKey] = fxParameter;
	}
}


- (void)setFxResult:(nullable id)fxResult {
	if (!fxResult) {
		[self removeObjectForKey:FxGripNotifyAPI_ResultKey];
	} else {
		self[FxGripNotifyAPI_ResultKey] = fxResult;
	}
}

- (void)setFxError:(nullable NSError *)fxError {
	if (!fxError) {
		[self removeObjectForKey:FxGripNotifyAPI_ErrorKey];
	} else {
		self[FxGripNotifyAPI_ErrorKey] = fxError;
	}
}

@end
