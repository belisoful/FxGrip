/*!
	@file       FxGripOnScreenControlTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripOnScreenControlTests
	@abstract   Verifies FxGripOnScreenControl and its stock parts across coordinate conversion, hit testing, and drag routing.
	@discussion Introduced in FxGrip 0.1.0. A control subclass returns a stub API manager whose OSC API maps canvas to object space by a uniform scale of 100, and stub retrieval and setting APIs stage and record parameter values. The tests cover the Metal point conversion, standard colors, coordinate round-trips, part ordering and hit testing, and the mouse-drag pipeline for rect, point, circle, line, gradient, angle dial, rectangle corner, polyline, and box parts, including Shift, Option, and combined modifier behavior. A live Metal render pass from FxGripOSCMetalTestPass drives the draw kit, the control's own drawing scaffold, and every part's drawing, and the rendered pixels are read back and asserted.
*/

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripOnScreenControl.h>
#import <FxGrip/FxGripOSCPart.h>

@interface FxGripOnScreenControl (FxGripShadowTesting)
+ (NSArray<NSNumber *> *)fxShadowBlurRadiiForParts:(NSArray<FxGripOSCPart *> *)parts;
@end

#import "FxGripOSCMetalTestSupport.h"
#import "FxPlugStub.h"

/*! The rectangle corner's private resize solver, for asserting the anchor and extents directly. */
@interface FxGripOSCRectCornerPart (FxGripResizeTesting)
- (void)fxResizeAnchor:(CGPoint *)anchor
				 signX:(double *)signX
				 signY:(double *)signY
				 width:(double *)width
				height:(double *)height
			 lowerLeft:(CGPoint)lowerLeft
			upperRight:(CGPoint)upperRight
			  atCenter:(BOOL)atCenter;
@end

/*! The circle's private parameter read, for asserting the per-axis normalization. */
@interface FxGripOSCCirclePart (FxGripReadTesting)
- (BOOL)readCenter:(CGPoint *)center normalizedRadius:(CGPoint *)normalizedRadius atTime:(CMTime)time;
@end

/*! The rotation handle's private rim solver. */
@interface FxGripOSCRotationHandlePart (FxGripReadTesting)
- (BOOL)readHandleObjectPoint:(CGPoint *)handlePoint center:(CGPoint *)center atTime:(CMTime)time;
@end

/*! The HUD part's private text cache and resolvers. */
@interface FxGripOSCHUDPart (FxGripHUDTesting)
@property (nonatomic, strong, nullable) id<MTLTexture> cachedTexture;
@property (nonatomic, copy, nullable) NSString *cachedKey;
- (nullable NSString *)resolvedTextAtTime:(CMTime)time;
- (nullable id<MTLTexture>)textureForString:(NSString *)string device:(id<MTLDevice>)device;
@end

/*! Records the mouse and key events the control routes to a part. */
@interface FxGripOSCTestRecordingPart : FxGripOSCPart
@property (nonatomic, assign) BOOL claimsMouseDown;
@property (nonatomic, assign) BOOL claimsDoubleClick;
@property (nonatomic, assign) BOOL claimsKey;
@property (nonatomic, assign) NSUInteger mouseDownCount;
@property (nonatomic, assign) NSUInteger doubleClickCount;
@property (nonatomic, assign) NSUInteger keyDownCount;
@property (nonatomic, assign) unsigned short lastKey;
@property (nonatomic, assign) CGPoint lastCanvasPoint;
@end

@implementation FxGripOSCTestRecordingPart

- (BOOL)mouseDownAtObjectPoint:(CGPoint)objectPoint
				   canvasPoint:(CGPoint)canvasPoint
					 modifiers:(FxModifierKeys)modifiers
						atTime:(CMTime)time
{
	self.mouseDownCount += 1;
	self.lastCanvasPoint = canvasPoint;
	return self.claimsMouseDown;
}

- (BOOL)mouseDoubleClickAtObjectPoint:(CGPoint)objectPoint
						  canvasPoint:(CGPoint)canvasPoint
							modifiers:(FxModifierKeys)modifiers
							   atTime:(CMTime)time
{
	self.doubleClickCount += 1;
	return self.claimsDoubleClick;
}

- (BOOL)keyDownWithKey:(unsigned short)asciiKey modifiers:(FxModifierKeys)modifiers atTime:(CMTime)time
{
	self.keyDownCount += 1;
	self.lastKey = asciiKey;
	return self.claimsKey;
}

@end

static const double kOSCTestCanvasPerObject = 100.0;

static CMTime FxGripOSCTestTime(void)
{
	return (CMTime){.value = 1, .timescale = 24, .flags = kCMTimeFlags_Valid, .epoch = 0};
}

#pragma mark - API stubs

/*! Canvas = object * 100; input bounds are staged (default 200 x 100). */
@interface FxGripOSCTestOSCAPI : NSObject
@property (nonatomic, assign) NSRect stagedInputBounds;
@property (nonatomic, strong) NSCursor *lastCursor;
@property (nonatomic, assign) NSUInteger setCursorCount;
@end

@implementation FxGripOSCTestOSCAPI

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
	self.lastCursor = newCursor;
	self.setCursorCount += 1;
}

- (void)convertPointFromSpace:(FxDrawingCoordinates)fromSpace
						fromX:(double)fromX
						fromY:(double)fromY
					  toSpace:(FxDrawingCoordinates)toSpace
						  toX:(double *)toX
						  toY:(double *)toY
{
	if (fromSpace == kFxDrawingCoordinates_CANVAS && toSpace == kFxDrawingCoordinates_OBJECT) {
		*toX = fromX / kOSCTestCanvasPerObject;
		*toY = fromY / kOSCTestCanvasPerObject;
	} else if (fromSpace == kFxDrawingCoordinates_OBJECT && toSpace == kFxDrawingCoordinates_CANVAS) {
		*toX = fromX * kOSCTestCanvasPerObject;
		*toY = fromY * kOSCTestCanvasPerObject;
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

/*! Answers point and float reads from staged dictionaries. */
@interface FxGripOSCTestRetrievalAPI : NSObject
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSValue *> *points;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *floats;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, id> *customs;
@end

@implementation FxGripOSCTestRetrievalAPI

- (instancetype)init
{
	self = [super init];
	if (self) {
		_points = NSMutableDictionary.new;
		_floats = NSMutableDictionary.new;
		_customs = NSMutableDictionary.new;
	}
	return self;
}

- (BOOL)getCustomParameterValue:(NSObject **)value fromParameter:(UInt32)parameterID atTime:(CMTime)time
{
	id staged = self.customs[@(parameterID)];
	if (staged == nil) {
		return NO;
	}
	*value = staged;
	return YES;
}

- (BOOL)getXValue:(double *)x YValue:(double *)y fromParameter:(UInt32)parameterID atTime:(CMTime)time
{
	NSValue *value = self.points[@(parameterID)];
	if (value == nil) {
		return NO;
	}
	NSPoint point = value.pointValue;
	*x = point.x;
	*y = point.y;
	return YES;
}

- (BOOL)getFloatValue:(double *)value fromParameter:(UInt32)parameterID atTime:(CMTime)time
{
	NSNumber *staged = self.floats[@(parameterID)];
	if (staged == nil) {
		return NO;
	}
	*value = staged.doubleValue;
	return YES;
}

@end

/*! Records every point and float write, and mirrors them into the retrieval stub. */
@interface FxGripOSCTestSettingAPI : NSObject
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *writes;
@property (nonatomic, weak) FxGripOSCTestRetrievalAPI *retrieval;
@end

@implementation FxGripOSCTestSettingAPI

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

- (BOOL)setFloatValue:(double)value toParameter:(UInt32)parameterID atTime:(CMTime)time
{
	[self.writes addObject:@{@"parameter": @(parameterID), @"value": @(value)}];
	self.retrieval.floats[@(parameterID)] = @(value);
	return YES;
}

- (BOOL)setCustomParameterValue:(id)value toParameter:(UInt32)parameterID atTime:(CMTime)time
{
	[self.writes addObject:@{@"parameter": @(parameterID), @"custom": value}];
	self.retrieval.customs[@(parameterID)] = value;
	return YES;
}

@end

@interface FxGripOSCTestAPIManager : NSObject
@property (nonatomic, strong) FxGripOSCTestOSCAPI *onScreenControlAPIv4;
@property (nonatomic, strong) FxGripOSCTestRetrievalAPI *paramGetAPIv6;
@property (nonatomic, strong) FxGripOSCTestSettingAPI *paramSetAPIv5;
@end

@implementation FxGripOSCTestAPIManager
@end

#pragma mark - Control double

@interface FxGripOSCTestControl : FxGripOnScreenControl
@property (nonatomic, strong) FxGripOSCTestAPIManager *stubAPIManager;
@property (nonatomic, assign) BOOL suppressesTextTextures;
@end

@implementation FxGripOSCTestControl

- (id<FxGripAPIAccessing>)apiManager
{
	return (id<FxGripAPIAccessing>)self.stubAPIManager;
}

- (id<MTLTexture>)textureForText:(NSString *)text
						fontSize:(CGFloat)fontSize
						   color:(simd_float4)color
						  device:(id<MTLDevice>)device
{
	if (self.suppressesTextTextures) {
		return nil;
	}
	return [super textureForText:text fontSize:fontSize color:color device:device];
}

@end

#pragma mark - Tests

@interface FxGripOnScreenControlTests : XCTestCase
@property (nonatomic, strong) FxGripOSCTestControl *control;
@property (nonatomic, strong) FxGripOSCTestAPIManager *manager;
@end

@implementation FxGripOnScreenControlTests

- (void)setUp
{
	[super setUp];
	self.manager = FxGripOSCTestAPIManager.new;
	self.manager.onScreenControlAPIv4 = FxGripOSCTestOSCAPI.new;
	self.manager.paramGetAPIv6 = FxGripOSCTestRetrievalAPI.new;
	self.manager.paramSetAPIv5 = FxGripOSCTestSettingAPI.new;
	self.manager.paramSetAPIv5.retrieval = self.manager.paramGetAPIv6;

	self.control = [[FxGripOSCTestControl alloc] initWithAPIManager:(id _Nonnull)nil];
	self.control.stubAPIManager = self.manager;
}

- (void)stagePoint:(NSPoint)point forParameter:(UInt32)parameterID
{
	self.manager.paramGetAPIv6.points[@(parameterID)] = [NSValue valueWithPoint:point];
}

/*! A rect part over object (0.2, 0.2)-(0.6, 0.6) with parameters 11 and 12. */
- (FxGripOSCRectPart *)stagedRectPartWithID:(NSInteger)partID
{
	[self stagePoint:NSMakePoint(0.2, 0.2) forParameter:11];
	[self stagePoint:NSMakePoint(0.6, 0.6) forParameter:12];
	FxGripOSCRectPart *part = [FxGripOSCRectPart partWithID:partID
									   lowerLeftParameterID:11
									  upperRightParameterID:12];
	[self.control addPart:part];
	return part;
}

- (NSInteger)hitTestAtCanvasX:(double)x y:(double)y
{
	NSInteger activePart = -1;
	[self.control hitTestOSCAtMousePositionX:x mousePositionY:y activePart:&activePart atTime:FxGripOSCTestTime()];
	return activePart;
}

#pragma mark Geometry and constants

/*! @abstract The canvas-to-Metal point conversion centers the origin and flips the y axis. */
- (void)testTheMetalPointConversionFlipsAndCenters
{
	CGSize size = CGSizeMake(100, 100);
	CGPoint center = FxGripOSCMetalPointFromCanvasPoint(CGPointMake(50, 50), size);
	XCTAssertEqualWithAccuracy(center.x, 0.0, 1e-12);
	XCTAssertEqualWithAccuracy(center.y, 0.0, 1e-12);

	CGPoint lowerLeft = FxGripOSCMetalPointFromCanvasPoint(CGPointMake(0, 0), size);
	XCTAssertEqualWithAccuracy(lowerLeft.x, -50.0, 1e-12);
	XCTAssertEqualWithAccuracy(lowerLeft.y, 50.0, 1e-12);

	CGPoint upperRight = FxGripOSCMetalPointFromCanvasPoint(CGPointMake(100, 100), size);
	XCTAssertEqualWithAccuracy(upperRight.x, 50.0, 1e-12);
	XCTAssertEqualWithAccuracy(upperRight.y, -50.0, 1e-12);
}

/*! @abstract The standard OSC fill, outline, and shadow colors carry the host-convention component values. */
- (void)testTheStandardColorsMatchTheHostConventions
{
	XCTAssertEqual(kFxGripOSCUnselectedFillColor.w, 0.25f);
	XCTAssertEqual(kFxGripOSCSelectedFillColor.w, 0.5f);
	XCTAssertEqual(kFxGripOSCOutlineColor.x, 1.0f);
	XCTAssertEqual(kFxGripOSCShadowColor.w, 1.0f);
}

/*! @abstract The control's drawing coordinates default to canvas space. */
- (void)testTheDrawingCoordinatesDefaultToCanvas
{
	XCTAssertEqual(self.control.drawingCoordinates, kFxDrawingCoordinates_CANVAS);
}

/*! @abstract Canvas-to-object and object-to-canvas conversions round-trip through the OSC API. */
- (void)testTheCoordinateConversionsRoundTripThroughTheOSCAPI
{
	CGPoint object = [self.control objectPointFromCanvasPoint:CGPointMake(40, 80)];
	XCTAssertEqualWithAccuracy(object.x, 0.4, 1e-12);
	XCTAssertEqualWithAccuracy(object.y, 0.8, 1e-12);

	CGPoint canvas = [self.control canvasPointFromObjectPoint:object];
	XCTAssertEqualWithAccuracy(canvas.x, 40.0, 1e-12);
	XCTAssertEqualWithAccuracy(canvas.y, 80.0, 1e-12);
}

#pragma mark Parts

/*! @abstract Adding parts preserves their order and sets each part's control back-reference. */
- (void)testAddPartWiresTheControlAndKeepsOrder
{
	FxGripOSCPart *first = [[FxGripOSCPart alloc] initWithPartID:1];
	FxGripOSCPart *second = [[FxGripOSCPart alloc] initWithPartID:2];
	[self.control addPart:first];
	[self.control addPart:second];

	XCTAssertEqualObjects(self.control.parts, (@[first, second]));
	XCTAssertEqualObjects(first.control, self.control);
	XCTAssertEqualObjects(second.control, self.control);
}

/*! @abstract A rect part hits a point inside its span and misses a point outside it. */
- (void)testARectPartHitsInsideAndMissesOutside
{
	[self stagedRectPartWithID:1];

	XCTAssertEqual([self hitTestAtCanvasX:40 y:40], (NSInteger)1);
	XCTAssertEqual([self hitTestAtCanvasX:70 y:40], (NSInteger)0);
}

/*! @abstract The last-added part wins a hit where two parts overlap. */
- (void)testTheLastAddedPartWinsAnOverlappingHit
{
	[self stagedRectPartWithID:1];
	FxGripOSCRectPart *top = [FxGripOSCRectPart partWithID:2
									  lowerLeftParameterID:11
									 upperRightParameterID:12];
	[self.control addPart:top];

	XCTAssertEqual([self hitTestAtCanvasX:40 y:40], (NSInteger)2);
}

/*! @abstract A point handle hits within its canvas radius of the parameter position and misses beyond it. */
- (void)testAPointHandleHitsByCanvasDistance
{
	[self stagePoint:NSMakePoint(0.5, 0.5) forParameter:21];
	FxGripOSCPointHandlePart *handle = [FxGripOSCPointHandlePart partWithID:3 parameterID:21];
	[self.control addPart:handle];

	XCTAssertEqual([self hitTestAtCanvasX:55 y:50], (NSInteger)3,
				   @"5 canvas pixels away is inside the default 10-pixel hit radius");
	XCTAssertEqual([self hitTestAtCanvasX:70 y:50], (NSInteger)0);
}

/*! @abstract A circle part hit test corrects for the input image aspect ratio. */
- (void)testACirclePartHitCorrectsForTheImageAspect
{
	[self stagePoint:NSMakePoint(0.5, 0.5) forParameter:31];
	self.manager.paramGetAPIv6.floats[@32] = @50.0;
	FxGripOSCCirclePart *circle = [FxGripOSCCirclePart partWithID:4
												centerParameterID:31
												radiusParameterID:32];
	[self.control addPart:circle];

	// Input bounds 200 x 100: the object-space radius is 50/200 = 0.25 in x, and a
	// y offset is halved by the aspect correction.
	XCTAssertEqual([self hitTestAtCanvasX:70 y:50], (NSInteger)4);
	XCTAssertEqual([self hitTestAtCanvasX:50 y:90], (NSInteger)4);
	XCTAssertEqual([self hitTestAtCanvasX:80 y:50], (NSInteger)0,
				   @"an x offset of 0.3 is outside the 0.25 object radius");
}

#pragma mark Mouse routing

/*! @abstract Dragging a rect body moves both corner parameters by the object-space delta. */
- (void)testDraggingARectPartMovesBothCornersByTheObjectDelta
{
	[self stagedRectPartWithID:1];
	BOOL forceUpdate = NO;

	[self.control mouseDownAtPositionX:40 positionY:40 activePart:1 modifiers:0
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	XCTAssertFalse(forceUpdate);

	[self.control mouseDraggedAtPositionX:50 positionY:45 activePart:1 modifiers:0
							  forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	XCTAssertTrue(forceUpdate);

	NSArray<NSDictionary *> *writes = self.manager.paramSetAPIv5.writes;
	XCTAssertEqual(writes.count, (NSUInteger)2);
	XCTAssertEqualObjects(writes[0][@"parameter"], @11);
	XCTAssertEqualWithAccuracy([writes[0][@"x"] doubleValue], 0.3, 1e-9);
	XCTAssertEqualWithAccuracy([writes[0][@"y"] doubleValue], 0.25, 1e-9);
	XCTAssertEqualObjects(writes[1][@"parameter"], @12);
	XCTAssertEqualWithAccuracy([writes[1][@"x"] doubleValue], 0.7, 1e-9);
	XCTAssertEqualWithAccuracy([writes[1][@"y"] doubleValue], 0.65, 1e-9);
}

/*! @abstract Mouse-up applies the final drag position and writes the corner parameters. */
- (void)testMouseUpRepeatsTheFinalDragAndResets
{
	[self stagedRectPartWithID:1];
	BOOL forceUpdate = NO;

	[self.control mouseDownAtPositionX:40 positionY:40 activePart:1 modifiers:0
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	[self.control mouseUpAtPositionX:50 positionY:40 activePart:1 modifiers:0
						 forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];

	XCTAssertTrue(forceUpdate);
	NSArray<NSDictionary *> *writes = self.manager.paramSetAPIv5.writes;
	XCTAssertEqual(writes.count, (NSUInteger)2);
	XCTAssertEqualWithAccuracy([writes[0][@"x"] doubleValue], 0.3, 1e-9);
}

/*! @abstract A drag with no active part writes no parameters and forces no update. */
- (void)testADragWithNoActivePartWritesNothing
{
	[self stagedRectPartWithID:1];
	BOOL forceUpdate = YES;

	[self.control mouseDownAtPositionX:40 positionY:40 activePart:0 modifiers:0
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	[self.control mouseDraggedAtPositionX:50 positionY:45 activePart:0 modifiers:0
							  forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];

	XCTAssertFalse(forceUpdate);
	XCTAssertEqual(self.manager.paramSetAPIv5.writes.count, (NSUInteger)0);
}

/*! @abstract Dragging a point handle writes the absolute object-space pointer position. */
- (void)testDraggingAPointHandleWritesTheAbsoluteObjectPosition
{
	[self stagePoint:NSMakePoint(0.5, 0.5) forParameter:21];
	[self.control addPart:[FxGripOSCPointHandlePart partWithID:3 parameterID:21]];
	BOOL forceUpdate = NO;

	[self.control mouseDownAtPositionX:50 positionY:50 activePart:3 modifiers:0
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	[self.control mouseDraggedAtPositionX:52 positionY:48 activePart:3 modifiers:0
							  forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];

	XCTAssertTrue(forceUpdate);
	NSDictionary *write = self.manager.paramSetAPIv5.writes.lastObject;
	XCTAssertEqualObjects(write[@"parameter"], @21);
	XCTAssertEqualWithAccuracy([write[@"x"] doubleValue], 0.52, 1e-9);
	XCTAssertEqualWithAccuracy([write[@"y"] doubleValue], 0.48, 1e-9);
}

/*! @abstract Shift constrains a mostly horizontal drag to the x axis and pins y to the click. */
- (void)testShiftConstrainsADragToTheDominantHorizontalAxis
{
	[self stagePoint:NSMakePoint(0.5, 0.5) forParameter:21];
	[self.control addPart:[FxGripOSCPointHandlePart partWithID:3 parameterID:21]];
	BOOL forceUpdate = NO;

	[self.control mouseDownAtPositionX:50 positionY:50 activePart:3 modifiers:0
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	[self.control mouseDraggedAtPositionX:58 positionY:53 activePart:3 modifiers:kFxModifierKey_SHIFT
							  forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];

	NSDictionary *write = self.manager.paramSetAPIv5.writes.lastObject;
	XCTAssertEqualWithAccuracy([write[@"x"] doubleValue], 0.58, 1e-9);
	XCTAssertEqualWithAccuracy([write[@"y"] doubleValue], 0.50, 1e-9, @"Shift pins y to the click");
}

/*! @abstract Shift constrains a mostly vertical drag to the y axis and pins x to the click. */
- (void)testShiftConstrainsADragToTheDominantVerticalAxis
{
	[self stagePoint:NSMakePoint(0.5, 0.5) forParameter:21];
	[self.control addPart:[FxGripOSCPointHandlePart partWithID:3 parameterID:21]];
	BOOL forceUpdate = NO;

	[self.control mouseDownAtPositionX:50 positionY:50 activePart:3 modifiers:0
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	[self.control mouseDraggedAtPositionX:53 positionY:58 activePart:3 modifiers:kFxModifierKey_SHIFT
							  forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];

	NSDictionary *write = self.manager.paramSetAPIv5.writes.lastObject;
	XCTAssertEqualWithAccuracy([write[@"x"] doubleValue], 0.50, 1e-9, @"Shift pins x to the click");
	XCTAssertEqualWithAccuracy([write[@"y"] doubleValue], 0.58, 1e-9);
}

/*! @abstract Option slows a drag to a tenth of the pointer travel. */
- (void)testOptionFineDragMovesAtATenthOfTheTravel
{
	[self stagePoint:NSMakePoint(0.5, 0.5) forParameter:21];
	[self.control addPart:[FxGripOSCPointHandlePart partWithID:3 parameterID:21]];
	BOOL forceUpdate = NO;

	[self.control mouseDownAtPositionX:50 positionY:50 activePart:3 modifiers:0
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	// 40 units of travel with Option becomes 4 units at the fine-drag scale: 0.5 → 0.54.
	[self.control mouseDraggedAtPositionX:90 positionY:50 activePart:3 modifiers:kFxModifierKey_OPTION
							  forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];

	NSDictionary *write = self.manager.paramSetAPIv5.writes.lastObject;
	XCTAssertEqualWithAccuracy([write[@"x"] doubleValue], 0.54, 1e-9, @"Option slows the drag to a tenth");
	XCTAssertEqualWithAccuracy([write[@"y"] doubleValue], 0.50, 1e-9);
}

/*! @abstract Dragging a circle body moves only the center parameter. */
- (void)testDraggingACirclePartMovesOnlyTheCenter
{
	[self stagePoint:NSMakePoint(0.5, 0.5) forParameter:31];
	self.manager.paramGetAPIv6.floats[@32] = @50.0;
	[self.control addPart:[FxGripOSCCirclePart partWithID:4 centerParameterID:31 radiusParameterID:32]];
	BOOL forceUpdate = NO;

	[self.control mouseDownAtPositionX:50 positionY:50 activePart:4 modifiers:0
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	[self.control mouseDraggedAtPositionX:60 positionY:50 activePart:4 modifiers:0
							  forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];

	XCTAssertTrue(forceUpdate);
	NSArray<NSDictionary *> *writes = self.manager.paramSetAPIv5.writes;
	XCTAssertEqual(writes.count, (NSUInteger)1);
	XCTAssertEqualObjects(writes[0][@"parameter"], @31);
	XCTAssertEqualWithAccuracy([writes[0][@"x"] doubleValue], 0.6, 1e-9);
	XCTAssertEqualWithAccuracy([writes[0][@"y"] doubleValue], 0.5, 1e-9);
}

#pragma mark Line and gradient

/*! A line over object (0.2, 0.2)-(0.6, 0.2) with parameters 51 and 52. */
- (void)stageLinePoints
{
	[self stagePoint:NSMakePoint(0.2, 0.2) forParameter:51];
	[self stagePoint:NSMakePoint(0.6, 0.2) forParameter:52];
}

/*! @abstract A line part hits near its segment and misses points far from it or beyond its endpoints. */
- (void)testALinePartHitsNearTheSegmentAndMissesFarOrBeyond
{
	[self stageLinePoints];
	[self.control addPart:[FxGripOSCLinePart partWithID:5 startParameterID:51 endParameterID:52]];

	XCTAssertEqual([self hitTestAtCanvasX:40 y:23], (NSInteger)5,
				   @"3 canvas pixels off the segment is inside the default 6-pixel radius");
	XCTAssertEqual([self hitTestAtCanvasX:40 y:30], (NSInteger)0);
	XCTAssertEqual([self hitTestAtCanvasX:70 y:20], (NSInteger)0,
				   @"10 pixels beyond the endpoint measures to the endpoint, not the infinite line");
}

/*! @abstract Dragging a line body moves both endpoint parameters by the object-space delta. */
- (void)testDraggingALinePartMovesBothEndpoints
{
	[self stageLinePoints];
	[self.control addPart:[FxGripOSCLinePart partWithID:5 startParameterID:51 endParameterID:52]];
	BOOL forceUpdate = NO;

	[self.control mouseDownAtPositionX:40 positionY:20 activePart:5 modifiers:0
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	[self.control mouseDraggedAtPositionX:50 positionY:25 activePart:5 modifiers:0
							  forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];

	XCTAssertTrue(forceUpdate);
	NSArray<NSDictionary *> *writes = self.manager.paramSetAPIv5.writes;
	XCTAssertEqual(writes.count, (NSUInteger)2);
	XCTAssertEqualObjects(writes[0][@"parameter"], @51);
	XCTAssertEqualWithAccuracy([writes[0][@"x"] doubleValue], 0.3, 1e-9);
	XCTAssertEqualWithAccuracy([writes[0][@"y"] doubleValue], 0.25, 1e-9);
	XCTAssertEqualObjects(writes[1][@"parameter"], @52);
	XCTAssertEqualWithAccuracy([writes[1][@"x"] doubleValue], 0.7, 1e-9);
	XCTAssertEqualWithAccuracy([writes[1][@"y"] doubleValue], 0.25, 1e-9);
}

/*! @abstract The gradient composite gives its endpoint handles the hit over the line body beneath them. */
- (void)testTheGradientCompositeGivesEndpointHandlesTheTopHit
{
	[self stageLinePoints];
	[self.control addParts:[FxGripOSCLinePart gradientPartsWithLineID:5
														startHandleID:6
														  endHandleID:7
													 startParameterID:51
													   endParameterID:52]];

	XCTAssertEqual(self.control.parts.count, (NSUInteger)3);
	XCTAssertEqual([self hitTestAtCanvasX:20 y:20], (NSInteger)6,
				   @"the start handle wins the hit over the line body beneath it");
	XCTAssertEqual([self hitTestAtCanvasX:60 y:20], (NSInteger)7);
	XCTAssertEqual([self hitTestAtCanvasX:40 y:20], (NSInteger)5,
				   @"mid-segment belongs to the line body");
}

#pragma mark Angle dial

- (void)stageDialWithRadiansPerUnit:(double)radiansPerUnit angleValue:(double)angleValue
{
	[self stagePoint:NSMakePoint(0.5, 0.5) forParameter:61];
	self.manager.paramGetAPIv6.floats[@62] = @(angleValue);
	FxGripOSCAngleDialPart *dial = [FxGripOSCAngleDialPart partWithID:9
													centerParameterID:61
													 angleParameterID:62];
	dial.radiansPerUnit = radiansPerUnit;
	[self.control addPart:dial];
}

/*! @abstract An angle dial hits at its spoke tip and misses near the center. */
- (void)testTheAngleDialTipHitsAtTheSpokeTip
{
	[self stageDialWithRadiansPerUnit:1.0 angleValue:0.0];

	// Angle 0 with the default 40-pixel spoke puts the tip at canvas (90, 50).
	XCTAssertEqual([self hitTestAtCanvasX:92 y:50], (NSInteger)9);
	XCTAssertEqual([self hitTestAtCanvasX:60 y:50], (NSInteger)0);
}

/*! @abstract Dragging the angle dial writes the pointer angle around the center. */
- (void)testDraggingTheAngleDialWritesThePointerAngle
{
	[self stageDialWithRadiansPerUnit:1.0 angleValue:0.0];
	BOOL forceUpdate = NO;

	[self.control mouseDownAtPositionX:90 positionY:50 activePart:9 modifiers:0
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	[self.control mouseDraggedAtPositionX:60 positionY:60 activePart:9 modifiers:0
							  forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];

	XCTAssertTrue(forceUpdate);
	NSDictionary *write = self.manager.paramSetAPIv5.writes.lastObject;
	XCTAssertEqualObjects(write[@"parameter"], @62);
	XCTAssertEqualWithAccuracy([write[@"value"] doubleValue], M_PI / 4.0, 1e-9,
							   @"the pointer at canvas (60, 60) sits 45 degrees around the center");
}

/*! @abstract The angle dial scales the written value by its radians-per-unit, so a degree parameter receives degrees. */
- (void)testTheAngleDialRespectsRadiansPerUnit
{
	[self stageDialWithRadiansPerUnit:M_PI / 180.0 angleValue:0.0];
	BOOL forceUpdate = NO;

	[self.control mouseDownAtPositionX:90 positionY:50 activePart:9 modifiers:0
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	[self.control mouseDraggedAtPositionX:60 positionY:60 activePart:9 modifiers:0
							  forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];

	NSDictionary *write = self.manager.paramSetAPIv5.writes.lastObject;
	XCTAssertEqualWithAccuracy([write[@"value"] doubleValue], 45.0, 1e-9,
							   @"a degree-unit parameter receives degrees");
}

/*! @abstract Shift snaps the angle dial to the nearest forty-five degrees. */
- (void)testShiftSnapsTheAngleDialToFortyFiveDegrees
{
	[self stageDialWithRadiansPerUnit:1.0 angleValue:0.0];
	BOOL forceUpdate = NO;

	// Canvas (90, 70) is 26.6° around the center (50, 50); Shift snaps it to 45°.
	[self.control mouseDownAtPositionX:90 positionY:50 activePart:9 modifiers:kFxModifierKey_SHIFT
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	[self.control mouseDraggedAtPositionX:90 positionY:70 activePart:9 modifiers:kFxModifierKey_SHIFT
							  forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];

	NSDictionary *write = self.manager.paramSetAPIv5.writes.lastObject;
	XCTAssertEqualWithAccuracy([write[@"value"] doubleValue], M_PI_4, 1e-9,
							   @"Shift snaps the dial to the nearest 45 degrees");
}

#pragma mark Rectangle corners

/*! @abstract A rect corner part hits at its corner handle and misses the interior. */
- (void)testARectCornerHitsItsHandle
{
	[self stagePoint:NSMakePoint(0.2, 0.2) forParameter:11];
	[self stagePoint:NSMakePoint(0.6, 0.6) forParameter:12];
	[self.control addPart:[FxGripOSCRectCornerPart partWithID:13
													   corner:FxGripOSCRectCornerLowerRight
										 lowerLeftParameterID:11
										upperRightParameterID:12]];

	XCTAssertEqual([self hitTestAtCanvasX:62 y:18], (NSInteger)13);
	XCTAssertEqual([self hitTestAtCanvasX:50 y:50], (NSInteger)0);
}

/*! @abstract Dragging a lower-right corner writes the x to the upper-right parameter and the y to the lower-left. */
- (void)testDraggingALowerRightCornerWritesTheMixedComponents
{
	[self stagePoint:NSMakePoint(0.2, 0.2) forParameter:11];
	[self stagePoint:NSMakePoint(0.6, 0.6) forParameter:12];
	[self.control addPart:[FxGripOSCRectCornerPart partWithID:13
													   corner:FxGripOSCRectCornerLowerRight
										 lowerLeftParameterID:11
										upperRightParameterID:12]];
	BOOL forceUpdate = NO;

	[self.control mouseDownAtPositionX:60 positionY:20 activePart:13 modifiers:0
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	[self.control mouseDraggedAtPositionX:70 positionY:10 activePart:13 modifiers:0
							  forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];

	XCTAssertTrue(forceUpdate);
	NSArray<NSDictionary *> *writes = self.manager.paramSetAPIv5.writes;
	XCTAssertEqual(writes.count, (NSUInteger)2);
	XCTAssertEqualObjects(writes[0][@"parameter"], @11);
	XCTAssertEqualWithAccuracy([writes[0][@"x"] doubleValue], 0.2, 1e-9);
	XCTAssertEqualWithAccuracy([writes[0][@"y"] doubleValue], 0.1, 1e-9);
	XCTAssertEqualObjects(writes[1][@"parameter"], @12);
	XCTAssertEqualWithAccuracy([writes[1][@"x"] doubleValue], 0.7, 1e-9);
	XCTAssertEqualWithAccuracy([writes[1][@"y"] doubleValue], 0.6, 1e-9);
}

/*! @abstract Shift locks a rect corner resize to the original aspect ratio about the fixed opposite corner. */
- (void)testShiftLocksARectCornerResizeToTheAspectRatio
{
	// A 2:1 rectangle: width 0.4, height 0.2.
	[self stagePoint:NSMakePoint(0.2, 0.2) forParameter:11];
	[self stagePoint:NSMakePoint(0.6, 0.4) forParameter:12];
	[self.control addPart:[FxGripOSCRectCornerPart partWithID:13
													   corner:FxGripOSCRectCornerLowerRight
										 lowerLeftParameterID:11
										upperRightParameterID:12]];
	BOOL forceUpdate = NO;

	// The pointer at (1.0, 0.1) pushes x twice as far as y proportionally; the lock follows x and
	// pins y so the new rectangle keeps 2:1 about the fixed upper-left corner (0.2, 0.4).
	[self.control mouseDownAtPositionX:60 positionY:20 activePart:13 modifiers:kFxModifierKey_SHIFT
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	[self.control mouseDraggedAtPositionX:100 positionY:10 activePart:13 modifiers:kFxModifierKey_SHIFT
							  forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];

	NSArray<NSDictionary *> *writes = self.manager.paramSetAPIv5.writes;
	XCTAssertEqualObjects(writes[0][@"parameter"], @11);
	XCTAssertEqualWithAccuracy([writes[0][@"x"] doubleValue], 0.2, 1e-9);
	XCTAssertEqualWithAccuracy([writes[0][@"y"] doubleValue], 0.0, 1e-9);
	XCTAssertEqualObjects(writes[1][@"parameter"], @12);
	XCTAssertEqualWithAccuracy([writes[1][@"x"] doubleValue], 1.0, 1e-9);
	XCTAssertEqualWithAccuracy([writes[1][@"y"] doubleValue], 0.4, 1e-9);
}

/*! @abstract Option keeps the rectangle center fixed and mirrors the opposite corner while resizing. */
- (void)testOptionDraggingARectCornerResizesAboutTheCenter
{
	[self stagePoint:NSMakePoint(0.2, 0.2) forParameter:11];
	[self stagePoint:NSMakePoint(0.6, 0.6) forParameter:12];
	[self.control addPart:[FxGripOSCRectCornerPart partWithID:13
													   corner:FxGripOSCRectCornerLowerRight
										 lowerLeftParameterID:11
										upperRightParameterID:12]];
	BOOL forceUpdate = NO;

	// Option keeps the center (0.4, 0.4) fixed; the upper-left corner mirrors the dragged one.
	[self.control mouseDownAtPositionX:60 positionY:20 activePart:13 modifiers:kFxModifierKey_OPTION
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	[self.control mouseDraggedAtPositionX:80 positionY:10 activePart:13 modifiers:kFxModifierKey_OPTION
							  forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];

	NSArray<NSDictionary *> *writes = self.manager.paramSetAPIv5.writes;
	XCTAssertEqualObjects(writes[0][@"parameter"], @11);
	XCTAssertEqualWithAccuracy([writes[0][@"x"] doubleValue], 0.0, 1e-9);
	XCTAssertEqualWithAccuracy([writes[0][@"y"] doubleValue], 0.1, 1e-9);
	XCTAssertEqualObjects(writes[1][@"parameter"], @12);
	XCTAssertEqualWithAccuracy([writes[1][@"x"] doubleValue], 0.8, 1e-9);
	XCTAssertEqualWithAccuracy([writes[1][@"y"] doubleValue], 0.7, 1e-9);
}

/*! @abstract Option-Shift resizes a rect corner about the fixed center while holding the aspect ratio. */
- (void)testOptionShiftResizesARectCornerAboutTheCenterAtTheAspectRatio
{
	// A 2:1 rectangle: width 0.4, height 0.2, center (0.4, 0.3).
	[self stagePoint:NSMakePoint(0.2, 0.2) forParameter:11];
	[self stagePoint:NSMakePoint(0.6, 0.4) forParameter:12];
	[self.control addPart:[FxGripOSCRectCornerPart partWithID:13
													   corner:FxGripOSCRectCornerLowerRight
										 lowerLeftParameterID:11
										upperRightParameterID:12]];
	BOOL forceUpdate = NO;

	// x dominates (scale 3 about the center); the mirrored corners keep 2:1 and hold the center.
	FxModifierKeys optionShift = kFxModifierKey_OPTION | kFxModifierKey_SHIFT;
	[self.control mouseDownAtPositionX:60 positionY:20 activePart:13 modifiers:optionShift
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	[self.control mouseDraggedAtPositionX:100 positionY:10 activePart:13 modifiers:optionShift
							  forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];

	NSArray<NSDictionary *> *writes = self.manager.paramSetAPIv5.writes;
	XCTAssertEqualObjects(writes[0][@"parameter"], @11);
	XCTAssertEqualWithAccuracy([writes[0][@"x"] doubleValue], -0.2, 1e-9);
	XCTAssertEqualWithAccuracy([writes[0][@"y"] doubleValue], 0.0, 1e-9);
	XCTAssertEqualObjects(writes[1][@"parameter"], @12);
	XCTAssertEqualWithAccuracy([writes[1][@"x"] doubleValue], 1.0, 1e-9);
	XCTAssertEqualWithAccuracy([writes[1][@"y"] doubleValue], 0.6, 1e-9);
}

/*! @abstract The rect composite numbers its corners in LL, LR, UR, UL order, and corners win the hit over the body. */
- (void)testTheRectCompositeNumbersCornersAndCornersWinHits
{
	[self stagePoint:NSMakePoint(0.2, 0.2) forParameter:11];
	[self stagePoint:NSMakePoint(0.6, 0.6) forParameter:12];
	[self.control addParts:[FxGripOSCRectPart rectPartsWithBodyID:1
													firstCornerID:2
											 lowerLeftParameterID:11
											upperRightParameterID:12]];

	XCTAssertEqual(self.control.parts.count, (NSUInteger)5);
	XCTAssertEqual([self hitTestAtCanvasX:20 y:20], (NSInteger)2,
				   @"the lower-left corner handle wins over the body");
	XCTAssertEqual([self hitTestAtCanvasX:60 y:60], (NSInteger)4,
				   @"corners number from firstCornerID in LL, LR, UR, UL order");
	XCTAssertEqual([self hitTestAtCanvasX:40 y:40], (NSInteger)1);
}

#pragma mark Circle radius handle

- (void)stageCircle
{
	[self stagePoint:NSMakePoint(0.5, 0.5) forParameter:31];
	self.manager.paramGetAPIv6.floats[@32] = @50.0;
}

/*! @abstract The circle radius handle hits on the rim at angle zero and misses at the center. */
- (void)testTheCircleRadiusHandleSitsOnTheRim
{
	[self stageCircle];
	[self.control addPart:[FxGripOSCCircleRadiusHandlePart partWithID:8
													centerParameterID:31
													radiusParameterID:32]];

	// Input bounds 200 x 100: the rim at angle 0 is object (0.75, 0.5), canvas (75, 50).
	XCTAssertEqual([self hitTestAtCanvasX:77 y:50], (NSInteger)8);
	XCTAssertEqual([self hitTestAtCanvasX:50 y:50], (NSInteger)0);
}

/*! @abstract Dragging the radius handle writes the radius in input pixels, aspect-correcting a y offset. */
- (void)testDraggingTheRadiusHandleWritesTheInputPixelRadius
{
	[self stageCircle];
	[self.control addPart:[FxGripOSCCircleRadiusHandlePart partWithID:8
													centerParameterID:31
													radiusParameterID:32]];
	BOOL forceUpdate = NO;

	[self.control mouseDownAtPositionX:75 positionY:50 activePart:8 modifiers:0
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	[self.control mouseDraggedAtPositionX:80 positionY:50 activePart:8 modifiers:0
							  forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];

	XCTAssertTrue(forceUpdate);
	NSDictionary *write = self.manager.paramSetAPIv5.writes.lastObject;
	XCTAssertEqualObjects(write[@"parameter"], @32);
	XCTAssertEqualWithAccuracy([write[@"value"] doubleValue], 60.0, 1e-9,
							   @"an x offset of 0.3 in object space is 60 input pixels");

	[self.control mouseDraggedAtPositionX:50 positionY:90 activePart:8 modifiers:0
							  forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	write = self.manager.paramSetAPIv5.writes.lastObject;
	XCTAssertEqualWithAccuracy([write[@"value"] doubleValue], 40.0, 1e-9,
							   @"a y offset is aspect-corrected before scaling to input pixels");
}

/*! @abstract The circle composite gives the radius handle the hit over the body. */
- (void)testTheCircleCompositeRadiusHandleWinsOverTheBody
{
	[self stageCircle];
	[self.control addParts:[FxGripOSCCirclePart circlePartsWithBodyID:4
													   radiusHandleID:8
													centerParameterID:31
													radiusParameterID:32]];

	XCTAssertEqual(self.control.parts.count, (NSUInteger)2);
	XCTAssertEqual([self hitTestAtCanvasX:75 y:50], (NSInteger)8);
	XCTAssertEqual([self hitTestAtCanvasX:60 y:50], (NSInteger)4);
}

#pragma mark Rotation handle

- (void)stageRotatableCircleWithAngle:(double)angleValue
{
	[self stageCircle];
	[self stagePoint:NSMakePoint(0.5, 0.5) forParameter:31];
	self.manager.paramGetAPIv6.floats[@33] = @(angleValue);
}

/*! @abstract The rotation handle rides the rim at the angle parameter, distinct from the radius handle at angle zero. */
- (void)testTheRotationHandleRidesTheRimAtTheAngleParameter
{
	[self stageRotatableCircleWithAngle:M_PI_2];
	[self.control addPart:[FxGripOSCRotationHandlePart partWithID:10
												centerParameterID:31
												radiusParameterID:32
												 angleParameterID:33]];

	// Angle pi/2 with radius 50 in 200 x 100 bounds is object (0.5, 1.0), canvas (50, 100).
	XCTAssertEqual([self hitTestAtCanvasX:52 y:100], (NSInteger)10);
	XCTAssertEqual([self hitTestAtCanvasX:75 y:50], (NSInteger)0,
				   @"the rim at angle 0 is the radius handle's spot, not the rotation handle's");
}

/*! @abstract Dragging the rotation handle writes the pointer angle around the center. */
- (void)testDraggingTheRotationHandleWritesThePointerAngleAroundTheCenter
{
	[self stageRotatableCircleWithAngle:M_PI_2];
	[self.control addPart:[FxGripOSCRotationHandlePart partWithID:10
												centerParameterID:31
												radiusParameterID:32
												 angleParameterID:33]];
	BOOL forceUpdate = NO;

	[self.control mouseDownAtPositionX:50 positionY:100 activePart:10 modifiers:0
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	[self.control mouseDraggedAtPositionX:80 positionY:50 activePart:10 modifiers:0
							  forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];

	XCTAssertTrue(forceUpdate);
	NSDictionary *write = self.manager.paramSetAPIv5.writes.lastObject;
	XCTAssertEqualObjects(write[@"parameter"], @33);
	XCTAssertEqualWithAccuracy([write[@"value"] doubleValue], 0.0, 1e-9,
							   @"the pointer due right of the center is angle 0");

	[self.control mouseDraggedAtPositionX:50 positionY:90 activePart:10 modifiers:0
							  forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	write = self.manager.paramSetAPIv5.writes.lastObject;
	XCTAssertEqualWithAccuracy([write[@"value"] doubleValue], M_PI_2, 1e-9);
}

/*! @abstract Shift snaps the rotation handle to the nearest forty-five degrees. */
- (void)testShiftSnapsTheRotationHandleToFortyFiveDegrees
{
	[self stageRotatableCircleWithAngle:M_PI_2];
	[self.control addPart:[FxGripOSCRotationHandlePart partWithID:10
												centerParameterID:31
												radiusParameterID:32
												 angleParameterID:33]];
	BOOL forceUpdate = NO;

	// Canvas (80, 70) is 33.7° around the center (50, 50); Shift snaps it to 45°.
	[self.control mouseDownAtPositionX:50 positionY:100 activePart:10 modifiers:kFxModifierKey_SHIFT
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	[self.control mouseDraggedAtPositionX:80 positionY:70 activePart:10 modifiers:kFxModifierKey_SHIFT
							  forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];

	NSDictionary *write = self.manager.paramSetAPIv5.writes.lastObject;
	XCTAssertEqualObjects(write[@"parameter"], @33);
	XCTAssertEqualWithAccuracy([write[@"value"] doubleValue], M_PI_4, 1e-9,
							   @"Shift snaps the rotation to the nearest 45 degrees");
}

/*! @abstract The full circle composite composes the body, radius handle, and rotation handle, each winning its own hit. */
- (void)testTheFullCircleCompositeComposesBodyRadiusAndRotation
{
	[self stageRotatableCircleWithAngle:M_PI_2];
	[self.control addParts:[FxGripOSCCirclePart circlePartsWithBodyID:4
													   radiusHandleID:8
													 rotationHandleID:10
													centerParameterID:31
													radiusParameterID:32
													 angleParameterID:33]];

	XCTAssertEqual(self.control.parts.count, (NSUInteger)3);
	XCTAssertEqual([self hitTestAtCanvasX:60 y:50], (NSInteger)4);
	XCTAssertEqual([self hitTestAtCanvasX:75 y:50], (NSInteger)8);
	XCTAssertEqual([self hitTestAtCanvasX:50 y:100], (NSInteger)10);
}

#pragma mark Polyline

/*! A square chain over parameters 71-74: LL, LR, UR, UL of (0.2, 0.2)-(0.6, 0.6). */
- (NSArray<NSNumber *> *)stageSquareChain
{
	[self stagePoint:NSMakePoint(0.2, 0.2) forParameter:71];
	[self stagePoint:NSMakePoint(0.6, 0.2) forParameter:72];
	[self stagePoint:NSMakePoint(0.6, 0.6) forParameter:73];
	[self stagePoint:NSMakePoint(0.2, 0.6) forParameter:74];
	return @[@71, @72, @73, @74];
}

/*! @abstract A closed polyline hits every segment including the wrap from the last vertex to the first, and misses the interior. */
- (void)testAClosedPolylineHitsEverySegmentIncludingTheWrap
{
	NSArray<NSNumber *> *chain = [self stageSquareChain];
	[self.control addPart:[FxGripOSCPolylinePart partWithID:20 pointParameterIDs:chain closed:YES]];

	XCTAssertEqual([self hitTestAtCanvasX:40 y:20], (NSInteger)20);
	XCTAssertEqual([self hitTestAtCanvasX:20 y:40], (NSInteger)20,
				   @"the wrap segment from the last vertex to the first is part of a closed chain");
	XCTAssertEqual([self hitTestAtCanvasX:40 y:40], (NSInteger)0,
				   @"the interior of the outline is not the outline");
}

/*! @abstract An open polyline hits its drawn segments and has no wrap segment. */
- (void)testAnOpenPolylineHasNoWrapSegment
{
	NSArray<NSNumber *> *chain = [self stageSquareChain];
	[self.control addPart:[FxGripOSCPolylinePart partWithID:20 pointParameterIDs:chain closed:NO]];

	XCTAssertEqual([self hitTestAtCanvasX:40 y:20], (NSInteger)20);
	XCTAssertEqual([self hitTestAtCanvasX:20 y:40], (NSInteger)0);
}

/*! @abstract Dragging a polyline body moves every vertex parameter by the object-space delta. */
- (void)testDraggingAPolylineMovesEveryVertex
{
	NSArray<NSNumber *> *chain = [self stageSquareChain];
	[self.control addPart:[FxGripOSCPolylinePart partWithID:20 pointParameterIDs:chain closed:YES]];
	BOOL forceUpdate = NO;

	[self.control mouseDownAtPositionX:40 positionY:20 activePart:20 modifiers:0
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	[self.control mouseDraggedAtPositionX:50 positionY:30 activePart:20 modifiers:0
							  forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];

	XCTAssertTrue(forceUpdate);
	NSArray<NSDictionary *> *writes = self.manager.paramSetAPIv5.writes;
	XCTAssertEqual(writes.count, (NSUInteger)4);
	XCTAssertEqualObjects(writes[0][@"parameter"], @71);
	XCTAssertEqualWithAccuracy([writes[0][@"x"] doubleValue], 0.3, 1e-9);
	XCTAssertEqualWithAccuracy([writes[0][@"y"] doubleValue], 0.3, 1e-9);
	XCTAssertEqualObjects(writes[3][@"parameter"], @74);
	XCTAssertEqualWithAccuracy([writes[3][@"x"] doubleValue], 0.3, 1e-9);
	XCTAssertEqualWithAccuracy([writes[3][@"y"] doubleValue], 0.7, 1e-9);
}

/*! @abstract The corner-pin composite numbers its vertex handles in chain order, and handles win the hit over the body. */
- (void)testTheCornerPinCompositeNumbersHandlesInChainOrder
{
	NSArray<NSNumber *> *chain = [self stageSquareChain];
	[self.control addParts:[FxGripOSCPolylinePart polylinePartsWithBodyID:20
															firstHandleID:21
														pointParameterIDs:chain
																   closed:YES]];

	XCTAssertEqual(self.control.parts.count, (NSUInteger)5);
	XCTAssertEqual([self hitTestAtCanvasX:20 y:20], (NSInteger)21);
	XCTAssertEqual([self hitTestAtCanvasX:60 y:60], (NSInteger)23);
	XCTAssertEqual([self hitTestAtCanvasX:40 y:20], (NSInteger)20);
}

#pragma mark Box (center + size + angle)

/*! A box at center (0.5, 0.5), width 80 px, height 40 px, on parameters 81-84. */
- (void)stageBoxWithAngle:(double)angleValue
{
	[self stagePoint:NSMakePoint(0.5, 0.5) forParameter:81];
	self.manager.paramGetAPIv6.floats[@82] = @80.0;
	self.manager.paramGetAPIv6.floats[@83] = @40.0;
	self.manager.paramGetAPIv6.floats[@84] = @(angleValue);
}

- (FxGripOSCBoxPart *)boxBodyPart
{
	return [FxGripOSCBoxPart partWithID:30
					  centerParameterID:81
					   widthParameterID:82
					  heightParameterID:83
					   angleParameterID:84];
}

/*! @abstract A box hits inside its rotated frame and misses points inside the unrotated frame only. */
- (void)testABoxHitsInsideItsRotatedFrame
{
	[self stageBoxWithAngle:M_PI_2];
	[self.control addPart:[self boxBodyPart]];

	// Rotated 90 degrees, the 80 x 40 pixel box extends 40 pixels vertically.
	XCTAssertEqual([self hitTestAtCanvasX:50 y:85], (NSInteger)30);
	XCTAssertEqual([self hitTestAtCanvasX:65 y:50], (NSInteger)0,
				   @"30 pixels along x is inside the unrotated box but outside the rotated one");
}

/*! @abstract A box with a zero angle hit-tests as axis-aligned. */
- (void)testABoxWithoutAnAngleStaysAxisAligned
{
	[self stageBoxWithAngle:0.0];
	[self.control addPart:[self boxBodyPart]];

	XCTAssertEqual([self hitTestAtCanvasX:65 y:50], (NSInteger)30);
	XCTAssertEqual([self hitTestAtCanvasX:50 y:85], (NSInteger)0);
}

/*! @abstract Dragging a box body moves only the center parameter. */
- (void)testDraggingABoxBodyMovesOnlyTheCenter
{
	[self stageBoxWithAngle:M_PI_2];
	[self.control addPart:[self boxBodyPart]];
	BOOL forceUpdate = NO;

	[self.control mouseDownAtPositionX:50 positionY:50 activePart:30 modifiers:0
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	[self.control mouseDraggedAtPositionX:60 positionY:50 activePart:30 modifiers:0
							  forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];

	XCTAssertTrue(forceUpdate);
	NSArray<NSDictionary *> *writes = self.manager.paramSetAPIv5.writes;
	XCTAssertEqual(writes.count, (NSUInteger)1);
	XCTAssertEqualObjects(writes[0][@"parameter"], @81);
	XCTAssertEqualWithAccuracy([writes[0][@"x"] doubleValue], 0.6, 1e-9);
}

/*! @abstract A box corner handle hits at the rotated position of its local corner. */
- (void)testABoxCornerRidesTheRotation
{
	[self stageBoxWithAngle:M_PI_2];
	[self.control addPart:[FxGripOSCBoxCornerPart partWithID:31
													  corner:FxGripOSCRectCornerUpperRight
										   centerParameterID:81
											widthParameterID:82
										   heightParameterID:83
											angleParameterID:84]];

	// The upper-right local corner (40, 20) rotates to canvas (40, 90).
	XCTAssertEqual([self hitTestAtCanvasX:42 y:90], (NSInteger)31);
	XCTAssertEqual([self hitTestAtCanvasX:70 y:70], (NSInteger)0);
}

/*! @abstract Option keeps the box center fixed and doubles the pointer's local offset into width and height. */
- (void)testOptionDraggingABoxCornerResizesAboutTheCenter
{
	[self stageBoxWithAngle:M_PI_2];
	[self.control addPart:[FxGripOSCBoxCornerPart partWithID:31
													  corner:FxGripOSCRectCornerUpperRight
										   centerParameterID:81
											widthParameterID:82
										   heightParameterID:83
											angleParameterID:84]];
	BOOL forceUpdate = NO;

	[self.control mouseDownAtPositionX:40 positionY:90 activePart:31 modifiers:kFxModifierKey_OPTION
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	[self.control mouseDraggedAtPositionX:55 positionY:95 activePart:31 modifiers:kFxModifierKey_OPTION
							  forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];

	XCTAssertTrue(forceUpdate);
	NSArray<NSDictionary *> *writes = self.manager.paramSetAPIv5.writes;
	XCTAssertEqual(writes.count, (NSUInteger)2, @"Option keeps the center fixed: only width and height move");
	XCTAssertEqualObjects(writes[0][@"parameter"], @82);
	XCTAssertEqualWithAccuracy([writes[0][@"value"] doubleValue], 90.0, 1e-9,
							   @"the pointer's local x of 45 pixels doubles into the width");
	XCTAssertEqualObjects(writes[1][@"parameter"], @83);
	XCTAssertEqualWithAccuracy([writes[1][@"value"] doubleValue], 20.0, 1e-9,
							   @"the pointer's local y of 10 pixels doubles into the height");
}

/*! @abstract A plain box corner drag anchors the opposite corner and writes the new width, height, and shifted center. */
- (void)testDraggingABoxCornerAnchorsTheOppositeCornerAndShiftsTheCenter
{
	[self stageBoxWithAngle:M_PI_2];
	[self.control addPart:[FxGripOSCBoxCornerPart partWithID:31
													  corner:FxGripOSCRectCornerUpperRight
										   centerParameterID:81
											widthParameterID:82
										   heightParameterID:83
											angleParameterID:84]];
	BOOL forceUpdate = NO;

	// The pointer resolves to local (30, 10); the opposite corner (-40, -20) stays fixed, so the
	// box becomes 70 x 30 and its center shifts to (0.525, 0.45).
	[self.control mouseDownAtPositionX:40 positionY:90 activePart:31 modifiers:0
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	[self.control mouseDraggedAtPositionX:45 positionY:80 activePart:31 modifiers:0
							  forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];

	XCTAssertTrue(forceUpdate);
	NSArray<NSDictionary *> *writes = self.manager.paramSetAPIv5.writes;
	XCTAssertEqual(writes.count, (NSUInteger)3, @"the default moves width, height, and the center");
	XCTAssertEqualObjects(writes[0][@"parameter"], @82);
	XCTAssertEqualWithAccuracy([writes[0][@"value"] doubleValue], 70.0, 1e-9);
	XCTAssertEqualObjects(writes[1][@"parameter"], @83);
	XCTAssertEqualWithAccuracy([writes[1][@"value"] doubleValue], 30.0, 1e-9);
	XCTAssertEqualObjects(writes[2][@"parameter"], @81);
	XCTAssertEqualWithAccuracy([writes[2][@"x"] doubleValue], 0.525, 1e-9);
	XCTAssertEqualWithAccuracy([writes[2][@"y"] doubleValue], 0.45, 1e-9);
}

/*! @abstract Option-Shift resizes a box corner about the fixed center while holding the aspect ratio from the dominant axis. */
- (void)testOptionShiftLocksABoxCornerResizeToTheAspectRatioAboutTheCenter
{
	// The box is 80 x 40 (2:1) at 90°.
	[self stageBoxWithAngle:M_PI_2];
	[self.control addPart:[FxGripOSCBoxCornerPart partWithID:31
													  corner:FxGripOSCRectCornerUpperRight
										   centerParameterID:81
											widthParameterID:82
										   heightParameterID:83
											angleParameterID:84]];
	BOOL forceUpdate = NO;

	// The pointer resolves to local (50, 20); x dominates, so the lock scales both half sizes by
	// 1.25 about the fixed center, giving width 100 and the aspect-preserving height 50.
	FxModifierKeys optionShift = kFxModifierKey_OPTION | kFxModifierKey_SHIFT;
	[self.control mouseDownAtPositionX:40 positionY:90 activePart:31 modifiers:optionShift
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	[self.control mouseDraggedAtPositionX:60 positionY:100 activePart:31 modifiers:optionShift
							  forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];

	NSArray<NSDictionary *> *writes = self.manager.paramSetAPIv5.writes;
	XCTAssertEqual(writes.count, (NSUInteger)2, @"Option holds the center: only width and height move");
	XCTAssertEqualObjects(writes[0][@"parameter"], @82);
	XCTAssertEqualWithAccuracy([writes[0][@"value"] doubleValue], 100.0, 1e-9);
	XCTAssertEqualObjects(writes[1][@"parameter"], @83);
	XCTAssertEqualWithAccuracy([writes[1][@"value"] doubleValue], 50.0, 1e-9,
							   @"the height follows the dominant x to hold 2:1");
}

/*! @abstract The box composite composes the body, four corners numbered LL, LR, UR, UL, and a rotation dial. */
- (void)testTheBoxCompositeComposesBodyCornersAndDial
{
	[self stageBoxWithAngle:M_PI_2];
	[self.control addParts:[FxGripOSCBoxPart boxPartsWithBodyID:30
												  firstCornerID:31
											   rotationHandleID:35
											  centerParameterID:81
											   widthParameterID:82
											  heightParameterID:83
											   angleParameterID:84]];

	XCTAssertEqual(self.control.parts.count, (NSUInteger)6);
	XCTAssertEqual([self hitTestAtCanvasX:50 y:50], (NSInteger)30);
	// The probe stays clear of the dial tip at (50, 90), which out-prioritizes the
	// corner within its own radius.
	XCTAssertEqual([self hitTestAtCanvasX:38 y:90], (NSInteger)33,
				   @"corners number from firstCornerID in LL, LR, UR, UL order");
	XCTAssertEqual([self hitTestAtCanvasX:50 y:92], (NSInteger)35,
				   @"the rotation dial's tip rides the angle at its spoke radius");
}

#pragma mark Rectangle angle overlay

/*! The 0.3-0.7 square on parameters 11/12 with the angle on 14. */
- (void)stageOverlayRectWithAngle:(double)angleValue
{
	[self stagePoint:NSMakePoint(0.3, 0.3) forParameter:11];
	[self stagePoint:NSMakePoint(0.7, 0.7) forParameter:12];
	self.manager.paramGetAPIv6.floats[@14] = @(angleValue);
}

/*! @abstract A rect part with a linked angle hits inside its rotated frame. */
- (void)testARotatedRectHitsInItsRotatedFrame
{
	[self stageOverlayRectWithAngle:M_PI_2];
	FxGripOSCRectPart *body = [FxGripOSCRectPart partWithID:1
									   lowerLeftParameterID:11
									  upperRightParameterID:12];
	body.angleParameterID = 14;
	[self.control addPart:body];

	// Pre-rotation the box spans 80 x 40 input pixels; rotated 90 degrees it spans
	// 40 x 80, reaching canvas y 85 but no longer canvas x 65.
	XCTAssertEqual([self hitTestAtCanvasX:50 y:85], (NSInteger)1);
	XCTAssertEqual([self hitTestAtCanvasX:65 y:50], (NSInteger)0);
}

/*! @abstract A rect corner with a linked angle hits at the rotated position of the corner. */
- (void)testARotatedRectCornerSitsOnTheRotatedCorner
{
	[self stageOverlayRectWithAngle:M_PI_2];
	FxGripOSCRectCornerPart *corner = [FxGripOSCRectCornerPart partWithID:13
																   corner:FxGripOSCRectCornerLowerRight
													 lowerLeftParameterID:11
													upperRightParameterID:12];
	corner.angleParameterID = 14;
	[self.control addPart:corner];

	// The pre-rotation lower-right corner (0.7, 0.3) rotates to canvas (60, 90).
	XCTAssertEqual([self hitTestAtCanvasX:62 y:90], (NSInteger)13);
	XCTAssertEqual([self hitTestAtCanvasX:60 y:20], (NSInteger)0,
				   @"the unrotated corner position is no longer the handle");
}

/*! @abstract Dragging a rotated rect corner unrotates the pointer into pre-rotation space before writing the corner parameters. */
- (void)testDraggingARotatedCornerWritesPreRotationComponents
{
	[self stageOverlayRectWithAngle:M_PI_2];
	FxGripOSCRectCornerPart *corner = [FxGripOSCRectCornerPart partWithID:13
																   corner:FxGripOSCRectCornerLowerRight
													 lowerLeftParameterID:11
													upperRightParameterID:12];
	corner.angleParameterID = 14;
	[self.control addPart:corner];
	BOOL forceUpdate = NO;

	[self.control mouseDownAtPositionX:60 positionY:90 activePart:13 modifiers:0
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	[self.control mouseDraggedAtPositionX:55 positionY:95 activePart:13 modifiers:0
							  forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];

	XCTAssertTrue(forceUpdate);
	NSArray<NSDictionary *> *writes = self.manager.paramSetAPIv5.writes;
	XCTAssertEqual(writes.count, (NSUInteger)2);
	XCTAssertEqualObjects(writes[0][@"parameter"], @11);
	XCTAssertEqualWithAccuracy([writes[0][@"y"] doubleValue], 0.4, 1e-9,
							   @"the pointer unrotates into pre-rotation space before the write");
	XCTAssertEqualObjects(writes[1][@"parameter"], @12);
	XCTAssertEqualWithAccuracy([writes[1][@"x"] doubleValue], 0.725, 1e-9);
}

/*! @abstract The rotated rect composite adds a rotation spoke that writes the pointer angle around the midpoint. */
- (void)testTheRotatedRectCompositeAddsTheRotationSpoke
{
	[self stageOverlayRectWithAngle:M_PI_2];
	[self.control addParts:[FxGripOSCRectPart rectPartsWithBodyID:1
													firstCornerID:2
												 rotationHandleID:6
											 lowerLeftParameterID:11
											upperRightParameterID:12
												 angleParameterID:14]];
	XCTAssertEqual(self.control.parts.count, (NSUInteger)6);
	XCTAssertEqual([self hitTestAtCanvasX:50 y:92], (NSInteger)6);

	BOOL forceUpdate = NO;
	[self.control mouseDownAtPositionX:50 positionY:90 activePart:6 modifiers:0
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	[self.control mouseDraggedAtPositionX:90 positionY:50 activePart:6 modifiers:0
							  forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];

	XCTAssertTrue(forceUpdate);
	NSDictionary *write = self.manager.paramSetAPIv5.writes.lastObject;
	XCTAssertEqualObjects(write[@"parameter"], @14);
	XCTAssertEqualWithAccuracy([write[@"value"] doubleValue], 0.0, 1e-9,
							   @"the pointer due right of the midpoint is angle 0");
}

/*! @abstract Shift snaps the rect rotation handle to the nearest forty-five degrees. */
- (void)testShiftSnapsTheRectRotationHandleToFortyFiveDegrees
{
	[self stageOverlayRectWithAngle:M_PI_2];
	[self.control addPart:[FxGripOSCRectRotationHandlePart partWithID:6
												lowerLeftParameterID:11
											   upperRightParameterID:12
													angleParameterID:14]];
	BOOL forceUpdate = NO;

	// Canvas (80, 70) is 33.7° around the midpoint (50, 50); Shift snaps it to 45°.
	[self.control mouseDownAtPositionX:50 positionY:90 activePart:6 modifiers:kFxModifierKey_SHIFT
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	[self.control mouseDraggedAtPositionX:80 positionY:70 activePart:6 modifiers:kFxModifierKey_SHIFT
							  forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];

	NSDictionary *write = self.manager.paramSetAPIv5.writes.lastObject;
	XCTAssertEqualObjects(write[@"parameter"], @14);
	XCTAssertEqualWithAccuracy([write[@"value"] doubleValue], M_PI_4, 1e-9,
							   @"Shift snaps the rectangle's rotation to the nearest 45 degrees");
}

#pragma mark Flag composition

/*! @abstract The flag-form circle composition includes only the requested parts and numbers them consecutively. */
- (void)testFlagCompositionNumbersOnlyTheIncludedParts
{
	NSArray<FxGripOSCPart *> *all =
		[FxGripOSCCirclePart circlePartsWithOptions:FxGripOSCShapeOptionsAll
										firstPartID:40
								  centerParameterID:31
								  radiusParameterID:32
								   angleParameterID:33];
	XCTAssertEqual(all.count, (NSUInteger)3);
	XCTAssertEqual(all[0].partID, (NSInteger)40);
	XCTAssertTrue([all[0] isKindOfClass:FxGripOSCCirclePart.class]);
	XCTAssertEqual(all[1].partID, (NSInteger)41);
	XCTAssertTrue([all[1] isKindOfClass:FxGripOSCCircleRadiusHandlePart.class]);
	XCTAssertEqual(all[2].partID, (NSInteger)42);
	XCTAssertTrue([all[2] isKindOfClass:FxGripOSCRotationHandlePart.class]);

	NSArray<FxGripOSCPart *> *noRadius =
		[FxGripOSCCirclePart circlePartsWithOptions:(FxGripOSCShapeOptionBody | FxGripOSCShapeOptionRotationHandle)
										firstPartID:40
								  centerParameterID:31
								  radiusParameterID:32
								   angleParameterID:33];
	XCTAssertEqual(noRadius.count, (NSUInteger)2);
	XCTAssertTrue([noRadius[1] isKindOfClass:FxGripOSCRotationHandlePart.class]);
	XCTAssertEqual(noRadius[1].partID, (NSInteger)41,
				   @"numbering counts only the included parts");
}

/*! @abstract The flag-form box composition omits the rotation dial when no angle parameter is given. */
- (void)testFlagCompositionOmitsRotationWithoutAnAngleParameter
{
	NSArray<FxGripOSCPart *> *parts =
		[FxGripOSCBoxPart boxPartsWithOptions:FxGripOSCShapeOptionsAll
								  firstPartID:30
							centerParameterID:81
							 widthParameterID:82
							heightParameterID:83
							 angleParameterID:0];
	XCTAssertEqual(parts.count, (NSUInteger)5,
				   @"the body and four corners, with no dial to write a missing angle");
	XCTAssertTrue([parts.lastObject isKindOfClass:FxGripOSCBoxCornerPart.class]);
}

/*! @abstract The flag-form rect composition stamps the angle parameter onto the body and corners and adds a rotation handle. */
- (void)testTheRectFlagFormStampsTheAngleOverlay
{
	NSArray<FxGripOSCPart *> *parts =
		[FxGripOSCRectPart rectPartsWithOptions:FxGripOSCShapeOptionsAll
									firstPartID:1
						   lowerLeftParameterID:11
						  upperRightParameterID:12
							   angleParameterID:14];
	XCTAssertEqual(parts.count, (NSUInteger)6);
	XCTAssertEqual(((FxGripOSCRectPart *)parts[0]).angleParameterID, (FxParameterId)14);
	XCTAssertEqual(((FxGripOSCRectCornerPart *)parts[1]).angleParameterID, (FxParameterId)14);
	XCTAssertTrue([parts.lastObject isKindOfClass:FxGripOSCRectRotationHandlePart.class]);
}

/*! @abstract The flag-form line and polyline compositions add vertex handles only when requested. */
- (void)testTheLineAndPolylineFlagFormsComposeVertexHandles
{
	NSArray<FxGripOSCPart *> *line =
		[FxGripOSCLinePart linePartsWithOptions:(FxGripOSCShapeOptionBody | FxGripOSCShapeOptionVertexHandles)
									firstPartID:5
							   startParameterID:51
								 endParameterID:52];
	XCTAssertEqual(line.count, (NSUInteger)3);
	XCTAssertEqual(line[2].partID, (NSInteger)7);

	NSArray<FxGripOSCPart *> *bodyOnly =
		[FxGripOSCPolylinePart polylinePartsWithOptions:FxGripOSCShapeOptionBody
											firstPartID:20
									  pointParameterIDs:@[@71, @72, @73]
												 closed:YES];
	XCTAssertEqual(bodyOnly.count, (NSUInteger)1);
	XCTAssertTrue([bodyOnly[0] isKindOfClass:FxGripOSCPolylinePart.class]);
}

#pragma mark Keys

/*! @abstract Key-down and key-up events default to unhandled. */
- (void)testKeyEventsDefaultToUnhandled
{
	BOOL forceUpdate = NO;
	BOOL didHandle = YES;
	[self.control keyDownAtPositionX:0 positionY:0 keyPressed:'a' modifiers:0
						 forceUpdate:&forceUpdate didHandle:&didHandle atTime:FxGripOSCTestTime()];
	XCTAssertFalse(didHandle);

	didHandle = YES;
	[self.control keyUpAtPositionX:0 positionY:0 keyPressed:'a' modifiers:0
					   forceUpdate:&forceUpdate didHandle:&didHandle atTime:FxGripOSCTestTime()];
	XCTAssertFalse(didHandle);
}

#pragma mark Cursor

// The test bundle does not link AppKit, so the cursor singletons are reached by runtime name.
- (id)cursor:(SEL)selector
{
	Class cls = NSClassFromString(@"NSCursor");
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
	return [cls performSelector:selector];
#pragma clang diagnostic pop
}

/*! @abstract A mouse move over a part applies that part's cursor and forces no re-render. */
- (void)testMouseMovedAppliesTheHoveredPartCursor
{
	id crosshair = [self cursor:@selector(crosshairCursor)];
	FxGripOSCRectPart *part = [self stagedRectPartWithID:5];
	part.cursor = crosshair;

	BOOL forceUpdate = YES;
	[self.control mouseMovedAtPositionX:0 positionY:0 activePart:5 modifiers:0
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];

	XCTAssertEqualObjects(self.manager.onScreenControlAPIv4.lastCursor, crosshair);
	XCTAssertFalse(forceUpdate, @"a hover does not force a re-render");
}

/*! @abstract A mouse move over no part applies the arrow cursor. */
- (void)testMouseMovedOverNoPartUsesTheArrow
{
	[self stagedRectPartWithID:5];

	BOOL forceUpdate = NO;
	[self.control mouseMovedAtPositionX:0 positionY:0 activePart:0 modifiers:0
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];

	XCTAssertEqualObjects(self.manager.onScreenControlAPIv4.lastCursor, [self cursor:@selector(arrowCursor)]);
}

/*! @abstract A hovered part with no cursor set falls back to the arrow cursor. */
- (void)testAPartWithoutACursorFallsBackToTheArrow
{
	[self stagedRectPartWithID:5];   // no cursor set on the part

	BOOL forceUpdate = NO;
	[self.control mouseMovedAtPositionX:0 positionY:0 activePart:5 modifiers:0
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];

	XCTAssertEqualObjects(self.manager.onScreenControlAPIv4.lastCursor, [self cursor:@selector(arrowCursor)]);
}

/*! @abstract Mouse exit restores the arrow cursor after a part cursor was applied. */
- (void)testMouseExitedRestoresTheArrow
{
	id crosshair = [self cursor:@selector(crosshairCursor)];
	FxGripOSCRectPart *part = [self stagedRectPartWithID:5];
	part.cursor = crosshair;

	BOOL forceUpdate = NO;
	[self.control mouseMovedAtPositionX:0 positionY:0 activePart:5 modifiers:0
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	XCTAssertEqualObjects(self.manager.onScreenControlAPIv4.lastCursor, crosshair);

	[self.control mouseExitedAtPositionX:0 positionY:0 modifiers:0
							 forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	XCTAssertEqualObjects(self.manager.onScreenControlAPIv4.lastCursor, [self cursor:@selector(arrowCursor)]);
}

#pragma mark Curve display part

/*! @abstract The curve part constructor sets its ID, point parameters, closed flag, and default shadow properties. */
- (void)testTheCurvePartConstructorSetsItsProperties
{
	FxGripOSCCurvePart *curve = [FxGripOSCCurvePart partWithID:7 pointParameterIDs:@[@1, @2, @3] closed:YES];

	XCTAssertEqual(curve.partID, (NSInteger)7);
	XCTAssertEqualObjects(curve.pointParameterIDs, (@[@1, @2, @3]));
	XCTAssertTrue(curve.closed);
	XCTAssertTrue(curve.castsShadow, @"a curve casts the inherited drop shadow by default");
	XCTAssertEqual(curve.shadowDistance, 1.0);
	XCTAssertEqual(curve.shadowBlur, 0.0);
}

/*! @abstract A curve part answers no hit and ignores drags. */
- (void)testACurvePartIsDisplayOnly
{
	[self stagePoint:NSMakePoint(0.2, 0.2) forParameter:11];
	[self stagePoint:NSMakePoint(0.6, 0.6) forParameter:12];
	FxGripOSCCurvePart *curve = [FxGripOSCCurvePart partWithID:9 pointParameterIDs:@[@11, @12] closed:NO];
	[self.control addPart:curve];

	// A display-only part answers no hit wherever it is drawn and ignores drags.
	XCTAssertEqual([self hitTestAtCanvasX:40 y:40], (NSInteger)0);
	XCTAssertEqual([self hitTestAtCanvasX:20 y:20], (NSInteger)0);
	XCTAssertFalse([curve dragToObjectPoint:CGPointMake(0.5, 0.5)
								objectDelta:CGPointMake(0.1, 0.1)
								  modifiers:0
									 atTime:FxGripOSCTestTime()]);
}

/*! @abstract The HUD text constructor sets the text and the default anchor, font size, and colors. */
- (void)testTheHUDPartTextConstructorSetsItsProperties
{
	FxGripOSCHUDPart *hud = [FxGripOSCHUDPart partWithID:5 text:@"120%"];

	XCTAssertEqual(hud.partID, (NSInteger)5);
	XCTAssertEqualObjects(hud.text, @"120%");
	XCTAssertNil(hud.textBlock);
	XCTAssertEqual(hud.anchorParameterID, (FxParameterId)0);
	XCTAssertEqual(hud.fontSize, 12.0);
	XCTAssertEqual(hud.canvasAnchor.x, 20.0);
	XCTAssertEqual(hud.canvasAnchor.y, 20.0);
	XCTAssertEqual(hud.textColor.x, 1.0f, @"text defaults to the outline color");
	XCTAssertEqualWithAccuracy(hud.backgroundColor.w, 0.6f, 1e-6, @"a translucent panel by default");
}

/*! @abstract The HUD block constructor stores the text block. */
- (void)testTheHUDPartBlockConstructorStoresItsBlock
{
	FxGripOSCHUDPart *hud = [FxGripOSCHUDPart partWithID:6 textBlock:^NSString *(CMTime time) {
		return @"frame";
	}];

	XCTAssertEqual(hud.partID, (NSInteger)6);
	XCTAssertNotNil(hud.textBlock);
}

/*! @abstract A HUD part answers no hit and ignores drags. */
- (void)testAHUDPartIsDisplayOnly
{
	FxGripOSCHUDPart *hud = [FxGripOSCHUDPart partWithID:8 text:@"readout"];
	[self.control addPart:hud];

	XCTAssertEqual([self hitTestAtCanvasX:20 y:20], (NSInteger)0);
	XCTAssertEqual([self hitTestAtCanvasX:40 y:30], (NSInteger)0);
	XCTAssertFalse([hud dragToObjectPoint:CGPointMake(0.5, 0.5)
							  objectDelta:CGPointMake(0.1, 0.1)
								modifiers:0
								   atTime:FxGripOSCTestTime()]);
}

#pragma mark Correctness fixes

/*! @abstract A rectangle whose corners are inverted still hits any point inside its span. */
- (void)testAnInvertedRectPartStillHitsInsideItsSpan
{
	// Corners dragged past each other invert the rectangle; a hit is still any point in the span.
	[self stagePoint:NSMakePoint(0.6, 0.6) forParameter:11];
	[self stagePoint:NSMakePoint(0.2, 0.2) forParameter:12];
	[self.control addPart:[FxGripOSCRectPart partWithID:1 lowerLeftParameterID:11 upperRightParameterID:12]];

	XCTAssertEqual([self hitTestAtCanvasX:40 y:40], (NSInteger)1, @"inside the inverted rect's span");
	XCTAssertEqual([self hitTestAtCanvasX:80 y:40], (NSInteger)0, @"outside the span misses");
}

/*! @abstract The box composite omits the rotation dial when no angle parameter is given. */
- (void)testTheBoxCompositeOmitsTheDialWithoutAnAngleParameter
{
	NSArray<FxGripOSCPart *> *parts = [FxGripOSCBoxPart boxPartsWithBodyID:30
														   firstCornerID:31
														rotationHandleID:35
													   centerParameterID:81
														widthParameterID:82
													   heightParameterID:83
														angleParameterID:0];
	XCTAssertEqual(parts.count, (NSUInteger)5, @"body plus four corners, no dead dial");
	for (FxGripOSCPart *part in parts) {
		XCTAssertFalse([part isKindOfClass:FxGripOSCAngleDialPart.class]);
	}
}

#pragma mark Shadow appearance

/*! @abstract A part casts the standard shadow by default, with the standard distance, blur, and shadow color alpha. */
- (void)testAPartCastsTheStandardShadowByDefault
{
	FxGripOSCPart *part = [[FxGripOSCPart alloc] initWithPartID:1];
	XCTAssertEqual(part.shadowDistance, 1.0);
	XCTAssertEqual(part.shadowBlur, 0.0);
	XCTAssertEqual(part.shadowColor.w, kFxGripOSCShadowColor.w);
	XCTAssertTrue(part.castsShadow);
}

/*! @abstract A part with a zero shadow alpha, or with no offset and no blur, casts no shadow. */
- (void)testAPartWithNoShadowAlphaOrOffsetDoesNotCastAShadow
{
	FxGripOSCPart *transparent = [[FxGripOSCPart alloc] initWithPartID:1];
	transparent.shadowColor = (simd_float4){ 0.0, 0.0, 0.0, 0.0 };
	XCTAssertFalse(transparent.castsShadow, @"a zero shadow alpha casts nothing");

	FxGripOSCPart *flat = [[FxGripOSCPart alloc] initWithPartID:2];
	flat.shadowDistance = 0.0;
	flat.shadowBlur = 0.0;
	XCTAssertFalse(flat.castsShadow, @"no offset and no blur casts nothing");
}

/*! @abstract Shadow blur grouping returns one ascending pass per distinct radius and skips non-casters. */
- (void)testShadowBlurGroupingIsDistinctSortedAndSkipsNonCasters
{
	FxGripOSCPart *a = [[FxGripOSCPart alloc] initWithPartID:1];   // blur 0
	FxGripOSCPart *b = [[FxGripOSCPart alloc] initWithPartID:2];
	b.shadowBlur = 3.0;
	FxGripOSCPart *c = [[FxGripOSCPart alloc] initWithPartID:3];
	c.shadowBlur = 3.0;   // shares b's radius
	FxGripOSCPart *d = [[FxGripOSCPart alloc] initWithPartID:4];
	d.shadowColor = (simd_float4){ 0.0, 0.0, 0.0, 0.0 };   // casts nothing

	NSArray<NSNumber *> *radii = [FxGripOnScreenControl fxShadowBlurRadiiForParts:@[a, b, c, d]];
	XCTAssertEqualObjects(radii, (@[@0.0, @3.0]), @"one pass per distinct radius, ascending, non-casters skipped");
}


#pragma mark Host API absence

/*! @abstract The coordinate conversions are the identity when the host publishes no OSC API. */
- (void)testTheCoordinateConversionsAreTheIdentityWithoutTheOSCAPI
{
	self.manager.onScreenControlAPIv4 = nil;
	CGPoint object = [self.control objectPointFromCanvasPoint:CGPointMake(3.0, 4.0)];
	CGPoint canvas = [self.control canvasPointFromObjectPoint:CGPointMake(5.0, 6.0)];
	XCTAssertEqual(object.x, 3.0);
	XCTAssertEqual(object.y, 4.0);
	XCTAssertEqual(canvas.x, 5.0);
	XCTAssertEqual(canvas.y, 6.0);
}

/*! @abstract Every parameter accessor fails and leaves the caller's storage untouched without the host APIs. */
- (void)testTheParameterAccessorsFailWithoutTheHostAPIs
{
	self.manager.paramGetAPIv6 = nil;
	self.manager.paramSetAPIv5 = nil;
	CMTime time = FxGripOSCTestTime();
	CGPoint point = CGPointMake(9.0, 9.0);
	double value = 7.0;

	XCTAssertFalse([self.control getObjectPoint:&point fromParameter:11 atTime:time]);
	XCTAssertFalse([self.control setObjectPoint:CGPointZero toParameter:11 atTime:time]);
	XCTAssertFalse([self.control getFloatValue:&value fromParameter:11 atTime:time]);
	XCTAssertFalse([self.control setFloatValue:1.0 toParameter:11 atTime:time]);
	XCTAssertNil([self.control getCustomValueFromParameter:11 atTime:time]);
	XCTAssertFalse([self.control setCustomValue:@"payload" toParameter:11 atTime:time]);
	XCTAssertEqual(point.x, 9.0, @"a failed read leaves the caller's point untouched");
	XCTAssertEqual(value, 7.0, @"a failed read leaves the caller's value untouched");
}

/*! @abstract A custom read the host declines returns nil, and a successful one returns the staged object. */
- (void)testTheCustomParameterReadReturnsNilWhenTheHostDeclines
{
	CMTime time = FxGripOSCTestTime();
	XCTAssertNil([self.control getCustomValueFromParameter:44 atTime:time], @"nothing is staged");
	self.manager.paramGetAPIv6.customs[@(44)] = @"payload";
	XCTAssertEqualObjects([self.control getCustomValueFromParameter:44 atTime:time], @"payload");
	XCTAssertTrue([self.control setCustomValue:@"replaced" toParameter:44 atTime:time]);
	XCTAssertEqualObjects(self.manager.paramGetAPIv6.customs[@(44)], @"replaced");
}

/*! @abstract Applying a cursor without the host OSC API is a no-op rather than a crash. */
- (void)testTheCursorIsNotAppliedWithoutTheOSCAPI
{
	FxGripOSCTestOSCAPI *oscAPI = self.manager.onScreenControlAPIv4;
	self.manager.onScreenControlAPIv4 = nil;
	BOOL forceUpdate = YES;
	[self.control mouseMovedAtPositionX:10 positionY:10 activePart:0 modifiers:0
							forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	XCTAssertFalse(forceUpdate);
	XCTAssertEqual(oscAPI.setCursorCount, (NSUInteger)0, @"no API means no cursor call");
}

#pragma mark Part list and routing

/*! @abstract The parts property is a snapshot that later additions do not change. */
- (void)testThePartsPropertyIsASnapshotOfTheCurrentList
{
	[self.control addPart:[[FxGripOSCPart alloc] initWithPartID:1]];
	NSArray<FxGripOSCPart *> *snapshot = self.control.parts;
	[self.control addPart:[[FxGripOSCPart alloc] initWithPartID:2]];

	XCTAssertEqual(snapshot.count, (NSUInteger)1);
	XCTAssertEqual(self.control.parts.count, (NSUInteger)2);
	XCTAssertFalse(snapshot == self.control.parts, @"each read is a fresh copy");
}

/*! @abstract Adding a nil part leaves the list unchanged. */
- (void)testAddingANilPartIsIgnored
{
	[self.control addPart:(FxGripOSCPart * _Nonnull)nil];
	XCTAssertEqual(self.control.parts.count, (NSUInteger)0);
}

/*! @abstract A drag naming a part number no part owns writes nothing and asks for no update. */
- (void)testADragOnAnUnknownPartNumberWritesNothing
{
	[self stagedRectPartWithID:1];
	BOOL forceUpdate = YES;
	[self.control mouseDownAtPositionX:40 positionY:40 activePart:999 modifiers:0
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	[self.control mouseDraggedAtPositionX:50 positionY:60 activePart:999
								modifiers:(kFxModifierKey_OPTION | kFxModifierKey_SHIFT)
							  forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];

	XCTAssertFalse(forceUpdate);
	XCTAssertEqual(self.manager.paramSetAPIv5.writes.count, (NSUInteger)0);
}

/*! @abstract A key press a part claims is reported handled and forces an update. */
- (void)testAKeyPressAPartClaimsIsReportedHandled
{
	FxGripOSCTestRecordingPart *part = [[FxGripOSCTestRecordingPart alloc] initWithPartID:5];
	part.claimsKey = YES;
	[self.control addPart:part];

	BOOL forceUpdate = NO, didHandle = NO;
	[self.control keyDownAtPositionX:0 positionY:0 keyPressed:127 modifiers:0
						 forceUpdate:&forceUpdate didHandle:&didHandle atTime:FxGripOSCTestTime()];

	XCTAssertTrue(didHandle);
	XCTAssertTrue(forceUpdate);
	XCTAssertEqual(part.keyDownCount, (NSUInteger)1);
	XCTAssertEqual(part.lastKey, (unsigned short)127);
}

/*! @abstract Entering the control asks for no update and touches no cursor. */
- (void)testMouseEnteredAsksForNoUpdate
{
	BOOL forceUpdate = YES;
	[self.control mouseEnteredAtPositionX:5 positionY:5 modifiers:0
							  forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	XCTAssertFalse(forceUpdate);
	XCTAssertEqual(self.manager.onScreenControlAPIv4.setCursorCount, (NSUInteger)0);
}

#pragma mark Mouse-down routing and double-click synthesis

/*! @abstract A mouse-down forwards the canvas point to the active part and reports its update request. */
- (void)testAMouseDownForwardsTheClickToTheActivePart
{
	FxGripOSCTestRecordingPart *part = [[FxGripOSCTestRecordingPart alloc] initWithPartID:7];
	part.claimsMouseDown = YES;
	[self.control addPart:part];

	BOOL forceUpdate = NO;
	[self.control mouseDownAtPositionX:31 positionY:44 activePart:7 modifiers:0
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];

	XCTAssertTrue(forceUpdate);
	XCTAssertEqual(part.mouseDownCount, (NSUInteger)1);
	XCTAssertEqual(part.lastCanvasPoint.x, 31.0);
	XCTAssertEqual(part.lastCanvasPoint.y, 44.0);
}

/*! @abstract A mouse-down with no active part, or on a part number no part owns, is not forwarded. */
- (void)testAMouseDownWithoutAMatchingPartIsNotForwarded
{
	FxGripOSCTestRecordingPart *part = [[FxGripOSCTestRecordingPart alloc] initWithPartID:7];
	[self.control addPart:part];

	BOOL forceUpdate = YES;
	[self.control mouseDownAtPositionX:31 positionY:44 activePart:0 modifiers:0
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	XCTAssertFalse(forceUpdate);
	[self.control mouseDownAtPositionX:31 positionY:44 activePart:99 modifiers:0
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	XCTAssertFalse(forceUpdate);
	XCTAssertEqual(part.mouseDownCount, (NSUInteger)0);
}

/*! @abstract A prompt second click on the same part at the same place arrives as a double-click. */
- (void)testASecondClickOnTheSamePartArrivesAsADoubleClick
{
	FxGripOSCTestRecordingPart *part = [[FxGripOSCTestRecordingPart alloc] initWithPartID:7];
	part.claimsDoubleClick = YES;
	[self.control addPart:part];
	BOOL forceUpdate = NO;

	[self.control mouseDownAtPositionX:30 positionY:30 activePart:7 modifiers:0
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	XCTAssertEqual(part.doubleClickCount, (NSUInteger)0, @"the first click is a plain click");

	[self.control mouseDownAtPositionX:31 positionY:30 activePart:7 modifiers:0
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	XCTAssertEqual(part.doubleClickCount, (NSUInteger)1);
	XCTAssertEqual(part.mouseDownCount, (NSUInteger)1, @"the double-click replaces the click");
	XCTAssertTrue(forceUpdate);

	[self.control mouseDownAtPositionX:31 positionY:30 activePart:7 modifiers:0
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	XCTAssertEqual(part.doubleClickCount, (NSUInteger)1, @"the consumed click does not seed a third");
	XCTAssertEqual(part.mouseDownCount, (NSUInteger)2);
}

/*! @abstract A second click beyond the double-click slop is a plain click. */
- (void)testASecondClickBeyondTheSlopIsAPlainClick
{
	FxGripOSCTestRecordingPart *part = [[FxGripOSCTestRecordingPart alloc] initWithPartID:7];
	part.claimsDoubleClick = YES;
	[self.control addPart:part];
	BOOL forceUpdate = NO;

	[self.control mouseDownAtPositionX:30 positionY:30 activePart:7 modifiers:0
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	[self.control mouseDownAtPositionX:60 positionY:30 activePart:7 modifiers:0
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];

	XCTAssertEqual(part.doubleClickCount, (NSUInteger)0);
	XCTAssertEqual(part.mouseDownCount, (NSUInteger)2);
}

/*! @abstract A part that declines a double-click still receives the click. */
- (void)testAPartDecliningADoubleClickStillReceivesTheClick
{
	FxGripOSCTestRecordingPart *part = [[FxGripOSCTestRecordingPart alloc] initWithPartID:7];
	part.claimsDoubleClick = NO;
	[self.control addPart:part];
	BOOL forceUpdate = NO;

	[self.control mouseDownAtPositionX:30 positionY:30 activePart:7 modifiers:0
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	[self.control mouseDownAtPositionX:30 positionY:30 activePart:7 modifiers:0
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];

	XCTAssertEqual(part.doubleClickCount, (NSUInteger)1, @"the part was asked");
	XCTAssertEqual(part.mouseDownCount, (NSUInteger)2, @"and the click was delivered anyway");
}

/*! @abstract A click on empty space clears the double-click tracking, so the next pair starts over. */
- (void)testAClickOnEmptySpaceClearsTheDoubleClickTracking
{
	FxGripOSCTestRecordingPart *part = [[FxGripOSCTestRecordingPart alloc] initWithPartID:7];
	part.claimsDoubleClick = YES;
	[self.control addPart:part];
	BOOL forceUpdate = NO;

	[self.control mouseDownAtPositionX:30 positionY:30 activePart:7 modifiers:0
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	[self.control mouseDownAtPositionX:30 positionY:30 activePart:0 modifiers:0
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	[self.control mouseDownAtPositionX:30 positionY:30 activePart:7 modifiers:0
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];

	XCTAssertEqual(part.doubleClickCount, (NSUInteger)0);
	XCTAssertEqual(part.mouseDownCount, (NSUInteger)2);
}

#pragma mark Part base defaults

/*! @abstract The part base answers no hit, ignores drags, keys, and double-clicks, and draws nothing. */
- (void)testThePartBaseAnswersNothingAndDrawsNothing
{
	FxGripOSCPart *part = [[FxGripOSCPart alloc] initWithPartID:3];
	[self.control addPart:part];
	CMTime time = FxGripOSCTestTime();

	XCTAssertEqual(part.partID, (NSInteger)3);
	XCTAssertTrue(part.control == self.control);
	XCTAssertFalse([part hitTestObjectPoint:CGPointZero canvasPoint:CGPointZero atTime:time]);
	XCTAssertFalse([part dragToObjectPoint:CGPointZero objectDelta:CGPointZero modifiers:0 atTime:time]);
	XCTAssertFalse([part mouseDownAtObjectPoint:CGPointZero canvasPoint:CGPointZero modifiers:0 atTime:time]);
	XCTAssertFalse([part mouseDoubleClickAtObjectPoint:CGPointZero canvasPoint:CGPointZero modifiers:0 atTime:time]);
	XCTAssertFalse([part keyDownWithKey:127 modifiers:0 atTime:time]);
	XCTAssertFalse([part handlesOptionDrag]);
	XCTAssertFalse([part handlesConstrainDrag]);
	XCTAssertNoThrow([part drawSelected:YES
							 canvasSize:CGSizeMake(10.0, 10.0)
						 commandEncoder:(id<MTLRenderCommandEncoder> _Nonnull)nil
								 atTime:time]);
}

#pragma mark Metal draw kit

/*! Binds `name` to a live render pass, or skips the test when the machine has no Metal device. */
#define FxGripOSCBeginPass(name, canvasSizeValue) \
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

/*! The opaque white the draw-kit tests stroke and fill with. */
static simd_float4 FxGripOSCTestOpaqueWhite(void)
{
	return (simd_float4){ 1.0f, 1.0f, 1.0f, 1.0f };
}

/*! @abstract A filled quad writes its color across its span and leaves the rest of the canvas clear. */
- (void)testFillCanvasQuadWritesItsColorAcrossTheQuad
{
	FxGripOSCBeginPass(pass, CGSizeMake(80.0, 80.0));
	[self.control fillCanvasQuadLL:CGPointMake(20.0, 20.0)
								lr:CGPointMake(40.0, 20.0)
								ur:CGPointMake(40.0, 40.0)
								ul:CGPointMake(20.0, 40.0)
							 color:(simd_float4){ 1.0f, 0.0f, 0.0f, 1.0f }
						canvasSize:pass.canvasSize
					commandEncoder:pass.commandEncoder];
	[pass finish];

	simd_float4 inside = [pass colorAtCanvasPoint:CGPointMake(30.0, 30.0)];
	XCTAssertEqualWithAccuracy(inside.x, 1.0, 0.01, @"the red channel");
	XCTAssertEqualWithAccuracy(inside.y, 0.0, 0.01, @"the green channel");
	XCTAssertEqualWithAccuracy(inside.w, 1.0, 0.01, @"the alpha channel");
	XCTAssertEqualWithAccuracy([pass colorAtCanvasPoint:CGPointMake(60.0, 60.0)].w, 0.0, 0.01,
							   @"outside the quad stays clear");
}

/*! @abstract Encoding zero vertices draws nothing. */
- (void)testEncodingZeroVerticesDrawsNothing
{
	FxGripOSCBeginPass(pass, CGSizeMake(40.0, 40.0));
	FxGripOSCVertex vertex = { .position = { 0.0f, 0.0f } };
	[self.control encodeVertices:&vertex
						   count:0
					   primitive:MTLPrimitiveTypeTriangleStrip
						   color:FxGripOSCTestOpaqueWhite()
					  canvasSize:pass.canvasSize
				  commandEncoder:pass.commandEncoder];
	[pass finish];

	XCTAssertEqualWithAccuracy([pass colorAtCanvasPoint:CGPointMake(20.0, 20.0)].w, 0.0, 0.01);
}

/*! @abstract A closed stroke adds the segment back to the first point that an open stroke omits. */
- (void)testAClosedStrokeAddsTheSegmentBackToTheFirstPoint
{
	CGPoint square[4] = {
		CGPointMake(20.0, 20.0), CGPointMake(60.0, 20.0),
		CGPointMake(60.0, 60.0), CGPointMake(20.0, 60.0),
	};

	FxGripOSCBeginPass(closedPass, CGSizeMake(80.0, 80.0));
	[self.control strokeCanvasPoints:square count:4 closed:YES color:FxGripOSCTestOpaqueWhite()
						  withShadow:YES canvasSize:closedPass.canvasSize
					  commandEncoder:closedPass.commandEncoder];
	[closedPass finish];
	XCTAssertGreaterThan([self inkNear:CGPointMake(40.0, 20.0) inPass:closedPass], 0.5f, @"the first edge");
	XCTAssertGreaterThan([self inkNear:CGPointMake(20.0, 40.0) inPass:closedPass], 0.5f, @"the closing edge");
	XCTAssertEqualWithAccuracy([closedPass colorAtCanvasPoint:CGPointMake(40.0, 40.0)].w, 0.0, 0.01,
							   @"a stroke leaves the interior clear");

	FxGripOSCBeginPass(openPass, CGSizeMake(80.0, 80.0));
	[self.control strokeCanvasPoints:square count:4 closed:NO color:FxGripOSCTestOpaqueWhite()
						  withShadow:YES canvasSize:openPass.canvasSize
					  commandEncoder:openPass.commandEncoder];
	[openPass finish];
	XCTAssertGreaterThan([self inkNear:CGPointMake(40.0, 20.0) inPass:openPass], 0.5f, @"the first edge");
	XCTAssertEqualWithAccuracy([self inkNear:CGPointMake(20.0, 40.0) inPass:openPass], 0.0, 0.01,
							   @"an open stroke has no closing edge");
}

/*! @abstract A stroke of fewer than two points draws nothing. */
- (void)testAStrokeOfOnePointDrawsNothing
{
	FxGripOSCBeginPass(pass, CGSizeMake(40.0, 40.0));
	CGPoint single = CGPointMake(20.0, 20.0);
	[self.control strokeCanvasPoints:&single count:1 closed:YES color:FxGripOSCTestOpaqueWhite()
						  withShadow:YES canvasSize:pass.canvasSize commandEncoder:pass.commandEncoder];
	[pass finish];

	XCTAssertEqualWithAccuracy([self inkNear:CGPointMake(20.0, 20.0) inPass:pass], 0.0, 0.01);
}

/*! @abstract A triangle fan fills the polygon its rim spans and nothing beyond it. */
- (void)testTheTriangleFanFillsThePolygonItsRimSpans
{
	FxGripOSCBeginPass(pass, CGSizeMake(80.0, 80.0));
	CGPoint rim[4] = {
		CGPointMake(20.0, 20.0), CGPointMake(60.0, 20.0),
		CGPointMake(60.0, 60.0), CGPointMake(20.0, 60.0),
	};
	[self.control fillCanvasFanAroundCenter:CGPointMake(40.0, 40.0)
								  rimPoints:rim
									  count:4
									  color:FxGripOSCTestOpaqueWhite()
								 canvasSize:pass.canvasSize
							 commandEncoder:pass.commandEncoder];
	[pass finish];

	XCTAssertEqualWithAccuracy([pass colorAtCanvasPoint:CGPointMake(40.0, 40.0)].w, 1.0, 0.01, @"the center");
	XCTAssertEqualWithAccuracy([pass colorAtCanvasPoint:CGPointMake(25.0, 50.0)].w, 1.0, 0.01, @"near a rim edge");
	XCTAssertEqualWithAccuracy([pass colorAtCanvasPoint:CGPointMake(70.0, 70.0)].w, 0.0, 0.01, @"outside the rim");
}

/*! @abstract A fan of fewer than two rim points draws nothing. */
- (void)testAFanOfOneRimPointDrawsNothing
{
	FxGripOSCBeginPass(pass, CGSizeMake(40.0, 40.0));
	CGPoint rim = CGPointMake(30.0, 30.0);
	[self.control fillCanvasFanAroundCenter:CGPointMake(20.0, 20.0)
								  rimPoints:&rim
									  count:1
									  color:FxGripOSCTestOpaqueWhite()
								 canvasSize:pass.canvasSize
							 commandEncoder:pass.commandEncoder];
	[pass finish];

	XCTAssertEqualWithAccuracy([self inkNear:CGPointMake(25.0, 25.0) inPass:pass], 0.0, 0.01);
}

/*! @abstract A textured quad draws nothing without a texture, and nothing outside the control's own render pass. */
- (void)testATexturedQuadNeedsATextureAndTheControlsOwnRenderPass
{
	FxGripOSCBeginPass(pass, CGSizeMake(80.0, 80.0));
	id<MTLTexture> texture = [self.control textureForText:@"88"
												 fontSize:12.0
													color:FxGripOSCTestOpaqueWhite()
												   device:pass.device];
	XCTAssertNotNil(texture);

	[self.control encodeTexturedQuadLL:CGPointMake(10.0, 10.0)
									lr:CGPointMake(50.0, 10.0)
									ur:CGPointMake(50.0, 50.0)
									ul:CGPointMake(10.0, 50.0)
							   texture:(id<MTLTexture> _Nonnull)nil
								 color:FxGripOSCTestOpaqueWhite()
							canvasSize:pass.canvasSize
						commandEncoder:pass.commandEncoder];
	[self.control encodeTexturedQuadLL:CGPointMake(10.0, 10.0)
									lr:CGPointMake(50.0, 10.0)
									ur:CGPointMake(50.0, 50.0)
									ul:CGPointMake(10.0, 50.0)
							   texture:texture
								 color:FxGripOSCTestOpaqueWhite()
							canvasSize:pass.canvasSize
						commandEncoder:pass.commandEncoder];
	[pass finish];

	XCTAssertEqualWithAccuracy([pass colorAtCanvasPoint:CGPointMake(30.0, 30.0)].w, 0.0, 0.01,
							   @"the textured pipeline is bound only inside the control's draw pass");
}

/*! @abstract Text rasterizes to a texture that grows with the string, and an empty string produces none. */
- (void)testTextRasterizesToATextureSizedToTheString
{
	id<MTLDevice> device = FxGripOSCMetalTestPass.sharedDevice;
	if (device == nil) {
		XCTSkip(@"no Metal device is available");
	}
	id<MTLTexture> shortText = [self.control textureForText:@"8"
												   fontSize:12.0
													  color:FxGripOSCTestOpaqueWhite()
													 device:device];
	id<MTLTexture> longText = [self.control textureForText:@"88888888"
												  fontSize:12.0
													 color:FxGripOSCTestOpaqueWhite()
													device:device];

	XCTAssertNotNil(shortText);
	XCTAssertGreaterThan(shortText.height, (NSUInteger)0);
	XCTAssertGreaterThan(longText.width, shortText.width, @"a longer string needs a wider texture");
	XCTAssertNil([self.control textureForText:@""
									 fontSize:12.0
										color:FxGripOSCTestOpaqueWhite()
									   device:device],
				 @"an empty string rasterizes to nothing");
}

/*! @abstract The framework shader library is cached per device and carries the OSC entry points. */
- (void)testTheShaderLibraryIsCachedPerDevice
{
	id<MTLDevice> device = FxGripOSCMetalTestPass.sharedDevice;
	if (device == nil) {
		XCTSkip(@"no Metal device is available");
	}
	XCTAssertNil([self.control fxOSCLibraryForDevice:nil], @"no device means no library");

	id<MTLLibrary> first = [self.control fxOSCLibraryForDevice:device];
	XCTAssertNotNil(first);
	XCTAssertTrue([self.control fxOSCLibraryForDevice:device] == first,
				  @"a second call returns the identical cached library");

	FxGripOSCTestControl *other = [[FxGripOSCTestControl alloc] initWithAPIManager:(id _Nonnull)nil];
	XCTAssertTrue([other fxOSCLibraryForDevice:device] == first, @"the cache is keyed by device, not by control");
	XCTAssertNotNil([first newFunctionWithName:@"fxGripOSCVertexShader"]);
	XCTAssertNotNil([first newFunctionWithName:@"fxGripOSCTexturedFragmentShader"]);
}

#pragma mark The control's own drawing scaffold

/*! Waits for the control's committed command buffer to land in the tile, keyed on a point that takes ink. */
- (void)waitForTile:(FxImageTile *)tile inkAtCanvasPoint:(CGPoint)canvasPoint
{
	id<MTLTexture> texture = [tile metalTextureForDevice:FxGripOSCMetalTestPass.sharedDevice];
	NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:5.0];
	while ([FxGripOSCMetalTestPass colorInTexture:texture atCanvasPoint:canvasPoint].w == 0.0f
		   && deadline.timeIntervalSinceNow > 0.0) {
		[NSThread sleepForTimeInterval:0.001];
	}
}

/*! A part that fills a 24 px canvas quad at (20, 20), with no shadow. */
- (FxGripOSCBlockDrawPart *)quadPartWithID:(NSInteger)partID
{
	FxGripOSCBlockDrawPart *part = [[FxGripOSCBlockDrawPart alloc] initWithPartID:partID];
	part.shadowColor = (simd_float4){ 0.0f, 0.0f, 0.0f, 0.0f };
	part.drawBlock = ^(FxGripOSCBlockDrawPart *drawn, BOOL selected, CGSize canvasSize,
					   id<MTLRenderCommandEncoder> commandEncoder) {
		[drawn.control fillCanvasQuadLL:CGPointMake(20.0, 20.0)
									 lr:CGPointMake(44.0, 20.0)
									 ur:CGPointMake(44.0, 44.0)
									 ul:CGPointMake(20.0, 44.0)
								  color:FxGripOSCTestOpaqueWhite()
							 canvasSize:canvasSize
						 commandEncoder:commandEncoder];
	};
	return part;
}

/*! @abstract Drawing the control asks every part to draw once, with the tile's canvas size, and marks the active one selected. */
- (void)testDrawingTheControlDrawsEveryPartOnceAndSelectsTheActiveOne
{
	FxImageTile *tile = [FxGripOSCMetalTestPass destinationTileWithCanvasSize:CGSizeMake(64.0, 64.0)];
	if (tile == nil) {
		XCTSkip(@"no Metal device is available");
	}
	FxGripOSCBlockDrawPart *first = [self quadPartWithID:1];
	FxGripOSCBlockDrawPart *second = [self quadPartWithID:2];
	[self.control addParts:@[first, second]];

	[self.control drawOSCWithWidth:64 height:64 activePart:2 destinationImage:tile atTime:FxGripOSCTestTime()];

	XCTAssertEqual(first.drawCount, (NSUInteger)1, @"one foreground draw, no shadow pass");
	XCTAssertEqual(second.drawCount, (NSUInteger)1);
	XCTAssertEqual(first.selectedDrawCount, (NSUInteger)0);
	XCTAssertEqual(second.selectedDrawCount, (NSUInteger)1, @"the active part draws selected");
	XCTAssertTrue(CGSizeEqualToSize(first.lastCanvasSize, CGSizeMake(64.0, 64.0)));
	[self waitForTile:tile inkAtCanvasPoint:CGPointMake(30.0, 30.0)];
	XCTAssertGreaterThan([FxGripOSCMetalTestPass colorInTexture:[tile metalTextureForDevice:FxGripOSCMetalTestPass.sharedDevice]
												 atCanvasPoint:CGPointMake(30.0, 30.0)].w,
						 0.5f, @"the parts reached the destination tile");
}

/*! @abstract Each distinct shadow blur radius adds one more draw for the parts that share it. */
- (void)testEachDistinctShadowRadiusAddsOneDrawForItsOwnParts
{
	FxImageTile *tile = [FxGripOSCMetalTestPass destinationTileWithCanvasSize:CGSizeMake(64.0, 64.0)];
	if (tile == nil) {
		XCTSkip(@"no Metal device is available");
	}
	FxGripOSCBlockDrawPart *crisp = [self quadPartWithID:1];
	FxGripOSCBlockDrawPart *sharpShadow = [self quadPartWithID:2];
	sharpShadow.shadowColor = kFxGripOSCShadowColor;
	sharpShadow.shadowDistance = 4.0;
	FxGripOSCBlockDrawPart *blurredShadow = [self quadPartWithID:3];
	blurredShadow.shadowColor = kFxGripOSCShadowColor;
	blurredShadow.shadowDistance = 4.0;
	blurredShadow.shadowBlur = 3.0;
	[self.control addParts:@[crisp, sharpShadow, blurredShadow]];

	[self.control drawOSCWithWidth:64 height:64 activePart:0 destinationImage:tile atTime:FxGripOSCTestTime()];

	XCTAssertEqual(crisp.drawCount, (NSUInteger)1, @"a part with no shadow draws only in the foreground");
	XCTAssertEqual(sharpShadow.drawCount, (NSUInteger)2, @"its own shadow group plus the foreground");
	XCTAssertEqual(blurredShadow.drawCount, (NSUInteger)2, @"a second group, for the blurred radius");
}

/*! Renders one shadow-casting part that fills a quad and strokes a line that opts out of the shadow. */
- (nullable FxImageTile *)renderShadowCastingQuadTile
{
	FxImageTile *tile = [FxGripOSCMetalTestPass destinationTileWithCanvasSize:CGSizeMake(64.0, 64.0)];
	if (tile == nil) {
		return nil;
	}
	FxGripOSCBlockDrawPart *part = [[FxGripOSCBlockDrawPart alloc] initWithPartID:1];
	part.shadowColor = kFxGripOSCShadowColor;
	part.shadowDistance = 6.0;
	part.shadowBlur = 0.0;
	part.drawBlock = ^(FxGripOSCBlockDrawPart *drawn, BOOL selected, CGSize canvasSize,
					   id<MTLRenderCommandEncoder> commandEncoder) {
		[drawn.control fillCanvasQuadLL:CGPointMake(20.0, 20.0)
									 lr:CGPointMake(44.0, 20.0)
									 ur:CGPointMake(44.0, 44.0)
									 ul:CGPointMake(20.0, 44.0)
								  color:FxGripOSCTestOpaqueWhite()
							 canvasSize:canvasSize
						 commandEncoder:commandEncoder];
		CGPoint stroke[2] = { CGPointMake(8.0, 60.0), CGPointMake(30.0, 60.0) };
		[drawn.control strokeCanvasPoints:stroke count:2 closed:NO color:FxGripOSCTestOpaqueWhite()
							   withShadow:NO canvasSize:canvasSize commandEncoder:commandEncoder];
	};
	[self.control addPart:part];

	[self.control drawOSCWithWidth:64 height:64 activePart:0 destinationImage:tile atTime:FxGripOSCTestTime()];
	[self waitForTile:tile inkAtCanvasPoint:CGPointMake(22.0, 42.0)];
	return tile;
}

/*! @abstract The shadow phase composites a tinted shadow beneath the crisp shape, and a stroke that opts out casts none. */
- (void)testTheShadowPhaseCompositesAShadowBeneathTheCrispShape
{
	FxImageTile *tile = [self renderShadowCastingQuadTile];
	if (tile == nil) {
		XCTSkip(@"no Metal device is available");
	}
	id<MTLTexture> texture = [tile metalTextureForDevice:FxGripOSCMetalTestPass.sharedDevice];
	XCTAssertGreaterThan([FxGripOSCMetalTestPass colorInTexture:texture
												  atCanvasPoint:CGPointMake(22.0, 42.0)].x, 0.9f,
						 @"the crisp white quad sits on top of its shadow");

	// The shadow is the only tinted ink on the canvas: the part draws white, the shadow color is gray.
	BOOL foundShadow = NO, foundStrokeShadow = NO;
	for (NSUInteger y = 0; y < 64; y++) {
		for (NSUInteger x = 0; x < 64; x++) {
			simd_float4 color = [FxGripOSCMetalTestPass colorInTexture:texture
														atCanvasPoint:CGPointMake(x, y)];
			if (color.w <= 0.3f || color.x >= 0.9f) {
				continue;
			}
			foundShadow = YES;
			foundStrokeShadow = foundStrokeShadow || y > 50;
		}
	}
	XCTAssertTrue(foundShadow, @"the shadow phase composited a shadow beneath the control");
	XCTAssertFalse(foundStrokeShadow, @"a stroke that opts out of the shadow casts none");
}

/*! @abstract The shadow lands offset from the crisp shape by the shadow distance. */
- (void)testTheShadowLandsAtTheShadowDistanceOffset
{
	FxImageTile *tile = [self renderShadowCastingQuadTile];
	if (tile == nil) {
		XCTSkip(@"no Metal device is available");
	}
	id<MTLTexture> texture = [tile metalTextureForDevice:FxGripOSCMetalTestPass.sharedDevice];

	// The quad spans canvas (20, 20) to (44, 44); a 6 px shadow spans (26, 14) to (50, 38), so
	// (47, 17) is shadow and not quad. Mirrored about the 64 px canvas center, the shadow would
	// span (26, 26) to (50, 50) instead, which puts shadow at (47, 47).
	XCTAssertGreaterThan([FxGripOSCMetalTestPass colorInTexture:texture
												  atCanvasPoint:CGPointMake(47.0, 17.0)].w, 0.3f,
						 @"the shadow reaches past the crisp quad, offset by the distance");
	XCTAssertLessThan([FxGripOSCMetalTestPass colorInTexture:texture
											   atCanvasPoint:CGPointMake(47.0, 47.0)].w, 0.05f,
					  @"the shadow is upright, not mirrored about the canvas center");
}

/*! @abstract Drawing into a tile no Metal device claims returns without asking any part to draw. */
- (void)testDrawingIntoATileWithNoDeviceDrawsNothing
{
	FxRect bounds = { 0, 0, 32, 32 };
	FxImageTile *tile = [FxImageTile stubTileWithPixelBounds:bounds];
	tile.deviceRegistryID = 0;
	FxGripOSCBlockDrawPart *part = [self quadPartWithID:1];
	[self.control addPart:part];

	XCTAssertNoThrow([self.control drawOSCWithWidth:32 height:32 activePart:0
								   destinationImage:tile atTime:FxGripOSCTestTime()]);
	XCTAssertEqual(part.drawCount, (NSUInteger)0, @"no command queue means no draw");
}

#pragma mark Part drawing

/*! Stages a square 100 x 100 input frame, so input-pixel math maps one to one across the axes. */
- (void)stageSquareInputBounds
{
	self.manager.onScreenControlAPIv4.stagedInputBounds = NSMakeRect(0.0, 0.0, 100.0, 100.0);
}

/*! Draws one part into a live pass, unselected unless stated. */
- (void)drawPart:(FxGripOSCPart *)part inPass:(FxGripOSCMetalTestPass *)pass selected:(BOOL)selected
{
	[part drawSelected:selected
			canvasSize:pass.canvasSize
		commandEncoder:pass.commandEncoder
				atTime:FxGripOSCTestTime()];
	[pass finish];
}

/*! @abstract A point handle fills its square at the parameter's canvas position, in the selected fill when active. */
- (void)testAPointHandleDrawsItsSquareAtTheParameterPosition
{
	[self stagePoint:NSMakePoint(0.3, 0.3) forParameter:21];
	FxGripOSCPointHandlePart *part = [FxGripOSCPointHandlePart partWithID:1 parameterID:21];
	[self.control addPart:part];

	FxGripOSCBeginPass(pass, CGSizeMake(80.0, 80.0));
	[self drawPart:part inPass:pass selected:NO];
	XCTAssertEqualWithAccuracy([pass colorAtCanvasPoint:CGPointMake(30.0, 30.0)].w,
							   kFxGripOSCUnselectedFillColor.w, 0.02, @"the unselected fill");
	XCTAssertEqualWithAccuracy([pass colorAtCanvasPoint:CGPointMake(50.0, 50.0)].w, 0.0, 0.01,
							   @"away from the handle");

	FxGripOSCBeginPass(selectedPass, CGSizeMake(80.0, 80.0));
	[self drawPart:part inPass:selectedPass selected:YES];
	XCTAssertEqualWithAccuracy([selectedPass colorAtCanvasPoint:CGPointMake(30.0, 30.0)].w,
							   kFxGripOSCSelectedFillColor.w, 0.02, @"the selected fill");
}

/*! @abstract A part whose parameter the host does not answer draws nothing and answers no hit. */
- (void)testAPointHandleWithNoParameterValueDrawsNothing
{
	FxGripOSCPointHandlePart *part = [FxGripOSCPointHandlePart partWithID:1 parameterID:99];
	[self.control addPart:part];

	FxGripOSCBeginPass(pass, CGSizeMake(80.0, 80.0));
	[self drawPart:part inPass:pass selected:NO];
	XCTAssertEqualWithAccuracy([self inkNear:CGPointMake(40.0, 40.0) inPass:pass], 0.0, 0.01);
	XCTAssertFalse([part hitTestObjectPoint:CGPointZero canvasPoint:CGPointZero atTime:FxGripOSCTestTime()]);
}

/*! @abstract A line strokes between its endpoints, and draws nothing without them. */
- (void)testALineStrokesBetweenItsEndpoints
{
	[self stagePoint:NSMakePoint(0.1, 0.5) forParameter:21];
	[self stagePoint:NSMakePoint(0.5, 0.5) forParameter:22];
	FxGripOSCLinePart *part = [FxGripOSCLinePart partWithID:1 startParameterID:21 endParameterID:22];
	[self.control addPart:part];

	FxGripOSCBeginPass(pass, CGSizeMake(80.0, 80.0));
	[self drawPart:part inPass:pass selected:NO];
	XCTAssertGreaterThan([self inkNear:CGPointMake(30.0, 50.0) inPass:pass], 0.5f, @"along the segment");
	XCTAssertEqualWithAccuracy([self inkNear:CGPointMake(65.0, 50.0) inPass:pass], 0.0, 0.01, @"past the end");

	FxGripOSCLinePart *unstaged = [FxGripOSCLinePart partWithID:2 startParameterID:97 endParameterID:98];
	[self.control addPart:unstaged];
	FxGripOSCBeginPass(emptyPass, CGSizeMake(80.0, 80.0));
	[self drawPart:unstaged inPass:emptyPass selected:NO];
	XCTAssertEqualWithAccuracy([self inkNear:CGPointMake(30.0, 50.0) inPass:emptyPass], 0.0, 0.01);
	XCTAssertFalse([unstaged hitTestObjectPoint:CGPointZero canvasPoint:CGPointZero atTime:FxGripOSCTestTime()]);
	XCTAssertFalse([unstaged dragToObjectPoint:CGPointZero objectDelta:CGPointMake(0.1, 0.0)
									 modifiers:0 atTime:FxGripOSCTestTime()]);
}

/*! @abstract An angle dial strokes its spoke and fills a handle on the tip. */
- (void)testTheAngleDialStrokesItsSpokeAndFillsItsTip
{
	[self stagePoint:NSMakePoint(0.4, 0.4) forParameter:21];
	self.manager.paramGetAPIv6.floats[@(22)] = @(0.0);
	FxGripOSCAngleDialPart *part = [FxGripOSCAngleDialPart partWithID:1 centerParameterID:21 angleParameterID:22];
	part.spokeRadius = 20.0;
	[self.control addPart:part];

	FxGripOSCBeginPass(pass, CGSizeMake(80.0, 80.0));
	[self drawPart:part inPass:pass selected:NO];
	XCTAssertGreaterThan([self inkNear:CGPointMake(50.0, 40.0) inPass:pass], 0.5f, @"the spoke");
	XCTAssertEqualWithAccuracy([pass colorAtCanvasPoint:CGPointMake(60.0, 40.0)].w,
							   kFxGripOSCUnselectedFillColor.w, 0.02, @"the tip handle's fill");
}

/*! @abstract An angle dial without its parameters draws nothing, answers no hit, and refuses a drag. */
- (void)testTheAngleDialWithoutItsParametersIsInert
{
	FxGripOSCAngleDialPart *part = [FxGripOSCAngleDialPart partWithID:1 centerParameterID:97 angleParameterID:98];
	[self.control addPart:part];
	CMTime time = FxGripOSCTestTime();

	FxGripOSCBeginPass(pass, CGSizeMake(80.0, 80.0));
	[self drawPart:part inPass:pass selected:NO];
	XCTAssertEqualWithAccuracy([self inkNear:CGPointMake(40.0, 40.0) inPass:pass], 0.0, 0.01);
	XCTAssertFalse([part hitTestObjectPoint:CGPointZero canvasPoint:CGPointZero atTime:time]);
	XCTAssertFalse([part dragToObjectPoint:CGPointMake(0.5, 0.5) objectDelta:CGPointZero modifiers:0 atTime:time]);

	[self stagePoint:NSMakePoint(0.4, 0.4) forParameter:97];
	XCTAssertFalse([part dragToObjectPoint:CGPointMake(0.4, 0.4) objectDelta:CGPointZero modifiers:0 atTime:time],
				   @"a drag onto the center has no angle to write");
}

/*! @abstract A rectangle fills its span and strokes its outline, and rotates rigidly with its angle overlay. */
- (void)testARectangleFillsItsSpanAndRotatesWithItsAngle
{
	[self stageSquareInputBounds];
	[self stagePoint:NSMakePoint(0.2, 0.2) forParameter:11];
	[self stagePoint:NSMakePoint(0.6, 0.6) forParameter:12];
	FxGripOSCRectPart *part = [FxGripOSCRectPart partWithID:1 lowerLeftParameterID:11 upperRightParameterID:12];
	[self.control addPart:part];

	FxGripOSCBeginPass(flatPass, CGSizeMake(80.0, 80.0));
	[self drawPart:part inPass:flatPass selected:NO];
	XCTAssertEqualWithAccuracy([flatPass colorAtCanvasPoint:CGPointMake(40.0, 40.0)].w,
							   kFxGripOSCUnselectedFillColor.w, 0.02, @"the body fill");
	XCTAssertGreaterThan([self inkNear:CGPointMake(40.0, 20.0) inPass:flatPass], 0.5f, @"the outline");
	XCTAssertEqualWithAccuracy([self inkNear:CGPointMake(66.0, 40.0) inPass:flatPass], 0.0, 0.01,
							   @"past the unrotated right edge");

	part.angleParameterID = 13;
	self.manager.paramGetAPIv6.floats[@(13)] = @(M_PI_4);
	FxGripOSCBeginPass(rotatedPass, CGSizeMake(80.0, 80.0));
	[self drawPart:part inPass:rotatedPass selected:NO];
	XCTAssertEqualWithAccuracy([rotatedPass colorAtCanvasPoint:CGPointMake(40.0, 40.0)].w,
							   kFxGripOSCUnselectedFillColor.w, 0.02, @"the rotated body still covers its center");
	XCTAssertGreaterThan([rotatedPass colorAtCanvasPoint:CGPointMake(66.0, 40.0)].w, 0.1f,
						 @"the rotated corner reaches past the unrotated edge");
	XCTAssertEqualWithAccuracy([rotatedPass colorAtCanvasPoint:CGPointMake(58.0, 58.0)].w, 0.0, 0.01,
							   @"and the unrotated corner is now outside");
}

/*! @abstract A rectangle whose angle parameter the host does not answer is inert. */
- (void)testARectangleWithAnUnreadableAngleIsInert
{
	[self stagePoint:NSMakePoint(0.2, 0.2) forParameter:11];
	[self stagePoint:NSMakePoint(0.6, 0.6) forParameter:12];
	FxGripOSCRectPart *part = [FxGripOSCRectPart partWithID:1 lowerLeftParameterID:11 upperRightParameterID:12];
	part.angleParameterID = 13;
	[self.control addPart:part];

	FxGripOSCBeginPass(pass, CGSizeMake(80.0, 80.0));
	[self drawPart:part inPass:pass selected:NO];
	XCTAssertEqualWithAccuracy([self inkNear:CGPointMake(40.0, 40.0) inPass:pass], 0.0, 0.01);
	XCTAssertFalse([part hitTestObjectPoint:CGPointMake(0.4, 0.4) canvasPoint:CGPointMake(40.0, 40.0)
									 atTime:FxGripOSCTestTime()]);
}

/*! @abstract A rotated rectangle with an unusable input frame is inert, since rotation is rigid in input pixels. */
- (void)testARotatedRectangleWithAnEmptyInputFrameIsInert
{
	self.manager.onScreenControlAPIv4.stagedInputBounds = NSZeroRect;
	[self stagePoint:NSMakePoint(0.2, 0.2) forParameter:11];
	[self stagePoint:NSMakePoint(0.6, 0.6) forParameter:12];
	self.manager.paramGetAPIv6.floats[@(13)] = @(M_PI_4);
	FxGripOSCRectPart *part = [FxGripOSCRectPart partWithID:1 lowerLeftParameterID:11 upperRightParameterID:12];
	part.angleParameterID = 13;
	[self.control addPart:part];
	FxGripOSCRectCornerPart *corner = [FxGripOSCRectCornerPart partWithID:2
																  corner:FxGripOSCRectCornerUpperRight
													lowerLeftParameterID:11
												   upperRightParameterID:12];
	corner.angleParameterID = 13;
	[self.control addPart:corner];
	CMTime time = FxGripOSCTestTime();

	FxGripOSCBeginPass(pass, CGSizeMake(80.0, 80.0));
	[part drawSelected:NO canvasSize:pass.canvasSize commandEncoder:pass.commandEncoder atTime:time];
	[corner drawSelected:NO canvasSize:pass.canvasSize commandEncoder:pass.commandEncoder atTime:time];
	[pass finish];

	XCTAssertEqualWithAccuracy([self inkNear:CGPointMake(40.0, 40.0) inPass:pass], 0.0, 0.01);
	XCTAssertFalse([part hitTestObjectPoint:CGPointMake(0.4, 0.4) canvasPoint:CGPointMake(40.0, 40.0) atTime:time]);
	XCTAssertFalse([corner hitTestObjectPoint:CGPointMake(0.6, 0.6) canvasPoint:CGPointMake(60.0, 60.0) atTime:time]);
	XCTAssertFalse([corner dragToObjectPoint:CGPointMake(0.7, 0.7) objectDelta:CGPointZero modifiers:0 atTime:time]);
}

/*! @abstract A rectangle corner fills its handle on the corner it names. */
- (void)testARectangleCornerFillsItsHandleOnItsCorner
{
	[self stagePoint:NSMakePoint(0.2, 0.2) forParameter:11];
	[self stagePoint:NSMakePoint(0.6, 0.6) forParameter:12];
	FxGripOSCRectCornerPart *part = [FxGripOSCRectCornerPart partWithID:1
																corner:FxGripOSCRectCornerUpperLeft
												  lowerLeftParameterID:11
												 upperRightParameterID:12];
	[self.control addPart:part];

	FxGripOSCBeginPass(pass, CGSizeMake(80.0, 80.0));
	[self drawPart:part inPass:pass selected:NO];
	XCTAssertEqualWithAccuracy([pass colorAtCanvasPoint:CGPointMake(20.0, 60.0)].w,
							   kFxGripOSCUnselectedFillColor.w, 0.02, @"the upper-left corner");
	XCTAssertEqualWithAccuracy([pass colorAtCanvasPoint:CGPointMake(60.0, 20.0)].w, 0.0, 0.01,
							   @"and no other corner");

	FxGripOSCRectCornerPart *unstaged = [FxGripOSCRectCornerPart partWithID:2
																	corner:FxGripOSCRectCornerLowerLeft
													  lowerLeftParameterID:97
													 upperRightParameterID:98];
	[self.control addPart:unstaged];
	FxGripOSCBeginPass(emptyPass, CGSizeMake(80.0, 80.0));
	[self drawPart:unstaged inPass:emptyPass selected:NO];
	XCTAssertEqualWithAccuracy([self inkNear:CGPointMake(20.0, 20.0) inPass:emptyPass], 0.0, 0.01);
	XCTAssertFalse([unstaged hitTestObjectPoint:CGPointZero canvasPoint:CGPointZero atTime:FxGripOSCTestTime()]);
	XCTAssertFalse([unstaged dragToObjectPoint:CGPointZero objectDelta:CGPointZero
									 modifiers:0 atTime:FxGripOSCTestTime()]);
}

/*! Stages a square input frame with a circle at object (0.4, 0.4) of 20 input pixels in parameters 21 and 22. */
- (void)stageSquareCircle
{
	[self stageSquareInputBounds];
	[self stagePoint:NSMakePoint(0.4, 0.4) forParameter:21];
	self.manager.paramGetAPIv6.floats[@(22)] = @(20.0);
}

/*! @abstract A circle fills its disk and strokes its rim. */
- (void)testACircleFillsItsDiskAndStrokesItsRim
{
	[self stageSquareCircle];
	FxGripOSCCirclePart *part = [FxGripOSCCirclePart partWithID:1 centerParameterID:21 radiusParameterID:22];
	[self.control addPart:part];

	FxGripOSCBeginPass(pass, CGSizeMake(80.0, 80.0));
	[self drawPart:part inPass:pass selected:YES];
	XCTAssertEqualWithAccuracy([pass colorAtCanvasPoint:CGPointMake(40.0, 40.0)].w,
							   kFxGripOSCSelectedFillColor.w, 0.02, @"the selected disk fill");
	XCTAssertGreaterThan([self inkNear:CGPointMake(60.0, 40.0) inPass:pass], 0.5f, @"the rim");
	XCTAssertEqualWithAccuracy([self inkNear:CGPointMake(74.0, 40.0) inPass:pass], 0.0, 0.01, @"outside the rim");
}

/*! @abstract The circle read normalizes its pixel radius per axis and fails without its parameters or an input frame. */
- (void)testTheCircleReadNormalizesItsRadiusPerAxis
{
	[self stagePoint:NSMakePoint(0.4, 0.4) forParameter:21];
	self.manager.paramGetAPIv6.floats[@(22)] = @(20.0);
	FxGripOSCCirclePart *part = [FxGripOSCCirclePart partWithID:1 centerParameterID:21 radiusParameterID:22];
	[self.control addPart:part];
	CMTime time = FxGripOSCTestTime();
	CGPoint center = CGPointZero, normalized = CGPointZero;

	XCTAssertTrue([part readCenter:&center normalizedRadius:&normalized atTime:time]);
	XCTAssertEqualWithAccuracy(normalized.x, 20.0 / 200.0, 1e-12, @"normalized against the 200 px width");
	XCTAssertEqualWithAccuracy(normalized.y, 20.0 / 100.0, 1e-12, @"and the 100 px height");

	self.manager.onScreenControlAPIv4.stagedInputBounds = NSZeroRect;
	XCTAssertFalse([part readCenter:&center normalizedRadius:&normalized atTime:time], @"no input frame");

	FxGripOSCCirclePart *noRadius = [FxGripOSCCirclePart partWithID:2 centerParameterID:21 radiusParameterID:98];
	[self.control addPart:noRadius];
	XCTAssertFalse([noRadius readCenter:&center normalizedRadius:&normalized atTime:time], @"no radius");

	FxGripOSCCirclePart *noCenter = [FxGripOSCCirclePart partWithID:3 centerParameterID:97 radiusParameterID:22];
	[self.control addPart:noCenter];
	XCTAssertFalse([noCenter readCenter:&center normalizedRadius:&normalized atTime:time], @"no center");
	XCTAssertFalse([noCenter hitTestObjectPoint:CGPointZero canvasPoint:CGPointZero atTime:time]);
	XCTAssertFalse([noCenter dragToObjectPoint:CGPointZero objectDelta:CGPointMake(0.1, 0.0) modifiers:0 atTime:time]);
}

/*! @abstract A circle radius handle fills its square on the rim, and is inert without its parameters. */
- (void)testACircleRadiusHandleFillsItsSquareOnTheRim
{
	[self stageSquareCircle];
	FxGripOSCCircleRadiusHandlePart *part = [FxGripOSCCircleRadiusHandlePart partWithID:1
																	 centerParameterID:21
																	 radiusParameterID:22];
	[self.control addPart:part];

	FxGripOSCBeginPass(pass, CGSizeMake(80.0, 80.0));
	[self drawPart:part inPass:pass selected:NO];
	XCTAssertEqualWithAccuracy([pass colorAtCanvasPoint:CGPointMake(60.0, 40.0)].w,
							   kFxGripOSCUnselectedFillColor.w, 0.02, @"on the rim at angle zero");

	CMTime time = FxGripOSCTestTime();
	self.manager.onScreenControlAPIv4.stagedInputBounds = NSZeroRect;
	XCTAssertFalse([part hitTestObjectPoint:CGPointZero canvasPoint:CGPointMake(60.0, 40.0) atTime:time],
				   @"no input frame, no handle");
	XCTAssertFalse([part dragToObjectPoint:CGPointMake(0.6, 0.4) objectDelta:CGPointZero modifiers:0 atTime:time]);

	FxGripOSCCircleRadiusHandlePart *noCenter = [FxGripOSCCircleRadiusHandlePart partWithID:2
																		 centerParameterID:97
																		 radiusParameterID:22];
	[self.control addPart:noCenter];
	XCTAssertFalse([noCenter dragToObjectPoint:CGPointZero objectDelta:CGPointZero modifiers:0 atTime:time]);
	FxGripOSCBeginPass(emptyPass, CGSizeMake(80.0, 80.0));
	[self drawPart:noCenter inPass:emptyPass selected:NO];
	XCTAssertEqualWithAccuracy([self inkNear:CGPointMake(40.0, 40.0) inPass:emptyPass], 0.0, 0.01);
}

/*! @abstract A rotation handle strokes a spoke to the rim point at its angle and fills a handle there. */
- (void)testARotationHandleStrokesItsSpokeToTheRim
{
	[self stageSquareCircle];
	self.manager.paramGetAPIv6.floats[@(23)] = @(0.0);
	FxGripOSCRotationHandlePart *part = [FxGripOSCRotationHandlePart partWithID:1
															  centerParameterID:21
															  radiusParameterID:22
															   angleParameterID:23];
	[self.control addPart:part];

	FxGripOSCBeginPass(pass, CGSizeMake(80.0, 80.0));
	[self drawPart:part inPass:pass selected:NO];
	XCTAssertGreaterThan([self inkNear:CGPointMake(50.0, 40.0) inPass:pass], 0.5f, @"the spoke");
	XCTAssertEqualWithAccuracy([pass colorAtCanvasPoint:CGPointMake(60.0, 40.0)].w,
							   kFxGripOSCUnselectedFillColor.w, 0.02, @"the rim handle");
}

/*! @abstract The rotation handle's rim read needs a center, a radius, an angle, and a usable input frame. */
- (void)testTheRotationHandleRimReadNeedsEveryParameter
{
	[self stageSquareCircle];
	self.manager.paramGetAPIv6.floats[@(23)] = @(0.0);
	CMTime time = FxGripOSCTestTime();
	CGPoint handle = CGPointZero, center = CGPointZero;

	FxGripOSCRotationHandlePart *part = [FxGripOSCRotationHandlePart partWithID:1
															  centerParameterID:21
															  radiusParameterID:22
															   angleParameterID:23];
	[self.control addPart:part];
	XCTAssertTrue([part readHandleObjectPoint:&handle center:&center atTime:time]);
	XCTAssertEqualWithAccuracy(handle.x, 0.6, 1e-12, @"the rim point at angle zero");
	XCTAssertEqualWithAccuracy(handle.y, 0.4, 1e-12);

	FxGripOSCRotationHandlePart *noCenter = [FxGripOSCRotationHandlePart partWithID:2
																  centerParameterID:97
																  radiusParameterID:22
																   angleParameterID:23];
	FxGripOSCRotationHandlePart *noRadius = [FxGripOSCRotationHandlePart partWithID:3
																  centerParameterID:21
																  radiusParameterID:98
																   angleParameterID:23];
	FxGripOSCRotationHandlePart *noAngle = [FxGripOSCRotationHandlePart partWithID:4
																 centerParameterID:21
																 radiusParameterID:22
																  angleParameterID:99];
	[self.control addParts:@[noCenter, noRadius, noAngle]];
	XCTAssertFalse([noCenter readHandleObjectPoint:&handle center:&center atTime:time]);
	XCTAssertFalse([noRadius readHandleObjectPoint:&handle center:&center atTime:time]);
	XCTAssertFalse([noAngle readHandleObjectPoint:&handle center:&center atTime:time]);
	XCTAssertFalse([noCenter hitTestObjectPoint:CGPointZero canvasPoint:CGPointZero atTime:time]);
	XCTAssertFalse([noCenter dragToObjectPoint:CGPointMake(0.6, 0.4) objectDelta:CGPointZero
									 modifiers:0 atTime:time]);
	XCTAssertFalse([part dragToObjectPoint:CGPointMake(0.4, 0.4) objectDelta:CGPointZero modifiers:0 atTime:time],
				   @"a drag onto the center has no angle to write");

	self.manager.onScreenControlAPIv4.stagedInputBounds = NSZeroRect;
	XCTAssertFalse([part readHandleObjectPoint:&handle center:&center atTime:time], @"no input frame");
	FxGripOSCBeginPass(pass, CGSizeMake(80.0, 80.0));
	[self drawPart:part inPass:pass selected:NO];
	XCTAssertEqualWithAccuracy([self inkNear:CGPointMake(50.0, 40.0) inPass:pass], 0.0, 0.01);
}

/*! @abstract A closed polyline strokes the wrap segment an open one omits, and short or unstaged chains are inert. */
- (void)testAClosedPolylineStrokesTheWrapSegment
{
	[self stagePoint:NSMakePoint(0.2, 0.2) forParameter:21];
	[self stagePoint:NSMakePoint(0.6, 0.2) forParameter:22];
	[self stagePoint:NSMakePoint(0.6, 0.6) forParameter:23];
	NSArray<NSNumber *> *chain = @[@21, @22, @23];

	FxGripOSCPolylinePart *closed = [FxGripOSCPolylinePart partWithID:1 pointParameterIDs:chain closed:YES];
	[self.control addPart:closed];
	FxGripOSCBeginPass(closedPass, CGSizeMake(80.0, 80.0));
	[self drawPart:closed inPass:closedPass selected:NO];
	XCTAssertGreaterThan([self inkNear:CGPointMake(40.0, 40.0) inPass:closedPass], 0.5f, @"the wrap segment");

	FxGripOSCPolylinePart *open = [FxGripOSCPolylinePart partWithID:2 pointParameterIDs:chain closed:NO];
	[self.control addPart:open];
	FxGripOSCBeginPass(openPass, CGSizeMake(80.0, 80.0));
	[self drawPart:open inPass:openPass selected:YES];
	XCTAssertGreaterThan([self inkNear:CGPointMake(40.0, 20.0) inPass:openPass], 0.5f, @"the first segment");
	XCTAssertEqualWithAccuracy([self inkNear:CGPointMake(40.0, 40.0) inPass:openPass], 0.0, 0.01,
							   @"an open chain has no wrap segment");
}

/*! @abstract A polyline of fewer than two points, or with unreadable parameters, draws nothing and answers no hit. */
- (void)testAShortOrUnreadablePolylineIsInert
{
	CMTime time = FxGripOSCTestTime();
	FxGripOSCPolylinePart *single = [FxGripOSCPolylinePart partWithID:1 pointParameterIDs:@[@21] closed:YES];
	FxGripOSCPolylinePart *unstaged = [FxGripOSCPolylinePart partWithID:2
													 pointParameterIDs:@[@97, @98]
																closed:NO];
	[self.control addParts:@[single, unstaged]];

	FxGripOSCBeginPass(pass, CGSizeMake(80.0, 80.0));
	[single drawSelected:NO canvasSize:pass.canvasSize commandEncoder:pass.commandEncoder atTime:time];
	[unstaged drawSelected:NO canvasSize:pass.canvasSize commandEncoder:pass.commandEncoder atTime:time];
	[pass finish];

	XCTAssertEqualWithAccuracy([self inkNear:CGPointMake(40.0, 40.0) inPass:pass], 0.0, 0.01);
	XCTAssertFalse([single hitTestObjectPoint:CGPointZero canvasPoint:CGPointMake(20.0, 20.0) atTime:time]);
	XCTAssertFalse([unstaged hitTestObjectPoint:CGPointZero canvasPoint:CGPointMake(20.0, 20.0) atTime:time]);
	XCTAssertFalse([unstaged dragToObjectPoint:CGPointZero objectDelta:CGPointMake(0.1, 0.0) modifiers:0 atTime:time]);
}

/*! @abstract The flag-form polyline composite includes the body and the vertex handles the options name. */
- (void)testThePolylineFlagCompositeFollowsItsOptions
{
	NSArray<NSNumber *> *chain = @[@21, @22, @23];
	NSArray<FxGripOSCPart *> *bodyOnly = [FxGripOSCPolylinePart polylinePartsWithOptions:FxGripOSCShapeOptionBody
																			 firstPartID:1
																	   pointParameterIDs:chain
																				  closed:YES];
	XCTAssertEqual(bodyOnly.count, (NSUInteger)1);
	XCTAssertTrue([bodyOnly.firstObject isKindOfClass:FxGripOSCPolylinePart.class]);

	NSArray<FxGripOSCPart *> *handlesOnly = [FxGripOSCPolylinePart polylinePartsWithOptions:FxGripOSCShapeOptionVertexHandles
																				firstPartID:5
																		  pointParameterIDs:chain
																					 closed:NO];
	XCTAssertEqual(handlesOnly.count, (NSUInteger)3);
	XCTAssertEqual(handlesOnly.firstObject.partID, (NSInteger)5);
	XCTAssertTrue([handlesOnly.lastObject isKindOfClass:FxGripOSCPointHandlePart.class]);
	XCTAssertEqual(handlesOnly.lastObject.partID, (NSInteger)7);
}

/*! @abstract The flag-form box composite includes only the pieces its options name. */
- (void)testTheBoxFlagCompositeFollowsItsOptions
{
	NSArray<FxGripOSCPart *> *cornersOnly = [FxGripOSCBoxPart boxPartsWithOptions:FxGripOSCShapeOptionCornerHandles
																	  firstPartID:1
																centerParameterID:21
																 widthParameterID:22
																heightParameterID:23
																 angleParameterID:24];
	XCTAssertEqual(cornersOnly.count, (NSUInteger)4);
	for (FxGripOSCPart *part in cornersOnly) {
		XCTAssertTrue([part isKindOfClass:FxGripOSCBoxCornerPart.class]);
	}

	NSArray<FxGripOSCPart *> *everything = [FxGripOSCBoxPart boxPartsWithOptions:FxGripOSCShapeOptionsAll
																	 firstPartID:1
															   centerParameterID:21
																widthParameterID:22
															   heightParameterID:23
																angleParameterID:24];
	XCTAssertEqual(everything.count, (NSUInteger)6, @"body, four corners, and the dial");
	XCTAssertTrue([everything.lastObject isKindOfClass:FxGripOSCAngleDialPart.class]);
	XCTAssertEqual(everything.lastObject.partID, (NSInteger)6);
}

/*! @abstract A rectangle rotation handle strokes a spoke from the corners' midpoint to its tip. */
- (void)testTheRectangleRotationHandleStrokesFromTheMidpoint
{
	[self stagePoint:NSMakePoint(0.2, 0.2) forParameter:11];
	[self stagePoint:NSMakePoint(0.6, 0.6) forParameter:12];
	self.manager.paramGetAPIv6.floats[@(13)] = @(0.0);
	FxGripOSCRectRotationHandlePart *part = [FxGripOSCRectRotationHandlePart partWithID:1
																  lowerLeftParameterID:11
																 upperRightParameterID:12
																	  angleParameterID:13];
	part.spokeRadius = 20.0;
	[self.control addPart:part];

	FxGripOSCBeginPass(pass, CGSizeMake(80.0, 80.0));
	[self drawPart:part inPass:pass selected:YES];
	XCTAssertGreaterThan([self inkNear:CGPointMake(50.0, 40.0) inPass:pass], 0.5f, @"the spoke");
	XCTAssertEqualWithAccuracy([pass colorAtCanvasPoint:CGPointMake(60.0, 40.0)].w,
							   kFxGripOSCSelectedFillColor.w, 0.02, @"the selected tip handle");

	CMTime time = FxGripOSCTestTime();
	FxGripOSCRectRotationHandlePart *unstaged = [FxGripOSCRectRotationHandlePart partWithID:2
																	  lowerLeftParameterID:97
																	 upperRightParameterID:98
																		  angleParameterID:13];
	[self.control addPart:unstaged];
	XCTAssertFalse([unstaged hitTestObjectPoint:CGPointZero canvasPoint:CGPointZero atTime:time]);
	XCTAssertFalse([unstaged dragToObjectPoint:CGPointMake(0.5, 0.5) objectDelta:CGPointZero modifiers:0 atTime:time]);
	XCTAssertFalse([part dragToObjectPoint:CGPointMake(0.4, 0.4) objectDelta:CGPointZero modifiers:0 atTime:time],
				   @"a drag onto the midpoint has no angle to write");
	FxGripOSCBeginPass(emptyPass, CGSizeMake(80.0, 80.0));
	[self drawPart:unstaged inPass:emptyPass selected:NO];
	XCTAssertEqualWithAccuracy([self inkNear:CGPointMake(40.0, 40.0) inPass:emptyPass], 0.0, 0.01);
}

/*! Stages a square input frame with a 40 x 20 pixel box at object (0.4, 0.4) in parameters 21 to 24. */
- (void)stageSquareBox
{
	[self stageSquareInputBounds];
	[self stagePoint:NSMakePoint(0.4, 0.4) forParameter:21];
	self.manager.paramGetAPIv6.floats[@(22)] = @(40.0);
	self.manager.paramGetAPIv6.floats[@(23)] = @(20.0);
	self.manager.paramGetAPIv6.floats[@(24)] = @(0.0);
}

/*! @abstract A box fills the frame its pixel width and height span, and its corner handle sits on that frame. */
- (void)testABoxFillsThePixelFrameItsParametersSpan
{
	[self stageSquareBox];
	FxGripOSCBoxPart *body = [FxGripOSCBoxPart partWithID:1
										centerParameterID:21
										 widthParameterID:22
										heightParameterID:23
										 angleParameterID:24];
	FxGripOSCBoxCornerPart *corner = [FxGripOSCBoxCornerPart partWithID:2
																corner:FxGripOSCRectCornerUpperRight
													 centerParameterID:21
													  widthParameterID:22
													 heightParameterID:23
													  angleParameterID:24];
	[self.control addParts:@[body, corner]];

	FxGripOSCBeginPass(pass, CGSizeMake(80.0, 80.0));
	[body drawSelected:NO canvasSize:pass.canvasSize commandEncoder:pass.commandEncoder atTime:FxGripOSCTestTime()];
	[corner drawSelected:NO canvasSize:pass.canvasSize commandEncoder:pass.commandEncoder atTime:FxGripOSCTestTime()];
	[pass finish];

	XCTAssertEqualWithAccuracy([pass colorAtCanvasPoint:CGPointMake(40.0, 40.0)].w,
							   kFxGripOSCUnselectedFillColor.w, 0.02, @"the body fill");
	XCTAssertEqualWithAccuracy([pass colorAtCanvasPoint:CGPointMake(40.0, 58.0)].w, 0.0, 0.01,
							   @"above the 20 px height");
	XCTAssertEqualWithAccuracy([pass colorAtCanvasPoint:CGPointMake(60.0, 50.0)].w,
							   kFxGripOSCUnselectedFillColor.w, 0.02, @"the upper-right corner handle");
}

/*! @abstract A box whose parameters the host does not answer draws nothing and answers no hit. */
- (void)testABoxWithUnreadableParametersIsInert
{
	CMTime time = FxGripOSCTestTime();
	FxGripOSCBoxPart *body = [FxGripOSCBoxPart partWithID:1
										centerParameterID:97
										 widthParameterID:98
										heightParameterID:99
										 angleParameterID:0];
	FxGripOSCBoxCornerPart *corner = [FxGripOSCBoxCornerPart partWithID:2
																corner:FxGripOSCRectCornerLowerLeft
													 centerParameterID:97
													  widthParameterID:98
													 heightParameterID:99
													  angleParameterID:0];
	[self.control addParts:@[body, corner]];

	FxGripOSCBeginPass(pass, CGSizeMake(80.0, 80.0));
	[body drawSelected:NO canvasSize:pass.canvasSize commandEncoder:pass.commandEncoder atTime:time];
	[corner drawSelected:NO canvasSize:pass.canvasSize commandEncoder:pass.commandEncoder atTime:time];
	[pass finish];

	XCTAssertEqualWithAccuracy([self inkNear:CGPointMake(40.0, 40.0) inPass:pass], 0.0, 0.01);
	XCTAssertFalse([body hitTestObjectPoint:CGPointZero canvasPoint:CGPointZero atTime:time]);
	XCTAssertFalse([body dragToObjectPoint:CGPointZero objectDelta:CGPointMake(0.1, 0.0) modifiers:0 atTime:time]);
	XCTAssertFalse([corner hitTestObjectPoint:CGPointZero canvasPoint:CGPointZero atTime:time]);
	XCTAssertFalse([corner dragToObjectPoint:CGPointZero objectDelta:CGPointZero modifiers:0 atTime:time]);
}

/*! @abstract A curve strokes a spline through its control points, and its closed form adds the returning arc. */
- (void)testACurveStrokesASplineThroughItsControlPoints
{
	[self stagePoint:NSMakePoint(0.1, 0.2) forParameter:21];
	[self stagePoint:NSMakePoint(0.3, 0.6) forParameter:22];
	[self stagePoint:NSMakePoint(0.5, 0.2) forParameter:23];
	NSArray<NSNumber *> *chain = @[@21, @22, @23];

	FxGripOSCCurvePart *open = [FxGripOSCCurvePart partWithID:1 pointParameterIDs:chain closed:NO];
	[self.control addPart:open];
	FxGripOSCBeginPass(openPass, CGSizeMake(80.0, 80.0));
	[self drawPart:open inPass:openPass selected:NO];
	XCTAssertGreaterThan([self inkNear:CGPointMake(30.0, 60.0) inPass:openPass], 0.5f, @"through the peak");
	XCTAssertEqualWithAccuracy([self inkNear:CGPointMake(30.0, 15.0) inPass:openPass], 0.0, 0.01,
							   @"an open curve has no returning arc");

	FxGripOSCCurvePart *closed = [FxGripOSCCurvePart partWithID:2 pointParameterIDs:chain closed:YES];
	[self.control addPart:closed];
	FxGripOSCBeginPass(closedPass, CGSizeMake(80.0, 80.0));
	[self drawPart:closed inPass:closedPass selected:NO];
	XCTAssertGreaterThan([self inkNear:CGPointMake(30.0, 60.0) inPass:closedPass], 0.5f, @"through the peak");
	XCTAssertGreaterThan([self inkNear:CGPointMake(30.0, 15.0) inPass:closedPass], 0.5f, @"the returning arc");
}

/*! @abstract A curve of fewer than two points, or with unreadable parameters, draws nothing. */
- (void)testAShortOrUnreadableCurveDrawsNothing
{
	CMTime time = FxGripOSCTestTime();
	FxGripOSCCurvePart *single = [FxGripOSCCurvePart partWithID:1 pointParameterIDs:@[@21] closed:NO];
	FxGripOSCCurvePart *unstaged = [FxGripOSCCurvePart partWithID:2 pointParameterIDs:@[@97, @98] closed:NO];
	[self.control addParts:@[single, unstaged]];

	FxGripOSCBeginPass(pass, CGSizeMake(80.0, 80.0));
	[single drawSelected:NO canvasSize:pass.canvasSize commandEncoder:pass.commandEncoder atTime:time];
	[unstaged drawSelected:NO canvasSize:pass.canvasSize commandEncoder:pass.commandEncoder atTime:time];
	[pass finish];

	XCTAssertEqualWithAccuracy([self inkNear:CGPointMake(40.0, 40.0) inPass:pass], 0.0, 0.01);
	XCTAssertFalse([single hitTestObjectPoint:CGPointZero canvasPoint:CGPointZero atTime:time], @"a curve is display only");
}

/*! @abstract A HUD readout fills its background panel below the anchor and caches the text texture per content. */
- (void)testTheHUDFillsItsPanelAndCachesItsTexture
{
	FxGripOSCHUDPart *part = [FxGripOSCHUDPart partWithID:1 text:@"88"];
	part.canvasAnchor = CGPointMake(20.0, 60.0);
	[self.control addPart:part];

	FxGripOSCBeginPass(pass, CGSizeMake(80.0, 80.0));
	[self drawPart:part inPass:pass selected:NO];
	XCTAssertGreaterThan([pass colorAtCanvasPoint:CGPointMake(23.0, 56.0)].w, 0.5f,
						 @"the panel hangs below the anchor");
	XCTAssertNotNil(part.cachedTexture);

	id<MTLTexture> first = part.cachedTexture;
	XCTAssertTrue([part textureForString:@"88" device:pass.device] == first,
				  @"the same content and device reuse the cached texture");
	XCTAssertFalse([part textureForString:@"99" device:pass.device] == first,
				   @"different content rebuilds it");
}

/*! @abstract A HUD readout with no text, or with an unreadable anchor parameter, draws nothing. */
- (void)testAHUDWithoutTextOrAnAnchorDrawsNothing
{
	CMTime time = FxGripOSCTestTime();
	FxGripOSCHUDPart *empty = [FxGripOSCHUDPart partWithID:1 text:@""];
	FxGripOSCHUDPart *nilBlock = [FxGripOSCHUDPart partWithID:2 textBlock:^NSString * _Nullable (CMTime blockTime) {
		return nil;
	}];
	FxGripOSCHUDPart *noAnchor = [FxGripOSCHUDPart partWithID:3 text:@"88"];
	noAnchor.anchorParameterID = 97;
	[self.control addParts:@[empty, nilBlock, noAnchor]];

	XCTAssertNil([empty resolvedTextAtTime:time]);
	XCTAssertNil([nilBlock resolvedTextAtTime:time]);

	FxGripOSCBeginPass(pass, CGSizeMake(80.0, 80.0));
	[empty drawSelected:NO canvasSize:pass.canvasSize commandEncoder:pass.commandEncoder atTime:time];
	[nilBlock drawSelected:NO canvasSize:pass.canvasSize commandEncoder:pass.commandEncoder atTime:time];
	[noAnchor drawSelected:NO canvasSize:pass.canvasSize commandEncoder:pass.commandEncoder atTime:time];
	[pass finish];

	XCTAssertEqualWithAccuracy([self inkNear:CGPointMake(25.0, 18.0) inPass:pass], 0.0, 0.01);
	XCTAssertNil(noAnchor.cachedTexture, @"an unreadable anchor stops the draw before rasterizing");
}

/*! @abstract A HUD readout anchored to a point parameter draws its panel at that point plus the offset. */
- (void)testAHUDAnchoredToAParameterFollowsThatPoint
{
	[self stagePoint:NSMakePoint(0.2, 0.7) forParameter:21];
	FxGripOSCHUDPart *part = [FxGripOSCHUDPart partWithID:1 textBlock:^NSString * _Nullable (CMTime time) {
		return @"88";
	}];
	part.anchorParameterID = 21;
	part.canvasOffset = CGPointMake(4.0, 0.0);
	part.backgroundColor = (simd_float4){ 0.0f, 0.0f, 1.0f, 1.0f };
	[self.control addPart:part];

	FxGripOSCBeginPass(pass, CGSizeMake(80.0, 80.0));
	[self drawPart:part inPass:pass selected:NO];
	simd_float4 panel = [pass colorAtCanvasPoint:CGPointMake(27.0, 66.0)];
	XCTAssertGreaterThan(panel.z, 0.5f, @"the panel carries the background color");
	XCTAssertEqualWithAccuracy([pass colorAtCanvasPoint:CGPointMake(10.0, 66.0)].w, 0.0, 0.01,
							   @"and starts at the anchor plus the offset");
}

/*! @abstract A HUD readout with a transparent background draws no panel. */
- (void)testAHUDWithATransparentBackgroundDrawsNoPanel
{
	FxGripOSCHUDPart *part = [FxGripOSCHUDPart partWithID:1 text:@"88"];
	part.canvasAnchor = CGPointMake(20.0, 60.0);
	part.backgroundColor = (simd_float4){ 0.0f, 0.0f, 0.0f, 0.0f };
	[self.control addPart:part];

	FxGripOSCBeginPass(pass, CGSizeMake(80.0, 80.0));
	[self drawPart:part inPass:pass selected:NO];
	XCTAssertEqualWithAccuracy([pass colorAtCanvasPoint:CGPointMake(23.0, 56.0)].w, 0.0, 0.01);
	XCTAssertNotNil(part.cachedTexture, @"the text still rasterizes");
}

#pragma mark Corner resize geometry

/*! @abstract The resize solver anchors the opposite corner by default and the rectangle center under Option. */
- (void)testTheResizeSolverAnchorsTheOppositeCornerOrTheCenter
{
	CGPoint lowerLeft = CGPointMake(0.2, 0.2), upperRight = CGPointMake(0.6, 0.5);
	FxGripOSCRectCorner corners[4] = {
		FxGripOSCRectCornerLowerLeft, FxGripOSCRectCornerLowerRight,
		FxGripOSCRectCornerUpperRight, FxGripOSCRectCornerUpperLeft,
	};
	CGPoint expectedAnchors[4] = {
		CGPointMake(0.6, 0.5), CGPointMake(0.2, 0.5), CGPointMake(0.2, 0.2), CGPointMake(0.6, 0.2),
	};
	double expectedSignX[4] = { -1.0, 1.0, 1.0, -1.0 };
	double expectedSignY[4] = { -1.0, -1.0, 1.0, 1.0 };

	for (NSUInteger index = 0; index < 4; index++) {
		FxGripOSCRectCornerPart *part = [FxGripOSCRectCornerPart partWithID:1
																	corner:corners[index]
													  lowerLeftParameterID:11
													 upperRightParameterID:12];
		CGPoint anchor = CGPointZero;
		double signX = 0.0, signY = 0.0, width = 0.0, height = 0.0;
		[part fxResizeAnchor:&anchor signX:&signX signY:&signY width:&width height:&height
				   lowerLeft:lowerLeft upperRight:upperRight atCenter:NO];
		XCTAssertEqualWithAccuracy(anchor.x, expectedAnchors[index].x, 1e-12);
		XCTAssertEqualWithAccuracy(anchor.y, expectedAnchors[index].y, 1e-12);
		XCTAssertEqual(signX, expectedSignX[index]);
		XCTAssertEqual(signY, expectedSignY[index]);
		XCTAssertEqualWithAccuracy(width, 0.4, 1e-12, @"the full span from the opposite corner");
		XCTAssertEqualWithAccuracy(height, 0.3, 1e-12);

		[part fxResizeAnchor:&anchor signX:&signX signY:&signY width:&width height:&height
				   lowerLeft:lowerLeft upperRight:upperRight atCenter:YES];
		XCTAssertEqualWithAccuracy(anchor.x, 0.4, 1e-12, @"Option anchors the center");
		XCTAssertEqualWithAccuracy(anchor.y, 0.35, 1e-12);
		XCTAssertEqualWithAccuracy(width, 0.2, 1e-12, @"and the extent is the half diagonal");
		XCTAssertEqualWithAccuracy(height, 0.15, 1e-12);
	}
}

/*! The point most recently written to a parameter. */
- (CGPoint)writtenPointForParameter:(UInt32)parameterID
{
	return self.manager.paramGetAPIv6.points[@(parameterID)].pointValue;
}

/*! @abstract Dragging a left-hand rectangle corner writes the x it names and leaves the opposite edge alone. */
- (void)testDraggingTheLeftRectangleCornersWritesTheNamedComponents
{
	[self stagePoint:NSMakePoint(0.2, 0.2) forParameter:11];
	[self stagePoint:NSMakePoint(0.6, 0.6) forParameter:12];
	FxGripOSCRectCornerPart *lowerLeft = [FxGripOSCRectCornerPart partWithID:1
																	 corner:FxGripOSCRectCornerLowerLeft
													   lowerLeftParameterID:11
													  upperRightParameterID:12];
	[self.control addPart:lowerLeft];

	XCTAssertTrue([lowerLeft dragToObjectPoint:CGPointMake(0.1, 0.1) objectDelta:CGPointZero
									 modifiers:0 atTime:FxGripOSCTestTime()]);
	XCTAssertEqualWithAccuracy([self writtenPointForParameter:11].x, 0.1, 1e-12);
	XCTAssertEqualWithAccuracy([self writtenPointForParameter:11].y, 0.1, 1e-12);
	XCTAssertEqualWithAccuracy([self writtenPointForParameter:12].x, 0.6, 1e-12, @"the opposite corner holds");

	[self stagePoint:NSMakePoint(0.2, 0.2) forParameter:11];
	[self stagePoint:NSMakePoint(0.6, 0.6) forParameter:12];
	FxGripOSCRectCornerPart *upperLeft = [FxGripOSCRectCornerPart partWithID:2
																	 corner:FxGripOSCRectCornerUpperLeft
													   lowerLeftParameterID:11
													  upperRightParameterID:12];
	[self.control addPart:upperLeft];
	XCTAssertTrue([upperLeft dragToObjectPoint:CGPointMake(0.1, 0.7) objectDelta:CGPointZero
									 modifiers:0 atTime:FxGripOSCTestTime()]);
	XCTAssertEqualWithAccuracy([self writtenPointForParameter:11].x, 0.1, 1e-12, @"the pointer's x");
	XCTAssertEqualWithAccuracy([self writtenPointForParameter:11].y, 0.2, 1e-12, @"the bottom holds");
	XCTAssertEqualWithAccuracy([self writtenPointForParameter:12].y, 0.7, 1e-12, @"the pointer's y");
	XCTAssertEqualWithAccuracy([self writtenPointForParameter:12].x, 0.6, 1e-12, @"the right edge holds");
}

/*! @abstract Option-dragging a left-hand rectangle corner mirrors the opposite corner through the center. */
- (void)testOptionDraggingTheLeftRectangleCornersMirrorsTheOppositeCorner
{
	[self stagePoint:NSMakePoint(0.2, 0.2) forParameter:11];
	[self stagePoint:NSMakePoint(0.6, 0.6) forParameter:12];
	FxGripOSCRectCornerPart *lowerLeft = [FxGripOSCRectCornerPart partWithID:1
																	 corner:FxGripOSCRectCornerLowerLeft
													   lowerLeftParameterID:11
													  upperRightParameterID:12];
	[self.control addPart:lowerLeft];

	XCTAssertTrue([lowerLeft dragToObjectPoint:CGPointMake(0.1, 0.1) objectDelta:CGPointZero
									 modifiers:kFxModifierKey_OPTION atTime:FxGripOSCTestTime()]);
	XCTAssertEqualWithAccuracy([self writtenPointForParameter:11].x, 0.1, 1e-12);
	XCTAssertEqualWithAccuracy([self writtenPointForParameter:12].x, 0.7, 1e-12, @"mirrored about the center");
	XCTAssertEqualWithAccuracy([self writtenPointForParameter:12].y, 0.7, 1e-12);

	[self stagePoint:NSMakePoint(0.2, 0.2) forParameter:11];
	[self stagePoint:NSMakePoint(0.6, 0.6) forParameter:12];
	FxGripOSCRectCornerPart *upperLeft = [FxGripOSCRectCornerPart partWithID:2
																	 corner:FxGripOSCRectCornerUpperLeft
													   lowerLeftParameterID:11
													  upperRightParameterID:12];
	[self.control addPart:upperLeft];
	XCTAssertTrue([upperLeft dragToObjectPoint:CGPointMake(0.1, 0.7) objectDelta:CGPointZero
									 modifiers:kFxModifierKey_OPTION atTime:FxGripOSCTestTime()]);
	XCTAssertEqualWithAccuracy([self writtenPointForParameter:11].x, 0.1, 1e-12);
	XCTAssertEqualWithAccuracy([self writtenPointForParameter:11].y, 0.1, 1e-12, @"mirrored about the center");
	XCTAssertEqualWithAccuracy([self writtenPointForParameter:12].x, 0.7, 1e-12);
	XCTAssertEqualWithAccuracy([self writtenPointForParameter:12].y, 0.7, 1e-12);
}

/*! @abstract Dragging a box corner anchors the diagonally opposite corner and shifts the center for every corner. */
- (void)testDraggingEachBoxCornerAnchorsTheOppositeCorner
{
	[self stageSquareBox];
	FxGripOSCBoxCornerPart *lowerLeft = [FxGripOSCBoxCornerPart partWithID:1
																   corner:FxGripOSCRectCornerLowerLeft
														centerParameterID:21
														 widthParameterID:22
														heightParameterID:23
														 angleParameterID:24];
	[self.control addPart:lowerLeft];

	XCTAssertTrue([lowerLeft dragToObjectPoint:CGPointMake(0.1, 0.25) objectDelta:CGPointZero
									 modifiers:0 atTime:FxGripOSCTestTime()]);
	XCTAssertEqualWithAccuracy(self.manager.paramGetAPIv6.floats[@(22)].doubleValue, 50.0, 1e-9,
							   @"the width from the anchored upper-right corner");
	XCTAssertEqualWithAccuracy(self.manager.paramGetAPIv6.floats[@(23)].doubleValue, 25.0, 1e-9);
	XCTAssertEqualWithAccuracy([self writtenPointForParameter:21].x, 0.35, 1e-9, @"the center shifts");
	XCTAssertEqualWithAccuracy([self writtenPointForParameter:21].y, 0.375, 1e-9);

	[self stageSquareBox];
	FxGripOSCBoxCornerPart *upperLeft = [FxGripOSCBoxCornerPart partWithID:2
																   corner:FxGripOSCRectCornerUpperLeft
														centerParameterID:21
														 widthParameterID:22
														heightParameterID:23
														 angleParameterID:24];
	[self.control addPart:upperLeft];
	XCTAssertTrue([upperLeft dragToObjectPoint:CGPointMake(0.1, 0.55) objectDelta:CGPointZero
									 modifiers:0 atTime:FxGripOSCTestTime()]);
	XCTAssertEqualWithAccuracy(self.manager.paramGetAPIv6.floats[@(22)].doubleValue, 50.0, 1e-9);
	XCTAssertEqualWithAccuracy(self.manager.paramGetAPIv6.floats[@(23)].doubleValue, 25.0, 1e-9);
	XCTAssertEqualWithAccuracy([self writtenPointForParameter:21].x, 0.35, 1e-9);
	XCTAssertEqualWithAccuracy([self writtenPointForParameter:21].y, 0.425, 1e-9);
}

/*! @abstract Option-dragging a box corner resizes about the fixed center and never writes the center. */
- (void)testOptionDraggingABoxCornerKeepsTheCenterFixed
{
	[self stageSquareBox];
	FxGripOSCBoxCornerPart *lowerLeft = [FxGripOSCBoxCornerPart partWithID:1
																   corner:FxGripOSCRectCornerLowerLeft
														centerParameterID:21
														 widthParameterID:22
														heightParameterID:23
														 angleParameterID:24];
	[self.control addPart:lowerLeft];
	NSUInteger writesBefore = self.manager.paramSetAPIv5.writes.count;

	XCTAssertTrue([lowerLeft dragToObjectPoint:CGPointMake(0.1, 0.25) objectDelta:CGPointZero
									 modifiers:kFxModifierKey_OPTION atTime:FxGripOSCTestTime()]);
	XCTAssertEqualWithAccuracy(self.manager.paramGetAPIv6.floats[@(22)].doubleValue, 60.0, 1e-9,
							   @"twice the pointer's local extent");
	XCTAssertEqualWithAccuracy(self.manager.paramGetAPIv6.floats[@(23)].doubleValue, 30.0, 1e-9);
	XCTAssertEqual(self.manager.paramSetAPIv5.writes.count - writesBefore, (NSUInteger)2,
				   @"only the width and the height are written");
	XCTAssertEqualWithAccuracy([self writtenPointForParameter:21].x, 0.4, 1e-12, @"the center is untouched");
}


#pragma mark Remaining branches

/*! @abstract The base control wraps the host API manager it was initialized with and starts with no parts. */
- (void)testTheBaseControlWrapsItsAPIManagerAndStartsEmpty
{
	FxGripOnScreenControl *plain = [[FxGripOnScreenControl alloc] initWithAPIManager:(id _Nonnull)nil];
	XCTAssertNotNil(plain.apiManager, @"the wrapped accessor is always published");
	XCTAssertEqual(plain.parts.count, (NSUInteger)0);
	XCTAssertEqual(plain.drawingCoordinates, kFxDrawingCoordinates_CANVAS);
}

/*! @abstract A modified drag with no active part asks no part whether it claims Option or Shift. */
- (void)testAModifiedDragWithNoActivePartClaimsNothing
{
	FxGripOSCRectCornerPart *corner = [FxGripOSCRectCornerPart partWithID:1
																  corner:FxGripOSCRectCornerLowerLeft
													lowerLeftParameterID:11
												   upperRightParameterID:12];
	[self.control addPart:corner];
	[self stagePoint:NSMakePoint(0.2, 0.2) forParameter:11];
	[self stagePoint:NSMakePoint(0.6, 0.6) forParameter:12];

	BOOL forceUpdate = YES;
	[self.control mouseDownAtPositionX:20 positionY:20 activePart:0 modifiers:0
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	[self.control mouseDraggedAtPositionX:30 positionY:40 activePart:0
								modifiers:(kFxModifierKey_OPTION | kFxModifierKey_SHIFT)
							  forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];

	XCTAssertFalse(forceUpdate);
	XCTAssertEqual(self.manager.paramSetAPIv5.writes.count, (NSUInteger)0);
}

/*! @abstract Dragging the upper-right rectangle corner writes it, and Option mirrors the lower-left one. */
- (void)testDraggingTheUpperRightRectangleCornerWritesIt
{
	[self stagePoint:NSMakePoint(0.2, 0.2) forParameter:11];
	[self stagePoint:NSMakePoint(0.6, 0.6) forParameter:12];
	FxGripOSCRectCornerPart *part = [FxGripOSCRectCornerPart partWithID:1
																corner:FxGripOSCRectCornerUpperRight
												  lowerLeftParameterID:11
												 upperRightParameterID:12];
	[self.control addPart:part];

	XCTAssertTrue([part dragToObjectPoint:CGPointMake(0.7, 0.7) objectDelta:CGPointZero
								modifiers:0 atTime:FxGripOSCTestTime()]);
	XCTAssertEqualWithAccuracy([self writtenPointForParameter:12].x, 0.7, 1e-12);
	XCTAssertEqualWithAccuracy([self writtenPointForParameter:11].x, 0.2, 1e-12, @"the opposite corner holds");

	[self stagePoint:NSMakePoint(0.2, 0.2) forParameter:11];
	[self stagePoint:NSMakePoint(0.6, 0.6) forParameter:12];
	XCTAssertTrue([part dragToObjectPoint:CGPointMake(0.7, 0.7) objectDelta:CGPointZero
								modifiers:kFxModifierKey_OPTION atTime:FxGripOSCTestTime()]);
	XCTAssertEqualWithAccuracy([self writtenPointForParameter:11].x, 0.1, 1e-12, @"mirrored about the center");
	XCTAssertEqualWithAccuracy([self writtenPointForParameter:11].y, 0.1, 1e-12);
}

/*! @abstract A rectangle whose corner parameters the host does not answer refuses a drag. */
- (void)testARectangleWithUnreadableCornersRefusesADrag
{
	FxGripOSCRectPart *part = [FxGripOSCRectPart partWithID:1 lowerLeftParameterID:97 upperRightParameterID:98];
	[self.control addPart:part];

	XCTAssertFalse([part dragToObjectPoint:CGPointZero objectDelta:CGPointMake(0.1, 0.0)
								 modifiers:0 atTime:FxGripOSCTestTime()]);
}

/*! @abstract A circle whose center the host does not answer draws nothing. */
- (void)testACircleWithNoCenterDrawsNothing
{
	FxGripOSCCirclePart *part = [FxGripOSCCirclePart partWithID:1 centerParameterID:97 radiusParameterID:98];
	[self.control addPart:part];

	FxGripOSCBeginPass(pass, CGSizeMake(80.0, 80.0));
	[self drawPart:part inPass:pass selected:NO];
	XCTAssertEqualWithAccuracy([self inkNear:CGPointMake(40.0, 40.0) inPass:pass], 0.0, 0.01);
}

/*! @abstract A rim handle and a rotation handle both need a radius even when the center reads. */
- (void)testTheRimHandlesNeedARadiusBesideTheCenter
{
	CMTime time = FxGripOSCTestTime();
	[self stagePoint:NSMakePoint(0.4, 0.4) forParameter:21];
	FxGripOSCCircleRadiusHandlePart *radiusHandle = [FxGripOSCCircleRadiusHandlePart partWithID:1
																			 centerParameterID:21
																			 radiusParameterID:98];
	[self.control addPart:radiusHandle];
	XCTAssertFalse([radiusHandle hitTestObjectPoint:CGPointZero canvasPoint:CGPointMake(40.0, 40.0) atTime:time]);

	self.manager.paramGetAPIv6.floats[@(23)] = @(0.0);
	FxGripOSCAngleDialPart *dial = [FxGripOSCAngleDialPart partWithID:2 centerParameterID:21 angleParameterID:98];
	[self.control addPart:dial];
	XCTAssertFalse([dial hitTestObjectPoint:CGPointZero canvasPoint:CGPointMake(40.0, 40.0) atTime:time],
				   @"the dial needs its angle as well as its center");
}

/*! @abstract Shift-dragging a box corner without Option locks the aspect ratio about the opposite corner. */
- (void)testShiftDraggingABoxCornerLocksTheAspectRatioAboutTheOppositeCorner
{
	[self stageSquareBox];
	FxGripOSCBoxCornerPart *upperRight = [FxGripOSCBoxCornerPart partWithID:1
																	corner:FxGripOSCRectCornerUpperRight
														 centerParameterID:21
														  widthParameterID:22
														 heightParameterID:23
														  angleParameterID:24];
	[self.control addPart:upperRight];

	// The box is 40 x 20 input pixels; the pointer sits 60 px across and 10 px up from the
	// anchored lower-left corner, so the wider axis sets a scale of one and a half.
	XCTAssertTrue([upperRight dragToObjectPoint:CGPointMake(0.8, 0.4) objectDelta:CGPointZero
									  modifiers:kFxModifierKey_SHIFT atTime:FxGripOSCTestTime()]);
	XCTAssertEqualWithAccuracy(self.manager.paramGetAPIv6.floats[@(22)].doubleValue, 60.0, 1e-9);
	XCTAssertEqualWithAccuracy(self.manager.paramGetAPIv6.floats[@(23)].doubleValue, 30.0, 1e-9,
							   @"the height follows the locked aspect ratio");
	XCTAssertEqualWithAccuracy([self writtenPointForParameter:21].x, 0.5, 1e-9, @"the center shifts");
	XCTAssertEqualWithAccuracy([self writtenPointForParameter:21].y, 0.45, 1e-9);
}

/*! @abstract A HUD readout draws nothing when the text cannot be rasterized. */
- (void)testAHUDDrawsNothingWhenTheTextCannotBeRasterized
{
	self.control.suppressesTextTextures = YES;
	FxGripOSCHUDPart *part = [FxGripOSCHUDPart partWithID:1 text:@"88"];
	part.canvasAnchor = CGPointMake(20.0, 60.0);
	part.backgroundColor = (simd_float4){ 0.0f, 0.0f, 0.0f, 0.0f };
	[self.control addPart:part];

	FxGripOSCBeginPass(pass, CGSizeMake(80.0, 80.0));
	[self drawPart:part inPass:pass selected:NO];
	XCTAssertEqualWithAccuracy([self inkNear:CGPointMake(24.0, 56.0) inPass:pass], 0.0, 0.01);
	XCTAssertNil(part.cachedTexture);
	XCTAssertNil(part.cachedKey, @"a failed rasterization caches no key");
}

@end
