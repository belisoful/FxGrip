/*!
	@file       FxGripPrincipalDelegate.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripPrincipalDelegate
	@abstract   The plug-in's FxPrincipalDelegate singleton that records the connected host.
	@discussion Introduced in FxGrip 0.1.0. FxPlug calls the principal delegate once when it
	            establishes the connection to a host, passing the host's bundle identifier and
	            version. This singleton stores those and derives whether the host is Motion. Code
	            throughout FxGrip reads the host identity through the shared instance.
*/

#ifndef FxGripPrincipalDelegate_h
#define FxGripPrincipalDelegate_h

#import <FxPlug/FxPlugSDK.h>
#import <BEFoundation/BESingleton.h>

NS_ASSUME_NONNULL_BEGIN


/*!
	@class		FxGripPrincipalDelegate
	@abstract	The FxPrincipalDelegate singleton that records the connected host's identity.
	@discussion	Introduced in FxGrip 0.1.0. The delegate captures the host bundle identifier and
				version at connection time and reports whether the host is Motion.
*/
@interface FxGripPrincipalDelegate : NSObject <FxPrincipalDelegate, BESingleton>

/*! The connected host's bundle identifier, or nil before the connection is established. */
@property (nullable, strong, readonly) NSString* hostBundleIdentifier;
/*! The connected host's version string, or nil before the connection is established. */
@property (nullable, strong, readonly) NSString* hostVersion;

/*! YES when the connected host is Motion; see FxGripPluginInfo.hostIsMotion for the timing
	differences this implies. Introduced in FxGrip 0.1.0. */
@property (readonly) BOOL hostIsMotion;

/*! The shared principal delegate instance. */
+(instancetype) sharedInstance;

@end

NS_ASSUME_NONNULL_END

#endif
