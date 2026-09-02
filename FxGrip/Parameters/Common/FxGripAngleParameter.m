//
//  FxGripParameter.m
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#import "FxGripAngleParameter.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "FxGripTileableEffect.h"


@implementation FxGripAngleParameter

+ (nullable NSString*)parameterTypeString
{
	return kFxParameterType_Angle;
}

+ (FxParameterType)parameterType
{
	return FxParameterType_Angle;
}


+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect
{
	double defaultValue = 0.0, minimumValue = 0, maximumValue = 360;
	NSNumber *value = parameter.parameterDefaultValue;
	if (value != nil) {
		defaultValue = value.doubleValue;
	}
	value = parameter.parameterMinimum_Raw;
	if (value != nil) {
		minimumValue = value.doubleValue;
	}
	value = parameter.parameterMaximum;
	if (value != nil) {
		maximumValue = value.doubleValue;
	}
	return [effect.apiManager.paramCreateAPIv5 addAngleSliderWithName: parameter.parameterName
														  parameterID: parameter.parameterID
													   defaultDegrees: defaultValue
												  parameterMinDegrees: minimumValue
												  parameterMaxDegrees: maximumValue
													   parameterFlags: parameter.parameterFlags];
}

@end
