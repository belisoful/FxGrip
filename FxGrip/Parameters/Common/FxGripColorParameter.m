/*!
	@file       FxGripColorParameter.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripColorParameter
	@abstract   Implements the parameter model for a host RGBA color well.
	@discussion Introduced in FxGrip 0.1.0. The class registers a color parameter through the parameter-creation API and reads and writes its components at a render time. The host's parameter-policy observers resolve the declared default color before registration.
*/

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

/*!
	@abstract	The parameter model for a host RGBA color well.
	@discussion	Introduced in FxGrip 0.1.0. The class registers a color parameter, reads and writes its red, green, blue, and alpha components at a render time, and encodes the color into the plugin-state coder.
*/
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


/*!
	@method		addParameter:toEffect:
	@abstract	Registers the color parameter with the effect's host.
	@param		parameter	The parameter configuration dictionary.
	@param		effect		The host that receives the parameter.
	@return		YES when the host creates the parameter.
	@discussion	Introduced in FxGrip 0.1.0. The default red, green, and blue are 0.0, and the default alpha is 1.0. The policy observers resolve the declared default color to the working gamut before registration. */
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


/*!
	@method		valueAtTime:
	@abstract	Reads the color at a render time.
	@param		renderTime	The time to sample the parameter at.
	@return		The color, or opaque black when FxParameterRetrievalAPI_v6 is unavailable.
	@discussion	Introduced in FxGrip 0.1.0. A retrieval failure sets the parameter's error. */
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



/*!
	@method		setValue:atTime:
	@abstract	Writes the color at a time.
	@param		color	The color to set. A NULL value performs no write.
	@param		time	The time to set the color at. */
- (void)setValue:(FxGripColor*_Nullable)color atTime:(CMTime)time
{
	if (!color) {
		return;
	}
	[self setRedValue:color->red greenValue:color->green blueValue:color->blue alphaValue:color->alpha atTime:time];
}

/*! @abstract Writes the red, green, blue, and alpha components at a time through FxParameterSettingAPI_v5. */
- (void)setRedValue:(double)red greenValue:(double)green blueValue:(double)blue alphaValue:(double)alpha atTime:(CMTime)time
{
	[self.effect.apiManager.paramSetAPIv5 setRedValue:red greenValue:green blueValue:blue alphaValue:alpha toParameter:self.parameterID atTime:time];
}

/*!
	@method		setRedValue:greenValue:blueValue:atTime:
	@abstract	Writes the red, green, and blue components at a time and preserves the current alpha.
	@discussion	Introduced in FxGrip 0.1.0. The method reads the current alpha before the write. */
- (void)setRedValue:(double)red greenValue:(double)green blueValue:(double)blue atTime:(CMTime)time
{
	FxGripColor colorValue = kFxGripBlackOpaque;
	if(![self.effect.apiManager.paramGetAPIv6 getRedValue:&colorValue.red greenValue:&colorValue.green blueValue:&colorValue.blue alphaValue:&colorValue.alpha fromParameter:self.parameterID atTime:time]) {
		NSLog(@"Error: Could not retrieve the alpha for RGBA parameter %d", self.parameterID);
		return;
	}
	[self setRedValue:red greenValue:green blueValue:blue alphaValue:colorValue.alpha atTime:time];
}


/*!
	@method		encodeWithCoder:
	@abstract	Encodes the color at the coder's render time into the plugin-state coder.
	@param		coder	The coder that receives the color.
	@discussion	Introduced in FxGrip 0.1.0. The color encodes only when the coder is an FxPlug plugin-state encoder. */
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
