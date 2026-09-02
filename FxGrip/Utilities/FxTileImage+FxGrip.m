//
//  NSCoder+AtIndex.h
//  XPC Service
//
//  Created by ~ ~ on 3/19/24.
//

#import "FxTileImage+FxGrip.h"
#import "FxGripRect.h"
#import "FxGripErrors.h"
#import "FxGripTextImage.h"
#import "FxGripMTLDeviceCache.h"
#import <objc/runtime.h>
#import <AppKit/AppKit.h>
#import <MetalKit/MetalKit.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
#import <BEFoundation/CIImage+BExtension.h>
#import "FxGrip_ARC.h"

CGRect FxGripImageRectForPixelBounds(FxRect pixelBounds, FxMatrix44 *inverseTransform)
{
	if (inverseTransform == nil) {
		return CGRectZero;
	}
	CGPoint corners[4];
	FxGripCGRectGetCorners(FxGripRectToCGRect(pixelBounds), corners);
	for (NSUInteger index = 0; index < 4; index++) {
		corners[index] = [inverseTransform transform2DPoint:corners[index]];
	}
	return FxGripCGRectBoundingPoints(corners, 4);
}

FxRect FxGripPixelBoundsForImageRect(CGRect imageRect, FxMatrix44 *transform)
{
	if (transform == nil) {
		return FxGripRectZero();
	}
	CGPoint corners[4];
	FxGripCGRectGetCorners(imageRect, corners);
	for (NSUInteger index = 0; index < 4; index++) {
		corners[index] = [transform transform2DPoint:corners[index]];
	}
	return FxGripRectFromCGRect(FxGripCGRectBoundingPoints(corners, 4));
}

@implementation FxImageTile (FxGrip)

- (id<MTLDevice>)device
{
	void *deviceKey = @selector(device);
	id<MTLDevice>   foundDevice = objc_getAssociatedObject(self, deviceKey);
	
	if (foundDevice && foundDevice.registryID == self.deviceRegistryID) {
		return foundDevice;
	}
	
	foundDevice = nil;
	// Didn't find one, so create one with the right settings
	NSArray<id<MTLDevice>>* devices = MTLCopyAllDevices();
	foundDevice = nil;
	for (id<MTLDevice> nextDevice in devices)
	{
		if (nextDevice.registryID == self.deviceRegistryID)
		{
			foundDevice = nextDevice;
			break;
		}
	}
	NARC_RELEASE(devices);
	
	if (foundDevice) {
		objc_setAssociatedObject(self, deviceKey, foundDevice, OBJC_ASSOCIATION_RETAIN);
	}
	
	return NARC_RETAIN_AUTORELEASE(foundDevice);
}

- (OSType)pixelFormat
{
	return self.ioSurface.pixelFormat;
}

- (MTLPixelFormat)metalPixelFormat
{
	MTLPixelFormat  result = 0;
	OSType pixelFormat = self.ioSurface.pixelFormat;
	switch (pixelFormat)
	{
		case kCVPixelFormatType_32BGRA:
			result = MTLPixelFormatBGRA8Unorm;
			break;
			
		case kCVPixelFormatType_32RGBA:
			result = MTLPixelFormatRGBA8Unorm;
			break;
			
		case kCVPixelFormatType_64RGBALE:
			result = MTLPixelFormatRGBA16Unorm;
			break;
			
		case kCVPixelFormatType_64RGBAHalf: // Most Common Case
			result = MTLPixelFormatRGBA16Float;
			break;
			
		case kCVPixelFormatType_128RGBAFloat:
			result = MTLPixelFormatRGBA32Float;
			break;
			
			
		default:
			NSLog (@"Got an unexpected pixel format in the IOSurface: %c%c%c%c",
				   (pixelFormat >> 24) & 0x000000FF,
				   (pixelFormat >> 16) & 0x000000FF,
				   (pixelFormat >> 8) & 0x000000FF,
				   (pixelFormat & 0x000000FF));
			break;
	}
	
	return result;
}

- (id<MTLTexture>)metalTexture
{
	return [self metalTextureForDevice:self.device];
}

- (CGPoint)imagePointFromPixelPoint:(CGPoint)pixelPoint
{
	return [self.inversePixelTransform transform2DPoint:pixelPoint];
}

- (CGPoint)pixelPointFromImagePoint:(CGPoint)imagePoint
{
	return [self.pixelTransform transform2DPoint:imagePoint];
}

- (CGRect)imageSpaceBounds
{
	return FxGripImageRectForPixelBounds(self.imagePixelBounds, self.inversePixelTransform);
}

- (FxRect)pixelBoundsForImageRect:(CGRect)imageRect
{
	return FxGripPixelBoundsForImageRect(imageRect, self.pixelTransform);
}

- (CGRect)imageRectForPixelBounds:(FxRect)pixelBounds
{
	return FxGripImageRectForPixelBounds(pixelBounds, self.inversePixelTransform);
}

@end


@implementation FxImageTile (FxGripText)

- (BOOL)fxg_compositeCIImage:(CIImage *)overlay
					 opacity:(CGFloat)opacity
					   error:(NSError *_Nullable *_Nullable)outError
{
	if (overlay == nil) {
		return YES;
	}
	id<MTLDevice> gpuDevice = self.device;
	id<MTLTexture> outputTexture = gpuDevice ? [self metalTextureForDevice:gpuDevice] : nil;
	if (gpuDevice == nil || outputTexture == nil) {
		if (outError != NULL) {
			*outError = [NSError errorWithDomain:FxGripPlugErrorDomain
											code:kFxGripError_WatermarkNoDevice
										userInfo:@{ NSLocalizedDescriptionKey:
														@"the tile has no backing Metal device" }];
		}
		return NO;
	}

	CGColorSpaceRef colorSpace = [NSColorSpace sRGBColorSpace].CGColorSpace;
	CIImage *base = [CIImage imageWithMTLTexture:outputTexture
										 options:@{ kCIImageColorSpace: (__bridge id)colorSpace }];
	CIImage *combined = [CIImage combineImage:overlay alpha:opacity withImage:base];

	CIContext *ciContext = [CIContext contextWithMTLDevice:gpuDevice];
	CGRect extent = CGRectMake(0, 0, outputTexture.width, outputTexture.height);
	CGImageRef cgImage = [ciContext createCGImage:combined fromRect:extent];
	if (cgImage == NULL) {
		if (outError != NULL) {
			*outError = [NSError errorWithDomain:FxGripPlugErrorDomain
											code:kFxGripError_WatermarkRender
										userInfo:@{ NSLocalizedDescriptionKey:
														@"the composite produced no image" }];
		}
		return NO;
	}

	MTKTextureLoader *loader = [[MTKTextureLoader alloc] initWithDevice:gpuDevice];
	id<MTLTexture> sourceTexture = [loader newTextureWithCGImage:cgImage
														options:@{ MTKTextureLoaderOptionSRGB: @(YES),
																   MTKTextureLoaderOptionOrigin: MTKTextureLoaderOriginBottomLeft }
														  error:outError];
	CGImageRelease(cgImage);
	if (sourceTexture == nil) {
		return NO;
	}

	id<MTLCommandQueue> commandQueue = [FxGripMTLDeviceCache commandQueueForImageTile:self];
	id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
	MPSImageBilinearScale *scaleEncoder = [[MPSImageBilinearScale alloc] initWithDevice:gpuDevice];
	[scaleEncoder encodeToCommandBuffer:commandBuffer sourceTexture:sourceTexture destinationTexture:outputTexture];
	// Wait so the source texture outlives the GPU work before the loader is released.
	[commandBuffer commit];
	[commandBuffer waitUntilCompleted];
	[FxGripMTLDeviceCache returnCommandQueue:commandQueue];

	return YES;
}

- (BOOL)fxg_drawText:(NSString *)text
		 attributes:(NSDictionary<NSAttributedStringKey, id> *)attributes
	   atPixelPoint:(CGPoint)pixelPoint
			  error:(NSError *_Nullable *_Nullable)outError
{
	NSAttributedString *attributed = [[NSAttributedString alloc] initWithString:text attributes:attributes];
	id<MTLTexture> textTexture = [FxGripTextImage textureForAttributedString:attributed padding:0 device:self.device];
	if (textTexture == nil) {
		if (outError != NULL) {
			*outError = [NSError errorWithDomain:FxGripPlugErrorDomain
											code:kFxGripError_WatermarkRender
										userInfo:@{ NSLocalizedDescriptionKey:
														@"the text produced no image" }];
		}
		return NO;
	}
	CGColorSpaceRef colorSpace = [NSColorSpace sRGBColorSpace].CGColorSpace;
	CIImage *textImage = [CIImage imageWithMTLTexture:textTexture
											 options:@{ kCIImageColorSpace: (__bridge id)colorSpace }];
	textImage = [textImage imageByApplyingTransform:CGAffineTransformMakeTranslation(pixelPoint.x, pixelPoint.y)];
	return [self fxg_compositeCIImage:textImage opacity:1.0 error:outError];
}

@end
