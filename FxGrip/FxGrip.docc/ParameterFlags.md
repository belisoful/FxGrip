# Parameter Flags

The parameter-flag bit layout, the boolean accessors, and how flags combine in a configuration dictionary.

## Overview

A parameter carries a bit set of flags that controls how the host presents it and
how FxGrip saves it. ``FxGripParameterFlags`` is a union that overlays a named
bitfield on the `FxParameterFlags` integer, so a caller reads one bit by name or the
whole value at once. `gfxFlags(x)` casts an integer to the union, and `fxFlags(x)`
casts the union back.

A parameter declaration sets its flags under the `kFxParameterProperty_Flags` key.
The parameter object exposes each flag as a boolean property, such as `flagHidden`.
See <doc:ParameterModel> for the parameter object and <doc:FxPlugParameters> for the
configuration dictionary.

## The flags

The host-facing flags control presentation and saving.

| Flag constant | Bit | Config string | Effect |
| --- | --- | --- | --- |
| `kFxParameterFlag_NOT_ANIMATABLE` | 0 | `notanimatable` | The parameter holds one value with no keyframes. |
| `kFxParameterFlag_HIDDEN` | 1 | `hidden` | The host hides the parameter. |
| `kFxParameterFlag_DISABLED` | 2 | `disabled` | The host disables the parameter. |
| `kFxParameterFlag_COLLAPSED` | 3 | `collapsed` | The host draws a group collapsed. |
| `kFxParameterFlag_DONT_SAVE` | 4 | `dontsave` | The host does not save the value. |
| `kFxParameterFlag_DONT_DISPLAY_IN_DASHBOARD` | 5 | `dontdisplay` | The parameter is absent from the dashboard. |
| `kFxParameterFlag_CUSTOM_UI` | 6 | `customui` | The parameter vends a custom view. |
| `kFxParameterFlag_IGNORE_MINMAX` | 8 | `ignoreminmax` | A value may pass outside the declared bounds. |
| `kFxParameterFlag_CURVE_EDITOR_HIDDEN` | 9 | `curveeditorhidden` | The parameter is absent from the curve editor. |
| `kFxParameterFlag_DONT_REMAP_COLORS` | 10 | `dontremapcolors` | The host leaves a color unmapped to its internal gamut. |
| `kFxParameterFlag_USE_FULL_VIEW_WIDTH` | 11 | `fullviewwidth` | The control spans the inspector width. |

The FxGrip application flags occupy bits 25 through 31.

| Flag constant | Bit | Config string | Effect |
| --- | --- | --- | --- |
| `kFxParameterFlag_PRESETNOVALUE` | 21 | `presetnovalue` | A preset omits the parameter's value. |
| `kFxParameterFlag_HIDDEN_PROXY` | 25 | `hiddenproxy` | The parameter is hidden in proxy mode. |
| `kFxParameterFlag_IN_DEBUG_MODE` | 26 | `indebugmode` | The parameter is shown in debug mode. |
| `kFxParameterFlag_NO_DEBUG` | 27 | `nodebug` | The parameter is not shown in debug mode. |
| `kFxParameterFlag_NOSTATE` | 28 | `nostate` | The value is kept out of the plugin state. |
| `kFxParameterFlag_PRESETNOTAGS` | 29 | `presetnotags` | A preset omits the parameter's tags. |
| `kFxParameterFlag_PRESETNOMETA` | 30 | `presetnometa` | A preset omits the parameter's meta. |
| `kFxParameterFlag_INVALID` | 31 | — | The flags could not be read from the host. |

The temporary flags track the state cache and are stripped before saving.

- `kFxParameterFlag_CACHE` (bit 24) → the parameter is caching its flags.
- `kFxParameterFlag_CACHEDIRTY` (bit 23) → the cached flags differ from the host's.
- `kFxParameterFlag_SAVING` (bit 22) → the flags are being written to the parameter's stored value.

## Reading and writing a flag

Each flag has a `flagXxx(x)` test macro that returns whether the bit is set, such as
`flagHidden(x)` and `flagNotAnimatable(x)`. The parameter object exposes the same
tests as boolean properties.

- `flagHidden`, `flagDisabled`, `flagDontDisplayInDashboard`, `flagInvalid`, `flagNoState`, `flagNoDebug`, `flagInDebugMode`, `flagHiddenProxy`, `flagCaching` → on ``FxGripParameterBase-class``.
- `flagNotAnimatable`, `flagDontSave`, `flagCustomUI`, `flagCurveEditorHidden`, `flagUseFullViewWidth` → on ``FxGripParameter-class``.
- `flagIgnoreMinMax` → on a numeric parameter.
- `flagDontRemapColors` → on ``FxGripColorParameter``.
- `flagCollapsed` → on ``FxGripGroupParameter``.

`flagCacheDirty` is read-only.

Three macros toggle a bit on a raw flags value and mark the cache. `FxParameterAddFlag(flags, f)`
sets a bit, `FxParameterRemoveFlag(flags, f)` clears it, and `FxParameterSetFlagOn(flags, f, on)`
sets or clears it by a boolean. Each sets `kFxParameterFlag_CACHE` when it changes a
bit.

## Masks

Two masks split the flags value.

- `kFxParameterFlag_APP_MASK` → the FxGrip application flags in bits 25 through 31. `FxParameterFlagsAppMask(m)` extracts them.
- `kFxParameterFlag_FX_MASK` → the complement, the flags that reach the host. `FxParameterFlagsFxMask(m)` extracts them.

`kFxParameterFlag_TEMP_MASK` covers the cache, cache-dirty, and saving bits.
`RemoveTempFlags(flags)` clears them. `SavingFlags(flags)` sets the saving bit and
`UnsavingFlags(flags)` clears it.

## Combining flags in a configuration

The `kFxParameterProperty_Flags` value is a number, a string, an array of strings,
or a dictionary. An array of the `kParameterFlagString_*` constants is the common
form. A bare or `+`-prefixed entry sets its flag; a `-`-prefixed entry clears it. A
non-string entry is skipped. An omitted flags key leaves the parameter at the
default flags.

```objc
@{
    kFxParameterProperty_Id:    @(kMyLicenseID),
    kFxParameterProperty_Name:  @"License",
    kFxParameterProperty_Type:  kFxParameterType_String,
    kFxParameterProperty_Flags: @[
        kParameterFlagString_HIDDEN,
        kParameterFlagString_NOT_ANIMATABLE,
        kParameterFlagString_NO_STATE,
    ],
}
```

A string value is split on human dividers, so a space- or comma-separated list of
flag names sets the same bits. A number value is taken as the raw flags. A dictionary
value contributes its values as the flag list.

## Topics

### Types

- ``FxGripParameterFlags``

### The parameter model

- ``FxGripParameterBase-class``
- ``FxGripParameter-class``

### Related

