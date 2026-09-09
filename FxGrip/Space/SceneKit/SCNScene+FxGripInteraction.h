/*!
	@file       SCNScene+FxGripInteraction.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-09
	@header     SCNScene+FxGripInteraction
	@abstract   A scene-wide default inter-particle force, and the reconciliation that applies it.
	@discussion Introduced in FxGrip 0.1.0. A scene may carry a default `particleInteraction` that
	            applies to every particle system in it that has no interaction of its own. The
	            reconciliation walks the scene and installs the effective force on each system: the
	            system's own interaction when it has one, otherwise the scene default.

	            The force is a modifier, and a modifier does not survive an archive or a copy, so the
	            reconciliation is meant to run once per render after the scene is built, which
	            reinstalls the force from the current configuration. In the FxGrip render model a fresh
	            scene is built for each frame, so the reconciliation always starts from clean systems.
*/

#ifndef SCNScene_FxGripInteraction_h
#define SCNScene_FxGripInteraction_h

#import <SceneKit/SceneKit.h>
#import <FxGrip/FxGripParticleInteraction.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCNScene (FxGripInteraction)

/*!
	@property   particleInteraction
	@abstract   The default inter-particle force for systems in this scene that lack their own.
	@discussion Introduced in FxGrip 0.1.0. The value is copied. It is a runtime default, applied by
	            `fxgrip_reconcileParticleInteractions`; it is not itself archived with the scene.
*/
@property (nonatomic, copy, nullable) FxGripParticleInteraction *particleInteraction;

/*!
	@method     fxgrip_reconcileParticleInteractions
	@abstract   Installs the effective inter-particle force on every particle system in the scene.
	@discussion Introduced in FxGrip 0.1.0. A system that already has its own `particleInteraction`
	            keeps it, and so does a system bound to an interaction physics field. A system with
	            neither receives the scene default, if the scene has one. Call it after the scene is
	            built and before it is rendered.
*/
- (void)fxgrip_reconcileParticleInteractions;

@end

NS_ASSUME_NONNULL_END

#endif /* SCNScene_FxGripInteraction_h */
