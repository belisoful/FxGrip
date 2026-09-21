# Image Buffers and the Device Cache

Store an image compressed in memory, convert between pixel formats and Metal textures,
and pool per-device Metal objects across render threads.

## Overview

``FxGripImageBuffer`` is an immutable image buffer that compresses its pixels at
initialization and keeps them compressed in memory. ``FxGripMTLDeviceCache`` is a
process-wide cache of Metal devices, command queues, pipeline states, and shader
libraries, keyed so concurrent render threads share the same objects. The pixel-format
descriptors and codecs the buffer uses are declared in `FxGripImageCompression.h`.

## Pixel formats

``FxGripPixelFormat`` packs a channel count and a component type. Every combination of one
to four channels and the five component types is valid:

- 1 channel → Gray
- 2 channels → GrayAlpha
- 3 channels → RGB
- 4 channels → RGBA

The component types are ``FxGripComponentType``: `UInt8`, `UInt16`, `UInt32`, `Float16`,
and `Float32`. A format's value is `(channels << 8) | componentType`, and the values are
stable because `encodeWithCoder:` writes them. The geometry functions report a format's
shape:

- ``FxGripPixelFormatComponents`` → channels per pixel (0 when invalid).
- ``FxGripPixelFormatBytesPerComponent`` → 1, 2, or 4.
- ``FxGripPixelFormatBytesPerPixel`` → channels times component size.
- ``FxGripPixelFormatHasAlpha`` → YES for the 2- and 4-channel formats.
- ``FxGripPixelFormatIsFloat`` → YES for the `Float16` and `Float32` types.

## Compression

``FxGripCompression`` names two families of codec. The lossless buffer codecs from the
system Compression library apply to every format:

- `FxGripCompressionLZFSE` balances ratio and speed and is the default.
- `FxGripCompressionLZ4` favors speed.
- `FxGripCompressionZlib` favors interchange.
- `FxGripCompressionLZMA` favors ratio.

The lossy image codecs from ImageIO take a quality setting:

- `FxGripCompressionJPEG` carries 8-bit components.
- `FxGripCompressionHEIC` carries 16-bit components over 10/12-bit HEVC internals.
- `FxGripCompressionAVIF` carries 16-bit components where the OS provides an encoder.

Codecs are reached by type identifier, never by linked symbol, so a codec the running OS
lacks degrades to an encoder failure and the buffer stores its pixels raw.
``FxGripCompressionIsLossy`` reports whether a codec discards information, and
``FxGripCompressionIsAvailable`` reports whether the running OS can encode with it. AVIF
encoding is newer than the deployment target, so consult ``FxGripCompressionIsAvailable``
before choosing it.

## Creating a buffer

An initializer copies pixel rows, repacks them tightly, and compresses them. When the
codec does not shrink the data the buffer stores it uncompressed and reports
`FxGripCompressionNone`. The initializer returns nil for an invalid format, zero
dimensions, or a nil source.

```objc
FxGripImageBuffer *buffer =
    [[FxGripImageBuffer alloc] initWithBytes:pixels
                                    rowBytes:srcRowBytes
                                       width:width
                                      height:height
                                      format:FxGripPixelFormatRGBA8U
                                 compression:FxGripCompressionLZFSE];
```

The quality-less initializer uses `kFxGripImageBufferDefaultQuality` (0.75). The
`quality:` form sets a 0…1 quality for the lossy codecs; the lossless codecs ignore it.

`pixelData` decompresses on demand and returns tightly-packed rows. `rowBytes` is the
tight stride, `width` times bytes per pixel. `encodeWithCoder:` writes the already
compressed bytes, so archiving a buffer costs no extra compression pass.
``FxGripImageBuffer`` conforms to `NSSecureCoding` and `NSCopying`.

## Format conversion

`bufferByConvertingToFormat:compression:` recompresses the pixels in a new format. The
conversion passes through a canonical RGBA double intermediate:

- A Gray source replicates to the color channels.
- A color source collapses to Rec.709 luminance for a Gray or GrayAlpha target.
- Alpha is carried, added opaque, or discarded.
- An integer component maps to 0…1; a float passes unclamped between float formats; a
  float to an integer component clamps to 0…1.

## Metal textures

`newTextureWithDevice:` allocates a texture holding the pixels: Gray maps to R, GrayAlpha
to RG, and RGBA to RGBA. Metal has no packed 3-channel storage, so the RGB formats return
nil. `+bufferWithTexture:compression:` reads a texture back into a buffer for the R, RG,
and RGBA members of Unorm 8/16, Uint 32, and Float 16/32, and returns nil for any other
format. `bitmapRep` and `image` produce an RGBA8U preview.

## The compression envelope

The envelope functions wrap a payload in a self-describing container that records the
codec and the exact original length. ``FxGripEnvelopeCompressedData`` compresses only when
the codec is lossless, the data reaches `minimumLength`, and the codec produces a strictly
smaller payload; otherwise it returns the data unchanged with no envelope. An uncompressed
payload therefore stays byte-identical to a pre-envelope one.
``FxGripEnvelopeDecompressedData`` detects the signature and restores the original, returns
unsignatured data unchanged, and sets an error in `FxGripCompressionErrorDomain` for a
corrupt envelope. ``FxGripCompressedData`` and ``FxGripDecompressedData`` are the raw
lossless pair without the envelope; the default threshold below which the envelope leaves
data raw is `FxGripCompressionEnvelopeThresholdDefault`.

## The Metal device cache

``FxGripMTLDeviceCache`` is a `BESingleton`. It keys one ``FxGripMTLDeviceCacheItem`` per
device registry ID, pixel format, and plugin ID, creating items on first request and
dropping them when Metal reports a device removed. `kDefaultPluginID` selects the shared,
non-per-plugin item, and `FxGripMTLPixelFormatAny` matches an item of any pixel format.
Every method is safe to call from concurrent render threads; the cache never holds a lock
while a command buffer executes.

### Command queues

Command queues are pooled per cache item. `+commandQueueForImageTile:` checks one out for
the tile's device and pixel format, and the caller returns it with `+returnCommandQueue:`
once its command buffer is committed. `+scopedCommandQueueForImageTile:` returns a
``FxGripMTLCommandQueue`` wrapper that checks the queue back in on dealloc, so a render
method holds it in a local variable and the queue returns when the variable goes out of
scope. Do not pass the wrapper to `+returnCommandQueue:`.

```objc
FxGripMTLCommandQueue *queue =
    [FxGripMTLDeviceCache scopedCommandQueueForImageTile:destinationImage];
id<MTLCommandBuffer> commands = [queue commandBuffer];
// encode work, commit; the wrapper returns the queue on dealloc
```

### Pipeline states and libraries

A cache item caches render pipeline states by vertex and fragment function names, with
optional function constants and a specialized-format key. It exposes the device's default
library through a ``FxGripMTLLibraryCache``, an `MTLLibrary` pass-through that memoizes the
`MTLFunction` objects it compiles. Concurrent asynchronous requests for one name share a
single compile; a synchronous request for a name whose asynchronous compile is in flight
compiles on the calling thread. `+depthTexture:forDevice:` allocates a depth texture sized
to a bounds rectangle, and `+MTLPixelFormatForImageTile:` reports the Metal pixel format
for a tile's IOSurface.

## Topics

### Image buffer

- ``FxGripImageBuffer``

### Pixel formats and codecs

- ``FxGripPixelFormat``
- ``FxGripComponentType``
- ``FxGripCompression``
- ``FxGripPixelFormatComponents``
- ``FxGripPixelFormatBytesPerComponent``
- ``FxGripPixelFormatBytesPerPixel``
- ``FxGripPixelFormatHasAlpha``
- ``FxGripPixelFormatIsFloat``
- ``FxGripCompressionIsLossy``
- ``FxGripCompressionIsAvailable``
- ``FxGripCompressedData``
- ``FxGripDecompressedData``
- ``FxGripEnvelopeCompressedData``
- ``FxGripEnvelopeDecompressedData``

### Metal device cache

- ``FxGripMTLDeviceCache``
- ``FxGripMTLDeviceCacheItem``
- ``FxGripMTLCommandQueue``
- ``FxGripMTLLibraryCache``

### Related

- <doc:CustomControls>

### Pixel formats

- ``FxGripPixelFormatMake``
- ``FxGripPixelFormatComponentType``
- ``FxGripPixelFormatR16F``
- ``FxGripPixelFormatR32F``
- ``FxGripPixelFormatRA16F``
- ``FxGripPixelFormatRA32F``
- ``FxGripMTLPixelFormatAny``
- ``bytesFromFxDepth``
- ``mtlPixelFormatFromFxDepth``

### Compression

- ``FxGripCompressionTypeIdentifier``
- ``FxGripCompressionErrorDomain``
- ``FxGripCompressionEnvelopeThresholdDefault``
- ``kFxGripImageBufferDefaultQuality``

### Histograms and gradients

- ``FxGripChannelHistogram``
- ``kZeroChannelHistogram``
- ``kZeroHistogram``
- ``FxGripGradient``
- ``FxGripGradientHeader``
- ``FxGripGradientUInt8``
- ``FxGripGradientHalf``
- ``FxGripGradientFloat``
- ``kZeroGradient``

### The histogram union

- ``FxGripHistogram``
