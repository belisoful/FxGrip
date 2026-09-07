# Progress

A read-only progress display: a bar with a status dot and a label.

## Overview

The progress control adds a bar beneath the same status dot and label as the
status control. A plugin declares it with the type string
`kFxParameterType_Progress` (`progress`). The class is
``FxGripProgressParameter`` and its backing view is ``FxGripProgressView``. The
value is an ``FxGripDictionary`` carrying the bar fraction under the float key,
the dot state under the integer key, and the label under the string key.

The bar is an `NSProgressIndicator` and the dot is a BEFoundation `BEDotView`.
The control is read-only, so the effect reports progress by setting the
parameter value. Creation adds the custom-UI and no-state flags.

## Value keys

| Key macro | Meaning | Default |
| --- | --- | --- |
| `kCustomAPI_FloatKey` | The bar fraction. A value in `0…1` is determinate; a negative value is indeterminate. | `0.0`. |
| `kCustomAPI_IntKey` | The dot state, a `BEDotState`. | `BEDotStateOff`. |
| `kCustomAPI_StringKey` | The label text. | Empty. |

## Behavior

- Fraction below zero → the bar spins as an indeterminate animation.
- Fraction from zero to one → the bar shows that determinate fraction.
- Fraction above one → the bar clamps to one.

The integer value sets the dot's `BEDotState`, drawn from the shared dot palette
(off gray, ok green, warning yellow, error red, active blue). The string value
sets the label. A value that is not an ``FxGripDictionary`` is ignored.

## Example

```objc
@{
    kFxParameterProperty_Id:      @(kMyProgressID),
    kFxParameterProperty_Name:    @"Export",
    kFxParameterProperty_Type:    kFxParameterType_Progress,
    kFxParameterProperty_Default: @{
        kCustomAPI_IntKey:    @(BEDotStateActive),
        kCustomAPI_StringKey: @"Exporting",
        kCustomAPI_FloatKey:  @0.62,
    },
}
```

## Topics

### Control

- ``FxGripProgressParameter``
- ``FxGripProgressView``
- ``FxGripDictionary``

### Related

