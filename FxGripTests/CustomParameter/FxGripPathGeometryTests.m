//
//  FxGripPathGeometryTests.m
//  FxGripTests
//

#import <XCTest/XCTest.h>
#import "FxGripPathData.h"
#import "FxGripPathGeometry.h"

@interface FxGripPathGeometryTests : XCTestCase
@end

@implementation FxGripPathGeometryTests

static FxVertex Vertex(double lx, double ly, double ix, double iy, double ox, double oy,
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

- (void)testSegmentCountOpenAndClosed
{
	XCTAssertEqual(FxGripPathSegmentCount(0, NO), (NSUInteger)0);
	XCTAssertEqual(FxGripPathSegmentCount(1, YES), (NSUInteger)0);
	XCTAssertEqual(FxGripPathSegmentCount(4, NO), (NSUInteger)3);
	XCTAssertEqual(FxGripPathSegmentCount(4, YES), (NSUInteger)4);
}

- (void)testBezierSegmentUsesTangentVectors
{
	FxVertex vertices[2] = {
		Vertex(0.0, 0.0, -0.1, 0.0, 0.1, 0.2, 0.0, kFxPathStyle_Bezier),
		Vertex(1.0, 1.0, -0.2, 0.1, 0.3, 0.0, 0.0, kFxPathStyle_Bezier),
	};
	FxGripCubicSegment segments[1];
	NSUInteger n = FxGripPathCubicSegments(vertices, 2, NO, segments, 1);
	XCTAssertEqual(n, (NSUInteger)1);
	// c1 = start.location + start.outTangent; c2 = end.location + end.inTangent.
	XCTAssertEqualWithAccuracy(segments[0].c1.x, 0.1, 1e-12);
	XCTAssertEqualWithAccuracy(segments[0].c1.y, 0.2, 1e-12);
	XCTAssertEqualWithAccuracy(segments[0].c2.x, 0.8, 1e-12);
	XCTAssertEqualWithAccuracy(segments[0].c2.y, 1.1, 1e-12);
}

- (void)testLinearSegmentIsStraight
{
	FxVertex vertices[2] = {
		Vertex(0.0, 0.0, 0.5, 0.5, 0.5, 0.5, 0.0, kFxPathStyle_Linear),
		Vertex(1.0, 1.0, 0.5, 0.5, 0.5, 0.5, 0.0, kFxPathStyle_Linear),
	};
	FxGripCubicSegment segments[1];
	FxGripPathCubicSegments(vertices, 2, NO, segments, 1);
	// Controls collapse onto the endpoints, ignoring the tangent vectors.
	XCTAssertTrue(CGPointEqualToPoint(segments[0].c1, segments[0].p0));
	XCTAssertTrue(CGPointEqualToPoint(segments[0].c2, segments[0].p3));
}

- (void)testRectangleStyleIsStraight
{
	FxVertex vertices[2] = {
		Vertex(0.0, 0.0, 0.5, 0.5, 0.5, 0.5, 0.0, kFxPathStyle_Rectangle),
		Vertex(1.0, 0.0, 0.5, 0.5, 0.5, 0.5, 0.0, kFxPathStyle_Rectangle),
	};
	FxGripCubicSegment segments[1];
	FxGripPathCubicSegments(vertices, 2, NO, segments, 1);
	XCTAssertTrue(CGPointEqualToPoint(segments[0].c1, segments[0].p0));
	XCTAssertTrue(CGPointEqualToPoint(segments[0].c2, segments[0].p3));
}

- (void)testXSplineWeightZeroGivesCatmullRomTangent
{
	// Middle vertex is XSpline weight 0; its outgoing control is a sixth of the neighbor span.
	FxVertex vertices[3] = {
		Vertex(0.0, 0.0, 0, 0, 0, 0, 0.0, kFxPathStyle_Linear),
		Vertex(1.0, 0.0, 0, 0, 0, 0, 0.0, kFxPathStyle_XSpline),
		Vertex(2.0, 3.0, 0, 0, 0, 0, 0.0, kFxPathStyle_Linear),
	};
	FxGripCubicSegment segments[2];
	FxGripPathCubicSegments(vertices, 3, NO, segments, 2);
	// Segment 1 starts at the middle vertex: c1 = mid + (next - prev)/6 = (1,0) + ((2,3)-(0,0))/6.
	XCTAssertEqualWithAccuracy(segments[1].c1.x, 1.0 + 2.0 / 6.0, 1e-12);
	XCTAssertEqualWithAccuracy(segments[1].c1.y, 0.0 + 3.0 / 6.0, 1e-12);
}

- (void)testXSplineWeightScalesTangent
{
	FxVertex vertices[3] = {
		Vertex(0.0, 0.0, 0, 0, 0, 0, 0.0, kFxPathStyle_Linear),
		Vertex(1.0, 0.0, 0, 0, 0, 0, 1.0, kFxPathStyle_XSpline),   // weight 1 -> factor 2
		Vertex(2.0, 3.0, 0, 0, 0, 0, 0.0, kFxPathStyle_Linear),
	};
	FxGripCubicSegment segments[2];
	FxGripPathCubicSegments(vertices, 3, NO, segments, 2);
	// Factor (1 + weight) = 2, so the tangent is twice the Catmull-Rom default.
	XCTAssertEqualWithAccuracy(segments[1].c1.x, 1.0 + 2.0 * (2.0 / 6.0), 1e-12);
	XCTAssertEqualWithAccuracy(segments[1].c1.y, 0.0 + 2.0 * (3.0 / 6.0), 1e-12);
}

- (void)testClosedPathWrapsLastSegment
{
	FxVertex vertices[3] = {
		Vertex(0.0, 0.0, 0, 0, 0, 0, 0.0, kFxPathStyle_Linear),
		Vertex(1.0, 0.0, 0, 0, 0, 0, 0.0, kFxPathStyle_Linear),
		Vertex(0.5, 1.0, 0, 0, 0, 0, 0.0, kFxPathStyle_Linear),
	};
	FxGripCubicSegment segments[3];
	NSUInteger n = FxGripPathCubicSegments(vertices, 3, YES, segments, 3);
	XCTAssertEqual(n, (NSUInteger)3);
	// The wrap segment runs from the last vertex back to the first.
	XCTAssertTrue(CGPointEqualToPoint(segments[2].p0, CGPointMake(0.5, 1.0)));
	XCTAssertTrue(CGPointEqualToPoint(segments[2].p3, CGPointMake(0.0, 0.0)));
}

- (void)testCubicSegmentPointHitsEndpoints
{
	FxGripCubicSegment segment = {
		CGPointMake(0, 0), CGPointMake(0, 1), CGPointMake(1, 1), CGPointMake(1, 0)
	};
	XCTAssertTrue(CGPointEqualToPoint(FxGripCubicSegmentPoint(segment, 0.0), segment.p0));
	XCTAssertTrue(CGPointEqualToPoint(FxGripCubicSegmentPoint(segment, 1.0), segment.p3));
	CGPoint mid = FxGripCubicSegmentPoint(segment, 0.5);
	XCTAssertEqualWithAccuracy(mid.x, 0.5, 1e-12);
	XCTAssertEqualWithAccuracy(mid.y, 0.75, 1e-12);
}

- (void)testCopyCubicSegmentsFromPathData
{
	FxVertex vertices[2] = {
		Vertex(0.0, 0.0, -0.1, 0.0, 0.1, 0.0, 0.0, kFxPathStyle_Bezier),
		Vertex(1.0, 0.0, -0.1, 0.0, 0.1, 0.0, 0.0, kFxPathStyle_Bezier),
	};
	FxGripPathData *path = [FxGripPathData pathWithVertices:vertices count:2 closed:NO];
	FxGripCubicSegment segments[1];
	NSUInteger n = [path copyCubicSegmentsToBuffer:segments capacity:1];
	XCTAssertEqual(n, (NSUInteger)1);
	XCTAssertEqualWithAccuracy(segments[0].c1.x, 0.1, 1e-12);
	XCTAssertEqualWithAccuracy(segments[0].c2.x, 0.9, 1e-12);
}

@end
