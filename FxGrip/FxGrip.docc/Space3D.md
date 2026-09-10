# 3D Space Effects

Render a 3D scene through the host's 3D camera and lights into the Metal tile.

## Overview

FxGrip is the FxPlug harness for a 3D effect. It reads the host camera and lights, builds a
SceneKit scene for each frame, and draws it into the destination tile with Metal. SceneKit
supplies the scene graph, camera, lights, geometry, materials, and the renderer. FxGrip supplies
the bridge from the FxPlug host into SceneKit and the render driver that targets the tile.

The subsystem is split at the render engine. ``FxGripSpaceEffect`` is the engine-neutral base: it
captures the host camera and lights where the host APIs are valid, serializes them into plugin
state, and decodes them for the render. ``FxGripSceneKitEffect`` is the SceneKit engine subclass:
at render time it builds the scene from that state and hands it to the backend. A plugin subclasses
the engine class. With the built-in layer plane enabled, the source tile appears in the host 3D
scene with no plugin code.

The source folders follow the split. `Space/` holds the base and the engine-neutral parts: camera
motion, the deterministic simulation store, the inter-particle force configuration, and the Fast
Multipole Method core. `Space/SceneKit/` holds everything that imports SceneKit. SceneKit is
deprecated as of WWDC25 in favor of RealityKit, and the RealityKit engine lives outside this
framework, in the `FxGripRealityKit` module described below.

### The frame

The host runs two passes for each frame.

- Capture pass → the retrieval, `Fx3DAPI_v5`, and `FxLightingAPI_v3` APIs are valid.
  ``FxGripSpaceEffect`` encodes the camera, the lights, view-matrix samples one frame on each side,
  and the inter-particle force configuration into plugin state, then calls the engine's capture
  hook and last the plugin's capture seam.
- Render pass → the host APIs are invalid and only plugin state is available. The base resolves the
  destination texture and calls the engine's render hook, which decodes the state, builds a scene,
  and renders it into the tile. The base's own render hook is the passthrough: the source copied
  unchanged, which an engine falls back to when its renderer cannot run.

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

- `encodeSceneParametersIntoCoder:atTime:error:`, on the base, runs in the capture pass. A subclass
  reads its parameters, where the retrieval API is valid, and encodes the values the render needs.
- `updateSceneContents:cameraNode:fromCoder:atTime:cameraMotion:`, on the SceneKit engine, runs in
  the render pass. A subclass adds its nodes to the per-render scene, reads its values back from the
  coder, adjusts `cameraNode` when needed, and uses the supplied camera motion.

A subclass overrides these two hooks. Overriding them keeps the host camera and light capture that
`pluginCoder:atTime:quality:error:` performs.

An engine contributes through two hooks of its own on the base. `encodeEngineStateIntoCoder:atTime:error:`
adds engine-specific state to the capture; the SceneKit engine archives the scene template there.
`renderSceneFromCoder:sourceTile:toTexture:atTime:error:` draws the frame. The base's decode helpers
serve any engine: `decodeCameraTransform:fromCoder:` returns the camera-to-world transform,
`decodeLayerTransform:fromCoder:` the layer transform, `cameraMotionFromCoder:` the camera velocity,
and the two interaction decoders the inter-particle force configuration, each in the simd
column-vector convention with no reference to a scene graph.

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
capture pass, so a project-anchored animation captures its time into plugin state.

### Deterministic physics

Physics integrates state forward, so a naive per-render step does not reproduce an arbitrary or
re-rendered frame. ``FxGripSceneKitPhysicsBackend`` makes it deterministic by fixed-step catch-up:
for a frame it simulates from the start to that frame in fixed `timeStep` increments on the render's
own physics world, driving `updateAtTime:` (the Metal render path does not step a simulation on its
own). The same frame reproduces in any order.

Three modes trade cost against storage. `Recompute` runs the whole catch-up on every render.
`SessionCache` memoizes each step's body transforms and replays them, so the simulation runs once
per step. Adding the ``FxGripPhysicsBake`` extension swaps the session store for one backed by an
`FxGripFrameData`, so the bake fills lazily as frames render and persists with the document; the
records are a transform per dynamic body per frame and stay inline with no media-folder spill. A
body is cached by its node name, so name any body to bake.

The store and the mode are engine-neutral. ``FxGripPhysicsSimulationStore``,
``FxGripPhysicsMemoryStore``, ``FxGripPhysicsFrameDataStore``, and the simulation mode live beside
the base and serve either engine. ``FxGripPhysicsBake`` names no engine: it hands its store to
`installPhysicsSimulationStore:` on ``FxGripSpaceEffect``, which each engine implements for its own
backend. The base refuses, and an engine whose backend does not simulate refuses too, which leaves
the bake inert rather than failing.

Particle systems reproduce under the same catch-up. `SCNParticleSystem` has no random seed, so a
stock system varies its particles differently on every re-simulation. ``FxGripParticleSystem`` is a
drop-in subclass that holds SceneKit's own variation at zero and reintroduces velocity, size, life
span, color, angle, and spreading-angle variation from a `seed` keyed by each particle's birth
index through `FxGripParticleRand`, the engine-neutral variation function the RealityKit engine's
particle system shares. The physics backend resets every system before the catch-up, so a frame
re-emits the same particles from the start. The seed and variation archive with the system, so a
system inside a scene template stays deterministic when decoded. `initWithParticleSystem:` converts
an authored or loaded system in place. Particles respond to `SCNPhysicsField` and colliders as
usual; SceneKit computes no particle-to-particle forces.

### Inter-particle forces

SceneKit particles respond to fields and colliders, never to each other, so mutual gravity or a
Coulomb force between particles is not built in. FxGrip adds it through the ``FxGripParticleInteraction``
configuration and the `particleInteraction` property the `SCNParticleSystem` category adds. Setting an
enabled interaction installs a pre-dynamics modifier that, each step, gathers the particles, evaluates
the force with a Fast Multipole Method in linear time, and adds the acceleration to the velocities.

The forces are a bit field, so they combine. Gravity uses the system's `particleMass`, electric and
magnetic use its `particleCharge` and the particle velocity. Gravity and electric share one field
evaluation and differ only in their coupling; magnetic adds the Biot-Savart term, so the electric and
magnetic bits together are the Lorentz force. The accuracy tier sets the multipole order, and the
softening length bounds the near force so a tight cluster stays finite.

The force is deterministic: the field is a fixed function of the gathered state, so under the physics
backend's fixed-step catch-up a frame reproduces. The evaluation is allocation-free once warm, and it
runs in parallel with a result independent of the thread count. An `SCNScene` may carry a default
interaction that `fxgrip_reconcileParticleInteractions` applies to every system that has none of its
own, and an ``FxGripParticleSystem`` archives its interaction, so a system in a scene template stays
configured. A modifier does not survive an archive, so the reconciliation reinstalls the force after
the scene is built.

An ``FxGripSceneKitEffect`` carries the whole arrangement for a plugin. Set the base's
`particleInteraction` in the capture pass and FxGrip serializes it into plugin state, then each
render decodes it onto the scene and reconciles every particle system, including one the apply hook
just created.

### The force as a physics field

The same force is also available as a SceneKit physics field, through the class factory the
`SCNPhysicsField` category adds. A custom field evaluator receives one target's position, velocity,
mass, charge, and time, with no reference to the particle collection, so the field alone cannot
compute a mutual force. The facade pairs it with a companion modifier: the modifier records a bound
system's particles once per step, and the evaluator queries the expansion built from them. Building
is linear in the particle count, and a query is a fixed cost per target: the leaf holding the point
carries the local expansion of the whole far field, so the query is one local evaluation plus the
near leaves the multipole could not cover.

Create the field with `particleInteractionFieldWithInteraction:`, assign it to a node's
`physicsField`, and bind its sources with `bindParticleInteractionToParticleSystemsInNode:`, which
takes every emitter on a node and its descendants. The standard field controls then apply:
`halfExtent`, `scope`, `categoryBitMask`, and `active` all shape where the force reaches.

Several systems may feed one field, and their particles then attract or repel each other across
systems. Each system contributes its own `particleMass` and `particleCharge`, so a heavy cloud and a
light one interact correctly. SceneKit runs every particle modifier before any field evaluation
within a step, so every bound system is current when the field is queried.

Two behaviors decide how the field couples. SceneKit applies a custom field's vector to a particle
unchanged and divides it by a rigid body's mass, so the vector is the particle acceleration and a
body in range feels that vector over its own mass; restrict the field with `categoryBitMask` when
only particles should respond. The modifier records positions in the system's simulation space while
the evaluator receives world-space targets, so leave `local` clear on a bound system.

Choose between the two shapes by what the force must reach. The `SCNParticleSystem` property is the
short path for a system that acts on itself. The field is the SceneKit-idiomatic path, composes with
the field controls, spans several systems, and couples rigid bodies to the particle cloud. Both
reserve the pre-dynamics modifier stage, so a system uses one or the other, never both, and a system
bound to a field is skipped by the scene-wide default.

An ``FxGripSceneKitEffect`` persists both shapes. The base's `particleInteraction` is the scene-wide
default, and its `particleInteractionFields` names the nodes that carry fields and the force each one
applies.
A field's evaluation block survives neither an archive nor a copy, so these are the durable record
and the per-render reconciliation is what makes them live: each render recreates the field on its
named node and binds the emitters under it.

The accuracy tier is the speed dial. On an M1 Max at twenty thousand particles, the field costs about
1.6 microseconds per particle per step at Draft, 3.8 at Standard, and 11.3 at Fine, most of it in the
build the whole system shares rather than in the per-particle query. Magnetic adds three more
expansion channels over the same tree, which multiplies the expansion work but not the tree.

### Camera velocity and focus

The host reports the camera position, no velocity, and no focus distance. FxGrip derives the last
two. `FxGripSpaceMotion` computes the camera's linear and angular velocity by central difference of
the view-matrix samples the capture pass stored, through the base's `cameraMotionFromCoder:`. The
velocity reaches the apply seam as `cameraMotion`, which a plugin feeds to `motionBlurIntensity` or its own motion-blur pass. The
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

### The RealityKit engine, Swift only

``FxGripSpaceEffect`` is engine-neutral, and a second engine subclasses it. That engine is
`FxGripRealityKitEffect`, in the separate `FxGripRealityKit` framework, and it is written in Swift.

RealityKit publishes no Objective-C interface. `RealityFoundation` ships a Swift module, and the
headers inside `RealityKit.framework` are Metal shader headers. An Objective-C RealityKit engine is
therefore not possible, and a plugin that subclasses `FxGripRealityKitEffect` is a Swift plugin. A
plugin that requires Objective-C subclasses ``FxGripSceneKitEffect``, which loses nothing outside
that module.

The RealityKit engine requires macOS 15, the release that introduced `RealityRenderer`, which is the
only offscreen render path RealityKit offers. FxGrip runs on macOS 13.5, so linking the RealityKit
module raises a plugin's floor to macOS 15.

Swift reaches Objective-C through clang modules, so FxGrip defines a module and the repository
carries `Modules/FxPlug/module.modulemap` for Apple's FxPlug SDK, which ships none. A Swift target
that imports FxGrip passes that file to the clang importer.

The engine inherits the whole engine-neutral base, including the inter-particle force
configuration, which it applies to particle systems it simulates itself, because RealityKit's own
particle emitter has no seed and exposes no per-particle state. Camera motion blur and depth of
field, which SceneKit provides on `SCNCamera`, are a Metal pass over the drawn tile in that engine,
driven by the same camera velocity and autofocus distance. The `FxGripRealityKit` documentation
covers the engine itself.

### The backend

``FxGripSceneKitBackend`` is the SceneKit render-driver contract: a readiness flag, an identifier, and
one method that renders an `SCNScene` through a point of view into an `id<MTLTexture>`. The
``FxGripSceneKitEffect`` owns the backend; the engine-neutral base has no backend of its own.
``FxGripSceneKitMetalBackend`` is the shipped driver. It pools a Metal `SCNRenderer` for each
device, builds a render pass whose color attachment is the tile texture and whose depth attachment
comes from the device cache, and draws through a pooled command queue.

A plugin that needs a render pipeline beyond SceneKit implements ``FxGripSceneKitBackend`` and installs
it through `spaceBackend`. Customization inside SceneKit uses `SCNTechnique` on the scene and
`SCNProgram` or shader modifiers on a material, set on the scene objects in the apply seam.

The host bridge is a pair of categories. `SCNCamera(FxGrip)` builds a camera from the host focal
length and frustum and installs SceneKit depth of field. `SCNLight(FxGrip)` maps one `FxLight` to a
SceneKit light node.

## Topics

### Effect template

- ``FxGripSpaceEffect``
- ``FxGripSceneKitEffect``

### The render driver

- ``FxGripSceneKitBackend``
- ``FxGripSceneKitMetalBackend``

### Deterministic simulation

- ``FxGripSceneKitPhysicsBackend``
- ``FxGripPhysicsBake``
- ``FxGripParticleSystem``
- ``FxGripPhysicsSimulationStore``
- ``FxGripPhysicsMemoryStore``
- ``FxGripPhysicsFrameDataStore``

### Inter-particle forces

- ``FxGripParticleInteraction``
