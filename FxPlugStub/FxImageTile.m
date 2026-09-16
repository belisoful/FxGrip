/*!
	@file       FxImageTile.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-10
	@header     FxImageTile
	@abstract   Test-only implementation of FxPlug's FxImageTile.
	@discussion Introduced in FxGrip 0.1.0. Implements the interface Apple declares in
	            FxImageTile.h. Pixel data lives in an optional IOSurface; metalTextureForDevice:
	            wraps that surface in a texture per device unless a test scripts the answer.
*/

#import "FxPlugStub.h"
#import <CoreVideo/CoreVideo.h>

@interface FxImageTile ()
@property (nonatomic, strong) NSMutableArray<id<MTLDevice>> *stubRequestedDeviceList;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, id<MTLTexture>> *stubTexturesByDevice;
@end

@implementation FxImageTile

@synthesize colorSpace = _colorSpace;

#pragma mark - Construction

- (instancetype)initWithImagePixelBounds:(FxRect)imageBounds tilePixelBounds:(FxRect)tileBounds
{
	self = [super init];
	if (self != nil) {
		_imagePixelBounds = imageBounds;
		_tilePixelBounds = tileBounds;
		_pixelTransform = [[FxMatrix44 alloc] init];
		_inversePixelTransform = [[FxMatrix44 alloc] init];
		_imageSource = kFxImageTileRequestSourceEffectClip;
		_mediaTime = kCMTimeZero;
		_stubRequestedDeviceList = [NSMutableArray array];
		_stubTexturesByDevice = [NSMutableDictionary dictionary];
	}
	return self;
}

- (instancetype)init
{
	return [self initWithImagePixelBounds:kFxRect_Empty tilePixelBounds:kFxRect_Empty];
}

- (void)dealloc
{
	if (_colorSpace != NULL) {
		CGColorSpaceRelease(_colorSpace);
	}
}

+ (instancetype)stubTileWithPixelBounds:(FxRect)bounds
{
	return [[self alloc] initWithImagePixelBounds:bounds tilePixelBounds:bounds];
}

+ (instancetype)stubTileWithPixelBounds:(FxRect)bounds
							pixelFormat:(OSType)ioSurfacePixelFormat
								 device:(id<MTLDevice>)device
{
	NSInteger width = bounds.right - bounds.left;
	NSInteger height = bounds.top - bounds.bottom;
	NSInteger bytesPerElement = [self stubBytesPerElementForIOSurfaceFormat:ioSurfacePixelFormat];
	if (width <= 0 || height <= 0 || bytesPerElement == 0) {
		return nil;
	}

	IOSurface *surface = [[IOSurface alloc] initWithProperties:@{
		IOSurfacePropertyKeyWidth: @(width),
		IOSurfacePropertyKeyHeight: @(height),
		IOSurfacePropertyKeyBytesPerElement: @(bytesPerElement),
		IOSurfacePropertyKeyPixelFormat: @(ioSurfacePixelFormat),
	}];
	if (surface == nil) {
		return nil;
	}

	FxImageTile *tile = [self stubTileWithPixelBounds:bounds];
	tile.ioSurface = surface;
	tile.deviceRegistryID = device.registryID;
	return tile;
}

#pragma mark - Pixel formats

+ (NSInteger)stubBytesPerElementForIOSurfaceFormat:(OSType)ioSurfacePixelFormat
{
	switch (ioSurfacePixelFormat) {
		case kCVPixelFormatType_32BGRA:
		case kCVPixelFormatType_32RGBA:
			return 4;
		case kCVPixelFormatType_64RGBALE:
		case kCVPixelFormatType_64RGBAHalf:
			return 8;
		case kCVPixelFormatType_128RGBAFloat:
			return 16;
		default:
			return 0;
	}
}

+ (MTLPixelFormat)stubMetalPixelFormatForIOSurfaceFormat:(OSType)ioSurfacePixelFormat
{
	switch (ioSurfacePixelFormat) {
		case kCVPixelFormatType_32BGRA:
			return MTLPixelFormatBGRA8Unorm;
		case kCVPixelFormatType_32RGBA:
			return MTLPixelFormatRGBA8Unorm;
		case kCVPixelFormatType_64RGBALE:
			return MTLPixelFormatRGBA16Unorm;
		case kCVPixelFormatType_64RGBAHalf:
			return MTLPixelFormatRGBA16Float;
		case kCVPixelFormatType_128RGBAFloat:
			return MTLPixelFormatRGBA32Float;
		default:
			return MTLPixelFormatInvalid;
	}
}

#pragma mark - Color space

- (CGColorSpaceRef)colorSpace
{
	return _colorSpace;
}

- (void)setColorSpace:(CGColorSpaceRef)colorSpace
{
	if (colorSpace == _colorSpace) {
		return;
	}
	if (colorSpace != NULL) {
		CGColorSpaceRetain(colorSpace);
	}
	if (_colorSpace != NULL) {
		CGColorSpaceRelease(_colorSpace);
	}
	_colorSpace = colorSpace;
}

#pragma mark - Textures

- (NSArray<id<MTLDevice>> *)stubRequestedDevices
{
	return [self.stubRequestedDeviceList copy];
}

- (id<MTLTexture>)metalTextureForDevice:(id<MTLDevice>)metalDevice
{
	if (metalDevice != nil) {
		[self.stubRequestedDeviceList addObject:metalDevice];
	}
	if (self.stubTextureProvider != nil) {
		return self.stubTextureProvider(metalDevice);
	}
	if (self.stubTexture != nil) {
		return self.stubTexture;
	}
	if (metalDevice == nil || self.ioSurface == nil) {
		return nil;
	}

	NSNumber *deviceKey = @(metalDevice.registryID);
	id<MTLTexture> cached = self.stubTexturesByDevice[deviceKey];
	if (cached != nil) {
		return cached;
	}

	MTLPixelFormat format = [self.class stubMetalPixelFormatForIOSurfaceFormat:self.ioSurface.pixelFormat];
	if (format == MTLPixelFormatInvalid) {
		return nil;
	}
	MTLTextureDescriptor *descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:format
																						  width:self.ioSurface.width
																						 height:self.ioSurface.height
																					  mipmapped:NO];
	descriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite | MTLTextureUsageRenderTarget;
	descriptor.storageMode = metalDevice.hasUnifiedMemory ? MTLStorageModeShared : MTLStorageModeManaged;
	id<MTLTexture> texture = [metalDevice newTextureWithDescriptor:descriptor iosurface:(__bridge IOSurfaceRef)self.ioSurface plane:0];
	if (texture != nil) {
		self.stubTexturesByDevice[deviceKey] = texture;
	}
	return texture;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"

- (GLuint)openGLTextureForContext:(CGLContextObj)openGLContext
{
	return 0;
}

- (double)scaleX
{
	return (*[self.pixelTransform matrix])[0][0];
}

- (double)scaleY
{
	return (*[self.pixelTransform matrix])[1][1];
}

- (double)pixelAspect
{
	return 1.0;
}

#pragma clang diagnostic pop

#pragma mark - Description

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ %p image=(%d,%d,%d,%d) tile=(%d,%d,%d,%d) surface=%@ device=%llu>",
			self.className, self,
			self.imagePixelBounds.left, self.imagePixelBounds.bottom, self.imagePixelBounds.right, self.imagePixelBounds.top,
			self.tilePixelBounds.left, self.tilePixelBounds.bottom, self.tilePixelBounds.right, self.tilePixelBounds.top,
			self.ioSurface == nil ? @"none" : [NSString stringWithFormat:@"%ldx%ld", (long)self.ioSurface.width, (long)self.ioSurface.height],
			self.deviceRegistryID];
}

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding
{
	return YES;
}

static void FxImageTileStubEncodeRect(NSCoder *coder, FxRect rect, NSString *key)
{
	[coder encodeInt32:rect.left forKey:[key stringByAppendingString:@".left"]];
	[coder encodeInt32:rect.bottom forKey:[key stringByAppendingString:@".bottom"]];
	[coder encodeInt32:rect.right forKey:[key stringByAppendingString:@".right"]];
	[coder encodeInt32:rect.top forKey:[key stringByAppendingString:@".top"]];
}

static FxRect FxImageTileStubDecodeRect(NSCoder *coder, NSString *key)
{
	FxRect rect;
	rect.left = [coder decodeInt32ForKey:[key stringByAppendingString:@".left"]];
	rect.bottom = [coder decodeInt32ForKey:[key stringByAppendingString:@".bottom"]];
	rect.right = [coder decodeInt32ForKey:[key stringByAppendingString:@".right"]];
	rect.top = [coder decodeInt32ForKey:[key stringByAppendingString:@".top"]];
	return rect;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	FxImageTileStubEncodeRect(coder, self.tilePixelBounds, @"tilePixelBounds");
	FxImageTileStubEncodeRect(coder, self.imagePixelBounds, @"imagePixelBounds");
	[coder encodeObject:self.pixelTransform forKey:@"pixelTransform"];
	[coder encodeObject:self.inversePixelTransform forKey:@"inversePixelTransform"];
	[coder encodeInt64:(int64_t)self.deviceRegistryID forKey:@"deviceRegistryID"];
	[coder encodeInteger:(NSInteger)self.field forKey:@"field"];
	[coder encodeInteger:(NSInteger)self.fieldOrder forKey:@"fieldOrder"];
	[coder encodeInteger:(NSInteger)self.imageOrigin forKey:@"imageOrigin"];
	[coder encodeInteger:(NSInteger)self.eyeType forKey:@"eyeType"];
	[coder encodeInteger:(NSInteger)self.imageSource forKey:@"imageSource"];
	[coder encodeInt32:(int32_t)self.parameterID forKey:@"parameterID"];
	[coder encodeInt64:self.mediaTime.value forKey:@"mediaTime.value"];
	[coder encodeInt32:self.mediaTime.timescale forKey:@"mediaTime.timescale"];
	[coder encodeInt32:(int32_t)self.mediaTime.flags forKey:@"mediaTime.flags"];
	[coder encodeInt64:self.mediaTime.epoch forKey:@"mediaTime.epoch"];
	[coder encodeObject:self.requestError forKey:@"requestError"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	self = [self initWithImagePixelBounds:FxImageTileStubDecodeRect(coder, @"imagePixelBounds")
						  tilePixelBounds:FxImageTileStubDecodeRect(coder, @"tilePixelBounds")];
	if (self != nil) {
		_pixelTransform = [coder decodeObjectOfClass:FxMatrix44.class forKey:@"pixelTransform"] ?: _pixelTransform;
		_inversePixelTransform = [coder decodeObjectOfClass:FxMatrix44.class forKey:@"inversePixelTransform"] ?: _inversePixelTransform;
		_deviceRegistryID = (uint64_t)[coder decodeInt64ForKey:@"deviceRegistryID"];
		_field = (FxField)[coder decodeIntegerForKey:@"field"];
		_fieldOrder = (FxFieldOrder)[coder decodeIntegerForKey:@"fieldOrder"];
		_imageOrigin = (FxImageOrigin)[coder decodeIntegerForKey:@"imageOrigin"];
		_eyeType = (FxEyeType)[coder decodeIntegerForKey:@"eyeType"];
		_imageSource = (FxImageTileRequestSource)[coder decodeIntegerForKey:@"imageSource"];
		_parameterID = (UInt32)[coder decodeInt32ForKey:@"parameterID"];
		_mediaTime.value = [coder decodeInt64ForKey:@"mediaTime.value"];
		_mediaTime.timescale = [coder decodeInt32ForKey:@"mediaTime.timescale"];
		_mediaTime.flags = (CMTimeFlags)[coder decodeInt32ForKey:@"mediaTime.flags"];
		_mediaTime.epoch = [coder decodeInt64ForKey:@"mediaTime.epoch"];
		_requestError = [coder decodeObjectOfClass:NSError.class forKey:@"requestError"];
	}
	return self;
}

@end
