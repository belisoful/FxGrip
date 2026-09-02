//
//  FxGripTextImageTests.m
//  FxGripTests
//
//  Unit tests for the text rasterizer: an attributed string becomes a Metal texture sized to
//  the glyphs plus padding, empty text produces no texture, and the color and font
//  conveniences feed the primary rasterizer.
//
//  The test bundle links only FxGrip and XCTest, so the Metal device is reached through the
//  loaded framework image rather than a link-time reference, and a test skips when no Metal
//  device is present.
//

#import <XCTest/XCTest.h>
#import <dlfcn.h>
#import <FxGrip/FxGripTextImage.h>

typedef void *(*FxGripTextImageTestCreateDevice)(void);

@interface FxGripTextImageTests : XCTestCase
@end

@implementation FxGripTextImageTests

- (id<MTLDevice>)metalDevice
{
	FxGripTextImageTestCreateDevice create =
		(FxGripTextImageTestCreateDevice)dlsym(RTLD_DEFAULT, "MTLCreateSystemDefaultDevice");
	if (create == NULL) {
		return nil;
	}
	return (__bridge_transfer id<MTLDevice>)create();
}

- (void)testEmptyTextMakesNoTexture
{
	id<MTLDevice> device = [self metalDevice];
	XCTSkipIf(device == nil, @"No Metal device.");

	XCTAssertNil([FxGripTextImage textureForText:@"" fontSize:24.0 color:simd_make_float4(1, 1, 1, 1) device:device]);
}

- (void)testNilDeviceMakesNoTexture
{
	XCTAssertNil([FxGripTextImage textureForText:@"Frame 01" fontSize:24.0 color:simd_make_float4(1, 1, 1, 1) device:nil]);
}

- (void)testTextMakesAnSRGBTextureSizedToTheGlyphs
{
	id<MTLDevice> device = [self metalDevice];
	XCTSkipIf(device == nil, @"No Metal device.");

	id<MTLTexture> texture = [FxGripTextImage textureForText:@"Frame 01"
												  fontSize:24.0
													 color:simd_make_float4(1, 1, 1, 1)
													device:device];
	XCTAssertNotNil(texture);
	XCTAssertEqual(texture.pixelFormat, MTLPixelFormatRGBA8Unorm_sRGB);
	XCTAssertGreaterThan(texture.width, 8u);
	XCTAssertGreaterThan(texture.height, 8u);
}

- (void)testALongerStringIsWider
{
	id<MTLDevice> device = [self metalDevice];
	XCTSkipIf(device == nil, @"No Metal device.");

	id<MTLTexture> shortText = [FxGripTextImage textureForText:@"A" fontSize:24.0 color:simd_make_float4(1, 1, 1, 1) device:device];
	id<MTLTexture> longText = [FxGripTextImage textureForText:@"AAAAAAAA" fontSize:24.0 color:simd_make_float4(1, 1, 1, 1) device:device];
	XCTAssertNotNil(shortText);
	XCTAssertNotNil(longText);
	XCTAssertGreaterThan(longText.width, shortText.width);
}

- (void)testAttributedStringPaddingWidensTheTexture
{
	id<MTLDevice> device = [self metalDevice];
	XCTSkipIf(device == nil, @"No Metal device.");

	// A nil attribute dictionary draws in the default font, which keeps this test from
	// referencing AppKit symbols the test bundle does not link.
	NSAttributedString *text = [[NSAttributedString alloc] initWithString:@"Watermark" attributes:nil];

	id<MTLTexture> tight = [FxGripTextImage textureForAttributedString:text padding:0 device:device];
	id<MTLTexture> padded = [FxGripTextImage textureForAttributedString:text padding:10 device:device];
	XCTAssertNotNil(tight);
	XCTAssertNotNil(padded);
	XCTAssertEqual(padded.width, tight.width + 20u);
	XCTAssertEqual(padded.height, tight.height + 20u);
}

@end
