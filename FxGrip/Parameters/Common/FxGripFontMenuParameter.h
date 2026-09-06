/*!
	@file       FxGripFontMenuParameter.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripFontMenuParameter
	@abstract   The parameter model for a host font menu.
	@discussion Introduced in FxGrip 0.1.0. The class registers a font menu whose value is a font name string. It derives from FxGripStringParameterBase and reads the font name at a render time. The default font name falls back to the framework default when the declaration sets none.
*/

#ifndef FxGripFontMenuParameter_h
#define FxGripFontMenuParameter_h

#import "FxGripStringParameter.h"


/*!
	@class		FxGripFontMenuParameter
	@abstract	The parameter model for a host font menu.
	@discussion	Introduced in FxGrip 0.1.0. The class maps the declared configuration to a host font menu and reads the selected font name at a render time.
*/
@interface FxGripFontMenuParameter : FxGripStringParameterBase

/*! @abstract The FxPlug type key string this class registers. */
+ (nullable NSString*)parameterTypeString;
/*! @abstract The FxParameterType this class registers. */
+ (FxParameterType)parameterType;
/*!
	@method		addParameter:toEffect:
	@abstract	Registers the font menu with the effect's host.
	@param		parameter	The parameter configuration dictionary.
	@param		effect		The host that receives the parameter.
	@return		YES when the host creates the parameter.
	@discussion	Introduced in FxGrip 0.1.0. The default font name falls back to kFxParameterType_FontNameDefault. */
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect;

/*!
	@method		valueAtTime:
	@abstract	Reads the selected font name at a render time.
	@param		renderTime	The time to sample the parameter at.
	@return		The font name, or nil when the retrieval API is unavailable. */
-(NSString*_Nullable) valueAtTime:(CMTime)renderTime;

@end

#endif
