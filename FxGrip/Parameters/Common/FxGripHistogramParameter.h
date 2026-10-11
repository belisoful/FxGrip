/*!
	@file       FxGripHistogramParameter.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripHistogramParameter
	@abstract   The parameter model for a host histogram parameter.
	@discussion Introduced in FxGrip 0.1.0. The class registers a histogram parameter and reads its per-channel levels at a render time. The sampled histogram holds the black in, black out, white in, white out, and gamma for five channels. The class conforms to FxGripStateParameter and encodes the histogram into the FxPlug plugin-state coder.
*/

#ifndef FxGripHistogramParameter_h
#define FxGripHistogramParameter_h

#import <FxGrip/FxGripParameter.h>


/*!
	@class		FxGripHistogramParameter
	@abstract	The parameter model for a host histogram parameter.
	@discussion	Introduced in FxGrip 0.1.0. The class maps the declared configuration to a host histogram parameter and reads its per-channel levels at a render time.
*/
@interface FxGripHistogramParameter : FxGripParameter <FxGripStateParameter>

/*! @abstract The FxPlug type key string this class registers. */
+ (nullable NSString*)parameterTypeString;
/*! @abstract The FxParameterType this class registers. */
+ (FxParameterType)parameterType;
/*!
	@method		addParameter:toEffect:
	@abstract	Registers the histogram parameter with the effect's host.
	@param		parameter	The parameter configuration dictionary.
	@param		effect		The host that receives the parameter.
	@return		YES when the host creates the parameter. */
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect;

/*!
	@method		getHistogram:atTime:
	@abstract	Reads the histogram levels at a render time into a caller-supplied histogram.
	@param		histogram	The histogram that receives the levels.
	@param		renderTime	The time to sample the parameter at.
	@return		YES when every channel reads.
	@discussion	Introduced in FxGrip 0.1.0. A channel the host refuses keeps the kZeroHistogram levels. The method is safe to call concurrently. */
- (BOOL)getHistogram:(FxGripHistogram *_Nonnull)histogram atTime:(CMTime)renderTime;
/*!
	@method		valueAtTime:
	@abstract	Reads the histogram levels at a render time.
	@param		renderTime	The time to sample the parameter at.
	@return		A pointer to the sampled histogram, valid until the enclosing autorelease pool drains.
	@discussion	Introduced in FxGrip 0.1.0. The method is safe to call concurrently. Use getHistogram:atTime: to learn whether every channel read. */
- (FxGripHistogram*_Nullable)valueAtTime:(CMTime)renderTime;
/*! @abstract Encodes the histogram into the plugin-state coder. */
- (void)encodeWithCoder:(NSCoder *_Nonnull)coder;

@end

#endif
