/*!
	@file       FxGripPathData.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripPathData
	@abstract   An immutable ordered list of FxPlug FxVertex path vertices with a closed flag.
	@discussion Introduced in FxGrip 0.1.0. The type backs an editable on-screen path whose vertex count
	            changes at runtime. It mirrors the FxPlug FxVertex layout, holding each vertex's location,
	            in and out tangent vectors, spline weight, and interpolation style in one custom-data
	            parameter. Edits return a new instance; there is no mutable variant.
*/

#ifndef FxGripPathData_h
#define FxGripPathData_h

#import <Foundation/Foundation.h>
#import <FxPlug/FxPlugSDK.h>

NS_ASSUME_NONNULL_BEGIN

/*!
	@class      FxGripPathData
	@abstract   An immutable ordered list of FxPlug `FxVertex` path vertices with a closed flag.
	@discussion Introduced in FxGrip 0.1.0. Backs an editable on-screen path whose vertex count
				changes at runtime, which a fixed set of point parameters cannot express. The
				whole list is stored in one custom-data parameter, mirroring the FxPlug
				`FxVertex` layout: each vertex carries a `location`, an `inTangent` and
				`outTangent` held as vectors from the location, an `xSplineWeight`, and an
				`interpStyle` (`FxPathStyle`). Tangents held as vectors move rigidly with the
				vertex, so relocating a vertex carries its tangents without extra bookkeeping.
				Locations are object-space coordinates, matching the point parameters the other
				on-screen-control parts read. Edits return a new instance; there is no mutable
				variant.
*/
@interface FxGripPathData : NSObject <NSSecureCoding, NSCopying>

/*! The number of vertices. */
@property (readonly) NSUInteger vertexCount;

/*! YES closes the path's last vertex back to the first. */
@property (readonly) BOOL closed;

/*! The vertex at an index, or a zeroed `FxVertex` (linear, no tangents) when out of range. */
- (FxVertex)vertexAtIndex:(NSUInteger)index;

/*! The location of the vertex at an index, or CGPointZero when out of range. */
- (CGPoint)locationAtIndex:(NSUInteger)index;

/*! An empty path with the given closed flag. */
+ (instancetype)emptyPathClosed:(BOOL)closed;

/*! A path from a vertex buffer. Returns nil when vertices is NULL and count is nonzero. */
+ (instancetype)pathWithVertices:(nullable const FxVertex *)vertices
						   count:(NSUInteger)count
						  closed:(BOOL)closed;

/*! A linear path from locations alone: zero tangents, zero weight, `kFxPathStyle_Linear`. */
+ (instancetype)pathWithLocations:(nullable const CGPoint *)locations
							count:(NSUInteger)count
						   closed:(BOOL)closed;

/*! A new path with vertex inserted at index, clamped to [0, vertexCount]. */
- (instancetype)byInsertingVertex:(FxVertex)vertex atIndex:(NSUInteger)index;

/*! A new path with the vertex at index removed. Returns self when the index is out of range. */
- (instancetype)byRemovingVertexAtIndex:(NSUInteger)index;

/*! A new path with the vertex at index replaced. Returns self when the index is out of range. */
- (instancetype)byReplacingVertexAtIndex:(NSUInteger)index withVertex:(FxVertex)vertex;

/*!
	@method     byReplacingLocationAtIndex:withLocation:
	@abstract   A new path with only the location at index changed.
	@discussion The tangent vectors are left unchanged, so they move rigidly with the vertex.
				Returns self when the index is out of range.
*/
- (instancetype)byReplacingLocationAtIndex:(NSUInteger)index withLocation:(CGPoint)location;

/*! A new path with every location offset by delta; the tangent vectors are unchanged. */
- (instancetype)byTranslatingBy:(CGPoint)delta;

/*! Writes the vertices into buffer, at most capacity, and returns the number written. */
- (NSUInteger)copyVerticesToBuffer:(FxVertex *)buffer capacity:(NSUInteger)capacity;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripPathData_h */
