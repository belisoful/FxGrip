/*!
	@file       FxGripInteractionFieldState.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-09
	@header     FxGripInteractionFieldState
	@abstract   The shared source expansion behind a particle interaction physics field.
	@discussion Introduced in FxGrip 0.1.0. A custom SCNPhysicsField evaluator sees one target at a
	            time and has no reference to the particle collection, so it cannot compute an
	            inter-particle force on its own. This object is the link between the two halves of the
	            facade: a companion particle modifier records each bound system's particles here, and
	            the field evaluator queries the expansion built from them.

	            Several systems may feed one field. SceneKit runs every particle modifier before any
	            field evaluation within a step, so the expansion is rebuilt lazily at the first query
	            of a step, by which time every bound system has reported. Sources are concatenated in
	            bind order, which keeps the summation order, and therefore the result, reproducible.

	            The state is private to the framework. It is attached to the physics field as an
	            associated object, so the field and its companion modifiers share one expansion.
*/

#ifndef FxGripInteractionFieldState_h
#define FxGripInteractionFieldState_h

#import <Foundation/Foundation.h>
#import <SceneKit/SceneKit.h>
#import <simd/simd.h>
#import "FxGripParticleInteraction.h"

NS_ASSUME_NONNULL_BEGIN

/*!
	@class      FxGripInteractionFieldState
	@abstract   The built source field a particle interaction physics field evaluates.
	@discussion Introduced in FxGrip 0.1.0. Record each system's particles once per step, then query
	            the acceleration at any number of target points. A rebuild retires the previous
	            expansion for one generation before freeing it, so a query that overlaps the next
	            rebuild still reads live memory.
*/
@interface FxGripInteractionFieldState : NSObject

/*! @abstract Creates a state for the given configuration, which it copies. */
- (instancetype)initWithInteraction:(FxGripParticleInteraction *)interaction NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

/*! @abstract The force configuration. A rebuild snapshots it. */
@property (nonatomic, copy) FxGripParticleInteraction *interaction;

/*!
	@property   boundSystems
	@abstract   The particle systems supplying this field's sources, in bind order.
	@discussion Introduced in FxGrip 0.1.0. A system takes its place when it is bound, not when it
	            first reports particles, so the order does not depend on which order SceneKit happens
	            to run the modifiers in. It is the order sources are concatenated in, so it decides the
	            summation order and therefore the exact result. A system that has been deallocated
	            drops out.
*/
@property (nonatomic, readonly, copy) NSArray<SCNParticleSystem *> *boundSystems;

/*! @abstract Gives a system its place in the bind order, before it has reported any particles. */
- (void)addSourceSystem:(SCNParticleSystem *)system;

/*!
	@method     setSourcesForSystem:count:positions:positionStride:velocities:velocityStride:mass:charge:
	@abstract   Records one system's particles as sources for the next rebuild.
	@param      system           The system these particles belong to. Held weakly.
	@param      count            The number of particles.
	@param      positions        The base address of the particle positions.
	@param      positionStride   The byte stride between consecutive positions.
	@param      velocities       The base address of the velocities, needed only for magnetic.
	@param      velocityStride   The byte stride between consecutive velocities.
	@param      mass             The system's particle mass.
	@param      charge           The system's particle charge.
	@result     YES when the sources are recorded.
	@discussion Introduced in FxGrip 0.1.0. Each position and velocity is read as three floats at the
	            given stride, which is how SceneKit reports its particle property buffers. Recording
	            marks the expansion stale; the next query rebuilds it. Per-system buffers grow
	            monotonically, so a step at a count already seen allocates no gather memory.
*/
- (BOOL)setSourcesForSystem:(SCNParticleSystem *)system
					  count:(uint32_t)count
				  positions:(const void *)positions
			 positionStride:(size_t)positionStride
				 velocities:(nullable const void *)velocities
			 velocityStride:(size_t)velocityStride
					   mass:(float)mass
					 charge:(float)charge;

/*! @abstract Drops a system's sources and its place in the bind order. */
- (void)removeSourcesForSystem:(SCNParticleSystem *)system;

/*!
	@method     accelerationAtPosition:velocity:mass:charge:
	@abstract   The acceleration the recorded sources impose on one target.
	@discussion Introduced in FxGrip 0.1.0. Returns zero while no sources are recorded. The result is
	            an acceleration, not a force, because SceneKit applies a custom field's vector to a
	            particle without dividing by the particle mass.
*/
- (simd_float3)accelerationAtPosition:(simd_float3)position
							 velocity:(simd_float3)velocity
								 mass:(float)mass
							   charge:(float)charge;

/*! @abstract The state attached to a particle interaction field, or nil for any other field. */
+ (nullable FxGripInteractionFieldState *)stateForPhysicsField:(SCNPhysicsField *)field;

/*! @abstract Attaches a state to a physics field. Passing nil detaches it. */
+ (void)setState:(nullable FxGripInteractionFieldState *)state forPhysicsField:(SCNPhysicsField *)field;

@end

/*!
	@category   SCNParticleSystem (FxGripInteractionFieldBinding)
	@abstract   The framework-internal setter behind the system's read-only `boundInteractionField`.
	@discussion Introduced in FxGrip 0.1.0. Binding a system to an interaction field records the field
	            on the system, so the scene-wide reconciliation leaves that system alone rather than
	            installing a second force at the same modifier stage.
*/
@interface SCNParticleSystem (FxGripInteractionFieldBinding)
- (void)fxgrip_setBoundInteractionField:(nullable SCNPhysicsField *)field;
@end

NS_ASSUME_NONNULL_END

#endif /* FxGripInteractionFieldState_h */
