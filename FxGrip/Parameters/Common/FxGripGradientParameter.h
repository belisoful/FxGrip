//
//  FxGripGradientParameter.h
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef FxGripGradientParameter_h
#define FxGripGradientParameter_h

#import "FxGripParameter.h"
#import <FxPlug/FxTypes.h>


@interface FxGripGradientParameter : FxGripParameter <FxGripStateParameter>

@property (readwrite, assign) FxDepth	fxDepth;
@property (readwrite, assign) uint		byteDepth;
@property (readwrite, assign) uint		samples;

+ (nullable NSString*)parameterTypeString;
+ (FxParameterType)parameterType;
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect;

- (FxGripGradient*_Nullable)valueAtTime:(CMTime)renderTime NS_RETURNS_INNER_POINTER;
- (void)encodeWithCoder:(NSCoder *_Nonnull)coder;


@end


@interface NSCoder (FxGripGradient)

- (nullable FxGripGradient *)decodeGradientAtIndex:(int64_t)index NS_RETURNS_INNER_POINTER;

// A MTLTexture that is 1 pixel in height and number of Samples in width
- (nullable id<MTLTexture>) decodeGradientAtIndex:(int64_t)index device:(nonnull id<MTLDevice>)device NS_RETURNS_RETAINED;

@end

#endif
