# ``FxGrip/FxGripExtensionBase-protocol``

The functional protocol an extension implements to observe an effect.

## Overview

An extension is a unit of effect behavior that reaches the effect through its notification stream
rather than through a subclass. The effect owns its extensions and keys them by ``extKey``.

A subclass of ``FxGripExtensionBase-class`` implements only the handlers it needs. On load, the base
registers the extension as an observer for each notification whose handler the subclass implements,
so an unimplemented handler costs nothing.

### Ordering

``ncPriority:`` returns the priority for one notification name, and lower numbers run first. The
range runs from -20 to 20, and ``FxGripExtensionDefaultPriority`` is the middle. An extension whose
work must land before another's overrides ``ncPriority:`` for that name alone.

<doc:ExtensionArchitecture> lays out the order FxGrip's own extensions take.

### Intercepting a host call

A handler whose name ends in `Pre` runs before the host call it names, so an observer serves or
absorbs the call. ``extAPIParameterGetFlagsPre:`` answers a flag read from a cache, and
``extAPIParameterSetFlagsPre:`` takes a flag write into one. ``extAPIParameterAddPre:`` is the one
handler that returns a value, and answering NO refuses the add.

### Extending the parameter type system

An extension maps a configuration type string to an `FxParameterType` through
``extParameterTypeForString:``, and a type to its backing class through
``extParameterClassForType:``. The effect consults every loaded extension when its own type map has
no entry, which is how a plug-in adds a parameter type without subclassing the effect.

## Topics

### Identifying the extension

- ``extKey``
- ``extKeyIndex``
- ``effect``

### Loading

- ``extLoadWithEffect:``
- ``extLoadWithEffect:index:``
- ``extLoadWithIndex:``
- ``extActive``
- ``extIncludeWhenDisabled``
- ``extensionCount``

### Ordering notifications

- ``ncPriority:``
- ``extDefaultPriority``

### The effect's lifecycle

- ``extInit:``
- ``extProperties:``
- ``extAddParameters:``
- ``extFinishInitialSetup:``
- ``extAddedToDocument:``
- ``extRemovedFromDocument:``
- ``extUnload:``

### The user acting on a parameter

- ``extParameterChanged:``
- ``extParameterClicked:``
- ``extFlush:``

### The render pass

- ``extPluginState:``
- ``extDestinationRect:``
- ``extSourceRect:``
- ``extSchedule:``
- ``extRenderDestinationImage:``

### Parameters being created

- ``extAPIParameterAddPre:``
- ``extAPIParameterAdd:``
- ``extAPIParameterStartGroup:``
- ``extAPIParameterEndGroup:``
- ``extAPIParameterRemove:``

### A parameter's name and type

- ``extAPIParameterGetName:``
- ``extAPIParameterSetNamePre:``
- ``extAPIParameterSetName:``
- ``extAPIParameterGetType:``

### A parameter's bounds and menu

- ``extAPIParameterSetIntBounds:``
- ``extAPIParameterSetFloatBounds:``
- ``extAPIParameterGetMenu:``
- ``extAPIParameterSetMenuPre:``
- ``extAPIParameterSetMenu:``

### A parameter's flags

- ``extAPIParameterGetFlagsPre:``
- ``extAPIParameterGetFlags:``
- ``extAPIParameterSetFlagsPre:``
- ``extAPIParameterSetFlags:``

### A parameter's value

- ``extAPIParameterGetStringValue:``
- ``extAPIParameterSetStringValuePre:``
- ``extAPIParameterSetStringValue:``
- ``extAPIParameterSetBool:``
- ``extAPIParameterSetInt:``
- ``extAPIParameterSetFloat:``
- ``extAPIParameterSetXY:``
- ``extAPIParameterSetRGB:``
- ``extAPIParameterSetRGBA:``
- ``extAPIParameterSetHistogram:``
- ``extAPIParameterSetPathID:``
- ``extAPIParameterSetCustomValue:``

### Extending the parameter type system

- ``extParameterTypeForString:``
- ``extParameterClassForType:``
