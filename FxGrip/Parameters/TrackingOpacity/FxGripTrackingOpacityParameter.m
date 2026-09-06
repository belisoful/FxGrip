/*!
	@file       FxGripTrackingOpacityParameter.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripTrackingOpacityParameter
	@abstract   Implements the read-only percent slider the framework drives during analysis.
	@discussion Introduced in FxGrip 0.1.0. The class creation method reads the declared default,
	            adds the disabled and not-animatable flags, and creates a 0-to-1 percent slider on
	            the effect. The value rests at 100% and the analysis driver lowers it to 0%.
*/

#import "FxGripTrackingOpacityParameter.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "FxGripTileableEffect.h"

/*!
	@abstract	The read-only percent slider driven to 0% during an analysis pass.
	@discussion	Introduced in FxGrip 0.1.0. Creation builds a 0-to-1 percent slider with the
				disabled and not-animatable flags set. */
@implementation FxGripTrackingOpacityParameter

+ (nullable NSString*)parameterTypeString
{
	return kFxParameterType_TrackingOpacity;
}

+ (FxParameterType)parameterType
{
	return FxParameterType_TrackingOpacity;
}

/*!
	@method		addParameter:toEffect:
	@abstract	Creates the tracking-opacity percent slider on the effect.
	@return		YES when the host creates the parameter.
	@discussion	Introduced in FxGrip 0.1.0. The slider spans 0 to 1 and rests at 100% unless the
				declaration lowers the default. Creation adds the disabled and not-animatable flags. */
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
