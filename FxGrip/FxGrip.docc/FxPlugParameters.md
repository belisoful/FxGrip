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

### Declaring a parameter

- ``kFxParameterProperty_Id``
- ``kFxParameterProperty_Name``
- ``kFxParameterProperty_Type``
- ``kFxParameterProperty_Flags``
- ``kFxParameterProperty_ParentId``
- ``kFxParameterProperty_Index``
- ``kFxParameterProperty_Default``
- ``kFxParameterProperty_ResetValue``
- ``kFxParameterProperty_Description``
- ``kFxParameterProperty_GroupParameters``

### Value bounds

- ``kFxParameterProperty_Minimum``
- ``kFxParameterProperty_Maximum``
- ``kFxParameterProperty_SliderMinimum``
- ``kFxParameterProperty_SliderMaximum``
- ``kFxParameterProperty_Delta``

### Color and histogram keys

- ``kFxParameterProperty_Red``
- ``kFxParameterProperty_Green``
- ``kFxParameterProperty_Blue``
- ``kFxParameterProperty_Alpha``
- ``kFxParameterProperty_ColorSpace``
- ``kFxParameterProperty_BlackIn``
- ``kFxParameterProperty_BlackOut``
- ``kFxParameterProperty_WhiteIn``
- ``kFxParameterProperty_WhiteOut``
- ``kFxParameterProperty_Gamma``
- ``kFxParameterProperty_Channel``

### Point keys

- ``kFxParameterProperty_X``
- ``kFxParameterProperty_Y``

### Menus, buttons, and selectors

- ``kFxParameterProperty_MenuItems``
- ``kFxParameterProperty_MenuLinks``
- ``kFxParameterProperty_ButtonTitle``
- ``kFxParameterProperty_ButtonStyle``
- ``kFxParameterProperty_ButtonFont``
- ``kFxParameterProperty_ButtonFontSize``
- ``kFxParameterProperty_ButtonImageName``
- ``kFxParameterProperty_ButtonImageURL``
- ``kFxParameterProperty_Selector``
- ``kFxParameterProperty_SelectorObject``
- ``kFxParameterProperty_SelectorPrefix``
- ``kFxParameterProperty_CustomHelp``
- ``kFxParameterProperty_MultiLine``

### Gradient keys

- ``kFxParameterProperty_GradientDepth``
- ``kFxParameterProperty_GradientDepthType``
- ``kFxParameterProperty_GradientDepthType_Bytes``
- ``kFxParameterProperty_GradientDepthType_FxDepth``
- ``kFxParameterProperty_GradientDepth_UInt8``
- ``kFxParameterProperty_GradientDepth_float32``
- ``kFxParameterProperty_GradientDepth_half16``
- ``kFxParameterProperty_GradientSamples``

### Custom-parameter keys

- ``kFxParameterProperty_CustomClass``
- ``kFxParameterProperty_CustomClasses``
- ``kFxParameterProperty_ClassName``
- ``kFxParameterProperty_Factory``
- ``kFxParameterProperty_ExtensionKey``
- ``kFxParameterProperty_ManagePrefix``

### Tags, meta, and preset targets

- ``kFxParameterProperty_Tags``
- ``kFxParameterProperty_Meta``
- ``kFxParameterProperty_Time``
- ``kFxParameterProperty_TargetPrefix``
- ``kFxParameterProperty_TargetPreset``
- ``kFxParameterProperty_TargetPresetFlags``
- ``kFxParameterProperty_TargetPresetMeta``
- ``kFxParameterProperty_TargetPresetNames``
- ``kFxParameterProperty_TargetPresetTags``
- ``kFxParameterProperty_TargetPresetValues``

### Parameter type strings

- ``kFxParameterType_Analyzer``
- ``kFxParameterType_Angle``
- ``kFxParameterType_Banner``
- ``kFxParameterType_Capsule``
- ``kFxParameterType_Custom``
- ``kFxParameterType_Divider``
- ``kFxParameterType_Float``
- ``kFxParameterType_FontMenu``
- ``kFxParameterType_FontNameDefault``
- ``kFxParameterType_Gradient``
- ``kFxParameterType_Group``
- ``kFxParameterType_Help``
- ``kFxParameterType_Histogram``
- ``kFxParameterType_ImageRef``
- ``kFxParameterType_Integer``
- ``kFxParameterType_LiveImage``
- ``kFxParameterType_Menu``
- ``kFxParameterType_ObjectTracker``
- ``kFxParameterType_PathID``
- ``kFxParameterType_Percent``
- ``kFxParameterType_Point``
- ``kFxParameterType_Presets``
- ``kFxParameterType_Progress``
- ``kFxParameterType_PushButton``
- ``kFxParameterType_RGB``
- ``kFxParameterType_RGBA``
- ``kFxParameterType_Random``
- ``kFxParameterType_Section``
- ``kFxParameterType_Status``
- ``kFxParameterType_String``
- ``kFxParameterType_Switch``
- ``kFxParameterType_Toggle``
- ``kFxParameterType_TrackingOpacity``
- ``kFxParameterType_VideoView``
- ``kFxParameterType_WebView``

### Reserved parameter IDs

- ``kFxParameterId_AboutMenu``
- ``kFxParameterId_AnalysisData``
- ``kFxParameterId_ApplePluginData``
- ``kFxParameterId_DebugActivator``
- ``kFxParameterId_DebugMenu``
- ``kFxParameterId_FxFactoryLicense``
- ``kFxParameterId_InstanceMeta``
- ``kFxParameterId_MLCache``
- ``kFxParameterId_Maximum``
- ``kFxParameterId_Minimum``
- ``kFxParameterId_None``
- ``kFxParameterId_ParameterData``
- ``kFxParameterId_PhysicsBake``
- ``kFxParameterId_TopLevelGroup``

### Click selectors

- ``kFxGripClickSelectorPrefix``

### Reserved type strings

- ``kParameterType_Button``
- ``kParameterType_Capsule``
- ``kParameterType_StringLine``
- ``kParameterType_Banner``
- ``kParameterType_Presets``
- ``kParameterType_Section``
- ``kParameterType_Links``
- ``kParameterType_Random``
- ``kParameterType_Indicator``
- ``kParameterType_Progress``
- ``kParameterType_MenuAdvanced``
