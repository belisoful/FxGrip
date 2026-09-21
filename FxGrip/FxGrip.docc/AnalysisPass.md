# The Analysis Pass

Run a pre-render pass over the clip, compute a record per frame, and read it back at render.

## Overview

Some effects need a value that depends on the frame image before they render: an average color, a tracked box, a histogram. An FxPlug plug-in runs out of process and cannot call the host's built-in analysis, so FxGrip runs its own pass over the source frames through FxPlug's `FxAnalyzer` protocol. The pass feeds each frame to a subclass hook, stores the result keyed by frame index, and reads it back at render.

An effect opts into the pass by declaring `<FxAnalyzer>` on its own interface. `FxGripTileableEffect (Analyze)` implements the `FxAnalyzer` callbacks on the base, so the subclass adds the conformance and the hook without answering the protocol itself.

## The opt-in

Conforming to `FxAnalyzer` does two things. It advertises the analysis capability to the host, so the inspector can start a pass. It also loads the ``FxGripAnalysis`` extension automatically, which owns the per-frame store. The effect reads the store through `analysisData` and its presence through `hasAnalysis`; both come from `FxGripTileableEffect (Analysis)`.

```objc
@interface MyAnalyzingEffect : FxGripTileableEffect <FxAnalyzer>
@end
```

## The per-frame hook

The pass calls `analyzeImageTile:atTime:frameIndex:error:` once for each analyzed frame. A subclass overrides it to compute the frame's record. The default returns nil and stores nothing.

```objc
- (id<NSSecureCoding, NSCopying>)analyzeImageTile:(FxImageTile *)frame
                                           atTime:(CMTime)frameTime
                                       frameIndex:(NSInteger)frameIndex
                                            error:(NSError **)error
{
    double luma = [MyAnalyzingEffect averageLuminanceOfImageTile:frame];
    return @(luma);
}
```

The return value is any secure-codable, copyable object: a boxed scalar, a dictionary, or an `FxGripImageBuffer`. A non-nil result is stored at `frameIndex`. The base supplies `averageColorOfImageTile:red:green:blue:alpha:` and `averageLuminanceOfImageTile:` as compute helpers over the tile's average color.

At render the effect reads the stored value for the current time:

```objc
id<NSSecureCoding, NSCopying> record = [self analysisRecordAtTime:renderTime];
```

`analysisRecordAtTime:` returns the record at or before the time's frame index, or nil when none is stored. It is valid to call where the parameter API is available, such as `pluginState:atTime:`. `analysisFrameIndexForTime:` maps a time to the absolute frame index the store keys by.

## Frame-index storage

``FxGripFrameData`` is the store. It keys records by frame index and does not interpolate. The store is sparse, and `latestRecordAtOrBefore:` serves a feedback-style seek: an effect whose frame derives from the previous frame re-simulates forward from the nearest stored index. String-keyed header entries ride alongside the records and persist with the store: the frame duration for arbitrary generator rates, the instance UUID, and the spill threshold.

Storage is size-gated. A record whose secure-coded archive exceeds `spillThreshold` is written to a machine-local cache file, and a small marker takes its place in the parameter, so the host document carries only the manifest. A smaller record stays inline. `attachProjectMediaCacheForEffect:` points the spill home at the project media folder, which the host deletes with its project and carries with collected media. Without a media folder the store spills nothing and keeps every record inline. A document opened where the cache files are absent returns nil for a spilled record, and the caller re-simulates.

## The analysis extension

``FxGripAnalysis`` registers the hidden `kFxParameterId_AnalysisData` custom parameter whose value is the ``FxGripFrameData``, loads it from the document when the effect is added, and attaches the project media cache. It loads automatically on `FxAnalyzer` conformance, so an effect does not add it by hand.

## Driving the pass

The pass runs from a parameter action. `startForwardAnalysisAtLocation:error:` requests a forward analysis of the source clip, and `startBackwardAnalysisAtLocation:error:` the backward direction. `analysisState` reports the host's analysis state, or `kFxAnalysisState_NotAnalyzing` when the API is unavailable.

``FxGripAnalyzerParameter`` is the control that starts the pass from the inspector, documented on the <doc:Analyzer> control page. ``FxGripTrackingOpacityParameter`` reports progress and lets a layer opt out of the analyzed frame, documented on the <doc:TrackingOpacity> page.

## Trackers ride the same pass

An object-tracker parameter is analyzed automatically during the same pass. The pass runs each ``FxGripObjectTrackerParameter`` for every frame and stores its samples, and the effect reads a resolved transform at render with `objectTrackerTransform:forParameter:atTime:`. <doc:ObjectTracking> documents the tracker built on the pass.

## Topics

### Storage and extension

- ``FxGripFrameData``
- ``FxGripAnalysis``

### Controls

- ``FxGripAnalyzerParameter``
- ``FxGripTrackingOpacityParameter``
- ``FxGripObjectTrackerParameter``

### Related articles

- <doc:ObjectTracking>
- <doc:TrackingOpacity>

### Frame-data keys

- ``kFxGripFrameDataKey_FrameDuration``
- ``kFxGripFrameDataKey_InstanceUUID``
- ``kFxGripFrameDataKey_SpillFile``
- ``kFxGripFrameDataKey_SpillLength``
- ``kFxGripFrameDataKey_SpillThreshold``

### Spill defaults

- ``kFxGripFrameDataDefaultSpillThreshold``
- ``kFxGripFrameDataFileExtension``
- ``kFxGripFrameDataNeverSpill``
