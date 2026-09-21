# The Parameter Model

The base classes and protocols every FxGrip parameter adopts, and how an effect reaches a parameter object.

## Overview

Every FxGrip parameter derives from a common root. ``FxGripParameterBase-class``
holds the flags, identity, and host wiring shared by group and regular parameters.
``FxGripParameter-class`` adds the value, bounds, and custom-view surface of a leaf
parameter. A parameter object wraps one host parameter, reads and writes it through
the effect's parameter APIs, and observes the effect's notifier for flag changes.

The value-parameter classes in <doc:StandardValueParameters> and the custom
controls in <doc:CustomControls> all build on this root.

## The base protocols

The model layers its interface across protocols.

- `FxGripParameterBase` → the flags, ID, type, name, parent ID, and error shared by every parameter, plus the class factory that adds a parameter to an effect.
- `FxGripParameter` → a leaf parameter's value flags, value bounds, string and bool value accessors, and custom view.
- `FxGripSubParameters` → a parameter that holds children, such as a group. It adds and removes children, counts and enumerates the direct children and the whole descendant tree, and reaches a child by index.
- `FxGripStateParameter` → marks a parameter whose value belongs in the plugin state.
- `FxGripParameterMinMax`, `FxGripParameterMinMaxInt`, `FxGripParameterMinMaxDouble` → the min/max opt-out and the numeric value and slider bounds.

A parameter conforms to `FxGripStateParameter` when its value is saved. Group, Help,
and PushButton parameters do not conform, so they carry no state.

## The base classes

``FxGripParameterBase-class`` is the concrete root. It stores the parameter's
dictionary, resolves the flags, identity, and name through the effect's parameter
APIs, and registers flag observers on the effect's notifier through
`-installNotifications`. It encodes the parameter type into the plugin state. Its
`+parameterType`, `-parameterType`, and `+addParameter:toEffect:` are unavailable on
the base and are overridden by a concrete parameter class.

``FxGripParameter-class`` adds the leaf surface: the custom inspector view
(`-newParameterView`, `-attachCustomView:`), the secure-coding allow-list for a
custom value (`+customValueClasses`), and the parameter's description, tags, meta,
custom classes, and default and reset values.

Each parameter registers its type with two class methods.

- `+parameterType` → the `FxParameterType` case the class maps to.
- `+parameterTypeString` → the type-key string the class registers, such as `float`.

A parameter reads its live flags from the host and caches them while it is being
built. The `flagXxx` boolean properties, such as `flagHidden` and `flagDisabled`,
read and write one flag bit each. See <doc:ParameterFlags>.

## The parameter libraries

The class methods are shared through library fragments included at compile time.
`FxGripParameterBaseLibrary.m` holds the ``FxGripParameterBase-class`` method
bodies: the notification wiring, the boolean flag accessors, the state test, and the
name, type, flags, and plugin-state coding. `FxGripParameterLibrary.m` holds the
``FxGripParameter-class`` leaf-value flag accessors. A parameter class and its
extension variant include the same library, so both share one implementation.

## Reaching a parameter from an effect

An effect reaches a parameter object by subscripting.

- `effect[id]` → the parameter for a numeric ID, through `-objectAtIndexedSubscript:`. A non-positive index is an ordinal position: `effect[0]` is the first parameter, `effect[-1]` the second, and so on until nil.
- `effect[@"name"]` → an extension by name, or the parameter for a numeric string, through `-objectForKeyedSubscript:`.

```objc
FxGripFloatParameter *gain = (FxGripFloatParameter *)self[kMyGainID];
double value = [gain valueAtTime:renderTime];
```

The effect enumerates its parameters through fast enumeration.

## Reconstruction

The effect keeps the parameter objects in step with the host's parameters. When
parameters are added, the effect reconstructs the objects from the stored
configuration.

- `-reconstructParametersWithGroupID:` walks a group's configuration records and recurses into subgroups.
- `-constructParameter:` builds one parameter object from a configuration record, registers it by ID, and attaches it to its parent group when the record names one.

Construction resolves the record's type to a parameter class and initializes the
class with the record and the effect. The effect resolves a type string to a class
with `-parameterClassWithTypeString:` and a numeric type with
`-parameterClassWithType:`, falling back to a loaded extension's class for a custom
type string the built-in map does not know. `-registerParameterType:` maps each
class into the type-to-class map by both its numeric type and its type-key string.

A removed host parameter drops its object, and `effect[id]` returns nil for it.

## Custom values and the typed API

A custom parameter's value can answer the host's typed get and set API directly. A
value that adopts ``FxGripMutableParameter`` implements the accessors for the types
it represents, such as `-getIntValue:`, `-setFloatValue:`, or `-getRedValue:greenValue:blueValue:alphaValue:`.
FxGrip routes the host's typed accessors to the value. Each method is optional; a
getter returns YES when it supplies a value, and a setter returns YES when it accepts
the value.

## Topics

### Base classes

- ``FxGripParameterBase-class``
- ``FxGripParameter-class``

### Custom values

- ``FxGripMutableParameter``

### Related

- <doc:StandardValueParameters>
- <doc:ParameterFlags>
- <doc:CustomControls>

### The parameter protocols

- ``FxGripParameter-protocol``
- ``FxGripParameterBase-protocol``
- ``FxGripStateParameter``
- ``FxGripSubParameters``
- ``FxGripToggleParameter-protocol``
- ``FxGripCustomParameter-protocol``
- ``FxParameterFactory``

### Numeric bounds

- ``FxGripParameterMinMax``
- ``FxGripParameterMinMaxInt``
- ``FxGripParameterMinMaxDouble``

### Identifying a parameter

- ``FxParameterId``
- ``FxPlugRootGroupID``
- ``kFxAllParameters``
- ``kFxParameterPropertyX_PathID``

### Helpers

- ``FxGripParameterUtility``
- ``kFxGripParameterErrorBool``
- ``kFxGripPluginStateParameterTypeString``
