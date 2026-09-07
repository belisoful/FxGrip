# FxPlug Parameters

The FxPlug parameter model, its control vocabulary, and the configuration dictionary that declares a parameter.

## Overview

An FxPlug plugin builds its inspector by adding parameters to the host. Each
parameter has a numeric ID, a kind, a name, a set of flags, and a value. FxGrip
declares a parameter with a configuration dictionary, resolves the declared kind
to a parameter class, and registers the control with the host through the
parameter-creation API.

The kind is one of the FxPlug control types, named by an `FxParameterType`
enumeration case and by a `kFxParameterType_*` type-key string. The configuration
dictionary names the parameter's ID, kind, and settings with `kFxParameterProperty_*`
keys. `FxGripTypes.h` declares both vocabularies.

The FxGrip wrapper classes carry each type's declaration and value access. See
<doc:StandardValueParameters> for the value-parameter classes and
<doc:CustomControls> for the inspector controls FxGrip adds beyond the FxPlug set.

## The control vocabulary

`FxParameterType` spans the FxPlug native types and the FxGrip custom controls.
Cases 0 through 19 mirror the FxPlug parameter types. Cases from 120 up are FxGrip
custom controls. The negative cases name the array and dictionary container types.

Each FxPlug type pairs an `FxParameterType` case with a `kFxParameterType_*`
type-key string. The type-key string is what a configuration dictionary sets under
the type property.

| Type key string | Constant | `FxParameterType` case |
| --- | --- | --- |
| `angle` | `kFxParameterType_Angle` | `FxParameterType_Angle` |
| `rgba` | `kFxParameterType_RGBA` | `FxParameterType_RGBA` |
| `rgb` | `kFxParameterType_RGB` | `FxParameterType_RGB` |
| `custom` | `kFxParameterType_Custom` | `FxParameterType_Custom` |
| `float` | `kFxParameterType_Float` | `FxParameterType_Float` |
| `font` | `kFxParameterType_FontMenu` | `FxParameterType_FontMenu` |
| `gradient` | `kFxParameterType_Gradient` | `FxParameterType_Gradient` |
| `help` | `kFxParameterType_Help` | `FxParameterType_Help` |
| `histogram` | `kFxParameterType_Histogram` | `FxParameterType_Histogram` |
| `imageref` | `kFxParameterType_ImageRef` | `FxParameterType_ImageRef` |
| `integer` | `kFxParameterType_Integer` | `FxParameterType_Int` |
| `path` | `kFxParameterType_PathID` | `FxParameterType_PathID` |
| `percent` | `kFxParameterType_Percent` | `FxParameterType_Percent` |
| `point` | `kFxParameterType_Point` | `FxParameterType_Point` |
| `menu` | `kFxParameterType_Menu` | `FxParameterType_Menu` |
| `button` | `kFxParameterType_PushButton` | `FxParameterType_PushButton` |
| `string` | `kFxParameterType_String` | `FxParameterType_String` |
| `toggle` | `kFxParameterType_Toggle` | `FxParameterType_Toggle` |
| `group` | `kFxParameterType_Group` | `FxParameterType_Group` |

The custom control type keys, such as `section`, `divider`, and `webview`, name
the FxGrip controls. See <doc:CustomControls>.

## The configuration dictionary

A parameter is declared with a dictionary keyed by `kFxParameterProperty_*` strings.
The keys divide into identity, common settings, and per-type settings.

### Identity and common keys

- `kFxParameterProperty_Id` → the parameter's numeric ID (`id`).
- `kFxParameterProperty_Type` → the type-key string (`type`).
- `kFxParameterProperty_Name` → the display name (`name`).
- `kFxParameterProperty_Description` → the descriptive text (`description`).
- `kFxParameterProperty_Flags` → the parameter flags (`flags`). See <doc:ParameterFlags>.
- `kFxParameterProperty_ParentId` → the containing group's ID (`parentid`).
- `kFxParameterProperty_Default` → the default value (`default`).
- `kFxParameterProperty_ResetValue` → the value the parameter resets to (`resetvalue`).
- `kFxParameterProperty_Tags` → the parameter's tags (`tags`).
- `kFxParameterProperty_Meta` → the parameter's meta dictionary (`meta`).

### Numeric and range keys

- `kFxParameterProperty_Minimum` / `kFxParameterProperty_Maximum` → the value bounds.
- `kFxParameterProperty_SliderMinimum` / `kFxParameterProperty_SliderMaximum` → the slider track bounds.
- `kFxParameterProperty_Delta` → the drag increment.

### Color keys

- `kFxParameterProperty_Red`, `kFxParameterProperty_Green`, `kFxParameterProperty_Blue`, `kFxParameterProperty_Alpha` → the color components.
- `kFxParameterProperty_ColorSpace` → the declared color space, which the host's parameter-policy observers convert to the working gamut.

### Structural, choice, and action keys

- `kFxParameterProperty_MenuItems` → the menu entry titles (`items`), for a menu.
- `kFxParameterProperty_GroupParameters` → the child parameters of a group (`parameters`).
- `kFxParameterProperty_X` / `kFxParameterProperty_Y` → a point's components.
- `kFxParameterProperty_Selector` → a push button's action selector.
- `kFxParameterProperty_GradientSamples`, `kFxParameterProperty_GradientDepth`, `kFxParameterProperty_GradientDepthType` → a gradient's sample count and depth.
- `kFxParameterProperty_ClassName`, `kFxParameterProperty_CustomClass`, `kFxParameterProperty_CustomClasses` → a custom parameter's value classes.

## Declaring a parameter

A float slider declares its ID, type, name, and range. An omitted range defaults
to 0.0 to 1.0.

```objc
@{
    kFxParameterProperty_Id:      @(kMyOpacityID),
    kFxParameterProperty_Name:    @"Opacity",
    kFxParameterProperty_Type:    kFxParameterType_Float,
    kFxParameterProperty_Default: @0.75,
    kFxParameterProperty_Minimum: @0.0,
    kFxParameterProperty_Maximum: @1.0,
}
```

A popup menu declares its entries under the menu-items key.

```objc
@{
    kFxParameterProperty_Id:        @(kMyBlendID),
    kFxParameterProperty_Name:      @"Blend",
    kFxParameterProperty_Type:      kFxParameterType_Menu,
    kFxParameterProperty_MenuItems: @[ @"Normal", @"Add", @"Multiply" ],
    kFxParameterProperty_Default:   @0,
}
```

## How FxGrip constructs a parameter

FxGrip registers a parameter class for each `FxParameterType`. The effect maps the
type-key string to the numeric type, then to the class. A class registers its type
through `+parameterType` and `+parameterTypeString`.

- Declaration → the effect reads the type-key string and resolves the parameter class.
- Registration → the class's `+addParameter:toEffect:` reads the configuration and calls the host's parameter-creation API to create the control.
- Reconstruction → the effect builds the matching parameter object for the ID and registers it, so `effect[id]` returns the parameter. See <doc:ParameterModel>.

Each parameter class supplies the defaults for keys the declaration omits. The
float slider defaults its range to 0.0 to 1.0 and its delta to 0.01 for a unit
range. The integer slider defaults its range to 0 to 100 and its delta to 1. The
per-class defaults appear with each class in <doc:StandardValueParameters>.

## Topics

### Type vocabulary

- ``FxParameterType``
- ``FxGripDepthType``

### The parameter model

- ``FxGripParameter-class``
- <doc:ParameterModel>
- <doc:ParameterFlags>

### The parameter classes

- <doc:StandardValueParameters>
- <doc:CustomControls>
