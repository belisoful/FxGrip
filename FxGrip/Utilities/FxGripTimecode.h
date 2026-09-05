//
//  FxGripTimecode.h
//  FxGrip
//

#ifndef FxGripTimecode_h
#define FxGripTimecode_h

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

NS_ASSUME_NONNULL_BEGIN

/*!
	@enum       FxGripFrameRate
	@abstract   The standard frame rates a host or a footage popup offers.
	@discussion Introduced in FxGrip 1.0. The order matches the twelve rates Apple's
				FxTimeCodeGenerator example lists, so a popup built from
				+[FxGripTimecode frameRateMenuEntries] stores this value directly.
*/
typedef NS_ENUM(NSInteger, FxGripFrameRate) {
	FxGripFrameRate_23_976 = 0,
	FxGripFrameRate_24,
	FxGripFrameRate_25,
	FxGripFrameRate_29_97,
	FxGripFrameRate_30,
	FxGripFrameRate_50,
	FxGripFrameRate_59_94,
	FxGripFrameRate_60,
	FxGripFrameRate_90,
	FxGripFrameRate_100,
	FxGripFrameRate_119_88,
	FxGripFrameRate_120,
};

/*!
	@struct     FxGripTimecodeComponents
	@abstract   A time split into timecode fields.
	@discussion Introduced in FxGrip 1.0. `frames` counts from zero within the second.
				`nominalFramesPerSecond` is the integer rate the fields count against (30 for
				29.97). `dropFrame` is the effective mode: YES only when the caller asked for
				drop-frame and the rate supports it. `valid` is NO when either time is invalid or
				the frame duration is not positive; the other fields are then zero.
*/
typedef struct FxGripTimecodeComponents {
	int64_t hours;
	int64_t minutes;
	int64_t seconds;
	int64_t frames;
	int64_t nominalFramesPerSecond;
	BOOL dropFrame;
	BOOL valid;
} FxGripTimecodeComponents;

/*!
	@class      FxGripTimecode
	@abstract   Formats times as SMPTE timecode, with drop-frame support.
	@discussion Introduced in FxGrip 1.0. Every method is a pure class method with no host
				dependency. The drop-frame counting skips two frame numbers per minute at 29.97,
				four at 59.94, and eight at 119.88, except in minutes divisible by ten. Other
				rates ignore the drop-frame flag. Frame indices come from exact integer arithmetic
				on the CMTime fields; a time within half a tick of its own timescale below a frame
				boundary counts as that frame, so hosts that quantize times to a coarse timescale
				still index correctly.
*/
@interface FxGripTimecode : NSObject

/*!
	@method     frameDurationForRate:
	@abstract   The frame duration of a standard rate as an exact CMTime.
	@discussion Fractional rates use a 1001 numerator (29.97 → 1001/30000). An unknown rate
				returns 30 fps.
*/
+ (CMTime)frameDurationForRate:(FxGripFrameRate)rate;

/*!
	@method     frameRateMenuEntries
	@abstract   The display names of every FxGripFrameRate, in enum order, for a popup menu.
*/
+ (NSArray<NSString *> *)frameRateMenuEntries;

/*!
	@method     rateSupportsDropFrame:
	@abstract   YES for 29.97, 59.94, and 119.88.
*/
+ (BOOL)rateSupportsDropFrame:(FxGripFrameRate)rate;

/*!
	@method     frameDurationSupportsDropFrame:
	@abstract   YES when the frame duration is a fractional rate whose nominal rate is 30, 60,
				or 120.
*/
+ (BOOL)frameDurationSupportsDropFrame:(CMTime)frameDuration;

/*!
	@method     frameIndexForTime:frameDuration:
	@abstract   The zero-based frame that contains time, at the given frame duration.
	@discussion Returns 0 when either time is invalid or the frame duration is not positive.
				Negative times return negative indices.
*/
+ (int64_t)frameIndexForTime:(CMTime)time frameDuration:(CMTime)frameDuration;

/*!
	@method     componentsForTime:frameDuration:dropFrame:
	@abstract   Splits time into hours, minutes, seconds, and frames.
	@param      dropFrame YES to count in drop-frame mode. Ignored for rates that do not
				support it.
	@discussion Hours wrap at 24. Negative times are clamped to zero.
*/
+ (FxGripTimecodeComponents)componentsForTime:(CMTime)time
								frameDuration:(CMTime)frameDuration
									dropFrame:(BOOL)dropFrame;

/*!
	@method     stringForComponents:
	@abstract   Formats components as `hh:mm:ss:ff`.
	@discussion Drop-frame mode separates the frames field with a semicolon (`hh:mm:ss;ff`).
				Rates of 100 fps and above use three frame digits. Invalid components format
				as `--:--:--:--`.
*/
+ (NSString *)stringForComponents:(FxGripTimecodeComponents)components;

/*!
	@method     stringForTime:frameDuration:dropFrame:
	@abstract   componentsForTime:frameDuration:dropFrame: followed by stringForComponents:.
*/
+ (NSString *)stringForTime:(CMTime)time
			  frameDuration:(CMTime)frameDuration
				  dropFrame:(BOOL)dropFrame;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripTimecode_h */
