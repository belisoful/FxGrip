//
//  FxGripStaticRegistrar.h
//  XPC Service
//
//  Created on 3/11/24.
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef FxGripStaticRegistrar_h
#define FxGripStaticRegistrar_h

#import <Foundation/Foundation.h>
#import <BEFoundation/BESingleton.h>
#import <PluginManager/PROPlugInBundleRegistration.h>

@protocol FxRegisteringGroups
- (void)registerGroup:(nullable id)inputGroup;
- (void)registerGroups:(nullable id)groups; // NSArray<NSDictionary*>*, or NSDictionary<NSString*, NSDictionary*>.allValues
- (void)registerGroupUUID:(nonnull NSString*)uuid groupName:(nonnull NSString*)groupName;
- (BOOL)containsGroupUUID:(nonnull NSString*)uuid;
@end


@protocol FxRegisteringPlugins <FxRegisteringGroups>
- (BOOL)registerPluginClass:(nonnull Class)pluginClass;
- (BOOL)registerPlugin:(nullable NSDictionary*)plugin;
- (void)registerPlugins:(nullable NSArray<NSDictionary*>*)plugins;
- (BOOL)containsPluginUUID:(nonnull NSString*)uuid;
@end



@protocol FxGripStaticRegistrarSubclass <NSObject>

@optional

- (nullable NSArray<NSDictionary<NSString*, NSString*> *> *)plugInGroupsWithError:(NSError * _Nullable * _Nonnull)error;
- (nullable NSArray<NSDictionary<NSString*, id> *> *)plugInsWithError:(NSError * _Nullable * _Nonnull)error;

// This can be a Class, NSString* (divided by human terms in case of multiple), NSArray<Class | NSString*>, NSDictionary<id [unused], Class | NSString*>
- (nullable id)plugInReferences;

@end




@interface FxGripStaticRegistrar : NSObject <PROPlugInRegistering, FxGripStaticRegistrarSubclass, FxRegisteringPlugins, BESingleton>
{
	NSMutableDictionary<NSString*, NSDictionary*> *__registeredPlugInGroups;
	NSMutableDictionary<NSString*, id> *__registeredPlugIns; //Mutable for OSC Processing
	BOOL				_isLoadable;
}

@property (readonly, retain, nullable) NSArray<NSDictionary<NSString*, NSString*>*> *registeredPlugInGroups;
@property (readonly, retain, nullable) NSArray<NSDictionary<NSString*, id>*>		*registeredPlugIns;
@property (readonly) BOOL															isLoadable;

// PROPlugInRegistering implementation
+ (nonnull id)sharedInstance;

- (BOOL)shouldLoadFirstInstanceOfPlugInWithError:(NSError * _Nullable * _Nonnull)error;

- (nullable NSArray *)registeredPlugInGroupsWithError:(NSError * _Nullable * _Nonnull)error;
- (nullable NSArray *)registeredPlugInsWithError:(NSError * _Nullable * _Nonnull)error;

// DEPRECATED
- (nullable NSArray *)requestedProtocolsWithError:(NSError * _Nullable * _Nonnull)error;

@end


#endif
