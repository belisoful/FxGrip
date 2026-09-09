/*!
	@file       SCNPhysicsField+FxGripInteraction.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-09
	@header     SCNPhysicsField+FxGripInteraction
	@abstract   Implements the inter-particle force as a SceneKit physics field.
	@discussion Introduced in FxGrip 0.1.0. The factory attaches a shared expansion state to a custom
	            field and closes the evaluator over it. Binding a particle system installs the
	            companion pre-dynamics modifier, which rebuilds that expansion from the live particles
	            each step. The modifier runs before any field evaluation within a step, so the
	            expansion the evaluator reads is the current one.
*/

#import "SCNPhysicsField+FxGripInteraction.h"
#import "FxGripInteractionFieldState.h"
#import "SCNParticleSystem+FxGripInteraction.h"
#import <simd/simd.h>

@implementation SCNPhysicsField (FxGripInteraction)

+ (SCNPhysicsField *)particleInteractionFieldWithInteraction:(FxGripParticleInteraction *)interaction
{
	FxGripInteractionFieldState *state = [FxGripInteractionFieldState.alloc initWithInteraction:interaction];
	SCNPhysicsField *field = [SCNPhysicsField customFieldWithEvaluationBlock:
		^SCNVector3(SCNVector3 position, SCNVector3 velocity, float mass, float charge, NSTimeInterval time) {
		const simd_float3 acceleration =
			[state accelerationAtPosition:simd_make_float3((float)position.x, (float)position.y, (float)position.z)
								 velocity:simd_make_float3((float)velocity.x, (float)velocity.y, (float)velocity.z)
									 mass:mass
								   charge:charge];
		return SCNVector3Make(acceleration.x, acceleration.y, acceleration.z);
	}];
	[FxGripInteractionFieldState setState:state forPhysicsField:field];
	return field;
}

- (FxGripParticleInteraction *)particleInteraction
{
	return [[FxGripInteractionFieldState stateForPhysicsField:self].interaction copy];
}

- (BOOL)bindParticleInteractionToParticleSystem:(SCNParticleSystem *)system
{
	FxGripInteractionFieldState *state = [FxGripInteractionFieldState stateForPhysicsField:self];
	if (state == nil || system == nil) {
		return NO;
	}
	SCNPhysicsField *previous = system.boundInteractionField;
	if (previous != nil && previous != self) {
		[previous unbindParticleInteractionFromParticleSystem:system];
	}
	[system fxgrip_setBoundInteractionField:self];
	// Take the slot now, so the concatenation order is the bind order rather than whichever order
	// SceneKit happens to run the modifiers in.
	[state addSourceSystem:system];
	system.affectedByPhysicsFields = YES;
	[system removeModifiersOfStage:SCNParticleModifierStagePreDynamics];

	__weak SCNParticleSystem *weakSystem = system;
	[system addModifierForProperties:@[SCNParticlePropertyPosition, SCNParticlePropertyVelocity]
							 atStage:SCNParticleModifierStagePreDynamics
						   withBlock:^(void * _Nonnull * _Nonnull data, size_t * _Nonnull dataStride,
									   NSInteger start, NSInteger end, float deltaTime) {
		__strong SCNParticleSystem *strongSystem = weakSystem;
		if (strongSystem == nil || end <= start) {
			return;
		}
		FxGripParticleInteraction *config = state.interaction;
		if (config == nil || !config.enabled || config.kind == FxGripParticleInteractionKindNone) {
			return;
		}
		const float mass = strongSystem.particleMass > 0.0 ? (float)strongSystem.particleMass : 1.0f;
		[state setSourcesForSystem:strongSystem
							 count:(uint32_t)(end - start)
						 positions:(const void *)((uintptr_t)data[0] + dataStride[0] * (size_t)start)
					positionStride:dataStride[0]
						velocities:(const void *)((uintptr_t)data[1] + dataStride[1] * (size_t)start)
					velocityStride:dataStride[1]
							  mass:mass
							charge:(float)strongSystem.particleCharge];
	}];
	return YES;
}

- (NSUInteger)bindParticleInteractionToParticleSystemsInNode:(SCNNode *)node
{
	if ([FxGripInteractionFieldState stateForPhysicsField:self] == nil || node == nil) {
		return 0;
	}
	__block NSUInteger bound = 0;
	SCNPhysicsField *field = self;
	void (^bindNode)(SCNNode *) = ^(SCNNode *visited) {
		for (SCNParticleSystem *system in visited.particleSystems) {
			if (system.particleInteraction != nil) {
				continue;
			}
			if ([field bindParticleInteractionToParticleSystem:system]) {
				bound += 1;
			}
		}
	};
	// enumerateChildNodesUsingBlock: visits descendants but not the root, so handle the root too.
	bindNode(node);
	[node enumerateChildNodesUsingBlock:^(SCNNode *child, BOOL *stop) {
		bindNode(child);
	}];
	return bound;
}

- (void)unbindParticleInteractionFromParticleSystem:(SCNParticleSystem *)system
{
	FxGripInteractionFieldState *state = [FxGripInteractionFieldState stateForPhysicsField:self];
	[state removeSourcesForSystem:system];
	if (system.boundInteractionField == self) {
		[system fxgrip_setBoundInteractionField:nil];
	}
	[system removeModifiersOfStage:SCNParticleModifierStagePreDynamics];
}

@end
