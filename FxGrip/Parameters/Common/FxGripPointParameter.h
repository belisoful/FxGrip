/*!
	@file       FxGripPointParameter.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripPointParameter
	@abstract   The parameter model for a host point parameter with on-screen control options.
	@discussion Introduced in FxGrip 0.1.0. The class registers a point parameter whose value is an X and Y pair. It parses the declaration's FxGripPointOptions once for the on-screen control. It conforms to FxGripStateParameter and encodes the point into the FxPlug plugin-state coder.
*/

#ifndef FxGripPointParameter_h
#define FxGripPointParameter_h

#import "FxGripParameter.h"
#import "FxGripPointOptions.h"


/*!
	@class      FxGripPointParameter
	@abstract   A host point parameter with FxGripPointOptions design-time options.
	@discussion The value is the host's X and Y. The declaration's option keys (see
				FxGripPointOptions.h) are parsed once into options, which an effect passes to
				FxGripPointOSC to draw and constrain the point's on-screen control.
*/
@interface FxGripPointParameter : FxGripParameter <FxGripStateParameter>

/*! The parsed design-time options; the documented defaults when the declaration sets none. */
@property (readonly, nonnull) FxGripPointOptions *options;

/*! @abstract The FxPlug type key string this class registers. */
+ (nullable NSString*)parameterTypeString;
/*! @abstract The FxParameterType this class registers. */
+ (FxParameterType)parameterType;
/*!
	@method		addParameter:toEffect:
	@abstract	Registers the point parameter with the effect's host.
	@param		parameter	The parameter configuration dictionary.
	@param		effect		The host that receives the parameter.
	@return		YES when the host creates the parameter.
	@discussion	Introduced in FxGrip 0.1.0. The default X and Y are 0.5. */
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect;

/*!
	@method		valueAtTime:
	@abstract	Reads the point at a render time.
	@param		renderTime	The time to sample the parameter at.
	@return		The point, or the origin when the retrieval API is unavailable. */
- (FxGripPoint)valueAtTime:(CMTime)renderTime;
/*!
	@method		setValue:atTime:
	@abstract	Writes the point at a time.
	@param		value	The point to set. A NULL value performs no write.
	@param		time	The time to set the point at. */
- (void)setValue:(FxGripPoint*_Nullable)value atTime:(CMTime)time;
/*! @abstract Writes the X and Y components at a time. */
- (void)setXValue:(double)xValue YValue:(double)yValue atTime:(CMTime)time;
/*! @abstract Encodes the point into the plugin-state coder. */
- (void)encodeWithCoder:(NSCoder *_Nonnull)coder;

@end

#endif
