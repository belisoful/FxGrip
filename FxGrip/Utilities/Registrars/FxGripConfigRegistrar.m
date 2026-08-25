
#import "FxGripConfigRegistrar.h"
#import "FxGripPluginInfo.h"


/*!
 	This mimics non-dynamic registration but dynamically
 */

@implementation FxGripConfigRegistrar

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
