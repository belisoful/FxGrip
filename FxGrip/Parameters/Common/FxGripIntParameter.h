//
//  FxGripIntParameter.h
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef FxGripIntParameter_h
#define FxGripIntParameter_h

#import "FxParameter.h"


@interface FxGripIntParameter : FxParameter <FxParameterMinMaxInt, FxStateParameter>

+ (nullable NSString*)parameterTypeString;
+ (FxParameterType)parameterType;
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect;

- (int)valueAtTime:(CMTime)renderTime;
- (void)setValue:(int)value atTime:(CMTime)time;
- (void)encodeWithCoder:(NSCoder *_Nonnull)coder;


@end

#endif
