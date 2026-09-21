# ``FxGrip/FxGripPresetsAPI_v1-protocol``

The preset capture, application, discovery, and file layer.

## Overview

No host vends a presets API. FxGrip implements this one itself, so it resolves whatever the host
provides. An effect reaches it as `presetsAPIv1` on ``FxGripAPIAccessing-protocol``.

### Capturing and applying

``generatePreset:fromLabel:`` captures every runtime parameter's value at time zero, plus its tags
and meta, and stamps the plug-in's identity onto the result. A parameter flagged PRESETNOTAGS or
PRESETNOMETA opts out of that section.

``setPreset:options:atTime:`` applies one. It checks compatibility, then applies the values, tags,
and meta sections through the tag API core, so the tag boundary decides which parameters change.
``FxGripParameterPresetFlagOptions`` relaxes each of those three checks in turn.

### Finding presets

Presets live in two places: the plug-in's bundled `Presets` folder, and the managed user folder
under `~/Library/Application Support`. ``presetsForTag:`` merges both listings, and the two
single-source methods read one each.

``observeTag:observer:`` watches the managed user folder for a tag, so a preset menu refreshes when
the user adds or removes a file. Releasing the returned watcher ends the watch.

### Files

``savePreset:remap:`` and ``loadPreset:remap:`` go through the save and open panels, reading and
writing FxFactory's `.fxpreset` property-list form. A file written here carries FxFactory's own
keys alongside FxGrip's, so either application reads the other's file.

<doc:Presets> covers the preset model and the file format.

## Topics

### Capturing and applying a preset

- ``generatePreset:fromLabel:``
- ``setPreset:options:``
- ``setPreset:options:atTime:``
- ``compatiblePreset:``

### Browsing presets

- ``presetsForTag:``
- ``pluginPresetsForTag:``
- ``userPresetsForTag:``
- ``observeTag:observer:``

### Locating the preset folders

- ``pluginPresetURL``
- ``pluginPresetURL:``
- ``userPresetURL``
- ``userPresetURL:``

### Reading and writing a preset file

- ``savePreset:remap:``
- ``loadPreset:remap:``
