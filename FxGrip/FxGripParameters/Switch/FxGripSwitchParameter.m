//
//  FxGripParameter.m
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#import "FxGripSwitchParameter.h"
#import "FxTileableEffectBase.h"
#import "NSDictionary+FxTileableEffect.h"
#import "FxGripInterpolatingDictionary.h"

// add NO STATE to flags automatically.

@implementation FxGripSwitchParameter

- (FxParameterType)parameterType
{
	return FxParameterType_Switch;
}

- (BOOL)addParameter
{
	NSNumber *defaultValue = @NO;
	NSNumber *defaultValueNumber = _data.parameterDefaultValue;
	if (defaultValueNumber != nil) {
		defaultValue = defaultValueNumber;
	}
	
	return [self.effect.apiManager.paramCreateAPIv5 addCustomParameterWithName: self.parameterName
																	  parameterID: self.parameterID
																	 defaultValue: [FxGripDictionary dictionaryWithDictionary:@{kCustomAPI_BoolKey: defaultValue}]
																parameterFlags: self.parameterFlags | kFxParameterFlag_CUSTOM_UI | kFxParameterFlag_NOSTATE];
}

@end
