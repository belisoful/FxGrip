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

+(instancetype) sharedInstance;

@end

NS_ASSUME_NONNULL_END

#endif
