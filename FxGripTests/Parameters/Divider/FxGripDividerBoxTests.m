/*!
	@file       FxGripDividerBoxTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-10
	@header     FxGripDividerBoxTests
	@abstract   Tests the separator box that draws a divider parameter's line.
	@discussion Introduced in FxGrip 0.1.0. The tests cover the golden-ratio defaults, the centering
	            layout the box performs when it joins a superview, the geometry it reads from an
	            FxGripDividerData or a plain dictionary, the lazily built container, and the margin
	            and height setters that keep the derived parameter height in sync.
*/

#import <XCTest/XCTest.h>
#import <AppKit/AppKit.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripDividerParameter.h>
#import <FxGrip/FxGripDividerData.h>
#import <FxGrip/FxGripDividerBox.h>

@interface FxGripDividerBoxTests : XCTestCase
@property (nonatomic, strong) FxGripDividerBox *box;
@end

@implementation FxGripDividerBoxTests

- (void)setUp
{
	[super setUp];
	self.box = [FxGripDividerBox.alloc initWithFrame:NSMakeRect(0, 0, 100, kFxGripBoxDividerHeight)];
}

- (void)tearDown
{
	self.box = nil;
	[super tearDown];
}

#pragma mark Helpers

/*! Centers the box inside a container of the given width, as the inspector's superview does. */
- (NSView *)containerOfWidth:(CGFloat)width
{
	NSView *container = [NSView.alloc initWithFrame:NSMakeRect(0, 0, width, 40)];
	[container addSubview:self.box];
	return container;
}

- (FxGripDividerData *)dataWithPercentWidth:(FxGripDividerSize)percentWidth
										top:(uint16)top
									 bottom:(uint16)bottom
{
	FxGripDividerData *data = [FxGripDividerData.alloc init];
	data.percentWidth = percentWidth;
	data.marginTop = top;
	data.marginBottom = bottom;
	return data;
}

#pragma mark Defaults

/*! @abstract A new box is a separator sized to the golden-ratio fraction with the house margins. */
- (void)testANewBoxCarriesTheGoldenRatioDefaults
{
	XCTAssertEqual(self.box.boxType, NSBoxSeparator);
	XCTAssertEqualWithAccuracy(self.box.percentWidth, phi - 1.0, 1e-12);
	XCTAssertEqual(self.box.marginTop, (uint16)7);
	XCTAssertEqual(self.box.marginBottom, (uint16)12);
	XCTAssertEqual(self.box.parameterHeight, (uint16)(7 + kFxGripBoxDividerHeight + 12));
}

/*! @abstract The box resizes with its container and stays centered in it. */
- (void)testTheBoxResizesWithItsContainerAndStaysCentered
{
	XCTAssertEqual(self.box.autoresizingMask,
				   (NSAutoresizingMaskOptions)(NSViewWidthSizable | NSViewMinXMargin | NSViewMaxXMargin));
}

#pragma mark Layout

/*! @abstract Joining a superview centers the box at the width fraction and lifts it by the bottom margin. */
- (void)testJoiningASuperviewCentersTheBoxAtTheWidthFraction
{
	[self containerOfWidth:200];

	CGFloat expectedWidth = 200.0 * (phi - 1.0);
	XCTAssertEqualWithAccuracy(self.box.frame.size.width, expectedWidth, 1e-9);
	XCTAssertEqualWithAccuracy(self.box.frame.origin.x, (200.0 - expectedWidth) / 2.0, 1e-9);
	XCTAssertEqualWithAccuracy(self.box.frame.origin.y, 12.0, 1e-9, @"the bottom margin lifts the line");
	XCTAssertEqualWithAccuracy(self.box.frame.size.height, kFxGripBoxDividerHeight, 1e-9);
}

/*! @abstract Setting the width fraction re-centers the box within its superview. */
- (void)testSettingTheWidthFractionRecentersTheBox
{
	[self containerOfWidth:200];

	self.box.percentWidth = 0.5;

	XCTAssertEqualWithAccuracy(self.box.frame.size.width, 100.0, 1e-9);
	XCTAssertEqualWithAccuracy(self.box.frame.origin.x, 50.0, 1e-9);
}

#pragma mark Margins and height

/*! @abstract Setting the top margin recomputes the parameter height and resizes the container. */
- (void)testSettingTheTopMarginResizesTheContainer
{
	NSView *container = self.box.topView;

	self.box.marginTop = 20;

	XCTAssertEqual(self.box.parameterHeight, (uint16)(20 + kFxGripBoxDividerHeight + 12));
	XCTAssertEqualWithAccuracy(container.frame.size.height, self.box.parameterHeight, 1e-9);
}

/*! @abstract Setting the bottom margin recomputes the height and lifts the line by the new margin. */
- (void)testSettingTheBottomMarginResizesTheContainerAndLiftsTheLine
{
	NSView *container = self.box.topView;

	self.box.marginBottom = 3;

	XCTAssertEqual(self.box.parameterHeight, (uint16)(7 + kFxGripBoxDividerHeight + 3));
	XCTAssertEqualWithAccuracy(container.frame.size.height, self.box.parameterHeight, 1e-9);
	XCTAssertEqualWithAccuracy(self.box.frame.origin.y, 3.0, 1e-9);
}

/*! @abstract Setting the parameter height splits it into margins around the line, giving the remainder to the bottom. */
- (void)testSettingTheParameterHeightSplitsItIntoMargins
{
	NSView *container = self.box.topView;

	self.box.parameterHeight = 41;

	XCTAssertEqual(self.box.marginTop, (uint16)20);
	XCTAssertEqual(self.box.marginBottom, (uint16)20);
	XCTAssertEqual(self.box.parameterHeight, (uint16)41);
	XCTAssertEqualWithAccuracy(container.frame.size.height, 41.0, 1e-9);
}

/*! @abstract An odd remainder in the height split lands on the bottom margin. */
- (void)testTheHeightSplitGivesTheOddPointToTheBottomMargin
{
	self.box.parameterHeight = 40;

	XCTAssertEqual(self.box.marginTop, (uint16)19);
	XCTAssertEqual(self.box.marginBottom, (uint16)20);
	XCTAssertEqual(self.box.parameterHeight, (uint16)40);
}

#pragma mark Container

/*! @abstract The container is built on first use, holds the box, and takes the parameter height. */
- (void)testTheContainerIsBuiltOnFirstUseAndHoldsTheBox
{
	NSView *container = self.box.topView;

	XCTAssertNotNil(container);
	XCTAssertEqualObjects(self.box.superview, container);
	XCTAssertEqualWithAccuracy(container.frame.size.height, self.box.parameterHeight, 1e-9);
	XCTAssertEqualObjects(self.box.topView, container, @"the container is built once");
}

#pragma mark Pushed value

/*! @abstract A pushed FxGripDividerData sets the width fraction, the margins, and the derived height. */
- (void)testAPushedDividerDataSetsTheGeometry
{
	NSView *container = self.box.topView;

	[self.box updateFromCustomData:[self dataWithPercentWidth:0.25 top:4 bottom:6]];

	XCTAssertEqualWithAccuracy(self.box.percentWidth, 0.25, 1e-12);
	XCTAssertEqual(self.box.marginTop, (uint16)4);
	XCTAssertEqual(self.box.marginBottom, (uint16)6);
	XCTAssertEqual(self.box.parameterHeight, (uint16)(4 + kFxGripBoxDividerHeight + 6));
	XCTAssertEqualWithAccuracy(container.frame.size.height, self.box.parameterHeight, 1e-9);
}

/*! @abstract A pushed dictionary sets the same geometry as the data object. */
- (void)testAPushedDictionarySetsTheGeometry
{
	[self containerOfWidth:200];

	[self.box updateFromCustomData:(id)@{@"percentWidth": @(0.5), @"marginTop": @(9), @"marginBottom": @(11)}];

	XCTAssertEqualWithAccuracy(self.box.percentWidth, 0.5, 1e-12);
	XCTAssertEqual(self.box.marginTop, (uint16)9);
	XCTAssertEqual(self.box.marginBottom, (uint16)11);
	XCTAssertEqualWithAccuracy(self.box.frame.size.width, 100.0, 1e-9, @"the box re-centers at the new fraction");
	XCTAssertEqualWithAccuracy(self.box.frame.origin.y, 11.0, 1e-9);
}

/*! @abstract A dictionary naming only one key leaves the other geometry alone. */
- (void)testAPartialDictionaryLeavesTheOtherGeometryAlone
{
	[self.box updateFromCustomData:(id)@{@"marginBottom": @(2)}];

	XCTAssertEqualWithAccuracy(self.box.percentWidth, phi - 1.0, 1e-12);
	XCTAssertEqual(self.box.marginTop, (uint16)7);
	XCTAssertEqual(self.box.marginBottom, (uint16)2);
}

/*! @abstract Pushing the geometry the box already carries changes nothing. */
- (void)testPushingTheCurrentGeometryChangesNothing
{
	NSView *container = self.box.topView;
	CGFloat height = container.frame.size.height;

	[self.box updateFromCustomData:[self dataWithPercentWidth:phi - 1.0 top:7 bottom:12]];

	XCTAssertEqual(self.box.parameterHeight, (uint16)(7 + kFxGripBoxDividerHeight + 12));
	XCTAssertEqualWithAccuracy(container.frame.size.height, height, 1e-9);
}

/*! @abstract A value that is neither divider data nor a dictionary is ignored. */
- (void)testAValueOfAnotherClassIsIgnored
{
	[self.box updateFromCustomData:(id)@"not a divider"];

	XCTAssertEqualWithAccuracy(self.box.percentWidth, phi - 1.0, 1e-12);
	XCTAssertEqual(self.box.marginTop, (uint16)7);
	XCTAssertEqual(self.box.marginBottom, (uint16)12);
}

/*! @abstract A geometry change reaches the box even before its container exists. */
- (void)testAGeometryChangeWithoutAContainerIsSafe
{
	XCTAssertNoThrow([self.box updateFromCustomData:[self dataWithPercentWidth:0.8 top:1 bottom:2]]);

	XCTAssertEqualWithAccuracy(self.box.percentWidth, 0.8, 1e-12);
	XCTAssertEqual(self.box.parameterHeight, (uint16)(1 + kFxGripBoxDividerHeight + 2));
}

@end
