//
//  FxGripPathParameter.h
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef FxGripPathParameter_h
#define FxGripPathParameter_h

#import <FxParameter.h>


@interface FxGripPathParameter : FxParameter <FxStateParameter>

+ (nullable NSString*)parameterTypeString;
+ (FxParameterType)parameterType;
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxTileableEffectBase>)effect;

- (FxPathID _Nullable)valueAtTime:(CMTime)renderTime;
- (void)encodeWithCoder:(NSCoder *_Nonnull)coder;

@end

#endif
