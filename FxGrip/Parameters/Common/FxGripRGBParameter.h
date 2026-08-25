//
//  FxGripToggle.h
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef FxGripRGBParameter_h
#define FxGripRGBParameter_h

#import "FxGripColorParameter.h"



@interface FxGripRGBParameter : FxGripColorParameter

@property (readwrite, nonatomic) double alpha;
@property (assign) FxParameterId alphaParameter;

+ (nullable NSString*)parameterTypeString;
+ (FxParameterType)parameterType;
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect;

- (FxGripColor)valueAtTime:(CMTime)renderTime;
- (void)setValue:(FxGripColor*_Nullable)color atTime:(CMTime)time;
- (void)setRedValue:(double)red greenValue:(double)green blueValue:(double)blue alphaValue:(double)alpha atTime:(CMTime)time;
- (void)setRedValue:(double)red greenValue:(double)green blueValue:(double)blue atTime:(CMTime)time;

- (BOOL)validate;

@end


#endif
