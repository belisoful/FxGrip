# ``FxGrip/FxGripParameterBase-protocol``

The flags, identity, and host wiring every parameter carries, whether it holds a value or holds children.

## Overview

Every FxGrip parameter conforms to this protocol. It covers the part of a parameter that does not
depend on the parameter having a value: the flag bits, the parameter's identity in the host, and the
wiring back to the effect that owns it.

``FxGripParameter-protocol`` extends it with a leaf parameter's value surface, and
``FxGripSubParameters`` extends that with children.

### Flags

Each `flagXxx` property mirrors one bit of the parameter's `FxParameterFlags`. Reading one reads the
parameter's current flags value, and writing one flips the bit and writes the whole value back.

- `flagCaching` is clear → a flag write reaches the host immediately.
- `flagCaching` is set → a flag write lands in the cache, `flagCacheDirty` turns on, and
  ``parameterFlush`` writes the cache to the host.

<doc:ParameterFlags> gives the bit layout and the configuration strings.

### Identity

``parameterID`` is the host's ID for the parameter, and ``parameterParentID`` is the group's, or 0 at
the top level. ``parameterType-property`` is the parameter's `FxParameterType`. The class-side
``parameterType-type.property`` and ``parameterTypeString`` report what a parameter class registers,
which is how a configuration dictionary names a type.

### The plugin state

``hasState`` answers whether the parameter contributes to the plugin state. A parameter contributes
when it conforms to ``FxGripStateParameter`` and neither it nor any ancestor sets the no-state flag.
Group, Help, and PushButton parameters do not conform, so they carry no state.

See <doc:ParameterModel> for the model as a whole and <doc:PluginState> for what the state holds.

## Topics

### Presentation flags

- ``flagHidden``
- ``flagDisabled``
- ``flagDontDisplayInDashboard``
- ``flagHiddenProxy``

### Debug flags

- ``flagInDebugMode``
- ``flagNoDebug``

### State and validity flags

- ``flagNoState``
- ``flagInvalid``

### The flag cache

- ``flagCaching``
- ``flagCacheDirty``
- ``parameterFlush``

### Reading and writing the whole flags value

- ``parameterFlags``
- ``parameterCurrentFlags``

### Identifying the parameter

- ``parameterID``
- ``parameterParentID``
- ``parameterName``
- ``parameterType-property``
- ``parameterType-type.property``
- ``parameterTypeString``
- ``extKey``

### Reaching the effect

- ``effect``
- ``addedToEffect``
- ``error``

### Contributing to the plugin state

- ``hasState``

### Creating a parameter

- ``addParameter:toEffect:``
- ``createdWithFlags:parentID:``
- ``setParameterParentID:``

### Responding to a change

- ``startChangedTime:error:``
- ``endChangedTime:error:``
- ``validate``
