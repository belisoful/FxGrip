# Shader Effects

Declare a shader's controls and color space in a comment inside the shader source, and render it with the values bound.

## Overview

A shader carries its own parameter metadata in a block comment. ``FxGripShaderMetadata`` scans
the source, validates the metadata, and produces the parameter configuration records the rest of
FxGrip consumes. ``FxGripShaderEffect`` appends those records to the effect's parameters and adopts
the declared color space. The metadata uses the same parameter configuration vocabulary a
registration record uses, so every parameter type FxGrip creates is available to a shader.

``FxGripShaderEffect`` also renders the shader. It encodes the bound parameter values into the
plugin state, and ``FxGripShaderPipeline`` compiles the source, sets the function constants,
packs the uniform struct, converts the primaries, and draws each tile. The subclass finds a
parameter by its key through ``FxGripShaderEffect/shaderParameterForKey:``.

A subclass supplies the source:

```objc
@implementation MyBlurEffect

- (NSString *)shaderSource
{
    NSURL *url = [NSBundle.mainBundle URLForResource:@"Blur" withExtension:@"metal"];
    return [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:NULL];
}

@end
```

### The metadata block

A metadata block is a block comment whose opener starts a line and is followed by the word
`FxGripShader`. The block ends at the comment close, which is where the Metal compiler ends it.
The body is JSON5, so it accepts trailing commas and `//` comments.

```metal
/* FxGripShader
{
    colorSpace: { transfer: "linear", primaries: "rec709" },
    parameters: [
        { id: 1, type: "float", name: "Radius", key: "radius", pixelUnits: true,
          default: 8, minimum: 0, maximum: 100 },
        { id: 2, type: "integer", name: "Taps", key: "TAPS", constant: true,
          default: 9, minimum: 1, maximum: 33 },
        { id: 10, type: "group", name: "Tint", parameters: [
            { id: 11, type: "rgb", name: "Color", key: "tint",
              default: { red: 1, green: 1, blue: 1 } },
        ] },
    ],
}
*/

constant int TAPS [[function_constant(0)]];

struct BlurUniforms {
    float  radius;
    float3 tint;
};

fragment float4 fxGripShaderFragment(FxGripShaderVertexOut in [[stage_in]],
                                     texture2d<float> source [[texture(0)]],
                                     constant BlurUniforms &uniforms [[buffer(0)]])
{
    constexpr sampler bilinear(filter::linear, address::clamp_to_edge);
    float2 reach = float2(uniforms.radius / float(source.get_width()), 0.0);
    float4 sum = 0.0;
    for (int tap = 0; tap < TAPS; tap++) {
        float position = TAPS > 1 ? float(tap) / float(TAPS - 1) * 2.0 - 1.0 : 0.0;
        sum += source.sample(bilinear, in.texCoord + reach * position);
    }
    float4 color = sum / float(TAPS);
    return float4(color.rgb * uniforms.tint, color.a);
}
```

A source may hold several blocks. Their parameter arrays concatenate in source order, and any
other top-level key may appear in one block only. Top-level keys the scanner does not recognize
pass through in ``FxGripShaderMetadata/properties``.

### Parameter records

Each record is a parameter configuration dictionary. The scanner adds four keys to the
vocabulary:

- `key` → the C identifier of the shader symbol the value binds to.
- `constant` → binds the value as a Metal function constant, by the name in `key`.
- `allowContinuousConstant` → permits a continuous type as a function constant.
- `pixelUnits` → marks a float or integer value as a length in image-space units, which the
  render scales to destination pixels. It requires `key`.

The `id` is the parameter's identity in saved projects, and `key` is its binding to the shader.
Renaming a shader symbol changes `key` and leaves saved values intact. IDs run from 1 through
``kFxGripShaderParameterIdMaximum``. FxGrip and the host reserve the IDs above it.

### The fragment function

The pipeline compiles the source with a prelude in front of it. The prelude includes
`metal_stdlib`, declares `FxGripShaderVertexOut` and `FxGripShaderTile`, and supplies the
`fxGripShaderTexCoord` function and the vertex function. A `#line`
directive at its end restores the source's own line numbers, so a compiler error names the line
in the shader file. The effect renders the fragment function named
``kFxGripShaderFragmentFunctionName``, and a subclass names another through
``FxGripShaderEffect/shaderFragmentFunctionName``.

The fragment function receives these bindings:

- `[[stage_in]]` `FxGripShaderVertexOut` → `position`, the destination pixel; `texCoord`, the
  normalized coordinate of that pixel in texture 0; `imagePixel`, the pixel's center in the
  destination's pixel space, the space of its `tilePixelBounds`, with y increasing upward.
- `[[texture(n)]]` → source image n.
- A texture argument named by an image or gradient parameter's `key` → that parameter's image
  (see "Images and gradients").
- `[[buffer(0)]]` → the uniform struct.
- `[[buffer(1)]]` `FxGripShaderTile` → the destination bounds, the pixel scale, and the
  coordinate maps (see "Coordinates and pixel transforms").
- A function constant named by a constant parameter's `key` → that parameter's value.

### Coordinates and pixel transforms

A source can cover different bounds than the destination, and an image parameter can arrive at
another resolution. `fxGripShaderTexCoord(tile, n, in.imagePixel)` returns the normalized
coordinate in texture n of the current destination pixel. The pipeline builds the map for each
texture index below ``kFxGripShaderTextureMapLimit`` from the tiles' pixel transforms. A
destination pixel goes to image space through the destination's inverse pixel transform, then
to the texture's pixel space through its tile's pixel transform. `texCoord` is the same map for
texture 0. A texture with no tile, such as a gradient or an empty image, maps the destination
tile onto 0 through 1.

At a proxy resolution the host renders fewer pixels per image-space unit. `tile.pixelScale`
holds the destination's pixels per image-space unit along x and y. A record that sets
`pixelUnits` has its value multiplied by `tile.pixelScale.x` before the pipeline sets the
constants and packs the uniforms, so a radius declared in full-resolution pixels covers the same
part of the image at every resolution. A shader that scales x and y separately reads
`tile.pixelScale` itself.

### Images and gradients

A texture argument whose name matches the `key` of an image or gradient parameter binds that
parameter's image at the argument's reflected index, and replaces the source image at that
index. ``FxGripShaderPipelineState/textureIndexes`` reports the bound indexes. The argument must
be a `texture2d`.

- An image parameter → the source tile whose `parameterID` matches. The effect schedules an
  image parameter's tile with the effect clip, so its tile is among the source images.
- A gradient parameter → a texture one pixel tall with a sample per column, decoded from the
  plugin state the gradient parameter encodes itself into. Read it with
  `ramp.sample(sampler, float2(t, 0.5))` or `ramp.read(uint2(column, 0))`.
- A parameter that supplies no image, such as an empty image well → a transparent black texture.

### The uniform struct

The layout of the uniform struct comes from Metal reflection. The pipeline builds each render
pipeline with binding reflection and reads the struct at fragment buffer
``kFxGripShaderUniformBufferIndex``. Each member whose name matches the `key` of a non-constant
parameter receives that parameter's value at the member's reflected offset. The compiler's own
alignment applies, so a `float3` member occupies 16 bytes and a `packed_float3` member 12. The
order of the members is independent of the order of the records. A member with no matching
parameter stays zero, and a parameter with no matching member is unused.

A member bound by key must be a scalar or vector whose component count matches the parameter,
as ``FxGripShaderComponentCountForType`` reports. The scalar type converts the value:

- `float` or `half` → the value.
- An integer type → the value rounded to the nearest integer and clamped to the type's range.
- `bool` → `true` for any nonzero value.

### Function constants

A function constant compiles into the pipeline, so each distinct value builds a separate
pipeline. The pipeline sets each constant parameter's value in the `MTLFunctionConstantValues`
it specializes the fragment function with, converted to the constant's declared type. It caches
one pipeline per device, destination pixel format, and constant signature, and keeps
``kFxGripShaderPipelineStateCacheLimit`` of them. ``FxGripShaderPipeline/constantSignatureForValues:``
reports the signature that keys the cache. Every instance of an effect that renders the same
source shares one pipeline, so each device compiles the source once per process. A compile runs
outside the cache lock. A render that needs a pipeline under construction waits for that compile,
and a render that needs any other pipeline proceeds.

A discrete type (integer, toggle, menu, switch) has few values and is allowed as a constant. A
continuous type (float, percent, angle, rgb, rgba, point) produces a new value on every slider
drag, so the scanner refuses it as a constant unless the record sets `allowContinuousConstant`.
A type with no scalar value, such as a gradient or an image, is never a constant.

A required function constant must have a value. A required constant that no constant parameter
binds, or whose parameter has no value, refuses the pipeline. A constant the shader reads only
through `is_function_constant_defined` stays undefined when its parameter has no value.

### Values in the plugin state

The render thread cannot use the retrieval API, so the effect reads the parameters during
`pluginState:atTime:quality:error:` (see <doc:PluginState>).
``FxGripShaderEffect/shaderValuesAtTime:`` collects the value of every keyed parameter into an
``FxGripShaderValues`` snapshot, and the effect encodes it under ``kFxGripShaderValuesCoderKey``
with the host's working primaries and the processing color info. The render decodes the snapshot
and hands it to the pipeline. A parameter the host has not created contributes no value. A
subclass overrides ``FxGripShaderEffect/shaderValuesAtTime:`` to adjust or add values.

### Color space

`colorSpace` declares the space the shader expects:

- `transfer` → `"linear"` or `"gamma"`. ``FxGripShaderEffect`` writes it to
  `desiredProcessingColorInfo`. The default is `"linear"`.
- `primaries` → `"host"`, `"rec709"`, or `"rec2020"`. `"host"` accepts the host's primaries
  unconverted and is the default. ``FxGripShaderMetadata/primaries`` reports the declared value.

When the declared primaries differ from the host's working primaries, the pipeline converts. A
conversion pass converts each source texture into the declared primaries, the fragment function
renders into an intermediate texture, and a final pass converts the result back into the
destination. Every bound texture converts, keyed images and gradients included. A gamma-encoded
image is unpremultiplied, decoded with the sRGB transfer, converted, encoded, and premultiplied
again. Equal primaries render with no conversion pass.

### Failures

A failed scan returns nil with ``kFxGripError_ShaderMetadataMalformed`` for a block that does not
parse, or ``kFxGripError_ShaderMetadataInvalid`` for a value that fails validation. The error's
``FxGripShaderMetadataErrorLineKey`` holds the source line of the failing block.
``FxGripShaderEffect`` keeps the error in ``FxGripShaderEffect/shaderMetadataError`` and refuses
parameter creation with it. An effect whose source is nil passes its first source image through.

A render fails with one of these errors:

- ``kFxGripError_ShaderCompileFailed`` → the source fails to compile, the fragment function is
  missing, or the pipeline fails to build. The compiler's error is under `NSUnderlyingErrorKey`.
- ``kFxGripError_ShaderBindingInvalid`` → a uniform member, texture argument, or function
  constant does not match the parameter bound to it, or a required constant has no value.
- ``kFxGripError_ShaderRenderFailed`` → the tile has no device or texture, no command queue is
  available, or the command buffer fails.

The pipeline caches a compile or binding failure with the library or pipeline it belongs to, so
a broken shader reports the same error on every render without compiling again.

## Topics

### Scanning

- ``FxGripShaderMetadata``
- ``FxGripShaderPrimaries``
- ``FxGripShaderMetadataErrorLineKey``
- ``kFxGripShaderBlockSentinel``
- ``kFxGripShaderMetadataVersion``
- ``kFxGripShaderParameterIdMaximum``

### The effect

- ``FxGripShaderEffect``

### The pipeline

- ``FxGripShaderPipeline``
- ``FxGripShaderPipelineState``
- ``FxGripShaderValues``
- ``FxGripShaderComponentCountForType``
- ``kFxGripShaderFragmentFunctionName``
- ``kFxGripShaderVertexFunctionName``
- ``kFxGripShaderUniformBufferIndex``
- ``kFxGripShaderTileBufferIndex``
- ``kFxGripShaderTextureMapLimit``
- ``kFxGripShaderPipelineStateCacheLimit``

### Plugin-state keys

- ``kFxGripShaderValuesCoderKey``
- ``kFxGripShaderHostPrimariesCoderKey``
- ``kFxGripShaderColorInfoCoderKey``

### Metadata keys

- ``kFxGripShaderProperty_Version``
- ``kFxGripShaderProperty_Parameters``
- ``kFxGripShaderProperty_ColorSpace``
- ``kFxGripShaderProperty_Transfer``
- ``kFxGripShaderProperty_Primaries``
- ``kFxGripShaderProperty_Key``
- ``kFxGripShaderProperty_Constant``
- ``kFxGripShaderProperty_AllowContinuousConstant``
- ``kFxGripShaderProperty_PixelUnits``

### Color-space values

- ``kFxGripShaderTransfer_Linear``
- ``kFxGripShaderTransfer_Gamma``
- ``kFxGripShaderPrimaries_Host``
- ``kFxGripShaderPrimaries_Rec709``
- ``kFxGripShaderPrimaries_Rec2020``
