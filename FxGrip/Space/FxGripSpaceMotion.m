/*!
	@file       FxGripSpaceMotion.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripSpaceMotion
	@abstract   Implements the camera motion and focus quantities derived from sampled scene transforms.
	@discussion Introduced in FxGrip 0.1.0. Position reads the translation column, and orientation reads the
	            normalized upper-left basis as a quaternion. Angular velocity takes the shortest-arc
	            rotation between two orientations over an interval. The central, forward, and backward
	            variants form linear and angular velocity from two samples by finite difference. Focus
	            distance is the straight-line distance between two points.
*/

#import "FxGripSpaceMotion.h"

FxGripCameraMotion FxGripCameraMotionZero(void)
{
	FxGripCameraMotion motion = { simd_make_float3(0.0f, 0.0f, 0.0f), simd_make_float3(0.0f, 0.0f, 0.0f) };
	return motion;
}

simd_float3 FxGripTransformPosition(simd_float4x4 transform)
{
	return transform.columns[3].xyz;
}

simd_quatf FxGripTransformOrientation(simd_float4x4 transform)
{
	simd_float3 x = transform.columns[0].xyz;
	simd_float3 y = transform.columns[1].xyz;
	simd_float3 z = transform.columns[2].xyz;

	const float epsilon = 1e-6f;
	if (simd_length(x) < epsilon || simd_length(y) < epsilon || simd_length(z) < epsilon) {
		return simd_quaternion(0.0f, simd_make_float3(0.0f, 1.0f, 0.0f));
	}

	simd_float3x3 basis = simd_matrix(simd_normalize(x), simd_normalize(y), simd_normalize(z));
	return simd_normalize(simd_quaternion(basis));
}

simd_float3 FxGripAngularVelocity(simd_quatf from, simd_quatf to, float seconds)
{
	if (seconds <= 0.0f) {
		return simd_make_float3(0.0f, 0.0f, 0.0f);
	}

	simd_quatf relative = simd_mul(to, simd_inverse(from));

	// Take the shortest arc: the double cover means q and -q are the same rotation.
	if (simd_real(relative) < 0.0f) {
		relative = simd_quaternion(-relative.vector);
	}

	float angle = simd_angle(relative);
	if (angle < 1e-6f) {
		return simd_make_float3(0.0f, 0.0f, 0.0f);
	}

	return simd_axis(relative) * (angle / seconds);
}

FxGripCameraMotion FxGripCameraMotionCentral(simd_float4x4 previous, simd_float4x4 next, float dt)
{
	if (dt <= 0.0f) {
		return FxGripCameraMotionZero();
	}

	float span = 2.0f * dt;
	FxGripCameraMotion motion;
	motion.linearVelocity = (FxGripTransformPosition(next) - FxGripTransformPosition(previous)) / span;
	motion.angularVelocity = FxGripAngularVelocity(FxGripTransformOrientation(previous), FxGripTransformOrientation(next), span);
	return motion;
}

FxGripCameraMotion FxGripCameraMotionForward(simd_float4x4 current, simd_float4x4 next, float dt)
{
	if (dt <= 0.0f) {
		return FxGripCameraMotionZero();
	}

	FxGripCameraMotion motion;
	motion.linearVelocity = (FxGripTransformPosition(next) - FxGripTransformPosition(current)) / dt;
	motion.angularVelocity = FxGripAngularVelocity(FxGripTransformOrientation(current), FxGripTransformOrientation(next), dt);
	return motion;
}

FxGripCameraMotion FxGripCameraMotionBackward(simd_float4x4 previous, simd_float4x4 current, float dt)
{
	if (dt <= 0.0f) {
		return FxGripCameraMotionZero();
	}

	FxGripCameraMotion motion;
	motion.linearVelocity = (FxGripTransformPosition(current) - FxGripTransformPosition(previous)) / dt;
	motion.angularVelocity = FxGripAngularVelocity(FxGripTransformOrientation(previous), FxGripTransformOrientation(current), dt);
	return motion;
}

float FxGripFocusDistance(simd_float3 cameraPosition, simd_float3 targetPosition)
{
	return simd_distance(cameraPosition, targetPosition);
}
