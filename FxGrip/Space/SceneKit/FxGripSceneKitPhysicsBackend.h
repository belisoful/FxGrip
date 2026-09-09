/*!
	@file       FxGripSceneKitPhysicsBackend.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripSceneKitPhysicsBackend
	@abstract   A space backend that advances SceneKit physics deterministically by fixed-step catch-up.
	@discussion Introduced in FxGrip 0.1.0. This file declares the physics backend, its fixed-step
	            parameters, and the simulation-mode enum that selects catch-up recompute or a memoized
	            session cache.
*/

#ifndef FxGripSceneKitPhysicsBackend_h
#define FxGripSceneKitPhysicsBackend_h

#import "FxGripSceneKitMetalBackend.h"
#import "FxGripPhysicsSimulationStore.h"

NS_ASSUME_NONNULL_BEGIN

/*! How the physics backend supplies each frame's simulated state. */
typedef NS_ENUM(NSInteger, FxGripPhysicsSimulationMode) {
	/*! Catch-up simulate from the start to the frame on every render. Deterministic, no storage. */
	FxGripPhysicsSimulationModeRecompute = 0,
	/*! Memoize each simulated step's body transforms and replay them on a later render of the same
		or an earlier step, so the simulation runs once per step for the session. */
	FxGripPhysicsSimulationModeSessionCache = 1,
};

/*!
	@class      FxGripSceneKitPhysicsBackend
	@abstract   An `FxGripSceneKitMetalBackend` that advances SceneKit physics deterministically by
				fixed-step catch-up.
	@discussion Introduced in FxGrip 0.1.0. The host renders frames out of order and re-renders them,
				so a stateful simulation cannot step once per render. This backend instead simulates
				from `simulationStartTime` to the render time in fixed `timeStep` increments on the
				per-render scene's own physics world, so a given frame reproduces the same result in
				any order, with no stored state.

				The cost is one `updateAtTime:` call per step, so the whole simulation reruns for each
				frame. A later layer caches the result. Particle systems are not made deterministic
				this way, because `SCNParticleSystem` has no seed; a deterministic particle effect uses
				a stateless analytic emitter.
*/
@interface FxGripSceneKitPhysicsBackend : FxGripSceneKitMetalBackend

/*! The time, in seconds, the simulation starts from. Defaults to 0. */
@property (nonatomic, assign) CFTimeInterval simulationStartTime;

/*! The fixed physics step, in seconds. Defaults to 1/60. A smaller step is more accurate and more
	costly; a fixed value keeps the result reproducible. Changing it clears the cache. */
@property (nonatomic, assign) CFTimeInterval timeStep;

/*! How simulated state is supplied. Defaults to `FxGripPhysicsSimulationModeRecompute`. */
@property (nonatomic, assign) FxGripPhysicsSimulationMode simulationMode;

/*! The store the session cache uses. Defaults to an in-memory `FxGripPhysicsMemoryStore`; the
	physics-bake extension swaps in an `FxGripFrameData`-backed store so the bake persists with the
	document. */
@property (nonatomic, strong) id<FxGripPhysicsSimulationStore> simulationStore;

/*! The count of physics steps taken, for tests and diagnostics. A cache hit adds none. */
@property (nonatomic, readonly) NSUInteger totalSimulationSteps;

/*!
	@method     resetSimulationCache
	@abstract   Clears the memoized trajectory.
	@discussion The session cache is keyed by step index and assumes a stable scene. A subclass or
				plugin calls this when the bodies, their initial conditions, or the world change, so a
				stale pose is not replayed. A later layer keys the cache by a simulation signature and
				invalidates automatically.
*/
- (void)resetSimulationCache;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripSceneKitPhysicsBackend_h */
