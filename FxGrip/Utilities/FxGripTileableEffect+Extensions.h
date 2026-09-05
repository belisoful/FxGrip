//
//  FxGripTileableEffect+Extensions.h
//  Fx3DBox
//
//  Created by Apple on 1/7/20.
//  Copyright © 2020-2023 Apple, Inc. All rights reserved.
//

#ifndef FxGripTileableEffect_Extensions_h
#define FxGripTileableEffect_Extensions_h

#import <Foundation/Foundation.h>
#import <FxPlug/FxPlugSDK.h>
#import "FxGripParameter.h"
#import "FxGripExtension.h"
#import <BEFoundation/NSPriorityNotificationCenter.h>

#import "FxGripTileableEffect.h"

// This is the extension key for the main FxTileableEffect class if it were to implement the FxGripExtension Protocol

@interface FxGripTileableEffect (FxGripExtensionBase)
- (nonnull id)effect;
@end





@interface FxGripTileableEffect (Extensions)


- (nullable NSMutableDictionary<NSString*, id<FxGripExtension>>*)initializeExtensions;

- (nullable NSError*)extensionsFlush;

- (BOOL)hasExtensionProtocol:(Protocol * _Nullable)extensionProtocol;
- (BOOL)hasExtensionClass:(Class _Nullable)extensionClass;
- (BOOL)hasExtensionKey:(NSString*_Nullable)extensionKey;


- (id<FxGripExtension>_Nullable)extensionForProtocol:(Protocol * _Nullable)extensionClass;
- (id<FxGripExtension>_Nullable)extensionForClass:(Class _Nullable)extensionClass;
- (id<FxGripExtension>_Nullable)extensionForKey:(NSString*_Nullable)extensionKey;

- (NSArray<id<FxGripExtension>>* _Nonnull)extensionsForProtocol:(Protocol * _Nullable)extensionClass;
- (NSArray<id<FxGripExtension>>* _Nonnull)extensionsForClass:(Class _Nullable)extensionClass;
- (NSArray<id<FxGripExtension>>* _Nonnull)extensionsForKey:(NSString*_Nullable)extensionKey;

@end

#endif
