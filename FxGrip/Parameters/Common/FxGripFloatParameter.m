//
//  FxGripParameter.m
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#import "FxGripFloatParameter.h"
#import "NSDictionary+FxTileableEffect.h"
#import "FxTileableEffectBase.h"
#import "NSCoder+FxPlug.h"

@implementation FxGripFloatParameter

+ (nullable NSString*)parameterTypeString
{
	return kFxParameterType_Float;
}

+ (FxParameterType)parameterType
{
	return FxParameterType_Float;
}


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


- (void)setValue:(double)value atTime:(CMTime)time
{
	[self.effect.apiManager.paramSetAPIv5 setFloatValue:value toParameter:self.parameterID atTime:time];
}


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
