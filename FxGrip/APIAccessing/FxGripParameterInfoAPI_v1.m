//
//  FxGripParameterInfoAPI_v1.m
//  FxGrip
//

#import "FxGripParameterInfoAPI_v1.h"
#import "FxGripTileableEffect.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "FxGripAPINotifications.h"

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
