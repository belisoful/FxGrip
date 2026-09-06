/*!
	@file       FxGripClassRegistrar.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripClassRegistrar
	@abstract   Implements the registrar that reads its plugin class list from the host Info.plist.
	@discussion Introduced in FxGrip 0.1.0. The class returns the FxGripRegisteredPlugins value from the
	            main bundle so the base class registers the named plugin effect classes.
*/

#import "FxGripClassRegistrar.h"
#import "FxGripPluginInfo.h"


/*!
	@abstract	The registrar that sources plugin class references from the host bundle's Info.plist.
	@discussion	Introduced in FxGrip 0.1.0. Within the main bundle, the FxGripRegisteredPlugins property
				holds the plugin effect classes as an NSString of human-separated names, an NSArray, or
				an NSDictionary of values.
*/
@implementation FxGripClassRegistrar

- (nullable id)plugInReferences
{
	NSBundle *mainBundle = [NSBundle mainBundle];
	
	return [mainBundle objectForInfoDictionaryKey:kProPlugPlugInX_FxRegisteredPlugins_Property];
}

@end
