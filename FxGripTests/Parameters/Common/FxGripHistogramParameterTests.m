/*!
	@file       FxGripHistogramParameterTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripHistogramParameterTests
	@abstract   Tests FxGripHistogramParameter: its FxPlug type identity and the name-ID-flags
	            payload it hands the creation API.
	@discussion Introduced in FxGrip 0.1.0. The tests confirm the host-refusal result, the
	            per-channel value read, and a channel the host refuses keeping its zero
	            histogram values.
*/

#import <XCTest/XCTest.h>
#import "FxGripParameterClassTestSupport.h"
#import <FxGrip/FxGripHistogramParameter.h>

static const FxParameterId kHistogramTestParameter = 51;

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

@end
