/*!
	@file       SCNParticleSystem+FxGripInteraction.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-08
	@header     SCNParticleSystem+FxGripInteraction
	@abstract   Adds an inter-particle force to any SCNParticleSystem.
	@discussion Introduced in FxGrip 0.1.0. SceneKit particles respond to fields and colliders but
	            never to each other. This category installs a force between the particles of one
	            system, evaluated in O(N) by the Fast Multipole Method. Setting `particleInteraction`
	            with an enabled configuration installs a pre-dynamics modifier that, each step, gathers
	            the particles, evaluates the force, and adds the resulting acceleration to their
	            velocity. Setting a disabled configuration or nil removes it.

	            The force reads the system's `particleMass` and `particleCharge` as the per-particle
	            mass and charge, since SceneKit holds those as system constants. Gravity uses the mass,
	            electric and magnetic use the charge and velocity.

	            The modifier is installed at the pre-dynamics stage, which the interaction reserves;
	            adding other pre-dynamics modifiers to a system that carries an interaction is not
	            supported, because removal clears the stage. This is a deliberate use of a direct
	            property name on an Apple class, per the project's decision to waive that rule for the
	            particle interaction API.
*/

#ifndef SCNParticleSystem_FxGripInteraction_h
#define SCNParticleSystem_FxGripInteraction_h

#import <SceneKit/SceneKit.h>
#import "FxGripParticleInteraction.h"

NS_ASSUME_NONNULL_BEGIN

@interface SCNParticleSystem (FxGripInteraction)

/*!
	@property   particleInteraction
	@abstract   The inter-particle force applied to this system, or nil for none.
	@discussion Introduced in FxGrip 0.1.0. Setting an enabled interaction installs the force; setting
	            a disabled one or nil removes it. The value is copied.
*/
@property (nonatomic, copy, nullable) FxGripParticleInteraction *particleInteraction;

/*!
	@property   boundInteractionField
	@abstract   The interaction physics field this system feeds, or nil when it feeds none.
	@discussion Introduced in FxGrip 0.1.0. Set by `bindParticleInteractionToParticleSystem:` on
	            SCNPhysicsField. A system bound to a field already carries a force at the pre-dynamics
	            stage, so the scene-wide reconciliation skips it.
*/
@property (nonatomic, readonly, weak, nullable) SCNPhysicsField *boundInteractionField;

@end

NS_ASSUME_NONNULL_END

#endif /* SCNParticleSystem_FxGripInteraction_h */
