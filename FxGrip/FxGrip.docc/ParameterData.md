# Parameter Data

Mirror each parameter's static properties in the document, because FxPlug does not vend them back to the plugin after creation.

## Overview

``FxGripParameterData`` is an extension in the notification-driven system described in
<doc:ExtensionArchitecture>. FxPlug does not return a parameter's type, flags, parent, menu
items, or selector to the plugin after the parameter is created. This extension captures those
entries from the add notification, persists them to a hidden custom parameter
(`kFxParameterId_ParameterData`), and answers reads for them. It is an
``FxGripCustomExtension``, so its store rides in the custom parameter's value.

The store is a dictionary keyed by parameter ID; each value is that parameter's record. The
record keys alias the parameter property keys the payloads carry: `kExtParameterData_Type`,
`kExtParameterData_Flag`, `kExtParameterData_SubGroup`, `kExtParameterData_MenuItems`, and
`kExtParameterData_Selector`.

## What it observes

- Add parameters → registers the hidden ParameterData custom parameter. It carries no state,
  is never presented or animated, and stays out of the debug view.
- Parameter add → copies the parameter's configuration into the store, keyed by ID.
- Added to document → loads the stored records from the custom parameter.
- Get flags → merges the stored app-mask flag bits into the flags the read reports.
- Set flags → recaptures the app-mask flags on a write, dropping temporary bits first.
- Set menu → recaptures the menu items on a write.
- Parameter remove → drops the parameter's record.
- Flush → persists the store to the custom parameter when it has unsaved changes.

## Notification priorities

The store must be current before other observers read it, so the extension reorders three
notifications:

| Notification | Priority | Reason |
| --- | --- | --- |
| `FxGripNotifyAPI_ParameterAddName` | -20 | seed the store before the parameters are constructed, ahead of the effect's -18 capture |
| `FxGripTileableEffectAddedToDocumentName` | -18 | load the stored records early |
| `FxGripTileableEffectFlushName` | -13 | persist after the effect's -14 flag flush, so the flag words it writes are captured this cycle |

## Accessors

The stored records answer reads for the properties FxPlug will not vend:

- `storedType:` → the stored type, or 0 when unknown.
- `storedFlags:` → the stored flags, or 0 when unknown.
- `storedParentId:` → the stored parent group ID, or -1 when unknown.
- `storedMenus:` → the stored menu items, or nil when unknown.
- `storedSelector:` → the stored action selector, or nil when unknown.

`setObject:forKey:toParameter:` writes a value into a record when it differs and marks the
store dirty; `objectForKey:fromParameter:` reads one. `isLoaded` reports whether the store
exists, and `isCacheDirty` reports unsaved changes.

## The resolve bridge

At load, the extension observes `FxGripTileableEffectResolveParameterDataName` and answers it
with itself under `FxGripTileableEffectResolvedObjectKey`, so the stored menus and flags reach
a plain host that loads it.

## Topics

### Extension

- ``FxGripParameterData``
- ``FxGripCustomExtension``
- <doc:ExtensionArchitecture>
