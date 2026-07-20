//
//  FxAPINotifications.m
//  FxAPINotifications
//
//  Created by Apple on 1/7/20.
//  Copyright © 2020-2023 Apple, Inc. All rights reserved.
//

#import "FxAPINotifications.h"

NSNotificationName const _Nonnull FxNotifyAPI_ParameterKey = @"Parameter";
NSNotificationName const _Nonnull FxNotifyAPI_ResultKey = @"Result";
NSNotificationName const _Nonnull FxNotifyAPI_ErrorKey = @"Error";
NSNotificationName const _Nonnull FxNotifyAPI_ParameterIDKey = @"ID";

//Creation
NSNotificationName const _Nonnull FxNotifyAPI_ParameterAddPreName = @"FxNotify_ParameterAddPre";
NSNotificationName const _Nonnull FxNotifyAPI_ParameterAddName = @"FxNotify_ParameterAdd";
NSNotificationName const _Nonnull FxNotifyAPI_ParameterStartGroupName = @"FxNotify_ParameterStartGroup";
NSNotificationName const _Nonnull FxNotifyAPI_ParameterEndGroupName = @"FxNotify_ParameterEndGroup";

//Dynamic
NSNotificationName const _Nonnull FxNotifyAPI_ParameterRemoveName = @"FxNotify_ParameterRemove";
NSNotificationName const _Nonnull FxNotifyAPI_ParameterGetNameName = @"FxNotify_ParameterGetName";
NSNotificationName const _Nonnull FxNotifyAPI_ParameterSetNamePreName = @"FxNotify_ParameterSetNamePre";
NSNotificationName const _Nonnull FxNotifyAPI_ParameterSetNameName = @"FxNotify_ParameterSetName";
NSNotificationName const _Nonnull FxNotifyAPI_ParameterGetTypeName = @"FxNotify_ParameterGetType";

NSNotificationName const _Nonnull FxNotifyAPI_ParameterSetFloatBoundsName = @"FxNotify_ParameterSetFloatBounds";
NSNotificationName const _Nonnull FxNotifyAPI_ParameterSetIntBoundsName = @"FxNotify_ParameterSetIntBounds";
NSNotificationName const _Nonnull FxNotifyAPI_ParameterGetMenuName = @"FxNotify_ParameterGetMenu";
NSNotificationName const _Nonnull FxNotifyAPI_ParameterSetMenuPreName = @"FxNotify_ParameterSetMenuPre";
NSNotificationName const _Nonnull FxNotifyAPI_ParameterSetMenuName = @"FxNotify_ParameterSetMenu";

//Get API
NSNotificationName const _Nonnull FxNotifyAPI_ParameterGetFlagsPreName = @"FxNotify_ParameterGetFlagsPre";
NSNotificationName const _Nonnull FxNotifyAPI_ParameterGetFlagsName = @"FxNotify_ParameterGetFlags";
NSNotificationName const _Nonnull FxNotifyAPI_ParameterGetStringValueName = @"FxNotify_ParameterGetStringValue";

// Set API
NSNotificationName const _Nonnull FxNotifyAPI_ParameterSetBoolName = @"FxNotify_ParameterSetBool";
NSNotificationName const _Nonnull FxNotifyAPI_ParameterSetCustomValueName = @"FxNotify_ParameterSetCustomValue";
NSNotificationName const _Nonnull FxNotifyAPI_ParameterSetFloatName = @"FxNotify_ParameterSetFloat";
NSNotificationName const _Nonnull FxNotifyAPI_ParameterSetHistogramName = @"FxNotify_ParameterSetHistogram";
NSNotificationName const _Nonnull FxNotifyAPI_ParameterSetIntName = @"FxNotify_ParameterSetInt";
NSNotificationName const _Nonnull FxNotifyAPI_ParameterSetFlagsPreName = @"FxNotify_ParameterSetFlagsPre";
NSNotificationName const _Nonnull FxNotifyAPI_ParameterSetFlagsName = @"FxNotify_ParameterSetFlags";
NSNotificationName const _Nonnull FxNotifyAPI_ParameterSetPathIDName = @"FxNotify_ParameterSetPathID";
NSNotificationName const _Nonnull FxNotifyAPI_ParameterSetRGBAName = @"FxNotify_ParameterSetRGBA";
NSNotificationName const _Nonnull FxNotifyAPI_ParameterSetRGBName = @"FxNotify_ParameterSetRGB";
NSNotificationName const _Nonnull FxNotifyAPI_ParameterSetStringValuePreName = @"FxNotify_ParameterSetStringValuePre";
NSNotificationName const _Nonnull FxNotifyAPI_ParameterSetStringValueName = @"FxNotify_ParameterSetStringValue";
NSNotificationName const _Nonnull FxNotifyAPI_ParameterSetXYName = @"FxNotify_ParameterSetXY";


#pragma mark -
#pragma mark NSDictionary FxPlug Notification UserInfo Access

@implementation NSDictionary (FxAPINotificationUserInfo)

- (nullable NSDictionary *)fxParameter { //NSDictionary or NSMutableDictionary
	return self[FxNotifyAPI_ParameterKey];
}

-(nullable NSMutableDictionary *)mutableFxParameter
{
	if ([self[FxNotifyAPI_ParameterKey] isKindOfClass:NSMutableDictionary.class]) {
		return self[FxNotifyAPI_ParameterKey];
	}
	return nil;
}

- (nullable id)fxResult {
	return self[FxNotifyAPI_ResultKey];
}

- (nullable NSError *)fxError {
	return self[FxNotifyAPI_ErrorKey];
}

@end



@implementation NSMutableDictionary (FxAPINotificationUserInfo)

- (void)setFxParameter:(nullable NSDictionary *)fxParameter {
	if (!fxParameter) {
		[self removeObjectForKey:FxNotifyAPI_ParameterKey];
	} else {
		self[FxNotifyAPI_ParameterKey] = fxParameter;
	}
}


- (void)setFxResult:(nullable id)fxResult {
	if (!fxResult) {
		[self removeObjectForKey:FxNotifyAPI_ResultKey];
	} else {
		self[FxNotifyAPI_ResultKey] = fxResult;
	}
}

- (void)setFxError:(nullable NSError *)fxError {
	if (!fxError) {
		[self removeObjectForKey:FxNotifyAPI_ErrorKey];
	} else {
		self[FxNotifyAPI_ErrorKey] = fxError;
	}
}

@end
