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

// TimingAPI_v5
/*! YES when the image well's clip requires drop-frame timecode. Motion always reports NO; a
	Motion template running in Final Cut Pro reports the clip setting. NO on hosts without
	FxTimingAPI_v5. Introduced in FxGrip 1.0. */
- (BOOL)isDropFrame;

@end

#endif
