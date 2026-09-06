/*!
	@file       FxGripTrackingOpacityParameterTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripTrackingOpacityParameterTests
	@abstract   Tests the FxGripTrackingOpacityParameter type identity and creation payload.
	@discussion Introduced in FxGrip 0.1.0. The tests cover the type identity, the percent parameter that rests at full opacity with editing and keyframing disabled, the declared default that lowers the resting value, the driven flags added on top of the configured flags, and the host-refusal result.
*/

#import <XCTest/XCTest.h>
#import "FxGripParameterClassTestSupport.h"
#import <FxGrip/FxGripTrackingOpacityParameter.h>

static const FxParameterId kTrackingOpacityTestParameter = 21;

@interface FxGripTrackingOpacityParameterTests : XCTestCase
@property (nonatomic, strong) FxGripParamClassTestEffect *effect;
@end

@implementation FxGripTrackingOpacityParameterTests

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
	NSDictionary *config = FxGripParamClassTestConfig(kTrackingOpacityTestParameter, type, @"Amount", extra);
	return [parameterClass addParameter:config toEffect:(id)self.effect];
}

#pragma mark Type identity

/*! @abstract The parameter reports the tracking-opacity FxPlug type and the matching type string. */
- (void)testTrackingOpacityReportsItsFxPlugTypeAndTypeString
{
	XCTAssertEqual(FxGripTrackingOpacityParameter.parameterType, FxParameterType_TrackingOpacity);
	XCTAssertEqualObjects(FxGripTrackingOpacityParameter.parameterTypeString, kFxParameterType_TrackingOpacity);
}

#pragma mark Creation payload

/*! @abstract Creation registers a percent parameter that defaults to full opacity over the zero-to-one range with the disabled and non-animatable flags set. */
- (void)testTrackingOpacityRestsAtFullOpacityAndDisablesEditingAndKeyframing
{
	XCTAssertTrue([self add:FxGripTrackingOpacityParameter.class type:kFxParameterType_TrackingOpacity extra:nil]);

	XCTAssertEqualObjects(self.call, (@{@"method": @"percent",
										@"name": @"Amount",
										@"id": @(kTrackingOpacityTestParameter),
										@"default": @1.0,
										@"min": @0.0,
										@"max": @1.0,
										@"slidermin": @0.0,
										@"slidermax": @1.0,
										@"delta": @0.01,
										@"flags": @(kFxParameterFlag_DEFAULT | kFxParameterFlag_DISABLED
													| kFxParameterFlag_NOT_ANIMATABLE)}));
}

/*! @abstract A declared default lowers the resting opacity value. */
- (void)testTrackingOpacityLetsADeclaredDefaultLowerTheRestingValue
{
	NSDictionary *extra = @{kFxParameterProperty_Default: @0.5};

	XCTAssertTrue([self add:FxGripTrackingOpacityParameter.class type:kFxParameterType_TrackingOpacity extra:extra]);

	XCTAssertEqualObjects(self.call[@"default"], @0.5);
}

/*! @abstract The parameter adds its disabled and non-animatable flags on top of the configured flags. */
- (void)testTrackingOpacityAddsItsDrivenFlagsOnTopOfTheConfiguredFlags
{
	NSDictionary *extra = @{kFxParameterProperty_Flags: @[kParameterFlagString_HIDDEN]};

	XCTAssertTrue([self add:FxGripTrackingOpacityParameter.class type:kFxParameterType_TrackingOpacity extra:extra]);

	XCTAssertEqualObjects(self.call[@"flags"],
						  @(kFxParameterFlag_HIDDEN | kFxParameterFlag_DISABLED | kFxParameterFlag_NOT_ANIMATABLE));
}

/*! @abstract A host that refuses creation makes the add call return false. */
- (void)testTrackingOpacityReportsAHostRefusal
{
	self.effect.apiManager.paramCreateAPIv5.succeeds = NO;

	XCTAssertFalse([self add:FxGripTrackingOpacityParameter.class type:kFxParameterType_TrackingOpacity extra:nil]);
}

@end
