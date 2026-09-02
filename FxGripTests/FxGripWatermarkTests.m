//
//  FxGripWatermarkTests.m
//  FxGripTests
//
//  Unit tests for the standalone watermark: the configuration defaults and presets, the
//  value-copy semantics of the configuration, and the geometry of the generated Core Image
//  for each layout style. The GPU composite onto a live render tile is verified in a host,
//  so these tests exercise the image the styles produce rather than the tile write.
//

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripWatermark.h>

@interface FxGripWatermarkTests : XCTestCase
@end

@implementation FxGripWatermarkTests

#pragma mark Configuration

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

- (void)testConfigurationWithTextSetsOnlyTheText
{
	FxGripWatermarkConfiguration *configuration = [FxGripWatermarkConfiguration configurationWithText:@"UNREGISTERED"];
	XCTAssertEqualObjects(configuration.text, @"UNREGISTERED");
	XCTAssertEqual(configuration.style, FxGripWatermarkStyleDiagonalTiled);
}

- (void)testTrialPresetIsTiledAndTranslucent
{
	FxGripWatermarkConfiguration *configuration = [FxGripWatermarkConfiguration trialConfigurationWithText:@"TRIAL"];
	XCTAssertEqualObjects(configuration.text, @"TRIAL");
	XCTAssertEqual(configuration.style, FxGripWatermarkStyleDiagonalTiled);
	XCTAssertEqual(configuration.opacity, 0.35);
}

- (void)testCenteredPresetIsSingleAndRotated
{
	FxGripWatermarkConfiguration *configuration = [FxGripWatermarkConfiguration centeredConfigurationWithText:@"SAMPLE"];
	XCTAssertEqual(configuration.style, FxGripWatermarkStyleSingle);
	XCTAssertEqual(configuration.fontSize, 96.0);
	XCTAssertEqual(configuration.angleDegrees, -30.0);
}

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

- (void)testEmptyTextMakesNoImage
{
	FxGripWatermark *watermark = [FxGripWatermark watermarkWithConfiguration:[[FxGripWatermarkConfiguration alloc] init]];
	XCTAssertNil([watermark watermarkImageForSize:CGSizeMake(640, 480) device:nil]);
}

- (void)testZeroSizeMakesNoImage
{
	XCTAssertNil([self imageForStyle:FxGripWatermarkStyleSingle size:CGSizeMake(0, 0)]);
}

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

- (void)testDiagonalTiledCoversMostOfTheFrame
{
	CGSize size = CGSizeMake(640, 480);
	CIImage *image = [self imageForStyle:FxGripWatermarkStyleDiagonalTiled size:size];
	XCTAssertNotNil(image);
	XCTAssertGreaterThanOrEqual(image.extent.size.width, size.width * 0.9);
	XCTAssertGreaterThanOrEqual(image.extent.size.height, size.height * 0.9);
}

- (void)testCornerImageStaysNearOneCorner
{
	CGSize size = CGSizeMake(640, 480);
	CIImage *image = [self imageForStyle:FxGripWatermarkStyleCorner size:size];
	XCTAssertNotNil(image);
	// A corner badge occupies a fraction of the frame, not the whole width.
	XCTAssertLessThan(image.extent.size.width, size.width);
}

@end
