/*!
	@file       FxGripTimecode.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripTimecode
	@abstract   Implements SMPTE timecode formatting with drop-frame counting.
	@discussion Introduced in FxGrip 0.1.0. Frame indices come from exact 128-bit rational
	            arithmetic on the CMTime fields, with a half-tick bias so a time just below a
	            frame boundary counts as that frame. Drop-frame mode adds back the skipped frame
	            numbers before splitting the index into fields.
*/

#import "FxGripTimecode.h"

static const int64_t kFxGripTimecodeSecondsPerMinute = 60;
static const int64_t kFxGripTimecodeSecondsPerTenMinutes = 600;

/*! YES when the frame duration is numeric with a positive value and timescale. */
static BOOL FxGripTimecodeDurationIsUsable(CMTime frameDuration)
{
	return CMTIME_IS_NUMERIC(frameDuration) && frameDuration.value > 0 && frameDuration.timescale > 0;
}

/*! Frames per span of seconds at the exact rate, truncated (1798 per minute at 29.97). */
static int64_t FxGripTimecodeFramesPerSeconds(int64_t seconds, CMTime frameDuration)
{
	__int128 numerator = (__int128)seconds * frameDuration.timescale;
	return (int64_t)(numerator / frameDuration.value);
}

/*! The integer rate the timecode fields count against (30 for 29.97). */
static int64_t FxGripTimecodeNominalRate(CMTime frameDuration)
{
	return (int64_t)llround((double)frameDuration.timescale / (double)frameDuration.value);
}

/*!
	@abstract	Formats times as SMPTE timecode, with drop-frame support.
	@discussion	Introduced in FxGrip 0.1.0. Every method is a pure class method with no host
				dependency.
*/
@implementation FxGripTimecode

/*! @abstract The exact frame duration of a standard rate; an unknown rate returns 30 fps. */
+ (CMTime)frameDurationForRate:(FxGripFrameRate)rate
{
	switch (rate) {
		case FxGripFrameRate_23_976: return CMTimeMake(1001, 24000);
		case FxGripFrameRate_24:     return CMTimeMake(1000, 24000);
		case FxGripFrameRate_25:     return CMTimeMake(1000, 25000);
		case FxGripFrameRate_29_97:  return CMTimeMake(1001, 30000);
		case FxGripFrameRate_30:     return CMTimeMake(1000, 30000);
		case FxGripFrameRate_50:     return CMTimeMake(1000, 50000);
		case FxGripFrameRate_59_94:  return CMTimeMake(1001, 60000);
		case FxGripFrameRate_60:     return CMTimeMake(1000, 60000);
		case FxGripFrameRate_90:     return CMTimeMake(1000, 90000);
		case FxGripFrameRate_100:    return CMTimeMake(1000, 100000);
		case FxGripFrameRate_119_88: return CMTimeMake(1001, 120000);
		case FxGripFrameRate_120:    return CMTimeMake(1000, 120000);
	}
	return CMTimeMake(1000, 30000);
}

/*! @abstract The display names of every FxGripFrameRate, in enum order. */
+ (NSArray<NSString *> *)frameRateMenuEntries
{
	return @[ @"23.98", @"24", @"25", @"29.97", @"30", @"50",
			  @"59.94", @"60", @"90", @"100", @"119.88", @"120" ];
}

/*! @abstract YES for 29.97, 59.94, and 119.88. */
+ (BOOL)rateSupportsDropFrame:(FxGripFrameRate)rate
{
	return rate == FxGripFrameRate_29_97
		|| rate == FxGripFrameRate_59_94
		|| rate == FxGripFrameRate_119_88;
}

/*! @abstract YES when the frame duration is a fractional rate whose nominal rate is 30, 60, or 120. */
+ (BOOL)frameDurationSupportsDropFrame:(CMTime)frameDuration
{
	if (!FxGripTimecodeDurationIsUsable(frameDuration)) {
		return NO;
	}
	int64_t nominal = FxGripTimecodeNominalRate(frameDuration);
	if (nominal != 30 && nominal != 60 && nominal != 120) {
		return NO;
	}
	// An exact integer rate has nothing to drop.
	return FxGripTimecodeFramesPerSeconds(kFxGripTimecodeSecondsPerMinute, frameDuration)
		!= nominal * kFxGripTimecodeSecondsPerMinute;
}

/*!
	@method		frameIndexForTime:frameDuration:
	@abstract	The zero-based frame that contains time, at the given frame duration.
	@return		The frame index; 0 when either time is invalid or the frame duration is not
				positive; a negative index for a negative time. */
+ (int64_t)frameIndexForTime:(CMTime)time frameDuration:(CMTime)frameDuration
{
	if (!CMTIME_IS_NUMERIC(time) || !FxGripTimecodeDurationIsUsable(frameDuration)) {
		return 0;
	}
	// frames = (time + half a tick) / frameDuration, as one exact rational.
	__int128 numerator = ((__int128)time.value * 2 + 1) * frameDuration.timescale;
	__int128 denominator = (__int128)time.timescale * 2 * frameDuration.value;
	__int128 quotient = numerator / denominator;
	if (numerator < 0 && numerator % denominator != 0) {
		quotient -= 1;
	}
	return (int64_t)quotient;
}

/*!
	@method		componentsForTime:frameDuration:dropFrame:
	@abstract	Splits time into hours, minutes, seconds, and frames.
	@param		dropFrame	YES to count in drop-frame mode; ignored for rates that do not
				support it.
	@discussion	Introduced in FxGrip 0.1.0. Hours wrap at 24 and negative times are clamped to
				zero. Drop-frame mode adds the skipped frame numbers before the split. */
+ (FxGripTimecodeComponents)componentsForTime:(CMTime)time
								frameDuration:(CMTime)frameDuration
									dropFrame:(BOOL)dropFrame
{
	FxGripTimecodeComponents result = { 0, 0, 0, 0, 0, NO, NO };
	if (!CMTIME_IS_NUMERIC(time) || !FxGripTimecodeDurationIsUsable(frameDuration)) {
		return result;
	}

	int64_t nominal = FxGripTimecodeNominalRate(frameDuration);
	int64_t frameIndex = MAX([self frameIndexForTime:time frameDuration:frameDuration], (int64_t)0);
	BOOL drops = dropFrame && [self frameDurationSupportsDropFrame:frameDuration];

	if (drops) {
		int64_t framesPerMinute = FxGripTimecodeFramesPerSeconds(kFxGripTimecodeSecondsPerMinute, frameDuration);
		int64_t framesPerTenMinutes = FxGripTimecodeFramesPerSeconds(kFxGripTimecodeSecondsPerTenMinutes, frameDuration);
		int64_t dropPerMinute = nominal * kFxGripTimecodeSecondsPerMinute - framesPerMinute;
		int64_t tenMinuteBlocks = frameIndex / framesPerTenMinutes;
		int64_t remainder = frameIndex % framesPerTenMinutes;
		int64_t skipped = dropPerMinute * 9 * tenMinuteBlocks;
		if (remainder > dropPerMinute) {
			skipped += dropPerMinute * ((remainder - dropPerMinute) / framesPerMinute);
		}
		frameIndex += skipped;
	}

	int64_t totalSeconds = frameIndex / nominal;
	result.frames = frameIndex % nominal;
	result.seconds = totalSeconds % 60;
	result.minutes = (totalSeconds / 60) % 60;
	result.hours = (totalSeconds / 3600) % 24;
	result.nominalFramesPerSecond = nominal;
	result.dropFrame = drops;
	result.valid = YES;
	return result;
}

/*!
	@method		stringForComponents:
	@abstract	Formats components as hh:mm:ss:ff.
	@discussion	Introduced in FxGrip 0.1.0. Drop-frame mode separates the frames field with a
				semicolon. Rates of 100 fps and above use three frame digits. Invalid components
				format as --:--:--:--. */
+ (NSString *)stringForComponents:(FxGripTimecodeComponents)components
{
	if (!components.valid) {
		return @"--:--:--:--";
	}
	const char *separator = components.dropFrame ? ";" : ":";
	const char *frameFormat = components.nominalFramesPerSecond >= 100 ? "%03lld" : "%02lld";
	NSString *format = [NSString stringWithFormat:@"%%02lld:%%02lld:%%02lld%s%s", separator, frameFormat];
	return [NSString stringWithFormat:format,
			components.hours, components.minutes, components.seconds, components.frames];
}

/*! @abstract componentsForTime:frameDuration:dropFrame: followed by stringForComponents:. */
+ (NSString *)stringForTime:(CMTime)time
			  frameDuration:(CMTime)frameDuration
				  dropFrame:(BOOL)dropFrame
{
	return [self stringForComponents:[self componentsForTime:time
											   frameDuration:frameDuration
												   dropFrame:dropFrame]];
}

@end
