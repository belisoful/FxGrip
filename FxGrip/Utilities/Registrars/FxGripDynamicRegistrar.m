/*!
	@file       FxGripDynamicRegistrar.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripDynamicRegistrar
	@abstract   Implements the registrar that discovers plugins from the loaded runtime classes.
	@discussion Introduced in FxGrip 0.1.0. Plugin discovery scans the runtime class list for
	            FxGripRegisteredPlugin conformance. Group discovery follows and names each referenced
	            group from the class, the host bundle, or a placeholder.
*/

#import <objc/runtime.h>
#import "FxGripDynamicRegistrar.h"
#import "FxGripTypes.h"
#import "FxGripPluginInfo.h"
#import "FxGripRegisteredPlugin.h"

/*!
	@abstract	The static registrar that finds conforming plugin classes by runtime introspection.
	@discussion	Introduced in FxGrip 0.1.0. The class registers every loaded FxGripRegisteredPlugin class
				and resolves the groups those plugins reference.
*/
@implementation FxGripDynamicRegistrar


/*!
	@method		plugInGroupsWithError:
	@abstract	Resolves and registers a group name for every group the active plugins reference.
	@discussion	Introduced in FxGrip 0.1.0. The method collects the group UUIDs from the registered
				plugins, then names each unregistered group. A name is taken from the plugin class
				through groupNameForUUID: or groupName, then from the host bundle's group list, then
				from a numbered placeholder. A caught exception sets kFxGripError_Exception. */
- (nullable NSArray *) plugInGroupsWithError:(NSError * _Nullable * _Nonnull)error
{
#if DEBUG
	NSLog(@"%s", __func__);
#endif
	// Get all active plugins and their group UUIDs
	NSMutableArray<NSDictionary*> *activePlugins = [self registeredPlugInsWithError:error].mutableCopy;
	if (!activePlugins || (error && *error)) {
		return nil;
	}
	
	NSMutableSet *pluginGroupUUIDs = [NSMutableSet set];
	
	// Collect all group UUID from the plugins
	for (NSDictionary *pluginInfo in activePlugins) {
		NSString *groupUUID = pluginInfo[kProPlugPlugIn_GroupUUIDProperty];
		if (groupUUID) {
			[pluginGroupUUIDs addObject:groupUUID];
		}
	}
	
	NSMutableSet *missingGroups = [pluginGroupUUIDs mutableCopy];
	[missingGroups minusSet:[NSSet setWithArray:__registeredPlugInGroups.allKeys]];
	
	if (missingGroups.count) {
		@try {
			//	NSMutableSet does not like being edited while enumerating, so copy.
			for (NSString *groupUUID in missingGroups.copy) {
				for (NSDictionary *plugin in activePlugins) {
					NSString *pguuid = plugin[kProPlugPlugIn_GroupUUIDProperty];
					if (![pguuid isEqualToString:groupUUID]) {
						continue;
					}
					Class cls = NSClassFromString(plugin[kProPlugPlugIn_ClassNameProperty]);
					NSString *groupName = nil;
					if ([cls respondsToSelector:@selector(groupNameForUUID:)]) {
						groupName = [cls groupNameForUUID:pguuid];
					}
					if (!groupName && [cls respondsToSelector:@selector(groupName)]) {
						groupName = [cls groupName];
					}
					if (groupName) {
						[self registerGroupUUID:groupUUID groupName:groupName];
						[missingGroups removeObject:groupUUID];
						[activePlugins removeObject:plugin];
						break;
					}
				}
			}
			
			// Fill any names still missing from the host bundle's group list.
			if (missingGroups.count) {
				id groupList = [[NSBundle mainBundle] objectForInfoDictionaryKey:kProPlugPlugIn_GroupList_Property];
				if ([groupList isKindOfClass:NSDictionary.class]) {
					groupList = [(NSDictionary*)groupList allValues];
				}
				if ([groupList isKindOfClass:NSArray.class]) {
					for (NSDictionary *groupInfo in groupList) {
						if (![groupInfo isKindOfClass:NSDictionary.class]) {
							continue;
						}
						NSString *uuid = groupInfo[kProPlugPlugInX_RegGroupUUIDProperty];
						if (![missingGroups containsObject:uuid]) {
							continue;
						}
						[missingGroups removeObject:uuid];
						[self registerGroup:groupInfo];
					}
				}
			}

			// Any group still without a name gets a placeholder.
			NSInteger unlabelledIndex = 1;
			for (NSString *uuid in missingGroups) {
				[self registerGroupUUID:uuid groupName:[NSString stringWithFormat:@"Unlabelled Group %ld", (long)unlabelledIndex++]];
			}
		}
		@catch (NSException *exception) {
			if (error) {
				*error = [NSError errorWithDomain:FxGripPlugErrorDomain
											 code:kFxGripError_Exception
										 userInfo:@{NSLocalizedDescriptionKey:
														[NSString stringWithFormat:@"Error: exception thrown getting group names, reason: %@", exception.reason]}];
			}
		}
	}
	return nil;
}


/*!
	@method		globalRegisteredPluginClasses
	@abstract	Returns every loaded class that conforms to FxGripRegisteredPlugin.
	@discussion	Introduced in FxGrip 0.1.0. The method walks the runtime class list with C introspection
				calls, so classes that trap on a message send are skipped safely. Each class's superclass
				chain is checked, matching the semantics of conformsToProtocol:. */
+ (nonnull NSArray<Class> *)globalRegisteredPluginClasses
{
	NSMutableArray *clss = NSMutableArray.new;

	unsigned int numClasses;
	Class *classes = objc_copyClassList(&numClasses);

	Protocol *registeredPlugin = @protocol(FxGripRegisteredPlugin);
	for (unsigned int i = 0; i < numClasses; i++) {
		// objc_copyClassList includes classes that lack an NSObject root and trap on any
		// message send; only runtime C calls are safe here. class_conformsToProtocol does
		// not consult superclasses, so walk the chain to match -conformsToProtocol:.
		for (Class cls = classes[i]; cls; cls = class_getSuperclass(cls)) {
			if (class_conformsToProtocol(cls, registeredPlugin)) {
				[clss addObject:classes[i]];
				break;
			}
		}
	}
	free(classes);

	return clss.copy;
}

/*!
	@method		plugInsWithError:
	@abstract	Registers every loaded FxGripRegisteredPlugin class.
	@discussion	Introduced in FxGrip 0.1.0. The method enumerates the conforming classes from
				globalRegisteredPluginClasses and registers each one. A caught exception sets
				kFxGripError_Exception. */
- (nullable NSArray *) plugInsWithError:(NSError * _Nullable * _Nonnull)error;
{
#if DEBUG
	NSLog(@"%s", __func__);
#endif
	
	// Get all classes
	@try {
		NSArray<Class> *registeredPlugins = [self.class globalRegisteredPluginClasses];
		
		[registeredPlugins enumerateObjectsUsingBlock:^(Class  _Nonnull currentClass, NSUInteger idx, BOOL * _Nonnull stop) {
			[self registerPluginClass:currentClass];
		}];
	}
	@catch (NSException *exception) {
		if (error) {
			*error = [NSError errorWithDomain:FxGripPlugErrorDomain
										 code:kFxGripError_Exception
									 userInfo:@{NSLocalizedDescriptionKey:
													[NSString stringWithFormat:@"Error: could not get inline registered plugins: %@",
													 exception.reason]}];
		}
	}
	return nil;
}


@end
