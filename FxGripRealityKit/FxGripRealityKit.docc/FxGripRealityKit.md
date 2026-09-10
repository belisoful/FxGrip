# ``FxGripRealityKit``

The RealityKit render engine for FxGrip's 3D Space subsystem, written in Swift.

## Overview

FxGrip's 3D Space subsystem splits at the render engine. `FxGripSpaceEffect`, in the FxGrip
framework, captures the host camera and lights, serializes them into plugin state, and decodes them
for the render. An engine subclass draws the frame. `FxGripSceneKitEffect` is the SceneKit engine.
``FxGripRealityKitEffect`` is the RealityKit engine, and this module holds it.

### Swift only

This module is Swift, and a plugin that subclasses ``FxGripRealityKitEffect`` is a Swift plugin.

RealityKit publishes no Objective-C interface. `RealityFoundation` ships a Swift module, and the
headers inside `RealityKit.framework` are Metal shader headers. An Objective-C engine for RealityKit
is not possible, so the engine is written in the language RealityKit publishes.

The rest of FxGrip stays Objective-C and is reachable from both languages. A plugin that requires
Objective-C subclasses `FxGripSceneKitEffect` instead and loses nothing outside this module.

Swift reaches Objective-C through clang modules, so the FxGrip framework defines a module and the
project carries a module map for Apple's FxPlug SDK, which ships none. `Modules/FxPlug/module.modulemap`
in the repository declares the `FxPlug` and `PluginManager` modules. A target that imports FxGrip from
Swift passes that file to the clang importer.

### Deployment floor

The module requires macOS 15. `RealityRenderer` is the only offscreen render path RealityKit offers
and it arrived in macOS 15, along with `ParticleEmitterComponent`, `ShaderGraphMaterial`,
`LowLevelMesh`, and `LowLevelTexture`. FxGrip itself runs on macOS 13.5, so linking this module
raises a plugin's floor to macOS 15.

### What the engine inherits

``FxGripRealityKitEffect`` subclasses `FxGripSpaceEffect` and inherits the whole engine-neutral half
of the subsystem:

- the capture pass, which encodes the host camera, the host lights, the view-matrix samples on each
  side of the frame, and the inter-particle force configuration
- the decode helpers, which return the camera-to-world transform, the layer transform, the camera
  motion, and the interaction configuration in the simd column-vector convention
- `FxGripParticleRand`, the seeded variation function both engines' particle systems draw from
- the plugin capture seam, `encodeSceneParameters(into:at:)`
- the passthrough render, which copies the source tile unchanged when no engine render driver runs

### The render driver

``FxGripRealityKitBackend`` is the render-driver seam, and ``FxGripRealityKitMetalBackend`` is the
shipped driver. The seam matches `FxGripSceneKitBackend`, which serves the SceneKit engine, and differs
where the engines differ.

- SceneKit samples an absolute time → its backend takes `atTime:`.
- RealityKit advances by a delta → this backend takes `deltaTime`.
- SceneKit accepts a finished `SCNScene` → RealityKit's graph is main-actor isolated, so this
  backend takes a ``FxGripRealityKitSceneBuilder`` closure and calls it where the frame is drawn.

Two properties of `RealityRenderer` shape the driver.

The renderer, its entity collection, and `updateAndRender` are main-actor isolated. Every frame is
built and submitted on the main actor while the calling thread waits. The main actor is occupied only
for the build and the submission; the GPU work runs with the main actor free, and the calling thread
waits on the renderer's completion callback.

`RealityRenderer` takes no Metal device and draws on the system default device. A destination tile on
a second GPU is unreachable, and `canRender(into:)` reports that before a render begins so the effect
falls back to the passthrough.

The host renders frames concurrently, out of order, and re-renders them. RealityKit holds one scene
per renderer, so a frame owns the renderer for its duration and the driver serializes renders behind
a lock. The renderer is cleared at the start of every frame, so no state survives from the frame
before.

The driver leaves RealityKit's display tone map off, because an FxPlug tile holds linear light. It
renders into every pixel format `FxGripMTLDeviceCache` maps a tile onto, including the RGBA16Float
that a host commonly supplies. `preservesDestinationContents` composites the frame over what the
texture already holds instead of clearing it, which is what an effect needs when the source tile is
placed before the render.

### The frame

``FxGripRealityKitEffect`` builds one frame for each render, from the plugin state the base captured.
Everything hangs off a single root, which is the one entity the renderer holds, so the graph is shaped
the way a SceneKit plugin expects.

- the host camera, which becomes the frame's active camera
- one entity for each host light
- the source tile on a plane at the host layer transform, when `rendersSourceLayerPlane` is set
- an independent copy of the plugin's authored template
- the plugin's own entities, added through the apply hook
- the particle pass, which steps every FxGrip particle carrier to the frame's time and gives it its
  geometry

Each render rebuilds the frame and shares nothing with the render before it. A driver that is not
ready, or that cannot reach the tile's Metal device, leaves the frame to the base, which copies the
source unchanged.

### The camera

The host reports its projection through `Fx3DAPI_v5` in the Metal clip convention, which is
RealityKit's own, so the matrix drives a `ProjectiveTransformCameraComponent` unchanged and an
asymmetric frustum renders exactly.

- projection present → a projective-transform camera carrying the host matrix.
- projection absent, frustum usable → a perspective camera whose vertical field of view and clip
  planes come from the frustum.
- neither → a perspective camera with RealityKit's defaults.

The SceneKit engine takes the other route, building its projection from the frustum, because SceneKit
expects a clip depth of [-1, 1] where the host reports [0, 1].

### The lights

`Entity.fxgLight(from:)` maps one host light to a RealityKit light entity. A host intensity of one
maps to the reference intensity of the matching RealityKit component, so the host's nominal
brightness keeps its meaning. Spot cone angles convert from radians to degrees, and a directional or
spot light is oriented so its local -Z axis points along the host direction.

The host's ambient light has no counterpart. RealityKit expresses ambient illumination through an
image-based light on the renderer, so an ambient host light produces no entity, and an engine that
needs it sets `RealityRenderer.lighting` in the apply hook instead.

### Two authoring styles

A plugin builds its frame imperatively, in `updateSceneContents(_:root:camera:from:at:cameraMotion:)`,
reading the parameters it encoded during the capture pass.

A plugin that already holds an authored entity returns it from `sceneTemplateEntity(at:)` instead.
FxGrip clones it into every frame. The SceneKit engine archives its template into plugin state,
because `SCNNode` conforms to `NSSecureCoding`. A RealityKit `Entity` does not, so the template is
held on the effect and cloned. Cloning happens inside the driver's render lock, so a shared template
is safe under the host's concurrent rendering.

The two styles compose, the way they do for the SceneKit engine.

### Writing a Swift plugin

Both hooks run on the main actor, because RealityKit's scene graph is main-actor isolated. A plugin
creates entities there and caches its meshes and materials on itself.

A subclass that adds stored properties gets its defaults, because `FxGripTileableEffect` declares
`initWithAPIManager:` as its designated initializer. Without that declaration Swift skips a
subclass's property initialization and every stored property reads as zeroed memory.

### Deterministic physics

The host renders frames out of order and re-renders them, so a stateful simulation cannot step once
per render. ``FxGripRealityKitPhysicsBackend`` simulates from a fixed start to the requested frame on
every render, in fixed steps, so a frame's pose is a function of its time and nothing else. The
target grid-aligns to a step index, so a rendered pose matches its cached step exactly.

Two RealityKit facts shape it, both verified rather than assumed.

- `RealityRenderer.update(_:)` advances physics by the delta it is given → the driver owns the
  simulation clock and steps it. `PhysicsSimulationComponent.clock` plays no part.
- A body simulates only when its entity also carries a `CollisionComponent` → a body without one
  never moves, whatever its mass or mode.

RealityKit writes a simulated pose straight back to the entity's transform, so a pose is read and
replayed through the transform. The SceneKit engine reads a separate presentation node instead.

Two modes, the same pair the SceneKit engine offers, through the same engine-neutral
`FxGripPhysicsSimulationStore` and `FxGripPhysicsSimulationMode`:

- recompute → simulate the whole span on every render. Deterministic, no storage.
- session cache → memoize each step's poses and replay a cached step without simulating. Replay
  switches each body to kinematic, which RealityKit leaves exactly where it is put.

The store is keyed by entity name, so a plugin names the bodies it wants cached and an unnamed body
is skipped.

Setting `physicsBakeEnabled` on the effect upgrades the default driver to the simulating one and
loads the `FxGripPhysicsBake` extension, which backs the store with the document. The bake reaches
the engine through `installPhysicsSimulationStore(_:)`, an engine-neutral seam on `FxGripSpaceEffect`
that both engines implement, so the extension names no render engine.

### Particles

RealityKit's `ParticleEmitterComponent` has no seed and exposes no per-particle state, so it neither
reproduces a frame the host renders out of order nor carries an inter-particle force. It still
renders inside a frame, as a preview. The deterministic path is FxGrip-owned.

``FxGripRealityKitParticleSystem`` simulates its particles on the CPU. Its `Configuration` holds
the emission and particle parameters, every one constant across the simulated span, and a `seed`.
Per-particle variation comes from `FxGripParticleRand`, the function the SceneKit engine's
`FxGripParticleSystem` uses, keyed by the seed and the particle's birth index, so the same seed gives
the same particles in both engines.

The system steps on a fixed grid from a fixed start, the way the physics driver does, and the state
at step *k* is a function of the configuration and *k*.

- a later step → the system resumes from its current step and simulates only the gap.
- an earlier step, a changed configuration, or a changed force → the system restarts from zero.

Either way a frame sees the state one step sequence produces from an empty system, which is what
the host's out-of-order rendering requires. `totalSimulationSteps` counts the steps taken, so a test
can prove a resume repeated nothing.

An entity carries a system through ``FxGripRealityKitParticleComponent``, and
`Entity.fxgParticleCarrier(_:name:)` makes one. The carrier's transform is the emitter transform,
and its particles simulate in its space. The carrier is per-frame, created by the apply hook or
cloned from the template; the system is the plugin's and persists. Cloning copies the component and
shares the system.

After the apply hook, the effect steps every carrier in the frame to the render time and sets a
`ModelComponent` on it from ``FxGripRealityKitParticleGeometry``, one quad per particle facing the
camera. RealityKit's stock materials read no per-vertex color, so the default material is unlit and
samples one texel per particle from a palette texture through `uv0`. The mesh also carries the color
in its `color` attribute and the quad corner in `uv1`, and a system's `material` replaces the
default, so a `ShaderGraphMaterial` can draw sprites from the same mesh. Colors are linear, matching
the tile.

### Inter-particle forces

The force configuration `FxGripSpaceEffect` carries applies in this engine through
``FxGripRealityKitParticleField``, the counterpart of the SceneKit interaction physics field. A
field's members are stepped in lockstep, every member's particles are sources and targets alike,
and one Fast Multipole evaluation per step serves them all. The effect forms the fields for each
frame:

- `particleInteractionFields` → each entry names an entity, and the carriers in that entity's
  subtree share one field, evaluated in world space through the carriers' transforms.
- `particleInteraction` → each carrier outside every field runs under the scene-wide default, in
  its own space.
- a system's own `particleInteraction` → wins over both.

Gravity reads each system's `particleMass`, electric and magnetic read `particleCharge`, and the
three combine as a bit field the way they do in the SceneKit engine.

### Camera motion blur and depth of field

RealityKit on macOS has no motion-blur and no depth-of-field camera component, and `RealityRenderer`
publishes no depth buffer. The engine applies both as a Metal pass over the drawn tile, through
``FxGripRealityKitPostPass``. A plugin turns them on by returning an
``FxGripRealityKitCameraEffects`` from `cameraEffects(from:at:cameraMotion:)`, which receives the
camera's linear and angular velocity from the base, and reads the autofocus distance from
`autofocusDistance(from:)`, the distance to the host layer. Those are the two host-derived
quantities the SceneKit engine feeds `SCNCamera`.

- Motion blur → each pixel is reprojected through the camera pose one shutter earlier, from
  ``FxGripRealityKitPostCamera``, and blurred along the displacement, centered on the frame.
  Without a depth buffer the reprojection assumes one view depth: the depth-of-field focus, the
  autofocus distance, or a value the plugin sets. Rotation blur is exact at every depth; translation
  blur is exact at the assumed depth.
- Depth of field → the engine draws the frame a second time as a depth proxy, with every model's
  materials replaced by a flat tint that encodes its origin's view depth, then gathers a disc whose
  radius is the thin-lens circle of confusion at each pixel's proxy depth. The proxy holds one depth
  per entity, so the blur is exact for an entity facing the camera and approximate across one that
  recedes. Particle carriers are left out of the proxy and take the background depth.

Every sample pattern is fixed, so the pass reproduces a frame exactly. Depth of field costs a second
frame; motion blur costs one kernel.

### Current state

The target, the module chain, the effect, the render driver, the host bridge, deterministic
physics, deterministic FxGrip-owned particles with inter-particle forces, and the camera effects
pass exist. Every phase of the engine plan is built.

## Topics

### Effect template

- ``FxGripRealityKitEffect``

### The host bridge

- ``FxGripRealityKitEntityName``
- ``FxGripHostFrustum``

### The render driver

- ``FxGripRealityKitBackend``
- ``FxGripRealityKitMetalBackend``
- ``FxGripRealityKitSceneBuilder``
- ``FxGripRealityKitError``

### Deterministic physics

- ``FxGripRealityKitPhysicsBackend``

### Camera effects

- ``FxGripRealityKitCameraEffects``
- ``FxGripRealityKitPostCamera``
- ``FxGripRealityKitPostPass``

### Particles

- ``FxGripRealityKitParticleSystem``
- ``FxGripRealityKitParticleComponent``
- ``FxGripRealityKitParticleField``
- ``FxGripRealityKitParticleGeometry``
