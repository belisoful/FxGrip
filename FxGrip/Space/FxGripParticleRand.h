/*!
	@file       FxGripParticleRand.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-09
	@header     FxGripParticleRand
	@abstract   The seeded, index-keyed variation function every deterministic particle system in
	            FxGrip draws from.
	@discussion Introduced in FxGrip 0.1.0. A particle effect reproduces a frame only when the
	            per-particle variation is a pure function of a seed and the particle's birth index.
	            This file declares that function, with a channel argument so each varied property
	            draws an independent stream, and the spreading-angle tangent that scales a birth
	            velocity. It has no render-engine dependency. `FxGripParticleSystem` (SceneKit) and
	            `FxGripRealityKitParticleSystem` (RealityKit) share it, so the same seed produces the
	            same variation in both engines.
*/

#ifndef FxGripParticleRand_h
#define FxGripParticleRand_h

#include <stdint.h>
#include <simd/simd.h>

#ifdef __cplusplus
extern "C" {
#endif

/*!
	@function   FxGripParticleRand
	@abstract   One reproducible value in [-1, 1] from a particle index, a seed, and a channel.
	@param      index    The particle's birth index.
	@param      seed     The system seed.
	@param      channel  The property stream. Different channels give independent values for the same
	                     particle.
	@discussion Introduced in FxGrip 0.1.0. An integer hash, so the value depends on the arguments and
	            nothing else, on every architecture.
*/
float FxGripParticleRand(uint32_t index, uint32_t seed, uint32_t channel);

/*! @abstract Three reproducible values, from `channel`, `channel + 1`, and `channel + 2`. */
simd_float3 FxGripParticleRand3(uint32_t index, uint32_t seed, uint32_t channel);

/*!
	@const      FxGripParticleMaxSpreadAngle
	@abstract   The largest full-cone spreading angle a system applies, just short of pi.
	@discussion Introduced in FxGrip 0.1.0. The half-angle tangent that scales the spread diverges at
	            pi, so a spreading angle at or beyond this value is treated as this value and the birth
	            velocity stays finite.
*/
extern const double FxGripParticleMaxSpreadAngle;

/*!
	@function   FxGripParticleSpreadTangent
	@abstract   The tangent of half the spreading angle, which scales the seeded spread of a birth
	            velocity.
	@discussion Introduced in FxGrip 0.1.0. Returns zero for an angle at or below zero, and caps the
	            angle at `FxGripParticleMaxSpreadAngle`.
*/
float FxGripParticleSpreadTangent(double spreadAngle);

#ifdef __cplusplus
}
#endif

#endif /* FxGripParticleRand_h */
