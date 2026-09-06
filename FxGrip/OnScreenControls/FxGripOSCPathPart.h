/*!
	@file       FxGripOSCPathPart.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripOSCPathPart
	@abstract   An editable on-screen path part built from FxPlug FxVertex vertices.
	@discussion Introduced in FxGrip 0.1.0. One part draws and edits a whole path: moving vertices and
	            tangents, inserting and deleting vertices, and dragging the whole path. It reads and
	            writes through a custom-data FxGripPathData backing or a per-parameter backing.
	            Drawing and hit-testing run through FxGripPathGeometry.
*/

#ifndef FxGripOSCPathPart_h
#define FxGripOSCPathPart_h

#import <Foundation/Foundation.h>
#import "FxGripOnScreenControl.h"
#import "FxGripOSCPart.h"
#import "FxGripPathData.h"
#import "FxGripPathGeometry.h"

NS_ASSUME_NONNULL_BEGIN

/*!
	@enum       FxGripOSCPathOptions
	@abstract   The interactive features a single FxGripOSCPathPart turns on.
	@discussion One part owns the whole path and resolves which vertex, tangent, or segment a
				gesture touches from its own recorded hit, the way FxGripOSCEditablePolygonPart
				does. The flags select which of those interactions are live.
	@constant   FxGripOSCPathOptionVertexHandles   Draws and drags a handle at each vertex location.
	@constant   FxGripOSCPathOptionTangentHandles  Draws and drags the in and out tangent handles
											 of the Bézier-family vertices.
	@constant   FxGripOSCPathOptionEditable        Inserts a vertex on a segment click, deletes the
											 selected vertex on Delete or Command-click, and toggles
											 a vertex between corner and smooth on a double-click.
											 Available only with the custom-data backing.
	@constant   FxGripOSCPathOptionBodyDrag        Drags a segment to move the whole path.
*/
typedef NS_OPTIONS(NSUInteger, FxGripOSCPathOptions) {
	FxGripOSCPathOptionVertexHandles	= 1 << 0,
	FxGripOSCPathOptionTangentHandles	= 1 << 1,
	FxGripOSCPathOptionEditable			= 1 << 2,
	FxGripOSCPathOptionBodyDrag			= 1 << 3,

	FxGripOSCPathOptionsAll				= NSUIntegerMax,
};

/*!
	@class      FxGripOSCPathPart
	@abstract   One on-screen path built from FxPlug `FxVertex` vertices, editable in place.
	@discussion Introduced in FxGrip 0.1.0. A single part draws a path and, per its options, edits
				it: moving vertices and tangents, inserting and deleting vertices, and dragging
				the whole path. It reads and writes its vertices through one of two backings:

				- Custom-data backing (`pathParameterID`): the whole path lives in one
				  `FxGripPathData` parameter, so the vertex count changes at runtime and the
				  Editable option is available.
				- Per-parameter backing (`locationParameterIDs` and the optional tangent, weight,
				  and style arrays): each field is its own host parameter, individually
				  keyframeable, at a fixed vertex count.

				Tangents are vectors from the vertex location, matching `FxVertex`, so moving a
				vertex carries its tangents. Drawing and hit-testing run through
				``FxGripPathGeometry``, so every `interpStyle` renders correctly. Set one backing;
				`pathParameterID` wins when both are set.
*/
@interface FxGripOSCPathPart : FxGripOSCPart

/*! The custom-data parameter holding an FxGripPathData; 0 selects the per-parameter backing. */
@property (nonatomic, assign) FxParameterId pathParameterID;

/*! Per-parameter backing: the vertex location parameters, in path order. */
@property (nonatomic, copy, nullable) NSArray<NSNumber *> *locationParameterIDs;

/*! Per-parameter backing: the incoming tangent vector parameters, one per vertex. */
@property (nonatomic, copy, nullable) NSArray<NSNumber *> *inTangentParameterIDs;

/*! Per-parameter backing: the outgoing tangent vector parameters, one per vertex. */
@property (nonatomic, copy, nullable) NSArray<NSNumber *> *outTangentParameterIDs;

/*! Per-parameter backing: the optional x-spline weight parameters, one per vertex. */
@property (nonatomic, copy, nullable) NSArray<NSNumber *> *xSplineWeightParameterIDs;

/*! Per-parameter backing: the per-vertex FxPathStyle values as NSNumbers. A nil or short array
	defaults a vertex to Bézier when it has tangent parameters, else Linear. */
@property (nonatomic, copy, nullable) NSArray<NSNumber *> *interpStyles;

/*! Per-parameter backing: closes the path's last vertex back to the first. The custom-data
	backing carries its own closed flag. Defaults to NO. */
@property (nonatomic, assign) BOOL closed;

/*! The live interactions. Defaults to FxGripOSCPathOptionVertexHandles. */
@property (nonatomic, assign) FxGripOSCPathOptions options;

/*! The outline stroke color. Defaults to the standard outline color. */
@property (nonatomic, assign) simd_float4 color;


/*! The hit distance from a segment, in canvas pixels. Defaults to 6. */
@property (nonatomic, assign) double hitRadius;

/*! The hit radius around a vertex or tangent handle, in canvas pixels. Defaults to 10. */
@property (nonatomic, assign) double vertexHitRadius;

/*! Half a handle's side, in canvas pixels. Defaults to 4. */
@property (nonatomic, assign) double handleRadius;

/*! The Editable path will not delete below this many vertices. Defaults to 2. */
@property (nonatomic, assign) NSUInteger minimumVertexCount;

/*! The selected vertex, or -1 when none is selected. */
@property (nonatomic, readonly) NSInteger selectedVertexIndex;

/*! A path part on a custom-data FxGripPathData parameter. */
+ (nonnull instancetype)pathPartWithID:(NSInteger)partID
					   pathParameterID:(FxParameterId)pathParameterID
							   options:(FxGripOSCPathOptions)options;

/*! A path part on per-parameter location parameters (linear unless tangent arrays are set). */
+ (nonnull instancetype)pathPartWithID:(NSInteger)partID
				  locationParameterIDs:(nonnull NSArray<NSNumber *> *)locationParameterIDs
								closed:(BOOL)closed
							   options:(FxGripOSCPathOptions)options;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripOSCPathPart_h */
