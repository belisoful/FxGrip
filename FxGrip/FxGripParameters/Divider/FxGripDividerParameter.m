//
//  FxGripParameter.m
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#import "FxGripDividerParameter.h"
#import "FxTileableEffectBase.h"
#import "NSDictionary+FxTileableEffect.h"
//#import "FxGripInterpolatingDictionary.h"
#import "FxGripDividerData.h"

// add NO STATE to flags automatically.

@implementation FxGripDividerParameter

- (FxParameterType)parameterType
{
	return FxParameterType_Divider;
}

- (BOOL)addParameter
{
	id defaultValue = _data.parameterDefaultValue;
		  if (defaultValue == nil || ![defaultValue isKindOfClass:[NSDictionary class]])
			  defaultValue = @{};
		  
	return [self.effect.apiManager.paramCreateAPIv5 addCustomParameterWithName:@""
												   parameterID: self.parameterID
												  defaultValue:[FxGripDividerData dataWithDictionary:defaultValue]
																parameterFlags: self.parameterFlags | kFxParameterFlag_CUSTOM_UI | kFxParameterFlag_NOT_ANIMATABLE | kFxParameterFlag_USE_FULL_VIEW_WIDTH | kFxParameterFlag_NOSTATE];
}

@end
