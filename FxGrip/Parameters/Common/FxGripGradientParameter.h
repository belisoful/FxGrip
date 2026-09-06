/*!
	@file       FxGripGradientParameter.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripGradientParameter
	@abstract   The parameter model for a host gradient parameter.
	@discussion Introduced in FxGrip 0.1.0. The class registers a gradient parameter and reads its samples at a render time. The sampled gradient is a header followed by the interleaved RGBA samples at the configured depth. The class conforms to FxGripStateParameter and encodes the sampled gradient into the FxPlug plugin-state coder. An NSCoder category decodes the gradient and builds a Metal texture from it.
*/

#ifndef FxGripGradientParameter_h
#define FxGripGradientParameter_h

#import "FxGripParameter.h"
#import <FxPlug/FxTypes.h>


/*!
	@class		FxGripGradientParameter
	@abstract	The parameter model for a host gradient parameter.
	@discussion	Introduced in FxGrip 0.1.0. The class maps the declared configuration to a host gradient parameter and samples its color ramp at a render time.
*/
@interface FxGripGradientParameter : FxGripParameter <FxGripStateParameter>

/*! @abstract The pixel depth the gradient samples are read at. */
@property (readwrite, assign) FxDepth	fxDepth;
/*! @abstract The number of bytes per sample component for the current depth. */
@property (readwrite, assign) uint		byteDepth;
/*! @abstract The number of samples read across the gradient. */
@property (readwrite, assign) uint		samples;

/*! @abstract The FxPlug type key string this class registers. */
+ (nullable NSString*)parameterTypeString;
/*! @abstract The FxParameterType this class registers. */
+ (FxParameterType)parameterType;
/*!
	@method		addParameter:toEffect:
	@abstract	Registers the gradient parameter with the effect's host.
	@param		parameter	The parameter configuration dictionary.
	@param		effect		The host that receives the parameter.
	@return		YES when the host creates the parameter. */
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect;

/*!
	@method		valueAtTime:
	@abstract	Samples the gradient at a render time.
	@param		renderTime	The time to sample the parameter at.
	@return		A pointer to the sampled gradient owned by the parameter, or nil when the retrieval API fails.
	@discussion	Introduced in FxGrip 0.1.0. The returned buffer is valid until the next sample or deallocation. */
- (FxGripGradient*_Nullable)valueAtTime:(CMTime)renderTime NS_RETURNS_INNER_POINTER;
/*! @abstract Encodes the sampled gradient into the plugin-state coder. */
- (void)encodeWithCoder:(NSCoder *_Nonnull)coder;


@end


/*!
	@abstract	The NSCoder additions that decode a gradient from the plugin-state coder.
	@discussion	Introduced in FxGrip 0.1.0. The category reads a gradient encoded by FxGripGradientParameter and builds a Metal texture from the decoded samples.
*/
@interface NSCoder (FxGripGradient)

/*!
	@method		decodeGradientAtIndex:
	@abstract	Decodes a gradient from the coder at an index.
	@param		index	The parameter index the gradient was encoded at.
	@return		A pointer to the decoded gradient owned by the coder, or NULL when the coder is not a plugin-state encoder. */
- (nullable FxGripGradient *)decodeGradientAtIndex:(int64_t)index NS_RETURNS_INNER_POINTER;

/*!
	@method		decodeGradientAtIndex:device:
	@abstract	Decodes a gradient and builds a Metal texture from it.
	@param		index	The parameter index the gradient was encoded at.
	@param		device	The Metal device that allocates the texture.
	@return		A texture one pixel tall and the sample count wide. */
// A MTLTexture that is 1 pixel in height and number of Samples in width
- (nullable id<MTLTexture>) decodeGradientAtIndex:(int64_t)index device:(nonnull id<MTLDevice>)device NS_RETURNS_RETAINED;

@end

#endif
