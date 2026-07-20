//
//  FxGripPluginInfo.m
//  XPC Service
//
//  Created on 3/11/24.
//  Copyright © 2024 Belisoful All rights reserved.
//
/*!
 *
 * FxGripPluginInfo cannot conform to protocol FxPrincipalDelegate because the
 * Principal Delegate is referenced in main, it cannot be subclassed for the
 * shared instance in such a standard way.
 */

#import "FxGripPluginInfo.h"
#import "FxGripAPIAccessing.h"
#import "FxTileableEffectBase.h"
#import "FxGripOOBParameterAccess.h"
#import <PluginManager/PROPlugInBundleRegistration.h>
#import "FxGripPrincipalDelegate.h"
#import <objc/runtime.h>
#import <FxGrip/FxGripTypes.h>
#import "FxGrip_ARC.h"
#include <BEFoundation/BESingleton.h>

// The common plugin info
static NSCharacterSet*		gSeparatorSet = nil;

// Implementation
@implementation FxGripPluginInfo


+(BOOL)isSingleton
{
	return YES;
}

+ (FxGripPluginInfo*)sharedInstance
{
	return self.__BESingleton;
}

- (nullable instancetype)init;
{
	self = [super init];
	
	if (self != nil)
	{
	}
	
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
	_hostBundleIdentifier = NARC_RETAIN(hostBundleIdentifier);
	_hostVersion = NARC_RETAIN(hostVersion);
}


// White Space plus period, comma, and semicolon.
+ (NSCharacterSet*_Nonnull)separatorSet
{
	static dispatch_once_t onceToken; // static and global initialized to zero by runtime
	dispatch_once(&onceToken, ^{
		NSMutableCharacterSet *flagSeparator = [NSMutableCharacterSet whitespaceAndNewlineCharacterSet];
		[flagSeparator addCharactersInString:@".,;"];
		gSeparatorSet = [flagSeparator copy];
	});
	
	return gSeparatorSet;
}


+(id _Nullable) localizeObject:(id _Nullable)object
{
	if (!object)
		return nil;
	
	NSBundle *mainBundle = [NSBundle mainBundle];
	NSDictionary<NSString *,id> *localized = [mainBundle localizedInfoDictionary];
	if (!localized)
		   return object;
	
	if ([object isKindOfClass:[NSString class]]) {
		id localObject = localized[object];
		if (localObject)
			return localObject;
	} else if ([object isKindOfClass:[NSMutableArray class]]) {
		for (int i = 0; i < [object count]; i++) {
			object[i] = [self localizeObject:object[i]];
		}
		return object;
	} else if ([object isKindOfClass:[NSMutableDictionary class]]) {
		for (id key in ((NSMutableDictionary*)object).allKeys) {
			((NSMutableDictionary*)object)[key] = [self localizeObject:((NSMutableDictionary*)object)[key]];
		}
		return object;
	} else if ([object isKindOfClass:[NSArray class]]) {
		id localObject = [NSMutableArray arrayWithCapacity:[object count]];
		for (id item in object) {
			[localObject addObject:[self localizeObject:item]];
		}
		return NARC_RETAIN_AUTORELEASE([[object class].alloc initWithArray:localObject]);
	} else if ([object isKindOfClass:[NSDictionary class]]) {
		id localObject = [NSMutableDictionary dictionaryWithCapacity:[object count]];
		for (id key in object) {
			localObject[key] = [self localizeObject:object[key]];
		}
		return NARC_RETAIN_AUTORELEASE([[object class].alloc initWithDictionary:localObject]);
	}
	return object;
}



#pragma mark -
#pragma mark Plugin Information from Info.plist & Dynamic Registration


+ (nullable id)propertyForKey:(NSString*_Nullable) key
{
	NSBundle *mainBundle = [NSBundle mainBundle];

	if (!mainBundle) {
		return nil;
	}
	return [mainBundle objectForInfoDictionaryKey:key];
}

+ (NSString*_Nullable)copyright
{
	return [self propertyForKey:@"NSHumanReadableCopyright"];
}


+ (BOOL)isDynamicRegistration
{
	return [[self propertyForKey:kProPlugDynamicRegistration_Property] boolValue];
}


+ (NSString *_Nullable)dynamicRegistrationPrincipalClass
{
	return [self propertyForKey:kProPlugDynamicRegistrationPrincipalClass_Property];
}


+ (nullable NSArray *) plugIns
{
	if (!self.isDynamicRegistration) {
		return [self localizeObject:[self propertyForKey:kProPlugPlugInList_Property]];
	}
	
	NSString *clsStr = self.dynamicRegistrationPrincipalClass;
	if (!clsStr) {
		return nil;
	}
	Class cls = NSClassFromString(clsStr);
	if (!cls) {
		NSLog(@"Error: Dynamic Registration Principal Class  \"%@\" Not Found in the main bundle Info.plist", clsStr ? clsStr : @"(null)");
		return nil;
	}
	if (![cls conformsToProtocol:@protocol(PROPlugInRegistering)]) {
		NSLog(@"Error: Dynamic Registration Principal Class  \"%@\" does not conform to  protocol PROPlugInRegistering", clsStr);
		return nil;
	}
	
	NSArray *pluginList = nil;
	
	// Instance Registration Class into Object and get plugins
	id <PROPlugInRegistering> dyRegister = [cls sharedInstance];
	if (!dyRegister) {
		NSLog(@"Error: Dynamic Registration Principal Class  \"%@\" did not return its sharedInstance", clsStr);
		return nil;
	}
	NSError *error = nil;
	pluginList = [dyRegister registeredPlugInsWithError:&error];
	
	if (!pluginList || !pluginList.count || error) {
		if (!error) {
			NSLog(@"Error: Dynamic Registration Principal Class  \"%@\" did not return any plugins", clsStr);
		}
		if (error) {
			NSLog(@"Error: %@::registeredPlugInsWithError returned an error \"%@\" ", clsStr, error);
		}
		return nil;
	}
	
	return [self localizeObject:pluginList];
}


+ (NSArray *)plugInGroups
{
	if (!self.isDynamicRegistration) {
		return [self localizeObject:[self propertyForKey:kProPlugPlugIn_GroupList_Property]];
	}
	
	NSString *clsStr = self.dynamicRegistrationPrincipalClass;
	if (!clsStr) {
		return nil;
	}
	Class cls = NSClassFromString(clsStr);
	if (!cls) {
		NSLog(@"Error: Dynamic Registration Principal Class  \"%@\" Not Found in the main bundle Info.plist", clsStr ? clsStr : @"(null)");
		return nil;
	}
	if (![cls conformsToProtocol:@protocol(PROPlugInRegistering)]) {
		NSLog(@"Error: Dynamic Registration Principal Class  \"%@\" does not conform to  protocol PROPlugInRegistering", clsStr);
		return nil;
	}
	
	NSArray *pluginGroupList = nil;
	
	// Instance Registration Class into Object and get plugins
	id <PROPlugInRegistering> dyRegister = [cls sharedInstance];
	if (!dyRegister) {
		NSLog(@"Error: Dynamic Registration Principal Class  \"%@\" did not return its sharedInstance", clsStr);
		return nil;
	}
	NSError *error = nil;
	pluginGroupList = [dyRegister registeredPlugInGroupsWithError:&error];
	
	if (!pluginGroupList || !pluginGroupList.count || error) {
		if (!error) {
			NSLog(@"Error: Dynamic Registration Principal Class  \"%@\" did not return any plugins", error);
		}
		if (error) {
			NSLog(@"Error: %@::registeredPlugInGroupsWithError returned an error \"%@\" ", clsStr, error);
		}
		return nil;
	}
	
	return [self localizeObject:pluginGroupList];
}


// return the plugin properties based on the class
+ (nonnull NSDictionary *)pluginPropertiesByClassName:(nonnull NSString *)pluginClassName
{
	pluginClassName = pluginClassName.uppercaseString;
	for(NSDictionary *pluginProperties in self.plugIns) {
		NSString *pluginClassName = [pluginProperties objectForKey:kProPlugPlugIn_ClassNameProperty];
		if (pluginClassName && [pluginClassName.lowercaseString isEqualToString:pluginClassName]) {
			return pluginProperties;
		}
	}
	return @{};
}


// return the plugin properties based on the UUID
+ (nonnull NSDictionary *)pluginPropertiesByUUID:(nonnull NSString *)pluginUUID
{
	pluginUUID = pluginUUID.uppercaseString;
	for(NSDictionary *pluginProperties in self.plugIns) {
		NSString *testPluginUUID = [pluginProperties objectForKey:kProPlugPlugIn_UuidProperty];
		if ([testPluginUUID isKindOfClass:NSString.class] && [testPluginUUID.uppercaseString isEqualToString:pluginUUID]) {
			return pluginProperties;
		}
	}
	return @{};
}

@end
