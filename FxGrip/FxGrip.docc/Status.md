# Status

A read-only status indicator drawn as a colored dot with a label.

## Overview

The status control pairs a colored dot with a trailing label. A plugin declares
it with the type string `kFxParameterType_Status` (`status`). The class is
``FxGripStatusParameter`` and its backing view is ``FxGripStatusView``. The value
is an ``FxGripDictionary`` carrying the dot state under the integer key and the
label under the string key.

The dot is a BEFoundation `BEDotView`, so the light matches the shared dot
palette. The control is read-only, so the effect reports status by setting the
parameter value, and `updateFromCustomData:` redraws the dot and label. Creation
adds the custom-UI and no-state flags.

## Value keys

| Key macro | Meaning | Default |
| --- | --- | --- |
| `kCustomAPI_IntKey` | The dot state, a `BEDotState`. | `BEDotStateOff`. |
| `kCustomAPI_StringKey` | The label text. | Empty. |

## Dot states

| State | Color |
| --- | --- |
| `BEDotStateOff` | Gray. |
| `BEDotStateOk` | Green. |
| `BEDotStateWarning` | Yellow. |
| `BEDotStateError` | Red. |
| `BEDotStateActive` | Blue. |

## Behavior

The integer value sets the dot's `BEDotState`. The string value sets the label
text. A value that is not an ``FxGripDictionary`` is ignored. The declared
default seeds the initial state and label; the host pushes the live value after
the view attaches.

## Example

```objc
@{
    kFxParameterProperty_Id:      @(kMyStatusID),
    kFxParameterProperty_Name:    @"State",
    kFxParameterProperty_Type:    kFxParameterType_Status,
    kFxParameterProperty_Default: @{
        kCustomAPI_IntKey:    @(BEDotStateOk),
        kCustomAPI_StringKey: @"Ready",
    },
}
```

## Topics

### Control

- ``FxGripStatusParameter``
- ``FxGripStatusView``
- ``FxGripDictionary``

### Related

- <doc:Progress>
