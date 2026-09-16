/*!
	@file       FxGripPointOSCTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripPointOSCTests
	@abstract   Verifies the FxGripPointOSC composite control, its parts, and the point parameter option parse.
	@discussion Introduced in FxGrip 0.1.0. A stub OSC API maps canvas to object space by a uniform scale of 100 over 200 x 100 input bounds, and a stub setting API records every parameter write. The tests cover part composition from options, plain and pinned handle hit geometry, the drag pipeline with mouse-speed, axis, distance, and range constraints, the thick divider acting as a control, the hover-gated name label, and the point parameter parsing its options. A live Metal render pass from FxGripOSCMetalTestPass draws the handle, the pin stem, the divider band, the background image, and the label, and the rendered pixels are read back and asserted.
*/

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripPointOSC.h>
#import <FxGrip/FxGripPointParameter.h>
#import "FxGripParameterClassTestSupport.h"
#import "FxGripOSCMetalTestSupport.h"

/*! The background part's private image and texture resolution. */
@interface FxGripOSCPointBackgroundPart (FxGripPointTesting)
- (nullable NSImage *)image;
- (nullable id<MTLTexture>)textureForDevice:(nonnull id<MTLDevice>)device;
@end

static const double kPointOSCCanvasPerObject = 100.0;
static const FxParameterId kPointOSCParameter = 7;

static CMTime FxGripPointOSCTestTime(void)
{
	return (CMTime){.value = 1, .timescale = 24, .flags = kCMTimeFlags_Valid, .epoch = 0};
}

#pragma mark - API stubs

@interface FxGripPointOSCTestOSCAPI : NSObject
@property (nonatomic, assign) NSRect stagedInputBounds;
@end

@implementation FxGripPointOSCTestOSCAPI

- (instancetype)init
{
	self = [super init];
	if (self) {
		_stagedInputBounds = NSMakeRect(0, 0, 200, 100);
	}
	return self;
}

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
	return self.stagedInputBounds;
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


#pragma mark Drawing

/*! Binds `name` to a live render pass, or skips the test when the machine has no Metal device. */
#define FxGripPointBeginPass(name, canvasSizeValue) \
	FxGripOSCMetalTestPass *name = [FxGripOSCMetalTestPass passWithCanvasSize:(canvasSizeValue)]; \
	if (name == nil) { \
		XCTSkip(@"no Metal device is available for the on-screen control render pass"); \
	}

/*! The greatest alpha within one pixel of a canvas point, so a rasterized line counts as ink. */
- (float)inkNear:(CGPoint)canvasPoint inPass:(FxGripOSCMetalTestPass *)pass
{
	float best = 0.0f;
	for (int dy = -1; dy <= 1; dy++) {
		for (int dx = -1; dx <= 1; dx++) {
			simd_float4 color = [pass colorAtCanvasPoint:CGPointMake(canvasPoint.x + dx, canvasPoint.y + dy)];
			best = MAX(best, color.w);
		}
	}
	return best;
}

/*! The sample with the greatest alpha within one pixel of a canvas point. */
- (simd_float4)colorNear:(CGPoint)canvasPoint inPass:(FxGripOSCMetalTestPass *)pass
{
	simd_float4 best = (simd_float4){ 0.0f, 0.0f, 0.0f, 0.0f };
	for (int dy = -1; dy <= 1; dy++) {
		for (int dx = -1; dx <= 1; dx++) {
			simd_float4 color = [pass colorAtCanvasPoint:CGPointMake(canvasPoint.x + dx, canvasPoint.y + dy)];
			if (color.w > best.w) {
				best = color;
			}
		}
	}
	return best;
}

/*! Draws one part into a live pass and finishes it. */
- (void)drawPart:(FxGripOSCPart *)part inPass:(FxGripOSCMetalTestPass *)pass selected:(BOOL)selected
{
	[part drawSelected:selected
			canvasSize:pass.canvasSize
		commandEncoder:pass.commandEncoder
				atTime:FxGripPointOSCTestTime()];
	[pass finish];
}

/*! Adds one rich handle bound to the staged point, with the given configuration. */
- (FxGripOSCRichPointHandlePart *)addRichHandleWith:(nullable NSDictionary *)config
{
	[self stagePoint:NSMakePoint(0.4, 0.4)];
	FxGripOSCRichPointHandlePart *part = [FxGripOSCRichPointHandlePart partWithID:1
																	 parameterID:kPointOSCParameter
																		 options:[self optionsWith:config]];
	[self.control addPart:part];
	return part;
}

/*! @abstract The rich handle fills its square at the parameter's position, in the selected fill when active. */
- (void)testTheRichHandleFillsItsSquareAtTheParameterPosition
{
	FxGripOSCRichPointHandlePart *part = [self addRichHandleWith:nil];

	FxGripPointBeginPass(pass, CGSizeMake(80.0, 80.0));
	[self drawPart:part inPass:pass selected:YES];
	XCTAssertEqualWithAccuracy([pass colorAtCanvasPoint:CGPointMake(40.0, 40.0)].w,
							   kFxGripOSCSelectedFillColor.w, 0.02);
	XCTAssertEqualWithAccuracy([pass colorAtCanvasPoint:CGPointMake(60.0, 60.0)].w, 0.0, 0.01);
}

/*! @abstract A pinned handle strokes a stem from the parameter's position out to the offset handle. */
- (void)testAPinnedHandleStrokesAStemToItsOffsetSquare
{
	FxGripOSCRichPointHandlePart *part = [self addRichHandleWith:@{
		kFxGripPointKey_PinDistance : @20.0,
		kFxGripPointKey_PinAngle : @90.0,
	}];

	FxGripPointBeginPass(pass, CGSizeMake(80.0, 80.0));
	[self drawPart:part inPass:pass selected:NO];
	XCTAssertGreaterThan([self inkNear:CGPointMake(40.0, 50.0) inPass:pass], 0.5f, @"the pin stem");
	XCTAssertEqualWithAccuracy([pass colorAtCanvasPoint:CGPointMake(40.0, 60.0)].w,
							   kFxGripOSCUnselectedFillColor.w, 0.02, @"the handle at the pin tip");
}

/*! @abstract A handle with a control color fills and outlines in that color. */
- (void)testAHandleWithAControlColorDrawsInThatColor
{
	FxGripOSCRichPointHandlePart *part = [self addRichHandleWith:@{
		kFxGripPointKey_ControlColor : (@[@1.0, @0.0, @0.0]),
		kFxGripPointKey_ControlSize : @12.0,
	}];
	XCTAssertNotNil(part.options.controlColor, @"the configuration parsed a color");
	XCTAssertEqual([part effectiveHandleRadius], 6.0, @"half the control size");

	FxGripPointBeginPass(pass, CGSizeMake(80.0, 80.0));
	[self drawPart:part inPass:pass selected:NO];
	simd_float4 fill = [pass colorAtCanvasPoint:CGPointMake(40.0, 40.0)];
	XCTAssertGreaterThan(fill.x, 0.9f, @"the red channel of the control color");
	XCTAssertLessThan(fill.y, 0.1f);
	XCTAssertEqualWithAccuracy(fill.w, 0.25, 0.02, @"at the unselected alpha");
}

/*! @abstract A handle whose parameter the host does not answer draws nothing, answers no hit, and refuses a drag. */
- (void)testAHandleWithoutAParameterValueIsInert
{
	CMTime time = FxGripPointOSCTestTime();
	FxGripOSCRichPointHandlePart *part = [FxGripOSCRichPointHandlePart partWithID:1
																	 parameterID:97
																		 options:[self optionsWith:nil]];
	[self.control addPart:part];
	CGPoint canvasPoint = CGPointZero;

	FxGripPointBeginPass(pass, CGSizeMake(80.0, 80.0));
	[self drawPart:part inPass:pass selected:NO];
	XCTAssertEqualWithAccuracy([self inkNear:CGPointMake(40.0, 40.0) inPass:pass], 0.0, 0.01);
	XCTAssertFalse([part handleCanvasPoint:&canvasPoint atTime:time]);
	XCTAssertFalse([part hitTestObjectPoint:CGPointZero canvasPoint:CGPointZero atTime:time]);
	XCTAssertFalse([part dragToObjectPoint:CGPointMake(0.5, 0.5) objectDelta:CGPointMake(0.1, 0.0)
								 modifiers:0 atTime:time], @"a drag cannot begin without a start value");
}

/*! @abstract A drag that arrives without a mouse-down begins its own drag from the parameter's value. */
- (void)testADragWithoutAMouseDownBeginsItsOwnDrag
{
	FxGripOSCRichPointHandlePart *part = [self addRichHandleWith:nil];

	XCTAssertTrue([part dragToObjectPoint:CGPointMake(0.5, 0.5) objectDelta:CGPointMake(0.1, 0.2)
								modifiers:0 atTime:FxGripPointOSCTestTime()]);
	[self assertLastWriteX:0.5 y:0.6];
}

#pragma mark Divider drawing

/*! Adds a divider bound to the staged point, with the given configuration. */
- (FxGripOSCPointDividerPart *)addDividerWith:(nonnull NSDictionary *)config draggable:(BOOL)draggable
{
	[self stagePoint:NSMakePoint(0.4, 0.4)];
	FxGripOSCPointDividerPart *part = [FxGripOSCPointDividerPart partWithID:1
															   parameterID:kPointOSCParameter
																   options:[self optionsWith:config]];
	part.draggable = draggable;
	[self.control addPart:part];
	return part;
}

/*! @abstract A horizontally constrained point carries a vertical divider that spans the canvas height. */
- (void)testAHorizontalConstraintDrawsAVerticalDivider
{
	FxGripOSCPointDividerPart *part = [self addDividerWith:@{
		kFxGripPointKey_Constraint : @(FxGripPointConstraintHorizontal),
	} draggable:NO];

	FxGripPointBeginPass(pass, CGSizeMake(80.0, 80.0));
	[self drawPart:part inPass:pass selected:NO];
	XCTAssertGreaterThan([self inkNear:CGPointMake(40.0, 10.0) inPass:pass], 0.5f, @"low on the canvas");
	XCTAssertGreaterThan([self inkNear:CGPointMake(40.0, 70.0) inPass:pass], 0.5f, @"and high on it");
	XCTAssertEqualWithAccuracy([self inkNear:CGPointMake(20.0, 40.0) inPass:pass], 0.0, 0.01,
							   @"a vertical divider has no horizontal reach");
}

/*! @abstract A vertically constrained point carries a horizontal divider, thickened when it is draggable. */
- (void)testAVerticalConstraintDrawsAHorizontalDividerThickenedWhenDraggable
{
	FxGripOSCPointDividerPart *thin = [self addDividerWith:@{
		kFxGripPointKey_Constraint : @(FxGripPointConstraintVertical),
	} draggable:NO];

	FxGripPointBeginPass(thinPass, CGSizeMake(80.0, 80.0));
	[self drawPart:thin inPass:thinPass selected:NO];
	XCTAssertGreaterThan([self inkNear:CGPointMake(10.0, 40.0) inPass:thinPass], 0.5f, @"the divider line");
	XCTAssertEqualWithAccuracy([thinPass colorAtCanvasPoint:CGPointMake(10.0, 41.0)].w, 0.0, 0.01,
							   @"a thin divider has no band");

	FxGripOSCPointDividerPart *thick = [self addDividerWith:@{
		kFxGripPointKey_Constraint : @(FxGripPointConstraintVertical),
	} draggable:YES];
	thick.partID = 2;

	FxGripPointBeginPass(thickPass, CGSizeMake(80.0, 80.0));
	[self drawPart:thick inPass:thickPass selected:YES];
	XCTAssertEqualWithAccuracy([thickPass colorAtCanvasPoint:CGPointMake(10.0, 41.0)].w,
							   kFxGripOSCSelectedFillColor.w, 0.02, @"the draggable band around the line");
}

/*! @abstract A divider with a control color strokes in that color. */
- (void)testADividerWithAControlColorStrokesInThatColor
{
	FxGripOSCPointDividerPart *part = [self addDividerWith:@{
		kFxGripPointKey_Constraint : @(FxGripPointConstraintHorizontal),
		kFxGripPointKey_ControlColor : (@[@0.0, @1.0, @0.0]),
	} draggable:NO];

	FxGripPointBeginPass(pass, CGSizeMake(80.0, 80.0));
	[self drawPart:part inPass:pass selected:NO];
	simd_float4 line = [self colorNear:CGPointMake(40.0, 20.0) inPass:pass];
	XCTAssertGreaterThan(line.y, 0.9f, @"the green channel of the control color");
	XCTAssertLessThan(line.x, 0.1f);
}

/*! @abstract A divider whose parameter the host does not answer draws nothing and answers no hit. */
- (void)testADividerWithoutAParameterValueIsInert
{
	FxGripOSCPointDividerPart *part = [FxGripOSCPointDividerPart partWithID:1
															   parameterID:97
																   options:[self optionsWith:@{
		kFxGripPointKey_Constraint : @(FxGripPointConstraintHorizontal),
	}]];
	part.draggable = YES;
	[self.control addPart:part];

	FxGripPointBeginPass(pass, CGSizeMake(80.0, 80.0));
	[self drawPart:part inPass:pass selected:NO];
	XCTAssertEqualWithAccuracy([self inkNear:CGPointMake(40.0, 40.0) inPass:pass], 0.0, 0.01);
	XCTAssertFalse([part hitTestObjectPoint:CGPointZero canvasPoint:CGPointMake(40.0, 40.0)
									 atTime:FxGripPointOSCTestTime()]);
}

#pragma mark Background image

/*! A PNG file in the temporary directory, for the file-path image branch. */
- (NSString *)writeTemporaryImageFile
{
	NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
																	pixelsWide:8
																	pixelsHigh:8
																 bitsPerSample:8
															   samplesPerPixel:4
																	  hasAlpha:YES
																	  isPlanar:NO
																colorSpaceName:NSDeviceRGBColorSpace
																   bytesPerRow:0
																  bitsPerPixel:0];
	memset(rep.bitmapData, 0xFF, (size_t)(rep.bytesPerRow * rep.pixelsHigh));
	NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
	NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"FxGripPointOSCTestImage.png"];
	[png writeToFile:path atomically:YES];
	return path;
}

/*! @abstract The background image resolves by AppKit name and by file path, and stays nil without one. */
- (void)testTheBackgroundImageResolvesByNameAndByPath
{
	FxGripOSCPointBackgroundPart *named = [FxGripOSCPointBackgroundPart partWithID:1
																		  options:[self optionsWith:@{
		kFxGripPointKey_BackgroundImage : NSImageNameCaution,
	}]];
	XCTAssertNotNil([named image], @"an AppKit image name resolves");

	FxGripOSCPointBackgroundPart *fromPath = [FxGripOSCPointBackgroundPart partWithID:2
																			 options:[self optionsWith:@{
		kFxGripPointKey_BackgroundImage : [self writeTemporaryImageFile],
	}]];
	XCTAssertNotNil([fromPath image], @"a file path resolves");

	FxGripOSCPointBackgroundPart *none = [FxGripOSCPointBackgroundPart partWithID:3
																		 options:[self optionsWith:nil]];
	XCTAssertNil([none image], @"no name, no image");
}

/*! @abstract The background texture is built once per device, and a missing image builds none. */
- (void)testTheBackgroundTextureIsBuiltOncePerDevice
{
	id<MTLDevice> device = FxGripOSCMetalTestPass.sharedDevice;
	if (device == nil) {
		XCTSkip(@"no Metal device is available");
	}
	FxGripOSCPointBackgroundPart *part = [FxGripOSCPointBackgroundPart partWithID:1
																		 options:[self optionsWith:@{
		kFxGripPointKey_BackgroundImage : [self writeTemporaryImageFile],
	}]];
	[self.control addPart:part];

	id<MTLTexture> texture = [part textureForDevice:device];
	XCTAssertNotNil(texture);
	XCTAssertTrue([part textureForDevice:device] == texture, @"the second call returns the cached texture");

	FxGripOSCPointBackgroundPart *none = [FxGripOSCPointBackgroundPart partWithID:2
																		 options:[self optionsWith:nil]];
	[self.control addPart:none];
	XCTAssertNil([none textureForDevice:device], @"no image, no texture");
}

/*! @abstract A background part with no image draws nothing. */
- (void)testABackgroundPartWithNoImageDrawsNothing
{
	FxGripOSCPointBackgroundPart *part = [FxGripOSCPointBackgroundPart partWithID:1
																		 options:[self optionsWith:nil]];
	[self.control addPart:part];

	FxGripPointBeginPass(pass, CGSizeMake(80.0, 80.0));
	[self drawPart:part inPass:pass selected:NO];
	XCTAssertEqualWithAccuracy([self inkNear:CGPointMake(40.0, 40.0) inPass:pass], 0.0, 0.01);
}

/*! @abstract The background image draws as a textured quad centered on its object point. */
- (void)testTheBackgroundImageDrawsItsTexturedQuad
{
	FxImageTile *tile = [FxGripOSCMetalTestPass destinationTileWithCanvasSize:CGSizeMake(64.0, 64.0)];
	if (tile == nil) {
		XCTSkip(@"no Metal device is available");
	}
	self.manager.onScreenControlAPIv4.stagedInputBounds = NSMakeRect(0.0, 0.0, 100.0, 100.0);
	FxGripOSCPointBackgroundPart *part = [FxGripOSCPointBackgroundPart partWithID:1
																		 options:[self optionsWith:@{
		kFxGripPointKey_BackgroundImage : [self writeTemporaryImageFile],
		kFxGripPointKey_BackgroundImageSize : @0.2,
		kFxGripPointKey_BackgroundImageX : @0.32,
		kFxGripPointKey_BackgroundImageY : @0.32,
	}]];
	[self.control addPart:part];

	[self.control drawOSCWithWidth:64 height:64 activePart:0
				  destinationImage:tile atTime:FxGripPointOSCTestTime()];

	id<MTLTexture> texture = [tile metalTextureForDevice:FxGripOSCMetalTestPass.sharedDevice];
	NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:5.0];
	while ([FxGripOSCMetalTestPass colorInTexture:texture atCanvasPoint:CGPointMake(32.0, 32.0)].w == 0.0f
		   && deadline.timeIntervalSinceNow > 0.0) {
		[NSThread sleepForTimeInterval:0.001];
	}
	XCTAssertGreaterThan([FxGripOSCMetalTestPass colorInTexture:texture
												  atCanvasPoint:CGPointMake(32.0, 32.0)].w, 0.1f,
						 @"the image covers its object point");
	XCTAssertEqualWithAccuracy([FxGripOSCMetalTestPass colorInTexture:texture
														atCanvasPoint:CGPointMake(58.0, 32.0)].w, 0.0, 0.01,
							   @"and nothing beyond its quad");
}

#pragma mark Name label

/*! @abstract A hover-gated label draws its panel only while its handle is hovered. */
- (void)testAHoverGatedLabelDrawsOnlyWhileHovered
{
	[self stagePoint:NSMakePoint(0.2, 0.6)];
	FxGripOSCPointLabelPart *label = [[FxGripOSCPointLabelPart alloc] initWithPartID:1];
	label.text = @"Center";
	label.anchorParameterID = kPointOSCParameter;
	label.nameOnlyWhenAbove = YES;
	[self.control addPart:label];

	FxGripPointBeginPass(hiddenPass, CGSizeMake(80.0, 80.0));
	[self drawPart:label inPass:hiddenPass selected:NO];
	XCTAssertEqualWithAccuracy([self inkNear:CGPointMake(24.0, 56.0) inPass:hiddenPass], 0.0, 0.01,
							   @"an unhovered gated label draws nothing");

	label.hovered = YES;
	XCTAssertTrue(label.visible);
	FxGripPointBeginPass(shownPass, CGSizeMake(80.0, 80.0));
	[self drawPart:label inPass:shownPass selected:NO];
	XCTAssertGreaterThan([shownPass colorAtCanvasPoint:CGPointMake(24.0, 56.0)].w, 0.5f,
						 @"the hovered label draws its panel");
}

#pragma mark Constraint edges

/*! @abstract Shift locks a distance drag to the vertical axis when the vertical travel dominates. */
- (void)testShiftLocksADistanceDragToTheVerticalAxisWhenItDominates
{
	[self stagePoint:NSMakePoint(0.4, 0.4)];
	[self.control addPointParameter:kPointOSCParameter name:nil options:[self optionsWith:@{
		kFxGripPointKey_Constraint : @(FxGripPointConstraintDistance),
		kFxGripPointKey_DistanceFromX : @0.4,
		kFxGripPointKey_DistanceFromY : @0.4,
		kFxGripPointKey_MaxDistance : @1.0,
		kFxGripPointKey_DistanceShiftOneAxis : @YES,
	}]];

	[self mouseDownAtCanvasX:40 y:40 activePart:1];
	// The pointer travels 2 px right and 20 px up: in the 200 x 100 input frame that is
	// 4 input pixels across against 20 up, so the vertical axis wins.
	[self dragToCanvasX:42 y:60 activePart:1 modifiers:kFxModifierKey_SHIFT];

	[self assertLastWriteX:0.4 y:0.6];
}

/*! @abstract Without a usable input frame the distance clamp falls back to object units. */
- (void)testTheDistanceClampFallsBackToObjectUnitsWithoutAnInputFrame
{
	self.manager.onScreenControlAPIv4.stagedInputBounds = NSZeroRect;
	[self stagePoint:NSMakePoint(0.4, 0.4)];
	[self.control addPointParameter:kPointOSCParameter name:nil options:[self optionsWith:@{
		kFxGripPointKey_Constraint : @(FxGripPointConstraintDistance),
		kFxGripPointKey_DistanceFromX : @0.4,
		kFxGripPointKey_DistanceFromY : @0.4,
		kFxGripPointKey_MaxDistance : @0.1,
	}]];

	[self mouseDownAtCanvasX:40 y:40 activePart:1];
	// A pure horizontal travel of 0.4 object units clamps to the 0.1 unit radius.
	[self dragToCanvasX:80 y:40 activePart:1 modifiers:0];

	[self assertLastWriteX:0.5 y:0.4];
}

@end
