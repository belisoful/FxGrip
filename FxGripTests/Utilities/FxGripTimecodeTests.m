/*!
	@file       FxGripTimecodeTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripTimecodeTests
	@abstract   Tests the SMPTE timecode formatter across its rate table, frame indexing, and drop-frame rules.
	@discussion Introduced in FxGrip 0.1.0. The tests build CMTime values directly so CoreMedia need not be linked. They cover the exact rational frame durations, drop-frame eligibility, floor-based frame indexing from CMTime, non-drop component splitting, and the drop-frame digit skips at minute boundaries for 29.97, 59.94, and 119.88 rates.
*/

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripTimecode.h>

// CoreMedia is not linked, so CMTime values are built without its symbols.
static CMTime FxGripTCTime(int64_t value, int32_t timescale)
{
	return (CMTime){.value = value, .timescale = timescale, .flags = kCMTimeFlags_Valid, .epoch = 0};
}

static CMTime FxGripTCInvalid(void)
{
	return (CMTime){.value = 0, .timescale = 0, .flags = 0, .epoch = 0};
}

/*! The time of frame index `frame` at a frame duration, exactly. */
static CMTime FxGripTCFrame(int64_t frame, CMTime frameDuration)
{
	return FxGripTCTime(frame * frameDuration.value, frameDuration.timescale);
}

static CMTime FxGripTC2997(void) { return [FxGripTimecode frameDurationForRate:FxGripFrameRate_29_97]; }
static CMTime FxGripTC5994(void) { return [FxGripTimecode frameDurationForRate:FxGripFrameRate_59_94]; }
static CMTime FxGripTC30(void)   { return [FxGripTimecode frameDurationForRate:FxGripFrameRate_30]; }
static CMTime FxGripTC25(void)   { return [FxGripTimecode frameDurationForRate:FxGripFrameRate_25]; }

@interface FxGripTimecodeTests : XCTestCase
@end

@implementation FxGripTimecodeTests

#pragma mark - Rate table

/*! @abstract Frame durations are exact rational fractions: 1001/30000 for 29.97, 1000/24000 for 24, and 1001/120000 for 119.88. */
- (void)testFrameDurationForRateUsesExactFractions
{
	CMTime df = FxGripTC2997();
	XCTAssertEqual(df.value, (int64_t)1001);
	XCTAssertEqual(df.timescale, (int32_t)30000);

	CMTime whole = [FxGripTimecode frameDurationForRate:FxGripFrameRate_24];
	XCTAssertEqual(whole.value, (int64_t)1000);
	XCTAssertEqual(whole.timescale, (int32_t)24000);

	CMTime fast = [FxGripTimecode frameDurationForRate:FxGripFrameRate_119_88];
	XCTAssertEqual(fast.value, (int64_t)1001);
	XCTAssertEqual(fast.timescale, (int32_t)120000);
}

/*! @abstract The menu entry list holds twelve labels indexed in enum order, each matching its rate's display string. */
- (void)testMenuEntriesFollowTheEnumOrder
{
	NSArray<NSString *> *entries = FxGripTimecode.frameRateMenuEntries;

	XCTAssertEqual(entries.count, (NSUInteger)12);
	XCTAssertEqualObjects(entries[FxGripFrameRate_23_976], @"23.98");
	XCTAssertEqualObjects(entries[FxGripFrameRate_29_97], @"29.97");
	XCTAssertEqualObjects(entries[FxGripFrameRate_120], @"120");
}

/*! @abstract Only the 29.97, 59.94, and 119.88 rates support drop frame; whole and film rates do not. */
- (void)testOnlyTheThreeFractionalNTSCRatesSupportDropFrame
{
	XCTAssertTrue([FxGripTimecode rateSupportsDropFrame:FxGripFrameRate_29_97]);
	XCTAssertTrue([FxGripTimecode rateSupportsDropFrame:FxGripFrameRate_59_94]);
	XCTAssertTrue([FxGripTimecode rateSupportsDropFrame:FxGripFrameRate_119_88]);
	XCTAssertFalse([FxGripTimecode rateSupportsDropFrame:FxGripFrameRate_23_976]);
	XCTAssertFalse([FxGripTimecode rateSupportsDropFrame:FxGripFrameRate_30]);
	XCTAssertFalse([FxGripTimecode rateSupportsDropFrame:FxGripFrameRate_60]);
}

/*! @abstract Drop-frame eligibility inferred from a frame duration matches the rate table, and an invalid duration is ineligible. */
- (void)testFrameDurationDropFrameEligibilityMatchesTheRateTable
{
	XCTAssertTrue([FxGripTimecode frameDurationSupportsDropFrame:FxGripTC2997()]);
	XCTAssertTrue([FxGripTimecode frameDurationSupportsDropFrame:FxGripTC5994()]);
	XCTAssertFalse([FxGripTimecode frameDurationSupportsDropFrame:FxGripTC30()]);
	XCTAssertFalse([FxGripTimecode frameDurationSupportsDropFrame:
					[FxGripTimecode frameDurationForRate:FxGripFrameRate_23_976]]);
	XCTAssertFalse([FxGripTimecode frameDurationSupportsDropFrame:FxGripTCInvalid()]);
}

#pragma mark - Frame index

/*! @abstract A time landing exactly on a frame boundary returns that frame's index. */
- (void)testFrameIndexIsExactOnFrameBoundaries
{
	CMTime df = FxGripTC2997();

	XCTAssertEqual([FxGripTimecode frameIndexForTime:FxGripTCFrame(0, df) frameDuration:df], (int64_t)0);
	XCTAssertEqual([FxGripTimecode frameIndexForTime:FxGripTCFrame(1, df) frameDuration:df], (int64_t)1);
	XCTAssertEqual([FxGripTimecode frameIndexForTime:FxGripTCFrame(17982, df) frameDuration:df], (int64_t)17982);
}

/*! @abstract A time one tick below the first frame boundary indexes to frame zero. */
- (void)testFrameIndexOneTickBelowABoundaryStaysOnThePriorFrame
{
	CMTime df = FxGripTC2997();

	XCTAssertEqual([FxGripTimecode frameIndexForTime:FxGripTCTime(1000, 30000) frameDuration:df], (int64_t)0);
}

/*! @abstract Frame indexing stays correct when the input time uses a coarse 600 timescale. */
- (void)testFrameIndexToleratesACoarseTimescale
{
	// 20/600 s is the nearest 600-scale tick below the first 29.97 frame (1001/30000 s).
	XCTAssertEqual([FxGripTimecode frameIndexForTime:FxGripTCTime(20, 600) frameDuration:FxGripTC2997()], (int64_t)1);
}

/*! @abstract Negative times floor toward negative infinity, so any part of the frame below zero indexes to -1. */
- (void)testFrameIndexOfNegativeTimeFloors
{
	CMTime whole = FxGripTC30();

	XCTAssertEqual([FxGripTimecode frameIndexForTime:FxGripTCTime(-1000, 30000) frameDuration:whole], (int64_t)-1);
	XCTAssertEqual([FxGripTimecode frameIndexForTime:FxGripTCTime(-1, 30000) frameDuration:whole], (int64_t)-1);
}

/*! @abstract An invalid time, an invalid frame duration, or a zero frame duration each yields a frame index of zero. */
- (void)testFrameIndexOfInvalidInputIsZero
{
	XCTAssertEqual([FxGripTimecode frameIndexForTime:FxGripTCInvalid() frameDuration:FxGripTC30()], (int64_t)0);
	XCTAssertEqual([FxGripTimecode frameIndexForTime:FxGripTCTime(600, 600) frameDuration:FxGripTCInvalid()], (int64_t)0);
	XCTAssertEqual([FxGripTimecode frameIndexForTime:FxGripTCTime(600, 600) frameDuration:FxGripTCTime(0, 30000)], (int64_t)0);
}

#pragma mark - Non-drop components

/*! @abstract Non-drop components split a 25 fps time into hours, minutes, seconds, and frames with the nominal frame rate. */
- (void)testNonDropComponentsSplitIntoFields
{
	CMTime pal = FxGripTC25();
	int64_t frame = ((1 * 3600) + (2 * 60) + 3) * 25 + 4;

	FxGripTimecodeComponents c = [FxGripTimecode componentsForTime:FxGripTCFrame(frame, pal)
													 frameDuration:pal
														 dropFrame:NO];

	XCTAssertTrue(c.valid);
	XCTAssertEqual(c.hours, (int64_t)1);
	XCTAssertEqual(c.minutes, (int64_t)2);
	XCTAssertEqual(c.seconds, (int64_t)3);
	XCTAssertEqual(c.frames, (int64_t)4);
	XCTAssertEqual(c.nominalFramesPerSecond, (int64_t)25);
	XCTAssertFalse(c.dropFrame);
}

/*! @abstract A drop-frame request on a whole 30 fps rate is ignored and formats with a non-drop separator. */
- (void)testDropFrameRequestIsIgnoredForAWholeRate
{
	CMTime whole = FxGripTC30();

	FxGripTimecodeComponents c = [FxGripTimecode componentsForTime:FxGripTCFrame(1800, whole)
													 frameDuration:whole
														 dropFrame:YES];

	XCTAssertFalse(c.dropFrame);
	XCTAssertEqual(c.minutes, (int64_t)1);
	XCTAssertEqual(c.frames, (int64_t)0);
	XCTAssertEqualObjects([FxGripTimecode stringForComponents:c], @"00:01:00:00");
}

/*! @abstract The hours field wraps modulo twenty-four, so twenty-five hours reads as one. */
- (void)testHoursWrapAtTwentyFour
{
	CMTime whole = FxGripTC30();

	FxGripTimecodeComponents c = [FxGripTimecode componentsForTime:FxGripTCFrame(25 * 3600 * 30, whole)
													 frameDuration:whole
														 dropFrame:NO];

	XCTAssertEqual(c.hours, (int64_t)1);
}

/*! @abstract A negative time produces valid components clamped to zero seconds and zero frames. */
- (void)testNegativeTimeClampsToZero
{
	FxGripTimecodeComponents c = [FxGripTimecode componentsForTime:FxGripTCTime(-600, 600)
													 frameDuration:FxGripTC30()
														 dropFrame:NO];

	XCTAssertTrue(c.valid);
	XCTAssertEqual(c.seconds, (int64_t)0);
	XCTAssertEqual(c.frames, (int64_t)0);
}

/*! @abstract An invalid time yields invalid components that format as the dashed placeholder string. */
- (void)testInvalidInputYieldsInvalidComponents
{
	FxGripTimecodeComponents c = [FxGripTimecode componentsForTime:FxGripTCInvalid()
													 frameDuration:FxGripTC30()
														 dropFrame:NO];

	XCTAssertFalse(c.valid);
	XCTAssertEqualObjects([FxGripTimecode stringForComponents:c], @"--:--:--:--");
}

#pragma mark - Drop frame at 29.97

/*! @abstract Within the first minute, drop-frame counting runs straight through with no frame numbers skipped. */
- (void)testDropFrameCountsStraightThroughTheFirstMinute
{
	CMTime df = FxGripTC2997();

	XCTAssertEqualObjects([FxGripTimecode stringForTime:FxGripTCFrame(0, df) frameDuration:df dropFrame:YES], @"00:00:00;00");
	XCTAssertEqualObjects([FxGripTimecode stringForTime:FxGripTCFrame(29, df) frameDuration:df dropFrame:YES], @"00:00:00;29");
	XCTAssertEqualObjects([FxGripTimecode stringForTime:FxGripTCFrame(30, df) frameDuration:df dropFrame:YES], @"00:00:01;00");
	XCTAssertEqualObjects([FxGripTimecode stringForTime:FxGripTCFrame(1799, df) frameDuration:df dropFrame:YES], @"00:00:59;29");
}

/*! @abstract At the first minute, 29.97 drop frame skips frame numbers 00 and 01 and resumes at 02. */
- (void)testDropFrameSkipsTwoNumbersAtTheFirstMinute
{
	CMTime df = FxGripTC2997();

	XCTAssertEqualObjects([FxGripTimecode stringForTime:FxGripTCFrame(1800, df) frameDuration:df dropFrame:YES], @"00:01:00;02");
	XCTAssertEqualObjects([FxGripTimecode stringForTime:FxGripTCFrame(1801, df) frameDuration:df dropFrame:YES], @"00:01:00;03");
}

/*! @abstract The tenth minute keeps its first two frame numbers, since drop frame skips only at minutes not divisible by ten. */
- (void)testDropFrameDoesNotSkipAtTheTenthMinute
{
	CMTime df = FxGripTC2997();

	// 17982 frames elapse in ten minutes at 29.97; the tenth minute keeps its first two numbers.
	XCTAssertEqualObjects([FxGripTimecode stringForTime:FxGripTCFrame(17981, df) frameDuration:df dropFrame:YES], @"00:09:59;29");
	XCTAssertEqualObjects([FxGripTimecode stringForTime:FxGripTCFrame(17982, df) frameDuration:df dropFrame:YES], @"00:10:00;00");
	XCTAssertEqualObjects([FxGripTimecode stringForTime:FxGripTCFrame(17982 + 1800, df) frameDuration:df dropFrame:YES], @"00:11:00;02");
}

/*! @abstract One hour of real time at 29.97 drop frame reads as exactly 01:00:00;00. */
- (void)testDropFrameRealignsWithWallClockEveryTenMinutes
{
	CMTime df = FxGripTC2997();

	// One hour of real time is 107892 frames at 29.97 and reads as 01:00:00;00 in drop frame.
	XCTAssertEqualObjects([FxGripTimecode stringForTime:FxGripTCFrame(107892, df) frameDuration:df dropFrame:YES], @"01:00:00;00");
}

/*! @abstract Non-drop formatting at 29.97 drifts behind wall-clock time, reading 00:59:56:12 after one real hour. */
- (void)testNonDropAtTwentyNineNinetySevenDriftsBehindWallClock
{
	CMTime df = FxGripTC2997();

	XCTAssertEqualObjects([FxGripTimecode stringForTime:FxGripTCFrame(1800, df) frameDuration:df dropFrame:NO], @"00:01:00:00");
	XCTAssertEqualObjects([FxGripTimecode stringForTime:FxGripTCFrame(107892, df) frameDuration:df dropFrame:NO], @"00:59:56:12");
}

#pragma mark - Drop frame at 59.94 and 119.88

/*! @abstract At 59.94 drop frame, the first minute skips four frame numbers and resumes at 04. */
- (void)testDropFrameAtFiftyNineNinetyFourSkipsFourNumbers
{
	CMTime df = FxGripTC5994();

	XCTAssertEqualObjects([FxGripTimecode stringForTime:FxGripTCFrame(3599, df) frameDuration:df dropFrame:YES], @"00:00:59;59");
	XCTAssertEqualObjects([FxGripTimecode stringForTime:FxGripTCFrame(3600, df) frameDuration:df dropFrame:YES], @"00:01:00;04");
	XCTAssertEqualObjects([FxGripTimecode stringForTime:FxGripTCFrame(35964, df) frameDuration:df dropFrame:YES], @"00:10:00;00");
}

/*! @abstract At 119.88 drop frame, frame numbers use three digits and the first minute skips eight numbers. */
- (void)testDropFrameAtOneNineteenEightyEightUsesThreeFrameDigits
{
	CMTime df = [FxGripTimecode frameDurationForRate:FxGripFrameRate_119_88];

	XCTAssertEqualObjects([FxGripTimecode stringForTime:FxGripTCFrame(7199, df) frameDuration:df dropFrame:YES], @"00:00:59;119");
	XCTAssertEqualObjects([FxGripTimecode stringForTime:FxGripTCFrame(7200, df) frameDuration:df dropFrame:YES], @"00:01:00;008");
	XCTAssertEqualObjects([FxGripTimecode stringForTime:FxGripTCFrame(71928, df) frameDuration:df dropFrame:YES], @"00:10:00;000");
}

/*! @abstract A whole rate of 120 fps formats its frame field with three digits. */
- (void)testWholeRatesAtOneHundredAndAboveUseThreeFrameDigits
{
	CMTime df = [FxGripTimecode frameDurationForRate:FxGripFrameRate_120];

	XCTAssertEqualObjects([FxGripTimecode stringForTime:FxGripTCFrame(121, df) frameDuration:df dropFrame:NO], @"00:00:01:001");
}

@end
