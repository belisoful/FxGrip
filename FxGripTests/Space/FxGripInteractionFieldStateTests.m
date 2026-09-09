/*!
	@file       FxGripInteractionFieldStateTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-09
	@header     FxGripInteractionFieldStateTests
	@abstract   Tests for the shared source expansion behind a particle interaction physics field.
	@discussion Introduced in FxGrip 0.1.0. The state is the half of the field facade that holds the
	            physics, so its acceleration is checked against a direct sum written from the force
	            definitions: gravity attracts by the source mass, electric repels like charges, and
	            magnetic is the Lorentz term over the Biot-Savart field of the moving sources.
*/

#import <XCTest/XCTest.h>
#import <simd/simd.h>
#import "../../FxGrip/Space/FxGripInteractionFieldState.h"

// The softened Laplace field of unit sources at one point: Σ (r_j − p) / (|r_j − p|² + ε²)^{3/2}.
static simd_float3 FxGripTestUnitField(const simd_float3 *sources, NSUInteger count, simd_float3 point, float softening)
{
	simd_float3 field = simd_make_float3(0.0f, 0.0f, 0.0f);
	for (NSUInteger j = 0; j < count; j++) {
		const simd_float3 d = sources[j] - point;
		const float r2 = simd_length_squared(d) + softening * softening;
		field += d / (r2 * sqrtf(r2));
	}
	return field;
}

// The Biot-Savart field of moving charges at one point: Σ q (v_j × (p − r_j)) / (|p − r_j|² + ε²)^{3/2}.
static simd_float3 FxGripTestBiotSavart(const simd_float3 *sources, const simd_float3 *velocities, NSUInteger count,
										simd_float3 point, float charge, float softening)
{
	simd_float3 field = simd_make_float3(0.0f, 0.0f, 0.0f);
	for (NSUInteger j = 0; j < count; j++) {
		const simd_float3 d = point - sources[j];
		const float r2 = simd_length_squared(d) + softening * softening;
		field += charge * simd_cross(velocities[j], d) / (r2 * sqrtf(r2));
	}
	return field;
}

@interface FxGripInteractionFieldStateTests : XCTestCase
@end

@implementation FxGripInteractionFieldStateTests
{
	simd_float3 _sources[4];
	simd_float3 _velocities[4];
	// The state holds its systems weakly, so the test owns them for the duration.
	NSMutableArray<SCNParticleSystem *> *_systems;
}

- (void)setUp
{
	[super setUp];
	_systems = [NSMutableArray array];
	_sources[0] = simd_make_float3(-1.0f, 0.0f, 0.0f);
	_sources[1] = simd_make_float3(1.0f, 0.5f, 0.0f);
	_sources[2] = simd_make_float3(0.0f, -1.0f, 0.75f);
	_sources[3] = simd_make_float3(0.25f, 0.25f, -1.5f);
	_velocities[0] = simd_make_float3(0.0f, 2.0f, 0.0f);
	_velocities[1] = simd_make_float3(-1.0f, 0.0f, 1.0f);
	_velocities[2] = simd_make_float3(0.5f, 0.5f, 0.0f);
	_velocities[3] = simd_make_float3(0.0f, -1.0f, 2.0f);
}

// A particle system the test keeps alive, to key a source slot with.
- (SCNParticleSystem *)newSystem
{
	SCNParticleSystem *system = [SCNParticleSystem particleSystem];
	[_systems addObject:system];
	return system;
}

// Records the fixture sources for one system on a state with the given configuration.
- (FxGripInteractionFieldState *)stateWithInteraction:(FxGripParticleInteraction *)interaction
												 mass:(float)mass
											   charge:(float)charge
{
	FxGripInteractionFieldState *state = [FxGripInteractionFieldState.alloc initWithInteraction:interaction];
	XCTAssertTrue([state setSourcesForSystem:[self newSystem]
									   count:4
								   positions:_sources
							  positionStride:sizeof(simd_float3)
								  velocities:_velocities
							  velocityStride:sizeof(simd_float3)
										mass:mass
									  charge:charge]);
	return state;
}

// Compares against the expected vector's own magnitude, since the accuracy the multipole promises is
// relative and the field magnitude varies by orders of magnitude with distance.
- (void)assertVector:(simd_float3)actual matches:(simd_float3)expected tolerance:(float)tolerance
{
	const float scale = fmaxf(simd_length(expected), 1e-6f);
	XCTAssertLessThan(simd_length(actual - expected) / scale, tolerance,
					  @"expected (%g, %g, %g), got (%g, %g, %g)",
					  expected.x, expected.y, expected.z, actual.x, actual.y, actual.z);
}

#pragma mark Lifecycle

/*! @abstract A state that has never been built evaluates to no acceleration. */
- (void)testUnbuiltStateIsInert
{
	FxGripInteractionFieldState *state =
		[FxGripInteractionFieldState.alloc initWithInteraction:[FxGripParticleInteraction gravityWithStrength:1.0]];
	const simd_float3 a = [state accelerationAtPosition:simd_make_float3(0.5f, 0.0f, 0.0f)
											   velocity:simd_make_float3(0.0f, 0.0f, 0.0f)
												   mass:1.0f
												 charge:1.0f];
	XCTAssertEqual(simd_length(a), 0.0f);
}

/*! @abstract A system that reports no particles leaves the state inert. */
- (void)testNoParticlesLeavesTheStateInert
{
	FxGripInteractionFieldState *state =
		[FxGripInteractionFieldState.alloc initWithInteraction:[FxGripParticleInteraction gravityWithStrength:1.0]];
	XCTAssertTrue([state setSourcesForSystem:[self newSystem] count:0 positions:_sources positionStride:sizeof(simd_float3)
								  velocities:NULL velocityStride:0 mass:1.0f charge:0.0f]);
	const simd_float3 a = [state accelerationAtPosition:simd_make_float3(0.5f, 0.0f, 0.0f)
											   velocity:simd_make_float3(0.0f, 0.0f, 0.0f)
												   mass:1.0f charge:1.0f];
	XCTAssertEqual(simd_length(a), 0.0f);
}

/*! @abstract Repeated recordings keep the state queryable, so a per-step rebuild is safe. */
- (void)testRepeatedRecordingsStayQueryable
{
	FxGripParticleInteraction *config = [FxGripParticleInteraction gravityWithStrength:2.0];
	config.softening = 0.1;
	FxGripInteractionFieldState *state = [self stateWithInteraction:config mass:1.0f charge:0.0f];
	SCNParticleSystem *system = _systems.lastObject;
	const simd_float3 point = simd_make_float3(0.5f, 0.25f, 0.0f);
	const simd_float3 first = [state accelerationAtPosition:point velocity:simd_make_float3(0.0f, 0.0f, 0.0f) mass:1.0f charge:0.0f];
	for (int i = 0; i < 5; i++) {
		XCTAssertTrue([state setSourcesForSystem:system count:4 positions:_sources positionStride:sizeof(simd_float3)
									  velocities:_velocities velocityStride:sizeof(simd_float3)
											mass:1.0f charge:0.0f]);
	}
	const simd_float3 last = [state accelerationAtPosition:point velocity:simd_make_float3(0.0f, 0.0f, 0.0f) mass:1.0f charge:0.0f];
	[self assertVector:last matches:first tolerance:1e-6f];
}

#pragma mark Force physics

/*! @abstract Gravity matches the direct sum, scales with the source mass, and ignores the receiver mass. */
- (void)testGravityMatchesDirectSum
{
	FxGripParticleInteraction *config = [FxGripParticleInteraction gravityWithStrength:0.75];
	config.softening = 0.2;
	const float sourceMass = 3.0f;
	FxGripInteractionFieldState *state = [self stateWithInteraction:config mass:sourceMass charge:0.0f];

	const simd_float3 point = simd_make_float3(0.4f, -0.2f, 0.1f);
	const simd_float3 expected = 0.75f * sourceMass * FxGripTestUnitField(_sources, 4, point, 0.2f);
	const simd_float3 actual = [state accelerationAtPosition:point velocity:simd_make_float3(0.0f, 0.0f, 0.0f) mass:sourceMass charge:0.0f];
	[self assertVector:actual matches:expected tolerance:1e-4f];

	// Gravity is an acceleration, so a heavier receiver falls the same way.
	const simd_float3 heavy = [state accelerationAtPosition:point velocity:simd_make_float3(0.0f, 0.0f, 0.0f) mass:100.0f charge:0.0f];
	[self assertVector:heavy matches:expected tolerance:1e-4f];
}

/*! @abstract Gravity pulls a distant target back toward the source cloud. */
- (void)testGravityAttractsTowardTheSources
{
	FxGripParticleInteraction *config = [FxGripParticleInteraction gravityWithStrength:1.0];
	config.softening = 0.05;
	FxGripInteractionFieldState *state = [self stateWithInteraction:config mass:1.0f charge:0.0f];

	const simd_float3 point = simd_make_float3(8.0f, 0.0f, 0.0f);
	const simd_float3 a = [state accelerationAtPosition:point velocity:simd_make_float3(0.0f, 0.0f, 0.0f) mass:1.0f charge:0.0f];
	XCTAssertLessThan(a.x, 0.0f, @"the pull points back toward the cloud at the origin");
	XCTAssertGreaterThan(simd_length(a), 0.0f);
}

/*! @abstract The electric force repels like charges, so it opposes gravity at the same configuration. */
- (void)testElectricRepelsLikeCharges
{
	FxGripParticleInteraction *config = [FxGripParticleInteraction new];
	config.enabled = YES;
	config.kind = FxGripParticleInteractionKindElectric;
	config.electricStrength = 0.5;
	config.softening = 0.2;
	const float charge = 2.0f;
	const float receiverMass = 4.0f;
	FxGripInteractionFieldState *state = [self stateWithInteraction:config mass:receiverMass charge:charge];

	const simd_float3 point = simd_make_float3(8.0f, 0.0f, 0.0f);
	const simd_float3 expected =
		-0.5f * charge * charge / receiverMass * FxGripTestUnitField(_sources, 4, point, 0.2f);
	const simd_float3 actual = [state accelerationAtPosition:point velocity:simd_make_float3(0.0f, 0.0f, 0.0f) mass:receiverMass charge:charge];
	[self assertVector:actual matches:expected tolerance:5e-3f];
	XCTAssertGreaterThan(actual.x, 0.0f, @"like charges push the target away from the cloud");
}

/*! @abstract Gravity and electric combine in one evaluation, adding their couplings. */
- (void)testGravityAndElectricCombine
{
	FxGripParticleInteraction *config = [FxGripParticleInteraction new];
	config.enabled = YES;
	config.kind = FxGripParticleInteractionKindGravity | FxGripParticleInteractionKindElectric;
	config.gravityStrength = 0.4;
	config.electricStrength = 0.3;
	config.softening = 0.15;
	const float mass = 2.0f;
	const float charge = 1.5f;
	FxGripInteractionFieldState *state = [self stateWithInteraction:config mass:mass charge:charge];

	const simd_float3 point = simd_make_float3(0.6f, 0.3f, -0.4f);
	const simd_float3 field = FxGripTestUnitField(_sources, 4, point, 0.15f);
	const simd_float3 expected = (0.4f * mass - 0.3f * charge * charge / mass) * field;
	const simd_float3 actual = [state accelerationAtPosition:point velocity:simd_make_float3(0.0f, 0.0f, 0.0f) mass:mass charge:charge];
	[self assertVector:actual matches:expected tolerance:1e-4f];
}

/*! @abstract The magnetic term is the Lorentz force over the Biot-Savart field of the moving sources. */
- (void)testMagneticMatchesLorentzOverBiotSavart
{
	FxGripParticleInteraction *config = [FxGripParticleInteraction new];
	config.enabled = YES;
	config.kind = FxGripParticleInteractionKindMagnetic;
	config.magneticStrength = 0.6;
	config.softening = 0.25;
	const float mass = 2.0f;
	const float charge = 1.25f;
	FxGripInteractionFieldState *state = [self stateWithInteraction:config mass:mass charge:charge];

	const simd_float3 point = simd_make_float3(0.3f, 0.6f, -0.2f);
	const simd_float3 velocity = simd_make_float3(1.0f, -0.5f, 2.0f);
	const simd_float3 B = FxGripTestBiotSavart(_sources, _velocities, 4, point, charge, 0.25f);
	const simd_float3 expected = (0.6f * charge / mass) * simd_cross(velocity, B);
	const simd_float3 actual = [state accelerationAtPosition:point velocity:velocity mass:mass charge:charge];
	[self assertVector:actual matches:expected tolerance:1e-3f];
	XCTAssertGreaterThan(simd_length(actual), 0.0f);
}

/*! @abstract A neutral or motionless receiver feels no magnetic force. */
- (void)testMagneticNeedsChargeAndMotion
{
	FxGripParticleInteraction *config = [FxGripParticleInteraction new];
	config.enabled = YES;
	config.kind = FxGripParticleInteractionKindMagnetic;
	config.magneticStrength = 1.0;
	FxGripInteractionFieldState *state = [self stateWithInteraction:config mass:1.0f charge:1.0f];

	const simd_float3 point = simd_make_float3(0.3f, 0.6f, -0.2f);
	const simd_float3 motionless = [state accelerationAtPosition:point velocity:simd_make_float3(0.0f, 0.0f, 0.0f) mass:1.0f charge:1.0f];
	XCTAssertEqual(simd_length(motionless), 0.0f);
	const simd_float3 neutral = [state accelerationAtPosition:point
													velocity:simd_make_float3(1.0f, 1.0f, 1.0f)
														mass:1.0f charge:0.0f];
	XCTAssertEqual(simd_length(neutral), 0.0f);
}

/*! @abstract A disabled kind contributes nothing, so an interaction of no forces evaluates to zero. */
- (void)testNoKindIsInert
{
	FxGripParticleInteraction *config = [FxGripParticleInteraction new];
	config.enabled = YES;
	config.kind = FxGripParticleInteractionKindNone;
	FxGripInteractionFieldState *state = [self stateWithInteraction:config mass:1.0f charge:1.0f];
	const simd_float3 a = [state accelerationAtPosition:simd_make_float3(0.5f, 0.0f, 0.0f)
											   velocity:simd_make_float3(1.0f, 0.0f, 0.0f)
												   mass:1.0f charge:1.0f];
	XCTAssertEqual(simd_length(a), 0.0f);
}

/*! @abstract A many-source build stays close to the direct sum, which is the multipole approximation. */
- (void)testManySourcesMatchTheDirectSum
{
	const NSUInteger count = 3000;
	const float softening = 0.05f;
	simd_float3 *sources = (simd_float3 *)malloc(sizeof(simd_float3) * count);
	uint32_t seed = 12345u;
	for (NSUInteger i = 0; i < count; i++) {
		float c[3];
		for (int k = 0; k < 3; k++) {
			seed = seed * 1664525u + 1013904223u;
			c[k] = (float)(seed >> 8) / (float)(1u << 24) * 4.0f - 2.0f;
		}
		sources[i] = simd_make_float3(c[0], c[1], c[2]);
	}

	FxGripParticleInteraction *config = [FxGripParticleInteraction gravityWithStrength:1.0];
	config.softening = softening;
	FxGripInteractionFieldState *state = [FxGripInteractionFieldState.alloc initWithInteraction:config];
	XCTAssertTrue([state setSourcesForSystem:[self newSystem] count:(uint32_t)count positions:sources positionStride:sizeof(simd_float3)
								  velocities:NULL velocityStride:0 mass:1.0f charge:0.0f]);

	// The reference sums in double: inside a cloud the net field is a small residue of large opposed
	// terms, so a float reference would carry its own cancellation error into the comparison.
	double errorSum = 0.0, referenceSum = 0.0;
	for (int q = 0; q < 32; q++) {
		float c[3];
		for (int k = 0; k < 3; k++) {
			seed = seed * 1664525u + 1013904223u;
			c[k] = (float)(seed >> 8) / (float)(1u << 24) * 4.0f - 2.0f;
		}
		const simd_float3 point = simd_make_float3(c[0], c[1], c[2]);
		double rx = 0.0, ry = 0.0, rz = 0.0;
		for (NSUInteger j = 0; j < count; j++) {
			const double dx = (double)sources[j].x - point.x;
			const double dy = (double)sources[j].y - point.y;
			const double dz = (double)sources[j].z - point.z;
			const double r2 = dx * dx + dy * dy + dz * dz + (double)softening * softening;
			const double w = 1.0 / (r2 * sqrt(r2));
			rx += w * dx; ry += w * dy; rz += w * dz;
		}
		const simd_float3 actual = [state accelerationAtPosition:point
													   velocity:simd_make_float3(0.0f, 0.0f, 0.0f)
														   mass:1.0f charge:0.0f];
		const double ex = actual.x - rx, ey = actual.y - ry, ez = actual.z - rz;
		errorSum += ex * ex + ey * ey + ez * ez;
		referenceSum += rx * rx + ry * ry + rz * rz;
	}
	XCTAssertLessThan(sqrt(errorSum / referenceSum), 2e-2, @"the multipole query tracks the direct sum");
	free(sources);
}

#pragma mark Several source systems

/*! @abstract Two systems' particles combine into one field, matching the same particles as one set. */
- (void)testTwoSystemsCombineIntoOneField
{
	simd_float3 far[4];
	for (int i = 0; i < 4; i++) {
		far[i] = _sources[i] + simd_make_float3(6.0f, 0.0f, 0.0f);
	}
	FxGripParticleInteraction *config = [FxGripParticleInteraction gravityWithStrength:1.0];
	config.softening = 0.2;

	FxGripInteractionFieldState *split = [FxGripInteractionFieldState.alloc initWithInteraction:config];
	SCNParticleSystem *first = [self newSystem];
	SCNParticleSystem *second = [self newSystem];
	XCTAssertTrue([split setSourcesForSystem:first count:4 positions:_sources positionStride:sizeof(simd_float3)
								  velocities:NULL velocityStride:0 mass:1.0f charge:0.0f]);
	XCTAssertTrue([split setSourcesForSystem:second count:4 positions:far positionStride:sizeof(simd_float3)
								  velocities:NULL velocityStride:0 mass:1.0f charge:0.0f]);
	XCTAssertEqual(split.boundSystems.count, 2u);
	XCTAssertEqual(split.boundSystems.firstObject, first, @"bind order is preserved");

	simd_float3 combined[8];
	memcpy(combined, _sources, sizeof(_sources));
	memcpy(combined + 4, far, sizeof(far));
	FxGripInteractionFieldState *whole = [FxGripInteractionFieldState.alloc initWithInteraction:config];
	XCTAssertTrue([whole setSourcesForSystem:[self newSystem] count:8 positions:combined positionStride:sizeof(simd_float3)
								  velocities:NULL velocityStride:0 mass:1.0f charge:0.0f]);

	const simd_float3 point = simd_make_float3(3.0f, 0.4f, -0.2f);
	const simd_float3 fromSplit = [split accelerationAtPosition:point velocity:simd_make_float3(0.0f, 0.0f, 0.0f) mass:1.0f charge:0.0f];
	const simd_float3 fromWhole = [whole accelerationAtPosition:point velocity:simd_make_float3(0.0f, 0.0f, 0.0f) mass:1.0f charge:0.0f];
	[self assertVector:fromSplit matches:fromWhole tolerance:1e-5f];

	const simd_float3 expected = FxGripTestUnitField(combined, 8, point, 0.2f);
	[self assertVector:fromSplit matches:expected tolerance:5e-3f];
}

/*! @abstract Dropping a system's sources removes its particles from the field. */
- (void)testRemovingASystemDropsItsSources
{
	FxGripParticleInteraction *config = [FxGripParticleInteraction gravityWithStrength:1.0];
	config.softening = 0.2;
	FxGripInteractionFieldState *state = [FxGripInteractionFieldState.alloc initWithInteraction:config];
	SCNParticleSystem *keeper = [self newSystem];
	SCNParticleSystem *leaver = [self newSystem];

	simd_float3 far[4];
	for (int i = 0; i < 4; i++) {
		far[i] = _sources[i] + simd_make_float3(6.0f, 0.0f, 0.0f);
	}
	XCTAssertTrue([state setSourcesForSystem:keeper count:4 positions:_sources positionStride:sizeof(simd_float3)
								  velocities:NULL velocityStride:0 mass:1.0f charge:0.0f]);
	XCTAssertTrue([state setSourcesForSystem:leaver count:4 positions:far positionStride:sizeof(simd_float3)
								  velocities:NULL velocityStride:0 mass:1.0f charge:0.0f]);

	[state removeSourcesForSystem:leaver];
	XCTAssertEqual(state.boundSystems.count, 1u);
	XCTAssertEqual(state.boundSystems.firstObject, keeper);

	const simd_float3 point = simd_make_float3(0.4f, -0.2f, 0.1f);
	const simd_float3 actual = [state accelerationAtPosition:point velocity:simd_make_float3(0.0f, 0.0f, 0.0f) mass:1.0f charge:0.0f];
	const simd_float3 expected = FxGripTestUnitField(_sources, 4, point, 0.2f);
	[self assertVector:actual matches:expected tolerance:1e-4f];
}

/*! @abstract Each system contributes its own particle mass, so a heavier cloud pulls harder. */
- (void)testSystemsContributeTheirOwnMass
{
	FxGripParticleInteraction *config = [FxGripParticleInteraction gravityWithStrength:1.0];
	config.softening = 0.2;
	FxGripInteractionFieldState *state = [FxGripInteractionFieldState.alloc initWithInteraction:config];

	simd_float3 heavy[2] = { simd_make_float3(-3.0f, 0.0f, 0.0f), simd_make_float3(-3.0f, 1.0f, 0.0f) };
	simd_float3 light[2] = { simd_make_float3(3.0f, 0.0f, 0.0f), simd_make_float3(3.0f, 1.0f, 0.0f) };
	XCTAssertTrue([state setSourcesForSystem:[self newSystem] count:2 positions:heavy positionStride:sizeof(simd_float3)
								  velocities:NULL velocityStride:0 mass:10.0f charge:0.0f]);
	XCTAssertTrue([state setSourcesForSystem:[self newSystem] count:2 positions:light positionStride:sizeof(simd_float3)
								  velocities:NULL velocityStride:0 mass:1.0f charge:0.0f]);

	// Midway between the two clusters the heavier one wins, so the pull is toward it.
	const simd_float3 a = [state accelerationAtPosition:simd_make_float3(0.0f, 0.5f, 0.0f)
											   velocity:simd_make_float3(0.0f, 0.0f, 0.0f)
												   mass:1.0f charge:0.0f];
	XCTAssertLessThan(a.x, 0.0f, @"the heavier cluster dominates");
}

@end
