//
//  FxTileableEffectBase+Notifications.h
//  FxTileableEffectBase+Notifications
//
//  Created by Apple on 1/7/20.
//  Copyright © 2020-2023 Apple, Inc. All rights reserved.
//

#ifndef FxTileableEffectBase_Parameters_h
#define FxTileableEffectBase_Parameters_h

#import "FxTileableEffectBase.h"


@interface FxTileableEffectBase (FxParameters) <FxParameterFactory>

- (nullable id)parameterForDictionary:(nullable NSDictionary *)data;

- (void)registerParameterType:(nullable Class)paramClass;
- (void)loadTypeToClassMap;
- (FxParameterType)parameterTypeWithString:(nullable NSString *)typeString;
- (nullable NSString *)parameterStringWithType:(FxParameterType)type;
- (nullable Class)parameterClassWithType:(FxParameterType)type;
- (nullable Class)parameterClassWithTypeString:(nullable NSString *)typeString;


@end


#endif
