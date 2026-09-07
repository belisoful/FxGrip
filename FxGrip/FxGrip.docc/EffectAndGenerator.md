# Effect and Generator

Subclass the FxGrip effect or generator base and inherit the parameter model, the extensions, and the FxPlug render path.

## Overview

``FxGripTileableEffect-class`` is the base class an FxGrip plug-in subclasses. The class conforms to FxPlug's `FxTileableEffect` protocol and answers every host entry point the protocol declares: the property callback, parameter creation, parameter changes, the render-geometry callbacks, and the render callback. Around that contract it adds FxGrip's parameter model, the extension system, the priority notification center, and the host-API accessors.

``FxGripTileableGenerator`` subclasses the effect for a plug-in that produces an image with no source. It overrides the destination-image-rect and source-tile-rect callbacks so the output covers the destination image's pixel bounds and no source tile is requested. A generator subclass implements the render callback to draw the generated image and inherits the rest of the effect stack unchanged.

A subclass reaches the framework through four override points:

- `loadExtensions` → returns the extensions to install; call `super` to keep the framework-installed extensions.
- `addParametersWithGroupID:error:` → creates parameters in code; call `super` to keep the configuration-driven parameters.
- `parametersConfiguration` → returns the parameter configuration records; the base reads the `"parameters"` array from the plugin's registration record.
- the coder-state render callbacks → encode and decode the render.

## The FxPlug lifecycle

The host drives the effect through the `FxTileableEffect` protocol. Each stage runs the base implementation and posts one notification, so an extension or a subclass observes the stage without overriding the callback. <doc:ExtensionArchitecture> documents the stage sequence, the notification names, and the userInfo payloads. The stages are the load and init, the property callback, parameter creation, the added-to-document callback, parameter changes, the flush, the plugin-state encode, the render-geometry callbacks, the render callback, and the teardown.

The base tracks its own progress through the stages with read-only flags:

- `addingParameters` → YES while the effect is inside its parameter-creation pass.
- `addedParameters` → YES once parameter creation finishes.
- `finishedSetup` → YES once initial setup finishes.
- `addedToDocument` → YES once the effect joins a document.

An extension or a category reads these flags to know which host APIs are valid at the moment it runs.

## The property callback

`properties:error:` fills the FxPlug property dictionary the host reads during setup. The base maps the effect's property settings into the FxPlug keys. A subclass sets those properties as declared attributes rather than building the dictionary:

- `needsFullBuffer` → the effect requires the full source buffer instead of a tile.
- `variesWhenParamsAreStatic` → the output varies over time while the parameters stay static.
- `changesOutputSize` → the effect changes the output image size.
- `mayRemapTime` → the effect remaps the timeline time of its input.
- `pixelTransformSupport` → the effect's support for pixel-transform rendering.

`FxGripTileableEffect (PluginProperties)` reads the property dictionary from the registration record instead when `isEffectPropertiesInInfo` is YES, so a plug-in declares its FxPlug properties in the plist. The base returns NO, and a subclass opts in by overriding.

## The coder-state render path

The render callbacks replace the opaque `pluginState` `NSData` with an `NSCoder`. `FxGripTileableEffectCoderStateWeak` declares the coder-based callbacks as optional members, so an effect adopts the coder path for the render stages it needs. `FxGripTileableEffectCoderState` promotes the coder, destination-bounds, source-tile, and render callbacks to required members, so a conforming effect supplies the complete coder-based render path. The `scheduleInputs` callback stays optional in both.

A subclass encodes its render state in `pluginCoder:atTime:quality:error:` and reads it back in `renderDestinationImage:sourceImages:pluginCoder:atTime:error:`. <doc:PluginState> documents why the render state travels through the coder and how the coder carries the render time and quality level. The base compresses the encoded state losslessly when `pluginStateCompression` names a codec and the blob reaches `pluginStateCompressionThreshold`.

## How the categories partition the API

The effect's surface is split across categories on ``FxGripTileableEffect-class``, one concern per category:

| Category | Concern |
| --- | --- |
| `(FxParameters)` | maps parameter type strings to classes and builds parameter objects from configuration |
| `(CustomUI)` | vends the custom parameter view for a custom-UI parameter |
| `(OOBParameterAccess)` | opens an out-of-band parameter access context |
| `(PluginProperties)` | reports whether the FxPlug properties come from the registration record |
| `(ProjectProperties)` | reads the host project's document ID, host kind, aspect ratio, and media folder |
| `(Versioning)` | compares the plugin version to the stored version and runs upgrades |
| `(Analyze)` | adds the FxPlug frame-analysis pass and its per-frame storage |
| `(Timing)` | reads the clip and timeline timing attributes |
| `(ColorGamut)` | reports the color primaries and the parameter color space |
| `(Notifications)` | declares the lifecycle notification names and userInfo keys |
| `(Extensions)` | loads and orders the extensions and posts the flush |

The `(FxParameters)` category conforms the effect to `FxParameterFactory`. It builds a parameter object from a configuration dictionary, delegating to an extension when the record names an extension key, so a loaded extension backs a custom type string the built-in map does not know.

The `(CustomUI)` category implements `createViewForParameterID:` without claiming FxPlug's `FxCustomParameterViewHost_v2` protocol. A plug-in with custom controls declares that protocol on its own subclass, and a plug-in without them advertises nothing to the host. The created view comes from the runtime parameter's `newParameterView` and attaches to the parameter so data pushes reach it.

The `(ProjectProperties)` category distinguishes the host by document ID: a document ID of 0 identifies a Motion project, and a non-zero value identifies Final Cut Pro. `isProjectMotion` and `isProjectFinalCutPro` read from that.

## The host seam

The parameter subsystem, the custom controls, and the out-of-band access context reach their owner only through ``FxGripEffectHost``. The protocol's required members are the wrapped API manager (`apiManager`), the notification center (`notifier`), and the optional effect base (`effectBase`). ``FxGripTileableEffect-class`` conforms and returns itself from `effectBase`.

A plug-in that keeps its own `FxTileableEffect` implementation adopts the parameter subsystem without the effect base. It conforms to ``FxGripEffectHost`` directly, or owns an ``FxGripPluginHost``, which wraps the plug-in's `PROAPIAccessing` in an ``FxGripAPIAccessing-class`` and supplies a notification center. A plain host returns nil from `effectBase`, and code that needs the base reads `host.effectBase.member`, which Objective-C nil messaging turns into a safe no-op. <doc:Adoption> maps the levels from a single utility to the full effect base.

## Topics

### Base classes

- ``FxGripTileableEffect-class``
- ``FxGripTileableGenerator``

### The host seam

- ``FxGripEffectHost``
- ``FxGripPluginHost``
- ``FxGripAPIAccessing-class``

### The render-state protocols

- ``FxGripTileableEffectCoderState``
- ``FxGripTileableEffectCoderStateWeak``

### Related articles

- <doc:Adoption>
- <doc:ExtensionArchitecture>
- <doc:PluginState>
