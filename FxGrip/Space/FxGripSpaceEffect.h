/*!
	@file       FxGripSpaceEffect.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-09
	@header     FxGripSpaceEffect
	@abstract   The engine-neutral base of a 3D Space effect: host camera and light capture, per-frame
	            decoding, and the full-frame render contract.
	@discussion Introduced in FxGrip 0.1.0. This file declares the base that every 3D Space effect
	            template subclasses. It captures the host camera, lights, and view-matrix samples into
	            plugin state where the host APIs are valid, decodes them for the render pass, and
	            defines the seams a render engine and a plugin fill in. It imports no render engine.
	            `FxGripSceneKitEffect` is the shipped SceneKit engine subclass.
*/

#ifndef FxGripSpaceEffect_h
#define FxGripSpaceEffect_h

#import <Metal/Metal.h>
#import <simd/simd.h>
#import "FxGripTileableEffect.h"
#import "FxGripSpaceMotion.h"
#import "FxGripParticleInteraction.h"

@class FxImageTile;

NS_ASSUME_NONNULL_BEGIN

/*!
	@class      FxGripSpaceEffect
	@abstract   The engine-neutral base of a 3D Space effect template.
	@discussion Introduced in FxGrip 0.1.0. The base owns the part of a 3D effect that does not
				depend on a render engine. In the capture pass, where the `Fx3DAPI_v5` and
				`FxLightingAPI_v3` APIs are valid, it encodes the host camera, the host lights,
				view-matrix samples one frame on each side for velocity, and the inter-particle force
				configuration into plugin state. In the render pass it decodes that state through the
				helpers declared here and hands the render to the engine subclass.

				The host renders frames concurrently on multiple threads, and re-renders and reorders
				them. The base holds no per-frame state: every value a render needs travels through
				plugin state, and every helper here is a pure function of the coder.

				Two kinds of subclass fill the seams.

				- An engine subclass, such as `FxGripSceneKitEffect`, overrides
				  `encodeEngineStateIntoCoder:atTime:error:` to add engine-specific state to the
				  capture and `renderSceneFromCoder:sourceTile:toTexture:atTime:error:` to draw the
				  frame. The default render copies the source unchanged.
				- A plugin subclasses an engine subclass and overrides
				  `encodeSceneParametersIntoCoder:atTime:error:` plus the engine's apply hook.

				The host reports matrices as `FxMatrix44` (double, row-major). The decode helpers
				return them in the simd column-vector convention `FxGripSpaceMotion` documents, and
				`decodeCameraTransform:fromCoder:` already inverts the host view matrix into the
				camera-to-world transform an engine places its camera with.
*/
@interface FxGripSpaceEffect : FxGripTileableEffect <FxGripTileableEffectCoderState>

/*! Places the source tile on a plane at the host layer transform. Defaults to YES. The engine
	subclass honors the flag when it builds the frame. */
@property (nonatomic, assign) BOOL rendersSourceLayerPlane;

/*!
	@property   particleInteraction
	@abstract   The scene-wide default inter-particle force for the rendered frame.
	@discussion Introduced in FxGrip 0.1.0. Setting this gives every particle system in the rendered
				frame a mutual gravity, electric, or magnetic force, except a system that carries its
				own interaction, which keeps it. Set it in the capture pass, where the base serializes
				it into plugin state; the engine subclass decodes it each render with
				`decodeParticleInteractionFromCoder:` and installs it. The value here is the durable
				record and the per-render installation is what makes it live.
*/
@property (nonatomic, copy, nullable) FxGripParticleInteraction *particleInteraction;

/*!
	@property   particleInteractionFields
	@abstract   Inter-particle forces installed as fields, keyed by the name of the node that carries
	            each one.
	@discussion Introduced in FxGrip 0.1.0. An entry names a node in the rendered frame and the force
	            that node's field applies. The base serializes the dictionary into plugin state; the
	            engine subclass decodes it each render with `decodeParticleInteractionFieldsFromCoder:`
	            and recreates each field on its named node. A system bound to a field is skipped by
	            the scene-wide default, so the two compose.
*/
@property (nonatomic, copy, nullable) NSDictionary<NSString *, FxGripParticleInteraction *> *particleInteractionFields;

#pragma mark Capture seams

/*!
	@method     encodeSceneParametersIntoCoder:atTime:error:
	@abstract   A plugin hook, run in the capture pass, that serializes the plugin's own per-frame
				parameters into plugin state.
	@discussion The default does nothing and returns YES. FxGrip encodes the host camera, lights,
				interactions, and engine state, then calls this last and returns its result. A
				plugin reads its parameters here, where the retrieval API is valid, and encodes the
				values the render pass needs, then reads them back in the engine's apply hook. This
				pairs capture with apply so a plugin never overrides `pluginCoder:atTime:quality:error:`
				and never risks dropping the host camera and light capture.

				The coder is created fresh for each render, so this hook carries no shared state and is
				safe under the host's concurrent per-frame rendering.
*/
- (BOOL)encodeSceneParametersIntoCoder:(NSCoder *)coder
								atTime:(CMTime)renderTime
								 error:(NSError * _Nullable *)error;

/*!
	@method     encodeEngineStateIntoCoder:atTime:error:
	@abstract   An engine hook, run in the capture pass after the host state and before the plugin
				seam, that serializes engine-specific state into plugin state.
	@discussion The default does nothing and returns YES. An engine subclass overrides it for state
				that belongs to the engine and not to the plugin, such as an archived authored scene
				template. Returning NO with an error fails the capture.
*/
- (BOOL)encodeEngineStateIntoCoder:(NSCoder *)coder
							atTime:(CMTime)renderTime
							 error:(NSError * _Nullable *)error;

#pragma mark Render seam

/*!
	@method     renderSceneFromCoder:sourceTile:toTexture:atTime:error:
	@abstract   An engine hook that draws one frame from the decoded plugin state into the
				destination texture.
	@discussion The base implementation is the passthrough: it copies `sourceTile` into `texture`
				with `blitTile:toTexture:error:`, or succeeds with no source. An engine subclass
				overrides it to build and draw its scene, and calls the base when its renderer cannot
				run so the source shows unchanged. `renderTime` is the effect's clip time. The
				destination texture is already resolved and non-nil.
*/
- (BOOL)renderSceneFromCoder:(NSCoder *)coder
				  sourceTile:(nullable FxImageTile *)sourceTile
				   toTexture:(id<MTLTexture>)texture
					  atTime:(CMTime)renderTime
					   error:(NSError * _Nullable *)error;

#pragma mark Decoding the host state

/*!
	@method     decodeCameraTransform:fromCoder:
	@abstract   The host camera's camera-to-world transform, the inverse of the encoded view matrix.
	@discussion Returns NO and leaves `transform` unchanged when the coder holds no view matrix. The
				result is in the simd column-vector convention, ready for a camera node or entity
				transform.
*/
- (BOOL)decodeCameraTransform:(simd_float4x4 *)transform fromCoder:(NSCoder *)coder;

/*!
	@method     decodeLayerTransform:fromCoder:
	@abstract   The host layer's model-to-world transform.
	@discussion Returns NO and leaves `transform` unchanged when the coder holds no model matrix. The
				result is in the simd column-vector convention. The source layer plane sits at this
				transform.
*/
- (BOOL)decodeLayerTransform:(simd_float4x4 *)transform fromCoder:(NSCoder *)coder;

/*!
	@method     cameraMotionFromCoder:
	@abstract   The camera's linear and angular velocity at the frame, by central difference of the
				view-matrix samples one frame on each side.
	@discussion Returns zero motion when either sample is absent, which is the case when the frame
				duration was unknown at capture. An engine feeds the result to its motion blur.
*/
- (FxGripCameraMotion)cameraMotionFromCoder:(NSCoder *)coder;

/*! The scene-wide interaction captured from `particleInteraction`, or nil when none was set. */
- (nullable FxGripParticleInteraction *)decodeParticleInteractionFromCoder:(NSCoder *)coder;

/*! The field configurations captured from `particleInteractionFields`, or nil when none were set. */
- (nullable NSDictionary<NSString *, FxGripParticleInteraction *> *)decodeParticleInteractionFieldsFromCoder:(NSCoder *)coder;

#pragma mark Render utilities

/*!
	@method     blitTile:toTexture:error:
	@abstract   Copies the source tile's texture into the destination texture, clipped to the smaller
				of the two.
	@discussion Uses a pooled command queue from `FxGripMTLDeviceCache` and waits for completion.
				Succeeds without copying when the source tile has no Metal texture. Returns NO with an
				error when no command queue is available.
*/
- (BOOL)blitTile:(FxImageTile *)sourceTile toTexture:(id<MTLTexture>)texture error:(NSError * _Nullable *)error;

/*! An `FxGripPlugErrorDomain` error with the `kFxGripError_SpaceRenderFailure` code and `reason`
	as its localized description. */
- (NSError *)spaceErrorWithReason:(NSString *)reason;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripSpaceEffect_h */
