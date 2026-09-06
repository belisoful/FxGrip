/*!
	@file       FxGripPushButtonParameter.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripPushButtonParameter
	@abstract   The parameter model for a host push button.
	@discussion Introduced in FxGrip 0.1.0. The class registers a push button. A click dispatches through the effect's parameter click handler. The configuration's optional selector names the subclass action hook. FxGripHelpParameter derives from it.
*/

#ifndef FxGripPushButtonParameter_h
#define FxGripPushButtonParameter_h

#import "FxGripParameter.h"


/*!
	@class		FxGripPushButtonParameter
	@abstract	The parameter model for a host push button.
	@discussion	Introduced in FxGrip 0.1.0. The class registers a push button and dispatches its click through the effect.
*/
@interface FxGripPushButtonParameter : FxGripParameter

/*! @abstract The action selector parsed from the configuration, or NULL when none is declared. */
@property (readonly, nonatomic, nullable) SEL			selector;
/*! @abstract The action selector name as a string. */
@property (readonly, nonatomic, nullable) NSString* 	selectorString;

/*! @abstract The FxPlug type key string this class registers. */
+ (nullable NSString*)parameterTypeString;
/*! @abstract The FxParameterType this class registers. */
+ (FxParameterType)parameterType;
/*!
	@method		addParameter:toEffect:
	@abstract	Registers the push button with the effect's host.
	@param		parameter	The parameter configuration dictionary.
	@param		effect		The host that receives the parameter.
	@return		YES when the host creates the parameter.
	@discussion	Introduced in FxGrip 0.1.0. A configuration selector that does not use the click prefix fails registration. */
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect;

@end

#endif
