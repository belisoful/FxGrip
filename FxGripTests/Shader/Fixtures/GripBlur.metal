#include <metal_stdlib>
#include <metal_math>
#include <metal_texture>
using namespace metal;

#line 36 "GripBlur.slang"
constant int fc_TAPS_0 [[function_constant(0)]];
constant int TAPS_0 = is_function_constant_defined(fc_TAPS_0) ? fc_TAPS_0 : int(9);

#line 37
constant bool fc_INVERT_0 [[function_constant(1)]];
constant bool INVERT_0 = is_function_constant_defined(fc_INVERT_0) ? fc_INVERT_0 : false;

#line 21 "/private/tmp/claude-501/-Users-user-Code-EveryGrip/ca122a2b-1826-404d-be26-ac87a36d607c/scratchpad/wt/FxGrip/Shader/GripKernel.slang"
struct GripTileMap_0
{
    float4 u_0;
    float4 v_0;
};


#line 32
struct GripTile_0
{
    float4 destinationBounds_0;
    float2 pixelScale_0;
    uint textureCount_0;
    uint reserved_0;
    array<GripTileMap_0, int(16)> textures_0;
};


#line 21 "GripBlur.slang"
struct BlurUniforms_0
{
    float radius_0;
    float3 tint_0;
    int2 offset_0;
    bool enabled_0;
};


#line 33
struct KernelContext_0
{
    GripTile_0 constant* tile_0;
    texture2d<float, access::sample> source_0;
    BlurUniforms_0 constant* uniforms_0;
    sampler bilinear_0;
    texture2d<float, access::sample> matte_0;
    texture2d<float, access::read_write> destination_0;
};


#line 2839 "core.meta.slang"
uint2 gripTileSize_0(KernelContext_0 thread* kernelContext_0)
{

#line 45 "/private/tmp/claude-501/-Users-user-Code-EveryGrip/ca122a2b-1826-404d-be26-ac87a36d607c/scratchpad/wt/FxGrip/Shader/GripKernel.slang"
    return uint2(uint(kernelContext_0->tile_0->destinationBounds_0.z - kernelContext_0->tile_0->destinationBounds_0.x), uint(kernelContext_0->tile_0->destinationBounds_0.w - kernelContext_0->tile_0->destinationBounds_0.y));
}


#line 45
bool gripInsideTile_0(uint2 _S1, KernelContext_0 thread* kernelContext_1)
{

#line 45
    uint2 _S2 = gripTileSize_0(kernelContext_1);

#line 45
    bool _S3;

#line 53
    if((_S1.x) < (_S2.x))
    {

#line 53
        _S3 = (_S1.y) < (_S2.y);

#line 53
    }
    else
    {

#line 53
        _S3 = false;

#line 53
    }

#line 53
    return _S3;
}


#line 53
float2 gripImagePixel_0(uint2 _S4, KernelContext_0 thread* kernelContext_2)
{

#line 61
    return float2(kernelContext_2->tile_0->destinationBounds_0.x + float(_S4.x) + 0.5f, kernelContext_2->tile_0->destinationBounds_0.w - float(_S4.y) - 0.5f);
}


#line 484 "core"
float2 gripTexCoord_0(uint _S5, float2 _S6, KernelContext_0 thread* kernelContext_3)
{

#line 68 "/private/tmp/claude-501/-Users-user-Code-EveryGrip/ca122a2b-1826-404d-be26-ac87a36d607c/scratchpad/wt/FxGrip/Shader/GripKernel.slang"
    if(_S5 >= 16U)
    {
        return float2(0.0f) ;
    }

    return float2(dot(kernelContext_3->tile_0->textures_0[_S5].u_0.xy, _S6) + kernelContext_3->tile_0->textures_0[_S5].u_0.z, dot(kernelContext_3->tile_0->textures_0[_S5].v_0.xy, _S6) + kernelContext_3->tile_0->textures_0[_S5].v_0.z);
}


#line 41 "GripBlur.slang"
[[kernel]] void fxGripKernel(uint3 tid_0 [[thread_position_in_grid]], GripTile_0 constant* tile_1 [[buffer(1)]], texture2d<float, access::sample> source_1 [[texture(0)]], BlurUniforms_0 constant* uniforms_1 [[buffer(0)]], sampler bilinear_1 [[sampler(0)]], texture2d<float, access::sample> matte_1 [[texture(1)]], texture2d<float, access::read_write> destination_1 [[texture(2)]])
{

#line 41
    thread KernelContext_0 kernelContext_4;

#line 41
    (&kernelContext_4)->tile_0 = tile_1;

#line 41
    (&kernelContext_4)->source_0 = source_1;

#line 41
    (&kernelContext_4)->uniforms_0 = uniforms_1;

#line 41
    (&kernelContext_4)->bilinear_0 = bilinear_1;

#line 41
    (&kernelContext_4)->matte_0 = matte_1;

#line 41
    (&kernelContext_4)->destination_0 = destination_1;

    uint2 _S7 = tid_0.xy;

#line 43
    bool _S8 = gripInsideTile_0(_S7, &kernelContext_4);

#line 43
    if(!_S8)
    {
        return;
    }

#line 45
    float2 _S9 = gripImagePixel_0(_S7, &kernelContext_4);

#line 45
    float2 _S10 = gripTexCoord_0(0U, _S9, &kernelContext_4);

#line 45
    texture2d<float, access::sample> _S11 = (&kernelContext_4)->source_0;



    thread uint width_0;

#line 49
    thread uint height_0;
    (*((&width_0)) = (_S11).get_width(0)),(*((&height_0)) = (_S11).get_height(0));
    float2 _S12 = float2((&kernelContext_4)->uniforms_0->radius_0 / float(width_0), 0.0f);
    float4 _S13 = float4(int4(int(0)) );

#line 52
    int tap_0 = int(0);

#line 52
    float4 sum_0 = _S13;
    for(;;)
    {

#line 53
        if(tap_0 < TAPS_0)
        {
        }
        else
        {

#line 53
            break;
        }

#line 53
        float position_0;

        if(TAPS_0 > int(1))
        {

#line 55
            position_0 = float(tap_0) / float(TAPS_0 - int(1)) * 2.0f - 1.0f;

#line 55
        }
        else
        {

#line 55
            position_0 = 0.0f;

#line 55
        }
        float4 sum_1 = sum_0 + (((&kernelContext_4)->source_0).sample(((&kernelContext_4)->bilinear_0), (_S10 + _S12 * float2(position_0) ), level((0.0f))));

#line 53
        tap_0 = tap_0 + int(1);

#line 53
        sum_0 = sum_1;

#line 53
    }

#line 58
    float4 color_0 = sum_0 / float4(float(TAPS_0)) ;

#line 58
    float2 _S14 = gripTexCoord_0(1U, _S9, &kernelContext_4);

    float3 rgb_0 = color_0.xyz * (&kernelContext_4)->uniforms_0->tint_0 * float3((((&kernelContext_4)->matte_0).sample(((&kernelContext_4)->bilinear_0), (_S14), level((0.0f)))).w) ;

#line 60
    float3 rgb_1;
    if(INVERT_0)
    {

#line 61
        rgb_1 = float3(color_0.w)  - rgb_0;

#line 61
    }
    else
    {

#line 61
        rgb_1 = rgb_0;

#line 61
    }



    (&kernelContext_4)->destination_0.write(float4(rgb_1, color_0.w),_S7);
    return;
}

