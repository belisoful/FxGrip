# ML Cache

Own an ML effect's per-frame inference cache, backed by the project media cache so results survive a reopen.

## Overview

``FxGripMLCache`` is an extension in the notification-driven system described in
<doc:ExtensionArchitecture>. It is an ``FxGripCustomExtension`` that owns an
``FxGripFrameData`` inference cache. The cache stores ``FxGripImageBuffer`` copies of
inference outputs, keyed by frame, so a multi-second model runs once per frame. See
<doc:Inference> for the ML effect template that uses it.

The extension registers a hidden custom parameter (`kFxParameterId_MLCache`) whose value is
the frame data, loads it from the document when the effect is added, and attaches the project
media cache so cached frames spill to disk and survive a reopen.

## What it observes

- Add parameters → registers the hidden MLCache custom parameter. It carries no state, is
  never presented or animated, and stays out of presets.
- Added to document → resolves the stored frame data from the custom parameter, then
  reattaches the project media cache.

The cache is transient and never encoded, so the media cache is re-resolved after every
document load. `frameData` creates the store on demand and attaches the media cache, so it is
never nil once accessed. `dataClasses` adds ``FxGripFrameData``, ``FxGripImageBuffer``, and
the frame-data value classes to the accepted custom-value set.

## Reaching the cache

`FxGripMLImageEffect` loads this extension and reads and writes the cache through the effect's
`mlCacheData`, which resolves the loaded extension's frame data. `hasMLCache` reports whether
the extension is loaded.

## Topics

### Extension

- ``FxGripMLCache``
- ``FxGripFrameData``
- ``FxGripCustomExtension``
- <doc:Inference>
- <doc:ExtensionArchitecture>
