//
//  FxGripLiveFrameTests.m
//  FxGripTests
//
//  Unit tests for the published live frame: the supported pixel-format table, the tight
//  repacking of strided rows, the format and size descriptions, the CGImage built from
//  integer and float layouts, and the texture, CGImage, and image-buffer constructors.
//
//  The test bundle links only FxGrip and XCTest. Metal and CoreGraphics entry points are
//  reached through the loaded images rather than a link-time reference.
//

#import <XCTest/XCTest.h>
#import <dlfcn.h>
#import <FxGrip/FxGripLiveFrame.h>
#import <FxGrip/FxGripImageBuffer.h>
#import <FxGrip/FxGripImageCompression.h>

typedef void *(*FxGripLiveFrameTestCreateDevice)(void);
typedef size_t (*FxGripLiveFrameTestImageSize)(CGImageRef);

static FxGripLiveFrameTestImageSize FxGripLiveFrameTestSymbol(const char *name)
{
	return (FxGripLiveFrameTestImageSize)dlsym(RTLD_DEFAULT, name);
}

@interface FxGripLiveFrameTests : XCTestCase
@end

@implementation FxGripLiveFrameTests

#pragma mark Fixtures

/*! RGBA8 pixels whose bytes encode their own coordinates, so a repacked row is checkable. */
- (NSData *)rgba8PixelsForWidth:(NSUInteger)width height:(NSUInteger)height
{
	NSMutableData *pixels = [NSMutableData dataWithLength:width * height * 4];
	uint8_t *bytes = pixels.mutableBytes;
	for (NSUInteger y = 0; y < height; y++) {
		for (NSUInteger x = 0; x < width; x++) {
			uint8_t *pixel = bytes + (y * width + x) * 4;
			pixel[0] = (uint8_t)x;
			pixel[1] = (uint8_t)y;
			pixel[2] = (uint8_t)(x + y);
			pixel[3] = 255;
		}
	}
	return pixels;
}

- (id<MTLDevice>)metalDevice
{
	FxGripLiveFrameTestCreateDevice create =
		(FxGripLiveFrameTestCreateDevice)dlsym(RTLD_DEFAULT, "MTLCreateSystemDefaultDevice");
	if (create == NULL) {
		return nil;
	}
	return (__bridge_transfer id<MTLDevice>)create();
}

- (id<MTLTexture>)textureWithDevice:(id<MTLDevice>)device
							 format:(MTLPixelFormat)format
							  width:(NSUInteger)width
							 height:(NSUInteger)height
{
	Class descriptorClass = NSClassFromString(@"MTLTextureDescriptor");
	MTLTextureDescriptor *descriptor = [descriptorClass texture2DDescriptorWithPixelFormat:format
																					width:width
																				   height:height
																				mipmapped:NO];
	descriptor.storageMode = MTLStorageModeShared;
	return [device newTextureWithDescriptor:descriptor];
}

#pragma mark Formats

- (void)testTheSupportedFormatsAreTheRGBABGRAAndSingleChannelFamilies
{
	XCTAssertTrue([FxGripLiveFrame supportsPixelFormat:MTLPixelFormatRGBA8Unorm]);
	XCTAssertTrue([FxGripLiveFrame supportsPixelFormat:MTLPixelFormatRGBA8Unorm_sRGB]);
	XCTAssertTrue([FxGripLiveFrame supportsPixelFormat:MTLPixelFormatBGRA8Unorm]);
	XCTAssertTrue([FxGripLiveFrame supportsPixelFormat:MTLPixelFormatBGRA8Unorm_sRGB]);
	XCTAssertTrue([FxGripLiveFrame supportsPixelFormat:MTLPixelFormatRGBA16Unorm]);
	XCTAssertTrue([FxGripLiveFrame supportsPixelFormat:MTLPixelFormatRGBA16Float]);
	XCTAssertTrue([FxGripLiveFrame supportsPixelFormat:MTLPixelFormatRGBA32Float]);
	XCTAssertTrue([FxGripLiveFrame supportsPixelFormat:MTLPixelFormatR8Unorm]);
	XCTAssertTrue([FxGripLiveFrame supportsPixelFormat:MTLPixelFormatR16Float]);
	XCTAssertTrue([FxGripLiveFrame supportsPixelFormat:MTLPixelFormatR32Float]);

	XCTAssertFalse([FxGripLiveFrame supportsPixelFormat:MTLPixelFormatRG8Unorm]);
	XCTAssertFalse([FxGripLiveFrame supportsPixelFormat:MTLPixelFormatRGBA32Uint]);
	XCTAssertFalse([FxGripLiveFrame supportsPixelFormat:MTLPixelFormatDepth32Float]);
	XCTAssertFalse([FxGripLiveFrame supportsPixelFormat:MTLPixelFormatInvalid]);
}

- (void)testAnUnsupportedFormatMakesNoFrame
{
	uint8_t pixels[16] = {0};
	XCTAssertNil([FxGripLiveFrame frameWithBytes:pixels rowBytes:8 width:2 height:2 pixelFormat:MTLPixelFormatRG8Unorm]);
}

- (void)testZeroDimensionsANilSourceOrAShortStrideMakeNoFrame
{
	uint8_t pixels[64] = {0};
	XCTAssertNil([FxGripLiveFrame frameWithBytes:pixels rowBytes:16 width:0 height:2 pixelFormat:MTLPixelFormatRGBA8Unorm]);
	XCTAssertNil([FxGripLiveFrame frameWithBytes:pixels rowBytes:16 width:4 height:0 pixelFormat:MTLPixelFormatRGBA8Unorm]);
	XCTAssertNil([FxGripLiveFrame frameWithBytes:NULL rowBytes:16 width:4 height:2 pixelFormat:MTLPixelFormatRGBA8Unorm]);
	XCTAssertNil([FxGripLiveFrame frameWithBytes:pixels rowBytes:8 width:4 height:2 pixelFormat:MTLPixelFormatRGBA8Unorm]);
}

- (void)testFormatDescriptionsAndBytesPerPixel
{
	uint8_t pixels[3 * 2 * 16] = {0};
	struct { MTLPixelFormat format; NSUInteger bytesPerPixel; NSString *name; BOOL isFloat; } cases[] = {
		{ MTLPixelFormatRGBA8Unorm, 4, @"RGBA8", NO },
		{ MTLPixelFormatBGRA8Unorm_sRGB, 4, @"BGRA8 sRGB", NO },
		{ MTLPixelFormatRGBA16Unorm, 8, @"RGBA16", NO },
		{ MTLPixelFormatRGBA16Float, 8, @"RGBA16F", YES },
		{ MTLPixelFormatRGBA32Float, 16, @"RGBA32F", YES },
		{ MTLPixelFormatR8Unorm, 1, @"R8", NO },
		{ MTLPixelFormatR16Float, 2, @"R16F", YES },
		{ MTLPixelFormatR32Float, 4, @"R32F", YES },
	};
	for (NSUInteger index = 0; index < sizeof(cases) / sizeof(cases[0]); index++) {
		FxGripLiveFrame *frame = [FxGripLiveFrame frameWithBytes:pixels rowBytes:3 * cases[index].bytesPerPixel
														   width:3 height:2 pixelFormat:cases[index].format];
		XCTAssertNotNil(frame, @"%@", cases[index].name);
		XCTAssertEqual(frame.bytesPerPixel, cases[index].bytesPerPixel, @"%@", cases[index].name);
		XCTAssertEqual(frame.rowBytes, 3 * cases[index].bytesPerPixel, @"%@", cases[index].name);
		XCTAssertEqual(frame.isFloat, cases[index].isFloat, @"%@", cases[index].name);
		XCTAssertEqualObjects(frame.formatDescription, cases[index].name);
		XCTAssertEqualObjects(frame.sizeDescription, ([NSString stringWithFormat:@"3×2 %@", cases[index].name]));
		XCTAssertEqual(frame.pixelFormat, cases[index].format);
	}
}

#pragma mark Bytes

- (void)testATightSourceIsCopiedAsIs
{
	NSData *pixels = [self rgba8PixelsForWidth:5 height:3];
	FxGripLiveFrame *frame = [FxGripLiveFrame frameWithBytes:pixels.bytes rowBytes:20 width:5 height:3
												 pixelFormat:MTLPixelFormatRGBA8Unorm];

	XCTAssertEqual(frame.width, 5u);
	XCTAssertEqual(frame.height, 3u);
	XCTAssertEqualObjects(frame.pixels, pixels);
}

- (void)testAStridedSourceRepacksTightly
{
	NSData *tight = [self rgba8PixelsForWidth:5 height:3];
	NSMutableData *strided = [NSMutableData dataWithLength:32 * 3];
	for (NSUInteger row = 0; row < 3; row++) {
		memcpy((uint8_t *)strided.mutableBytes + row * 32, (const uint8_t *)tight.bytes + row * 20, 20);
	}
	FxGripLiveFrame *frame = [FxGripLiveFrame frameWithBytes:strided.bytes rowBytes:32 width:5 height:3
												 pixelFormat:MTLPixelFormatRGBA8Unorm];

	XCTAssertEqual(frame.rowBytes, 20u);
	XCTAssertEqualObjects(frame.pixels, tight);
}

- (void)testTheFrameOwnsACopyOfItsPixels
{
	NSMutableData *pixels = [[self rgba8PixelsForWidth:2 height:2] mutableCopy];
	FxGripLiveFrame *frame = [FxGripLiveFrame frameWithBytes:pixels.bytes rowBytes:8 width:2 height:2
												 pixelFormat:MTLPixelFormatRGBA8Unorm];
	memset(pixels.mutableBytes, 0xAB, pixels.length);

	XCTAssertEqual(((const uint8_t *)frame.pixels.bytes)[0], 0);
	XCTAssertEqual(((const uint8_t *)frame.pixels.bytes)[4], 1);
}

- (void)testAFrameIsImmutableSoCopyReturnsTheSameObject
{
	NSData *pixels = [self rgba8PixelsForWidth:2 height:2];
	FxGripLiveFrame *frame = [FxGripLiveFrame frameWithBytes:pixels.bytes rowBytes:8 width:2 height:2
												 pixelFormat:MTLPixelFormatRGBA8Unorm];
	XCTAssertTrue([frame copy] == frame);
}

- (void)testTheTimestampIsTakenAtCreation
{
	NSTimeInterval before = NSProcessInfo.processInfo.systemUptime;
	NSData *pixels = [self rgba8PixelsForWidth:2 height:2];
	FxGripLiveFrame *frame = [FxGripLiveFrame frameWithBytes:pixels.bytes rowBytes:8 width:2 height:2
												 pixelFormat:MTLPixelFormatRGBA8Unorm];
	NSTimeInterval after = NSProcessInfo.processInfo.systemUptime;

	XCTAssertGreaterThanOrEqual(frame.timestamp, before);
	XCTAssertLessThanOrEqual(frame.timestamp, after);
}

#pragma mark CGImage

- (void)testAnIntegerFrameBuildsACGImageWrappingItsPixels
{
	FxGripLiveFrameTestImageSize width = FxGripLiveFrameTestSymbol("CGImageGetWidth");
	FxGripLiveFrameTestImageSize height = FxGripLiveFrameTestSymbol("CGImageGetHeight");
	FxGripLiveFrameTestImageSize bitsPerComponent = FxGripLiveFrameTestSymbol("CGImageGetBitsPerComponent");
	XCTSkipIf(width == NULL || height == NULL || bitsPerComponent == NULL, @"No CoreGraphics.");

	NSData *pixels = [self rgba8PixelsForWidth:6 height:4];
	FxGripLiveFrame *frame = [FxGripLiveFrame frameWithBytes:pixels.bytes rowBytes:24 width:6 height:4
												 pixelFormat:MTLPixelFormatRGBA8Unorm];
	CGImageRef image = frame.CGImage;

	XCTAssertTrue(image != NULL);
	XCTAssertEqual(width(image), 6u);
	XCTAssertEqual(height(image), 4u);
	XCTAssertEqual(bitsPerComponent(image), 8u);
	XCTAssertTrue(frame.CGImage == image, @"the image is built once and owned by the frame");
}

- (void)testASixteenBitFrameKeepsItsDepthInTheCGImage
{
	FxGripLiveFrameTestImageSize bitsPerComponent = FxGripLiveFrameTestSymbol("CGImageGetBitsPerComponent");
	XCTSkipIf(bitsPerComponent == NULL, @"No CoreGraphics.");

	uint16_t pixels[2 * 2 * 4] = {0};
	FxGripLiveFrame *frame = [FxGripLiveFrame frameWithBytes:pixels rowBytes:16 width:2 height:2
												 pixelFormat:MTLPixelFormatRGBA16Unorm];

	XCTAssertTrue(frame.CGImage != NULL);
	XCTAssertEqual(bitsPerComponent(frame.CGImage), 16u);
}

- (void)testAFloatFrameConvertsToEightBitsForItsCGImage
{
	FxGripLiveFrameTestImageSize bitsPerComponent = FxGripLiveFrameTestSymbol("CGImageGetBitsPerComponent");
	FxGripLiveFrameTestImageSize bitsPerPixel = FxGripLiveFrameTestSymbol("CGImageGetBitsPerPixel");
	XCTSkipIf(bitsPerComponent == NULL || bitsPerPixel == NULL, @"No CoreGraphics.");

	float pixels[2 * 2 * 4] = {0};
	FxGripLiveFrame *frame = [FxGripLiveFrame frameWithBytes:pixels rowBytes:32 width:2 height:2
												 pixelFormat:MTLPixelFormatRGBA32Float];

	XCTAssertTrue(frame.CGImage != NULL);
	XCTAssertEqual(bitsPerComponent(frame.CGImage), 8u);
	XCTAssertEqual(bitsPerPixel(frame.CGImage), 32u);
	XCTAssertTrue(frame.isFloat, @"the frame keeps its float pixels");
	XCTAssertEqual(frame.pixels.length, 64u);

	float gray[3] = {0};
	FxGripLiveFrame *single = [FxGripLiveFrame frameWithBytes:gray rowBytes:12 width:3 height:1
												  pixelFormat:MTLPixelFormatR32Float];
	XCTAssertTrue(single.CGImage != NULL);
	XCTAssertEqual(bitsPerPixel(single.CGImage), 8u);
}

- (void)testAHalfFloatFrameConvertsThroughTheHalfDecoder
{
	FxGripLiveFrameTestImageSize bitsPerComponent = FxGripLiveFrameTestSymbol("CGImageGetBitsPerComponent");
	XCTSkipIf(bitsPerComponent == NULL, @"No CoreGraphics.");

	// 0x3C00 = 1.0, 0x3800 = 0.5, 0x0000 = 0.0 in IEEE half.
	uint16_t pixels[4] = { 0x3C00, 0x3800, 0x0000, 0x3C00 };
	FxGripLiveFrame *frame = [FxGripLiveFrame frameWithBytes:pixels rowBytes:8 width:1 height:1
												 pixelFormat:MTLPixelFormatRGBA16Float];

	XCTAssertTrue(frame.CGImage != NULL);
	XCTAssertEqual(bitsPerComponent(frame.CGImage), 8u);
}

- (void)testSettingTheColorSpaceNameDiscardsTheBuiltImage
{
	NSData *pixels = [self rgba8PixelsForWidth:2 height:2];
	FxGripLiveFrame *frame = [FxGripLiveFrame frameWithBytes:pixels.bytes rowBytes:8 width:2 height:2
												 pixelFormat:MTLPixelFormatRGBA8Unorm];
	CGImageRef first = frame.CGImage;
	XCTAssertTrue(first != NULL);

	frame.colorSpaceName = @"kCGColorSpaceDisplayP3";
	XCTAssertEqualObjects(frame.colorSpaceName, @"kCGColorSpaceDisplayP3");
	XCTAssertTrue(frame.CGImage != NULL);
}

- (void)testACGImageRoundTripsThroughAnRGBA8Frame
{
	NSData *pixels = [self rgba8PixelsForWidth:4 height:3];
	FxGripLiveFrame *source = [FxGripLiveFrame frameWithBytes:pixels.bytes rowBytes:16 width:4 height:3
												  pixelFormat:MTLPixelFormatRGBA8Unorm];
	XCTSkipIf(source.CGImage == NULL, @"No CoreGraphics.");

	FxGripLiveFrame *frame = [FxGripLiveFrame frameWithCGImage:source.CGImage];

	XCTAssertEqual(frame.width, 4u);
	XCTAssertEqual(frame.height, 3u);
	XCTAssertEqual(frame.pixelFormat, MTLPixelFormatRGBA8Unorm);
	// Opaque sRGB pixels drawn into an sRGB context keep their bytes.
	XCTAssertEqualObjects(frame.pixels, pixels);
}

- (void)testANullCGImageMakesNoFrame
{
	XCTAssertNil([FxGripLiveFrame frameWithCGImage:NULL]);
}

#pragma mark Image buffer

- (void)testAnRGBA8BufferMapsToTheMatchingMetalFormat
{
	NSData *pixels = [self rgba8PixelsForWidth:4 height:2];
	FxGripImageBuffer *buffer = [FxGripImageBuffer.alloc initWithBytes:pixels.bytes rowBytes:16 width:4 height:2
																format:FxGripPixelFormatRGBA8U
														   compression:FxGripCompressionNone];
	FxGripLiveFrame *frame = [FxGripLiveFrame frameWithImageBuffer:buffer];

	XCTAssertEqual(frame.pixelFormat, MTLPixelFormatRGBA8Unorm);
	XCTAssertEqual(frame.width, 4u);
	XCTAssertEqual(frame.height, 2u);
	XCTAssertEqualObjects(frame.pixels, pixels);
}

- (void)testAThreeChannelBufferConvertsToRGBA8
{
	uint8_t rgb[3 * 2 * 3] = { 10, 20, 30,  40, 50, 60,  70, 80, 90,
							   1, 2, 3,  4, 5, 6,  7, 8, 9 };
	FxGripImageBuffer *buffer = [FxGripImageBuffer.alloc initWithBytes:rgb rowBytes:9 width:3 height:2
																format:FxGripPixelFormatRGB8U
														   compression:FxGripCompressionNone];
	FxGripLiveFrame *frame = [FxGripLiveFrame frameWithImageBuffer:buffer];

	XCTAssertEqual(frame.pixelFormat, MTLPixelFormatRGBA8Unorm);
	XCTAssertEqual(frame.pixels.length, 3u * 2u * 4u);
	const uint8_t *bytes = frame.pixels.bytes;
	XCTAssertEqual(bytes[0], 10);
	XCTAssertEqual(bytes[1], 20);
	XCTAssertEqual(bytes[2], 30);
	XCTAssertEqual(bytes[3], 255);
}

- (void)testAFloatBufferKeepsItsFloatFormat
{
	float pixels[2 * 1 * 4] = { 0.5f, 1.0f, 0.0f, 1.0f,  2.0f, -1.0f, 0.25f, 1.0f };
	FxGripImageBuffer *buffer = [FxGripImageBuffer.alloc initWithBytes:pixels rowBytes:32 width:2 height:1
																format:FxGripPixelFormatRGBA32F
														   compression:FxGripCompressionNone];
	FxGripLiveFrame *frame = [FxGripLiveFrame frameWithImageBuffer:buffer];

	XCTAssertEqual(frame.pixelFormat, MTLPixelFormatRGBA32Float);
	XCTAssertEqual(memcmp(frame.pixels.bytes, pixels, sizeof(pixels)), 0);
}

- (void)testANilBufferMakesNoFrame
{
	XCTAssertNil([FxGripLiveFrame frameWithImageBuffer:(FxGripImageBuffer * _Nonnull)nil]);
}

#pragma mark Metal

- (void)testASharedTextureReadsBackIntoAFrame
{
	id<MTLDevice> device = [self metalDevice];
	XCTSkipIf(device == nil, @"No Metal device.");

	NSData *pixels = [self rgba8PixelsForWidth:8 height:4];
	id<MTLTexture> texture = [self textureWithDevice:device format:MTLPixelFormatRGBA8Unorm width:8 height:4];
	[texture replaceRegion:MTLRegionMake2D(0, 0, 8, 4) mipmapLevel:0 withBytes:pixels.bytes bytesPerRow:32];

	FxGripLiveFrame *frame = [FxGripLiveFrame frameWithTexture:texture];

	XCTAssertEqual(frame.width, 8u);
	XCTAssertEqual(frame.height, 4u);
	XCTAssertEqual(frame.pixelFormat, MTLPixelFormatRGBA8Unorm);
	XCTAssertEqualObjects(frame.pixels, pixels);
}

- (void)testABGRATextureReadsBackWithItsOwnFormat
{
	id<MTLDevice> device = [self metalDevice];
	XCTSkipIf(device == nil, @"No Metal device.");

	id<MTLTexture> texture = [self textureWithDevice:device format:MTLPixelFormatBGRA8Unorm width:2 height:2];
	FxGripLiveFrame *frame = [FxGripLiveFrame frameWithTexture:texture];

	XCTAssertEqual(frame.pixelFormat, MTLPixelFormatBGRA8Unorm);
	XCTAssertEqualObjects(frame.formatDescription, @"BGRA8");
}

- (void)testAnUnsupportedTextureFormatMakesNoFrame
{
	id<MTLDevice> device = [self metalDevice];
	XCTSkipIf(device == nil, @"No Metal device.");

	id<MTLTexture> texture = [self textureWithDevice:device format:MTLPixelFormatRG8Unorm width:2 height:2];
	XCTAssertNil([FxGripLiveFrame frameWithTexture:texture]);
}

- (void)testAPrivateTextureMakesNoFrame
{
	id<MTLDevice> device = [self metalDevice];
	XCTSkipIf(device == nil, @"No Metal device.");

	Class descriptorClass = NSClassFromString(@"MTLTextureDescriptor");
	MTLTextureDescriptor *descriptor = [descriptorClass texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
																					width:2 height:2 mipmapped:NO];
	descriptor.storageMode = MTLStorageModePrivate;
	id<MTLTexture> texture = [device newTextureWithDescriptor:descriptor];

	XCTAssertNil([FxGripLiveFrame frameWithTexture:texture]);
}

@end
