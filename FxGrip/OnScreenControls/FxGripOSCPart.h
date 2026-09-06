/*!
	@file       FxGripOSCPart.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripOSCPart
	@abstract   The interactive-part base class and the shape parts an on-screen control composes.
	@discussion Introduced in FxGrip 0.1.0. A part owns a part number, answers hit tests, draws itself,
	            and applies drags. The framework ships parts for points, lines, rectangles, boxes,
	            circles, polylines, curves, angle dials, rotation handles, and HUD readouts, plus
	            composite constructors that build a whole control in one addParts: call. Every part
	            casts an optional drop shadow.
*/

#ifndef FxGripOSCPart_h
#define FxGripOSCPart_h

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <Metal/Metal.h>
#import "FxGripOnScreenControl.h"

/*!
	@enum       FxGripOSCShapeOptions
	@abstract   Selects the parts a shape family's flag constructor composes.
	@discussion Each family honors the flags that apply to it and ignores the rest.
				Part numbers are assigned sequentially from firstPartID in the
				family's documented inclusion order, counting only the parts the
				flags include; read partID off the returned parts when handles are
				optional.
	@constant   FxGripOSCShapeOptionBody           The shape body that hit-tests and drags the whole shape.
	@constant   FxGripOSCShapeOptionCornerHandles  Resize handles on the four corners.
	@constant   FxGripOSCShapeOptionVertexHandles  A point handle on each vertex.
	@constant   FxGripOSCShapeOptionRadiusHandle   A handle on a circle's rim that sets the radius.
	@constant   FxGripOSCShapeOptionRotationHandle A rotation handle, omitted when the angle parameter is 0.
	@constant   FxGripOSCShapeOptionTangentHandles Tangent handles on the Bézier-family vertices.
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
	@discussion Introduced in FxGrip 0.1.0. A part owns a nonzero part number, answers
				hit tests, draws itself, and applies drags. FxGripOnScreenControl
				hit-tests parts last-added first (the part drawn on top wins), draws
				them in order, and routes a drag to the active part. The base class
				answers no hit, ignores drags, and draws nothing.
*/
@interface FxGripOSCPart : NSObject

/*! The part's nonzero identifier within its control. */
@property (nonatomic, assign) NSInteger partID;

/*! The owning control; set by addPart:. */
@property (nonatomic, assign, nullable) FxGripOnScreenControl *control;

/*! The cursor shown while the pointer hovers this part. A nil cursor uses the arrow. The
	base applies it through the host's OSC API on mouse-moved. */
@property (nonatomic, strong, nullable) NSCursor *cursor;

/*!
	@property   shadowColor
	@abstract   The color of the part's drop shadow.
	@discussion Introduced in FxGrip 0.1.0. Every part casts a drop shadow, drawn by the control in
				a pass beneath the crisp control. shadowColor defaults to the standard shadow. An
				alpha of 0 disables the shadow.
*/
@property (nonatomic, assign) simd_float4 shadowColor;

/*! The shadow offset in canvas pixels, down and to the right. Defaults to 1. 0 offsets nothing. */
@property (nonatomic, assign) double shadowDistance;

/*! The gaussian blur radius of the shadow, in canvas pixels. Defaults to 0 (a crisp shadow). */
@property (nonatomic, assign) double shadowBlur;

/*! YES when the part casts a visible shadow: a nonzero shadow alpha with a nonzero offset or blur. */
@property (nonatomic, readonly) BOOL castsShadow;

/*! The designated initializer, assigning the part number. */
- (nonnull instancetype)initWithPartID:(NSInteger)partID;

/*! YES when the point falls on this part. The base part answers no hit. */
- (BOOL)hitTestObjectPoint:(CGPoint)objectPoint canvasPoint:(CGPoint)canvasPoint atTime:(CMTime)time;

/*! Applies the drag; returns YES when the effect must re-render. */
- (BOOL)dragToObjectPoint:(CGPoint)objectPoint
			  objectDelta:(CGPoint)objectDelta
				modifiers:(FxModifierKeys)modifiers
				   atTime:(CMTime)time;

/*! Draws the part, in its selected appearance when selected is YES. */
- (void)drawSelected:(BOOL)selected
		  canvasSize:(CGSize)canvasSize
	  commandEncoder:(nonnull id<MTLRenderCommandEncoder>)commandEncoder
			  atTime:(CMTime)time;

/*!
	@method     mouseDownAtObjectPoint:canvasPoint:modifiers:atTime:
	@abstract   Handles a mouse-down on this part before any drag; returns YES to re-render.
	@discussion Introduced in FxGrip 0.1.0. The base forwards the event only to the active
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
	@discussion Introduced in FxGrip 0.1.0. The base forwards every key press to every part,
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
	@discussion Introduced in FxGrip 0.1.0. The control applies Option as a fine (slow) drag at the
				base level for every part. A part that reads Option itself while dragging (a Bézier
				tangent breaking its mirror) returns YES so the base leaves Option to it. The base
				part returns NO.
*/
- (BOOL)handlesOptionDrag;

/*!
	@method     handlesConstrainDrag
	@abstract   YES when the part gives the Shift modifier its own meaning during a drag.
	@discussion Introduced in FxGrip 0.1.0. The control constrains a Shift drag to the horizontal or
				vertical axis at the base level for every part. A part that reads Shift itself while
				dragging (a Bézier tangent snapping its angle to 45° increments) returns YES so the
				base leaves Shift to it. The base part returns NO.
*/
- (BOOL)handlesConstrainDrag;

/*!
	@method     mouseDoubleClickAtObjectPoint:canvasPoint:modifiers:atTime:
	@abstract   Handles a double-click on this part; returns YES when it acted and must re-render.
	@discussion Introduced in FxGrip 0.1.0. FxPlug delivers no click count, so the control synthesizes
				a double-click from two clicks on the same part within the system double-click
				interval and a small canvas-pixel radius, then forwards it to the active part. A part
				that returns NO leaves the second click to run as an ordinary mouse-down. The base
				part does nothing and returns NO; a Bézier vertex handle toggles smooth and corner.
*/
- (BOOL)mouseDoubleClickAtObjectPoint:(CGPoint)objectPoint
						  canvasPoint:(CGPoint)canvasPoint
							modifiers:(FxModifierKeys)modifiers
							   atTime:(CMTime)time;

@end

/*!
	@class      FxGripOSCPointHandlePart
	@abstract   A square handle bound to a point parameter.
	@discussion Introduced in FxGrip 0.1.0. The handle follows the cursor: a drag writes the pointer's object
				position to the parameter. Hit testing measures canvas-pixel distance
				to the handle, so the grab target stays the same size at every zoom.
*/
@interface FxGripOSCPointHandlePart : FxGripOSCPart

/*! The point parameter the handle reads and writes. */
@property (nonatomic, assign) FxParameterId parameterID;

/*! The hit radius around the handle, in canvas pixels. Defaults to 10. */
@property (nonatomic, assign) double hitRadius;

/*! Half the handle square's side, in canvas pixels. Defaults to 4. */
@property (nonatomic, assign) double handleRadius;

/*! Creates a handle bound to a point parameter. */
+ (nonnull instancetype)partWithID:(NSInteger)partID parameterID:(FxParameterId)parameterID;

@end

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

/*!
	@class      FxGripOSCRectPart
	@abstract   A rectangle bound to lower-left and upper-right point parameters.
	@discussion Introduced in FxGrip 0.1.0. A hit is any object point inside the rectangle; a drag moves both
				corner parameters by the drag's object-space delta.
*/
@interface FxGripOSCRectPart : FxGripOSCPart

/*! The lower-left corner point parameter. */
@property (nonatomic, assign) FxParameterId lowerLeftParameterID;

/*! The upper-right corner point parameter. */
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

/*! Creates a rectangle bound to lower-left and upper-right point parameters. */
+ (nonnull instancetype)partWithID:(NSInteger)partID
			  lowerLeftParameterID:(FxParameterId)lowerLeftParameterID
			 upperRightParameterID:(FxParameterId)upperRightParameterID;

@end

/*!
	@class      FxGripOSCRectRotationHandlePart
	@abstract   A rotation spoke for the two-corner rectangle's angle overlay.
	@discussion Introduced in FxGrip 0.1.0. The spoke runs from the corners' midpoint to a tip handle at a fixed
				canvas radius, aimed by the angle parameter; dragging writes the
				pointer's canvas-space angle around the midpoint. Holding Shift snaps
				the written angle to 45° increments, the Final Cut Pro convention.
*/
@interface FxGripOSCRectRotationHandlePart : FxGripOSCPart

/*! The rectangle's lower-left corner point parameter, for the midpoint. */
@property (nonatomic, assign) FxParameterId lowerLeftParameterID;

/*! The rectangle's upper-right corner point parameter, for the midpoint. */
@property (nonatomic, assign) FxParameterId upperRightParameterID;

/*! The angle parameter the spoke reads and writes. */
@property (nonatomic, assign) FxParameterId angleParameterID;

/*! Radians per one unit of the angle parameter. Defaults to 1. */
@property (nonatomic, assign) double radiansPerUnit;

/*! The spoke length, in canvas pixels. Defaults to 40. */
@property (nonatomic, assign) double spokeRadius;

/*! The hit radius around the tip handle, in canvas pixels. Defaults to 10. */
@property (nonatomic, assign) double hitRadius;

/*! Half the tip handle square's side, in canvas pixels. Defaults to 4. */
@property (nonatomic, assign) double handleRadius;

/*! Creates a rotation spoke for the two-corner rectangle's angle overlay. */
+ (nonnull instancetype)partWithID:(NSInteger)partID
			  lowerLeftParameterID:(FxParameterId)lowerLeftParameterID
			 upperRightParameterID:(FxParameterId)upperRightParameterID
				  angleParameterID:(FxParameterId)angleParameterID;

@end

/*!
	@class      FxGripOSCBoxPart
	@abstract   A rotatable box bound to center point, pixel width, pixel height,
				and angle parameters.
	@discussion Introduced in FxGrip 0.1.0. The Motion-style box model. Width and height are in input-image
				pixels; the box rotates rigidly about its center in the input-pixel
				frame. A hit is any pointer inside the rotated box; a drag moves the
				center. angleParameterID 0 leaves the box axis-aligned.

				boxPartsWithBodyID:... composes the body, four
				FxGripOSCBoxCornerPart resize handles, and an FxGripOSCAngleDialPart
				rotation spoke on the center.
*/
@interface FxGripOSCBoxPart : FxGripOSCPart

/*! The box's center point parameter. */
@property (nonatomic, assign) FxParameterId centerParameterID;

/*! The box's width parameter, in input-image pixels. */
@property (nonatomic, assign) FxParameterId widthParameterID;

/*! The box's height parameter, in input-image pixels. */
@property (nonatomic, assign) FxParameterId heightParameterID;

/*! The rotation parameter; 0 (the default) keeps the box axis-aligned. */
@property (nonatomic, assign) FxParameterId angleParameterID;

/*! Radians per one unit of the angle parameter. Defaults to 1. */
@property (nonatomic, assign) double radiansPerUnit;

/*! Creates a box bound to center, width, height, and angle parameters. */
+ (nonnull instancetype)partWithID:(NSInteger)partID
				 centerParameterID:(FxParameterId)centerParameterID
				  widthParameterID:(FxParameterId)widthParameterID
				 heightParameterID:(FxParameterId)heightParameterID
				  angleParameterID:(FxParameterId)angleParameterID;

/*! The body, four corner handles numbered firstCornerID through firstCornerID + 3
	in lower-left, lower-right, upper-right, upper-left order, and the rotation
	dial, which is omitted when angleParameterID is 0. Handles follow the body, so
	they win overlapping hits. */
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
	@discussion Introduced in FxGrip 0.1.0. The handle sits on the rotated corner. Dragging resizes the box in
				its local frame, writing the width and height parameters. Modifiers
				follow Final Cut Pro:

				- The default anchors the diagonally opposite corner: it stays put
				  while the center parameter shifts to follow the resize.
				- Holding Option anchors the fixed center instead, resizing
				  symmetrically; the center and angle do not change.
				- Holding Shift locks the resize to the box's aspect ratio, scaling
				  both dimensions by the dominant axis.

				The angle never changes.
*/
@interface FxGripOSCBoxCornerPart : FxGripOSCPart

/*! The box's center point parameter. */
@property (nonatomic, assign) FxParameterId centerParameterID;

/*! The box's width parameter, in input-image pixels. */
@property (nonatomic, assign) FxParameterId widthParameterID;

/*! The box's height parameter, in input-image pixels. */
@property (nonatomic, assign) FxParameterId heightParameterID;

/*! The box's angle parameter; 0 keeps the box axis-aligned. */
@property (nonatomic, assign) FxParameterId angleParameterID;

/*! Radians per one unit of the angle parameter. Defaults to 1. */
@property (nonatomic, assign) double radiansPerUnit;

/*! Which corner this handle sits on. */
@property (nonatomic, assign) FxGripOSCRectCorner corner;

/*! The hit radius around the handle, in canvas pixels. Defaults to 10. */
@property (nonatomic, assign) double hitRadius;

/*! Half the handle square's side, in canvas pixels. Defaults to 4. */
@property (nonatomic, assign) double handleRadius;

/*! Creates a resize handle on one corner of a box. */
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
	@discussion Introduced in FxGrip 0.1.0. Serves gradients, wipes, and motion vectors. A hit is any point
				within hitRadius canvas pixels of the segment; a drag moves both
				endpoint parameters by the drag's object-space delta.

				gradientPartsWithLineID:... composes the full control: the line body
				plus a point handle on each endpoint. The handles are listed after
				the body, so they win overlapping hits.
*/
@interface FxGripOSCLinePart : FxGripOSCPart

/*! The segment's start point parameter. */
@property (nonatomic, assign) FxParameterId startParameterID;

/*! The segment's end point parameter. */
@property (nonatomic, assign) FxParameterId endParameterID;

/*! The hit distance from the segment, in canvas pixels. Defaults to 6. */
@property (nonatomic, assign) double hitRadius;

/*! Creates a line bound to start and end point parameters. */
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
	@discussion Introduced in FxGrip 0.1.0. The spoke runs from the center to a tip handle at a fixed canvas
				radius; dragging the tip writes the angle of the pointer around the
				center, measured counterclockwise from +x in canvas space. Holding
				Shift snaps the written angle to 45° increments, the Final Cut Pro
				convention. The parameter's unit is set by radiansPerUnit: 1 for a
				radian parameter (the FxPlug angle-slider convention), M_PI / 180 for
				degrees.
*/
@interface FxGripOSCAngleDialPart : FxGripOSCPart

/*! The center point parameter the spoke pivots on. */
@property (nonatomic, assign) FxParameterId centerParameterID;

/*! The angle parameter the spoke reads and writes. */
@property (nonatomic, assign) FxParameterId angleParameterID;

/*! Radians per one unit of the angle parameter. Defaults to 1. */
@property (nonatomic, assign) double radiansPerUnit;

/*! The spoke length, in canvas pixels. Defaults to 40. */
@property (nonatomic, assign) double spokeRadius;

/*! The hit radius around the tip handle, in canvas pixels. Defaults to 10. */
@property (nonatomic, assign) double hitRadius;

/*! Half the tip handle square's side, in canvas pixels. Defaults to 4. */
@property (nonatomic, assign) double handleRadius;

/*! Creates a rotation spoke bound to a center point and an angle parameter. */
+ (nonnull instancetype)partWithID:(NSInteger)partID
				 centerParameterID:(FxParameterId)centerParameterID
				  angleParameterID:(FxParameterId)angleParameterID;

@end

/*!
	@class      FxGripOSCRectCornerPart
	@abstract   A resize handle on one corner of a rectangle bound to lower-left and
				upper-right point parameters.
	@discussion Introduced in FxGrip 0.1.0. Dragging writes the pointer's object position into the corner's
				components: the lower-right corner, for example, writes x to the
				upper-right parameter and y to the lower-left parameter. The corners
				are not normalized; a corner dragged past its opposite inverts the
				rectangle, matching the host's parameter behavior. Modifiers follow
				Final Cut Pro: holding Shift locks the resize to the rectangle's aspect
				ratio, and holding Option anchors the center, resizing symmetrically so
				the opposite corner mirrors the dragged one, in place of the default
				fixed opposite corner.
*/
@interface FxGripOSCRectCornerPart : FxGripOSCPart

/*! The rectangle's lower-left corner point parameter. */
@property (nonatomic, assign) FxParameterId lowerLeftParameterID;

/*! The rectangle's upper-right corner point parameter. */
@property (nonatomic, assign) FxParameterId upperRightParameterID;

/*! Which corner this handle sits on. */
@property (nonatomic, assign) FxGripOSCRectCorner corner;

/*! The angle overlay, matching FxGripOSCRectPart's; 0 (the default) is axis-aligned. */
@property (nonatomic, assign) FxParameterId angleParameterID;

/*! Radians per one unit of the angle parameter. Defaults to 1. */
@property (nonatomic, assign) double radiansPerUnit;

/*! The hit radius around the handle, in canvas pixels. Defaults to 10. */
@property (nonatomic, assign) double hitRadius;

/*! Half the handle square's side, in canvas pixels. Defaults to 4. */
@property (nonatomic, assign) double handleRadius;

/*! Creates a resize handle on one corner of a two-corner rectangle. */
+ (nonnull instancetype)partWithID:(NSInteger)partID
							corner:(FxGripOSCRectCorner)corner
			  lowerLeftParameterID:(FxParameterId)lowerLeftParameterID
			 upperRightParameterID:(FxParameterId)upperRightParameterID;

@end

/*!
	@class      FxGripOSCCirclePart
	@abstract   A circle bound to a center point parameter and a pixel-radius float
				parameter.
	@discussion Introduced in FxGrip 0.1.0. The radius parameter is in input-image pixels; hit testing and
				drawing normalize it against the input bounds, correcting for the
				image's aspect ratio. A drag moves the center by the object-space
				delta.
*/
@interface FxGripOSCCirclePart : FxGripOSCPart

/*! The circle's center point parameter. */
@property (nonatomic, assign) FxParameterId centerParameterID;

/*! The circle's radius parameter, in input-image pixels. */
@property (nonatomic, assign) FxParameterId radiusParameterID;

/*! The rim segments drawn. Defaults to 24; clamped to at least 3. */
@property (nonatomic, assign) NSUInteger segmentCount;

/*! Creates a circle bound to a center point and a pixel-radius parameter. */
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
	@discussion Introduced in FxGrip 0.1.0. The handle sits on the rim at rimAngle. Dragging writes the
				aspect-corrected object-space distance from the center, scaled to
				input-image pixels, into the radius parameter; the companion
				FxGripOSCCirclePart's drag moves the center, so together they give a
				movable, resizable circle (circlePartsWithBodyID:... composes both).
*/
@interface FxGripOSCCircleRadiusHandlePart : FxGripOSCPart

/*! The circle's center point parameter. */
@property (nonatomic, assign) FxParameterId centerParameterID;

/*! The circle's radius parameter, in input-image pixels. */
@property (nonatomic, assign) FxParameterId radiusParameterID;

/*! The handle's position on the rim, radians counterclockwise from +x. Defaults to 0. */
@property (nonatomic, assign) double rimAngle;

/*! The hit radius around the handle, in canvas pixels. Defaults to 10. */
@property (nonatomic, assign) double hitRadius;

/*! Half the handle square's side, in canvas pixels. Defaults to 4. */
@property (nonatomic, assign) double handleRadius;

/*! Creates a radius handle on a circle's rim. */
+ (nonnull instancetype)partWithID:(NSInteger)partID
				 centerParameterID:(FxParameterId)centerParameterID
				 radiusParameterID:(FxParameterId)radiusParameterID;

@end

/*!
	@class      FxGripOSCRotationHandlePart
	@abstract   A rotation handle on a circle's rim, bound to center point, pixel
				radius, and angle parameters.
	@discussion Introduced in FxGrip 0.1.0. The handle sits on the rim at the angle parameter's direction, with
				a spoke drawn from the center. Dragging writes the pointer's angle
				around the center, measured counterclockwise from +x in canvas
				space; the radius parameter only positions the handle. Holding Shift
				snaps the written angle to 45° increments, the Final Cut Pro
				convention. With FxGripOSCCirclePart and
				FxGripOSCCircleRadiusHandlePart it forms
				the movable, resizable, rotatable circle
				(circlePartsWithBodyID:radiusHandleID:rotationHandleID:... composes
				all three). radiansPerUnit follows the dial's convention: 1 for a
				radian parameter, M_PI / 180 for degrees.
*/
@interface FxGripOSCRotationHandlePart : FxGripOSCPart

/*! The circle's center point parameter. */
@property (nonatomic, assign) FxParameterId centerParameterID;

/*! The circle's radius parameter, which positions the handle on the rim. */
@property (nonatomic, assign) FxParameterId radiusParameterID;

/*! The angle parameter the handle reads and writes. */
@property (nonatomic, assign) FxParameterId angleParameterID;

/*! Radians per one unit of the angle parameter. Defaults to 1. */
@property (nonatomic, assign) double radiansPerUnit;

/*! The hit radius around the handle, in canvas pixels. Defaults to 10. */
@property (nonatomic, assign) double hitRadius;

/*! Half the handle square's side, in canvas pixels. Defaults to 4. */
@property (nonatomic, assign) double handleRadius;

/*! Creates a rotation handle bound to center, radius, and angle parameters. */
+ (nonnull instancetype)partWithID:(NSInteger)partID
				 centerParameterID:(FxParameterId)centerParameterID
				 radiusParameterID:(FxParameterId)radiusParameterID
				  angleParameterID:(FxParameterId)angleParameterID;

@end

/*!
	@class      FxGripOSCPolylinePart
	@abstract   A chain of point parameters drawn as connected segments.
	@discussion Introduced in FxGrip 0.1.0. Serves paths, garbage mattes, and corner pins: four points with
				closed YES is a corner-pin outline. A hit is any point within
				hitRadius canvas pixels of a segment; a drag moves every point
				parameter by the drag's object-space delta.

				polylinePartsWithBodyID:... composes the body with a point handle on
				each vertex, so the whole control is one addParts: call.
*/
@interface FxGripOSCPolylinePart : FxGripOSCPart

/*! The point parameters, in chain order. */
@property (nonatomic, copy, nonnull) NSArray<NSNumber *> *pointParameterIDs;

/*! YES closes the chain's last vertex back to the first. Defaults to NO. */
@property (nonatomic, assign) BOOL closed;

/*! The hit distance from a segment, in canvas pixels. Defaults to 6. */
@property (nonatomic, assign) double hitRadius;

/*! Creates a polyline through the given point parameters. */
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

@end


/*!
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
	@discussion Introduced in FxGrip 0.1.0. Strokes a Catmull-Rom spline that passes through every control point named by
				pointParameterIDs. The part answers no hit and ignores drags; pair it with
				point handle parts (or a polyline body) for an editable curve, or use it alone
				to draw a read-only path such as a motion track. For an editable curve with
				vertex and tangent handles, use FxGripOSCPathPart instead. The drop shadow is the
				inherited shadowColor, shadowDistance, and shadowBlur appearance.
*/
@interface FxGripOSCCurvePart : FxGripOSCPart

/*! The control point parameters the curve passes through, in order. */
@property (nonatomic, copy, nonnull) NSArray<NSNumber *> *pointParameterIDs;

/*! YES closes the curve back to the first point. Defaults to NO. */
@property (nonatomic, assign) BOOL closed;

/*! The stroke color. Defaults to the standard outline color. */
@property (nonatomic, assign) simd_float4 color;

/*! Creates a display-only curve through the given point parameters. */
+ (nonnull instancetype)partWithID:(NSInteger)partID
				 pointParameterIDs:(nonnull NSArray<NSNumber *> *)pointParameterIDs
							closed:(BOOL)closed;

@end

/*!
	@class      FxGripOSCHUDPart
	@abstract   A display-only text readout drawn at a fixed pixel size.
	@discussion Introduced in FxGrip 0.1.0. Rasterizes text to a texture and draws it over
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

/*! Creates a HUD readout with static text. */
+ (nonnull instancetype)partWithID:(NSInteger)partID text:(nonnull NSString *)text;

/*! Creates a HUD readout whose text is evaluated at draw time. */
+ (nonnull instancetype)partWithID:(NSInteger)partID textBlock:(nonnull NSString * _Nullable (^)(CMTime time))textBlock;

@end


#endif /* FxGripOSCPart_h */
