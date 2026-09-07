# Random

An integer custom parameter with a field, a stepper, and a reload button that randomizes it.

## Overview

The random control shows an editable integer field, an up-down stepper, and a
reload button, left to right. A plugin declares it with the type string
`kFxParameterType_Random` (`random`). The class is ``FxGripRandomParameter`` and
its backing view is ``FxGripRandomView``. The value is an ``FxGripDictionary``
carrying the integer under the int key, with the range and step under dedicated
keys declared in `FxGripRandom.h`. Creation adds the custom-UI and no-state
flags.

## Value keys

| Key macro | Meaning | Default |
| --- | --- | --- |
| `kFxGripRandomKey_Value` (`kCustomAPI_IntKey`) | The current integer. | `0` (`kFxGripRandomDefaultValue`). |
| `kFxGripRandomKey_Min` (`"min"`) | The range minimum. | `0` (`kFxGripRandomDefaultMin`). |
| `kFxGripRandomKey_Max` (`"max"`) | The range maximum. | `2147483647` (`kFxGripRandomDefaultMax`, `INT32_MAX`). |
| `kFxGripRandomKey_Step` (`"step"`) | The stepper increment. | `1` (`kFxGripRandomDefaultStep`). |

## Behavior

- Editing the field → the value is clamped to the range and written back.
- Changing the stepper → the value is clamped to the range and written back.
- Clicking reload → a uniform integer is drawn in the closed range from min to max, then written back.

Each write runs outside a host call, so it goes through an out-of-band access
context at the current time. A changed min, max, or step reconfigures the
stepper. `updateFromCustomData:` clamps the value to the range before display.

## Example

```objc
@{
    kFxParameterProperty_Id:      @(kMyRandomID),
    kFxParameterProperty_Name:    @"Seed",
    kFxParameterProperty_Type:    kFxParameterType_Random,
    kFxParameterProperty_Default: @{
        kFxGripRandomKey_Value: @1234,
        kFxGripRandomKey_Min:   @1,
        kFxGripRandomKey_Max:   @100000,
        kFxGripRandomKey_Step:  @1,
    },
}
```

## Topics

### Control

- ``FxGripRandomParameter``
- ``FxGripRandomView``
- ``FxGripDictionary``

### Related

