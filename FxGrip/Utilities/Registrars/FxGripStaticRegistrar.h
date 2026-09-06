/*!
	@file       FxGripStaticRegistrar.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripStaticRegistrar
	@abstract   The base singleton that registers a plugin's effects and groups with the FxPlug host.
	@discussion Introduced in FxGrip 0.1.0. The class implements PROPlugInRegistering and holds the
	            registered plugin and group records as it builds them. A subclass supplies the source of
	            the records through the FxGripStaticRegistrarSubclass hooks, and the base class validates
	            and stores each record. Registration collects plugins first, then groups, then rewrites
	            any plugin that names an on-screen control so the control lists the plugin as supported.
	            The records are localized and frozen into immutable arrays once registration completes.
*/

#ifndef FxGripStaticRegistrar_h
#define FxGripStaticRegistrar_h

#import <Foundation/Foundation.h>
#import <BEFoundation/BESingleton.h>
#import <PluginManager/PROPlugInBundleRegistration.h>

/*!
	@protocol	FxGripRegisteringGroups
	@abstract	The interface for registering plugin groups with a registrar.
	@discussion	Introduced in FxGrip 0.1.0. A group is registered from a dictionary, a list of
				dictionaries, or an explicit UUID and name pair.
*/
@protocol FxGripRegisteringGroups
/*! @abstract Registers one group from an FxGripPluginGroupData or a group dictionary. */
- (void)registerGroup:(nullable id)inputGroup;
/*! @abstract Registers a list of groups from an array, or a dictionary's values. */
- (void)registerGroups:(nullable id)groups; // NSArray<NSDictionary*>*, or NSDictionary<NSString*, NSDictionary*>.allValues
/*! @abstract Registers one group from an explicit UUID and display name. */
- (void)registerGroupUUID:(nonnull NSString*)uuid groupName:(nonnull NSString*)groupName;
/*! @abstract Returns YES when a group with the UUID is registered. */
- (BOOL)containsGroupUUID:(nonnull NSString*)uuid;
@end


/*!
	@protocol	FxGripRegisteringPlugins
	@abstract	The interface for registering plugins with a registrar, extending group registration.
	@discussion	Introduced in FxGrip 0.1.0. A plugin is registered from a conforming class or from a
				validated plugin dictionary.
*/
@protocol FxGripRegisteringPlugins <FxGripRegisteringGroups>
/*! @abstract Registers a plugin from a class that conforms to FxGripRegisteredPlugin; returns success. */
- (BOOL)registerPluginClass:(nonnull Class)pluginClass;
/*! @abstract Registers one plugin from a dictionary after validating its required entries; returns success. */
- (BOOL)registerPlugin:(nullable NSDictionary*)plugin;
/*! @abstract Registers a list of plugins from an array, or a dictionary's values. */
- (void)registerPlugins:(nullable NSArray<NSDictionary*>*)plugins;
/*! @abstract Returns YES when a plugin with the UUID is registered. */
- (BOOL)containsPluginUUID:(nonnull NSString*)uuid;
@end



/*!
	@protocol	FxGripStaticRegistrarSubclass
	@abstract	The optional hooks a subclass implements to supply the plugin and group records.
	@discussion	Introduced in FxGrip 0.1.0. The base class calls whichever hooks the subclass
				implements and registers the returned records.
*/
@protocol FxGripStaticRegistrarSubclass <NSObject>

@optional

/*! @abstract Returns the subclass's plugin group dictionaries, or nil with an error. */
- (nullable NSArray<NSDictionary<NSString*, NSString*> *> *)plugInGroupsWithError:(NSError * _Nullable * _Nonnull)error;
/*! @abstract Returns the subclass's plugin dictionaries, or nil with an error. */
- (nullable NSArray<NSDictionary<NSString*, id> *> *)plugInsWithError:(NSError * _Nullable * _Nonnull)error;

/*! @abstract Returns plugin class references the base class resolves and registers individually. */
// This can be a Class, NSString* (divided by human terms in case of multiple), NSArray<Class | NSString*>, NSDictionary<id [unused], Class | NSString*>
- (nullable id)plugInReferences;

@end




/*!
	@class		FxGripStaticRegistrar
	@abstract	The singleton registrar that validates and stores a plugin bundle's registration records.
	@discussion	Introduced in FxGrip 0.1.0. The class is the FxPlug host's registration entry point. It
				builds the plugin and group records from the subclass hooks, moves on-screen controls to
				their supporting plugins, and freezes the results into immutable, localized arrays.
*/
@interface FxGripStaticRegistrar : NSObject <PROPlugInRegistering, FxGripStaticRegistrarSubclass, FxGripRegisteringPlugins, BESingleton>
{
	NSMutableDictionary<NSString*, NSDictionary*> *__registeredPlugInGroups;
	NSMutableDictionary<NSString*, id> *__registeredPlugIns; //Mutable for OSC Processing
	BOOL				_isLoadable;
}

/*! @abstract The registered group dictionaries, or nil before registration runs. */
@property (readonly, retain, nullable) NSArray<NSDictionary<NSString*, NSString*>*> *registeredPlugInGroups;
/*! @abstract The registered plugin dictionaries, or nil before registration runs. */
@property (readonly, retain, nullable) NSArray<NSDictionary<NSString*, id>*>		*registeredPlugIns;
/*! @abstract YES when the host should load the first plugin instance from this bundle. */
@property (readonly) BOOL															isLoadable;

/*! @abstract The shared registrar instance. */
// PROPlugInRegistering implementation
+ (nonnull id)sharedInstance;

/*!
	@method		shouldLoadFirstInstanceOfPlugInWithError:
	@abstract	Answers the host's query of whether to load the bundle's first plugin instance.
	@return		The value of isLoadable. */
- (BOOL)shouldLoadFirstInstanceOfPlugInWithError:(NSError * _Nullable * _Nonnull)error;

/*!
	@method		registeredPlugInGroupsWithError:
	@abstract	Returns the registered group dictionaries, building them on first call.
	@param		error	Set to kFxGripError_NoConfigGroups when no groups are registered.
	@return		The localized group dictionaries, or nil when none are registered. */
- (nullable NSArray *)registeredPlugInGroupsWithError:(NSError * _Nullable * _Nonnull)error;

/*!
	@method		registeredPlugInsWithError:
	@abstract	Returns the registered plugin dictionaries, building them on first call.
	@param		error	Set to kFxGripError_NoConfigPlugins when no plugins are registered.
	@return		The localized, immutable plugin dictionaries, or nil when none are registered. */
- (nullable NSArray *)registeredPlugInsWithError:(NSError * _Nullable * _Nonnull)error;

/*! @abstract Deprecated. Returns nil. */
// DEPRECATED
- (nullable NSArray *)requestedProtocolsWithError:(NSError * _Nullable * _Nonnull)error;

@end


#endif
