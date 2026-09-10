/*!
	@file       FxGripRealityKitPostPass.metal
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-09
	@header     FxGripRealityKitPostPass
	@abstract   The camera motion-blur and depth-of-field kernels of the RealityKit engine's post-pass.
	@discussion Introduced in FxGrip 0.1.0. RealityKit on macOS has neither a motion-blur nor a
	            depth-of-field camera component, so the engine applies both after the frame is drawn.
	            Motion blur reprojects each pixel through the camera's pose one shutter earlier and
	            blurs along the screen-space displacement. Depth of field gathers a disc whose radius
	            is the circle of confusion at each pixel's view depth, read from a depth proxy the
	            engine renders. Every sample pattern is fixed, so a frame reproduces exactly.
*/

#include <metal_stdlib>
using namespace metal;

/// The uniforms the motion-blur kernel reads. Matches `FxGripRealityKitMotionBlurUniforms` in Swift.
struct FxGripMotionBlurUniforms {
	float4x4 inverseProjection;
	float4x4 cameraToWorld;
	float4x4 previousViewProjection;
	float assumedDepth;
	uint sampleCount;
	float maximumPixels;
	float padding;
};

/// The uniforms the depth-of-field kernel reads. Matches `FxGripRealityKitDepthOfFieldUniforms`.
struct FxGripDepthOfFieldUniforms {
	float focusDistance;
	float aperture;
	float focalPixels;
	float farDistance;
	float maximumRadius;
	uint sampleCount;
	float2 padding;
};

constant sampler fxgLinearClamp(coord::normalized, address::clamp_to_edge, filter::linear);
constant sampler fxgNearestClamp(coord::normalized, address::clamp_to_edge, filter::nearest);

/// The view-space point along the pixel's ray at `depth` in front of the camera.
static float3 fxgViewPoint(float2 ndc, float4x4 inverseProjection, float depth)
{
	float4 far = inverseProjection * float4(ndc, 1.0, 1.0);
	float3 direction = far.xyz / far.w;
	return direction * (depth / max(-direction.z, 1e-6));
}

kernel void fxgMotionBlur(texture2d<float, access::sample> source [[texture(0)]],
						  texture2d<float, access::write> destination [[texture(1)]],
						  constant FxGripMotionBlurUniforms &uniforms [[buffer(0)]],
						  uint2 gid [[thread_position_in_grid]])
{
	uint width = destination.get_width();
	uint height = destination.get_height();
	if (gid.x >= width || gid.y >= height) {
		return;
	}
	float2 size = float2(width, height);
	float2 uv = (float2(gid) + 0.5) / size;
	float2 ndc = float2(uv.x * 2.0 - 1.0, 1.0 - uv.y * 2.0);

	float3 viewPoint = fxgViewPoint(ndc, uniforms.inverseProjection, uniforms.assumedDepth);
	float4 world = uniforms.cameraToWorld * float4(viewPoint, 1.0);
	float4 previousClip = uniforms.previousViewProjection * world;
	float2 previousNdc = previousClip.xy / max(previousClip.w, 1e-6);
	float2 previousUv = float2(previousNdc.x * 0.5 + 0.5, 0.5 - previousNdc.y * 0.5);

	float2 deltaPixels = (previousUv - uv) * size;
	float length2 = length(deltaPixels);
	if (length2 > uniforms.maximumPixels) {
		deltaPixels *= uniforms.maximumPixels / length2;
	}
	float2 deltaUv = deltaPixels / size;

	uint count = max(uniforms.sampleCount, 1u);
	float4 sum = 0.0;
	for (uint i = 0; i < count; i++) {
		// Centered on the exposure, so the frame does not drift toward either shutter edge.
		float t = (float(i) + 0.5) / float(count) - 0.5;
		sum += source.sample(fxgLinearClamp, uv + deltaUv * t);
	}
	destination.write(sum / float(count), gid);
}

/// The circle-of-confusion diameter in pixels at view depth `z`, thin-lens, for the given aperture
/// diameter in world units and focal length in pixels.
static float fxgCircleOfConfusion(float z, constant FxGripDepthOfFieldUniforms &uniforms)
{
	float depth = max(z, 1e-4);
	float focus = max(uniforms.focusDistance, 1e-4);
	float coc = uniforms.aperture * uniforms.focalPixels * abs(depth - focus) / (depth * focus);
	return min(coc, uniforms.maximumRadius * 2.0);
}

/// View depth at `uv` from the proxy, and the far distance where nothing was drawn.
///
/// The renderer antialiases a silhouette by coverage, so an edge texel holds the depth scaled by
/// its alpha. Dividing it back out gives the edge the entity's depth. Without the division an edge
/// decodes near depth zero.
static float fxgProxyDepth(texture2d<float, access::sample> proxy, float2 uv, float farDistance)
{
	float4 texel = proxy.sample(fxgNearestClamp, uv);
	if (texel.a <= 0.001) {
		return farDistance;
	}
	return saturate(texel.r / texel.a) * farDistance;
}

kernel void fxgDepthOfField(texture2d<float, access::sample> source [[texture(0)]],
							texture2d<float, access::write> destination [[texture(1)]],
							texture2d<float, access::sample> proxy [[texture(2)]],
							constant FxGripDepthOfFieldUniforms &uniforms [[buffer(0)]],
							uint2 gid [[thread_position_in_grid]])
{
	uint width = destination.get_width();
	uint height = destination.get_height();
	if (gid.x >= width || gid.y >= height) {
		return;
	}
	float2 size = float2(width, height);
	float2 uv = (float2(gid) + 0.5) / size;

	float centerDepth = fxgProxyDepth(proxy, uv, uniforms.farDistance);
	float radius = 0.5 * fxgCircleOfConfusion(centerDepth, uniforms);
	// Color and depth are read at the same texel, so a tap beside a silhouette never blends the
	// foreground's color under the background's weight.
	float4 center = source.sample(fxgNearestClamp, uv);
	if (radius < 0.5) {
		destination.write(center, gid);
		return;
	}

	// A golden-angle spiral, fixed for every pixel, so the gather is deterministic.
	uint count = max(uniforms.sampleCount, 1u);
	float4 sum = center;
	float weight = 1.0;
	for (uint i = 1; i <= count; i++) {
		float fraction = float(i) / float(count);
		float distance = radius * sqrt(fraction);
		float angle = float(i) * 2.399963;
		float2 offset = float2(cos(angle), sin(angle)) * distance;
		float2 sampleUv = uv + offset / size;

		// A tap contributes when its own circle of confusion reaches back to this pixel, which
		// keeps a sharp foreground from bleeding across a blurred background.
		float tapDepth = fxgProxyDepth(proxy, sampleUv, uniforms.farDistance);
		float tapRadius = 0.5 * fxgCircleOfConfusion(tapDepth, uniforms);
		float w = clamp((tapRadius - distance) + 1.0, 0.0, 1.0);
		sum += source.sample(fxgNearestClamp, sampleUv) * w;
		weight += w;
	}
	destination.write(sum / weight, gid);
}
