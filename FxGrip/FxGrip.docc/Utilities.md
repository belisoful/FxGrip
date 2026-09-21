# Utilities

The standalone helper classes that have no coupling to the rest of FxGrip.

## Overview

The utility classes are the Level 1 adoption surface described in <doc:Adoption>. An
existing plug-in with its own `FxTileableEffect` implementation links the framework and
calls them directly, without adopting the parameter subsystem, the host seam, or the
effect base. Each class solves one problem FxPlug leaves to the plug-in: rectangle
algebra on `FxRect`, gamut matrices for the working color space, compressed image
storage, per-device Metal object pooling, text and watermark rendering, SMPTE timecode,
and a single modifier-key convention for draggable controls.

Some of these classes are also companion categories on `FxGripTileableEffect`. A category
reads the host API the effect already holds and returns the same math the free functions
compute, so a subclass reaches the utility through `self` and a standalone plug-in calls
the function directly.

## Image storage and Metal

``FxGripImageBuffer`` stores an image compressed in memory and converts between pixel
formats and Metal textures. ``FxGripMTLDeviceCache`` pools Metal devices, command queues,
pipeline states, and shader libraries per device. See <doc:ImageBuffer>.

## Text and watermarks

``FxGripTextImage`` rasterizes an attributed string into a Metal texture.
``FxGripWatermark`` composites a configured text watermark onto a render tile in one of
four layouts. See <doc:TextAndWatermark>.

## Color

The `FxGripColorGamut` functions supply luminance weights and gamut-conversion matrices
for the Rec.709 and Rec.2020 primaries FxPlug reports. The `FxGripTileableEffect`
`ColorGamut` category reads the working gamut from the host and derives the same matrices.
See <doc:ColorAndGamut>.

## Geometry and tiles

The `FxGripRect` functions supply union, intersection, containment, and the CGRect
bridge for FxPlug's integer `FxRect`. The `FxImageTile` `FxGrip` category resolves a
tile's Metal device and pixel format and converts between pixel and image space. The
`FxMatrix44` `FxGrip` category narrows a host transform to a `simd_float4x4`. See
<doc:TilingAndGeometry>.

## Timing

The `FxGripTileableEffect` `Timing` category reports frame durations, retiming speed, and
frame counts, and formats timecode. ``FxGripTimecode`` formats a `CMTime` as SMPTE
timecode with drop-frame support and no host dependency. ``FxGripTimingAPI_v4`` wraps the
host timing protocol. See <doc:Timing>.

## Modifier keys

``FxGripEventModifiers`` defines the Option, Shift, Command, and Control convention that
every draggable FxGrip control reads. See <doc:EventModifiers>.

## Other Level 1 classes

``FxGripURLWhitelist`` gates the URLs a web or video control may load; see
<doc:WebContent>. The value types ``FxGripDictionary``, ``FxGripCurveData``, and
``FxGripPathData`` carry custom-control state; see <doc:CustomControls>.

## Topics

### Deeper articles

- <doc:ImageBuffer>
- <doc:TextAndWatermark>
- <doc:ColorAndGamut>
- <doc:TilingAndGeometry>
- <doc:Timing>
- <doc:EventModifiers>
- <doc:Adoption>

### Classes

- ``FxGripImageBuffer``
- ``FxGripMTLDeviceCache``
- ``FxGripTextImage``
- ``FxGripWatermark``
- ``FxGripTimecode``
- ``FxGripEventModifiers``

### Debug logging

- ``DebugLog``
- ``DebugLog2``
