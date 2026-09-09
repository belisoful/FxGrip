/*!
	@file       FxGripSceneKitEffect.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripSceneKitEffect
	@abstract   A tileable-effect template that renders a SceneKit scene through the host 3D camera and lights.
	@discussion Introduced in FxGrip 0.1.0. This file declares the SceneKit engine subclass of
	            `FxGripSpaceEffect`. The base captures the host camera and lights into plugin state;
	            this class builds a fresh SceneKit scene per render from that state and draws it into
	            the destination tile through the space backend. Subclass hooks add per-frame
	            parameters and scene content.
*/

#ifndef FxGripSceneKitEffect_h
#define FxGripSceneKitEffect_h

#import <SceneKit/SceneKit.h>
#import <FxGrip/FxGripSpaceEffect.h>
#import <FxGrip/FxGripSpaceBackend.h>

NS_ASSUME_NONNULL_BEGIN

/*!
	@class      FxGripSceneKitEffect
	@abstract   A tileable-effect template that renders a SceneKit scene through the host 3D camera
				and lights.
	@discussion Introduced in FxGrip 0.1.0. `FxGripSpaceEffect` captures the host camera and lights
				in the state pass and serializes them into plugin state along with view-matrix
				samples one frame on each side for velocity. At render time this class builds a
				SceneKit scene from that state and draws it into the destination tile through the
				space backend.

				The host renders frames concurrently on multiple threads, and re-renders and reorders
				them. The template therefore holds no scene state: `buildSceneWithCoder:...` builds a
				fresh scene from the per-frame coder on each render, so concurrent renders never share
				a scene. All per-frame state travels through plugin state, never through the effect.

				A plugin adds its own geometry in `updateSceneContents:cameraNode:fromCoder:atTime:cameraMotion:`,
				which receives the per-render scene. Expensive `SCNGeometry` and `SCNMaterial` are
				immutable once built and safe to cache on the plugin and reference from the per-render
				nodes; only nodes and transforms are created per frame. The built-in content, enabled
				by `rendersSourceLayerPlane`, places the source tile on a plane at the host layer
				transform.

				`spaceBackend` defaults to an `FxGripSceneKitMetalBackend`. When no source is present
				the template renders the scene alone; when the backend cannot render it copies the
				source unchanged.

				The inter-particle force configuration the base carries, `particleInteraction` and
				`particleInteractionFields`, is installed on the per-render scene after the apply hook
				runs: the scene-wide default reconciles every `SCNParticleSystem` that has none of
				its own, and each field entry is recreated as an `SCNPhysicsField` on its named node
				with the emitters under that node bound as its sources.

				Converting the host matrices into the SceneKit column-vector convention and deriving
				the camera-to-world transform is performed in the base and is the part of the
				subsystem that requires verification against a running Final Cut Pro or Motion host.
*/
@interface FxGripSceneKitEffect : FxGripSpaceEffect

/*! The engine that renders the scene into the tile. Defaults to `defaultSpaceBackend`; setting nil
	restores that default. The backend is shared across concurrent renders and is thread-safe. */
@property (nonatomic, strong, null_resettable) id<FxGripSpaceBackend> spaceBackend;

/*! The backend used when none is set. Defaults to an `FxGripSceneKitMetalBackend`. A subclass
	overrides to change the default engine. */
- (id<FxGripSpaceBackend>)defaultSpaceBackend;

/*!
	@property   physicsBakeEnabled
	@abstract   Runs a deterministic physics simulation and persists the bake with the document.
	@discussion Defaults to NO. Set at setup, before rendering. When set, `defaultSpaceBackend`
				becomes an `FxGripSceneKitPhysicsBackend` in session-cache mode, and the effect loads an
				`FxGripPhysicsBake` extension that backs the backend's store with the document, so the
				simulation fills lazily as frames render and survives a reopen. A custom `spaceBackend`
				that the plugin set is left in place; the bake applies only to a physics backend.
*/
@property (nonatomic, assign) BOOL physicsBakeEnabled;

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

#endif /* FxGripSceneKitEffect_h */
