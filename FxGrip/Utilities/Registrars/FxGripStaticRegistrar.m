
#import <objc/runtime.h>
#import <Foundation/NSTask.h>
#import "FxGripStaticRegistrar.h"
#import "FxGripTypes.h"
#import "FxGripPluginInfo.h"
#import "FxGrip_ARC.h"
#import "NSDictionary+FxTileableEffect.h"
#import "FxRegisteredPlugin.h"
#import "FxPluginGroupData.h"

/**!
 	You may ask yourself, why should there be a constant class for registering FxPlug Plugins?
 Great question.  It allows for easy localization of the  values, storage of the plugin configurations,
 and parameterization of data registration.
 
 The data can be produced the same way or through the Registrar methids.
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
 * 				@{@"groupName" : @"FxPluginEffect::Group Name", @"uuid": @"11111111-60C2-4634-B29C-01C6FE8C9E9E"}]
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


/**
 	Go through all classes, find the FxRegisteredPlugin, and if active, include it.
 */

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
			*stop = hasOSC = plugin[kProPlugPlugInX_OSCUUIDsProperty];
		}];
		
		if (hasOSC) {
			// Move any plugins that use OSC over to their OSC
			[__registeredPlugIns.allValues enumerateObjectsUsingBlock:^(NSMutableDictionary*  _Nonnull plugin, NSUInteger idx, BOOL * _Nonnull stop) {
				
				NSArray* oscUUIDs = plugin[kProPlugPlugInX_OSCUUIDsProperty];
				if (!oscUUIDs) {
					return;
				}
				[plugin removeObjectForKey:kProPlugPlugInX_OSCUUIDsProperty];
				
				NSString* pluginUUID = plugin[kProPlugPlugIn_UuidProperty];
				if ([oscUUIDs isKindOfClass:NSDictionary.class]) {
					oscUUIDs = [(NSDictionary*)oscUUIDs allValues];
				} else if([oscUUIDs isKindOfClass:NSString.class]) {
					oscUUIDs = @[oscUUIDs];
				}
				for(NSString *oscUUID in oscUUIDs) {
					if (!__registeredPlugIns[oscUUID]) {
						NSLog(@"Error: Plugin UUID %@ wants OSC UUID %@ that does not exist.", pluginUUID, oscUUID);
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
			}];
		}
		
		//Make the plugins immutable
		[__registeredPlugIns enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull plugin, BOOL * _Nonnull stop) {
			if ([__registeredPlugIns[key] isKindOfClass:NSMutableDictionary.class]) {
				__registeredPlugIns[key] = [__registeredPlugIns[key] copy];
			}
		}];
		
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
#pragma mark FxRegisteringGroups Implementation

- (void)registerGroup:(nullable id)inputGroup
{
	if (!inputGroup || !([inputGroup isKindOfClass:FxPluginGroupData.class] || [inputGroup isKindOfClass:NSDictionary.class])) {
		return;
	}
	
	NSString *groupName = nil;
	NSString *uuid = nil;
	
	if ([inputGroup isKindOfClass:FxPluginGroupData.class]) {
		groupName = ((FxPluginGroupData*)inputGroup).name;
		uuid = ((FxPluginGroupData*)inputGroup).uuid;
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

- (void)registerGroupUUID:(nonnull NSString*)uuid groupName:(nonnull NSString*)groupName
{
	if (!__registeredPlugInGroups) {
#if DEBUG
		NSLog(@"Error: Cannot register a group after the registration process");
#endif
	} else if (!uuid && !groupName) {
		NSLog(@"Error: attempting to register a group that doesn't have a Group Name or UUID");
	} else if (!uuid) {
		NSLog(@"Error: attempting to register a group that doesn't have a UUID");
	} else if (!groupName) {
		NSLog(@"Error: attempting to register a group that doesn't have a Group Name");
	} else if (__registeredPlugInGroups[uuid] && ![__registeredPlugInGroups[uuid][kProPlugPlugInX_RegGroupNameProperty] isEqualToString:groupName]) {
		NSLog(@"Error: groupUUID '%@' already registered with groupName '%@'", uuid, __registeredPlugInGroups[uuid]);
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
#pragma mark FxRegisteringPlugins Implementation

- (BOOL)registerPluginClass:(nonnull Class)pluginClass
{
	if (![pluginClass conformsToProtocol:@protocol(FxRegisteredPlugin)]) {
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
