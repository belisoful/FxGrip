# Switch

A boolean custom parameter presented as an `NSSwitch`.

## Overview

The switch is an interactive control that shows a boolean as a macOS switch. A
plugin declares it with the type string `kFxParameterType_Switch` (`switch`).
The class is ``FxGripSwitchParameter`` and its backing view is
``FxGripSwitchView``, an `NSSwitch` subclass. The stored value is an
``FxGripDictionary`` carrying the boolean under `kCustomAPI_BoolKey`. Creation
adds the custom-UI and no-state flags.

## Configuration

The declared default value is a boolean `NSNumber`, not a dictionary. Creation
reads that number and stores it in the value dictionary under
`kCustomAPI_BoolKey`.

| Configuration key | Meaning | Default |
| --- | --- | --- |
| `kFxParameterProperty_Default` | The initial boolean, an `NSNumber`. | `@NO`. |

## Value key

| Key macro | Meaning | Default |
| --- | --- | --- |
| `kCustomAPI_BoolKey` | The stored boolean the view reads and writes. | The declared default. |

## Behavior

Toggling the switch writes the boolean back into the value. The action runs
outside a host call, so the read and write go through an out-of-band access
context at the current time. `updateFromCustomData:` sets the switch state from
the stored boolean.

## Example

```objc
@{
    kFxParameterProperty_Id:      @(kMySwitchID),
    kFxParameterProperty_Name:    @"Enabled",
    kFxParameterProperty_Type:    kFxParameterType_Switch,
    kFxParameterProperty_Default: @YES,
}
```

## Topics

### Control

- ``FxGripSwitchParameter``
- ``FxGripSwitchView``
- ``FxGripDictionary``

### Related

- <doc:Random>
