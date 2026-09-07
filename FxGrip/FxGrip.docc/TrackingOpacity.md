# Tracking Opacity

A read-only percent slider the framework drives to 0% during an analysis pass, so
a layer contributes nothing to the analyzed frame.

## Overview

``FxGripTrackingOpacityParameter`` is a read-only percent slider that extends
``FxGripPercentParameter``. It rests at 100% (`kFxGripTrackingOpacityResting`),
and the framework drives it to 0% (`kFxGripTrackingOpacityAnalyzing`) while an
analysis pass runs. An effect links a layer's opacity to this parameter so the
layer contributes nothing to the analyzed frame, which keeps host-drawn overlays
(for example Final Cut Pro titles) out of the analysis. The parameter mirrors the
FxFactory Tracking Opacity parameter.

The type string is `kFxParameterType_TrackingOpacity` and the enumerator is
`FxParameterType_TrackingOpacity`.

## Behavior

The value is framework driven, not user edited, so creation adds the disabled and
not-animatable flags. The slider spans 0 to 1 and rests at 100% unless the
declaration lowers the default. The parameter is published so other parameters
can link to it. The driver that lowers the value during analysis pairs with the
object tracker and the analysis pass.

```objc
@{
    kFxParameterProperty_Id:   @(kMyTrackingOpacityID),
    kFxParameterProperty_Name: @"Tracking Opacity",
    kFxParameterProperty_Type: kFxParameterType_TrackingOpacity,
}
```

## Role in the tracking flow

The tracking and analysis flow assembles from parts that already exist in FxGrip.
``FxGripAnalyzerParameter`` starts the pass, the object tracker follows a placed
region, and ``FxGripTrackingOpacityParameter`` lets a layer opt out of the
analyzed frame. See <doc:ObjectTracking> for how the parts fit together.

## Topics

### Control

- ``FxGripTrackingOpacityParameter``

### Related

- <doc:ObjectTracking>
- ``FxGripAnalyzerParameter``
