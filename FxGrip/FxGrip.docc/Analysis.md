# Analysis Extension

Own the effect's per-frame analysis storage, loaded automatically when the effect analyzes its input.

## Overview

``FxGripAnalysis`` is an extension in the notification-driven system described in
<doc:ExtensionArchitecture>. It is an ``FxGripCustomExtension`` that owns an
``FxGripFrameData`` store for per-frame analysis records. The extension loads automatically
when the effect conforms to the FxPlug `FxAnalyzer` protocol. The analysis pass reads and
writes the store; see <doc:AnalysisPass> for the pass, and <doc:ObjectTracking> for the
tracking model built on it.

The extension registers a hidden custom parameter (`kFxParameterId_AnalysisData`) whose value
is the frame data, loads it from the document when the effect is added, and attaches the
project media cache so large per-frame records spill to disk.

## What it observes

- Add parameters → registers the hidden AnalysisData custom parameter. It carries no state, is
  never presented or animated, and stays out of presets.
- Added to document → resolves the stored frame data from the custom parameter, then
  reattaches the project media cache.

The media cache is transient and never encoded, so it is re-resolved after every document
load. `frameData` creates the store on demand with the media cache attached, so it is never
nil once accessed. `dataClasses` adds ``FxGripFrameData``, ``FxGripImageBuffer``, and the
frame-data value classes to the accepted custom-value set.

## Reaching the store

The analysis pass in the effect's `Analyze` category reads and writes per-frame records
through the effect's `analysisData`, which resolves the loaded extension's frame data.
`hasAnalysis` reports whether the extension is loaded, which is true when the effect conforms
to `FxAnalyzer`.

## Topics

### Extension

- ``FxGripAnalysis``
- ``FxGripFrameData``
- ``FxGripCustomExtension``
- <doc:AnalysisPass>
- <doc:ObjectTracking>
- <doc:ExtensionArchitecture>
