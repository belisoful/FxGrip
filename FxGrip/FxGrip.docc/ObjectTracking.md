# Object Tracking

Track an object or point across a clip with the Vision framework and map the
result into an effect's parameters.

## Overview

An object tracker follows a region of the image over time and reports its
location, scale, and rotation on every frame. FxGrip runs the track in its own
analysis pass with Apple's Vision framework, because an FxPlug plug-in runs out
of process and cannot call Final Cut Pro's built-in tracker.

The tracker is assembled from parts that already exist in FxGrip:

- ``FxGripObjectTrackerParameter`` holds the tracker state: its configuration,
  the placed region, and the per-frame result. The value is an
  ``FxGripObjectTrackerData`` that saves with the host document and travels in a
  preset.
- ``FxGripObjectTrackerOSC`` places the region on the canvas as a rectangle
  whose two diagonal corners are point parameters.
- ``FxGripAnalyzerParameter`` starts the analysis pass.
- ``FxGripTrackingOpacityParameter``, ``FxGripProgressParameter``, and
  ``FxGripStatusParameter`` report progress and let a layer opt out of the
  analyzed frame.

The effect opts into analysis by conforming to the FxPlug `FxAnalyzer` protocol.
The pass feeds each frame to every tracker parameter, stores the samples, and
writes them back when the pass ends.

## The tracking engine

``FxGripObjectTracker`` wraps a Vision sequence request handler. The bounding-box
tracker (`VNTrackObjectRequest`) reports position and scale. Setting
`tracksRotation` selects the rectangle tracker (`VNTrackRectangleRequest`), which
reports rotation as well; it is seeded by a one-shot rectangle detection inside
the placed region, and falls back to the bounding-box tracker with zero rotation
when no rectangle is found.

The engine consumes the `CIImage` the analysis pass builds from the frame's
`IOSurface`, so no extra image plumbing is needed.

## Configuring a tracker

The configuration is read from the parameter's default value and edited in the
inspector through `FxGripObjectTrackerView`:

| Option | Values |
| --- | --- |
| Shape | Rectangle, Convex Quadrilateral |
| Behavior | Position, Position and Scale |
| Resolution | Full, Half |
| Smoothing | 0 (none) and up |

Half resolution scales the frame down before Vision, which speeds tracking of a
high-resolution clip. Smoothing averages the tracked box across a window of
frames when the result is read.

## Mapping the result

The tracker exposes its result two ways.

The effect reads a resolved transform by time:

```objc
FxGripObjectTrackerTransform t;
if ([self objectTrackerTransform:&t forParameter:kTrackerID atTime:renderTime]) {
    // t.location, t.rotation, and t.size are normalized to the frame.
}
```

The tracker also drives linked parameters as keyframes across the analyzed
frames. The corner points stay as the manual region; the center point, the
anchor points, and the angle parameter follow the track. An anchor keeps its
initial offset from the box center, scaled by the box size, so it rides with the
object.

## Coordinate space

The tracker works in Vision's normalized space, a unit square with a lower-left
origin. The placed region, the linked point values, and every stored sample use
it. Point parameters in Final Cut Pro and Motion are normalized to the frame, so
a linked point maps directly. A point parameter declared in another range is
converted to the unit square before analysis.

## Topics

### Classes

- ``FxGripObjectTrackerParameter``
- ``FxGripObjectTrackerData``
- ``FxGripObjectTrackerOSC``
- ``FxGripTrackingOpacityParameter``
- ``FxGripAnalyzerParameter``
