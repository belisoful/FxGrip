/*!
	@file       FxGripParameterCreationAPI_v6.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripParameterCreationAPI_v6
	@abstract   Implements the FxGrip wrapper for the host's FxParameterCreationAPI_v6.
	@discussion Introduced in FxGrip 0.1.0. addTaggedPopupMenuWithName:… builds the menu payload
	            with the current subgroup as its parent, runs the v5 preprocess step, forwards the
	            amended values to the host v6 API, and posts the parameter-add notification on
	            success.
*/

#import "FxGripParameterCreationAPI_v6.h"
#import "FxGripParameterFlags.h"
#import "FxGripTileableEffect.h"
#import "NSDictionary+FxGripTileableEffect.h"

// preprocess: is a protected helper implemented in the v5 wrapper; declare it for this subclass.
@interface FxGripParameterCreationAPI_v5 ()
- (BOOL)preprocess:(NSMutableDictionary *)userInfo;
@end

/*!
	@abstract	Wraps the host v6 creation API and adds the tagged popup menu.
	@discussion	Introduced in FxGrip 0.1.0. Inherits the v5 add methods and routes the tagged popup
				through the same preprocess and notification path.
*/
@implementation FxGripParameterCreationAPI_v6

/*!
	@method		addTaggedPopupMenuWithName:parameterID:defaultValue:menuEntries:parameterFlags:
	@abstract	Adds a popup menu whose entries carry stable tags.
	@return		YES when the host accepts the parameter; NO when preprocess or the host call fails.
	@discussion	Introduced in FxGrip 0.1.0. Assembles the menu payload, runs the v5 preprocess step,
				forwards to the host v6 API, and posts the parameter-add notification on success.
*/
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
