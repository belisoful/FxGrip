//
//  FxGripRect.h
//  FxGrip
//

#ifndef FxGripRect_h
#define FxGripRect_h

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <FxPlug/FxPlugSDK.h>

NS_ASSUME_NONNULL_BEGIN

/*!
	@header     FxGripRect
	@abstract   Rectangle algebra for FxPlug's integer FxRect, in the pixel-bounds convention.
	@discussion Introduced in FxGrip 1.0. FxRect is `{ left, bottom, right, top }` in a y-up pixel
				space: width is right minus left, height is top minus bottom, and a rectangle is
				empty when either is not positive. FxPlug hands effects FxRects for image and tile
				bounds but ships no operations for them, so every effect that clips, unions, or
				tests bounds reimplements this. These functions supply union, intersection,
				containment, and the CGRect bridge once.

				Intersection and the empty result use the canonical empty rectangle
				`{ 0, 0, 0, 0 }`. Union treats an empty operand as absent and returns the other.
*/

/*! A rectangle from its four edges. */
FxRect FxGripRectMake(SInt32 left, SInt32 bottom, SInt32 right, SInt32 top);

/*! The canonical empty rectangle, `{ 0, 0, 0, 0 }`. */
FxRect FxGripRectZero(void);

/*! right minus left, clamped to zero. */
SInt32 FxGripRectWidth(FxRect rect);

/*! top minus bottom, clamped to zero. */
SInt32 FxGripRectHeight(FxRect rect);

/*! YES when the rectangle has no positive area. */
BOOL FxGripRectIsEmpty(FxRect rect);

/*! Field-by-field equality. */
BOOL FxGripRectEqualToRect(FxRect a, FxRect b);

/*! A rectangle with left ≤ right and bottom ≤ top, swapping inverted edges. */
FxRect FxGripRectStandardize(FxRect rect);

/*! YES when (x, y) is inside, with the left and bottom edges inclusive and the right and top
	edges exclusive. */
BOOL FxGripRectContainsPoint(FxRect rect, SInt32 x, SInt32 y);

/*! YES when inner lies within outer. An empty inner is contained by any rectangle. */
BOOL FxGripRectContainsRect(FxRect outer, FxRect inner);

/*! YES when the two rectangles share positive area. */
BOOL FxGripRectIntersectsRect(FxRect a, FxRect b);

/*! The overlap of the two rectangles, or the empty rectangle when they do not overlap. */
FxRect FxGripRectIntersection(FxRect a, FxRect b);

/*! The smallest rectangle containing both. An empty operand is treated as absent. */
FxRect FxGripRectUnion(FxRect a, FxRect b);

/*! The rectangle translated by (dx, dy). */
FxRect FxGripRectOffset(FxRect rect, SInt32 dx, SInt32 dy);

/*! The rectangle inset by dx on the left and right and dy on the bottom and top; negative values
	grow it. An inset past empty returns the empty rectangle. */
FxRect FxGripRectInset(FxRect rect, SInt32 dx, SInt32 dy);

/*! The rectangle as a CGRect, with left/bottom as the origin. */
CGRect FxGripRectToCGRect(FxRect rect);

/*! A rectangle from a CGRect, rounding the origin down and the far edges up so the result covers
	the CGRect. */
FxRect FxGripRectFromCGRect(CGRect rect);

/*! Writes the four corners of rect into corners, in lower-left, lower-right, upper-right,
	upper-left order. */
void FxGripCGRectGetCorners(CGRect rect, CGPoint corners[_Nonnull 4]);

/*! The smallest CGRect containing every point, or CGRectZero when count is 0. Useful for the
	bounding box of a set of transformed corners. */
CGRect FxGripCGRectBoundingPoints(const CGPoint *_Nullable points, NSUInteger count);

NS_ASSUME_NONNULL_END

#endif /* FxGripRect_h */
