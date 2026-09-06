/*!
	@file       FxGripConfigRegistrar.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripConfigRegistrar
	@abstract   Implements the registrar that reads plugin and group lists from the host Info.plist.
	@discussion Introduced in FxGrip 0.1.0. Each accessor reads its list from the main bundle and reports
	            an absent list through the error argument.
*/

#import "FxGripConfigRegistrar.h"
#import "FxGripPluginInfo.h"


/*!
	@abstract	The static registrar that reproduces the host's plist registration from bundle values.
	@discussion	Introduced in FxGrip 0.1.0. The class reads the plugin and group lists from the main
				bundle so the base class registers them.
*/
@implementation FxGripConfigRegistrar

/*!
	@method		plugInGroupsWithError:
	@abstract	Returns the plugin group dictionaries from the main bundle, or nil with an error when absent.
	@discussion	Introduced in FxGrip 0.1.0. A missing key sets kFxGripError_NoConfigGroups. */
- (nullable NSArray<NSDictionary*> *)plugInGroupsWithError:(NSError * _Nullable * _Nonnull)error
{
	NSBundle *mainBundle = [NSBundle mainBundle];
	
	NSArray<NSDictionary*> *groups = [mainBundle objectForInfoDictionaryKey:kProPlugPlugIn_GroupList_Property];
	
	if (!groups) {
#if DEBUG
			NSLog(@"Error: %@::%s no groups found.", self.className, __func__);
#endif
		if (error) {
			*error = [NSError errorWithDomain:FxGripPlugErrorDomain
										 code:kFxGripError_NoConfigGroups
									 userInfo:nil];
		}
	}
	
	return groups;
}


/*!
	@method		plugInsWithError:
	@abstract	Returns the plugin dictionaries from the main bundle, or nil with an error when absent.
	@discussion	Introduced in FxGrip 0.1.0. A missing key sets kFxGripError_NoConfigPlugins. */
- (nullable NSArray<NSDictionary*> *)plugInsWithError:(NSError * _Nullable * _Nonnull)error
{
	NSBundle *mainBundle = [NSBundle mainBundle];

	NSArray<NSDictionary*> *plugins =  [mainBundle objectForInfoDictionaryKey:kProPlugPlugInList_Property];
	
	if (!plugins) {
#if DEBUG
			NSLog(@"Error: %@::%s no plugins found.", self.className, __func__);
#endif
		if (error) {
			*error = [NSError errorWithDomain:FxGripPlugErrorDomain
										 code:kFxGripError_NoConfigPlugins
									 userInfo:nil];
		}
	}
	
	return plugins;
}

@end
