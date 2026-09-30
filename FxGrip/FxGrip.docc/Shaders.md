# Shader Effects

Declare a shader's controls and color space in a comment inside the shader source.

## Overview

A shader carries its own parameter metadata in a block comment. ``FxGripShaderMetadata`` scans
the source, validates the metadata, and produces the parameter configuration records the rest of
FxGrip consumes. ``FxGripShaderEffect`` appends those records to the effect's parameters and adopts
the declared color space. The metadata uses the same parameter configuration vocabulary a
registration record uses, so every parameter type FxGrip creates is available to a shader.

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
        { id: 1, type: "float", name: "Radius", key: "radius",
          default: 8, minimum: 0, maximum: 100 },
        { id: 2, type: "integer", name: "Taps", key: "TAPS", constant: true,
          default: 9, minimum: 1, maximum: 33 },
        { id: 10, type: "group", name: "Tint", parameters: [
            { id: 11, type: "rgb", name: "Color", key: "tint" },
        ] },
    ],
}
*/

constant int TAPS [[function_constant(0)]];

struct BlurUniforms {
    float  radius;
    float3 tint;
};
```

A source may hold several blocks. Their parameter arrays concatenate in source order, and any
other top-level key may appear in one block only. Top-level keys the scanner does not recognize
pass through in ``FxGripShaderMetadata/properties``.

### Parameter records

Each record is a parameter configuration dictionary. The scanner adds three keys to the
vocabulary:

- `key` → the C identifier of the shader symbol the value binds to.
- `constant` → binds the value as a Metal function constant, by the name in `key`.
- `allowContinuousConstant` → permits a continuous type as a function constant.

The `id` is the parameter's identity in saved projects, and `key` is its binding to the shader.
Renaming a shader symbol changes `key` and leaves saved values intact. IDs run from 1 through
``kFxGripShaderParameterIdMaximum``. FxGrip and the host reserve the IDs above it.

### Function constants

A function constant compiles into the pipeline, so each distinct value builds a separate
pipeline. A discrete type (integer, toggle, menu, switch) has few values and is allowed as a
constant. A continuous type (float, percent, angle, rgb, rgba, point) produces a new value on
every slider drag, so the scanner refuses it as a constant unless the record sets
`allowContinuousConstant`. A type with no scalar value, such as a gradient or an image, is never
a constant.

### Color space

`colorSpace` declares the space the shader expects:

- `transfer` → `"linear"` or `"gamma"`. ``FxGripShaderEffect`` writes it to
  `desiredProcessingColorInfo`. The default is `"linear"`.
- `primaries` → `"host"`, `"rec709"`, or `"rec2020"`. `"host"` accepts the host's primaries
  unconverted and is the default.

### Failures

A failed scan returns nil with ``kFxGripError_ShaderMetadataMalformed`` for a block that does not
parse, or ``kFxGripError_ShaderMetadataInvalid`` for a value that fails validation. The error's
``FxGripShaderMetadataErrorLineKey`` holds the source line of the failing block.
``FxGripShaderEffect`` keeps the error in ``FxGripShaderEffect/shaderMetadataError`` and refuses
parameter creation with it.

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

### Metadata keys

- ``kFxGripShaderProperty_Version``
- ``kFxGripShaderProperty_Parameters``
- ``kFxGripShaderProperty_ColorSpace``
- ``kFxGripShaderProperty_Transfer``
- ``kFxGripShaderProperty_Primaries``
- ``kFxGripShaderProperty_Key``
- ``kFxGripShaderProperty_Constant``
- ``kFxGripShaderProperty_AllowContinuousConstant``

### Color-space values

- ``kFxGripShaderTransfer_Linear``
- ``kFxGripShaderTransfer_Gamma``
- ``kFxGripShaderPrimaries_Host``
- ``kFxGripShaderPrimaries_Rec709``
- ``kFxGripShaderPrimaries_Rec2020``
