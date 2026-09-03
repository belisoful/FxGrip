# 3D Space Effects

Render a SceneKit scene through the host's 3D camera and lights into the Metal tile.

## Overview

FxGrip is the FxPlug harness for a 3D effect. It reads the host camera and lights, builds a
SceneKit scene for each frame, and draws it into the destination tile with Metal. SceneKit
supplies the scene graph, camera, lights, geometry, materials, and the renderer. FxGrip supplies
the bridge from the FxPlug host into SceneKit and the render driver that targets the tile.

An effect subclasses ``FxGripSpaceEffect``. The template captures the host camera and lights where
the host APIs are valid, serializes them into plugin state, and at render time builds the scene and
hands it to the backend. With the built-in layer plane enabled, the source tile appears in the host
3D scene with no plugin code.

### The frame

The host runs two passes for each frame.

- Capture pass → the retrieval, `Fx3DAPI_v5`, and `FxLightingAPI_v3` APIs are valid.
  ``FxGripSpaceEffect`` encodes the camera, the lights, and view-matrix samples one frame on each
  side into plugin state, then calls the plugin's capture seam.
- Render pass → the host APIs are invalid and only plugin state is available. The template decodes
  that state, builds a scene, and renders it into the tile.

The host renders frames concurrently, out of order, and re-renders them. Plugin state is the only
per-frame channel that survives this, so every value the render needs travels through it.

### Building the scene

`buildSceneWithCoder:sourceTile:atTime:pointOfView:` constructs a fresh SceneKit scene for each
render from the decoded state:

- a camera node, configured from the host focal length, frustum, and view matrix, returned as the
  point of view
- a lights container, one SceneKit light for each host light
- the built-in layer plane, the source tile on a plane at the host layer transform, when
  `rendersSourceLayerPlane` is set
- the plugin's own nodes, added through the apply seam

Each call returns an independent scene. Concurrent renders share no scene state.

### The two seams

A plugin contributes through two hooks and touches neither Metal nor the tile.

- `encodeSceneParametersIntoCoder:atTime:error:` runs in the capture pass. A subclass reads its
  parameters, where the retrieval API is valid, and encodes the values the render needs.
- `updateSceneContents:cameraNode:fromCoder:atTime:cameraMotion:` runs in the render pass. A
  subclass adds its nodes to the per-render scene, reads its values back from the coder, adjusts
  `cameraNode` when needed, and uses the supplied camera motion.

A subclass overrides these two hooks. Overriding them keeps the host camera and light capture that
`pluginCoder:atTime:quality:error:` performs.

### Two authoring styles

The seams above build the scene imperatively from decoded values. A plugin that already holds a scene
object, imported from a file or assembled in an inspector, uses the declarative style instead.
`sceneTemplateNodeAtTime:` returns an authored content node; FxGrip archives it into plugin state
and adds an independent copy to each render's scene. `SCNScene` and `SCNNode` conform to
`NSSecureCoding`, so the graph serializes and recreates through the coder, and the recreation gives
each render its own copy with no per-frame rebuild.

The two styles compose. A subclass returns a static authored node from `sceneTemplateNodeAtTime:`
and still adjusts the recreated copy per frame in the apply seam, found by name. FxGrip re-archives
the template only when `sceneTemplateVersion` changes, so a static template serializes once. The
archived graph rides in every frame's plugin state, so the template style suits authored or imported
scenes with light animation, and the imperative style suits a scene derived from parameters.

### Concurrency

Renders run on several threads at once, so ``FxGripSpaceEffect`` holds no scene, node, or velocity
state. The scene is a pure function of the coder, built for each render. The apply seam runs on the
render thread and reads only immutable plugin state.

`SCNGeometry` and `SCNMaterial` are immutable once built and safe to reference from many scenes. A
plugin caches them once and creates a light `SCNNode` for each render that points at the cached
geometry. ``FxGripSceneKitMetalBackend`` pools an `SCNRenderer` for each device, so every in-flight
render borrows its own renderer.

### Animation

Two models drive change over time.

- Reconfigure the scene for each frame from time-sampled parameters. The render stays a pure
  function of time and reproduces any frame in any order. Use this model for anything derived from a
  host parameter or the host camera.
- Attach a `CAAnimation` or `SCNAction` and let SceneKit evaluate it at the render time. This suits
  self-contained procedural motion. Express the animation in an absolute time base with a fixed
  `beginTime`, because "start now" has no stable meaning when the host renders frames out of order.

The render time is the effect's clip time, which follows trims and retiming. The project timeline
time comes from `timelineTime:fromInputTime:`, which reads the timing API and is valid only in the
capture pass, so a project-anchored animation captures its time into plugin state. Physics and
particle systems integrate state forward and do not reproduce an arbitrary frame; bake them to
per-frame values instead.

### Camera velocity and focus

The host reports the camera position, no velocity, and no focus distance. FxGrip derives the last
two. `FxGripSpaceMotion` computes the camera's linear and angular velocity by central difference of
the view-matrix samples the capture pass stored. The velocity reaches the apply seam as
`cameraMotion`, which a plugin feeds to `motionBlurIntensity` or its own motion-blur pass. The
autofocus distance is the distance from the camera to the layer origin, which a plugin sets on
`cameraNode.camera` with an aperture to drive SceneKit depth of field.

### A worked example

A spinning card that carries the source image and composites in the host 3D scene:

```objc
@implementation FxSpaceCardExample
{
    SCNGeometry *_card; // immutable, built once, shared across renders
}

- (SCNGeometry *)card
{
    @synchronized (self) {
        if (_card == nil) {
            _card = [SCNBox boxWithWidth:1.0 height:1.0 length:0.05 chamferRadius:0.02];
        }
        return _card;
    }
}

/*! Capture: read the angle parameter where the retrieval API is valid. */
- (BOOL)encodeSceneParametersIntoCoder:(NSCoder *)coder atTime:(CMTime)time error:(NSError **)error
{
    [coder encodeDouble:[self cardAngleAtTime:time] forKey:@"angle"];
    return YES;
}

/*! Apply: build this frame's node from the decoded angle, and focus the camera on it. */
- (void)updateSceneContents:(SCNScene *)scene
                 cameraNode:(SCNNode *)cameraNode
                  fromCoder:(NSCoder *)coder
                     atTime:(CMTime)time
               cameraMotion:(FxGripCameraMotion)cameraMotion
{
    SCNNode *card = [SCNNode nodeWithGeometry:self.card];
    card.simdOrientation = simd_quaternion((float)[coder decodeDoubleForKey:@"angle"],
                                           simd_make_float3(0.0f, 1.0f, 0.0f));
    [scene.rootNode addChildNode:card];

    cameraNode.camera.wantsDepthOfField = YES;
    cameraNode.camera.focusDistance = simd_length(card.simdPosition - cameraNode.simdPosition);
}
@end
```

### The backend

``FxGripSpaceBackend`` is the render-driver contract: a readiness flag, an identifier, and one
method that renders a scene through a point of view into an `id<MTLTexture>`.
``FxGripSceneKitMetalBackend`` is the shipped driver. It pools a Metal `SCNRenderer` for each
device, builds a render pass whose color attachment is the tile texture and whose depth attachment
comes from the device cache, and draws through a pooled command queue.

A plugin that needs a render pipeline beyond SceneKit implements ``FxGripSpaceBackend`` and installs
it through `spaceBackend`. Customization inside SceneKit uses `SCNTechnique` on the scene and
`SCNProgram` or shader modifiers on a material, set on the scene objects in the apply seam.

The host bridge is a pair of categories. `SCNCamera(FxGrip)` builds a camera from the host focal
length and frustum and installs SceneKit depth of field. `SCNLight(FxGrip)` maps one `FxLight` to a
SceneKit light node.

## Topics

### Effect template

- ``FxGripSpaceEffect``

### The render driver

- ``FxGripSpaceBackend``
- ``FxGripSceneKitMetalBackend``
