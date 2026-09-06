/*!
	@file       FxGripParticleSystem.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripParticleSystem
	@abstract   A deterministic SCNParticleSystem subclass for reproducible 3D Space renders.
	@discussion Introduced in FxGrip 0.1.0. The FxPlug host renders frames out of order and re-renders
	            them, so a particle system seeded by SceneKit's internal generator never reproduces a
	            frame. This file declares the subclass that neutralizes that generator and reintroduces
	            variation from a seeded, index-keyed function.
*/

#ifndef FxGripParticleSystem_h
#define FxGripParticleSystem_h

#import <SceneKit/SceneKit.h>

NS_ASSUME_NONNULL_BEGIN

/*!
	@class      FxGripParticleSystem
	@abstract   A deterministic drop-in replacement for `SCNParticleSystem`.
	@discussion Introduced in FxGrip 0.1.0. `SCNParticleSystem` seeds its per-particle variation from an
				internal generator with no seed control, so it does not reproduce a re-rendered or
				out-of-order frame. `FxGripParticleSystem` subclasses it, keeps the same property
				surface, and makes the result reproducible: it neutralizes SceneKit's stochastic
				variation and reintroduces variety from a seeded, computed function keyed by a
				per-particle birth index. With the `FxGripSceneKitPhysicsBackend` driving fixed-step
				`updateAtTime:`, the same `seed` yields the same frame every time.

				Use it wherever an `SCNParticleSystem` is expected. `initWithParticleSystem:` copies an
				existing system's properties, so an authored or loaded system becomes deterministic
				without rebuilding it.

				Velocity, size, life-span, color, angle, and spreading-angle variation are reimplemented
				as seeded jitter, so setting those properties gives reproducible variety. The remaining
				SceneKit variations (angular velocity, mass, bounce, friction, charge, intensity, and
				image-sequence timing) are neutralized.
*/
@interface FxGripParticleSystem : SCNParticleSystem

/*! The seed for the computed per-particle variation. The same seed reproduces the same simulation. */
@property (nonatomic, assign) uint32_t seed;

/*! A deterministic system that copies `system`'s properties. */
- (instancetype)initWithParticleSystem:(SCNParticleSystem *)system;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripParticleSystem_h */
