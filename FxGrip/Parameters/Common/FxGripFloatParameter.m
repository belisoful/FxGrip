/*!
	@file       FxGripFloatParameter.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripFloatParameter
	@abstract   Implements the parameter model for a host floating-point slider.
	@discussion Introduced in FxGrip 0.1.0. The class registers a float slider through the parameter-creation API. It reads and writes the value at a render time and encodes the value into the FxPlug plugin-state coder.
*/

#import "FxGripFloatParameter.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "FxGripTileableEffect.h"
#import "NSCoder+FxPlug.h"

/*!
	@abstract	The parameter model for a host floating-point slider.
	@discussion	Introduced in FxGrip 0.1.0. The class registers a float slider, reads and writes its value at a render time, and encodes the value into the plugin-state coder.
*/
@implementation FxGripFloatParameter

+ (nullable NSString*)parameterTypeString
{
	return kFxParameterType_Float;
}

+ (FxParameterType)parameterType
{
	return FxParameterType_Float;
}


/*!
	@method		addParameter:toEffect:
	@abstract	Registers the float slider with the effect's host.
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
	
	return [effect.apiManager.paramCreateAPIv5 addFloatSliderWithName: parameter.parameterName
														  parameterID: parameter.parameterID
														 defaultValue: defaultValue
														 parameterMin: minimumValue
														 parameterMax: maximumValue
															sliderMin: sliderMinimumValue
															sliderMax: sliderMaximumValue
																delta: defaultDelta
													   parameterFlags: parameter.parameterFlags];
}


/*!
	@method		valueAtTime:
	@abstract	Reads the slider value at a render time.
	@param		renderTime	The time to sample the parameter at.
	@return		The float value, or 0 when FxParameterRetrievalAPI_v6 is unavailable.
	@discussion	Introduced in FxGrip 0.1.0. A retrieval failure sets the parameter's error. */
-(double) valueAtTime:(CMTime)renderTime
{
	double floatValue = 0;
	if(![self.effect.apiManager.paramGetAPIv6 getFloatValue:&floatValue fromParameter:self.parameterID atTime:renderTime]) {
		_error = [NSError errorWithDomain:FxGripPlugErrorDomain
									 code:kFxGripParameterErrorBool
								 userInfo:@{ NSLocalizedFailureReasonErrorKey : @"Unable to obtain the FxParameterRetrievalAPI_v6" }];
	}
	return floatValue;
}


/*!
	@method		setValue:atTime:
	@abstract	Writes the slider value at a time through FxParameterSettingAPI_v5.
	@param		value	The float value to set.
	@param		time	The time to set the value at. */
- (void)setValue:(double)value atTime:(CMTime)time
{
	[self.effect.apiManager.paramSetAPIv5 setFloatValue:value toParameter:self.parameterID atTime:time];
}


/*!
	@method		encodeWithCoder:
	@abstract	Encodes the value at the coder's render time into the plugin-state coder.
	@param		coder	The coder that receives the value.
	@discussion	Introduced in FxGrip 0.1.0. The value encodes only when the coder is an FxPlug plugin-state encoder. */
- (void)encodeWithCoder:(NSCoder *_Nonnull)coder
{
	[super encodeWithCoder:coder];

	if (coder.isFxPluginStateEncoder) {
		[coder encodeDouble:[self valueAtTime:coder.renderTime] atIndex:self.parameterID];
	} else {
		// encode meta
	}
}
@end
