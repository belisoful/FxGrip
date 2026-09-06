/*!
	@file       FxGripConfigRegistrar.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripConfigRegistrar
	@abstract   The registrar that reads plugin and group lists from the host bundle's Info.plist.
	@discussion Introduced in FxGrip 0.1.0. The class reads the ProPlugPlugInList and
	            ProPlugPlugInGroupList keys from the main bundle. It reproduces the host's static
	            registration path while the values are supplied dynamically. Each accessor reports a
	            missing list through the error argument.
*/

#ifndef FxGripConfigRegistrar_h
#define FxGripConfigRegistrar_h

#import "FxGripStaticRegistrar.h"

/*!
	@class		FxGripConfigRegistrar
	@abstract	The static registrar that sources its plugins and groups from the host Info.plist.
	@discussion	Introduced in FxGrip 0.1.0. The class returns the plist plugin and group dictionaries
				to the base class for registration.
*/
@interface FxGripConfigRegistrar : FxGripStaticRegistrar

/*!
	@method		plugInGroupsWithError:
	@abstract	Returns the plugin group dictionaries from the main bundle's ProPlugPlugInGroupList key.
	@param		error	Set to kFxGripError_NoConfigGroups when the key is absent.
	@return		The group dictionaries, or nil when the key is absent. */
- (nullable NSArray<NSDictionary*> *)plugInGroupsWithError:(NSError * _Nullable * _Nonnull)error;

/*!
	@method		plugInsWithError:
	@abstract	Returns the plugin dictionaries from the main bundle's ProPlugPlugInList key.
	@param		error	Set to kFxGripError_NoConfigPlugins when the key is absent.
	@return		The plugin dictionaries, or nil when the key is absent. */
- (nullable NSArray<NSDictionary*> *)plugInsWithError:(NSError * _Nullable * _Nonnull)error;

@end


#endif
