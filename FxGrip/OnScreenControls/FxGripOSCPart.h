//
//  FxGripOSCPart.h
//  FxGrip
//

#ifndef FxGripOSCPart_h
#define FxGripOSCPart_h

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <Metal/Metal.h>
#import "FxOnScreenControlBase.h"

/*!
	@enum       FxGripOSCShapeOptions
	@abstract   Selects the parts a shape family's flag constructor composes.
	@discussion Each family honors the flags that apply to it and ignores the rest.
				Part numbers are assigned sequentially from firstPartID in the
				family's documented inclusion order, counting only the parts the
				flags include; read partID off the returned parts when handles are
				optional.
*/
typedef NS_OPTIONS(NSUInteger, FxGripOSCShapeOptions) {
	FxGripOSCShapeOptionBody			= 1 << 0,
	FxGripOSCShapeOptionCornerHandles	= 1 << 1,
	FxGripOSCShapeOptionVertexHandles	= 1 << 2,
	FxGripOSCShapeOptionRadiusHandle	= 1 << 3,
	FxGripOSCShapeOptionRotationHandle	= 1 << 4,
	FxGripOSCShapeOptionTangentHandles	= 1 << 5,

	FxGripOSCShapeOptionsAll			= NSUIntegerMax,
};

/*!
	@class      FxGripOSCPart
	@abstract   One interactive piece of an on-screen control.
	@discussion Introduced in FxGrip 1.0. A part owns a nonzero part number, answers
				hit tests, draws itself, and applies drags. FxOnScreenControlBase
				hit-tests parts last-added first (the part drawn on top wins), draws
				them in order, and routes a drag to the active part. The base class
				answers no hit, ignores drags, and draws nothing.
*/
@interface FxGripOSCPart : NSObject

@property (nonatomic, assign) NSInteger partID;

/*! The owning control; set by addPart:. */
@property (nonatomic, assign, nullable) FxOnScreenControlBase *control;

/*! The cursor shown while the pointer hovers this part. A nil cursor uses the arrow. The
	base applies it through the host's OSC API on mouse-moved. */
@property (nonatomic, strong, nullable) NSCursor *cursor;

- (nonnull instancetype)initWithPartID:(NSInteger)partID;

- (BOOL)hitTestObjectPoint:(CGPoint)objectPoint canvasPoint:(CGPoint)canvasPoint atTime:(CMTime)time;

/*! Applies the drag; returns YES when the effect must re-render. */
- (BOOL)dragToObjectPoint:(CGPoint)objectPoint
			  objectDelta:(CGPoint)objectDelta
				modifiers:(FxModifierKeys)modifiers
				   atTime:(CMTime)time;

- (void)drawSelected:(BOOL)selected
		  canvasSize:(CGSize)canvasSize
	  commandEncoder:(nonnull id<MTLRenderCommandEncoder>)commandEncoder
			  atTime:(CMTime)time;

/*!
	@method     mouseDownAtObjectPoint:canvasPoint:modifiers:atTime:
	@abstract   Handles a mouse-down on this part before any drag; returns YES to re-render.
	@discussion Introduced in FxGrip 1.0. The base forwards the event only to the active
				part. The base part does nothing and returns NO; a part that edits on click
				(inserting a polygon vertex, for example) overrides this.
*/
- (BOOL)mouseDownAtObjectPoint:(CGPoint)objectPoint
				   canvasPoint:(CGPoint)canvasPoint
					 modifiers:(FxModifierKeys)modifiers
						atTime:(CMTime)time;

/*!
	@method     keyDownWithKey:modifiers:atTime:
	@abstract   Handles a key press; returns YES when the part consumed it and must re-render.
	@discussion Introduced in FxGrip 1.0. The base forwards every key press to every part,
				since a key event carries no active part. The base part does nothing and
				returns NO; a part that edits on a key (deleting a selected vertex, for
				example) overrides this.
*/
- (BOOL)keyDownWithKey:(unsigned short)asciiKey
			 modifiers:(FxModifierKeys)modifiers
				atTime:(CMTime)time;

/*!
	@method     handlesOptionDrag
	@abstract   YES when the part gives the Option modifier its own meaning during a drag.
	@discussion Introduced in FxGrip 1.0. The control applies Option as a fine (slow) drag at the
				base level for every part. A part that reads Option itself while dragging (a Bézier
				tangent breaking its mirror) returns YES so the base leaves Option to it. The base
				part returns NO.
*/
- (BOOL)handlesOptionDrag;

@end

/*!
	@class      FxGripOSCPointHandlePart
	@abstract   A square handle bound to a point parameter.
	@discussion The handle follows the cursor: a drag writes the pointer's object
				position to the parameter. Hit testing measures canvas-pixel distance
				to the handle, so the grab target stays the same size at every zoom.
*/
@interface FxGripOSCPointHandlePart : FxGripOSCPart

@property (nonatomic, assign) FxParameterId parameterID;

/*! The hit radius around the handle, in canvas pixels. Defaults to 10. */
@property (nonatomic, assign) double hitRadius;

/*! Half the handle square's side, in canvas pixels. Defaults to 4. */
@property (nonatomic, assign) double handleRadius;

+ (nonnull instancetype)partWithID:(NSInteger)partID parameterID:(FxParameterId)parameterID;

@end

/*!
	@class      FxGripOSCRectPart
	@abstract   A rectangle bound to lower-left and upper-right point parameters.
	@discussion A hit is any object point inside the rectangle; a drag moves both
				corner parameters by the drag's object-space delta.
*/
/*!
	@enum       FxGripOSCRectCorner
	@abstract   Names a corner for FxGripOSCRectCornerPart and FxGripOSCBoxCornerPart.
*/
typedef NS_ENUM(NSInteger, FxGripOSCRectCorner) {
	FxGripOSCRectCornerLowerLeft	= 0,
	FxGripOSCRectCornerLowerRight	= 1,
	FxGripOSCRectCornerUpperRight	= 2,
	FxGripOSCRectCornerUpperLeft	= 3,
};

@interface FxGripOSCRectPart : FxGripOSCPart

@property (nonatomic, assign) FxParameterId lowerLeftParameterID;
@property (nonatomic, assign) FxParameterId upperRightParameterID;

/*!
	@property   angleParameterID
	@abstract   An optional rotation overlay; 0 (the default) keeps the rectangle
				axis-aligned.
	@discussion The corner parameters stay in pre-rotation coordinates; the
				rectangle rotates about their midpoint, rigidly in the input-pixel
				frame. Hit tests unrotate the pointer, so hits and drags land in the
				stored coordinate space. The same property on FxGripOSCRectCornerPart
				and FxGripOSCRectRotationHandlePart completes the rotated family.
*/
@property (nonatomic, assign) FxParameterId angleParameterID;

/*! Radians per one unit of the angle parameter. Defaults to 1. */
@property (nonatomic, assign) double radiansPerUnit;

+ (nonnull instancetype)partWithID:(NSInteger)partID
			  lowerLeftParameterID:(FxParameterId)lowerLeftParameterID
			 upperRightParameterID:(FxParameterId)upperRightParameterID;

@end

/*!
	@class      FxGripOSCRectRotationHandlePart
	@abstract   A rotation spoke for the two-corner rectangle's angle overlay.
	@discussion The spoke runs from the corners' midpoint to a tip handle at a fixed
				canvas radius, aimed by the angle parameter; dragging writes the
				pointer's canvas-space angle around the midpoint.
*/
@interface FxGripOSCRectRotationHandlePart : FxGripOSCPart

@property (nonatomic, assign) FxParameterId lowerLeftParameterID;
@property (nonatomic, assign) FxParameterId upperRightParameterID;
@property (nonatomic, assign) FxParameterId angleParameterID;

/*! Radians per one unit of the angle parameter. Defaults to 1. */
@property (nonatomic, assign) double radiansPerUnit;

/*! The spoke length, in canvas pixels. Defaults to 40. */
@property (nonatomic, assign) double spokeRadius;

/*! The hit radius around the tip handle, in canvas pixels. Defaults to 10. */
@property (nonatomic, assign) double hitRadius;

/*! Half the tip handle square's side, in canvas pixels. Defaults to 4. */
@property (nonatomic, assign) double handleRadius;

+ (nonnull instancetype)partWithID:(NSInteger)partID
			  lowerLeftParameterID:(FxParameterId)lowerLeftParameterID
			 upperRightParameterID:(FxParameterId)upperRightParameterID
				  angleParameterID:(FxParameterId)angleParameterID;

@end

/*!
	@class      FxGripOSCBoxPart
	@abstract   A rotatable box bound to center point, pixel width, pixel height,
				and angle parameters.
	@discussion The Motion-style box model. Width and height are in input-image
				pixels; the box rotates rigidly about its center in the input-pixel
				frame. A hit is any pointer inside the rotated box; a drag moves the
				center. angleParameterID 0 leaves the box axis-aligned.

				boxPartsWithBodyID:... composes the body, four
				FxGripOSCBoxCornerPart resize handles, and an FxGripOSCAngleDialPart
				rotation spoke on the center.
*/
@interface FxGripOSCBoxPart : FxGripOSCPart

@property (nonatomic, assign) FxParameterId centerParameterID;
@property (nonatomic, assign) FxParameterId widthParameterID;
@property (nonatomic, assign) FxParameterId heightParameterID;

/*! The rotation parameter; 0 (the default) keeps the box axis-aligned. */
@property (nonatomic, assign) FxParameterId angleParameterID;

/*! Radians per one unit of the angle parameter. Defaults to 1. */
@property (nonatomic, assign) double radiansPerUnit;

+ (nonnull instancetype)partWithID:(NSInteger)partID
				 centerParameterID:(FxParameterId)centerParameterID
				  widthParameterID:(FxParameterId)widthParameterID
				 heightParameterID:(FxParameterId)heightParameterID
				  angleParameterID:(FxParameterId)angleParameterID;

/*! The body, four corner handles numbered firstCornerID through firstCornerID + 3
	in lower-left, lower-right, upper-right, upper-left order, and the rotation
	dial. Handles follow the body, so they win overlapping hits. */
+ (nonnull NSArray<FxGripOSCPart *> *)boxPartsWithBodyID:(NSInteger)bodyID
										   firstCornerID:(NSInteger)firstCornerID
										rotationHandleID:(NSInteger)rotationHandleID
									   centerParameterID:(FxParameterId)centerParameterID
										widthParameterID:(FxParameterId)widthParameterID
									   heightParameterID:(FxParameterId)heightParameterID
										angleParameterID:(FxParameterId)angleParameterID;

/*! Flag form. Inclusion order: Body, CornerHandles (LL, LR, UR, UL),
	RotationHandle. The rotation dial is omitted when angleParameterID is 0. */
+ (nonnull NSArray<FxGripOSCPart *> *)boxPartsWithOptions:(FxGripOSCShapeOptions)options
											  firstPartID:(NSInteger)firstPartID
										centerParameterID:(FxParameterId)centerParameterID
										 widthParameterID:(FxParameterId)widthParameterID
										heightParameterID:(FxParameterId)heightParameterID
										 angleParameterID:(FxParameterId)angleParameterID;

@end

/*!
	@class      FxGripOSCBoxCornerPart
	@abstract   A resize handle on one corner of an FxGripOSCBoxPart-model box.
	@discussion The handle sits on the rotated corner. Dragging resizes the box
				about its fixed center: the pointer's position in the box's local
				frame writes twice its absolute local x as the width and twice its
				absolute local y as the height. The center and angle do not change.
*/
@interface FxGripOSCBoxCornerPart : FxGripOSCPart

@property (nonatomic, assign) FxParameterId centerParameterID;
@property (nonatomic, assign) FxParameterId widthParameterID;
@property (nonatomic, assign) FxParameterId heightParameterID;
@property (nonatomic, assign) FxParameterId angleParameterID;
@property (nonatomic, assign) double radiansPerUnit;
@property (nonatomic, assign) FxGripOSCRectCorner corner;

/*! The hit radius around the handle, in canvas pixels. Defaults to 10. */
@property (nonatomic, assign) double hitRadius;

/*! Half the handle square's side, in canvas pixels. Defaults to 4. */
@property (nonatomic, assign) double handleRadius;

+ (nonnull instancetype)partWithID:(NSInteger)partID
							corner:(FxGripOSCRectCorner)corner
				 centerParameterID:(FxParameterId)centerParameterID
				  widthParameterID:(FxParameterId)widthParameterID
				 heightParameterID:(FxParameterId)heightParameterID
				  angleParameterID:(FxParameterId)angleParameterID;

@end

/*!
	@class      FxGripOSCLinePart
	@abstract   A line segment bound to start and end point parameters.
	@discussion Serves gradients, wipes, and motion vectors. A hit is any point
				within hitRadius canvas pixels of the segment; a drag moves both
				endpoint parameters by the drag's object-space delta.

				gradientPartsWithLineID:... composes the full control: the line body
				plus a point handle on each endpoint. The handles are listed after
				the body, so they win overlapping hits.
*/
@interface FxGripOSCLinePart : FxGripOSCPart

@property (nonatomic, assign) FxParameterId startParameterID;
@property (nonatomic, assign) FxParameterId endParameterID;

/*! The hit distance from the segment, in canvas pixels. Defaults to 6. */
@property (nonatomic, assign) double hitRadius;

+ (nonnull instancetype)partWithID:(NSInteger)partID
				  startParameterID:(FxParameterId)startParameterID
					endParameterID:(FxParameterId)endParameterID;

/*! The line body plus an FxGripOSCPointHandlePart per endpoint, in add order. */
+ (nonnull NSArray<FxGripOSCPart *> *)gradientPartsWithLineID:(NSInteger)lineID
												startHandleID:(NSInteger)startHandleID
												  endHandleID:(NSInteger)endHandleID
											 startParameterID:(FxParameterId)startParameterID
											   endParameterID:(FxParameterId)endParameterID;

/*! Flag form. Inclusion order: Body, VertexHandles (start then end). */
+ (nonnull NSArray<FxGripOSCPart *> *)linePartsWithOptions:(FxGripOSCShapeOptions)options
											   firstPartID:(NSInteger)firstPartID
										  startParameterID:(FxParameterId)startParameterID
											endParameterID:(FxParameterId)endParameterID;

@end

/*!
	@class      FxGripOSCAngleDialPart
	@abstract   A rotation spoke bound to a center point parameter and an angle
				parameter.
	@discussion The spoke runs from the center to a tip handle at a fixed canvas
				radius; dragging the tip writes the angle of the pointer around the
				center, measured counterclockwise from +x in canvas space. The
				parameter's unit is set by radiansPerUnit: 1 for a radian parameter
				(the FxPlug angle-slider convention), M_PI / 180 for degrees.
*/
@interface FxGripOSCAngleDialPart : FxGripOSCPart

@property (nonatomic, assign) FxParameterId centerParameterID;
@property (nonatomic, assign) FxParameterId angleParameterID;

/*! Radians per one unit of the angle parameter. Defaults to 1. */
@property (nonatomic, assign) double radiansPerUnit;

/*! The spoke length, in canvas pixels. Defaults to 40. */
@property (nonatomic, assign) double spokeRadius;

/*! The hit radius around the tip handle, in canvas pixels. Defaults to 10. */
@property (nonatomic, assign) double hitRadius;

/*! Half the tip handle square's side, in canvas pixels. Defaults to 4. */
@property (nonatomic, assign) double handleRadius;

+ (nonnull instancetype)partWithID:(NSInteger)partID
				 centerParameterID:(FxParameterId)centerParameterID
				  angleParameterID:(FxParameterId)angleParameterID;

@end

/*!
	@class      FxGripOSCRectCornerPart
	@abstract   A resize handle on one corner of a rectangle bound to lower-left and
				upper-right point parameters.
	@discussion Dragging writes the pointer's object position into the corner's
				components: the lower-right corner, for example, writes x to the
				upper-right parameter and y to the lower-left parameter. The corners
				are not normalized; a corner dragged past its opposite inverts the
				rectangle, matching the host's parameter behavior.
*/
@interface FxGripOSCRectCornerPart : FxGripOSCPart

@property (nonatomic, assign) FxParameterId lowerLeftParameterID;
@property (nonatomic, assign) FxParameterId upperRightParameterID;
@property (nonatomic, assign) FxGripOSCRectCorner corner;

/*! The angle overlay, matching FxGripOSCRectPart's; 0 (the default) is axis-aligned. */
@property (nonatomic, assign) FxParameterId angleParameterID;

/*! Radians per one unit of the angle parameter. Defaults to 1. */
@property (nonatomic, assign) double radiansPerUnit;

/*! The hit radius around the handle, in canvas pixels. Defaults to 10. */
@property (nonatomic, assign) double hitRadius;

/*! Half the handle square's side, in canvas pixels. Defaults to 4. */
@property (nonatomic, assign) double handleRadius;

+ (nonnull instancetype)partWithID:(NSInteger)partID
							corner:(FxGripOSCRectCorner)corner
			  lowerLeftParameterID:(FxParameterId)lowerLeftParameterID
			 upperRightParameterID:(FxParameterId)upperRightParameterID;

@end

/*!
	@class      FxGripOSCCirclePart
	@abstract   A circle bound to a center point parameter and a pixel-radius float
				parameter.
	@discussion The radius parameter is in input-image pixels; hit testing and
				drawing normalize it against the input bounds, correcting for the
				image's aspect ratio. A drag moves the center by the object-space
				delta.
*/
@interface FxGripOSCCirclePart : FxGripOSCPart

@property (nonatomic, assign) FxParameterId centerParameterID;
@property (nonatomic, assign) FxParameterId radiusParameterID;

/*! The rim segments drawn. Defaults to 24; clamped to at least 3. */
@property (nonatomic, assign) NSUInteger segmentCount;

+ (nonnull instancetype)partWithID:(NSInteger)partID
				 centerParameterID:(FxParameterId)centerParameterID
				 radiusParameterID:(FxParameterId)radiusParameterID;

/*! The circle body plus an FxGripOSCCircleRadiusHandlePart on its rim. */
+ (nonnull NSArray<FxGripOSCPart *> *)circlePartsWithBodyID:(NSInteger)bodyID
											  radiusHandleID:(NSInteger)radiusHandleID
										   centerParameterID:(FxParameterId)centerParameterID
										   radiusParameterID:(FxParameterId)radiusParameterID;

/*! The movable, resizable, rotatable circle: the body, the radius handle at
	rimAngle 0, and an FxGripOSCRotationHandlePart riding the rim at the angle
	parameter's direction. */
+ (nonnull NSArray<FxGripOSCPart *> *)circlePartsWithBodyID:(NSInteger)bodyID
											 radiusHandleID:(NSInteger)radiusHandleID
										   rotationHandleID:(NSInteger)rotationHandleID
										  centerParameterID:(FxParameterId)centerParameterID
										  radiusParameterID:(FxParameterId)radiusParameterID
										   angleParameterID:(FxParameterId)angleParameterID;

/*! Flag form. Inclusion order: Body, RadiusHandle, RotationHandle. The rotation
	handle is omitted when angleParameterID is 0. */
+ (nonnull NSArray<FxGripOSCPart *> *)circlePartsWithOptions:(FxGripOSCShapeOptions)options
												 firstPartID:(NSInteger)firstPartID
										   centerParameterID:(FxParameterId)centerParameterID
										   radiusParameterID:(FxParameterId)radiusParameterID
											angleParameterID:(FxParameterId)angleParameterID;

@end

/*!
	@class      FxGripOSCCircleRadiusHandlePart
	@abstract   A handle on a circle's rim that resizes the radius parameter.
	@discussion The handle sits on the rim at rimAngle. Dragging writes the
				aspect-corrected object-space distance from the center, scaled to
				input-image pixels, into the radius parameter; the companion
				FxGripOSCCirclePart's drag moves the center, so together they give a
				movable, resizable circle (circlePartsWithBodyID:... composes both).
*/
@interface FxGripOSCCircleRadiusHandlePart : FxGripOSCPart

@property (nonatomic, assign) FxParameterId centerParameterID;
@property (nonatomic, assign) FxParameterId radiusParameterID;

/*! The handle's position on the rim, radians counterclockwise from +x. Defaults to 0. */
@property (nonatomic, assign) double rimAngle;

/*! The hit radius around the handle, in canvas pixels. Defaults to 10. */
@property (nonatomic, assign) double hitRadius;

/*! Half the handle square's side, in canvas pixels. Defaults to 4. */
@property (nonatomic, assign) double handleRadius;

+ (nonnull instancetype)partWithID:(NSInteger)partID
				 centerParameterID:(FxParameterId)centerParameterID
				 radiusParameterID:(FxParameterId)radiusParameterID;

@end

/*!
	@class      FxGripOSCRotationHandlePart
	@abstract   A rotation handle on a circle's rim, bound to center point, pixel
				radius, and angle parameters.
	@discussion The handle sits on the rim at the angle parameter's direction, with
				a spoke drawn from the center. Dragging writes the pointer's angle
				around the center, measured counterclockwise from +x in canvas
				space; the radius parameter only positions the handle. With
				FxGripOSCCirclePart and FxGripOSCCircleRadiusHandlePart it forms
				the movable, resizable, rotatable circle
				(circlePartsWithBodyID:radiusHandleID:rotationHandleID:... composes
				all three). radiansPerUnit follows the dial's convention: 1 for a
				radian parameter, M_PI / 180 for degrees.
*/
@interface FxGripOSCRotationHandlePart : FxGripOSCPart

@property (nonatomic, assign) FxParameterId centerParameterID;
@property (nonatomic, assign) FxParameterId radiusParameterID;
@property (nonatomic, assign) FxParameterId angleParameterID;

/*! Radians per one unit of the angle parameter. Defaults to 1. */
@property (nonatomic, assign) double radiansPerUnit;

/*! The hit radius around the handle, in canvas pixels. Defaults to 10. */
@property (nonatomic, assign) double hitRadius;

/*! Half the handle square's side, in canvas pixels. Defaults to 4. */
@property (nonatomic, assign) double handleRadius;

+ (nonnull instancetype)partWithID:(NSInteger)partID
				 centerParameterID:(FxParameterId)centerParameterID
				 radiusParameterID:(FxParameterId)radiusParameterID
				  angleParameterID:(FxParameterId)angleParameterID;

@end

/*!
	@class      FxGripOSCPolylinePart
	@abstract   A chain of point parameters drawn as connected segments.
	@discussion Serves paths, garbage mattes, and corner pins: four points with
				closed YES is a corner-pin outline. A hit is any point within
				hitRadius canvas pixels of a segment; a drag moves every point
				parameter by the drag's object-space delta.

				polylinePartsWithBodyID:... composes the body with a point handle on
				each vertex, so the whole control is one addParts: call.
*/
@interface FxGripOSCPolylinePart : FxGripOSCPart

/*! The point parameters, in chain order. */
@property (nonatomic, copy, nonnull) NSArray<NSNumber *> *pointParameterIDs;

/*!
	@property   inTangentParameterIDs
	@abstract   Opts the chain into cubic Bézier segments, Final Cut Pro style.
	@discussion Both tangent arrays name one point parameter per vertex, in chain
				order, holding absolute object-space positions. Segment i curves
				from vertex i through its out tangent and vertex i+1's in tangent.
				A vertex whose tangents sit on it behaves as a linear point. The
				chain stays straight while either array is nil or its count does
				not match the vertices. A body drag moves the tangents with the
				vertices.
*/
@property (nonatomic, copy, nullable) NSArray<NSNumber *> *inTangentParameterIDs;
@property (nonatomic, copy, nullable) NSArray<NSNumber *> *outTangentParameterIDs;

/*! YES closes the chain's last vertex back to the first. Defaults to NO. */
@property (nonatomic, assign) BOOL closed;

/*! The hit distance from a segment, in canvas pixels. Defaults to 6. */
@property (nonatomic, assign) double hitRadius;

+ (nonnull instancetype)partWithID:(NSInteger)partID
				 pointParameterIDs:(nonnull NSArray<NSNumber *> *)pointParameterIDs
							closed:(BOOL)closed;

/*! The body plus a point handle per vertex, numbered firstHandleID upward in
	chain order. The handles follow the body, so they win overlapping hits. */
+ (nonnull NSArray<FxGripOSCPart *> *)polylinePartsWithBodyID:(NSInteger)bodyID
												firstHandleID:(NSInteger)firstHandleID
											pointParameterIDs:(nonnull NSArray<NSNumber *> *)pointParameterIDs
													   closed:(BOOL)closed;

/*! Flag form. Inclusion order: Body, VertexHandles in chain order. */
+ (nonnull NSArray<FxGripOSCPart *> *)polylinePartsWithOptions:(FxGripOSCShapeOptions)options
												   firstPartID:(NSInteger)firstPartID
											 pointParameterIDs:(nonnull NSArray<NSNumber *> *)pointParameterIDs
														closed:(BOOL)closed;

/*!
	@method     bezierPartsWithOptions:firstPartID:pointParameterIDs:inTangentParameterIDs:outTangentParameterIDs:closed:
	@abstract   The Bézier chain: the curved body, vertex handles that carry their
				tangents, and tangent handles with aligned mirroring.
	@discussion Inclusion order: Body; VertexHandles
				(FxGripOSCBezierVertexHandlePart per vertex, chain order);
				TangentHandles (FxGripOSCTangentHandlePart in, then out, per vertex,
				chain order). An open chain skips the first vertex's in tangent and
				the last vertex's out tangent, which no segment uses.
*/
+ (nonnull NSArray<FxGripOSCPart *> *)bezierPartsWithOptions:(FxGripOSCShapeOptions)options
												 firstPartID:(NSInteger)firstPartID
										   pointParameterIDs:(nonnull NSArray<NSNumber *> *)pointParameterIDs
									   inTangentParameterIDs:(nonnull NSArray<NSNumber *> *)inTangentParameterIDs
									  outTangentParameterIDs:(nonnull NSArray<NSNumber *> *)outTangentParameterIDs
													  closed:(BOOL)closed;

@end

/*!
	@class      FxGripOSCBezierVertexHandlePart
	@abstract   A vertex handle that carries the vertex's tangents with it.
	@discussion Dragging writes the pointer's object position to the vertex and
				moves both tangent parameters by the same delta, so the curve's
				shape at the vertex is preserved, the Final Cut Pro behavior. A
				tangent parameter ID of 0 skips that side.
*/
@interface FxGripOSCBezierVertexHandlePart : FxGripOSCPart

@property (nonatomic, assign) FxParameterId vertexParameterID;
@property (nonatomic, assign) FxParameterId inTangentParameterID;
@property (nonatomic, assign) FxParameterId outTangentParameterID;

/*! The hit radius around the handle, in canvas pixels. Defaults to 10. */
@property (nonatomic, assign) double hitRadius;

/*! Half the handle square's side, in canvas pixels. Defaults to 4. */
@property (nonatomic, assign) double handleRadius;

+ (nonnull instancetype)partWithID:(NSInteger)partID
				 vertexParameterID:(FxParameterId)vertexParameterID
			  inTangentParameterID:(FxParameterId)inTangentParameterID
			 outTangentParameterID:(FxParameterId)outTangentParameterID;

@end

/*!
	@class      FxGripOSCTangentHandlePart
	@abstract   A Bézier tangent handle drawn with a stem from its vertex.
	@discussion Dragging writes the pointer's object position to the tangent. When
				oppositeTangentParameterID names the vertex's other tangent, the
				opposite rotates to stay collinear through the vertex, keeping its
				own length, so the vertex stays smooth; holding Option breaks the
				pair and moves only the dragged tangent, the Final Cut Pro
				convention. Collinearity is measured in the input-pixel frame.
*/
@interface FxGripOSCTangentHandlePart : FxGripOSCPart

@property (nonatomic, assign) FxParameterId vertexParameterID;
@property (nonatomic, assign) FxParameterId tangentParameterID;

/*! The vertex's other tangent for aligned mirroring; 0 (the default) is none. */
@property (nonatomic, assign) FxParameterId oppositeTangentParameterID;

/*! The hit radius around the handle, in canvas pixels. Defaults to 8. */
@property (nonatomic, assign) double hitRadius;

/*! Half the handle square's side, in canvas pixels. Defaults to 3. */
@property (nonatomic, assign) double handleRadius;

+ (nonnull instancetype)partWithID:(NSInteger)partID
				 vertexParameterID:(FxParameterId)vertexParameterID
				tangentParameterID:(FxParameterId)tangentParameterID;

@end

/*!
	@category   FxGripOSCRectPart (Composites)
	@abstract   The rectangle body with corner resize handles.
*/
@interface FxGripOSCRectPart (Composites)

/*! The body plus four FxGripOSCRectCornerPart handles numbered firstCornerID
	through firstCornerID + 3 in lower-left, lower-right, upper-right, upper-left
	order. The corners follow the body, so they win overlapping hits. */
+ (nonnull NSArray<FxGripOSCPart *> *)rectPartsWithBodyID:(NSInteger)bodyID
											firstCornerID:(NSInteger)firstCornerID
									 lowerLeftParameterID:(FxParameterId)lowerLeftParameterID
									upperRightParameterID:(FxParameterId)upperRightParameterID;

/*! The rotated-family composite: the body and corners carry the angle overlay, and
	an FxGripOSCRectRotationHandlePart follows them. */
+ (nonnull NSArray<FxGripOSCPart *> *)rectPartsWithBodyID:(NSInteger)bodyID
											firstCornerID:(NSInteger)firstCornerID
										 rotationHandleID:(NSInteger)rotationHandleID
									 lowerLeftParameterID:(FxParameterId)lowerLeftParameterID
									upperRightParameterID:(FxParameterId)upperRightParameterID
										 angleParameterID:(FxParameterId)angleParameterID;

/*! Flag form. Inclusion order: Body, CornerHandles (LL, LR, UR, UL),
	RotationHandle. An angleParameterID of 0 keeps the family axis-aligned and
	omits the rotation handle. */
+ (nonnull NSArray<FxGripOSCPart *> *)rectPartsWithOptions:(FxGripOSCShapeOptions)options
											   firstPartID:(NSInteger)firstPartID
									  lowerLeftParameterID:(FxParameterId)lowerLeftParameterID
									 upperRightParameterID:(FxParameterId)upperRightParameterID
										  angleParameterID:(FxParameterId)angleParameterID;

@end


/*!
	@class      FxGripOSCCurvePart
	@abstract   A display-only smooth curve through point parameters.
	@discussion Strokes a Catmull-Rom spline that passes through every control point named by
				pointParameterIDs. The part answers no hit and ignores drags; pair it with
				point handle parts (or a polyline body) for an editable curve, or use it alone
				to draw a read-only path such as a motion track.
*/
@interface FxGripOSCCurvePart : FxGripOSCPart

/*! The control point parameters the curve passes through, in order. */
@property (nonatomic, copy, nonnull) NSArray<NSNumber *> *pointParameterIDs;

/*! YES closes the curve back to the first point. Defaults to NO. */
@property (nonatomic, assign) BOOL closed;

/*! The stroke color. Defaults to the standard outline color. */
@property (nonatomic, assign) simd_float4 color;

/*! Draws a one-pixel drop shadow beneath the stroke. Defaults to YES. */
@property (nonatomic, assign) BOOL shadowed;

+ (nonnull instancetype)partWithID:(NSInteger)partID
				 pointParameterIDs:(nonnull NSArray<NSNumber *> *)pointParameterIDs
							closed:(BOOL)closed;

@end

/*!
	@class      FxGripOSCHUDPart
	@abstract   A display-only text readout drawn at a fixed pixel size.
	@discussion Introduced in FxGrip 1.0. Rasterizes text to a texture and draws it over
				an optional background panel, so the readout stays the same size at every
				zoom. The part answers no hit and ignores drags. Content is either the
				static text property or, when set, textBlock evaluated at the draw time.
				The anchor is the object point named by anchorParameterID converted to
				canvas pixels; when anchorParameterID is 0 the fixed canvasAnchor is used.
				The text's top-left sits at the anchor plus canvasOffset.
*/
@interface FxGripOSCHUDPart : FxGripOSCPart

/*! The static readout text. Ignored while textBlock is set. Defaults to the empty string. */
@property (nonatomic, copy, nonnull) NSString *text;

/*! Supplies the readout text at draw time, overriding text when set. Defaults to nil. */
@property (nonatomic, copy, nullable) NSString * _Nullable (^textBlock)(CMTime time);

/*! An object-space anchor point parameter; 0 (the default) uses canvasAnchor. */
@property (nonatomic, assign) FxParameterId anchorParameterID;

/*! The screen-space anchor, in canvas pixels, used when anchorParameterID is 0. Defaults to (20, 20). */
@property (nonatomic, assign) CGPoint canvasAnchor;

/*! Canvas-pixel offset added to the resolved anchor before drawing. Defaults to (0, 0). */
@property (nonatomic, assign) CGPoint canvasOffset;

/*! The text point size. Defaults to 12. */
@property (nonatomic, assign) CGFloat fontSize;

/*! The text color. Defaults to white. */
@property (nonatomic, assign) simd_float4 textColor;

/*! The panel color drawn behind the text. An alpha of 0 draws no panel. Defaults to translucent black. */
@property (nonatomic, assign) simd_float4 backgroundColor;

+ (nonnull instancetype)partWithID:(NSInteger)partID text:(nonnull NSString *)text;

+ (nonnull instancetype)partWithID:(NSInteger)partID textBlock:(nonnull NSString * _Nullable (^)(CMTime time))textBlock;

@end

/*!
	@class      FxGripOSCEditablePolygonPart
	@abstract   A polygon whose vertices can be inserted, moved, and deleted at runtime.
	@discussion Introduced in FxGrip 1.0. The vertices live in one custom-data parameter
				holding an FxGripPointListData, so the count changes without a fixed set of
				point parameters. Interactions:
				- click a vertex to select it, then drag to move it;
				- drag a segment (no vertex under the pointer) to move the whole polygon;
				- click a segment to insert a vertex at the pointer's projection
				  (requiresModifierToInsert gates this on the Option key);
				- press Delete or Backspace to remove the selected vertex, down to
				  minimumVertexCount.
				A hit on a vertex measures canvas-pixel distance, so the grab target stays
				the same size at every zoom.
*/
@interface FxGripOSCEditablePolygonPart : FxGripOSCPart

/*! The custom-data parameter holding the FxGripPointListData vertices. */
@property (nonatomic, assign) FxParameterId pointListParameterID;

/*! YES requires the Option key to insert a vertex on a segment click. Defaults to YES. */
@property (nonatomic, assign) BOOL requiresModifierToInsert;

/*! The polygon will not delete below this many vertices. Defaults to 2. */
@property (nonatomic, assign) NSUInteger minimumVertexCount;

/*! The hit distance from a segment, in canvas pixels. Defaults to 6. */
@property (nonatomic, assign) double hitRadius;

/*! The hit radius around a vertex, in canvas pixels. Defaults to 10. */
@property (nonatomic, assign) double vertexHitRadius;

/*! Half a vertex handle's side, in canvas pixels. Defaults to 4. */
@property (nonatomic, assign) double handleRadius;

/*! The outline stroke color. Defaults to the standard outline color. */
@property (nonatomic, assign) simd_float4 color;

/*! The selected vertex, or -1 when none is selected. */
@property (nonatomic, readonly) NSInteger selectedVertexIndex;

+ (nonnull instancetype)partWithID:(NSInteger)partID pointListParameterID:(FxParameterId)pointListParameterID;

@end

#endif /* FxGripOSCPart_h */
