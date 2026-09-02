//
//  FxGripOSC.metal
//  FxGrip
//
//  The flat-color pipeline FxGripOnScreenControl draws with. Vertices arrive in
//  viewport-centered pixel coordinates; the fragment color is a uniform.
//

#include <metal_stdlib>
#include "FxGripOSCShaderTypes.h"

using namespace metal;

struct FxGripOSCRasterizerData {
	float4 position [[position]];
};

vertex FxGripOSCRasterizerData fxGripOSCVertexShader(uint vertexID [[vertex_id]],
			constant FxGripOSCVertex *vertices [[buffer(FxGripOSCVertexInputIndexVertices)]],
			constant vector_uint2 *viewportSizePointer [[buffer(FxGripOSCVertexInputIndexViewportSize)]])
{
	FxGripOSCRasterizerData out;
	float2 pixelSpacePosition = vertices[vertexID].position;
	float2 viewportSize = float2(*viewportSizePointer);
	out.position = float4(0.0, 0.0, 0.0, 1.0);
	out.position.xy = pixelSpacePosition / (viewportSize / 2.0);
	return out;
}

fragment float4 fxGripOSCFragmentShader(FxGripOSCRasterizerData in [[stage_in]],
			constant vector_float4 *color [[buffer(FxGripOSCFragmentInputIndexColor)]])
{
	return *color;
}

struct FxGripOSCTexturedRasterizerData {
	float4 position [[position]];
	float2 texCoord;
};

vertex FxGripOSCTexturedRasterizerData fxGripOSCTexturedVertexShader(uint vertexID [[vertex_id]],
			constant FxGripOSCTexturedVertex *vertices [[buffer(FxGripOSCVertexInputIndexVertices)]],
			constant vector_uint2 *viewportSizePointer [[buffer(FxGripOSCVertexInputIndexViewportSize)]])
{
	FxGripOSCTexturedRasterizerData out;
	float2 pixelSpacePosition = vertices[vertexID].position;
	float2 viewportSize = float2(*viewportSizePointer);
	out.position = float4(0.0, 0.0, 0.0, 1.0);
	out.position.xy = pixelSpacePosition / (viewportSize / 2.0);
	out.texCoord = vertices[vertexID].texCoord;
	return out;
}

fragment float4 fxGripOSCTexturedFragmentShader(FxGripOSCTexturedRasterizerData in [[stage_in]],
			texture2d<float> colorTexture [[texture(FxGripOSCFragmentTextureIndexColor)]],
			constant vector_float4 *tint [[buffer(FxGripOSCFragmentInputIndexColor)]])
{
	constexpr sampler textureSampler(mag_filter::linear, min_filter::linear, address::clamp_to_edge);
	float4 sample = colorTexture.sample(textureSampler, in.texCoord);
	return sample * (*tint);
}
