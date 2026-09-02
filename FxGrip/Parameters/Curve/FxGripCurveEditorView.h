//
//  FxGripCurveEditorView.h
//  FxGrip
//

#ifndef FxGripCurveEditorView_h
#define FxGripCurveEditorView_h

#import <AppKit/AppKit.h>
#import "FxGripCurveData.h"
#import "FxGripCustomViewDataDelegate.h"

@class FxGripCurveEditorView;

/*! The default slowDragScale: one-tenth of mouse travel. */
FOUNDATION_EXPORT const CGFloat kFxGripCurveSlowDragScaleDefault;

/*! The default curve stroke width, in view points. */
FOUNDATION_EXPORT const CGFloat kFxGripCurveLineWidthDefault;

/*!
	@enum       FxGripCurveBackground
	@abstract   The strip background drawn behind the curve.
	@discussion Grid draws alignment lines per `gridDivisions`. The ramps and the spectrum
				render the selector axis (horizontal); the alpha checker renders transparency.
*/
typedef NS_ENUM(NSInteger, FxGripCurveBackground) {
	FxGripCurveBackgroundGrid			= 0,
	FxGripCurveBackgroundHueSpectrum	= 1,
	FxGripCurveBackgroundLumaRamp		= 2,
	FxGripCurveBackgroundSaturationRamp	= 3,
	FxGripCurveBackgroundRedRamp		= 4,
	FxGripCurveBackgroundGreenRamp		= 5,
	FxGripCurveBackgroundBlueRamp		= 6,
	FxGripCurveBackgroundAlphaChecker	= 7,
};

/*!
	@enum       FxGripCurveGridDivisions
	@abstract   How many equal divisions the alignment grid draws behind the curve.
	@discussion Introduced in FxGrip 1.0. The interior lines split each axis into the given
				number of equal parts, leaving `divisions - 1` lines per axis. Finer lines
				dim by tier so the primary quarter lines stay dominant, matching Final Cut Pro:

				Quarters  → 3 lines, all at the primary weight.
				Eighths   → 7 lines; the 1/8 lines dim below the 1/4 lines. (Default.)
				Sixteenths → 15 lines; the 1/16 lines dim below the 1/8 lines.
*/
typedef NS_ENUM(NSInteger, FxGripCurveGridDivisions) {
	FxGripCurveGridDivisionsQuarters	= 4,
	FxGripCurveGridDivisionsEighths		= 8,
	FxGripCurveGridDivisionsSixteenths	= 16,
};

/*!
	@enum       FxGripCurveLineStyle
	@abstract   How the curve line is stroked.
	@discussion Solid strokes with lineColor. Hue strokes with the hue spectrum along x, so the
				line reads as a rainbow that matches a hue-spectrum background.
*/
typedef NS_ENUM(NSInteger, FxGripCurveLineStyle) {
	FxGripCurveLineStyleSolid	= 0,
	FxGripCurveLineStyleHue		= 1,
};

/*!
	@enum       FxGripCurvePaintKind
	@abstract   What paints a vertical background stop.
	@discussion None is transparent and fades to the strip base. Color is a fixed color. Hue is the
				hue spectrum along x, so a stop can carry the full spectrum at its vertical position.
*/
typedef NS_ENUM(NSInteger, FxGripCurvePaintKind) {
	FxGripCurvePaintKindNone	= 0,
	FxGripCurvePaintKindColor	= 1,
	FxGripCurvePaintKindHue		= 2,
};

/*!
	@class      FxGripCurvePaint
	@abstract   One stop of a vertical background gradient: none, a color, or the hue spectrum.
	@discussion Introduced in FxGrip 1.0. Immutable. A curve strip composes up to three of these
				(top, center, bottom) into a vertical gradient over the strip base.
*/
@interface FxGripCurvePaint : NSObject <NSCopying>
@property (nonatomic, readonly) FxGripCurvePaintKind kind;
@property (nonatomic, readonly, nullable) NSColor *color;
/*! A transparent stop; the gradient fades to the strip base here. */
+ (nonnull instancetype)nonePaint;
/*! A fixed-color stop. */
+ (nonnull instancetype)paintWithColor:(nonnull NSColor *)color;
/*! A hue-spectrum stop: the color runs across x at this vertical position. */
+ (nonnull instancetype)huePaint;
@end

/*!
	@enum       FxGripCurveReadoutStyle
	@abstract   How a point's exact value is displayed.
	@discussion None draws nothing. FloatingChip pins a value chip near the point. Axis draws
				crosshair guides to the edges with the value at each axis. Corner shows the value in
				a fixed strip corner. SystemTooltip uses the OS tooltip (shown after the hover delay).
*/
typedef NS_ENUM(NSInteger, FxGripCurveReadoutStyle) {
	FxGripCurveReadoutStyleNone			= 0,
	FxGripCurveReadoutStyleFloatingChip	= 1,
	FxGripCurveReadoutStyleAxis			= 2,
	FxGripCurveReadoutStyleCorner		= 3,
	FxGripCurveReadoutStyleSystemTooltip	= 4,
};

/*!
	@enum       FxGripCurveReadoutUnits
	@abstract   The units a point's value is shown in.
	@discussion DomainAware reads x as degrees for a circular (hue) domain and as 0–255 otherwise,
				and reads y as 0–255.
*/
typedef NS_ENUM(NSInteger, FxGripCurveReadoutUnits) {
	FxGripCurveReadoutUnitsNormalized	= 0,	// 0.00–1.00
	FxGripCurveReadoutUnitsEightBit		= 1,	// 0–255
	FxGripCurveReadoutUnitsPercent		= 2,	// 0–100%
	FxGripCurveReadoutUnitsDomainAware	= 3,
};

/*!
	@enum       FxGripCurveReadoutTrigger
	@abstract   When the readout appears.
	@discussion ActivePoint shows it for the dragged or selected point. ActiveAndHover adds any
				hovered point. ActiveAndModifierHover adds a hovered point only while Command is held.
*/
typedef NS_ENUM(NSInteger, FxGripCurveReadoutTrigger) {
	FxGripCurveReadoutTriggerActivePoint			= 0,
	FxGripCurveReadoutTriggerActiveAndHover			= 1,
	FxGripCurveReadoutTriggerActiveAndModifierHover	= 2,
};

/*!
	@protocol   FxGripCurveEditorDelegate
	@abstract   Receives the editor's edits.
	@discussion didEdit fires continuously during a drag; didCommit fires on mouse-up
				and keyboard edits, the boundary an out-of-band write (and the host's
				undo entry) coalesces to.
*/
@protocol FxGripCurveEditorDelegate <NSObject>
- (void)curveEditorView:(nonnull FxGripCurveEditorView *)editor didEditCurve:(nonnull FxGripCurveData *)curve;
- (void)curveEditorView:(nonnull FxGripCurveEditorView *)editor didCommitCurve:(nonnull FxGripCurveData *)curve;
@end

/*!
	@class      FxGripCurveEditorView
	@abstract   One reusable curve editor: an FCP-style strip or pane for a single curve.
	@discussion Introduced in FxGrip 1.0. The domain, role, and background style the
				editor; the same class serves every mapping. Interactions: click on the
				curve adds a point; dragging moves it (a linear domain pins the first
				and last point in x; a circular domain wraps x); holding Control during
				a drag slows the point to slowDragScale of mouse travel for fine
				positioning; Option-click on a point deletes it, as do dragging far
				outside the strip, pressing Delete, and the context menu's Delete
				Point item; double-click resets to the role's identity. A linear
				curve's pinned endpoints never delete. Rendering evaluates the curve with the same
				Fritsch-Carlson builders the render uses, at view-width resolution, so
				the drawn curve equals the applied curve.

				updateFromCustomData: accepts an FxGripCurveData directly, or a curve
				set from which the editor reads its mappingKey.
*/
@interface FxGripCurveEditorView : NSView <FxGripCustomViewDataDelegate>

/*! The curve set key this editor edits; consulted by updateFromCustomData:. */
@property (nonatomic, copy, nullable) NSString *mappingKey;
@property (nonatomic, assign) FxGripCurveBackground background;

/*! The alignment grid density. Defaults to eighths (7 lines). Setting redraws. */
@property (nonatomic, assign) FxGripCurveGridDivisions gridDivisions;

@property (nonatomic, assign, nullable) id<FxGripCurveEditorDelegate> delegate;

/*! The curve being edited; never nil after initialization. Setting redraws. */
@property (nonatomic, copy, nonnull) FxGripCurveData *curve;

/*!
	@property   lineColor
	@abstract   The stroke color of the curve. Defaults to white; setting nil restores white.
	@discussion A curve set colors each strip to the channel it edits: red, green, blue, or an
				arbitrary color over a hue spectrum. The point handles stay light for contrast on
				any line color. Setting redraws.
*/
@property (nonatomic, copy, null_resettable) NSColor *lineColor;

/*! How the curve line is stroked. Defaults to solid (lineColor). Setting redraws. */
@property (nonatomic, assign) FxGripCurveLineStyle lineStyle;

/*!
	@property   lineWidth
	@abstract   The stroke width of the curve line, in view points.
	@discussion Defaults to kFxGripCurveLineWidthDefault (1.0). Applies to both the solid
				and the hue line styles. A curve line of roughly 0.5 to 4 points reads well
				at the standard strip height; setting clamps to [0.1, 8.0], a range wide
				enough to try heavy lines, and redraws.
*/
@property (nonatomic, assign) CGFloat lineWidth;

/*!
	@abstract   A vertical background gradient built from up to three stops: top, center, bottom.
	@discussion When any of the three is set, the gradient draws over `background`. Each stop is a
				color, the hue spectrum, or none (transparent, fading to the strip base). A nil
				center makes a two-stop top-to-bottom gradient; a nil top or bottom drops that end.
				All three nil falls back to `background`. Setting any redraws.
*/
@property (nonatomic, copy, nullable) FxGripCurvePaint *topPaint;
@property (nonatomic, copy, nullable) FxGripCurvePaint *centerPaint;
@property (nonatomic, copy, nullable) FxGripCurvePaint *bottomPaint;

/*! How a point's exact value is displayed. Defaults to none. Setting redraws. */
@property (nonatomic, assign) FxGripCurveReadoutStyle pointReadoutStyle;

/*! The units the readout shows. Defaults to normalized. Setting redraws. */
@property (nonatomic, assign) FxGripCurveReadoutUnits pointReadoutUnits;

/*! When the readout appears. Defaults to the active (dragged or selected) point. Setting redraws. */
@property (nonatomic, assign) FxGripCurveReadoutTrigger pointReadoutTrigger;

/*! The index of the selected point, or NSNotFound. */
@property (nonatomic, readonly) NSUInteger selectedPointIndex;

/*!
	@property   slowDragScale
	@abstract   The fraction of mouse travel a Control-slowed drag applies.
	@discussion Defaults to kFxGripCurveSlowDragScaleDefault (0.1), which lands the
				point within half an 8-bit value step per point of travel at the
				standard strip height. Setting clamps to [0.01, 1.0].
*/
@property (nonatomic, assign) CGFloat slowDragScale;

- (nonnull instancetype)initWithFrame:(NSRect)frameRect
								 role:(FxGripCurveRole)role
							   domain:(FxGripCurveDomain)domain
						   background:(FxGripCurveBackground)background;

/*! Replaces the curve with the role's identity and commits. */
- (void)resetCurve;

@end

#endif /* FxGripCurveEditorView_h */
