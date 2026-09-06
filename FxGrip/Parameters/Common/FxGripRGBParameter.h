/*!
	@file       FxGripRGBParameter.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripRGBParameter
	@abstract   The parameter model for a host RGB color well with a separate alpha parameter.
	@discussion Introduced in FxGrip 0.1.0. The class registers an RGB color parameter that carries no alpha component. An optional alphaParameter binds a separate float or percent parameter as the alpha source. It derives from FxGripColorParameter.
*/

#ifndef FxGripRGBParameter_h
#define FxGripRGBParameter_h

#import "FxGripColorParameter.h"



/*!
	@class		FxGripRGBParameter
	@abstract	The parameter model for a host RGB color well.
	@discussion	Introduced in FxGrip 0.1.0. The class registers an RGB color parameter and reads its alpha from a separately bound parameter.
*/
@interface FxGripRGBParameter : FxGripColorParameter

/*! @abstract The current alpha component of the cached color. */
@property (readwrite, nonatomic) double alpha;
/*! @abstract The parameter ID of the bound alpha source, or 0 when none is bound. */
@property (assign) FxParameterId alphaParameter;

/*! @abstract The FxPlug type key string this class registers. */
+ (nullable NSString*)parameterTypeString;
/*! @abstract The FxParameterType this class registers. */
+ (FxParameterType)parameterType;
/*!
	@method		addParameter:toEffect:
	@abstract	Registers the RGB color parameter with the effect's host.
	@param		parameter	The parameter configuration dictionary.
	@param		effect		The host that receives the parameter.
	@return		YES when the host creates the parameter.
	@discussion	Introduced in FxGrip 0.1.0. The host's parameter-policy observers convert a declared color space to the working gamut. */
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect;

/*!
	@method		valueAtTime:
	@abstract	Reads the color at a render time.
	@param		renderTime	The time to sample the parameter at.
	@return		The color, with alpha read from the bound alpha parameter when one is set. */
- (FxGripColor)valueAtTime:(CMTime)renderTime;
/*!
	@method		setValue:atTime:
	@abstract	Writes the red, green, and blue components at a time.
	@param		color	The color to set. A NULL value performs no write.
	@param		time	The time to set the color at. */
- (void)setValue:(FxGripColor*_Nullable)color atTime:(CMTime)time;
/*! @abstract Writes the red, green, and blue components at a time and caches the alpha. */
- (void)setRedValue:(double)red greenValue:(double)green blueValue:(double)blue alphaValue:(double)alpha atTime:(CMTime)time;
/*! @abstract Writes the red, green, and blue components at a time. */
- (void)setRedValue:(double)red greenValue:(double)green blueValue:(double)blue atTime:(CMTime)time;

/*!
	@method		validate
	@abstract	Checks that the bound alpha parameter exists and is a float or percent.
	@return		YES when no alpha parameter is bound or the bound parameter is a valid alpha source. */
- (BOOL)validate;

@end


#endif
