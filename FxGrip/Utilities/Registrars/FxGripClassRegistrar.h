/*!
	@file       FxGripClassRegistrar.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripClassRegistrar
	@abstract   The registrar that reads the plugin class list from the host bundle's Info.plist.
	@discussion Introduced in FxGrip 0.1.0. The class reads the FxGripRegisteredPlugins key from the
	            main bundle and returns its value as the plugin class references to register.
	            FxGripStaticRegistrar accepts the value as an NSString of human-separated class names,
	            an NSArray, or an NSDictionary and registers each named class.
*/

#ifndef FxGripClassRegistrar_h
#define FxGripClassRegistrar_h

/*! The Info.plist key that holds the registrar's plugin class list. */
#ifndef kProPlugPlugInX_FxRegisteredPlugins_Property
	#define kProPlugPlugInX_FxRegisteredPlugins_Property		@"FxGripRegisteredPlugins"
#endif

#import "FxGripStaticRegistrar.h"

/*!
	@class		FxGripClassRegistrar
	@abstract	The static registrar that sources its plugin class references from the host Info.plist.
	@discussion	Introduced in FxGrip 0.1.0. The class supplies plugInReferences from the main bundle's
				FxGripRegisteredPlugins key. The base class resolves and registers the referenced classes.
*/
@interface FxGripClassRegistrar : FxGripStaticRegistrar

/*!
	@method		plugInReferences
	@abstract	Returns the FxGripRegisteredPlugins value from the main bundle.
	@return		The class references as an NSString, NSArray, or NSDictionary, or nil when the key is absent. */
- (nullable id)plugInReferences;

@end


#endif
