//
//  FxGripCurveLUT.h
//  FxGrip
//

#ifndef FxGripCurveLUT_h
#define FxGripCurveLUT_h

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

/*!
	@function   FxGripBuildCurveLUT
	@abstract   Fills a 1-D LUT from curve control points using monotone cubic
				interpolation.
	@discussion Introduced in FxGrip 1.0. A CPU port of Metal Forge's MTFBuildCurveLUT,
				kept numerically identical so editor previews and keyframe blending
				match the render. Control points are copied, sorted by x, and
				deduplicated (first wins). Fritsch-Carlson PCHIP slopes give a monotone
				spline with no overshoot; outside the point range the end values hold.
				Fewer than 2 distinct points yield an identity ramp (NULL, count < 2)
				or a constant (1 distinct x). Each point is {x, y}; the layout matches
				simd_float2.
	@param      points  The control points (x = input, y = output), or NULL for an
						identity ramp.
	@param      count   The number of control points.
	@param      outLUT  The output buffer, filled with `n` entries.
	@param      n       The number of LUT entries to write.
*/
void FxGripBuildCurveLUT(const float (*_Nullable points)[2], unsigned long count,
						 float *_Nonnull outLUT, int n);

/*!
	@function   FxGripBuildCurveLUTPeriodic
	@abstract   Fills a 1-D LUT using periodic monotone cubic interpolation, for a
				selector whose domain wraps (hue: x = 0 and x = 1 are the same point).
	@discussion Introduced in FxGrip 1.0. A CPU port of Metal Forge's
				MTFBuildCurveLUTPeriodic. The x domain is a circle of period 1: input x
				folds into [0, 1), the control points form a closed loop, the interval
				from the last point wraps across the seam back to the first, and every
				point's PCHIP slope uses both wrapped neighbors. The result is
				C¹-continuous across x = 0/1 and `outLUT[0] == outLUT[n-1]`. Degenerate
				inputs match FxGripBuildCurveLUT.
*/
void FxGripBuildCurveLUTPeriodic(const float (*_Nullable points)[2], unsigned long count,
								 float *_Nonnull outLUT, int n);

#ifdef __cplusplus
}
#endif

#endif /* FxGripCurveLUT_h */
