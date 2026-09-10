/*!
	@file       FxGripParticleRand.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-09
	@header     FxGripParticleRand
	@abstract   Implements the seeded, index-keyed variation function.
	@discussion Introduced in FxGrip 0.1.0. The hash mixes the index, the seed, and the channel with
	            three large odd multipliers and two xor-shifts, then maps the 32-bit result onto
	            [-1, 1]. Its output is the contract: changing the constants changes every seeded
	            particle effect that has been rendered.
*/

#import "FxGripParticleRand.h"
#import <math.h>

float FxGripParticleRand(uint32_t index, uint32_t seed, uint32_t channel)
{
	uint32_t h = index * 747796405u + seed * 2891336453u + (channel + 1u) * 2246822519u;
	h ^= h >> 16;
	h *= 2246822519u;
	h ^= h >> 13;
	h *= 3266489917u;
	h ^= h >> 16;
	return ((float)h / 2147483647.5f) - 1.0f;
}

simd_float3 FxGripParticleRand3(uint32_t index, uint32_t seed, uint32_t channel)
{
	return simd_make_float3(FxGripParticleRand(index, seed, channel),
							FxGripParticleRand(index, seed, channel + 1),
							FxGripParticleRand(index, seed, channel + 2));
}

const double FxGripParticleMaxSpreadAngle = 0.99 * M_PI;

float FxGripParticleSpreadTangent(double spreadAngle)
{
	if (spreadAngle <= 0.0) {
		return 0.0f;
	}
	double angle = fmin(spreadAngle, FxGripParticleMaxSpreadAngle);
	return tanf((float)(angle * 0.5));
}
