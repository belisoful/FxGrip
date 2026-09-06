/*!
	@file       FxGripSpaceMotionTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripSpaceMotionTests
	@abstract   Tests for the FxGripSpaceMotion transform and camera-motion functions.
	@discussion Introduced in FxGrip 0.1.0. The tests cover position and focus-distance extraction, forward, backward, and central linear and angular velocity, orientation recovery that ignores non-uniform scale, and the non-positive time-step guard.
*/

#import <XCTest/XCTest.h>
#import <simd/simd.h>
#import <FxGrip/FxGripSpaceMotion.h>

@interface FxGripSpaceMotionTests : XCTestCase
@end

@implementation FxGripSpaceMotionTests

static simd_float4x4 TransformWithTranslation(float x, float y, float z)
{
	simd_float4x4 m = matrix_identity_float4x4;
	m.columns[3] = simd_make_float4(x, y, z, 1.0f);
	return m;
}

static simd_float4x4 TransformFromBasis(simd_float3x3 basis, simd_float3 translation)
{
	simd_float4x4 m;
	m.columns[0] = simd_make_float4(basis.columns[0], 0.0f);
	m.columns[1] = simd_make_float4(basis.columns[1], 0.0f);
	m.columns[2] = simd_make_float4(basis.columns[2], 0.0f);
	m.columns[3] = simd_make_float4(translation, 1.0f);
	return m;
}

#pragma mark Position and focus

/*! @abstract FxGripTransformPosition returns the transform's translation column. */
- (void)testPositionIsTheTranslationColumn
{
	simd_float3 p = FxGripTransformPosition(TransformWithTranslation(3.0f, 4.0f, 5.0f));
	XCTAssertEqualWithAccuracy(p.x, 3.0f, 1e-5);
	XCTAssertEqualWithAccuracy(p.y, 4.0f, 1e-5);
	XCTAssertEqualWithAccuracy(p.z, 5.0f, 1e-5);
}

/*! @abstract FxGripFocusDistance returns the Euclidean distance between two points. */
- (void)testFocusDistanceIsEuclidean
{
	float d = FxGripFocusDistance(simd_make_float3(0.0f, 0.0f, 0.0f), simd_make_float3(0.0f, 0.0f, 10.0f));
	XCTAssertEqualWithAccuracy(d, 10.0f, 1e-5);

	float d2 = FxGripFocusDistance(simd_make_float3(3.0f, 4.0f, 0.0f), simd_make_float3(0.0f, 0.0f, 0.0f));
	XCTAssertEqualWithAccuracy(d2, 5.0f, 1e-5);
}

#pragma mark Linear velocity

/*! @abstract Central linear velocity divides the span between the previous and next samples by twice the time step. */
- (void)testCentralLinearVelocityUsesTheSpanBetweenSamples
{
	simd_float4x4 previous = TransformWithTranslation(-1.0f, 0.0f, 0.0f);
	simd_float4x4 next = TransformWithTranslation(1.0f, 0.0f, 0.0f);
	FxGripCameraMotion motion = FxGripCameraMotionCentral(previous, next, 1.0f); // span 2

	XCTAssertEqualWithAccuracy(motion.linearVelocity.x, 1.0f, 1e-5);
	XCTAssertEqualWithAccuracy(motion.linearVelocity.y, 0.0f, 1e-5);
	XCTAssertEqualWithAccuracy(motion.linearVelocity.z, 0.0f, 1e-5);
}

/*! @abstract Forward linear velocity divides the displacement from the current to the next sample by the time step. */
- (void)testForwardLinearVelocity
{
	simd_float4x4 current = TransformWithTranslation(0.0f, 0.0f, 0.0f);
	simd_float4x4 next = TransformWithTranslation(3.0f, 0.0f, 0.0f);
	FxGripCameraMotion motion = FxGripCameraMotionForward(current, next, 1.5f);

	XCTAssertEqualWithAccuracy(motion.linearVelocity.x, 2.0f, 1e-5);
}

/*! @abstract Backward linear velocity divides the displacement from the previous to the current sample by the time step. */
- (void)testBackwardLinearVelocity
{
	simd_float4x4 previous = TransformWithTranslation(1.0f, 0.0f, 0.0f);
	simd_float4x4 current = TransformWithTranslation(4.0f, 0.0f, 0.0f);
	FxGripCameraMotion motion = FxGripCameraMotionBackward(previous, current, 1.0f);

	XCTAssertEqualWithAccuracy(motion.linearVelocity.x, 3.0f, 1e-5);
}

/*! @abstract Under constant velocity, the forward, backward, and central estimates agree. */
- (void)testForwardAndBackwardAgreeUnderConstantVelocity
{
	simd_float4x4 a = TransformWithTranslation(0.0f, 0.0f, 0.0f);
	simd_float4x4 b = TransformWithTranslation(2.0f, 0.0f, 0.0f);
	simd_float4x4 c = TransformWithTranslation(4.0f, 0.0f, 0.0f);

	FxGripCameraMotion forward = FxGripCameraMotionForward(a, b, 1.0f);
	FxGripCameraMotion backward = FxGripCameraMotionBackward(b, c, 1.0f);
	FxGripCameraMotion central = FxGripCameraMotionCentral(a, c, 1.0f);

	XCTAssertEqualWithAccuracy(forward.linearVelocity.x, 2.0f, 1e-5);
	XCTAssertEqualWithAccuracy(backward.linearVelocity.x, 2.0f, 1e-5);
	XCTAssertEqualWithAccuracy(central.linearVelocity.x, 2.0f, 1e-5);
}

#pragma mark Angular velocity

/*! @abstract Central angular velocity of a rotation about the y-axis recovers the rate about y and zero about x and z. */
- (void)testCentralAngularVelocityAboutY
{
	float theta = 0.2f;
	simd_float4x4 previous = matrix_identity_float4x4;
	simd_float4x4 next = simd_matrix4x4(simd_quaternion(theta, simd_make_float3(0.0f, 1.0f, 0.0f)));

	FxGripCameraMotion motion = FxGripCameraMotionCentral(previous, next, 0.1f); // span 0.2 -> rate 1.0

	XCTAssertEqualWithAccuracy(motion.angularVelocity.x, 0.0f, 1e-4);
	XCTAssertEqualWithAccuracy(motion.angularVelocity.y, 1.0f, 1e-4);
	XCTAssertEqualWithAccuracy(motion.angularVelocity.z, 0.0f, 1e-4);
}

/*! @abstract FxGripAngularVelocity of two equal orientations is zero. */
- (void)testAngularVelocityIsZeroWithoutRotation
{
	simd_quatf identity = simd_quaternion(0.0f, simd_make_float3(0.0f, 1.0f, 0.0f));
	simd_float3 w = FxGripAngularVelocity(identity, identity, 0.5f);
	XCTAssertEqualWithAccuracy(simd_length(w), 0.0f, 1e-5);
}

#pragma mark Orientation

/*! @abstract FxGripTransformOrientation recovers the rotation up to the quaternion double cover even when the basis carries non-uniform scale. */
- (void)testOrientationIgnoresNonUniformScale
{
	simd_quatf rotation = simd_quaternion(0.5f, simd_normalize(simd_make_float3(1.0f, 2.0f, 3.0f)));
	simd_float3x3 r = simd_matrix3x3(rotation);
	simd_float3x3 scaled = simd_matrix(r.columns[0] * 2.0f, r.columns[1] * 3.0f, r.columns[2] * 4.0f);
	simd_float4x4 transform = TransformFromBasis(scaled, simd_make_float3(7.0f, 8.0f, 9.0f));

	simd_quatf recovered = FxGripTransformOrientation(transform);

	// Same rotation up to the quaternion double cover: |dot| == 1.
	XCTAssertEqualWithAccuracy(fabsf(simd_dot(recovered.vector, rotation.vector)), 1.0f, 1e-4);
}

#pragma mark Guards

/*! @abstract A zero or negative time step yields zero linear and angular velocity for every estimator. */
- (void)testNonPositiveDtYieldsZeroMotion
{
	simd_float4x4 a = TransformWithTranslation(0.0f, 0.0f, 0.0f);
	simd_float4x4 b = TransformWithTranslation(5.0f, 5.0f, 5.0f);

	FxGripCameraMotion central = FxGripCameraMotionCentral(a, b, 0.0f);
	FxGripCameraMotion forward = FxGripCameraMotionForward(a, b, -1.0f);
	FxGripCameraMotion backward = FxGripCameraMotionBackward(a, b, 0.0f);

	XCTAssertEqualWithAccuracy(simd_length(central.linearVelocity), 0.0f, 1e-6);
	XCTAssertEqualWithAccuracy(simd_length(forward.linearVelocity), 0.0f, 1e-6);
	XCTAssertEqualWithAccuracy(simd_length(backward.angularVelocity), 0.0f, 1e-6);
}

@end
