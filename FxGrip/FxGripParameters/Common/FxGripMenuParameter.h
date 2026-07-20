//
//  FxGripToggle.h
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef FxGripMenuParameter_h
#define FxGripMenuParameter_h

#import <FxGripIntParameter.h>


@interface FxGripMenuParameter : FxGripIntParameter

@property (readonly, nonnull) NSArray<NSString*>* parameterMenuItems;

+ (nullable NSString*)parameterTypeString;
+ (FxParameterType)parameterType;
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxTileableEffectBase>)effect;

@end

#endif
