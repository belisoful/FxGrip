//
//  FxGripToggle.h
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef FxGripFloatParameter_h
#define FxGripFloatParameter_h

#import "FxParameter.h"


@interface FxGripFloatParameter : FxParameter <FxStateParameter>

+ (nullable NSString*)parameterTypeString;
+ (FxParameterType)parameterType;
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect;

- (double)valueAtTime:(CMTime)renderTime;
- (void)setValue:(double)value atTime:(CMTime)time;
- (void)encodeWithCoder:(NSCoder *_Nonnull)coder;

@end

#endif
