//
//  FxGripToggle.h
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef FxGripPercentParameter_h
#define FxGripPercentParameter_h

#import <FxGripFloatParameter.h>


@interface FxGripPercentParameter : FxGripFloatParameter

+ (nullable NSString*)parameterTypeString;
+ (FxParameterType)parameterType;
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxTileableEffectBase>)effect;

@end

#endif
