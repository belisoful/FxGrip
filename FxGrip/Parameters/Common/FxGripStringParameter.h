//
//  FxGripToggle.h
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef FxGripStringParameter_h
#define FxGripStringParameter_h

#import "FxGripParameter.h"


@interface FxGripStringParameterBase : FxGripParameter <FxGripStateParameter>

+ (nullable NSString*)parameterTypeString;
+ (FxParameterType)parameterType;

- (nullable NSString*)valueAtTime:(CMTime)renderTime;
- (void)setValue:(NSString*_Nullable)value atTime:(CMTime)time;

@property (readwrite, nullable, nonatomic) NSString* stringValue;

- (void)encodeWithCoder:(NSCoder *_Nonnull)coder;

@end

//
@interface FxGripStringParameter : FxGripStringParameterBase //NSSecureCoding NSCopying

+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect;

@end

#endif
