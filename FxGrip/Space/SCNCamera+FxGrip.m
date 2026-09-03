//
//  SCNCamera+FxGrip.m
//  FxGrip
//

#import "SCNCamera+FxGrip.h"

const CGFloat FxGripCamera35mmSensorHeight = 24.0;

simd_float4x4 FxGripProjectionMatrixFromFrustum(double left, double right,
												double bottom, double top,
												double near, double far)
{
	double rl = right - left;
	double tb = top - bottom;
	double fn = far - near;

	if (rl == 0.0 || tb == 0.0 || fn == 0.0) {
		return matrix_identity_float4x4;
	}

	// glFrustum, written as simd columns (column-vector convention, clip z in [-1, 1]).
	simd_float4 c0 = simd_make_float4((float)(2.0 * near / rl), 0.0f, 0.0f, 0.0f);
	simd_float4 c1 = simd_make_float4(0.0f, (float)(2.0 * near / tb), 0.0f, 0.0f);
	simd_float4 c2 = simd_make_float4((float)((right + left) / rl),
									  (float)((top + bottom) / tb),
									  (float)(-(far + near) / fn),
									  -1.0f);
	simd_float4 c3 = simd_make_float4(0.0f, 0.0f, (float)(-2.0 * far * near / fn), 0.0f);

	return simd_matrix(c0, c1, c2, c3);
}

@implementation SCNCamera (FxGrip)

+ (instancetype)fxg_cameraWithFocalLength:(double)focalLengthMillimeters
									nearZ:(double)nearZ
									 farZ:(double)farZ
{
	SCNCamera *camera = [SCNCamera camera];
	camera.sensorHeight = FxGripCamera35mmSensorHeight;
	camera.focalLength = focalLengthMillimeters;
	camera.zNear = nearZ;
	camera.zFar = farZ;
	return camera;
}

- (void)fxg_setProjectionFromFrustumLeft:(double)left right:(double)right
								  bottom:(double)bottom top:(double)top
									near:(double)near far:(double)far
{
	self.zNear = near;
	self.zFar = far;
	self.projectionTransform = SCNMatrix4FromMat4(FxGripProjectionMatrixFromFrustum(left, right, bottom, top, near, far));
}

- (void)fxg_setFocusDistance:(CGFloat)distance fStop:(CGFloat)fStop
{
	self.wantsDepthOfField = YES;
	self.focusDistance = distance;
	self.fStop = fStop;
}

@end
