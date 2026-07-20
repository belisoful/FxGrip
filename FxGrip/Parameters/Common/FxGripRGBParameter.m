//
//  FxGripParameter.m
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#import "FxGripRGBParameter.h"
#import "FxTileableEffectBase.h"
#import "NSDictionary+FxTileableEffect.h"

/*!
 Parameter Specific properties in plist
 alpha  ->  alpha
 alphaParameter => alphaParameter
 
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


+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxTileableEffectBase>)effect
{
	double defaultRed = 0.0, defaultGreen = 0.0, defaultBlue = 0.0;
	NSDictionary<NSString*, NSNumber*> *colorDict = [parameter valueForKey:kFxParameterProperty_Default];
	int	convertGamma = 0;
	if (colorDict) {
		NSNumber *value = colorDict.parameterRed;
		if (value != nil) {
			defaultRed = value.doubleValue;
		}
		value = colorDict.parameterGreen;
		if (value != nil) {
			defaultGreen = value.doubleValue;
		}
		value = colorDict.parameterBlue;
		if (value != nil) {
			defaultBlue = value.doubleValue;
		}
		value = colorDict.parameterColorSpace;
		if (value != nil) {
			if (value.intValue == 1 && effect.isLinearColorParameters) {
				convertGamma = -1;
			} else if (value.intValue == 0 && effect.isGammaColorParameters) {
				convertGamma = 1;
				
			}
		}
	}
	const double gamma = 2.2;
	if (convertGamma > 0) { // apply gamme
		defaultRed = pow( defaultRed, gamma );
		defaultGreen = pow( defaultGreen, gamma );
		defaultBlue = pow( defaultBlue, gamma );
	} else if (convertGamma < 0) { // remove gamme
		defaultRed = pow( defaultRed, 1.0 / gamma );
		defaultGreen = pow( defaultGreen, 1.0 / gamma );
		defaultBlue = pow( defaultBlue, 1.0 / gamma );
	}
	
	return [effect.apiManager.paramCreateAPIv5 addColorParameterWithName: parameter.parameterName
															 parameterID: parameter.parameterID
															  defaultRed: defaultRed
															defaultGreen: defaultGreen
															 defaultBlue: defaultBlue
														  parameterFlags: parameter.parameterFlags];
}


-(FxGripColor) valueAtTime:(CMTime)renderTime
{
	_colorValue.red = _colorValue.green = _colorValue.blue = 0;
	if (self.alphaParameter) {
		if(![self.effect.apiManager.paramGetAPIv6 getFloatValue:&_colorValue.alpha fromParameter:self.alphaParameter atTime:renderTime]) {
			_error = [NSError errorWithDomain:FxPlugErrorDomain
										 code:kFxGripParameterErrorBool
								  userInfo:@{ NSLocalizedFailureReasonErrorKey : @"Unable to obtain the FxParameterRetrievalAPI_v6" }];
		}
	}
	if(![self.effect.apiManager.paramGetAPIv6 getRedValue:&_colorValue.red greenValue:&_colorValue.green blueValue:&_colorValue.blue  fromParameter:self.parameterID atTime:renderTime]) {
		_error = [NSError errorWithDomain:FxPlugErrorDomain
									 code:kFxGripParameterErrorBool
								 userInfo:@{ NSLocalizedFailureReasonErrorKey : @"Unable to obtain the FxParameterRetrievalAPI_v6" }];
	}
	return _colorValue;
}


- (void)setValue:(FxGripColor*_Nullable)color atTime:(CMTime)time
{
	if (!color) {
		return;
	}
	[self setRedValue:color->red greenValue:color->green blueValue:color->blue atTime:time];
}


- (void)setRGBAValue:(FxGripColor*_Nullable)color atTime:(CMTime)time
{
	if (!color) {
		return;
	}
	[self setRedValue:color->red greenValue:color->green blueValue:color->blue alphaValue:color->alpha atTime:time];
}


- (void)setRedValue:(double)red greenValue:(double)green blueValue:(double)blue alphaValue:(double)alpha atTime:(CMTime)time
{
	self.alpha = alpha;
	if (self.alphaParameter) {
		if(![self.effect.apiManager.paramGetAPIv6 getFloatValue:&_colorValue.alpha fromParameter:self.alphaParameter atTime:time]) {
			_error = [NSError errorWithDomain:FxPlugErrorDomain
										 code:kFxGripParameterErrorBool
								  userInfo:@{ NSLocalizedFailureReasonErrorKey : @"Unable to obtain the FxParameterRetrievalAPI_v6" }];
		}
	}
	[self setRedValue:red greenValue:green blueValue:blue atTime:time];
}


- (void)setRedValue:(double)red greenValue:(double)green blueValue:(double)blue atTime:(CMTime)time
{
	[self.effect.apiManager.paramSetAPIv5 setRedValue:red greenValue:green blueValue:blue toParameter:self.parameterID atTime:time];
}


- (BOOL)validate
{
	if (self.alphaParameter) {
		
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
