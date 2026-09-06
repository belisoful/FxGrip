/*!
	@file       FxGripPrincipalDelegate.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripPrincipalDelegate
	@abstract   Implements the FxPrincipalDelegate singleton that records the connected host.
	@discussion Introduced in FxGrip 0.1.0. The connection callback stores the host bundle
	            identifier and version. hostIsMotion derives from the bundle identifier.
*/

#import "FxGripPrincipalDelegate.h"
#import "FxGripPluginInfo.h"
#import <objc/runtime.h>
#import "FxGrip_ARC.h"

/*!
	@abstract	The FxPrincipalDelegate singleton that records the connected host's identity.
	@discussion	Introduced in FxGrip 0.1.0. The delegate captures the host identity at connection
				time and reports whether the host is Motion.
*/
@implementation FxGripPrincipalDelegate

@synthesize hostBundleIdentifier = _hostBundleIdentifier;
@synthesize hostVersion = _hostVersion;


+(BOOL)isSingleton {
	return YES;
}

+(instancetype) sharedInstance
{
	return self.__BESingleton;
}


-(instancetype)init
{
    self = [super init];
    
    return self;
}

- (void)dealloc
{
	NARC_RELEASE(_hostBundleIdentifier);
	NARC_RELEASE(_hostVersion);
	
	SUPER_DEALLOC();
}


/*!
	@method		didEstablishConnectionWithHost:version:
	@abstract	Records the host identity when FxPlug establishes the connection.
	@param		hostBundleIdentifier	The connected host's bundle identifier.
	@param		hostVersion				The connected host's version string. */
- (void)didEstablishConnectionWithHost:(NSString *)hostBundleIdentifier
                               version:(NSString *)hostVersion
{
#ifdef DEBUG
    NSLog (@"%s Established a connection to: %@ v%@", __func__, hostBundleIdentifier, hostVersion);
#endif
	_hostBundleIdentifier = hostBundleIdentifier;
	_hostVersion = hostVersion;
}

/*! @abstract YES when the recorded host bundle identifier is Motion's. */
- (BOOL)hostIsMotion
{
	return FxGripHostBundleIdentifierIsMotion(self.hostBundleIdentifier);
}


@end
