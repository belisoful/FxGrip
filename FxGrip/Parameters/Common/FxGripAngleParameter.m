/*!
	@file       FxGripAngleParameter.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripAngleParameter
	@abstract   Implements the parameter model for a host angle slider measured in degrees.
	@discussion Introduced in FxGrip 0.1.0. The class registers an angle slider through the parameter-creation API. It inherits value access and state encoding from FxGripFloatParameter. The range defaults to 0 to 360 degrees.
*/

#import "FxGripAngleParameter.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "FxGripTileableEffect.h"


/*!
	@abstract	The parameter model for a host angle slider measured in degrees.
	@discussion	Introduced in FxGrip 0.1.0. The class registers an angle slider and inherits value access from FxGripFloatParameter.
*/
@implementation FxGripAngleParameter

+ (nullable NSString*)parameterTypeString
{
	return kFxParameterType_Angle;
}

+ (FxParameterType)parameterType
{
	return FxParameterType_Angle;
}


/*!
	@method		addParameter:toEffect:
	@abstract	Registers the angle slider with the effect's host.
	@param		parameter	The parameter configuration dictionary.
	@param		effect		The host that receives the parameter.
	@return		YES when the host creates the parameter.
	@discussion	Introduced in FxGrip 0.1.0. The range defaults to 0 to 360 degrees. */
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
