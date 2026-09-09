/*!
	@file       FxGripFMMKernels.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-08
	@header     FxGripFMMKernels
	@abstract   Implements the FMM particle kernels.
	@discussion Introduced in FxGrip 0.1.0. The P2P kernel evaluates one block of eight targets at a
	            time. Target coordinates load into eight-wide vectors; each source broadcasts a scalar
	            across the block; the reciprocal cube of the softened distance scales the separation
	            and accumulates into the block's field. A partial final block copies through a padded
	            local buffer so every real target runs the same vector path and no read strays past the
	            arrays. Summation runs in source order for a target, so the result is reproducible.
*/

#include "FxGripFMMKernels.h"
#include <simd/simd.h>
#include <string.h>

// Loads up to eight targets into aligned lane buffers, zero-padding the unused lanes.
static inline void FxGripFMMLoadTargetBlock(const float *tx, const float *ty, const float *tz,
											uint32_t base, uint32_t blockCount,
											float *bx, float *by, float *bz)
{
	for (uint32_t l = 0; l < 8u; l++) {
		if (l < blockCount) {
			bx[l] = tx[base + l];
			by[l] = ty[base + l];
			bz[l] = tz[base + l];
		} else {
			bx[l] = 0.0f;
			by[l] = 0.0f;
			bz[l] = 0.0f;
		}
	}
}

void FxGripFMMFieldP2P(const float *tx, const float *ty, const float *tz,
					   float *ex, float *ey, float *ez, uint32_t nt,
					   const float *sx, const float *sy, const float *sz, const float *ss, uint32_t ns,
					   float eps2)
{
	if (nt == 0 || ns == 0) {
		return;
	}
	const simd_float8 eps2v = eps2;

	for (uint32_t base = 0; base < nt; base += 8u) {
		const uint32_t blockCount = (nt - base) < 8u ? (nt - base) : 8u;

		_Alignas(16) float bx[8], by[8], bz[8];
		FxGripFMMLoadTargetBlock(tx, ty, tz, base, blockCount, bx, by, bz);
		const simd_float8 txv = *(const simd_float8 *)bx;
		const simd_float8 tyv = *(const simd_float8 *)by;
		const simd_float8 tzv = *(const simd_float8 *)bz;

		simd_float8 accx = 0.0f, accy = 0.0f, accz = 0.0f;
		for (uint32_t j = 0; j < ns; j++) {
			const simd_float8 dx = sx[j] - txv;
			const simd_float8 dy = sy[j] - tyv;
			const simd_float8 dz = sz[j] - tzv;
			const simd_float8 r2 = dx * dx + dy * dy + dz * dz + eps2v;
			// One Newton step refines the hardware estimate to near single-precision accuracy, so the
			// near field is exact to the limit of float regardless of the platform estimate.
			simd_float8 inv = simd_rsqrt(r2);
			inv = inv * (1.5f - 0.5f * r2 * inv * inv);
			const simd_float8 w = ss[j] * inv * inv * inv;
			accx += w * dx;
			accy += w * dy;
			accz += w * dz;
		}

		_Alignas(16) float ox[8], oy[8], oz[8];
		*(simd_float8 *)ox = accx;
		*(simd_float8 *)oy = accy;
		*(simd_float8 *)oz = accz;
		for (uint32_t l = 0; l < blockCount; l++) {
			ex[base + l] += ox[l];
			ey[base + l] += oy[l];
			ez[base + l] += oz[l];
		}
	}
}
