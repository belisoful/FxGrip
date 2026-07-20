

#import "FxTileableEffectBase+Versioning.h"
#import "FxTileableEffectBase.h"
#import <BEFoundation/NSString+BExtension.h>


@implementation FxTileableEffectBase (Versioning)


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

- (BOOL)checkVersion:(NSError * _Nullable * _Nullable)error
{
	id<FxVersioningAPI> versioningAPI = self.apiManager.versioningAPIv1;
	
	if (!versioningAPI) {
		NSLog(@"%s(%llu) Could not load FxVersioningAPI", __func__, self.apiManager.sessionID);
		if (error)
		{
			*error = [NSError errorWithDomain:FxPlugErrorDomain
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
