/*!
	@file       FxGripSwitchParameter.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripSwitchParameter
	@abstract   Implements the boolean switch view and its custom parameter.
	@discussion Introduced in FxGrip 0.1.0. The view sets its state from the parameter's
	            FxGripDictionary value and writes the toggled boolean back through an out-of-band
	            access context. The parameter creates the custom control seeded from the declared
	            boolean default.
*/

#import "FxGripSwitchParameter.h"
#import "FxGripTileableEffect.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "FxGripDictionary.h"
#import "FxGripOOBParameterAccess.h"
#import "FxGrip_ARC.h"

/*!
	@abstract	The NSSwitch backing the switch parameter.
	@discussion	Introduced in FxGrip 0.1.0. The view reads its state from the parameter value and
				writes the toggled boolean back through an out-of-band access context. */
@implementation FxGripSwitchView

/*!
	@method		updateFromCustomData:
	@abstract	Sets the switch state from the parameter's FxGripDictionary value.
	@param		value	The parameter value; ignored when it is not an FxGripDictionary. */
- (void)updateFromCustomData:(NSObject<NSSecureCoding,NSCopying> * _Nullable)value
{
	if (![value isKindOfClass:FxGripDictionary.class]) {
		return;
	}
	BOOL flag = NO;
	if ([(FxGripDictionary*)value getBoolValue:&flag]) {
		self.state = flag ? NSControlStateValueOn : NSControlStateValueOff;
	}
}

/*!
	@method		fxSwitchToggled:
	@abstract	Writes the switch's boolean state back into the parameter value.
	@discussion	Introduced in FxGrip 0.1.0. The action runs outside a host call, so the read and
				write go through an out-of-band access context at the current time. */
// The action runs outside a host call, so the write goes through an out-of-band access context.
- (void)fxSwitchToggled:(nullable id)sender
{
	FxGripTileableEffect *effect = (FxGripTileableEffect*)self.parameterEffect;
	if (effect == nil) {
		return;
	}
	FxGripOOBParameterAccess *access = [FxGripOOBParameterAccess access:effect];
	CMTime time = access.currentTime;

	NSObject<NSSecureCoding, NSCopying> *value = nil;
	[effect.apiManager.paramGetAPIv6 getCustomParameterValue:&value
											   fromParameter:self.parameterID
													  atTime:time];
	FxGripDictionary *dictionary = [value isKindOfClass:FxGripDictionary.class]
		? (FxGripDictionary*)value
		: [FxGripDictionary dictionaryWithDictionary:@{}];
	dictionary.locked = NO;
	[dictionary setBoolValue:self.state == NSControlStateValueOn];
	[effect.apiManager.paramSetAPIv5 setCustomParameterValue:dictionary
												 toParameter:self.parameterID
													  atTime:time];
}

@end


/*!
	@abstract	The boolean custom parameter presented as a switch.
	@discussion	Introduced in FxGrip 0.1.0. Creation stores the boolean under the default bool key
				in an FxGripDictionary and adds the custom-UI and no-state flags. */
@implementation FxGripSwitchParameter

/*! @abstract The registry type string for the switch parameter. */
+ (nullable NSString*)parameterTypeString
{
	return kFxParameterType_Switch;
}

+ (FxParameterType)parameterType
{
	return FxParameterType_Switch;
}

/*! @abstract The value classes the custom parameter decodes: FxGripDictionary and its element classes. */
+ (NSSet<Class> *_Nullable)customValueClasses
{
	NSMutableSet *classes = [NSMutableSet setWithObject:FxGripDictionary.class];
	[classes unionSet:FxGripDictionary.classesForParameter.set];
	return classes;
}

/*!
	@method		addParameter:toEffect:
	@abstract	Creates the switch custom parameter on the effect.
	@return		YES when the host creates the parameter.
	@discussion	Introduced in FxGrip 0.1.0. The declared default sets the initial boolean. Creation
				adds the custom-UI and no-state flags. */
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect
{
	NSNumber *defaultValue = @NO;
	NSNumber *declared = parameter.parameterDefaultValue;
	if ([declared isKindOfClass:NSNumber.class]) {
		defaultValue = declared;
	}

	return [effect.apiManager.paramCreateAPIv5
		addCustomParameterWithName: parameter.parameterName
					   parameterID: parameter.parameterID
					  defaultValue: [FxGripDictionary dictionaryWithDictionary:@{kCustomAPI_BoolKey: defaultValue}]
					parameterFlags: parameter.parameterFlags | kFxParameterFlag_CUSTOM_UI | kFxParameterFlag_NOSTATE];
}

/*!
	@method		newParameterView
	@abstract	Creates the switch view wired to this parameter and seeds its state.
	@return		A new FxGripSwitchView.
	@discussion	Introduced in FxGrip 0.1.0. The view targets its own toggle action and seeds its
				on state from the declared boolean default. */
- (NSView *_Nullable)newParameterView
{
	FxGripSwitchView *switchView = [FxGripSwitchView.alloc initWithFrame:NSMakeRect(0, 0, 80, 24)];
	switchView.controlSize = NSControlSizeMini;
	switchView.parameterEffect = self.effect;
	switchView.parameterID = self.parameterID;
	switchView.target = switchView;
	switchView.action = @selector(fxSwitchToggled:);

	NSNumber *declared = _data.parameterDefaultValue;
	if ([declared isKindOfClass:NSNumber.class] && declared.boolValue) {
		switchView.state = NSControlStateValueOn;
	}
	return switchView;
}

@end
