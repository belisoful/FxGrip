/*!
	@file       FxGripShaderTestSupport.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripShaderTestSupport
	@abstract   Implements the documented shader example and the float tile helpers.
	@discussion Introduced in FxGrip 0.1.0. The tiles read and write their IOSurface-backed texture
	            directly, after the render's command buffer has completed.
*/

#import "FxGripShaderTestSupport.h"
#import "FxPlugStub.h"
#import <CoreVideo/CoreVideo.h>

NSString *FxGripShaderTestDocumentedExampleSource(void)
{
	return
		@"/* FxGripShader\n"
		@"{\n"
		@"    colorSpace: { transfer: \"linear\", primaries: \"rec709\" },\n"
		@"    parameters: [\n"
		@"        { id: 1, type: \"float\", name: \"Radius\", key: \"radius\",\n"
		@"          default: 8, minimum: 0, maximum: 100 },\n"
		@"        { id: 2, type: \"integer\", name: \"Taps\", key: \"TAPS\", constant: true,\n"
		@"          default: 9, minimum: 1, maximum: 33 },\n"
		@"        { id: 10, type: \"group\", name: \"Tint\", parameters: [\n"
		@"            { id: 11, type: \"rgb\", name: \"Color\", key: \"tint\",\n"
		@"              default: { red: 1, green: 1, blue: 1 } },\n"
		@"        ] },\n"
		@"    ],\n"
		@"}\n"
		@"*/\n"
		@"\n"
		@"constant int TAPS [[function_constant(0)]];\n"
		@"\n"
		@"struct BlurUniforms {\n"
		@"    float  radius;\n"
		@"    float3 tint;\n"
		@"};\n"
		@"\n"
		@"fragment float4 fxGripShaderFragment(FxGripShaderVertexOut in [[stage_in]],\n"
		@"                                     texture2d<float> source [[texture(0)]],\n"
		@"                                     constant BlurUniforms &uniforms [[buffer(0)]])\n"
		@"{\n"
		@"    constexpr sampler bilinear(filter::linear, address::clamp_to_edge);\n"
		@"    float2 reach = float2(uniforms.radius / float(source.get_width()), 0.0);\n"
		@"    float4 sum = 0.0;\n"
		@"    for (int tap = 0; tap < TAPS; tap++) {\n"
		@"        float position = TAPS > 1 ? float(tap) / float(TAPS - 1) * 2.0 - 1.0 : 0.0;\n"
		@"        sum += source.sample(bilinear, in.texCoord + reach * position);\n"
		@"    }\n"
		@"    float4 color = sum / float(TAPS);\n"
		@"    return float4(color.rgb * uniforms.tint, color.a);\n"
		@"}\n";
}

NSString *FxGripShaderTestSource(NSString *metadataBody, NSString *metal)
{
	return [NSString stringWithFormat:@"/* FxGripShader\n%@\n*/\n%@", metadataBody, metal];
}

id<MTLDevice> _Nullable FxGripShaderTestDevice(void)
{
	static id<MTLDevice> device = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		device = MTLCreateSystemDefaultDevice();
	});
	return device;
}

static id<MTLTexture> FxGripShaderTestTexture(FxImageTile *tile)
{
	return [tile metalTextureForDevice:FxGripShaderTestDevice()];
}

FxImageTile *_Nullable FxGripShaderTestFloatTile(FxRect bounds, simd_float4 fill)
{
	id<MTLDevice> device = FxGripShaderTestDevice();
	if (device == nil) {
		return nil;
	}
	FxImageTile *tile = [FxImageTile stubTileWithPixelBounds:bounds
												 pixelFormat:kCVPixelFormatType_128RGBAFloat
													  device:device];
	if (tile == nil) {
		return nil;
	}
	FxGripShaderTestFillTile(tile, ^simd_float4(NSUInteger column, NSUInteger row) {
		return fill;
	});
	return tile;
}

void FxGripShaderTestFillTile(FxImageTile *tile, simd_float4 (^color)(NSUInteger column, NSUInteger row))
{
	id<MTLTexture> texture = FxGripShaderTestTexture(tile);
	NSUInteger width = texture.width;
	NSUInteger height = texture.height;
	NSMutableData *pixels = [NSMutableData dataWithLength:width * height * sizeof(simd_float4)];
	simd_float4 *pixel = pixels.mutableBytes;
	for (NSUInteger row = 0; row < height; row++) {
		for (NSUInteger column = 0; column < width; column++) {
			pixel[row * width + column] = color(column, row);
		}
	}
	[texture replaceRegion:MTLRegionMake2D(0, 0, width, height)
			   mipmapLevel:0
				 withBytes:pixels.bytes
			   bytesPerRow:width * sizeof(simd_float4)];
}

simd_float4 FxGripShaderTestPixel(FxImageTile *tile, NSUInteger column, NSUInteger row)
{
	simd_float4 pixel = 0.0f;
	[FxGripShaderTestTexture(tile) getBytes:&pixel
								bytesPerRow:sizeof(pixel)
								 fromRegion:MTLRegionMake2D(column, row, 1, 1)
								mipmapLevel:0];
	return pixel;
}
