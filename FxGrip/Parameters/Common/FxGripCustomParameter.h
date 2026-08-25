//
//  FxGripCustomParameter.h
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef FxGripCustomParameter_h
#define FxGripCustomParameter_h

#import "FxParameter.h"

@protocol FxGripCustomParameter <FxParameter>
@property (readonly) NSSet<Class> * _Nonnull dataClasses;

- (id<NSSecureCoding, NSCopying> _Nullable)value;
- (id<NSSecureCoding, NSCopying> _Nullable)valueAtTime:(CMTime)renderTime;
- (void)setValue:(id<NSSecureCoding, NSCopying> _Nullable)value;
- (void)setValue:(id<NSSecureCoding, NSCopying> _Nullable)value atTime:(CMTime)renderTime;

@end



@interface FxGripCustomParameter :
FxParameter <FxGripCustomParameter, FxStateParameter>

-(instancetype _Nullable) initWithDictionary:(NSDictionary*_Nonnull)dictionary effect:(id<FxGripEffectHost>_Nonnull)effect;

+ (nullable NSString*)parameterTypeString;
+ (FxParameterType)parameterType;
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect;

- (id<NSSecureCoding, NSCopying> _Nullable)value;
- (id<NSSecureCoding, NSCopying> _Nullable)valueAtTime:(CMTime)renderTime;
- (void)setValue:(id<NSSecureCoding, NSCopying> _Nullable)value;
- (void)setValue:(id<NSSecureCoding, NSCopying> _Nullable)value atTime:(CMTime)renderTime;

- (void)encodeWithCoder:(NSCoder *_Nonnull)coder;

@end

#endif
