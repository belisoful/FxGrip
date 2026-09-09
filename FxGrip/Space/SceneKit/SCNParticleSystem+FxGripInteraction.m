/*!
	@file       SCNParticleSystem+FxGripInteraction.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-08
	@header     SCNParticleSystem+FxGripInteraction
	@abstract   Implements the inter-particle force modifier.
	@discussion Introduced in FxGrip 0.1.0. A private state object holds the FMM context and reusable
	            gather buffers, attached to the system as an associated object so the force is
	            allocation-free once warm. The pre-dynamics modifier gathers positions and velocities,
	            evaluates the softened field, folds the per-force coupling, and adds the acceleration to
	            the particle velocities.

	            Gravity and electric share one scalar field evaluation over a unit charge, since the
	            mass and charge are system constants: the combined coefficient is G·m − k·q²/m. Magnetic
	            adds a Biot-Savart evaluation, and the acceleration is (magnetic·q/m)·(v × B).
*/

#import "SCNParticleSystem+FxGripInteraction.h"
#import "FxGripInteractionFieldState.h"
#import "FxGripFMM.h"
#import <objc/runtime.h>
#import <simd/simd.h>

#pragma mark Per-system state

// Holds the FMM context and the gather buffers for one particle system. Buffers grow monotonically,
// so a warm step allocates nothing. Freed when the system is deallocated.
@interface FxGripInteractionState : NSObject
@end

@implementation FxGripInteractionState
{
	@public
	FxGripFMMContext *_context;
	float *_x; float *_y; float *_z;
	float *_vx; float *_vy; float *_vz;
	float *_q; float *_fx; float *_fy; float *_fz;
	uint32_t _capacity;
}

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		_context = FxGripFMMContextCreate();
	}
	return self;
}

- (BOOL)ensureCapacity:(uint32_t)n
{
	if (n <= _capacity) {
		return YES;
	}
	float **buffers[10] = { &_x, &_y, &_z, &_vx, &_vy, &_vz, &_q, &_fx, &_fy, &_fz };
	for (int i = 0; i < 10; i++) {
		float *grown = (float *)realloc(*buffers[i], sizeof(float) * n);
		if (grown == NULL) {
			return NO;
		}
		*buffers[i] = grown;
	}
	_capacity = n;
	return YES;
}

- (void)dealloc
{
	FxGripFMMContextDestroy(_context);
	free(_x); free(_y); free(_z);
	free(_vx); free(_vy); free(_vz);
	free(_q); free(_fx); free(_fy); free(_fz);
}

@end

// A weak reference an associated object can hold: associations are strong, assign, or copy, and an
// assign association to a deallocated field would dangle.
@interface FxGripWeakFieldBox : NSObject
@property (nonatomic, weak) SCNPhysicsField *field;
@end

@implementation FxGripWeakFieldBox
@end

#pragma mark Category

static const void *kInteractionKey = &kInteractionKey;
static const void *kStateKey = &kStateKey;
static const void *kInstalledKey = &kInstalledKey;
static const void *kBoundFieldKey = &kBoundFieldKey;

@implementation SCNParticleSystem (FxGripInteraction)

- (SCNPhysicsField *)boundInteractionField
{
	return [(FxGripWeakFieldBox *)objc_getAssociatedObject(self, kBoundFieldKey) field];
}

- (void)fxgrip_setBoundInteractionField:(SCNPhysicsField *)field
{
	FxGripWeakFieldBox *box = nil;
	if (field != nil) {
		box = [FxGripWeakFieldBox.alloc init];
		box.field = field;
	}
	objc_setAssociatedObject(self, kBoundFieldKey, box, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (FxGripParticleInteraction *)particleInteraction
{
	return objc_getAssociatedObject(self, kInteractionKey);
}

- (void)setParticleInteraction:(FxGripParticleInteraction *)interaction
{
	objc_setAssociatedObject(self, kInteractionKey, [interaction copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	[self fxgrip_reconcileInteraction];
}

// Installs or removes the modifier to match the configuration's enabled state.
- (void)fxgrip_reconcileInteraction
{
	FxGripParticleInteraction *config = self.particleInteraction;
	BOOL want = config != nil && config.enabled && config.kind != FxGripParticleInteractionKindNone;
	BOOL installed = [objc_getAssociatedObject(self, kInstalledKey) boolValue];
	if (want && !installed) {
		[self fxgrip_installInteractionModifier];
		objc_setAssociatedObject(self, kInstalledKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	} else if (!want && installed) {
		[self removeModifiersOfStage:SCNParticleModifierStagePreDynamics];
		objc_setAssociatedObject(self, kInstalledKey, @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
}

- (FxGripInteractionState *)fxgrip_interactionState
{
	FxGripInteractionState *state = objc_getAssociatedObject(self, kStateKey);
	if (state == nil) {
		state = [[FxGripInteractionState alloc] init];
		objc_setAssociatedObject(self, kStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	return state;
}

- (void)fxgrip_installInteractionModifier
{
	__weak SCNParticleSystem *weakSelf = self;
	[self addModifierForProperties:@[SCNParticlePropertyPosition, SCNParticlePropertyVelocity]
						   atStage:SCNParticleModifierStagePreDynamics
						 withBlock:^(void * _Nonnull * _Nonnull data, size_t * _Nonnull dataStride,
									 NSInteger start, NSInteger end, float deltaTime) {
		__strong SCNParticleSystem *system = weakSelf;
		if (system == nil || end <= start) {
			return;
		}
		FxGripParticleInteraction *config = system.particleInteraction;
		if (config == nil || !config.enabled || config.kind == FxGripParticleInteractionKindNone) {
			return;
		}
		const uint32_t n = (uint32_t)(end - start);
		FxGripInteractionState *state = [system fxgrip_interactionState];
		if (![state ensureCapacity:n]) {
			return;
		}

		// Gather positions and velocities from the strided property buffers.
		for (uint32_t i = 0; i < n; i++) {
			const float *p = (const float *)((uintptr_t)data[0] + dataStride[0] * (NSUInteger)i);
			const float *v = (const float *)((uintptr_t)data[1] + dataStride[1] * (NSUInteger)i);
			state->_x[i] = p[0]; state->_y[i] = p[1]; state->_z[i] = p[2];
			state->_vx[i] = v[0]; state->_vy[i] = v[1]; state->_vz[i] = v[2];
		}

		FxGripFMMParameters params = FxGripFMMDefaultParameters();
		params.expansionOrder = config.expansionOrder;
		params.theta = config.theta;
		params.softening = (float)config.softening;

		const double m = system.particleMass > 0.0 ? (double)system.particleMass : 1.0;
		const double q = (double)system.particleCharge;
		const FxGripParticleInteractionKind kind = config.kind;
		const float dt = deltaTime;

		double scalarCoeff = 0.0;
		if (kind & FxGripParticleInteractionKindGravity) {
			scalarCoeff += (double)config.gravityStrength * m;
		}
		if (kind & FxGripParticleInteractionKindElectric) {
			scalarCoeff -= (double)config.electricStrength * q * q / m;
		}

		if (scalarCoeff != 0.0) {
			for (uint32_t i = 0; i < n; i++) { state->_q[i] = 1.0f; }
			FxGripFMMEvaluateField(state->_context, &params, n, state->_x, state->_y, state->_z, state->_q,
								   state->_fx, state->_fy, state->_fz);
			const float c = (float)scalarCoeff * dt;
			for (uint32_t i = 0; i < n; i++) {
				float *v = (float *)((uintptr_t)data[1] + dataStride[1] * (NSUInteger)i);
				v[0] += c * state->_fx[i];
				v[1] += c * state->_fy[i];
				v[2] += c * state->_fz[i];
			}
		}

		if ((kind & FxGripParticleInteractionKindMagnetic) && q != 0.0 && config.magneticStrength != 0.0) {
			for (uint32_t i = 0; i < n; i++) { state->_q[i] = (float)q; }
			FxGripFMMEvaluateBiotSavart(state->_context, &params, n, state->_x, state->_y, state->_z, state->_q,
										state->_vx, state->_vy, state->_vz,
										state->_fx, state->_fy, state->_fz);
			const float c = (float)((double)config.magneticStrength * q / m) * dt;
			for (uint32_t i = 0; i < n; i++) {
				// a = c · (v × B), using the gathered velocity as the step's velocity.
				const simd_float3 vel = simd_make_float3(state->_vx[i], state->_vy[i], state->_vz[i]);
				const simd_float3 B = simd_make_float3(state->_fx[i], state->_fy[i], state->_fz[i]);
				const simd_float3 cross = simd_cross(vel, B);
				float *vout = (float *)((uintptr_t)data[1] + dataStride[1] * (NSUInteger)i);
				vout[0] += c * cross.x;
				vout[1] += c * cross.y;
				vout[2] += c * cross.z;
			}
		}
	}];
}

@end
