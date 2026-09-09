/*!
	@file       FxGripInteractionFieldState.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-09
	@header     FxGripInteractionFieldState
	@abstract   Implements the shared source expansion behind a particle interaction physics field.
	@discussion Introduced in FxGrip 0.1.0. Each bound system keeps a slot of gathered positions and
	            velocities. A rebuild concatenates the live slots, derives one strength channel per
	            active force, and hands them to the FMM, which returns a field queryable at any point.
	            One tree carries every channel, so the magnetic force costs three more channels rather
	            than three more trees.
*/

#import "FxGripInteractionFieldState.h"
#import "FxGripFMM.h"
#import <objc/runtime.h>
#import <os/lock.h>

// Where each force's strength channel sits in the built field, or -1 when that force is inactive.
// Magnetic occupies three consecutive channels, the velocity-weighted charge per axis.
typedef struct FxGripInteractionChannelLayout {
	int gravity;
	int electric;
	int magnetic;
	uint32_t count;
} FxGripInteractionChannelLayout;

static FxGripInteractionChannelLayout FxGripInteractionLayoutForKind(FxGripParticleInteractionKind kind, BOOL hasCharge)
{
	FxGripInteractionChannelLayout layout = { -1, -1, -1, 0 };
	if (kind & FxGripParticleInteractionKindGravity) {
		layout.gravity = (int)layout.count++;
	}
	if ((kind & FxGripParticleInteractionKindElectric) && hasCharge) {
		layout.electric = (int)layout.count++;
	}
	if ((kind & FxGripParticleInteractionKindMagnetic) && hasCharge) {
		layout.magnetic = (int)layout.count;
		layout.count += 3;
	}
	return layout;
}

// One generation of the built expansion, together with the constants a query folds in.
typedef struct FxGripInteractionFieldSet {
	FxGripFMMField *field;
	FxGripInteractionChannelLayout layout;
	float gravityStrength;
	float electricStrength;
	float magneticStrength;
} FxGripInteractionFieldSet;

static void FxGripInteractionFieldSetDestroy(FxGripInteractionFieldSet *set)
{
	FxGripFMMFieldDestroy(set->field);
	*set = (FxGripInteractionFieldSet){ 0 };
}

#pragma mark Per-system slot

// One bound system's gathered particles. Buffers grow monotonically, so a step at a count already
// seen allocates nothing.
@interface FxGripInteractionSourceSlot : NSObject
@end

@implementation FxGripInteractionSourceSlot
{
	@public
	__weak SCNParticleSystem *_system;
	float *_x; float *_y; float *_z;
	float *_vx; float *_vy; float *_vz;
	float _mass;
	float _charge;
	uint32_t _count;
	uint32_t _capacity;
}

- (BOOL)ensureCapacity:(uint32_t)count
{
	if (count <= _capacity) {
		return YES;
	}
	float **buffers[6] = { &_x, &_y, &_z, &_vx, &_vy, &_vz };
	for (int i = 0; i < 6; i++) {
		float *grown = (float *)realloc(*buffers[i], sizeof(float) * count);
		if (grown == NULL) {
			return NO;
		}
		*buffers[i] = grown;
	}
	_capacity = count;
	return YES;
}

- (void)dealloc
{
	free(_x); free(_y); free(_z);
	free(_vx); free(_vy); free(_vz);
}

@end

#pragma mark State

static const void *kFieldStateKey = &kFieldStateKey;

@implementation FxGripInteractionFieldState
{
	FxGripFMMContext *_context;
	// Bind order, not a hash order: the concatenation order decides the summation order, and the
	// result must reproduce.
	NSMutableArray<FxGripInteractionSourceSlot *> *_slots;
	float *_x; float *_y; float *_z;
	float *_channels[5];
	uint32_t _capacity;
	BOOL _stale;
	FxGripInteractionFieldSet _current;
	FxGripInteractionFieldSet _retired;
	os_unfair_lock _lock;
}

- (instancetype)initWithInteraction:(FxGripParticleInteraction *)interaction
{
	self = [super init];
	if (self != nil) {
		_interaction = [interaction copy];
		_context = FxGripFMMContextCreate();
		_slots = [NSMutableArray array];
		_lock = OS_UNFAIR_LOCK_INIT;
	}
	return self;
}

- (void)dealloc
{
	FxGripInteractionFieldSetDestroy(&_current);
	FxGripInteractionFieldSetDestroy(&_retired);
	FxGripFMMContextDestroy(_context);
	free(_x); free(_y); free(_z);
	for (int c = 0; c < 5; c++) {
		free(_channels[c]);
	}
}

- (NSArray<SCNParticleSystem *> *)boundSystems
{
	NSMutableArray<SCNParticleSystem *> *systems = [NSMutableArray array];
	os_unfair_lock_lock(&_lock);
	for (FxGripInteractionSourceSlot *slot in _slots) {
		SCNParticleSystem *system = slot->_system;
		if (system != nil) {
			[systems addObject:system];
		}
	}
	os_unfair_lock_unlock(&_lock);
	return systems;
}

#pragma mark Recording sources

// The slot for a system, appended in bind order when it has none yet.
- (FxGripInteractionSourceSlot *)slotForSystem:(SCNParticleSystem *)system
{
	for (FxGripInteractionSourceSlot *slot in _slots) {
		if (slot->_system == system) {
			return slot;
		}
	}
	FxGripInteractionSourceSlot *slot = [FxGripInteractionSourceSlot.alloc init];
	slot->_system = system;
	[_slots addObject:slot];
	return slot;
}

- (void)addSourceSystem:(SCNParticleSystem *)system
{
	if (system == nil) {
		return;
	}
	os_unfair_lock_lock(&_lock);
	[self slotForSystem:system];
	os_unfair_lock_unlock(&_lock);
}

- (BOOL)setSourcesForSystem:(SCNParticleSystem *)system
					  count:(uint32_t)count
				  positions:(const void *)positions
			 positionStride:(size_t)positionStride
				 velocities:(const void *)velocities
			 velocityStride:(size_t)velocityStride
					   mass:(float)mass
					 charge:(float)charge
{
	if (system == nil || positions == NULL) {
		return NO;
	}
	os_unfair_lock_lock(&_lock);
	FxGripInteractionSourceSlot *slot = [self slotForSystem:system];
	BOOL ok = [slot ensureCapacity:count];
	if (ok) {
		for (uint32_t i = 0; i < count; i++) {
			const float *p = (const float *)((uintptr_t)positions + positionStride * (size_t)i);
			slot->_x[i] = p[0]; slot->_y[i] = p[1]; slot->_z[i] = p[2];
		}
		if (velocities != NULL) {
			for (uint32_t i = 0; i < count; i++) {
				const float *v = (const float *)((uintptr_t)velocities + velocityStride * (size_t)i);
				slot->_vx[i] = v[0]; slot->_vy[i] = v[1]; slot->_vz[i] = v[2];
			}
		} else {
			memset(slot->_vx, 0, sizeof(float) * count);
			memset(slot->_vy, 0, sizeof(float) * count);
			memset(slot->_vz, 0, sizeof(float) * count);
		}
		slot->_count = count;
		slot->_mass = mass;
		slot->_charge = charge;
		_stale = YES;
	}
	os_unfair_lock_unlock(&_lock);
	return ok;
}

- (void)removeSourcesForSystem:(SCNParticleSystem *)system
{
	os_unfair_lock_lock(&_lock);
	NSUInteger index = [_slots indexOfObjectPassingTest:^BOOL(FxGripInteractionSourceSlot *slot, NSUInteger idx, BOOL *stop) {
		return slot->_system == system;
	}];
	if (index != NSNotFound) {
		[_slots removeObjectAtIndex:index];
		_stale = YES;
	}
	os_unfair_lock_unlock(&_lock);
}

#pragma mark Rebuild

- (BOOL)ensureCombinedCapacity:(uint32_t)count channels:(uint32_t)channelCount
{
	if (count <= _capacity) {
		return YES;
	}
	float **buffers[3] = { &_x, &_y, &_z };
	for (int i = 0; i < 3; i++) {
		float *grown = (float *)realloc(*buffers[i], sizeof(float) * count);
		if (grown == NULL) {
			return NO;
		}
		*buffers[i] = grown;
	}
	// Every channel is grown, not only the active ones, so a later change of kind finds them sized.
	for (int c = 0; c < 5; c++) {
		float *grown = (float *)realloc(_channels[c], sizeof(float) * count);
		if (grown == NULL) {
			return NO;
		}
		_channels[c] = grown;
	}
	_capacity = count;
	return YES;
}

// Concatenates the live slots and rebuilds the expansion. Runs under the lock.
- (void)rebuildLocked
{
	_stale = NO;
	FxGripParticleInteraction *config = self.interaction;
	FxGripInteractionFieldSet built = { 0 };
	if (config == nil || _context == NULL) {
		[self installLocked:built];
		return;
	}

	// A slot whose system has gone away contributes nothing and is dropped.
	NSIndexSet *dead = [_slots indexesOfObjectsPassingTest:^BOOL(FxGripInteractionSourceSlot *slot, NSUInteger idx, BOOL *stop) {
		return slot->_system == nil;
	}];
	[_slots removeObjectsAtIndexes:dead];

	uint32_t total = 0;
	BOOL hasCharge = NO;
	for (FxGripInteractionSourceSlot *slot in _slots) {
		total += slot->_count;
		hasCharge = hasCharge || slot->_charge != 0.0f;
	}
	const FxGripInteractionChannelLayout layout = FxGripInteractionLayoutForKind(config.kind, hasCharge);
	if (total == 0 || layout.count == 0 || ![self ensureCombinedCapacity:total channels:layout.count]) {
		[self installLocked:built];
		return;
	}

	uint32_t offset = 0;
	for (FxGripInteractionSourceSlot *slot in _slots) {
		const uint32_t n = slot->_count;
		memcpy(_x + offset, slot->_x, sizeof(float) * n);
		memcpy(_y + offset, slot->_y, sizeof(float) * n);
		memcpy(_z + offset, slot->_z, sizeof(float) * n);
		if (layout.gravity >= 0) {
			float *g = _channels[layout.gravity] + offset;
			for (uint32_t i = 0; i < n; i++) { g[i] = slot->_mass; }
		}
		if (layout.electric >= 0) {
			float *e = _channels[layout.electric] + offset;
			for (uint32_t i = 0; i < n; i++) { e[i] = slot->_charge; }
		}
		if (layout.magnetic >= 0) {
			float *mx = _channels[layout.magnetic] + offset;
			float *my = _channels[layout.magnetic + 1] + offset;
			float *mz = _channels[layout.magnetic + 2] + offset;
			for (uint32_t i = 0; i < n; i++) {
				mx[i] = slot->_charge * slot->_vx[i];
				my[i] = slot->_charge * slot->_vy[i];
				mz[i] = slot->_charge * slot->_vz[i];
			}
		}
		offset += n;
	}

	FxGripFMMParameters parameters = FxGripFMMDefaultParameters();
	parameters.expansionOrder = config.expansionOrder;
	parameters.theta = config.theta;
	parameters.softening = (float)config.softening;

	const float *strengths[5];
	for (uint32_t c = 0; c < layout.count; c++) {
		strengths[c] = _channels[c];
	}
	built.field = FxGripFMMFieldBuildChannels(_context, &parameters, total, _x, _y, _z, strengths, layout.count);
	built.layout = layout;
	built.gravityStrength = (float)config.gravityStrength;
	built.electricStrength = (float)config.electricStrength;
	built.magneticStrength = (float)config.magneticStrength;
	[self installLocked:built];
}

// Swaps in a new generation and frees the one retired before it, so a query in flight against the
// generation being replaced still reads live memory.
- (void)installLocked:(FxGripInteractionFieldSet)built
{
	FxGripInteractionFieldSet retiring = _retired;
	_retired = _current;
	_current = built;
	FxGripInteractionFieldSetDestroy(&retiring);
}

#pragma mark Query

- (simd_float3)accelerationAtPosition:(simd_float3)position
							 velocity:(simd_float3)velocity
								 mass:(float)mass
							   charge:(float)charge
{
	os_unfair_lock_lock(&_lock);
	if (_stale) {
		[self rebuildLocked];
	}
	const FxGripInteractionFieldSet set = _current;
	os_unfair_lock_unlock(&_lock);
	if (set.field == NULL) {
		return simd_make_float3(0.0f, 0.0f, 0.0f);
	}
	const float receiverMass = mass > 0.0f ? mass : 1.0f;
	float ex[5] = { 0.0f }, ey[5] = { 0.0f }, ez[5] = { 0.0f };
	FxGripFMMFieldEvaluateChannelsAt(set.field, position.x, position.y, position.z, ex, ey, ez);

	simd_float3 acceleration = simd_make_float3(0.0f, 0.0f, 0.0f);
	if (set.layout.gravity >= 0) {
		const int g = set.layout.gravity;
		acceleration += set.gravityStrength * simd_make_float3(ex[g], ey[g], ez[g]);
	}
	if (set.layout.electric >= 0 && charge != 0.0f) {
		const int e = set.layout.electric;
		acceleration -= (set.electricStrength * charge / receiverMass) * simd_make_float3(ex[e], ey[e], ez[e]);
	}
	if (set.layout.magnetic >= 0 && charge != 0.0f) {
		const int m = set.layout.magnetic;
		// B = ∇ × F, where F's components are the three potentials just differentiated.
		const simd_float3 B = simd_make_float3(ey[m + 2] - ez[m + 1],
											   ez[m + 0] - ex[m + 2],
											   ex[m + 1] - ey[m + 0]);
		acceleration += (set.magneticStrength * charge / receiverMass) * simd_cross(velocity, B);
	}
	return acceleration;
}

#pragma mark Attachment

+ (FxGripInteractionFieldState *)stateForPhysicsField:(SCNPhysicsField *)field
{
	return objc_getAssociatedObject(field, kFieldStateKey);
}

+ (void)setState:(FxGripInteractionFieldState *)state forPhysicsField:(SCNPhysicsField *)field
{
	objc_setAssociatedObject(field, kFieldStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
