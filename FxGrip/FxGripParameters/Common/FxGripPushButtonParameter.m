//
//  FxGripParameter.m
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#import "FxGripPushButtonParameter.h"
#import "FxTileableEffectBase.h"
#import "NSDictionary+FxTileableEffect.h"

@implementation FxGripPushButtonParameter

@synthesize selector = _selector;
@synthesize selectorString = _selectorString;


-(instancetype _Nullable) initWithDictionary:(NSDictionary*)dictionary
{
	self = [super init];
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

+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxTileableEffectBase>)effect
{
	BOOL success = NO;
	NSString *selectorString = parameter.parameterSelector;
	SEL selector = NSSelectorFromString(selectorString);
	if (selector == nil) {
		//errorReason = @"Missing Selector.";
		success = NO;
	} else if ([selectorString.lowercaseString hasPrefix:kFxParameterProperty_SelectorPrefix]) {
		success = [effect.apiManager.paramCreateAPIv5 addPushButtonWithName: parameter.parameterName
																parameterID: parameter.parameterID
																   selector: selector  //selector needs to use FxCustomParameterActionAPI_v4 to access parameters
															 parameterFlags: parameter.parameterFlags];
	} else {
		//errorReason = @"Incorrrect selector prefix.  Must start with 'click' for security reasons";
		success = NO;
	}
	return success;
}


@end
