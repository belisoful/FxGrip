/*!
	@file       FxGripPercentParameter.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripPercentParameter
	@abstract   The parameter model for a host percent slider.
	@discussion Introduced in FxGrip 0.1.0. The class registers a percent slider with the effect's host. It inherits value access and state encoding from FxGripFloatParameter. The default range is 0.0 to 1.0.
*/

#ifndef FxGripPercentParameter_h
#define FxGripPercentParameter_h

#import "FxGripFloatParameter.h"


/*!
	@class		FxGripPercentParameter
	@abstract	The parameter model for a host percent slider.
	@discussion	Introduced in FxGrip 0.1.0. The class registers a percent slider and inherits float value access from FxGripFloatParameter.
*/
@interface FxGripPercentParameter : FxGripFloatParameter

/*! @abstract The FxPlug type key string this class registers. */
+ (nullable NSString*)parameterTypeString;
/*! @abstract The FxParameterType this class registers. */
+ (FxParameterType)parameterType;
/*!
	@method		addParameter:toEffect:
	@abstract	Registers the percent slider with the effect's host.
	@param		parameter	The parameter configuration dictionary.
	@param		effect		The host that receives the parameter.
	@return		YES when the host creates the parameter.
	@discussion	Introduced in FxGrip 0.1.0. The parameter range defaults to 0.0 to 1.0, and the delta defaults to 0.01 for a unit-width range and 1.0 otherwise. */
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect;

@end

#endif
