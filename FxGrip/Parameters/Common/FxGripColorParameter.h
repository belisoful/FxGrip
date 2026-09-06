/*!
	@file       FxGripColorParameter.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripColorParameter
	@abstract   The parameter model for a host RGBA color well.
	@discussion Introduced in FxGrip 0.1.0. The class registers a color parameter with red, green, blue, and alpha components. It reads and writes the color at a render time. It conforms to FxGripStateParameter and encodes the color into the FxPlug plugin-state coder. FxGripRGBParameter derives from it for the alpha-less RGB variant.
*/

#ifndef FxGripColorParameter_h
#define FxGripColorParameter_h

#import "FxGripParameter.h"


/*!
	@class		FxGripColorParameter
	@abstract	The parameter model for a host RGBA color well.
	@discussion	Introduced in FxGrip 0.1.0. The class maps the declared configuration to a host color parameter and exposes its red, green, blue, and alpha components at a render time.
*/
@interface FxGripColorParameter : FxGripParameter <FxGripStateParameter>

/*!
	@property	flagDontRemapColors
	@abstract	The DONT_REMAP_COLORS parameter flag as a boolean.
	@discussion	Introduced in FxGrip 0.1.0. A YES value tells the host to leave the color unmapped to its internal gamut. */
@property (readwrite, nonatomic) BOOL flagDontRemapColors;

/*! @abstract The FxPlug type key string this class registers. */
+ (nullable NSString*)parameterTypeString;
/*! @abstract The FxParameterType this class registers. */
+ (FxParameterType)parameterType;
/*!
	@method		addParameter:toEffect:
	@abstract	Registers the color parameter with the effect's host.
	@param		parameter	The parameter configuration dictionary.
	@param		effect		The host that receives the parameter.
	@return		YES when the host creates the parameter.
	@discussion	Introduced in FxGrip 0.1.0. The default alpha is 1.0. The host's parameter-policy observers convert a declared color space to the working gamut. */
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect;

/*!
	@method		valueAtTime:
	@abstract	Reads the color at a render time.
	@param		renderTime	The time to sample the parameter at.
	@return		The color, or opaque black when the retrieval API is unavailable. */
- (FxGripColor)valueAtTime:(CMTime)renderTime;
/*!
	@method		setValue:atTime:
	@abstract	Writes the color at a time.
	@param		color	The color to set. A NULL value performs no write.
	@param		time	The time to set the color at. */
- (void)setValue:(FxGripColor*_Nullable)color atTime:(CMTime)time;
/*!
	@method		setRedValue:greenValue:blueValue:alphaValue:atTime:
	@abstract	Writes the red, green, blue, and alpha components at a time. */
- (void)setRedValue:(double)red greenValue:(double)green blueValue:(double)blue alphaValue:(double)alpha atTime:(CMTime)time;
/*!
	@method		setRedValue:greenValue:blueValue:atTime:
	@abstract	Writes the red, green, and blue components at a time and preserves the current alpha. */
- (void)setRedValue:(double)red greenValue:(double)green blueValue:(double)blue atTime:(CMTime)time;
/*! @abstract Encodes the color into the plugin-state coder. */
- (void)encodeWithCoder:(NSCoder *_Nonnull)coder;

@end

#endif
