//
//  FxGripImageCompressionTests.m
//  FxGripTests
//
//  Unit tests for the pixel-format helpers and the lossless codec wrappers: the component
//  geometry of the twenty packed formats, the round trip of each codec, and the nil returns
//  that tell a caller to keep the original bytes.
//
//  The lossy image codecs appear here only through the helpers that classify them and the
//  raw-data functions that refuse them; their encodes need image geometry and are covered by
//  FxGripImageBufferTests.
//
//  Compressed byte counts are not asserted; the codecs are free to change their output. The
//  tests assert round trips and length relations instead. Incompressible payloads come from
//  a fixed linear congruential sequence so every run sees the same bytes.
//

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripImageCompression.h>

static const FxGripCompression kCompressionTestCodecs[] = {
	FxGripCompressionLZFSE,
	FxGripCompressionLZ4,
	FxGripCompressionZlib,
	FxGripCompressionLZMA
};
static const NSUInteger kCompressionTestCodecCount = 4;

static const FxGripPixelFormat kCompressionTestFormats[] = {
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
static const NSUInteger kCompressionTestFormatCount = 20;

/*! The geometry every named format answers, written out rather than derived. */
typedef struct {
	FxGripPixelFormat	format;
	NSUInteger			channels;
	FxGripComponentType	componentType;
	NSUInteger			bytesPerComponent;
	BOOL				hasAlpha;
	BOOL				isFloat;
} FxGripCompressionTestFormatSpec;

static const FxGripCompressionTestFormatSpec kCompressionTestFormatSpecs[] = {
	{FxGripPixelFormatGray8U,		1, FxGripComponentTypeUInt8,	1, NO,	NO},
	{FxGripPixelFormatGray16U,		1, FxGripComponentTypeUInt16,	2, NO,	NO},
	{FxGripPixelFormatGray32U,		1, FxGripComponentTypeUInt32,	4, NO,	NO},
	{FxGripPixelFormatGray16F,		1, FxGripComponentTypeFloat16,	2, NO,	YES},
	{FxGripPixelFormatGray32F,		1, FxGripComponentTypeFloat32,	4, NO,	YES},

	{FxGripPixelFormatGrayAlpha8U,	2, FxGripComponentTypeUInt8,	1, YES,	NO},
	{FxGripPixelFormatGrayAlpha16U,	2, FxGripComponentTypeUInt16,	2, YES,	NO},
	{FxGripPixelFormatGrayAlpha32U,	2, FxGripComponentTypeUInt32,	4, YES,	NO},
	{FxGripPixelFormatGrayAlpha16F,	2, FxGripComponentTypeFloat16,	2, YES,	YES},
	{FxGripPixelFormatGrayAlpha32F,	2, FxGripComponentTypeFloat32,	4, YES,	YES},

	{FxGripPixelFormatRGB8U,		3, FxGripComponentTypeUInt8,	1, NO,	NO},
	{FxGripPixelFormatRGB16U,		3, FxGripComponentTypeUInt16,	2, NO,	NO},
	{FxGripPixelFormatRGB32U,		3, FxGripComponentTypeUInt32,	4, NO,	NO},
	{FxGripPixelFormatRGB16F,		3, FxGripComponentTypeFloat16,	2, NO,	YES},
	{FxGripPixelFormatRGB32F,		3, FxGripComponentTypeFloat32,	4, NO,	YES},

	{FxGripPixelFormatRGBA8U,		4, FxGripComponentTypeUInt8,	1, YES,	NO},
	{FxGripPixelFormatRGBA16U,		4, FxGripComponentTypeUInt16,	2, YES,	NO},
	{FxGripPixelFormatRGBA32U,		4, FxGripComponentTypeUInt32,	4, YES,	NO},
	{FxGripPixelFormatRGBA16F,		4, FxGripComponentTypeFloat16,	2, YES,	YES},
	{FxGripPixelFormatRGBA32F,		4, FxGripComponentTypeFloat32,	4, YES,	YES}
};
static const NSUInteger kCompressionTestFormatSpecCount = 20;

/*! Packed values no named format occupies: a channel count outside 1...4 or a component
	type outside the enumeration. */
static const FxGripPixelFormat kCompressionTestMalformedFormats[] = {
	FxGripPixelFormatInvalid,
	(FxGripPixelFormat)99,
	FxGripPixelFormatMake(0, FxGripComponentTypeUInt8),
	FxGripPixelFormatMake(5, FxGripComponentTypeUInt8),
	FxGripPixelFormatMake(6, FxGripComponentTypeFloat32),
	FxGripPixelFormatMake(15, FxGripComponentTypeUInt16),
	FxGripPixelFormatMake(1, FxGripComponentTypeInvalid),
	FxGripPixelFormatMake(3, (FxGripComponentType)6),
	FxGripPixelFormatMake(4, (FxGripComponentType)255)
};
static const NSUInteger kCompressionTestMalformedFormatCount = 9;

/*! The subset whose component-type field alone is out of range. */
static const FxGripPixelFormat kCompressionTestMalformedTypes[] = {
	FxGripPixelFormatMake(1, FxGripComponentTypeInvalid),
	FxGripPixelFormatMake(2, (FxGripComponentType)6),
	FxGripPixelFormatMake(3, (FxGripComponentType)7),
	FxGripPixelFormatMake(4, (FxGripComponentType)255)
};
static const NSUInteger kCompressionTestMalformedTypeCount = 4;

static const FxGripCompression kCompressionTestLossyCodecs[] = {
	FxGripCompressionJPEG,
	FxGripCompressionHEIC,
	FxGripCompressionAVIF
};
static const NSUInteger kCompressionTestLossyCodecCount = 3;

/*! A constant-byte payload; every codec shrinks it. */
static NSData *FxGripCompressionTestCompressibleData(NSUInteger length)
{
	NSMutableData *data = [NSMutableData dataWithLength:length];
	memset(data.mutableBytes, 0x5A, length);
	return data;
}

/*! A deterministic pseudo-random payload; no codec shrinks it. */
static NSData *FxGripCompressionTestIncompressibleData(NSUInteger length)
{
	NSMutableData *data = [NSMutableData dataWithLength:length];
	uint8_t *bytes = data.mutableBytes;
	uint32_t state = 0x12345678u;
	for (NSUInteger index = 0; index < length; index++) {
		state = state * 1664525u + 1013904223u;
		bytes[index] = (uint8_t)(state >> 24);
	}
	return data;
}


@interface FxGripImageCompressionTests : XCTestCase
@end

@implementation FxGripImageCompressionTests

#pragma mark Format geometry

- (void)testComponentsAreFourForTheAlphaFormatsAndThreeOtherwise
{
	XCTAssertEqual(FxGripPixelFormatComponents(FxGripPixelFormatRGBA32F), 4u);
	XCTAssertEqual(FxGripPixelFormatComponents(FxGripPixelFormatRGBA16F), 4u);
	XCTAssertEqual(FxGripPixelFormatComponents(FxGripPixelFormatRGBA32U), 4u);
	XCTAssertEqual(FxGripPixelFormatComponents(FxGripPixelFormatRGBA16U), 4u);
	XCTAssertEqual(FxGripPixelFormatComponents(FxGripPixelFormatRGBA8U), 4u);

	XCTAssertEqual(FxGripPixelFormatComponents(FxGripPixelFormatRGB32F), 3u);
	XCTAssertEqual(FxGripPixelFormatComponents(FxGripPixelFormatRGB16F), 3u);
	XCTAssertEqual(FxGripPixelFormatComponents(FxGripPixelFormatRGB32U), 3u);
	XCTAssertEqual(FxGripPixelFormatComponents(FxGripPixelFormatRGB16U), 3u);
	XCTAssertEqual(FxGripPixelFormatComponents(FxGripPixelFormatRGB8U), 3u);
}

- (void)testComponentsAreZeroForAnUnknownFormat
{
	XCTAssertEqual(FxGripPixelFormatComponents(FxGripPixelFormatInvalid), 0u);
	XCTAssertEqual(FxGripPixelFormatComponents((FxGripPixelFormat)99), 0u);
}

- (void)testBytesPerComponentFollowTheComponentWidth
{
	XCTAssertEqual(FxGripPixelFormatBytesPerComponent(FxGripPixelFormatRGBA32F), 4u);
	XCTAssertEqual(FxGripPixelFormatBytesPerComponent(FxGripPixelFormatRGB32F), 4u);
	XCTAssertEqual(FxGripPixelFormatBytesPerComponent(FxGripPixelFormatRGBA32U), 4u);
	XCTAssertEqual(FxGripPixelFormatBytesPerComponent(FxGripPixelFormatRGB32U), 4u);

	XCTAssertEqual(FxGripPixelFormatBytesPerComponent(FxGripPixelFormatRGBA16F), 2u);
	XCTAssertEqual(FxGripPixelFormatBytesPerComponent(FxGripPixelFormatRGB16F), 2u);
	XCTAssertEqual(FxGripPixelFormatBytesPerComponent(FxGripPixelFormatRGBA16U), 2u);
	XCTAssertEqual(FxGripPixelFormatBytesPerComponent(FxGripPixelFormatRGB16U), 2u);

	XCTAssertEqual(FxGripPixelFormatBytesPerComponent(FxGripPixelFormatRGBA8U), 1u);
	XCTAssertEqual(FxGripPixelFormatBytesPerComponent(FxGripPixelFormatRGB8U), 1u);
}

- (void)testBytesPerComponentIsZeroForAnUnknownFormat
{
	XCTAssertEqual(FxGripPixelFormatBytesPerComponent(FxGripPixelFormatInvalid), 0u);
	XCTAssertEqual(FxGripPixelFormatBytesPerComponent((FxGripPixelFormat)99), 0u);
}

- (void)testBytesPerPixelIsComponentsTimesTheComponentWidth
{
	for (NSUInteger index = 0; index < kCompressionTestFormatCount; index++) {
		FxGripPixelFormat format = kCompressionTestFormats[index];
		XCTAssertEqual(FxGripPixelFormatBytesPerPixel(format),
					   FxGripPixelFormatComponents(format) * FxGripPixelFormatBytesPerComponent(format),
					   @"format %ld", (long)format);
	}
}

- (void)testBytesPerPixelOfTheWidestAndNarrowestFormats
{
	XCTAssertEqual(FxGripPixelFormatBytesPerPixel(FxGripPixelFormatRGBA32F), 16u);
	XCTAssertEqual(FxGripPixelFormatBytesPerPixel(FxGripPixelFormatRGB32U), 12u);
	XCTAssertEqual(FxGripPixelFormatBytesPerPixel(FxGripPixelFormatRGBA16U), 8u);
	XCTAssertEqual(FxGripPixelFormatBytesPerPixel(FxGripPixelFormatRGB16F), 6u);
	XCTAssertEqual(FxGripPixelFormatBytesPerPixel(FxGripPixelFormatRGBA8U), 4u);
	XCTAssertEqual(FxGripPixelFormatBytesPerPixel(FxGripPixelFormatRGB8U), 3u);
}

- (void)testBytesPerPixelIsZeroForAnUnknownFormat
{
	XCTAssertEqual(FxGripPixelFormatBytesPerPixel(FxGripPixelFormatInvalid), 0u);
	XCTAssertEqual(FxGripPixelFormatBytesPerPixel((FxGripPixelFormat)99), 0u);
}

- (void)testHasAlphaIsTrueOnlyForTheTwoAndFourChannelFormats
{
	for (NSUInteger index = 0; index < kCompressionTestFormatCount; index++) {
		FxGripPixelFormat format = kCompressionTestFormats[index];
		NSUInteger channels = FxGripPixelFormatComponents(format);
		XCTAssertEqual(FxGripPixelFormatHasAlpha(format),
					   channels == 2 || channels == 4,
					   @"format %ld", (long)format);
	}
	XCTAssertFalse(FxGripPixelFormatHasAlpha(FxGripPixelFormatInvalid));
}

- (void)testIsFloatIsTrueOnlyForTheFloatFormats
{
	XCTAssertTrue(FxGripPixelFormatIsFloat(FxGripPixelFormatRGBA32F));
	XCTAssertTrue(FxGripPixelFormatIsFloat(FxGripPixelFormatRGB32F));
	XCTAssertTrue(FxGripPixelFormatIsFloat(FxGripPixelFormatRGBA16F));
	XCTAssertTrue(FxGripPixelFormatIsFloat(FxGripPixelFormatRGB16F));

	XCTAssertFalse(FxGripPixelFormatIsFloat(FxGripPixelFormatRGBA32U));
	XCTAssertFalse(FxGripPixelFormatIsFloat(FxGripPixelFormatRGB32U));
	XCTAssertFalse(FxGripPixelFormatIsFloat(FxGripPixelFormatRGBA16U));
	XCTAssertFalse(FxGripPixelFormatIsFloat(FxGripPixelFormatRGB16U));
	XCTAssertFalse(FxGripPixelFormatIsFloat(FxGripPixelFormatRGBA8U));
	XCTAssertFalse(FxGripPixelFormatIsFloat(FxGripPixelFormatRGB8U));
	XCTAssertFalse(FxGripPixelFormatIsFloat(FxGripPixelFormatInvalid));
}

#pragma mark The packed format table

- (void)testEveryNamedFormatReportsItsChannelCount
{
	for (NSUInteger index = 0; index < kCompressionTestFormatSpecCount; index++) {
		FxGripCompressionTestFormatSpec spec = kCompressionTestFormatSpecs[index];

		XCTAssertEqual(FxGripPixelFormatComponents(spec.format), spec.channels,
					   @"format %ld", (long)spec.format);
	}
}

- (void)testEveryNamedFormatReportsItsComponentType
{
	for (NSUInteger index = 0; index < kCompressionTestFormatSpecCount; index++) {
		FxGripCompressionTestFormatSpec spec = kCompressionTestFormatSpecs[index];

		XCTAssertEqual(FxGripPixelFormatComponentType(spec.format), spec.componentType,
					   @"format %ld", (long)spec.format);
	}
}

- (void)testEveryNamedFormatReportsItsBytesPerComponent
{
	for (NSUInteger index = 0; index < kCompressionTestFormatSpecCount; index++) {
		FxGripCompressionTestFormatSpec spec = kCompressionTestFormatSpecs[index];

		XCTAssertEqual(FxGripPixelFormatBytesPerComponent(spec.format), spec.bytesPerComponent,
					   @"format %ld", (long)spec.format);
	}
}

- (void)testEveryNamedFormatReportsItsBytesPerPixel
{
	for (NSUInteger index = 0; index < kCompressionTestFormatSpecCount; index++) {
		FxGripCompressionTestFormatSpec spec = kCompressionTestFormatSpecs[index];

		XCTAssertEqual(FxGripPixelFormatBytesPerPixel(spec.format),
					   spec.channels * spec.bytesPerComponent,
					   @"format %ld", (long)spec.format);
	}
}

- (void)testEveryNamedFormatReportsWhetherItCarriesAlpha
{
	for (NSUInteger index = 0; index < kCompressionTestFormatSpecCount; index++) {
		FxGripCompressionTestFormatSpec spec = kCompressionTestFormatSpecs[index];

		XCTAssertEqual(FxGripPixelFormatHasAlpha(spec.format), spec.hasAlpha,
					   @"format %ld", (long)spec.format);
	}
}

- (void)testEveryNamedFormatReportsWhetherItsComponentsAreFloat
{
	for (NSUInteger index = 0; index < kCompressionTestFormatSpecCount; index++) {
		FxGripCompressionTestFormatSpec spec = kCompressionTestFormatSpecs[index];

		XCTAssertEqual(FxGripPixelFormatIsFloat(spec.format), spec.isFloat,
					   @"format %ld", (long)spec.format);
	}
}

- (void)testPixelFormatMakeProducesTheNamedConstants
{
	for (NSUInteger index = 0; index < kCompressionTestFormatSpecCount; index++) {
		FxGripCompressionTestFormatSpec spec = kCompressionTestFormatSpecs[index];

		XCTAssertEqual(FxGripPixelFormatMake(spec.channels, spec.componentType), spec.format,
					   @"format %ld", (long)spec.format);
	}
}

- (void)testTheNamedFormatsAreDistinct
{
	NSMutableSet<NSNumber *> *values = [NSMutableSet set];
	for (NSUInteger index = 0; index < kCompressionTestFormatSpecCount; index++) {
		[values addObject:@(kCompressionTestFormatSpecs[index].format)];
	}

	XCTAssertEqual(values.count, kCompressionTestFormatSpecCount);
	XCTAssertFalse([values containsObject:@(FxGripPixelFormatInvalid)]);
}

- (void)testTheShaderAliasesNameTheGrayFloatFormats
{
	XCTAssertEqual(FxGripPixelFormatR16F, FxGripPixelFormatGray16F);
	XCTAssertEqual(FxGripPixelFormatR32F, FxGripPixelFormatGray32F);
	XCTAssertEqual(FxGripPixelFormatRA16F, FxGripPixelFormatGrayAlpha16F);
	XCTAssertEqual(FxGripPixelFormatRA32F, FxGripPixelFormatGrayAlpha32F);
}

- (void)testMalformedPackedValuesHaveNoPixelGeometry
{
	for (NSUInteger index = 0; index < kCompressionTestMalformedFormatCount; index++) {
		FxGripPixelFormat format = kCompressionTestMalformedFormats[index];

		XCTAssertEqual(FxGripPixelFormatComponents(format), 0u, @"format %ld", (long)format);
		XCTAssertEqual(FxGripPixelFormatBytesPerPixel(format), 0u, @"format %ld", (long)format);
		XCTAssertFalse(FxGripPixelFormatHasAlpha(format), @"format %ld", (long)format);
	}
}

- (void)testAComponentTypeOutsideTheEnumerationIsInvalid
{
	for (NSUInteger index = 0; index < kCompressionTestMalformedTypeCount; index++) {
		FxGripPixelFormat format = kCompressionTestMalformedTypes[index];

		XCTAssertEqual(FxGripPixelFormatComponentType(format), FxGripComponentTypeInvalid,
					   @"format %ld", (long)format);
		XCTAssertEqual(FxGripPixelFormatBytesPerComponent(format), 0u, @"format %ld", (long)format);
		XCTAssertFalse(FxGripPixelFormatIsFloat(format), @"format %ld", (long)format);
	}
}

/*!
	A channel count outside 1...4 is malformed, so every helper answers zero. The channel
	field is read through a four-bit mask, so counts 17...20 alias onto 1...4 and answer as
	though the value named a real format.
*/
- (void)testAChannelCountAboveFifteenIsRejectedRatherThanMasked
{

	for (NSUInteger channels = 16; channels <= 20; channels++) {
		FxGripPixelFormat format = FxGripPixelFormatMake(channels, FxGripComponentTypeUInt8);

		XCTAssertEqual(FxGripPixelFormatComponents(format), 0u, @"channels %lu", (unsigned long)channels);
		XCTAssertEqual(FxGripPixelFormatBytesPerPixel(format), 0u, @"channels %lu", (unsigned long)channels);
	}
}

#pragma mark Codec classification

- (void)testOnlyTheImageCodecsAreLossy
{
	XCTAssertTrue(FxGripCompressionIsLossy(FxGripCompressionJPEG));
	XCTAssertTrue(FxGripCompressionIsLossy(FxGripCompressionHEIC));

	XCTAssertFalse(FxGripCompressionIsLossy(FxGripCompressionNone));
	XCTAssertFalse(FxGripCompressionIsLossy(FxGripCompressionLZFSE));
	XCTAssertFalse(FxGripCompressionIsLossy(FxGripCompressionLZ4));
	XCTAssertFalse(FxGripCompressionIsLossy(FxGripCompressionZlib));
	XCTAssertFalse(FxGripCompressionIsLossy(FxGripCompressionLZMA));
	XCTAssertFalse(FxGripCompressionIsLossy((FxGripCompression)99));
}

#pragma mark Compression

- (void)testEveryCodecRoundTripsCompressibleData
{
	NSData *original = FxGripCompressionTestCompressibleData(8192);

	for (NSUInteger index = 0; index < kCompressionTestCodecCount; index++) {
		FxGripCompression codec = kCompressionTestCodecs[index];
		NSData *compressed = FxGripCompressedData(original, codec);

		XCTAssertNotNil(compressed, @"codec %ld", (long)codec);
		XCTAssertEqualObjects(FxGripDecompressedData(compressed, codec, original.length), original,
							  @"codec %ld", (long)codec);
	}
}

- (void)testEveryCodecShrinksCompressibleData
{
	NSData *original = FxGripCompressionTestCompressibleData(8192);

	for (NSUInteger index = 0; index < kCompressionTestCodecCount; index++) {
		FxGripCompression codec = kCompressionTestCodecs[index];

		XCTAssertLessThan(FxGripCompressedData(original, codec).length, original.length,
						  @"codec %ld", (long)codec);
	}
}

- (void)testCompressionNoneReturnsNil
{
	XCTAssertNil(FxGripCompressedData(FxGripCompressionTestCompressibleData(8192), FxGripCompressionNone));
}

- (void)testAnUnknownCodecReturnsNilFromCompression
{
	XCTAssertNil(FxGripCompressedData(FxGripCompressionTestCompressibleData(8192), (FxGripCompression)99));
}

/*! The image codecs need width, height, and format; only FxGripImageBuffer can supply them. */
- (void)testTheRawCompressorRejectsTheLossyImageCodecs
{
	NSData *original = FxGripCompressionTestCompressibleData(8192);

	for (NSUInteger index = 0; index < kCompressionTestLossyCodecCount; index++) {
		XCTAssertNil(FxGripCompressedData(original, kCompressionTestLossyCodecs[index]),
					 @"codec %ld", (long)kCompressionTestLossyCodecs[index]);
	}
}

- (void)testTheRawDecompressorRejectsTheLossyImageCodecs
{
	NSData *original = FxGripCompressionTestCompressibleData(8192);

	for (NSUInteger index = 0; index < kCompressionTestLossyCodecCount; index++) {
		XCTAssertNil(FxGripDecompressedData(original, kCompressionTestLossyCodecs[index], original.length),
					 @"codec %ld", (long)kCompressionTestLossyCodecs[index]);
	}
}

- (void)testCompressingEmptyDataReturnsNil
{
	for (NSUInteger index = 0; index < kCompressionTestCodecCount; index++) {
		XCTAssertNil(FxGripCompressedData([NSData data], kCompressionTestCodecs[index]),
					 @"codec %ld", (long)kCompressionTestCodecs[index]);
	}
}

- (void)testIncompressibleDataReturnsNilFromEveryCodec
{
	NSData *noise = FxGripCompressionTestIncompressibleData(256);

	for (NSUInteger index = 0; index < kCompressionTestCodecCount; index++) {
		XCTAssertNil(FxGripCompressedData(noise, kCompressionTestCodecs[index]),
					 @"codec %ld", (long)kCompressionTestCodecs[index]);
	}
}

- (void)testAShortIncompressiblePayloadReturnsNilRatherThanGrowing
{
	NSData *noise = FxGripCompressionTestIncompressibleData(8);

	for (NSUInteger index = 0; index < kCompressionTestCodecCount; index++) {
		XCTAssertNil(FxGripCompressedData(noise, kCompressionTestCodecs[index]),
					 @"codec %ld", (long)kCompressionTestCodecs[index]);
	}
}

#pragma mark Decompression

- (void)testDecompressionNonePassesTheDataThrough
{
	NSData *original = FxGripCompressionTestCompressibleData(64);

	XCTAssertEqualObjects(FxGripDecompressedData(original, FxGripCompressionNone, original.length), original);
}

- (void)testDecompressionNoneIgnoresTheStatedLength
{
	NSData *original = FxGripCompressionTestCompressibleData(64);

	XCTAssertEqualObjects(FxGripDecompressedData(original, FxGripCompressionNone, 999), original);
}

- (void)testDecompressionWithAnUnknownCodecReturnsNil
{
	NSData *original = FxGripCompressionTestCompressibleData(64);

	XCTAssertNil(FxGripDecompressedData(original, (FxGripCompression)99, original.length));
}

- (void)testDecompressionOfEmptyDataReturnsNil
{
	XCTAssertNil(FxGripDecompressedData([NSData data], FxGripCompressionLZFSE, 64));
}

- (void)testDecompressionWithAZeroLengthReturnsNil
{
	NSData *compressed = FxGripCompressedData(FxGripCompressionTestCompressibleData(8192), FxGripCompressionLZFSE);

	XCTAssertNil(FxGripDecompressedData(compressed, FxGripCompressionLZFSE, 0));
}

- (void)testDecompressionWithALengthAboveTheOriginalReturnsNil
{
	NSData *original = FxGripCompressionTestCompressibleData(8192);

	for (NSUInteger index = 0; index < kCompressionTestCodecCount; index++) {
		FxGripCompression codec = kCompressionTestCodecs[index];
		NSData *compressed = FxGripCompressedData(original, codec);

		XCTAssertNil(FxGripDecompressedData(compressed, codec, original.length * 2),
					 @"codec %ld", (long)codec);
	}
}

/*! An undersized length claim is a mismatch: the spare destination byte exposes the
	overrun, so no codec returns truncated pixels. */
- (void)testDecompressionWithALengthBelowTheOriginalReturnsNil
{
	NSData *original = FxGripCompressionTestCompressibleData(8192);

	for (NSUInteger index = 0; index < kCompressionTestCodecCount; index++) {
		FxGripCompression codec = kCompressionTestCodecs[index];
		NSData *compressed = FxGripCompressedData(original, codec);

		XCTAssertNil(FxGripDecompressedData(compressed, codec, original.length / 2),
					 @"codec %ld", (long)codec);
	}
}

- (void)testDecompressionWithTheWrongCodecReturnsNil
{
	NSData *original = FxGripCompressionTestCompressibleData(8192);
	NSData *compressed = FxGripCompressedData(original, FxGripCompressionLZFSE);

	XCTAssertNil(FxGripDecompressedData(compressed, FxGripCompressionLZMA, original.length));
}


#pragma mark Availability

- (void)testTheBufferCodecsAreAlwaysAvailableAndJPEGAndHEICOnEverySupportedOS
{
	XCTAssertTrue(FxGripCompressionIsAvailable(FxGripCompressionNone));
	XCTAssertTrue(FxGripCompressionIsAvailable(FxGripCompressionLZFSE));
	XCTAssertTrue(FxGripCompressionIsAvailable(FxGripCompressionLZ4));
	XCTAssertTrue(FxGripCompressionIsAvailable(FxGripCompressionZlib));
	XCTAssertTrue(FxGripCompressionIsAvailable(FxGripCompressionLZMA));
	XCTAssertTrue(FxGripCompressionIsAvailable(FxGripCompressionJPEG));
	XCTAssertTrue(FxGripCompressionIsAvailable(FxGripCompressionHEIC));
	XCTAssertFalse(FxGripCompressionIsAvailable((FxGripCompression)99));
}

- (void)testTheLossyCodecsNameTheirTypeIdentifiersAndTheBufferCodecsHaveNone
{
	XCTAssertEqualObjects(FxGripCompressionTypeIdentifier(FxGripCompressionJPEG), @"public.jpeg");
	XCTAssertEqualObjects(FxGripCompressionTypeIdentifier(FxGripCompressionHEIC), @"public.heic");
	XCTAssertEqualObjects(FxGripCompressionTypeIdentifier(FxGripCompressionAVIF), @"public.avif");
	XCTAssertNil(FxGripCompressionTypeIdentifier(FxGripCompressionNone));
	XCTAssertNil(FxGripCompressionTypeIdentifier(FxGripCompressionLZFSE));
	XCTAssertNil(FxGripCompressionTypeIdentifier(FxGripCompressionLZMA));
}

/*! AVIF is answered by the OS; whatever the answer, it is stable across calls. */
- (void)testAVIFAvailabilityIsStable
{
	BOOL first = FxGripCompressionIsAvailable(FxGripCompressionAVIF);

	XCTAssertEqual(FxGripCompressionIsAvailable(FxGripCompressionAVIF), first);
}

#pragma mark Compression envelope

- (void)testEnvelopeRoundTripsCompressibleDataThroughEveryCodec
{
	NSData *original = FxGripCompressionTestCompressibleData(8192);
	for (NSUInteger index = 0; index < kCompressionTestCodecCount; index++) {
		FxGripCompression codec = kCompressionTestCodecs[index];
		NSData *envelope = FxGripEnvelopeCompressedData(original, codec, 0);
		XCTAssertLessThan(envelope.length, original.length, @"codec %ld should wrap a smaller payload", (long)codec);

		NSError *error = nil;
		NSData *restored = FxGripEnvelopeDecompressedData(envelope, &error);
		XCTAssertNil(error);
		XCTAssertEqualObjects(restored, original, @"codec %ld should restore the original", (long)codec);
	}
}

- (void)testEnvelopeLeavesDataBelowTheThresholdUncompressed
{
	NSData *original = FxGripCompressionTestCompressibleData(4096);
	NSData *result = FxGripEnvelopeCompressedData(original, FxGripCompressionLZFSE, 8192);

	XCTAssertEqualObjects(result, original, @"a payload below the threshold passes through unchanged");
}

- (void)testEnvelopeCompressesDataAtOrAboveTheThreshold
{
	NSData *original = FxGripCompressionTestCompressibleData(8192);
	NSData *result = FxGripEnvelopeCompressedData(original, FxGripCompressionLZFSE, 8192);

	XCTAssertLessThan(result.length, original.length);
	XCTAssertNotEqualObjects(result, original);
}

- (void)testEnvelopeLeavesIncompressibleDataUncompressed
{
	NSData *noise = FxGripCompressionTestIncompressibleData(8192);
	NSData *result = FxGripEnvelopeCompressedData(noise, FxGripCompressionLZFSE, 0);

	XCTAssertEqualObjects(result, noise, @"noise the codec cannot shrink stays raw with no envelope");
}

- (void)testEnvelopeLeavesDataUncompressedForNoneAndLossyCodecs
{
	NSData *original = FxGripCompressionTestCompressibleData(8192);

	XCTAssertEqualObjects(FxGripEnvelopeCompressedData(original, FxGripCompressionNone, 0), original);
	XCTAssertEqualObjects(FxGripEnvelopeCompressedData(original, FxGripCompressionJPEG, 0), original);
}

/*! A raw payload has no envelope signature, so the decoder returns it untouched. */
- (void)testEnvelopeDecompressPassesThroughUnwrappedData
{
	NSData *original = FxGripCompressionTestCompressibleData(8192);

	NSError *error = nil;
	NSData *result = FxGripEnvelopeDecompressedData(original, &error);
	XCTAssertNil(error);
	XCTAssertEqualObjects(result, original);
}

/*! A binary property list begins with "bplist00"; it must not be read as an envelope. */
- (void)testEnvelopeDecompressPassesThroughABinaryPropertyList
{
	NSDictionary *root = @{ @"key" : @"value" };
	NSError *error = nil;
	NSData *plist = [NSPropertyListSerialization dataWithPropertyList:root
															  format:NSPropertyListBinaryFormat_v1_0
															 options:0
															   error:&error];
	XCTAssertNotNil(plist);

	NSData *result = FxGripEnvelopeDecompressedData(plist, &error);
	XCTAssertNil(error);
	XCTAssertEqualObjects(result, plist);
}

- (void)testEnvelopeDecompressReportsAnErrorOnACorruptPayload
{
	NSData *original = FxGripCompressionTestCompressibleData(8192);
	NSMutableData *envelope = [FxGripEnvelopeCompressedData(original, FxGripCompressionLZFSE, 0) mutableCopy];
	XCTAssertGreaterThan(envelope.length, 16u);
	// Corrupt a payload byte past the 14-byte header.
	((uint8_t *)envelope.mutableBytes)[envelope.length - 1] ^= 0xFF;

	NSError *error = nil;
	NSData *result = FxGripEnvelopeDecompressedData(envelope, &error);
	XCTAssertNil(result);
	XCTAssertNotNil(error);
	XCTAssertEqualObjects(error.domain, FxGripCompressionErrorDomain);
}

- (void)testEnvelopeDecompressReportsAnErrorOnAnUnknownVersion
{
	NSData *original = FxGripCompressionTestCompressibleData(8192);
	NSMutableData *envelope = [FxGripEnvelopeCompressedData(original, FxGripCompressionLZFSE, 0) mutableCopy];
	((uint8_t *)envelope.mutableBytes)[4] = 0xFE;

	NSError *error = nil;
	NSData *result = FxGripEnvelopeDecompressedData(envelope, &error);
	XCTAssertNil(result);
	XCTAssertNotNil(error);
	XCTAssertEqualObjects(error.domain, FxGripCompressionErrorDomain);
}

- (void)testEnvelopeDecompressToleratesANullErrorOnCorruptData
{
	NSData *original = FxGripCompressionTestCompressibleData(8192);
	NSMutableData *envelope = [FxGripEnvelopeCompressedData(original, FxGripCompressionLZFSE, 0) mutableCopy];
	((uint8_t *)envelope.mutableBytes)[envelope.length - 1] ^= 0xFF;

	XCTAssertNil(FxGripEnvelopeDecompressedData(envelope, NULL));
}

@end
