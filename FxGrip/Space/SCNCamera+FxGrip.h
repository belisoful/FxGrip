//
//  SCNCamera+FxGrip.h
//  FxGrip
//

#ifndef SCNCamera_FxGrip_h
#define SCNCamera_FxGrip_h

#import <SceneKit/SceneKit.h>
#import <simd/simd.h>

NS_ASSUME_NONNULL_BEGIN

/*! The 35mm-equivalent sensor height, in millimeters, that pairs with an `Fx3DAPI` focal length so
	SceneKit derives the matching field of view. */
extern const CGFloat FxGripCamera35mmSensorHeight;

/*! A perspective projection from an asymmetric view frustum, in the SceneKit column-vector, z in
	[-1, 1] convention. The arguments are the `Fx3DAPI_v5` frustum bounds: left/right/bottom/top are
	the near-plane window edges and near/far are positive clip-plane distances. */
simd_float4x4 FxGripProjectionMatrixFromFrustum(double left, double right,
												double bottom, double top,
												double near, double far);

/*!
	@category   SCNCamera (FxGrip)
	@abstract   Builds a SceneKit camera from FxPlug host camera data.
	@discussion Introduced in FxGrip 1.0. The `Fx3DAPI_v5` host API reports the camera focal length,
				view and projection matrices, and view frustum. These methods configure an `SCNCamera`
				from that data. `fxg_cameraWithFocalLength:nearZ:farZ:` sets the focal length and a
				35mm-equivalent sensor height, so SceneKit derives the field of view, along with the
				near and far clip planes. `fxg_setProjectionFromFrustumLeft:...` installs the exact
				host projection when an asymmetric or otherwise non-standard frustum requires it.

				The camera node transform (camera-to-world) is the caller's responsibility, built from
				the host view matrix, because converting the host `FxMatrix44` (double, row-major) into
				the SceneKit column-vector convention and inverting it belongs with the effect that
				reads the host state.
*/
@interface SCNCamera (FxGrip)

/*! A camera whose field of view derives from `focalLengthMillimeters` against a 35mm sensor, with the
	given near and far clip-plane distances. */
+ (instancetype)fxg_cameraWithFocalLength:(double)focalLengthMillimeters
									nearZ:(double)nearZ
									 farZ:(double)farZ;

/*! Replaces the projection with the exact host frustum. Use when the host frustum is asymmetric. */
- (void)fxg_setProjectionFromFrustumLeft:(double)left right:(double)right
								  bottom:(double)bottom top:(double)top
									near:(double)near far:(double)far;

/*! Enables depth of field focused at `distance` world units with aperture `fStop`. */
- (void)fxg_setFocusDistance:(CGFloat)distance fStop:(CGFloat)fStop;

@end

NS_ASSUME_NONNULL_END

#endif /* SCNCamera_FxGrip_h */
