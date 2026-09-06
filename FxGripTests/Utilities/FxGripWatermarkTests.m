/*!
	@file       FxGripWatermarkTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripWatermarkTests
	@abstract   Unit tests for the FxGripWatermark configuration, presets, copy semantics, and generated image geometry.
	@discussion Introduced in FxGrip 0.1.0. The tests cover the configuration defaults and presets, the value-copy semantics of the configuration and the watermark, and the extent of the Core Image each layout style generates. The GPU composite onto a render tile is verified in a host.
*/

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripWatermark.h>

@interface FxGripWatermarkTests : XCTestCase
@end

@implementation FxGripWatermarkTests

#pragma mark Configuration

/*! @abstract A newly initialized configuration has empty text, Helvetica 48pt, the diagonal-tiled style, 0.5 opacity, and no shadow color. */
- (void)testDefaultConfiguration
{
	FxGripWatermarkConfiguration *configuration = [[FxGripWatermarkConfiguration alloc] init];
	XCTAssertEqualObjects(configuration.text, @"");
	XCTAssertEqualObjects(configuration.fontName, @"Helvetica");
	XCTAssertEqual(configuration.fontSize, 48.0);
	XCTAssertEqual(configuration.style, FxGripWatermarkStyleDiagonalTiled);
	XCTAssertEqual(configuration.opacity, 0.5);
	XCTAssertNil(configuration.shadowColor);
}

/*! @abstract configurationWithText: sets the text and leaves the style at the diagonal-tiled default. */
- (void)testConfigurationWithTextSetsOnlyTheText
{
	FxGripWatermarkConfiguration *configuration = [FxGripWatermarkConfiguration configurationWithText:@"UNREGISTERED"];
	XCTAssertEqualObjects(configuration.text, @"UNREGISTERED");
	XCTAssertEqual(configuration.style, FxGripWatermarkStyleDiagonalTiled);
}

/*! @abstract The trial preset carries the given text, the diagonal-tiled style, and 0.35 opacity. */
- (void)testTrialPresetIsTiledAndTranslucent
{
	FxGripWatermarkConfiguration *configuration = [FxGripWatermarkConfiguration trialConfigurationWithText:@"TRIAL"];
	XCTAssertEqualObjects(configuration.text, @"TRIAL");
	XCTAssertEqual(configuration.style, FxGripWatermarkStyleDiagonalTiled);
	XCTAssertEqual(configuration.opacity, 0.35);
}

/*! @abstract The centered preset uses the single style, a 96pt font, and a -30 degree angle. */
- (void)testCenteredPresetIsSingleAndRotated
{
	FxGripWatermarkConfiguration *configuration = [FxGripWatermarkConfiguration centeredConfigurationWithText:@"SAMPLE"];
	XCTAssertEqual(configuration.style, FxGripWatermarkStyleSingle);
	XCTAssertEqual(configuration.fontSize, 96.0);
	XCTAssertEqual(configuration.angleDegrees, -30.0);
}

/*! @abstract A copied configuration holds its own text and opacity, so mutating the copy leaves the original unchanged. */
- (void)testCopyIsIndependent
{
	FxGripWatermarkConfiguration *original = [FxGripWatermarkConfiguration configurationWithText:@"A"];
	original.opacity = 0.9;
	FxGripWatermarkConfiguration *copy = [original copy];
	copy.text = @"B";
	copy.opacity = 0.1;

	XCTAssertEqualObjects(original.text, @"A");
	XCTAssertEqual(original.opacity, 0.9);
	XCTAssertEqualObjects(copy.text, @"B");
	XCTAssertEqual(copy.opacity, 0.1);
}

/*! @abstract A watermark copies the configuration it is built from, so a later mutation of that configuration does not change the watermark. */
- (void)testWatermarkCopiesItsConfiguration
{
	FxGripWatermarkConfiguration *configuration = [FxGripWatermarkConfiguration configurationWithText:@"A"];
	FxGripWatermark *watermark = [FxGripWatermark watermarkWithConfiguration:configuration];
	configuration.text = @"mutated";
	XCTAssertEqualObjects(watermark.configuration.text, @"A");
}

#pragma mark Generated image geometry

- (CIImage *)imageForStyle:(FxGripWatermarkStyle)style size:(CGSize)size
{
	FxGripWatermarkConfiguration *configuration = [FxGripWatermarkConfiguration configurationWithText:@"WATERMARK"];
	configuration.style = style;
	FxGripWatermark *watermark = [FxGripWatermark watermarkWithConfiguration:configuration];
	return [watermark watermarkImageForSize:size device:nil];
}

/*! @abstract A watermark with empty text produces no image. */
- (void)testEmptyTextMakesNoImage
{
	FxGripWatermark *watermark = [FxGripWatermark watermarkWithConfiguration:[[FxGripWatermarkConfiguration alloc] init]];
	XCTAssertNil([watermark watermarkImageForSize:CGSizeMake(640, 480) device:nil]);
}

/*! @abstract A zero size produces no image. */
- (void)testZeroSizeMakesNoImage
{
	XCTAssertNil([self imageForStyle:FxGripWatermarkStyleSingle size:CGSizeMake(0, 0)]);
}

/*! @abstract Each style produces an image whose extent is positive, bounded to a few frame widths, and overlaps the requested frame. */
- (void)testEachStyleProducesAFiniteImageWithinTheFrame
{
	CGSize size = CGSizeMake(640, 480);
	FxGripWatermarkStyle styles[] = {
		FxGripWatermarkStyleSingle,
		FxGripWatermarkStyleDiagonalTiled,
		FxGripWatermarkStyleBanner,
		FxGripWatermarkStyleCorner,
	};
	// CGRect predicate functions live in CoreGraphics, which the test bundle does not link,
	// so the extent is checked with the inline CGRectGet* accessors alone.
	for (NSUInteger index = 0; index < sizeof(styles) / sizeof(styles[0]); index++) {
		CIImage *image = [self imageForStyle:styles[index] size:size];
		CGRect extent = image.extent;
		XCTAssertNotNil(image, @"style %ld", (long)styles[index]);
		XCTAssertGreaterThan(extent.size.width, 0.0, @"style %ld", (long)styles[index]);
		XCTAssertGreaterThan(extent.size.height, 0.0, @"style %ld", (long)styles[index]);
		XCTAssertLessThan(extent.size.width, size.width * 4.0, @"style %ld", (long)styles[index]);
		XCTAssertLessThan(extent.size.height, size.height * 4.0, @"style %ld", (long)styles[index]);
		XCTAssertGreaterThan(extent.origin.x + extent.size.width, 0.0, @"style %ld", (long)styles[index]);
		XCTAssertLessThan(extent.origin.x, size.width, @"style %ld", (long)styles[index]);
		XCTAssertGreaterThan(extent.origin.y + extent.size.height, 0.0, @"style %ld", (long)styles[index]);
		XCTAssertLessThan(extent.origin.y, size.height, @"style %ld", (long)styles[index]);
	}
}

/*! @abstract The diagonal-tiled style produces an image covering at least ninety percent of the frame in each dimension. */
- (void)testDiagonalTiledCoversMostOfTheFrame
{
	CGSize size = CGSizeMake(640, 480);
	CIImage *image = [self imageForStyle:FxGripWatermarkStyleDiagonalTiled size:size];
	XCTAssertNotNil(image);
	XCTAssertGreaterThanOrEqual(image.extent.size.width, size.width * 0.9);
	XCTAssertGreaterThanOrEqual(image.extent.size.height, size.height * 0.9);
}

/*! @abstract The corner style produces an image narrower than the full frame width. */
- (void)testCornerImageStaysNearOneCorner
{
	CGSize size = CGSizeMake(640, 480);
	CIImage *image = [self imageForStyle:FxGripWatermarkStyleCorner size:size];
	XCTAssertNotNil(image);
	// A corner badge occupies a fraction of the frame, not the whole width.
	XCTAssertLessThan(image.extent.size.width, size.width);
}

@end
