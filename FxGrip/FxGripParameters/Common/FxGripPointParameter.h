//
//  FxGripPointParameter.h
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef FxGripPointParameter_h
#define FxGripPointParameter_h

#import <FxParameter.h>


@interface FxGripPointParameter : FxParameter <FxStateParameter>

+ (nullable NSString*)parameterTypeString;
+ (FxParameterType)parameterType;
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxTileableEffectBase>)effect;

- (FxGripPoint)valueAtTime:(CMTime)renderTime;
- (void)setValue:(FxGripPoint*_Nullable)value atTime:(CMTime)time;
- (void)setXValue:(double)xValue YValue:(double)yValue atTime:(CMTime)time;
- (void)encodeWithCoder:(NSCoder *_Nonnull)coder;

@end

#endif
