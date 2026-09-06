/*!
	@file       FxGripPercentParameter.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripPercentParameter
	@abstract   Implements the parameter model for a host percent slider.
	@discussion Introduced in FxGrip 0.1.0. The class registers a percent slider through the parameter-creation API. It inherits value access and state encoding from FxGripFloatParameter. The range defaults to 0.0 to 1.0.
*/

#import "FxGripPercentParameter.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "FxGripTileableEffect.h"

/*!
	@abstract	The parameter model for a host percent slider.
	@discussion	Introduced in FxGrip 0.1.0. The class registers a percent slider and inherits value access from FxGripFloatParameter.
*/
@implementation FxGripPercentParameter

+ (nullable NSString*)parameterTypeString
{
	return kFxParameterType_Percent;
}

+ (FxParameterType)parameterType
{
	return FxParameterType_Percent;
}

/*!
	@method		addParameter:toEffect:
	@abstract	Registers the percent slider with the effect's host.
	@param		parameter	The parameter configuration dictionary.
	@param		effect		The host that receives the parameter.
	@return		YES when the host creates the parameter.
	@discussion	Introduced in FxGrip 0.1.0. The parameter range defaults to 0.0 to 1.0, and the slider range defaults to the parameter range. The delta defaults to 0.01 for a unit-width range and 1.0 otherwise. */
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect
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
