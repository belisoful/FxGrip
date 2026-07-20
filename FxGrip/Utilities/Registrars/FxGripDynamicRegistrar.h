//
//  FxGripDynamicRegistrar.h
//  XPC Service
//
//  Created on 3/11/24.
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef FxGripDynamicRegistrar_h
#define FxGripDynamicRegistrar_h

#import <FxGripStaticRegistrar.h>
#import <FxRegisteredPlugin.h>


@interface FxGripDynamicRegistrar : FxGripStaticRegistrar

+ (nonnull NSArray<Class> *)globalRegisteredPluginClasses;

- (nullable NSArray *) plugInGroupsWithError:(NSError * _Nullable * _Nonnull)error;
- (nullable NSArray *) plugInsWithError:(NSError * _Nullable * _Nonnull)error;

@end


#endif
