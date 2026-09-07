# Meta Extension

Own the effect's per-instance parameter meta storage: tags, meta entries, reset values, and target presets, persisted in the document.

## Overview

``FxGripMeta`` is an extension in the notification-driven system described in
<doc:ExtensionArchitecture>. It is an ``FxGripCustomExtension``, so a single object attaches
to the effect and holds a secure-codable custom value. The value is an ``FxGripMetaManager``,
stored in a hidden custom parameter (`kFxParameterId_InstanceMeta`). Activation is driven by
the plist `manageMeta` boolean, which defaults to `YES`; a plugin opts out with
`manageMeta` = NO.

The extension owns the manager's lifecycle across the effect lifecycle:

- Add parameters → registers the hidden InstanceMeta parameter. It carries no state, is never
  presented or animated, and stays out of presets.
- Parameter add → seeds a record for each newly added parameter.
- Added to document → loads the manager from the document and merges pre-load seeded records.
- Parameter changed → applies the target preset a Menu or Toggle change selects, and the
  momentary reset value.
- Flush → persists the manager to the custom parameter.

## Seeding and merge

As each parameter registers, the extension transfers the configuration's tags, meta entries,
reset value, and target-preset definitions into the manager's per-instance record. The
transfer is additive: entries already present, including customizations restored from the
document, are kept, and the configuration fills only absent entries. Target-preset
definitions therefore live in the instance storage and are customizable per instance.

When the effect is added to the document, the extension reads the stored manager. When the
document has no stored manager, the seeded manager is kept. Otherwise the loaded manager wins
and the seeded records fill only its absent entries. Because the merge writes record
dictionaries directly, it raises the manager's unsaved flag by hand so a config that carries
only target or reset keys still flushes.

## Notification priorities

The extension reorders four notifications so its work runs at the right point relative to
``FxGripParameterData`` and the effect's own bookkeeping:

| Notification | Priority | Reason |
| --- | --- | --- |
| `FxGripNotifyAPI_ParameterAddName` | -20 | seed after the add is captured |
| `FxGripTileableEffectAddedToDocumentName` | -18 | load before other observers read the manager |
| `FxGripTileableEffectFlushName` | -14 | flush last, one step after ``FxGripParameterData`` |
| `FxGripTileableEffectParameterChangedName` | -10 | apply after the per-parameter start-time handlers |

## Parameter changed

A Menu or Toggle change applies its target preset through the tags API, with the value, flags,
tags, and meta options. A parameter carrying a reset value is a momentary control: it snaps
back to that value after every change, such as a Menu returning to its main item. The names
section of the target preset runs in a second call, because Final Cut Pro misreports a String
parameter when its name changes earlier in the same pass.

## The resolve bridge

At load, the extension observes `FxGripTileableEffectResolveMetaName` and answers it with its
manager under `FxGripTileableEffectResolvedObjectKey`, so the meta bridge works on a plain
host that loads this extension.

## Topics

### Extension

- ``FxGripMeta``
- ``FxGripMetaManager``
- ``FxGripCustomExtension``
- <doc:ExtensionArchitecture>
