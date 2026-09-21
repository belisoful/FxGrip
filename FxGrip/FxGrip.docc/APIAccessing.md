# Accessing Host APIs

Reach every FxPlug host API and FxGrip's own additions through one wrapped API manager.

## Overview

FxPlug hands every plug-in a `PROAPIAccessing` manager, and a plug-in resolves a
host API by asking that manager for a protocol. ``FxGripAPIAccessing-class`` wraps
the host manager and vends the same APIs from one place. It conforms to
``FxGripAPIAccessing-class`` (the protocol), which extends `PROAPIAccessing` with an
`apiForProtocol:bypass:` entry point and a typed accessor for each API.

The wrapper resolves a protocol two ways:

- `apiForProtocol:` (the `PROAPIAccessing` method) → FxGrip's wrapper for a
  protocol FxGrip augments, and the host object for every other protocol.
- `apiForProtocol:bypass:` with `bypassFxGripLayer` set to `YES` → the raw host
  object with no FxGrip layer.

A plug-in that adopts FxGrip at the API level reaches the wrapper through its host.
Adoption.md shows an existing plug-in wrapping its manager directly or through
``FxGripPluginHost``, after which each accessor vends the wrapped API:

```objc
id<FxParameterRetrievalAPI_v7> get = _gripHost.apiManager.paramGetAPIv7;
CGSize wellSize;
[get imageSize:&wellSize fromParameter:kImageWellID atTime:renderTime error:&error];
```

## Typed accessors

Each API has a pair of accessor properties on ``FxGripAPIAccessing-class``. The
plain accessor vends FxGrip's wrapper when one exists, and the `_Raw` accessor vends
the host object with no FxGrip layer. Both answer `nil` when the host does not
provide the API.

| Accessor | Vends |
| --- | --- |
| `paramCreateAPIv5` / `paramCreateAPIv5_Raw` | ``FxGripParameterCreationAPI_v5`` |
| `paramCreateAPIv6` / `paramCreateAPIv6_Raw` | ``FxGripParameterCreationAPI_v6`` |
| `paramGetAPIv6` / `paramGetAPIv6_Raw` | ``FxGripParameterRetrievalAPI_v6`` |
| `paramGetAPIv7` / `paramGetAPIv7_Raw` | ``FxGripParameterRetrievalAPI_v7`` |
| `paramSetAPIv5` / `paramSetAPIv5_Raw` | ``FxGripParameterSettingAPI_v5`` |
| `paramSetAPIv6` / `paramSetAPIv6_Raw` | ``FxGripParameterSettingAPI_v6`` |
| `dynamicParamAPIv3` / `dynamicParamAPIv3_Raw` | ``FxGripDynamicParameterAPI_v3`` |
| `timingAPIv4` / `timingAPIv4_Raw` | ``FxGripTimingAPI_v4`` |

FxGrip's own APIs resolve through the same object, each from a single accessor with
no `_Raw` pair, because no host vends them:

| Accessor | Vends |
| --- | --- |
| `parameterInfoAPIv1` | ``FxGripParameterInfoAPI_v1-class`` |
| `parameterBoundsAPIv1` | ``FxGripParameterBoundsAPI_v1-class`` |
| `metaAPIv1` | ``FxGripMetaAPI_v1-class`` |
| `paramTagsAPIv1` | ``FxGripParameterTagsAPI_v1-class`` |
| `presetsAPIv1` | ``FxGripPresetsAPI_v1-class`` |
| `customCreationAPIv1` | ``FxGripCustomCreationAPI_v1-class`` |

`customCreationAPIv1` answers `nil` when the manager has no effect host. The
grouping API resolves from FxGrip's parameter model through the
``FxGripParameterGroupingAPI_v1-class`` implementation.

The accessors for host protocols FxGrip does not wrap return the raw host object
from both the plain and `_Raw` accessors. These cover the on-screen control,
path, undo, command, remote window, 3D space, lighting, color gamut, keyframe,
analysis, project, and versioning APIs.

## Versioned classes mirror FxPlug protocol versions

A `*API_v5` … `*API_v7` wrapper mirrors the FxPlug protocol of the same version.
Each higher version subclasses the one before it and adds the methods that version
introduces, so every earlier method is inherited.

- ``FxGripParameterCreationAPI_v6`` extends ``FxGripParameterCreationAPI_v5`` with
  `addTaggedPopupMenuWithName:parameterID:defaultValue:menuEntries:parameterFlags:`.
- ``FxGripParameterRetrievalAPI_v7`` extends ``FxGripParameterRetrievalAPI_v6`` with
  `imageSize:fromParameter:atTime:error:`.
- ``FxGripParameterSettingAPI_v6`` extends ``FxGripParameterSettingAPI_v5`` with
  `addFlags:toParameter:` and `removeFlags:fromParameter:`.

A new FxPlug protocol version gets a new wrapper class. A shipped wrapper keeps its
semantics. The setting wrapper holds its host API as the v6 protocol, because the
upgraded host object implements both v5 and v6.

## Custom-parameter routing

The retrieval and setting wrappers detect a Custom parameter through
``FxGripParameterInfoAPI_v1-class`` before forwarding. For a Custom parameter, a read
routes to the value's `FxGripMutableParameter` accessor when it responds, and a
write reads the current custom value, mutates it through the same accessor, and
writes it back.

## Notifications

The versioned wrappers post an `FxGripNotifyAPI_…Name` notification around each host
parameter call, so extensions observe and rewrite parameter traffic. A creation call
posts before and after the host call, a set posts after a successful write, and a get
posts a mutable dictionary the wrapper reads back. See <doc:ExtensionArchitecture>
for the notification names, the userInfo layout, and the observer selectors.

## FxGrip's own APIs

FxGrip adds APIs in the style of Apple's FxPlug APIs. Each resolves through
``FxGripAPIAccessing-class`` and reads from FxGrip's parameter model, meta manager,
or plist configuration.

- ``FxGripParameterInfoAPI_v1-class`` reports parameter existence, type, menu
  entries, and the full ID list. Existence and the ID list walk Apple's
  dynamic-parameter roster; type and menu entries resolve through the effect's
  notification seam.
- ``FxGripParameterBoundsAPI_v1-class`` sets one edge of a Float or Int parameter's
  value or slider range, reading the current range first and writing it back with one
  edge changed.
- ``FxGripParameterGroupingAPI_v1-class`` reports the subgroup that contains a
  parameter and enumerates a subgroup's members from the parameter model.
- ``FxGripMetaAPI_v1-class`` stores secure-codable metadata on a parameter, persisted
  with the effect's plugin state, forwarding every call to the host's meta manager.
- ``FxGripParameterTagsAPI_v1-class`` stores tags on parameters, queries parameters
  by tag, resolves tags to preset definitions from the plugin plist, and applies
  preset definitions to parameters.
- ``FxGripPresetsAPI_v1-class`` captures the effect's parameters as a preset, applies
  presets through the tag API core, browses the merged plugin and user listings, and
  watches the managed user folder.
- ``FxGripCustomCreationAPI_v1-class`` creates FxGrip's custom inspector controls in
  the style of Apple's creation APIs. See <doc:CustomControls> and <doc:WebContent>.

``FxGripDynamicParameterAPI_v4-class`` aggregates existence, type, single-edge bounds, and
per-parameter metadata over the v3 wrapper. Its bounds and metadata methods now have
their own APIs, ``FxGripParameterBoundsAPI_v1-class`` and ``FxGripMetaAPI_v1-class``,
so FxGrip does not extend Apple's dynamic-parameter protocol. No accessor vends the
v4 class; the dynamic accessor vends ``FxGripDynamicParameterAPI_v3``.

## Topics

### The wrapper

- ``FxGripAPIAccessing-class``
- ``FxGripAPIAccessing-class``
- ``FxGripCommonAPI``

### Creation

- ``FxGripParameterCreationAPI_v5``
- ``FxGripParameterCreationAPI_v6``
- ``FxGripCustomCreationAPI_v1-class``

### Retrieval

- ``FxGripParameterRetrievalAPI_v6``
- ``FxGripParameterRetrievalAPI_v7``

### Setting

- ``FxGripParameterSettingAPI_v5``
- ``FxGripParameterSettingAPI_v6``

### Dynamic

- ``FxGripDynamicParameterAPI_v3``
- ``FxGripDynamicParameterAPI_v4-class``

### Grouping and bounds

- ``FxGripParameterGroupingAPI_v1-class``
- ``FxGripParameterBoundsAPI_v1-class``

### Info

- ``FxGripParameterInfoAPI_v1-class``

### Tags and meta

- ``FxGripParameterTagsAPI_v1-class``
- ``FxGripMetaAPI_v1-class``

### Timing

- ``FxGripTimingAPI_v4``

### Presets

- ``FxGripPresetsAPI_v1-class``

### Related articles

- <doc:Adoption>
- <doc:Registration>
- <doc:ExtensionArchitecture>
- <doc:OnScreenControls>

### The API protocols

- ``FxGripAPIAccessing-protocol``
- ``FxGripCustomCreationAPI_v1-protocol``
- ``FxGripDynamicParameterAPI_v4-protocol``
- ``FxGripMetaAPI_v1-protocol``
- ``FxGripParameterBoundsAPI_v1-protocol``
- ``FxGripParameterGroupingAPI_v1-protocol``
- ``FxGripParameterInfoAPI_v1-protocol``
- ``FxGripParameterTagsAPI_v1-protocol``
- ``FxGripPresetsAPI_v1-protocol``
