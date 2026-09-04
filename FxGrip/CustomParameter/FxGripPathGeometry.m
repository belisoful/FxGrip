//
//  FxGripPathGeometry.m
//  FxGrip
//

#import "FxGripPathGeometry.h"

static CGPoint FxGripPathAdd(CGPoint a, CGPoint b)
{
	return CGPointMake(a.x + b.x, a.y + b.y);
}

static CGPoint FxGripPathSub(CGPoint a, CGPoint b)
{
	return CGPointMake(a.x - b.x, a.y - b.y);
}

static CGPoint FxGripPathScale(CGPoint a, double s)
{
	return CGPointMake(a.x * s, a.y * s);
}

NSUInteger FxGripPathSegmentCount(NSUInteger vertexCount, BOOL closed)
{
	if (vertexCount < 2) {
		return 0;
	}
	return closed ? vertexCount : vertexCount - 1;
}

/*! The outgoing and incoming control vectors (relative to location) for one vertex. */
static void FxGripPathVertexControls(const FxVertex *vertices,
									 NSUInteger count,
									 BOOL closed,
									 NSUInteger index,
									 CGPoint *outControl,
									 CGPoint *inControl)
{
	FxVertex vertex = vertices[index];
	switch (vertex.interpStyle) {
		case kFxPathStyle_Linear:
		case kFxPathStyle_Rectangle:
			*outControl = CGPointZero;
			*inControl = CGPointZero;
			break;
		case kFxPathStyle_XSpline: {
			CGPoint previous, next;
			if (closed) {
				previous = vertices[(index + count - 1) % count].location;
				next = vertices[(index + 1) % count].location;
			} else {
				previous = (index > 0) ? vertices[index - 1].location : vertex.location;
				next = (index + 1 < count) ? vertices[index + 1].location : vertex.location;
			}
			// Catmull-Rom tangent (a sixth of the neighbor span), tension scaled by the weight.
			CGPoint tangent = FxGripPathScale(FxGripPathSub(next, previous),
											  (1.0 / 6.0) * (1.0 + vertex.xSplineWeight));
			*outControl = tangent;
			*inControl = FxGripPathScale(tangent, -1.0);
			break;
		}
		case kFxPathStyle_Bezier:
		case kFxPathStyle_SuperEllipse:
		default:
			*outControl = vertex.outTangent;
			*inControl = vertex.inTangent;
			break;
	}
}

NSUInteger FxGripPathCubicSegments(const FxVertex *vertices,
								   NSUInteger count,
								   BOOL closed,
								   FxGripCubicSegment *segments,
								   NSUInteger capacity)
{
	if (vertices == NULL || segments == NULL) {
		return 0;
	}
	NSUInteger segmentCount = FxGripPathSegmentCount(count, closed);
	NSUInteger written = MIN(segmentCount, capacity);
	for (NSUInteger index = 0; index < written; index++) {
		NSUInteger startIndex = index;
		NSUInteger endIndex = (index + 1) % count;
		CGPoint startOut = CGPointZero, startIn = CGPointZero;
		CGPoint endOut = CGPointZero, endIn = CGPointZero;
		FxGripPathVertexControls(vertices, count, closed, startIndex, &startOut, &startIn);
		FxGripPathVertexControls(vertices, count, closed, endIndex, &endOut, &endIn);
		FxGripCubicSegment segment;
		segment.p0 = vertices[startIndex].location;
		segment.p3 = vertices[endIndex].location;
		segment.c1 = FxGripPathAdd(vertices[startIndex].location, startOut);
		segment.c2 = FxGripPathAdd(vertices[endIndex].location, endIn);
		segments[index] = segment;
	}
	return written;
}

CGPoint FxGripCubicSegmentPoint(FxGripCubicSegment segment, double t)
{
	double u = 1.0 - t;
	double b0 = u * u * u;
	double b1 = 3.0 * u * u * t;
	double b2 = 3.0 * u * t * t;
	double b3 = t * t * t;
	return CGPointMake(b0 * segment.p0.x + b1 * segment.c1.x + b2 * segment.c2.x + b3 * segment.p3.x,
					   b0 * segment.p0.y + b1 * segment.c1.y + b2 * segment.c2.y + b3 * segment.p3.y);
}

@implementation FxGripPathData (Geometry)

- (NSUInteger)copyCubicSegmentsToBuffer:(FxGripCubicSegment *)buffer capacity:(NSUInteger)capacity
{
	NSUInteger count = self.vertexCount;
	if (count == 0 || buffer == NULL) {
		return 0;
	}
	FxVertex *vertices = malloc(count * sizeof(FxVertex));
	if (vertices == NULL) {
		return 0;
	}
	[self copyVerticesToBuffer:vertices capacity:count];
	NSUInteger written = FxGripPathCubicSegments(vertices, count, self.closed, buffer, capacity);
	free(vertices);
	return written;
}

@end
