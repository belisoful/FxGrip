//
//  FxGripAngleParameterTests.m
//  FxGripTests
//
//  Unit tests for FxGripAngleParameter: the type identity, the payload
//  +addParameter:toEffect: derives from a configuration, the full-turn default range, the
//  omission of slider bounds and delta from the angle creation method, and the host-refusal
//  result.
//

#import <XCTest/XCTest.h>
#import "FxGripParameterClassTestSupport.h"
#import <FxGrip/FxGripAngleParameter.h>

static const FxParameterId kAngleTestParameter = 21;

@interface FxGripAngleParameterTests : XCTestCase
@property (nonatomic, strong) FxGripParamClassTestEffect *effect;
@end

@implementation FxGripAngleParameterTests

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
	NSDictionary *config = FxGripParamClassTestConfig(kAngleTestParameter, type, @"Amount", extra);
	return [parameterClass addParameter:config toEffect:(id)self.effect];
}

#pragma mark Type identity

- (void)testReportsItsFxPlugTypeAndTypeString
{
	XCTAssertEqual(FxGripAngleParameter.parameterType, FxParameterType_Angle);
	XCTAssertEqualObjects(FxGripAngleParameter.parameterTypeString, kFxParameterType_Angle);
}

#pragma mark Creation payload

- (void)testAngleWithoutBoundsSpansAFullTurn
{
	XCTAssertTrue([self add:FxGripAngleParameter.class type:kFxParameterType_Angle extra:nil]);

	XCTAssertEqualObjects(self.call, (@{@"method": @"angle",
										@"name": @"Amount",
										@"id": @(kAngleTestParameter),
										@"default": @0.0,
										@"min": @0.0,
										@"max": @360.0,
										@"flags": @(kFxParameterFlag_DEFAULT)}));
}

- (void)testAngleForwardsTheDeclaredDegreesAndBounds
{
	NSDictionary *extra = @{kFxParameterProperty_Default: @45.0,
							kFxParameterProperty_Minimum: @(-180.0),
							kFxParameterProperty_Maximum: @180.0};

	XCTAssertTrue([self add:FxGripAngleParameter.class type:kFxParameterType_Angle extra:extra]);

	XCTAssertEqualObjects(self.call, (@{@"method": @"angle",
										@"name": @"Amount",
										@"id": @(kAngleTestParameter),
										@"default": @45.0,
										@"min": @(-180.0),
										@"max": @180.0,
										@"flags": @(kFxParameterFlag_DEFAULT)}));
}

- (void)testAngleIgnoresSliderBoundsAndDelta
{
	NSDictionary *extra = @{kFxParameterProperty_SliderMinimum: @10.0,
							kFxParameterProperty_SliderMaximum: @20.0,
							kFxParameterProperty_Delta: @5.0};

	XCTAssertTrue([self add:FxGripAngleParameter.class type:kFxParameterType_Angle extra:extra]);

	XCTAssertNil(self.call[@"slidermin"], @"the angle creation method takes no slider bounds");
	XCTAssertNil(self.call[@"delta"]);
	XCTAssertEqualObjects(self.call[@"max"], @360.0);
}

- (void)testAngleReportsAHostRefusal
{
	self.effect.apiManager.paramCreateAPIv5.succeeds = NO;

	XCTAssertFalse([self add:FxGripAngleParameter.class type:kFxParameterType_Angle extra:nil]);
}

@end
