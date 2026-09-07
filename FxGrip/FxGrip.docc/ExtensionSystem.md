# Extension System

Run FxGrip extensions inside a plug-in that does not subclass the effect base.

## Overview

``FxGripExtensionSystem`` runs the extension machinery described in
<doc:ExtensionArchitecture> as a self-contained subsystem. ``FxGripTileableEffect-class``
drives its extensions by posting lifecycle notifications; this class posts the same
notifications, with the same names and payloads, over an effect host, so a loaded extension
cannot tell the subsystem from the effect base. It is the incremental-adoption path in
<doc:Adoption> for a plug-in built on its own FxPlug base.

The system is created over a host that conforms to `FxGripEffectHost`. An extension observes
the host it was loaded with, so several systems coexist. The parameter-facing extensions,
such as meta, parameter data, and toggles, run on the host alone. An extension that reaches
beyond the host contract needs the fuller member it asks for.

## Using it

Create the system, load the extensions, then forward each FxPlug lifecycle call to the
matching dispatch method:

```objc
self.extensionSystem = [[FxGripExtensionSystem alloc] initWithHost:self];
[self.extensionSystem loadExtension:[FxGripParameterData.alloc init]];
[self.extensionSystem dispatchInit];
```

`loadExtension:` binds an extension to the host and records it when it loads, returning the
extension's own load result. `extensions` lists the loaded extensions in load order, and
`extensionForClass:` returns the first of a class. `dispatchInit` announces the host to the
extensions; call it once after loading them.

## Lifecycle dispatch

| FxPlug call | Dispatch method | Posts |
| --- | --- | --- |
| `-properties:` | `dispatchProperties:` | properties, returns the result |
| `-addParameters` | `dispatchAddParameters:` | parameters, flattened, returns the result |
| end of setup | `dispatchFinishInitialSetup` then `dispatchAddedToDocument` | finish setup, then added to document |
| `-parameterChanged:atTime:error:` | `dispatchParameterChanged:atTime:` | the change, with the ID and encoded time |
| a custom-parameter click | `dispatchParameterClicked:` | the click ID |
| `-pluginState:atTime:error:` | `dispatchPluginStateWithCoder:` | the plug-in state coder |
| after out-of-band writes | `flush` | the flush, returning the collected error or nil |

`dispatchProperties:` and `dispatchAddParameters:` return the dictionary and array the
extensions leave; register what comes back. `dispatchAddParameters:` flattens the parameter
array through `FxGripParameterUtility` in a post-block, so the extensions may add, remove, and
reorder entries.

## Topics

### System

- ``FxGripExtensionSystem``
- <doc:Adoption>
- <doc:ExtensionArchitecture>
