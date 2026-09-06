/*!
	@file       FxGripTileableEffect+Timing.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripTileableEffect+Timing
	@abstract   The category that reports the effect's timing, frame rates, timecode, and frame offsets.
	@discussion Introduced in FxGrip 0.1.0. The category reads the FxPlug timing API to report the
	            frame duration, retiming speed, sample duration, and the effect and input start and
	            duration in time and frames. It converts between input time and timeline time,
	            formats SMPTE timecode strings, and reports drop-frame settings through
	            FxTimingAPI_v5. It builds source-tile requests offset by whole frames for temporal
	            effects.
*/

#ifndef FxGripTileableEffect_Timing_h
#define FxGripTileableEffect_Timing_h

#import <Foundation/Foundation.h>
#import <FxPlug/FxPlugSDK.h>
#import "FxGripTileableEffect.h"

/*! Change-watch flag for the input start time. */
#define kWatchInputStartTime	(1 << 0)
/*! Change-watch flag for the input duration. */
#define kWatchInputDuration		(1 << 1)
/*! Change-watch flag for a frame-rate change. */
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
/*! Floors a value, rounding up when its fractional part is within epsilon of the next integer. */
inline long long floorWithError(double value, double epsilon);

/*! floorWithError with a fixed epsilon of 1e-4. */
inline long long floorWithNearest(double value);



/*!
	@abstract	The category exposing the effect's timing, frame rates, timecode, and frame offsets.
	@discussion	Introduced in FxGrip 0.1.0. The accessors read the FxPlug timing API. Frame counts
				come from multiplying a time by the timeline frame rate and flooring to the nearest.
*/
@interface FxGripTileableEffect (Timing)
{
	@protected
}

// Time Utilities
/*! The duration of one frame after retiming, in timeline time. */
- (CMTime)frameDuration;
/*! The clip's retiming speed; 1.0 is 100%, 2.0 is 200%, 0.5 is slowed to 50%. */
- (Float64)retimingSpeed;

/*! The sample duration; equal to the frame duration for progressive clips, half for interlaced. */
- (CMTime)sampleDuration;

/*! YES when the sample duration differs from the frame duration. Final Cut Pro reports half the
	frame duration per sample for interlaced clips. */
- (BOOL)isInterlacedClip;

/*! YES when the project displays timecode in drop-frame format. NO on hosts without
	FxTimingAPI_v5. Introduced in FxGrip 0.1.0. */
- (BOOL)isTimelineDropFrame;

/*! YES when the filter's input clip requires drop-frame timecode. Motion always reports NO;
	a Motion template running in Final Cut Pro reports the clip setting. NO on hosts without
	FxTimingAPI_v5. Introduced in FxGrip 0.1.0. */
- (BOOL)isInputDropFrame;

/*! YES when an image-well parameter's clip requires drop-frame timecode. Same host behavior as
	isInputDropFrame. Introduced in FxGrip 0.1.0. */
- (BOOL)isDropFrameOfImageParameter:(UInt32)parameterID;

/*! The timeline timecode for an input time: the time converted to timeline time, at the
	timeline frame rate, in the project's drop-frame mode. `--:--:--:--` when the host vends
	no timing API. Introduced in FxGrip 0.1.0. */
- (nonnull NSString *)timelineTimecodeStringForTime:(CMTime)time;

/*! The input-clip timecode for an input time, at the effect's frame duration, in the input's
	drop-frame mode. Introduced in FxGrip 0.1.0. */
- (nonnull NSString *)inputTimecodeStringForTime:(CMTime)time;

/*! The effect's start time in input time. */
- (CMTime)effectStartTime;
/*! The effect's start time as a timeline frame index. */
- (NSInteger)effectStartFrame;
/*! The effect's start time converted to timeline time. */
- (CMTime)effectStartTimeInTimeline;
/*! The effect's duration in input time. */
- (CMTime)effectDurationTime;
/*! The effect's duration in timeline frames. */
- (NSInteger)effectDurationFrames;

/*! The filter input's start time in input time. */
- (CMTime)inputStartTime;
/*! The filter input's start time as a timeline frame index. */
- (NSInteger)inputStartFrame;
/*! The filter input's start time converted to timeline time. */
- (CMTime)inputStartTimeInTimeline;
/*! The filter input's duration in input time. */
- (CMTime)inputDurationTime;
/*! The filter input's duration in timeline frames. */
- (NSInteger)inputDurationFrames;

/*! The effect's in point on the timeline. */
- (CMTime)effectInPointOfTimeLine;
/*! The effect's out point on the timeline. */
- (CMTime)effectOutPointOfTimeLine;

/*! The numerator of the timeline frame rate. */
- (NSUInteger)timelineFpsNumerator;
/*! The denominator of the timeline frame rate. */
- (NSUInteger)timelineFpsDenominator;

/*! The timeline frame duration as a CMTime. */
- (CMTime)timelineFrameDuration;
/*! The timeline frame duration in seconds. */
- (Float64)timelineFrameDurationFloat;
/*! The timeline frame rate as a CMTime. */
- (CMTime)timelineFrameRate;
/*! The timeline frame rate in frames per second. */
- (Float64)timelineFps;

/*! The timeline frame index for a time, from the time multiplied by the timeline frame rate. */
- (NSInteger)frameForTime:(CMTime)time;

/*! @abstract Converts an input time to timeline time through the host timing API. */
- (void)timelineTime:(nonnull CMTime*)timelineTime fromInputTime:(CMTime)time;
/*! @abstract Converts a timeline time to input time through the host timing API. */
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
