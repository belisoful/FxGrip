/*!
	@file       FxGripPhysicsSimulationStore.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripPhysicsSimulationStore
	@abstract   The per-step store seam for the deterministic physics simulation, with two backings.
	@discussion Introduced in FxGrip 0.1.0. This file declares the store protocol the physics backend
	            memoizes steps into, and two implementations: an in-memory session cache and an
	            FxGripFrameData-backed store that persists the bake with the document.
*/

#ifndef FxGripPhysicsSimulationStore_h
#define FxGripPhysicsSimulationStore_h

#import <Foundation/Foundation.h>

@class FxGripFrameData;

NS_ASSUME_NONNULL_BEGIN

/*!
	@protocol   FxGripPhysicsSimulationStore
	@abstract   A per-step store of physics-body transforms for the deterministic simulation.
	@discussion Introduced in FxGrip 0.1.0. The physics backend memoizes each simulated step's body
				transforms here, keyed by step index, and replays them instead of re-simulating. One
				record is a map of body node name to the 16-float `simd_float4x4` transform packed as
				`NSData`. The seam lets the same backend cache to memory for a session or to an
				`FxGripFrameData` that persists with the document.

				A signature captures the simulation's identity (bodies, gravity, time step, initial
				conditions). `invalidateIfSignatureChanged:` clears the store when it differs, so a
				changed scene never replays a stale pose.
*/
@protocol FxGripPhysicsSimulationStore <NSObject>

/*! The stored body transforms at a step index, or nil on a miss. */
- (nullable NSDictionary<NSString *, NSData *> *)transformsForStep:(NSInteger)stepIndex;

/*! Stores the body transforms at a step index. */
- (void)setTransforms:(NSDictionary<NSString *, NSData *> *)transforms forStep:(NSInteger)stepIndex;

/*! Removes every stored step. */
- (void)invalidate;

/*! Clears the store when `signature` differs from the stored one, then records `signature`. */
- (void)invalidateIfSignatureChanged:(NSString *)signature;

@end

/*! A thread-safe in-memory store: the session cache that does not persist. */
@interface FxGripPhysicsMemoryStore : NSObject <FxGripPhysicsSimulationStore>
@end

/*! A store backed by an `FxGripFrameData`, so the bake persists with the host document. */
@interface FxGripPhysicsFrameDataStore : NSObject <FxGripPhysicsSimulationStore>
/*! A store that reads and writes steps through `frameData`. */
- (instancetype)initWithFrameData:(FxGripFrameData *)frameData;
/*! The backing frame data the store persists steps into. */
@property (nonatomic, readonly, strong) FxGripFrameData *frameData;
@end

NS_ASSUME_NONNULL_END

#endif /* FxGripPhysicsSimulationStore_h */
