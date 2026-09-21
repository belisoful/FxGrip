# Tiling and Geometry

Rectangle algebra for FxPlug's integer `FxRect`, tile coordinate conversions, and the
host-transform bridge to simd.

## Overview

FxPlug hands effects `FxRect` bounds, `FxImageTile` render tiles, and `FxMatrix44`
transforms, and ships no operations for them. The `FxGripRect` functions supply
rectangle algebra in the pixel-bounds convention. The `FxImageTile` `FxGrip` category
resolves a tile's Metal device and pixel format and converts between the tile's pixel
space and image space. The `FxMatrix44` `FxGrip` category narrows a host transform to a
`simd_float4x4` a shader can use. The pixel and image coordinate spaces here match the
canvas and object-space conventions the on-screen controls use; see <doc:OnScreenControls>.

## Rectangle algebra

`FxRect` is `{ left, bottom, right, top }` in a y-up pixel space: width is right minus
left, height is top minus bottom, and a rectangle is empty when either is not positive.
The canonical empty rectangle is `{ 0, 0, 0, 0 }`, returned by ``FxGripRectZero``.
Intersection and every empty result use it; union treats an empty operand as absent and
returns the other.

- ``FxGripRectMake`` builds a rectangle from its four edges.
- ``FxGripRectWidth`` and ``FxGripRectHeight`` return the dimensions, clamped to zero.
- ``FxGripRectIsEmpty`` reports no positive area; ``FxGripRectEqualToRect`` is field-by-field
  equality.
- ``FxGripRectStandardize`` swaps inverted edges so left ≤ right and bottom ≤ top.
- ``FxGripRectContainsPoint`` includes the left and bottom edges and excludes the right and
  top; ``FxGripRectContainsRect`` reports containment, and an empty inner is contained by
  any rectangle.
- ``FxGripRectIntersectsRect`` reports shared positive area; ``FxGripRectIntersection``
  returns the overlap or the empty rectangle.
- ``FxGripRectUnion`` returns the smallest rectangle containing both.
- ``FxGripRectOffset`` translates; ``FxGripRectInset`` insets by `dx` and `dy`, and negative
  values grow the rectangle.

```objc
FxRect a = FxGripRectMake(0, 0, 640, 480);
FxRect b = FxGripRectMake(320, 240, 960, 720);
FxRect overlap = FxGripRectIntersection(a, b);   // { 320, 240, 640, 480 }
FxRect cover   = FxGripRectUnion(a, b);           // { 0, 0, 960, 720 }
```

### The CGRect bridge

``FxGripRectToCGRect`` uses left and bottom as the origin. ``FxGripRectFromCGRect`` rounds
the origin down and the far edges up so the result covers the CGRect.
``FxGripCGRectGetCorners`` writes a CGRect's four corners in lower-left, lower-right,
upper-right, upper-left order, and ``FxGripCGRectBoundingPoints`` returns the smallest
CGRect containing a set of points, which builds the bounding box of transformed corners.

## Tile coordinates

The `FxImageTile` `FxGrip` category resolves the tile's rendering resources and converts
its coordinates. `device` finds the `MTLDevice` for the tile's device registry ID and
caches it on the tile. `pixelFormat` returns the IOSurface pixel format as an OSType
FourCC, `metalPixelFormat` returns it as a `MTLPixelFormat` (zero when unrecognized), and
`metalTexture` returns the tile's Metal texture on its own device.

The coordinate helpers use the tile's pixel and inverse-pixel transforms:

- `imagePointFromPixelPoint:` and `pixelPointFromImagePoint:` convert single points.
- `imageSpaceBounds` returns the tile's pixel bounds expressed in image space.
- `pixelBoundsForImageRect:` returns the pixel bounds covering an image-space rectangle,
  for cropping or sampling.
- `imageRectForPixelBounds:` returns the image-space rectangle covering a pixel region.

The two free functions perform the same mapping without a tile.
``FxGripImageRectForPixelBounds`` transforms a pixel rectangle's four corners by an inverse
transform and returns their bounding box, so a rotated or skewed transform still yields the
covering image-space rectangle; it returns `CGRectZero` for a nil transform.
``FxGripPixelBoundsForImageRect`` maps an image rectangle to pixel bounds and rounds outward
to whole pixels; it returns the empty rectangle for a nil transform.

## Compositing onto a tile

The `FxImageTile` `FxGripText` category composites onto the tile's output texture.
`fxg_compositeCIImage:opacity:error:` source-over composites a Core Image positioned in the
texture's pixel space, where the origin is the texture's bottom-left corner and one unit is
one pixel. `fxg_drawText:attributes:atPixelPoint:error:` rasterizes text and composites it
at native resolution. Both read the output texture, composite, and write the result back,
and both return NO with an error set when the tile has no backing device. See
<doc:TextAndWatermark> for the text and watermark paths built on these methods.

## The transform bridge

The `FxMatrix44` `FxGrip` category converts FxPlug's row-major double-precision transform
to a column-major single-precision `simd_float4x4` a shader can use. `toFloat4x4Matrix:`
writes the receiver's transform into a destination matrix, and
`+doubleMatrix:toFloat4x4Matrix:` converts a raw `Matrix44Data`. The conversion transposes
and narrows.

## Topics

### Rectangle algebra

- ``FxGripRectMake``
- ``FxGripRectZero``
- ``FxGripRectWidth``
- ``FxGripRectHeight``
- ``FxGripRectIsEmpty``
- ``FxGripRectEqualToRect``
- ``FxGripRectStandardize``
- ``FxGripRectContainsPoint``
- ``FxGripRectContainsRect``
- ``FxGripRectIntersectsRect``
- ``FxGripRectIntersection``
- ``FxGripRectUnion``
- ``FxGripRectOffset``
- ``FxGripRectInset``
- ``FxGripRectToCGRect``
- ``FxGripRectFromCGRect``
- ``FxGripCGRectGetCorners``
- ``FxGripCGRectBoundingPoints``

### Tile coordinates

- ``FxGripImageRectForPixelBounds``
- ``FxGripPixelBoundsForImageRect``

### Related

- <doc:OnScreenControls>
- <doc:TextAndWatermark>
- <doc:ImageBuffer>

### Rect conversion

- ``CGRectFromFxRect``
- ``FxRectFromCGRect``
- ``kFxImageTileNotFound``
- ``kFxImageTileRequest_NoParameter``

### Vectors and points

- ``FxGripPoint``
- ``kZeroVector2``
- ``kZeroVector3``
- ``kZeroVector4``

### Constants and rounding

- ``kAspectRatio16x9``
- ``phi``
- ``floorWithError``
- ``floorWithNearest``

### Vector unions

- ``FxGripFloat2``
- ``FxGripFloat3``
- ``FxGripFloat4``
- ``FxGripDouble2``
- ``FxGripDouble3``
- ``FxGripDouble4``
- ``FxGripHalf2``
- ``FxGripHalf3``
- ``FxGripHalf4``
- ``FxGripUChar2``
- ``FxGripUChar3``
- ``FxGripUChar4``
