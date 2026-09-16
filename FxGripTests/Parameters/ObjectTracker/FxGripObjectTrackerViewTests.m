/*!
	@file       FxGripObjectTrackerViewTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripObjectTrackerViewTests
	@abstract   Tests that the object tracker inspector view reflects the pushed value and writes edits back.
	@discussion Introduced in FxGrip 0.1.0. The tests verify that the shape, behavior, and resolution popups and the smoothing stepper follow updateFromCustomData:, that the popups select the first option for a default value, that the status line reports the analyzed frame count, that the rows lay out on resize, and that each control edit reads the current value, changes one option, and writes it back inside a host action bracket.
*/

#import <XCTest/XCTest.h>
#import <AppKit/AppKit.h>
#import <CoreMedia/CoreMedia.h>

@protocol FxGripCustomViewDataDelegate <NSObject>
- (void)updateFromCustomData:(NSObject<NSSecureCoding,NSCopying> *)value;
@end

@interface FxGripObjectTrackerData : NSObject
@property (nonatomic) NSInteger shape;
@property (nonatomic) NSInteger behavior;
@property (nonatomic) NSInteger resolution;
@property (nonatomic) NSInteger smoothing;
@property (readonly, nonatomic) NSUInteger sampleCount;
- (void)setSample:(id)sample atFrame:(NSInteger)frameIndex;
@end

/*! The tracked-sample class the value stores, reached by name. */
@interface FxGripObjectTrackerSample : NSObject
- (instancetype)initWithBoundingBox:(CGRect)boundingBox confidence:(float)confidence;
@end

/*! The members the control exposes to the parameter that hosts it, and its control actions. */
@protocol FxGripTrackerTestEditing <FxGripCustomViewDataDelegate>
@property (nonatomic, assign) id parameterEffect;
@property (nonatomic, assign) UInt32 parameterID;
- (void)shapeChanged:(nullable id)sender;
- (void)behaviorChanged:(nullable id)sender;
- (void)resolutionChanged:(nullable id)sender;
- (void)smoothingChanged:(nullable id)sender;
@end

#pragma mark - Host doubles

/*! Builds a CMTime without calling CoreMedia, which the test bundle does not link. */
static CMTime FxGripTrackerViewTestTime(int64_t value, int32_t timescale)
{
	CMTime time = {0};
	time.value = value;
	time.timescale = timescale;
	time.flags = kCMTimeFlags_Valid;
	return time;
}

/*! Stands in for the host's FxCustomParameterActionAPI_v4, counting the bracket calls. */
@interface FxGripTrackerTestActionAPI : NSObject
@property (nonatomic, assign) CMTime currentTime;
@property (nonatomic, assign) NSUInteger startCount;
@property (nonatomic, assign) NSUInteger endCount;
@end

@implementation FxGripTrackerTestActionAPI

- (instancetype)init
{
	self = [super init];
	if (self) {
		_currentTime = FxGripTrackerViewTestTime(60, 30);
	}
	return self;
}

- (void)startAction:(id)sender { self.startCount += 1; }
- (void)endAction:(id)sender { self.endCount += 1; }

@end

/*! Answers the custom-value read with the staged value. */
@interface FxGripTrackerTestGetAPI : NSObject
@property (nonatomic, strong, nullable) id customValue;
@property (nonatomic, assign) BOOL succeeds;
@property (nonatomic, assign) UInt32 lastReadParameterID;
@end

@implementation FxGripTrackerTestGetAPI

- (instancetype)init
{
	self = [super init];
	if (self) {
		_succeeds = YES;
	}
	return self;
}

- (BOOL)getCustomParameterValue:(NSObject *_Nullable *_Nullable)value
				  fromParameter:(UInt32)parameterID
						 atTime:(CMTime)time
{
	self.lastReadParameterID = parameterID;
	if (self.succeeds && value != NULL) {
		*value = self.customValue;
	}
	return self.succeeds;
}

@end

/*! Records the custom-value write the control performs. */
@interface FxGripTrackerTestSetAPI : NSObject
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *writes;
@end

@implementation FxGripTrackerTestSetAPI

- (instancetype)init
{
	self = [super init];
	if (self) {
		_writes = NSMutableArray.new;
	}
	return self;
}

- (BOOL)setCustomParameterValue:(id)value toParameter:(UInt32)parameterID atTime:(CMTime)time
{
	[self.writes addObject:@{@"value": value ?: NSNull.null,
							 @"id": @(parameterID),
							 @"timevalue": @(time.value)}];
	return YES;
}

@end

/*! Binds the three APIs an out-of-band edit reaches for. */
@interface FxGripTrackerTestAPIManager : NSObject
@property (nonatomic, strong) FxGripTrackerTestActionAPI *customParameterActionAPIv4;
@property (nonatomic, strong) FxGripTrackerTestGetAPI *paramGetAPIv6;
@property (nonatomic, strong) FxGripTrackerTestSetAPI *paramSetAPIv5;
@end

@implementation FxGripTrackerTestAPIManager

- (instancetype)init
{
	self = [super init];
	if (self) {
		_customParameterActionAPIv4 = [FxGripTrackerTestActionAPI.alloc init];
		_paramGetAPIv6 = [FxGripTrackerTestGetAPI.alloc init];
		_paramSetAPIv5 = [FxGripTrackerTestSetAPI.alloc init];
	}
	return self;
}

@end

/*! The effect host the control reads its API manager from. */
@interface FxGripTrackerTestEffect : NSObject
@property (nonatomic, strong) FxGripTrackerTestAPIManager *apiManager;
@end

@implementation FxGripTrackerTestEffect

- (instancetype)init
{
	self = [super init];
	if (self) {
		_apiManager = [FxGripTrackerTestAPIManager.alloc init];
	}
	return self;
}

@end

#pragma mark - Tests

@interface FxGripObjectTrackerViewTests : XCTestCase
@property (nonatomic, strong) FxGripTrackerTestEffect *effect;
@end

@implementation FxGripObjectTrackerViewTests

- (void)setUp
{
	[super setUp];
	self.effect = [FxGripTrackerTestEffect.alloc init];
}

- (void)tearDown
{
	self.effect = nil;
	[super tearDown];
}

- (NSView<FxGripCustomViewDataDelegate> *)makeView
{
	Class viewClass = NSClassFromString(@"FxGripObjectTrackerView");
	return [[viewClass alloc] initWithFrame:NSMakeRect(0, 0, 240, 134)];
}

/*! A control wired to the stub effect, so an edit writes back through the stub host APIs. */
- (NSView<FxGripTrackerTestEditing> *)makeWiredView
{
	NSView<FxGripTrackerTestEditing> *view = (NSView<FxGripTrackerTestEditing> *)[self makeView];
	view.parameterEffect = self.effect;
	view.parameterID = 55;
	return view;
}

- (FxGripTrackerTestSetAPI *)setter
{
	return self.effect.apiManager.paramSetAPIv5;
}

- (NSDictionary *)lastWrite
{
	return self.setter.writes.lastObject;
}

- (id)writtenValue
{
	return [self lastWrite][@"value"];
}

- (NSStepper *)stepperIn:(NSView *)view
{
	for (NSView *sub in view.subviews) {
		if ([sub isKindOfClass:NSStepper.class]) {
			return (NSStepper *)sub;
		}
	}
	return nil;
}

- (NSArray<NSTextField *> *)labelsIn:(NSView *)view
{
	NSMutableArray<NSTextField *> *labels = [NSMutableArray array];
	for (NSView *sub in view.subviews) {
		if ([sub isKindOfClass:NSTextField.class]) {
			[labels addObject:(NSTextField *)sub];
		}
	}
	return labels;
}

/*! The status line is the last text field the control lays out. */
- (NSTextField *)statusLabelIn:(NSView *)view
{
	return [self labelsIn:view].lastObject;
}

- (id)trackerDataWithSampleCount:(NSUInteger)count
{
	id data = [NSClassFromString(@"FxGripObjectTrackerData") new];
	Class sampleClass = NSClassFromString(@"FxGripObjectTrackerSample");
	for (NSUInteger frame = 0; frame < count; frame++) {
		id sample = [[sampleClass alloc] initWithBoundingBox:CGRectMake(0.1, 0.1, 0.2, 0.2) confidence:1.0f];
		[data setSample:sample atFrame:(NSInteger)frame];
	}
	return data;
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

/*! @abstract A value of another class leaves every control untouched. */
- (void)testAValueOfAnotherClassIsIgnored
{
	NSView<FxGripCustomViewDataDelegate> *view = [self makeView];
	FxGripObjectTrackerData *data = [NSClassFromString(@"FxGripObjectTrackerData") new];
	data.shape = 1;
	[view updateFromCustomData:(id)data];

	[view updateFromCustomData:(id)@"not tracker data"];

	XCTAssertEqual([self popupsIn:view][0].selectedTag, 1, @"the earlier value stands");
}

#pragma mark Status line

/*! @abstract An unanalyzed value reports that the tracker has not run. */
- (void)testTheStatusLineReportsAnUnanalyzedTracker
{
	NSView<FxGripCustomViewDataDelegate> *view = [self makeView];

	[view updateFromCustomData:(id)[NSClassFromString(@"FxGripObjectTrackerData") new]];

	XCTAssertEqualObjects([self statusLabelIn:view].stringValue, @"Not analyzed");
}

/*! @abstract An analyzed value reports the tracked frame count. */
- (void)testTheStatusLineReportsTheTrackedFrameCount
{
	NSView<FxGripCustomViewDataDelegate> *view = [self makeView];

	[view updateFromCustomData:(id)[self trackerDataWithSampleCount:4]];

	XCTAssertEqualObjects([self statusLabelIn:view].stringValue, @"Tracked 4 frames");
}

#pragma mark Layout

/*! @abstract The control lays out top-down and stacks its rows in that order. */
- (void)testTheControlLaysOutTopDown
{
	NSView *view = [self makeView];

	XCTAssertTrue(view.isFlipped);

	NSArray<NSPopUpButton *> *popups = [self popupsIn:view];
	XCTAssertLessThan(popups[0].frame.origin.y, popups[1].frame.origin.y);
	XCTAssertLessThan(popups[1].frame.origin.y, popups[2].frame.origin.y);
	XCTAssertLessThan(popups[2].frame.origin.y, [self stepperIn:view].frame.origin.y);
}

/*! @abstract Resizing the control widens its rows to the new width. */
- (void)testResizingWidensTheRows
{
	NSView *view = [self makeView];
	CGFloat before = [self popupsIn:view][0].frame.size.width;

	view.frame = NSMakeRect(0, 0, 400, 134);

	XCTAssertGreaterThan([self popupsIn:view][0].frame.size.width, before);
}

/*! @abstract A control narrower than the label column keeps a usable minimum row width. */
- (void)testANarrowControlKeepsAMinimumRowWidth
{
	NSView *view = [self makeView];

	view.frame = NSMakeRect(0, 0, 40, 134);

	XCTAssertEqualWithAccuracy([self popupsIn:view][0].frame.size.width, 60.0, 1e-9);
}

#pragma mark Edits

/*! @abstract An edit with no owning effect writes nothing. */
- (void)testAnEditWithoutAnEffectWritesNothing
{
	NSView<FxGripTrackerTestEditing> *view = (NSView<FxGripTrackerTestEditing> *)[self makeView];

	[view shapeChanged:nil];

	XCTAssertEqual(self.setter.writes.count, 0u);
}

/*! @abstract A shape edit reads the current value, changes only the shape, and writes it back at the host's current time. */
- (void)testAShapeEditWritesOnlyTheShapeBack
{
	NSView<FxGripTrackerTestEditing> *view = [self makeWiredView];
	FxGripObjectTrackerData *stored = (id)[self trackerDataWithSampleCount:3];
	stored.behavior = 1;
	stored.smoothing = 5;
	self.effect.apiManager.paramGetAPIv6.customValue = stored;
	[[self popupsIn:view][0] selectItemWithTag:1];

	[view shapeChanged:nil];

	XCTAssertEqual(self.setter.writes.count, 1u);
	XCTAssertEqualObjects([self lastWrite][@"id"], @(55));
	XCTAssertEqualObjects([self lastWrite][@"timevalue"], @(60));
	FxGripObjectTrackerData *written = [self writtenValue];
	XCTAssertEqual(written.shape, 1);
	XCTAssertEqual(written.behavior, 1, @"the other options ride through");
	XCTAssertEqual(written.smoothing, 5);
	XCTAssertEqual(written.sampleCount, 3u, @"the tracked samples ride through");
	XCTAssertNotEqualObjects(written, stored, @"the value is copied before it is changed");
}

/*! @abstract The edit is bracketed by one host action, which closes when the accessor goes out of scope. */
- (void)testAnEditIsBracketedByOneHostAction
{
	NSView<FxGripTrackerTestEditing> *view = [self makeWiredView];
	self.effect.apiManager.paramGetAPIv6.customValue = [NSClassFromString(@"FxGripObjectTrackerData") new];

	@autoreleasepool {
		[view behaviorChanged:nil];
	}

	XCTAssertEqual(self.effect.apiManager.customParameterActionAPIv4.startCount, 1u);
	XCTAssertEqual(self.effect.apiManager.customParameterActionAPIv4.endCount, 1u);
	XCTAssertEqual(self.effect.apiManager.paramGetAPIv6.lastReadParameterID, (UInt32)55);
}

/*! @abstract A behavior edit writes the selected behavior back. */
- (void)testABehaviorEditWritesTheSelectedBehaviorBack
{
	NSView<FxGripTrackerTestEditing> *view = [self makeWiredView];
	self.effect.apiManager.paramGetAPIv6.customValue = [NSClassFromString(@"FxGripObjectTrackerData") new];
	[[self popupsIn:view][1] selectItemWithTag:1];

	[view behaviorChanged:nil];

	XCTAssertEqual(((FxGripObjectTrackerData *)[self writtenValue]).behavior, 1);
}

/*! @abstract A resolution edit writes the selected resolution back. */
- (void)testAResolutionEditWritesTheSelectedResolutionBack
{
	NSView<FxGripTrackerTestEditing> *view = [self makeWiredView];
	self.effect.apiManager.paramGetAPIv6.customValue = [NSClassFromString(@"FxGripObjectTrackerData") new];
	[[self popupsIn:view][2] selectItemWithTag:1];

	[view resolutionChanged:nil];

	XCTAssertEqual(((FxGripObjectTrackerData *)[self writtenValue]).resolution, 1);
}

/*! @abstract A smoothing edit writes the stepper value back and mirrors it in the readout beside the stepper. */
- (void)testASmoothingEditWritesTheStepperValueBackAndUpdatesTheReadout
{
	NSView<FxGripTrackerTestEditing> *view = [self makeWiredView];
	self.effect.apiManager.paramGetAPIv6.customValue = [NSClassFromString(@"FxGripObjectTrackerData") new];
	[self stepperIn:view].integerValue = 7;

	[view smoothingChanged:nil];

	XCTAssertEqual(((FxGripObjectTrackerData *)[self writtenValue]).smoothing, 7);
	XCTAssertEqualObjects([self labelsIn:view].firstObject.stringValue, @"7");
}

/*! @abstract An edit against a host holding no tracker value starts from a fresh default value. */
- (void)testAnEditWithoutAStoredValueStartsFromTheDefault
{
	NSView<FxGripTrackerTestEditing> *view = [self makeWiredView];
	self.effect.apiManager.paramGetAPIv6.customValue = @"not tracker data";
	[[self popupsIn:view][0] selectItemWithTag:1];

	[view shapeChanged:nil];

	FxGripObjectTrackerData *written = [self writtenValue];
	FxGripObjectTrackerData *fresh = [NSClassFromString(@"FxGripObjectTrackerData") new];
	XCTAssertEqual(written.shape, 1);
	XCTAssertEqual(written.behavior, fresh.behavior, @"the rest of the value is the default");
	XCTAssertEqual(written.smoothing, fresh.smoothing);
	XCTAssertEqual(written.sampleCount, 0u);
}

@end
