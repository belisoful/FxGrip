/*!
	@file       FxGripIntParameter.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripIntParameter
	@abstract   The parameter model for a host integer slider.
	@discussion Introduced in FxGrip 0.1.0. The class registers an integer slider with the effect's host and reads and writes its value at a render time. It conforms to FxGripParameterMinMaxInt for its minimum and maximum flags. It conforms to FxGripStateParameter and encodes its value into the FxPlug plugin-state coder. FxGripMenuParameter derives from it.
*/

#ifndef FxGripIntParameter_h
#define FxGripIntParameter_h

#import "FxGripParameter.h"


/*!
	@class		FxGripIntParameter
	@abstract	The parameter model for a host integer slider.
	@discussion	Introduced in FxGrip 0.1.0. The class maps the declared configuration to a host integer slider and exposes its value at a render time.
*/
@interface FxGripIntParameter : FxGripParameter <FxGripParameterMinMaxInt, FxGripStateParameter>

/*! @abstract The FxPlug type key string this class registers. */
+ (nullable NSString*)parameterTypeString;
/*! @abstract The FxParameterType this class registers. */
+ (FxParameterType)parameterType;
/*!
	@method		addParameter:toEffect:
	@abstract	Registers the integer slider with the effect's host.
	@param		parameter	The parameter configuration dictionary.
	@param		effect		The host that receives the parameter.
	@return		YES when the host creates the parameter.
	@discussion	Introduced in FxGrip 0.1.0. The parameter range defaults to 0 to 100, and the delta defaults to 1. */
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect;

/*!
	@method		valueAtTime:
	@abstract	Reads the integer value at a render time.
	@param		renderTime	The time to sample the parameter at.
	@return		The integer value, or 0 when the retrieval API is unavailable. */
- (int)valueAtTime:(CMTime)renderTime;
/*!
	@method		setValue:atTime:
	@abstract	Writes the integer value at a time.
	@param		value	The integer value to set.
	@param		time	The time to set the value at. */
- (void)setValue:(int)value atTime:(CMTime)time;
/*! @abstract Encodes the value into the plugin-state coder. */
- (void)encodeWithCoder:(NSCoder *_Nonnull)coder;


@end

#endif
