# Custom Parameter Data

Declare, key, secure-code, and interpolate the value object behind a custom
control.

## Overview

A custom control stores its state in a value object the host archives with the
document. The value answers the standard typed parameter API, reports the classes
it contains so the host can unarchive it, and, for an animatable control, blends
across keyframes. FxGrip ships a small family of value classes and the protocols
that connect a value to its view and effect. See <doc:CustomControls> for the
controls that use these values.

## The keyed value

``FxGripDictionary`` is a mutable dictionary custom value. It stores a custom
parameter's data as keyed entries and feeds that data to the host's typed
accessors, so a plugin sets and reads bool, float, int, color, path, string, and
point values without translating through `NSNumber`. Well-known key macros map
each FxPlug type to its entry:

| Macro | Type |
| --- | --- |
| `kCustomAPI_BoolKey` | boolean |
| `kCustomAPI_FloatKey` | double |
| `kCustomAPI_IntKey` | int |
| `kCustomAPI_RGBAKey` / `kCustomAPI_RGBKey` | color |
| `kCustomAPI_StringKey` | string |
| `kCustomAPI_PointKey` | x and y point |
| `kCustomAPI_PathIDKey` | path ID |
| `kCustomAPI_HistogramKey` | histogram |

A `getIntValue:fromParameter:` on the custom parameter reads the entry under
`kCustomAPI_IntKey`, and a `setIntValue:toParameter:` writes it. Each typed
accessor also has a `forKey:` variant that reads or writes an explicit key, so
one value carries several named entries.

```objc
FxGripDictionary *value = [FxGripDictionary new];
[value setIntValue:BEDotStateOk forKey:kCustomAPI_IntKey];
[value setStringParameterValue:@"Ready" forKey:kCustomAPI_StringKey];
```

The `locked` flag restricts the default typed setters to keys that already
exist, so the standard interface cannot add new keys.
``FxGripDictionary/exemptKeys`` names the keys the interpolating subclass copies
rather than blends. The class conforms to `NSSecureCoding`, and
``FxGripDictionary/classesForParameter`` supplies the allow-list of value classes
the host uses to decode; a subclass overrides it to extend the list.

## Keyframe interpolation

``FxGripInterpolatingDictionary`` subclasses ``FxGripDictionary`` and conforms to
`FxCustomParameterInterpolation_v2`, so the host blends the value across
keyframes. It interpolates strings, collections, and numbers, and copies
everything else. A key in the exempt-keys array and a key prefixed with the
`kInterpolatingDictionaryNonePrefix` underscore are copied rather than blended.

A subclass blends further types through
``FxGripInterpolatingDictionary/customInterpolateValue:rightValue:path:withWeight:``.
The base calls the hook for a value pair whose class is neither string,
collection, nor number, and keeps a copy of the left value when the hook returns
nil. `path` is the slash-joined key path of the entry. ``FxGripCurveSetData``
uses this hook to blend curves curve-aware.

## Path data

``FxGripPathData`` is an immutable ordered list of FxPlug `FxVertex` vertices with
a closed flag. It backs an editable on-screen path whose vertex count changes at
runtime, which a fixed set of point parameters cannot express. Each vertex
carries a `location`, an `inTangent` and `outTangent` held as vectors from the
location, an `xSplineWeight`, and an `interpStyle`. Tangents held as vectors move
rigidly with the vertex, so relocating a vertex carries its tangents. Locations
are object-space coordinates. Edits return a new instance; there is no mutable
variant.

```objc
CGPoint locations[] = { {0.2, 0.2}, {0.8, 0.2}, {0.8, 0.8} };
FxGripPathData *path = [FxGripPathData pathWithLocations:locations count:3 closed:YES];
FxGripPathData *moved = [path byReplacingLocationAtIndex:0 withLocation:CGPointMake(0.1, 0.1)];
```

`FxGripPathGeometry.h` converts a path into cubic Bézier segments for evaluation
and drawing. `FxGripPathCubicSegments` resolves each vertex's `interpStyle` into
control points, `FxGripPathSegmentCount` reports the segment count, and
`FxGripCubicSegmentPoint` evaluates one `FxGripCubicSegment` at `t`. The
`FxGripPathData (Geometry)` category converts a stored path directly with
`copyCubicSegmentsToBuffer:capacity:`.

## Per-frame data

``FxGripFrameData`` subclasses ``FxGripDictionary`` and keys records by frame
index for feedback-style simulations where a frame derives from the previous one.
Records store under `NSNumber` frame-index keys, and the store is sparse.
``FxGripFrameData/latestRecordAtOrBefore:`` serves the feedback-simulation seek,
so a frame re-simulates forward from the nearest stored index.

Storage is size-gated. A record whose secure-coded archive exceeds
``FxGripFrameData/spillThreshold`` spills to
`<cacheURL>/<instanceUUID>/<index>.fxframe`, and a small marker takes its place in
the parameter, so the host document carries only the manifest.
``FxGripFrameData/attachProjectMediaCacheForEffect:`` points the spill home at the
effect's project media folder, which the host deletes with its project and
carries with collected media. Without a media folder the store spills nothing and
every record stays inline. A document opened where the cache files are absent
returns nil for spilled records, and the caller re-simulates. The class does not
interpolate.

## Connecting the value, view, and effect

Four protocols connect a custom value to the objects that present it:

- ``FxGripCustomDataClasses`` reports the secure-coding classes the host uses to unarchive the value, through `classesForParameter`.
- ``FxGripCustomViewData`` keeps back references from a value to its `parameterView` and its owning `parameterEffect`, so the value reads host state while responding to view edits.
- ``FxGripCustomViewDataDelegate`` is the protocol a custom parameter view adopts. The owner pushes a new value to the view through `updateFromCustomData:`, and the view redraws to match.
- ``FxGripCustomCommonDelegate`` is the shared base class for delegates that route a view's AppKit control callbacks back to the host parameter. A view receives those callbacks outside the host's managed plugin call stack, so the delegate writes through the out-of-band parameter access API.

## Topics

### Values

- ``FxGripDictionary``
- ``FxGripInterpolatingDictionary``
- ``FxGripPathData``
- ``FxGripFrameData``

### Protocols

- ``FxGripCustomDataClasses``
- ``FxGripCustomViewData``
- ``FxGripCustomViewDataDelegate``
- ``FxGripCustomCommonDelegate``

### Related

