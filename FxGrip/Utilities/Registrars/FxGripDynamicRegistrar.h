/*!
	@file       FxGripDynamicRegistrar.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripDynamicRegistrar
	@abstract   The registrar that discovers plugins from the Objective-C runtime's loaded classes.
	@discussion Introduced in FxGrip 0.1.0. The class scans every loaded class for conformance to
	            FxGripRegisteredPlugin and registers the matches. It resolves each plugin's group name
	            from the class, then from the host bundle's group list, then from a placeholder. Group
	            discovery follows plugin discovery because a plugin names the group it belongs to.
*/

#ifndef FxGripDynamicRegistrar_h
#define FxGripDynamicRegistrar_h

#import "FxGripStaticRegistrar.h"
#import "FxGripRegisteredPlugin.h"


/*!
	@class		FxGripDynamicRegistrar
	@abstract	The static registrar that finds conforming plugin classes by runtime introspection.
	@discussion	Introduced in FxGrip 0.1.0. The class registers every loaded FxGripRegisteredPlugin class
				and fills in the groups those plugins reference.
*/
@interface FxGripDynamicRegistrar : FxGripStaticRegistrar

/*!
	@method     globalRegisteredPluginClasses
	@abstract   Returns every loaded class that conforms to FxGripRegisteredPlugin.
	@discussion Scans the Objective-C runtime's full class list, including superclass
				conformance. Uses runtime introspection functions rather than message
				sends, so classes that cannot receive messages are skipped safely.
*/
+ (nonnull NSArray<Class> *)globalRegisteredPluginClasses;

/*!
	@method		plugInGroupsWithError:
	@abstract	Resolves and registers a group name for every group a registered plugin references.
	@param		error	Set when an exception is caught while resolving names.
	@return		nil; groups are registered as a side effect through the base registrar.
	@discussion	Introduced in FxGrip 0.1.0. A group name is taken from the plugin class, then from the
				host bundle's group list, then from a numbered placeholder. */
- (nullable NSArray *) plugInGroupsWithError:(NSError * _Nullable * _Nonnull)error;

/*!
	@method		plugInsWithError:
	@abstract	Registers every loaded class that conforms to FxGripRegisteredPlugin.
	@param		error	Set when an exception is caught during registration.
	@return		nil; plugins are registered as a side effect through the base registrar.
	@discussion	Introduced in FxGrip 0.1.0. */
- (nullable NSArray *) plugInsWithError:(NSError * _Nullable * _Nonnull)error;

@end


#endif
