//
//  FxGripTimecodeTests.m
//  FxGripTests
//
//  Unit tests for the SMPTE timecode formatter: the rate table, drop-frame eligibility,
//  frame indexing from exact CMTime arithmetic, and the drop-frame skip at minute boundaries.
//

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

- (void)testMenuEntriesFollowTheEnumOrder
{
	NSArray<NSString *> *entries = FxGripTimecode.frameRateMenuEntries;

	XCTAssertEqual(entries.count, (NSUInteger)12);
	XCTAssertEqualObjects(entries[FxGripFrameRate_23_976], @"23.98");
	XCTAssertEqualObjects(entries[FxGripFrameRate_29_97], @"29.97");
	XCTAssertEqualObjects(entries[FxGripFrameRate_120], @"120");
}

- (void)testOnlyTheThreeFractionalNTSCRatesSupportDropFrame
{
	XCTAssertTrue([FxGripTimecode rateSupportsDropFrame:FxGripFrameRate_29_97]);
	XCTAssertTrue([FxGripTimecode rateSupportsDropFrame:FxGripFrameRate_59_94]);
	XCTAssertTrue([FxGripTimecode rateSupportsDropFrame:FxGripFrameRate_119_88]);
	XCTAssertFalse([FxGripTimecode rateSupportsDropFrame:FxGripFrameRate_23_976]);
	XCTAssertFalse([FxGripTimecode rateSupportsDropFrame:FxGripFrameRate_30]);
	XCTAssertFalse([FxGripTimecode rateSupportsDropFrame:FxGripFrameRate_60]);
}

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

- (void)testFrameIndexIsExactOnFrameBoundaries
{
	CMTime df = FxGripTC2997();

	XCTAssertEqual([FxGripTimecode frameIndexForTime:FxGripTCFrame(0, df) frameDuration:df], (int64_t)0);
	XCTAssertEqual([FxGripTimecode frameIndexForTime:FxGripTCFrame(1, df) frameDuration:df], (int64_t)1);
	XCTAssertEqual([FxGripTimecode frameIndexForTime:FxGripTCFrame(17982, df) frameDuration:df], (int64_t)17982);
}

- (void)testFrameIndexOneTickBelowABoundaryStaysOnThePriorFrame
{
	CMTime df = FxGripTC2997();

	XCTAssertEqual([FxGripTimecode frameIndexForTime:FxGripTCTime(1000, 30000) frameDuration:df], (int64_t)0);
}

- (void)testFrameIndexToleratesACoarseTimescale
{
	// 20/600 s is the nearest 600-scale tick below the first 29.97 frame (1001/30000 s).
	XCTAssertEqual([FxGripTimecode frameIndexForTime:FxGripTCTime(20, 600) frameDuration:FxGripTC2997()], (int64_t)1);
}

- (void)testFrameIndexOfNegativeTimeFloors
{
	CMTime whole = FxGripTC30();

	XCTAssertEqual([FxGripTimecode frameIndexForTime:FxGripTCTime(-1000, 30000) frameDuration:whole], (int64_t)-1);
	XCTAssertEqual([FxGripTimecode frameIndexForTime:FxGripTCTime(-1, 30000) frameDuration:whole], (int64_t)-1);
}

- (void)testFrameIndexOfInvalidInputIsZero
{
	XCTAssertEqual([FxGripTimecode frameIndexForTime:FxGripTCInvalid() frameDuration:FxGripTC30()], (int64_t)0);
	XCTAssertEqual([FxGripTimecode frameIndexForTime:FxGripTCTime(600, 600) frameDuration:FxGripTCInvalid()], (int64_t)0);
	XCTAssertEqual([FxGripTimecode frameIndexForTime:FxGripTCTime(600, 600) frameDuration:FxGripTCTime(0, 30000)], (int64_t)0);
}

#pragma mark - Non-drop components

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

- (void)testHoursWrapAtTwentyFour
{
	CMTime whole = FxGripTC30();

	FxGripTimecodeComponents c = [FxGripTimecode componentsForTime:FxGripTCFrame(25 * 3600 * 30, whole)
													 frameDuration:whole
														 dropFrame:NO];

	XCTAssertEqual(c.hours, (int64_t)1);
}

- (void)testNegativeTimeClampsToZero
{
	FxGripTimecodeComponents c = [FxGripTimecode componentsForTime:FxGripTCTime(-600, 600)
													 frameDuration:FxGripTC30()
														 dropFrame:NO];

	XCTAssertTrue(c.valid);
	XCTAssertEqual(c.seconds, (int64_t)0);
	XCTAssertEqual(c.frames, (int64_t)0);
}

- (void)testInvalidInputYieldsInvalidComponents
{
	FxGripTimecodeComponents c = [FxGripTimecode componentsForTime:FxGripTCInvalid()
													 frameDuration:FxGripTC30()
														 dropFrame:NO];

	XCTAssertFalse(c.valid);
	XCTAssertEqualObjects([FxGripTimecode stringForComponents:c], @"--:--:--:--");
}

#pragma mark - Drop frame at 29.97

- (void)testDropFrameCountsStraightThroughTheFirstMinute
{
	CMTime df = FxGripTC2997();

	XCTAssertEqualObjects([FxGripTimecode stringForTime:FxGripTCFrame(0, df) frameDuration:df dropFrame:YES], @"00:00:00;00");
	XCTAssertEqualObjects([FxGripTimecode stringForTime:FxGripTCFrame(29, df) frameDuration:df dropFrame:YES], @"00:00:00;29");
	XCTAssertEqualObjects([FxGripTimecode stringForTime:FxGripTCFrame(30, df) frameDuration:df dropFrame:YES], @"00:00:01;00");
	XCTAssertEqualObjects([FxGripTimecode stringForTime:FxGripTCFrame(1799, df) frameDuration:df dropFrame:YES], @"00:00:59;29");
}

- (void)testDropFrameSkipsTwoNumbersAtTheFirstMinute
{
	CMTime df = FxGripTC2997();

	XCTAssertEqualObjects([FxGripTimecode stringForTime:FxGripTCFrame(1800, df) frameDuration:df dropFrame:YES], @"00:01:00;02");
	XCTAssertEqualObjects([FxGripTimecode stringForTime:FxGripTCFrame(1801, df) frameDuration:df dropFrame:YES], @"00:01:00;03");
}

- (void)testDropFrameDoesNotSkipAtTheTenthMinute
{
	CMTime df = FxGripTC2997();

	// 17982 frames elapse in ten minutes at 29.97; the tenth minute keeps its first two numbers.
	XCTAssertEqualObjects([FxGripTimecode stringForTime:FxGripTCFrame(17981, df) frameDuration:df dropFrame:YES], @"00:09:59;29");
	XCTAssertEqualObjects([FxGripTimecode stringForTime:FxGripTCFrame(17982, df) frameDuration:df dropFrame:YES], @"00:10:00;00");
	XCTAssertEqualObjects([FxGripTimecode stringForTime:FxGripTCFrame(17982 + 1800, df) frameDuration:df dropFrame:YES], @"00:11:00;02");
}

- (void)testDropFrameRealignsWithWallClockEveryTenMinutes
{
	CMTime df = FxGripTC2997();

	// One hour of real time is 107892 frames at 29.97 and reads as 01:00:00;00 in drop frame.
	XCTAssertEqualObjects([FxGripTimecode stringForTime:FxGripTCFrame(107892, df) frameDuration:df dropFrame:YES], @"01:00:00;00");
}

- (void)testNonDropAtTwentyNineNinetySevenDriftsBehindWallClock
{
	CMTime df = FxGripTC2997();

	XCTAssertEqualObjects([FxGripTimecode stringForTime:FxGripTCFrame(1800, df) frameDuration:df dropFrame:NO], @"00:01:00:00");
	XCTAssertEqualObjects([FxGripTimecode stringForTime:FxGripTCFrame(107892, df) frameDuration:df dropFrame:NO], @"00:59:56:12");
}

#pragma mark - Drop frame at 59.94 and 119.88

- (void)testDropFrameAtFiftyNineNinetyFourSkipsFourNumbers
{
	CMTime df = FxGripTC5994();

	XCTAssertEqualObjects([FxGripTimecode stringForTime:FxGripTCFrame(3599, df) frameDuration:df dropFrame:YES], @"00:00:59;59");
	XCTAssertEqualObjects([FxGripTimecode stringForTime:FxGripTCFrame(3600, df) frameDuration:df dropFrame:YES], @"00:01:00;04");
	XCTAssertEqualObjects([FxGripTimecode stringForTime:FxGripTCFrame(35964, df) frameDuration:df dropFrame:YES], @"00:10:00;00");
}

- (void)testDropFrameAtOneNineteenEightyEightUsesThreeFrameDigits
{
	CMTime df = [FxGripTimecode frameDurationForRate:FxGripFrameRate_119_88];

	XCTAssertEqualObjects([FxGripTimecode stringForTime:FxGripTCFrame(7199, df) frameDuration:df dropFrame:YES], @"00:00:59;119");
	XCTAssertEqualObjects([FxGripTimecode stringForTime:FxGripTCFrame(7200, df) frameDuration:df dropFrame:YES], @"00:01:00;008");
	XCTAssertEqualObjects([FxGripTimecode stringForTime:FxGripTCFrame(71928, df) frameDuration:df dropFrame:YES], @"00:10:00;000");
}

- (void)testWholeRatesAtOneHundredAndAboveUseThreeFrameDigits
{
	CMTime df = [FxGripTimecode frameDurationForRate:FxGripFrameRate_120];

	XCTAssertEqualObjects([FxGripTimecode stringForTime:FxGripTCFrame(121, df) frameDuration:df dropFrame:NO], @"00:00:01:001");
}

@end
