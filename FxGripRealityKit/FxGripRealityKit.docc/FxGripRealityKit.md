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
- the plugin capture seam, `encodeSceneParameters(into:at:)`
- the passthrough render, which copies the source tile unchanged when no engine render driver runs

### Current state

The target, the module chain, and the effect class exist. The render driver, the host-to-entity
bridge, deterministic physics, and FxGrip-owned particles are not yet built, so the inherited
passthrough render runs and the source tile passes through unchanged.

## Topics

### Effect template

- ``FxGripRealityKitEffect``
