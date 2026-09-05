//
//  FxGripHistogramParameter.h
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef FxGripHistogramParameter_h
#define FxGripHistogramParameter_h

#import "FxGripParameter.h"


@interface FxGripHistogramParameter : FxGripParameter <FxGripStateParameter>

+ (nullable NSString*)parameterTypeString;
+ (FxParameterType)parameterType;
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect;

- (FxGripHistogram*_Nullable)valueAtTime:(CMTime)renderTime;
- (void)encodeWithCoder:(NSCoder *_Nonnull)coder;

@end

#endif
