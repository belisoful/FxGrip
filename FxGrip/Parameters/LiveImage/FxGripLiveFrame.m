/*!
	@file       FxGripLiveFrame.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripLiveFrame
	@abstract   Implements the immutable published image and its lazy CGImage.
	@discussion Introduced in FxGrip 0.1.0. A frame table maps each supported Metal pixel format to
	            its byte layout. The constructors copy pixels from raw bytes, a texture, a CGImage,
	            or an image buffer, repacking rows tightly. The CGImage is built on first use, with a
	            float format converted to 8-bit clamped to 0...1. The color space follows the format
	            unless colorSpaceName overrides it.
*/

#import "FxGripLiveFrame.h"
#import "FxGripImageBuffer.h"
#import "FxGrip_ARC.h"

typedef struct {
	MTLPixelFormat	format;
	const char		*name;
	NSUInteger		bytesPerPixel;
	NSUInteger		bitsPerComponent;
	NSUInteger		components;
	BOOL			isFloat;
	BOOL			isBGRA;
} FxGripLiveFrameFormatInfo;

static const FxGripLiveFrameFormatInfo kFxGripLiveFrameFormats[] = {
	{ MTLPixelFormatRGBA8Unorm,			"RGBA8",		4,	8,	4, NO,  NO  },
	{ MTLPixelFormatRGBA8Unorm_sRGB,	"RGBA8 sRGB",	4,	8,	4, NO,  NO  },
	{ MTLPixelFormatBGRA8Unorm,			"BGRA8",		4,	8,	4, NO,  YES },
	{ MTLPixelFormatBGRA8Unorm_sRGB,	"BGRA8 sRGB",	4,	8,	4, NO,  YES },
	{ MTLPixelFormatRGBA16Unorm,		"RGBA16",		8,	16,	4, NO,  NO  },
	{ MTLPixelFormatRGBA16Float,		"RGBA16F",		8,	16,	4, YES, NO  },
	{ MTLPixelFormatRGBA32Float,		"RGBA32F",		16,	32,	4, YES, NO  },
	{ MTLPixelFormatR8Unorm,			"R8",			1,	8,	1, NO,  NO  },
	{ MTLPixelFormatR16Float,			"R16F",			2,	16,	1, YES, NO  },
	{ MTLPixelFormatR32Float,			"R32F",			4,	32,	1, YES, NO  },
};

static const FxGripLiveFrameFormatInfo *FxGripLiveFrameInfoForFormat(MTLPixelFormat format)
{
	const NSUInteger count = sizeof(kFxGripLiveFrameFormats) / sizeof(kFxGripLiveFrameFormats[0]);
	for (NSUInteger index = 0; index < count; index++) {
		if (kFxGripLiveFrameFormats[index].format == format) {
			return &kFxGripLiveFrameFormats[index];
		}
	}
	return NULL;
}

static inline float FxGripLiveFrameHalfToFloat(uint16_t half)
{
	uint32_t sign = (uint32_t)(half >> 15) << 31;
	uint32_t exponent = (half >> 10) & 0x1F;
	uint32_t mantissa = half & 0x3FF;
	uint32_t bits;
	if (exponent == 0) {
		if (mantissa == 0) {
			bits = sign;
		} else {
			// Subnormal half: renormalize into a float exponent.
			exponent = 127 - 15 + 1;
			while ((mantissa & 0x400) == 0) {
				mantissa <<= 1;
				exponent--;
			}
			mantissa &= 0x3FF;
			bits = sign | (exponent << 23) | (mantissa << 13);
		}
	} else if (exponent == 31) {
		bits = sign | 0x7F800000 | (mantissa << 13);
	} else {
		bits = sign | ((exponent + 112) << 23) | (mantissa << 13);
	}
	float value;
	memcpy(&value, &bits, sizeof(value));
	return value;
}

static inline uint8_t FxGripLiveFrameByteFromFloat(float value)
{
	if (!(value > 0.0f)) {
		return 0;
	}
	if (value >= 1.0f) {
		return 255;
	}
	return (uint8_t)(value * 255.0f + 0.5f);
}

static inline float FxGripLiveFrameComponent(const uint8_t *pixel, NSUInteger index, NSUInteger bitsPerComponent)
{
	if (bitsPerComponent == 16) {
		uint16_t half;
		memcpy(&half, pixel + index * 2, sizeof(half));
		return FxGripLiveFrameHalfToFloat(half);
	}
	float value;
	memcpy(&value, pixel + index * 4, sizeof(value));
	return value;
}


/*!
	@abstract	One immutable published image: tightly packed pixels with a CGImage built on demand.
	@discussion	Introduced in FxGrip 0.1.0. The frame owns a copy of its pixels and the format info
				for its layout. The CGImage is cached after the first build and discarded when the
				color space name changes. */
@implementation FxGripLiveFrame
{
	const FxGripLiveFrameFormatInfo *_info;
	NSData *_pixels;
	NSUInteger _width;
	NSUInteger _height;
	NSTimeInterval _timestamp;
	NSString *_colorSpaceName;
	CGImageRef _image;
}

#pragma mark Construction

+ (BOOL)supportsPixelFormat:(MTLPixelFormat)pixelFormat
{
	return FxGripLiveFrameInfoForFormat(pixelFormat) != NULL;
}

- (nullable instancetype)initWithPixels:(NSData *)pixels
								  width:(NSUInteger)width
								 height:(NSUInteger)height
								   info:(const FxGripLiveFrameFormatInfo *)info
{
	if (info == NULL || pixels == nil || width == 0 || height == 0
		|| pixels.length < width * height * info->bytesPerPixel) {
		return nil;
	}
	self = [super init];
	if (self != nil) {
		_info = info;
		_pixels = [pixels copy];
		_width = width;
		_height = height;
		_timestamp = NSProcessInfo.processInfo.systemUptime;
	}
	return self;
}

/*!
	@method		frameWithBytes:rowBytes:width:height:pixelFormat:
	@abstract	Copies pixel rows into a frame, repacking to a tight stride.
	@return		A frame, or nil for an unsupported format, zero dimensions, a nil source, or a stride
				shorter than a row. */
+ (nullable instancetype)frameWithBytes:(const void *)pixels
							   rowBytes:(NSUInteger)rowBytes
								  width:(NSUInteger)width
								 height:(NSUInteger)height
							pixelFormat:(MTLPixelFormat)pixelFormat
{
	const FxGripLiveFrameFormatInfo *info = FxGripLiveFrameInfoForFormat(pixelFormat);
	if (info == NULL || pixels == NULL || width == 0 || height == 0) {
		return nil;
	}
	NSUInteger tightRowBytes = width * info->bytesPerPixel;
	if (rowBytes < tightRowBytes) {
		return nil;
	}
	NSData *packed;
	if (rowBytes == tightRowBytes) {
		packed = [NSData dataWithBytes:pixels length:tightRowBytes * height];
	} else {
		NSMutableData *rows = [NSMutableData dataWithLength:tightRowBytes * height];
		uint8_t *destination = rows.mutableBytes;
		const uint8_t *source = pixels;
		for (NSUInteger row = 0; row < height; row++) {
			memcpy(destination + row * tightRowBytes, source + row * rowBytes, tightRowBytes);
		}
		packed = rows;
	}
	return NARC_AUTORELEASE([[self alloc] initWithPixels:packed width:width height:height info:info]);
}

/*!
	@method		frameWithTexture:
	@abstract	Reads mipmap level 0 of a CPU-readable 2D texture into a frame.
	@return		A frame, or nil for a private texture, a non-2D texture, or an unsupported format.
	@discussion	Introduced in FxGrip 0.1.0. The read is synchronous on the calling thread. */
+ (nullable instancetype)frameWithTexture:(id<MTLTexture>)texture
{
	const FxGripLiveFrameFormatInfo *info = FxGripLiveFrameInfoForFormat(texture.pixelFormat);
	if (texture == nil || info == NULL || texture.textureType != MTLTextureType2D
		|| texture.storageMode == MTLStorageModePrivate
		|| texture.width == 0 || texture.height == 0) {
		return nil;
	}
	NSUInteger rowBytes = texture.width * info->bytesPerPixel;
	NSMutableData *pixels = [NSMutableData dataWithLength:rowBytes * texture.height];
	[texture getBytes:pixels.mutableBytes
		  bytesPerRow:rowBytes
		   fromRegion:MTLRegionMake2D(0, 0, texture.width, texture.height)
		  mipmapLevel:0];
	return NARC_AUTORELEASE([[self alloc] initWithPixels:pixels width:texture.width height:texture.height info:info]);
}

/*! Draws a CGImage into an RGBA8Unorm premultiplied frame. */
+ (nullable instancetype)frameWithCGImage:(CGImageRef)image
{
	if (image == NULL) {
		return nil;
	}
	size_t width = CGImageGetWidth(image);
	size_t height = CGImageGetHeight(image);
	if (width == 0 || height == 0) {
		return nil;
	}
	NSMutableData *pixels = [NSMutableData dataWithLength:width * height * 4];
	CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
	CGContextRef context = CGBitmapContextCreate(pixels.mutableBytes, width, height, 8, width * 4, space,
												 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrderDefault);
	CGColorSpaceRelease(space);
	if (context == NULL) {
		return nil;
	}
	CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
	CGContextRelease(context);
	return NARC_AUTORELEASE([[self alloc] initWithPixels:pixels width:width height:height
												   info:FxGripLiveFrameInfoForFormat(MTLPixelFormatRGBA8Unorm)]);
}

static MTLPixelFormat FxGripLiveFrameMetalFormatForBuffer(FxGripPixelFormat format)
{
	switch (format) {
		case FxGripPixelFormatRGBA8U:	return MTLPixelFormatRGBA8Unorm;
		case FxGripPixelFormatRGBA16U:	return MTLPixelFormatRGBA16Unorm;
		case FxGripPixelFormatRGBA16F:	return MTLPixelFormatRGBA16Float;
		case FxGripPixelFormatRGBA32F:	return MTLPixelFormatRGBA32Float;
		case FxGripPixelFormatGray8U:	return MTLPixelFormatR8Unorm;
		case FxGripPixelFormatGray16F:	return MTLPixelFormatR16Float;
		case FxGripPixelFormatGray32F:	return MTLPixelFormatR32Float;
		default:						return MTLPixelFormatInvalid;
	}
}

/*!
	@method		frameWithImageBuffer:
	@abstract	Wraps an image buffer's pixels in a frame.
	@discussion	Introduced in FxGrip 0.1.0. A buffer format that maps to a Metal format directly is
				used as is; every other format converts to RGBA8U first. */
+ (nullable instancetype)frameWithImageBuffer:(FxGripImageBuffer *)buffer
{
	if (buffer == nil) {
		return nil;
	}
	MTLPixelFormat format = FxGripLiveFrameMetalFormatForBuffer(buffer.format);
	FxGripImageBuffer *source = buffer;
	if (format == MTLPixelFormatInvalid) {
		source = [buffer bufferByConvertingToFormat:FxGripPixelFormatRGBA8U compression:FxGripCompressionNone];
		format = MTLPixelFormatRGBA8Unorm;
	}
	NSData *pixels = source.pixelData;
	if (pixels == nil) {
		return nil;
	}
	return NARC_AUTORELEASE([[self alloc] initWithPixels:pixels width:source.width height:source.height
												   info:FxGripLiveFrameInfoForFormat(format)]);
}

- (void)dealloc
{
	if (_image != NULL) {
		CGImageRelease(_image);
	}
	SUPER_DEALLOC();
}

- (id)copyWithZone:(nullable NSZone *)zone
{
	return NARC_RETAIN(self);
}

#pragma mark Properties

- (NSUInteger)width
{
	return _width;
}

- (NSUInteger)height
{
	return _height;
}

- (MTLPixelFormat)pixelFormat
{
	return _info->format;
}

- (NSUInteger)bytesPerPixel
{
	return _info->bytesPerPixel;
}

- (NSUInteger)rowBytes
{
	return _width * _info->bytesPerPixel;
}

- (NSData *)pixels
{
	return _pixels;
}

- (BOOL)isFloat
{
	return _info->isFloat;
}

- (NSTimeInterval)timestamp
{
	return _timestamp;
}

- (NSString *)formatDescription
{
	return @(_info->name);
}

- (NSString *)sizeDescription
{
	return [NSString stringWithFormat:@"%lu×%lu %s", (unsigned long)_width, (unsigned long)_height, _info->name];
}

- (nullable NSString *)colorSpaceName
{
	@synchronized (self) {
		return _colorSpaceName;
	}
}

- (void)setColorSpaceName:(nullable NSString *)colorSpaceName
{
	@synchronized (self) {
		_colorSpaceName = [colorSpaceName copy];
		if (_image != NULL) {
			CGImageRelease(_image);
			_image = NULL;
		}
	}
}

#pragma mark CGImage

- (CGColorSpaceRef)newColorSpace CF_RETURNS_RETAINED
{
	if (_colorSpaceName.length > 0) {
		CGColorSpaceRef named = CGColorSpaceCreateWithName((__bridge CFStringRef)_colorSpaceName);
		if (named != NULL) {
			return named;
		}
	}
	if (_info->components == 1) {
		return CGColorSpaceCreateWithName(_info->isFloat ? kCGColorSpaceExtendedLinearGray : kCGColorSpaceGenericGrayGamma2_2);
	}
	return CGColorSpaceCreateWithName(_info->isFloat ? kCGColorSpaceExtendedLinearSRGB : kCGColorSpaceSRGB);
}

/*! Float pixels clamped to 0...1 as 8-bit components, in the frame's channel order. */
- (NSData *)eightBitPixels
{
	NSUInteger components = _info->components;
	NSUInteger count = _width * _height;
	NSMutableData *bytes = [NSMutableData dataWithLength:count * components];
	uint8_t *destination = bytes.mutableBytes;
	const uint8_t *source = _pixels.bytes;
	NSUInteger bytesPerPixel = _info->bytesPerPixel;
	for (NSUInteger pixel = 0; pixel < count; pixel++) {
		const uint8_t *sourcePixel = source + pixel * bytesPerPixel;
		for (NSUInteger component = 0; component < components; component++) {
			destination[pixel * components + component] =
				FxGripLiveFrameByteFromFloat(FxGripLiveFrameComponent(sourcePixel, component, _info->bitsPerComponent));
		}
	}
	return bytes;
}

- (CGImageRef)newCGImage CF_RETURNS_RETAINED
{
	NSData *pixels = _pixels;
	NSUInteger bitsPerComponent = _info->bitsPerComponent;
	NSUInteger bytesPerPixel = _info->bytesPerPixel;
	CGBitmapInfo bitmapInfo;
	if (_info->isFloat) {
		pixels = [self eightBitPixels];
		bitsPerComponent = 8;
		bytesPerPixel = _info->components;
	}
	if (_info->components == 1) {
		bitmapInfo = kCGImageAlphaNone;
	} else if (_info->isBGRA) {
		bitmapInfo = kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little;
	} else {
		bitmapInfo = kCGImageAlphaPremultipliedLast;
	}
	if (bitsPerComponent == 16) {
		bitmapInfo |= kCGBitmapByteOrder16Little;
	}

	CGColorSpaceRef space = [self newColorSpace];
	CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)pixels);
	CGImageRef image = CGImageCreate(_width, _height, bitsPerComponent, bytesPerPixel * 8,
									 _width * bytesPerPixel, space, bitmapInfo, provider, NULL, true,
									 kCGRenderingIntentDefault);
	CGDataProviderRelease(provider);
	CGColorSpaceRelease(space);
	return image;
}

/*!
	@method		CGImage
	@abstract	Returns the frame drawn as a CGImage, building and caching it on first use.
	@return		The CGImage owned by the frame, or nil when CoreGraphics rejects the layout. */
- (nullable CGImageRef)CGImage
{
	@synchronized (self) {
		if (_image == NULL) {
			_image = [self newCGImage];
		}
		return _image;
	}
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ %p %@>", self.className, self, self.sizeDescription];
}

@end
