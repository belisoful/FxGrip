//
//  FxGripConfigRegistrar.h
//  XPC Service
//
//  Created on 3/11/24.
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef FxGripConfigRegistrar_h
#define FxGripConfigRegistrar_h

#import "FxGripStaticRegistrar.h"

@interface FxGripConfigRegistrar : FxGripStaticRegistrar

- (nullable NSArray<NSDictionary*> *)plugInGroupsWithError:(NSError * _Nullable * _Nonnull)error;
- (nullable NSArray<NSDictionary*> *)plugInsWithError:(NSError * _Nullable * _Nonnull)error;

@end


#endif
