/*!
	@file       FxGripIntParameter.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripIntParameter
	@abstract   Implements the parameter model for a host integer slider.
	@discussion Introduced in FxGrip 0.1.0. The class registers an integer slider through the parameter-creation API. It reads and writes the value at a render time and encodes the value into the FxPlug plugin-state coder.
*/

#import "FxGripIntParameter.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "FxGripTileableEffect.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "NSCoder+FxPlug.h"

/*!
	@abstract	The parameter model for a host integer slider.
	@discussion	Introduced in FxGrip 0.1.0. The class registers an integer slider, reads and writes its value at a render time, and encodes the value into the plugin-state coder.
*/
@implementation FxGripIntParameter

- (BOOL)flagIgnoreMinMax {
	return flagIgnoreMinMax(self.parameterFlags);
}

- (void)setFlagIgnoreMinMax:(BOOL)ignoreMinMax {
	if (flagIgnoreMinMax(self.parameterFlags) && !ignoreMinMax) {
		self.parameterFlags &= ~kFxParameterFlag_IGNORE_MINMAX;
		
	} else if (!flagIgnoreMinMax(self.parameterFlags) && ignoreMinMax) {
		self.parameterFlags |= kFxParameterFlag_IGNORE_MINMAX;
	}
}


+ (nullable NSString*)parameterTypeString
{
	return kFxParameterType_Integer;
}

+ (FxParameterType)parameterType
{
	return FxParameterType_Int;
}


/*!
	@method		addParameter:toEffect:
	@abstract	Registers the integer slider with the effect's host.
	@param		parameter	The parameter configuration dictionary.
	@param		effect		The host that receives the parameter.
	@return		YES when the host creates the parameter.
	@discussion	Introduced in FxGrip 0.1.0. The parameter range defaults to 0 to 100, the slider range defaults to the parameter range, and the delta defaults to 1. */
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect
{
	int defaultValue = 0, defaultDelta = 1;
	int minimumValue = 0, maximumValue = 100;
	
	int sliderMinimumValue = 0, sliderMaximumValue = 0;
	
	NSNumber *value = parameter.parameterDefaultValue;
	if (value != nil) {
		defaultValue = value.intValue;
	}
	
	value = parameter.parameterDelta;
	if (value != nil) {
		defaultDelta = value.intValue;
	}
	value = parameter.parameterMinimum_Raw;
	if (value != nil) {
		minimumValue = value.intValue;
	}
	value = parameter.parameterMaximum;
	if (value != nil) {
		maximumValue = value.intValue;
	}
	
	value = parameter.parameterSliderMinimum;
	if (value != nil) {
		sliderMinimumValue = value.intValue;
	} else {
		sliderMinimumValue = minimumValue;
	}
	
	value = parameter.parameterSliderMaximum;
	if (value != nil) {
		sliderMaximumValue = value.intValue;
	} else {
		sliderMaximumValue = maximumValue;
	}
	
	
	return [effect.apiManager.paramCreateAPIv5 addIntSliderWithName: parameter.parameterName
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
	@abstract	Reads the integer value at a render time.
	@param		renderTime	The time to sample the parameter at.
	@return		The integer value, or 0 when FxParameterRetrievalAPI_v6 is unavailable.
	@discussion	Introduced in FxGrip 0.1.0. A retrieval failure sets the parameter's error. */
- (int)valueAtTime:(CMTime)renderTime
{
	int intValue = 0;
	if(![self.effect.apiManager.paramGetAPIv6 getIntValue:&intValue fromParameter:self.parameterID atTime:renderTime]) {
		_error = [NSError errorWithDomain:FxGripPlugErrorDomain
									 code:kFxGripParameterErrorBool
								 userInfo:@{ NSLocalizedFailureReasonErrorKey : @"Unable to obtain the FxParameterRetrievalAPI_v6" }];
	}
	return intValue;
}


/*!
	@method		setValue:atTime:
	@abstract	Writes the integer value at a time through FxParameterSettingAPI_v5.
	@param		value	The integer value to set.
	@param		time	The time to set the value at. */
- (void)setValue:(int)value atTime:(CMTime)time
{
	[self.effect.apiManager.paramSetAPIv5 setIntValue:value toParameter:self.parameterID atTime:time];
}


/*!
	@method		encodeWithCoder:
	@abstract	Encodes the integer value at the coder's render time into the plugin-state coder.
	@param		coder	The coder that receives the value.
	@discussion	Introduced in FxGrip 0.1.0. The value encodes only when the coder is an FxPlug plugin-state encoder. */
- (void)encodeWithCoder:(NSCoder *_Nonnull)coder
{
	[super encodeWithCoder:coder];
	if (coder.isFxPluginStateEncoder) {
		[coder encodeInt:[self valueAtTime:coder.renderTime] atIndex:self.parameterID];
	} else {
		// encode meta
	}
}

@end
