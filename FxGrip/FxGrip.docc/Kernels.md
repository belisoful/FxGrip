# Kernel Effects

Write one compute kernel in Slang against the GripKernel module, build it to Metal and a reflection JSON, and render it with parameters, function constants, and keyed images bound.

## Overview

A kernel effect is a shader effect whose shader is a Slang compute kernel. Slang's CUDA and CPU
targets accept compute kernels only, so a kernel written to this contract runs on every backend
the EveryGrip frameworks target, and FxGrip runs it on Metal. ``FxGripKernelEffect`` scans the
same `FxGripShader` metadata block the fragment path uses (see <doc:Shaders>) from the kernel's
Slang source, creates the declared parameters, and encodes their values into the plugin state.
``FxGripKernelPipeline`` compiles the Metal source `slangc` emitted, binds every global from the
reflection JSON that ``FxGripKernelLayout`` reads, and dispatches the kernel over each tile.

The emitted Metal names are mangled (`radius` becomes `radius_0`, `TAPS` becomes `fc_TAPS_0`), so
the framework never binds by Metal reflection. The JSON carries the source names, the buffer and
texture indexes, the struct offsets, the scalar types, and the destination's read-write access.

A subclass names its kernel:

```objc
@implementation MyBlurEffect

- (NSURL *)kernelURL
{
    return [[NSBundle bundleForClass:self.class] URLForResource:@"GripBlur" withExtension:@"slang"];
}

@end
```

The effect reads `GripBlur.slang`, `GripBlur.metal`, and `GripBlur.json` beside each other. A
subclass that keeps them elsewhere overrides ``FxGripKernelEffect/kernelSource``,
``FxGripKernelEffect/kernelMetalSource``, and ``FxGripKernelEffect/kernelLayoutData`` instead.

### The contract

A kernel imports `GripKernel`, declares its globals, and defines one compute entry point. The
framework binds each global by its role:

- One `ConstantBuffer<T>` of the kernel's own struct → the uniforms. A member whose name matches
  a record's `key` receives that parameter's value at the JSON offset, converted to the JSON
  scalar type.
- One `ConstantBuffer<GripTile>` → the tile, found by its struct name. The kernel may omit it.
- A `Texture2D<float4>` whose name matches an image or gradient parameter's `key` → that
  parameter's image. Every other `Texture2D<float4>` → the source images in declaration order.
- Exactly one `RWTexture2D<float4>` → the destination tile.
- A `SamplerState` → bilinear filtering with clamp-to-edge addressing.
- A `[SpecializationConstant]` whose name matches a record with `constant: true` → that
  parameter's value, set as the Metal function constant at the JSON index. Slang restricts a
  specialization constant to a scalar, so a constant record has one component: integer, toggle,
  menu, switch, or a float type with `allowContinuousConstant`.

The entry point is `[shader("compute")] [numthreads(8, 8, 1)] void <name>(uint3 tid :
SV_DispatchThreadID)`. The framework dispatches enough threadgroups of the declared size to cover
the tile, and the kernel returns early outside it through `gripInsideTile`.

### The module

`GripKernel.slang` ships in `FxGrip.framework/Resources`. It declares:

- `GripTileMap` → `u` and `v`, the affine map from a destination pixel to a normalized
  coordinate in one texture.
- `GripTile` → `destinationBounds` (left, bottom, right, top, y up), `pixelScale`,
  `textureCount`, `reserved`, and `textures[16]`. The layout equals the fragment path's
  `FxGripShaderTile`, 544 bytes, and the framework fills both the same way.
- `gripTileSize(tile)` → the tile's size in texels.
- `gripInsideTile(tile, texel)` → whether a texel lies inside the tile. Texel row 0 is the top row.
- `gripImagePixel(tile, texel)` → the texel's center in destination pixel space, y up: the space
  of the fragment path's `imagePixel`.
- `gripTexCoord(tile, index, imagePixel)` → the normalized coordinate in texture `index` of the
  destination pixel. `index` is the texture's binding index, which `slangc` assigns in declaration
  order across every texture global, the destination included.

Through `gripImagePixel`, `gripTexCoord`, `pixelUnits`, and `pixelScale` keep the meaning they
have in the fragment path (see "Coordinates and pixel transforms" in <doc:Shaders>).

### The worked example

```slang
import GripKernel;

/* FxGripShader
{
    colorSpace: { transfer: "linear", primaries: "rec709" },
    parameters: [
        { id: 1, type: "float", name: "Radius", key: "radius", pixelUnits: true,
          default: 8, minimum: 0, maximum: 100 },
        { id: 2, type: "integer", name: "Taps", key: "TAPS", constant: true,
          default: 9, minimum: 1, maximum: 33 },
        { id: 3, type: "toggle", name: "Invert", key: "INVERT", constant: true, default: false },
        { id: 10, type: "group", name: "Tint", parameters: [
            { id: 11, type: "rgb", name: "Color", key: "tint",
              default: { red: 1, green: 1, blue: 1 } },
        ] },
        { id: 12, type: "imageref", name: "Matte", key: "matte" },
    ],
}
*/

struct BlurUniforms
{
    float radius;
    float3 tint;
    int2 offset;
    bool enabled;
};

ConstantBuffer<BlurUniforms> uniforms;
ConstantBuffer<GripTile> tile;
Texture2D<float4> source;
Texture2D<float4> matte;
RWTexture2D<float4> destination;
SamplerState bilinear;

[SpecializationConstant] const int TAPS = 9;
[SpecializationConstant] const bool INVERT = false;

[shader("compute")]
[numthreads(8, 8, 1)]
void fxGripKernel(uint3 tid : SV_DispatchThreadID)
{
    if (!gripInsideTile(tile, tid.xy))
    {
        return;
    }
    float2 imagePixel = gripImagePixel(tile, tid.xy);
    float2 uv = gripTexCoord(tile, 0, imagePixel);
    uint width, height;
    source.GetDimensions(width, height);
    float2 reach = float2(uniforms.radius / float(width), 0.0);
    float4 sum = 0;
    for (int tap = 0; tap < TAPS; tap++)
    {
        float position = TAPS > 1 ? float(tap) / float(TAPS - 1) * 2.0 - 1.0 : 0.0;
        sum += source.SampleLevel(bilinear, uv + reach * position, 0);
    }
    float4 color = sum / float(TAPS);
    float4 m = matte.SampleLevel(bilinear, gripTexCoord(tile, 1, imagePixel), 0);
    float3 rgb = color.rgb * uniforms.tint * m.a;
    if (INVERT)
    {
        rgb = color.a - rgb;
    }
    destination[tid.xy] = float4(rgb, color.a);
}
```

`source` is texture 0 and takes the effect clip. `matte` is texture 1 and takes the image
parameter's tile, mapped by its own bounds through `gripTexCoord(tile, 1, ...)`. `destination` is
texture 2. `radius` and `tint` pack into the uniforms buffer at offsets 0 and 16; `offset` and
`enabled` match no record and stay zero. `TAPS` and `INVERT` are function constants 0 and 1, so
each distinct pair builds its own pipeline.

### The build

`slangc` runs in the plug-in's project at build time. No Slang binary ships in a plug-in. The
command is:

```bash
slangc -I <module dir> GripBlur.slang -target metal -entry fxGripKernel -stage compute \
       -line-directive-mode standard -reflection-json GripBlur.json -o GripBlur.metal
```

`<module dir>` is the directory holding `GripKernel.slang`: `FxGrip/Shader` in the FxGrip
checkout, or `FxGrip.framework/Resources` in a build that links the framework.
`Scripts/fxgrip-slang.sh` runs the command, and `Scripts/README.md` describes the Xcode build
rule that runs it for every `.slang` file and bundles the three files as resources.
`-line-directive-mode standard` emits `#line` directives, so a runtime Metal compile error names
the Slang line.

### The render

``FxGripKernelPipeline`` compiles the Metal source as its own library, with no prelude, once per
device. A render scales each `pixelUnits` value by the destination's horizontal pixel scale,
builds the constant signature, and takes the pipeline state for the device and signature from a
cache that keeps ``kFxGripShaderPipelineStateCacheLimit`` states. A compute pipeline is
independent of the destination's pixel format, so the cache keys by device and signature alone.
The render then packs the uniforms, fills the tile, binds the textures and samplers, dispatches
ceil(width / 8) by ceil(height / 8) threadgroups for a `numthreads(8, 8, 1)` kernel, and waits
for the GPU.

The destination is written through the read-write texture. When the destination tile's texture
excludes shader writes, the kernel writes an intermediate texture that a blit copies into the
destination. When the metadata declares rec709 or rec2020 and the host's working primaries
differ, the same conversion passes the fragment path runs convert each bound texture into the
kernel's primaries and convert the kernel's output back into the destination.

### Failures

- The Slang source fails to scan → parameter creation fails with
  ``kFxGripError_ShaderMetadataMalformed`` or ``kFxGripError_ShaderMetadataInvalid``, and a
  render passes the first source image through.
- The reflection JSON does not parse, or its version is not 1.x →
  ``kFxGripError_KernelLayoutMalformed``.
- The reflection JSON breaks the contract: no entry point or two, a stage other than compute,
  a bound entry-point parameter, a constant buffer that is not a struct, two uniforms buffers, a
  `GripTile` of another size, a texture that is not 2D, a texture access other than read and
  readWrite, no read-write texture or two, a non-scalar specialization constant, or a binding
  kind outside the contract → ``kFxGripError_KernelLayoutInvalid``.
- The Metal source or the reflection JSON is missing, malformed, or invalid →
  ``FxGripKernelEffect/kernelError`` holds the failure, parameter creation succeeds, and every
  render fails with it.
- The Metal source fails to compile, the entry point is missing, the pipeline fails to build, or
  the threadgroup exceeds the pipeline's maximum → ``kFxGripError_ShaderCompileFailed``.
- A member, texture, or constant does not match the parameter bound to it, a constant's type in
  the JSON differs from the compiled library's, or a required constant has no value →
  ``kFxGripError_ShaderBindingInvalid``.
- The tile has no device or texture, no command queue is available, or the command buffer
  fails → ``kFxGripError_ShaderRenderFailed``.

Compile and binding failures are cached with the library or state they belong to.

## Topics

### The effect

- ``FxGripKernelEffect``

### The layout

- ``FxGripKernelLayout``
- ``FxGripKernelMember``
- ``FxGripKernelTexture``
- ``FxGripKernelSampler``
- ``FxGripKernelConstant``
- ``FxGripKernelScalarType``
- ``FxGripKernelTextureAccess``
- ``FxGripKernelMetalDataType``
- ``kFxGripKernelLayoutVersion``
- ``kFxGripKernelTileStructName``
- ``kFxGripKernelTileLength``

### The pipeline

- ``FxGripKernelPipeline``
- ``FxGripKernelPipelineState``
