# Plugin State

Carry every value the render needs through the plugin-state coder, because the host renders frames concurrently, out of order, and again.

## Overview

FxPlug separates the host callbacks that read parameters from the callbacks that render. A parameter read is valid during the parameter-setup and parameter-change callbacks and during the `pluginState` callback. It is not valid at render. The host bridges the two by asking the effect to encode its render-time state during `pluginState:atTime:quality:error:` and handing that state back to each render callback.

The state is the only per-frame channel that survives the host's render model:

- the host renders several frames concurrently on different threads.
- the host renders frames out of timeline order.
- the host re-renders a frame whose inputs change.

An instance variable set during one callback does not survive to the render of an arbitrary frame under that model. Every value a render needs travels through the plugin state instead, keyed to the frame it belongs to.

## The coder in place of an opaque blob

FxPlug's `pluginState` is an opaque `NSData`. FxGrip replaces it with an `NSCoder`, so an effect encodes and decodes typed keyed values rather than packing bytes. The render callbacks take a coder in place of the data, declared on the coder-state protocols (see <doc:EffectAndGenerator>).

`NSCoder (FxPlug)` in `NSCoder+FxPlug.h` adds the FxPlug value types to the coder. It encodes and decodes `FxPoint2D`, `FxSize`, `FxPoint3D`, `FxRect`, and the 4×4 double matrices as keyed bytes. A decode checks the stored size and returns a zero value on a mismatch, so a truncated or wrong-typed key does not read past its bytes.

## The render time and quality on the coder

The coder carries the render time and the quality level, so a callback reads them from the coder itself.

- `renderTime` → the render time associated with the coder; `kCMTimeInvalid` when none is set. It rides on the coder as an associated object.
- `qualityLevel` → the encoded quality level; `kFxQuality_HIGH` when the key is absent. It is stored under `kFxPlugCoderQualityLevelKey`.
- `isFxPluginStateEncoder` → YES once a render time is associated, which marks the coder as a plugin-state encoder.

The framework sets `renderTime` and `qualityLevel` on the archiver before the plugin-state notification, and reads them off the unarchiver at render.

## The coder-state protocol

An effect adopts the coder-based render path by conforming to a coder-state protocol.

- `FxGripTileableEffectCoderStateWeak` declares the coder callbacks as optional members. An effect adopts the coder path for the render stages it needs.
- `FxGripTileableEffectCoderState` promotes the coder, destination-bounds, source-tile, and render callbacks to required members. A conforming effect supplies the complete coder-based render path. `scheduleInputs` stays optional.

The subclass encode hook runs first:

```objc
- (BOOL)pluginCoder:(NSCoder *)coder
             atTime:(CMTime)renderTime
            quality:(FxQuality)qualityLevel
              error:(NSError **)error
{
    [coder encodeFxPoint2D:[self centerAtTime:renderTime] forKey:@"center"];
    [coder encodeDouble:[self amountAtTime:renderTime] forKey:@"amount"];
    return YES;
}
```

The render hook reads the same keys back:

```objc
- (BOOL)renderDestinationImage:(FxImageTile *)destinationImage
                  sourceImages:(NSArray<FxImageTile *> *)sourceImages
                   pluginCoder:(NSCoder *)coder
                        atTime:(CMTime)renderTime
                         error:(NSError **)error
{
    FxPoint2D center = [coder decodeFxPoint2D:@"center"];
    double amount = [coder decodeDoubleForKey:@"amount"];
    // draw from center and amount, on this render's thread.
    return YES;
}
```

The render hook reads only the coder. It holds no instance state from the encode, so it reproduces its frame in any order.

## The plugin-state notification

The base posts the render-path stages as notifications, so an extension encodes and decodes its own render state alongside the subclass. The plugin-state notification carries the live archiver under `FxGripTileableEffectPluginStateCoderKey`, read back through `userInfo.fxCoder`. The geometry and render notifications carry the unarchiver under the same key. When the subclass conforms to `FxGripTileableEffectCoderState`, the subclass encode runs before the notification. <doc:ExtensionArchitecture> documents the payload of each render-path notification.

## Current-time encoding of host state

The coder's `renderTime` also gates the host-state encoders. `encodeFx3DAPI:` and `encodeFxLightingAPI:` capture the host 3D camera, frustum, focal length, and lights at the coder's render time under a current-time key prefix. The `atTime:forKey:` form skips the encode when it targets the current-time key with a time that does not match the coder's `renderTime`, so a value stored under the current-time key belongs to exactly the frame the coder represents. <doc:Space3D> uses this to move the whole host scene through the plugin state.

## Compression

The encoded state passes through a size-gated lossless codec on the effect base. `pluginStateCompression` names the codec (LZFSE, LZ4, zlib, or LZMA); the default `FxGripCompressionNone` leaves the blob uncompressed. Compression runs only when the encoded state reaches `pluginStateCompressionThreshold` and the codec shrinks it, and the state passes through uncompressed otherwise. The render side detects the codec from the blob and decompresses without further configuration, so the setting is safe to change per instance.

## Topics

### The coder

- ``FxGripTileableEffectCoderState``
- ``FxGripTileableEffectCoderStateWeak``

### Related articles

- <doc:ExtensionArchitecture>
- <doc:Space3D>
