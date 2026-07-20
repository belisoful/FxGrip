/// @deprecated Legacy GuruFx implementation retained only for the final merge into the
/// new FxGrip implementations. Do not modify or extend; names intentionally unchanged.

//
//  MetalFx_ML_UpscalePlugIn.h
//  MetalFx ML Upscale
//
//  Created by ~ ~ on 2/27/24.
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef GuruFxTileableEffect_Timing_h
#define GuruFxTileableEffect_Timing_h

#import <Foundation/Foundation.h>
#import <FxPlug/FxPlugSDK.h>
#import "GuruFxTileableEffect.h"

#define kWatchInputStartTime	(1 << 0)
#define kWatchInputDuration		(1 << 1)
#define kWatchFPSChange		(1 << 0)

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



@interface GuruFxTileableEffect (Timing)
{
	@protected
	//uint watchingKey;
}

// Time Utilities
@property (assign, readonly) CMTime frameDuration;
@property (assign, readonly) CMTime sampleDuration;
@property (assign, readonly) CMTime effectStartTime;
@property (assign, readonly) CMTime effectDuration;
@property (assign, readonly) CMTime inputStartTime;
@property (assign, readonly) CMTime inputDuractionTime;
@property (assign, readonly) CMTime effectInPointOfTimeLine;
@property (assign, readonly) CMTime effectOutPointOfTimeLine;

@property (assign, readonly) NSUInteger timelineFpsNumerator;
@property (assign, readonly) NSUInteger timelineFpsDenominator;

-(CMTime) timelineFrameRate;
-(Float64) timelineFps;

-(NSInteger)frameForTime:(CMTime)time;

@optional

// on change of x.

@end

#endif
