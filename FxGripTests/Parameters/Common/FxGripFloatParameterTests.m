/*!
	@file       FxGripFloatParameterTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripFloatParameterTests
	@abstract   Tests FxGripFloatParameter: its FxPlug type identity and the creation payload
	            +addParameter:toEffect: derives from a configuration.
	@discussion Introduced in FxGrip 0.1.0. The tests confirm the defaults applied when the
	            configuration omits a bound, the slider-bound and delta fallbacks, the flag
	            forwarding, and the host-refusal result.
*/

#import <XCTest/XCTest.h>
#import "FxGripParameterClassTestSupport.h"
#import <FxGrip/FxGripFloatParameter.h>

static const FxParameterId kFloatTestParameter = 21;

@interface FxGripFloatParameterTests : XCTestCase
@property (nonatomic, strong) FxGripParamClassTestEffect *effect;
@end

@implementation FxGripFloatParameterTests

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
	NSDictionary *config = FxGripParamClassTestConfig(kFloatTestParameter, type, @"Amount", extra);
	return [parameterClass addParameter:config toEffect:(id)self.effect];
}

#pragma mark Type identity

/*! @abstract The class reports the FxPlug float type and its type string. */
- (void)testReportsItsFxPlugTypeAndTypeString
{
	XCTAssertEqual(FxGripFloatParameter.parameterType, FxParameterType_Float);
	XCTAssertEqualObjects(FxGripFloatParameter.parameterTypeString, kFxParameterType_Float);
}

/*! @abstract An instance reports the float type through its instance parameterType accessor. */
- (void)testAnInstanceReportsTheClassTypeThroughTheInstanceAccessor
{
	NSDictionary *config = FxGripParamClassTestConfig(kFloatTestParameter, kFxParameterType_Float, @"Amount", nil);
	FxGripFloatParameter *parameter = [FxGripFloatParameter.alloc initWithDictionary:config
																			  effect:(id)self.effect];

	XCTAssertNotNil(parameter);
	XCTAssertEqual(parameter.parameterType, FxParameterType_Float);
}

#pragma mark Creation payload

/*! @abstract A float created with no bounds defaults to a zero-to-one range and a hundredth delta. */
- (void)testFloatWithoutBoundsUsesZeroToOneAndTheHundredthDelta
{
	XCTAssertTrue([self add:FxGripFloatParameter.class type:kFxParameterType_Float extra:nil]);

	XCTAssertEqualObjects(self.call, (@{@"method": @"float",
										@"name": @"Amount",
										@"id": @(kFloatTestParameter),
										@"default": @0.0,
										@"min": @0.0,
										@"max": @1.0,
										@"slidermin": @0.0,
										@"slidermax": @1.0,
										@"delta": @0.01,
										@"flags": @(kFxParameterFlag_DEFAULT)}));
}

/*! @abstract A float forwards every declared bound and the declared delta to the creation call. */
- (void)testFloatForwardsEveryDeclaredBoundAndTheDeclaredDelta
{
	NSDictionary *extra = @{kFxParameterProperty_Default: @0.5,
							kFxParameterProperty_Minimum: @(-2.0),
							kFxParameterProperty_Maximum: @3.0,
							kFxParameterProperty_SliderMinimum: @(-1.0),
							kFxParameterProperty_SliderMaximum: @2.0,
							kFxParameterProperty_Delta: @0.25};

	XCTAssertTrue([self add:FxGripFloatParameter.class type:kFxParameterType_Float extra:extra]);

	XCTAssertEqualObjects(self.call, (@{@"method": @"float",
										@"name": @"Amount",
										@"id": @(kFloatTestParameter),
										@"default": @0.5,
										@"min": @(-2.0),
										@"max": @3.0,
										@"slidermin": @(-1.0),
										@"slidermax": @2.0,
										@"delta": @0.25,
										@"flags": @(kFxParameterFlag_DEFAULT)}));
}

/*! @abstract The slider bounds fall back to the parameter bounds when none are declared. */
- (void)testFloatSliderBoundsFallBackToTheParameterBounds
{
	NSDictionary *extra = @{kFxParameterProperty_Minimum: @(-5.0),
							kFxParameterProperty_Maximum: @5.0};

	XCTAssertTrue([self add:FxGripFloatParameter.class type:kFxParameterType_Float extra:extra]);

	XCTAssertEqualObjects(self.call[@"slidermin"], @(-5.0));
	XCTAssertEqualObjects(self.call[@"slidermax"], @5.0);
}

/*! @abstract The delta falls back to one when the declared range is wider than a unit. */
- (void)testFloatDeltaFallsBackToOneWhenTheRangeIsNotUnit
{
	NSDictionary *extra = @{kFxParameterProperty_Minimum: @0.0,
							kFxParameterProperty_Maximum: @10.0};

	XCTAssertTrue([self add:FxGripFloatParameter.class type:kFxParameterType_Float extra:extra]);

	XCTAssertEqualObjects(self.call[@"delta"], @1.0);
}

/*! @abstract The delta falls back to a hundredth for a unit-wide range at any offset. */
- (void)testFloatDeltaFallsBackToAHundredthForAnyUnitWideRange
{
	NSDictionary *extra = @{kFxParameterProperty_Minimum: @(-3.0),
							kFxParameterProperty_Maximum: @(-2.0)};

	XCTAssertTrue([self add:FxGripFloatParameter.class type:kFxParameterType_Float extra:extra]);

	XCTAssertEqualObjects(self.call[@"delta"], @0.01);
}

/*! @abstract The declared flag strings are combined into the flag bitmask sent to the host. */
- (void)testFloatCarriesTheConfiguredFlagsThrough
{
	NSArray *flags = @[kParameterFlagString_HIDDEN, kParameterFlagString_DISABLED];
	NSDictionary *extra = @{kFxParameterProperty_Flags: flags};

	XCTAssertTrue([self add:FxGripFloatParameter.class type:kFxParameterType_Float extra:extra]);

	XCTAssertEqualObjects(self.call[@"flags"],
						  @(kFxParameterFlag_HIDDEN | kFxParameterFlag_DISABLED));
}

/*! @abstract A host refusal returns false after a single creation call. */
- (void)testFloatReportsAHostRefusal
{
	self.effect.apiManager.paramCreateAPIv5.succeeds = NO;

	XCTAssertFalse([self add:FxGripFloatParameter.class type:kFxParameterType_Float extra:nil]);
	XCTAssertEqual(self.effect.creationCalls.count, (NSUInteger)1);
}

#pragma mark Incomplete configurations

/*!
	The NSDictionary+FxGripTileableEffect accessors answer only for a record carrying "id",
	"type", and "name". A configuration missing the name reads back as an unnamed parameter
	whose every property is the fallback, which is what the host then receives.
*/
- (void)testAConfigurationMissingTheNameFallsBackToTheUnnamedParameterID
{
	NSDictionary *config = @{kFxParameterProperty_Id: @(kFloatTestParameter),
							 kFxParameterProperty_Type: kFxParameterType_Float,
							 kFxParameterProperty_Default: @0.5};

	XCTAssertTrue([FxGripFloatParameter addParameter:config toEffect:(id)self.effect]);

	XCTAssertEqualObjects(self.call[@"name"], NSNull.null);
	XCTAssertEqualObjects(self.call[@"id"], @((UInt32)kFxParameterId_None));
	XCTAssertEqualObjects(self.call[@"default"], @0.0, @"the declared default is unreachable");
	XCTAssertEqualObjects(self.call[@"flags"], @(kFxParameterFlag_INVALID));
}

@end
