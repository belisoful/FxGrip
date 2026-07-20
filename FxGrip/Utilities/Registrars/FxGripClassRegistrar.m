
#import "FxGripClassRegistrar.h"
#import "FxGripPluginInfo.h"


/*!
 Within the mainBundle, the property `FxRegisteredPlugins` contains the list of plugin effect classes via `NSString*` (human separated), NSArray, or NSDictionary values.
 */

@implementation FxGripClassRegistrar

- (nullable id)plugInReferences
{
	NSBundle *mainBundle = [NSBundle mainBundle];
	
	return [mainBundle objectForInfoDictionaryKey:kProPlugPlugInX_FxRegisteredPlugins_Property];
}

@end
