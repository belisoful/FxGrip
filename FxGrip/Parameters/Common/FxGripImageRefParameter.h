//
//  FxGripImageRefParameter.h
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef FxGripImageRefParameter_h
#define FxGripImageRefParameter_h

#import "FxParameter.h"


@interface FxGripImageRefParameter : FxParameter

+ (nullable NSString*)parameterTypeString;
+ (FxParameterType)parameterType;
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect;

- (BOOL)includeFilters;

// TimingAPI_v4
- (CMTime)startTime;
- (CMTime)durationTime;

@end

#endif
