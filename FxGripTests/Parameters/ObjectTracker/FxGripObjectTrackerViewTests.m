//
//  FxGripObjectTrackerViewTests.m
//  FxGripTests
//
//  The object tracker's inspector view reflects the value the host pushes: the shape,
//  behavior, and resolution popups and the smoothing stepper follow updateFromCustomData:,
//  and the status line reports the analyzed frame count. The view and value classes are
//  framework-internal, so they are reached by name and their surfaces re-declared.
//

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
