//
//  FxGripDynamicRegistrar.h
//  XPC Service
//
//  Created on 3/11/24.
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef FxRegisteredPlugin_h
#define FxRegisteredPlugin_h

@protocol FxRegisteredPlugin

/**
 Acceptable return results:
 • NSDictionary of Plugin's Data
 • Array of NSDictionary of Plugins' Data
 • NSDictionary of @{
 	@"ProPlugPlugInList": <NSDictinoray of Plugin> | <NSArray of NSDictionary of Plugins>,
 	@"ProPlugPlugInGroupList": <NSDictinoray of group>, | <NSArray of NSDictionary of groups>
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
+ (nonnull id)registeredPlugInInformation:(nonnull id<FxRegisteringGroups> )groupRegistrar;

@optional
+ (BOOL)isRegisteredPlugIn;

//+ (nonnull NSString*)groupUUID;
+ (nonnull NSString *)groupName;
+ (nullable NSString *)groupNameForUUID:(nonnull NSString *)groupUUID;
@end



#endif
