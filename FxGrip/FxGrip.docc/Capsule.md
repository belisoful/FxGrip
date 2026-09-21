# Capsule

A read-only pill badge sized to its text that keeps its row label.

## Overview

The capsule is a display control that draws a rounded-rectangle fill behind a
centered label. A plugin declares it with the type string
`kFxParameterType_Capsule` (`capsule`). The class is ``FxGripCapsuleParameter``
and its backing view is ``FxGripCapsuleView``. The value is an
``FxGripDictionary`` carrying the text, point size, colors, and corner radius
declared in `FxGripCapsule.h`.

The badge sizes itself to the text plus padding and keeps the parameter name as
its inspector row label. Creation adds the custom-UI, not-animatable, and
no-state flags.

## Value keys

| Key macro | Meaning | Default |
| --- | --- | --- |
| `kFxGripCapsuleKey_Title` (`kCustomAPI_StringKey`) | The badge text. | Empty. |
| `kFxGripCapsuleKey_FontSize` (`kCustomAPI_FloatKey`) | The point size. | `11.0` (`kFxGripCapsuleDefaultFontSize`). |
| `kFxGripCapsuleKey_FillColor` (`kCustomAPI_RGBAKey`) | The fill color, as an RGBA array. | System gray. |
| `kFxGripCapsuleKey_TextColor` (`"textColor"`) | The text color, as an RGBA array. | White. |
| `kFxGripCapsuleKey_CornerRadius` (`"cornerRadius"`) | The corner radius, in points. | `-1.0` (`kFxGripCapsulePillRadius`), a full pill. |

## Behavior

- Corner radius zero or above → a rounded rectangle at that radius.
- Corner radius below zero → a full pill, using half the badge height as the radius.
- Point size above zero → the label font uses that size.

The badge is read-only. The effect changes it by setting the parameter value,
and `updateFromCustomData:` relays out the badge.

## Example

```objc
@{
    kFxParameterProperty_Id:      @(kMyCapsuleID),
    kFxParameterProperty_Name:    @"Stage",
    kFxParameterProperty_Type:    kFxParameterType_Capsule,
    kFxParameterProperty_Default: @{
        kFxGripCapsuleKey_Title:     @"Beta",
        kFxGripCapsuleKey_FontSize:  @11.0,
        kFxGripCapsuleKey_FillColor: @[ @0.85, @0.65, @0.13, @1.0 ],
        kFxGripCapsuleKey_TextColor: @[ @0.0, @0.0, @0.0, @1.0 ],
    },
}
```

## Topics

### Control

- ``FxGripCapsuleParameter``
- ``FxGripCapsuleView``
- ``FxGripDictionary``

### Related

### Configuration keys

- ``kFxGripCapsuleKey_CornerRadius``
- ``kFxGripCapsuleKey_FillColor``
- ``kFxGripCapsuleKey_FontSize``
- ``kFxGripCapsuleKey_TextColor``
- ``kFxGripCapsuleKey_Title``

### Defaults

- ``kFxGripCapsuleDefaultFontSize``
- ``kFxGripCapsulePillRadius``
