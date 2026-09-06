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

@property (readonly) double defaultX;
@property (readonly) double defaultY;
@property (readonly) double rangeMinX;
@property (readonly) double rangeMaxX;
@property (readonly) double rangeMinY;
@property (readonly) double rangeMaxY;
@property (readonly) FxGripPointCoordinateMapping coordinateMapping;
@property (readonly) BOOL compensateFrameMargin;
@property (readonly) double controlSize;
@property (readonly, nullable) NSColor *controlColor;
@property (readonly) double pinDistance;
@property (readonly) double pinAngle;
@property (readonly) BOOL displayName;
@property (readonly) BOOL nameOnlyWhenAbove;
@property (readonly) double mouseSpeed;
@property (readonly) BOOL mouseSpeedShiftOnly;
@property (readonly, nullable) NSString *backgroundImageName;
@property (readonly) double backgroundImageSize;
@property (readonly) double backgroundImageX;
@property (readonly) double backgroundImageY;
@property (readonly) FxGripPointConstraint constraint;
@property (readonly) FxGripPointDivider divider;
@property (readonly) double distanceFromX;
@property (readonly) double distanceFromY;
@property (readonly) double maxDistance;
@property (readonly) BOOL distanceShiftOneAxis;

/*! YES when the on-screen control draws the point as a pin offset by pinDistance. */
@property (readonly) BOOL displayAsPin;

- (nonnull instancetype)initWithConfiguration:(nullable NSDictionary *)configuration;

@end

#endif
