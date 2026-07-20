
#import <objc/runtime.h>
#import "FxGripDynamicRegistrar.h"
#import "FxGripTypes.h"
#import "FxGripPluginInfo.h"
#import "FxRegisteredPlugin.h"

@implementation FxGripDynamicRegistrar



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
			//	NSMutableSet doesn'	t like being edited while enumerating, so copy.
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
			
			// Handle any remaining unnamed groups
			NSInteger unlabelledIndex = 1;
			for (NSString *uuid in missingGroups) {
				[self registerGroupUUID:uuid groupName:[NSString stringWithFormat:@"Unlabelled Group %ld", (long)unlabelledIndex++]];
			}
			
			if (missingGroups.count) {
				// Get ProPlugPlugInGroupList and verify all UUIDs are present
				NSBundle *mainBundle = [NSBundle mainBundle];
				if (mainBundle) {
					NSArray *groupList = [mainBundle objectForInfoDictionaryKey:kProPlugPlugIn_GroupList_Property];
					if (groupList) {
						for (NSDictionary *groupInfo in missingGroups) {
							NSString *uuid = groupInfo[kProPlugPlugInX_RegGroupUUIDProperty];
							if (![missingGroups containsObject:uuid]) {
								continue;
							}
							[missingGroups removeObject:uuid];
							[self registerGroup:groupInfo];
						}
					}
				}
			}
		}
		@catch (NSException *exception) {
			if (error) {
				*error = [NSError errorWithDomain:FxPlugErrorDomain
											 code:kFxGripError_Exception
										 userInfo:@{NSLocalizedDescriptionKey:
														[NSString stringWithFormat:@"Error: exception thrown getting group names, reason: %@", exception.reason]}];
			}
		}
	}
	return nil;
}


+ (nonnull NSArray<Class> *)globalRegisteredPluginClasses
{
	NSMutableArray *clss = NSMutableArray.new;
	
	unsigned int numClasses;
	Class *classes = objc_copyClassList(&numClasses);
	
	@try {
		for (int i = 0; i < numClasses; i++) {
			Class currentClass = classes[i];
			
			// Check if class conforms to our protocol
			if ([currentClass conformsToProtocol:@protocol(FxRegisteredPlugin)]) {
				[clss addObject:currentClass];
			}
		}
	}
	@finally {
		free(classes);
	}
	return clss.copy;
}

/**
 	Go through all classes, find the FxRegisteredPlugin, and if active, include it.
 */

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
			*error = [NSError errorWithDomain:FxPlugErrorDomain
										 code:kFxGripError_Exception
									 userInfo:@{NSLocalizedDescriptionKey:
													[NSString stringWithFormat:@"Error: could not get inline registered plugins: %@",
													 exception.reason]}];
		}
	}
	return nil;
}


@end
