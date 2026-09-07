# Parameter Extensions

Extensions that are themselves effect parameters, so one object both attaches to the effect and behaves as one of its parameters.

## Overview

A parameter extension is an extension in the notification-driven system described in
<doc:ExtensionArchitecture> that also conforms to `FxGripParameter`. A single object attaches
to the effect and behaves as one of its parameters. Three base classes cover the cases:

- ``FxGripParameterExtension-class`` is the base; subclasses adopt a concrete parameter type
  through the included parameter libraries.
- ``FxGripCustomExtension`` models a custom-value parameter.
- ``FxGripToggleExtension`` models a boolean toggle parameter.

The stock extensions ``FxGripMeta``, ``FxGripParameterData``, ``FxGripMLCache``, and
``FxGripAnalysis`` subclass ``FxGripCustomExtension``.

## The base parameter extension

``FxGripParameterExtension-class`` binds to the effect on load and observes
`FxGripNotifyAPI_ParameterAddPreName` at priority -18 through a block observer. The observer
acts only on the notification whose parameter ID matches the extension. It tags the parameter
with the extension key under `kFxParameterProperty_ExtensionKey` when the parameter lacks one,
and sets `kFxParameterProperty_Factory` to the extension when it conforms to
`FxParameterFactory`.

The parameter ID freezes from the first observed add; a later write to `parameterID` after
registration is rejected. The block observer is removed in `dealloc` through a cached notifier,
because the weak effect reference reads nil by then.

`parameterForDictionary:` configures the extension's name, ID, parent ID, and flags from a
parameter dictionary and returns the extension itself as the parameter object. `parameterType`
and the plain `addParameter` path are `NS_UNAVAILABLE`: the base declares no concrete type,
and the extension registers its parameter through the notification seam. The class is
secure-codable.

## The custom extension

``FxGripCustomExtension`` is an ``FxGripParameterExtension-class`` that conforms to
`FxGripCustomParameter`. It holds a secure-codable custom value, read and written directly or
at a specific render time:

- `value` / `setValue:` → the current value.
- `valueAtTime:` / `setValue:atTime:` → the value at a render time.

`dataClasses` is the ordered set of value classes the parameter accepts, seeded with the
Foundation and FxGrip value types. A subclass adds its own value classes by overriding
`dataClasses` and unioning them onto `super.dataClasses`. `addParameter:toEffect:` adds a
custom parameter described by a dictionary to the effect.

## The toggle extension

``FxGripToggleExtension`` is an ``FxGripParameterExtension-class`` that conforms to
`FxGripToggleParameter`. It replicates the boolean toggle behavior through the included toggle
parameter library.

## Topics

### Base classes

- ``FxGripParameterExtension-class``
- ``FxGripCustomExtension``
- ``FxGripToggleExtension``
- <doc:ExtensionArchitecture>
