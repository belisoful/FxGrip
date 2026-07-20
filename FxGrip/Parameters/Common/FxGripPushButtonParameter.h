//
//  FxGripToggle.h
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef FxGripPushButtonParameter_h
#define FxGripPushButtonParameter_h

#import <FxParameter.h>


@interface FxGripPushButtonParameter : FxParameter

@property (readonly, nonatomic, nullable) SEL			selector;
@property (readonly, nonatomic, nullable) NSString* 	selectorString;

+ (nullable NSString*)parameterTypeString;
+ (FxParameterType)parameterType;
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxTileableEffectBase>)effect;

@end

#endif
