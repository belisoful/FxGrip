/*!
	@file       FxGripFMMKernels.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-08
	@header     FxGripFMMKernels
	@abstract   The particle-level kernels of the Fast Multipole Method.
	@discussion Introduced in FxGrip 0.1.0. A private core header, not part of the framework API. This
	            declares the direct particle-to-particle (P2P) kernel that evaluates the exact near
	            field between two body ranges. The multipole kernels (P2M, M2M, M2L, L2L, L2P) are added
	            here as later phases build them.

	            The P2P kernel processes targets eight at a time with the hardware reciprocal square
	            root. It accumulates into the target field, so the caller sums the near field over
	            several source ranges by calling it once per range. A nonzero softening is required: it
	            bounds the near force and makes a body's self term vanish, so a range may be its own
	            source without an index test.
*/

#ifndef FxGripFMMKernels_h
#define FxGripFMMKernels_h

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/*!
	@function   FxGripFMMFieldP2P
	@abstract   Adds the softened Laplace field of a source range onto a target range.
	@discussion Introduced in FxGrip 0.1.0. For each target i, adds
	            Σ_j strength_j · (s_j − t_i) / (|s_j − t_i|² + ε²)^{3/2} into (ex, ey, ez). The target
	            and source ranges may be the same arrays; with ε² > 0 the self term is exactly zero, so
	            no index test is needed. The field is accumulated, not overwritten.
	@param      tx          Target x coordinates, length nt.
	@param      ty          Target y coordinates, length nt.
	@param      tz          Target z coordinates, length nt.
	@param      ex          Target x field accumulators, length nt, added into.
	@param      ey          Target y field accumulators, length nt, added into.
	@param      ez          Target z field accumulators, length nt, added into.
	@param      nt          Target count.
	@param      sx          Source x coordinates, length ns.
	@param      sy          Source y coordinates, length ns.
	@param      sz          Source z coordinates, length ns.
	@param      ss          Source strengths, length ns.
	@param      ns          Source count.
	@param      eps2        The softening ε², which must be positive.
*/
void FxGripFMMFieldP2P(const float *tx, const float *ty, const float *tz,
					   float *ex, float *ey, float *ez, uint32_t nt,
					   const float *sx, const float *sy, const float *sz, const float *ss, uint32_t ns,
					   float eps2);

#ifdef __cplusplus
}
#endif

#endif /* FxGripFMMKernels_h */
