/*!
	@file       FxGripTileableEffect+PluginProperties.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripTileableEffect+PluginProperties
	@abstract   Implements the flag reporting whether effect properties come from the Info.plist.
	@discussion Introduced in FxGrip 0.1.0. The base returns NO, so a subclass overrides to read its
	            effect properties from the plugin registration record.
*/

#import "FxGripTileableEffect+OOBParameterAccess.h"
#import "FxGripOOBParameterAccess.h"


/*!
	@abstract	The category reporting whether the effect properties come from the Info.plist.
	@discussion	Introduced in FxGrip 0.1.0.
*/
@implementation FxGripTileableEffect (PluginProperties)

- (BOOL)isEffectPropertiesInInfo
{
	return false;
}


@end
