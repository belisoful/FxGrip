//
//  FxTileableEffectBase+Extensions.h
//  Fx3DBox
//
//  Created by Apple on 1/7/20.
//  Copyright © 2020-2023 Apple, Inc. All rights reserved.
//

#ifndef FxTileableEffectBase_Extensions_h
#define FxTileableEffectBase_Extensions_h

#import <Foundation/Foundation.h>
#import <FxPlug/FxPlugSDK.h>
#import <FxParameter.h>
#import "FxExtension.h"
#import <BEFoundation/NSPriorityNotificationCenter.h>

#import <FxTileableEffectBase.h>

// This is the extension key for the main FxTileableEffect class if it were to implement the FxExtension Protocol

@interface FxTileableEffectBase (FxExtensionBase)
- (nonnull id)effect;
@end





@interface FxTileableEffectBase (Extensions)


- (nullable NSMutableDictionary<NSString*, id<FxExtension>>*)initializeExtensions;

- (nullable NSError*)extensionsFlush;

- (BOOL)hasExtensionProtocol:(Protocol * _Nullable)extensionProtocol;
- (BOOL)hasExtensionClass:(Class _Nullable)extensionClass;
- (BOOL)hasExtensionKey:(NSString*_Nullable)extensionKey;


- (id<FxExtension>_Nullable)extensionForProtocol:(Protocol * _Nullable)extensionClass;
- (id<FxExtension>_Nullable)extensionForClass:(Class _Nullable)extensionClass;
- (id<FxExtension>_Nullable)extensionForKey:(NSString*_Nullable)extensionKey;

- (NSArray<id<FxExtension>>* _Nonnull)extensionsForProtocol:(Protocol * _Nullable)extensionClass;
- (NSArray<id<FxExtension>>* _Nonnull)extensionsForClass:(Class _Nullable)extensionClass;
- (NSArray<id<FxExtension>>* _Nonnull)extensionsForKey:(NSString*_Nullable)extensionKey;

@end

#endif
