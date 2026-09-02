//
//  FxGripParameter.m
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#import "FxGripPushButtonParameter.h"
#import "FxGripTileableEffect.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "FxGripParameterUtility.h"

@implementation FxGripPushButtonParameter

@synthesize selector = _selector;
@synthesize selectorString = _selectorString;


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
