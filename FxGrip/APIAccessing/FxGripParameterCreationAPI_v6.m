//
//  FxGripParameterCreationAPI_v6.m
//  FxGrip
//

#import "FxGripParameterCreationAPI_v6.h"
#import "FxGripParameterFlags.h"
#import "FxGripTileableEffect.h"
#import "NSDictionary+FxGripTileableEffect.h"

// preprocess: is a protected helper implemented in the v5 wrapper; declare it for this subclass.
@interface FxGripParameterCreationAPI_v5 ()
- (BOOL)preprocess:(NSMutableDictionary *)userInfo;
@end

@implementation FxGripParameterCreationAPI_v6

- (BOOL)addTaggedPopupMenuWithName:(NSString *)name
					   parameterID:(UInt32)parameterID
					  defaultValue:(UInt32)defaultValue
					   menuEntries:(NSArray<FxTaggedMenuEntry *> *)entries
					parameterFlags:(FxParameterFlags)flags
{
	NSMutableDictionary *userInfo = @{
		kFxParameterProperty_Id: @(parameterID),
		FxGripNotifyAPI_ParameterKey: @{
			kFxParameterProperty_Type: @(FxParameterType_Menu),
			kFxParameterProperty_Name: name,
			kFxParameterProperty_Id: @(parameterID),
			kFxParameterProperty_ParentId: self.subGroupStack.lastObject,
			kFxParameterProperty_MenuItems: entries,
			kFxParameterProperty_Default: @(defaultValue),
			kFxParameterProperty_Flags: @(flags)
		}.mutableCopy
	}.mutableCopy;

	if (![self preprocess:userInfo]) {
		return NO;
	}

	NSDictionary *param = userInfo.fxParameter;
	id<FxParameterCreationAPI_v6> api = (id<FxParameterCreationAPI_v6>)self.api;
	if (![api addTaggedPopupMenuWithName:param.parameterName
							 parameterID:param.parameterID
							defaultValue:[param.parameterDefaultValue intValue]
							 menuEntries:param.parameterMenuItems
						  parameterFlags:FxParameterFlagsFxMask(param.parameterFlags)]) {
		return NO;
	}
	[self.effect.notifier postNotificationName:FxGripNotifyAPI_ParameterAddName object:self.effect userInfo:userInfo.copy];
	return YES;
}

@end
