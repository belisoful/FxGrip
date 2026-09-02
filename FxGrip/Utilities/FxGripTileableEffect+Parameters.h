//
//  FxGripTileableEffect+Notifications.h
//  FxGripTileableEffect+Notifications
//
//  Created by Apple on 1/7/20.
//  Copyright © 2020-2023 Apple, Inc. All rights reserved.
//

#ifndef FxGripTileableEffect_Parameters_h
#define FxGripTileableEffect_Parameters_h

#import "FxGripTileableEffect.h"


@interface FxGripTileableEffect (FxParameters) <FxParameterFactory>

- (nullable id)parameterForDictionary:(nullable NSDictionary *)data;

- (void)registerParameterType:(nullable Class)paramClass;
- (void)loadTypeToClassMap;
- (FxParameterType)parameterTypeWithString:(nullable NSString *)typeString;
- (nullable NSString *)parameterStringWithType:(FxParameterType)type;
- (nullable Class)parameterClassWithType:(FxParameterType)type;
- (nullable Class)parameterClassWithTypeString:(nullable NSString *)typeString;


@end


#endif
