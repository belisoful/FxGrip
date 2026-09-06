/*!
	@file       FxGripPointOSCTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripPointOSCTests
	@abstract   Verifies the FxGripPointOSC composite control, its parts, and the point parameter option parse.
	@discussion Introduced in FxGrip 0.1.0. A stub OSC API maps canvas to object space by a uniform scale of 100 over 200 x 100 input bounds, and a stub setting API records every parameter write. The tests cover part composition from options, plain and pinned handle hit geometry, the drag pipeline with mouse-speed, axis, distance, and range constraints, the thick divider acting as a control, the hover-gated name label, and the point parameter parsing its options.
*/

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripPointOSC.h>
#import <FxGrip/FxGripPointParameter.h>
#import "FxGripParameterClassTestSupport.h"

static const double kPointOSCCanvasPerObject = 100.0;
static const FxParameterId kPointOSCParameter = 7;

static CMTime FxGripPointOSCTestTime(void)
{
	return (CMTime){.value = 1, .timescale = 24, .flags = kCMTimeFlags_Valid, .epoch = 0};
}

#pragma mark - API stubs

@interface FxGripPointOSCTestOSCAPI : NSObject
@end

@implementation FxGripPointOSCTestOSCAPI

- (void)setCursor:(NSCursor *)newCursor
{
}

- (void)convertPointFromSpace:(FxDrawingCoordinates)fromSpace
						fromX:(double)fromX
						fromY:(double)fromY
					  toSpace:(FxDrawingCoordinates)toSpace
						  toX:(double *)toX
						  toY:(double *)toY
{
	if (fromSpace == kFxDrawingCoordinates_CANVAS && toSpace == kFxDrawingCoordinates_OBJECT) {
		*toX = fromX / kPointOSCCanvasPerObject;
		*toY = fromY / kPointOSCCanvasPerObject;
	} else if (fromSpace == kFxDrawingCoordinates_OBJECT && toSpace == kFxDrawingCoordinates_CANVAS) {
		*toX = fromX * kPointOSCCanvasPerObject;
		*toY = fromY * kPointOSCCanvasPerObject;
	} else {
		*toX = fromX;
		*toY = fromY;
	}
}

- (NSRect)inputBounds
{
	return NSMakeRect(0, 0, 200, 100);
}

@end

@interface FxGripPointOSCTestRetrievalAPI : NSObject
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSValue *> *points;
@end

@implementation FxGripPointOSCTestRetrievalAPI

- (instancetype)init
{
	self = [super init];
	if (self) {
		_points = NSMutableDictionary.new;
	}
	return self;
}

- (BOOL)getXValue:(double *)x YValue:(double *)y fromParameter:(UInt32)parameterID atTime:(CMTime)time
{
	NSValue *value = self.points[@(parameterID)];
	if (value == nil) {
		return NO;
	}
	*x = value.pointValue.x;
	*y = value.pointValue.y;
	return YES;
}

- (BOOL)getFloatValue:(double *)value fromParameter:(UInt32)parameterID atTime:(CMTime)time
{
	return NO;
}

@end

@interface FxGripPointOSCTestSettingAPI : NSObject
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *writes;
@property (nonatomic, weak) FxGripPointOSCTestRetrievalAPI *retrieval;
@end

@implementation FxGripPointOSCTestSettingAPI

- (instancetype)init
{
	self = [super init];
	if (self) {
		_writes = NSMutableArray.new;
	}
	return self;
}

- (BOOL)setXValue:(double)x YValue:(double)y toParameter:(UInt32)parameterID atTime:(CMTime)time
{
	[self.writes addObject:@{@"parameter": @(parameterID), @"x": @(x), @"y": @(y)}];
	self.retrieval.points[@(parameterID)] = [NSValue valueWithPoint:NSMakePoint(x, y)];
	return YES;
}

@end

@interface FxGripPointOSCTestAPIManager : NSObject
@property (nonatomic, strong) FxGripPointOSCTestOSCAPI *onScreenControlAPIv4;
@property (nonatomic, strong) FxGripPointOSCTestRetrievalAPI *paramGetAPIv6;
@property (nonatomic, strong) FxGripPointOSCTestSettingAPI *paramSetAPIv5;
@end

@implementation FxGripPointOSCTestAPIManager
@end

@interface FxGripPointOSCTestControl : FxGripPointOSC
@property (nonatomic, strong) FxGripPointOSCTestAPIManager *stubAPIManager;
@end

@implementation FxGripPointOSCTestControl

- (id<FxGripAPIAccessing>)apiManager
{
	return (id<FxGripAPIAccessing>)self.stubAPIManager;
}

@end

#pragma mark - Tests

@interface FxGripPointOSCTests : XCTestCase
@property (nonatomic, strong) FxGripPointOSCTestControl *control;
@property (nonatomic, strong) FxGripPointOSCTestAPIManager *manager;
@end

@implementation FxGripPointOSCTests

- (void)setUp
{
	[super setUp];
	self.manager = FxGripPointOSCTestAPIManager.new;
	self.manager.onScreenControlAPIv4 = FxGripPointOSCTestOSCAPI.new;
	self.manager.paramGetAPIv6 = FxGripPointOSCTestRetrievalAPI.new;
	self.manager.paramSetAPIv5 = FxGripPointOSCTestSettingAPI.new;
	self.manager.paramSetAPIv5.retrieval = self.manager.paramGetAPIv6;

	self.control = [[FxGripPointOSCTestControl alloc] initWithAPIManager:(id _Nonnull)nil];
	self.control.stubAPIManager = self.manager;
}

#pragma mark Helpers

- (FxGripPointOptions *)optionsWith:(nullable NSDictionary *)config
{
	return [FxGripPointOptions.alloc initWithConfiguration:config];
}

- (void)stagePoint:(NSPoint)point
{
	self.manager.paramGetAPIv6.points[@(kPointOSCParameter)] = [NSValue valueWithPoint:point];
}

/*! Stages the point at (0.4, 0.4) and adds one rich point with the options. */
- (NSArray<FxGripOSCPart *> *)addPointWith:(nullable NSDictionary *)config name:(nullable NSString *)name
{
	[self stagePoint:NSMakePoint(0.4, 0.4)];
	[self.control addPointParameter:kPointOSCParameter name:name options:[self optionsWith:config]];
	return self.control.parts;
}

- (NSInteger)hitTestAtCanvasX:(double)x y:(double)y
{
	NSInteger activePart = -1;
	[self.control hitTestOSCAtMousePositionX:x mousePositionY:y activePart:&activePart atTime:FxGripPointOSCTestTime()];
	return activePart;
}

- (void)mouseDownAtCanvasX:(double)x y:(double)y activePart:(NSInteger)activePart
{
	BOOL forceUpdate = NO;
	[self.control mouseDownAtPositionX:x positionY:y activePart:activePart modifiers:0
						   forceUpdate:&forceUpdate atTime:FxGripPointOSCTestTime()];
}

- (void)dragToCanvasX:(double)x y:(double)y activePart:(NSInteger)activePart modifiers:(FxModifierKeys)modifiers
{
	BOOL forceUpdate = NO;
	[self.control mouseDraggedAtPositionX:x positionY:y activePart:activePart modifiers:modifiers
							  forceUpdate:&forceUpdate atTime:FxGripPointOSCTestTime()];
}

- (NSDictionary *)lastWrite
{
	return self.manager.paramSetAPIv5.writes.lastObject;
}

- (void)assertLastWriteX:(double)x y:(double)y
{
	NSDictionary *write = self.lastWrite;
	XCTAssertNotNil(write, @"the drag wrote the parameter");
	XCTAssertEqualObjects(write[@"parameter"], @(kPointOSCParameter));
	XCTAssertEqualWithAccuracy([write[@"x"] doubleValue], x, 1e-9);
	XCTAssertEqualWithAccuracy([write[@"y"] doubleValue], y, 1e-9);
}

#pragma mark Composition

/*! @abstract A plain point composes a single rich handle part with part ID one. */
- (void)testAPlainPointComposesOnlyTheHandle
{
	NSArray *parts = [self addPointWith:nil name:@"Center"];

	XCTAssertEqual(parts.count, (NSUInteger)1);
	XCTAssertTrue([parts[0] isKindOfClass:FxGripOSCRichPointHandlePart.class]);
	XCTAssertFalse([parts[0] isKindOfClass:FxGripOSCPointDividerPart.class]);
	XCTAssertEqual([parts[0] partID], (NSInteger)1);
}

/*! @abstract The display-name option appends a label part carrying the name and bound to the handle and anchor. */
- (void)testDisplayNameAppendsALabelBoundToTheHandle
{
	NSArray *parts = [self addPointWith:@{kFxGripPointKey_DisplayName: @YES} name:@"Center"];

	XCTAssertEqual(parts.count, (NSUInteger)2);
	FxGripOSCPointLabelPart *label = parts[1];
	XCTAssertTrue([label isKindOfClass:FxGripOSCPointLabelPart.class]);
	XCTAssertEqualObjects(label.text, @"Center");
	XCTAssertEqual(label.handlePartID, [parts[0] partID]);
	XCTAssertEqual(label.anchorParameterID, kPointOSCParameter);
}

/*! @abstract The display-name option adds no label when the point has no name. */
- (void)testDisplayNameWithoutANameAddsNoLabel
{
	NSArray *parts = [self addPointWith:@{kFxGripPointKey_DisplayName: @YES} name:nil];

	XCTAssertEqual(parts.count, (NSUInteger)1);
}

/*! @abstract An axis constraint with a thin divider inserts a non-draggable divider before the handle. */
- (void)testAnAxisConstraintWithAThinDividerAddsTheDividerBeforeTheHandle
{
	NSArray *parts = [self addPointWith:@{kFxGripPointKey_Constraint: @(FxGripPointConstraintHorizontal),
										  kFxGripPointKey_Divider: @(FxGripPointDividerThinWithControl)}
								   name:nil];

	XCTAssertEqual(parts.count, (NSUInteger)2);
	FxGripOSCPointDividerPart *divider = parts[0];
	XCTAssertTrue([divider isKindOfClass:FxGripOSCPointDividerPart.class]);
	XCTAssertFalse(divider.draggable);
	XCTAssertTrue([parts[1] isKindOfClass:FxGripOSCRichPointHandlePart.class]);
	XCTAssertFalse([parts[1] isKindOfClass:FxGripOSCPointDividerPart.class]);
}

/*! @abstract A thick divider replaces the handle with a single draggable divider part. */
- (void)testAThickDividerReplacesTheHandle
{
	NSArray *parts = [self addPointWith:@{kFxGripPointKey_Constraint: @(FxGripPointConstraintVertical),
										  kFxGripPointKey_Divider: @(FxGripPointDividerThickWithoutControl)}
								   name:nil];

	XCTAssertEqual(parts.count, (NSUInteger)1);
	FxGripOSCPointDividerPart *divider = parts[0];
	XCTAssertTrue([divider isKindOfClass:FxGripOSCPointDividerPart.class]);
	XCTAssertTrue(divider.draggable);
}

/*! @abstract A divider option without an axis constraint adds no divider. */
- (void)testADividerNeedsAnAxisConstraint
{
	NSArray *parts = [self addPointWith:@{kFxGripPointKey_Divider: @(FxGripPointDividerThickWithoutControl)} name:nil];

	XCTAssertEqual(parts.count, (NSUInteger)1);
	XCTAssertFalse([parts[0] isKindOfClass:FxGripOSCPointDividerPart.class]);
}

/*! @abstract A background-image option adds a background part ordered before the handle. */
- (void)testABackgroundImageComesFirst
{
	NSArray *parts = [self addPointWith:@{kFxGripPointKey_BackgroundImage: @"NSApplicationIcon"} name:nil];

	XCTAssertEqual(parts.count, (NSUInteger)2);
	XCTAssertTrue([parts[0] isKindOfClass:FxGripOSCPointBackgroundPart.class]);
	XCTAssertTrue([parts[1] isKindOfClass:FxGripOSCRichPointHandlePart.class]);
}

/*! @abstract Adding further point parameters numbers their parts after the existing ones. */
- (void)testAddPointParameterNumbersPartsAfterTheExistingOnes
{
	[self addPointWith:nil name:nil];
	[self.control addPointParameter:8 name:nil options:[self optionsWith:@{kFxGripPointKey_DisplayName: @YES}]];
	[self.control addPointParameter:9 name:@"Tail" options:[self optionsWith:@{kFxGripPointKey_DisplayName: @YES}]];

	NSArray *ids = [self.control.parts valueForKey:@"partID"];
	XCTAssertEqualObjects(ids, (@[@1, @2, @3, @4]));
}

#pragma mark Hit geometry

/*! @abstract The handle hits within its canvas radius of the parameter position and misses beyond it. */
- (void)testTheHandleHitsAtTheParameterPosition
{
	[self addPointWith:nil name:nil];

	XCTAssertEqual([self hitTestAtCanvasX:40 y:40], (NSInteger)1);
	XCTAssertEqual([self hitTestAtCanvasX:47 y:47], (NSInteger)1, @"inside the 10 px hit radius");
	XCTAssertEqual([self hitTestAtCanvasX:60 y:40], (NSInteger)0);
}

/*! @abstract A pinned handle hits at the pin offset from the anchor, not at the anchor itself. */
- (void)testAPinnedHandleHitsAtThePinOffset
{
	[self addPointWith:@{kFxGripPointKey_PinDistance: @20.0, kFxGripPointKey_PinAngle: @0.0} name:nil];

	XCTAssertEqual([self hitTestAtCanvasX:60 y:40], (NSInteger)1);
	XCTAssertEqual([self hitTestAtCanvasX:40 y:40], (NSInteger)0, @"the anchor itself is not the handle");
}

/*! @abstract A ninety-degree pin angle places the handle above the anchor in canvas space. */
- (void)testAPositivePinAngleLiftsThePinOnScreen
{
	[self addPointWith:@{kFxGripPointKey_PinDistance: @20.0, kFxGripPointKey_PinAngle: @90.0} name:nil];

	XCTAssertEqual([self hitTestAtCanvasX:40 y:60], (NSInteger)1, @"canvas y increases upward, so up is +y");
	XCTAssertEqual([self hitTestAtCanvasX:40 y:20], (NSInteger)0);
}

/*! @abstract The effective handle radius is half the configured control size, and defaults to the handle radius. */
- (void)testTheEffectiveHandleRadiusFollowsControlSize
{
	FxGripOSCRichPointHandlePart *sized = (FxGripOSCRichPointHandlePart *)[self addPointWith:@{kFxGripPointKey_ControlSize: @14.0} name:nil][0];
	XCTAssertEqual([sized effectiveHandleRadius], 7.0);

	FxGripOSCRichPointHandlePart *stock = [FxGripOSCRichPointHandlePart partWithID:9 parameterID:1 options:[self optionsWith:nil]];
	XCTAssertEqual([stock effectiveHandleRadius], stock.handleRadius);
}

#pragma mark Drag pipeline

/*! @abstract A drag moves the point by the pointer travel and clamps it to the configured range maximum. */
- (void)testADragMovesByThePointerTravelWithinTheRange
{
	[self addPointWith:@{kFxGripPointKey_RangeMaxX: @0.5} name:nil];

	[self mouseDownAtCanvasX:40 y:40 activePart:1];
	[self dragToCanvasX:45 y:40 activePart:1 modifiers:0];
	[self assertLastWriteX:0.45 y:0.4];

	[self dragToCanvasX:90 y:40 activePart:1 modifiers:0];
	[self assertLastWriteX:0.5 y:0.4];
}

/*! @abstract A drag begun off the handle center moves the point by the travel and does not jump it to the pointer. */
- (void)testADragStartedOffTheHandleCenterDoesNotJumpThePoint
{
	[self addPointWith:nil name:nil];

	// Grab 5 px right of center; the point moves by the travel, not to the pointer.
	[self mouseDownAtCanvasX:45 y:40 activePart:1];
	[self dragToCanvasX:55 y:40 activePart:1 modifiers:0];
	[self assertLastWriteX:0.5 y:0.4];
}

/*! @abstract A horizontal constraint moves the point in x and locks y. */
- (void)testAHorizontalConstraintLocksY
{
	[self addPointWith:@{kFxGripPointKey_Constraint: @(FxGripPointConstraintHorizontal),
						 kFxGripPointKey_Divider: @(FxGripPointDividerThinWithControl)} name:nil];

	[self mouseDownAtCanvasX:40 y:40 activePart:2];
	[self dragToCanvasX:60 y:70 activePart:2 modifiers:0];
	[self assertLastWriteX:0.6 y:0.4];
}

/*! @abstract A vertical constraint moves the point in y and locks x. */
- (void)testAVerticalConstraintLocksX
{
	[self addPointWith:@{kFxGripPointKey_Constraint: @(FxGripPointConstraintVertical)} name:nil];

	[self mouseDownAtCanvasX:40 y:40 activePart:1];
	[self dragToCanvasX:70 y:60 activePart:1 modifiers:0];
	[self assertLastWriteX:0.4 y:0.6];
}

/*! The clamp is circular in input pixels: the 200 x 100 input makes 20 px 0.1 in x and 0.2 in y. */
/*! @abstract A distance constraint clamps the point to the maximum radius measured in input pixels. */
- (void)testADistanceConstraintClampsInInputPixels
{
	NSDictionary *config = @{kFxGripPointKey_Constraint: @(FxGripPointConstraintDistance),
							 kFxGripPointKey_DistanceFromX: @0.5, kFxGripPointKey_DistanceFromY: @0.5,
							 kFxGripPointKey_MaxDistance: @0.1};
	[self stagePoint:NSMakePoint(0.5, 0.5)];
	[self.control addPointParameter:kPointOSCParameter name:nil options:[self optionsWith:config]];

	[self mouseDownAtCanvasX:50 y:50 activePart:1];
	[self dragToCanvasX:80 y:50 activePart:1 modifiers:0];
	[self assertLastWriteX:0.6 y:0.5];

	[self dragToCanvasX:50 y:90 activePart:1 modifiers:0];
	[self assertLastWriteX:0.5 y:0.7];
}

/*! @abstract When configured, Shift locks a distance-constrained drag to the dominant axis, and the part reports it handles the constraint. */
- (void)testShiftLocksADistanceDragToOneAxisWhenConfigured
{
	NSDictionary *config = @{kFxGripPointKey_Constraint: @(FxGripPointConstraintDistance),
							 kFxGripPointKey_DistanceFromX: @0.5, kFxGripPointKey_DistanceFromY: @0.5,
							 kFxGripPointKey_MaxDistance: @0.1, kFxGripPointKey_DistanceShiftOneAxis: @YES};
	[self stagePoint:NSMakePoint(0.5, 0.5)];
	[self.control addPointParameter:kPointOSCParameter name:nil options:[self optionsWith:config]];

	XCTAssertTrue([self.control.parts[0] handlesConstrainDrag], @"the part reads Shift itself");

	[self mouseDownAtCanvasX:50 y:50 activePart:1];
	[self dragToCanvasX:56 y:52 activePart:1 modifiers:kFxModifierKey_SHIFT];
	[self assertLastWriteX:0.56 y:0.5];
}

/*! @abstract The mouse-speed option scales the pointer travel applied to the point. */
- (void)testMouseSpeedScalesTheTravel
{
	[self addPointWith:@{kFxGripPointKey_MouseSpeed: @0.5} name:nil];

	[self mouseDownAtCanvasX:40 y:40 activePart:1];
	[self dragToCanvasX:60 y:40 activePart:1 modifiers:0];
	[self assertLastWriteX:0.5 y:0.4];
}

/*! @abstract A Shift-gated mouse speed applies the scale only while Shift is held. */
- (void)testShiftGatedMouseSpeedAppliesOnlyWhileShiftIsHeld
{
	[self addPointWith:@{kFxGripPointKey_MouseSpeed: @0.5, kFxGripPointKey_MouseSpeedShiftOnly: @YES} name:nil];
	XCTAssertTrue([self.control.parts[0] handlesConstrainDrag]);

	[self mouseDownAtCanvasX:40 y:40 activePart:1];
	[self dragToCanvasX:60 y:40 activePart:1 modifiers:0];
	[self assertLastWriteX:0.6 y:0.4];

	[self mouseDownAtCanvasX:60 y:40 activePart:1];
	[self dragToCanvasX:80 y:40 activePart:1 modifiers:kFxModifierKey_SHIFT];
	[self assertLastWriteX:0.7 y:0.4];
}

/*! @abstract A plain handle does not claim the Shift constraint, leaving it to the control. */
- (void)testAPlainHandleLeavesShiftToTheControl
{
	[self addPointWith:nil name:nil];

	XCTAssertFalse([self.control.parts[0] handlesConstrainDrag]);
}

#pragma mark Divider as a control

/*! @abstract A thick divider hits anywhere along its line and drags the free axis of the constraint. */
- (void)testAThickDividerHitsAlongItsLineAndDragsTheFreeAxis
{
	[self addPointWith:@{kFxGripPointKey_Constraint: @(FxGripPointConstraintHorizontal),
						 kFxGripPointKey_Divider: @(FxGripPointDividerThickWithoutControl)} name:nil];

	XCTAssertEqual([self hitTestAtCanvasX:40 y:90], (NSInteger)1, @"anywhere along the vertical line");
	XCTAssertEqual([self hitTestAtCanvasX:60 y:90], (NSInteger)0);

	[self mouseDownAtCanvasX:40 y:90 activePart:1];
	[self dragToCanvasX:55 y:95 activePart:1 modifiers:0];
	[self assertLastWriteX:0.55 y:0.4];
}

/*! @abstract A thin divider answers no hit along its line, and the handle stays the control. */
- (void)testAThinDividerAnswersNoHit
{
	[self addPointWith:@{kFxGripPointKey_Constraint: @(FxGripPointConstraintHorizontal),
						 kFxGripPointKey_Divider: @(FxGripPointDividerThinWithControl)} name:nil];

	XCTAssertEqual([self hitTestAtCanvasX:40 y:90], (NSInteger)0);
	XCTAssertEqual([self hitTestAtCanvasX:40 y:40], (NSInteger)2, @"the handle stays the control");
}

#pragma mark Name label

- (void)mouseMovedWithActivePart:(NSInteger)activePart expectingUpdate:(BOOL)expected
{
	BOOL forceUpdate = NO;
	[self.control mouseMovedAtPositionX:0 positionY:0 activePart:activePart modifiers:0
							forceUpdate:&forceUpdate atTime:FxGripPointOSCTestTime()];
	XCTAssertEqual(forceUpdate, expected);
}

/*! @abstract Hovering the handle shows the name label and moving away hides it, forcing a redraw only on a change. */
- (void)testHoverShowsAndHidesTheNameLabel
{
	NSArray *parts = [self addPointWith:@{kFxGripPointKey_DisplayName: @YES} name:@"Center"];
	FxGripOSCPointLabelPart *label = parts[1];
	XCTAssertFalse(label.visible, @"hidden until hovered by default");

	[self mouseMovedWithActivePart:1 expectingUpdate:YES];
	XCTAssertTrue(label.visible);

	[self mouseMovedWithActivePart:1 expectingUpdate:NO];

	[self mouseMovedWithActivePart:0 expectingUpdate:YES];
	XCTAssertFalse(label.visible);

	BOOL forceUpdate = YES;
	[self.control mouseExitedAtPositionX:0 positionY:0 modifiers:0 forceUpdate:&forceUpdate atTime:FxGripPointOSCTestTime()];
	XCTAssertFalse(forceUpdate, @"leaving while already hidden changes nothing");
}

/*! @abstract A label with hover gating disabled stays visible and forces no redraw on hover. */
- (void)testALabelWithoutHoverGatingIsAlwaysVisible
{
	NSArray *parts = [self addPointWith:@{kFxGripPointKey_DisplayName: @YES, kFxGripPointKey_NameOnlyWhenAbove: @NO}
								   name:@"Center"];
	FxGripOSCPointLabelPart *label = parts[1];

	XCTAssertTrue(label.visible);
	[self mouseMovedWithActivePart:1 expectingUpdate:NO];
	XCTAssertTrue(label.visible);
}

#pragma mark Point parameter

/*! @abstract The point parameter parses its configuration into options, including the constraint and pin display. */
- (void)testThePointParameterParsesItsOptions
{
	FxGripParamClassTestEffect *effect = [FxGripParamClassTestEffect.alloc init];
	NSDictionary *config = FxGripParamClassTestConfig(kPointOSCParameter, kFxParameterType_Point, @"Center",
													  @{kFxGripPointKey_Constraint: @(FxGripPointConstraintVertical),
														kFxGripPointKey_PinDistance: @12.0});

	FxGripPointParameter *parameter = [FxGripPointParameter.alloc initWithDictionary:config effect:(id)effect];

	XCTAssertNotNil(parameter.options);
	XCTAssertEqual(parameter.options.constraint, FxGripPointConstraintVertical);
	XCTAssertTrue(parameter.options.displayAsPin);
}

@end
