/*!
	@file       FxGripHelpParameter.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripHelpParameter
	@abstract   The parameter model for a host help button.
	@discussion Introduced in FxGrip 0.1.0. The class registers a help button. It derives from FxGripPushButtonParameter. A click opens the plugin's help book when no configuration selector overrides the default action.
*/

#ifndef FxGripHelpParameter_h
#define FxGripHelpParameter_h

#import "FxGripPushButtonParameter.h"


/*!
	@class		FxGripHelpParameter
	@abstract	The parameter model for a host help button.
	@discussion	Introduced in FxGrip 0.1.0. The class registers a help button whose default click action opens the plugin's help book.
*/
@interface FxGripHelpParameter : FxGripPushButtonParameter

/*! @abstract The FxPlug type key string this class registers. */
+ (nullable NSString*)parameterTypeString;
/*! @abstract The FxParameterType this class registers. */
+ (FxParameterType)parameterType;
/*!
	@method		addParameter:toEffect:
	@abstract	Registers the help button with the effect's host.
	@param		parameter	The parameter configuration dictionary.
	@param		effect		The host that receives the parameter.
	@return		YES when the host creates the parameter.
	@discussion	Introduced in FxGrip 0.1.0. The button dispatches through the synthesized click selector for the parameter ID. */
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect;

@end

#endif
