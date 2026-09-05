//
//  FxGripToggleParameter.h
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef FxGripToggleParameter_h
#define FxGripToggleParameter_h

#import "FxGripParameter.h"

@protocol FxGripToggleParameter <FxGripParameter>

+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect;

- (BOOL)valueAtTime:(CMTime)renderTime;
- (void)setValue:(BOOL)value atTime:(CMTime)time;

//  Sets at Time Zero
@property (readwrite, nonatomic) BOOL boolValue;

- (void)encodeWithCoder:(NSCoder *_Nonnull)coder;

@end


@interface FxGripToggleParameter : FxGripParameter <FxGripToggleParameter, FxGripStateParameter>

+ (nullable NSString*)parameterTypeString;
+ (FxParameterType)parameterType;
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect;

- (BOOL)valueAtTime:(CMTime)renderTime;
- (void)setValue:(BOOL)value atTime:(CMTime)time;

//  Sets at Time Zero
- (BOOL)boolValue;
- (void)setBoolValue:(BOOL)value;

- (void)encodeWithCoder:(NSCoder *_Nonnull)coder;

@end

#endif
