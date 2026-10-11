/*!
	@file       FxGripFCPXMLTimeTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripFCPXMLTimeTests
	@abstract   Tests the FCPXML rational time parser and formatter.
	@discussion Introduced in FxGrip 0.1.0. The tests cover the string forms Final Cut Pro writes, the
	            tolerated variants, the rejected forms, reduction to lowest terms, and frame alignment.
*/

#import <XCTest/XCTest.h>
#import <CoreMedia/CoreMedia.h>
#import <FxGrip/FxGripFCPXMLTime.h>

@interface FxGripFCPXMLTimeTests : XCTestCase
@end

@implementation FxGripFCPXMLTimeTests

- (void)testParsesRationalSeconds
{
	CMTime time = [FxGripFCPXMLTime timeFromString:@"1001/30000s"];
	XCTAssertTrue(CMTIME_IS_NUMERIC(time));
	XCTAssertEqual(time.value, 1001);
	XCTAssertEqual(time.timescale, 30000);
}

- (void)testParsesWholeSecondsAndZero
{
	CMTime five = [FxGripFCPXMLTime timeFromString:@"5s"];
	XCTAssertEqual(five.value, 5);
	XCTAssertEqual(five.timescale, 1);
	CMTime zero = [FxGripFCPXMLTime timeFromString:@"0s"];
	XCTAssertEqual(zero.value, 0);
	XCTAssertTrue(CMTIME_IS_NUMERIC(zero));
}

- (void)testParsesNegativeAndWhitespaceAndMissingSuffix
{
	CMTime negative = [FxGripFCPXMLTime timeFromString:@" -3/10s "];
	XCTAssertEqual(negative.value, -3);
	XCTAssertEqual(negative.timescale, 10);
	CMTime bare = [FxGripFCPXMLTime timeFromString:@"7/8"];
	XCTAssertEqual(bare.value, 7);
	XCTAssertEqual(bare.timescale, 8);
}

- (void)testRejectsMalformedStrings
{
	XCTAssertFalse(CMTIME_IS_VALID([FxGripFCPXMLTime timeFromString:nil]));
	XCTAssertFalse(CMTIME_IS_VALID([FxGripFCPXMLTime timeFromString:@""]));
	XCTAssertFalse(CMTIME_IS_VALID([FxGripFCPXMLTime timeFromString:@"s"]));
	XCTAssertFalse(CMTIME_IS_VALID([FxGripFCPXMLTime timeFromString:@"1/0s"]));
	XCTAssertFalse(CMTIME_IS_VALID([FxGripFCPXMLTime timeFromString:@"1/-5s"]));
	XCTAssertFalse(CMTIME_IS_VALID([FxGripFCPXMLTime timeFromString:@"abc"]));
	XCTAssertFalse(CMTIME_IS_VALID([FxGripFCPXMLTime timeFromString:@"1.5s"]));
	XCTAssertFalse(CMTIME_IS_VALID([FxGripFCPXMLTime timeFromString:@"1/99999999999s"]));
	XCTAssertFalse([FxGripFCPXMLTime isTimeString:@"1/2/3s"]);
	XCTAssertTrue([FxGripFCPXMLTime isTimeString:@"100/2400s"]);
}

- (void)testFormatsReducedToLowestTerms
{
	XCTAssertEqualObjects([FxGripFCPXMLTime stringFromTime:CMTimeMake(2002, 60000)], @"1001/30000s");
	XCTAssertEqualObjects([FxGripFCPXMLTime stringFromTime:CMTimeMake(600, 600)], @"1s");
	XCTAssertEqualObjects([FxGripFCPXMLTime stringFromTime:CMTimeMake(0, 24000)], @"0s");
	XCTAssertEqualObjects([FxGripFCPXMLTime stringFromTime:CMTimeMake(-1001, 30000)], @"-1001/30000s");
	XCTAssertNil([FxGripFCPXMLTime stringFromTime:kCMTimeInvalid]);
	XCTAssertNil([FxGripFCPXMLTime stringFromTime:kCMTimePositiveInfinity]);
}

- (void)testRoundTripsThroughString
{
	CMTime original = CMTimeMake(3003, 60000);
	CMTime parsed = [FxGripFCPXMLTime timeFromString:[FxGripFCPXMLTime stringFromTime:original]];
	XCTAssertEqual(CMTimeCompare(original, parsed), 0);
}

- (void)testFormatsSeconds
{
	XCTAssertEqualObjects([FxGripFCPXMLTime stringFromSeconds:0.5 timescale:600], @"1/2s");
	XCTAssertEqualObjects([FxGripFCPXMLTime stringFromSeconds:2 timescale:0], @"2s");
}

- (void)testReducesTime
{
	CMTime reduced = [FxGripFCPXMLTime reducedTime:CMTimeMake(300, 600)];
	XCTAssertEqual(reduced.value, 1);
	XCTAssertEqual(reduced.timescale, 2);
	CMTime zero = [FxGripFCPXMLTime reducedTime:CMTimeMake(0, 600)];
	XCTAssertEqual(zero.timescale, 1);
	XCTAssertFalse(CMTIME_IS_VALID([FxGripFCPXMLTime reducedTime:kCMTimeInvalid]));
}

- (void)testAlignsToFrameDuration
{
	CMTime frame = CMTimeMake(1001, 30000);
	// 0.1 s at 29.97 is 2.997 frames, so it aligns down to two frames.
	CMTime aligned = [FxGripFCPXMLTime time:CMTimeMake(1, 10) alignedToFrameDuration:frame];
	XCTAssertEqual(aligned.value, 2002);
	XCTAssertEqual(aligned.timescale, 30000);
	CMTime exact = [FxGripFCPXMLTime time:CMTimeMake(3003, 30000) alignedToFrameDuration:frame];
	XCTAssertEqual(exact.value, 3003);
	CMTime negative = [FxGripFCPXMLTime time:CMTimeMake(-1, 10) alignedToFrameDuration:frame];
	XCTAssertEqual(negative.value, -3003);
	CMTime unchanged = [FxGripFCPXMLTime time:CMTimeMake(1, 10) alignedToFrameDuration:kCMTimeZero];
	XCTAssertEqual(unchanged.value, 1);
	XCTAssertEqual(unchanged.timescale, 10);
}

@end
