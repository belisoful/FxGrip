/*!
	@file       FxGripMenuParameter.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripMenuParameter
	@abstract   The parameter model for a host popup menu.
	@discussion Introduced in FxGrip 0.1.0. The class registers a popup menu with the effect's host. The menu's selected index is an integer, and value access comes from FxGripIntParameter. The declared menu entries are parsed once into parameterMenuItems.
*/

#ifndef FxGripMenuParameter_h
#define FxGripMenuParameter_h

#import "FxGripIntParameter.h"


/*!
	@class		FxGripMenuParameter
	@abstract	The parameter model for a host popup menu.
	@discussion	Introduced in FxGrip 0.1.0. The class registers a popup menu and inherits integer value access from FxGripIntParameter.
*/
@interface FxGripMenuParameter : FxGripIntParameter

/*! @property parameterMenuItems @abstract The menu entry titles parsed from the declaration. */
@property (readonly, nonnull) NSArray<NSString*>* parameterMenuItems;

/*! @abstract The FxPlug type key string this class registers. */
+ (nullable NSString*)parameterTypeString;
/*! @abstract The FxParameterType this class registers. */
+ (FxParameterType)parameterType;
/*!
	@method		addParameter:toEffect:
	@abstract	Registers the popup menu with the effect's host.
	@param		parameter	The parameter configuration dictionary, including the menu entries.
	@param		effect		The host that receives the parameter.
	@return		YES when the host creates the parameter.
	@discussion	Introduced in FxGrip 0.1.0. The default selected index is 0. */
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect;

@end

#endif
