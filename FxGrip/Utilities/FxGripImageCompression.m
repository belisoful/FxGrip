//
//  FxGripImageCompression.m
//  FxGrip
//

#import "FxGripImageCompression.h"
#import <ImageIO/ImageIO.h>
#import <compression.h>

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
