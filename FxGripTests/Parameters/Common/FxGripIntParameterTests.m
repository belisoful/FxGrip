/*!
	@file       FxGripIntParameterTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripIntParameterTests
	@abstract   Tests FxGripIntParameter: its FxPlug type identity and the creation payload
	            +addParameter:toEffect: derives from a configuration.
	@discussion Introduced in FxGrip 0.1.0. The tests confirm the integer truncation of
	            fractional values, the host-refusal result, and the ignore-min/max flag
	            accessors an instance exposes.
*/

#import <XCTest/XCTest.h>
#import "FxGripParameterClassTestSupport.h"
#import <FxGrip/FxGripIntParameter.h>

static const FxParameterId kIntTestParameter = 21;

@interface FxGripIntParameterTests : XCTestCase
@property (nonatomic, strong) FxGripParamClassTestEffect *effect;
@end

@implementation FxGripIntParameterTests

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
	NSDictionary *config = FxGripParamClassTestConfig(kIntTestParameter, type, @"Amount", extra);
	return [parameterClass addParameter:config toEffect:(id)self.effect];
}

- (FxGripIntParameter *)makeIntParameter
{
	NSDictionary *config = FxGripParamClassTestConfig(kIntTestParameter, kFxParameterType_Integer, @"Count", nil);
	return [FxGripIntParameter.alloc initWithDictionary:config effect:(id)self.effect];
}

#pragma mark Type identity

/*! @abstract The class reports the FxPlug integer type and its type string. */
- (void)testReportsItsFxPlugTypeAndTypeString
{
	XCTAssertEqual(FxGripIntParameter.parameterType, FxParameterType_Int);
	XCTAssertEqualObjects(FxGripIntParameter.parameterTypeString, kFxParameterType_Integer);
}

#pragma mark Creation payload

/*! @abstract An integer created with no bounds defaults to a zero-to-one-hundred range and a unit delta. */
- (void)testIntWithoutBoundsUsesZeroToOneHundredAndAUnitDelta
{
	XCTAssertTrue([self add:FxGripIntParameter.class type:kFxParameterType_Integer extra:nil]);

	XCTAssertEqualObjects(self.call, (@{@"method": @"int",
										@"name": @"Amount",
										@"id": @(kIntTestParameter),
										@"default": @0,
										@"min": @0,
										@"max": @100,
										@"slidermin": @0,
										@"slidermax": @100,
										@"delta": @1,
										@"flags": @(kFxParameterFlag_DEFAULT)}));
}

/*!
	The creation wrapper had a defect forwarding every integer bound as the default value.
	This states the contract at the class boundary: the class reads each bound from its own
	configuration key before handing it to the API.
*/
- (void)testIntForwardsEachBoundFromItsOwnConfigurationKey
{
	NSDictionary *extra = @{kFxParameterProperty_Default: @5,
							kFxParameterProperty_Minimum: @1,
							kFxParameterProperty_Maximum: @100,
							kFxParameterProperty_SliderMinimum: @2,
							kFxParameterProperty_SliderMaximum: @50,
							kFxParameterProperty_Delta: @3};

	XCTAssertTrue([self add:FxGripIntParameter.class type:kFxParameterType_Integer extra:extra]);

	XCTAssertEqualObjects(self.call, (@{@"method": @"int",
										@"name": @"Amount",
										@"id": @(kIntTestParameter),
										@"default": @5,
										@"min": @1,
										@"max": @100,
										@"slidermin": @2,
										@"slidermax": @50,
										@"delta": @3,
										@"flags": @(kFxParameterFlag_DEFAULT)}));
}

/*! @abstract The slider bounds fall back to the parameter bounds when none are declared. */
- (void)testIntSliderBoundsFallBackToTheParameterBounds
{
	NSDictionary *extra = @{kFxParameterProperty_Minimum: @(-10),
							kFxParameterProperty_Maximum: @10};

	XCTAssertTrue([self add:FxGripIntParameter.class type:kFxParameterType_Integer extra:extra]);

	XCTAssertEqualObjects(self.call[@"slidermin"], @(-10));
	XCTAssertEqualObjects(self.call[@"slidermax"], @10);
}

/*! @abstract A fractional default and delta are truncated to integers. */
- (void)testIntTruncatesAFractionalConfigurationValue
{
	NSDictionary *extra = @{kFxParameterProperty_Default: @7.9,
							kFxParameterProperty_Delta: @2.5};

	XCTAssertTrue([self add:FxGripIntParameter.class type:kFxParameterType_Integer extra:extra]);

	XCTAssertEqualObjects(self.call[@"default"], @7);
	XCTAssertEqualObjects(self.call[@"delta"], @2);
}

/*! @abstract When the host creation API refuses, +addParameter:toEffect: returns false. */
- (void)testIntReportsAHostRefusal
{
	self.effect.apiManager.paramCreateAPIv5.succeeds = NO;

	XCTAssertFalse([self add:FxGripIntParameter.class type:kFxParameterType_Integer extra:nil]);
}

#pragma mark Instance flags

/*! @abstract The flagIgnoreMinMax accessor reads the IGNORE_MINMAX bit from the host flags. */
- (void)testIgnoreMinMaxReadsTheHostFlags
{
	FxGripIntParameter *parameter = [self makeIntParameter];
	self.effect.apiManager.paramGetAPIv6.flags = kFxParameterFlag_IGNORE_MINMAX;

	XCTAssertTrue(parameter.flagIgnoreMinMax);

	self.effect.apiManager.paramGetAPIv6.flags = kFxParameterFlag_DEFAULT;
	XCTAssertFalse(parameter.flagIgnoreMinMax);
}

/*! @abstract Setting flagIgnoreMinMax adds the bit to the existing flags and writes them to the host. */
- (void)testSettingIgnoreMinMaxWritesTheBitToTheHost
{
	FxGripIntParameter *parameter = [self makeIntParameter];
	self.effect.apiManager.paramGetAPIv6.flags = kFxParameterFlag_HIDDEN;

	parameter.flagIgnoreMinMax = YES;

	NSArray *expected = @[@{@"flags": @(kFxParameterFlag_HIDDEN | kFxParameterFlag_IGNORE_MINMAX),
							@"id": @(kIntTestParameter)}];
	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.setFlagsCalls, expected);
}

/*! @abstract Clearing flagIgnoreMinMax removes only that bit and leaves the other flags set. */
- (void)testClearingIgnoreMinMaxRemovesOnlyThatBit
{
	FxGripIntParameter *parameter = [self makeIntParameter];
	self.effect.apiManager.paramGetAPIv6.flags = kFxParameterFlag_IGNORE_MINMAX | kFxParameterFlag_HIDDEN;

	parameter.flagIgnoreMinMax = NO;

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.setFlagsCalls.firstObject[@"flags"],
						  @(kFxParameterFlag_HIDDEN));
}

/*! @abstract Setting flagIgnoreMinMax to its current state writes nothing to the host. */
- (void)testSettingIgnoreMinMaxToItsCurrentStateWritesNothing
{
	FxGripIntParameter *parameter = [self makeIntParameter];
	self.effect.apiManager.paramGetAPIv6.flags = kFxParameterFlag_IGNORE_MINMAX;

	parameter.flagIgnoreMinMax = YES;

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.setFlagsCalls, @[]);
}

@end
