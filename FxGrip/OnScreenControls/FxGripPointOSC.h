/*!
	@file       FxGripPointOSC.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripPointOSC
	@abstract   An on-screen control and its parts for FxGripPointOptions-configured point parameters.
	@discussion Introduced in FxGrip 0.1.0. The control composes a rich point handle, an optional axis
	            divider, an optional background image, and an optional name label for each point. An
	            effect's OSC subclass calls addPointParameter:name:options: for each rich point.
*/

#ifndef FxGripPointOSC_h
#define FxGripPointOSC_h

#import <Foundation/Foundation.h>
#import "FxGripOnScreenControl.h"
#import "FxGripOSCPart.h"
#import "FxGripPointOptions.h"

/*!
	@class      FxGripOSCRichPointHandlePart
	@abstract   The draggable handle of a point parameter configured by FxGripPointOptions.
	@discussion Introduced in FxGrip 0.1.0. Extends the stock point handle with the FxGripPointOptions
				behaviors:
				- the handle draws at the parameter's position, or offset by pinDistance canvas
				  pixels at pinAngle degrees (0 is right, counterclockwise positive) as a pin
				  with a stem back to the parameter's position;
				- a drag moves the parameter by the pointer's travel scaled by mouseSpeed
				  (only while Shift is held when mouseSpeedShiftOnly is set), so the handle
				  never jumps to the pointer;
				- the constraint locks the drag to an axis, or clamps it within maxDistance of
				  the distance location, measured in input pixels; Shift locks a distance drag
				  to one axis when distanceShiftOneAxis is set;
				- the written position clamps to the range;
				- controlSize sets the handle's side in canvas pixels and controlColor its fill.
				The part claims Shift only when mouseSpeedShiftOnly or distanceShiftOneAxis needs
				it; otherwise the control's standard Shift axis-constrain applies.
*/
@interface FxGripOSCRichPointHandlePart : FxGripOSCPointHandlePart

/*! The point behaviors: pin offset, mouse speed, constraint, range, and appearance. */
@property (nonatomic, strong, nonnull) FxGripPointOptions *options;

/*! Creates a handle bound to a point parameter with the given options. */
+ (nonnull instancetype)partWithID:(NSInteger)partID
					   parameterID:(FxParameterId)parameterID
						   options:(nonnull FxGripPointOptions *)options;

/*! The handle's canvas position: the parameter's position plus the pin offset. */
- (BOOL)handleCanvasPoint:(nonnull CGPoint *)canvasPoint atTime:(CMTime)time;

/*! Half the drawn handle's side in canvas pixels: controlSize / 2, or handleRadius when controlSize is 0. */
- (double)effectiveHandleRadius;

@end

/*!
	@class      FxGripOSCPointDividerPart
	@abstract   The divider line of an axis-constrained point.
	@discussion Introduced in FxGrip 0.1.0. Draws a line across the canvas through the point,
				perpendicular to the axis the point moves along. A thin divider is display
				only and pairs with the handle. A thick divider is the control itself: it
				answers hits along its length and drags the point along the free axis, so
				the handle is omitted.
*/
@interface FxGripOSCPointDividerPart : FxGripOSCRichPointHandlePart

/*! YES draws the thick band and accepts drags; NO draws the thin line and answers no hit. */
@property (nonatomic, assign) BOOL draggable;

/*! The hit distance from the line, in canvas pixels. Defaults to 6. */
@property (nonatomic, assign) double lineHitRadius;

@end

/*!
	@class      FxGripOSCPointBackgroundPart
	@abstract   A display-only image drawn beneath a point's control.
	@discussion Introduced in FxGrip 0.1.0. Draws backgroundImageName (a named AppKit image or a
				file path) centered on the backgroundImageX and backgroundImageY object point,
				backgroundImageSize of the input width wide, keeping the image's aspect in
				input pixels. The texture is built once per Metal device. The part answers no
				hit and ignores drags.
*/
@interface FxGripOSCPointBackgroundPart : FxGripOSCPart

/*! The point options supplying the background image name, position, and size. */
@property (nonatomic, strong, nonnull) FxGripPointOptions *options;

/*! Creates a background-image part from the given options. */
+ (nonnull instancetype)partWithID:(NSInteger)partID options:(nonnull FxGripPointOptions *)options;

@end

/*!
	@class      FxGripOSCPointLabelPart
	@abstract   The parameter-name readout beside a point's handle.
	@discussion Introduced in FxGrip 0.1.0. A HUD readout anchored to the point. When
				nameOnlyWhenAbove is set the label draws only while hovered, which
				FxGripPointOSC sets from mouse-moved events for the handle part named by
				handlePartID.
*/
@interface FxGripOSCPointLabelPart : FxGripOSCHUDPart

/*! The part number of the handle this label tracks for hover; 0 means no handle. */
@property (nonatomic, assign) NSInteger handlePartID;

/*! YES draws the label only while the handle is hovered. */
@property (nonatomic, assign) BOOL nameOnlyWhenAbove;

/*! YES while the tracked handle is hovered; set by the control from mouse-moved events. */
@property (nonatomic, assign) BOOL hovered;

/*! YES when the label draws: always, or while hovered when nameOnlyWhenAbove is set. */
@property (nonatomic, readonly) BOOL visible;

@end

/*!
	@class      FxGripPointOSC
	@abstract   An on-screen control composed from FxGripPointOptions-configured point parameters.
	@discussion Introduced in FxGrip 0.1.0. An effect's OSC subclass calls addPointParameter:name:
				options: for each rich point in its initializer, which appends the parts
				pointPartsWithOptions:firstPartID:parameterID:name: composes. The control
				tracks the hovered handle from mouse-moved events to show and hide the
				name labels. Registration is unchanged: the effect lists the OSC UUID under
				the "osc" key.
*/
@interface FxGripPointOSC : FxGripOnScreenControl

/*! Composes and appends the parts for one point, numbering them after the existing parts. */
- (void)addPointParameter:(FxParameterId)parameterID
					 name:(nullable NSString *)name
				  options:(nonnull FxGripPointOptions *)options;

/*!
	@method     pointPartsWithOptions:firstPartID:parameterID:name:
	@abstract   The parts for one point, numbered firstPartID upward.
	@discussion Inclusion order: the background image (when backgroundImageName is set); the
				divider (for an axis constraint with a divider); the handle (omitted for the
				thick divider, which is the control); the name label (when displayName is set).
*/
+ (nonnull NSArray<FxGripOSCPart *> *)pointPartsWithOptions:(nonnull FxGripPointOptions *)options
												firstPartID:(NSInteger)firstPartID
												parameterID:(FxParameterId)parameterID
													   name:(nullable NSString *)name;

@end

#endif /* FxGripPointOSC_h */
