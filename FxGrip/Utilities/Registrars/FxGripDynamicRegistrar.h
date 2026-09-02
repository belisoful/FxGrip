//
//  FxGripDynamicRegistrar.h
//  XPC Service
//
//  Created on 3/11/24.
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef FxGripDynamicRegistrar_h
#define FxGripDynamicRegistrar_h

#import "FxGripStaticRegistrar.h"
#import "FxGripRegisteredPlugin.h"


@interface FxGripDynamicRegistrar : FxGripStaticRegistrar

/*!
	@method     globalRegisteredPluginClasses
	@abstract   Returns every loaded class that conforms to FxGripRegisteredPlugin.
	@discussion Scans the Objective-C runtime's full class list, including superclass
				conformance. Uses runtime introspection functions rather than message
				sends, so classes that cannot receive messages are skipped safely.
*/
+ (nonnull NSArray<Class> *)globalRegisteredPluginClasses;

- (nullable NSArray *) plugInGroupsWithError:(NSError * _Nullable * _Nonnull)error;
- (nullable NSArray *) plugInsWithError:(NSError * _Nullable * _Nonnull)error;

@end


#endif
