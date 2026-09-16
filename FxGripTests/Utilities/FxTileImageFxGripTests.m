/*!
	@file       FxTileImageFxGripTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-10
	@header     FxTileImageFxGripTests
	@abstract   Verifies the FxImageTile device, pixel-format, coordinate, and compositing categories.
	@discussion Introduced in FxGrip 0.1.0. The tests build IOSurface-backed tiles through the
	            FxPlugStub factory, so the device lookup resolves a real MTLDevice by registry ID
	            and the compositing path writes into a real Metal texture. They pin the pixel-format
	            mapping for every supported IOSurface format and the unrecognized case, the pixel
	            and image space conversions against the tile's transforms, and the error each
	            compositing method reports when the tile has no device or the text rasterizes to
	            nothing.
*/

#import <XCTest/XCTest.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreImage/CoreImage.h>
#import <AppKit/AppKit.h>
#import <IOSurface/IOSurfaceObjC.h>
#import "FxPlugStub.h"
#import <FxGrip/FxGripErrors.h>
#import <FxGrip/FxGripRect.h>
#import <FxGrip/FxTileImage+FxGrip.h>

/*!
	The IOSurface designated initializer, reached through the runtime. The test bundle does
	not link IOSurface.framework, so the class and its property-key globals are resolved by
	name and the keys are spelled as the literal strings the framework defines.
*/
@protocol FxGripTestSurfaceAllocation <NSObject>
- (instancetype)initWithProperties:(NSDictionary<NSString *, id> *)properties;
@end

@interface FxTileImageFxGripTests : XCTestCase
@property (nonatomic, strong) id<MTLDevice> device;
@end

@implementation FxTileImageFxGripTests

- (void)setUp
{
	[super setUp];
	self.device = MTLCreateSystemDefaultDevice();
}

/*! A tile whose IOSurface carries a pixel format the category does not recognize. */
- (FxImageTile *)tileWithUnrecognizedSurface
{
	id<FxGripTestSurfaceAllocation> allocated = [NSClassFromString(@"IOSurface") alloc];
	id surface = [allocated initWithProperties:@{
		@"IOSurfaceWidth": @8,
		@"IOSurfaceHeight": @8,
		@"IOSurfaceBytesPerElement": @2,
		@"IOSurfacePixelFormat": @(kCVPixelFormatType_422YpCbCr8),
	}];
	XCTAssertNotNil(surface);
	FxImageTile *tile = [FxImageTile stubTileWithPixelBounds:(FxRect){ 0, 0, 8, 8 }];
	tile.ioSurface = surface;
	return tile;
}

/*! Fills every pixel of a 32BGRA tile through its Metal texture. */
- (void)fillTile:(FxImageTile *)tile blue:(uint8_t)blue green:(uint8_t)green red:(uint8_t)red alpha:(uint8_t)alpha
{
	id<MTLTexture> texture = tile.metalTexture;
	XCTAssertNotNil(texture);
	NSUInteger rowBytes = texture.width * 4;
	NSMutableData *bytes = [NSMutableData dataWithLength:rowBytes * texture.height];
	uint8_t *pixel = bytes.mutableBytes;
	for (NSUInteger index = 0; index < texture.width * texture.height; index++, pixel += 4) {
		pixel[0] = blue;
		pixel[1] = green;
		pixel[2] = red;
		pixel[3] = alpha;
	}
	[texture replaceRegion:MTLRegionMake2D(0, 0, texture.width, texture.height)
			   mipmapLevel:0
				 withBytes:bytes.bytes
			   bytesPerRow:rowBytes];
}

/*! Reads the bottom-left pixel of a 32BGRA tile through its Metal texture. */
- (void)readTile:(FxImageTile *)tile blue:(uint8_t *)blue green:(uint8_t *)green red:(uint8_t *)red
{
	id<MTLTexture> texture = tile.metalTexture;
	XCTAssertNotNil(texture);
	uint8_t pixel[4] = { 0, 0, 0, 0 };
	[texture getBytes:pixel bytesPerRow:4 fromRegion:MTLRegionMake2D(0, 0, 1, 1) mipmapLevel:0];
	*blue = pixel[0];
	*green = pixel[1];
	*red = pixel[2];
}

#pragma mark Device lookup

/*! @abstract The tile's device resolves by registry ID and is answered from the tile's cache on a repeat read. */
- (void)testDeviceResolvesTheRegistryIDAndCachesTheResult
{
	XCTSkipIf(self.device == nil, @"No Metal device.");
	FxImageTile *tile = [FxImageTile stubTileWithPixelBounds:(FxRect){ 0, 0, 16, 16 }];
	tile.deviceRegistryID = self.device.registryID;

	id<MTLDevice> first = tile.device;
	id<MTLDevice> second = tile.device;

	XCTAssertEqual(first, self.device);
	XCTAssertEqual(second, first, @"the resolved device is cached on the tile");
}

/*! @abstract A registry ID no Metal device carries resolves to nil, and a changed ID invalidates the cached device. */
- (void)testDeviceIsNilForAnUnknownRegistryIDAndTheCacheFollowsTheID
{
	XCTSkipIf(self.device == nil, @"No Metal device.");
	FxImageTile *tile = [FxImageTile stubTileWithPixelBounds:(FxRect){ 0, 0, 16, 16 }];
	tile.deviceRegistryID = self.device.registryID;
	XCTAssertEqual(tile.device, self.device);

	tile.deviceRegistryID = 0xFEEDFACEDEADBEEFULL;

	XCTAssertNil(tile.device, @"a cached device whose registry ID no longer matches is discarded");
}

#pragma mark Pixel format

/*! @abstract pixelFormat reports the backing IOSurface's FourCC, and zero when the tile has no surface. */
- (void)testPixelFormatReportsTheSurfaceFormat
{
	FxImageTile *surfaced = [FxImageTile stubTileWithPixelBounds:(FxRect){ 0, 0, 8, 8 }
													 pixelFormat:kCVPixelFormatType_32BGRA
														  device:nil];
	FxImageTile *bare = [FxImageTile stubTileWithPixelBounds:(FxRect){ 0, 0, 8, 8 }];

	XCTAssertEqual(surfaced.pixelFormat, (OSType)kCVPixelFormatType_32BGRA);
	XCTAssertEqual(bare.pixelFormat, (OSType)0);
}

/*! @abstract Every supported IOSurface format maps to its Metal format. */
- (void)testMetalPixelFormatMapsEverySupportedSurfaceFormat
{
	NSArray<NSNumber *> *surfaceFormats = @[
		@(kCVPixelFormatType_32BGRA), @(kCVPixelFormatType_32RGBA), @(kCVPixelFormatType_64RGBALE),
		@(kCVPixelFormatType_64RGBAHalf), @(kCVPixelFormatType_128RGBAFloat),
	];
	NSArray<NSNumber *> *metalFormats = @[
		@(MTLPixelFormatBGRA8Unorm), @(MTLPixelFormatRGBA8Unorm), @(MTLPixelFormatRGBA16Unorm),
		@(MTLPixelFormatRGBA16Float), @(MTLPixelFormatRGBA32Float),
	];

	for (NSUInteger index = 0; index < surfaceFormats.count; index++) {
		FxImageTile *tile = [FxImageTile stubTileWithPixelBounds:(FxRect){ 0, 0, 8, 8 }
													 pixelFormat:surfaceFormats[index].unsignedIntValue
														  device:nil];
		XCTAssertEqual(tile.metalPixelFormat, (MTLPixelFormat)metalFormats[index].unsignedIntegerValue,
					   @"format %@", surfaceFormats[index]);
	}
}

/*! @abstract An unrecognized IOSurface format maps to no Metal format. */
- (void)testMetalPixelFormatIsZeroForAnUnrecognizedSurfaceFormat
{
	FxImageTile *tile = [self tileWithUnrecognizedSurface];

	XCTAssertEqual(tile.pixelFormat, (OSType)kCVPixelFormatType_422YpCbCr8);
	XCTAssertEqual(tile.metalPixelFormat, (MTLPixelFormat)0);
}

/*! @abstract metalTexture answers the surface's texture on the tile's own device. */
- (void)testMetalTextureUsesTheTilesOwnDevice
{
	XCTSkipIf(self.device == nil, @"No Metal device.");
	FxImageTile *tile = [FxImageTile stubTileWithPixelBounds:(FxRect){ 0, 0, 32, 16 }
												 pixelFormat:kCVPixelFormatType_32BGRA
													  device:self.device];

	id<MTLTexture> texture = tile.metalTexture;

	XCTAssertNotNil(texture);
	XCTAssertEqual(texture.device, self.device);
	XCTAssertEqual(texture.pixelFormat, MTLPixelFormatBGRA8Unorm);
	XCTAssertEqual(texture.width, (NSUInteger)32);
	XCTAssertEqual(texture.height, (NSUInteger)16);
	XCTAssertEqualObjects(tile.stubRequestedDevices.firstObject, self.device);
}

/*! @abstract metalTexture is nil when the tile's registry ID matches no device. */
- (void)testMetalTextureIsNilWithoutADevice
{
	FxImageTile *tile = [FxImageTile stubTileWithPixelBounds:(FxRect){ 0, 0, 8, 8 }];
	tile.deviceRegistryID = 0xFEEDFACEDEADBEEFULL;

	XCTAssertNil(tile.metalTexture);
}

#pragma mark Coordinate conversion

/*! @abstract A pixel point converts to image space through the tile's inverse pixel transform. */
- (void)testImagePointFromPixelPointUsesTheInverseTransform
{
	FxImageTile *tile = [FxImageTile stubTileWithPixelBounds:(FxRect){ 0, 0, 100, 100 }];
	tile.inversePixelTransform = [FxMatrix44 stubMatrixWithScaleX:0.5 scaleY:0.25 translationX:3.0 translationY:-4.0];

	CGPoint point = [tile imagePointFromPixelPoint:CGPointMake(20.0, 40.0)];

	XCTAssertEqualWithAccuracy(point.x, 13.0, 1e-9);
	XCTAssertEqualWithAccuracy(point.y, 6.0, 1e-9);
}

/*! @abstract An image point converts to pixel space through the tile's pixel transform. */
- (void)testPixelPointFromImagePointUsesThePixelTransform
{
	FxImageTile *tile = [FxImageTile stubTileWithPixelBounds:(FxRect){ 0, 0, 100, 100 }];
	tile.pixelTransform = [FxMatrix44 stubMatrixWithScaleX:2.0 scaleY:4.0 translationX:-6.0 translationY:8.0];

	CGPoint point = [tile pixelPointFromImagePoint:CGPointMake(13.0, 6.0)];

	XCTAssertEqualWithAccuracy(point.x, 20.0, 1e-9);
	XCTAssertEqualWithAccuracy(point.y, 32.0, 1e-9);
}

/*! @abstract imageSpaceBounds maps the tile's whole image pixel bounds through the inverse transform. */
- (void)testImageSpaceBoundsCoversTheImagePixelBounds
{
	FxImageTile *tile = [FxImageTile stubTileWithPixelBounds:(FxRect){ 10, 20, 110, 220 }];
	tile.inversePixelTransform = [FxMatrix44 stubMatrixWithScale:0.5];

	CGRect bounds = tile.imageSpaceBounds;

	XCTAssertEqualWithAccuracy(CGRectGetMinX(bounds), 5.0, 1e-9);
	XCTAssertEqualWithAccuracy(CGRectGetMinY(bounds), 10.0, 1e-9);
	XCTAssertEqualWithAccuracy(CGRectGetWidth(bounds), 50.0, 1e-9);
	XCTAssertEqualWithAccuracy(CGRectGetHeight(bounds), 100.0, 1e-9);
}

/*! @abstract imageSpaceBounds is empty when the tile carries no inverse transform. */
- (void)testImageSpaceBoundsIsEmptyWithoutAnInverseTransform
{
	FxImageTile *tile = [FxImageTile stubTileWithPixelBounds:(FxRect){ 0, 0, 64, 64 }];
	tile.inversePixelTransform = nil;

	XCTAssertTrue(CGRectEqualToRect(tile.imageSpaceBounds, CGRectZero));
}

/*! @abstract pixelBoundsForImageRect: transforms the rectangle and rounds outward to whole pixels. */
- (void)testPixelBoundsForImageRectRoundsOutward
{
	FxImageTile *tile = [FxImageTile stubTileWithPixelBounds:(FxRect){ 0, 0, 200, 200 }];
	tile.pixelTransform = [FxMatrix44 stubMatrixWithScale:2.0];

	FxRect bounds = [tile pixelBoundsForImageRect:CGRectMake(1.25, 2.75, 10.0, 4.0)];

	XCTAssertEqual(bounds.left, (SInt32)2);
	XCTAssertEqual(bounds.bottom, (SInt32)5);
	XCTAssertEqual(bounds.right, (SInt32)23);
	XCTAssertEqual(bounds.top, (SInt32)14);
}

/*! @abstract pixelBoundsForImageRect: is the empty rectangle when the tile carries no pixel transform. */
- (void)testPixelBoundsForImageRectIsEmptyWithoutAPixelTransform
{
	FxImageTile *tile = [FxImageTile stubTileWithPixelBounds:(FxRect){ 0, 0, 200, 200 }];
	tile.pixelTransform = nil;

	FxRect bounds = [tile pixelBoundsForImageRect:CGRectMake(0.0, 0.0, 10.0, 10.0)];

	XCTAssertTrue(FxRectsAreEqual(bounds, FxGripRectZero()));
}

/*! @abstract imageRectForPixelBounds: maps an arbitrary pixel region through the inverse transform. */
- (void)testImageRectForPixelBoundsMapsThroughTheInverseTransform
{
	FxImageTile *tile = [FxImageTile stubTileWithPixelBounds:(FxRect){ 0, 0, 200, 200 }];
	tile.inversePixelTransform = [FxMatrix44 stubMatrixWithScaleX:0.5 scaleY:0.5 translationX:1.0 translationY:2.0];

	CGRect rect = [tile imageRectForPixelBounds:(FxRect){ 10, 20, 30, 60 }];

	XCTAssertEqualWithAccuracy(CGRectGetMinX(rect), 6.0, 1e-9);
	XCTAssertEqualWithAccuracy(CGRectGetMinY(rect), 12.0, 1e-9);
	XCTAssertEqualWithAccuracy(CGRectGetWidth(rect), 10.0, 1e-9);
	XCTAssertEqualWithAccuracy(CGRectGetHeight(rect), 20.0, 1e-9);
}

#pragma mark Compositing

/*! @abstract A nil overlay composites nothing and succeeds. */
- (void)testCompositingANilOverlaySucceeds
{
	FxImageTile *tile = [FxImageTile stubTileWithPixelBounds:(FxRect){ 0, 0, 8, 8 }];
	NSError *error = [NSError errorWithDomain:@"unset" code:0 userInfo:nil];

	XCTAssertTrue([tile fxg_compositeCIImage:(CIImage * _Nonnull)nil opacity:1.0 error:&error]);
	XCTAssertEqualObjects(error.domain, @"unset", @"a nil overlay leaves the error untouched");
}

/*! @abstract Compositing onto a tile with no backing Metal device reports the no-device error. */
- (void)testCompositingWithoutADeviceReportsTheNoDeviceError
{
	FxImageTile *tile = [FxImageTile stubTileWithPixelBounds:(FxRect){ 0, 0, 8, 8 }];
	tile.deviceRegistryID = 0xFEEDFACEDEADBEEFULL;
	CIImage *overlay = [CIImage imageWithColor:CIColor.redColor];
	NSError *error = nil;

	BOOL composited = [tile fxg_compositeCIImage:overlay opacity:1.0 error:&error];

	XCTAssertFalse(composited);
	XCTAssertEqualObjects(error.domain, FxGripPlugErrorDomain);
	XCTAssertEqual(error.code, (NSInteger)kFxGripError_WatermarkNoDevice);
}

/*! @abstract An opaque overlay composites into the tile's own texture, changing its pixels. */
- (void)testCompositingAnOverlayWritesTheTileTexture
{
	XCTSkipIf(self.device == nil, @"No Metal device.");
	FxImageTile *tile = [FxImageTile stubTileWithPixelBounds:(FxRect){ 0, 0, 16, 16 }
												 pixelFormat:kCVPixelFormatType_32BGRA
													  device:self.device];
	CIImage *overlay = [[CIImage imageWithColor:CIColor.redColor]
						imageByCroppingToRect:CGRectMake(0.0, 0.0, 16.0, 16.0)];
	NSError *error = nil;

	BOOL composited = [tile fxg_compositeCIImage:overlay opacity:1.0 error:&error];

	XCTAssertTrue(composited, @"%@", error);
	XCTAssertNil(error);

	uint8_t blue = 0, green = 0, red = 0;
	[self readTile:tile blue:&blue green:&green red:&red];

	XCTAssertGreaterThan(red, (uint8_t)200, @"the red overlay reaches the surface");
	XCTAssertLessThan(green, (uint8_t)64);
	XCTAssertLessThan(blue, (uint8_t)64);
}

/*! @abstract A fully transparent overlay leaves the tile's existing pixels in place. */
- (void)testCompositingATransparentOverlayLeavesTheTileUnchanged
{
	XCTSkipIf(self.device == nil, @"No Metal device.");
	FxImageTile *tile = [FxImageTile stubTileWithPixelBounds:(FxRect){ 0, 0, 16, 16 }
												 pixelFormat:kCVPixelFormatType_32BGRA
													  device:self.device];
	[self fillTile:tile blue:0 green:255 red:0 alpha:255];
	CIImage *overlay = [[CIImage imageWithColor:[CIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.0]]
						imageByCroppingToRect:CGRectMake(0.0, 0.0, 16.0, 16.0)];
	NSError *error = nil;

	BOOL composited = [tile fxg_compositeCIImage:overlay opacity:1.0 error:&error];

	uint8_t blue = 0, green = 0, red = 0;
	[self readTile:tile blue:&blue green:&green red:&red];

	XCTAssertTrue(composited, @"%@", error);
	XCTAssertGreaterThan(green, (uint8_t)128, @"a transparent overlay must not erase the tile's own pixels");
	XCTAssertLessThan(red, (uint8_t)128);
	XCTAssertLessThan(blue, (uint8_t)128);
}

/*! @abstract Drawing text rasterizes and composites it onto the tile's texture. */
- (void)testDrawingTextCompositesOntoTheTile
{
	XCTSkipIf(self.device == nil, @"No Metal device.");
	FxImageTile *tile = [FxImageTile stubTileWithPixelBounds:(FxRect){ 0, 0, 128, 64 }
												 pixelFormat:kCVPixelFormatType_32BGRA
													  device:self.device];
	NSDictionary<NSAttributedStringKey, id> *attributes = @{
		NSFontAttributeName: [NSFont systemFontOfSize:24.0],
		NSForegroundColorAttributeName: NSColor.whiteColor,
	};
	NSError *error = nil;

	BOOL drawn = [tile fxg_drawText:@"Fx" attributes:attributes atPixelPoint:CGPointMake(4.0, 4.0) error:&error];

	XCTAssertTrue(drawn, @"%@", error);
	XCTAssertNil(error);
}

/*! @abstract Text that rasterizes to nothing reports the render error and composites nothing. */
- (void)testDrawingEmptyTextReportsTheRenderError
{
	XCTSkipIf(self.device == nil, @"No Metal device.");
	FxImageTile *tile = [FxImageTile stubTileWithPixelBounds:(FxRect){ 0, 0, 32, 32 }
												 pixelFormat:kCVPixelFormatType_32BGRA
													  device:self.device];
	NSError *error = nil;

	BOOL drawn = [tile fxg_drawText:@"" attributes:@{} atPixelPoint:CGPointZero error:&error];

	XCTAssertFalse(drawn);
	XCTAssertEqualObjects(error.domain, FxGripPlugErrorDomain);
	XCTAssertEqual(error.code, (NSInteger)kFxGripError_WatermarkRender);
}

@end
