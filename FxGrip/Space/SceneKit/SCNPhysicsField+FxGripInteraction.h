/*!
	@file       SCNPhysicsField+FxGripInteraction.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-09
	@header     SCNPhysicsField+FxGripInteraction
	@abstract   An inter-particle force shaped as a SceneKit physics field.
	@discussion Introduced in FxGrip 0.1.0. SceneKit computes no force between particles, and a custom
	            physics field cannot supply one on its own: its evaluator receives a single target's
	            position, velocity, mass, charge, and time, with no reference to the particle
	            collection. The facade pairs the field with a companion modifier. The modifier gathers
	            every particle of a bound system once per step and builds the multipole expansion of
	            the sources; the field evaluator queries that expansion at each target point. Building
	            is O(N) and each query is a single tree walk.

	            Use it in two steps: create the field with
	            `particleInteractionFieldWithInteraction:`, assign it to a node's `physicsField`, and
	            bind each contributing particle system with
	            `bindParticleInteractionToParticleSystem:`. Binding sets `affectedByPhysicsFields` on
	            the system and installs the companion modifier at the pre-dynamics stage.

	            The field carries the standard `SCNPhysicsField` controls, so `halfExtent`, `scope`,
	            `categoryBitMask`, and `active` all apply. SceneKit also offers the field to rigid
	            bodies in range, and it divides the returned vector by a body's mass while applying it
	            to a particle unchanged. The vector is therefore the particle acceleration, and a rigid
	            body feels that vector divided by its own mass. Restrict the field with
	            `categoryBitMask` when only particles should respond.

	            The modifier gathers the source positions in the particle system's simulation space,
	            and the evaluator receives its target position in world space. A system simulates in
	            world space unless `local` is set, so leave `local` clear on a bound system.

	            The pre-dynamics stage is reserved for the companion modifier, so a bound system must
	            not carry other pre-dynamics modifiers, and must not also carry its own
	            `particleInteraction`, which would apply the force twice. The direct method names on an
	            Apple class are deliberate, per the project's decision to waive that rule for the
	            particle interaction API.
*/

#ifndef SCNPhysicsField_FxGripInteraction_h
#define SCNPhysicsField_FxGripInteraction_h

#import <SceneKit/SceneKit.h>
#import <FxGrip/FxGripParticleInteraction.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCNPhysicsField (FxGripInteraction)

/*!
	@method     particleInteractionFieldWithInteraction:
	@abstract   Creates a physics field that applies an inter-particle force.
	@param      interaction  The force configuration, which is copied.
	@result     A custom physics field, ready to assign to a node's `physicsField`.
	@discussion Introduced in FxGrip 0.1.0. The field is inert until at least one particle system is
	            bound to it, because the bound systems are the sources of the force. A disabled
	            interaction produces a field that evaluates to zero.
*/
+ (SCNPhysicsField *)particleInteractionFieldWithInteraction:(FxGripParticleInteraction *)interaction;

/*!
	@property   particleInteraction
	@abstract   The force configuration of a particle interaction field, or nil for any other field.
	@discussion Introduced in FxGrip 0.1.0. The returned value is a copy of the configuration the
	            field was created with.
*/
@property (nonatomic, readonly, copy, nullable) FxGripParticleInteraction *particleInteraction;

/*!
	@method     bindParticleInteractionToParticleSystem:
	@abstract   Makes a particle system both a source of and a responder to this field.
	@param      system  The particle system to bind.
	@result     YES when the system is bound; NO when the receiver is not a particle interaction field.
	@discussion Introduced in FxGrip 0.1.0. Installs the companion modifier that records the system's
	            particles each step, and sets `affectedByPhysicsFields` on the system so SceneKit
	            offers the field to its particles. Several systems may be bound to one field, and their
	            particles then attract or repel each other across systems. SceneKit runs every particle
	            modifier before any field evaluation within a step, so every bound system is current
	            when the field is queried.
*/
- (BOOL)bindParticleInteractionToParticleSystem:(SCNParticleSystem *)system;

/*!
	@method     bindParticleInteractionToParticleSystemsInNode:
	@abstract   Binds every particle system on a node and its descendants.
	@param      node  The root of the subtree to bind.
	@result     The number of systems bound.
	@discussion Introduced in FxGrip 0.1.0. This is the shape reconciliation uses: a field placed on a
	            node draws its sources from the emitters under that node, and a field on the scene's
	            root node draws from the whole scene. A system that carries its own
	            `particleInteraction` is skipped, since it already computes a force of its own.
*/
- (NSUInteger)bindParticleInteractionToParticleSystemsInNode:(SCNNode *)node;

/*!
	@method     unbindParticleInteractionFromParticleSystem:
	@abstract   Removes the companion modifier from a particle system.
	@discussion Introduced in FxGrip 0.1.0. Removal clears the pre-dynamics stage, which the
	            interaction reserves, drops the system's sources from the field, and clears the
	            system's `boundInteractionField`. The system keeps `affectedByPhysicsFields`, so clear
	            that separately when the system should stop responding to every field.
*/
- (void)unbindParticleInteractionFromParticleSystem:(SCNParticleSystem *)system;

@end

NS_ASSUME_NONNULL_END

#endif /* SCNPhysicsField_FxGripInteraction_h */
