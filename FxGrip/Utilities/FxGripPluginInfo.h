/*!
	@file       FxGripPluginInfo.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripPluginInfo
	@abstract   The singleton that reads the plug-in's registration and host identity.
	@discussion Introduced in FxGrip 0.1.0. The class reads plug-in and group lists from the main
	            bundle's Info.plist, or from a dynamic registrar named in the Info.plist. It
	            localizes registration strings against the bundle's localized info dictionary and
	            looks up a plug-in's properties by class name or UUID. It also records the
	            connected host's identity and reports whether the host is Motion.
*/

#ifndef FxGripPluginInfo_h
#define FxGripPluginInfo_h

#import <FxPlug/FxPlugSDK.h>
#import <PluginManager/PROPlugInBundleRegistration.h>
#import "FxGripTypes.h"
#import <BEFoundation/BESingleton.h>
//#import "FxGripDynamicRegistrar.h"


/*!
	@class      FxGripPluginInfo
	@abstract   Reads the plug-in's registration lists, properties, and host identity.
	@discussion Introduced in FxGrip 0.1.0. The singleton loads the plug-in list and plug-in
				group list from the Info.plist, or from the dynamic registrar the Info.plist
				names. It mimics the host's own loading of those lists. It localizes registration
				strings and answers a plug-in's properties by class name or UUID. Subclasses can
				override the PROPlugInRegistering functions.
 */
@interface FxGripPluginInfo : NSObject <BESingleton, FxPrincipalDelegate>

//	FxPrincipalDelegate accessor functions
/*! The connected host's bundle identifier, or nil before the host connects. */
@property (nullable, readonly) NSString* hostBundleIdentifier;
/*! The connected host's version string, or nil before the host connects. */
@property (nullable, readonly) NSString* hostVersion;

/*! YES when the connected host is Motion. NO before the host connects. Introduced in FxGrip 0.1.0.
	@discussion Motion differs from Final Cut Pro in two timing queries: `frameDuration:` returns
	the project frame duration rather than the footage's, and `isInputDropFrame:parameterID:`
	always returns NO. A plugin that displays footage timecode in Motion asks the user for the
	footage rate instead; see FxGripTimecode. */
@property (readonly) BOOL hostIsMotion;


/*! The shared plug-in info instance. */
+ (nullable id)sharedInstance;

//Common Properties
/*! NSHumanReadableCopyright from the main bundle's Info.plist. */
@property (class, strong, readonly) NSString* _Nullable copyright;


//Plugin Information from the Info.plist or the Dynamic Registration
/*! YES when the Info.plist declares dynamic registration. */
@property (class, assign, readonly) BOOL isDynamicRegistration;
/*! The class name of the dynamic-registration principal, from the Info.plist. */
@property (class, strong, readonly) NSString* _Nullable dynamicRegistrationPrincipalClass;

// Filled from the Info.plist or the Dynamic Registrar specified by Info.plist
/*! The registered plug-in list, from the Info.plist or the dynamic registrar. */
@property (class, strong, readonly) NSArray* _Nullable plugIns; // Info.plist
/*! The registered plug-in group list, from the Info.plist or the dynamic registrar. */
@property (class, strong, readonly) NSArray* _Nullable plugInGroups; // "ProPlugPlugInList" or dynamic registration from Info.plist

//+ (FxGripPluginInfo* _Nonnull) sharedInfo;
- (nullable instancetype) init;

/*!
	@method		localizeObject:
	@abstract	Localizes registration strings against the main bundle's localized info dictionary.
	@param		object	A string, array, or dictionary from the registration data, or nil.
	@return		The localized object; a mutable input is localized in place, an immutable input
				returns a localized copy. */
+ (id _Nullable)localizeObject:(id _Nullable)object;


/*! A value from the main bundle's Info.plist for a key. */
+ (nullable id)propertyForKey:(NSString*_Nullable) key;

/*!
	@method		pluginPropertiesByClassName:
	@abstract	The registered properties of the plug-in with a given class name.
	@param		pluginClassName	The plug-in class name, matched case-insensitively.
	@return		The plug-in's properties dictionary, or an empty dictionary when none matches. */
+ (nonnull NSDictionary *)pluginPropertiesByClassName:(nonnull NSString *)pluginClassName;

/*!
	@method		pluginPropertiesByUUID:
	@abstract	The registered properties of the plug-in with a given UUID.
	@param		pluginUUID	The plug-in UUID, matched case-insensitively.
	@return		The plug-in's properties dictionary, or an empty dictionary when none matches. */
+ (nonnull NSDictionary *)pluginPropertiesByUUID:(nonnull NSString *)pluginUUID;

/*! The character set of whitespace, period, comma, and semicolon used to split flag strings. */
+ (NSCharacterSet*_Nonnull)separatorSet;

@end

/*! YES when a host bundle identifier names Motion: `com.apple.motionapp` or
	`com.apple.motionappApp`. nil returns NO. Introduced in FxGrip 0.1.0. */
BOOL FxGripHostBundleIdentifierIsMotion(NSString * _Nullable hostBundleIdentifier);

#endif
