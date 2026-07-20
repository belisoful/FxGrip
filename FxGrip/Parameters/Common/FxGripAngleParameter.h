//
//  FxGripToggle.h
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef FxGripAngleParameter_h
#define FxGripAngleParameter_h

#import <FxGripFloatParameter.h>


@interface FxGripAngleParameter : FxGripFloatParameter

+ (nullable NSString*)parameterTypeString;
+ (FxParameterType)parameterType;
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxTileableEffectBase>)effect;

@end

#endif
