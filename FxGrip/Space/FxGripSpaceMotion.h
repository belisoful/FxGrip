//
//  FxGripSpaceMotion.h
//  FxGrip
//

#ifndef FxGripSpaceMotion_h
#define FxGripSpaceMotion_h

#import <Foundation/Foundation.h>
#import <simd/simd.h>

/*!
	@header     FxGripSpaceMotion
	@abstract   Camera motion and focus quantities the FxPlug host does not supply, derived from
				sampled scene transforms.
	@discussion Introduced in FxGrip 1.0. The `Fx3DAPI_v5` host API reports the camera view and
				layer matrices at a given time but no velocity, and no focus distance. The 3D Space
				subsystem samples those matrices at t-dt, t, and t+dt (the existing keyed
				`NSCoder(FxPlug)` scene encoders store the extra samples) and turns them into the
				values a 3D-aware effect needs: linear and angular camera velocity for motion blur,
				and the camera-to-layer distance for autofocus. SceneKit consumes these directly
				through `SCNCamera.motionBlurIntensity` and `SCNCamera.focusDistance`.

				Every function takes transforms in the standard simd column-vector convention: a
				point p maps as `M * (p, 1)`, the translation is `columns[3].xyz`, and the
				upper-left 3x3 is rotation times scale. This matches `SCNNode.simdTransform` and a
				camera-to-world (inverse view) matrix. Converting the host `FxMatrix44`
				(double, row-major) into this convention is the caller's concern, handled by the
				host-to-SceneKit configuration layer, not here.

				The same functions compute object motion when fed model-to-world transforms.
*/

/*! Linear and angular velocity of a sampled transform. */
typedef struct FxGripCameraMotion {
	/*! World units per second. */
	simd_float3 linearVelocity;
	/*! Radians per second, as the rotation axis scaled by angular speed. */
	simd_float3 angularVelocity;
} FxGripCameraMotion;

/*! Zero motion. */
FxGripCameraMotion FxGripCameraMotionZero(void);

/*! World-space position of a transform: its translation column. */
simd_float3 FxGripTransformPosition(simd_float4x4 transform);

/*! Orientation of a transform's upper-left 3x3 as a unit quaternion. Columns are normalized to drop
	scale; a degenerate basis returns the identity quaternion. */
simd_quatf FxGripTransformOrientation(simd_float4x4 transform);

/*! The angular velocity carrying `from` to `to` over `seconds`: the shortest-arc rotation axis
	scaled by radians per second. Zero when `seconds` is not positive or the rotation is negligible. */
simd_float3 FxGripAngularVelocity(simd_quatf from, simd_quatf to, float seconds);

/*! Central-difference motion from two samples `dt` seconds on each side of the center: `previous` at
	t-dt and `next` at t+dt, so the pair spans 2·dt. Zero motion when `dt` is not positive. */
FxGripCameraMotion FxGripCameraMotionCentral(simd_float4x4 previous, simd_float4x4 next, float dt);

/*! Forward-difference motion from `current` at t to `next` at t+dt. Zero motion when `dt` is not
	positive. Use at the first sampled frame, where no earlier sample exists. */
FxGripCameraMotion FxGripCameraMotionForward(simd_float4x4 current, simd_float4x4 next, float dt);

/*! Backward-difference motion from `previous` at t-dt to `current` at t. Zero motion when `dt` is not
	positive. Use at the last sampled frame, where no later sample exists. */
FxGripCameraMotion FxGripCameraMotionBackward(simd_float4x4 previous, simd_float4x4 current, float dt);

/*! The autofocus distance: the straight-line distance from the camera position to a target point,
	the layer or object origin in world space. */
float FxGripFocusDistance(simd_float3 cameraPosition, simd_float3 targetPosition);

#endif /* FxGripSpaceMotion_h */
