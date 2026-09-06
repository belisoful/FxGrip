/*!
	@file       FxGripRect.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripRect
	@abstract   Implements the FxRect rectangle algebra in the pixel-bounds convention.
	@discussion Introduced in FxGrip 0.1.0. The functions treat FxRect as `{ left, bottom, right, top }`
	            in a y-up pixel space and a rectangle as empty when its width or height is not positive.
	            Intersection and the empty result use the canonical empty rectangle `{ 0, 0, 0, 0 }`, and
	            union treats an empty operand as absent.
*/

#import "FxGripRect.h"

FxRect FxGripRectMake(SInt32 left, SInt32 bottom, SInt32 right, SInt32 top)
{
	return (FxRect){ .left = left, .bottom = bottom, .right = right, .top = top };
}

FxRect FxGripRectZero(void)
{
	return FxGripRectMake(0, 0, 0, 0);
}

SInt32 FxGripRectWidth(FxRect rect)
{
	return rect.right > rect.left ? rect.right - rect.left : 0;
}

SInt32 FxGripRectHeight(FxRect rect)
{
	return rect.top > rect.bottom ? rect.top - rect.bottom : 0;
}

BOOL FxGripRectIsEmpty(FxRect rect)
{
	return rect.right <= rect.left || rect.top <= rect.bottom;
}

BOOL FxGripRectEqualToRect(FxRect a, FxRect b)
{
	return a.left == b.left && a.bottom == b.bottom && a.right == b.right && a.top == b.top;
}

FxRect FxGripRectStandardize(FxRect rect)
{
	SInt32 left = MIN(rect.left, rect.right);
	SInt32 right = MAX(rect.left, rect.right);
	SInt32 bottom = MIN(rect.bottom, rect.top);
	SInt32 top = MAX(rect.bottom, rect.top);
	return FxGripRectMake(left, bottom, right, top);
}

BOOL FxGripRectContainsPoint(FxRect rect, SInt32 x, SInt32 y)
{
	return x >= rect.left && x < rect.right && y >= rect.bottom && y < rect.top;
}

BOOL FxGripRectContainsRect(FxRect outer, FxRect inner)
{
	if (FxGripRectIsEmpty(inner)) {
		return YES;
	}
	if (FxGripRectIsEmpty(outer)) {
		return NO;
	}
	return inner.left >= outer.left && inner.right <= outer.right
		&& inner.bottom >= outer.bottom && inner.top <= outer.top;
}

BOOL FxGripRectIntersectsRect(FxRect a, FxRect b)
{
	return !FxGripRectIsEmpty(FxGripRectIntersection(a, b));
}

FxRect FxGripRectIntersection(FxRect a, FxRect b)
{
	SInt32 left = MAX(a.left, b.left);
	SInt32 bottom = MAX(a.bottom, b.bottom);
	SInt32 right = MIN(a.right, b.right);
	SInt32 top = MIN(a.top, b.top);
	if (left < right && bottom < top) {
		return FxGripRectMake(left, bottom, right, top);
	}
	return FxGripRectZero();
}

FxRect FxGripRectUnion(FxRect a, FxRect b)
{
	if (FxGripRectIsEmpty(a)) {
		return FxGripRectIsEmpty(b) ? FxGripRectZero() : FxGripRectStandardize(b);
	}
	if (FxGripRectIsEmpty(b)) {
		return FxGripRectStandardize(a);
	}
	SInt32 left = MIN(a.left, b.left);
	SInt32 bottom = MIN(a.bottom, b.bottom);
	SInt32 right = MAX(a.right, b.right);
	SInt32 top = MAX(a.top, b.top);
	return FxGripRectMake(left, bottom, right, top);
}

FxRect FxGripRectOffset(FxRect rect, SInt32 dx, SInt32 dy)
{
	return FxGripRectMake(rect.left + dx, rect.bottom + dy, rect.right + dx, rect.top + dy);
}

FxRect FxGripRectInset(FxRect rect, SInt32 dx, SInt32 dy)
{
	FxRect inset = FxGripRectMake(rect.left + dx, rect.bottom + dy, rect.right - dx, rect.top - dy);
	return FxGripRectIsEmpty(inset) ? FxGripRectZero() : inset;
}

CGRect FxGripRectToCGRect(FxRect rect)
{
	return CGRectMake(rect.left, rect.bottom, FxGripRectWidth(rect), FxGripRectHeight(rect));
}

FxRect FxGripRectFromCGRect(CGRect rect)
{
	SInt32 left = (SInt32)floor(CGRectGetMinX(rect));
	SInt32 bottom = (SInt32)floor(CGRectGetMinY(rect));
	SInt32 right = (SInt32)ceil(CGRectGetMaxX(rect));
	SInt32 top = (SInt32)ceil(CGRectGetMaxY(rect));
	return FxGripRectMake(left, bottom, right, top);
}

void FxGripCGRectGetCorners(CGRect rect, CGPoint corners[_Nonnull 4])
{
	CGFloat minX = CGRectGetMinX(rect), maxX = CGRectGetMaxX(rect);
	CGFloat minY = CGRectGetMinY(rect), maxY = CGRectGetMaxY(rect);
	corners[0] = CGPointMake(minX, minY);
	corners[1] = CGPointMake(maxX, minY);
	corners[2] = CGPointMake(maxX, maxY);
	corners[3] = CGPointMake(minX, maxY);
}

CGRect FxGripCGRectBoundingPoints(const CGPoint *points, NSUInteger count)
{
	if (points == NULL || count == 0) {
		return CGRectZero;
	}
	CGFloat minX = points[0].x, maxX = points[0].x;
	CGFloat minY = points[0].y, maxY = points[0].y;
	for (NSUInteger index = 1; index < count; index++) {
		minX = MIN(minX, points[index].x);
		maxX = MAX(maxX, points[index].x);
		minY = MIN(minY, points[index].y);
		maxY = MAX(maxY, points[index].y);
	}
	return CGRectMake(minX, minY, maxX - minX, maxY - minY);
}
