/*!
	@file       FxGripParticleSystem.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripParticleSystem
	@abstract   Implements the deterministic SCNParticleSystem subclass.
	@discussion Introduced in FxGrip 0.1.0. The variation setters capture each magnitude and hold the
	            live property's own generator at zero. A birth-event block then applies the captured
	            magnitudes through a hashed function keyed by a per-particle birth index, so the same
	            seed produces the same particles every render. The unreimplemented SceneKit variations
	            are set to zero so no other stochastic generator runs.
*/

#import "FxGripParticleSystem.h"
#import <simd/simd.h>
#import <objc/runtime.h>

// One reproducible value in [-1, 1] from a particle index, the seed, and a channel, so each varied
// property draws an independent stream.
static float FxGripParticleRand(uint32_t index, uint32_t seed, uint32_t channel)
{
	uint32_t h = index * 747796405u + seed * 2891336453u + (channel + 1u) * 2246822519u;
	h ^= h >> 16;
	h *= 2246822519u;
	h ^= h >> 13;
	h *= 3266489917u;
	h ^= h >> 16;
	return ((float)h / 2147483647.5f) - 1.0f;
}

static simd_float3 FxGripParticleRand3(uint32_t index, uint32_t seed, uint32_t channel)
{
	return simd_make_float3(FxGripParticleRand(index, seed, channel),
							FxGripParticleRand(index, seed, channel + 1),
							FxGripParticleRand(index, seed, channel + 2));
}

static float FxGripClamp01(float value)
{
	return value < 0.0f ? 0.0f : (value > 1.0f ? 1.0f : value);
}

/*!
	@abstract	A deterministic drop-in replacement for SCNParticleSystem.
	@discussion	Introduced in FxGrip 0.1.0. The initializer installs the seeded birth-event block and
				zeroes SceneKit's own variations. The captured magnitudes drive the block so the same
				seed reproduces the same particles.
*/
@implementation FxGripParticleSystem
{
	uint32_t _birthCounter;
	// Captured variation magnitudes, driven deterministically instead of by SceneKit's generator.
	CGFloat _velocityJitter;
	CGFloat _sizeJitter;
	CGFloat _lifeJitter;
	CGFloat _angleJitter;
	CGFloat _spreadAngle;
	SCNVector4 _colorJitter;
}

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		[self installSeededVariation];
		[self neutralizeSceneKitVariation];
	}
	return self;
}

/*!
	@method		initWithParticleSystem:
	@abstract	Creates a deterministic system that copies an existing system's properties.
	@param		system	The particle system whose writable properties are copied.
	@discussion	Introduced in FxGrip 0.1.0. */
- (instancetype)initWithParticleSystem:(SCNParticleSystem *)system
{
	self = [super init];
	if (self != nil) {
		[self copyPropertiesFromParticleSystem:system];
		[self installSeededVariation];
		[self neutralizeSceneKitVariation];
	}
	return self;
}

#pragma mark Drop-in mimicry

/*! @abstract Copies every writable, key-value coding compliant property from `system`. */
- (void)copyPropertiesFromParticleSystem:(SCNParticleSystem *)system
{
	unsigned int count = 0;
	objc_property_t *properties = class_copyPropertyList(SCNParticleSystem.class, &count);
	for (unsigned int i = 0; i < count; i++) {
		const char *attributes = property_getAttributes(properties[i]);
		if (attributes != NULL && strstr(attributes, ",R") != NULL) {
			continue; // readonly
		}
		NSString *name = @(property_getName(properties[i]));
		@try {
			[self setValue:[system valueForKey:name] forKey:name];
		} @catch (NSException *exception) {
			// A property that is not key-value coding compliant is skipped.
		}
	}
	free(properties);
}

#pragma mark Captured variation setters

// Each reimplemented variation is captured and the live property's own generator is kept off.

- (void)setParticleVelocityVariation:(CGFloat)variation
{
	_velocityJitter = variation;
	[super setParticleVelocityVariation:0.0];
}

- (void)setParticleSizeVariation:(CGFloat)variation
{
	_sizeJitter = variation;
	[super setParticleSizeVariation:0.0];
}

- (void)setParticleLifeSpanVariation:(CGFloat)variation
{
	_lifeJitter = variation;
	[super setParticleLifeSpanVariation:0.0];
}

- (void)setParticleAngleVariation:(CGFloat)variation
{
	_angleJitter = variation;
	[super setParticleAngleVariation:0.0];
}

- (void)setParticleColorVariation:(SCNVector4)variation
{
	_colorJitter = variation;
	[super setParticleColorVariation:SCNVector4Make(0.0, 0.0, 0.0, 0.0)];
}

- (void)setSpreadingAngle:(CGFloat)angle
{
	_spreadAngle = angle;
	[super setSpreadingAngle:0.0];
}

#pragma mark Determinism

/*! @abstract Zeroes the SceneKit variations that have no seeded reimplementation. */
- (void)neutralizeSceneKitVariation
{
	// Variations without a seeded reimplementation are dropped so no generator runs.
	self.emissionDurationVariation = 0.0;
	self.idleDurationVariation = 0.0;
	self.birthRateVariation = 0.0;
	self.particleAngularVelocityVariation = 0.0;
	self.imageSequenceInitialFrameVariation = 0.0;
	self.imageSequenceFrameRateVariation = 0.0;
	self.particleIntensityVariation = 0.0;
	self.particleMassVariation = 0.0;
	self.particleBounceVariation = 0.0;
	self.particleFrictionVariation = 0.0;
	self.particleChargeVariation = 0.0;
}

/*!
	@method		installSeededVariation
	@abstract	Installs the birth-event block that applies seeded jitter to new particles.
	@discussion	Introduced in FxGrip 0.1.0. The block reads the captured variation magnitudes and, for
				each born particle, adds hashed offsets keyed by an incrementing birth index. Velocity,
				size, life, color, and angle receive independent hash channels. */
- (void)installSeededVariation
{
	__weak typeof(self) weakSelf = self;
	[self handleEvent:SCNParticleEventBirth
		forProperties:@[SCNParticlePropertyVelocity, SCNParticlePropertySize,
						SCNParticlePropertyLife, SCNParticlePropertyColor, SCNParticlePropertyAngle]
			withBlock:^(void * _Nonnull * _Nonnull data, size_t * _Nonnull dataStride, uint32_t * _Nullable indices, NSInteger count) {
		__strong typeof(weakSelf) self = weakSelf;
		if (self == nil) {
			return;
		}
		uint32_t seed = self.seed;
		float velocityJitter = (float)self->_velocityJitter;
		float sizeJitter = (float)self->_sizeJitter;
		float lifeJitter = (float)self->_lifeJitter;
		float angleJitter = (float)self->_angleJitter;
		float spreadTangent = self->_spreadAngle > 0.0 ? tanf((float)self->_spreadAngle * 0.5f) : 0.0f;
		simd_float4 colorJitter = simd_make_float4((float)self->_colorJitter.x, (float)self->_colorJitter.y,
												   (float)self->_colorJitter.z, (float)self->_colorJitter.w);

		for (NSInteger i = 0; i < count; i++) {
			uint32_t pid = self->_birthCounter++;

			float *velocity = (float *)((uintptr_t)data[0] + dataStride[0] * (NSUInteger)i);
			simd_float3 jitter = FxGripParticleRand3(pid, seed, 0) * velocityJitter;
			if (spreadTangent > 0.0f) {
				float speed = sqrtf(velocity[0] * velocity[0] + velocity[1] * velocity[1] + velocity[2] * velocity[2]);
				jitter += FxGripParticleRand3(pid, seed, 3) * (speed * spreadTangent);
			}
			velocity[0] += jitter.x;
			velocity[1] += jitter.y;
			velocity[2] += jitter.z;

			float *size = (float *)((uintptr_t)data[1] + dataStride[1] * (NSUInteger)i);
			size[0] = MAX(0.0f, size[0] + FxGripParticleRand(pid, seed, 6) * sizeJitter);

			float *life = (float *)((uintptr_t)data[2] + dataStride[2] * (NSUInteger)i);
			life[0] = MAX(0.001f, life[0] + FxGripParticleRand(pid, seed, 7) * lifeJitter);

			float *color = (float *)((uintptr_t)data[3] + dataStride[3] * (NSUInteger)i);
			color[0] = FxGripClamp01(color[0] + FxGripParticleRand(pid, seed, 8) * colorJitter.x);
			color[1] = FxGripClamp01(color[1] + FxGripParticleRand(pid, seed, 9) * colorJitter.y);
			color[2] = FxGripClamp01(color[2] + FxGripParticleRand(pid, seed, 10) * colorJitter.z);
			color[3] = FxGripClamp01(color[3] + FxGripParticleRand(pid, seed, 11) * colorJitter.w);

			float *angle = (float *)((uintptr_t)data[4] + dataStride[4] * (NSUInteger)i);
			angle[0] += FxGripParticleRand(pid, seed, 12) * angleJitter;
		}
	}];
}

/*! @abstract Resets the birth-index counter so re-emission reproduces the same particle stream. */
- (void)reset
{
	_birthCounter = 0;
	[super reset];
}

@end
