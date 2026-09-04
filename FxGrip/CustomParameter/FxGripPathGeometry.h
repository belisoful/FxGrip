//
//  FxGripPathGeometry.h
//  FxGrip
//

#ifndef FxGripPathGeometry_h
#define FxGripPathGeometry_h

#import <Foundation/Foundation.h>
#import <FxPlug/FxPlugSDK.h>
#import "FxGripPathData.h"

NS_ASSUME_NONNULL_BEGIN

/*!
	@struct     FxGripCubicSegment
	@abstract   One cubic Bézier segment between two path vertices.
	@discussion p0 and p3 lie on the path; c1 and c2 are the start and end control points. A
				straight segment has c1 == p0 and c2 == p3. All points are in the vertex list's
				own coordinate space.
*/
typedef struct FxGripCubicSegment {
	CGPoint p0;
	CGPoint c1;
	CGPoint c2;
	CGPoint p3;
} FxGripCubicSegment;

/*!
	@function   FxGripPathSegmentCount
	@abstract   The number of cubic segments a path produces.
	@discussion vertexCount when closed, vertexCount - 1 when open, 0 for fewer than two vertices.
*/
FOUNDATION_EXPORT NSUInteger FxGripPathSegmentCount(NSUInteger vertexCount, BOOL closed);

/*!
	@function   FxGripPathCubicSegments
	@abstract   Converts an FxVertex list into cubic Bézier segments, resolving each interpStyle.
	@discussion Linear and Rectangle vertices collapse their controls onto the endpoints, so the
				segment is straight. Bezier and SuperEllipse vertices use their inTangent and
				outTangent vectors. An XSpline vertex derives a Catmull-Rom tangent from its
				neighbors, its magnitude scaled by (1 + xSplineWeight); weight 0 reproduces the
				Catmull-Rom tangent. A segment's shape comes from its start vertex's outgoing side
				and its end vertex's incoming side, so mixed styles compose. Writes at most
				capacity segments and returns the number written.
*/
FOUNDATION_EXPORT NSUInteger FxGripPathCubicSegments(const FxVertex * _Nullable vertices,
													 NSUInteger count,
													 BOOL closed,
													 FxGripCubicSegment * _Nullable segments,
													 NSUInteger capacity);

/*! Evaluates one cubic segment at parameter t in [0, 1]. */
FOUNDATION_EXPORT CGPoint FxGripCubicSegmentPoint(FxGripCubicSegment segment, double t);

/*!
	@category   FxGripPathData (Geometry)
	@abstract   Cubic-segment conversion for a stored path.
*/
@interface FxGripPathData (Geometry)

/*! Converts the path's vertices to cubic segments; writes at most capacity, returns the count. */
- (NSUInteger)copyCubicSegmentsToBuffer:(FxGripCubicSegment *)buffer capacity:(NSUInteger)capacity;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripPathGeometry_h */
