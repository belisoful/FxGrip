/// @deprecated Legacy GuruFx implementation retained only for the final merge into the
/// new FxGrip implementations. Do not modify or extend; names intentionally unchanged.

//
//  GuruFxTileableEffect+Extensions.h
//  MetalFx ML Upscale
//
//  Created by ~ ~ on 2/27/24.
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef GuruFxTileableEffect_Extensions_h
#define GuruFxTileableEffect_Extensions_h

#import <Foundation/Foundation.h>
#import <FxTileableEffectBase.h>
//#import "FxExtension.h"

#define __INT32_MIN__ (-2147483648)	// 0x80000000


#define kExtensionsLoadName					((NSNotificationName) NSStringFromSelector(@selector(extLoadWithEffect:)))
#define kExtensionsInitName					((NSNotificationName) NSStringFromSelector(@selector(extInit)))
#define kExtensionsProcessParametersName	((NSNotificationName) NSStringFromSelector(@selector(extProcessParameters:)))
#define kExtensionsAddParameterName			((NSNotificationName) NSStringFromSelector(@selector(extAddParameter:)))
#define kExtensionsFinishInitialSetupName	((NSNotificationName) NSStringFromSelector(@selector(extFinishInitialSetup)))
#define kExtensionsAddedToDocumentName		((NSNotificationName) NSStringFromSelector(@selector(extAddedToDocument)))

#define kExtensionsGetParameterTypeName		((NSNotificationName) NSStringFromSelector(@selector(extGetParameterType:)))

#define kExtensionsParameterGetFlagsName		((NSNotificationName) NSStringFromSelector(@selector(extGetParameterFlags:fromParameter:)))
#define kExtensionsParameterSetFlagsPreName		((NSNotificationName) NSStringFromSelector(@selector(extSetParameterFlagsPre:toParameter:)))
#define kExtensionsParameterSetFlagsName		((NSNotificationName) NSStringFromSelector(@selector(extSetParameterFlags:toParameter:)))

#define kExtensionsGetParameterNameName		((NSNotificationName) NSStringFromSelector(@selector(extGetParameterName:fromParameter:)))
#define kExtensionsSetParameterNamePreName		((NSNotificationName) NSStringFromSelector(@selector(extSetParameterNamePre:toParameter:)))
#define kExtensionsSetParameterNameName		((NSNotificationName) NSStringFromSelector(@selector(extSetParameterName:toParameter:)))

#define kExtensionsGetParameterStringValueName		((NSNotificationName) NSStringFromSelector(@selector(extGetParameterStringValue:fromParameter:)))
#define kExtensionsSetParameterStringValuePreName	((NSNotificationName) NSStringFromSelector(@selector(extSetParameterStringValuePre:toParameter:)))

#define kExtensionsGetParameterMenuName		((NSNotificationName) NSStringFromSelector(@selector(extGetParameterMenu:fromParameter:)))
#define kExtensionsSetParameterMenuItemPreName		((NSNotificationName) NSStringFromSelector(@selector(extSetParameterMenuItemPre:toParameter:)))
#define kExtensionsSetParameterMenuName		((NSNotificationName) NSStringFromSelector(@selector(extSetParameterMenu:defaultValue:toParameter:)))


#define kExtensionsParameterChangedName		((NSNotificationName) NSStringFromSelector(@selector(extParameterChanged:atTime:error:)))

#define kExtensionsRemoveParameterName			((NSNotificationName) NSStringFromSelector(@selector(extRemoveParameter:)))

#define kExtensionsFlushName				((NSNotificationName) NSStringFromSelector(@selector(extFlush)))

#define kExtensionsRenderDestinationImageName		((NSNotificationName) NSStringFromSelector(@selector(extRenderDestinationImage:sourceImages:pluginState:atTime:error:)))

#define kExtensionsRemovedFromDocumentName	((NSNotificationName) NSStringFromSelector(@selector(extRemovedFromDocument)))
#define kExtensionsUnloadName				((NSNotificationName) NSStringFromSelector(@selector(extUnload)))

#define kExtensionsParameterTypeForStringName				((NSNotificationName) NSStringFromSelector(@selector(extParameterTypeForString:)))
#define kExtensionsParameterClassForTypeName				((NSNotificationName) NSStringFromSelector(@selector(extParameterClassForType:)))


#define kExtensionsReturnValueName			(@"_return")
#define kExtensionsParameter0Name			(@"_parameter0")
#define kExtensionsParameter1Name			(@"_parameter1")
#define kExtensionsParameter2Name			(@"_parameter2")
#define kExtensionsParametersValueName		(@"_parameters")
#define kExtensionsParameterValueName		(@"_parameter")
#define kExtensionsParameterFlagsName		(@"_flags")
#define kExtensionsParameterNameName		(@"_name")
#define kExtensionsMenuEntryName			(@"_entry")
#define kExtensionsMenuEntriesName			(@"_entries")
#define kExtensionsDefaultName				(@"_default")
#define kExtensionsParameterIDName			(@"_parameterID")
#define kExtensionsAtTimeName				(@"_atTime")
#define kExtensionsErrorName				(@"_error")


@interface GuruFxTileableEffect (Extensions)

@property (readonly) UInt32 extensionCount;
@property (readonly) NSArray<id<FxExtension>>* _Nonnull extensions;

// All subclasses should implement this if they want to load custom extensions.
-(NSMutableArray<id<FxExtension>>* _Nonnull) loadExtensions;

- (void)extensionsInit;
- (void)extensionsProcessParameters:(NSMutableArray*_Nonnull)parameters;
- (BOOL)extensionsAddParameter:(nonnull id<FxParameter>)parameter;
- (BOOL)extensionsFinishInitialSetup;
- (void)extensionsAddedToDocument;

- (FxParameterType)extensionsGetParameterType:(FxParameterId)parameterID;

- (BOOL)extensionsGetParameterFlags:(FxParameterFlags*_Nonnull)flags fromParameter:(FxParameterId)parameterID;
- (void)extensionsSetParameterFlagsPre:(FxParameterFlags*_Nonnull)flags toParameter:(FxParameterId)parameterID;
- (void)extensionsSetParameterFlags:(FxParameterFlags)flags toParameter:(FxParameterId)parameterID;

- (NSError*_Nullable)extensionsGetParameterName:(NSString*_Nonnull*_Nonnull)name  fromParameter:(FxParameterId)parameterID;
- (void)extensionsSetParameterNamePre:(NSString*_Nonnull*_Nonnull)name  toParameter:(FxParameterId)parameterID;
- (void)extensionsSetParameterName:(NSString*_Nonnull)name  toParameter:(FxParameterId)parameterID;

- (NSError*_Nullable)extensionsGetParameterStringValue:(NSString*_Nonnull*_Nonnull)value  fromParameter:(FxParameterId)parameterID;
- (void)extensionsSetParameterStringValuePre:(NSString*_Nonnull*_Nonnull)value toParameter:(FxParameterId)parameterID;

- (NSError*_Nullable)extensionsGetParameterMenu:(NSArray<NSString*>*_Nullable*_Nonnull)entries fromParameter:(FxParameterId)parameterID;
- (void)extensionsSetParameterMenuItemPre:(NSString*_Nonnull*_Nonnull)name  toParameter:(FxParameterId)parameterID;
- (void)extensionsSetParameterMenu:(NSArray<NSString*>*_Nonnull)newEntries defaultValue:(UInt32)defaultIndex toParameter:(FxParameterId)parameterID;

- (void)extensionsRemoveParameter:(FxParameterId)parameterID;


- (void)extensionsParameterChanged:(FxParameterId)paramID
							atTime:(CMTime)time
							 error:(NSError * _Nullable * _Nullable)error;

- (void)extensionsFlush;


- (BOOL)extensionsRender:(FxImageTile *_Nonnull)destinationImage
			sourceImages:(NSArray<FxImageTile *> *_Nullable)sourceImages
			 pluginState:(id _Nullable)pluginState
				  atTime:(CMTime)renderTime
				   error:(NSError *_Nullable *_Nullable)outError;

//- (void)extensionsBroadcastName:(NSNotificationName _Nullable)aName object:(id _Nullable )anObject;
//- (void)extensionsBroadcastName:(NSNotificationName _Nullable)aName object:(id _Nullable )anObject userInfo:(NSDictionary *_Nullable)aUserInfo;

- (void)extensionsRemovedFromDocument;
- (void)extensionsUnload;

- (FxParameterType)extensionParameterTypeForString:(nullable NSString *)typeString;
- (nullable Class)extensionParameterClassForType:(FxParameterType)type;


- (BOOL)hasExtensionProtocol:(Protocol * _Nullable)extensionProtocol;
- (BOOL)hasExtensionClass:(Class _Nullable)extensionClass;
- (BOOL)hasExtensionKey:(NSString*_Nullable)extensionKey;


-(id<FxExtension>_Nullable)extensionForProtocol:(Protocol * _Nullable)extensionClass;
-(id<FxExtension>_Nullable)extensionForClass:(Class _Nullable)extensionClass;
-(id<FxExtension>_Nullable)extensionForKey:(NSString*_Nullable)extensionKey;

-(NSArray<id<FxExtension>>* _Nonnull)extensionsForProtocol:(Protocol * _Nullable)extensionClass;
-(NSArray<id<FxExtension>>* _Nonnull)extensionsForClass:(Class _Nullable)extensionClass;
-(NSArray<id<FxExtension>>* _Nonnull)extensionsForKey:(NSString*_Nullable)extensionKey;

@end




// Methods for GuruFxExtension
@interface GuruFxTileableEffect (GuruFxExtension) <NSNotificationObjectPriorityItem>

- (GuruFxTileableEffect*_Nonnull)effect;
- (NSString*_Nonnull)extKey;
- (NSInteger)ncPriority:(nullable NSNotificationName)aName;
- (void)setExtActive:(BOOL)active;
- (BOOL)extLoadWithEffect:(GuruFxTileableEffect* _Nonnull) effect;
// If the subclass has @protocol(GuruFxExtensionProtocol) this will add the optional methods
//	to the effect notification center.

@end



#endif
