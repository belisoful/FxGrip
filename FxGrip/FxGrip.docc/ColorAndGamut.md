# Color and Gamut

Derive luminance weights and gamut-conversion matrices for the working color space FxPlug
reports.

## Overview

FxPlug tells an effect its project's working gamut, `kFxColorPrimaries_Rec709` or
`kFxColorPrimaries_Rec2020`, and ships no math for it. An effect that needs a luminance, a
gamut conversion, or an XYZ transform derives the matrix itself. The `FxGripColorGamut`
functions supply the standard matrices, computed from each gamut's primary chromaticities
against a D65 white, so the luminance row agrees with the published weights. The
`FxGripTileableEffect` `ColorGamut` category reads the working gamut from the host and
returns the same values for a subclass.

Matrices are `simd_float3x3` in simd's column-major layout, so `simd_mul(matrix, rgb)`
transforms a column vector.

## Gamut functions

``FxGripLuminanceWeights`` returns the CIE Y row, the luminance weights, for a set of
primaries. ``FxGripRGBToXYZMatrix`` and ``FxGripXYZToRGBMatrix`` return the RGB-to-XYZ and
XYZ-to-RGB matrices for the primaries against D65. ``FxGripGamutConversionMatrix`` returns
the matrix converting linear RGB from one gamut to another, and equal primaries give the
identity.

```objc
FxColorPrimaries from = kFxColorPrimaries_Rec709;
FxColorPrimaries to   = kFxColorPrimaries_Rec2020;

simd_float3x3 toWide = FxGripGamutConversionMatrix(from, to);
simd_float3   weights = FxGripLuminanceWeights(to);
```

``FxGripColorMatrixMakeRowMajor`` builds a `simd_float3x3` from the nine components in the
row-major order a reference matrix is usually written in, returning it in simd's
column-major layout.

## The sRGB transfer

``FxGripSRGBToLinear`` applies the sRGB electro-optical transfer, decoding a gamma-encoded
component to linear. ``FxGripLinearToSRGB`` applies the inverse.

## Encoding a matrix

``FxGripEncodeColorMatrix`` writes a matrix as nine packed floats under a coder key.
``FxGripDecodeColorMatrix`` reads it back, returning the identity when the key is absent.

## The effect category

The `ColorGamut` category on `FxGripTileableEffect` reports the working gamut and its
matrices. `colorPrimaries` reads the host color-gamut API and returns
`kFxColorPrimaries_Rec709` when the API is unavailable. `isRec2020Gamut` and
`isRec709Gamut` classify it. `colorLuminanceWeights`, `rgbToXYZMatrix`, and
`xyzToRGBMatrix` return the working gamut's values, and `gamutMatrixToPrimaries:` and
`gamutMatrixFromPrimaries:` convert between the working gamut and a target.

```objc
// Inside an FxGripTileableEffect subclass:
simd_float3   weights = self.colorLuminanceWeights;
simd_float3x3 toWide  = [self gamutMatrixToPrimaries:kFxColorPrimaries_Rec2020];
```

The category also reports the color parameters' transfer curve.
`isGammaColorParameters` returns YES when the effect's color parameters are on the gamma
curve, and `isLinearColorParameters` returns YES when they are linear, from the effect's
desired processing color info.

## Topics

### Gamut functions

- ``FxGripLuminanceWeights``
- ``FxGripRGBToXYZMatrix``
- ``FxGripXYZToRGBMatrix``
- ``FxGripGamutConversionMatrix``
- ``FxGripColorMatrixMakeRowMajor``
- ``FxGripSRGBToLinear``
- ``FxGripLinearToSRGB``
- ``FxGripEncodeColorMatrix``
- ``FxGripDecodeColorMatrix``

### The effect category

- ``FxGripTileableEffect-class``

### Related

- <doc:TilingAndGeometry>
