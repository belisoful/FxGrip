//
//  FxGripTileableEffect+Timing.m
//  MetalFx ML Upscale
//
//  Created by ~ ~ on 2/27/24.
//  Copyright © 2024 Belisoful All rights reserved.
//
/*
 Todo:
 - parameter 9998: Plugin Data - holds the plugin metadata for each instance.
 	-has instance guid (initial to plugin guid, gets changed if the same)
 	-has last updated time flag
 - effect metadata - saved when has media directory
 	-has effect guid

 - capture FxParameterCreationAPI_v5 to save parameter types into instance meta data
 - FxParameterRetrievalAPI_v6 has getParameterFlags passthrough to FlagsCache
 - FxParameterSettingAPI_v5 has setParameters flag passthrough to FlagsCache
 - FxParameterSettingAPI_v6 as Flags Cache, add remove passthrough to flagscache
 - FxDynamicParameterAPI_v3 removeParameter capture
 
 */

#import "FxGripTileableEffect+Timing.h"
#import "FxGripTimecode.h"
#import "FxGripTypes.h"
#import "FxGrip_ARC.h"

CMTime FxGripTimeByOffsettingFrames(CMTime time, NSInteger frames, CMTime frameDuration)
{
	return CMTimeAdd(time, CMTimeMultiply(frameDuration, (int32_t)frames));
}


// In a float, at 8388608, a 1 bit change in mantissa results in ~1.0f change in the number.
// In a double, at 4503599627370496, a 1 bit change in mantissa results in ~1.0f change in the number.
long long floorWithError(double value, double epsilon)
{
	// Check if the fractional part is very close to 1
	if (value - ((long long)value) >= (1.0 - epsilon)) {
		// If the value is close to the next integer, round it up
		return (long long)(value + 0.5); // Correct rounding by adding 0.5 and truncating
	} else {
		// Otherwise, round down
		return (long long)(value); // Convert the value directly to an int
	}
}

long long floorWithNearest(double value)
{
	return floorWithError(value, 1e-4);
}



@implementation FxGripTileableEffect (Timing)

#pragma mark -
#pragma mark Time Utilities Implementation


/**
 *	The amount of time for 1 frame after  retiming.
 *  If a clip is slowed by 200%, then this is twice the amount of time that 1 frame
 *  in the primary timeline has.   If the main timeline fps is 30, and the clip is
 *  slowed by 200%, then the frame Duration will be 2.0 / timelineFps.
 */
- (CMTime)frameDuration
{
	CMTime time = kCMTimeInvalid;
	[self.apiManager.timingAPIv4 frameDuration:&time];
	return time;
}


// This is how much the clip is retimed.  1.0 is 100%.  2.0 is 200% speed
//		0.5 is 50% (aka slowed by 200%)
- (Float64)retimingSpeed
{
	id<FxTimingAPI_v4> timing = self.apiManager.timingAPIv4;
	CMTime frameDuration = kCMTimeInvalid;
	[timing frameDuration:&frameDuration];
	
	// speed =  (timelineNumerator * frameDurationDenominator) / (timelineDenominator * frameDurationNumerator)
	NSUInteger numerator = [timing timelineFpsNumeratorForEffect:self];
	NSUInteger denominator = [timing timelineFpsDenominatorForEffect:self];
	return 1.0 / CMTimeGetSeconds(CMTimeMultiplyByRatio(frameDuration, (int)numerator, (int)denominator));
}

/**
 * NOTE: In Final Cut Pro, the sample duration is equal to the object’s native frame duration for progressive clips, but half of the frame duration for interlaced clips.
 */
- (CMTime)sampleDuration
{
	CMTime time = kCMTimeInvalid;
	[self.apiManager.timingAPIv4 sampleDuration:&time];
	return time;
}

- (BOOL)isInterlacedClip
{
	id<FxTimingAPI_v4> timing = self.apiManager.timingAPIv4;
	CMTime frameDuration = kCMTimeInvalid, sampleDuration = kCMTimeInvalid;
	[timing frameDuration:&frameDuration];
	[timing sampleDuration:&sampleDuration];
	return CMTimeCompare(frameDuration, sampleDuration) != 0;
}

#pragma mark Drop frame (FxTimingAPI_v5)

// Each query messages nil on a host older than FxPlug 4.3.5 and so reports NO.
- (BOOL)isTimelineDropFrame
{
	return [self.apiManager.timingAPIv5 isTimelineDropFrame];
}

- (BOOL)isInputDropFrame
{
	return [self.apiManager.timingAPIv5 isInputDropFrame:kFxImageTileRequestSourceEffectClip
											 parameterID:0];
}

- (BOOL)isDropFrameOfImageParameter:(UInt32)parameterID
{
	return [self.apiManager.timingAPIv5 isInputDropFrame:kFxImageTileRequestSourceParameter
											 parameterID:parameterID];
}

- (NSString *)timelineTimecodeStringForTime:(CMTime)time
{
	CMTime timelineTime = kCMTimeInvalid;
	[self timelineTime:&timelineTime fromInputTime:time];
	return [FxGripTimecode stringForTime:timelineTime
						   frameDuration:self.timelineFrameDuration
							   dropFrame:self.isTimelineDropFrame];
}

- (NSString *)inputTimecodeStringForTime:(CMTime)time
{
	return [FxGripTimecode stringForTime:time
						   frameDuration:self.frameDuration
							   dropFrame:self.isInputDropFrame];
}


- (CMTime)effectStartTime
{
	CMTime time = kCMTimeInvalid;
	[self.apiManager.timingAPIv4 startTimeForEffect:&time];
	return time;
}

- (NSInteger)effectStartFrame
{
	CMTime time = kCMTimeInvalid;
	id<FxTimingAPI_v4> timing = self.apiManager.timingAPIv4;
	[timing startTimeForEffect:&time];
	Float64 frame = CMTimeGetSeconds(
				CMTimeMultiplyByRatio(time, (int)[timing timelineFpsNumeratorForEffect:self], (int)[timing timelineFpsDenominatorForEffect:self])
			);
	return floorWithNearest(frame);
}

- (CMTime)effectStartTimeInTimeline
{
	CMTime  effectTime  = kCMTimeInvalid;
	id<FxTimingAPI_v4>  timing = self.effect.apiManager.timingAPIv4;
	[timing startTimeForEffect:&effectTime];
	
	CMTime  timelineEffectTime  = kCMTimeInvalid;
	[timing timelineTime:&timelineEffectTime
					fromInputTime:effectTime];
	return timelineEffectTime;
}

- (CMTime)effectDurationTime
{
	CMTime time = kCMTimeInvalid;
	[self.apiManager.timingAPIv4 durationTimeForEffect:&time];
	return time;
}

- (NSInteger)effectDurationFrames
{
	CMTime time = kCMTimeInvalid;
	id<FxTimingAPI_v4> timing = self.apiManager.timingAPIv4;
	[timing durationTimeForEffect:&time];
	Float64 frame = CMTimeGetSeconds(
				CMTimeMultiplyByRatio(time, (int)[timing timelineFpsNumeratorForEffect:self], (int)[timing timelineFpsDenominatorForEffect:self])
			);
	return floorWithNearest(frame);
}


- (CMTime)inputStartTime
{
	CMTime inputTime = kCMTimeInvalid;
	[self.apiManager.timingAPIv4 startTimeOfInputToFilter:&inputTime];
	return inputTime;
}

- (NSInteger)inputStartFrame
{
	CMTime time = kCMTimeInvalid;
	id<FxTimingAPI_v4> timing = self.apiManager.timingAPIv4;
	[timing startTimeOfInputToFilter:&time];
	Float64 frame = CMTimeGetSeconds(
				CMTimeMultiplyByRatio(time, (int)[timing timelineFpsNumeratorForEffect:self], (int)[timing timelineFpsDenominatorForEffect:self])
			);
	return floorWithNearest(frame);
}

- (CMTime)inputStartTimeInTimeline
{
	CMTime inputTime = kCMTimeInvalid;
	id<FxTimingAPI_v4> timing = self.apiManager.timingAPIv4;
	[timing startTimeOfInputToFilter:&inputTime];
	CMTime  timelineInputTime  = kCMTimeInvalid;
	[timing timelineTime:&timelineInputTime
					fromInputTime:inputTime];
	return timelineInputTime;
}

- (CMTime)inputDurationTime
{
	CMTime time = kCMTimeInvalid;
	[self.apiManager.timingAPIv4 durationTimeOfInputToFilter:&time];
	return time;
}

- (NSInteger)inputDurationFrames
{
	CMTime time = kCMTimeInvalid;
	id<FxTimingAPI_v4> timing = self.apiManager.timingAPIv4;
	[timing durationTimeOfInputToFilter:&time];
	Float64 frame = CMTimeGetSeconds(
				CMTimeMultiplyByRatio(time, (int)[timing timelineFpsNumeratorForEffect:self], (int)[timing timelineFpsDenominatorForEffect:self])
			);
	return floorWithNearest(frame);
}


- (CMTime)effectInPointOfTimeLine
{
	CMTime time = kCMTimeInvalid;
	[self.apiManager.timingAPIv4 inPointTimeOfTimelineForEffect:&time];
	return time;
}

- (CMTime)effectOutPointOfTimeLine
{
	CMTime time = kCMTimeInvalid;
	[self.apiManager.timingAPIv4 outPointTimeOfTimelineForEffect:&time];
	return time;
}


- (NSUInteger)timelineFpsNumerator
{
	return [self.apiManager.timingAPIv4 timelineFpsNumeratorForEffect:self];
}

- (NSUInteger)timelineFpsDenominator
{
	return [self.apiManager.timingAPIv4 timelineFpsDenominatorForEffect:self];
}



//  How many frames per second in a CMTime
- (CMTime)timelineFrameDuration
{
	id<FxTimingAPI_v4> timing = self.apiManager.timingAPIv4;
	return CMTimeMake([timing timelineFpsDenominatorForEffect:self], (int)[timing timelineFpsNumeratorForEffect:self]);
}

- (Float64)timelineFrameDurationFloat
{
	id<FxTimingAPI_v4> timing = self.apiManager.timingAPIv4;
	return CMTimeGetSeconds(CMTimeMake([timing timelineFpsDenominatorForEffect:self], (int)[timing timelineFpsNumeratorForEffect:self]));
}


//  How many frames per second in a CMTime
- (CMTime)timelineFrameRate
{
	id<FxTimingAPI_v4> timing = self.apiManager.timingAPIv4;
	return CMTimeMake([timing timelineFpsNumeratorForEffect:self], (int)[timing timelineFpsDenominatorForEffect:self]);
}

// How many frames per second, invert this for the timelineFrameDuration
- (Float64)timelineFps
{
	id<FxTimingAPI_v4> timing = self.apiManager.timingAPIv4;
	return CMTimeGetSeconds(CMTimeMake([timing timelineFpsNumeratorForEffect:self], (int)[timing timelineFpsDenominatorForEffect:self]));
}



//This multiplies the time by the timeline Frame Rate
- (NSInteger)frameForTime:(CMTime)time
{
	id<FxTimingAPI_v4> timing = self.apiManager.timingAPIv4;
	Float64 frame = CMTimeGetSeconds(
				CMTimeMultiplyByRatio(time, (int)[timing timelineFpsNumeratorForEffect:self], (int)[timing timelineFpsDenominatorForEffect:self])
			);
	return floorWithNearest(frame);
}

- (void)timelineTime:(CMTime*)timelineTime fromInputTime:(CMTime)time
{
	[self.effect.apiManager.timingAPIv4 timelineTime:timelineTime
									   fromInputTime:time];
}

- (void)inputTime:(CMTime*)inputTime fromTimelineTime:(CMTime)time;
{
	[self.effect.apiManager.timingAPIv4 inputTime:inputTime
								 fromTimelineTime:time];
}

- (CMTime)timeByOffsettingTime:(CMTime)time byFrames:(NSInteger)frames
{
	return FxGripTimeByOffsettingFrames(time, frames, self.frameDuration);
}

- (nullable FxImageTileRequest *)sourceTileRequestAtTime:(CMTime)time frameOffset:(NSInteger)frames
{
	CMTime requestTime = [self timeByOffsettingTime:time byFrames:frames];
	FxImageTileRequest *request = [[FxImageTileRequest alloc] initWithSource:kFxImageTileRequestSourceEffectClip
																	  time:requestTime
															includeFilters:NO
															   parameterID:0];
	return NARC_AUTORELEASE(request);
}

- (nullable FxImageTileRequest *)sourceTileRequestAtTime:(CMTime)time
{
	return [self sourceTileRequestAtTime:time frameOffset:0];
}

@end
