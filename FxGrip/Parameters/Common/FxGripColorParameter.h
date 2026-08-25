//
//  FxGripColorParameter.h
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef FxGripColorParameter_h
#define FxGripColorParameter_h

#import "FxParameter.h"


@interface FxGripColorParameter : FxParameter <FxStateParameter>

@property (readwrite, nonatomic) BOOL flagDontRemapColors;

+ (nullable NSString*)parameterTypeString;
+ (FxParameterType)parameterType;
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect;

- (FxGripColor)valueAtTime:(CMTime)renderTime;
- (void)setValue:(FxGripColor*_Nullable)color atTime:(CMTime)time;
- (void)setRedValue:(double)red greenValue:(double)green blueValue:(double)blue alphaValue:(double)alpha atTime:(CMTime)time;
- (void)setRedValue:(double)red greenValue:(double)green blueValue:(double)blue atTime:(CMTime)time;
- (void)encodeWithCoder:(NSCoder *_Nonnull)coder;

@end

#endif
