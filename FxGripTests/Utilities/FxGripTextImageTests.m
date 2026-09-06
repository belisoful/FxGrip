/*!
	@file       FxGripTextImageTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripTextImageTests
	@abstract   Tests the text rasterizer that turns an attributed string into a Metal texture.
	@discussion Introduced in FxGrip 0.1.0. The tests confirm the texture is sized to the glyphs plus padding, empty or device-less input yields no texture, and the color and font conveniences reach the primary rasterizer. Metal-dependent tests skip when no device is available.
*/

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

/*! @abstract Empty text returns no texture even when a Metal device is present. */
- (void)testEmptyTextMakesNoTexture
{
	id<MTLDevice> device = [self metalDevice];
	XCTSkipIf(device == nil, @"No Metal device.");

	XCTAssertNil([FxGripTextImage textureForText:@"" fontSize:24.0 color:simd_make_float4(1, 1, 1, 1) device:device]);
}

/*! @abstract A nil device returns no texture. */
- (void)testNilDeviceMakesNoTexture
{
	XCTAssertNil([FxGripTextImage textureForText:@"Frame 01" fontSize:24.0 color:simd_make_float4(1, 1, 1, 1) device:nil]);
}

/*! @abstract Rasterized text produces an sRGB RGBA8 texture wider and taller than eight pixels. */
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

/*! @abstract An eight-character string produces a wider texture than a single character at the same font size. */
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

/*! @abstract Padding of ten points adds twenty pixels to both the width and the height of the attributed-string texture. */
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
