/*!
	@file       FxGripStaticRegistrar.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripStaticRegistrar
	@abstract   Implements the base singleton that registers a plugin bundle's effects and groups.
	@discussion Introduced in FxGrip 0.1.0. The class builds the plugin and group records from the
	            subclass hooks, validates each plugin's required entries, moves on-screen controls to
	            their supporting plugins, and freezes the results into immutable, localized arrays.
*/

#import <objc/runtime.h>
#import <Foundation/NSTask.h>
#import "FxGripStaticRegistrar.h"
#import "FxGripTypes.h"
#import "FxGripPluginInfo.h"
#import "FxGrip_ARC.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "FxGripRegisteredPlugin.h"
#import "FxGripPluginGroupData.h"

/**!
 	You may ask yourself, why should there be a constant class for registering FxPlug Plugins?
 Great question.  It allows for easy localization of the  values, storage of the plugin configurations,
 and parameterization of data registration.

 The data can be produced the same way or through the Registrar methids.
 */

/*!
	@abstract	The singleton registrar that validates and stores a plugin bundle's registration records.
	@discussion	Introduced in FxGrip 0.1.0. The class serves as the FxPlug host's registration entry
				point, collecting plugins and groups from the subclass hooks and freezing them for the host.
*/
@implementation FxGripStaticRegistrar
@synthesize isLoadable = _isLoadable;
@synthesize registeredPlugInGroups = _registeredPlugInGroups;
@synthesize registeredPlugIns = _registeredPlugIns;

#pragma mark -
#pragma mark BESingleton

+(BOOL)isSingleton
{
	return YES;
}

- (id) init
{
#if DEBUG
	NSLog(@"%s", __func__);
#endif
	self = [super init];
	if (self) {
		_isLoadable = YES;
		__registeredPlugInGroups = NSMutableDictionary.new;
		__registeredPlugIns = NSMutableDictionary.new;
	}
	return self;
}

- (void)dealloc
{
	NARC_RELEASE(__registeredPlugInGroups);
	NARC_RELEASE(__registeredPlugIns);
	
	SUPER_DEALLOC();
}


#pragma mark - PROPlugInRegistering

+ (id)sharedInstance
{
	return self.__BESingleton;
}

- (BOOL)shouldLoadFirstInstanceOfPlugInWithError:(NSError **)error
{
#if DEBUG
	NSLog(@"%@::%s", self.className, __func__);
#endif
	return self.isLoadable;
}

/*!
 * @method		registeredPlugInGroupsWithError
 * @param	error	The error Handle
 * @return		Return a NSArray of NSDictionaries mirroring the structure found in property lists.
 * 				eg. @[@{@"groupName" : @"Plugin Group", @"uuid": @"00000000-60C2-4634-B29C-00C6FE8C9E9E"},
 * 				@{@"groupName" : @"FxGripPluginEffect::Group Name", @"uuid": @"11111111-60C2-4634-B29C-01C6FE8C9E9E"}]
 *@discussion	The groupName field is localized by` FxGripPluginInfo::localizeObject:`.
 *				If the subclass contains method `plugInGroupsWithError`, it is called and the return value passed to `registerGroups`
 *
 */
- (nullable NSArray<NSDictionary*> *)registeredPlugInGroupsWithError:(NSError **)error
{
#if DEBUG
	NSLog(@"%@::%s", self.className, __func__);
#endif
	if (error) {
		*error = nil;
	}
	
	NSArray<NSDictionary<NSString*, id>*> *plugInGroupsArray = self.registeredPlugInGroups;
	
	if (!plugInGroupsArray) {
		//Call the primary method to retrieve PlugIns
		if (![self registeredPlugInsWithError:error]) {
			return nil;
		}
		
		//Call the subclass method to retrieve or register Plugin Groups
		if ([self respondsToSelector:@selector(plugInGroupsWithError:)]) {
			NSArray<id> *groups = [self plugInGroupsWithError:error];
			if ((!error || !*error) && groups) {
				// 
				[self registerGroups:groups];
			}
		}
		
		plugInGroupsArray = _registeredPlugInGroups = [FxGripPluginInfo localizeObject:__registeredPlugInGroups.allValues];
		__registeredPlugInGroups = nil;
	}
	
	if (!plugInGroupsArray.count) {
#if DEBUG
		NSLog(@"%@::%s No Plugin Groups", self.className, __func__);
#endif
		if (error && !*error) {
			*error = [NSError errorWithDomain:FxGripPlugErrorDomain
										 code:kFxGripError_NoConfigGroups
									 userInfo:nil];
		}
		return nil;
	}
	return plugInGroupsArray;
}


// DEPRECATED
- (NSArray *)requestedProtocolsWithError:(NSError **)error
{
#if DEBUG
	NSLog(@"DEPRECATED-- %@::%s", self.className, __func__);
#endif
	return nil;
}


/*!
	@method		registeredPlugInsWithError:
	@abstract	Builds and returns the registered plugin dictionaries on first call.
	@discussion	Introduced in FxGrip 0.1.0. The method registers the plugins the subclass supplies
				through plugInReferences and plugInsWithError:, then moves each plugin that names an
				on-screen control into that control's supportedPlugins list. It freezes every record to
				immutable, localizes the result, and caches it. A later call returns the cached array.
				An empty result sets kFxGripError_NoConfigPlugins. */
- (nullable NSArray *)registeredPlugInsWithError:(NSError **)error
{
#if DEBUG
	NSLog(@"%@::%s", self.className, __func__);
#endif
	
	NSArray<NSDictionary<NSString*, id>*> *plugInsArray = self.registeredPlugIns;

	if (!plugInsArray) {
		
		// Register any individually specified plugins
		id plugInReferences = nil;
		if ([self respondsToSelector:@selector(plugInReferences)] && (plugInReferences = [self plugInReferences])) {
			if ([plugInReferences isKindOfClass:NSString.class]) {
				plugInReferences = [plugInReferences splitByHumanDividers];
			} else if ([plugInReferences isKindOfClass:NSDictionary.class]) {
				plugInReferences = [plugInReferences allValues];
			} else if (![plugInReferences isKindOfClass:NSArray.class]) {
				plugInReferences = @[plugInReferences];
			}
			if ([plugInReferences isKindOfClass:NSArray.class]) {
				for (id p in plugInReferences) {
					Class cls = p;
					if ([p isKindOfClass:NSString.class]) {
						cls = NSClassFromString(p);
					}
					if (cls) {
						[self registerPluginClass:cls];
					}
				}
			}
		}
		
		// Register any plugins from subclass
		if ([self respondsToSelector:@selector(plugInsWithError:)]) {
			NSError *errorReserved = nil;
			id plugins = [self plugInsWithError:&errorReserved];
			if (!errorReserved) {
				[self registerPlugins:plugins];
			} else {
				*error = errorReserved;
			}
		}
		
		// Search for plugins using other OSC plugins
		__block BOOL hasOSC = NO;
		[__registeredPlugIns.allValues enumerateObjectsUsingBlock:^(NSDictionary*  _Nonnull plugin, NSUInteger idx, BOOL * _Nonnull stop) {
			if (plugin[kProPlugPlugInX_OSCUUIDsProperty]) {
				hasOSC = YES;
				*stop = YES;
			}
		}];
		
		if (hasOSC) {
			// Move any plugins that use OSC over to their OSC. Iterate a key snapshot and
			// operate through the live store: plugins are registered immutable, so each entry
			// is upgraded to a mutable copy in place before it is edited.
			for (NSString *pluginUUID in __registeredPlugIns.allKeys) {
				id oscUUIDs = __registeredPlugIns[pluginUUID][kProPlugPlugInX_OSCUUIDsProperty];
				if (!oscUUIDs) {
					continue;
				}
				// The osc key is a registration-time directive, not part of the plugin record.
				if (![__registeredPlugIns[pluginUUID] isKindOfClass:NSMutableDictionary.class]) {
					__registeredPlugIns[pluginUUID] = [__registeredPlugIns[pluginUUID] mutableCopy];
				}
				[(NSMutableDictionary*)__registeredPlugIns[pluginUUID] removeObjectForKey:kProPlugPlugInX_OSCUUIDsProperty];

				if ([oscUUIDs isKindOfClass:NSDictionary.class]) {
					oscUUIDs = [(NSDictionary*)oscUUIDs allValues];
				} else if([oscUUIDs isKindOfClass:NSString.class]) {
					oscUUIDs = @[oscUUIDs];
				}
				for(NSString *oscUUID in oscUUIDs) {
					if (!__registeredPlugIns[oscUUID]) {
						NSLog(@"Error: Plugin UUID %@ wants OSC UUID %@ that does not exist.", pluginUUID, oscUUID);
						continue;
					}
					if (![__registeredPlugIns[oscUUID] isKindOfClass:NSMutableDictionary.class]) {
						__registeredPlugIns[oscUUID] = [__registeredPlugIns[oscUUID] mutableCopy];
					}
					NSArray *supportedPlugins = __registeredPlugIns[oscUUID][kProPlugPlugIn_SupportedPluginsProperty];
					if (!supportedPlugins) {
						supportedPlugins = NSArray.new;
					}
					__registeredPlugIns[oscUUID][kProPlugPlugIn_SupportedPluginsProperty] = [supportedPlugins arrayByAddingObject:pluginUUID];
				}
			}
		}

		//Make the plugins immutable
		for (NSString *key in __registeredPlugIns.allKeys) {
			if ([__registeredPlugIns[key] isKindOfClass:NSMutableDictionary.class]) {
				__registeredPlugIns[key] = [__registeredPlugIns[key] copy];
			}
		}
		
		plugInsArray = _registeredPlugIns = [[FxGripPluginInfo localizeObject:__registeredPlugIns.allValues] copy];
		__registeredPlugIns = nil;
	}
	
	if (!plugInsArray.count) {
#if DEBUG
		NSLog(@"%@::%s No Plugin Effects", self.className, __func__);
#endif
		if (error && !*error) {
			*error = [NSError errorWithDomain:FxGripPlugErrorDomain
										 code:kFxGripError_NoConfigPlugins
									 userInfo:nil];
		}
		return nil;
	}
	return plugInsArray;
}



#pragma mark -
#pragma mark FxGripRegisteringGroups Implementation

- (void)registerGroup:(nullable id)inputGroup
{
	if (!inputGroup || !([inputGroup isKindOfClass:FxGripPluginGroupData.class] || [inputGroup isKindOfClass:NSDictionary.class])) {
		return;
	}
	
	NSString *groupName = nil;
	NSString *uuid = nil;
	
	if ([inputGroup isKindOfClass:FxGripPluginGroupData.class]) {
		groupName = ((FxGripPluginGroupData*)inputGroup).name;
		uuid = ((FxGripPluginGroupData*)inputGroup).uuid;
	} else if ([inputGroup isKindOfClass:NSDictionary.class]) {
		groupName = inputGroup[kProPlugPlugInX_RegGroupNameProperty];
		uuid = inputGroup[kProPlugPlugInX_RegGroupUUIDProperty];
	}
	
	[self registerGroupUUID:uuid groupName:groupName];
}

- (void)registerGroups:(nullable id)groups
{
	if (!groups) {
		return;
	}
	if ([groups isKindOfClass:NSDictionary.class] && ![(NSDictionary*)groups objectForKey:kProPlugPlugInX_RegGroupNameProperty]) {
		//NSDictionary without a groupName is a list of groups
		groups = [(NSDictionary*)groups allValues];
	}
	if (![groups isKindOfClass:NSArray.class]) {
		groups = @[groups];
	}
	[groups enumerateObjectsUsingBlock:^(NSDictionary * _Nonnull group, NSUInteger idx, BOOL * _Nonnull stop) {
		[self registerGroup:group];
	}];
}

/*!
	@method		registerGroupUUID:groupName:
	@abstract	Registers one group under its UUID with its display name.
	@discussion	Introduced in FxGrip 0.1.0. The method rejects a call made after registration closes and
				a call missing the UUID or name. Re-registering a UUID with a different name logs an error. */
- (void)registerGroupUUID:(nonnull NSString*)uuid groupName:(nonnull NSString*)groupName
{
	if (!__registeredPlugInGroups) {
#if DEBUG
		NSLog(@"Error: Cannot register a group after the registration process");
#endif
		return;
	}
	if (!uuid && !groupName) {
		NSLog(@"Error: attempting to register a group that doesn't have a Group Name or UUID");
		return;
	}
	if (!uuid) {
		NSLog(@"Error: attempting to register a group that doesn't have a UUID");
		return;
	}
	if (!groupName) {
		NSLog(@"Error: attempting to register a group that doesn't have a Group Name");
		return;
	}
	if (__registeredPlugInGroups[uuid] && ![__registeredPlugInGroups[uuid][kProPlugPlugInX_RegGroupNameProperty] isEqualToString:groupName]) {
		NSLog(@"Error: groupUUID '%@' already registered with groupName '%@'", uuid, __registeredPlugInGroups[uuid][kProPlugPlugInX_RegGroupNameProperty]);
	}

	NSDictionary *group = @{kProPlugPlugInX_RegGroupUUIDProperty: uuid,
							kProPlugPlugInX_RegGroupNameProperty: groupName};
	[__registeredPlugInGroups setObject:group forKey:uuid];
}

- (BOOL)containsGroupUUID:(nonnull NSString*)uuid
{
	return [__registeredPlugInGroups objectForKey:uuid] != NULL;
}


#pragma mark -
#pragma mark FxGripRegisteringPlugins Implementation

/*!
	@method		registerPluginClass:
	@abstract	Registers a plugin from a class that conforms to FxGripRegisteredPlugin.
	@discussion	Introduced in FxGrip 0.1.0. The method skips a non-conforming class and a class whose
				isRegisteredPlugIn returns NO. It reads the class's registration records, registers any
				carried group list, and registers the plugin records. It returns YES when the class
				supplied records. */
- (BOOL)registerPluginClass:(nonnull Class)pluginClass
{
	if (![pluginClass conformsToProtocol:@protocol(FxGripRegisteredPlugin)]) {
		return NO;
	}
	
	if ([pluginClass respondsToSelector: @selector(isRegisteredPlugIn)] && ![pluginClass isRegisteredPlugIn]) {
		return NO;
	}
	
	// Get the data from the PlugIn Class
	id pluginsInfo = [pluginClass registeredPlugInInformation:self];
	BOOL success = NO;
	if (pluginsInfo) {
		if ([pluginsInfo isKindOfClass:NSDictionary.class] && pluginsInfo[kProPlugPlugInList_Property]) {
			// NSDictionary with groupName/uuid, NSDictionary.allValues of the same, or NSarray of NSDictionary of same.
			[self registerGroups:pluginsInfo[kProPlugPlugIn_GroupList_Property]];
			pluginsInfo = pluginsInfo[kProPlugPlugInList_Property];
		}
		success = YES;
		[self registerPlugins:pluginsInfo];
	}
	return success;
}


/*!
	@method		registerPlugin:
	@abstract	Registers one plugin from a class or a validated plugin dictionary.
	@discussion	Introduced in FxGrip 0.1.0. A class argument is forwarded to registerPluginClass:. A
				dictionary that carries a group name registers the group and drops the name from the
				stored record. The plugin registers only when it has a UUID, a loadable class name, a
				display name, a group UUID, protocol names, and a version. A class name that resolves to
				no loaded class is rejected. The method returns YES when the plugin registers. */
- (BOOL) registerPlugin:(nullable NSDictionary*)plugin
{
	if (!plugin) {
		return NO;
	}
	if (object_isClass (plugin)) {
		return [self registerPluginClass:(Class)plugin];
	}
	if (![plugin isKindOfClass:NSDictionary.class]) {
		return NO;
	}
	NSMutableDictionary *mutablePlugin = nil;
	
	if (plugin[kProPlugPlugInX_RegGroupNameProperty]) {
		if (plugin[kProPlugPlugIn_GroupUUIDProperty]) {
			[self registerGroupUUID:plugin[kProPlugPlugIn_GroupUUIDProperty] groupName:plugin[kProPlugPlugInX_RegGroupNameProperty]];
		} else {
#if DEBUG
			NSLog(@"Error: %s plugin %@(%@) has no group uuid.", __func__, plugin[kProPlugPlugIn_ClassNameProperty], plugin[kProPlugPlugIn_UuidProperty]);
#endif
		}
		mutablePlugin = plugin.mutableCopy;
		[mutablePlugin removeObjectForKey:kProPlugPlugInX_RegGroupNameProperty];
	}
	BOOL success = NO;
	if (__registeredPlugIns) {
		// The class must be loadable: the host instantiates plugins by this name, so a
		// name that resolves to nothing would register a plugin that cannot run.
		BOOL classExists = NSClassFromString(plugin[kProPlugPlugIn_ClassNameProperty]) != Nil;
		if (plugin[kProPlugPlugIn_UuidProperty]
			&& plugin[kProPlugPlugIn_ClassNameProperty]
			&& classExists
			&& plugin[kProPlugPlugIn_DisplayNameProperty]
			&& plugin[kProPlugPlugIn_GroupUUIDProperty]
			&& plugin[kProPlugPlugIn_ProtocolNamesProperty]
			&& plugin[kProPlugPlugIn_VersionProperty]) {
			if (!mutablePlugin) {
				mutablePlugin = plugin.mutableCopy;
			}
			[__registeredPlugIns setObject:mutablePlugin.copy forKey:plugin[kProPlugPlugIn_UuidProperty]];
			success = YES;
		} else if (plugin[kProPlugPlugIn_ClassNameProperty] && !classExists) {
#if DEBUG
			NSLog(@"Error: Plugin class \"%@\" (%@) is not loaded.", plugin[kProPlugPlugIn_ClassNameProperty], plugin[kProPlugPlugIn_UuidProperty]);
#endif
		} else {
#if DEBUG
			NSString *uuid = plugin[kProPlugPlugIn_UuidProperty] ? @"" : @" uuid";
			NSString *className = plugin[kProPlugPlugIn_ClassNameProperty] ? @"" : @" className";
			NSString *displayName = plugin[kProPlugPlugIn_DisplayNameProperty] ? @"" : @" displayName";
			NSString *groupUUID = plugin[kProPlugPlugIn_GroupUUIDProperty] ? @"" : @" group";
			NSString *protocolNames = plugin[kProPlugPlugIn_ProtocolNamesProperty] ? @"" : @" protocolNames";
			NSString *version = plugin[kProPlugPlugIn_VersionProperty] ? @"" : @" version";
			NSString *protocol = [plugin[kProPlugPlugIn_ProtocolNamesProperty] isKindOfClass:NSArray.class] ? @"" : @" and protocolNames is not an Array. ";
			NSString *versionWrong = [plugin[kProPlugPlugIn_VersionProperty] isKindOfClass:NSNumber.class] ? @"": @"version should be an Integer Number, like 1000 for version 1.0.0.0";
			NSLog(@"Error: Plugin does not have (%@%@%@%@%@%@) %@ %@", uuid, className, displayName, groupUUID, protocolNames, version,    protocol, versionWrong);
#endif
		}
	} else {
#if DEBUG
		NSLog(@"Error: Cannot register a group after the registration process");
#endif
	}
	return success;
}

- (void) registerPlugins:(nullable NSArray<NSDictionary*>*)plugins
{
	if (!plugins) {
		return;
	}
	if ([plugins isKindOfClass:NSDictionary.class] && ![(NSDictionary*)plugins objectForKey:kProPlugPlugIn_ClassNameProperty]) {
		//NSDictionary without a className is a list of plugins
		plugins = [(NSDictionary*)plugins allValues];
	}
	if (![plugins isKindOfClass:NSArray.class]) {
		plugins = @[(NSDictionary*)plugins];
	}
	[plugins enumerateObjectsUsingBlock:^(NSDictionary * _Nonnull plugin, NSUInteger idx, BOOL * _Nonnull stop) {
		[self registerPlugin:plugin];
	}];
}

- (BOOL) containsPluginUUID:(nonnull NSString*)uuid
{
	return __registeredPlugIns[uuid] != NULL;
}



@end
