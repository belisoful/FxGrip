/*!
	@file       FxGripOSCMetalTestSupport.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-10
	@header     FxGripOSCMetalTestSupport
	@abstract   Implements the live on-screen-control render pass and the block-driven part.
	@discussion Introduced in FxGrip 0.1.0. The pass renders into an FxPlugStub tile whose IOSurface is
	            the color attachment, so the rendered pixels read back through the texture. Blending is
	            off, so a draw writes its color verbatim and an assertion compares exact components.
*/

#import "FxGripOSCMetalTestSupport.h"
#import "FxPlugStub.h"
#import <CoreVideo/CoreVideo.h>

@implementation FxGripOSCMetalTestPass
{
	id<MTLCommandQueue> _commandQueue;
	id<MTLCommandBuffer> _commandBuffer;
	BOOL _finished;
}

+ (nullable id<MTLDevice>)sharedDevice
{
	static id<MTLDevice> device = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		device = MTLCreateSystemDefaultDevice();
	});
	return device;
}

+ (nullable instancetype)passWithCanvasSize:(CGSize)canvasSize
{
	FxGripOSCMetalTestPass *pass = [[self alloc] initWithCanvasSize:canvasSize];
	return pass;
}

+ (nullable FxImageTile *)destinationTileWithCanvasSize:(CGSize)canvasSize
{
	id<MTLDevice> device = self.sharedDevice;
	if (device == nil) {
		return nil;
	}
	FxRect bounds = { 0, 0, (SInt32)canvasSize.width, (SInt32)canvasSize.height };
	return [FxImageTile stubTileWithPixelBounds:bounds
									pixelFormat:kCVPixelFormatType_32BGRA
										 device:device];
}

+ (simd_float4)colorInTexture:(id<MTLTexture>)texture atCanvasPoint:(CGPoint)canvasPoint
{
	// The pipeline's canvas-to-Metal conversion flips y, so canvas y maps straight to a texture row.
	NSUInteger x = (NSUInteger)canvasPoint.x;
	NSUInteger y = (NSUInteger)canvasPoint.y;
	if (canvasPoint.x < 0.0 || canvasPoint.y < 0.0 || x >= texture.width || y >= texture.height) {
		return (simd_float4){ 0.0f, 0.0f, 0.0f, 0.0f };
	}
	uint8_t bgra[4] = { 0, 0, 0, 0 };
	[texture getBytes:bgra
		  bytesPerRow:sizeof(bgra)
		   fromRegion:MTLRegionMake2D(x, y, 1, 1)
		  mipmapLevel:0];
	return (simd_float4){ bgra[2] / 255.0f, bgra[1] / 255.0f, bgra[0] / 255.0f, bgra[3] / 255.0f };
}

- (nullable instancetype)initWithCanvasSize:(CGSize)canvasSize
{
	self = [super init];
	if (self == nil) {
		return nil;
	}
	_device = FxGripOSCMetalTestPass.sharedDevice;
	if (_device == nil) {
		return nil;
	}
	_canvasSize = canvasSize;
	FxRect bounds = { 0, 0, (SInt32)canvasSize.width, (SInt32)canvasSize.height };
	_tile = [FxImageTile stubTileWithPixelBounds:bounds
									 pixelFormat:kCVPixelFormatType_32BGRA
										  device:_device];
	_texture = [_tile metalTextureForDevice:_device];
	if (_tile == nil || _texture == nil) {
		return nil;
	}

	FxGripOnScreenControl *libraryOwner = [[FxGripOnScreenControl alloc] initWithAPIManager:(id _Nonnull)nil];
	_library = [libraryOwner fxOSCLibraryForDevice:_device];
	if (_library == nil) {
		return nil;
	}

	MTLRenderPipelineDescriptor *descriptor = [[MTLRenderPipelineDescriptor alloc] init];
	descriptor.vertexFunction = [_library newFunctionWithName:@"fxGripOSCVertexShader"];
	descriptor.fragmentFunction = [_library newFunctionWithName:@"fxGripOSCFragmentShader"];
	descriptor.colorAttachments[0].pixelFormat = _texture.pixelFormat;
	// Blending stays off so a draw writes its color verbatim and read-back compares exactly.
	descriptor.colorAttachments[0].blendingEnabled = NO;
	id<MTLRenderPipelineState> pipeline = [_device newRenderPipelineStateWithDescriptor:descriptor error:NULL];
	if (pipeline == nil) {
		return nil;
	}

	_commandQueue = [_device newCommandQueue];
	_commandBuffer = [_commandQueue commandBuffer];
	MTLRenderPassDescriptor *renderPass = [MTLRenderPassDescriptor renderPassDescriptor];
	renderPass.colorAttachments[0].texture = _texture;
	renderPass.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0);
	renderPass.colorAttachments[0].loadAction = MTLLoadActionClear;
	renderPass.colorAttachments[0].storeAction = MTLStoreActionStore;
	_commandEncoder = [_commandBuffer renderCommandEncoderWithDescriptor:renderPass];
	[_commandEncoder setRenderPipelineState:pipeline];
	MTLViewport viewport = { 0.0, 0.0, canvasSize.width, canvasSize.height, -1.0, 1.0 };
	[_commandEncoder setViewport:viewport];
	return self;
}

- (void)finish
{
	if (_finished) {
		return;
	}
	_finished = YES;
	[_commandEncoder endEncoding];
	[_commandBuffer commit];
	[_commandBuffer waitUntilCompleted];
}

- (simd_float4)colorAtCanvasPoint:(CGPoint)canvasPoint
{
	return [self.class colorInTexture:_texture atCanvasPoint:canvasPoint];
}

@end


@implementation FxGripOSCBlockDrawPart

- (void)drawSelected:(BOOL)selected
		  canvasSize:(CGSize)canvasSize
	  commandEncoder:(nonnull id<MTLRenderCommandEncoder>)commandEncoder
			  atTime:(CMTime)time
{
	_drawCount += 1;
	if (selected) {
		_selectedDrawCount += 1;
	}
	_lastCanvasSize = canvasSize;
	if (self.drawBlock != nil) {
		self.drawBlock(self, selected, canvasSize, commandEncoder);
	}
}

@end
