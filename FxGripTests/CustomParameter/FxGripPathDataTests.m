//
//  FxGripPathDataTests.m
//  FxGripTests
//

#import <XCTest/XCTest.h>
#import "FxGripPathData.h"

@interface FxGripPathDataTests : XCTestCase
@end

@implementation FxGripPathDataTests

/*! A fully populated vertex, so every field is exercised by round-trip tests. */
static FxVertex MakeVertex(double lx, double ly, double ix, double iy, double ox, double oy,
						   double weight, FxPathStyle style)
{
	FxVertex vertex = { 0 };
	vertex.location = CGPointMake(lx, ly);
	vertex.inTangent = CGPointMake(ix, iy);
	vertex.outTangent = CGPointMake(ox, oy);
	vertex.xSplineWeight = weight;
	vertex.interpStyle = style;
	return vertex;
}

- (void)testEmptyPathHasNoVertices
{
	FxGripPathData *path = [FxGripPathData emptyPathClosed:YES];
	XCTAssertEqual(path.vertexCount, (NSUInteger)0);
	XCTAssertTrue(path.closed);
}

- (void)testPathFromLocationsStoresLinearVerticesWithZeroTangents
{
	CGPoint locations[2] = { CGPointMake(0.2, 0.3), CGPointMake(0.6, 0.7) };
	FxGripPathData *path = [FxGripPathData pathWithLocations:locations count:2 closed:NO];

	XCTAssertEqual(path.vertexCount, (NSUInteger)2);
	XCTAssertFalse(path.closed);
	FxVertex first = [path vertexAtIndex:0];
	XCTAssertEqual(first.location.x, 0.2);
	XCTAssertEqual(first.location.y, 0.3);
	XCTAssertEqual(first.inTangent.x, 0.0);
	XCTAssertEqual(first.outTangent.y, 0.0);
	XCTAssertEqual(first.xSplineWeight, 0.0);
	XCTAssertEqual(first.interpStyle, (FxPathStyle)kFxPathStyle_Linear);
}

- (void)testPathFromVerticesRoundTripsEveryField
{
	FxVertex vertices[1] = { MakeVertex(0.1, 0.2, -0.05, 0.0, 0.05, 0.01, 1.5, kFxPathStyle_Bezier) };
	FxGripPathData *path = [FxGripPathData pathWithVertices:vertices count:1 closed:NO];

	FxVertex out = [path vertexAtIndex:0];
	XCTAssertEqual(out.location.x, 0.1);
	XCTAssertEqual(out.location.y, 0.2);
	XCTAssertEqual(out.inTangent.x, -0.05);
	XCTAssertEqual(out.inTangent.y, 0.0);
	XCTAssertEqual(out.outTangent.x, 0.05);
	XCTAssertEqual(out.outTangent.y, 0.01);
	XCTAssertEqual(out.xSplineWeight, 1.5);
	XCTAssertEqual(out.interpStyle, (FxPathStyle)kFxPathStyle_Bezier);
}

- (void)testVertexAtOutOfRangeIndexIsZeroedLinear
{
	FxGripPathData *path = [FxGripPathData emptyPathClosed:NO];
	FxVertex out = [path vertexAtIndex:5];
	XCTAssertEqual(out.location.x, 0.0);
	XCTAssertEqual(out.interpStyle, (FxPathStyle)kFxPathStyle_Linear);
	XCTAssertTrue(CGPointEqualToPoint([path locationAtIndex:5], CGPointZero));
}

- (void)testInsertVertexShiftsLaterVertices
{
	CGPoint locations[2] = { CGPointMake(0.0, 0.0), CGPointMake(1.0, 1.0) };
	FxGripPathData *path = [FxGripPathData pathWithLocations:locations count:2 closed:NO];
	FxGripPathData *edited = [path byInsertingVertex:MakeVertex(0.5, 0.5, 0, 0, 0, 0, 0, kFxPathStyle_Bezier)
											atIndex:1];

	XCTAssertEqual(edited.vertexCount, (NSUInteger)3);
	XCTAssertEqual([edited locationAtIndex:1].x, 0.5);
	XCTAssertEqual([edited locationAtIndex:2].x, 1.0, @"the old second vertex shifted to index 2");
	XCTAssertEqual(path.vertexCount, (NSUInteger)2, @"the original is unchanged");
}

- (void)testInsertClampsBeyondEnd
{
	CGPoint locations[1] = { CGPointMake(0.0, 0.0) };
	FxGripPathData *path = [FxGripPathData pathWithLocations:locations count:1 closed:NO];
	FxGripPathData *edited = [path byInsertingVertex:MakeVertex(0.9, 0.9, 0, 0, 0, 0, 0, kFxPathStyle_Linear)
											atIndex:99];
	XCTAssertEqual(edited.vertexCount, (NSUInteger)2);
	XCTAssertEqual([edited locationAtIndex:1].x, 0.9);
}

- (void)testRemoveVertex
{
	CGPoint locations[3] = { CGPointMake(0, 0), CGPointMake(0.5, 0.5), CGPointMake(1, 1) };
	FxGripPathData *path = [FxGripPathData pathWithLocations:locations count:3 closed:NO];
	FxGripPathData *edited = [path byRemovingVertexAtIndex:1];

	XCTAssertEqual(edited.vertexCount, (NSUInteger)2);
	XCTAssertEqual([edited locationAtIndex:1].x, 1.0);
	XCTAssertEqualObjects([path byRemovingVertexAtIndex:9], path, @"out of range returns self");
}

- (void)testReplaceVertex
{
	CGPoint locations[2] = { CGPointMake(0, 0), CGPointMake(1, 1) };
	FxGripPathData *path = [FxGripPathData pathWithLocations:locations count:2 closed:NO];
	FxGripPathData *edited = [path byReplacingVertexAtIndex:0
												withVertex:MakeVertex(0.25, 0.25, 0.1, 0, 0, 0, 2.0, kFxPathStyle_XSpline)];

	FxVertex out = [edited vertexAtIndex:0];
	XCTAssertEqual(out.location.x, 0.25);
	XCTAssertEqual(out.inTangent.x, 0.1);
	XCTAssertEqual(out.xSplineWeight, 2.0);
	XCTAssertEqual(out.interpStyle, (FxPathStyle)kFxPathStyle_XSpline);
}

- (void)testReplaceLocationKeepsTangentVectors
{
	FxVertex vertices[1] = { MakeVertex(0.2, 0.2, -0.05, 0.03, 0.05, -0.03, 1.0, kFxPathStyle_Bezier) };
	FxGripPathData *path = [FxGripPathData pathWithVertices:vertices count:1 closed:NO];
	FxGripPathData *edited = [path byReplacingLocationAtIndex:0 withLocation:CGPointMake(0.8, 0.9)];

	FxVertex out = [edited vertexAtIndex:0];
	XCTAssertEqual(out.location.x, 0.8);
	XCTAssertEqual(out.location.y, 0.9);
	XCTAssertEqual(out.inTangent.x, -0.05, @"the tangent vectors ride along with the location");
	XCTAssertEqual(out.outTangent.y, -0.03);
	XCTAssertEqual(out.xSplineWeight, 1.0);
}

- (void)testTranslateMovesLocationsButNotTangentVectors
{
	FxVertex vertices[2] = {
		MakeVertex(0.1, 0.1, -0.02, 0.0, 0.02, 0.0, 0.0, kFxPathStyle_Bezier),
		MakeVertex(0.5, 0.5, -0.02, 0.0, 0.02, 0.0, 0.0, kFxPathStyle_Bezier),
	};
	FxGripPathData *path = [FxGripPathData pathWithVertices:vertices count:2 closed:YES];
	FxGripPathData *edited = [path byTranslatingBy:CGPointMake(0.1, -0.2)];

	XCTAssertEqualWithAccuracy([edited locationAtIndex:0].x, 0.2, 1e-12);
	XCTAssertEqualWithAccuracy([edited locationAtIndex:1].y, 0.3, 1e-12);
	XCTAssertEqual([edited vertexAtIndex:0].outTangent.x, 0.02, @"tangent vectors are unchanged by a translate");
	XCTAssertTrue(edited.closed);
}

- (void)testCopyVerticesToBufferRespectsCapacity
{
	CGPoint locations[3] = { CGPointMake(0, 0), CGPointMake(0.5, 0.5), CGPointMake(1, 1) };
	FxGripPathData *path = [FxGripPathData pathWithLocations:locations count:3 closed:NO];
	FxVertex buffer[2];
	NSUInteger written = [path copyVerticesToBuffer:buffer capacity:2];
	XCTAssertEqual(written, (NSUInteger)2);
	XCTAssertEqual(buffer[1].location.x, 0.5);
}

- (void)testSecureCodingRoundTrip
{
	FxVertex vertices[2] = {
		MakeVertex(0.1, 0.2, -0.05, 0.03, 0.05, -0.03, 1.25, kFxPathStyle_Bezier),
		MakeVertex(0.7, 0.8, 0.0, 0.0, 0.0, 0.0, 3.0, kFxPathStyle_XSpline),
	};
	FxGripPathData *path = [FxGripPathData pathWithVertices:vertices count:2 closed:YES];

	NSError *error = nil;
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:path requiringSecureCoding:YES error:&error];
	XCTAssertNil(error);
	FxGripPathData *decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:FxGripPathData.class
															   fromData:data
																  error:&error];
	XCTAssertNil(error);
	XCTAssertEqualObjects(decoded, path);
	XCTAssertTrue(decoded.closed);
	FxVertex out = [decoded vertexAtIndex:0];
	XCTAssertEqual(out.inTangent.y, 0.03);
	XCTAssertEqual(out.xSplineWeight, 1.25);
	XCTAssertEqual([decoded vertexAtIndex:1].interpStyle, (FxPathStyle)kFxPathStyle_XSpline);
}

- (void)testEqualityAndHash
{
	CGPoint locations[2] = { CGPointMake(0, 0), CGPointMake(1, 1) };
	FxGripPathData *a = [FxGripPathData pathWithLocations:locations count:2 closed:NO];
	FxGripPathData *b = [FxGripPathData pathWithLocations:locations count:2 closed:NO];
	FxGripPathData *c = [FxGripPathData pathWithLocations:locations count:2 closed:YES];

	XCTAssertEqualObjects(a, b);
	XCTAssertEqual(a.hash, b.hash);
	XCTAssertNotEqualObjects(a, c, @"the closed flag distinguishes paths");
}

@end
