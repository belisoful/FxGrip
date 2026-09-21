# ``FxGrip/FxGripAPIAccessing-protocol``

The interface a wrapped API manager exposes to an FxGrip effect.

## Overview

An effect reaches every host service through this manager. ``FxGripTileableEffect-class`` holds one
and vends it as `apiManager`, typed as this protocol, so a plug-in reads a host API as a property
instead of resolving a protocol by hand.

### Two accessors for each API

Each FxPlug API has a pair of accessors. The plain accessor returns FxGrip's wrapper when FxGrip
wraps that API, and the host's own object when it does not. The `_Raw` accessor returns the host's
object with no FxGrip layer, whatever the API.

- the API is one FxGrip wraps → `paramSetAPIv6` is FxGrip's wrapper, `paramSetAPIv6_Raw` is the host's.
- the API is one FxGrip passes through → `pathAPIv3` and `pathAPIv3_Raw` return the same object.
- the host does not vend the API → both answer nil.

The plain accessor logs when the host answers nil, and the `_Raw` accessor does not. A plug-in that
expects an API to be absent reads the `_Raw` accessor to keep the log quiet.

### What FxGrip wraps

FxGrip wraps the eight parameter and timing APIs, because those are the ones its parameter
subsystem has to observe:

| Host API | What the wrapper adds |
| --- | --- |
| `FxParameterCreationAPI_v5`, `FxParameterCreationAPI_v6` | The extension pass over each parameter's properties, and a notification for every parameter added. |
| `FxParameterRetrievalAPI_v6`, `FxParameterRetrievalAPI_v7` | Custom-parameter routing through ``FxGripMutableParameter``, and a read notification. |
| `FxParameterSettingAPI_v5`, `FxParameterSettingAPI_v6` | Custom-parameter routing through ``FxGripMutableParameter``, and a write notification. |
| `FxDynamicParameterAPI_v3` | A notification for each parameter added, removed, or reflagged outside the `addParameters` pass. |
| `FxTimingAPI_v4` | A guard on each frame, sample, input, and timeline conversion. |

Every other FxPlug API passes through untouched.

### FxGrip's own APIs

Five APIs have no host counterpart. FxGrip implements them itself, so they resolve whatever the host
vends: ``FxGripParameterInfoAPI_v1-class``, ``FxGripParameterBoundsAPI_v1-class``, ``FxGripMetaAPI_v1-class``,
``FxGripParameterTagsAPI_v1-class``, and ``FxGripPresetsAPI_v1-class``. ``FxGripCustomCreationAPI_v1-class`` joins them
and needs an effect host, so it answers nil when the manager has none.

```objc
id<FxParameterSettingAPI_v6> setter = self.apiManager.paramSetAPIv6;       // FxGrip's wrapper
id<FxParameterSettingAPI_v6> host   = self.apiManager.paramSetAPIv6_Raw;   // the host's own object
id<FxGripPresetsAPI_v1>      presets = self.apiManager.presetsAPIv1;       // FxGrip-implemented
```

A write through `setter` reaches the host and posts an FxGrip notification. The same write through
`host` reaches the host alone, and FxGrip's parameter subsystem does not see it.

Bypassing the layer for a single call, rather than for a whole API, goes through
``apiForProtocol:bypass:``.

See <doc:APIAccessing> for the subsystem, and <doc:Registration> for how a plug-in reaches a manager.

## Topics

### Resolving an API

- ``apiForProtocol:bypass:``

### Creating a manager

- ``initWithAPIManager:effect:``
- ``effect``
- ``apiAccessing``

### Identifying the plug-in

- ``pluginUUID``
- ``pluginVersion``
- ``sessionID``

### Creating parameters

- ``paramCreateAPIv5``
- ``paramCreateAPIv6``
- ``dynamicParamAPIv3``
- ``customCreationAPIv1``

### Reading and writing parameters

- ``paramGetAPIv6``
- ``paramGetAPIv7``
- ``paramSetAPIv5``
- ``paramSetAPIv6``
- ``parameterInfoAPIv1``
- ``parameterBoundsAPIv1``

### Meta, tags, and presets

- ``metaAPIv1``
- ``paramTagsAPIv1``
- ``presetsAPIv1``

### Acting on a custom parameter

- ``customParameterActionAPIv4``

### On-screen controls

- ``onScreenControlAPIv1``
- ``onScreenControlAPIv2``
- ``onScreenControlAPIv3``
- ``onScreenControlAPIv4``

### Paths, undo, and commands

- ``pathAPIv3``
- ``undoAPIv1``
- ``commandAPIv1``
- ``commandAPIv2``

### The host window

- ``remoteWindowAPIv1``
- ``remoteWindowAPIv2``
- ``remoteWindowAPIv3``

### The scene and the color space

- ``spaceAPIv5``
- ``lightingAPIv3``
- ``colorGamutAPIv2``

### Timing and keyframes

- ``timingAPIv4``
- ``timingAPIv5``
- ``keyframeAPIv3``

### Analysis

- ``analysisAPIv1``
- ``analysisAPIv2``

### The project and the plug-in version

- ``projectAPIv1``
- ``projectAPIv2``
- ``versioningAPIv1``

### Reaching a host API with no FxGrip layer

- ``paramCreateAPIv5_Raw``
- ``paramCreateAPIv6_Raw``
- ``dynamicParamAPIv3_Raw``
- ``paramGetAPIv6_Raw``
- ``paramGetAPIv7_Raw``
- ``paramSetAPIv5_Raw``
- ``paramSetAPIv6_Raw``
- ``customParameterActionAPIv4_Raw``
- ``onScreenControlAPIv1_Raw``
- ``onScreenControlAPIv2_Raw``
- ``onScreenControlAPIv3_Raw``
- ``onScreenControlAPIv4_Raw``
- ``pathAPIv3_Raw``
- ``undoAPIv1_Raw``
- ``commandAPIv1_Raw``
- ``commandAPIv2_Raw``
- ``remoteWindowAPIv1_Raw``
- ``remoteWindowAPIv2_Raw``
- ``remoteWindowAPIv3_Raw``
- ``spaceAPIv5_Raw``
- ``lightingAPIv3_Raw``
- ``colorGamutAPIv2_Raw``
- ``timingAPIv4_Raw``
- ``timingAPIv5_Raw``
- ``keyframeAPIv3_Raw``
- ``analysisAPIv1_Raw``
- ``analysisAPIv2_Raw``
- ``projectAPIv1_Raw``
- ``projectAPIv2_Raw``
- ``versioningAPIv1_Raw``
