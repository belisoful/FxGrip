/// @deprecated Legacy GuruFx implementation retained only for the final merge into the
/// new FxGrip implementations. Do not modify or extend; names intentionally unchanged.



#import "GuruFxTileableEffect+Versioning.h"
#import "GuruFxTileableEffect.h"
#import "NSString+BExtension.h"


@implementation GuruFxTileableEffect (Versioning)


#pragma mark -
#pragma mark Versioning Implementation

#define kVersion1_0_0 100

- (UInt32)version
{
	id version = self.properties[kProPlugPlugIn_VersionProperty];
	if (version) {
		if ([version isKindOfClass:NSNumber.class] ) {
			return ((NSNumber*)version).intValue;
		}
		if ([version isKindOfClass:NSString.class] && ((NSString*)version).isDigits) {
			return ((NSString*)version).intValue;
		}
		NSLog(@"Plugin Version \"\%@"" must be an NSNumber integer", version);
	}
	return 0;
}

- (NSString*_Nullable)pluginShortVersion
{
	return self.properties[@"CFBundleShortVersionString"];
}

-(unsigned int) checkVersion:(NSError * _Nullable * _Nullable)error
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
		return -1;
	}
	unsigned int mProjectPluginVersion = [versioningAPI versionAtCreation];
	unsigned int mPluginVersion = self.version;
	if(mPluginVersion > mProjectPluginVersion) {
		//@question is down grade possible?  should it be '!=' ?
		if ([self upgradeFromVersion:mProjectPluginVersion currentVersion:mPluginVersion error:error]) {
			NSLog(@"%s(%llu) Upgraded: Project Plugin Version=%d -> Current Version=%d", __func__, self.apiManager.sessionID, mProjectPluginVersion, mPluginVersion);
			[versioningAPI updateVersionAtCreation: mProjectPluginVersion];
		} else {
			NSLog(@"%s(%llu) Upgrade Failed: Project Plugin Version=%d -> Current Version=%d", __func__, self.apiManager.sessionID, mProjectPluginVersion, mPluginVersion);
		}
	} else {
		NSLog(@"%s(%llu) Checking: Project Plugin Version=%d - Current Version=%d", __func__, self.apiManager.sessionID, mProjectPluginVersion, mPluginVersion);
	}
	
	return mPluginVersion;
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
-(bool) upgradeFromVersion:(unsigned int)fromVersion currentVersion:(unsigned int)currentVersion error:(NSError * _Nullable * _Nullable)error
{
	return YES;
}


@end
