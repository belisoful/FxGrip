# Analyzer Control

Start the effect's frame-analysis pass from an inspector button.

## Overview

``FxGripAnalyzerParameter`` is a push button that starts the FxGrip
frame-analysis pass. Clicking the button drives the pass forward or backward
across the source clip, storing per-frame records in the effect's `analysisData`.
The parameter extends ``FxGripPushButtonParameter``. Its type string is
`kFxParameterType_Analyzer` and its enumerator is `FxParameterType_Analyzer`.

The effect opts into analysis by conforming to the FxPlug `FxAnalyzer` protocol.
When the effect does not conform, or reports no analysis, the click does nothing.
This control wraps the analysis pass in the FxFactory Analyzer button shape. See
<doc:ObjectTracking> for the tracker that consumes the stored samples, and
<doc:AnalysisPass> for the analysis pass the button drives.

## Configuration keys

The button reads its configuration from the value:

| Key | Meaning |
| --- | --- |
| `kFxGripAnalyzerKey_Location` | The analysis image path; `kFxAnalysisLocation_GPU` (the default) or `kFxAnalysisLocation_CPU` |
| `kFxGripAnalyzerKey_Backward` | Runs the pass in reverse |
| The push-button title key | The button title; falls back to the parameter name, then to `kFxGripAnalyzerDefaultTitle` ("Analyze") |

```objc
@{
    kFxParameterProperty_Id:      @(kMyAnalyzeID),
    kFxParameterProperty_Name:    @"Analyze",
    kFxParameterProperty_Type:    kFxParameterType_Analyzer,
    kFxParameterProperty_Default: @{
        kFxGripAnalyzerKey_Location: @(kFxAnalysisLocation_GPU),
        kFxGripAnalyzerKey_Backward: @NO,
    },
}
```

## Driving the pass

A click reaches the parameter through `-[FxGripTileableEffect parameterClicked:]`,
which calls ``FxGripAnalyzerParameter/defaultParameterAction``. The action reads
the configured direction and calls the effect's
`startForwardAnalysisAtLocation:error:` or `startBackwardAnalysisAtLocation:error:`
with the configured location. The action does nothing when the host is not an
``FxGripTileableEffect-class`` or reports no analysis. The pass feeds each frame to
every analyzing parameter, stores the samples, and writes them back when the pass
ends.

## Topics

### Control

- ``FxGripAnalyzerParameter``

### Related

- <doc:ObjectTracking>
- <doc:AnalysisPass>
- ``FxGripTrackingOpacityParameter``

### Configuration keys

- ``kFxGripAnalyzerKey_Backward``
- ``kFxGripAnalyzerKey_Location``

### Defaults

- ``kFxGripAnalyzerDefaultTitle``
