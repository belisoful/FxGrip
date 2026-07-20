//
//  FxGripParameterCreationAPI_v5.m
//  XPC Service
//
//  Created by ~ ~ on 2/29/24.
//

#import "FxParameterFlags.h"
#import "FxGripParameterCreationAPI_v5.h"
#import "FxTileableEffectBase.h"
#import "FxTileableEffectBase+Notifications.h"
//#import "GuruFxTileableEffect+Extensions.h"
#import <BEFoundation/NSArray+BExtension.h>
#import <BEFoundation/BEStackExtensions.h>
#import "FxAPINotifications.h"
#import "NSDictionary+FxTileableEFfect.h"
#import "FxGrip_ARC.h"

@implementation FxGripParameterCreationAPI_v5

//---------------------------------------------------------
// initWithAPIManager:
//
// This method is called when a plug-in is first loaded, and
// is a good point to conduct any checks for anti-piracy or
// system compatibility. Returning NULL means that a plug-in
// chooses not to be accessible for some reason.
//---------------------------------------------------------

- (nullable instancetype)initWithAPI:(id<FxParameterCreationAPI_v5>)api
							  effect:(id<FxTileableEffectBase>)effect
{
	self = [super initWithEffect:effect];
	
	if (self != nil)
	{
		_api = api;
		_subGroupStack = NARC_RETAIN([NSMutableArray.alloc initWithCapacity:6]);
		[_subGroupStack addObject:@0];
	}
	return self;
}

- (void)dealloc
{
	NARC_RELEASE(_subGroupStack);
	
	SUPER_DEALLOC();
}

- (BOOL)preprocess:(NSMutableDictionary*)userInfo
{
	FxParameterType parameterType = userInfo.fxParameter.parameterType;
	FxParameterId parameterID = userInfo.fxParameter.parameterID;
	FxParameterId parameterParentID = userInfo.fxParameter.parameterParentID;
	
	[self.effect.notifier postNotificationName:FxNotifyAPI_ParameterSetNamePreName object:self.effect userInfo:userInfo];
	
	[self.effect.notifier postNotificationName:FxNotifyAPI_ParameterAddPreName object:self.effect userInfo:userInfo];
	
	//ensure these parameters
	userInfo.parameterID = parameterID;
	userInfo.mutableFxParameter.parameterType = parameterType;
	userInfo.mutableFxParameter.parameterID = parameterID;
	userInfo.mutableFxParameter.parameterParentID = parameterParentID;
	
	userInfo.fxParameter = userInfo.fxParameter.copy;
#if DEBUG
	if (userInfo.fxError) {
		NSLog(@"%s Error PreProcessing Failed %@", __func__, userInfo.fxError);
	}
#endif
	
	return userInfo.fxError == nil;
}


- (BOOL)addAngleSliderWithName:(nonnull NSString *)name
				   parameterID:(UInt32)parameterID
				defaultDegrees:(double)defaultDegrees
		   parameterMinDegrees:(double)minDegrees
		   parameterMaxDegrees:(double)maxDegrees
				parameterFlags:(FxParameterFlags)flags
{
	NSMutableDictionary *userInfo = @{
		kFxParameterProperty_Id: @(parameterID),
		FxNotifyAPI_ParameterKey: @{
			kFxParameterProperty_Type: @(FxParameterType_Angle),
			kFxParameterProperty_Name: name,
			kFxParameterProperty_Id: @(parameterID),
			kFxParameterProperty_ParentId: _subGroupStack.lastObject,
			kFxParameterProperty_Default: @(defaultDegrees),
			kFxParameterProperty_Minimum: @(minDegrees),
			kFxParameterProperty_Maximum: @(maxDegrees),
			kFxParameterProperty_Flags: @(flags)
		}.mutableCopy
	}.mutableCopy;
	
	if(![self preprocess:userInfo]) {
		return NO;
	}
	
	NSDictionary *param = userInfo.fxParameter;
	if (![_api addAngleSliderWithName:param.parameterName
						  parameterID:param.parameterID
					   defaultDegrees:[param.parameterDefaultValue doubleValue]
				  parameterMinDegrees:param.parameterMinimumDouble
				  parameterMaxDegrees:param.parameterMaximumDouble
					   parameterFlags:FxParameterFlagsFxMask(param.parameterFlags)]) {
		return NO;
	}
	
	[self.effect.notifier postNotificationName:FxNotifyAPI_ParameterAddName object:self.effect userInfo:userInfo.copy];
	return YES;
}



- (BOOL)addColorParameterWithName:(nonnull NSString *)name
					  parameterID:(UInt32)parameterID
					   defaultRed:(double)red
					 defaultGreen:(double)green
					  defaultBlue:(double)blue
					 defaultAlpha:(double)alpha
				   parameterFlags:(FxParameterFlags)flags
{
	NSMutableDictionary *userInfo = @{
		kFxParameterProperty_Id: @(parameterID),
		FxNotifyAPI_ParameterKey: @{
			kFxParameterProperty_Type: @(FxParameterType_RGBA),
			kFxParameterProperty_Name: name,
			kFxParameterProperty_Id: @(parameterID),
			kFxParameterProperty_ParentId: _subGroupStack.lastObject,
			kFxParameterProperty_Red: @(red),
			kFxParameterProperty_Green: @(green),
			kFxParameterProperty_Blue: @(blue),
			kFxParameterProperty_Alpha: @(alpha),
			kFxParameterProperty_Flags: @(flags)
		}.mutableCopy
	}.mutableCopy;
	
	if(![self preprocess:userInfo]) {
		return NO;
	}
	
	NSDictionary *param = userInfo.fxParameter;
	if (![_api addColorParameterWithName:param.parameterName
							 parameterID:param.parameterID
							  defaultRed:[param.parameterRed doubleValue]
							defaultGreen:[param.parameterGreen doubleValue]
							 defaultBlue:[param.parameterBlue doubleValue]
							defaultAlpha:[param.parameterAlpha doubleValue]
						  parameterFlags:FxParameterFlagsFxMask(param.parameterFlags)]) {
		return NO;
	}
	[self.effect.notifier postNotificationName:FxNotifyAPI_ParameterAddName object:self.effect userInfo:userInfo.copy];
	return YES;
}


- (BOOL)addColorParameterWithName:(nonnull NSString *)name
					  parameterID:(UInt32)parameterID
					   defaultRed:(double)red
					 defaultGreen:(double)green
					  defaultBlue:(double)blue
				   parameterFlags:(FxParameterFlags)flags
{
	NSMutableDictionary *userInfo = @{
		kFxParameterProperty_Id: @(parameterID),
		FxNotifyAPI_ParameterKey: @{
			kFxParameterProperty_Type: @(FxParameterType_RGB),
			kFxParameterProperty_Name: name,
			kFxParameterProperty_Id: @(parameterID),
			kFxParameterProperty_ParentId: _subGroupStack.lastObject,
			kFxParameterProperty_Red: @(red),
			kFxParameterProperty_Green: @(green),
			kFxParameterProperty_Blue: @(blue),
			kFxParameterProperty_Flags: @(flags)
		}.mutableCopy
	}.mutableCopy;
	
	if(![self preprocess:userInfo]) {
		return NO;
	}
	
	NSDictionary *param = userInfo.fxParameter;
	if (![_api addColorParameterWithName:param.parameterName
							 parameterID:param.parameterID
							  defaultRed:[param.parameterRed doubleValue]
							defaultGreen:[param.parameterGreen doubleValue]
							 defaultBlue:[param.parameterBlue doubleValue]
						  parameterFlags:FxParameterFlagsFxMask(param.parameterFlags)]) {
		return NO;
	}
	[self.effect.notifier postNotificationName:FxNotifyAPI_ParameterAddName object:self.effect userInfo:userInfo.copy];
	return YES;
}


- (BOOL)addCustomParameterWithName:(nonnull NSString *)name
					   parameterID:(UInt32)parameterID
					  defaultValue:(nonnull NSObject<NSSecureCoding,NSCopying> *)defaultValue
					parameterFlags:(FxParameterFlags)flags
{
	NSMutableDictionary *userInfo = @{
		kFxParameterProperty_Id: @(parameterID),
		FxNotifyAPI_ParameterKey: @{
			kFxParameterProperty_Type: @(FxParameterType_Custom),
			kFxParameterProperty_Name: name,
			kFxParameterProperty_Id: @(parameterID),
			kFxParameterProperty_ParentId: _subGroupStack.lastObject,
			kFxParameterProperty_Default: defaultValue,
			kFxParameterProperty_Flags: @(flags)
		}.mutableCopy
	}.mutableCopy;
	
	if(![self preprocess:userInfo]) {
		return NO;
	}
	
	NSDictionary *param = userInfo.fxParameter;
	if (![_api addCustomParameterWithName:param.parameterName
							  parameterID:param.parameterID
							 defaultValue:defaultValue
						   parameterFlags:FxParameterFlagsFxMask(param.parameterFlags)]) {
		return NO;
	}
	[self.effect.notifier postNotificationName:FxNotifyAPI_ParameterAddName object:self.effect userInfo:userInfo.copy];
	return YES;
}


- (BOOL)addFloatSliderWithName:(nonnull NSString *)name
				   parameterID:(UInt32)parameterID
				  defaultValue:(double)defaultValue
				  parameterMin:(double)min
				  parameterMax:(double)max
					 sliderMin:(double)sliderMin
					 sliderMax:(double)sliderMax
						 delta:(double)sliderDelta
				parameterFlags:(FxParameterFlags)flags
{
	NSMutableDictionary *userInfo = @{
		kFxParameterProperty_Id: @(parameterID),
		FxNotifyAPI_ParameterKey: @{
			kFxParameterProperty_Type: @(FxParameterType_Float),
			kFxParameterProperty_Name: name,
			kFxParameterProperty_Id: @(parameterID),
			kFxParameterProperty_ParentId: _subGroupStack.lastObject,
			kFxParameterProperty_Default: @(defaultValue),
			kFxParameterProperty_Minimum: @(min),
			kFxParameterProperty_Maximum: @(max),
			kFxParameterProperty_SliderMinimum: @(sliderMin),
			kFxParameterProperty_SliderMaximum: @(sliderMax),
			kFxParameterProperty_Delta: @(sliderDelta),
			kFxParameterProperty_Flags: @(flags)
		}.mutableCopy
	}.mutableCopy;
	
	if(![self preprocess:userInfo]) {
		return NO;
	}
	
	NSDictionary *param = userInfo.fxParameter;
	if (![_api addFloatSliderWithName:param.parameterName
						  parameterID:param.parameterID
						 defaultValue:[param.parameterDefaultValue doubleValue]
						 parameterMin:param.parameterMinimumDouble
						 parameterMax:[param.parameterMaximum doubleValue]
							sliderMin:[param.parameterSliderMinimum doubleValue]
							sliderMax:[param.parameterSliderMaximum doubleValue]
								delta:[param.parameterDelta doubleValue]
					   parameterFlags:FxParameterFlagsFxMask(param.parameterFlags)]) {
		return NO;
	}
	[self.effect.notifier postNotificationName:FxNotifyAPI_ParameterAddName object:self.effect userInfo:userInfo.copy];
	return YES;
}


- (BOOL)addFontMenuWithName:(nonnull NSString *)name
				parameterID:(UInt32)parameterID
				   fontName:(nonnull NSString *)fontName
			 parameterFlags:(FxParameterFlags)flags
{
	NSMutableDictionary *userInfo = @{
		kFxParameterProperty_Id: @(parameterID),
		FxNotifyAPI_ParameterKey: @{
			kFxParameterProperty_Type: @(FxParameterType_FontMenu),
			kFxParameterProperty_Name: name,
			kFxParameterProperty_Id: @(parameterID),
			kFxParameterProperty_ParentId: _subGroupStack.lastObject,
			kFxParameterProperty_Default: fontName,
			kFxParameterProperty_Flags: @(flags)
		}.mutableCopy
	}.mutableCopy;
	
	if(![self preprocess:userInfo]) {
		return NO;
	}
	
	NSDictionary *param = userInfo.fxParameter;
	if (![_api addFontMenuWithName:param.parameterName
					   parameterID:param.parameterID
						  fontName:param.parameterDefaultValue
					parameterFlags:FxParameterFlagsFxMask(param.parameterFlags)]) {
		return NO;
	}
	[self.effect.notifier postNotificationName:FxNotifyAPI_ParameterAddName object:self.effect userInfo:userInfo.copy];
	return YES;
}


- (BOOL)addGradientWithName:(nonnull NSString *)name
				parameterID:(UInt32)parameterID
			 parameterFlags:(FxParameterFlags)flags
{
	NSMutableDictionary *userInfo = @{
		kFxParameterProperty_Id: @(parameterID),
		FxNotifyAPI_ParameterKey: @{
			kFxParameterProperty_Type: @(FxParameterType_Gradient),
			kFxParameterProperty_Name: name,
			kFxParameterProperty_Id: @(parameterID),
			kFxParameterProperty_ParentId: _subGroupStack.lastObject,
			kFxParameterProperty_Flags: @(flags)
		}.mutableCopy
	}.mutableCopy;
	
	if(![self preprocess:userInfo]) {
		return NO;
	}
	
	NSDictionary *param = userInfo.fxParameter;
	if (![_api addGradientWithName:param.parameterName
					   parameterID:param.parameterID
					parameterFlags:FxParameterFlagsFxMask(param.parameterFlags)]) {
		return NO;
	}
	[self.effect.notifier postNotificationName:FxNotifyAPI_ParameterAddName object:self.effect userInfo:userInfo.copy];
	return YES;
}


- (BOOL)addHelpButtonWithName:(nonnull NSString *)name
				  parameterID:(UInt32)parameterID
					 selector:(nonnull SEL)selector
			   parameterFlags:(FxParameterFlags)flags
{
	NSMutableDictionary *userInfo = @{
		kFxParameterProperty_Id: @(parameterID),
		FxNotifyAPI_ParameterKey: @{
			kFxParameterProperty_Type: @(FxParameterType_Help),
			kFxParameterProperty_Name: name,
			kFxParameterProperty_Id: @(parameterID),
			kFxParameterProperty_ParentId: _subGroupStack.lastObject,
			kFxParameterProperty_Selector: NSStringFromSelector(selector),
			kFxParameterProperty_Flags: @(flags)
		}.mutableCopy
	}.mutableCopy;
	
	if(![self preprocess:userInfo]) {
		return NO;
	}
	
	NSDictionary *param = userInfo.fxParameter;
	if (![_api addHelpButtonWithName:param.parameterName
						 parameterID:param.parameterID
							selector:NSSelectorFromString(param.parameterSelector)
					  parameterFlags:FxParameterFlagsFxMask(param.parameterFlags)]) {
		return NO;
	}
	[self.effect.notifier postNotificationName:FxNotifyAPI_ParameterAddName object:self.effect userInfo:userInfo.copy];
	return YES;
}


- (BOOL)addHistogramWithName:(nonnull NSString *)name
				 parameterID:(UInt32)parameterID
			  parameterFlags:(FxParameterFlags)flags
{
	NSMutableDictionary *userInfo = @{
		kFxParameterProperty_Id: @(parameterID),
		FxNotifyAPI_ParameterKey: @{
			kFxParameterProperty_Type: @(FxParameterType_Histogram),
			kFxParameterProperty_Name: name,
			kFxParameterProperty_Id: @(parameterID),
			kFxParameterProperty_ParentId: _subGroupStack.lastObject,
			kFxParameterProperty_Flags: @(flags)
		}.mutableCopy
	}.mutableCopy;
	
	if(![self preprocess:userInfo]) {
		return NO;
	}
	
	NSDictionary *param = userInfo.fxParameter;
	if (![_api addHistogramWithName:param.parameterName
						parameterID:param.parameterID
					 parameterFlags:FxParameterFlagsFxMask(param.parameterFlags)]) {
		return NO;
	}
	[self.effect.notifier postNotificationName:FxNotifyAPI_ParameterAddName object:self.effect userInfo:userInfo.copy];
	return YES;
}


- (BOOL)addImageReferenceWithName:(nonnull NSString *)name
					  parameterID:(UInt32)parameterID
				   parameterFlags:(FxParameterFlags)flags
{
	NSMutableDictionary *userInfo = @{
		kFxParameterProperty_Id: @(parameterID),
		FxNotifyAPI_ParameterKey: @{
			kFxParameterProperty_Type: @(FxParameterType_ImageRef),
			kFxParameterProperty_Name: name,
			kFxParameterProperty_Id: @(parameterID),
			kFxParameterProperty_ParentId: _subGroupStack.lastObject,
			kFxParameterProperty_Flags: @(flags)
		}.mutableCopy
	}.mutableCopy;
	
	if(![self preprocess:userInfo]) {
		return NO;
	}
	
	NSDictionary *param = userInfo.fxParameter;
	if (![_api addImageReferenceWithName:param.parameterName
							 parameterID:param.parameterID
						  parameterFlags:FxParameterFlagsFxMask(param.parameterFlags)]) {
		return NO;
	}
	[self.effect.notifier postNotificationName:FxNotifyAPI_ParameterAddName object:self.effect userInfo:userInfo.copy];
	return YES;
}


- (BOOL)addIntSliderWithName:(nonnull NSString *)name
				 parameterID:(UInt32)parameterID
				defaultValue:(int)defaultValue
				parameterMin:(int)min
				parameterMax:(int)max
				   sliderMin:(int)sliderMin
				   sliderMax:(int)sliderMax
					   delta:(int)sliderDelta
			  parameterFlags:(FxParameterFlags)flags
{
	NSMutableDictionary *userInfo = @{
		kFxParameterProperty_Id: @(parameterID),
		FxNotifyAPI_ParameterKey: @{
			kFxParameterProperty_Type: @(FxParameterType_Int),
			kFxParameterProperty_Name: name,
			kFxParameterProperty_Id: @(parameterID),
			kFxParameterProperty_ParentId: _subGroupStack.lastObject,
			kFxParameterProperty_Default: @(defaultValue),
			kFxParameterProperty_Minimum: @(min),
			kFxParameterProperty_Maximum: @(max),
			kFxParameterProperty_SliderMinimum: @(sliderMin),
			kFxParameterProperty_SliderMaximum: @(sliderMax),
			kFxParameterProperty_Delta: @(sliderDelta),
			kFxParameterProperty_Flags: @(flags)
		}.mutableCopy
	}.mutableCopy;
	
	if(![self preprocess:userInfo]) {
		return NO;
	}
	
	NSDictionary *param = userInfo.fxParameter;
	if (![_api addIntSliderWithName:param.parameterName
						parameterID:param.parameterID
					   defaultValue:[param.parameterDefaultValue intValue]
					   parameterMin:[param.parameterDefaultValue intValue]
					   parameterMax:[param.parameterDefaultValue intValue]
						  sliderMin:[param.parameterDefaultValue intValue]
						  sliderMax:[param.parameterDefaultValue intValue]
							  delta:[param.parameterDefaultValue intValue]
					 parameterFlags:FxParameterFlagsFxMask(param.parameterFlags)]) {
		return NO;
	}
	[self.effect.notifier postNotificationName:FxNotifyAPI_ParameterAddName object:self.effect userInfo:userInfo.copy];
	return YES;
}


- (BOOL)addPathPickerWithName:(nonnull NSString *)name
				  parameterID:(UInt32)parameterID
			   parameterFlags:(FxParameterFlags)flags
{
	NSMutableDictionary *userInfo = @{
		kFxParameterProperty_Id: @(parameterID),
		FxNotifyAPI_ParameterKey: @{
			kFxParameterProperty_Type: @(FxParameterType_PathID),
			kFxParameterProperty_Name: name,
			kFxParameterProperty_Id: @(parameterID),
			kFxParameterProperty_ParentId: _subGroupStack.lastObject,
			kFxParameterProperty_Flags: @(flags)
		}.mutableCopy
	}.mutableCopy;
	
	if(![self preprocess:userInfo]) {
		return NO;
	}
	
	NSDictionary *param = userInfo.fxParameter;
	if (![_api addPathPickerWithName:param.parameterName
						 parameterID:param.parameterID
					  parameterFlags:FxParameterFlagsFxMask(param.parameterFlags)]) {
		return NO;
	}
	[self.effect.notifier postNotificationName:FxNotifyAPI_ParameterAddName object:self.effect userInfo:userInfo.copy];
	return YES;
}


- (BOOL)addPercentSliderWithName:(nonnull NSString *)name
					 parameterID:(UInt32)parameterID
					defaultValue:(double)defaultValue
					parameterMin:(double)min
					parameterMax:(double)max
					   sliderMin:(double)sliderMin
					   sliderMax:(double)sliderMax
						   delta:(double)sliderDelta
				  parameterFlags:(FxParameterFlags)flags
{
	NSMutableDictionary *userInfo = @{
		kFxParameterProperty_Id: @(parameterID),
		FxNotifyAPI_ParameterKey: @{
			kFxParameterProperty_Type: @(FxParameterType_Percent),
			kFxParameterProperty_Name: name,
			kFxParameterProperty_Id: @(parameterID),
			kFxParameterProperty_ParentId: _subGroupStack.lastObject,
			kFxParameterProperty_Default: @(defaultValue),
			kFxParameterProperty_Minimum: @(min),
			kFxParameterProperty_Maximum: @(max),
			kFxParameterProperty_SliderMinimum: @(sliderMin),
			kFxParameterProperty_SliderMaximum: @(sliderMax),
			kFxParameterProperty_Delta: @(sliderDelta),
			kFxParameterProperty_Flags: @(flags)
		}.mutableCopy
	}.mutableCopy;
	
	if(![self preprocess:userInfo]) {
		return NO;
	}
	
	NSDictionary *param = userInfo.fxParameter;
	if (![_api addPercentSliderWithName:param.parameterName
							parameterID:param.parameterID
						   defaultValue:[param.parameterDefaultValue doubleValue]
						   parameterMin:param.parameterMinimumDouble
						   parameterMax:[param.parameterMaximum doubleValue]
							  sliderMin:[param.parameterSliderMinimum doubleValue]
							  sliderMax:[param.parameterSliderMaximum doubleValue]
								  delta:[param.parameterDelta doubleValue]
						 parameterFlags:FxParameterFlagsFxMask(param.parameterFlags)]) {
		return NO;
	}
	[self.effect.notifier postNotificationName:FxNotifyAPI_ParameterAddName object:self.effect userInfo:userInfo.copy];
	return YES;
}


- (BOOL)addPointParameterWithName:(nonnull NSString *)name
					  parameterID:(UInt32)parameterID
						 defaultX:(double)defaultX
						 defaultY:(double)defaultY
				   parameterFlags:(FxParameterFlags)flags
{
	NSMutableDictionary *userInfo = @{
		kFxParameterProperty_Id: @(parameterID),
		FxNotifyAPI_ParameterKey: @{
			kFxParameterProperty_Type: @(FxParameterType_Point),
			kFxParameterProperty_Name: name,
			kFxParameterProperty_Id: @(parameterID),
			kFxParameterProperty_ParentId: _subGroupStack.lastObject,
			kFxParameterProperty_X: @(defaultX),
			kFxParameterProperty_Y: @(defaultY),
			kFxParameterProperty_Flags: @(flags)
		}.mutableCopy
	}.mutableCopy;
	
	if(![self preprocess:userInfo]) {
		return NO;
	}
	
	NSDictionary *param = userInfo.fxParameter;
	if (![_api addPointParameterWithName:param.parameterName
							 parameterID:param.parameterID
								defaultX:[param.parameterDefaultX doubleValue]
								defaultY:[param.parameterDefaultY doubleValue]
						  parameterFlags:FxParameterFlagsFxMask(param.parameterFlags)]) {
		return NO;
	}
	[self.effect.notifier postNotificationName:FxNotifyAPI_ParameterAddName object:self.effect userInfo:userInfo.copy];
	return YES;
}


- (BOOL)addPopupMenuWithName:(nonnull NSString *)name
				 parameterID:(UInt32)parameterID
				defaultValue:(UInt32)defaultValue
				 menuEntries:(nonnull NSArray *)entries
			  parameterFlags:(FxParameterFlags)flags
{
	NSMutableDictionary *userInfo = @{
		kFxParameterProperty_Id: @(parameterID),
		FxNotifyAPI_ParameterKey: @{
			kFxParameterProperty_Type: @(FxParameterType_Menu),
			kFxParameterProperty_Name: name,
			kFxParameterProperty_Id: @(parameterID),
			kFxParameterProperty_ParentId: _subGroupStack.lastObject,
			kFxParameterProperty_MenuItems: entries,
			kFxParameterProperty_Flags: @(flags)
		}.mutableCopy
	}.mutableCopy;
	
	if(![self preprocess:userInfo]) {
		return NO;
	}
	
	NSDictionary *param = userInfo.fxParameter;
	if (![_api addPopupMenuWithName:param.parameterName
						parameterID:param.parameterID
					   defaultValue:[param.parameterDefaultValue intValue]
						menuEntries:param.parameterMenuItems
					 parameterFlags:FxParameterFlagsFxMask(param.parameterFlags)]) {
		return NO;
	}
	[self.effect.notifier postNotificationName:FxNotifyAPI_ParameterAddName object:self.effect userInfo:userInfo.copy];
	return YES;
}


- (BOOL)addPushButtonWithName:(nonnull NSString *)name
				  parameterID:(UInt32)parameterID
					 selector:(nonnull SEL)selector
			   parameterFlags:(FxParameterFlags)flags
{
	NSMutableDictionary *userInfo = @{
		kFxParameterProperty_Id: @(parameterID),
		FxNotifyAPI_ParameterKey: @{
			kFxParameterProperty_Type: @(FxParameterType_PushButton),
			kFxParameterProperty_Name: name,
			kFxParameterProperty_Id: @(parameterID),
			kFxParameterProperty_ParentId: _subGroupStack.lastObject,
			kFxParameterProperty_Selector: NSStringFromSelector(selector),
			kFxParameterProperty_Flags: @(flags)
		}.mutableCopy
	}.mutableCopy;
	
	if(![self preprocess:userInfo]) {
		return NO;
	}
	
	NSDictionary *param = userInfo.fxParameter;
	if (![_api addPushButtonWithName:param.parameterName
						 parameterID:param.parameterID
							selector:NSSelectorFromString(param.parameterSelector)
					  parameterFlags:FxParameterFlagsFxMask(param.parameterFlags)]) {
		return NO;
	}
	[self.effect.notifier postNotificationName:FxNotifyAPI_ParameterAddName object:self.effect userInfo:userInfo.copy];
	return YES;
}


- (BOOL)addStringParameterWithName:(nonnull NSString *)name
					   parameterID:(UInt32)parameterID
					  defaultValue:(nonnull NSString *)defaultValue
					parameterFlags:(FxParameterFlags)flags
{
	NSMutableDictionary *userInfo = @{
		kFxParameterProperty_Id: @(parameterID),
		FxNotifyAPI_ParameterKey: @{
			kFxParameterProperty_Type: @(FxParameterType_String),
			kFxParameterProperty_Name: name,
			kFxParameterProperty_Id: @(parameterID),
			kFxParameterProperty_ParentId: _subGroupStack.lastObject,
			kFxParameterProperty_Default: defaultValue,
			kFxParameterProperty_Flags: @(flags)
		}.mutableCopy
	}.mutableCopy;
	
	if(![self preprocess:userInfo]) {
		return NO;
	}
	
	NSDictionary *param = userInfo.fxParameter;
	if (![_api addStringParameterWithName:param.parameterName
							  parameterID:param.parameterID
							 defaultValue:param.parameterDefaultValue
						   parameterFlags:FxParameterFlagsFxMask(param.parameterFlags)]) {
		return NO;
	}
	[self.effect.notifier postNotificationName:FxNotifyAPI_ParameterAddName object:self.effect userInfo:userInfo.copy];
	return YES;
}


- (BOOL)addToggleButtonWithName:(nonnull NSString *)name
					parameterID:(UInt32)parameterID
				   defaultValue:(BOOL)defaultValue
				 parameterFlags:(FxParameterFlags)flags
{
	NSMutableDictionary *userInfo = @{
		kFxParameterProperty_Id: @(parameterID),
		FxNotifyAPI_ParameterKey: @{
			kFxParameterProperty_Type: @(FxParameterType_Toggle),
			kFxParameterProperty_Name: name,
			kFxParameterProperty_Id: @(parameterID),
			kFxParameterProperty_ParentId: _subGroupStack.lastObject,
			kFxParameterProperty_Default: @(defaultValue),
			kFxParameterProperty_Flags: @(flags)
		}.mutableCopy
	}.mutableCopy;
	
	if(![self preprocess:userInfo]) {
		return NO;
	}
	
	NSDictionary *param = userInfo.fxParameter;
	if (![_api addToggleButtonWithName:param.parameterName
						   parameterID:param.parameterID
						  defaultValue:[param.parameterDefaultValue boolValue]
						parameterFlags:FxParameterFlagsFxMask(param.parameterFlags)]) {
		return NO;
	}
	[self.effect.notifier postNotificationName:FxNotifyAPI_ParameterAddName object:self.effect userInfo:userInfo.copy];
	return YES;
}


- (BOOL)startParameterSubGroup:(nonnull NSString *)name
				   parameterID:(UInt32)parameterID
				parameterFlags:(FxParameterFlags)flags
{
	NSMutableDictionary *userInfo = @{
		kFxParameterProperty_Id: @(parameterID),
		FxNotifyAPI_ParameterKey: @{
			kFxParameterProperty_Type: @(FxParameterType_Group),
			kFxParameterProperty_Name: name,
			kFxParameterProperty_Id: @(parameterID),
			kFxParameterProperty_ParentId: _subGroupStack.lastObject,
			kFxParameterProperty_Flags: @(flags)
		}.mutableCopy
	}.mutableCopy;
	
	if(![self preprocess:userInfo]) {
		return NO;
	}
	
	NSDictionary *param = userInfo.fxParameter;
	if (![_api startParameterSubGroup:param.parameterName
						  parameterID:param.parameterID
					   parameterFlags:FxParameterFlagsFxMask(param.parameterFlags)]) {
		return NO;
	}
	[_subGroupStack push:@(parameterID)];
	
	NSDictionary *concreteUserInfo = userInfo.copy;
	[self.effect.notifier postNotificationName:FxNotifyAPI_ParameterAddName object:self.effect userInfo:concreteUserInfo];
	[self.effect.notifier postNotificationName:FxNotifyAPI_ParameterStartGroupName object:self.effect userInfo:concreteUserInfo];
	
	return YES;
}


- (BOOL)endParameterSubGroup
{
	BOOL success = [_api endParameterSubGroup];
	if (success) {
		NSNumber *parameterID = [_subGroupStack pop];
		
		NSDictionary *userInfo = @{
			kFxParameterProperty_Id: parameterID,
		 	FxNotifyAPI_ParameterKey: @{
				kFxParameterProperty_Type: @(FxParameterType_Group),
				kFxParameterProperty_Id: parameterID,
				kFxParameterProperty_ParentId: _subGroupStack.lastObject
			}
		};
		[self.effect.notifier postNotificationName:FxNotifyAPI_ParameterEndGroupName object:self.effect userInfo:userInfo];
	}
	return success;
}

@end
