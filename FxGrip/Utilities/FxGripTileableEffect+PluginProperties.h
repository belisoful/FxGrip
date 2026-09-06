/*!
	@file       FxGripTileableEffect+PluginProperties.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripTileableEffect+PluginProperties
	@abstract   The category that reports whether the effect's FxPlug properties live in the Info.plist.
	@discussion Introduced in FxGrip 0.1.0. The properties callback reads the effect-property
	            dictionary from the plugin registration record when isEffectPropertiesInInfo is YES.
	            The base returns NO, so a subclass opts in by overriding.
*/

#ifndef FxGripTileableEffect_PluginProperties_h
#define FxGripTileableEffect_PluginProperties_h

#import <Foundation/Foundation.h>
#import "FxGripTileableEffect.h"

/*!
	@abstract	The category reporting whether the effect properties come from the Info.plist.
	@discussion	Introduced in FxGrip 0.1.0.
*/
@interface FxGripTileableEffect (PluginProperties)

/*! YES when the effect reads its FxPlug properties from the plugin registration record. */
@property (readonly)			BOOL		isEffectPropertiesInInfo;

@end

#endif /* ProjectProperties */
