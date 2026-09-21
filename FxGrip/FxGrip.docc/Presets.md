# Presets

Capture an effect's parameters as a preset, apply presets from the plugin and the user, read and write the FxFactory `.fxpreset` file form, and offer them in a menu.

## Overview

A preset is a captured set of parameter values, tags, and meta, plus the identity of the plugin that produced them. FxGrip provides the preset model, a host-style API that captures, applies, browses, and files presets, and an inspector control that lists the presets for a tag and applies the one the user picks. FxGrip owns the presets API; no host vends it. <doc:APIAccessing> vends the wrapper.

Preset application funnels through the tags API core, so the tag boundary and the section order hold for every path into a preset (see <doc:MetaAndTags>).

## The preset model

``FxGripPreset`` holds one preset. Its fields carry the captured parameter data and the plugin identity:

- `parameterValues`, `parameterTags`, `parameterMeta` → the captured sections, each keyed by parameter ID.
- `createdByParameterId` → the ID of the parameter that created the preset, or 0.
- `framework`, `uuid`, `name`, `tag`, `createdTime` → the preset's own identity.
- `pluginUuid`, `pluginVersion`, `pluginAuthor`, `pluginLocalizedName`, `productId` → the producing plugin's identity, which drives compatibility.

`presetDictionary` and `initWithPresetDictionary:` are the canonical round-trip to and from the file-form dictionary. `presetSections` returns the values, tags, and meta sections in the shape the apply path consumes.

## The FxFactory file form

The on-disk form is an XML property list in FxFactory's `.fxpreset` format, extended with flat FxGrip keys. A written file carries the seven FxFactory keys under their exact names, so FxFactory reads an FxGrip file and FxGrip reads an FxFactory file:

| FxFactory file key | Preset field |
| --- | --- |
| `FxFactoryPresetParameterValues` | `parameterValues` |
| `FxFactoryPresetCreatedByParameterID` | `createdByParameterId` |
| `FxFactoryPresetPlugInUUID` | `pluginUuid` |
| `FxFactoryPresetPlugInVersion` | `pluginVersion` |
| `FxFactoryPresetPlugInAuthor` | `pluginAuthor` |
| `FxFactoryPresetPlugInLocalizedName` | `pluginLocalizedName` |
| `FxFactoryPresetProductID` | `productId` |

The FxGrip additions have no FxFactory equivalent. The seven `FxGripPreset*` keys carry the framework, the preset UUID, the display name, the tag, the created time, and the parameter tags and meta, and they ride alongside the FxFactory keys as flat siblings. A reader ignores keys it does not know, so both directions degrade to the shared subset. Parameter-keyed dictionaries use string parameter-ID keys on disk, matching FxFactory.

`savePresetToURL:` writes the property list, and `loadPresetFromURL:` reads a file written by FxGrip or by FxFactory.

## The presets API

``FxGripPresetsAPI_v1-class`` captures, applies, browses, and files presets. It is constructed without a host API, because FxGrip implements it itself.

Capture and apply:

```objc
id<FxGripPresetsAPI_v1> presets = self.apiManager.presetsAPIv1;

FxGripPreset *preset = nil;
[presets generatePreset:&preset fromLabel:@"Warm"];   // captures values, tags, meta at time zero
[presets setPreset:preset options:kFxParameterPreset_Default atTime:renderTime];
```

`generatePreset:fromLabel:` captures every runtime parameter's value at time zero, plus its tags and meta, and fills the plugin identity from the effect. A parameter flagged PRESETNOTAGS or PRESETNOMETA opts out of the tags or meta capture. `setPreset:options:atTime:` verifies compatibility, then applies the values, tags, and meta sections with `FxGripPresetSourceFile` and the preset's tag, so the tag boundary governs which parameters change. The options relax the apply:

- `kFxParameterPreset_IgnoreCompatibility` → skip the plugin-UUID compatibility check.
- `kFxParameterPreset_IgnoreTagBoundary` → apply to a parameter the tag does not cover.
- `kFxParameterPreset_IgnoreMetaData` → skip the meta section.

`compatiblePreset:` answers whether a preset's plugin UUID matches the effect's, or appears in the plugin's `supportedPlugins` alternatives.

### Browsing and files

The API merges two preset sources for a tag. `pluginPresetsForTag:` returns the premade presets: the plist `presets` table entries, then the bundled `.fxpreset` files under the plugin's `Presets` resource folder. `userPresetsForTag:` returns the `.fxpreset` files in the managed user folder. `presetsForTag:` is the merged listing, plugin then user.

The managed user folder is `~/Library/Application Support/<company>/<plugin name>/<tag>/`, where the company and plugin names are version agnostic, so presets survive plugin updates. `savePreset:remap:` runs the save panel starting in that folder, and `loadPreset:remap:` runs the open panel. `presetDictionary` already writes the FxFactory file keys, so `kFxFactoryPresetKeyMap` and a nil `remap` are equivalent. `observeTag:observer:` watches the managed per-tag folder and runs the handler on each change; the caller keeps the returned `BEPathWatcher` alive.

## The presets control

``FxGripPresetsParameter`` is the inspector control. It extends ``FxGripMenuParameter``, so the host draws a popup menu and no custom view is created (see <doc:CustomControls>). Declare it with the `presets` type:

```objc
@{
    kFxParameterProperty_Id:   @(kMyPresetsID),
    kFxParameterProperty_Name: @"Preset",
    kFxParameterProperty_Type: kFxParameterType_Presets,
}
```

The menu is built as `Default, -, <user presets>, -, <plugin presets>, -, Reveal User Presets in Finder..., Save Preset`; an empty preset section drops together with its separator. The tag is the configuration's first entry under `tags`.

Selecting a preset name applies it through the presets API and records the name under `kFxMetaProperty_SelectedPreset` in the instance record. The host persists a menu as an integer, and the name keeps the selection stable when entries are appended, removed, or reordered across plugin versions. A user preset shadows a plugin preset of the same name, matching the menu order. Selecting Default records the default state and applies nothing. Reveal opens the managed folder in Finder, and Save Preset captures the current state and runs the save panel; both restore the previous selection afterward.

The managed per-tag folder is watched. A file added, removed, or renamed there rebuilds the menu on the host and remaps the recorded selection name to its new index.

## Topics

### Model and API

- ``FxGripPreset``
- ``FxGripPresetsAPI_v1-class``

### Control

- ``FxGripPresetsParameter``

### Related articles

- <doc:APIAccessing>
- <doc:MetaAndTags>

### The preset file keys

- ``kFxPresetProperty_ColorSpace``
- ``kFxPresetProperty_CreatedByParameterId``
- ``kFxPresetProperty_CreatedTime``
- ``kFxPresetProperty_DisplayName``
- ``kFxPresetProperty_Extension``
- ``kFxPresetProperty_Framework``
- ``kFxPresetProperty_LocalizedName``
- ``kFxPresetProperty_ParameterMeta``
- ``kFxPresetProperty_ParameterTags``
- ``kFxPresetProperty_ParameterValues``
- ``kFxPresetProperty_PluginAuthor``
- ``kFxPresetProperty_PluginUuid``
- ``kFxPresetProperty_PluginVersion``
- ``kFxPresetProperty_PresetUuid``
- ``kFxPresetProperty_ProductId``
- ``kFxPresetProperty_RemapValues``
- ``kFxPresetProperty_Tag``

### FxFactory's own keys

- ``kFxFactoryPresetKeyMap``
- ``kFxFactoryPresetKey_CreatedByParameterId``
- ``kFxFactoryPresetKey_LocalizedName``
- ``kFxFactoryPresetKey_ParameterValues``
- ``kFxFactoryPresetKey_PluginAuthor``
- ``kFxFactoryPresetKey_PluginUuid``
- ``kFxFactoryPresetKey_PluginVersion``
- ``kFxFactoryPresetKey_ProductId``

### The preset file extension

- ``kFxPreset_Extension``

### The presets menu

- ``kFxPresetsMenuEntry_Default``
- ``kFxPresetsMenuEntry_Reveal``
- ``kFxPresetsMenuEntry_Save``
- ``kFxPresetsMenuEntry_Separator``

### Preset types

- ``FxGripPresetOptions``
- ``FxGripPresetSource``
- ``FxGripParameterPresetFlagOptions``
- ``FxGripParameterPresetFlags``

### FxGrip's flat sibling keys

- ``kFxGripPresetKey_Uuid``
- ``kFxGripPresetKey_DisplayName``
- ``kFxGripPresetKey_Framework``
- ``kFxGripPresetKey_Tag``
- ``kFxGripPresetKey_CreatedTime``
- ``kFxGripPresetKey_ParameterTags``
- ``kFxGripPresetKey_ParameterMeta``
- ``kFxFactorPresetColorSpace_sRGB_Color``
