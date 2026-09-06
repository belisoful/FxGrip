/*!
	@file       FxGripPercentParameterTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripPercentParameterTests
	@abstract   Tests FxGripPercentParameter: its FxPlug type identity and the creation payload
	            +addParameter:toEffect: derives from a configuration.
	@discussion Introduced in FxGrip 0.1.0. The tests confirm the defaults matching the float
	            parameter, the delta fallback, and the host-refusal result.
*/

#import <XCTest/XCTest.h>
#import "FxGripParameterClassTestSupport.h"
#import <FxGrip/FxGripPercentParameter.h>

static const FxParameterId kPercentTestParameter = 21;

@interface FxGripPercentParameterTests : XCTestCase
@property (nonatomic, strong) FxGripParamClassTestEffect *effect;
@end

@implementation FxGripPercentParameterTests

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
	NSDictionary *config = FxGripParamClassTestConfig(kPercentTestParameter, type, @"Amount", extra);
	return [parameterClass addParameter:config toEffect:(id)self.effect];
}

#pragma mark Type identity

/*! @abstract The class reports the FxPlug percent type and its type string. */
- (void)testReportsItsFxPlugTypeAndTypeString
{
	XCTAssertEqual(FxGripPercentParameter.parameterType, FxParameterType_Percent);
	XCTAssertEqualObjects(FxGripPercentParameter.parameterTypeString, kFxParameterType_Percent);
}

#pragma mark Creation payload

/*! @abstract A percent created with no bounds uses the same zero-to-one defaults as a float. */
- (void)testPercentWithoutBoundsMatchesTheFloatDefaults
{
	XCTAssertTrue([self add:FxGripPercentParameter.class type:kFxParameterType_Percent extra:nil]);

	XCTAssertEqualObjects(self.call, (@{@"method": @"percent",
										@"name": @"Amount",
										@"id": @(kPercentTestParameter),
										@"default": @0.0,
										@"min": @0.0,
										@"max": @1.0,
										@"slidermin": @0.0,
										@"slidermax": @1.0,
										@"delta": @0.01,
										@"flags": @(kFxParameterFlag_DEFAULT)}));
}

/*! @abstract A percent forwards every declared bound and the declared delta to the creation call. */
- (void)testPercentForwardsEveryDeclaredBoundAndTheDeclaredDelta
{
	NSDictionary *extra = @{kFxParameterProperty_Default: @0.75,
							kFxParameterProperty_Minimum: @0.0,
							kFxParameterProperty_Maximum: @2.0,
							kFxParameterProperty_SliderMinimum: @0.25,
							kFxParameterProperty_SliderMaximum: @1.75,
							kFxParameterProperty_Delta: @0.05};

	XCTAssertTrue([self add:FxGripPercentParameter.class type:kFxParameterType_Percent extra:extra]);

	XCTAssertEqualObjects(self.call, (@{@"method": @"percent",
										@"name": @"Amount",
										@"id": @(kPercentTestParameter),
										@"default": @0.75,
										@"min": @0.0,
										@"max": @2.0,
										@"slidermin": @0.25,
										@"slidermax": @1.75,
										@"delta": @0.05,
										@"flags": @(kFxParameterFlag_DEFAULT)}));
}

/*! @abstract The delta falls back to one when the declared range is wider than a unit. */
- (void)testPercentDeltaFallsBackToOneWhenTheRangeIsNotUnit
{
	NSDictionary *extra = @{kFxParameterProperty_Maximum: @4.0};

	XCTAssertTrue([self add:FxGripPercentParameter.class type:kFxParameterType_Percent extra:extra]);

	XCTAssertEqualObjects(self.call[@"delta"], @1.0);
}

/*! @abstract When the host creation API refuses, +addParameter:toEffect: returns false. */
- (void)testPercentReportsAHostRefusal
{
	self.effect.apiManager.paramCreateAPIv5.succeeds = NO;

	XCTAssertFalse([self add:FxGripPercentParameter.class type:kFxParameterType_Percent extra:nil]);
}

@end
