//
//  FxGripTrackingOpacityParameter.m
//  FxGrip
//

#import "FxGripTrackingOpacityParameter.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "FxGripTileableEffect.h"

@implementation FxGripTrackingOpacityParameter

+ (nullable NSString*)parameterTypeString
{
	return kFxParameterType_TrackingOpacity;
}

+ (FxParameterType)parameterType
{
	return FxParameterType_TrackingOpacity;
}

+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect
{
	// The slider rests at 100% and spans 0…1. A declared default may lower the resting value.
	double defaultValue = kFxGripTrackingOpacityResting;
	NSNumber *value = parameter.parameterDefaultValue;
	if (value != nil) {
		defaultValue = value.doubleValue;
	}

	// The value is framework driven: disable inspector editing and keyframing.
	FxParameterFlags flags = parameter.parameterFlags
		| kFxParameterFlag_DISABLED
		| kFxParameterFlag_NOT_ANIMATABLE;

	return [effect.apiManager.paramCreateAPIv5 addPercentSliderWithName:parameter.parameterName
															parameterID:parameter.parameterID
														   defaultValue:defaultValue
														   parameterMin:0.0
														   parameterMax:1.0
															  sliderMin:0.0
															  sliderMax:1.0
																  delta:0.01
														 parameterFlags:flags];
}

@end
