//
//  FxGripSpaceEffect.h
//  FxGrip
//

#ifndef FxGripSpaceEffect_h
#define FxGripSpaceEffect_h

#import <SceneKit/SceneKit.h>
#import <simd/simd.h>
#import "FxGripTileableEffect.h"
#import "FxGripSpaceBackend.h"
#import "FxGripSpaceMotion.h"

@class FxImageTile;

NS_ASSUME_NONNULL_BEGIN

/*!
	@class      FxGripSpaceEffect
	@abstract   A tileable-effect template that renders a SceneKit scene through the host 3D camera
				and lights.
	@discussion Introduced in FxGrip 1.0. Captures the host camera and lights in the state pass
				(where the `Fx3DAPI_v5` and `FxLightingAPI_v3` APIs are valid), serializes them into
				plugin state along with view-matrix samples one frame on each side for velocity, and
				at render time builds a SceneKit scene from that state and draws it into the
				destination tile through the space backend.

				The host renders frames concurrently on multiple threads, and re-renders and reorders
				them. The template therefore holds no scene state: `buildSceneWithCoder:...` builds a
				fresh scene from the per-frame coder on each render, so concurrent renders never share
				a scene. All per-frame state travels through plugin state, never through the effect.

				A plugin adds its own geometry in `updateSceneContents:fromCoder:atTime:cameraMotion:`,
				which receives the per-render scene. Expensive `SCNGeometry` and `SCNMaterial` are
				immutable once built and safe to cache on the plugin and reference from the per-render
				nodes; only nodes and transforms are created per frame. The built-in content, enabled
				by `rendersSourceLayerPlane`, places the source tile on a plane at the host layer
				transform.

				`spaceBackend` defaults to an `FxGripSceneKitMetalBackend`. When no source is present
				the template renders the scene alone; when the backend cannot render it copies the
				source unchanged.

				The host reports matrices as `FxMatrix44` (double, row-major). Converting them into the
				SceneKit column-vector convention and deriving the camera-to-world transform is
				performed here and is the part of the subsystem that requires verification against a
				running Final Cut Pro or Motion host.
*/
@interface FxGripSpaceEffect : FxGripTileableEffect <FxGripTileableEffectCoderState>

/*! The engine that renders the scene into the tile. Defaults to `defaultSpaceBackend`; setting nil
	restores that default. The backend is shared across concurrent renders and is thread-safe. */
@property (nonatomic, strong, null_resettable) id<FxGripSpaceBackend> spaceBackend;

/*! The backend used when none is set. Defaults to an `FxGripSceneKitMetalBackend`. A subclass
	overrides to change the default engine. */
- (id<FxGripSpaceBackend>)defaultSpaceBackend;

/*! Places the source tile on a plane at the host layer transform. Defaults to YES. */
@property (nonatomic, assign) BOOL rendersSourceLayerPlane;

/*!
	@method     encodeSceneParametersIntoCoder:atTime:error:
	@abstract   A subclass hook, run in the capture pass, that serializes the plugin's own per-frame
				parameters into plugin state.
	@discussion The default does nothing and returns YES. FxGrip encodes the host camera and lights,
				then calls this. A subclass reads its parameters here, where the retrieval API is
				valid, and encodes the values the render pass needs, then reads them back in
				`updateSceneContents:cameraNode:fromCoder:atTime:cameraMotion:`. This pairs capture
				with apply so a subclass never overrides `pluginCoder:atTime:quality:error:` and never
				risks dropping the host camera and light capture.

				The coder is created fresh for each render, so this hook carries no shared state and is
				safe under the host's concurrent per-frame rendering.
*/
- (BOOL)encodeSceneParametersIntoCoder:(NSCoder *)coder
								atTime:(CMTime)renderTime
								 error:(NSError * _Nullable *)error;

/*!
	@method     updateSceneContents:cameraNode:fromCoder:atTime:cameraMotion:
	@abstract   A subclass hook, called once per render, to add the plugin's nodes to the per-render
				scene.
	@discussion The default does nothing. FxGrip has already added the camera, lights, and built-in
				layer plane to `scene`. `cameraNode` is the host camera node, the scene's point of
				view; a subclass reads or adjusts it (for example enabling depth of field on
				`cameraNode.camera` with the computed focus, or driving `motionBlurIntensity` from
				`cameraMotion`) and parents nodes to it to pin them to the camera. A subclass adds its
				own geometry, reading the decoded host state from `coder` (the `NSCoder(FxPlug)`
				decoders) and its own parameters (from `encodeSceneParametersIntoCoder:`). The scene
				is exclusive to this render; nodes and transforms are created here while cached
				geometry is reused.
*/
- (void)updateSceneContents:(SCNScene *)scene
				 cameraNode:(SCNNode *)cameraNode
				  fromCoder:(NSCoder *)coder
					 atTime:(CMTime)renderTime
			   cameraMotion:(FxGripCameraMotion)cameraMotion;

/*!
	@method     sceneTemplateNodeAtTime:
	@abstract   An optional authored content node that FxGrip serializes into plugin state and
				recreates for each render.
	@discussion The default returns nil, and the scene is built imperatively in
				`updateSceneContents:cameraNode:fromCoder:atTime:cameraMotion:`. A subclass returns a
				node subtree, its own content without the camera or lights, to have FxGrip archive it
				and add an independent copy to each render's scene. The apply hook still runs
				afterward, so a subclass combines a static authored template with per-frame
				adjustments (found by name on the recreated copy).

				Recreating from the archive gives each render its own node graph, so this style is
				concurrency-safe with no per-frame rebuild. FxGrip re-archives the template only when
				`sceneTemplateVersion` changes, so a static template serializes once. The archived
				graph is embedded in every frame's plugin state, so this style suits authored or
				imported scenes with light animation; a parameter-driven scene is cheaper to build
				imperatively.
*/
- (nullable SCNNode *)sceneTemplateNodeAtTime:(CMTime)renderTime;

/*!
	@method     sceneTemplateVersion
	@abstract   A revision number for the `sceneTemplateNodeAtTime:` content. Defaults to 0.
	@discussion FxGrip re-archives the template only when this value changes. A subclass returns a
				larger value after it mutates the authored node so the new content reaches the render.
*/
- (NSInteger)sceneTemplateVersion;

/*!
	@method     buildSceneWithCoder:sourceTile:atTime:pointOfView:
	@abstract   Builds a fresh SceneKit scene for one render from the decoded plugin state.
	@discussion Creates a new `SCNScene`, adds a camera node configured from the host camera (returned
				through `outPointOfView`), a lights container from the host lights, the built-in layer
				plane when enabled and a source is present, and calls
				`updateSceneContents:cameraNode:fromCoder:atTime:cameraMotion:`. Each call returns an
				independent scene, so renders on different threads do not share state.
*/
- (SCNScene *)buildSceneWithCoder:(NSCoder *)coder
					   sourceTile:(nullable FxImageTile *)sourceTile
						   atTime:(CMTime)renderTime
					  pointOfView:(SCNNode * _Nullable * _Nullable)outPointOfView;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripSpaceEffect_h */
