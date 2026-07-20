//
//  PrincipalDelegate.m
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#import "FxGripPrincipalDelegate.h"
#import <objc/runtime.h>
#import "FxGrip_ARC.h"

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


- (void)didEstablishConnectionWithHost:(NSString *)hostBundleIdentifier
                               version:(NSString *)hostVersion
{
#ifdef DEBUG
    NSLog (@"%s Established a connection to: %@ v%@", __func__, hostBundleIdentifier, hostVersion);
#endif
	_hostBundleIdentifier = hostBundleIdentifier;
	_hostVersion = hostVersion;
}


@end
