/*!
	@file       FxGripPushButtonParameter.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripPushButtonParameter
	@abstract   Implements the parameter model for a host push button.
	@discussion Introduced in FxGrip 0.1.0. The class registers a push button through the parameter-creation API. Clicks dispatch through the synthesized click selector for the parameter ID.
*/

#import "FxGripPushButtonParameter.h"
#import "FxGripTileableEffect.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "FxGripParameterUtility.h"

/*!
	@abstract	The parameter model for a host push button.
	@discussion	Introduced in FxGrip 0.1.0. The class registers a push button and dispatches its click through the effect.
*/
@implementation FxGripPushButtonParameter

@synthesize selector = _selector;
@synthesize selectorString = _selectorString;


/*!
	@method		initWithDictionary:effect:
	@abstract	Initializes the parameter and parses the configuration's action selector.
	@param		dictionary	The parameter configuration dictionary.
	@param		effect		The host that owns the parameter. */
-(instancetype _Nullable) initWithDictionary:(NSDictionary*)dictionary effect:(nonnull id<FxGripEffectHost>)effect
{
	self = [super initWithDictionary:dictionary effect:effect];
	if(self) {
		_selectorString = dictionary.parameterSelector;
		_selector = NSSelectorFromString(_selectorString);
	}
	return self;
}

+ (nullable NSString*)parameterTypeString
{
	return kFxParameterType_PushButton;
}

+ (FxParameterType)parameterType
{
	return FxParameterType_PushButton;
}

/*!
	@method		addParameter:toEffect:
	@abstract	Registers the push button with the effect's host.
	@param		parameter	The parameter configuration dictionary.
	@param		effect		The host that receives the parameter.
	@return		YES when the host creates the parameter.
	@discussion	Introduced in FxGrip 0.1.0. The button registers the synthesized click selector for the parameter ID. A configuration selector that does not use the click prefix fails registration. */
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect
{
	// The host registers the synthesized selector encoding the parameter ID; clicks
	// dispatch through -[FxGripTileableEffect parameterClicked:]. The configuration's
	// "selector" is the optional subclass hook and keeps the "click" prefix requirement.
	NSString *declaredSelector = parameter.parameterSelector;
	if (declaredSelector && ![declaredSelector.lowercaseString hasPrefix:kFxParameterProperty_SelectorPrefix]) {
		return NO;
	}
	SEL selector = NSSelectorFromString([FxGripParameterUtility clickSelectorNameForParameter:parameter.parameterID]);
	return [effect.apiManager.paramCreateAPIv5 addPushButtonWithName: parameter.parameterName
														 parameterID: parameter.parameterID
															selector: selector
													  parameterFlags: parameter.parameterFlags];
}


@end
