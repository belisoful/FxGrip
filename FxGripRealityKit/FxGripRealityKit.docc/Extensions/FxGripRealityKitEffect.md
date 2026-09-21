# ``FxGripRealityKit/FxGripRealityKitEffect``

The RealityKit engine for FxGrip's 3D Space subsystem.

## Overview

The class subclasses `FxGripSpaceEffect` and inherits the engine-neutral half of the subsystem: the
capture pass, the decode helpers, the seeded particle variation, and the passthrough render. What it
adds is the RealityKit frame.

A plug-in that subclasses this is a Swift plug-in. A plug-in that requires Objective-C subclasses
`FxGripSceneKitEffect` instead and loses nothing outside this module.

### The two authoring hooks

Both run on the main actor, because RealityKit's entity graph is main-actor isolated. A plug-in
creates its entities there and caches meshes and materials on itself.

- ``updateSceneContents(_:root:camera:from:at:cameraMotion:)`` builds the frame imperatively.
- ``sceneTemplateEntity(at:)`` returns an authored entity that FxGrip clones into every frame.

The two compose, the way they do for the SceneKit engine.

### Camera effects

RealityKit on macOS has no motion-blur and no depth-of-field camera component, and `RealityRenderer`
publishes no depth buffer, so both run as a Metal pass over the drawn tile. A plug-in turns them on
by returning settings from ``cameraEffects(from:at:cameraMotion:)``, which receives the camera's
linear and angular velocity. ``autofocusDistance(from:)`` gives the distance to the host layer.

### Physics

Setting ``physicsBakeEnabled`` upgrades ``realityBackend`` to the simulating driver and loads the
`FxGripPhysicsBake` extension. The bake reaches the engine through
``installPhysicsSimulationStore(_:)``, an engine-neutral seam both engines implement, so the
extension names no render engine.

## Topics

### Building the frame

- ``updateSceneContents(_:root:camera:from:at:cameraMotion:)``
- ``sceneTemplateEntity(at:)``

### Camera effects

- ``cameraEffects(from:at:cameraMotion:)``
- ``autofocusDistance(from:)``
- ``postPass(for:)``

### The render driver

- ``realityBackend``
- ``defaultRealityBackend()``
- ``renderScene(from:sourceTile:to:at:)``

### Physics

- ``physicsBakeEnabled``
- ``installPhysicsSimulationStore(_:)``

### Extensions

- ``loadExtensions()``
