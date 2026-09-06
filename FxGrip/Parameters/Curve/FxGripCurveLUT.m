/*!
	@file       FxGripCurveLUT.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripCurveLUT
	@abstract   Implements the monotone cubic LUT builders for the clamped and circular domains.
	@discussion Introduced in FxGrip 0.1.0. Both builders copy, sort, and deduplicate the control
	            points, then evaluate a Fritsch-Carlson monotone cubic spline into the output LUT.
	            The clamped builder holds the end values outside the point range. The periodic builder
	            treats the x domain as a circle of period 1 and gives a C1-continuous seam at x = 0/1.
	            Degenerate inputs yield an identity ramp or a constant.
*/

#import "FxGripCurveLUT.h"
#import <stdlib.h>
#import <string.h>
#import <math.h>

typedef struct { float x, y; } FxGripCurvePoint;

/*! qsort comparator ordering control points by ascending x. */
static int FxGripCurveCompare(const void *a, const void *b)
{
	float xa = ((const FxGripCurvePoint *)a)->x, xb = ((const FxGripCurvePoint *)b)->x;
	return (xa < xb) ? -1 : (xa > xb ? 1 : 0);
}

static void FxGripCurveIdentityRamp(float *outLUT, int n)
{
	for (int i = 0; i < n; i++) {
		outLUT[i] = (n > 1) ? (float)i / (float)(n - 1) : 0.0f;
	}
}

/*! Copies, optionally folds x into [0, 1), sorts, and drops duplicate x (first wins).
	Returns the deduplicated count; the caller frees the result. */
static unsigned long FxGripCurvePreparePoints(const float (*points)[2], unsigned long count,
											  BOOL fold, FxGripCurvePoint **outPoints)
{
	FxGripCurvePoint *pts = malloc(count * sizeof(FxGripCurvePoint));
	memcpy(pts, points, count * sizeof(FxGripCurvePoint));
	if (fold) {
		for (unsigned long i = 0; i < count; i++) {
			pts[i].x -= floorf(pts[i].x);
		}
	}
	qsort(pts, count, sizeof(FxGripCurvePoint), FxGripCurveCompare);

	unsigned long m = 0;
	for (unsigned long i = 0; i < count; i++) {
		if (m == 0 || pts[i].x > pts[m - 1].x + 1e-9f) {
			pts[m++] = pts[i];
		}
	}
	*outPoints = pts;
	return m;
}

void FxGripBuildCurveLUT(const float (*points)[2], unsigned long count, float *outLUT, int n)
{
	if (n <= 0) {
		return;
	}
	if (!points || count < 2) {
		FxGripCurveIdentityRamp(outLUT, n);
		return;
	}
	FxGripCurvePoint *pts = NULL;
	unsigned long m = FxGripCurvePreparePoints(points, count, NO, &pts);
	if (m < 2) {
		float y = pts[0].y;
		for (int i = 0; i < n; i++) {
			outLUT[i] = y;
		}
		free(pts);
		return;
	}

	double *h = malloc((m - 1) * sizeof(double));
	double *delta = malloc((m - 1) * sizeof(double));
	double *slope = malloc(m * sizeof(double));
	for (unsigned long i = 0; i < m - 1; i++) {
		h[i] = pts[i + 1].x - pts[i].x;
		delta[i] = (pts[i + 1].y - pts[i].y) / h[i];
	}
	slope[0] = delta[0];
	slope[m - 1] = delta[m - 2];
	for (unsigned long i = 1; i < m - 1; i++) {
		if (delta[i - 1] * delta[i] <= 0.0) {
			slope[i] = 0.0;
		} else {
			double w1 = 2.0 * h[i] + h[i - 1];
			double w2 = h[i] + 2.0 * h[i - 1];
			slope[i] = (w1 + w2) / (w1 / delta[i - 1] + w2 / delta[i]);
		}
	}

	for (int k = 0; k < n; k++) {
		double x = (n > 1) ? (double)k / (double)(n - 1) : 0.0;
		if (x <= pts[0].x) {
			outLUT[k] = pts[0].y;
			continue;
		}
		if (x >= pts[m - 1].x) {
			outLUT[k] = pts[m - 1].y;
			continue;
		}
		unsigned long i = 0;
		while (i < m - 1 && x > pts[i + 1].x) {
			i++;
		}
		double t = (x - pts[i].x) / h[i];
		double t2 = t * t, t3 = t2 * t;
		double h00 = 2.0 * t3 - 3.0 * t2 + 1.0;
		double h10 = t3 - 2.0 * t2 + t;
		double h01 = -2.0 * t3 + 3.0 * t2;
		double h11 = t3 - t2;
		double y = h00 * pts[i].y + h10 * h[i] * slope[i]
				 + h01 * pts[i + 1].y + h11 * h[i] * slope[i + 1];
		outLUT[k] = (float)y;
	}

	free(h);
	free(delta);
	free(slope);
	free(pts);
}

void FxGripBuildCurveLUTPeriodic(const float (*points)[2], unsigned long count, float *outLUT, int n)
{
	if (n <= 0) {
		return;
	}
	if (!points || count < 2) {
		FxGripCurveIdentityRamp(outLUT, n);
		return;
	}
	FxGripCurvePoint *pts = NULL;
	unsigned long m = FxGripCurvePreparePoints(points, count, YES, &pts);
	if (m < 2) {
		float y = pts[0].y;
		for (int i = 0; i < n; i++) {
			outLUT[i] = y;
		}
		free(pts);
		return;
	}

	// m intervals on the circle (period 1): interval i runs from point i to point
	// (i+1) mod m; the last one wraps across the seam, its width extended by the period.
	const double period = 1.0;
	double *h = malloc(m * sizeof(double));
	double *delta = malloc(m * sizeof(double));
	double *slope = malloc(m * sizeof(double));
	for (unsigned long i = 0; i < m; i++) {
		unsigned long j = (i + 1) % m;
		double dx = pts[j].x - pts[i].x;
		if (i == m - 1) {
			dx += period;
		}
		h[i] = dx;
		delta[i] = (pts[j].y - pts[i].y) / h[i];
	}
	// Periodic Fritsch-Carlson: every point has both neighbor intervals, so there is no
	// one-sided endpoint slope — the slopes at point 0 and point m-1 both see the wrap
	// interval, giving a C¹ seam.
	for (unsigned long i = 0; i < m; i++) {
		unsigned long p = (i + m - 1) % m;
		if (delta[p] * delta[i] <= 0.0) {
			slope[i] = 0.0;
		} else {
			double w1 = 2.0 * h[i] + h[p];
			double w2 = h[i] + 2.0 * h[p];
			slope[i] = (w1 + w2) / (w1 / delta[p] + w2 / delta[i]);
		}
	}

	for (int k = 0; k < n; k++) {
		double x = (n > 1) ? (double)k / (double)(n - 1) : 0.0;
		x -= floor(x);
		unsigned long i;
		double t;
		if (x < pts[0].x || x >= pts[m - 1].x) {
			// Wrap interval: covers [pts[m-1].x, 1) U [0, pts[0].x).
			i = m - 1;
			double xx = (x >= pts[m - 1].x) ? x : x + period;
			t = (xx - pts[m - 1].x) / h[i];
		} else {
			i = 0;
			while (i < m - 1 && x >= pts[i + 1].x) {
				i++;
			}
			t = (x - pts[i].x) / h[i];
		}
		unsigned long j = (i + 1) % m;
		double t2 = t * t, t3 = t2 * t;
		double h00 = 2.0 * t3 - 3.0 * t2 + 1.0;
		double h10 = t3 - 2.0 * t2 + t;
		double h01 = -2.0 * t3 + 3.0 * t2;
		double h11 = t3 - t2;
		double y = h00 * pts[i].y + h10 * h[i] * slope[i]
				 + h01 * pts[j].y + h11 * h[i] * slope[j];
		outLUT[k] = (float)y;
	}

	free(h);
	free(delta);
	free(slope);
	free(pts);
}
