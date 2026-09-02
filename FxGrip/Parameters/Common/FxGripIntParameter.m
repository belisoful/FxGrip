//
//  FxGripParameter.m
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#import "FxGripIntParameter.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "FxGripTileableEffect.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "NSCoder+FxPlug.h"

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


- (void)setValue:(int)value atTime:(CMTime)time
{
	[self.effect.apiManager.paramSetAPIv5 setIntValue:value toParameter:self.parameterID atTime:time];
}


/**
 * This encodes the parameter type into the dictionary pluginState
 */
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
