/*!
	@file       FxGripRegisteredPlugin.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripRegisteredPlugin
	@abstract   The protocol a class adopts to declare itself as an FxGrip-registrable plugin.
	@discussion Introduced in FxGrip 0.1.0. The dynamic registrar discovers every loaded class that
	            conforms to this protocol and asks it for its registration information. A conforming
	            class returns its plugin and group records and may report activation state and group
	            names. FxGripDynamicRegistrar drives the discovery.
*/

#ifndef FxGripRegisteredPlugin_h
#define FxGripRegisteredPlugin_h

/*!
	@protocol	FxGripRegisteredPlugin
	@abstract	Marks a class as a plugin the registrar discovers and registers by runtime introspection.
	@discussion	Introduced in FxGrip 0.1.0. The registrar reads the class's plugin and group records
				through registeredPlugInInformation:. The optional methods report whether the plugin is
				active and supply group names.
*/
@protocol FxGripRegisteredPlugin

/**
 Acceptable return results:
 • NSDictionary of Plugin's Data
 • Array of NSDictionary of Plugins' Data
 • NSDictionary of @{
 	@"ProPlugPlugInList": <NSDictionary of Plugin> | <NSArray of NSDictionary of Plugins>,
 	@"ProPlugPlugInGroupList": <NSDictionary of group>, | <NSArray of NSDictionary of groups>
 	}
 
 	// kProPlugPlugInList_Property and kProPlugPlugInGroupList_Property are the constants
 	// Type definitions:
 	Group = @{@"uuid": <group uuid>, @"groupName": <NSString of group Name>}
 
	Plugin = @{
 		@"uuid": <plugin uuid>,
 		@"className": <NSString of Class Name>,
 		@"displayName": <NSString for Display Name>,
 		@"group": <NSString uuid of the group containing the plugin>,
 		@"protocolNames": <NSArray for Fx Protocols: FxBaseEffect, FxFilter, FxGenerator, FxOnScreenControl>,
 		@"infoString": <NSString for the description of the plugin>,
 		@"version": <NSNumber integer version of the plugin, use 1000 for v1.0.0.0>,
 
 //FxGrip Extension configurations (optional)
 		@"defaultFontName": <NSString the default font name if a parameter default font is not specified>,
 		@"presets": <Presets of the plugin>,
 		@"priorUuids": <NSArray all the prior UUID of the plugin>,
 		@"effectProperties": <NSDictionary of effect properties, like remap, change output size, draw in screen space, needs full buffer, varies when static, nonmatching textures, processing color info, pixel transformation support>
 
 //		Combined Group Name
 		@"groupName": <NSString of group Name>
 	}
 */
/*!
	@method		registeredPlugInInformation:
	@abstract	Returns the plugin's registration records for the registrar to install.
	@param		groupRegistrar	The registrar the class may call to register groups directly.
	@return		A plugin dictionary, an array of plugin dictionaries, or a dictionary that carries the
				plugin and group lists under their kProPlugPlugIn keys. */
+ (nonnull id)registeredPlugInInformation:(nonnull id<FxGripRegisteringGroups> )groupRegistrar;

@optional
/*! @abstract Returns NO to exclude the class from registration; a class that omits it is registered. */
+ (BOOL)isRegisteredPlugIn;

//+ (nonnull NSString*)groupUUID;
/*! @abstract Returns the plugin's group display name. */
+ (nonnull NSString *)groupName;
/*! @abstract Returns the display name for a given group UUID, or nil when the class does not own it. */
+ (nullable NSString *)groupNameForUUID:(nonnull NSString *)groupUUID;
@end



#endif
