/*!
	@file       FxGripParticleInteraction.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-08
	@header     FxGripParticleInteraction
	@abstract   The configuration of an inter-particle force applied to an SCNParticleSystem.
	@discussion Introduced in FxGrip 0.1.0. SceneKit computes no force between particles. This value
	            object describes the mutual force a particle system exerts on itself: which forces are
	            active, how strong each is, the softening that bounds the near force, and the accuracy
	            tier that sets the multipole order. It is applied through the SCNParticleSystem
	            FxGripInteraction category, which evaluates the force in O(N) with the Fast Multipole
	            Method.

	            The forces are a bit field, so they combine. Gravity and electric share one field
	            evaluation and differ only in their coupling; magnetic adds the Biot-Savart term, so
	            setting electric and magnetic together is the Lorentz force.
*/

#ifndef FxGripParticleInteraction_h
#define FxGripParticleInteraction_h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/*!
	@enum       FxGripParticleInteractionKind
	@abstract   The active forces, combinable as a bit field.
	@constant   FxGripParticleInteractionKindNone      No inter-particle force.
	@constant   FxGripParticleInteractionKindGravity   Mutual gravity, attractive.
	@constant   FxGripParticleInteractionKindElectric  Coulomb force, repulsive between like charges.
	@constant   FxGripParticleInteractionKindMagnetic  The magnetic force of moving charges.
*/
typedef NS_OPTIONS(NSUInteger, FxGripParticleInteractionKind) {
	FxGripParticleInteractionKindNone     = 0,
	FxGripParticleInteractionKindGravity  = 1u << 0,
	FxGripParticleInteractionKindElectric = 1u << 1,
	FxGripParticleInteractionKindMagnetic = 1u << 2,
};

/*!
	@enum       FxGripParticleInteractionAccuracy
	@abstract   The accuracy tier, which sets the multipole order and acceptance ratio.
	@constant   FxGripParticleInteractionAccuracyDraft     Order 2, the fastest and least accurate.
	@constant   FxGripParticleInteractionAccuracyStandard  Order 4, the default balance.
	@constant   FxGripParticleInteractionAccuracyFine      Order 6, the most accurate and slowest.
*/
typedef NS_ENUM(NSInteger, FxGripParticleInteractionAccuracy) {
	FxGripParticleInteractionAccuracyDraft = 0,
	FxGripParticleInteractionAccuracyStandard,
	FxGripParticleInteractionAccuracyFine,
};

/*!
	@class      FxGripParticleInteraction
	@abstract   A mutable description of a particle system's inter-particle force.
	@discussion Introduced in FxGrip 0.1.0. Archive it with the system that carries it, or set it
	            directly on the system each render. The `enabled` flag is the on/off state used by the
	            reconciliation that installs or removes the force.
*/
@interface FxGripParticleInteraction : NSObject <NSSecureCoding, NSCopying>

/*! Whether the force is active. Defaults to NO. */
@property (nonatomic, assign) BOOL enabled;

/*! Which forces are active. Defaults to none. */
@property (nonatomic, assign) FxGripParticleInteractionKind kind;

/*! The gravitational constant G. Defaults to 1. */
@property (nonatomic, assign) CGFloat gravityStrength;

/*! The electric constant k. Defaults to 1. */
@property (nonatomic, assign) CGFloat electricStrength;

/*! The magnetic constant. Defaults to 1. */
@property (nonatomic, assign) CGFloat magneticStrength;

/*! The softening length ε, in world units, that bounds the near force. Defaults to 0.01. */
@property (nonatomic, assign) CGFloat softening;

/*! The accuracy tier. Defaults to Standard. */
@property (nonatomic, assign) FxGripParticleInteractionAccuracy accuracy;

/*! A convenience for an enabled gravity interaction of the given strength. */
+ (instancetype)gravityWithStrength:(CGFloat)strength;

/*! The multipole order for the accuracy tier: 2, 4, or 6. */
@property (nonatomic, readonly) uint32_t expansionOrder;

/*! The multipole acceptance ratio for the accuracy tier. */
@property (nonatomic, readonly) float theta;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripParticleInteraction_h */
