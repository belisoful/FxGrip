/*!
	@file       SCNCamera+FxGripTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     SCNCamera+FxGripTests
	@abstract   Tests for the SCNCamera+FxGrip category and its frustum-projection helpers.
	@discussion Introduced in FxGrip 0.1.0. The tests cover camera creation from a focal length, the field of view derived from focal length and sensor height, depth-of-field wiring, symmetric and asymmetric frustum projection matrices, the degenerate-frustum identity fallback, and exact projection setting the clip planes.
*/

#import <XCTest/XCTest.h>
#import <SceneKit/SceneKit.h>
#import <simd/simd.h>
#import <FxGrip/SCNCamera+FxGrip.h>

@interface SCNCamera_FxGripTests : XCTestCase
@end

@implementation SCNCamera_FxGripTests

/*! @abstract +fxg_cameraWithFocalLength:nearZ:farZ: sets the focal length, the 35mm sensor height, and the near and far clip planes. */
- (void)testFocalLengthAndClipPlanes
{
	SCNCamera *camera = [SCNCamera fxg_cameraWithFocalLength:50.0 nearZ:1.0 farZ:1000.0];
	XCTAssertEqualWithAccuracy(camera.focalLength, 50.0, 1e-6);
	XCTAssertEqualWithAccuracy(camera.sensorHeight, FxGripCamera35mmSensorHeight, 1e-6);
	XCTAssertEqualWithAccuracy(camera.zNear, 1.0, 1e-6);
	XCTAssertEqualWithAccuracy(camera.zFar, 1000.0, 1e-6);
}

/*! @abstract The camera's field of view matches the value derived from its focal length and sensor height. */
- (void)testFieldOfViewDerivesFromFocalLength
{
	SCNCamera *camera = [SCNCamera fxg_cameraWithFocalLength:50.0 nearZ:1.0 farZ:1000.0];
	double expectedDegrees = 2.0 * atan((FxGripCamera35mmSensorHeight / 2.0) / 50.0) * 180.0 / M_PI;
	XCTAssertEqualWithAccuracy(camera.fieldOfView, expectedDegrees, 0.5);
}

/*! @abstract -fxg_setFocusDistance:fStop: enables depth of field and sets the focus distance and f-stop. */
- (void)testDepthOfFieldWiring
{
	SCNCamera *camera = [SCNCamera fxg_cameraWithFocalLength:50.0 nearZ:1.0 farZ:1000.0];
	[camera fxg_setFocusDistance:12.0 fStop:2.8];
	XCTAssertTrue(camera.wantsDepthOfField);
	XCTAssertEqualWithAccuracy(camera.focusDistance, 12.0, 1e-6);
	XCTAssertEqualWithAccuracy(camera.fStop, 2.8, 1e-6);
}

/*! @abstract FxGripProjectionMatrixFromFrustum builds the expected projection matrix for a symmetric frustum. */
- (void)testSymmetricFrustumProjection
{
	simd_float4x4 p = FxGripProjectionMatrixFromFrustum(-1.0, 1.0, -1.0, 1.0, 1.0, 10.0);
	XCTAssertEqualWithAccuracy(p.columns[0].x, 1.0f, 1e-5);        // 2n/(r-l)
	XCTAssertEqualWithAccuracy(p.columns[1].y, 1.0f, 1e-5);        // 2n/(t-b)
	XCTAssertEqualWithAccuracy(p.columns[2].x, 0.0f, 1e-5);        // (r+l)/(r-l)
	XCTAssertEqualWithAccuracy(p.columns[2].y, 0.0f, 1e-5);        // (t+b)/(t-b)
	XCTAssertEqualWithAccuracy(p.columns[2].z, -11.0f / 9.0f, 1e-5); // -(f+n)/(f-n)
	XCTAssertEqualWithAccuracy(p.columns[2].w, -1.0f, 1e-5);
	XCTAssertEqualWithAccuracy(p.columns[3].z, -20.0f / 9.0f, 1e-5); // -2fn/(f-n)
	XCTAssertEqualWithAccuracy(p.columns[3].w, 0.0f, 1e-5);
}

/*! @abstract An asymmetric frustum offsets the projection center and scales the x term accordingly. */
- (void)testAsymmetricFrustumOffsetsCenter
{
	simd_float4x4 p = FxGripProjectionMatrixFromFrustum(-2.0, 1.0, -1.0, 1.0, 1.0, 10.0);
	XCTAssertEqualWithAccuracy(p.columns[2].x, -1.0f / 3.0f, 1e-5); // (r+l)/(r-l) = -1/3
	XCTAssertEqualWithAccuracy(p.columns[0].x, 2.0f / 3.0f, 1e-5);  // 2n/(r-l) = 2/3
}

/*! @abstract A degenerate frustum with zero width returns the identity matrix rather than a projection. */
- (void)testDegenerateFrustumReturnsIdentity
{
	simd_float4x4 p = FxGripProjectionMatrixFromFrustum(0.0, 0.0, -1.0, 1.0, 1.0, 10.0);
	XCTAssertEqualWithAccuracy(p.columns[0].x, 1.0f, 1e-6); // identity, not a projection
	XCTAssertEqualWithAccuracy(p.columns[2].w, 0.0f, 1e-6);
	XCTAssertEqualWithAccuracy(p.columns[3].w, 1.0f, 1e-6);
}

/*! @abstract -fxg_setProjectionFromFrustumLeft:right:bottom:top:near:far: sets the camera's near and far clip planes from the frustum. */
- (void)testExactProjectionSetsClipPlanes
{
	SCNCamera *camera = [SCNCamera fxg_cameraWithFocalLength:50.0 nearZ:1.0 farZ:1000.0];
	[camera fxg_setProjectionFromFrustumLeft:-1.0 right:1.0 bottom:-1.0 top:1.0 near:2.0 far:50.0];
	XCTAssertEqualWithAccuracy(camera.zNear, 2.0, 1e-6);
	XCTAssertEqualWithAccuracy(camera.zFar, 50.0, 1e-6);
}

@end
