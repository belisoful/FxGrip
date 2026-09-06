/*!
	@file       FxGripImageCompression.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripImageCompression
	@abstract   Implements the pixel-format descriptors, lossless codecs, and the compression envelope.
	@discussion Introduced in FxGrip 0.1.0. The format functions validate the packed channel count
	            and component type. The lossless codecs go through the system Compression library,
	            returning nil when a codec does not shrink the data. The envelope prefixes a
	            signed header that records the codec and original length, and its signature cannot
	            begin a binary property list.
*/

#import "FxGripImageCompression.h"
#import <ImageIO/ImageIO.h>
#import <compression.h>
#import <libkern/OSByteOrder.h>

NSString *const FxGripCompressionErrorDomain = @"FxGripCompressionErrorDomain";
const NSUInteger FxGripCompressionEnvelopeThresholdDefault = 4096;

// Envelope: 4-byte signature, 1-byte version, 1-byte codec, 8-byte little-endian
// uncompressed length, then the compressed payload. The signature cannot begin a binary
// property list ("bplist00"), so a raw pluginState blob is never mistaken for an envelope.
static const uint8_t kFxGripEnvelopeSignature[4] = { 'F', 'x', 'G', 'z' };
static const uint8_t kFxGripEnvelopeVersion = 1;
static const NSUInteger kFxGripEnvelopeHeaderLength = 14;

NSUInteger FxGripPixelFormatComponents(FxGripPixelFormat format)
{
	// The full field validates; masking would alias out-of-range channel counts onto
	// the valid ones.
	NSInteger channels = format >> 8;
	if (channels < 1 || channels > 4
		|| FxGripPixelFormatComponentType(format) == FxGripComponentTypeInvalid) {
		return 0;
	}
	return (NSUInteger)channels;
}

FxGripComponentType FxGripPixelFormatComponentType(FxGripPixelFormat format)
{
	NSInteger type = format & 0xFF;
	if (type < FxGripComponentTypeUInt8 || type > FxGripComponentTypeFloat32) {
		return FxGripComponentTypeInvalid;
	}
	return (FxGripComponentType)type;
}

NSUInteger FxGripPixelFormatBytesPerComponent(FxGripPixelFormat format)
{
	switch (FxGripPixelFormatComponentType(format)) {
		case FxGripComponentTypeUInt8:
			return 1;
		case FxGripComponentTypeUInt16:
		case FxGripComponentTypeFloat16:
			return 2;
		case FxGripComponentTypeUInt32:
		case FxGripComponentTypeFloat32:
			return 4;
		default:
			return 0;
	}
}

NSUInteger FxGripPixelFormatBytesPerPixel(FxGripPixelFormat format)
{
	return FxGripPixelFormatComponents(format) * FxGripPixelFormatBytesPerComponent(format);
}

BOOL FxGripPixelFormatHasAlpha(FxGripPixelFormat format)
{
	NSUInteger channels = FxGripPixelFormatComponents(format);
	return channels == 2 || channels == 4;
}

BOOL FxGripPixelFormatIsFloat(FxGripPixelFormat format)
{
	FxGripComponentType type = FxGripPixelFormatComponentType(format);
	return type == FxGripComponentTypeFloat16 || type == FxGripComponentTypeFloat32;
}

BOOL FxGripCompressionIsLossy(FxGripCompression compression)
{
	return compression == FxGripCompressionJPEG
		|| compression == FxGripCompressionHEIC
		|| compression == FxGripCompressionAVIF;
}

NSString *FxGripCompressionTypeIdentifier(FxGripCompression compression)
{
	switch (compression) {
		case FxGripCompressionJPEG:	return @"public.jpeg";
		case FxGripCompressionHEIC:	return @"public.heic";
		case FxGripCompressionAVIF:	return @"public.avif";
		default:					return nil;
	}
}

BOOL FxGripCompressionIsAvailable(FxGripCompression compression)
{
	NSString *identifier = FxGripCompressionTypeIdentifier(compression);
	if (identifier == nil) {
		switch (compression) {
			case FxGripCompressionNone:
			case FxGripCompressionLZFSE:
			case FxGripCompressionLZ4:
			case FxGripCompressionZlib:
			case FxGripCompressionLZMA:
				return YES;
			default:
				return NO;
		}
	}
	// The destination registry is the runtime source of truth for every image codec,
	// reached by identifier rather than linked symbol.
	static NSSet *encodableIdentifiers = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		NSArray *identifiers = CFBridgingRelease(CGImageDestinationCopyTypeIdentifiers());
		encodableIdentifiers = [NSSet setWithArray:identifiers ?: @[]];
	});
	return [encodableIdentifiers containsObject:identifier];
}

/*! The system Compression algorithm for a lossless codec; 0 for None or a lossy codec. */
static compression_algorithm FxGripCompressionAlgorithm(FxGripCompression compression)
{
	switch (compression) {
		case FxGripCompressionLZFSE:	return COMPRESSION_LZFSE;
		case FxGripCompressionLZ4:		return COMPRESSION_LZ4;
		case FxGripCompressionZlib:		return COMPRESSION_ZLIB;
		case FxGripCompressionLZMA:		return COMPRESSION_LZMA;
		default:						return 0;
	}
}

NSData *FxGripCompressedData(NSData *data, FxGripCompression compression)
{
	compression_algorithm algorithm = FxGripCompressionAlgorithm(compression);
	if (algorithm == 0 || data.length == 0) {
		return nil;
	}
	NSMutableData *destination = [NSMutableData dataWithLength:data.length];
	size_t written = compression_encode_buffer(destination.mutableBytes, destination.length,
											   data.bytes, data.length,
											   NULL, algorithm);
	// A zero result is a codec failure or output at least as large as the input; either
	// way the original is the better representation.
	if (written == 0 || written >= data.length) {
		return nil;
	}
	destination.length = written;
	return destination;
}

NSData *FxGripDecompressedData(NSData *data, FxGripCompression compression, NSUInteger uncompressedLength)
{
	if (compression == FxGripCompressionNone) {
		return data;
	}
	compression_algorithm algorithm = FxGripCompressionAlgorithm(compression);
	if (algorithm == 0 || data.length == 0 || uncompressedLength == 0) {
		return nil;
	}
	// One spare byte: a payload larger than the claimed length fills past it, so the
	// written count exposes an undersized claim instead of returning truncated data.
	NSMutableData *destination = [NSMutableData dataWithLength:uncompressedLength + 1];
	size_t written = compression_decode_buffer(destination.mutableBytes, destination.length,
											   data.bytes, data.length,
											   NULL, algorithm);
	if (written != uncompressedLength) {
		return nil;
	}
	destination.length = uncompressedLength;
	return destination;
}

NSData *FxGripEnvelopeCompressedData(NSData *data, FxGripCompression compression, NSUInteger minimumLength)
{
	if (data.length < minimumLength || FxGripCompressionIsLossy(compression)) {
		return data;
	}
	NSData *compressed = FxGripCompressedData(data, compression);
	if (compressed == nil) {
		return data;
	}
	NSMutableData *envelope = [NSMutableData dataWithCapacity:kFxGripEnvelopeHeaderLength + compressed.length];
	uint8_t header[kFxGripEnvelopeHeaderLength];
	memcpy(header, kFxGripEnvelopeSignature, sizeof(kFxGripEnvelopeSignature));
	header[4] = kFxGripEnvelopeVersion;
	header[5] = (uint8_t)compression;
	OSWriteLittleInt64(header, 6, (uint64_t)data.length);
	[envelope appendBytes:header length:sizeof(header)];
	[envelope appendData:compressed];
	return envelope;
}

/*! Sets a FxGripCompressionErrorDomain error and returns nil. */
static NSData *FxGripEnvelopeError(NSError **error, NSString *description)
{
	if (error) {
		*error = [NSError errorWithDomain:FxGripCompressionErrorDomain
									 code:-1
								 userInfo:@{ NSLocalizedDescriptionKey : description }];
	}
	return nil;
}

NSData *FxGripEnvelopeDecompressedData(NSData *data, NSError **error)
{
	if (data.length < kFxGripEnvelopeHeaderLength
		|| memcmp(data.bytes, kFxGripEnvelopeSignature, sizeof(kFxGripEnvelopeSignature)) != 0) {
		return data;
	}
	const uint8_t *header = data.bytes;
	if (header[4] != kFxGripEnvelopeVersion) {
		return FxGripEnvelopeError(error, [NSString stringWithFormat:@"Unsupported compression envelope version %u", header[4]]);
	}
	FxGripCompression compression = (FxGripCompression)header[5];
	uint64_t uncompressedLength = OSReadLittleInt64(header, 6);
	NSData *payload = [data subdataWithRange:NSMakeRange(kFxGripEnvelopeHeaderLength,
														 data.length - kFxGripEnvelopeHeaderLength)];
	NSData *restored = FxGripDecompressedData(payload, compression, (NSUInteger)uncompressedLength);
	if (restored == nil) {
		return FxGripEnvelopeError(error, @"Corrupt compression envelope payload");
	}
	return restored;
}
