//
//  FxGripPointOptionsTests.m
//  FxGripTests
//
//  Unit tests for FxGripPointOptions: the defaults applied to an empty declaration, the
//  typed parse of a full declaration, the pin display predicate, the enum clamping, the
//  color-array parse, and the mouse-speed guard.
//

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripPointOptions.h>
#import "FxGripTypes.h"

@interface FxGripPointOptionsTests : XCTestCase
@end

@implementation FxGripPointOptionsTests

#pragma mark Defaults

- (void)testAnEmptyDeclarationAppliesEveryDocumentedDefault
{
	FxGripPointOptions *options = [FxGripPointOptions.alloc initWithConfiguration:nil];

	XCTAssertEqual(options.defaultX, 0.5);
	XCTAssertEqual(options.defaultY, 0.5);
	XCTAssertEqual(options.rangeMinX, 0.0);
	XCTAssertEqual(options.rangeMaxX, 1.0);
	XCTAssertEqual(options.rangeMinY, 0.0);
	XCTAssertEqual(options.rangeMaxY, 1.0);
	XCTAssertEqual(options.coordinateMapping, FxGripPointCoordinatePixel);
	XCTAssertFalse(options.compensateFrameMargin);
	XCTAssertEqual(options.controlSize, 0.0);
	XCTAssertNil(options.controlColor);
	XCTAssertEqual(options.pinDistance, 0.0);
	XCTAssertFalse(options.displayAsPin);
	XCTAssertFalse(options.displayName);
	XCTAssertTrue(options.nameOnlyWhenAbove);
	XCTAssertEqual(options.mouseSpeed, 1.0);
	XCTAssertFalse(options.mouseSpeedShiftOnly);
	XCTAssertNil(options.backgroundImageName);
	XCTAssertEqual(options.backgroundImageSize, 1.0);
	XCTAssertEqual(options.constraint, FxGripPointConstraintAnyDirection);
	XCTAssertEqual(options.divider, FxGripPointDividerNone);
	XCTAssertEqual(options.maxDistance, 1.0);
	XCTAssertFalse(options.distanceShiftOneAxis);
}

- (void)testANonDictionaryConfigurationIsTreatedAsEmpty
{
	FxGripPointOptions *options = [FxGripPointOptions.alloc initWithConfiguration:(NSDictionary *)@"nonsense"];

	XCTAssertEqual(options.defaultX, 0.5);
	XCTAssertEqual(options.constraint, FxGripPointConstraintAnyDirection);
}

#pragma mark Full parse

- (void)testAFullDeclarationParsesEveryOption
{
	NSDictionary *config = @{
		kFxParameterProperty_X: @0.25, kFxParameterProperty_Y: @0.75,
		kFxGripPointKey_RangeMinX: @(-1.0), kFxGripPointKey_RangeMaxX: @2.0,
		kFxGripPointKey_RangeMinY: @(-2.0), kFxGripPointKey_RangeMaxY: @3.0,
		kFxGripPointKey_CoordinateMapping: @(FxGripPointCoordinateQuartzComposer),
		kFxGripPointKey_CompensateFrameMargin: @YES,
		kFxGripPointKey_ControlSize: @14.0,
		kFxGripPointKey_ControlColor: @[@1.0, @0.5, @0.0, @1.0],
		kFxGripPointKey_PinDistance: @30.0, kFxGripPointKey_PinAngle: @45.0,
		kFxGripPointKey_DisplayName: @YES, kFxGripPointKey_NameOnlyWhenAbove: @NO,
		kFxGripPointKey_MouseSpeed: @0.25, kFxGripPointKey_MouseSpeedShiftOnly: @YES,
		kFxGripPointKey_BackgroundImage: @"grid", kFxGripPointKey_BackgroundImageSize: @0.5,
		kFxGripPointKey_BackgroundImageX: @0.1, kFxGripPointKey_BackgroundImageY: @0.2,
		kFxGripPointKey_Constraint: @(FxGripPointConstraintDistance),
		kFxGripPointKey_Divider: @(FxGripPointDividerThickWithoutControl),
		kFxGripPointKey_DistanceFromX: @0.4, kFxGripPointKey_DistanceFromY: @0.6,
		kFxGripPointKey_MaxDistance: @0.3, kFxGripPointKey_DistanceShiftOneAxis: @YES,
	};

	FxGripPointOptions *options = [FxGripPointOptions.alloc initWithConfiguration:config];

	XCTAssertEqual(options.defaultX, 0.25);
	XCTAssertEqual(options.defaultY, 0.75);
	XCTAssertEqual(options.rangeMinX, -1.0);
	XCTAssertEqual(options.rangeMaxY, 3.0);
	XCTAssertEqual(options.coordinateMapping, FxGripPointCoordinateQuartzComposer);
	XCTAssertTrue(options.compensateFrameMargin);
	XCTAssertEqual(options.controlSize, 14.0);
	XCTAssertNotNil(options.controlColor);
	XCTAssertEqual(options.pinDistance, 30.0);
	XCTAssertEqual(options.pinAngle, 45.0);
	XCTAssertTrue(options.displayAsPin);
	XCTAssertTrue(options.displayName);
	XCTAssertFalse(options.nameOnlyWhenAbove);
	XCTAssertEqual(options.mouseSpeed, 0.25);
	XCTAssertTrue(options.mouseSpeedShiftOnly);
	XCTAssertEqualObjects(options.backgroundImageName, @"grid");
	XCTAssertEqual(options.backgroundImageSize, 0.5);
	XCTAssertEqual(options.backgroundImageX, 0.1);
	XCTAssertEqual(options.backgroundImageY, 0.2);
	XCTAssertEqual(options.constraint, FxGripPointConstraintDistance);
	XCTAssertEqual(options.divider, FxGripPointDividerThickWithoutControl);
	XCTAssertEqual(options.distanceFromX, 0.4);
	XCTAssertEqual(options.maxDistance, 0.3);
	XCTAssertTrue(options.distanceShiftOneAxis);
}

#pragma mark Guards

- (void)testAThreeElementColorArrayDefaultsAlphaToOpaque
{
	FxGripPointOptions *options = [FxGripPointOptions.alloc initWithConfiguration:@{
		kFxGripPointKey_ControlColor: @[@0.2, @0.4, @0.6]}];

	XCTAssertNotNil(options.controlColor);
	XCTAssertEqual(options.controlColor.alphaComponent, 1.0);
}

- (void)testAShortOrNonArrayColorIsIgnored
{
	FxGripPointOptions *shortArray = [FxGripPointOptions.alloc initWithConfiguration:@{
		kFxGripPointKey_ControlColor: @[@0.2, @0.4]}];
	FxGripPointOptions *notAnArray = [FxGripPointOptions.alloc initWithConfiguration:@{
		kFxGripPointKey_ControlColor: @"blue"}];

	XCTAssertNil(shortArray.controlColor);
	XCTAssertNil(notAnArray.controlColor);
}

- (void)testAnOutOfRangeConstraintOrDividerFallsBackToTheNeutralValue
{
	FxGripPointOptions *options = [FxGripPointOptions.alloc initWithConfiguration:@{
		kFxGripPointKey_Constraint: @99, kFxGripPointKey_Divider: @(-3)}];

	XCTAssertEqual(options.constraint, FxGripPointConstraintAnyDirection);
	XCTAssertEqual(options.divider, FxGripPointDividerNone);
}

- (void)testANonPositiveMouseSpeedFallsBackToOne
{
	XCTAssertEqual([FxGripPointOptions.alloc initWithConfiguration:@{kFxGripPointKey_MouseSpeed: @0.0}].mouseSpeed, 1.0);
	XCTAssertEqual([FxGripPointOptions.alloc initWithConfiguration:@{kFxGripPointKey_MouseSpeed: @(-2.0)}].mouseSpeed, 1.0);
}

- (void)testAZeroPinDistanceIsNotAPin
{
	FxGripPointOptions *options = [FxGripPointOptions.alloc initWithConfiguration:@{kFxGripPointKey_PinDistance: @0.0}];
	XCTAssertFalse(options.displayAsPin);
}

@end
