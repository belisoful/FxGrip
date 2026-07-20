//
//  FxGripFontMenuParameter.h
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef FxGripFontMenuParameter_h
#define FxGripFontMenuParameter_h

#import <FxGripStringParameter.h>


@interface FxGripFontMenuParameter : FxGripStringParameterBase

+ (nullable NSString*)parameterTypeString;
+ (FxParameterType)parameterType;
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxTileableEffectBase>)effect;

-(NSString*_Nullable) valueAtTime:(CMTime)renderTime;

@end

#endif
