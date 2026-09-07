# Standard Value Parameters

The FxGrip wrapper classes for the FxPlug native parameter types.

## Overview

Each FxPlug parameter type has an FxGrip wrapper class. A class registers its
control with the host through `+addParameter:toEffect:`, reads and writes the value
at a render time, and encodes the value into the FxPlug plugin state. A class
declares the type it maps to with `+parameterType` and `+parameterTypeString`.

Every class derives from ``FxGripParameter-class``. A class that carries a value
that belongs in the plugin state conforms to `FxGripStateParameter`. See
<doc:ParameterModel> for the base class and <doc:FxPlugParameters> for the type
vocabulary and the configuration dictionary.

The examples below show the declaration each class registers. The declaration is a
`kFxParameterProperty_*` dictionary; the type property selects the class.

## Numeric parameters

### FxGripFloatParameter

Maps to `float`. Registers a floating-point slider. The range defaults to 0.0 to
1.0, the slider range defaults to the value range, and the delta defaults to 0.01
for a unit-width range and 1.0 otherwise. `-valueAtTime:` reads the value and
`-setValue:atTime:` writes it. ``FxGripAngleParameter`` and ``FxGripPercentParameter``
derive from it.

```objc
@{
    kFxParameterProperty_Id:      @(kMyGainID),
    kFxParameterProperty_Name:    @"Gain",
    kFxParameterProperty_Type:    kFxParameterType_Float,
    kFxParameterProperty_Default: @1.0,
    kFxParameterProperty_Minimum: @0.0,
    kFxParameterProperty_Maximum: @4.0,
}
```

### FxGripIntParameter

Maps to `integer`. Registers an integer slider. The range defaults to 0 to 100 and
the delta defaults to 1. It conforms to `FxGripParameterMinMaxInt` for its integer
bounds. `-valueAtTime:` returns an `int`. ``FxGripMenuParameter`` derives from it.

### FxGripAngleParameter

Maps to `angle`. Registers an angle slider measured in degrees. The range defaults
to 0 to 360 degrees. It inherits float value access from ``FxGripFloatParameter``.

### FxGripPercentParameter

Maps to `percent`. Registers a percent slider. The range defaults to 0.0 to 1.0. It
inherits float value access from ``FxGripFloatParameter``.

## Color parameters

### FxGripColorParameter

Maps to `rgba`. Registers a color well with red, green, blue, and alpha components.
The default alpha is 1.0. `-valueAtTime:` returns an ``FxGripColor``;
`-setRedValue:greenValue:blueValue:alphaValue:atTime:` writes the components. The
`flagDontRemapColors` property maps the DONT_REMAP_COLORS flag, which tells the host
to leave the color unmapped to its internal gamut. The host's parameter-policy
observers convert a declared `colorspace` to the working gamut.

```objc
@{
    kFxParameterProperty_Id:      @(kMyTintID),
    kFxParameterProperty_Name:    @"Tint",
    kFxParameterProperty_Type:    kFxParameterType_RGBA,
    kFxParameterProperty_Default: @{
        kFxParameterProperty_Red:   @1.0,
        kFxParameterProperty_Green: @0.5,
        kFxParameterProperty_Blue:  @0.0,
        kFxParameterProperty_Alpha: @1.0,
    },
}
```

### FxGripRGBParameter

Maps to `rgb`. Registers a color well that carries no alpha component. The default
red, green, and blue are 0.0. The `alphaParameter` property binds a separate float
or percent parameter as the alpha source; `-valueAtTime:` reads that parameter's
value into the color's alpha when one is bound. `-validate` checks that the bound
alpha parameter exists and is a float or percent. It derives from
``FxGripColorParameter``.

## Choice parameters

### FxGripMenuParameter

Maps to `menu`. Registers a popup menu whose selected index is an integer. The menu
entry titles come from the `items` key (`kFxParameterProperty_MenuItems`) and are
parsed once into `parameterMenuItems`. The default selected index is 0. It inherits
integer value access from ``FxGripIntParameter``.

```objc
@{
    kFxParameterProperty_Id:        @(kMyModeID),
    kFxParameterProperty_Name:      @"Mode",
    kFxParameterProperty_Type:      kFxParameterType_Menu,
    kFxParameterProperty_MenuItems: @[ @"Off", @"Low", @"High" ],
    kFxParameterProperty_Default:   @0,
}
```

### FxGripFontMenuParameter

Maps to `font`. Registers a font menu whose value is a font name string. The default
font name falls back to `kFxParameterType_FontNameDefault` when the declaration sets
none. `-valueAtTime:` returns the selected font name. It derives from
``FxGripStringParameterBase``.

## Text parameters

### FxGripStringParameter

Maps to `string`. Registers a plain string field. The default value is localized
before registration. Value access comes from ``FxGripStringParameterBase``, which
reads and writes `stringValue` and encodes the string into the plugin state. A nil
write stores an empty string.

```objc
@{
    kFxParameterProperty_Id:      @(kMyLabelID),
    kFxParameterProperty_Name:    @"Label",
    kFxParameterProperty_Type:    kFxParameterType_String,
    kFxParameterProperty_Default: @"Title",
}
```

## Boolean parameters

### FxGripToggleParameter

Maps to `toggle`. Registers a toggle button. The default value is NO.
`-valueAtTime:` reads the boolean at a render time, and `boolValue` reads and writes
it at time zero.

```objc
@{
    kFxParameterProperty_Id:      @(kMyEnabledID),
    kFxParameterProperty_Name:    @"Enabled",
    kFxParameterProperty_Type:    kFxParameterType_Toggle,
    kFxParameterProperty_Default: @YES,
}
```

## Point parameters

### FxGripPointParameter

Maps to `point`. Registers a point parameter whose value is an X and Y pair. The
default X and Y are 0.5. `-valueAtTime:` returns an ``FxGripPoint``;
`-setXValue:YValue:atTime:` writes the components. The declaration's on-screen
control option keys are parsed once into `options`, which an effect passes to the
point's on-screen control. See <doc:OnScreenControls>.

## Action parameters

### FxGripPushButtonParameter

Maps to `button`. Registers a push button. A click dispatches through the effect's
parameter click handler. The optional `selector` key names the subclass action hook;
a selector that does not use the click prefix fails registration. It carries no
plugin state.

### FxGripHelpParameter

Maps to `help`. Registers a help button. A click opens the plugin's help book when
no configuration selector overrides the default action. It derives from
``FxGripPushButtonParameter``.

## Data parameters

### FxGripGradientParameter

Maps to `gradient`. Registers a gradient parameter and samples its color ramp at a
render time. The `fxDepth`, `byteDepth`, and `samples` properties set the sampling
depth and count. `-valueAtTime:` returns an ``FxGripGradient`` owned by the
parameter, a header followed by the interleaved RGBA samples. An `NSCoder (FxGripGradient)`
category decodes the gradient from the plugin state and builds a one-pixel-tall
Metal texture from it.

### FxGripHistogramParameter

Maps to `histogram`. Registers a histogram parameter and reads its per-channel
levels at a render time. `-valueAtTime:` returns an ``FxGripHistogram`` owned by the
parameter, holding the black in, black out, white in, white out, and gamma for five
channels.

### FxGripImageRefParameter

Maps to `imageref`. Registers an image well that references another clip.
`-includeFilters` reports whether the referenced image includes upstream filters.
`-startTime` and `-durationTime` report the referenced clip's timing through
FxTimingAPI_v4, and `-isDropFrame` reports its drop-frame setting through
FxTimingAPI_v5. It carries no plugin state.

### FxGripPathParameter

Maps to `path`. Registers a path picker whose value is an `FxPathID`.
`-valueAtTime:` returns the path identifier.

### FxGripCustomParameter

Maps to `custom`. Registers a custom parameter whose value is an object conforming
to `NSSecureCoding` and `NSCopying`. The default value is an empty mutable
dictionary. `-value` and `-valueAtTime:` read the coded value, and the matching
setters write it. `dataClasses` lists the classes the value is permitted to be. A
subclass seeds the default value. See <doc:CustomControls> for the controls built on
custom parameters.

## Structural parameters

### FxGripGroupParameter

Maps to `group`. Registers a parameter subgroup and holds its child parameters. The
`flagCollapsed` property maps the COLLAPSED flag. Registration opens the host
subgroup, posts a notification for the configuration's owner to register the
children under the `parameters` key (`kFxParameterProperty_GroupParameters`), and
closes the subgroup even when a child fails. It conforms to `FxGripSubParameters`
for child counting, enumeration, and indexed access, and carries no plugin state of
its own. See <doc:ParameterModel>.

```objc
@{
    kFxParameterProperty_Id:              @(kMyGroupID),
    kFxParameterProperty_Name:            @"Adjustments",
    kFxParameterProperty_Type:            kFxParameterType_Group,
    kFxParameterProperty_GroupParameters: @[ /* child declarations */ ],
}
```

## Topics

### Numeric

- ``FxGripFloatParameter``
- ``FxGripIntParameter``
- ``FxGripAngleParameter``
- ``FxGripPercentParameter``

### Color

- ``FxGripColorParameter``
- ``FxGripRGBParameter``

### Choice

- ``FxGripMenuParameter``
- ``FxGripFontMenuParameter``

### Text and boolean

- ``FxGripStringParameter``
- ``FxGripStringParameterBase``
- ``FxGripToggleParameter-class``

### Point and action

- ``FxGripPointParameter``
- ``FxGripPushButtonParameter``
- ``FxGripHelpParameter``

### Data

- ``FxGripGradientParameter``
- ``FxGripHistogramParameter``
- ``FxGripImageRefParameter``
- ``FxGripPathParameter``
- ``FxGripCustomParameter-class``

### Structural

- ``FxGripGroupParameter``

### Related

- <doc:ParameterFlags>
- <doc:CustomControls>
