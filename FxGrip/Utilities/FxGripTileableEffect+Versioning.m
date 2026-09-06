/*!
	@file       FxGripTileableEffect+Versioning.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripTileableEffect+Versioning
	@abstract   Implements plugin-version reporting and the project upgrade path.
	@discussion Introduced in FxGrip 0.1.0. The category reads the plugin version from the
	            registration record and the installed version from the FxPlug versioning API. When
	            the plugin version is greater, it runs the upgrade hook and records the new version.
*/

#import "FxGripTileableEffect+Versioning.h"
#import "FxGripTileableEffect.h"
#import <BEFoundation/NSString+BExtension.h>


/*!
	@abstract	The category that reports the plugin version and upgrades stored project data.
	@discussion	Introduced in FxGrip 0.1.0.
*/
@implementation FxGripTileableEffect (Versioning)


#pragma mark -
#pragma mark Versioning Implementation

#define kVersion1_0_0 100

 - (UInt32)pluginVersion
{
	id version = self.pluginProperties[kProPlugPlugIn_VersionProperty];
	if (version) {
		if ([version isKindOfClass:NSNumber.class] ) {
			return ((NSNumber*)version).intValue;
		}
		if ([version isKindOfClass:NSString.class] && ((NSString*)version).isIntValue) {
			return ((NSString*)version).intValue;
		}
		NSLog(@"Plugin Version \"\%@"" must be an NSNumber int", version);
	}
	return 1;
}

- (nullable NSString *)pluginStringVersion
{
	return self.pluginProperties[@"CFBundleShortVersionString"];
}

- (UInt32)installedVersion
{
	id<FxVersioningAPI> versioningAPI = self.apiManager.versioningAPIv1;
	
	if (!versioningAPI) {
		return 0;
	}
	
	return [versioningAPI versionAtCreation];
}

/*!
	@method		checkVersion:
	@abstract	Upgrades the project when the plugin version is newer than the stored version.
	@param		error	On failure, the error from the missing versioning API or the upgrade hook.
	@return		YES when an upgrade runs and records the new version; NO otherwise.
	@discussion	Introduced in FxGrip 0.1.0. The method reads the installed version, and when the
				plugin version is greater it runs upgradeFromVersion:currentVersion:error: and then
				records the plugin version through the versioning API. */
- (BOOL)checkVersion:(NSError * _Nullable * _Nullable)error
{
	id<FxVersioningAPI> versioningAPI = self.apiManager.versioningAPIv1;
	
	if (!versioningAPI) {
		NSLog(@"%s(%llu) Could not load FxVersioningAPI", __func__, self.apiManager.sessionID);
		if (error)
		{
			*error = [NSError errorWithDomain:FxGripPlugErrorDomain
										 code:kFxError_APIUnavailable
									 userInfo:@{ NSLocalizedFailureReasonErrorKey : @"Unable to obtain the FxVersioningAPI" }];
		}
		return NO;
	}
	
	UInt32 installedVersion = [versioningAPI versionAtCreation];
	UInt32 pluginVersion = self.pluginVersion;
	BOOL success = NO;
	
	if(installedVersion && pluginVersion > installedVersion) {
		//@question is down grade possible?  should it be '!=' ?
		if ([self upgradeFromVersion:installedVersion currentVersion:pluginVersion error:error]) {
			success = [versioningAPI updateVersionAtCreation:pluginVersion];
			if (success) {
				NSLog(@"%s(%llu) Upgraded: Installed Plugin Version=%d -> Current Version=%d", __func__, self.apiManager.sessionID, installedVersion, pluginVersion);
			} else {
				NSLog(@"%s(%llu) Upgrade Failed in API: Installed Plugin Version=%d -> Current Version=%d", __func__, self.apiManager.sessionID, installedVersion, pluginVersion);
			}
		} else {
			NSLog(@"%s(%llu) Upgrade Failed: Installed Plugin Version=%d -> Current Version=%d", __func__, self.apiManager.sessionID, installedVersion, pluginVersion);
		}
	}
	
	return success;
}

/*!
	@method     -upgradeFromVersion
	@param      fromVersion   -   	The version stored in the project to upgrade from.
	@param      currentVersion   -   The current version from the Info.plist.
	@param      error   -   		The NSError**, if one occurs.
	@discussion This method is called when the project needs to update its plugin version. This method
				updates all the project data associated
	@result     bool				Was the plugin successfully updated.
 */
- (BOOL)upgradeFromVersion:(unsigned int)fromVersion currentVersion:(unsigned int)currentVersion error:(NSError * _Nullable * _Nullable)error
{
	return YES;
}


@end
