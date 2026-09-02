# Adoption Levels

Use FxGrip from an existing FxPlug plug-in at the depth that fits, from a single utility to the
full effect base.

## Overview

FxGrip is adoptable incrementally. An existing plug-in with its own FxTileableEffect
implementation takes what helps and ignores the rest; a new plug-in starts from the effect base
and gets everything. Each level below stands on its own, and each is a superset of the one
before it.

### Level 1: Utilities

The utility classes have no coupling to the rest of FxGrip. Link the framework and use them
directly from any code:

- `FxGripRect`, `FxGripColorGamut`, ``FxGripImageBuffer``, ``FxGripMTLDeviceCache``
- ``FxGripEventModifiers`` (the modifier-key convention), ``FxGripURLWhitelist``
- The value types: ``FxGripDictionary``, ``FxGripCurveData``, ``FxGripPointListData``

### Level 2: API access and on-screen controls

``FxGripAPIAccessing`` wraps the `PROAPIAccessing` manager FxPlug hands every plug-in, and vends
the versioned host APIs plus FxGrip's additions (the tags and presets wrappers) from one place.
``FxGripOnScreenControl`` and its parts build on the same wrapper and bind directly to a raw
API manager, so a plug-in adopts FxGrip's on-screen controls without any effect-base code.

### Level 3: The parameter subsystem, through a host

The parameter classes, the plist-driven registration, and the custom controls reach their owner
only through ``FxGripEffectHost``: a wrapped API manager and a notification center. An existing
plug-in conforms directly, or owns an ``FxGripPluginHost``:

```objc
// In the plug-in's -initWithAPIManager:
_gripHost = [[FxGripPluginHost alloc] initWithAPIManager:apiManager];

// In -addParameters, from plist dictionaries or literals:
[FxGripFloatParameter addParameter:@{
    kFxParameterProperty_Id:      @(kAmountID),
    kFxParameterProperty_Name:    @"Amount",
    kFxParameterProperty_Type:    kFxParameterType_Float,
    kFxParameterProperty_Default: @0.5,
} toEffect:_gripHost];
```

The host carries a nullable `effectBase`: the full ``FxGripTileableEffect`` behind it, when
there is one. FxGripTileableEffect returns itself and a plain host returns nil, so the API
layer holds only the host and reads base-only members as `host.effectBase.member`, which nil
messaging turns into a safe no-op on a baseless host. Nothing in FxGrip casts a host to the
base class.

The host protocol's optional members serve individual parameter classes; a minimal host gets
each parameter's neutral behavior — the font menu uses the shipped default font, a color
registers without gamut conversion, a group opens and closes and the host registers its own
children, and the presets menu skips meta recording.

``FxGripCustomCreationAPI_v1``, vended by the API manager's `customCreationAPIv1`, creates the
custom controls in the style of Apple's creation APIs, so the routing layer is the only FxGrip
surface a plug-in touches:

```objc
FxGripCustomCreationAPI_v1 *custom = _gripHost.apiManager.customCreationAPIv1;
[custom addStatusWithName:@"State" parameterID:kStateID state:BEDotStateOk label:@"Ready"
		   parameterFlags:0];
[custom addRandomWithName:@"Seed" parameterID:kSeedID defaultValue:1 minimum:1 maximum:100000
					 step:1 parameterFlags:0];
```

``FxGripExtensionSystem`` runs the extensions as a self-contained subsystem over the same host:
load the extensions, then forward each FxPlug lifecycle call to the matching dispatch method
(dispatchProperties:, dispatchAddParameters:, dispatchParameterChanged:atTime:, flush, …). The
payloads mirror the effect base's, so an extension cannot tell the difference.

### Level 4: Composition

An existing plug-in that wants a subsystem the host protocol does not carry — the extensions,
the analysis pass, the plist configuration walk — owns an ``FxGripTileableEffect`` instance
instead of subclassing it, and forwards the FxPlug lifecycle calls it cares about
(-addParameters, -pluginState, parameter changes, rendering) to the inner effect. The inner
effect conforms to every host-typed entry point, loads its extensions, and posts the lifecycle
notifications they observe.

### Level 5: The effect base

Subclass ``FxGripTileableEffect`` (or ``FxGripTileableGenerator``) and the whole framework is
active: the registrars, the plist parameter configuration, the extensions, meta and tags,
presets, analysis, and the ML effect templates.

## Topics

### The host seam

- ``FxGripEffectHost``
- ``FxGripPluginHost``
- ``FxGripCustomCreationAPI_v1``
- ``FxGripExtensionSystem``

### The full base

- ``FxGripTileableEffect``
- ``FxGripTileableGenerator``
