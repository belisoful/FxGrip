//
//  NSCoder+AtIndex.h
//  XPC Service
//
//  Created by ~ ~ on 3/19/24.
//

#import "FxTileImage+FxGrip.h"
#import "FxGripRect.h"
#import <objc/runtime.h>
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
