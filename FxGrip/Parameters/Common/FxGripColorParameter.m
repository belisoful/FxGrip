//
//  FxGripParameter.m
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#import "FxGripColorParameter.h"
#import "FxGripTileableEffect+Notifications.h"
#import "FxGripAPINotifications.h"
#import <BEFoundation/NSPriorityNotificationCenter.h>
#import "FxGripTileableEffect.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "NSCoder+FxPlug.h"

/*! The declared configuration with a mutable default, run through the host's parameter-policy
	observers. */
static NSMutableDictionary *FxGripPolicyResolvedConfiguration(NSDictionary *parameter,
															  id<FxGripEffectHost> effect)
{
	NSMutableDictionary *config = parameter.mutableCopy;
	NSDictionary *declared = [parameter valueForKey:kFxParameterProperty_Default];
	if ([declared isKindOfClass:NSDictionary.class]) {
		config[kFxParameterProperty_Default] = [declared mutableCopy];
	}
	[effect.notifier postNotificationName:FxGripTileableEffectParameterPolicyName
								   object:effect
								 userInfo:@{FxGripNotifyAPI_ParameterKey: config}];
	return config;
}

@implementation FxGripColorParameter

// This flag is if the host program should modify the colors for its internal gamut
// This is only YES if the colors don't map in the host.
- (BOOL)flagDontRemapColors {
	return flagDontRemapColors(self.parameterFlags);
}

- (void)setFlagDontRemapColors:(BOOL)dontRemapColors {
	if (flagDontRemapColors(self.parameterFlags) && !dontRemapColors) {
		self.parameterFlags &= ~kFxParameterFlag_DONT_REMAP_COLORS;
		
	} else if (!flagDontRemapColors(self.parameterFlags) && dontRemapColors) {
		self.parameterFlags |= kFxParameterFlag_DONT_REMAP_COLORS;
	}
}

+ (nullable NSString*)parameterTypeString
{
	return kFxParameterType_RGBA;
}

+ (FxParameterType)parameterType
{
	return FxParameterType_RGBA;
}


+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect
{
	// The host's policy observers convert a declared color space to the working gamut.
	NSMutableDictionary *config = FxGripPolicyResolvedConfiguration(parameter, effect);
	double defaultRed = 0.0, defaultGreen = 0.0, defaultBlue = 0.0, defaultAlpha = 1.0;
	NSDictionary<NSString*, NSNumber*> *colorDict = config[kFxParameterProperty_Default];
	if ([colorDict isKindOfClass:NSDictionary.class]) {
		defaultRed = colorDict.parameterRed.doubleValue;
		defaultGreen = colorDict.parameterGreen.doubleValue;
		defaultBlue = colorDict.parameterBlue.doubleValue;
		NSNumber *alpha = colorDict.parameterAlpha;
		if (alpha != nil) {
			defaultAlpha = alpha.doubleValue;
		}
	}

	return [effect.apiManager.paramCreateAPIv5 addColorParameterWithName: parameter.parameterName
															 parameterID: parameter.parameterID
															  defaultRed: defaultRed
															defaultGreen: defaultGreen
															 defaultBlue: defaultBlue
															defaultAlpha: defaultAlpha
														  parameterFlags: parameter.parameterFlags];
}


-(FxGripColor) valueAtTime:(CMTime)renderTime
{
	FxGripColor colorValue = kFxGripBlackOpaque;
	if(![self.effect.apiManager.paramGetAPIv6 getRedValue:&colorValue.r greenValue:&colorValue.g blueValue:&colorValue.b alphaValue:&colorValue.a fromParameter:self.parameterID atTime:renderTime]) {
		_error = [NSError errorWithDomain:FxGripPlugErrorDomain
									 code:kFxGripParameterErrorBool
								 userInfo:@{ NSLocalizedFailureReasonErrorKey : @"Unable to obtain the FxParameterRetrievalAPI_v6" }];
	}
	return colorValue;
}



- (void)setValue:(FxGripColor*_Nullable)color atTime:(CMTime)time
{
	if (!color) {
		return;
	}
	[self setRedValue:color->red greenValue:color->green blueValue:color->blue alphaValue:color->alpha atTime:time];
}

- (void)setRedValue:(double)red greenValue:(double)green blueValue:(double)blue alphaValue:(double)alpha atTime:(CMTime)time
{
	[self.effect.apiManager.paramSetAPIv5 setRedValue:red greenValue:green blueValue:blue alphaValue:alpha toParameter:self.parameterID atTime:time];
}

- (void)setRedValue:(double)red greenValue:(double)green blueValue:(double)blue atTime:(CMTime)time
{
	FxGripColor colorValue = kFxGripBlackOpaque;
	if(![self.effect.apiManager.paramGetAPIv6 getRedValue:&colorValue.red greenValue:&colorValue.green blueValue:&colorValue.blue alphaValue:&colorValue.alpha fromParameter:self.parameterID atTime:time]) {
		NSLog(@"Error: Could not retrieve the alpha for RGBA parameter %d", self.parameterID);
		return;
	}
	[self setRedValue:red greenValue:green blueValue:blue alphaValue:colorValue.alpha atTime:time];
}


- (void)encodeWithCoder:(NSCoder *_Nonnull)coder
{
	[super encodeWithCoder:coder];
	
	if (coder.isFxPluginStateEncoder) {
		FxGripColor color = [self valueAtTime:coder.renderTime];
		[coder encodeBytes:(void*)&color length:sizeof(color) atIndex:self.parameterID];
	} else {
		// encode meta
	}
}


@end
