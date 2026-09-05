//
//  MetalFx_ML_UpscalePlugIn.h
//  MetalFx ML Upscale
//
//  Created by ~ ~ on 2/27/24.
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef FxGripTileableEffect_Timing_h
#define FxGripTileableEffect_Timing_h

#import <Foundation/Foundation.h>
#import <FxPlug/FxPlugSDK.h>
#import "FxGripTileableEffect.h"

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



@interface FxGripTileableEffect (Timing)
{
	@protected
}

// Time Utilities
- (CMTime)frameDuration;
- (Float64)retimingSpeed;

- (CMTime)sampleDuration;

/*! YES when the sample duration differs from the frame duration. Final Cut Pro reports half the
	frame duration per sample for interlaced clips. */
- (BOOL)isInterlacedClip;

/*! YES when the project displays timecode in drop-frame format. NO on hosts without
	FxTimingAPI_v5. Introduced in FxGrip 1.0. */
- (BOOL)isTimelineDropFrame;

/*! YES when the filter's input clip requires drop-frame timecode. Motion always reports NO;
	a Motion template running in Final Cut Pro reports the clip setting. NO on hosts without
	FxTimingAPI_v5. Introduced in FxGrip 1.0. */
- (BOOL)isInputDropFrame;

/*! YES when an image-well parameter's clip requires drop-frame timecode. Same host behavior as
	isInputDropFrame. Introduced in FxGrip 1.0. */
- (BOOL)isDropFrameOfImageParameter:(UInt32)parameterID;

/*! The timeline timecode for an input time: the time converted to timeline time, at the
	timeline frame rate, in the project's drop-frame mode. `--:--:--:--` when the host vends
	no timing API. Introduced in FxGrip 1.0. */
- (nonnull NSString *)timelineTimecodeStringForTime:(CMTime)time;

/*! The input-clip timecode for an input time, at the effect's frame duration, in the input's
	drop-frame mode. Introduced in FxGrip 1.0. */
- (nonnull NSString *)inputTimecodeStringForTime:(CMTime)time;

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

/*! The time frames away from time, at the given frame duration. A negative frame count moves
	earlier. Pure arithmetic; the category methods supply the effect's frame duration. */
CMTime FxGripTimeByOffsettingFrames(CMTime time, NSInteger frames, CMTime frameDuration);

/*! time moved by frames at the effect's frame duration; a negative count moves earlier. */
- (CMTime)timeByOffsettingTime:(CMTime)time byFrames:(NSInteger)frames;

/*! A request for the effect's source clip at time, offset by frames, for a temporal effect that
	samples neighboring frames. Leading filters are excluded. */
- (nullable FxImageTileRequest *)sourceTileRequestAtTime:(CMTime)time frameOffset:(NSInteger)frames;

/*! sourceTileRequestAtTime:frameOffset: with no offset. */
- (nullable FxImageTileRequest *)sourceTileRequestAtTime:(CMTime)time;

@end

#endif
