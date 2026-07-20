//
//  FxGripParameter.m
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#import "FxGripPercentParameter.h"
#import "NSDictionary+FxTileableEffect.h"
#import "FxTileableEffectBase.h"

@implementation FxGripPercentParameter

+ (nullable NSString*)parameterTypeString
{
	return kFxParameterType_Percent;
}

+ (FxParameterType)parameterType
{
	return FxParameterType_Percent;
}

+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxTileableEffectBase>)effect
{
	double defaultValue = 0.0, defaultDelta = NAN;
	double minimumValue = 0.0, maximumValue = 1.0;
	double sliderMinimumValue = NAN, sliderMaximumValue = NAN;
	
	NSNumber *value = parameter.parameterDefaultValue;
	if (value != nil) {
		defaultValue = value.doubleValue;
	}
	value = parameter.parameterDelta;
	if (value != nil) {
		defaultDelta = value.doubleValue;
	}
	value = parameter.parameterMinimum_Raw;
	if (value != nil) {
		minimumValue = value.doubleValue;
	}
	value = parameter.parameterMaximum;
	if (value != nil) {
		maximumValue = value.doubleValue;
	}
	value = parameter.parameterSliderMinimum;
	if (value != nil) {
		sliderMinimumValue = value.doubleValue;
	} else {
		sliderMinimumValue = minimumValue;
	}
	value = parameter.parameterSliderMaximum;
	if (value != nil) {
		sliderMaximumValue = value.doubleValue;
	} else {
		sliderMaximumValue = maximumValue;
	}
	
	if (isnan(defaultDelta)) {
		if (fabs(maximumValue - minimumValue - 1.0) < 0.0000001) {
			defaultDelta = 0.01;
		} else {
			defaultDelta = 1.0;
		}
	}
	
	return [effect.apiManager.paramCreateAPIv5 addPercentSliderWithName:parameter.parameterName
															parameterID:parameter.parameterID
														   defaultValue:defaultValue
														   parameterMin:minimumValue
														   parameterMax:maximumValue
															  sliderMin:sliderMinimumValue
															  sliderMax:sliderMaximumValue
																  delta:defaultDelta
														 parameterFlags:parameter.parameterFlags];
}


@end
