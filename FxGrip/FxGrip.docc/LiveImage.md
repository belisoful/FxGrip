# Live Image

Show a strip of images fed straight from the render pass to the inspector,
without a round trip through the host's parameter store.

## Overview

``FxGripLiveImageParameter`` is a read-only strip of image slots. The FxPlug host
runs the render pass and the custom parameter views in the same plugin process,
so an image the effect holds at render reaches the inspector without a trip
through the host's parameter store. The parameter's value is an
``FxGripDictionary`` carrying only the configuration. The pixels stay in memory
and never enter the host document. See <doc:CustomControls> for the custom
parameter model.

Creation adds the custom-UI, not-animatable, full-view-width, and no-state flags.
The slot count is fixed by the declared configuration.

## Configuration keys

The value carries the keys from `FxGripLiveImage.h`:

| Key | Meaning |
| --- | --- |
| `kFxGripLiveImageKey_Labels` | An array of slot labels; one slot per label |
| `kFxGripLiveImageKey_Slots` | The slot count when no labels are given |
| `kFxGripLiveImageKey_Height` | The row height in points (default `kFxGripLiveImageDefaultHeight`, 120) |
| `kFxGripLiveImageKey_ShowInfo` | Shows each frame's dimensions and pixel format in the caption |
| `kFxGripLiveImageKey_Checkerboard` | Draws a checkerboard behind an aspect-fit frame |
| `kFxGripLiveImageKey_Flip` | Flips a source whose bottom row is stored first |
| `kFxGripLiveImageKey_SnapshotSize` | The longest side, in pixels, of the read-back snapshot (default `kFxGripLiveImageDefaultSnapshotSize`, 640) |

```objc
@{
    kFxParameterProperty_Id:      @(kMyChannelsID),
    kFxParameterProperty_Name:    @"Channels",
    kFxParameterProperty_Type:    kFxParameterType_LiveImage,
    kFxParameterProperty_Default: @{
        kFxGripLiveImageKey_Labels: @[ @"Channel A", @"Channel B", @"Channel C", @"Channel D" ],
        kFxGripLiveImageKey_Height: @96.0,
    },
}
```

Set `kFxGripLiveImageKey_Flip` when a source stores its bottom row first, as a
raw FxPlug tile texture does.

## Publishing from the render pass

The runtime instance is the effect's parameter for the ID
(`effect[parameterID]`). The effect publishes from the render pass, on any
thread, and the publish call returns before the copy runs.

```objc
FxGripLiveImageParameter *channels = (FxGripLiveImageParameter *)self[kMyChannelsID];
[channels publishTextures:@[ channelA, channelB, channelC, channelD ]];   // one command buffer
[channels publishTexture:bufferA inSlot:0];                               // one texture
[channels publishImageTile:sourceTile inSlot:1];                          // an FxImageTile
[channels publishImageBuffer:cachedFrame inSlot:2];                       // an FxGripImageBuffer
```

``FxGripLiveImageParameter/publishTexture:inSlot:`` copies one Metal texture.
``FxGripLiveImageParameter/publishTextures:`` copies several in one command
buffer, mapping array index to slot index, where an `NSNull` entry skips its
slot. ``FxGripLiveImageParameter/publishImageTile:inSlot:`` publishes an
`FxImageTile`'s Metal texture. ``FxGripLiveImageParameter/publishFrame:inSlot:``
stores a ready ``FxGripLiveFrame``.
``FxGripLiveImageParameter/publishCGImage:inSlot:`` draws a `CGImageRef` into an
RGBA8 frame. ``FxGripLiveImageParameter/publishImageBuffer:inSlot:`` wraps an
`FxGripImageBuffer`'s pixels.

`clearSlot:` and `clearAllSlots` empty slots.
``FxGripLiveImageParameter/frameInSlot:`` returns the latest stored frame.

## The GPU copy, downscale, and readback

A Metal texture is copied on the GPU into a CPU-readable staging texture,
downscaled through its mipmap chain until its longest side is at most
`snapshotSize`, and read back when the command buffer completes. A value of 0
reads the texture at full size. A slot whose previous copy is still in flight
drops the new texture, so a fast render never queues behind the inspector. A
frame, `CGImageRef`, or image buffer is stored as given. Every path stores the
latest frame per slot and coalesces the redraw onto the main thread.

The supported texture and frame pixel formats are RGBA8Unorm (and its sRGB
variant), BGRA8Unorm (and its sRGB variant), RGBA16Unorm, RGBA16Float,
RGBA32Float, R8Unorm, R16Float, and R32Float; ``FxGripLiveFrame`` returns nil for
any other format. A four-channel frame is treated as premultiplied. A float
format converts to 8-bit on first `CGImage` use and keeps the raw float pixels.

## Gating on the inspector

Publishing is gated on an on-screen inspector view. A publish is suppressed,
storing nothing and returning `NO`, while no parameter view is on screen. The
FxPlug host puts a parameter view on screen only for the interactive timeline
render in the inspector's process. A batch export or a background render runs
with no inspector, so the strip shows the timeline play point and never an
off-screen render.

## The slot strip and its frames

``FxGripLiveImageView`` draws one slot per configured label across the inspector
width. Each slot shows its latest ``FxGripLiveFrame`` aspect-fit over the
checkerboard, with a caption carrying the slot label and, when
`kFxGripLiveImageKey_ShowInfo` is set, the frame's `sizeDescription`. A view
attached while another is on screen shows the last stored frames.

``FxGripLiveFrame`` is one immutable published image: tightly packed pixels in a
supported Metal pixel format with a `CGImage` built on demand. It owns a copy of
its pixels, so it outlives the texture or image it was read from.

## Topics

### Parameter

- ``FxGripLiveImageParameter``
- ``FxGripLiveImageView``

### Frame

- ``FxGripLiveFrame``

### Related

### Configuration keys

- ``kFxGripLiveImageKey_Checkerboard``
- ``kFxGripLiveImageKey_Flip``
- ``kFxGripLiveImageKey_Height``
- ``kFxGripLiveImageKey_Labels``
- ``kFxGripLiveImageKey_ShowInfo``
- ``kFxGripLiveImageKey_Slots``
- ``kFxGripLiveImageKey_SnapshotSize``

### Defaults

- ``kFxGripLiveImageDefaultHeight``
- ``kFxGripLiveImageDefaultSnapshotSize``
