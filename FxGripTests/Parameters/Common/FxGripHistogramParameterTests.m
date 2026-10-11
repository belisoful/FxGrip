/*!
	@file       FxGripHistogramParameterTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripHistogramParameterTests
	@abstract   Tests FxGripHistogramParameter: its FxPlug type identity and the name-ID-flags
	            payload it hands the creation API.
	@discussion Introduced in FxGrip 0.1.0. The tests confirm the host-refusal result, the
	            per-channel value read, a channel the host refuses keeping its zero
	            histogram values, and reads and encoding on concurrent threads.
*/

#import <XCTest/XCTest.h>
#import "FxGripParameterClassTestSupport.h"
#import <FxGrip/FxGripHistogramParameter.h>
#import <FxGrip/NSCoder+FxPlug.h>

static const FxParameterId kHistogramTestParameter = 51;
static const size_t kHistogramTestConcurrentReads = 512;

/*! The black-in level the timed stub answers for a channel at a render time. */
static double FxGripHistogramTestLevel(int64_t time, int channel)
{
	return time + channel / 10.0;
}

/*!
	Answers each channel's levels as a function of the requested time and channel, so every
	concurrent read has one correct histogram. The shared stub records reads into an
	unsynchronized array, so this subclass answers without recording.
*/
@interface FxGripHistogramTestTimedRetrievalAPI : FxGripParamClassTestRetrievalAPI
@end

@implementation FxGripHistogramTestTimedRetrievalAPI

- (BOOL)getHistogramBlackIn:(double *)blackIn
				   BlackOut:(double *)blackOut
					WhiteIn:(double *)whiteIn
				   WhiteOut:(double *)whiteOut
					  Gamma:(double *)gammaValue
				 forChannel:(int)channel
			  fromParameter:(UInt32)parameterID
					 atTime:(CMTime)time
{
	double level = FxGripHistogramTestLevel(time.value, channel);
	*blackIn = level;
	*blackOut = level + 0.01;
	*whiteIn = level + 0.02;
	*whiteOut = level + 0.03;
	*gammaValue = level + 0.04;
	// Holds the read open so concurrent reads overlap.
	usleep(5);
	return YES;
}

@end

@interface FxGripHistogramParameterTests : XCTestCase
@property (nonatomic, strong) FxGripParamClassTestEffect *effect;
@end

@implementation FxGripHistogramParameterTests

- (void)setUp
{
	[super setUp];
	self.effect = [FxGripParamClassTestEffect.alloc init];
}

- (void)tearDown
{
	self.effect = nil;
	[super tearDown];
}

#pragma mark Helpers

- (NSDictionary *)call
{
	return self.effect.creationCall;
}

- (BOOL)add:(Class)parameterClass type:(NSString *)type extra:(NSDictionary *)extra
{
	NSDictionary *config = FxGripParamClassTestConfig(kHistogramTestParameter, type, @"Levels", extra);
	return [parameterClass addParameter:config toEffect:(id)self.effect];
}

/*! Asserts that a histogram holds the timed stub's levels for a render time. */
- (void)assertHistogram:(const FxGripHistogram *)histogram holdsTheLevelsForTime:(int64_t)time
{
	for (int channel = 0; channel < 5; channel++) {
		double level = FxGripHistogramTestLevel(time, channel);
		XCTAssertEqual(histogram->component[channel].blackIn, level, @"time %lld channel %d", time, channel);
		XCTAssertEqual(histogram->component[channel].whiteOut, level + 0.03, @"time %lld channel %d", time, channel);
		XCTAssertEqual(histogram->component[channel].gamma, level + 0.04, @"time %lld channel %d", time, channel);
		XCTAssertEqual(histogram->component[channel].channel, channel);
	}
}

- (FxGripHistogramParameter *)makeHistogramParameter
{
	NSDictionary *config = FxGripParamClassTestConfig(kHistogramTestParameter, kFxParameterType_Histogram, @"Levels", nil);
	return [FxGripHistogramParameter.alloc initWithDictionary:config effect:(id)self.effect];
}

#pragma mark Type identity

/*! @abstract The class reports the FxPlug histogram type and its type string. */
- (void)testReportsItsFxPlugTypeAndTypeString
{
	XCTAssertEqual(FxGripHistogramParameter.parameterType, FxParameterType_Histogram);
	XCTAssertEqualObjects(FxGripHistogramParameter.parameterTypeString, kFxParameterType_Histogram);
}

#pragma mark Creation payload

/*! @abstract A histogram hands the creation call only the name, ID, and flags. */
- (void)testHistogramForwardsOnlyTheNameIDAndFlags
{
	XCTAssertTrue([self add:FxGripHistogramParameter.class type:kFxParameterType_Histogram extra:nil]);

	XCTAssertEqualObjects(self.call, (@{@"method": @"histogram",
										@"name": @"Levels",
										@"id": @(kHistogramTestParameter),
										@"flags": @(kFxParameterFlag_DEFAULT)}));
}

/*! @abstract When the host creation API refuses, +addParameter:toEffect: returns false. */
- (void)testReportsAHostRefusal
{
	self.effect.apiManager.paramCreateAPIv5.succeeds = NO;

	XCTAssertFalse([self add:FxGripHistogramParameter.class type:kFxParameterType_Histogram extra:nil]);
}

#pragma mark Values

/*! @abstract -valueAtTime: reads all five channels and populates each component with its values. */
- (void)testHistogramValueAtTimeReadsEveryChannel
{
	FxGripHistogramParameter *parameter = [self makeHistogramParameter];
	FxGripParamClassTestRetrievalAPI *retrieval = self.effect.apiManager.paramGetAPIv6;
	retrieval.blackIn = 0.05;
	retrieval.blackOut = 0.1;
	retrieval.whiteIn = 0.8;
	retrieval.whiteOut = 0.9;
	retrieval.gamma = 1.5;

	FxGripHistogram *histogram = [parameter valueAtTime:FxGripParamClassTestTime(11, 30)];

	XCTAssertTrue(histogram != NULL);
	XCTAssertEqual(retrieval.reads.count, (NSUInteger)5);
	for (int channel = 0; channel < 5; channel++) {
		XCTAssertEqual(histogram->component[channel].blackIn, 0.05);
		XCTAssertEqual(histogram->component[channel].whiteOut, 0.9);
		XCTAssertEqual(histogram->component[channel].gamma, 1.5);
		XCTAssertEqual(histogram->component[channel].channel, channel);
		XCTAssertEqualObjects(retrieval.reads[channel][@"channel"], @(channel));
	}
}

/*! @abstract A channel the host refuses keeps its zero histogram values, with gamma left at one. */
- (void)testAChannelTheHostRefusesKeepsItsZeroHistogramValues
{
	FxGripHistogramParameter *parameter = [self makeHistogramParameter];
	FxGripParamClassTestRetrievalAPI *retrieval = self.effect.apiManager.paramGetAPIv6;
	retrieval.blackIn = 0.05;
	retrieval.gamma = 1.5;
	[retrieval.refusedHistogramChannels addObject:@2];

	FxGripHistogram *histogram = [parameter valueAtTime:FxGripParamClassTestTime(0, 1)];

	XCTAssertEqual(histogram->component[1].blackIn, 0.05);
	XCTAssertEqual(histogram->component[2].blackIn, 0.0);
	XCTAssertEqual(histogram->component[2].gamma, 1.0, @"the zero histogram leaves gamma at one");
}

/*! @abstract -getHistogram:atTime: fills the supplied histogram and reports that every channel read. */
- (void)testGetHistogramFillsTheSuppliedHistogram
{
	FxGripHistogramParameter *parameter = [self makeHistogramParameter];
	self.effect.apiManager.paramGetAPIv6.gamma = 1.5;
	FxGripHistogram histogram;

	XCTAssertTrue([parameter getHistogram:&histogram atTime:FxGripParamClassTestTime(0, 1)]);

	XCTAssertEqual(histogram.component[3].gamma, 1.5);
	XCTAssertEqual(histogram.component[3].channel, 3);
}

/*! @abstract -getHistogram:atTime: reports a refused channel, which keeps its zero histogram values. */
- (void)testGetHistogramReportsARefusedChannel
{
	FxGripHistogramParameter *parameter = [self makeHistogramParameter];
	FxGripParamClassTestRetrievalAPI *retrieval = self.effect.apiManager.paramGetAPIv6;
	retrieval.blackIn = 0.05;
	[retrieval.refusedHistogramChannels addObject:@2];
	FxGripHistogram histogram;

	XCTAssertFalse([parameter getHistogram:&histogram atTime:FxGripParamClassTestTime(0, 1)]);

	XCTAssertEqual(histogram.component[1].blackIn, 0.05);
	XCTAssertEqual(histogram.component[2].blackIn, 0.0);
}

/*! @abstract Concurrent -getHistogram:atTime: reads at different times each return the levels for their own time. */
- (void)testConcurrentGetHistogramReadsEachReturnTheirOwnLevels
{
	FxGripHistogramParameter *parameter = [self makeHistogramParameter];
	self.effect.apiManager.paramGetAPIv6 = FxGripHistogramTestTimedRetrievalAPI.new;
	NSMutableData *results = [NSMutableData dataWithLength:kHistogramTestConcurrentReads * sizeof(FxGripHistogram)];
	FxGripHistogram *histograms = results.mutableBytes;
	NSMutableData *outcomes = [NSMutableData dataWithLength:kHistogramTestConcurrentReads * sizeof(BOOL)];
	BOOL *everyChannelRead = outcomes.mutableBytes;

	dispatch_apply(kHistogramTestConcurrentReads, DISPATCH_APPLY_AUTO, ^(size_t index) {
		everyChannelRead[index] = [parameter getHistogram:&histograms[index]
												   atTime:FxGripParamClassTestTime((int64_t)index, 30)];
	});

	for (size_t index = 0; index < kHistogramTestConcurrentReads; index++) {
		XCTAssertTrue(everyChannelRead[index], @"read %zu", index);
		[self assertHistogram:&histograms[index] holdsTheLevelsForTime:(int64_t)index];
	}
}

/*! @abstract Concurrent -valueAtTime: reads at different times each return a histogram for their own time. */
- (void)testConcurrentValueAtTimeReadsEachReturnTheirOwnHistogram
{
	FxGripHistogramParameter *parameter = [self makeHistogramParameter];
	self.effect.apiManager.paramGetAPIv6 = FxGripHistogramTestTimedRetrievalAPI.new;
	NSMutableData *results = [NSMutableData dataWithLength:kHistogramTestConcurrentReads * sizeof(FxGripHistogram)];
	FxGripHistogram *histograms = results.mutableBytes;

	dispatch_apply(kHistogramTestConcurrentReads, DISPATCH_APPLY_AUTO, ^(size_t index) {
		histograms[index] = *[parameter valueAtTime:FxGripParamClassTestTime((int64_t)index, 30)];
	});

	for (size_t index = 0; index < kHistogramTestConcurrentReads; index++) {
		[self assertHistogram:&histograms[index] holdsTheLevelsForTime:(int64_t)index];
	}
}

#pragma mark Plugin state

/*! @abstract A plain coder, which is no plugin-state encoder, reads no histogram from the host. */
- (void)testHistogramEncodingWithAPlainCoderReadsNoValue
{
	FxGripHistogramParameter *parameter = [self makeHistogramParameter];
	NSKeyedArchiver *archiver = [NSKeyedArchiver.alloc initRequiringSecureCoding:NO];

	[parameter encodeWithCoder:archiver];

	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.reads, @[]);
}

/*! @abstract A plugin-state coder reads every channel at its own render time and encodes the histogram. */
- (void)testHistogramEncodingWithAPluginStateCoderEncodesEveryChannel
{
	FxGripHistogramParameter *parameter = [self makeHistogramParameter];
	self.effect.apiManager.paramGetAPIv6.gamma = 1.8;
	NSKeyedArchiver *archiver = [NSKeyedArchiver.alloc initRequiringSecureCoding:NO];
	archiver.renderTime = FxGripParamClassTestTime(21, 30);

	[parameter encodeWithCoder:archiver];
	[archiver finishEncoding];

	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.lastRead[@"timevalue"], @21);

	NSKeyedUnarchiver *unarchiver = [NSKeyedUnarchiver.alloc initForReadingFromData:archiver.encodedData error:NULL];
	unarchiver.requiresSecureCoding = NO;
	NSUInteger length = 0;
	const FxGripHistogram *decoded = (const FxGripHistogram *)[unarchiver decodeBytesAtIndex:kHistogramTestParameter
																			 returnedLength:&length];
	XCTAssertEqual(length, sizeof(FxGripHistogram));
	XCTAssertEqualWithAccuracy(decoded->component[0].gamma, 1.8, 1e-12);
}

/*! @abstract A histogram with a refused channel encodes nothing, because a partial read is not state. */
- (void)testAHistogramWithARefusedChannelEncodesNothing
{
	FxGripHistogramParameter *parameter = [self makeHistogramParameter];
	[self.effect.apiManager.paramGetAPIv6.refusedHistogramChannels addObject:@(kFxHistogramChannel_Blue)];
	[parameter valueAtTime:FxGripParamClassTestTime(0, 1)];
	NSKeyedArchiver *archiver = [NSKeyedArchiver.alloc initRequiringSecureCoding:NO];
	archiver.renderTime = FxGripParamClassTestTime(0, 1);

	[parameter encodeWithCoder:archiver];
	[archiver finishEncoding];

	NSKeyedUnarchiver *unarchiver = [NSKeyedUnarchiver.alloc initForReadingFromData:archiver.encodedData error:NULL];
	unarchiver.requiresSecureCoding = NO;
	NSUInteger length = 0;
	XCTAssertTrue([unarchiver decodeBytesAtIndex:kHistogramTestParameter returnedLength:&length] == NULL);
}

/*! @abstract Plugin-state coders on concurrent threads each encode the histogram for their own render time. */
- (void)testConcurrentEncodingEncodesEachCodersOwnHistogram
{
	FxGripHistogramParameter *parameter = [self makeHistogramParameter];
	self.effect.apiManager.paramGetAPIv6 = FxGripHistogramTestTimedRetrievalAPI.new;
	NSMutableData *results = [NSMutableData dataWithLength:kHistogramTestConcurrentReads * sizeof(FxGripHistogram)];
	FxGripHistogram *histograms = results.mutableBytes;

	dispatch_apply(kHistogramTestConcurrentReads, DISPATCH_APPLY_AUTO, ^(size_t index) {
		NSKeyedArchiver *archiver = [NSKeyedArchiver.alloc initRequiringSecureCoding:NO];
		archiver.renderTime = FxGripParamClassTestTime((int64_t)index, 30);
		[parameter encodeWithCoder:archiver];
		[archiver finishEncoding];
		NSKeyedUnarchiver *unarchiver = [NSKeyedUnarchiver.alloc initForReadingFromData:archiver.encodedData error:NULL];
		unarchiver.requiresSecureCoding = NO;
		NSUInteger length = 0;
		const void *decoded = [unarchiver decodeBytesAtIndex:kHistogramTestParameter returnedLength:&length];
		if (decoded && length == sizeof(FxGripHistogram)) {
			memcpy(&histograms[index], decoded, sizeof(FxGripHistogram));
		}
	});

	for (size_t index = 0; index < kHistogramTestConcurrentReads; index++) {
		[self assertHistogram:&histograms[index] holdsTheLevelsForTime:(int64_t)index];
	}
}

@end
