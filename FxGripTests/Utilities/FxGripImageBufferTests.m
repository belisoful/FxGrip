/*!
	@file       FxGripImageBufferTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripImageBufferTests
	@abstract   Unit tests for the compressed image buffer covering repacking, storage codecs, conversion, coding, identity, Metal and preview bridges, and lossy codecs.
	@discussion Introduced in FxGrip 0.1.0. The tests repack strided source rows tightly, store pixels under each codec with an uncompressed fallback, and convert between the channel-aware formats. They assert the keyed secure-coding round trip, pixel equality across codecs, the Metal and NSBitmapImageRep bridges, and the lossy image codecs with their quality setting. Lossy tests assert a component tolerance and a payload-size relation rather than exact bytes, and Metal tests skip when no device is present.
*/

#import <XCTest/XCTest.h>
#import <dlfcn.h>
#import <FxGrip/FxGripImageBuffer.h>
#import <FxGrip/FxGripImageCompression.h>

// The test bundle links only FxGrip and XCTest. Metal comes in with the framework, so its
// entry points are reached through the loaded images rather than a link-time reference.
typedef void *(*FxGripImageBufferTestCreateDevice)(void);

static NSString *const kImageBufferCoderKey_Width = @"width";
static NSString *const kImageBufferCoderKey_Height = @"height";
static NSString *const kImageBufferCoderKey_Format = @"format";
static NSString *const kImageBufferCoderKey_Compression = @"compression";
static NSString *const kImageBufferCoderKey_Length = @"length";
static NSString *const kImageBufferCoderKey_Payload = @"payload";
static NSString *const kImageBufferCoderKey_Version = @"version";

static const FxGripPixelFormat kImageBufferTestFormats[] = {
	FxGripPixelFormatGray8U,
	FxGripPixelFormatGray16U,
	FxGripPixelFormatGray32U,
	FxGripPixelFormatGray16F,
	FxGripPixelFormatGray32F,
	FxGripPixelFormatGrayAlpha8U,
	FxGripPixelFormatGrayAlpha16U,
	FxGripPixelFormatGrayAlpha32U,
	FxGripPixelFormatGrayAlpha16F,
	FxGripPixelFormatGrayAlpha32F,
	FxGripPixelFormatRGB8U,
	FxGripPixelFormatRGB16U,
	FxGripPixelFormatRGB32U,
	FxGripPixelFormatRGB16F,
	FxGripPixelFormatRGB32F,
	FxGripPixelFormatRGBA8U,
	FxGripPixelFormatRGBA16U,
	FxGripPixelFormatRGBA32U,
	FxGripPixelFormatRGBA16F,
	FxGripPixelFormatRGBA32F
};
static const NSUInteger kImageBufferTestFormatCount = 20;

static const FxGripPixelFormat kImageBufferTestGrayFormats[] = {
	FxGripPixelFormatGray8U,
	FxGripPixelFormatGray16U,
	FxGripPixelFormatGray32U,
	FxGripPixelFormatGray16F,
	FxGripPixelFormatGray32F
};
static const NSUInteger kImageBufferTestGrayFormatCount = 5;

static const FxGripPixelFormat kImageBufferTestGrayAlphaFormats[] = {
	FxGripPixelFormatGrayAlpha8U,
	FxGripPixelFormatGrayAlpha16U,
	FxGripPixelFormatGrayAlpha32U,
	FxGripPixelFormatGrayAlpha16F,
	FxGripPixelFormatGrayAlpha32F
};
static const NSUInteger kImageBufferTestGrayAlphaFormatCount = 5;

/*!
	Encodes chosen fields under the buffer's class name, so the unarchiver runs the buffer's
	initWithCoder: over an archive the buffer itself would never produce.
*/
@interface FxGripImageBufferTestArchiveStub : NSObject <NSSecureCoding>
@property (nonatomic, strong) NSDictionary<NSString *, id> *integerFields;
@property (nonatomic, strong) NSData *payload;
@end

@implementation FxGripImageBufferTestArchiveStub

+ (BOOL)supportsSecureCoding
{
	return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	for (NSString *key in self.integerFields) {
		[coder encodeInteger:((NSNumber *)self.integerFields[key]).integerValue forKey:key];
	}
	if (self.payload != nil) {
		[coder encodeObject:self.payload forKey:kImageBufferCoderKey_Payload];
	}
}

// The archiver validates that an encodable class decodes securely, so the stub declares a
// decoder it never runs; the substituted class name is what the unarchiver instantiates.
- (instancetype)initWithCoder:(NSCoder *)coder
{
	return [super init];
}

@end


@interface FxGripImageBufferTests : XCTestCase
@end

@implementation FxGripImageBufferTests

#pragma mark Fixtures

/*! A constant-byte payload of the exact tight size; every codec shrinks it. */
- (NSData *)compressiblePixelsForWidth:(NSUInteger)width height:(NSUInteger)height format:(FxGripPixelFormat)format
{
	NSMutableData *pixels = [NSMutableData dataWithLength:width * height * FxGripPixelFormatBytesPerPixel(format)];
	memset(pixels.mutableBytes, 0x40, pixels.length);
	return pixels;
}

/*! A deterministic pseudo-random payload of the exact tight size; no codec shrinks it. */
- (NSData *)incompressiblePixelsForWidth:(NSUInteger)width height:(NSUInteger)height format:(FxGripPixelFormat)format
{
	NSUInteger length = width * height * FxGripPixelFormatBytesPerPixel(format);
	NSMutableData *pixels = [NSMutableData dataWithLength:length];
	uint8_t *bytes = pixels.mutableBytes;
	uint32_t state = 0x2545F491u;
	for (NSUInteger index = 0; index < length; index++) {
		state = state * 1664525u + 1013904223u;
		bytes[index] = (uint8_t)(state >> 24);
	}
	return pixels;
}

- (FxGripImageBuffer *)bufferWithPixels:(NSData *)pixels
								  width:(NSUInteger)width
								 height:(NSUInteger)height
								 format:(FxGripPixelFormat)format
							compression:(FxGripCompression)compression
{
	return [FxGripImageBuffer.alloc initWithBytes:pixels.bytes
										 rowBytes:width * FxGripPixelFormatBytesPerPixel(format)
											width:width
										   height:height
										   format:format
									  compression:compression];
}

/*! A smooth two-axis gradient in 8-bit channels; a lossy codec reproduces it closely. Alpha
	is opaque, so a premultiplied decode returns the color channels unscaled. */
- (NSData *)gradientPixelsForWidth:(NSUInteger)width height:(NSUInteger)height format:(FxGripPixelFormat)format
{
	NSUInteger channels = FxGripPixelFormatComponents(format);
	NSMutableData *pixels = [NSMutableData dataWithLength:width * height * channels];
	uint8_t *bytes = pixels.mutableBytes;
	for (NSUInteger row = 0; row < height; row++) {
		for (NSUInteger column = 0; column < width; column++) {
			uint8_t red = (uint8_t)(40 + (column * 180) / width);
			uint8_t green = (uint8_t)(50 + (row * 160) / height);
			uint8_t blue = (uint8_t)(60 + ((column + row) * 140) / (width + height));
			uint8_t *pixel = bytes + (row * width + column) * channels;
			if (channels >= 3) {
				pixel[0] = red;
				pixel[1] = green;
				pixel[2] = blue;
			} else {
				pixel[0] = (uint8_t)(((NSUInteger)red + green + blue) / 3);
			}
			if (FxGripPixelFormatHasAlpha(format)) {
				pixel[channels - 1] = 255;
			}
		}
	}
	return pixels;
}

/*! The gradient carrying a deterministic ripple in its color channels; a lossy codec spends
	more bytes on the detail, so quality changes the payload size. */
- (NSData *)detailedPixelsForWidth:(NSUInteger)width height:(NSUInteger)height format:(FxGripPixelFormat)format
{
	NSMutableData *pixels = [[self gradientPixelsForWidth:width height:height format:format] mutableCopy];
	NSUInteger channels = FxGripPixelFormatComponents(format);
	NSUInteger colorChannels = FxGripPixelFormatHasAlpha(format) ? channels - 1 : channels;
	uint8_t *bytes = pixels.mutableBytes;
	uint32_t state = 0x9E3779B9u;
	for (NSUInteger pixel = 0; pixel < width * height; pixel++) {
		for (NSUInteger channel = 0; channel < colorChannels; channel++) {
			state = state * 1664525u + 1013904223u;
			NSInteger ripple = (NSInteger)((state >> 24) & 0x3Fu) - 32;
			NSInteger value = (NSInteger)bytes[pixel * channels + channel] + ripple;
			bytes[pixel * channels + channel] = (uint8_t)(value < 0 ? 0 : (value > 255 ? 255 : value));
		}
	}
	return pixels;
}

/*! Finite single-precision components from a deterministic ramp. */
- (NSData *)floatPixelsForWidth:(NSUInteger)width height:(NSUInteger)height format:(FxGripPixelFormat)format
{
	NSUInteger count = width * height * FxGripPixelFormatComponents(format);
	NSMutableData *pixels = [NSMutableData dataWithLength:count * sizeof(float)];
	float *values = pixels.mutableBytes;
	for (NSUInteger index = 0; index < count; index++) {
		values[index] = (float)index * 0.125f - 4.0f;
	}
	return pixels;
}

/*! Half-precision components drawn from the normal range [1, 2): every pattern is finite, so
	a texture round trip compares bit for bit. */
- (NSData *)halfFloatPixelsForWidth:(NSUInteger)width height:(NSUInteger)height format:(FxGripPixelFormat)format
{
	NSUInteger count = width * height * FxGripPixelFormatComponents(format);
	NSMutableData *pixels = [NSMutableData dataWithLength:count * sizeof(uint16_t)];
	uint16_t *values = pixels.mutableBytes;
	for (NSUInteger index = 0; index < count; index++) {
		values[index] = (uint16_t)(0x3C00u | ((index * 37u) & 0x03FFu));
	}
	return pixels;
}

/*! The largest absolute difference between two 8-bit payloads; NSUIntegerMax when their
	lengths disagree, so a length mismatch fails any tolerance. */
- (NSUInteger)largestByteDifferenceBetween:(NSData *)lhs and:(NSData *)rhs
{
	if (lhs.length == 0 || lhs.length != rhs.length) {
		return NSUIntegerMax;
	}
	const uint8_t *left = lhs.bytes;
	const uint8_t *right = rhs.bytes;
	NSUInteger largest = 0;
	for (NSUInteger index = 0; index < lhs.length; index++) {
		NSUInteger difference = left[index] > right[index]
			? (NSUInteger)(left[index] - right[index])
			: (NSUInteger)(right[index] - left[index]);
		if (difference > largest) {
			largest = difference;
		}
	}
	return largest;
}

- (FxGripImageBuffer *)bufferWithPixels:(NSData *)pixels
								  width:(NSUInteger)width
								 height:(NSUInteger)height
								 format:(FxGripPixelFormat)format
							compression:(FxGripCompression)compression
								quality:(float)quality
{
	return [FxGripImageBuffer.alloc initWithBytes:pixels.bytes
										 rowBytes:width * FxGripPixelFormatBytesPerPixel(format)
											width:width
										   height:height
										   format:format
									  compression:compression
										  quality:quality];
}

- (FxGripImageBuffer *)bufferWithFloats:(const float *)components
								  count:(NSUInteger)count
								 format:(FxGripPixelFormat)format
{
	NSData *pixels = [NSData dataWithBytes:components length:count * sizeof(float)];
	return [self bufferWithPixels:pixels
							width:count / FxGripPixelFormatComponents(format)
						   height:1
						   format:format
					  compression:FxGripCompressionNone];
}

- (NSData *)archivedBuffer:(FxGripImageBuffer *)buffer
{
	return [NSKeyedArchiver archivedDataWithRootObject:buffer requiringSecureCoding:YES error:NULL];
}

- (FxGripImageBuffer *)unarchivedBufferFromData:(NSData *)data
{
	return [NSKeyedUnarchiver unarchivedObjectOfClass:FxGripImageBuffer.class fromData:data error:NULL];
}

/*! An archive carrying the given coder fields under the buffer's class name. */
- (NSData *)archiveWithIntegerFields:(NSDictionary<NSString *, NSNumber *> *)fields payload:(NSData *)payload
{
	FxGripImageBufferTestArchiveStub *stub = [FxGripImageBufferTestArchiveStub.alloc init];
	stub.integerFields = fields;
	stub.payload = payload;

	NSKeyedArchiver *archiver = [NSKeyedArchiver.alloc initRequiringSecureCoding:YES];
	[archiver setClassName:NSStringFromClass(FxGripImageBuffer.class) forClass:FxGripImageBufferTestArchiveStub.class];
	[archiver encodeObject:stub forKey:NSKeyedArchiveRootObjectKey];
	[archiver finishEncoding];
	return archiver.encodedData;
}

#pragma mark Initialization

/*! @abstract Initialization repacks strided source rows into tightly packed pixel data. */
- (void)testInitRepacksStridedRowsTightly
{
	const NSUInteger width = 4;
	const NSUInteger height = 3;
	const NSUInteger tightRowBytes = width * FxGripPixelFormatBytesPerPixel(FxGripPixelFormatRGBA8U);
	const NSUInteger sourceRowBytes = tightRowBytes + 13;

	NSMutableData *strided = [NSMutableData dataWithLength:sourceRowBytes * height];
	memset(strided.mutableBytes, 0xAB, strided.length);
	NSMutableData *expected = [NSMutableData dataWithLength:tightRowBytes * height];
	for (NSUInteger row = 0; row < height; row++) {
		for (NSUInteger byte = 0; byte < tightRowBytes; byte++) {
			uint8_t value = (uint8_t)(row * 100 + byte);
			((uint8_t *)strided.mutableBytes)[row * sourceRowBytes + byte] = value;
			((uint8_t *)expected.mutableBytes)[row * tightRowBytes + byte] = value;
		}
	}

	FxGripImageBuffer *buffer = [FxGripImageBuffer.alloc initWithBytes:strided.bytes
															 rowBytes:sourceRowBytes
																width:width
															   height:height
															   format:FxGripPixelFormatRGBA8U
														  compression:FxGripCompressionNone];

	XCTAssertEqualObjects(buffer.pixelData, expected);
}

/*! @abstract Initialization drops the per-row padding bytes and keeps only the pixel bytes. */
- (void)testInitDropsTheRowPaddingBytes
{
	const NSUInteger width = 4;
	const NSUInteger height = 3;
	const NSUInteger tightRowBytes = width * FxGripPixelFormatBytesPerPixel(FxGripPixelFormatRGBA8U);

	NSMutableData *strided = [NSMutableData dataWithLength:(tightRowBytes + 8) * height];
	memset(strided.mutableBytes, 0xAB, strided.length);
	for (NSUInteger row = 0; row < height; row++) {
		memset((uint8_t *)strided.mutableBytes + row * (tightRowBytes + 8), 0x11, tightRowBytes);
	}

	FxGripImageBuffer *buffer = [FxGripImageBuffer.alloc initWithBytes:strided.bytes
															 rowBytes:tightRowBytes + 8
																width:width
															   height:height
															   format:FxGripPixelFormatRGBA8U
														  compression:FxGripCompressionNone];
	NSData *pixels = buffer.pixelData;

	XCTAssertEqual(pixels.length, tightRowBytes * height);
	const uint8_t *bytes = pixels.bytes;
	for (NSUInteger index = 0; index < pixels.length; index++) {
		XCTAssertEqual(bytes[index], 0x11, @"padding byte survived at %lu", (unsigned long)index);
	}
}

/*! @abstract The buffer reports the width, height, format, tight row bytes, and uncompressed length. */
- (void)testInitReportsTheTightRowBytesAndLength
{
	FxGripImageBuffer *buffer = [self bufferWithPixels:[self compressiblePixelsForWidth:5 height:4 format:FxGripPixelFormatRGB16U]
												 width:5
												height:4
												format:FxGripPixelFormatRGB16U
										   compression:FxGripCompressionNone];

	XCTAssertEqual(buffer.width, 5u);
	XCTAssertEqual(buffer.height, 4u);
	XCTAssertEqual(buffer.format, FxGripPixelFormatRGB16U);
	XCTAssertEqual(buffer.rowBytes, 5u * 6u);
	XCTAssertEqual(buffer.uncompressedLength, 5u * 4u * 6u);
}

/*! @abstract Initialization returns nil for an invalid pixel format. */
- (void)testInitRejectsAnInvalidFormat
{
	uint8_t pixels[64] = {0};

	XCTAssertNil([FxGripImageBuffer.alloc initWithBytes:pixels
											   rowBytes:16
												  width:4
												 height:4
												 format:FxGripPixelFormatInvalid
											compression:FxGripCompressionNone]);
}

/*! @abstract Initialization returns nil for a zero width. */
- (void)testInitRejectsAZeroWidth
{
	uint8_t pixels[64] = {0};

	XCTAssertNil([FxGripImageBuffer.alloc initWithBytes:pixels
											   rowBytes:16
												  width:0
												 height:4
												 format:FxGripPixelFormatRGBA8U
											compression:FxGripCompressionNone]);
}

/*! @abstract Initialization returns nil for a zero height. */
- (void)testInitRejectsAZeroHeight
{
	uint8_t pixels[64] = {0};

	XCTAssertNil([FxGripImageBuffer.alloc initWithBytes:pixels
											   rowBytes:16
												  width:4
												 height:0
												 format:FxGripPixelFormatRGBA8U
											compression:FxGripCompressionNone]);
}

/*! @abstract Initialization returns nil when the source stride is narrower than one tight row. */
- (void)testInitRejectsAStrideNarrowerThanARow
{
	uint8_t pixels[64] = {0};

	XCTAssertNil([FxGripImageBuffer.alloc initWithBytes:pixels
											   rowBytes:15
												  width:4
												 height:4
												 format:FxGripPixelFormatRGBA8U
											compression:FxGripCompressionNone]);
}

/*! @abstract Initialization returns nil for a NULL bytes pointer. */
- (void)testInitRejectsNullBytes
{
	const void *pixels = NULL;

	XCTAssertNil([FxGripImageBuffer.alloc initWithBytes:pixels
											   rowBytes:16
												  width:4
												 height:4
												 format:FxGripPixelFormatRGBA8U
											compression:FxGripCompressionNone]);
}

#pragma mark Storage

/*! @abstract Compressible pixels store under the requested codec, shrink below the uncompressed length, and decompress back to the original. */
- (void)testCompressiblePixelsStoreWithTheRequestedCodec
{
	NSData *pixels = [self compressiblePixelsForWidth:64 height:64 format:FxGripPixelFormatRGBA8U];

	FxGripImageBuffer *buffer = [self bufferWithPixels:pixels width:64 height:64
											   format:FxGripPixelFormatRGBA8U
										  compression:FxGripCompressionLZFSE];

	XCTAssertEqual(buffer.compression, FxGripCompressionLZFSE);
	XCTAssertLessThan(buffer.compressedData.length, buffer.uncompressedLength);
	XCTAssertEqualObjects(buffer.pixelData, pixels);
}

/*! @abstract Each lossless codec stores compressible pixels under itself and decompresses back to the original. */
- (void)testEachCodecStoresCompressiblePixelsUnderItself
{
	const FxGripCompression codecs[] = {FxGripCompressionLZFSE, FxGripCompressionLZ4,
										FxGripCompressionZlib, FxGripCompressionLZMA};
	NSData *pixels = [self compressiblePixelsForWidth:64 height:64 format:FxGripPixelFormatRGBA8U];

	for (NSUInteger index = 0; index < 4; index++) {
		FxGripImageBuffer *buffer = [self bufferWithPixels:pixels width:64 height:64
												   format:FxGripPixelFormatRGBA8U
											  compression:codecs[index]];

		XCTAssertEqual(buffer.compression, codecs[index]);
		XCTAssertEqualObjects(buffer.pixelData, pixels, @"codec %ld", (long)codecs[index]);
	}
}

/*! @abstract Incompressible pixels fall back to uncompressed storage while still reading back exactly. */
- (void)testIncompressiblePixelsFallBackToUncompressedStorage
{
	NSData *pixels = [self incompressiblePixelsForWidth:8 height:8 format:FxGripPixelFormatRGBA8U];

	FxGripImageBuffer *buffer = [self bufferWithPixels:pixels width:8 height:8
											   format:FxGripPixelFormatRGBA8U
										  compression:FxGripCompressionLZFSE];

	XCTAssertEqual(buffer.compression, FxGripCompressionNone);
	XCTAssertEqual(buffer.compressedData.length, buffer.uncompressedLength);
	XCTAssertEqualObjects(buffer.pixelData, pixels);
}

/*! @abstract The none codec stores the pixels verbatim as the compressed data. */
- (void)testCompressionNoneStoresThePixelsVerbatim
{
	NSData *pixels = [self compressiblePixelsForWidth:16 height:16 format:FxGripPixelFormatRGBA8U];

	FxGripImageBuffer *buffer = [self bufferWithPixels:pixels width:16 height:16
											   format:FxGripPixelFormatRGBA8U
										  compression:FxGripCompressionNone];

	XCTAssertEqual(buffer.compression, FxGripCompressionNone);
	XCTAssertEqualObjects(buffer.compressedData, pixels);
}

/*! @abstract pixelData round-trips exactly for every pixel format under a lossless codec. */
- (void)testPixelDataRoundTripsExactlyForEveryFormat
{
	for (NSUInteger index = 0; index < kImageBufferTestFormatCount; index++) {
		FxGripPixelFormat format = kImageBufferTestFormats[index];
		NSData *pixels = [self incompressiblePixelsForWidth:3 height:2 format:format];

		FxGripImageBuffer *buffer = [self bufferWithPixels:pixels width:3 height:2
												   format:format
											  compression:FxGripCompressionLZFSE];

		XCTAssertNotNil(buffer, @"format %ld", (long)format);
		XCTAssertEqualObjects(buffer.pixelData, pixels, @"format %ld", (long)format);
	}
}

/*! @abstract Compressible pixel data round-trips exactly for every format under the Zlib codec. */
- (void)testCompressedPixelDataRoundTripsExactlyForEveryFormat
{
	for (NSUInteger index = 0; index < kImageBufferTestFormatCount; index++) {
		FxGripPixelFormat format = kImageBufferTestFormats[index];
		NSData *pixels = [self compressiblePixelsForWidth:32 height:8 format:format];

		FxGripImageBuffer *buffer = [self bufferWithPixels:pixels width:32 height:8
												   format:format
											  compression:FxGripCompressionZlib];

		XCTAssertEqual(buffer.compression, FxGripCompressionZlib, @"format %ld", (long)format);
		XCTAssertEqualObjects(buffer.pixelData, pixels, @"format %ld", (long)format);
	}
}

#pragma mark Conversion

/*! @abstract Converting to half float and back keeps each value within half-precision tolerance and halves the length. */
- (void)testConversionToHalfFloatKeepsValuesWithinHalfPrecision
{
	const float source[] = {0.1f, 0.5f, 2.5f, -1.25f};
	FxGripImageBuffer *buffer = [self bufferWithFloats:source count:4 format:FxGripPixelFormatRGBA32F];

	FxGripImageBuffer *half = [buffer bufferByConvertingToFormat:FxGripPixelFormatRGBA16F
													compression:FxGripCompressionNone];
	FxGripImageBuffer *back = [half bufferByConvertingToFormat:FxGripPixelFormatRGBA32F
												  compression:FxGripCompressionNone];
	const float *values = back.pixelData.bytes;

	XCTAssertEqual(half.uncompressedLength, buffer.uncompressedLength / 2);
	for (NSUInteger index = 0; index < 4; index++) {
		XCTAssertEqualWithAccuracy(values[index], source[index], fabs(source[index]) * 0.001 + 1e-6,
								   @"component %lu", (unsigned long)index);
	}
}

/*! @abstract Half-float conversion keeps values outside the zero-to-one range rather than clamping them. */
- (void)testHalfFloatConversionKeepsValuesOutsideTheZeroToOneRange
{
	const float source[] = {-1.25f, 2.5f, 8.0f, 0.0f};
	FxGripImageBuffer *buffer = [self bufferWithFloats:source count:4 format:FxGripPixelFormatRGBA32F];

	FxGripImageBuffer *back = [[buffer bufferByConvertingToFormat:FxGripPixelFormatRGBA16F
													 compression:FxGripCompressionNone]
							   bufferByConvertingToFormat:FxGripPixelFormatRGBA32F
											  compression:FxGripCompressionNone];
	const float *values = back.pixelData.bytes;

	XCTAssertEqual(values[0], -1.25f);
	XCTAssertEqual(values[1], 2.5f);
	XCTAssertEqual(values[2], 8.0f);
}

/*! @abstract Converting float to an integer format clamps values below zero and above one. */
- (void)testConversionToAnIntegerFormatClampsBelowZeroAndAboveOne
{
	const float source[] = {-0.5f, 0.0f, 0.5f, 1.5f};
	FxGripImageBuffer *buffer = [self bufferWithFloats:source count:4 format:FxGripPixelFormatRGBA32F];

	FxGripImageBuffer *bytes = [buffer bufferByConvertingToFormat:FxGripPixelFormatRGBA8U
													 compression:FxGripCompressionNone];
	const uint8_t *values = bytes.pixelData.bytes;

	XCTAssertEqual(values[0], 0);
	XCTAssertEqual(values[1], 0);
	XCTAssertEqual(values[2], 128);
	XCTAssertEqual(values[3], 255);
}

/*! @abstract Converting float to a 32-bit integer format maps one to the full-scale value. */
- (void)testConversionToAThirtyTwoBitIntegerFormatMapsOneToFullScale
{
	const float source[] = {0.0f, 1.0f, 0.5f, 1.0f};
	FxGripImageBuffer *buffer = [self bufferWithFloats:source count:4 format:FxGripPixelFormatRGBA32F];

	FxGripImageBuffer *integers = [buffer bufferByConvertingToFormat:FxGripPixelFormatRGBA32U
														 compression:FxGripCompressionNone];
	const uint32_t *values = integers.pixelData.bytes;

	XCTAssertEqual(values[0], 0u);
	XCTAssertEqual(values[1], UINT32_MAX);
	XCTAssertEqual(values[3], UINT32_MAX);
}

/*! @abstract Converting from an 8-bit format normalizes full scale to one. */
- (void)testConversionFromAnEightBitFormatNormalizesFullScaleToOne
{
	const uint8_t source[] = {0, 128, 255, 255};
	FxGripImageBuffer *buffer = [self bufferWithPixels:[NSData dataWithBytes:source length:4]
												 width:1 height:1
												format:FxGripPixelFormatRGBA8U
										   compression:FxGripCompressionNone];

	FxGripImageBuffer *floats = [buffer bufferByConvertingToFormat:FxGripPixelFormatRGBA32F
													   compression:FxGripCompressionNone];
	const float *values = floats.pixelData.bytes;

	XCTAssertEqual(values[0], 0.0f);
	XCTAssertEqualWithAccuracy(values[1], 128.0f / 255.0f, 1e-6);
	XCTAssertEqual(values[2], 1.0f);
	XCTAssertEqual(values[3], 1.0f);
}

/*! @abstract Converting from a 16-bit format normalizes full scale to one. */
- (void)testConversionFromASixteenBitFormatNormalizesFullScaleToOne
{
	const uint16_t source[] = {0, 65535, 32768, 65535};
	FxGripImageBuffer *buffer = [self bufferWithPixels:[NSData dataWithBytes:source length:sizeof(source)]
												 width:1 height:1
												format:FxGripPixelFormatRGBA16U
										   compression:FxGripCompressionNone];

	FxGripImageBuffer *floats = [buffer bufferByConvertingToFormat:FxGripPixelFormatRGBA32F
													   compression:FxGripCompressionNone];
	const float *values = floats.pixelData.bytes;

	XCTAssertEqual(values[0], 0.0f);
	XCTAssertEqual(values[1], 1.0f);
	XCTAssertEqualWithAccuracy(values[2], 32768.0f / 65535.0f, 1e-6);
}

/*! @abstract An 8-bit to 16-bit and back conversion is lossless. */
- (void)testAnIntegerRoundTripThroughTheFullScaleIsLossless
{
	const uint8_t source[] = {0, 1, 128, 255};
	FxGripImageBuffer *buffer = [self bufferWithPixels:[NSData dataWithBytes:source length:4]
												 width:1 height:1
												format:FxGripPixelFormatRGBA8U
										   compression:FxGripCompressionNone];

	FxGripImageBuffer *back = [[buffer bufferByConvertingToFormat:FxGripPixelFormatRGBA16U
													 compression:FxGripCompressionNone]
							   bufferByConvertingToFormat:FxGripPixelFormatRGBA8U
											  compression:FxGripCompressionNone];

	XCTAssertEqualObjects(back.pixelData, buffer.pixelData);
}

/*! @abstract Converting to add an alpha channel fills it opaque for an integer format. */
- (void)testConversionAddingAlphaFillsItOpaque
{
	const uint8_t source[] = {10, 20, 30};
	FxGripImageBuffer *buffer = [self bufferWithPixels:[NSData dataWithBytes:source length:3]
												 width:1 height:1
												format:FxGripPixelFormatRGB8U
										   compression:FxGripCompressionNone];

	FxGripImageBuffer *withAlpha = [buffer bufferByConvertingToFormat:FxGripPixelFormatRGBA8U
														 compression:FxGripCompressionNone];
	const uint8_t *values = withAlpha.pixelData.bytes;

	XCTAssertEqual(values[0], 10);
	XCTAssertEqual(values[1], 20);
	XCTAssertEqual(values[2], 30);
	XCTAssertEqual(values[3], 255);
}

/*! @abstract Converting to add an alpha channel fills it with one for a float format. */
- (void)testConversionAddingAlphaToAFloatFormatFillsItWithOne
{
	const float source[] = {0.25f, 0.5f, 0.75f};
	FxGripImageBuffer *buffer = [self bufferWithFloats:source count:3 format:FxGripPixelFormatRGB32F];

	FxGripImageBuffer *withAlpha = [buffer bufferByConvertingToFormat:FxGripPixelFormatRGBA32F
														 compression:FxGripCompressionNone];
	const float *values = withAlpha.pixelData.bytes;

	XCTAssertEqual(values[3], 1.0f);
}

/*! @abstract Converting to drop the alpha channel discards it and keeps the color channels. */
- (void)testConversionDroppingAlphaDiscardsIt
{
	const float source[] = {1.5f, 2.5f, 3.5f, 0.25f};
	FxGripImageBuffer *buffer = [self bufferWithFloats:source count:4 format:FxGripPixelFormatRGBA32F];

	FxGripImageBuffer *withoutAlpha = [buffer bufferByConvertingToFormat:FxGripPixelFormatRGB32F
															compression:FxGripCompressionNone];
	const float *values = withoutAlpha.pixelData.bytes;

	XCTAssertEqual(withoutAlpha.format, FxGripPixelFormatRGB32F);
	XCTAssertEqual(withoutAlpha.uncompressedLength, 12u);
	XCTAssertEqual(values[0], 1.5f);
	XCTAssertEqual(values[1], 2.5f);
	XCTAssertEqual(values[2], 3.5f);
}

/*! @abstract Converting to the same format recompresses the pixels under the new codec. */
- (void)testConversionToTheSameFormatRecompressesThePixels
{
	NSData *pixels = [self compressiblePixelsForWidth:32 height:32 format:FxGripPixelFormatRGBA8U];
	FxGripImageBuffer *buffer = [self bufferWithPixels:pixels width:32 height:32
											   format:FxGripPixelFormatRGBA8U
										  compression:FxGripCompressionNone];

	FxGripImageBuffer *recompressed = [buffer bufferByConvertingToFormat:FxGripPixelFormatRGBA8U
															compression:FxGripCompressionLZMA];

	XCTAssertEqual(recompressed.compression, FxGripCompressionLZMA);
	XCTAssertLessThan(recompressed.compressedData.length, buffer.compressedData.length);
	XCTAssertEqualObjects(recompressed.pixelData, pixels);
}

/*! @abstract Conversion preserves the width, height, and tight row bytes of the new format. */
- (void)testConversionPreservesTheDimensions
{
	FxGripImageBuffer *buffer = [self bufferWithPixels:[self compressiblePixelsForWidth:7 height:5 format:FxGripPixelFormatRGBA8U]
												 width:7 height:5
												format:FxGripPixelFormatRGBA8U
										   compression:FxGripCompressionNone];

	FxGripImageBuffer *converted = [buffer bufferByConvertingToFormat:FxGripPixelFormatRGB16F
														 compression:FxGripCompressionNone];

	XCTAssertEqual(converted.width, 7u);
	XCTAssertEqual(converted.height, 5u);
	XCTAssertEqual(converted.rowBytes, 7u * 6u);
}

/*! @abstract Converting to an invalid format returns nil. */
- (void)testConversionToAnInvalidFormatIsNil
{
	FxGripImageBuffer *buffer = [self bufferWithPixels:[self compressiblePixelsForWidth:4 height:4 format:FxGripPixelFormatRGBA8U]
												 width:4 height:4
												format:FxGripPixelFormatRGBA8U
										   compression:FxGripCompressionNone];

	XCTAssertNil([buffer bufferByConvertingToFormat:FxGripPixelFormatInvalid compression:FxGripCompressionNone]);
}

#pragma mark Secure coding

/*! @abstract A secure-coding archive round trip preserves the pixels, format, and dimensions. */
- (void)testTheArchiveRoundTripPreservesThePixelsFormatAndDimensions
{
	NSData *pixels = [self incompressiblePixelsForWidth:9 height:6 format:FxGripPixelFormatRGBA16F];
	FxGripImageBuffer *buffer = [self bufferWithPixels:pixels width:9 height:6
											   format:FxGripPixelFormatRGBA16F
										  compression:FxGripCompressionLZFSE];

	FxGripImageBuffer *decoded = [self unarchivedBufferFromData:[self archivedBuffer:buffer]];

	XCTAssertEqual(decoded.width, 9u);
	XCTAssertEqual(decoded.height, 6u);
	XCTAssertEqual(decoded.format, FxGripPixelFormatRGBA16F);
	XCTAssertEqual(decoded.uncompressedLength, buffer.uncompressedLength);
	XCTAssertEqualObjects(decoded.pixelData, pixels);
}

/*! @abstract A secure-coding archive round trip keeps the storage codec and compressed bytes. */
- (void)testTheArchiveRoundTripKeepsTheStorageCodec
{
	NSData *pixels = [self compressiblePixelsForWidth:32 height:32 format:FxGripPixelFormatRGBA8U];
	FxGripImageBuffer *buffer = [self bufferWithPixels:pixels width:32 height:32
											   format:FxGripPixelFormatRGBA8U
										  compression:FxGripCompressionZlib];

	FxGripImageBuffer *decoded = [self unarchivedBufferFromData:[self archivedBuffer:buffer]];

	XCTAssertEqual(decoded.compression, FxGripCompressionZlib);
	XCTAssertEqualObjects(decoded.compressedData, buffer.compressedData);
}

/*! @abstract Encoding writes the compressed payload without decompressing, so the archive stays close to the compressed size. */
- (void)testEncodingWritesTheCompressedPayloadWithoutDecompressing
{
	NSData *pixels = [self compressiblePixelsForWidth:256 height:256 format:FxGripPixelFormatRGBA8U];
	FxGripImageBuffer *buffer = [self bufferWithPixels:pixels width:256 height:256
											   format:FxGripPixelFormatRGBA8U
										  compression:FxGripCompressionLZFSE];

	NSUInteger archiveLength = [self archivedBuffer:buffer].length;

	XCTAssertEqual(buffer.uncompressedLength, 262144u);
	XCTAssertLessThan(archiveLength, buffer.compressedData.length + 1024u);
	XCTAssertLessThan(archiveLength, buffer.uncompressedLength / 100u);
}

/*! @abstract Decoding rejects an archive whose stored length contradicts the dimensions and format. */
- (void)testAnArchiveWhoseLengthContradictsTheDimensionsIsRejected
{
	NSData *pixels = [self incompressiblePixelsForWidth:4 height:4 format:FxGripPixelFormatRGBA8U];
	NSData *archive = [self archiveWithIntegerFields:@{kImageBufferCoderKey_Version: @1,
													   kImageBufferCoderKey_Width: @4,
													   kImageBufferCoderKey_Height: @4,
													   kImageBufferCoderKey_Format: @(FxGripPixelFormatRGBA8U),
													   kImageBufferCoderKey_Compression: @(FxGripCompressionNone),
													   kImageBufferCoderKey_Length: @99}
											 payload:pixels];

	XCTAssertNil([self unarchivedBufferFromData:archive]);
}

/*! @abstract Decoding rejects an archive whose stored format is invalid. */
- (void)testAnArchiveWithAnInvalidFormatIsRejected
{
	NSData *pixels = [self incompressiblePixelsForWidth:4 height:4 format:FxGripPixelFormatRGBA8U];
	NSData *archive = [self archiveWithIntegerFields:@{kImageBufferCoderKey_Version: @1,
													   kImageBufferCoderKey_Width: @4,
													   kImageBufferCoderKey_Height: @4,
													   kImageBufferCoderKey_Format: @(FxGripPixelFormatInvalid),
													   kImageBufferCoderKey_Compression: @(FxGripCompressionNone),
													   kImageBufferCoderKey_Length: @64}
											 payload:pixels];

	XCTAssertNil([self unarchivedBufferFromData:archive]);
}

/*! @abstract Decoding rejects an archive that carries no payload. */
- (void)testAnArchiveWithoutAPayloadIsRejected
{
	NSData *archive = [self archiveWithIntegerFields:@{kImageBufferCoderKey_Version: @1,
													   kImageBufferCoderKey_Width: @4,
													   kImageBufferCoderKey_Height: @4,
													   kImageBufferCoderKey_Format: @(FxGripPixelFormatRGBA8U),
													   kImageBufferCoderKey_Compression: @(FxGripCompressionNone),
													   kImageBufferCoderKey_Length: @64}
											 payload:nil];

	XCTAssertNil([self unarchivedBufferFromData:archive]);
}

/*! @abstract Decoding accepts an archive whose fields are internally consistent and returns the pixels. */
- (void)testAnArchiveWithConsistentFieldsIsAccepted
{
	NSData *pixels = [self incompressiblePixelsForWidth:4 height:4 format:FxGripPixelFormatRGBA8U];
	NSData *archive = [self archiveWithIntegerFields:@{kImageBufferCoderKey_Version: @1,
													   kImageBufferCoderKey_Width: @4,
													   kImageBufferCoderKey_Height: @4,
													   kImageBufferCoderKey_Format: @(FxGripPixelFormatRGBA8U),
													   kImageBufferCoderKey_Compression: @(FxGripCompressionNone),
													   kImageBufferCoderKey_Length: @64}
											 payload:pixels];

	XCTAssertEqualObjects([self unarchivedBufferFromData:archive].pixelData, pixels);
}

#pragma mark Identity

/*! @abstract Two buffers holding equal pixels under different codecs are equal and hash alike. */
- (void)testBuffersWithEqualPixelsUnderDifferentCodecsAreEqual
{
	NSData *pixels = [self compressiblePixelsForWidth:16 height:16 format:FxGripPixelFormatRGBA8U];
	FxGripImageBuffer *lzfse = [self bufferWithPixels:pixels width:16 height:16
											   format:FxGripPixelFormatRGBA8U
										  compression:FxGripCompressionLZFSE];
	FxGripImageBuffer *uncompressed = [self bufferWithPixels:pixels width:16 height:16
													  format:FxGripPixelFormatRGBA8U
												 compression:FxGripCompressionNone];

	XCTAssertNotEqual(lzfse.compression, uncompressed.compression);
	XCTAssertEqualObjects(lzfse, uncompressed);
	XCTAssertEqual(lzfse.hash, uncompressed.hash);
}

/*! @abstract Two buffers holding different pixels are not equal. */
- (void)testBuffersWithDifferentPixelsAreNotEqual
{
	FxGripImageBuffer *flat = [self bufferWithPixels:[self compressiblePixelsForWidth:8 height:8 format:FxGripPixelFormatRGBA8U]
											   width:8 height:8
											  format:FxGripPixelFormatRGBA8U
										 compression:FxGripCompressionNone];
	FxGripImageBuffer *noise = [self bufferWithPixels:[self incompressiblePixelsForWidth:8 height:8 format:FxGripPixelFormatRGBA8U]
												width:8 height:8
											   format:FxGripPixelFormatRGBA8U
										  compression:FxGripCompressionNone];

	XCTAssertNotEqualObjects(flat, noise);
}

/*! @abstract Two buffers holding the same bytes under different formats are not equal. */
- (void)testBuffersWithTheSameBytesUnderDifferentFormatsAreNotEqual
{
	NSData *pixels = [self compressiblePixelsForWidth:4 height:4 format:FxGripPixelFormatRGBA8U];
	FxGripImageBuffer *asBytes = [self bufferWithPixels:pixels width:4 height:4
												 format:FxGripPixelFormatRGBA8U
											compression:FxGripCompressionNone];
	FxGripImageBuffer *asShorts = [self bufferWithPixels:pixels width:2 height:4
												  format:FxGripPixelFormatRGBA16U
											 compression:FxGripCompressionNone];

	XCTAssertNotEqualObjects(asBytes, asShorts);
}

/*! @abstract A buffer is not equal to an object of another kind. */
- (void)testABufferIsNotEqualToAnotherKindOfObject
{
	FxGripImageBuffer *buffer = [self bufferWithPixels:[self compressiblePixelsForWidth:4 height:4 format:FxGripPixelFormatRGBA8U]
												 width:4 height:4
												format:FxGripPixelFormatRGBA8U
										   compression:FxGripCompressionNone];

	XCTAssertNotEqualObjects(buffer, @"buffer");
}

/*! @abstract copy returns the same immutable instance. */
- (void)testCopyReturnsTheSameImmutableInstance
{
	FxGripImageBuffer *buffer = [self bufferWithPixels:[self compressiblePixelsForWidth:4 height:4 format:FxGripPixelFormatRGBA8U]
												 width:4 height:4
												format:FxGripPixelFormatRGBA8U
										   compression:FxGripCompressionNone];

	XCTAssertTrue([buffer copy] == buffer);
}

#pragma mark Metal

- (id<MTLDevice>)metalDevice
{
	FxGripImageBufferTestCreateDevice create =
		(FxGripImageBufferTestCreateDevice)dlsym(RTLD_DEFAULT, "MTLCreateSystemDefaultDevice");
	if (create == NULL) {
		return nil;
	}
	return (__bridge_transfer id<MTLDevice>)create();
}

/*! @abstract An RGBA float buffer round-trips through a Metal texture with its dimensions, pixel format, and pixels intact. */
- (void)testAFloatBufferRoundTripsThroughAMetalTexture
{
	id<MTLDevice> device = [self metalDevice];
	XCTSkipIf(device == nil, @"No Metal device.");

	NSData *pixels = [self incompressiblePixelsForWidth:8 height:4 format:FxGripPixelFormatRGBA32F];
	FxGripImageBuffer *buffer = [self bufferWithPixels:pixels width:8 height:4
											   format:FxGripPixelFormatRGBA32F
										  compression:FxGripCompressionLZFSE];

	id<MTLTexture> texture = [buffer newTextureWithDevice:device];
	FxGripImageBuffer *readBack = [FxGripImageBuffer bufferWithTexture:texture compression:FxGripCompressionLZFSE];

	XCTAssertNotNil(texture);
	XCTAssertEqual(texture.width, 8u);
	XCTAssertEqual(texture.height, 4u);
	XCTAssertEqual(texture.pixelFormat, MTLPixelFormatRGBA32Float);
	XCTAssertEqualObjects(readBack, buffer);
}

/*! @abstract An RGBA 8-bit buffer round-trips through a Metal texture with its pixels and format intact. */
- (void)testAnEightBitBufferRoundTripsThroughAMetalTexture
{
	id<MTLDevice> device = [self metalDevice];
	XCTSkipIf(device == nil, @"No Metal device.");

	NSData *pixels = [self incompressiblePixelsForWidth:8 height:4 format:FxGripPixelFormatRGBA8U];
	FxGripImageBuffer *buffer = [self bufferWithPixels:pixels width:8 height:4
											   format:FxGripPixelFormatRGBA8U
										  compression:FxGripCompressionNone];

	id<MTLTexture> texture = [buffer newTextureWithDevice:device];
	FxGripImageBuffer *readBack = [FxGripImageBuffer bufferWithTexture:texture compression:FxGripCompressionNone];

	XCTAssertEqual(texture.pixelFormat, MTLPixelFormatRGBA8Unorm);
	XCTAssertEqualObjects(readBack.pixelData, pixels);
	XCTAssertEqual(readBack.format, FxGripPixelFormatRGBA8U);
}

/*! @abstract A three-channel RGB buffer makes no Metal texture. */
- (void)testAnRGBBufferHasNoMetalTexture
{
	id<MTLDevice> device = [self metalDevice];
	XCTSkipIf(device == nil, @"No Metal device.");

	FxGripImageBuffer *buffer = [self bufferWithPixels:[self compressiblePixelsForWidth:4 height:4 format:FxGripPixelFormatRGB32F]
												 width:4 height:4
												format:FxGripPixelFormatRGB32F
										   compression:FxGripCompressionNone];

	XCTAssertNil([buffer newTextureWithDevice:device]);
}

/*! @abstract A texture in an unsupported Metal pixel format makes no buffer. */
- (void)testATextureInAnUnsupportedFormatMakesNoBuffer
{
	id<MTLDevice> device = [self metalDevice];
	XCTSkipIf(device == nil, @"No Metal device.");

	Class descriptorClass = NSClassFromString(@"MTLTextureDescriptor");
	MTLTextureDescriptor *descriptor =
		[descriptorClass texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm
													  width:4
													 height:4
												  mipmapped:NO];
	id<MTLTexture> texture = [device newTextureWithDescriptor:descriptor];

	XCTAssertNil([FxGripImageBuffer bufferWithTexture:texture compression:FxGripCompressionNone]);
}

#pragma mark Previews

/*! @abstract The bitmap representation carries the buffer's dimensions and four samples per pixel. */
- (void)testTheBitmapRepresentationCarriesTheBufferDimensions
{
	FxGripImageBuffer *buffer = [self bufferWithPixels:[self incompressiblePixelsForWidth:6 height:5 format:FxGripPixelFormatRGBA8U]
												 width:6 height:5
												format:FxGripPixelFormatRGBA8U
										   compression:FxGripCompressionNone];

	NSBitmapImageRep *rep = buffer.bitmapRep;

	XCTAssertNotNil(rep);
	XCTAssertEqual(rep.pixelsWide, 6);
	XCTAssertEqual(rep.pixelsHigh, 5);
	XCTAssertEqual(rep.samplesPerPixel, 4);
}

/*! @abstract A float buffer converts to an 8-bit bitmap representation carrying the buffer's dimensions. */
- (void)testAFloatBufferConvertsForTheBitmapRepresentation
{
	FxGripImageBuffer *buffer = [self bufferWithPixels:[self compressiblePixelsForWidth:6 height:5 format:FxGripPixelFormatRGB32F]
												 width:6 height:5
												format:FxGripPixelFormatRGB32F
										   compression:FxGripCompressionLZFSE];

	NSBitmapImageRep *rep = buffer.bitmapRep;

	XCTAssertNotNil(rep);
	XCTAssertEqual(rep.pixelsWide, 6);
	XCTAssertEqual(rep.pixelsHigh, 5);
	XCTAssertEqual(rep.bitsPerPixel, 32);
}

/*! @abstract The image preview carries the buffer size and a single representation. */
- (void)testTheImagePreviewCarriesTheBufferSize
{
	FxGripImageBuffer *buffer = [self bufferWithPixels:[self incompressiblePixelsForWidth:6 height:5 format:FxGripPixelFormatRGBA8U]
												 width:6 height:5
												format:FxGripPixelFormatRGBA8U
										   compression:FxGripCompressionNone];

	NSImage *image = buffer.image;

	XCTAssertNotNil(image);
	XCTAssertEqual(image.size.width, 6.0);
	XCTAssertEqual(image.size.height, 5.0);
	XCTAssertEqual(image.representations.count, 1u);
}

#pragma mark Lossy codecs

/*! @abstract JPEG encodes gray and RGB gradients within a per-byte tolerance and shrinks the payload. */
- (void)testJPEGHoldsGrayAndRGBWithinTolerance
{
	// Large enough that the codec's container overhead cannot outweigh the pixels.
	const FxGripPixelFormat formats[] = {FxGripPixelFormatGray8U, FxGripPixelFormatRGB8U};
	for (NSUInteger index = 0; index < 2; index++) {
		FxGripPixelFormat format = formats[index];
		NSData *pixels = [self gradientPixelsForWidth:128 height:128 format:format];

		FxGripImageBuffer *buffer = [FxGripImageBuffer.alloc initWithBytes:pixels.bytes
																 rowBytes:128 * FxGripPixelFormatBytesPerPixel(format)
																	width:128
																   height:128
																   format:format
															  compression:FxGripCompressionJPEG
																  quality:0.9f];

		XCTAssertEqual(buffer.compression, FxGripCompressionJPEG, @"format %ld", (long)format);
		XCTAssertLessThan(buffer.compressedData.length, buffer.uncompressedLength);
		NSData *decoded = buffer.pixelData;
		XCTAssertEqual(decoded.length, pixels.length);
		const uint8_t *expected = pixels.bytes;
		const uint8_t *actual = decoded.bytes;
		// JPEG subsamples chroma, so color components drift further than luma.
		for (NSUInteger byte = 0; byte < decoded.length; byte++) {
			XCTAssertLessThanOrEqual(abs((int)expected[byte] - (int)actual[byte]), 16,
									 @"format %ld byte %lu", (long)format, (unsigned long)byte);
		}
	}
}

/*! @abstract A lower JPEG quality yields a smaller compressed payload than a higher quality. */
- (void)testALowerJPEGQualityYieldsASmallerPayload
{
	NSData *pixels = [self gradientPixelsForWidth:64 height:64 format:FxGripPixelFormatRGB8U];

	FxGripImageBuffer *half = [FxGripImageBuffer.alloc initWithBytes:pixels.bytes
															rowBytes:64 * 3 width:64 height:64
															  format:FxGripPixelFormatRGB8U
														 compression:FxGripCompressionJPEG
															 quality:0.5f];
	FxGripImageBuffer *high = [FxGripImageBuffer.alloc initWithBytes:pixels.bytes
															rowBytes:64 * 3 width:64 height:64
															  format:FxGripPixelFormatRGB8U
														 compression:FxGripCompressionJPEG
															 quality:0.95f];

	XCTAssertLessThan(half.compressedData.length, high.compressedData.length);
}

/*! @abstract HEIC encodes an opaque RGBA image and keeps its alpha fully opaque. */
- (void)testHEICCarriesAnOpaqueRGBAImage
{
	NSData *pixels = [self gradientPixelsForWidth:64 height:64 format:FxGripPixelFormatRGBA8U];

	FxGripImageBuffer *buffer = [FxGripImageBuffer.alloc initWithBytes:pixels.bytes
															 rowBytes:64 * 4 width:64 height:64
															   format:FxGripPixelFormatRGBA8U
														  compression:FxGripCompressionHEIC
															  quality:0.9f];

	XCTAssertEqual(buffer.compression, FxGripCompressionHEIC);
	NSData *decoded = buffer.pixelData;
	XCTAssertEqual(decoded.length, pixels.length);
	const uint8_t *actual = decoded.bytes;
	for (NSUInteger pixel = 0; pixel < 64 * 64; pixel++) {
		XCTAssertEqual(actual[pixel * 4 + 3], 255, @"opaque alpha survives at pixel %lu", (unsigned long)pixel);
	}
}

/*! Every format lossy-encodes: the codec that cannot hold it natively gets an internal
	down-convert with alpha in its own plane, and the declared format survives. */
- (void)testEveryFormatLossyEncodesAndKeepsItsDeclaredShape
{
	const struct { FxGripPixelFormat format; FxGripCompression codec; } cases[] = {
		{FxGripPixelFormatRGBA8U, FxGripCompressionJPEG},
		{FxGripPixelFormatGray16U, FxGripCompressionJPEG},
		{FxGripPixelFormatGrayAlpha8U, FxGripCompressionHEIC},
		{FxGripPixelFormatRGB32F, FxGripCompressionHEIC},
	};
	for (NSUInteger index = 0; index < 4; index++) {
		NSData *pixels = [self gradientPixelsForWidth:32 height:32 format:cases[index].format];
		if (FxGripPixelFormatComponentType(cases[index].format) != FxGripComponentTypeUInt8) {
			// The gradient fixture writes 8-bit bytes; widen through a conversion so the
			// wide formats carry real values.
			FxGripImageBuffer *narrow = [self bufferWithPixels:[self gradientPixelsForWidth:32 height:32
																					 format:FxGripPixelFormatRGBA8U]
														 width:32 height:32
														format:FxGripPixelFormatRGBA8U
												   compression:FxGripCompressionNone];
			pixels = [narrow bufferByConvertingToFormat:cases[index].format
											compression:FxGripCompressionNone].pixelData;
		}

		FxGripImageBuffer *buffer = [FxGripImageBuffer.alloc initWithBytes:pixels.bytes
																 rowBytes:32 * FxGripPixelFormatBytesPerPixel(cases[index].format)
																	width:32
																   height:32
																   format:cases[index].format
															  compression:cases[index].codec
																  quality:0.9f];

		XCTAssertEqual(buffer.compression, cases[index].codec, @"case %lu", (unsigned long)index);
		XCTAssertEqual(buffer.format, cases[index].format, @"case %lu", (unsigned long)index);
		NSData *decoded = buffer.pixelData;
		XCTAssertEqual(decoded.length, pixels.length, @"case %lu", (unsigned long)index);
	}
}

/*! An opaque alpha channel rides its own constant plane, so it survives a lossy encode
	exactly even under JPEG. */
- (void)testJPEGCarriesRGBAWithAnExactOpaqueAlpha
{
	NSData *pixels = [self gradientPixelsForWidth:64 height:64 format:FxGripPixelFormatRGBA8U];

	FxGripImageBuffer *buffer = [FxGripImageBuffer.alloc initWithBytes:pixels.bytes
															 rowBytes:64 * 4 width:64 height:64
															   format:FxGripPixelFormatRGBA8U
														  compression:FxGripCompressionJPEG
															  quality:0.9f];

	XCTAssertEqual(buffer.compression, FxGripCompressionJPEG);
	NSData *decoded = buffer.pixelData;
	const uint8_t *actual = decoded.bytes;
	for (NSUInteger pixel = 0; pixel < 64 * 64; pixel++) {
		XCTAssertEqual(actual[pixel * 4 + 3], 255, @"pixel %lu", (unsigned long)pixel);
	}
}

/*! HEIC carries 16-bit components, so a 16-bit gray gradient survives with far better
	than 8-bit precision (the codec's HEVC internals are 10/12-bit). */
- (void)testHEICKeepsSixteenBitPrecisionBeyondEightBits
{
	const NSUInteger width = 64, height = 64;
	NSMutableData *pixels = [NSMutableData dataWithLength:width * height * 2];
	uint16_t *values = pixels.mutableBytes;
	for (NSUInteger pixel = 0; pixel < width * height; pixel++) {
		values[pixel] = (uint16_t)((pixel * 65535) / (width * height - 1));
	}

	FxGripImageBuffer *buffer = [FxGripImageBuffer.alloc initWithBytes:pixels.bytes
															 rowBytes:width * 2 width:width height:height
															   format:FxGripPixelFormatGray16U
														  compression:FxGripCompressionHEIC
															  quality:0.95f];

	XCTAssertEqual(buffer.compression, FxGripCompressionHEIC);
	NSData *decoded = buffer.pixelData;
	XCTAssertEqual(decoded.length, pixels.length);
	const uint16_t *actual = decoded.bytes;
	NSUInteger maxDelta = 0;
	for (NSUInteger pixel = 0; pixel < width * height; pixel++) {
		NSUInteger delta = (NSUInteger)labs((long)values[pixel] - (long)actual[pixel]);
		if (delta > maxDelta) {
			maxDelta = delta;
		}
	}
	// An 8-bit container quantizes a full-range ramp in 257-wide steps; the 16-bit
	// transport must beat that floor. The margin differs per architecture (the arm64 and
	// Rosetta HEVC encoders quantize differently), so the floor is the assertion.
	XCTAssertLessThan(maxDelta, 257u);
}

/*! @abstract The quality clamps to the zero-to-one range and persists through the archive. */
- (void)testTheQualityClampsAndPersistsThroughTheArchive
{
	NSData *pixels = [self gradientPixelsForWidth:16 height:16 format:FxGripPixelFormatGray8U];
	FxGripImageBuffer *loud = [FxGripImageBuffer.alloc initWithBytes:pixels.bytes
															rowBytes:16 width:16 height:16
															  format:FxGripPixelFormatGray8U
														 compression:FxGripCompressionJPEG
															 quality:2.0f];
	FxGripImageBuffer *negative = [FxGripImageBuffer.alloc initWithBytes:pixels.bytes
																rowBytes:16 width:16 height:16
																  format:FxGripPixelFormatGray8U
															 compression:FxGripCompressionJPEG
																 quality:-1.0f];

	XCTAssertEqual(loud.quality, 1.0f);
	XCTAssertEqual(negative.quality, 0.0f);
	FxGripImageBuffer *decoded = [self unarchivedBufferFromData:[self archivedBuffer:loud]];
	XCTAssertEqual(decoded.quality, 1.0f);
	XCTAssertEqual(decoded.compression, FxGripCompressionJPEG);
	XCTAssertNotNil(decoded.pixelData);
}

#pragma mark Channel-aware conversion

/*! @abstract Converting color to gray collapses the channels to Rec.709 luminance. */
- (void)testConversionCollapsesColorToRec709Luminance
{
	const float red[4] = {1.f, 0.f, 0.f, 1.f};
	FxGripImageBuffer *source = [self bufferWithFloats:red count:4 format:FxGripPixelFormatRGBA32F];

	FxGripImageBuffer *gray = [source bufferByConvertingToFormat:FxGripPixelFormatGray32F
													 compression:FxGripCompressionNone];

	const float *value = gray.pixelData.bytes;
	XCTAssertEqualWithAccuracy(value[0], 0.2126f, 0.0001f);
}

/*! @abstract Converting gray to color replicates the gray value across the color channels. */
- (void)testConversionReplicatesGrayToTheColorChannels
{
	const float gray[1] = {0.25f};
	FxGripImageBuffer *source = [self bufferWithFloats:gray count:1 format:FxGripPixelFormatGray32F];

	FxGripImageBuffer *rgb = [source bufferByConvertingToFormat:FxGripPixelFormatRGB32F
													compression:FxGripCompressionNone];

	const float *values = rgb.pixelData.bytes;
	XCTAssertEqual(values[0], 0.25f);
	XCTAssertEqual(values[1], 0.25f);
	XCTAssertEqual(values[2], 0.25f);
}

/*! @abstract Converting color to gray-alpha carries the alpha alongside the luminance. */
- (void)testConversionToGrayAlphaCarriesTheAlphaWithTheLuminance
{
	const float pixel[4] = {0.f, 1.f, 0.f, 0.5f};
	FxGripImageBuffer *source = [self bufferWithFloats:pixel count:4 format:FxGripPixelFormatRGBA32F];

	FxGripImageBuffer *grayAlpha = [source bufferByConvertingToFormat:FxGripPixelFormatGrayAlpha32F
														  compression:FxGripCompressionNone];

	const float *values = grayAlpha.pixelData.bytes;
	XCTAssertEqualWithAccuracy(values[0], 0.7152f, 0.0001f);
	XCTAssertEqual(values[1], 0.5f);
}

/*! @abstract Converting gray-alpha to RGBA replicates the gray across the color channels and carries the alpha. */
- (void)testConversionFromGrayAlphaReplicatesAndCarriesAlpha
{
	const float pixel[2] = {0.75f, 0.25f};
	FxGripImageBuffer *source = [self bufferWithFloats:pixel count:2 format:FxGripPixelFormatGrayAlpha32F];

	FxGripImageBuffer *rgba = [source bufferByConvertingToFormat:FxGripPixelFormatRGBA32F
													 compression:FxGripCompressionNone];

	const float *values = rgba.pixelData.bytes;
	XCTAssertEqual(values[0], 0.75f);
	XCTAssertEqual(values[1], 0.75f);
	XCTAssertEqual(values[2], 0.75f);
	XCTAssertEqual(values[3], 0.25f);
}

/*! @abstract Converting gray to gray-alpha keeps the gray value and adds an opaque alpha. */
- (void)testConversionFromGrayAddsAnOpaqueAlpha
{
	const float gray[1] = {0.5f};
	FxGripImageBuffer *source = [self bufferWithFloats:gray count:1 format:FxGripPixelFormatGray32F];

	FxGripImageBuffer *grayAlpha = [source bufferByConvertingToFormat:FxGripPixelFormatGrayAlpha32F
														  compression:FxGripCompressionNone];

	const float *values = grayAlpha.pixelData.bytes;
	XCTAssertEqual(values[0], 0.5f);
	XCTAssertEqual(values[1], 1.0f);
}

#pragma mark Metal, new formats

/*! @abstract A gray float buffer round-trips through a Metal texture with its format and pixels intact. */
- (void)testAGrayFloatBufferRoundTripsThroughATexture
{
	id<MTLDevice> device = [self metalDevice];
	XCTSkipIf(device == nil, @"No Metal device.");
	const float gray[4] = {0.f, 0.25f, 0.5f, 1.f};
	FxGripImageBuffer *source = [self bufferWithFloats:gray count:4 format:FxGripPixelFormatGray32F];

	id<MTLTexture> texture = [source newTextureWithDevice:device];
	FxGripImageBuffer *returned = [FxGripImageBuffer bufferWithTexture:texture compression:FxGripCompressionNone];

	XCTAssertEqual(returned.format, FxGripPixelFormatGray32F);
	XCTAssertEqualObjects(returned.pixelData, source.pixelData);
}

/*! @abstract A gray-alpha half-float buffer round-trips through a Metal texture with its format and pixels intact. */
- (void)testAGrayAlphaHalfBufferRoundTripsThroughATexture
{
	id<MTLDevice> device = [self metalDevice];
	XCTSkipIf(device == nil, @"No Metal device.");
	NSData *pixels = [self incompressiblePixelsForWidth:4 height:2 format:FxGripPixelFormatGrayAlpha16F];
	FxGripImageBuffer *source = [self bufferWithPixels:pixels width:4 height:2
											   format:FxGripPixelFormatGrayAlpha16F
										  compression:FxGripCompressionNone];

	id<MTLTexture> texture = [source newTextureWithDevice:device];
	FxGripImageBuffer *returned = [FxGripImageBuffer bufferWithTexture:texture compression:FxGripCompressionNone];

	XCTAssertEqual(returned.format, FxGripPixelFormatGrayAlpha16F);
	XCTAssertEqualObjects(returned.pixelData, pixels);
}

/*! @abstract A three-channel half-float buffer makes no Metal texture. */
- (void)testAThreeChannelHalfBufferMakesNoTexture
{
	id<MTLDevice> device = [self metalDevice];
	XCTSkipIf(device == nil, @"No Metal device.");
	NSData *pixels = [self incompressiblePixelsForWidth:2 height:2 format:FxGripPixelFormatRGB16F];
	FxGripImageBuffer *buffer = [self bufferWithPixels:pixels width:2 height:2
											   format:FxGripPixelFormatRGB16F
										  compression:FxGripCompressionNone];

	XCTAssertNil([buffer newTextureWithDevice:device]);
}

/*! @abstract A gray buffer still makes a bitmap preview at the buffer's dimensions. */
- (void)testAGrayBufferStillMakesAPreview
{
	NSData *pixels = [self gradientPixelsForWidth:8 height:8 format:FxGripPixelFormatGray8U];
	FxGripImageBuffer *buffer = [self bufferWithPixels:pixels width:8 height:8
											   format:FxGripPixelFormatGray8U
										  compression:FxGripCompressionNone];

	NSBitmapImageRep *rep = buffer.bitmapRep;
	XCTAssertEqual(rep.pixelsWide, 8);
	XCTAssertEqual(rep.pixelsHigh, 8);
}


#pragma mark AVIF

/*! The codec reaches ImageIO by identifier, so an OS without the encoder degrades to
	raw storage; with the encoder the requested codec sticks. */
- (void)testAVIFEncodesWhenAvailableAndStoresRawOtherwise
{
	NSData *pixels = [self gradientPixelsForWidth:64 height:64 format:FxGripPixelFormatRGB8U];

	FxGripImageBuffer *buffer = [FxGripImageBuffer.alloc initWithBytes:pixels.bytes
															 rowBytes:64 * 3 width:64 height:64
															   format:FxGripPixelFormatRGB8U
														  compression:FxGripCompressionAVIF
															  quality:0.7f];

	if (FxGripCompressionIsAvailable(FxGripCompressionAVIF)) {
		XCTAssertEqual(buffer.compression, FxGripCompressionAVIF);
	} else {
		XCTAssertEqual(buffer.compression, FxGripCompressionNone);
		XCTAssertEqualObjects(buffer.pixelData, pixels);
	}
}

/*! @abstract AVIF encodes an RGBA gradient within a per-channel tolerance and keeps its alpha opaque. */
- (void)testAVIFRoundTripsWithinToleranceAndKeepsOpaqueAlpha
{
	XCTSkipIf(!FxGripCompressionIsAvailable(FxGripCompressionAVIF), @"No AVIF encoder on this OS.");
	NSData *pixels = [self gradientPixelsForWidth:64 height:64 format:FxGripPixelFormatRGBA8U];

	FxGripImageBuffer *buffer = [FxGripImageBuffer.alloc initWithBytes:pixels.bytes
															 rowBytes:64 * 4 width:64 height:64
															   format:FxGripPixelFormatRGBA8U
														  compression:FxGripCompressionAVIF
															  quality:0.9f];

	XCTAssertEqual(buffer.compression, FxGripCompressionAVIF);
	NSData *decoded = buffer.pixelData;
	XCTAssertEqual(decoded.length, pixels.length);
	const uint8_t *expected = pixels.bytes;
	const uint8_t *actual = decoded.bytes;
	for (NSUInteger pixel = 0; pixel < 64 * 64; pixel++) {
		for (NSUInteger channel = 0; channel < 3; channel++) {
			XCTAssertLessThanOrEqual(abs((int)expected[pixel * 4 + channel] - (int)actual[pixel * 4 + channel]), 16,
									 @"pixel %lu channel %lu", (unsigned long)pixel, (unsigned long)channel);
		}
		XCTAssertEqual(actual[pixel * 4 + 3], 255, @"opaque alpha at pixel %lu", (unsigned long)pixel);
	}
}

/*! @abstract AVIF carries a 16-bit gray ramp with better than 8-bit precision. */
- (void)testAVIFCarriesASixteenBitRampBeyondTheEightBitFloor
{
	XCTSkipIf(!FxGripCompressionIsAvailable(FxGripCompressionAVIF), @"No AVIF encoder on this OS.");
	const NSUInteger width = 64, height = 64;
	NSMutableData *pixels = [NSMutableData dataWithLength:width * height * 2];
	uint16_t *values = pixels.mutableBytes;
	for (NSUInteger pixel = 0; pixel < width * height; pixel++) {
		values[pixel] = (uint16_t)((pixel * 65535) / (width * height - 1));
	}

	FxGripImageBuffer *buffer = [FxGripImageBuffer.alloc initWithBytes:pixels.bytes
															 rowBytes:width * 2 width:width height:height
															   format:FxGripPixelFormatGray16U
														  compression:FxGripCompressionAVIF
															  quality:0.95f];

	XCTAssertEqual(buffer.compression, FxGripCompressionAVIF);
	const uint16_t *actual = buffer.pixelData.bytes;
	NSUInteger maxDelta = 0;
	for (NSUInteger pixel = 0; pixel < width * height; pixel++) {
		NSUInteger delta = (NSUInteger)labs((long)values[pixel] - (long)actual[pixel]);
		if (delta > maxDelta) {
			maxDelta = delta;
		}
	}
	XCTAssertLessThan(maxDelta, 257u);
}

@end
