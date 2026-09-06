/*!
	@file       FxGripParameterInfoAPI_v1.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripParameterInfoAPI_v1
	@abstract   Implements the read-only parameter queries.
	@discussion Introduced in FxGrip 0.1.0. Existence and the ID list iterate Apple's
	            FxDynamicParameterAPI_v3 roster. Type and menu queries post notifications on the
	            effect and read the resulting payload back.
*/

#import "FxGripParameterInfoAPI_v1.h"
#import "FxGripTileableEffect.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "FxGripAPINotifications.h"

/*!
	@abstract	FxGrip's implementation of the read-only parameter queries.
	@discussion	Introduced in FxGrip 0.1.0. Wraps Apple's FxDynamicParameterAPI_v3 for the roster
				walk and posts notifications for type and menu entries.
*/
@implementation FxGripParameterInfoAPI_v1

- (nullable instancetype)initWithAPI:(id<FxDynamicParameterAPI_v3> _Nullable)api
							  effect:(nonnull id<FxGripEffectHost>)effect
{
	self = [super initWithEffect:effect];
	if (self != nil) {
		_api = api;
	}
	return self;
}

/*! @abstract YES when a parameter with this ID appears in the host roster. */
- (BOOL)parameterExists:(FxParameterId)parameterID
{
	UInt32 count = [self.api parameterCount];

	for (UInt32 i = 0; i < count; i++) {
		if ([self.api parameterIDAtIndex:i] == parameterID) {
			return YES;
		}
	}

	return NO;
}

/*! @abstract Resolves the parameter's type by posting the get-type notification and reading the payload. */
- (FxParameterType)parameterType:(FxParameterId)parameterID
{
	NSMutableDictionary *userInfo = @{
			kFxParameterProperty_Id: @(parameterID),
			FxGripNotifyAPI_ParameterKey:@{
				kFxParameterProperty_Id: @(parameterID),
				kFxParameterProperty_Type: @0
			}.mutableCopy
		}.mutableCopy;
	[self.effect.notifier postNotificationName:FxGripNotifyAPI_ParameterGetTypeName object:self.effect userInfo:userInfo];
	return ((NSNumber*)userInfo.fxParameter[kFxParameterProperty_Type]).intValue;
}

/*! @abstract Fills `entries` with a menu parameter's item titles by posting the get-menu notification. */
// Gets the menu entries
- (NSError*)parameter:(FxParameterId)parameterID entries:(NSArray<NSString*>**_Nonnull)entries
{
	NSMutableDictionary *userInfo = @{
			kFxParameterProperty_Id: @(parameterID),
			FxGripNotifyAPI_ParameterKey:@{
				kFxParameterProperty_Id: @(parameterID),
				kFxParameterProperty_MenuItems: @[]
			}.mutableCopy
		}.mutableCopy;
	[self.effect.notifier postNotificationName:FxGripNotifyAPI_ParameterGetMenuName object:self.effect userInfo:userInfo];
	*entries = userInfo.fxParameter[kFxParameterProperty_MenuItems];

	return userInfo.fxError;
}

/*! @abstract Every registered parameter ID, in host roster order. */
- (NSArray<NSNumber*>*)allParameterIDs
{
	UInt32			count = [self.api parameterCount];
	NSMutableArray	*ids = [NSMutableArray arrayWithCapacity:count];

	for (UInt32 i = 0; i < count; i++) {
		[ids addObject:@([self.api parameterIDAtIndex:i])];
	}

	return [ids copy];
}

@end
