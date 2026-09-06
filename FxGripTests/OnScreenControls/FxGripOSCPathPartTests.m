//
//  FxGripOSCPathPartTests.m
//  FxGripTests
//
//  Unit tests for the unified FxGripOSCPathPart across both backings: the
//  custom-data FxGripPathData parameter (variable count, editable) and the
//  per-parameter location/tangent arrays (fixed count, keyframeable). The stub
//  OSC API maps canvas to object space by a uniform scale of 100, matching the
//  FxGripOnScreenControl test harness.
//

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripOnScreenControl.h>
#import <FxGrip/FxGripOSCPathPart.h>
#import <FxGrip/FxGripPathData.h>

static const double kPathTestCanvasPerObject = 100.0;

static CMTime FxGripPathPartTestTime(void)
{
	return (CMTime){.value = 1, .timescale = 24, .flags = kCMTimeFlags_Valid, .epoch = 0};
}

#pragma mark - Stubs

@interface FxGripPathTestOSCAPI : NSObject
@property (nonatomic, assign) NSRect stagedInputBounds;
@end

@implementation FxGripPathTestOSCAPI
- (instancetype)init
{
	self = [super init];
	if (self) {
		_stagedInputBounds = NSMakeRect(0, 0, 100, 100);
	}
	return self;
}
- (void)convertPointFromSpace:(FxDrawingCoordinates)fromSpace
						fromX:(double)fromX fromY:(double)fromY
					  toSpace:(FxDrawingCoordinates)toSpace
						  toX:(double *)toX toY:(double *)toY
{
	if (fromSpace == kFxDrawingCoordinates_CANVAS && toSpace == kFxDrawingCoordinates_OBJECT) {
		*toX = fromX / kPathTestCanvasPerObject;
		*toY = fromY / kPathTestCanvasPerObject;
	} else if (fromSpace == kFxDrawingCoordinates_OBJECT && toSpace == kFxDrawingCoordinates_CANVAS) {
		*toX = fromX * kPathTestCanvasPerObject;
		*toY = fromY * kPathTestCanvasPerObject;
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

@interface FxGripPathTestRetrievalAPI : NSObject
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSValue *> *points;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *floats;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, id> *customs;
@end

@implementation FxGripPathTestRetrievalAPI
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

@interface FxGripPathTestSettingAPI : NSObject
@property (nonatomic, weak) FxGripPathTestRetrievalAPI *retrieval;
@end

@implementation FxGripPathTestSettingAPI
- (BOOL)setXValue:(double)x YValue:(double)y toParameter:(UInt32)parameterID atTime:(CMTime)time
{
	self.retrieval.points[@(parameterID)] = [NSValue valueWithPoint:NSMakePoint(x, y)];
	return YES;
}
- (BOOL)setFloatValue:(double)value toParameter:(UInt32)parameterID atTime:(CMTime)time
{
	self.retrieval.floats[@(parameterID)] = @(value);
	return YES;
}
- (BOOL)setCustomParameterValue:(id)value toParameter:(UInt32)parameterID atTime:(CMTime)time
{
	self.retrieval.customs[@(parameterID)] = value;
	return YES;
}
@end

@interface FxGripPathTestAPIManager : NSObject
@property (nonatomic, strong) FxGripPathTestOSCAPI *onScreenControlAPIv4;
@property (nonatomic, strong) FxGripPathTestRetrievalAPI *paramGetAPIv6;
@property (nonatomic, strong) FxGripPathTestSettingAPI *paramSetAPIv5;
@end

@implementation FxGripPathTestAPIManager
@end

@interface FxGripPathTestControl : FxGripOnScreenControl
@property (nonatomic, strong) FxGripPathTestAPIManager *stubAPIManager;
@end

@implementation FxGripPathTestControl
- (id<FxGripAPIAccessing>)apiManager
{
	return (id<FxGripAPIAccessing>)self.stubAPIManager;
}
@end

#pragma mark - Tests

@interface FxGripOSCPathPartTests : XCTestCase
@property (nonatomic, strong) FxGripPathTestControl *control;
@property (nonatomic, strong) FxGripPathTestAPIManager *manager;
@end

@implementation FxGripOSCPathPartTests

- (void)setUp
{
	[super setUp];
	self.manager = FxGripPathTestAPIManager.new;
	self.manager.onScreenControlAPIv4 = FxGripPathTestOSCAPI.new;
	self.manager.paramGetAPIv6 = FxGripPathTestRetrievalAPI.new;
	self.manager.paramSetAPIv5 = FxGripPathTestSettingAPI.new;
	self.manager.paramSetAPIv5.retrieval = self.manager.paramGetAPIv6;
	self.control = [[FxGripPathTestControl alloc] initWithAPIManager:(id _Nonnull)nil];
	self.control.stubAPIManager = self.manager;
}

- (NSInteger)hitTestAtCanvasX:(double)x y:(double)y
{
	NSInteger activePart = -1;
	[self.control hitTestOSCAtMousePositionX:x mousePositionY:y activePart:&activePart atTime:FxGripPathPartTestTime()];
	return activePart;
}

- (void)mouseDownAtCanvasX:(double)x y:(double)y activePart:(NSInteger)activePart modifiers:(FxModifierKeys)modifiers
{
	// The host hit-tests before every mouse-down; that is what records the part's active
	// sub-element, so mirror the order here.
	[self hitTestAtCanvasX:x y:y];
	BOOL forceUpdate = NO;
	[self.control mouseDownAtPositionX:x positionY:y activePart:activePart modifiers:modifiers
						  forceUpdate:&forceUpdate atTime:FxGripPathPartTestTime()];
}

- (void)dragToCanvasX:(double)x y:(double)y activePart:(NSInteger)activePart modifiers:(FxModifierKeys)modifiers
{
	BOOL forceUpdate = NO;
	[self.control mouseDraggedAtPositionX:x positionY:y activePart:activePart modifiers:modifiers
							 forceUpdate:&forceUpdate atTime:FxGripPathPartTestTime()];
}

- (FxGripPathData *)stagedPathForParameter:(UInt32)parameterID
{
	return self.manager.paramGetAPIv6.customs[@(parameterID)];
}

/*! A closed custom-data triangle at object (0.2,0.2),(0.6,0.2),(0.6,0.6) in parameter 30. */
- (FxGripOSCPathPart *)stageCustomTrianglePartWithID:(NSInteger)partID options:(FxGripOSCPathOptions)options
{
	CGPoint locations[3] = { CGPointMake(0.2, 0.2), CGPointMake(0.6, 0.2), CGPointMake(0.6, 0.6) };
	self.manager.paramGetAPIv6.customs[@(30)] = [FxGripPathData pathWithLocations:locations count:3 closed:YES];
	FxGripOSCPathPart *part = [FxGripOSCPathPart pathPartWithID:partID pathParameterID:30 options:options];
	[self.control addPart:part];
	return part;
}


#pragma mark Custom-data backing

- (void)testVertexHandleHitsByCanvasDistance
{
	[self stageCustomTrianglePartWithID:1 options:FxGripOSCPathOptionVertexHandles];
	XCTAssertEqual([self hitTestAtCanvasX:20 y:20], (NSInteger)1, @"on the first vertex");
	XCTAssertEqual([self hitTestAtCanvasX:26 y:20], (NSInteger)1, @"within the 10 px vertex radius");
	XCTAssertEqual([self hitTestAtCanvasX:45 y:45], (NSInteger)0, @"the interior is not a vertex");
}

- (void)testDraggingAVertexWritesItsNewLocation
{
	[self stageCustomTrianglePartWithID:1 options:FxGripOSCPathOptionVertexHandles];
	[self mouseDownAtCanvasX:20 y:20 activePart:1 modifiers:0];
	[self dragToCanvasX:10 y:30 activePart:1 modifiers:0];

	FxVertex moved = [[self stagedPathForParameter:30] vertexAtIndex:0];
	XCTAssertEqualWithAccuracy(moved.location.x, 0.10, 1e-9);
	XCTAssertEqualWithAccuracy(moved.location.y, 0.30, 1e-9);
}

- (void)testBodyDragTranslatesEveryVertex
{
	[self stageCustomTrianglePartWithID:1 options:FxGripOSCPathOptionBodyDrag];
	// A point on the bottom edge between the first two vertices.
	NSInteger part = [self hitTestAtCanvasX:40 y:20];
	XCTAssertEqual(part, (NSInteger)1);
	[self mouseDownAtCanvasX:40 y:20 activePart:1 modifiers:0];
	[self dragToCanvasX:50 y:30 activePart:1 modifiers:0];

	FxGripPathData *path = [self stagedPathForParameter:30];
	XCTAssertEqualWithAccuracy([path locationAtIndex:0].x, 0.3, 1e-9);
	XCTAssertEqualWithAccuracy([path locationAtIndex:0].y, 0.3, 1e-9);
	XCTAssertEqualWithAccuracy([path locationAtIndex:2].y, 0.7, 1e-9);
}

- (void)testEditableInsertsAVertexOnSegmentClick
{
	[self stageCustomTrianglePartWithID:1 options:FxGripOSCPathOptionEditable | FxGripOSCPathOptionVertexHandles];
	// Midpoint of the bottom edge, away from the vertices.
	XCTAssertEqual([self hitTestAtCanvasX:40 y:20], (NSInteger)1);
	[self mouseDownAtCanvasX:40 y:20 activePart:1 modifiers:kFxModifierKey_OPTION];

	FxGripPathData *path = [self stagedPathForParameter:30];
	XCTAssertEqual(path.vertexCount, (NSUInteger)4);
	XCTAssertEqualWithAccuracy([path locationAtIndex:1].x, 0.4, 1e-9, @"inserted at the projection");
}

- (void)testEditableDeletesTheSelectedVertex
{
	FxGripOSCPathPart *part = [self stageCustomTrianglePartWithID:1
														options:FxGripOSCPathOptionEditable | FxGripOSCPathOptionVertexHandles];
	part.minimumVertexCount = 2;
	[self mouseDownAtCanvasX:20 y:20 activePart:1 modifiers:0];
	XCTAssertEqual(part.selectedVertexIndex, (NSInteger)0);

	BOOL forceUpdate = NO;
	[self.control keyDownAtPositionX:20 positionY:20 keyPressed:127 modifiers:0
						 forceUpdate:&forceUpdate didHandle:&forceUpdate atTime:FxGripPathPartTestTime()];
	XCTAssertEqual([self stagedPathForParameter:30].vertexCount, (NSUInteger)2);
}

- (void)testEditableDeleteStopsAtTheMinimum
{
	FxGripOSCPathPart *part = [self stageCustomTrianglePartWithID:1
														options:FxGripOSCPathOptionEditable | FxGripOSCPathOptionVertexHandles];
	part.minimumVertexCount = 3;
	[self mouseDownAtCanvasX:20 y:20 activePart:1 modifiers:0];
	BOOL forceUpdate = NO;
	[self.control keyDownAtPositionX:20 positionY:20 keyPressed:8 modifiers:0
						 forceUpdate:&forceUpdate didHandle:&forceUpdate atTime:FxGripPathPartTestTime()];
	XCTAssertEqual([self stagedPathForParameter:30].vertexCount, (NSUInteger)3, @"held at the minimum");
}

- (void)testDoubleClickTogglesAVertexToSmoothAndBack
{
	FxGripOSCPathPart *part = [self stageCustomTrianglePartWithID:1
														options:FxGripOSCPathOptionEditable | FxGripOSCPathOptionVertexHandles];
	// Select the middle vertex, then toggle it smooth through the part's double-click hook.
	[self mouseDownAtCanvasX:60 y:20 activePart:1 modifiers:0];
	FxVertex before = [[self stagedPathForParameter:30] vertexAtIndex:1];
	XCTAssertEqual(before.interpStyle, (FxPathStyle)kFxPathStyle_Linear);

	BOOL toggled = [part mouseDoubleClickAtObjectPoint:CGPointMake(0.6, 0.2)
										   canvasPoint:CGPointMake(60, 20)
											 modifiers:0
												atTime:FxGripPathPartTestTime()];
	XCTAssertTrue(toggled);
	FxVertex smooth = [[self stagedPathForParameter:30] vertexAtIndex:1];
	XCTAssertEqual(smooth.interpStyle, (FxPathStyle)kFxPathStyle_Bezier);
	XCTAssertGreaterThan(hypot(smooth.outTangent.x, smooth.outTangent.y), 0.0, @"smooth regenerates tangents");
}


#pragma mark Tangent handles

/*! Two Bézier vertices in a custom path, with out/in tangents, in parameter 30. */
- (void)stageTwoBezierVerticesWithOutTangent:(CGPoint)out inTangent:(CGPoint)in
{
	FxVertex vertices[2] = { {0}, {0} };
	vertices[0].location = CGPointMake(0.2, 0.5);
	vertices[0].outTangent = out;
	vertices[0].inTangent = CGPointMake(-out.x, -out.y);
	vertices[0].interpStyle = kFxPathStyle_Bezier;
	vertices[1].location = CGPointMake(0.8, 0.5);
	vertices[1].inTangent = in;
	vertices[1].outTangent = CGPointMake(-in.x, -in.y);
	vertices[1].interpStyle = kFxPathStyle_Bezier;
	self.manager.paramGetAPIv6.customs[@(30)] = [FxGripPathData pathWithVertices:vertices count:2 closed:NO];
}

- (void)testTangentHandleHitAndDragWritesTheVector
{
	[self stageTwoBezierVerticesWithOutTangent:CGPointMake(0.1, 0.0) inTangent:CGPointMake(0.1, 0.0)];
	FxGripOSCPathPart *part = [FxGripOSCPathPart pathPartWithID:1 pathParameterID:30
													  options:FxGripOSCPathOptionTangentHandles];
	[self.control addPart:part];

	// Vertex 0's out tangent tip sits at object (0.3, 0.5) -> canvas (30, 50).
	XCTAssertEqual([self hitTestAtCanvasX:30 y:50], (NSInteger)1);
	[self mouseDownAtCanvasX:30 y:50 activePart:1 modifiers:0];
	[self dragToCanvasX:40 y:60 activePart:1 modifiers:0];

	FxVertex vertex = [[self stagedPathForParameter:30] vertexAtIndex:0];
	// Tip dragged to object (0.4, 0.6); the vector from location (0.2, 0.5) is (0.2, 0.1).
	XCTAssertEqualWithAccuracy(vertex.outTangent.x, 0.2, 1e-9);
	XCTAssertEqualWithAccuracy(vertex.outTangent.y, 0.1, 1e-9);
}

- (void)testDraggingATangentMirrorsTheOppositeAligned
{
	[self stageTwoBezierVerticesWithOutTangent:CGPointMake(0.1, 0.0) inTangent:CGPointMake(0.1, 0.0)];
	FxGripOSCPathPart *part = [FxGripOSCPathPart pathPartWithID:1 pathParameterID:30
													  options:FxGripOSCPathOptionTangentHandles];
	[self.control addPart:part];
	[self mouseDownAtCanvasX:30 y:50 activePart:1 modifiers:0];
	// Drag the out tangent straight up: the in tangent (opposite) rotates to stay collinear,
	// keeping its own length of 0.1.
	[self dragToCanvasX:20 y:70 activePart:1 modifiers:0];

	FxVertex vertex = [[self stagedPathForParameter:30] vertexAtIndex:0];
	XCTAssertEqualWithAccuracy(hypot(vertex.inTangent.x, vertex.inTangent.y), 0.1, 1e-6, @"aligned keeps its length");
	// Opposite points against the dragged direction (which was straight up, +y).
	XCTAssertLessThan(vertex.inTangent.y, 0.0);
	XCTAssertEqualWithAccuracy(vertex.inTangent.x, 0.0, 1e-6);
}

- (void)testOptionBreaksTheTangentPair
{
	[self stageTwoBezierVerticesWithOutTangent:CGPointMake(0.1, 0.0) inTangent:CGPointMake(0.1, 0.0)];
	FxGripOSCPathPart *part = [FxGripOSCPathPart pathPartWithID:1 pathParameterID:30
													  options:FxGripOSCPathOptionTangentHandles];
	[self.control addPart:part];
	[self mouseDownAtCanvasX:30 y:50 activePart:1 modifiers:0];
	[self dragToCanvasX:20 y:70 activePart:1 modifiers:kFxModifierKey_OPTION];

	FxVertex vertex = [[self stagedPathForParameter:30] vertexAtIndex:0];
	// The in tangent is left untouched at its original (-0.1, 0).
	XCTAssertEqualWithAccuracy(vertex.inTangent.x, -0.1, 1e-9);
	XCTAssertEqualWithAccuracy(vertex.inTangent.y, 0.0, 1e-9);
}


#pragma mark Converter-driven body

- (void)testBodyHitFollowsTheBezierCurve
{
	// Two Bézier vertices whose tangents bulge the curve upward off the straight chord. A point on
	// the bulge hits the body; the converter, not a straight segment, decides the hit.
	FxVertex vertices[2] = { {0}, {0} };
	vertices[0].location = CGPointMake(0.2, 0.5);
	vertices[0].outTangent = CGPointMake(0.0, 0.4);
	vertices[0].interpStyle = kFxPathStyle_Bezier;
	vertices[1].location = CGPointMake(0.8, 0.5);
	vertices[1].inTangent = CGPointMake(0.0, 0.4);
	vertices[1].interpStyle = kFxPathStyle_Bezier;
	self.manager.paramGetAPIv6.customs[@(30)] = [FxGripPathData pathWithVertices:vertices count:2 closed:NO];
	[self.control addPart:[FxGripOSCPathPart pathPartWithID:1 pathParameterID:30
													options:FxGripOSCPathOptionBodyDrag]];

	// The chord midpoint is object (0.5, 0.5) -> canvas (50, 50); the curve bulges to about y 0.8.
	XCTAssertEqual([self hitTestAtCanvasX:50 y:50], (NSInteger)0, @"the straight chord is not the curve");
	XCTAssertEqual([self hitTestAtCanvasX:50 y:80], (NSInteger)1, @"the point on the bulge hits the curved body");
}


#pragma mark Per-parameter backing

- (void)testPerParameterVertexDragWritesTheLocationParameter
{
	[self.control addPart:[FxGripOSCPathPart pathPartWithID:1
									  locationParameterIDs:@[@41, @42]
													closed:NO
												   options:FxGripOSCPathOptionVertexHandles]];
	self.manager.paramGetAPIv6.points[@(41)] = [NSValue valueWithPoint:NSMakePoint(0.2, 0.2)];
	self.manager.paramGetAPIv6.points[@(42)] = [NSValue valueWithPoint:NSMakePoint(0.8, 0.8)];

	XCTAssertEqual([self hitTestAtCanvasX:20 y:20], (NSInteger)1);
	[self mouseDownAtCanvasX:20 y:20 activePart:1 modifiers:0];
	[self dragToCanvasX:30 y:10 activePart:1 modifiers:0];

	NSValue *moved = self.manager.paramGetAPIv6.points[@(41)];
	XCTAssertEqualWithAccuracy(moved.pointValue.x, 0.3, 1e-9);
	XCTAssertEqualWithAccuracy(moved.pointValue.y, 0.1, 1e-9);
	XCTAssertEqualWithAccuracy(self.manager.paramGetAPIv6.points[@(42)].pointValue.x, 0.8, 1e-9, @"the other vertex is untouched");
}

- (void)testPerParameterTangentsRideAlongWithTheLocation
{
	// Tangents are vectors in their own parameters, so moving the location leaves them unchanged
	// and their tips move with the vertex.
	[self.control addPart:[FxGripOSCPathPart pathPartWithID:1
									  locationParameterIDs:@[@41, @42]
													closed:NO
												   options:FxGripOSCPathOptionVertexHandles]];
	FxGripOSCPathPart *part = (FxGripOSCPathPart *)self.control.parts.firstObject;
	part.outTangentParameterIDs = @[@51, @52];
	part.inTangentParameterIDs = @[@53, @54];
	self.manager.paramGetAPIv6.points[@(41)] = [NSValue valueWithPoint:NSMakePoint(0.2, 0.2)];
	self.manager.paramGetAPIv6.points[@(42)] = [NSValue valueWithPoint:NSMakePoint(0.8, 0.8)];
	self.manager.paramGetAPIv6.points[@(51)] = [NSValue valueWithPoint:NSMakePoint(0.05, 0.0)];

	[self mouseDownAtCanvasX:20 y:20 activePart:1 modifiers:0];
	[self dragToCanvasX:40 y:40 activePart:1 modifiers:0];

	XCTAssertEqualWithAccuracy(self.manager.paramGetAPIv6.points[@(41)].pointValue.x, 0.4, 1e-9);
	XCTAssertEqualWithAccuracy(self.manager.paramGetAPIv6.points[@(51)].pointValue.x, 0.05, 1e-9, @"the tangent vector is untouched");
}

@end
