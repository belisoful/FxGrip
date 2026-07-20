//
//  MetalFx_ML_UpscalePlugIn.h
//  MetalFx ML Upscale
//
//  Created by ~ ~ on 2/27/24.
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef FxTileableEffectBase_Timing_h
#define FxTileableEffectBase_Timing_h

#import <Foundation/Foundation.h>
#import <FxPlug/FxPlugSDK.h>
#import <FxTileableEffectBase.h>

#define kWatchInputStartTime	(1 << 0)
#define kWatchInputDuration		(1 << 1)
#define kWatchFPSChange			(1 << 2)

/*
 @link https://developer.apple.com/documentation/professional-video-applications/understanding-time-in-fxplug?language=objc
 
   0.0s                                                        0.5s
  0:00:00            0:00:05             0:00:10             0:00:15
    |                   |                   |                   |
 ---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
 
 
 ** Place:
 frameDuration
 sampleDuration
 startTimeForEffect
 duractioTimeForEffect
 startTimeOfInputToFilter
 duractionTimeOfInputToFilter
 inPointTimeOfTimelineForEffect
 outPutTimeOfTimelineForEffect
 
 FpsNumeratorForEffect
 FpSDenominatorForEffect
	
 
 */

// In a float, at 8388608, a 1 bit change in mantissa results in ~1.0f change in the number.
// In a double, at 4503599627370496, a 1 bit change in mantissa results in ~1.0f change in the number.
inline long long floorWithError(double value, double epsilon);

inline long long floorWithNearest(double value);



@interface FxTileableEffectBase (Timing)
{
	@protected
}

// Time Utilities
- (CMTime)frameDuration;
- (Float64)retimingSpeed;

- (CMTime)sampleDuration;
- (BOOL)isInterlacedClip;

- (CMTime)effectStartTime;
- (NSInteger)effectStartFrame;
- (CMTime)effectStartTimeInTimeline;
- (CMTime)effectDurationTime;
- (NSInteger)effectDurationFrames;

- (CMTime)inputStartTime;
- (NSInteger)inputStartFrame;
- (CMTime)inputStartTimeInTimeline;
- (CMTime)inputDurationTime;
- (NSInteger)inputDurationFrames;

- (CMTime)effectInPointOfTimeLine;
- (CMTime)effectOutPointOfTimeLine;

- (NSUInteger)timelineFpsNumerator;
- (NSUInteger)timelineFpsDenominator;

- (CMTime)timelineFrameDuration;
- (Float64)timelineFrameDurationFloat;
- (CMTime)timelineFrameRate;
- (Float64)timelineFps;

- (NSInteger)frameForTime:(CMTime)time;

- (void)timelineTime:(nonnull CMTime*)timelineTime fromInputTime:(CMTime)time;
- (void)inputTime:(nonnull CMTime*)inputTime fromTimelineTime:(CMTime)time;

@end

#endif
