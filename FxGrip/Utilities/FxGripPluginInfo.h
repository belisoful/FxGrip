//
//  FxGripPluginInfo.h
//  XPC Service
//
//  Created on 3/11/24.
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef FxGripPluginInfo_h
#define FxGripPluginInfo_h

#import <FxPlug/FxPlugSDK.h>
#import <PluginManager/PROPlugInBundleRegistration.h>
#import "FxGripTypes.h"
#import <BEFoundation/BESingleton.h>
//#import "FxGripDynamicRegistrar.h"


/*!
	@class      FxGripPluginInfo
	@discussion This class keeps track of all the instances of the FxGripTileableEffect plug-in. It figures out the start time
				of each instance and can return the start time of the previous or next instance given an instance. This
				allows you to determine where to move the playhead to get to the next one.
 				This mimics behavior of loading the pluginGroups and PluginList from the Info.plist.
 				Subclasses can override the PROPlugInRegistering functions
 */
@interface FxGripPluginInfo : NSObject <BESingleton, FxPrincipalDelegate>

//	FxPrincipalDelegate accessor functions
@property (nullable, readonly) NSString* hostBundleIdentifier;
@property (nullable, readonly) NSString* hostVersion;

/*! YES when the connected host is Motion. NO before the host connects. Introduced in FxGrip 1.0.
	@discussion Motion differs from Final Cut Pro in two timing queries: `frameDuration:` returns
	the project frame duration rather than the footage's, and `isInputDropFrame:parameterID:`
	always returns NO. A plugin that displays footage timecode in Motion asks the user for the
	footage rate instead; see FxGripTimecode. */
@property (readonly) BOOL hostIsMotion;


+ (nullable id)sharedInstance;

//Common Properties
// return NSHumanReadableCopyright from Info.plist
@property (class, strong, readonly) NSString* _Nullable copyright;


//Plugin Information from the Info.plist or the Dynamic Registration
@property (class, assign, readonly) BOOL isDynamicRegistration;
@property (class, strong, readonly) NSString* _Nullable dynamicRegistrationPrincipalClass;

// Filled from the Info.plist or the Dynamic Registrar specified by Info.plist
@property (class, strong, readonly) NSArray* _Nullable plugIns; // Info.plist
@property (class, strong, readonly) NSArray* _Nullable plugInGroups; // "ProPlugPlugInList" or dynamic registration from Info.plist

//+ (FxGripPluginInfo* _Nonnull) sharedInfo;
- (nullable instancetype) init;

//Takes an object and localizes the strings from the plugin main NSBundle.
+ (id _Nullable)localizeObject:(id _Nullable)object;


+ (nullable id)propertyForKey:(NSString*_Nullable) key;

+ (nonnull NSDictionary *)pluginPropertiesByClassName:(nonnull NSString *)pluginClassName;
+ (nonnull NSDictionary *)pluginPropertiesByUUID:(nonnull NSString *)pluginUUID;

+ (NSCharacterSet*_Nonnull)separatorSet;

@end

/*! YES when a host bundle identifier names Motion: `com.apple.motionapp` or
	`com.apple.motionappApp`. nil returns NO. Introduced in FxGrip 1.0. */
BOOL FxGripHostBundleIdentifierIsMotion(NSString * _Nullable hostBundleIdentifier);

#endif
