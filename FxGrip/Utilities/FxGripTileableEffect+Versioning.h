/*!
	@file       FxGripTileableEffect+Versioning.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripTileableEffect+Versioning
	@abstract   The category that compares the plugin version to the stored version and runs upgrades.
	@discussion Introduced in FxGrip 0.1.0. The category reads the plugin's declared version from
	            its registration record and the version stored in the project through the FxPlug
	            versioning API. When the plugin version is newer, the category runs the subclass
	            upgrade hook and records the new version. A subclass overrides the upgrade hook to
	            migrate its stored data.
*/

#ifndef FxGripTileableEffect_Versioning_h
#define FxGripTileableEffect_Versioning_h

#import <Foundation/Foundation.h>
#import <FxPlug/FxPlugSDK.h>
#import <FxGrip/FxGripTileableEffect.h>



/*!
	@abstract	The category that reports the plugin version and upgrades stored project data.
	@discussion	Introduced in FxGrip 0.1.0. The plugin version comes from the registration record;
				the installed version comes from the FxPlug versioning API.
*/
@interface FxGripTileableEffect (Versioning)

/*! The plugin's integer version from its registration record; defaults to 1 when absent. */
@property (readonly)			UInt32		pluginVersion;
/*! The plugin's short version string from CFBundleShortVersionString. */
@property (readonly, nullable)	NSString*	pluginStringVersion;
/*! The version stored in the project at creation, from the FxPlug versioning API. */
@property (readonly)			UInt32		installedVersion;

/*!
	@method		checkVersion:
	@abstract	Upgrades the project when the plugin version is newer than the stored version.
	@param		error	On failure, the error from the versioning API or the upgrade hook.
	@return		YES when an upgrade runs and records the new version; NO otherwise.
	@discussion	Introduced in FxGrip 0.1.0. The method runs the upgrade hook and records the new
				version through the versioning API. */
- (BOOL)checkVersion:(NSError * _Nullable * _Nullable)error;

/*!
	@method		upgradeFromVersion:currentVersion:error:
	@abstract	Migrates the project's stored data from one plugin version to another.
	@param		fromVersion	The version stored in the project.
	@param		currentVersion	The current plugin version.
	@param		error	On failure, the error describing why the migration failed.
	@return		YES when the migration succeeds.
	@discussion	Introduced in FxGrip 0.1.0. The base implementation returns YES. A subclass
				overrides to migrate its stored data. */
- (BOOL)upgradeFromVersion:(unsigned int)fromVersion currentVersion:(unsigned int)currentVersion error:(NSError * _Nullable * _Nullable)error;

@end

#endif
