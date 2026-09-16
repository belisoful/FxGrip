/*!
	@file       FxGripOSCPathPartTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripOSCPathPartTests
	@abstract   Verifies the FxGripOSCPathPart on-screen control across its custom-data and per-parameter backings.
	@discussion Introduced in FxGrip 0.1.0. A stub OSC API maps canvas to object space by a uniform scale of 100, and stub retrieval and setting APIs stage and capture path, point, and float parameters. The tests cover vertex-handle hit testing and dragging, body-drag translation, editable insert and delete with a minimum count, smooth-vertex toggling, tangent-handle hit, drag, mirroring, and break, converter-driven body hits on a Bézier curve, and the per-parameter location and tangent backing. A live Metal render pass from FxGripOSCMetalTestPass draws the flattened path, the tangent stems, and the vertex handles, and the rendered pixels are read back and asserted.
*/

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripOnScreenControl.h>
#import <FxGrip/FxGripOSCPathPart.h>
#import <FxGrip/FxGripPathData.h>
#import "FxGripOSCMetalTestSupport.h"

/*! The path part's private backing writes, geometry, and editing hooks. */
@interface FxGripOSCPathPart (FxGripPathTesting)
- (BOOL)writeLocationAtIndex:(NSUInteger)index toObjectPoint:(CGPoint)location atTime:(CMTime)time;
- (BOOL)writeTangentAtIndex:(NSUInteger)index
				 isOutgoing:(BOOL)isOutgoing
			   objectVector:(CGPoint)vector
					 atTime:(CMTime)time;
- (BOOL)writeStyleAtIndex:(NSUInteger)index toStyle:(FxPathStyle)style atTime:(CMTime)time;
- (BOOL)translateBy:(CGPoint)objectDelta atTime:(CMTime)time;
- (BOOL)dragTangentAtIndex:(NSUInteger)index
				isOutgoing:(BOOL)isOutgoing
			 toObjectPoint:(CGPoint)objectPoint
				 modifiers:(FxModifierKeys)modifiers
					atTime:(CMTime)time;
- (BOOL)insertVertexAtObjectPoint:(CGPoint)objectPoint atTime:(CMTime)time;
- (BOOL)removeSelectedVertexAtTime:(CMTime)time;
- (BOOL)toggleVertexStyleAtIndex:(NSUInteger)index atTime:(CMTime)time;
@end

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
@property (nonatomic, assign) BOOL refusesCustomWrites;
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
	if (self.refusesCustomWrites) {
		return NO;
	}
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

/*! @abstract A vertex hit registers within the canvas hit radius of a vertex and misses in the interior. */
- (void)testVertexHandleHitsByCanvasDistance
{
	[self stageCustomTrianglePartWithID:1 options:FxGripOSCPathOptionVertexHandles];
	XCTAssertEqual([self hitTestAtCanvasX:20 y:20], (NSInteger)1, @"on the first vertex");
	XCTAssertEqual([self hitTestAtCanvasX:26 y:20], (NSInteger)1, @"within the 10 px vertex radius");
	XCTAssertEqual([self hitTestAtCanvasX:45 y:45], (NSInteger)0, @"the interior is not a vertex");
}

/*! @abstract Dragging a vertex writes its new object-space location to the path parameter. */
- (void)testDraggingAVertexWritesItsNewLocation
{
	[self stageCustomTrianglePartWithID:1 options:FxGripOSCPathOptionVertexHandles];
	[self mouseDownAtCanvasX:20 y:20 activePart:1 modifiers:0];
	[self dragToCanvasX:10 y:30 activePart:1 modifiers:0];

	FxVertex moved = [[self stagedPathForParameter:30] vertexAtIndex:0];
	XCTAssertEqualWithAccuracy(moved.location.x, 0.10, 1e-9);
	XCTAssertEqualWithAccuracy(moved.location.y, 0.30, 1e-9);
}

/*! @abstract A body drag translates every vertex of the path by the drag delta. */
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

/*! @abstract An Option-click on a segment of an editable path inserts a vertex at the projected point. */
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

/*! @abstract A delete key removes the selected vertex from an editable path above its minimum count. */
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

/*! @abstract A delete key holds the vertex count at the minimum and removes no vertex. */
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

/*! @abstract A double-click switches a linear vertex to Bézier and regenerates nonzero tangents. */
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

/*! @abstract A tangent handle hits at its tip, and dragging it writes the new tangent vector relative to the vertex location. */
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

/*! @abstract Dragging one tangent rotates the opposite tangent to stay collinear while keeping its own length. */
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

/*! @abstract An Option drag breaks the tangent pair and leaves the opposite tangent untouched. */
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

/*! @abstract A body hit follows the Bézier curve, missing the straight chord and hitting the bulge. */
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

/*! @abstract With per-parameter backing, dragging a vertex writes its location parameter and leaves the other vertex untouched. */
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

/*! @abstract Moving a per-parameter vertex leaves its tangent vector parameters unchanged so the tips ride along. */
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


#pragma mark Drawing

/*! Binds `name` to a live render pass, or skips the test when the machine has no Metal device. */
#define FxGripPathBeginPass(name, canvasSizeValue) \
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

/*! Draws one part into a live pass and finishes it. */
- (void)drawPart:(FxGripOSCPart *)part inPass:(FxGripOSCMetalTestPass *)pass
{
	[part drawSelected:NO
			canvasSize:pass.canvasSize
		commandEncoder:pass.commandEncoder
				atTime:FxGripPathPartTestTime()];
	[pass finish];
}

/*! @abstract The path strokes its flattened outline and fills a handle on every vertex. */
- (void)testThePathStrokesItsOutlineAndFillsItsVertexHandles
{
	FxGripOSCPathPart *part = [self stageCustomTrianglePartWithID:1
														  options:FxGripOSCPathOptionVertexHandles];

	FxGripPathBeginPass(pass, CGSizeMake(80.0, 80.0));
	[self drawPart:part inPass:pass];

	XCTAssertGreaterThan([self inkNear:CGPointMake(40.0, 20.0) inPass:pass], 0.5f, @"the first segment");
	XCTAssertGreaterThan([self inkNear:CGPointMake(40.0, 40.0) inPass:pass], 0.5f, @"the closing segment");
	XCTAssertEqualWithAccuracy([pass colorAtCanvasPoint:CGPointMake(20.0, 20.0)].w,
							   kFxGripOSCUnselectedFillColor.w, 0.02, @"the first vertex handle");
	XCTAssertEqualWithAccuracy([pass colorAtCanvasPoint:CGPointMake(45.0, 55.0)].w, 0.0, 0.01,
							   @"outside the triangle");
}

/*! @abstract The selected vertex draws in the selected fill and the others do not. */
- (void)testTheSelectedVertexDrawsInTheSelectedFill
{
	FxGripOSCPathPart *part = [self stageCustomTrianglePartWithID:1
														  options:FxGripOSCPathOptionVertexHandles];
	[self mouseDownAtCanvasX:60 y:20 activePart:1 modifiers:0];
	XCTAssertEqual(part.selectedVertexIndex, (NSInteger)1);

	FxGripPathBeginPass(pass, CGSizeMake(80.0, 80.0));
	[self drawPart:part inPass:pass];

	XCTAssertEqualWithAccuracy([pass colorAtCanvasPoint:CGPointMake(60.0, 20.0)].w,
							   kFxGripOSCSelectedFillColor.w, 0.02, @"the selected vertex");
	XCTAssertEqualWithAccuracy([pass colorAtCanvasPoint:CGPointMake(20.0, 20.0)].w,
							   kFxGripOSCUnselectedFillColor.w, 0.02, @"an unselected vertex");
}

/*! @abstract Tangent handles draw only for Bézier-family vertices whose tangents are extended. */
- (void)testTangentHandlesDrawOnlyForExtendedBezierTangents
{
	FxVertex vertices[3] = { {0}, {0}, {0} };
	vertices[0].location = CGPointMake(0.2, 0.5);
	vertices[0].outTangent = CGPointMake(0.1, 0.0);
	vertices[0].interpStyle = kFxPathStyle_Bezier;
	vertices[1].location = CGPointMake(0.5, 0.5);
	vertices[1].outTangent = CGPointMake(0.1, 0.0);
	vertices[1].interpStyle = kFxPathStyle_Linear;
	vertices[2].location = CGPointMake(0.75, 0.5);
	vertices[2].interpStyle = kFxPathStyle_Bezier;
	self.manager.paramGetAPIv6.customs[@(30)] = [FxGripPathData pathWithVertices:vertices count:3 closed:NO];
	FxGripOSCPathPart *part = [FxGripOSCPathPart pathPartWithID:1
												pathParameterID:30
														options:FxGripOSCPathOptionTangentHandles];
	[self.control addPart:part];

	FxGripPathBeginPass(pass, CGSizeMake(80.0, 80.0));
	[self drawPart:part inPass:pass];

	XCTAssertEqualWithAccuracy([self inkNear:CGPointMake(30.0, 50.0) inPass:pass],
							   kFxGripOSCUnselectedFillColor.w, 0.02,
							   @"the Bézier vertex's out tangent tip covers the stroke there");
	XCTAssertEqualWithAccuracy([self inkNear:CGPointMake(60.0, 50.0) inPass:pass], 1.0, 0.02,
							   @"a linear vertex exposes no tangent handle, so only the stroke is there");
	XCTAssertEqualWithAccuracy([self inkNear:CGPointMake(73.0, 50.0) inPass:pass], 1.0, 0.02,
							   @"a retracted tangent draws no handle");
}

/*! @abstract A path with no vertices draws nothing and answers no hit. */
- (void)testAnEmptyPathDrawsNothingAndAnswersNoHit
{
	CMTime time = FxGripPathPartTestTime();
	self.manager.paramGetAPIv6.customs[@(30)] = [FxGripPathData emptyPathClosed:NO];
	FxGripOSCPathPart *customBacked = [FxGripOSCPathPart pathPartWithID:1
														pathParameterID:30
																options:FxGripOSCPathOptionsAll];
	FxGripOSCPathPart *perParameter = [FxGripOSCPathPart pathPartWithID:2
												  locationParameterIDs:@[]
																closed:NO
															   options:FxGripOSCPathOptionsAll];
	[self.control addParts:@[customBacked, perParameter]];

	FxGripPathBeginPass(pass, CGSizeMake(80.0, 80.0));
	[customBacked drawSelected:NO canvasSize:pass.canvasSize commandEncoder:pass.commandEncoder atTime:time];
	[perParameter drawSelected:NO canvasSize:pass.canvasSize commandEncoder:pass.commandEncoder atTime:time];
	[pass finish];

	XCTAssertEqualWithAccuracy([self inkNear:CGPointMake(40.0, 40.0) inPass:pass], 0.0, 0.01);
	XCTAssertFalse([customBacked hitTestObjectPoint:CGPointZero canvasPoint:CGPointMake(40.0, 40.0) atTime:time]);
	XCTAssertFalse([perParameter hitTestObjectPoint:CGPointZero canvasPoint:CGPointMake(40.0, 40.0) atTime:time]);
}

#pragma mark Per-parameter backing

/*! A two-vertex per-parameter path with tangent, weight, and style arrays, at object (0.2, 0.2) and (0.8, 0.2). */
- (FxGripOSCPathPart *)stagePerParameterPathWithOptions:(FxGripOSCPathOptions)options
{
	FxGripOSCPathPart *part = [FxGripOSCPathPart pathPartWithID:1
										   locationParameterIDs:@[@41, @42]
														 closed:NO
														options:options];
	part.outTangentParameterIDs = @[@51, @52];
	part.inTangentParameterIDs = @[@53, @54];
	part.xSplineWeightParameterIDs = @[@61, @62];
	part.interpStyles = @[@(kFxPathStyle_Bezier), @(kFxPathStyle_Bezier)];
	[self.control addPart:part];

	self.manager.paramGetAPIv6.points[@(41)] = [NSValue valueWithPoint:NSMakePoint(0.2, 0.2)];
	self.manager.paramGetAPIv6.points[@(42)] = [NSValue valueWithPoint:NSMakePoint(0.8, 0.2)];
	self.manager.paramGetAPIv6.points[@(51)] = [NSValue valueWithPoint:NSMakePoint(0.1, 0.0)];
	self.manager.paramGetAPIv6.points[@(53)] = [NSValue valueWithPoint:NSMakePoint(-0.1, 0.0)];
	self.manager.paramGetAPIv6.floats[@(61)] = @(0.5);
	self.manager.paramGetAPIv6.floats[@(62)] = @(0.5);
	return part;
}

/*! @abstract Dragging a per-parameter tangent handle writes its own vector parameter and mirrors the opposite one. */
- (void)testDraggingAPerParameterTangentWritesItsOwnParameter
{
	[self stagePerParameterPathWithOptions:FxGripOSCPathOptionTangentHandles];

	// Vertex 0's out tangent tip sits at object (0.3, 0.2) -> canvas (30, 20).
	XCTAssertEqual([self hitTestAtCanvasX:30 y:20], (NSInteger)1);
	[self mouseDownAtCanvasX:30 y:20 activePart:1 modifiers:0];
	[self dragToCanvasX:20 y:40 activePart:1 modifiers:0];

	NSPoint out = self.manager.paramGetAPIv6.points[@(51)].pointValue;
	XCTAssertEqualWithAccuracy(out.x, 0.0, 1e-9, @"the vector from the vertex location");
	XCTAssertEqualWithAccuracy(out.y, 0.2, 1e-9);
	NSPoint in = self.manager.paramGetAPIv6.points[@(53)].pointValue;
	XCTAssertLessThan(in.y, 0.0, @"the opposite tangent rotates to stay collinear");
	XCTAssertEqualWithAccuracy(hypot(in.x, in.y), 0.1, 1e-6, @"keeping its own length");
}

/*! @abstract Dragging the per-parameter body translates every location parameter by the delta. */
- (void)testDraggingThePerParameterBodyTranslatesEveryLocation
{
	[self stagePerParameterPathWithOptions:FxGripOSCPathOptionBodyDrag];

	XCTAssertEqual([self hitTestAtCanvasX:50 y:20], (NSInteger)1, @"a point on the body");
	[self mouseDownAtCanvasX:50 y:20 activePart:1 modifiers:0];
	[self dragToCanvasX:60 y:30 activePart:1 modifiers:0];

	XCTAssertEqualWithAccuracy(self.manager.paramGetAPIv6.points[@(41)].pointValue.x, 0.3, 1e-9);
	XCTAssertEqualWithAccuracy(self.manager.paramGetAPIv6.points[@(41)].pointValue.y, 0.3, 1e-9);
	XCTAssertEqualWithAccuracy(self.manager.paramGetAPIv6.points[@(42)].pointValue.x, 0.9, 1e-9);
}

/*! @abstract A per-parameter path with an unreadable location parameter refuses to translate. */
- (void)testAPerParameterBodyDragStopsAtAnUnreadableLocation
{
	FxGripOSCPathPart *part = [FxGripOSCPathPart pathPartWithID:1
										   locationParameterIDs:@[@41, @91]
														 closed:NO
														options:FxGripOSCPathOptionBodyDrag];
	[self.control addPart:part];
	self.manager.paramGetAPIv6.points[@(41)] = [NSValue valueWithPoint:NSMakePoint(0.2, 0.2)];

	XCTAssertFalse([part translateBy:CGPointMake(0.1, 0.0) atTime:FxGripPathPartTestTime()]);
}

/*! @abstract Toggling a per-parameter vertex style records the style locally and rewrites its tangents. */
- (void)testTogglingAPerParameterVertexStyleRecordsItLocally
{
	FxGripOSCPathPart *part = [self stagePerParameterPathWithOptions:FxGripOSCPathOptionsAll];
	CMTime time = FxGripPathPartTestTime();

	XCTAssertTrue([part toggleVertexStyleAtIndex:0 atTime:time], @"an extended Bézier vertex toggles to a corner");
	XCTAssertEqualWithAccuracy(self.manager.paramGetAPIv6.points[@(51)].pointValue.x, 0.0, 1e-12);
	XCTAssertEqualWithAccuracy(self.manager.paramGetAPIv6.points[@(53)].pointValue.x, 0.0, 1e-12);

	XCTAssertTrue([part toggleVertexStyleAtIndex:0 atTime:time], @"and back to smooth");
	NSPoint regenerated = self.manager.paramGetAPIv6.points[@(51)].pointValue;
	XCTAssertGreaterThan(hypot(regenerated.x, regenerated.y), 0.0, @"smooth regenerates a tangent");

	XCTAssertFalse([part toggleVertexStyleAtIndex:9 atTime:time], @"an index past the end is refused");
}

/*! @abstract An out-of-range write is refused on both backings. */
- (void)testOutOfRangeWritesAreRefused
{
	CMTime time = FxGripPathPartTestTime();
	FxGripOSCPathPart *custom = [self stageCustomTrianglePartWithID:1 options:FxGripOSCPathOptionsAll];
	FxGripOSCPathPart *perParameter = [self stagePerParameterPathWithOptions:FxGripOSCPathOptionsAll];
	perParameter.partID = 2;

	XCTAssertFalse([custom writeLocationAtIndex:9 toObjectPoint:CGPointZero atTime:time]);
	XCTAssertFalse([custom writeTangentAtIndex:9 isOutgoing:YES objectVector:CGPointZero atTime:time]);
	XCTAssertFalse([custom writeStyleAtIndex:9 toStyle:kFxPathStyle_Linear atTime:time]);
	XCTAssertFalse([perParameter writeLocationAtIndex:9 toObjectPoint:CGPointZero atTime:time]);
	XCTAssertFalse([perParameter writeTangentAtIndex:9 isOutgoing:NO objectVector:CGPointZero atTime:time]);
}

#pragma mark Tangent gestures

/*! @abstract A Command drag retracts the tangent onto its vertex, making that side linear. */
- (void)testACommandDragRetractsATangent
{
	[self stageTwoBezierVerticesWithOutTangent:CGPointMake(0.1, 0.0) inTangent:CGPointMake(0.1, 0.0)];
	FxGripOSCPathPart *part = [FxGripOSCPathPart pathPartWithID:1 pathParameterID:30
														options:FxGripOSCPathOptionTangentHandles];
	[self.control addPart:part];
	[self mouseDownAtCanvasX:30 y:50 activePart:1 modifiers:0];
	[self dragToCanvasX:40 y:60 activePart:1 modifiers:kFxModifierKey_COMMAND];

	FxVertex vertex = [[self stagedPathForParameter:30] vertexAtIndex:0];
	XCTAssertEqualWithAccuracy(vertex.outTangent.x, 0.0, 1e-12);
	XCTAssertEqualWithAccuracy(vertex.outTangent.y, 0.0, 1e-12);
	XCTAssertEqualWithAccuracy(vertex.inTangent.x, -0.1, 1e-9, @"the opposite tangent is left alone");
}

/*! @abstract Shift snaps a tangent's angle to 45° increments and keeps its length. */
- (void)testShiftSnapsATangentToFortyFiveDegrees
{
	[self stageTwoBezierVerticesWithOutTangent:CGPointMake(0.1, 0.0) inTangent:CGPointMake(0.1, 0.0)];
	FxGripOSCPathPart *part = [FxGripOSCPathPart pathPartWithID:1 pathParameterID:30
														options:FxGripOSCPathOptionTangentHandles];
	[self.control addPart:part];
	[self mouseDownAtCanvasX:30 y:50 activePart:1 modifiers:0];
	// The pointer lands at object (0.4, 0.55), 14° off the axis; Shift snaps it onto the axis.
	[self dragToCanvasX:40 y:55 activePart:1 modifiers:kFxModifierKey_SHIFT];

	FxVertex vertex = [[self stagedPathForParameter:30] vertexAtIndex:0];
	XCTAssertEqualWithAccuracy(vertex.outTangent.y, 0.0, 1e-9, @"snapped onto the horizontal");
	XCTAssertGreaterThan(vertex.outTangent.x, 0.0);
	XCTAssertEqualWithAccuracy(hypot(vertex.outTangent.x, vertex.outTangent.y),
							   hypot(0.2, 0.05), 1e-6, @"and the length is kept");
}

/*! @abstract Mirroring stops when either tangent of the pair is retracted. */
- (void)testMirroringStopsWhenEitherTangentIsRetracted
{
	CMTime time = FxGripPathPartTestTime();
	[self stageTwoBezierVerticesWithOutTangent:CGPointMake(0.1, 0.0) inTangent:CGPointMake(0.1, 0.0)];
	FxGripOSCPathPart *part = [FxGripOSCPathPart pathPartWithID:1 pathParameterID:30
														options:FxGripOSCPathOptionTangentHandles];
	[self.control addPart:part];

	// A drag onto the vertex itself leaves nothing to mirror with.
	XCTAssertTrue([part dragTangentAtIndex:0 isOutgoing:YES toObjectPoint:CGPointMake(0.2, 0.5)
								 modifiers:0 atTime:time]);
	XCTAssertEqualWithAccuracy([[self stagedPathForParameter:30] vertexAtIndex:0].inTangent.x, -0.1, 1e-9,
							   @"a retracted drag leaves the opposite tangent alone");

	// With the opposite tangent already retracted, there is nothing to rotate.
	FxVertex vertices[2] = { {0}, {0} };
	vertices[0].location = CGPointMake(0.2, 0.5);
	vertices[0].outTangent = CGPointMake(0.1, 0.0);
	vertices[0].interpStyle = kFxPathStyle_Bezier;
	vertices[1].location = CGPointMake(0.8, 0.5);
	vertices[1].interpStyle = kFxPathStyle_Bezier;
	self.manager.paramGetAPIv6.customs[@(30)] = [FxGripPathData pathWithVertices:vertices count:2 closed:NO];

	XCTAssertTrue([part dragTangentAtIndex:0 isOutgoing:YES toObjectPoint:CGPointMake(0.2, 0.7)
								 modifiers:0 atTime:time]);
	FxVertex vertex = [[self stagedPathForParameter:30] vertexAtIndex:0];
	XCTAssertEqualWithAccuracy(vertex.outTangent.y, 0.2, 1e-9);
	XCTAssertEqualWithAccuracy(hypot(vertex.inTangent.x, vertex.inTangent.y), 0.0, 1e-12,
							   @"a retracted opposite tangent stays retracted");
}

/*! @abstract The path claims Option and Shift only while a tangent is the active handle. */
- (void)testThePathClaimsOptionAndShiftOnlyForTangents
{
	[self stageTwoBezierVerticesWithOutTangent:CGPointMake(0.2, 0.0) inTangent:CGPointMake(0.2, 0.0)];
	FxGripOSCPathPart *part = [FxGripOSCPathPart pathPartWithID:1 pathParameterID:30
														options:FxGripOSCPathOptionsAll];
	[self.control addPart:part];

	XCTAssertFalse([part handlesOptionDrag], @"nothing is active yet");
	XCTAssertFalse([part handlesConstrainDrag]);

	// Vertex 0's out tangent tip sits at object (0.4, 0.5), well clear of both vertices.
	[self mouseDownAtCanvasX:40 y:50 activePart:1 modifiers:0];
	XCTAssertTrue([part handlesOptionDrag], @"a tangent reads Option for itself");
	XCTAssertTrue([part handlesConstrainDrag]);

	[self mouseDownAtCanvasX:20 y:50 activePart:1 modifiers:0];
	XCTAssertFalse([part handlesOptionDrag], @"a vertex leaves both to the control");
	XCTAssertFalse([part handlesConstrainDrag]);
}

/*! @abstract A drag with no recorded hit writes nothing. */
- (void)testADragWithNoRecordedHitWritesNothing
{
	FxGripOSCPathPart *part = [self stageCustomTrianglePartWithID:1 options:FxGripOSCPathOptionsAll];
	FxGripPathData *before = [self stagedPathForParameter:30];

	XCTAssertFalse([part dragToObjectPoint:CGPointMake(0.5, 0.5) objectDelta:CGPointMake(0.1, 0.1)
								 modifiers:0 atTime:FxGripPathPartTestTime()]);
	XCTAssertTrue([self stagedPathForParameter:30] == before, @"the path is untouched");
}

#pragma mark Editing guards

/*! @abstract A Command-click on a vertex deletes it when the path is editable. */
- (void)testACommandClickOnAVertexDeletesIt
{
	FxGripOSCPathPart *part = [self stageCustomTrianglePartWithID:1
														  options:FxGripOSCPathOptionEditable
																  | FxGripOSCPathOptionVertexHandles];
	part.minimumVertexCount = 2;

	[self mouseDownAtCanvasX:20 y:20 activePart:1 modifiers:kFxModifierKey_COMMAND];

	XCTAssertEqual([self stagedPathForParameter:30].vertexCount, (NSUInteger)2);
	XCTAssertEqual(part.selectedVertexIndex, (NSInteger)-1, @"the selection clears with the vertex");
}

/*! @abstract Key presses other than Delete and Backspace, and any key on a non-editable path, are ignored. */
- (void)testOnlyDeleteAndBackspaceEditAnEditablePath
{
	CMTime time = FxGripPathPartTestTime();
	FxGripOSCPathPart *editable = [self stageCustomTrianglePartWithID:1
															  options:FxGripOSCPathOptionEditable];
	FxGripOSCPathPart *plain = [FxGripOSCPathPart pathPartWithID:2 pathParameterID:30
														options:FxGripOSCPathOptionVertexHandles];
	[self.control addPart:plain];

	XCTAssertFalse([editable keyDownWithKey:'a' modifiers:0 atTime:time], @"not an edit key");
	XCTAssertFalse([plain keyDownWithKey:127 modifiers:0 atTime:time], @"not an editable path");
	XCTAssertFalse([plain mouseDoubleClickAtObjectPoint:CGPointMake(0.2, 0.2)
											canvasPoint:CGPointMake(20.0, 20.0)
											  modifiers:0
												 atTime:time],
				   @"a non-editable path does not toggle a vertex");
	XCTAssertEqual([self stagedPathForParameter:30].vertexCount, (NSUInteger)3);
}

/*! @abstract Inserting needs at least two vertices, and removing needs a selection on a custom-data path. */
- (void)testInsertingAndRemovingHaveTheirGuards
{
	CMTime time = FxGripPathPartTestTime();
	CGPoint single = CGPointMake(0.4, 0.4);
	self.manager.paramGetAPIv6.customs[@(30)] = [FxGripPathData pathWithLocations:&single count:1 closed:NO];
	FxGripOSCPathPart *part = [FxGripOSCPathPart pathPartWithID:1 pathParameterID:30
														options:FxGripOSCPathOptionsAll];
	[self.control addPart:part];

	XCTAssertFalse([part insertVertexAtObjectPoint:CGPointMake(0.5, 0.5) atTime:time],
				   @"one vertex spans no segment");
	XCTAssertFalse([part removeSelectedVertexAtTime:time], @"nothing is selected");

	FxGripOSCPathPart *perParameter = [self stagePerParameterPathWithOptions:FxGripOSCPathOptionsAll];
	perParameter.partID = 2;
	[self mouseDownAtCanvasX:20 y:20 activePart:2 modifiers:0];
	XCTAssertEqual(perParameter.selectedVertexIndex, (NSInteger)0);
	XCTAssertFalse([perParameter removeSelectedVertexAtTime:time],
				   @"the per-parameter backing has a fixed vertex count");
}

/*! @abstract Without a usable input frame the tangent math falls back to object units. */
- (void)testTangentSnappingFallsBackToObjectUnitsWithoutAnInputFrame
{
	self.manager.onScreenControlAPIv4.stagedInputBounds = NSZeroRect;
	[self stageTwoBezierVerticesWithOutTangent:CGPointMake(0.1, 0.0) inTangent:CGPointMake(0.1, 0.0)];
	FxGripOSCPathPart *part = [FxGripOSCPathPart pathPartWithID:1 pathParameterID:30
														options:FxGripOSCPathOptionTangentHandles];
	[self.control addPart:part];

	// Object units are square, so a 45° pointer stays at 45° after the snap.
	XCTAssertTrue([part dragTangentAtIndex:0 isOutgoing:YES toObjectPoint:CGPointMake(0.4, 0.7)
								 modifiers:kFxModifierKey_SHIFT atTime:FxGripPathPartTestTime()]);
	FxVertex vertex = [[self stagedPathForParameter:30] vertexAtIndex:0];
	XCTAssertEqualWithAccuracy(vertex.outTangent.x, vertex.outTangent.y, 1e-9,
							   @"a square frame snaps the diagonal onto itself");
}

/*! @abstract A path part releases its parameter arrays when it goes away. */
- (void)testAPathPartReleasesItsParameterArrays
{
	__weak FxGripOSCPathPart *weakPart = nil;
	@autoreleasepool {
		FxGripOSCPathPart *part = [FxGripOSCPathPart pathPartWithID:1
											   locationParameterIDs:@[@41, @42]
															 closed:NO
															options:FxGripOSCPathOptionVertexHandles];
		part.interpStyles = @[@(kFxPathStyle_Bezier)];
		weakPart = part;
		XCTAssertNotNil(weakPart);
	}
	XCTAssertNil(weakPart, @"the part deallocates with its arrays");
}


#pragma mark Remaining branches

/*! @abstract A tangent hit takes the nearest tip and skips vertices whose style exposes no tangents. */
- (void)testTangentHitsTakeTheNearestTipAndSkipLinearVertices
{
	FxVertex vertices[3] = { {0}, {0}, {0} };
	vertices[0].location = CGPointMake(0.4, 0.5);
	vertices[0].outTangent = CGPointMake(0.2, 0.0);
	vertices[0].inTangent = CGPointMake(-0.2, 0.0);
	vertices[0].interpStyle = kFxPathStyle_Bezier;
	vertices[1].location = CGPointMake(0.8, 0.5);
	vertices[1].outTangent = CGPointMake(0.1, 0.0);
	vertices[1].inTangent = CGPointMake(-0.1, 0.0);
	vertices[1].interpStyle = kFxPathStyle_Linear;
	vertices[2].location = CGPointMake(0.9, 0.2);
	vertices[2].interpStyle = kFxPathStyle_Bezier;
	self.manager.paramGetAPIv6.customs[@(30)] = [FxGripPathData pathWithVertices:vertices count:3 closed:NO];
	FxGripOSCPathPart *part = [FxGripOSCPathPart pathPartWithID:1 pathParameterID:30
														options:FxGripOSCPathOptionTangentHandles];
	[self.control addPart:part];

	XCTAssertEqual([self hitTestAtCanvasX:90 y:50], (NSInteger)0,
				   @"a linear vertex exposes no tangent handle");

	// Vertex 0's in tangent tip sits at object (0.2, 0.5) -> canvas (20, 50).
	XCTAssertEqual([self hitTestAtCanvasX:20 y:50], (NSInteger)1);
	[self mouseDownAtCanvasX:20 y:50 activePart:1 modifiers:0];
	[self dragToCanvasX:20 y:30 activePart:1 modifiers:kFxModifierKey_OPTION];

	FxVertex dragged = [[self stagedPathForParameter:30] vertexAtIndex:0];
	XCTAssertEqualWithAccuracy(dragged.inTangent.x, -0.2, 1e-9, @"the in tangent took the drag");
	XCTAssertEqualWithAccuracy(dragged.inTangent.y, -0.2, 1e-9);
	XCTAssertEqualWithAccuracy(dragged.outTangent.x, 0.2, 1e-9, @"and Option left the pair broken");
}

/*! @abstract Writing a style past the end of the local style list pads the list to reach it. */
- (void)testWritingAStylePastTheEndPadsTheStyleList
{
	FxGripOSCPathPart *part = [FxGripOSCPathPart pathPartWithID:1
										   locationParameterIDs:@[@41, @42]
														 closed:NO
														options:FxGripOSCPathOptionTangentHandles];
	part.outTangentParameterIDs = @[@51, @52];
	part.inTangentParameterIDs = @[@53, @54];
	[self.control addPart:part];
	self.manager.paramGetAPIv6.points[@(41)] = [NSValue valueWithPoint:NSMakePoint(0.2, 0.2)];
	self.manager.paramGetAPIv6.points[@(42)] = [NSValue valueWithPoint:NSMakePoint(0.8, 0.2)];
	self.manager.paramGetAPIv6.points[@(51)] = [NSValue valueWithPoint:NSMakePoint(0.1, 0.0)];
	self.manager.paramGetAPIv6.points[@(52)] = [NSValue valueWithPoint:NSMakePoint(0.1, 0.0)];

	XCTAssertEqual([self hitTestAtCanvasX:90 y:20], (NSInteger)1, @"vertex 1 starts with a tangent handle");
	XCTAssertTrue([part writeStyleAtIndex:1 toStyle:kFxPathStyle_Linear atTime:FxGripPathPartTestTime()]);

	XCTAssertEqual([self hitTestAtCanvasX:90 y:20], (NSInteger)0, @"the linear vertex lost its handle");
	XCTAssertEqual([self hitTestAtCanvasX:30 y:20], (NSInteger)1, @"the padded vertex kept its Bézier default");
}

/*! @abstract A body drag on a custom-data path the host does not answer writes nothing. */
- (void)testABodyDragWithNoStagedPathWritesNothing
{
	FxGripOSCPathPart *part = [FxGripOSCPathPart pathPartWithID:1 pathParameterID:77
														options:FxGripOSCPathOptionBodyDrag];
	[self.control addPart:part];

	XCTAssertFalse([part translateBy:CGPointMake(0.1, 0.0) atTime:FxGripPathPartTestTime()]);
}

/*! @abstract An insert the host refuses leaves the selection where it was. */
- (void)testAnInsertTheHostRefusesLeavesTheSelectionAlone
{
	FxGripOSCPathPart *part = [self stageCustomTrianglePartWithID:1 options:FxGripOSCPathOptionsAll];
	self.manager.paramSetAPIv5.refusesCustomWrites = YES;

	XCTAssertFalse([part insertVertexAtObjectPoint:CGPointMake(0.4, 0.2) atTime:FxGripPathPartTestTime()]);
	XCTAssertEqual(part.selectedVertexIndex, (NSInteger)-1, @"nothing was inserted, so nothing is selected");
	XCTAssertEqual([self stagedPathForParameter:30].vertexCount, (NSUInteger)3);
}

@end
