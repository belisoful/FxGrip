/*!
	@file       FxGripObjectTrackerViewTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripObjectTrackerViewTests
	@abstract   Tests that the object tracker inspector view reflects the pushed value.
	@discussion Introduced in FxGrip 0.1.0. The tests verify that the shape, behavior, and resolution popups and the smoothing stepper follow updateFromCustomData:, and that the popups select the first option for a default value.
*/

#import <XCTest/XCTest.h>
#import <AppKit/AppKit.h>

@protocol FxGripCustomViewDataDelegate <NSObject>
- (void)updateFromCustomData:(NSObject<NSSecureCoding,NSCopying> *)value;
@end

@interface FxGripObjectTrackerData : NSObject
@property (nonatomic) NSInteger shape;
@property (nonatomic) NSInteger behavior;
@property (nonatomic) NSInteger resolution;
@property (nonatomic) NSInteger smoothing;
@end

@interface FxGripObjectTrackerViewTests : XCTestCase
@end

@implementation FxGripObjectTrackerViewTests

- (NSView<FxGripCustomViewDataDelegate> *)makeView
{
	Class viewClass = NSClassFromString(@"FxGripObjectTrackerView");
	return [[viewClass alloc] initWithFrame:NSMakeRect(0, 0, 240, 134)];
}

- (NSArray<NSPopUpButton *> *)popupsIn:(NSView *)view
{
	NSMutableArray<NSPopUpButton *> *popups = [NSMutableArray array];
	for (NSView *sub in view.subviews) {
		if ([sub isKindOfClass:NSPopUpButton.class]) {
			[popups addObject:(NSPopUpButton *)sub];
		}
	}
	return popups;
}

/*! @abstract A pushed value sets the shape, behavior, and resolution popups and the smoothing stepper to match. */
- (void)testPopupsAndStepperFollowTheValue
{
	NSView<FxGripCustomViewDataDelegate> *view = [self makeView];

	FxGripObjectTrackerData *data = [NSClassFromString(@"FxGripObjectTrackerData") new];
	data.shape = 1;
	data.behavior = 1;
	data.resolution = 1;
	data.smoothing = 3;
	[view updateFromCustomData:(id)data];

	NSArray<NSPopUpButton *> *popups = [self popupsIn:view];
	XCTAssertEqual(popups.count, 3u, @"shape, behavior, resolution");
	XCTAssertEqual(popups[0].selectedTag, 1, @"shape = Quadrilateral");
	XCTAssertEqual(popups[1].selectedTag, 1, @"behavior = Position and Scale");
	XCTAssertEqual(popups[2].selectedTag, 1, @"resolution = Half");

	NSStepper *stepper = nil;
	for (NSView *sub in view.subviews) {
		if ([sub isKindOfClass:NSStepper.class]) {
			stepper = (NSStepper *)sub;
		}
	}
	XCTAssertNotNil(stepper);
	XCTAssertEqual(stepper.integerValue, 3);
}

/*! @abstract A default value selects the first option in each popup. */
- (void)testDefaultsSelectTheFirstOptions
{
	NSView<FxGripCustomViewDataDelegate> *view = [self makeView];
	FxGripObjectTrackerData *data = [NSClassFromString(@"FxGripObjectTrackerData") new];
	[view updateFromCustomData:(id)data];

	NSArray<NSPopUpButton *> *popups = [self popupsIn:view];
	XCTAssertEqual(popups[0].selectedTag, 0, @"default shape = Rectangle");
	XCTAssertEqual(popups[2].selectedTag, 0, @"default resolution = Full");
}

@end
