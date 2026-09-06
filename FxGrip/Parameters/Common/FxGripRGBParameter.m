/*!
	@file       FxGripRGBParameter.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripRGBParameter
	@abstract   Implements the parameter model for a host RGB color well with a separate alpha parameter.
	@discussion Introduced in FxGrip 0.1.0. The class registers an RGB color parameter through the parameter-creation API. The alpha component comes from a separately bound float or percent parameter when one is set.
*/

#import "FxGripRGBParameter.h"
#import "FxGripTileableEffect+Notifications.h"
#import "FxGripAPINotifications.h"
#import <BEFoundation/NSPriorityNotificationCenter.h>
#import "FxGripTileableEffect.h"
#import "NSDictionary+FxGripTileableEffect.h"

/*!
 Parameter Specific properties in plist
 alpha  ->  alpha
 alphaParameter => alphaParameter
 
 */
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
	@abstract	The parameter model for a host RGB color well.
	@discussion	Introduced in FxGrip 0.1.0. The class registers an RGB color parameter, caches the color value, and reads its alpha from a separately bound parameter.
*/
@implementation FxGripRGBParameter
{
	@protected
	FxGripColor _colorValue;
}


- (double)alpha
{
	return _colorValue.alpha;
}


- (void)setAlpha:(double)alpha
{
	_colorValue.alpha = alpha;
}

+ (nullable NSString*)parameterTypeString
{
	return kFxParameterType_RGB;
}

+ (FxParameterType)parameterType
{
	return FxParameterType_RGB;
}


/*!
	@method		addParameter:toEffect:
	@abstract	Registers the RGB color parameter with the effect's host.
	@param		parameter	The parameter configuration dictionary.
	@param		effect		The host that receives the parameter.
	@return		YES when the host creates the parameter.
	@discussion	Introduced in FxGrip 0.1.0. The default red, green, and blue are 0.0. The policy observers resolve the declared default color to the working gamut before registration. */
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect
{
	// The host's policy observers convert a declared color space to the working gamut.
	NSMutableDictionary *config = FxGripPolicyResolvedConfiguration(parameter, effect);
	double defaultRed = 0.0, defaultGreen = 0.0, defaultBlue = 0.0;
	NSDictionary<NSString*, NSNumber*> *colorDict = config[kFxParameterProperty_Default];
	if ([colorDict isKindOfClass:NSDictionary.class]) {
		defaultRed = colorDict.parameterRed.doubleValue;
		defaultGreen = colorDict.parameterGreen.doubleValue;
		defaultBlue = colorDict.parameterBlue.doubleValue;
	}

	return [effect.apiManager.paramCreateAPIv5 addColorParameterWithName: parameter.parameterName
															 parameterID: parameter.parameterID
															  defaultRed: defaultRed
															defaultGreen: defaultGreen
															 defaultBlue: defaultBlue
														  parameterFlags: parameter.parameterFlags];
}


/*!
	@method		valueAtTime:
	@abstract	Reads the color at a render time.
	@param		renderTime	The time to sample the parameter at.
	@return		The color, with alpha read from the bound alpha parameter when one is set.
	@discussion	Introduced in FxGrip 0.1.0. A retrieval failure sets the parameter's error. */
-(FxGripColor) valueAtTime:(CMTime)renderTime
{
	_colorValue.red = _colorValue.green = _colorValue.blue = 0;
	if (self.alphaParameter) {
		if(![self.effect.apiManager.paramGetAPIv6 getFloatValue:&_colorValue.alpha fromParameter:self.alphaParameter atTime:renderTime]) {
			_error = [NSError errorWithDomain:FxGripPlugErrorDomain
										 code:kFxGripParameterErrorBool
								  userInfo:@{ NSLocalizedFailureReasonErrorKey : @"Unable to obtain the FxParameterRetrievalAPI_v6" }];
		}
	}
	if(![self.effect.apiManager.paramGetAPIv6 getRedValue:&_colorValue.red greenValue:&_colorValue.green blueValue:&_colorValue.blue  fromParameter:self.parameterID atTime:renderTime]) {
		_error = [NSError errorWithDomain:FxGripPlugErrorDomain
									 code:kFxGripParameterErrorBool
								 userInfo:@{ NSLocalizedFailureReasonErrorKey : @"Unable to obtain the FxParameterRetrievalAPI_v6" }];
	}
	return _colorValue;
}


/*!
	@method		setValue:atTime:
	@abstract	Writes the red, green, and blue components at a time.
	@param		color	The color to set. A NULL value performs no write.
	@param		time	The time to set the color at. */
- (void)setValue:(FxGripColor*_Nullable)color atTime:(CMTime)time
{
	if (!color) {
		return;
	}
	[self setRedValue:color->red greenValue:color->green blueValue:color->blue atTime:time];
}


/*!
	@method		setRGBAValue:atTime:
	@abstract	Writes the red, green, and blue components at a time and caches the alpha.
	@param		color	The color to set. A NULL value performs no write.
	@param		time	The time to set the color at. */
- (void)setRGBAValue:(FxGripColor*_Nullable)color atTime:(CMTime)time
{
	if (!color) {
		return;
	}
	[self setRedValue:color->red greenValue:color->green blueValue:color->blue alphaValue:color->alpha atTime:time];
}


/*!
	@method		setRedValue:greenValue:blueValue:alphaValue:atTime:
	@abstract	Caches the alpha and writes the red, green, and blue components at a time.
	@discussion	Introduced in FxGrip 0.1.0. When an alpha parameter is bound the cached alpha is refreshed from it. */
- (void)setRedValue:(double)red greenValue:(double)green blueValue:(double)blue alphaValue:(double)alpha atTime:(CMTime)time
{
	self.alpha = alpha;
	if (self.alphaParameter) {
		if(![self.effect.apiManager.paramGetAPIv6 getFloatValue:&_colorValue.alpha fromParameter:self.alphaParameter atTime:time]) {
			_error = [NSError errorWithDomain:FxGripPlugErrorDomain
										 code:kFxGripParameterErrorBool
								  userInfo:@{ NSLocalizedFailureReasonErrorKey : @"Unable to obtain the FxParameterRetrievalAPI_v6" }];
		}
	}
	[self setRedValue:red greenValue:green blueValue:blue atTime:time];
}


/*! @abstract Writes the red, green, and blue components at a time through FxParameterSettingAPI_v5. */
- (void)setRedValue:(double)red greenValue:(double)green blueValue:(double)blue atTime:(CMTime)time
{
	[self.effect.apiManager.paramSetAPIv5 setRedValue:red greenValue:green blueValue:blue toParameter:self.parameterID atTime:time];
}


/*!
	@method		validate
	@abstract	Checks that the bound alpha parameter exists and is a float or percent.
	@return		YES when no alpha parameter is bound, or the bound parameter exists and is a float or percent; NO otherwise. */
- (BOOL)validate
{
	if (self.alphaParameter
		&& [self.effect respondsToSelector:@selector(objectAtIndexedSubscript:)]) {
		if (!self.effect[self.alphaParameter]) {
			return NO;
		}
		FxParameterType type = self.effect[self.alphaParameter].parameterType;
		if (type != FxParameterType_Float && type != FxParameterType_Percent) {
			return NO;
		}
	}
	return YES;
}


@end
