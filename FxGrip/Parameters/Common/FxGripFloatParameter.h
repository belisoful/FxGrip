/*!
	@file       FxGripFloatParameter.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripFloatParameter
	@abstract   The parameter model for a host floating-point slider.
	@discussion Introduced in FxGrip 0.1.0. The class registers a float slider with the effect's host through the parameter-creation API. It reads and writes the slider value at a render time. It conforms to FxGripStateParameter and encodes its value into the FxPlug plugin-state coder. FxGripAngleParameter and FxGripPercentParameter derive from it.
*/

#ifndef FxGripFloatParameter_h
#define FxGripFloatParameter_h

#import "FxGripParameter.h"


/*!
	@class		FxGripFloatParameter
	@abstract	The parameter model for a host floating-point slider.
	@discussion	Introduced in FxGrip 0.1.0. The class maps the declared configuration to a host float slider and exposes its value at a render time.
*/
@interface FxGripFloatParameter : FxGripParameter <FxGripStateParameter>

/*! @abstract The FxPlug type key string this class registers. */
+ (nullable NSString*)parameterTypeString;
/*! @abstract The FxParameterType this class registers. */
+ (FxParameterType)parameterType;
/*!
	@method		addParameter:toEffect:
	@abstract	Registers the float slider with the effect's host.
	@param		parameter	The parameter configuration dictionary.
	@param		effect		The host that receives the parameter.
	@return		YES when the host creates the parameter.
	@discussion	Introduced in FxGrip 0.1.0. The default range is 0.0 to 1.0, and the delta defaults to 0.01 for a unit range or 1.0 otherwise. */
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect;

/*!
	@method		valueAtTime:
	@abstract	Reads the slider value at a render time.
	@param		renderTime	The time to sample the parameter at.
	@return		The float value, or 0 when the retrieval API is unavailable. */
- (double)valueAtTime:(CMTime)renderTime;
/*!
	@method		setValue:atTime:
	@abstract	Writes the slider value at a time.
	@param		value	The float value to set.
	@param		time	The time to set the value at. */
- (void)setValue:(double)value atTime:(CMTime)time;
/*! @abstract Encodes the value into the plugin-state coder. */
- (void)encodeWithCoder:(NSCoder *_Nonnull)coder;

@end

#endif
