/*!
	@file       FxGripParticleRandTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-09
	@header     FxGripParticleRandTests
	@abstract   Tests for the seeded, index-keyed variation function shared by both particle engines.
	@discussion Introduced in FxGrip 0.1.0. The function is a contract: its outputs are what every
	            rendered seeded particle effect was built from. The tests pin its range, its
	            determinism, the independence of its channels, a handful of exact values, and the
	            spreading-angle cap.
*/

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripParticleRand.h>

@interface FxGripParticleRandTests : XCTestCase
@end

@implementation FxGripParticleRandTests

/*! @abstract Every value lies in [-1, 1]. */
- (void)testValuesLieInTheUnitInterval
{
	for (uint32_t index = 0; index < 2000; index++) {
		float value = FxGripParticleRand(index, 7u, index % 5u);
		XCTAssertGreaterThanOrEqual(value, -1.0f);
		XCTAssertLessThanOrEqual(value, 1.0f);
	}
}

/*! @abstract The same arguments give the same value, and a different seed gives a different one. */
- (void)testDeterministicAndSeeded
{
	XCTAssertEqual(FxGripParticleRand(12u, 3u, 0u), FxGripParticleRand(12u, 3u, 0u));
	XCTAssertNotEqual(FxGripParticleRand(12u, 3u, 0u), FxGripParticleRand(12u, 4u, 0u));
	XCTAssertNotEqual(FxGripParticleRand(12u, 3u, 0u), FxGripParticleRand(13u, 3u, 0u));
}

/*! @abstract Channels are independent streams, so one particle's varied properties do not correlate. */
- (void)testChannelsAreIndependent
{
	double dot = 0.0;
	for (uint32_t index = 0; index < 4000; index++) {
		dot += (double)FxGripParticleRand(index, 9u, 0u) * (double)FxGripParticleRand(index, 9u, 1u);
	}
	// Uncorrelated streams average near zero; a shared stream would average near 1/3.
	XCTAssertLessThan(fabs(dot / 4000.0), 0.05);
}

/*! @abstract The three-vector form takes consecutive channels. */
- (void)testRand3TakesConsecutiveChannels
{
	simd_float3 v = FxGripParticleRand3(5u, 2u, 10u);
	XCTAssertEqual(v.x, FxGripParticleRand(5u, 2u, 10u));
	XCTAssertEqual(v.y, FxGripParticleRand(5u, 2u, 11u));
	XCTAssertEqual(v.z, FxGripParticleRand(5u, 2u, 12u));
}

/*! @abstract The hash is a contract, so a few exact values are pinned. */
- (void)testPinnedValues
{
	// Derived from the hash as shipped; a change here changes every rendered seeded effect.
	XCTAssertEqualWithAccuracy(FxGripParticleRand(0u, 0u, 0u), 0.5027732f, 1e-6f);
	XCTAssertEqualWithAccuracy(FxGripParticleRand(1u, 1u, 1u), 0.0343297f, 1e-6f);
	XCTAssertEqualWithAccuracy(FxGripParticleRand(1000u, 42u, 7u), -0.0325373f, 1e-6f);
}

/*! @abstract The spread tangent is zero at and below zero, grows with the angle, and caps short of pi. */
- (void)testSpreadTangentCapsShortOfPi
{
	XCTAssertEqual(FxGripParticleSpreadTangent(0.0), 0.0f);
	XCTAssertEqual(FxGripParticleSpreadTangent(-1.0), 0.0f);
	XCTAssertEqualWithAccuracy(FxGripParticleSpreadTangent(M_PI_2), 1.0f, 1e-6f);
	float capped = FxGripParticleSpreadTangent(FxGripParticleMaxSpreadAngle);
	XCTAssertEqual(FxGripParticleSpreadTangent(M_PI), capped);
	XCTAssertEqual(FxGripParticleSpreadTangent(10.0), capped);
	XCTAssertTrue(isfinite(capped));
	XCTAssertLessThan(FxGripParticleMaxSpreadAngle, M_PI);
}

@end
