# Text and Watermark Images

Rasterize an attributed string into a Metal texture, and composite a configured text
watermark onto a render tile.

## Overview

``FxGripTextImage`` draws text into a Metal texture. ``FxGripWatermark`` renders a
declarative ``FxGripWatermarkConfiguration`` onto a render tile in one of four layouts.
Both depend only on the base FxGrip tile and the Metal layer, with no dependency on
FxGrip's extension, notification, or FxFactory subsystems, so a plug-in that drives its
own licensing or activation logic reuses them directly.

## Rasterizing text

Every ``FxGripTextImage`` method is a class method that allocates and returns an
independent texture. The primary rasterizer draws an attributed string into a
premultiplied RGBA8 sRGB bitmap and uploads it to a new `MTLTexture` sized to the text
plus padding. The texture carries top-first row order, so a sampler reads row 0 as the
visual top. The pixel size is read from the returned texture's `width` and `height`.

```objc
NSDictionary *attributes = @{
    NSFontAttributeName:            [NSFont systemFontOfSize:24],
    NSForegroundColorAttributeName: NSColor.whiteColor,
};
NSAttributedString *string =
    [[NSAttributedString alloc] initWithString:@"Preview" attributes:attributes];

id<MTLTexture> texture = [FxGripTextImage textureForAttributedString:string
                                                             padding:4
                                                              device:device];
```

The method returns nil when the text is empty, the device is nil, or texture allocation
fails. Two convenience methods draw a plain string: `textureForText:font:color:device:`
uses a four-pixel padding, and `textureForText:fontSize:color:device:` draws in Helvetica
and takes color as a `simd_float4` read as sRGB, retained for the on-screen controls.

## Watermark configuration

``FxGripWatermarkConfiguration`` carries the text, typography, and layout.

| Property | Default | Notes |
| --- | --- | --- |
| `text` | — | An empty string renders nothing. |
| `fontName` | Helvetica | An unrecognized name falls back to the system font. |
| `fontSize` | 48 | Point size. |
| `color` | white | Text color. |
| `angleDegrees` | — | Rotation for the Single and Banner styles. |
| `opacity` | 0.5 | Composite opacity, 0…1. |
| `blur` | — | Shadow blur radius; applies only when `shadowColor` is set. |
| `shadowColor` | nil | nil draws no shadow. |
| `style` | DiagonalTiled | The layout. |
| `tileSpacing` | 80 × 80 | Gap between repeats for DiagonalTiled. |
| `corner` | BottomRight | Anchor for the Corner style. |
| `inset` | 24 | Edge inset for the Corner style. |

Three factory methods seed a configuration: `configurationWithText:` uses every default,
`trialConfigurationWithText:` builds the diagonally tiled semi-transparent trial look, and
`centeredConfigurationWithText:` builds a single centered watermark at 50% opacity.

## Watermark styles

``FxGripWatermarkStyle`` chooses how the text covers the frame:

- `FxGripWatermarkStyleSingle` → one placement centered on the frame, rotated by
  `angleDegrees`.
- `FxGripWatermarkStyleDiagonalTiled` → the text repeated across the frame on a grid,
  fixed at 45 degrees.
- `FxGripWatermarkStyleBanner` → one placement scaled to span the frame width, centered
  vertically, rotated by `angleDegrees`.
- `FxGripWatermarkStyleCorner` → one placement pinned to a ``FxGripWatermarkCorner`` with
  an inset, no rotation.

## Rendering a watermark

Build a watermark from a configuration and composite it onto the destination tile.
`renderOntoImageTile:error:` returns YES with no change when the text is empty, and NO
with an error set when the tile has no backing device or the Metal work fails.

```objc
FxGripWatermarkConfiguration *config =
    [FxGripWatermarkConfiguration trialConfigurationWithText:@"UNLICENSED"];
config.style = FxGripWatermarkStyleDiagonalTiled;

FxGripWatermark *watermark = [FxGripWatermark watermarkWithConfiguration:config];

NSError *error = nil;
BOOL ok = [watermark renderOntoImageTile:destinationImage error:&error];
```

`watermarkImageForSize:device:` builds the watermark as a Core Image cropped to a frame of
the given pixel size, so the generated image is inspected without a render tile. The image
is opaque; the configuration's opacity applies when the image is composited.

## Drawing onto a tile

The compositing path lives on the `FxImageTile` `FxGripText` category.
`fxg_compositeCIImage:opacity:error:` reads a tile's output texture as the background,
source-over composites a Core Image positioned in the texture's pixel space, and writes
the result back. `fxg_drawText:attributes:atPixelPoint:error:` rasterizes text and
composites it at native resolution. Both are the workhorses the watermark and text paths
share. See <doc:TilingAndGeometry> for the tile category and its coordinate helpers.

## Topics

### Text

- ``FxGripTextImage``

### Watermark

- ``FxGripWatermark``
- ``FxGripWatermarkConfiguration``
- ``FxGripWatermarkStyle``
- ``FxGripWatermarkCorner``

### Related

- <doc:ImageBuffer>
