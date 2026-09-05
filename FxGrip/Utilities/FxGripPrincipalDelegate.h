//
//  FxGripPrincipalDelegate.h
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef FxGripPrincipalDelegate_h
#define FxGripPrincipalDelegate_h

#import <FxPlug/FxPlugSDK.h>
#import <BEFoundation/BESingleton.h>

NS_ASSUME_NONNULL_BEGIN


@interface FxGripPrincipalDelegate : NSObject <FxPrincipalDelegate, BESingleton>

@property (nullable, strong, readonly) NSString* hostBundleIdentifier;
@property (nullable, strong, readonly) NSString* hostVersion;

/*! YES when the connected host is Motion; see FxGripPluginInfo.hostIsMotion for the timing
	differences this implies. Introduced in FxGrip 1.0. */
@property (readonly) BOOL hostIsMotion;

+(instancetype) sharedInstance;

@end

NS_ASSUME_NONNULL_END

#endif
