//
//  FxGripOnScreenControlTests.m
//  FxGripTests
//
//  Unit tests for FxGripOnScreenControl and the stock OSC parts: coordinate
//  conversion, part hit-testing and ordering, the mouse-event drag routing, and
//  the parameter writes the drags produce.
//
//  The control under test is a local subclass whose apiManager getter returns a
//  stub manager, the FxGripTileableEffectCategoriesTests convention. The stub OSC
//  API maps canvas to object space by a uniform scale of 100, so canvas (40, 40)
//  is object (0.4, 0.4). GPU drawing is not exercised; the geometry helpers are.
//

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripOnScreenControl.h>
#import <FxGrip/FxGripOSCPart.h>
#import <FxGrip/FxGripPointListData.h>

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
@end

@implementation FxGripOSCTestControl

- (id<FxGripAPIAccessing>)apiManager
{
	return (id<FxGripAPIAccessing>)self.stubAPIManager;
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

- (void)testTheStandardColorsMatchTheHostConventions
{
	XCTAssertEqual(kFxGripOSCUnselectedFillColor.w, 0.25f);
	XCTAssertEqual(kFxGripOSCSelectedFillColor.w, 0.5f);
	XCTAssertEqual(kFxGripOSCOutlineColor.x, 1.0f);
	XCTAssertEqual(kFxGripOSCShadowColor.w, 1.0f);
}

- (void)testTheDrawingCoordinatesDefaultToCanvas
{
	XCTAssertEqual(self.control.drawingCoordinates, kFxDrawingCoordinates_CANVAS);
}

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

- (void)testARectPartHitsInsideAndMissesOutside
{
	[self stagedRectPartWithID:1];

	XCTAssertEqual([self hitTestAtCanvasX:40 y:40], (NSInteger)1);
	XCTAssertEqual([self hitTestAtCanvasX:70 y:40], (NSInteger)0);
}

- (void)testTheLastAddedPartWinsAnOverlappingHit
{
	[self stagedRectPartWithID:1];
	FxGripOSCRectPart *top = [FxGripOSCRectPart partWithID:2
									  lowerLeftParameterID:11
									 upperRightParameterID:12];
	[self.control addPart:top];

	XCTAssertEqual([self hitTestAtCanvasX:40 y:40], (NSInteger)2);
}

- (void)testAPointHandleHitsByCanvasDistance
{
	[self stagePoint:NSMakePoint(0.5, 0.5) forParameter:21];
	FxGripOSCPointHandlePart *handle = [FxGripOSCPointHandlePart partWithID:3 parameterID:21];
	[self.control addPart:handle];

	XCTAssertEqual([self hitTestAtCanvasX:55 y:50], (NSInteger)3,
				   @"5 canvas pixels away is inside the default 10-pixel hit radius");
	XCTAssertEqual([self hitTestAtCanvasX:70 y:50], (NSInteger)0);
}

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

- (void)testTheAngleDialTipHitsAtTheSpokeTip
{
	[self stageDialWithRadiansPerUnit:1.0 angleValue:0.0];

	// Angle 0 with the default 40-pixel spoke puts the tip at canvas (90, 50).
	XCTAssertEqual([self hitTestAtCanvasX:92 y:50], (NSInteger)9);
	XCTAssertEqual([self hitTestAtCanvasX:60 y:50], (NSInteger)0);
}

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

- (void)testAnOpenPolylineHasNoWrapSegment
{
	NSArray<NSNumber *> *chain = [self stageSquareChain];
	[self.control addPart:[FxGripOSCPolylinePart partWithID:20 pointParameterIDs:chain closed:NO]];

	XCTAssertEqual([self hitTestAtCanvasX:40 y:20], (NSInteger)20);
	XCTAssertEqual([self hitTestAtCanvasX:20 y:40], (NSInteger)0);
}

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

- (void)testABoxHitsInsideItsRotatedFrame
{
	[self stageBoxWithAngle:M_PI_2];
	[self.control addPart:[self boxBodyPart]];

	// Rotated 90 degrees, the 80 x 40 pixel box extends 40 pixels vertically.
	XCTAssertEqual([self hitTestAtCanvasX:50 y:85], (NSInteger)30);
	XCTAssertEqual([self hitTestAtCanvasX:65 y:50], (NSInteger)0,
				   @"30 pixels along x is inside the unrotated box but outside the rotated one");
}

- (void)testABoxWithoutAnAngleStaysAxisAligned
{
	[self stageBoxWithAngle:0.0];
	[self.control addPart:[self boxBodyPart]];

	XCTAssertEqual([self hitTestAtCanvasX:65 y:50], (NSInteger)30);
	XCTAssertEqual([self hitTestAtCanvasX:50 y:85], (NSInteger)0);
}

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

#pragma mark Bézier chains

/*!
	A two-vertex chain on 71/72 with tangents 75-78 bowing the segment upward:
	canvas control polygon (20,20) - (33,47) - (47,47) - (60,20).
*/
- (FxGripOSCPolylinePart *)stageBezierChain
{
	[self stagePoint:NSMakePoint(0.2, 0.2) forParameter:71];
	[self stagePoint:NSMakePoint(0.6, 0.2) forParameter:72];
	[self stagePoint:NSMakePoint(0.2, 0.2) forParameter:75];
	[self stagePoint:NSMakePoint(0.33, 0.47) forParameter:76];
	[self stagePoint:NSMakePoint(0.47, 0.47) forParameter:77];
	[self stagePoint:NSMakePoint(0.6, 0.2) forParameter:78];

	FxGripOSCPolylinePart *part = [FxGripOSCPolylinePart partWithID:20
												  pointParameterIDs:@[@71, @72]
															 closed:NO];
	part.inTangentParameterIDs = @[@75, @77];
	part.outTangentParameterIDs = @[@76, @78];
	return part;
}

- (void)testABezierChainCurvesAwayFromTheStraightLine
{
	[self.control addPart:[self stageBezierChain]];

	XCTAssertEqual([self hitTestAtCanvasX:40 y:40], (NSInteger)20,
				   @"the curve's midpoint sits near canvas (40, 40)");
	XCTAssertEqual([self hitTestAtCanvasX:40 y:20], (NSInteger)0,
				   @"the straight chord is no longer on the curve");
}

- (void)testMismatchedTangentArraysFallBackToStraightSegments
{
	FxGripOSCPolylinePart *part = [self stageBezierChain];
	part.inTangentParameterIDs = @[@75];
	[self.control addPart:part];

	XCTAssertEqual([self hitTestAtCanvasX:40 y:20], (NSInteger)20);
}

- (void)testABezierBodyDragCarriesTheTangents
{
	[self.control addPart:[self stageBezierChain]];
	BOOL forceUpdate = NO;

	[self.control mouseDownAtPositionX:40 positionY:40 activePart:20 modifiers:0
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	[self.control mouseDraggedAtPositionX:50 positionY:50 activePart:20 modifiers:0
							  forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];

	XCTAssertTrue(forceUpdate);
	NSArray<NSDictionary *> *writes = self.manager.paramSetAPIv5.writes;
	XCTAssertEqual(writes.count, (NSUInteger)6, @"two vertices and four tangents move together");
	XCTAssertEqualObjects(writes[2][@"parameter"], @75);
	XCTAssertEqualWithAccuracy([writes[2][@"x"] doubleValue], 0.3, 1e-9);
	XCTAssertEqualWithAccuracy([writes[2][@"y"] doubleValue], 0.3, 1e-9);
}

- (void)testABezierVertexHandleCarriesItsTangents
{
	[self stageBezierChain];
	[self.control addPart:[FxGripOSCBezierVertexHandlePart partWithID:25
													vertexParameterID:71
												 inTangentParameterID:75
												outTangentParameterID:76]];
	BOOL forceUpdate = NO;

	XCTAssertEqual([self hitTestAtCanvasX:20 y:20], (NSInteger)25);
	[self.control mouseDownAtPositionX:20 positionY:20 activePart:25 modifiers:0
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	[self.control mouseDraggedAtPositionX:30 positionY:30 activePart:25 modifiers:0
							  forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];

	XCTAssertTrue(forceUpdate);
	NSArray<NSDictionary *> *writes = self.manager.paramSetAPIv5.writes;
	XCTAssertEqual(writes.count, (NSUInteger)3);
	XCTAssertEqualObjects(writes[0][@"parameter"], @71);
	XCTAssertEqualWithAccuracy([writes[0][@"x"] doubleValue], 0.3, 1e-9);
	XCTAssertEqualObjects(writes[2][@"parameter"], @76);
	XCTAssertEqualWithAccuracy([writes[2][@"x"] doubleValue], 0.43, 1e-9,
							   @"the out tangent moves by the vertex's delta");
	XCTAssertEqualWithAccuracy([writes[2][@"y"] doubleValue], 0.57, 1e-9);
}

- (void)testATangentHandleMirrorsTheOppositeTangent
{
	[self stagePoint:NSMakePoint(0.5, 0.5) forParameter:61];
	[self stagePoint:NSMakePoint(0.6, 0.6) forParameter:62];
	[self stagePoint:NSMakePoint(0.5, 0.7) forParameter:63];
	FxGripOSCTangentHandlePart *handle = [FxGripOSCTangentHandlePart partWithID:26
																vertexParameterID:61
															   tangentParameterID:62];
	handle.oppositeTangentParameterID = 63;
	[self.control addPart:handle];
	BOOL forceUpdate = NO;

	[self.control mouseDownAtPositionX:60 positionY:60 activePart:26 modifiers:0
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	[self.control mouseDraggedAtPositionX:70 positionY:50 activePart:26 modifiers:0
							  forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];

	XCTAssertTrue(forceUpdate);
	NSArray<NSDictionary *> *writes = self.manager.paramSetAPIv5.writes;
	XCTAssertEqual(writes.count, (NSUInteger)2);
	XCTAssertEqualObjects(writes[0][@"parameter"], @62);
	XCTAssertEqualWithAccuracy([writes[0][@"x"] doubleValue], 0.7, 1e-9);
	// The opposite keeps its 20-pixel length, rotated collinear with the drag.
	XCTAssertEqualObjects(writes[1][@"parameter"], @63);
	XCTAssertEqualWithAccuracy([writes[1][@"x"] doubleValue], 0.4, 1e-9);
	XCTAssertEqualWithAccuracy([writes[1][@"y"] doubleValue], 0.5, 1e-9);
}

- (void)testOptionBreaksTheTangentPair
{
	[self stagePoint:NSMakePoint(0.5, 0.5) forParameter:61];
	[self stagePoint:NSMakePoint(0.6, 0.6) forParameter:62];
	[self stagePoint:NSMakePoint(0.5, 0.7) forParameter:63];
	FxGripOSCTangentHandlePart *handle = [FxGripOSCTangentHandlePart partWithID:26
																vertexParameterID:61
															   tangentParameterID:62];
	handle.oppositeTangentParameterID = 63;
	[self.control addPart:handle];
	BOOL forceUpdate = NO;

	[self.control mouseDownAtPositionX:60 positionY:60 activePart:26 modifiers:kFxModifierKey_OPTION
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	[self.control mouseDraggedAtPositionX:70 positionY:50 activePart:26 modifiers:kFxModifierKey_OPTION
							  forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];

	NSArray<NSDictionary *> *writes = self.manager.paramSetAPIv5.writes;
	XCTAssertEqual(writes.count, (NSUInteger)1, @"only the dragged tangent moves");
	XCTAssertEqualObjects(writes[0][@"parameter"], @62);
	// The tangent claims Option for its break gesture, so the base does not slow it: full distance.
	XCTAssertEqualWithAccuracy([writes[0][@"x"] doubleValue], 0.7, 1e-9);
	XCTAssertEqualWithAccuracy([writes[0][@"y"] doubleValue], 0.5, 1e-9);
}

- (void)testSymmetricMirroringMatchesTheDraggedLength
{
	[self stagePoint:NSMakePoint(0.5, 0.5) forParameter:61];
	[self stagePoint:NSMakePoint(0.6, 0.6) forParameter:62];
	[self stagePoint:NSMakePoint(0.5, 0.7) forParameter:63];
	FxGripOSCTangentHandlePart *handle = [FxGripOSCTangentHandlePart partWithID:26
																vertexParameterID:61
															   tangentParameterID:62];
	handle.oppositeTangentParameterID = 63;
	handle.mirroring = FxGripOSCTangentMirroringSymmetric;
	[self.control addPart:handle];
	BOOL forceUpdate = NO;

	[self.control mouseDownAtPositionX:60 positionY:60 activePart:26 modifiers:0
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	[self.control mouseDraggedAtPositionX:70 positionY:50 activePart:26 modifiers:0
							  forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];

	NSArray<NSDictionary *> *writes = self.manager.paramSetAPIv5.writes;
	XCTAssertEqual(writes.count, (NSUInteger)2);
	XCTAssertEqualObjects(writes[0][@"parameter"], @62);
	// The opposite matches the dragged 40-pixel length, so it moves twice as far as aligned did.
	XCTAssertEqualObjects(writes[1][@"parameter"], @63);
	XCTAssertEqualWithAccuracy([writes[1][@"x"] doubleValue], 0.3, 1e-9);
	XCTAssertEqualWithAccuracy([writes[1][@"y"] doubleValue], 0.5, 1e-9);
}

- (void)testShiftSnapsATangentToFortyFiveDegreesAboutTheVertex
{
	[self stagePoint:NSMakePoint(0.5, 0.5) forParameter:61];
	[self stagePoint:NSMakePoint(0.6, 0.6) forParameter:62];
	FxGripOSCTangentHandlePart *handle = [FxGripOSCTangentHandlePart partWithID:26
																vertexParameterID:61
															   tangentParameterID:62];
	[self.control addPart:handle];
	BOOL forceUpdate = NO;

	// A mostly-horizontal drag: pixel offset (40, 5) snaps to the horizontal axis, length kept.
	[self.control mouseDownAtPositionX:60 positionY:60 activePart:26 modifiers:kFxModifierKey_SHIFT
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	[self.control mouseDraggedAtPositionX:70 positionY:55 activePart:26 modifiers:kFxModifierKey_SHIFT
							  forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];

	NSArray<NSDictionary *> *writes = self.manager.paramSetAPIv5.writes;
	XCTAssertEqual(writes.count, (NSUInteger)1, @"no opposite tangent to mirror");
	XCTAssertEqualObjects(writes[0][@"parameter"], @62);
	double tx = [writes[0][@"x"] doubleValue], ty = [writes[0][@"y"] doubleValue];
	XCTAssertEqualWithAccuracy(ty, 0.5, 1e-9, @"the tangent snaps onto the vertex's horizontal");
	XCTAssertGreaterThan(tx, 0.5, @"and keeps the drag's positive direction");
	double inputLength = hypot(0.2 * 200.0, 0.05 * 100.0);
	double snappedLength = hypot((tx - 0.5) * 200.0, (ty - 0.5) * 100.0);
	XCTAssertEqualWithAccuracy(snappedLength, inputLength, 1e-9, @"the handle keeps its length");
}

- (void)testCommandClickRetractsATangentOntoItsVertex
{
	[self stagePoint:NSMakePoint(0.5, 0.5) forParameter:61];
	[self stagePoint:NSMakePoint(0.6, 0.6) forParameter:62];
	FxGripOSCTangentHandlePart *handle = [FxGripOSCTangentHandlePart partWithID:26
																vertexParameterID:61
															   tangentParameterID:62];
	[self.control addPart:handle];
	BOOL forceUpdate = NO;

	[self.control mouseDownAtPositionX:60 positionY:60 activePart:26 modifiers:kFxModifierKey_COMMAND
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];

	XCTAssertTrue(forceUpdate);
	NSArray<NSDictionary *> *writes = self.manager.paramSetAPIv5.writes;
	XCTAssertEqual(writes.count, (NSUInteger)1);
	XCTAssertEqualObjects(writes[0][@"parameter"], @62);
	XCTAssertEqualWithAccuracy([writes[0][@"x"] doubleValue], 0.5, 1e-9, @"the tangent sits on the vertex");
	XCTAssertEqualWithAccuracy([writes[0][@"y"] doubleValue], 0.5, 1e-9);
}

- (void)testDoubleClickTogglesASmoothVertexToACorner
{
	[self stagePoint:NSMakePoint(0.2, 0.2) forParameter:71];
	[self stagePoint:NSMakePoint(0.1, 0.2) forParameter:75];
	[self stagePoint:NSMakePoint(0.33, 0.47) forParameter:76];
	[self.control addPart:[FxGripOSCBezierVertexHandlePart partWithID:25
													vertexParameterID:71
												 inTangentParameterID:75
												outTangentParameterID:76]];
	BOOL forceUpdate = NO;

	[self.control mouseDownAtPositionX:20 positionY:20 activePart:25 modifiers:0
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	[self.control mouseDownAtPositionX:20 positionY:20 activePart:25 modifiers:0
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];

	XCTAssertTrue(forceUpdate, @"the second click toggles the vertex");
	NSArray<NSDictionary *> *writes = self.manager.paramSetAPIv5.writes;
	XCTAssertEqual(writes.count, (NSUInteger)2, @"both tangents retract onto the vertex");
	for (NSDictionary *write in writes) {
		XCTAssertEqualWithAccuracy([write[@"x"] doubleValue], 0.2, 1e-9);
		XCTAssertEqualWithAccuracy([write[@"y"] doubleValue], 0.2, 1e-9);
	}
}

- (void)testDoubleClickTogglesACornerVertexToSmoothAlongItsNeighbors
{
	[self stagePoint:NSMakePoint(0.2, 0.4) forParameter:70];
	[self stagePoint:NSMakePoint(0.4, 0.4) forParameter:71];
	[self stagePoint:NSMakePoint(0.6, 0.4) forParameter:72];
	// A corner vertex: both tangents sit on it.
	[self stagePoint:NSMakePoint(0.4, 0.4) forParameter:75];
	[self stagePoint:NSMakePoint(0.4, 0.4) forParameter:76];
	FxGripOSCBezierVertexHandlePart *handle = [FxGripOSCBezierVertexHandlePart partWithID:25
																	   vertexParameterID:71
																	inTangentParameterID:75
																   outTangentParameterID:76];
	handle.previousVertexParameterID = 70;
	handle.nextVertexParameterID = 72;
	[self.control addPart:handle];
	BOOL forceUpdate = NO;

	[self.control mouseDownAtPositionX:40 positionY:40 activePart:25 modifiers:0
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	[self.control mouseDownAtPositionX:40 positionY:40 activePart:25 modifiers:0
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];

	XCTAssertTrue(forceUpdate);
	NSArray<NSDictionary *> *writes = self.manager.paramSetAPIv5.writes;
	XCTAssertEqual(writes.count, (NSUInteger)2);
	// The neighbor span is 80 pixels wide; a sixth of it is the handle offset, along +x.
	double offset = (80.0 / 6.0) / 200.0;
	XCTAssertEqualObjects(writes[0][@"parameter"], @76);
	XCTAssertEqualWithAccuracy([writes[0][@"x"] doubleValue], 0.4 + offset, 1e-9, @"the out tangent leads");
	XCTAssertEqualWithAccuracy([writes[0][@"y"] doubleValue], 0.4, 1e-9);
	XCTAssertEqualObjects(writes[1][@"parameter"], @75);
	XCTAssertEqualWithAccuracy([writes[1][@"x"] doubleValue], 0.4 - offset, 1e-9, @"the in tangent trails");
	XCTAssertEqualWithAccuracy([writes[1][@"y"] doubleValue], 0.4, 1e-9);
}

- (void)testAClosedBezierChainCurvesItsWrapSegment
{
	// Two vertices closed into a lens: the forward segment bows up through
	// (33,47)-(47,47); the wrap segment bows down through (47,-7)-(33,-7).
	[self stagePoint:NSMakePoint(0.2, 0.2) forParameter:71];
	[self stagePoint:NSMakePoint(0.6, 0.2) forParameter:72];
	[self stagePoint:NSMakePoint(0.33, -0.07) forParameter:75];
	[self stagePoint:NSMakePoint(0.33, 0.47) forParameter:76];
	[self stagePoint:NSMakePoint(0.47, 0.47) forParameter:77];
	[self stagePoint:NSMakePoint(0.47, -0.07) forParameter:78];

	FxGripOSCPolylinePart *part = [FxGripOSCPolylinePart partWithID:20
												  pointParameterIDs:@[@71, @72]
															 closed:YES];
	part.inTangentParameterIDs = @[@75, @77];
	part.outTangentParameterIDs = @[@76, @78];
	[self.control addPart:part];

	XCTAssertEqual([self hitTestAtCanvasX:40 y:40], (NSInteger)20,
				   @"the forward segment's crown");
	XCTAssertEqual([self hitTestAtCanvasX:40 y:0], (NSInteger)20,
				   @"the wrap segment curves back through its own tangents");
	XCTAssertEqual([self hitTestAtCanvasX:40 y:20], (NSInteger)0,
				   @"the straight chord lies between the two arcs");
}

- (void)testTheClosedBezierCompositeKeepsEveryTangentHandle
{
	NSArray<FxGripOSCPart *> *parts =
		[FxGripOSCPolylinePart bezierPartsWithOptions:FxGripOSCShapeOptionsAll
										  firstPartID:20
									pointParameterIDs:@[@71, @72, @73]
								inTangentParameterIDs:@[@75, @77, @79]
							   outTangentParameterIDs:@[@76, @78, @80]
											   closed:YES];

	XCTAssertEqual(parts.count, (NSUInteger)10,
				   @"the body, three vertex handles, and all six tangent handles");
	FxGripOSCTangentHandlePart *first = (FxGripOSCTangentHandlePart *)parts[4];
	XCTAssertEqual(first.tangentParameterID, (FxParameterId)75,
				   @"a closed chain's first vertex keeps its in tangent");
}

- (void)testTheBezierCompositeSkipsUnusedOpenTangents
{
	NSArray<FxGripOSCPart *> *parts =
		[FxGripOSCPolylinePart bezierPartsWithOptions:FxGripOSCShapeOptionsAll
										  firstPartID:20
									pointParameterIDs:@[@71, @72, @73]
								inTangentParameterIDs:@[@75, @77, @79]
							   outTangentParameterIDs:@[@76, @78, @80]
											   closed:NO];

	// Body, three vertex handles, then tangents skipping in_0 and out_2.
	XCTAssertEqual(parts.count, (NSUInteger)8);
	XCTAssertEqual(parts.lastObject.partID, (NSInteger)27);
	XCTAssertTrue([parts[1] isKindOfClass:FxGripOSCBezierVertexHandlePart.class]);
	XCTAssertTrue([parts[4] isKindOfClass:FxGripOSCTangentHandlePart.class]);
	FxGripOSCTangentHandlePart *first = (FxGripOSCTangentHandlePart *)parts[4];
	XCTAssertEqual(first.tangentParameterID, (FxParameterId)76,
				   @"the open chain's first tangent handle is vertex 0's out tangent");
	FxGripOSCTangentHandlePart *last = (FxGripOSCTangentHandlePart *)parts.lastObject;
	XCTAssertEqual(last.tangentParameterID, (FxParameterId)79,
				   @"the open chain's last tangent handle is the final vertex's in tangent");
}

#pragma mark Flag composition

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

- (void)testMouseMovedOverNoPartUsesTheArrow
{
	[self stagedRectPartWithID:5];

	BOOL forceUpdate = NO;
	[self.control mouseMovedAtPositionX:0 positionY:0 activePart:0 modifiers:0
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];

	XCTAssertEqualObjects(self.manager.onScreenControlAPIv4.lastCursor, [self cursor:@selector(arrowCursor)]);
}

- (void)testAPartWithoutACursorFallsBackToTheArrow
{
	[self stagedRectPartWithID:5];   // no cursor set on the part

	BOOL forceUpdate = NO;
	[self.control mouseMovedAtPositionX:0 positionY:0 activePart:5 modifiers:0
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];

	XCTAssertEqualObjects(self.manager.onScreenControlAPIv4.lastCursor, [self cursor:@selector(arrowCursor)]);
}

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

- (void)testTheCurvePartConstructorSetsItsProperties
{
	FxGripOSCCurvePart *curve = [FxGripOSCCurvePart partWithID:7 pointParameterIDs:@[@1, @2, @3] closed:YES];

	XCTAssertEqual(curve.partID, (NSInteger)7);
	XCTAssertEqualObjects(curve.pointParameterIDs, (@[@1, @2, @3]));
	XCTAssertTrue(curve.closed);
	XCTAssertTrue(curve.shadowed, @"a curve strokes with a shadow by default");
}

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

- (void)testTheHUDPartBlockConstructorStoresItsBlock
{
	FxGripOSCHUDPart *hud = [FxGripOSCHUDPart partWithID:6 textBlock:^NSString *(CMTime time) {
		return @"frame";
	}];

	XCTAssertEqual(hud.partID, (NSInteger)6);
	XCTAssertNotNil(hud.textBlock);
}

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

#pragma mark Editable polygon

/*! A closed triangle at object (0.2,0.2), (0.6,0.2), (0.6,0.6) staged in a custom parameter. */
- (FxGripPointListData *)stageTriangleForParameter:(UInt32)parameterID
{
	CGPoint points[3] = { CGPointMake(0.2, 0.2), CGPointMake(0.6, 0.2), CGPointMake(0.6, 0.6) };
	FxGripPointListData *list = [FxGripPointListData pointListWithPoints:points count:3 closed:YES];
	self.manager.paramGetAPIv6.customs[@(parameterID)] = list;
	return list;
}

- (FxGripPointListData *)stagedListForParameter:(UInt32)parameterID
{
	return self.manager.paramGetAPIv6.customs[@(parameterID)];
}

- (void)testEditablePolygonSelectsAVertexOnClick
{
	[self stageTriangleForParameter:30];
	FxGripOSCEditablePolygonPart *poly = [FxGripOSCEditablePolygonPart partWithID:3 pointListParameterID:30];
	[self.control addPart:poly];

	NSInteger active = [self hitTestAtCanvasX:20 y:20];
	XCTAssertEqual(active, (NSInteger)3);
	BOOL forceUpdate = NO;
	[self.control mouseDownAtPositionX:20 positionY:20 activePart:active modifiers:0 forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	XCTAssertEqual(poly.selectedVertexIndex, (NSInteger)0);
}

- (void)testEditablePolygonDragMovesTheSelectedVertex
{
	[self stageTriangleForParameter:30];
	FxGripOSCEditablePolygonPart *poly = [FxGripOSCEditablePolygonPart partWithID:3 pointListParameterID:30];
	[self.control addPart:poly];

	NSInteger active = [self hitTestAtCanvasX:20 y:20];
	BOOL forceUpdate = NO;
	[self.control mouseDownAtPositionX:20 positionY:20 activePart:active modifiers:0 forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	[self.control mouseDraggedAtPositionX:30 positionY:30 activePart:active modifiers:0 forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];

	FxGripPointListData *updated = [self stagedListForParameter:30];
	XCTAssertEqual(updated.count, (NSUInteger)3);
	CGPoint moved = [updated pointAtIndex:0];
	XCTAssertEqualWithAccuracy(moved.x, 0.3, 1e-9);
	XCTAssertEqualWithAccuracy(moved.y, 0.3, 1e-9);
	XCTAssertEqualWithAccuracy([updated pointAtIndex:1].x, 0.6, 1e-9, @"the other vertices are unchanged");
}

- (void)testEditablePolygonBodyDragTranslatesEveryVertex
{
	[self stageTriangleForParameter:30];
	FxGripOSCEditablePolygonPart *poly = [FxGripOSCEditablePolygonPart partWithID:3 pointListParameterID:30];
	[self.control addPart:poly];

	// Segment 0's midpoint is canvas (40, 20); a plain click there selects no vertex.
	NSInteger active = [self hitTestAtCanvasX:40 y:20];
	XCTAssertEqual(active, (NSInteger)3);
	BOOL forceUpdate = NO;
	[self.control mouseDownAtPositionX:40 positionY:20 activePart:active modifiers:0 forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	XCTAssertEqual(poly.selectedVertexIndex, (NSInteger)-1);
	[self.control mouseDraggedAtPositionX:50 positionY:30 activePart:active modifiers:0 forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];

	FxGripPointListData *updated = [self stagedListForParameter:30];
	XCTAssertEqual(updated.count, (NSUInteger)3);
	XCTAssertEqualWithAccuracy([updated pointAtIndex:0].x, 0.3, 1e-9);
	XCTAssertEqualWithAccuracy([updated pointAtIndex:0].y, 0.3, 1e-9);
	XCTAssertEqualWithAccuracy([updated pointAtIndex:2].x, 0.7, 1e-9);
}

- (void)testEditablePolygonInsertsAVertexOnOptionSegmentClick
{
	[self stageTriangleForParameter:30];
	FxGripOSCEditablePolygonPart *poly = [FxGripOSCEditablePolygonPart partWithID:3 pointListParameterID:30];
	[self.control addPart:poly];

	NSInteger active = [self hitTestAtCanvasX:40 y:20];
	BOOL forceUpdate = NO;
	[self.control mouseDownAtPositionX:40 positionY:20 activePart:active modifiers:kFxModifierKey_OPTION forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	XCTAssertTrue(forceUpdate);

	FxGripPointListData *updated = [self stagedListForParameter:30];
	XCTAssertEqual(updated.count, (NSUInteger)4);
	XCTAssertEqualWithAccuracy([updated pointAtIndex:1].x, 0.4, 1e-9);
	XCTAssertEqualWithAccuracy([updated pointAtIndex:1].y, 0.2, 1e-9);
	XCTAssertEqual(poly.selectedVertexIndex, (NSInteger)1);
}

- (void)testEditablePolygonPlainSegmentClickDoesNotInsert
{
	[self stageTriangleForParameter:30];
	FxGripOSCEditablePolygonPart *poly = [FxGripOSCEditablePolygonPart partWithID:3 pointListParameterID:30];
	[self.control addPart:poly];

	NSInteger active = [self hitTestAtCanvasX:40 y:20];
	BOOL forceUpdate = NO;
	[self.control mouseDownAtPositionX:40 positionY:20 activePart:active modifiers:0 forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];

	XCTAssertEqual([self stagedListForParameter:30].count, (NSUInteger)3);
}

- (void)testEditablePolygonDeletesTheSelectedVertex
{
	[self stageTriangleForParameter:30];
	FxGripOSCEditablePolygonPart *poly = [FxGripOSCEditablePolygonPart partWithID:3 pointListParameterID:30];
	[self.control addPart:poly];

	NSInteger active = [self hitTestAtCanvasX:60 y:60];
	BOOL forceUpdate = NO;
	[self.control mouseDownAtPositionX:60 positionY:60 activePart:active modifiers:0 forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	XCTAssertEqual(poly.selectedVertexIndex, (NSInteger)2);

	BOOL didHandle = NO;
	[self.control keyDownAtPositionX:60 positionY:60 keyPressed:127 modifiers:0 forceUpdate:&forceUpdate didHandle:&didHandle atTime:FxGripOSCTestTime()];
	XCTAssertTrue(didHandle);
	XCTAssertEqual([self stagedListForParameter:30].count, (NSUInteger)2);
	XCTAssertEqual(poly.selectedVertexIndex, (NSInteger)-1);
}

- (void)testEditablePolygonCommandClickDeletesAVertex
{
	[self stageTriangleForParameter:30];
	FxGripOSCEditablePolygonPart *poly = [FxGripOSCEditablePolygonPart partWithID:3 pointListParameterID:30];
	[self.control addPart:poly];

	NSInteger active = [self hitTestAtCanvasX:60 y:60];
	BOOL forceUpdate = NO;
	[self.control mouseDownAtPositionX:60 positionY:60 activePart:active modifiers:kFxModifierKey_COMMAND
						   forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];

	XCTAssertTrue(forceUpdate);
	XCTAssertEqual([self stagedListForParameter:30].count, (NSUInteger)2, @"Command-click removes the vertex");
	XCTAssertEqual(poly.selectedVertexIndex, (NSInteger)-1);
}

- (void)testEditablePolygonDeleteStopsAtTheMinimum
{
	CGPoint points[2] = { CGPointMake(0.2, 0.2), CGPointMake(0.6, 0.6) };
	self.manager.paramGetAPIv6.customs[@(30)] = [FxGripPointListData pointListWithPoints:points count:2 closed:NO];
	FxGripOSCEditablePolygonPart *poly = [FxGripOSCEditablePolygonPart partWithID:3 pointListParameterID:30];
	[self.control addPart:poly];

	NSInteger active = [self hitTestAtCanvasX:20 y:20];
	BOOL forceUpdate = NO;
	[self.control mouseDownAtPositionX:20 positionY:20 activePart:active modifiers:0 forceUpdate:&forceUpdate atTime:FxGripOSCTestTime()];
	XCTAssertEqual(poly.selectedVertexIndex, (NSInteger)0);

	BOOL didHandle = NO;
	[self.control keyDownAtPositionX:20 positionY:20 keyPressed:127 modifiers:0 forceUpdate:&forceUpdate didHandle:&didHandle atTime:FxGripOSCTestTime()];
	XCTAssertFalse(didHandle);
	XCTAssertEqual([self stagedListForParameter:30].count, (NSUInteger)2);
}

@end
