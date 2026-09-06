//
//  FxGripImageRefParameterTests.m
//  FxGripTests
//
//  Unit tests for FxGripImageRefParameter: the type identity, the name-ID-flags payload it
//  hands the creation API, the host-refusal result, the always-included filters, and the
//  start time and duration it reads from the timing API.
//

#import <XCTest/XCTest.h>
#import "FxGripParameterClassTestSupport.h"
#import <FxGrip/FxGripImageRefParameter.h>

static const FxParameterId kImageRefTestParameter = 51;

@interface FxGripImageRefParameterTests : XCTestCase
@property (nonatomic, strong) FxGripParamClassTestEffect *effect;
@end

@implementation FxGripImageRefParameterTests

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
	NSDictionary *config = FxGripParamClassTestConfig(kImageRefTestParameter, type, @"Levels", extra);
	return [parameterClass addParameter:config toEffect:(id)self.effect];
}

- (FxGripImageRefParameter *)makeImageRefParameter
{
	NSDictionary *config = FxGripParamClassTestConfig(kImageRefTestParameter, kFxParameterType_ImageRef, @"Levels", nil);
	return [FxGripImageRefParameter.alloc initWithDictionary:config effect:(id)self.effect];
}

#pragma mark Type identity

- (void)testReportsItsFxPlugTypeAndTypeString
{
	XCTAssertEqual(FxGripImageRefParameter.parameterType, FxParameterType_ImageRef);
	XCTAssertEqualObjects(FxGripImageRefParameter.parameterTypeString, kFxParameterType_ImageRef);
}

#pragma mark Creation payload

- (void)testImageReferenceForwardsOnlyTheNameIDAndFlags
{
	XCTAssertTrue([self add:FxGripImageRefParameter.class type:kFxParameterType_ImageRef extra:nil]);

	XCTAssertEqualObjects(self.call, (@{@"method": @"imageref",
										@"name": @"Levels",
										@"id": @(kImageRefTestParameter),
										@"flags": @(kFxParameterFlag_DEFAULT)}));
}

- (void)testReportsAHostRefusal
{
	self.effect.apiManager.paramCreateAPIv5.succeeds = NO;

	XCTAssertFalse([self add:FxGripImageRefParameter.class type:kFxParameterType_ImageRef extra:nil]);
}

#pragma mark Values

- (void)testAnImageReferenceAlwaysIncludesFilters
{
	XCTAssertTrue([self makeImageRefParameter].includeFilters);
}

- (void)testImageReferenceStartTimeComesFromTheTimingAPI
{
	FxGripImageRefParameter *parameter = [self makeImageRefParameter];
	self.effect.apiManager.timingAPIv4.startTime = FxGripParamClassTestTime(15, 30);

	CMTime start = parameter.startTime;

	XCTAssertEqual(start.value, (int64_t)15);
	XCTAssertEqual(start.timescale, (int32_t)30);
	XCTAssertEqualObjects(self.effect.apiManager.timingAPIv4.queries.lastObject,
						  (@{@"accessor": @"start", @"id": @(kImageRefTestParameter)}));
}

- (void)testImageReferenceDurationComesFromTheTimingAPI
{
	FxGripImageRefParameter *parameter = [self makeImageRefParameter];
	self.effect.apiManager.timingAPIv4.durationTime = FxGripParamClassTestTime(90, 30);

	CMTime duration = parameter.durationTime;

	XCTAssertEqual(duration.value, (int64_t)90);
	XCTAssertEqualObjects(self.effect.apiManager.timingAPIv4.queries.lastObject[@"accessor"], @"duration");
}

@end
