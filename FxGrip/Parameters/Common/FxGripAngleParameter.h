/*!
	@file       FxGripAngleParameter.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripAngleParameter
	@abstract   The parameter model for a host angle slider measured in degrees.
	@discussion Introduced in FxGrip 0.1.0. The class registers an angle slider with the effect's host. It inherits value access and state encoding from FxGripFloatParameter. The default range is 0 to 360 degrees.
*/

#ifndef FxGripAngleParameter_h
#define FxGripAngleParameter_h

#import "FxGripFloatParameter.h"


/*!
	@class		FxGripAngleParameter
	@abstract	The parameter model for a host angle slider measured in degrees.
	@discussion	Introduced in FxGrip 0.1.0. The class registers an angle slider and inherits float value access from FxGripFloatParameter.
*/
@interface FxGripAngleParameter : FxGripFloatParameter

/*! @abstract The FxPlug type key string this class registers. */
+ (nullable NSString*)parameterTypeString;
/*! @abstract The FxParameterType this class registers. */
+ (FxParameterType)parameterType;
/*!
	@method		addParameter:toEffect:
	@abstract	Registers the angle slider with the effect's host.
	@param		parameter	The parameter configuration dictionary.
	@param		effect		The host that receives the parameter.
	@return		YES when the host creates the parameter.
	@discussion	Introduced in FxGrip 0.1.0. The range defaults to 0 to 360 degrees. */
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect;

@end

#endif
