/*!
	@file       SCNScene+FxGripInteraction.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-09
	@header     SCNScene+FxGripInteraction
	@abstract   Implements the scene-wide default force and the reconciliation.
	@discussion Introduced in FxGrip 0.1.0. The default is held as an associated object. The
	            reconciliation enumerates the scene graph and, for each system without its own
	            interaction, sets the scene default on it, which installs the force through the
	            SCNParticleSystem category.
*/

#import "SCNScene+FxGripInteraction.h"
#import "SCNParticleSystem+FxGripInteraction.h"
#import <objc/runtime.h>

static const void *kSceneInteractionKey = &kSceneInteractionKey;

@implementation SCNScene (FxGripInteraction)

- (FxGripParticleInteraction *)particleInteraction
{
	return objc_getAssociatedObject(self, kSceneInteractionKey);
}

- (void)setParticleInteraction:(FxGripParticleInteraction *)interaction
{
	objc_setAssociatedObject(self, kSceneInteractionKey, [interaction copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)fxgrip_reconcileParticleInteractions
{
	FxGripParticleInteraction *sceneDefault = self.particleInteraction;
	if (sceneDefault == nil) {
		return;
	}
	void (^applyToNode)(SCNNode *) = ^(SCNNode *node) {
		for (SCNParticleSystem *system in node.particleSystems) {
			// A system bound to an interaction field already carries a force at the pre-dynamics
			// stage, which the default would displace.
			if (system.particleInteraction == nil && system.boundInteractionField == nil) {
				system.particleInteraction = sceneDefault;
			}
		}
	};
	// enumerateChildNodesUsingBlock: visits descendants but not the root, so handle the root itself too.
	applyToNode(self.rootNode);
	[self.rootNode enumerateChildNodesUsingBlock:^(SCNNode *node, BOOL *stop) {
		applyToNode(node);
	}];
}

@end
