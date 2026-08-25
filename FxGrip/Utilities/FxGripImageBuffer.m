//
//  FxGripImageBuffer.m
//  FxGrip
//

#import "FxGripImageBuffer.h"
#import <ImageIO/ImageIO.h>
#import "FxGrip_ARC.h"

#define kFxGripImageBufferCoderVersion	2

static NSString *const kFxGripImageBufferKey_Version		= @"version";
static NSString *const kFxGripImageBufferKey_Width			= @"width";
static NSString *const kFxGripImageBufferKey_Height			= @"height";
static NSString *const kFxGripImageBufferKey_Format			= @"format";
static NSString *const kFxGripImageBufferKey_Compression	= @"compression";
static NSString *const kFxGripImageBufferKey_Quality		= @"quality";
static NSString *const kFxGripImageBufferKey_Length			= @"length";
static NSString *const kFxGripImageBufferKey_Payload		= @"payload";

// Rec.709 luma weights for collapsing color to a Gray target.
static const double kFxGripLumaRed		= 0.2126;
static const double kFxGripLumaGreen	= 0.7152;
static const double kFxGripLumaBlue		= 0.0722;


#pragma mark - Component access

/*! Reads one component as a normalized double: integers map to 0...1, floats pass
	through unclamped. */
static double FxGripReadComponent(const void *component, FxGripComponentType type)
{
	switch (type) {
		case FxGripComponentTypeFloat32:
			return (double)*(const float *)component;
		case FxGripComponentTypeFloat16:
			return (double)*(const __fp16 *)component;
		case FxGripComponentTypeUInt32:
			return (double)*(const uint32_t *)component / (double)UINT32_MAX;
		case FxGripComponentTypeUInt16:
			return (double)*(const uint16_t *)component / (double)UINT16_MAX;
		case FxGripComponentTypeUInt8:
			return (double)*(const uint8_t *)component / (double)UINT8_MAX;
		default:
			return 0.0;
	}
}

/*! Writes one normalized double as a component; integer targets clamp to 0...1. */
static void FxGripWriteComponent(void *component, FxGripComponentType type, double value)
{
	double clamped = value < 0.0 ? 0.0 : (value > 1.0 ? 1.0 : value);
	switch (type) {
		case FxGripComponentTypeFloat32:
			*(float *)component = (float)value;
			break;
		case FxGripComponentTypeFloat16:
			*(__fp16 *)component = (__fp16)value;
			break;
		case FxGripComponentTypeUInt32:
			*(uint32_t *)component = (uint32_t)llround(clamped * (double)UINT32_MAX);
			break;
		case FxGripComponentTypeUInt16:
			*(uint16_t *)component = (uint16_t)lround(clamped * (double)UINT16_MAX);
			break;
		case FxGripComponentTypeUInt8:
			*(uint8_t *)component = (uint8_t)lround(clamped * (double)UINT8_MAX);
			break;
		default:
			break;
	}
}

/*! Decomposes one pixel to canonical RGBA: Gray replicates, missing alpha is opaque. */
static void FxGripReadPixel(const uint8_t *pixel, NSUInteger channels, FxGripComponentType type,
							NSUInteger componentBytes, double rgba[4])
{
	switch (channels) {
		case 1:
			rgba[0] = rgba[1] = rgba[2] = FxGripReadComponent(pixel, type);
			rgba[3] = 1.0;
			break;
		case 2:
			rgba[0] = rgba[1] = rgba[2] = FxGripReadComponent(pixel, type);
			rgba[3] = FxGripReadComponent(pixel + componentBytes, type);
			break;
		case 3:
		case 4:
			rgba[0] = FxGripReadComponent(pixel, type);
			rgba[1] = FxGripReadComponent(pixel + componentBytes, type);
			rgba[2] = FxGripReadComponent(pixel + 2 * componentBytes, type);
			rgba[3] = channels == 4 ? FxGripReadComponent(pixel + 3 * componentBytes, type) : 1.0;
			break;
		default:
			break;
	}
}

/*! Composes one pixel from canonical RGBA: a Gray target takes Rec.709 luminance. */
static void FxGripWritePixel(uint8_t *pixel, NSUInteger channels, FxGripComponentType type,
							 NSUInteger componentBytes, const double rgba[4])
{
	double luma = kFxGripLumaRed * rgba[0] + kFxGripLumaGreen * rgba[1] + kFxGripLumaBlue * rgba[2];
	switch (channels) {
		case 1:
			FxGripWriteComponent(pixel, type, luma);
			break;
		case 2:
			FxGripWriteComponent(pixel, type, luma);
			FxGripWriteComponent(pixel + componentBytes, type, rgba[3]);
			break;
		case 3:
		case 4:
			FxGripWriteComponent(pixel, type, rgba[0]);
			FxGripWriteComponent(pixel + componentBytes, type, rgba[1]);
			FxGripWriteComponent(pixel + 2 * componentBytes, type, rgba[2]);
			if (channels == 4) {
				FxGripWriteComponent(pixel + 3 * componentBytes, type, rgba[3]);
			}
			break;
		default:
			break;
	}
}


#pragma mark - Lossy image codecs

// Every format lossy-encodes: components down-convert to the codec's internal depth
// (JPEG is 8-bit; HEIC carries 16-bit components over its 10/12-bit HEVC internals) and
// alpha always splits into its own plane, so no premultiplication touches the color.
// The payload is a binary-plist envelope: color chunk, optional alpha chunk, depth.

static NSString *const kFxGripLossyEnvelopeKey_Color	= @"c";
static NSString *const kFxGripLossyEnvelopeKey_Alpha	= @"a";
static NSString *const kFxGripLossyEnvelopeKey_Depth	= @"d";

static CFStringRef FxGripLossyCodecType(FxGripCompression compression)
{
	return (__bridge CFStringRef)FxGripCompressionTypeIdentifier(compression);
}

/*! The component depth a codec's container carries: JPEG 8; HEIC and AVIF 8 for 8-bit
	sources and 16 otherwise. */
static NSUInteger FxGripLossyInternalDepth(FxGripCompression compression, FxGripPixelFormat format)
{
	if (compression == FxGripCompressionJPEG) {
		return 8;
	}
	return FxGripPixelFormatComponentType(format) == FxGripComponentTypeUInt8 ? 8 : 16;
}

/*! Encodes one tightly-packed plane (1 or 3 channels at depth 8 or 16) into a container. */
static NSData *FxGripLossyEncodedPlane(NSData *plane, NSUInteger width, NSUInteger height,
									   NSUInteger channels, NSUInteger depth,
									   FxGripCompression compression, float quality)
{
	CGColorSpaceRef colorSpace = channels == 1
		? CGColorSpaceCreateWithName(kCGColorSpaceGenericGrayGamma2_2)
		: CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
	CGBitmapInfo bitmapInfo = (CGBitmapInfo)kCGImageAlphaNone;
	if (depth == 16) {
		bitmapInfo |= kCGBitmapByteOrder16Host;
	}
	NSUInteger rowBytes = width * channels * depth / 8;
	CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)plane);
	CGImageRef image = CGImageCreate(width, height, depth, depth * channels, rowBytes,
									 colorSpace, bitmapInfo, provider, NULL, false,
									 kCGRenderingIntentDefault);
	CGColorSpaceRelease(colorSpace);
	CGDataProviderRelease(provider);
	if (image == NULL) {
		return nil;
	}

	NSMutableData *encoded = [NSMutableData data];
	CGImageDestinationRef destination =
		CGImageDestinationCreateWithData((__bridge CFMutableDataRef)encoded,
										 FxGripLossyCodecType(compression), 1, NULL);
	if (destination == NULL) {
		CGImageRelease(image);
		return nil;
	}
	NSDictionary *properties = @{(__bridge NSString*)kCGImageDestinationLossyCompressionQuality: @(quality)};
	CGImageDestinationAddImage(destination, image, (__bridge CFDictionaryRef)properties);
	BOOL finished = CGImageDestinationFinalize(destination);
	CFRelease(destination);
	CGImageRelease(image);

	return finished && encoded.length > 0 ? encoded : nil;
}

/*! Decodes one container into canonical RGBA components at the given depth. The plane
	carries no alpha, so the premultiplied context is an identity on the color. */
static NSData *FxGripLossyDecodedPlaneRGBA(NSData *container, NSUInteger width, NSUInteger height,
										   NSUInteger depth)
{
	CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)container, NULL);
	if (source == NULL) {
		return nil;
	}
	CGImageRef image = CGImageSourceCreateImageAtIndex(source, 0, NULL);
	CFRelease(source);
	if (image == NULL) {
		return nil;
	}

	NSMutableData *rgba = [NSMutableData dataWithLength:width * height * 4 * depth / 8];
	CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
	CGBitmapInfo bitmapInfo = (CGBitmapInfo)kCGImageAlphaPremultipliedLast;
	if (depth == 16) {
		bitmapInfo |= kCGBitmapByteOrder16Host;
	}
	CGContextRef context = CGBitmapContextCreate(rgba.mutableBytes, width, height, depth,
												 width * 4 * depth / 8, colorSpace, bitmapInfo);
	CGColorSpaceRelease(colorSpace);
	if (context == NULL) {
		CGImageRelease(image);
		return nil;
	}
	CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
	CGContextRelease(context);
	CGImageRelease(image);
	return rgba;
}

/*! Encodes a plane, retrying a refused gray plane as replicated RGB: some encoders
	(AVIF at 16-bit) take no grayscale input, and the canonical-RGBA decode reads either
	shape identically. */
static NSData *FxGripLossyEncodedPlaneAdaptive(NSData *plane, NSUInteger width, NSUInteger height,
											   NSUInteger channels, NSUInteger depth,
											   FxGripCompression compression, float quality)
{
	NSData *encoded = FxGripLossyEncodedPlane(plane, width, height, channels, depth, compression, quality);
	if (encoded != nil || channels != 1) {
		return encoded;
	}
	NSUInteger componentBytes = depth / 8;
	NSUInteger pixelCount = width * height;
	NSMutableData *replicated = [NSMutableData dataWithLength:pixelCount * 3 * componentBytes];
	const uint8_t *source = plane.bytes;
	uint8_t *target = replicated.mutableBytes;
	for (NSUInteger pixel = 0; pixel < pixelCount; pixel++) {
		for (NSUInteger channel = 0; channel < 3; channel++) {
			memcpy(target + (pixel * 3 + channel) * componentBytes,
				   source + pixel * componentBytes,
				   componentBytes);
		}
	}
	return FxGripLossyEncodedPlane(replicated, width, height, 3, depth, compression, quality);
}

/*! Splits the source pixels into a color plane (Gray sources stay 1 channel, color
	sources carry 3) and, for the alpha formats, an alpha plane — both at the codec's
	internal depth. */
static void FxGripLossySplitPlanes(NSData *pixels, NSUInteger width, NSUInteger height,
								   FxGripPixelFormat format, NSUInteger depth,
								   NSData **colorPlane, NSUInteger *colorChannels,
								   NSData **alphaPlane)
{
	NSUInteger sourceChannels = FxGripPixelFormatComponents(format);
	FxGripComponentType sourceType = FxGripPixelFormatComponentType(format);
	NSUInteger sourceComponentBytes = FxGripPixelFormatBytesPerComponent(format);
	FxGripComponentType planeType = depth == 16 ? FxGripComponentTypeUInt16 : FxGripComponentTypeUInt8;
	NSUInteger planeComponentBytes = depth / 8;
	NSUInteger planeChannels = sourceChannels >= 3 ? 3 : 1;
	BOOL hasAlpha = FxGripPixelFormatHasAlpha(format);

	NSUInteger pixelCount = width * height;
	NSMutableData *color = [NSMutableData dataWithLength:pixelCount * planeChannels * planeComponentBytes];
	NSMutableData *alpha = hasAlpha ? [NSMutableData dataWithLength:pixelCount * planeComponentBytes] : nil;
	const uint8_t *sourceBytes = pixels.bytes;
	uint8_t *colorBytes = color.mutableBytes;
	uint8_t *alphaBytes = alpha.mutableBytes;

	for (NSUInteger pixel = 0; pixel < pixelCount; pixel++) {
		double rgba[4];
		FxGripReadPixel(sourceBytes + pixel * sourceChannels * sourceComponentBytes,
						sourceChannels, sourceType, sourceComponentBytes, rgba);
		FxGripWritePixel(colorBytes + pixel * planeChannels * planeComponentBytes,
						 planeChannels, planeType, planeComponentBytes, rgba);
		if (hasAlpha) {
			FxGripWriteComponent(alphaBytes + pixel * planeComponentBytes, planeType, rgba[3]);
		}
	}

	*colorPlane = color;
	*colorChannels = planeChannels;
	*alphaPlane = alpha;
}

/*! Encodes any format: color and alpha planes in separate containers, wrapped in the
	envelope. Nil on any encoder failure, and the caller stores raw. */
static NSData *FxGripLossyEncodedData(NSData *pixels, NSUInteger width, NSUInteger height,
									  FxGripPixelFormat format, FxGripCompression compression,
									  float quality)
{
	NSUInteger depth = FxGripLossyInternalDepth(compression, format);
	NSData *colorPlane = nil;
	NSData *alphaPlane = nil;
	NSUInteger colorChannels = 0;
	FxGripLossySplitPlanes(pixels, width, height, format, depth,
						   &colorPlane, &colorChannels, &alphaPlane);

	NSMutableDictionary *envelope = [NSMutableDictionary dictionaryWithCapacity:3];
	envelope[kFxGripLossyEnvelopeKey_Depth] = @(depth);
	envelope[kFxGripLossyEnvelopeKey_Color] =
		FxGripLossyEncodedPlaneAdaptive(colorPlane, width, height, colorChannels, depth, compression, quality);
	if (envelope[kFxGripLossyEnvelopeKey_Color] == nil) {
		return nil;
	}
	if (alphaPlane != nil) {
		envelope[kFxGripLossyEnvelopeKey_Alpha] =
			FxGripLossyEncodedPlaneAdaptive(alphaPlane, width, height, 1, depth, compression, quality);
		if (envelope[kFxGripLossyEnvelopeKey_Alpha] == nil) {
			return nil;
		}
	}
	return [NSPropertyListSerialization dataWithPropertyList:envelope
													  format:NSPropertyListBinaryFormat_v1_0
													 options:0
													   error:NULL];
}

/*! Decodes the envelope and reassembles the declared format from the planes. */
static NSData *FxGripLossyDecodedData(NSData *payload, NSUInteger width, NSUInteger height,
									  FxGripPixelFormat format)
{
	NSDictionary *envelope = [NSPropertyListSerialization propertyListWithData:payload
																	   options:NSPropertyListImmutable
																		format:NULL
																		 error:NULL];
	if (![envelope isKindOfClass:NSDictionary.class]) {
		return nil;
	}
	NSUInteger depth = ((NSNumber*)envelope[kFxGripLossyEnvelopeKey_Depth]).unsignedIntegerValue;
	NSData *colorContainer = envelope[kFxGripLossyEnvelopeKey_Color];
	NSData *alphaContainer = envelope[kFxGripLossyEnvelopeKey_Alpha];
	if ((depth != 8 && depth != 16) || ![colorContainer isKindOfClass:NSData.class]) {
		return nil;
	}

	NSData *colorRGBA = FxGripLossyDecodedPlaneRGBA(colorContainer, width, height, depth);
	if (colorRGBA == nil) {
		return nil;
	}
	NSData *alphaRGBA = nil;
	if ([alphaContainer isKindOfClass:NSData.class]) {
		alphaRGBA = FxGripLossyDecodedPlaneRGBA(alphaContainer, width, height, depth);
		if (alphaRGBA == nil) {
			return nil;
		}
	}

	NSUInteger channels = FxGripPixelFormatComponents(format);
	FxGripComponentType type = FxGripPixelFormatComponentType(format);
	NSUInteger componentBytes = FxGripPixelFormatBytesPerComponent(format);
	FxGripComponentType planeType = depth == 16 ? FxGripComponentTypeUInt16 : FxGripComponentTypeUInt8;
	NSUInteger planeComponentBytes = depth / 8;

	NSMutableData *pixels = [NSMutableData dataWithLength:width * height * channels * componentBytes];
	const uint8_t *colorBytes = colorRGBA.bytes;
	const uint8_t *alphaBytes = alphaRGBA.bytes;
	uint8_t *targetBytes = pixels.mutableBytes;

	NSUInteger pixelCount = width * height;
	for (NSUInteger pixel = 0; pixel < pixelCount; pixel++) {
		const uint8_t *colorPixel = colorBytes + pixel * 4 * planeComponentBytes;
		double rgba[4];
		rgba[0] = FxGripReadComponent(colorPixel, planeType);
		rgba[1] = FxGripReadComponent(colorPixel + planeComponentBytes, planeType);
		rgba[2] = FxGripReadComponent(colorPixel + 2 * planeComponentBytes, planeType);
		rgba[3] = alphaBytes != NULL
			? FxGripReadComponent(alphaBytes + pixel * 4 * planeComponentBytes, planeType)
			: 1.0;
		FxGripWritePixel(targetBytes + pixel * channels * componentBytes,
						 channels, type, componentBytes, rgba);
	}
	return pixels;
}


@implementation FxGripImageBuffer
{
	NSData *_payload;
}

+ (BOOL)supportsSecureCoding
{
	return YES;
}

- (void)dealloc
{
	NARC_RELEASE(_payload);
	SUPER_DEALLOC();
}

/*! Stores tightly-packed pixels, compressing when the codec applies and shrinks them. */
- (nullable instancetype)initWithPixelData:(NSData *)pixels
									 width:(NSUInteger)width
									height:(NSUInteger)height
									format:(FxGripPixelFormat)format
							   compression:(FxGripCompression)compression
								   quality:(float)quality
{
	NSUInteger bytesPerPixel = FxGripPixelFormatBytesPerPixel(format);
	if (bytesPerPixel == 0 || width == 0 || height == 0
		|| pixels.length != width * height * bytesPerPixel) {
		NARC_RELEASE_RAW(self);
		return nil;
	}
	self = [super init];
	if (self != nil) {
		_width = width;
		_height = height;
		_format = format;
		_quality = quality < 0.f ? 0.f : (quality > 1.f ? 1.f : quality);
		_uncompressedLength = pixels.length;

		NSData *compressed = nil;
		if (FxGripCompressionIsLossy(compression)) {
			compressed = FxGripLossyEncodedData(pixels, width, height, format, compression, _quality);
		} else {
			compressed = FxGripCompressedData(pixels, compression);
		}
		if (compressed != nil) {
			_compression = compression;
			_payload = NARC_RETAIN(compressed);
		} else {
			_compression = FxGripCompressionNone;
			_payload = [pixels copy];
		}
	}
	return self;
}

- (nullable instancetype)initWithBytes:(const void *)pixels
							  rowBytes:(NSUInteger)rowBytes
								 width:(NSUInteger)width
								height:(NSUInteger)height
								format:(FxGripPixelFormat)format
						   compression:(FxGripCompression)compression
							   quality:(float)quality
{
	NSUInteger tightRowBytes = width * FxGripPixelFormatBytesPerPixel(format);
	if (pixels == NULL || tightRowBytes == 0 || rowBytes < tightRowBytes) {
		NARC_RELEASE_RAW(self);
		return nil;
	}
	NSMutableData *tight = [NSMutableData dataWithLength:tightRowBytes * height];
	for (NSUInteger row = 0; row < height; row++) {
		memcpy((uint8_t *)tight.mutableBytes + row * tightRowBytes,
			   (const uint8_t *)pixels + row * rowBytes,
			   tightRowBytes);
	}
	return [self initWithPixelData:tight width:width height:height format:format
					   compression:compression quality:quality];
}

- (nullable instancetype)initWithBytes:(const void *)pixels
							  rowBytes:(NSUInteger)rowBytes
								 width:(NSUInteger)width
								height:(NSUInteger)height
								format:(FxGripPixelFormat)format
						   compression:(FxGripCompression)compression
{
	return [self initWithBytes:pixels rowBytes:rowBytes width:width height:height
						format:format compression:compression
					   quality:kFxGripImageBufferDefaultQuality];
}

- (NSUInteger)rowBytes
{
	return _width * FxGripPixelFormatBytesPerPixel(_format);
}

- (nonnull NSData *)compressedData
{
	return _payload;
}

- (nullable NSData *)pixelData
{
	if (FxGripCompressionIsLossy(_compression)) {
		NSData *pixels = FxGripLossyDecodedData(_payload, _width, _height, _format);
		return pixels.length == _uncompressedLength ? pixels : nil;
	}
	return FxGripDecompressedData(_payload, _compression, _uncompressedLength);
}


#pragma mark Conversion

- (nullable FxGripImageBuffer *)bufferByConvertingToFormat:(FxGripPixelFormat)format
											   compression:(FxGripCompression)compression
{
	return [self bufferByConvertingToFormat:format compression:compression
									quality:kFxGripImageBufferDefaultQuality];
}

- (nullable FxGripImageBuffer *)bufferByConvertingToFormat:(FxGripPixelFormat)format
											   compression:(FxGripCompression)compression
												   quality:(float)quality
{
	NSUInteger targetPixelBytes = FxGripPixelFormatBytesPerPixel(format);
	NSData *source = self.pixelData;
	if (targetPixelBytes == 0 || source == nil) {
		return nil;
	}
	if (format == _format) {
		return NARC_AUTORELEASE([[FxGripImageBuffer alloc] initWithPixelData:source
																	   width:_width
																	  height:_height
																	  format:format
																 compression:compression
																	 quality:quality]);
	}

	NSUInteger sourceChannels = FxGripPixelFormatComponents(_format);
	FxGripComponentType sourceType = FxGripPixelFormatComponentType(_format);
	NSUInteger sourceComponentBytes = FxGripPixelFormatBytesPerComponent(_format);
	NSUInteger targetChannels = FxGripPixelFormatComponents(format);
	FxGripComponentType targetType = FxGripPixelFormatComponentType(format);
	NSUInteger targetComponentBytes = FxGripPixelFormatBytesPerComponent(format);

	NSMutableData *converted = [NSMutableData dataWithLength:_width * _height * targetPixelBytes];
	const uint8_t *sourceBytes = source.bytes;
	uint8_t *targetBytes = converted.mutableBytes;

	NSUInteger pixelCount = _width * _height;
	for (NSUInteger pixel = 0; pixel < pixelCount; pixel++) {
		double rgba[4];
		FxGripReadPixel(sourceBytes + pixel * sourceChannels * sourceComponentBytes,
						sourceChannels, sourceType, sourceComponentBytes, rgba);
		FxGripWritePixel(targetBytes + pixel * targetChannels * targetComponentBytes,
						 targetChannels, targetType, targetComponentBytes, rgba);
	}

	return NARC_AUTORELEASE([[FxGripImageBuffer alloc] initWithPixelData:converted
																   width:_width
																  height:_height
																  format:format
															 compression:compression
																 quality:quality]);
}


#pragma mark Metal

static FxGripPixelFormat FxGripFormatForMTLPixelFormat(MTLPixelFormat format)
{
	switch (format) {
		case MTLPixelFormatR8Unorm:		return FxGripPixelFormatGray8U;
		case MTLPixelFormatR16Unorm:	return FxGripPixelFormatGray16U;
		case MTLPixelFormatR32Uint:		return FxGripPixelFormatGray32U;
		case MTLPixelFormatR16Float:	return FxGripPixelFormatGray16F;
		case MTLPixelFormatR32Float:	return FxGripPixelFormatGray32F;
		case MTLPixelFormatRG8Unorm:	return FxGripPixelFormatGrayAlpha8U;
		case MTLPixelFormatRG16Unorm:	return FxGripPixelFormatGrayAlpha16U;
		case MTLPixelFormatRG32Uint:	return FxGripPixelFormatGrayAlpha32U;
		case MTLPixelFormatRG16Float:	return FxGripPixelFormatGrayAlpha16F;
		case MTLPixelFormatRG32Float:	return FxGripPixelFormatGrayAlpha32F;
		case MTLPixelFormatRGBA8Unorm:	return FxGripPixelFormatRGBA8U;
		case MTLPixelFormatRGBA16Unorm:	return FxGripPixelFormatRGBA16U;
		case MTLPixelFormatRGBA32Uint:	return FxGripPixelFormatRGBA32U;
		case MTLPixelFormatRGBA16Float:	return FxGripPixelFormatRGBA16F;
		case MTLPixelFormatRGBA32Float:	return FxGripPixelFormatRGBA32F;
		default:						return FxGripPixelFormatInvalid;
	}
}

static MTLPixelFormat FxGripMTLPixelFormatForFormat(FxGripPixelFormat format)
{
	switch (format) {
		case FxGripPixelFormatGray8U:		return MTLPixelFormatR8Unorm;
		case FxGripPixelFormatGray16U:		return MTLPixelFormatR16Unorm;
		case FxGripPixelFormatGray32U:		return MTLPixelFormatR32Uint;
		case FxGripPixelFormatGray16F:		return MTLPixelFormatR16Float;
		case FxGripPixelFormatGray32F:		return MTLPixelFormatR32Float;
		case FxGripPixelFormatGrayAlpha8U:	return MTLPixelFormatRG8Unorm;
		case FxGripPixelFormatGrayAlpha16U:	return MTLPixelFormatRG16Unorm;
		case FxGripPixelFormatGrayAlpha32U:	return MTLPixelFormatRG32Uint;
		case FxGripPixelFormatGrayAlpha16F:	return MTLPixelFormatRG16Float;
		case FxGripPixelFormatGrayAlpha32F:	return MTLPixelFormatRG32Float;
		case FxGripPixelFormatRGBA8U:		return MTLPixelFormatRGBA8Unorm;
		case FxGripPixelFormatRGBA16U:		return MTLPixelFormatRGBA16Unorm;
		case FxGripPixelFormatRGBA32U:		return MTLPixelFormatRGBA32Uint;
		case FxGripPixelFormatRGBA16F:		return MTLPixelFormatRGBA16Float;
		case FxGripPixelFormatRGBA32F:		return MTLPixelFormatRGBA32Float;
		default:							return MTLPixelFormatInvalid;
	}
}

- (nullable id<MTLTexture>)newTextureWithDevice:(nonnull id<MTLDevice>)device
{
	MTLPixelFormat metalFormat = FxGripMTLPixelFormatForFormat(_format);
	NSData *pixels = self.pixelData;
	if (metalFormat == MTLPixelFormatInvalid || pixels == nil || device == nil) {
		return nil;
	}
	MTLTextureDescriptor *descriptor =
		[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:metalFormat
														   width:_width
														  height:_height
													   mipmapped:NO];
	descriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
	id<MTLTexture> texture = [device newTextureWithDescriptor:descriptor];
	[texture replaceRegion:MTLRegionMake2D(0, 0, _width, _height)
			   mipmapLevel:0
				 withBytes:pixels.bytes
			   bytesPerRow:self.rowBytes];
	return texture;
}

+ (nullable instancetype)bufferWithTexture:(nonnull id<MTLTexture>)texture
							   compression:(FxGripCompression)compression
{
	FxGripPixelFormat format = FxGripFormatForMTLPixelFormat(texture.pixelFormat);
	if (format == FxGripPixelFormatInvalid) {
		return nil;
	}
	NSUInteger rowBytes = texture.width * FxGripPixelFormatBytesPerPixel(format);
	NSMutableData *pixels = [NSMutableData dataWithLength:rowBytes * texture.height];
	[texture getBytes:pixels.mutableBytes
		  bytesPerRow:rowBytes
		   fromRegion:MTLRegionMake2D(0, 0, texture.width, texture.height)
		  mipmapLevel:0];
	return NARC_AUTORELEASE([[self alloc] initWithPixelData:pixels
													  width:texture.width
													 height:texture.height
													 format:format
												compression:compression
													quality:kFxGripImageBufferDefaultQuality]);
}


#pragma mark Previews

- (nullable NSBitmapImageRep *)bitmapRep
{
	FxGripImageBuffer *preview = self;
	if (_format != FxGripPixelFormatRGBA8U) {
		preview = [self bufferByConvertingToFormat:FxGripPixelFormatRGBA8U
									   compression:FxGripCompressionNone];
	}
	NSData *pixels = preview.pixelData;
	if (pixels == nil) {
		return nil;
	}
	NSBitmapImageRep *rep = [[NSBitmapImageRep alloc]
		initWithBitmapDataPlanes:NULL
					  pixelsWide:(NSInteger)preview.width
					  pixelsHigh:(NSInteger)preview.height
				   bitsPerSample:8
				 samplesPerPixel:4
						hasAlpha:YES
						isPlanar:NO
				  colorSpaceName:NSCalibratedRGBColorSpace
					 bytesPerRow:(NSInteger)preview.rowBytes
					bitsPerPixel:32];
	if (rep == nil) {
		return nil;
	}
	memcpy(rep.bitmapData, pixels.bytes, pixels.length);
	return NARC_AUTORELEASE(rep);
}

- (nullable NSImage *)image
{
	NSBitmapImageRep *rep = self.bitmapRep;
	if (rep == nil) {
		return nil;
	}
	NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(_width, _height)];
	[image addRepresentation:rep];
	return NARC_AUTORELEASE(image);
}


#pragma mark Identity

- (BOOL)isEqual:(id)object
{
	if (self == object) {
		return YES;
	}
	if (![object isKindOfClass:FxGripImageBuffer.class]) {
		return NO;
	}
	FxGripImageBuffer *rhs = object;
	if (_width != rhs.width || _height != rhs.height || _format != rhs.format) {
		return NO;
	}
	// Codecs may differ while the pixels agree; lossy payloads compare as decoded.
	return [self.pixelData isEqualToData:rhs.pixelData];
}

- (NSUInteger)hash
{
	return _width ^ (_height << 16) ^ ((NSUInteger)_format << 32) ^ _uncompressedLength;
}

- (id)copyWithZone:(NSZone *)zone
{
	// Immutable.
	return NARC_RETAIN(self);
}


#pragma mark NSSecureCoding

- (void)encodeWithCoder:(nonnull NSCoder *)coder
{
	[coder encodeInteger:kFxGripImageBufferCoderVersion forKey:kFxGripImageBufferKey_Version];
	[coder encodeInteger:(NSInteger)_width forKey:kFxGripImageBufferKey_Width];
	[coder encodeInteger:(NSInteger)_height forKey:kFxGripImageBufferKey_Height];
	[coder encodeInteger:_format forKey:kFxGripImageBufferKey_Format];
	[coder encodeInteger:_compression forKey:kFxGripImageBufferKey_Compression];
	[coder encodeFloat:_quality forKey:kFxGripImageBufferKey_Quality];
	[coder encodeInteger:(NSInteger)_uncompressedLength forKey:kFxGripImageBufferKey_Length];
	[coder encodeObject:_payload forKey:kFxGripImageBufferKey_Payload];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder
{
	self = [super init];
	if (self != nil) {
		_width = (NSUInteger)[coder decodeIntegerForKey:kFxGripImageBufferKey_Width];
		_height = (NSUInteger)[coder decodeIntegerForKey:kFxGripImageBufferKey_Height];
		_format = [coder decodeIntegerForKey:kFxGripImageBufferKey_Format];
		_compression = [coder decodeIntegerForKey:kFxGripImageBufferKey_Compression];
		_quality = [coder decodeFloatForKey:kFxGripImageBufferKey_Quality];
		_uncompressedLength = (NSUInteger)[coder decodeIntegerForKey:kFxGripImageBufferKey_Length];
		_payload = NARC_RETAIN([coder decodeObjectOfClass:NSData.class forKey:kFxGripImageBufferKey_Payload]);

		if (_payload == nil || FxGripPixelFormatBytesPerPixel(_format) == 0
			|| _uncompressedLength != _width * _height * FxGripPixelFormatBytesPerPixel(_format)) {
			NARC_RELEASE_RAW(self);
			return nil;
		}
	}
	return self;
}

@end
