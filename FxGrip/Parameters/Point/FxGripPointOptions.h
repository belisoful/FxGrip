/*!
	@file       FxGripPointOptions.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripPointOptions
	@abstract   The parsed design-time options of a point parameter and its configuration enums.
	@discussion Introduced in FxGrip 0.1.0. FxGripPointOptions reads a point parameter's
	            declaration once and answers typed properties for its on-screen control. The
	            enums name the coordinate mapping, the movement constraint, and the axis divider.
	            The kFxGripPointKey_* constants name the configuration keys, and the
	            kFxGripPointDefault* constants are the documented defaults.
*/

#ifndef FxGripPointOptions_h
#define FxGripPointOptions_h

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

/*!
	@enum       FxGripPointCoordinateMapping
	@abstract   How a point parameter's value maps onto the frame.
	@constant   FxGripPointCoordinatePixel          Pixel-based values.
	@constant   FxGripPointCoordinateQuartzComposer Quartz Composer coordinate system.
*/
typedef NS_ENUM(NSInteger, FxGripPointCoordinateMapping) {
	FxGripPointCoordinatePixel			= 0,
	FxGripPointCoordinateQuartzComposer	= 1,
};

/*!
	@enum       FxGripPointConstraint
	@abstract   The direction a point's on-screen control may move.
	@constant   FxGripPointConstraintAnyDirection  Free movement.
	@constant   FxGripPointConstraintHorizontal    Locked to the horizontal axis.
	@constant   FxGripPointConstraintVertical      Locked to the vertical axis.
	@constant   FxGripPointConstraintDistance      Locked within a distance of a location.
*/
typedef NS_ENUM(NSInteger, FxGripPointConstraint) {
	FxGripPointConstraintAnyDirection	= 0,
	FxGripPointConstraintHorizontal		= 1,
	FxGripPointConstraintVertical		= 2,
	FxGripPointConstraintDistance		= 3,
};

/*!
	@enum       FxGripPointDivider
	@abstract   The divider drawn for an axis-constrained point.
	@constant   FxGripPointDividerNone               No divider.
	@constant   FxGripPointDividerThinWithControl    A thin divider with the point control.
	@constant   FxGripPointDividerThickWithoutControl A thick divider without the point control.
*/
typedef NS_ENUM(NSInteger, FxGripPointDivider) {
	FxGripPointDividerNone					= 0,
	FxGripPointDividerThinWithControl		= 1,
	FxGripPointDividerThickWithoutControl	= 2,
};

// Configuration keys read from a point parameter's declaration. Every key is optional; a
// missing or wrong-typed value falls back to the documented default.
#define kFxGripPointKey_RangeMinX			@"rangeMinX"
#define kFxGripPointKey_RangeMaxX			@"rangeMaxX"
#define kFxGripPointKey_RangeMinY			@"rangeMinY"
#define kFxGripPointKey_RangeMaxY			@"rangeMaxY"
#define kFxGripPointKey_CoordinateMapping	@"coordinateMapping"
#define kFxGripPointKey_CompensateFrameMargin	@"compensateFrameMargin"
#define kFxGripPointKey_ControlSize			@"controlSize"
#define kFxGripPointKey_ControlColor		@"controlColor"
#define kFxGripPointKey_PinDistance			@"pinDistance"
#define kFxGripPointKey_PinAngle			@"pinAngle"
#define kFxGripPointKey_DisplayName			@"displayName"
#define kFxGripPointKey_NameOnlyWhenAbove	@"nameOnlyWhenAbove"
#define kFxGripPointKey_MouseSpeed			@"mouseSpeed"
#define kFxGripPointKey_MouseSpeedShiftOnly	@"mouseSpeedShiftOnly"
#define kFxGripPointKey_BackgroundImage		@"backgroundImage"
#define kFxGripPointKey_BackgroundImageSize	@"backgroundImageSize"
#define kFxGripPointKey_BackgroundImageX	@"backgroundImageX"
#define kFxGripPointKey_BackgroundImageY	@"backgroundImageY"
#define kFxGripPointKey_Constraint			@"constraint"
#define kFxGripPointKey_Divider				@"divider"
#define kFxGripPointKey_DistanceFromX		@"distanceFromX"
#define kFxGripPointKey_DistanceFromY		@"distanceFromY"
#define kFxGripPointKey_MaxDistance			@"maxDistance"
#define kFxGripPointKey_DistanceShiftOneAxis	@"distanceShiftOneAxis"

// Defaults.
#define kFxGripPointDefaultPosition			(0.5)
#define kFxGripPointDefaultControlSize		(0.0)	// 0 -> the on-screen control's own size
#define kFxGripPointDefaultMouseSpeed		(1.0)
#define kFxGripPointDefaultBackgroundSize	(1.0)	// 100% of the frame width
#define kFxGripPointDefaultMaxDistance		(1.0)

/*!
	@class      FxGripPointOptions
	@abstract   The parsed design-time options of a point parameter.
	@discussion Introduced in FxGrip 0.1.0. A point parameter's declaration configures the
				behavior and appearance of its on-screen control: the value range, the
				coordinate mapping, the control size and color, a pin-with-distance display,
				the parameter-name label, a mouse-speed modifier, a background image, and a
				movement constraint with its divider. This value object reads those keys once
				and answers typed properties, applying the documented default for any key the
				declaration omits. The point value itself stays a host point (X and Y).
*/
@interface FxGripPointOptions : NSObject

/*! The point's declared X default, from `x`. Defaults to 0.5. */
@property (readonly) double defaultX;
/*! The point's declared Y default, from `y`. Defaults to 0.5. */
@property (readonly) double defaultY;
/*! The lowest X the control reaches, from `rangeMinX`. Defaults to 0.0. */
@property (readonly) double rangeMinX;
/*! The highest X the control reaches, from `rangeMaxX`. Defaults to 1.0. */
@property (readonly) double rangeMaxX;
/*! The lowest Y the control reaches, from `rangeMinY`. Defaults to 0.0. */
@property (readonly) double rangeMinY;
/*! The highest Y the control reaches, from `rangeMaxY`. Defaults to 1.0. */
@property (readonly) double rangeMaxY;
/*! How the value maps onto the frame, from `coordinateMapping`. Defaults to `FxGripPointCoordinatePixel`. */
@property (readonly) FxGripPointCoordinateMapping coordinateMapping;
/*! YES when the control offsets itself by the frame margin, from `compensateFrameMargin`. Defaults to NO. */
@property (readonly) BOOL compensateFrameMargin;
/*! The control's drawn size, from `controlSize`. Clamped at zero, and 0.0 means the on-screen control's own size. */
@property (readonly) double controlSize;
/*! The control's color, from `controlColor` as an RGB or RGBA array; nil for any other shape. A missing alpha reads as opaque. */
@property (readonly, nullable) NSColor *controlColor;
/*! How far the pin sits from the point, from `pinDistance`. Defaults to 0.0, which draws no pin. */
@property (readonly) double pinDistance;
/*! The angle the pin extends along, from `pinAngle`. Defaults to 0.0. */
@property (readonly) double pinAngle;
/*! YES when the control labels itself with the parameter name, from `displayName`. Defaults to NO. */
@property (readonly) BOOL displayName;
/*! YES when the label appears only above the control, from `nameOnlyWhenAbove`. Defaults to YES. */
@property (readonly) BOOL nameOnlyWhenAbove;
/*! The multiplier on drag distance, from `mouseSpeed`. Defaults to 1.0, and a value that is not positive falls back to the default. */
@property (readonly) double mouseSpeed;
/*! YES when `mouseSpeed` applies only while Shift is held, from `mouseSpeedShiftOnly`. Defaults to NO. */
@property (readonly) BOOL mouseSpeedShiftOnly;
/*! The name of the image drawn behind the control, from `backgroundImage`; nil when the key is absent or empty. */
@property (readonly, nullable) NSString *backgroundImageName;
/*! The background image's width as a fraction of the frame, from `backgroundImageSize`. Defaults to 1.0. */
@property (readonly) double backgroundImageSize;
/*! The background image's X placement, from `backgroundImageX`. Defaults to 0.5. */
@property (readonly) double backgroundImageX;
/*! The background image's Y placement, from `backgroundImageY`. Defaults to 0.5. */
@property (readonly) double backgroundImageY;
/*! The direction the control may move, from `constraint`. An unrecognized value reads as `FxGripPointConstraintAnyDirection`. */
@property (readonly) FxGripPointConstraint constraint;
/*! The divider drawn for an axis-constrained point, from `divider`. An unrecognized value reads as `FxGripPointDividerNone`. */
@property (readonly) FxGripPointDivider divider;
/*! The X the distance constraint measures from, from `distanceFromX`. Defaults to 0.5. */
@property (readonly) double distanceFromX;
/*! The Y the distance constraint measures from, from `distanceFromY`. Defaults to 0.5. */
@property (readonly) double distanceFromY;
/*! How far the point may travel under a distance constraint, from `maxDistance`. Defaults to 1.0. */
@property (readonly) double maxDistance;
/*! YES when Shift locks a distance-constrained drag to one axis, from `distanceShiftOneAxis`. Defaults to NO. */
@property (readonly) BOOL distanceShiftOneAxis;

/*! YES when the on-screen control draws the point as a pin offset by pinDistance. */
@property (readonly) BOOL displayAsPin;

/*!
	@method		initWithConfiguration:
	@abstract	Reads a point parameter's declared configuration into typed properties.
	@discussion	Each key is read once and coerced to the expected type. A key that is absent or
				carries the wrong type takes the documented default, so a nil configuration
				yields all defaults.
	@param		configuration	The declared configuration dictionary, or nil.
	@return		The parsed options.
*/
- (nonnull instancetype)initWithConfiguration:(nullable NSDictionary *)configuration;

@end

#endif
