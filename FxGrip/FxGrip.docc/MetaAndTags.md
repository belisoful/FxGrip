# Meta and Tags

Attach arbitrary per-parameter metadata and tags to an effect instance, stored with the document and reachable through host-style APIs.

## Overview

FxGrip adds two per-parameter stores that FxPlug does not provide. Meta is arbitrary secure-codable data attached to a parameter. Tags are string labels attached to a parameter, with a reverse index from a tag to the parameters that carry it. Both persist with the effect's plugin state and travel in a preset.

``FxGripMetaManager`` holds both stores for one effect instance. Two host-style APIs read and write them: ``FxGripMetaAPI_v1-class`` for meta, and ``FxGripParameterTagsAPI_v1-class`` for tags. FxGrip owns both APIs; no host vends them. The ``FxGripMeta`` extension owns the manager and drives its lifecycle. <doc:APIAccessing> vends the API wrappers.

## The meta manager

``FxGripMetaManager`` is the value of the hidden `kFxParameterId_InstanceMeta` custom parameter, so it saves and loads with the host document. Its archive root holds two entries:

- a tag reverse index under `kFxMetaProperty_Tags`, from a tag string to an array of parameter IDs.
- a parameter record store under `kFxMetaProperty_Parameters`, from a parameter ID to a record.

Each record carries `kFxMetaProperty_ParamId`, a `kFxMetaProperty_ParamTags` array, and a `kFxMetaProperty_ParamMeta` dictionary. Parameter types and flags belong to `FxGripParameterData`, not to the meta record.

A record is created for a parameter ID with `addParameter:`, and removed with `removeParameter:`, which also scrubs the ID from the tag reverse index. `parameterData:` returns the live mutable record rather than a copy.

### Locking

Every public method takes the manager's recursive lock. A caller that composes a multi-step atomic edit takes the lock across its own call sequence with the `lock` / `lockWithinTime:` / `unlock` triple. `lockWithinTime:` tries once when `tryTime` is `≤ 0`, and otherwise waits up to `tryTime` seconds.

### Persistence

Every mutation marks the manager unsaved. `saveMeta` writes the manager to the host as the `InstanceMeta` custom parameter value and clears the unsaved state. It runs only when unsaved, and it needs the effect's parameter-setting API. When that API is unavailable the manager stays unsaved and `saveMeta` returns NO, so a later flush persists the state.

## The meta API

``FxGripMetaAPI_v1-class`` forwards every call to the host's meta manager. A host without a meta manager answers the not-found result. The API reads and writes a parameter's whole meta dictionary, one key at a time, or its key list:

```objc
id<FxGripMetaAPI_v1> meta = self.apiManager.metaAPIv1;
[meta setMeta:@"linear" forKey:@"colorSpace" toParameter:kAmountID];

id<NSSecureCoding, NSCopying> value = nil;
[meta getMeta:&value forKey:@"colorSpace" fromParameter:kAmountID];
```

A whole-dictionary read fills an out-parameter and returns an `NSError`, nil on success. `metaCountFromParameter:` returns the entry count, or −1 when no record exists. `parameter:hasMetaKey:error:` answers a key's presence.

## The tags API

``FxGripParameterTagsAPI_v1-class`` stores tags on parameters and queries parameters by tag. Tag storage forwards to the effect's meta manager and returns a no-meta error when the host carries none.

```objc
id<FxGripParameterTagsAPI_v1> tagsAPI = self.apiManager.parameterTagsAPIv1;
[tagsAPI addTag:@"color" toParameter:kAmountID];
NSArray *colorParams = [tagsAPI parametersWithTag:@"color"];
```

`tags` returns every tag in use across the effect, `tagCount` the distinct-tag count, and `parameterTags:` the tags on one parameter. `setTags:toParameter:`, `addTag:toParameter:`, `removeTag:fromParameter:`, and `removeAllTags:` mutate a parameter's tags and keep the reverse index current.

### Tags address presets

The tags API also resolves a tag to a preset definition and applies it. `presetDefinitionForTag:` reads the plugin plist's `presets` table. `applyPreset:atTime:options:presetFlags:source:tag:` applies a definition, and every preset entry point funnels into it, so the tag boundary and the section order hold for every caller. Sections apply in a fixed order: values, flags, tags, meta, names. Names run last because the host misreports string parameters when a name changes earlier in the same pass. <doc:Presets> documents the preset system that builds on this.

## The meta extension

``FxGripMeta`` owns the manager. The extension registers the hidden `InstanceMeta` parameter, loads the manager from the document when the effect is added, seeds a record for each parameter as it is created, applies target presets on parameter changes, and persists the manager on flush.

Configuration transfer is additive. A value already present in a record, including a customization restored from the document, is kept, and the configuration supplies a default for an absent entry only. Target-preset definitions therefore live in the instance storage and are customizable per instance.

Activation follows the plist `manageMeta` boolean, which defaults to YES, through the standard extension loading path. A plug-in opts out with `manageMeta` set to NO. The effect reads the loaded manager through `meta` and its presence through `hasMeta`. The <doc:Meta> extension page covers activation in the extension system.

## Topics

### Storage

- ``FxGripMetaManager``

### APIs

- ``FxGripMetaAPI_v1-class``
- ``FxGripParameterTagsAPI_v1-class``

### The extension

- ``FxGripMeta``

### Related articles

- <doc:APIAccessing>
- <doc:Meta>

### The meta keys

- ``kFxMetaProperty_ParamId``
- ``kFxMetaProperty_ParamMeta``
- ``kFxMetaProperty_ParamTags``
- ``kFxMetaProperty_Parameters``
- ``kFxMetaProperty_SelectedPreset``
- ``kFxMetaProperty_Tags``
