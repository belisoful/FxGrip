/*!
	@file       FxGripParameterBoundsAPI_v1Tests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripParameterBoundsAPI_v1Tests
	@abstract   Verifies that the single-bound convenience setters read the current bounds, change only the named value, and write the full set back.
	@discussion Introduced in FxGrip 0.1.0. Each test drives one float or int setter against a recording stub host and asserts the complete bounds write. A failed read of the current bounds skips the write.
*/

#import "FxGripDynamicAPITestSupport.h"
#import <FxGrip/FxGripParameterBoundsAPI_v1.h>

@interface FxGripParameterBoundsAPI_v1Tests : FxGripDynamicAPITestCase
@end

@implementation FxGripParameterBoundsAPI_v1Tests

#pragma mark Single-bound float setters

/*! @abstract Setting only the float minimum writes the new minimum and keeps the maximum and both slider bounds from the host. */
- (void)testSettingOnlyTheFloatMinimumKeepsTheOtherBounds
{
	self.hostAPI.floatMinimum = -1;
	self.hostAPI.floatMaximum = 1;
	self.hostAPI.floatSliderMinimum = -0.5;
	self.hostAPI.floatSliderMaximum = 0.5;

	XCTAssertNil([self.apiBounds setParameter:kDynamicTestParameter floatMinimum:-3]);

	XCTAssertEqualObjects([self hostCallNamed:@"setfloatbounds"], (@{@"method": @"setfloatbounds",
																	@"id": @(kDynamicTestParameter),
																	@"min": @(-3.0),
																	@"max": @1.0,
																	@"slidermin": @(-0.5),
																	@"slidermax": @0.5}));
}

/*! @abstract Setting only the float maximum writes the new maximum and keeps the host's minimum. */
- (void)testSettingOnlyTheFloatMaximumKeepsTheOtherBounds
{
	self.hostAPI.floatMinimum = -1;
	self.hostAPI.floatMaximum = 1;

	XCTAssertNil([self.apiBounds setParameter:kDynamicTestParameter floatMaximum:5]);

	XCTAssertEqualObjects([self hostCallNamed:@"setfloatbounds"][@"min"], @(-1.0));
	XCTAssertEqualObjects([self hostCallNamed:@"setfloatbounds"][@"max"], @5.0);
}

/*! @abstract Setting the float minimum and maximum together writes both and keeps the host's slider bounds. */
- (void)testSettingTheFloatMinimumAndMaximumKeepsTheSliderBounds
{
	self.hostAPI.floatSliderMinimum = -0.5;
	self.hostAPI.floatSliderMaximum = 0.5;

	XCTAssertNil([self.apiBounds setParameter:kDynamicTestParameter floatMinimum:-2 maximum:2]);

	NSDictionary *call = [self hostCallNamed:@"setfloatbounds"];
	XCTAssertEqualObjects(call[@"min"], @(-2.0));
	XCTAssertEqualObjects(call[@"max"], @2.0);
	XCTAssertEqualObjects(call[@"slidermin"], @(-0.5));
	XCTAssertEqualObjects(call[@"slidermax"], @0.5);
}

/*! @abstract Setting the float slider bounds writes the slider range and keeps the host's parameter minimum and maximum. */
- (void)testSettingTheFloatSliderBoundsKeepsTheParameterBounds
{
	self.hostAPI.floatMinimum = -10;
	self.hostAPI.floatMaximum = 10;

	XCTAssertNil([self.apiBounds setParameter:kDynamicTestParameter floatSliderMinimum:-1]);
	XCTAssertNil([self.apiBounds setParameter:kDynamicTestParameter floatSliderMaximum:1]);
	XCTAssertNil([self.apiBounds setParameter:kDynamicTestParameter floatSliderMinimum:-2 sliderMaximum:2]);

	NSDictionary *last = self.hostAPI.calls.lastObject;
	XCTAssertEqualObjects(last[@"min"], @(-10.0));
	XCTAssertEqualObjects(last[@"max"], @10.0);
	XCTAssertEqualObjects(last[@"slidermin"], @(-2.0));
	XCTAssertEqualObjects(last[@"slidermax"], @2.0);
}

/*! @abstract A failed read of the current float bounds returns the host error and issues no bounds write. */
- (void)testAFailedBoundsReadSkipsTheBoundsWrite
{
	self.hostAPI.nextError = FxGripDynamicTestError();

	XCTAssertEqualObjects([self.apiBounds setParameter:kDynamicTestParameter floatMinimum:-3],
						  FxGripDynamicTestError());

	XCTAssertEqualObjects(self.hostMethods, @[@"getfloatbounds"]);
}

#pragma mark Single-bound int setters

/*! @abstract Setting only the int minimum writes the new minimum and keeps the maximum and both slider bounds from the host. */
- (void)testSettingOnlyTheIntMinimumKeepsTheOtherBounds
{
	self.hostAPI.intMinimum = 1;
	self.hostAPI.intMaximum = 100;
	self.hostAPI.intSliderMinimum = 2;
	self.hostAPI.intSliderMaximum = 50;

	XCTAssertNil([self.apiBounds setParameter:kDynamicTestParameter intMinimum:0]);

	XCTAssertEqualObjects([self hostCallNamed:@"setintbounds"], (@{@"method": @"setintbounds",
																   @"id": @(kDynamicTestParameter),
																   @"min": @0,
																   @"max": @100,
																   @"slidermin": @2,
																   @"slidermax": @50}));
}

/*! @abstract Setting only the int maximum writes the new maximum and keeps the host's minimum. */
- (void)testSettingOnlyTheIntMaximumKeepsTheOtherBounds
{
	self.hostAPI.intMinimum = 1;
	self.hostAPI.intMaximum = 100;

	XCTAssertNil([self.apiBounds setParameter:kDynamicTestParameter intMaximum:7]);

	XCTAssertEqualObjects([self hostCallNamed:@"setintbounds"][@"min"], @1);
	XCTAssertEqualObjects([self hostCallNamed:@"setintbounds"][@"max"], @7);
}

/*! @abstract Setting the int minimum and maximum together writes both and keeps the host's slider bounds. */
- (void)testSettingTheIntMinimumAndMaximumKeepsTheSliderBounds
{
	self.hostAPI.intSliderMinimum = 3;
	self.hostAPI.intSliderMaximum = 30;

	XCTAssertNil([self.apiBounds setParameter:kDynamicTestParameter intMinimum:0 maximum:9]);

	NSDictionary *call = [self hostCallNamed:@"setintbounds"];
	XCTAssertEqualObjects(call[@"min"], @0);
	XCTAssertEqualObjects(call[@"max"], @9);
	XCTAssertEqualObjects(call[@"slidermin"], @3);
	XCTAssertEqualObjects(call[@"slidermax"], @30);
}

/*! @abstract Setting the int slider bounds writes the slider range and keeps the host's parameter minimum and maximum. */
- (void)testSettingTheIntSliderBoundsKeepsTheParameterBounds
{
	self.hostAPI.intMinimum = -100;
	self.hostAPI.intMaximum = 100;

	XCTAssertNil([self.apiBounds setParameter:kDynamicTestParameter intSliderMinimum:-1]);
	XCTAssertNil([self.apiBounds setParameter:kDynamicTestParameter intSliderMaximum:1]);
	XCTAssertNil([self.apiBounds setParameter:kDynamicTestParameter intSliderMinimum:-2 sliderMaximum:2]);

	NSDictionary *last = self.hostAPI.calls.lastObject;
	XCTAssertEqualObjects(last[@"min"], @(-100));
	XCTAssertEqualObjects(last[@"max"], @100);
	XCTAssertEqualObjects(last[@"slidermin"], @(-2));
	XCTAssertEqualObjects(last[@"slidermax"], @2);
}

/*! @abstract A failed read of the current int bounds returns the host error and issues no bounds write. */
- (void)testAFailedIntBoundsReadSkipsTheBoundsWrite
{
	self.hostAPI.nextError = FxGripDynamicTestError();

	XCTAssertEqualObjects([self.apiBounds setParameter:kDynamicTestParameter intMinimum:0],
						  FxGripDynamicTestError());

	XCTAssertEqualObjects(self.hostMethods, @[@"getintbounds"]);
}

@end
