/*!
	@file       FxPlugStubTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-10
	@header     FxPlugStubTests
	@abstract   Verifies the FxPlugStub test framework that stands in for FxPlug.framework.
	@discussion Introduced in FxGrip 0.1.0. The tests pin the facts every other test relies on: the stub loads under the SDK install name so FxGrip's weak class imports resolve and its FxImageTile and FxMatrix44 categories attach; FxMatrix44 follows the row-vector convention with translation in row 3; inversion, transposition, copying, and secure coding round-trip; FxImageTile answers a real IOSurface-backed Metal texture per device and honors scripted textures; FxImageTileRequest keeps its values and equality.
*/

#import <XCTest/XCTest.h>
#import <CoreVideo/CoreVideo.h>
#import "FxPlugStub.h"
#import <FxGrip/FxTileImage+FxGrip.h>
#import <FxGrip/FxMatrix+FxGrip.h>

@interface FxPlugStubTests : XCTestCase
@end

@implementation FxPlugStubTests

#pragma mark - Loading

/*! @abstract The three FxPlug classes resolve by name, so the stub framework is loaded. */
- (void)testTheStubClassesResolveByName
{
	XCTAssertNotNil(NSClassFromString(@"FxImageTile"));
	XCTAssertNotNil(NSClassFromString(@"FxImageTileRequest"));
	XCTAssertNotNil(NSClassFromString(@"FxMatrix44"));
}

/*! @abstract The stub binary carries the SDK install name, so FxGrip's weak imports bind to it. */
- (void)testTheStubCarriesTheSDKInstallName
{
	NSBundle *bundle = [NSBundle bundleForClass:FxImageTile.class];

	XCTAssertEqualObjects(bundle.executablePath.lastPathComponent, @"FxPlug");
	XCTAssertEqualObjects(bundle.bundleIdentifier, @"com.belisoful.FxPlugStub");
}

/*! @abstract FxGrip's categories on FxImageTile and FxMatrix44 attach once the classes exist. */
- (void)testFxGripCategoriesAttachToTheStubClasses
{
	XCTAssertTrue([FxImageTile instancesRespondToSelector:@selector(metalPixelFormat)]);
	XCTAssertTrue([FxImageTile instancesRespondToSelector:@selector(imagePointFromPixelPoint:)]);
	XCTAssertTrue([FxImageTile instancesRespondToSelector:@selector(fxg_drawText:attributes:atPixelPoint:error:)]);
	XCTAssertTrue([FxMatrix44 instancesRespondToSelector:@selector(toFloat4x4Matrix:)]);
	XCTAssertTrue([FxMatrix44 respondsToSelector:@selector(doubleMatrix:toFloat4x4Matrix:)]);
}

/*! @abstract The exported globals hold the documented values. */
- (void)testTheExportedGlobalsHoldTheDocumentedValues
{
	XCTAssertEqualObjects(FxPlugErrorDomain, @"FxPlugErrorDomain");
	XCTAssertTrue(FxRectsAreEqual(kFxRect_Empty, ((FxRect){ 0, 0, 0, 0 })));
	XCTAssertEqual(kFxRect_Infinite.left, INT32_MIN);
	XCTAssertEqual(kFxRect_Infinite.top, INT32_MAX);
	XCTAssertFalse(FxRectsAreEqual(kFxRect_Empty, kFxRect_Infinite));
	XCTAssertEqual(kKeyChar_UpArrow, (unichar)0x21de);
	XCTAssertEqual(kKeyChar_RightArrow, (unichar)0x21e2);
}

#pragma mark - FxMatrix44

/*! @abstract init produces the identity and matrix exposes the row-major storage. */
- (void)testInitProducesTheIdentity
{
	FxMatrix44 *matrix = [[FxMatrix44 alloc] init];
	Matrix44Data *data = [matrix matrix];

	for (int row = 0; row < 4; row++) {
		for (int column = 0; column < 4; column++) {
			XCTAssertEqual((*data)[row][column], row == column ? 1.0 : 0.0);
		}
	}
}

/*! @abstract transform2DPoint: multiplies a row vector by the matrix, so translation lives in row 3. */
- (void)testTransform2DPointUsesTheRowVectorConvention
{
	FxMatrix44 *matrix = [FxMatrix44 stubMatrixWithScaleX:2.0 scaleY:3.0 translationX:10.0 translationY:20.0];

	FxPoint2D point = [matrix transform2DPoint:(FxPoint2D){ 1.0, 1.0 }];

	XCTAssertEqualWithAccuracy(point.x, 12.0, 1e-12);
	XCTAssertEqualWithAccuracy(point.y, 23.0, 1e-12);
	XCTAssertEqual((*[matrix matrix])[3][0], 10.0);
	XCTAssertEqual((*[matrix matrix])[3][1], 20.0);
}

/*! @abstract transform3DPoint: carries z and applies a perspective divide when w differs from one. */
- (void)testTransform3DPointAppliesThePerspectiveDivide
{
	Matrix44Data data = { { 1, 0, 0, 0 }, { 0, 1, 0, 0 }, { 0, 0, 1, 1 }, { 0, 0, 0, 0 } };
	FxMatrix44 *matrix = [[FxMatrix44 alloc] initWithMatrix44Data:data];

	FxPoint3D point = [matrix transform3DPoint:(FxPoint3D){ 4.0, 6.0, 2.0 }];

	XCTAssertEqualWithAccuracy(point.x, 2.0, 1e-12);
	XCTAssertEqualWithAccuracy(point.y, 3.0, 1e-12);
	XCTAssertEqualWithAccuracy(point.z, 1.0, 1e-12);
}

/*! @abstract invert produces the inverse; composing a transform with its inverse returns the original point. */
- (void)testInvertProducesTheInverse
{
	FxMatrix44 *forward = [FxMatrix44 stubMatrixWithScaleX:2.0 scaleY:4.0 translationX:5.0 translationY:-7.0];
	FxMatrix44 *inverse = [[FxMatrix44 alloc] initWithInverseOfFxMatrix:forward];

	FxPoint2D moved = [forward transform2DPoint:(FxPoint2D){ 3.0, 9.0 }];
	FxPoint2D restored = [inverse transform2DPoint:moved];

	XCTAssertNotNil(inverse);
	XCTAssertEqualWithAccuracy(restored.x, 3.0, 1e-9);
	XCTAssertEqualWithAccuracy(restored.y, 9.0, 1e-9);
}

/*! @abstract invert refuses a singular matrix and leaves the data untouched. */
- (void)testInvertRefusesASingularMatrix
{
	Matrix44Data data = { { 1, 2, 0, 0 }, { 2, 4, 0, 0 }, { 0, 0, 1, 0 }, { 0, 0, 0, 1 } };
	FxMatrix44 *matrix = [[FxMatrix44 alloc] initWithMatrix44Data:data];

	XCTAssertFalse([matrix invert]);
	XCTAssertEqual(memcmp(*[matrix matrix], data, sizeof(Matrix44Data)), 0);
	XCTAssertNil([[FxMatrix44 alloc] initWithInverseOfFxMatrix:matrix]);
}

/*! @abstract invertColorMatrixWithTolerance: treats a pivot at or below the tolerance as singular. */
- (void)testInvertColorMatrixHonorsTheTolerance
{
	FxMatrix44 *matrix = [FxMatrix44 stubMatrixWithScale:0.001];

	XCTAssertFalse([matrix invertColorMatrixWithTolerance:0.01]);
	XCTAssertTrue([matrix invertColorMatrixWithTolerance:0.0001]);
	XCTAssertEqualWithAccuracy((*[matrix matrix])[0][0], 1000.0, 1e-9);
}

/*! @abstract transpose swaps rows and columns in place. */
- (void)testTransposeSwapsRowsAndColumns
{
	Matrix44Data data = { { 1, 2, 3, 4 }, { 5, 6, 7, 8 }, { 9, 10, 11, 12 }, { 13, 14, 15, 16 } };
	FxMatrix44 *matrix = [[FxMatrix44 alloc] initWithMatrix44Data:data];

	[matrix transpose];

	XCTAssertEqual((*[matrix matrix])[0][1], 5.0);
	XCTAssertEqual((*[matrix matrix])[1][0], 2.0);
	XCTAssertEqual((*[matrix matrix])[3][0], 4.0);
}

/*! @abstract setMatrix:, setToIdentity, initWithFxMatrix:, and copy keep independent storage. */
- (void)testCopiesAndSettersKeepIndependentStorage
{
	Matrix44Data data = { { 1, 2, 3, 4 }, { 5, 6, 7, 8 }, { 9, 10, 11, 12 }, { 13, 14, 15, 16 } };
	FxMatrix44 *matrix = [[FxMatrix44 alloc] init];
	[matrix setMatrix:data];
	FxMatrix44 *clone = [[FxMatrix44 alloc] initWithFxMatrix:matrix];
	FxMatrix44 *copy = [matrix copy];
	FxMatrix44 *color = [[FxMatrix44 alloc] initWithColorMatrix44Data:data];

	[matrix setToIdentity];

	XCTAssertTrue([clone isEqualToMatrix:copy]);
	XCTAssertTrue([clone isEqualToMatrix:color]);
	XCTAssertEqualObjects(clone, copy);
	XCTAssertEqual(clone.hash, copy.hash);
	XCTAssertFalse([matrix isEqualToMatrix:clone]);
	XCTAssertFalse([matrix isEqual:@"not a matrix"]);
	FxMatrix44 *noMatrix = nil;
	XCTAssertFalse([matrix isEqualToMatrix:noMatrix]);
}

/*! @abstract A matrix survives a secure keyed-archive round trip. */
- (void)testMatrixSurvivesSecureCoding
{
	FxMatrix44 *matrix = [FxMatrix44 stubMatrixWithScaleX:1.5 scaleY:2.5 translationX:3.5 translationY:4.5];
	NSError *error = nil;
	NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:matrix requiringSecureCoding:YES error:&error];
	FxMatrix44 *decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:FxMatrix44.class fromData:archive error:&error];

	XCTAssertTrue([FxMatrix44 supportsSecureCoding]);
	XCTAssertNil(error);
	XCTAssertEqualObjects(decoded, matrix);
	XCTAssertTrue([matrix.description containsString:@"[1.5 0 0 0]"]);
}

/*! @abstract The FxGrip simd conversion sees the stub's storage through the shared ivar. */
- (void)testTheSimdConversionReadsTheStubStorage
{
	FxMatrix44 *matrix = [FxMatrix44 stubMatrixWithScaleX:2.0 scaleY:3.0 translationX:4.0 translationY:5.0];
	simd_float4x4 converted;

	[matrix toFloat4x4Matrix:&converted];

	XCTAssertEqual(converted.columns[0][0], 2.0f);
	XCTAssertEqual(converted.columns[1][1], 3.0f);
	XCTAssertEqual(converted.columns[0][3], 4.0f);
	XCTAssertEqual(converted.columns[1][3], 5.0f);
}

#pragma mark - FxTaggedMenuEntry

/*! @abstract A tagged menu entry keeps the name and tag it was built with. */
- (void)testATaggedMenuEntryKeepsItsNameAndTag
{
	FxTaggedMenuEntry *entry = [FxTaggedMenuEntry taggedMenuEntryWithName:@"Advanced" tag:42];

	XCTAssertTrue([entry isKindOfClass:NSClassFromString(@"FxTaggedMenuEntry")]);
	XCTAssertEqualObjects(entry.menuItemName, @"Advanced");
	XCTAssertEqual(entry.tag, (NSUInteger)42);
	XCTAssertTrue([entry.description containsString:@"tag=42"]);
}

#pragma mark - FxImageTileRequest

/*! @abstract The designated initializer stores every value and equality compares all four. */
- (void)testRequestStoresItsValuesAndComparesThem
{
	CMTime time = CMTimeMake(300, 600);
	FxImageTileRequest *request = [[FxImageTileRequest alloc] initWithSource:kFxImageTileRequestSourceParameter time:time includeFilters:YES parameterID:42];
	FxImageTileRequest *same = [[FxImageTileRequest alloc] initWithSource:kFxImageTileRequestSourceParameter time:time includeFilters:YES parameterID:42];
	FxImageTileRequest *other = [[FxImageTileRequest alloc] initWithSource:kFxImageTileRequestSourceParameter time:time includeFilters:NO parameterID:42];

	XCTAssertEqual(request.source, kFxImageTileRequestSourceParameter);
	XCTAssertEqual(CMTimeCompare(request.requestTime, time), 0);
	XCTAssertTrue(request.includeLeadingFilters);
	XCTAssertEqual(request.parameterID, (UInt32)42);
	XCTAssertEqualObjects(request, same);
	XCTAssertEqual(request.hash, same.hash);
	XCTAssertNotEqualObjects(request, other);
	XCTAssertNotEqualObjects(request, @"request");
	XCTAssertTrue([request.description containsString:@"parameterID=42"]);
}

/*! @abstract The plain init is the none source at time zero, and the writable properties take effect. */
- (void)testRequestInitAndWritableProperties
{
	FxImageTileRequest *request = [[FxImageTileRequest alloc] init];

	XCTAssertEqual(request.source, kFxImageTileRequestSourceNone);
	XCTAssertEqual(CMTimeCompare(request.requestTime, kCMTimeZero), 0);

	request.source = kFxImageTileRequestSourceOutput;
	request.parameterID = 7;

	XCTAssertEqual(request.source, kFxImageTileRequestSourceOutput);
	XCTAssertEqual(request.parameterID, (UInt32)7);
}

/*! @abstract A request survives a secure keyed-archive round trip. */
- (void)testRequestSurvivesSecureCoding
{
	FxImageTileRequest *request = [[FxImageTileRequest alloc] initWithSource:kFxImageTileRequestSourceEffectClip time:CMTimeMake(7, 25) includeFilters:YES parameterID:3];
	NSError *error = nil;
	NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:request requiringSecureCoding:YES error:&error];
	FxImageTileRequest *decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:FxImageTileRequest.class fromData:archive error:&error];

	XCTAssertNil(error);
	XCTAssertEqualObjects(decoded, request);
}

#pragma mark - FxImageTile

/*! @abstract stubTileWithPixelBounds: shares the bounds, uses identity transforms, and has no surface. */
- (void)testStubTileWithPixelBoundsIsAPlainTile
{
	FxRect bounds = { 10, 20, 110, 70 };
	FxImageTile *tile = [FxImageTile stubTileWithPixelBounds:bounds];

	XCTAssertTrue(FxRectsAreEqual(tile.imagePixelBounds, bounds));
	XCTAssertTrue(FxRectsAreEqual(tile.tilePixelBounds, bounds));
	XCTAssertTrue([tile.pixelTransform isEqualToMatrix:[[FxMatrix44 alloc] init]]);
	XCTAssertTrue([tile.inversePixelTransform isEqualToMatrix:[[FxMatrix44 alloc] init]]);
	XCTAssertNil(tile.ioSurface);
	XCTAssertEqual(tile.imageSource, kFxImageTileRequestSourceEffectClip);
	XCTAssertNil([tile metalTextureForDevice:MTLCreateSystemDefaultDevice()]);
	XCTAssertEqual([tile openGLTextureForContext:NULL], (GLuint)0);
	XCTAssertEqual(tile.pixelAspect, 1.0);
	XCTAssertTrue([tile.description containsString:@"surface=none"]);
}

/*! @abstract The writable properties and the color space retain take effect. */
- (void)testWritablePropertiesAndColorSpaceRetain
{
	FxImageTile *tile = [[FxImageTile alloc] init];
	CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
	NSError *requestError = [NSError errorWithDomain:@"Stub" code:9 userInfo:nil];

	tile.colorSpace = colorSpace;
	tile.colorSpace = colorSpace;
	tile.deviceRegistryID = 77;
	tile.field = 1;
	tile.fieldOrder = 2;
	tile.imageOrigin = 1;
	tile.eyeType = 2;
	tile.parameterID = 5;
	tile.mediaTime = CMTimeMake(10, 30);
	tile.requestError = requestError;
	tile.pixelTransform = [FxMatrix44 stubMatrixWithScale:2.0];
	CGColorSpaceRelease(colorSpace);

	XCTAssertEqual(tile.colorSpace, colorSpace);
	XCTAssertEqual(tile.deviceRegistryID, (uint64_t)77);
	XCTAssertEqual(tile.field, (FxField)1);
	XCTAssertEqual(tile.fieldOrder, (FxFieldOrder)2);
	XCTAssertEqual(tile.imageOrigin, (FxImageOrigin)1);
	XCTAssertEqual(tile.eyeType, (FxEyeType)2);
	XCTAssertEqual(tile.parameterID, (UInt32)5);
	XCTAssertEqual(CMTimeCompare(tile.mediaTime, CMTimeMake(10, 30)), 0);
	XCTAssertEqualObjects(tile.requestError, requestError);
	XCTAssertEqual(tile.scaleX, 2.0);
	XCTAssertEqual(tile.scaleY, 2.0);

	tile.colorSpace = NULL;
	XCTAssertTrue(tile.colorSpace == NULL);
}

/*! @abstract A surface-backed tile answers one cached Metal texture per device with the mapped pixel format. */
- (void)testSurfaceBackedTileAnswersACachedTexturePerDevice
{
	id<MTLDevice> device = MTLCreateSystemDefaultDevice();
	XCTSkipIf(device == nil, @"No Metal device.");
	FxRect bounds = { 0, 0, 64, 32 };
	FxImageTile *tile = [FxImageTile stubTileWithPixelBounds:bounds pixelFormat:kCVPixelFormatType_64RGBAHalf device:device];

	id<MTLTexture> first = [tile metalTextureForDevice:device];
	id<MTLTexture> second = [tile metalTextureForDevice:device];

	XCTAssertNotNil(tile);
	XCTAssertEqual(tile.deviceRegistryID, device.registryID);
	XCTAssertEqual(tile.ioSurface.width, (NSInteger)64);
	XCTAssertEqual(tile.ioSurface.height, (NSInteger)32);
	XCTAssertEqual(tile.ioSurface.pixelFormat, (OSType)kCVPixelFormatType_64RGBAHalf);
	XCTAssertNotNil(first);
	XCTAssertEqual(first, second);
	XCTAssertEqual(first.pixelFormat, MTLPixelFormatRGBA16Float);
	XCTAssertEqual(first.width, (NSUInteger)64);
	XCTAssertEqual(first.height, (NSUInteger)32);
	XCTAssertEqual(tile.stubRequestedDevices.count, (NSUInteger)2);
	XCTAssertTrue([tile.description containsString:@"surface=64x32"]);
}

/*! @abstract Every supported IOSurface format maps to its Metal format, and unknown formats are refused. */
- (void)testPixelFormatMappingCoversTheSupportedFormats
{
	XCTAssertEqual([FxImageTile stubMetalPixelFormatForIOSurfaceFormat:kCVPixelFormatType_32BGRA], MTLPixelFormatBGRA8Unorm);
	XCTAssertEqual([FxImageTile stubMetalPixelFormatForIOSurfaceFormat:kCVPixelFormatType_32RGBA], MTLPixelFormatRGBA8Unorm);
	XCTAssertEqual([FxImageTile stubMetalPixelFormatForIOSurfaceFormat:kCVPixelFormatType_64RGBALE], MTLPixelFormatRGBA16Unorm);
	XCTAssertEqual([FxImageTile stubMetalPixelFormatForIOSurfaceFormat:kCVPixelFormatType_64RGBAHalf], MTLPixelFormatRGBA16Float);
	XCTAssertEqual([FxImageTile stubMetalPixelFormatForIOSurfaceFormat:kCVPixelFormatType_128RGBAFloat], MTLPixelFormatRGBA32Float);
	XCTAssertEqual([FxImageTile stubMetalPixelFormatForIOSurfaceFormat:kCVPixelFormatType_422YpCbCr8], MTLPixelFormatInvalid);

	XCTAssertNil([FxImageTile stubTileWithPixelBounds:((FxRect){ 0, 0, 8, 8 }) pixelFormat:kCVPixelFormatType_422YpCbCr8 device:nil]);
	XCTAssertNil([FxImageTile stubTileWithPixelBounds:((FxRect){ 0, 0, 0, 8 }) pixelFormat:kCVPixelFormatType_32BGRA device:nil]);
	XCTAssertNotNil([FxImageTile stubTileWithPixelBounds:((FxRect){ 0, 0, 8, 8 }) pixelFormat:kCVPixelFormatType_128RGBAFloat device:nil]);
}

/*! @abstract A scripted provider wins over a scripted texture, which wins over the surface. */
- (void)testScriptedTexturesTakePrecedenceOverTheSurface
{
	id<MTLDevice> device = MTLCreateSystemDefaultDevice();
	XCTSkipIf(device == nil, @"No Metal device.");
	FxImageTile *tile = [FxImageTile stubTileWithPixelBounds:(FxRect){ 0, 0, 4, 4 } pixelFormat:kCVPixelFormatType_32BGRA device:device];
	MTLTextureDescriptor *descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:2 height:2 mipmapped:NO];
	id<MTLTexture> scripted = [device newTextureWithDescriptor:descriptor];
	id<MTLTexture> provided = [device newTextureWithDescriptor:descriptor];
	__block id<MTLDevice> seenDevice = nil;

	tile.stubTexture = scripted;
	XCTAssertEqual([tile metalTextureForDevice:device], scripted);

	tile.stubTextureProvider = ^id<MTLTexture>(id<MTLDevice> requested) {
		seenDevice = requested;
		return provided;
	};
	XCTAssertEqual([tile metalTextureForDevice:device], provided);
	XCTAssertEqual(seenDevice, device);

	tile.stubTextureProvider = nil;
	tile.stubTexture = nil;
	XCTAssertEqual([tile metalTextureForDevice:device].pixelFormat, MTLPixelFormatBGRA8Unorm);
	XCTAssertNil([tile metalTextureForDevice:nil]);
}

/*! @abstract A tile's scalar state and transforms survive a secure keyed-archive round trip; the surface does not travel. */
- (void)testTileSurvivesSecureCoding
{
	FxImageTile *tile = [[FxImageTile alloc] initWithImagePixelBounds:(FxRect){ 0, 0, 100, 50 } tilePixelBounds:(FxRect){ 10, 10, 60, 40 }];
	tile.pixelTransform = [FxMatrix44 stubMatrixWithScale:0.5];
	tile.inversePixelTransform = [FxMatrix44 stubMatrixWithScale:2.0];
	tile.deviceRegistryID = 99;
	tile.field = 2;
	tile.fieldOrder = 1;
	tile.imageOrigin = 1;
	tile.eyeType = 1;
	tile.imageSource = kFxImageTileRequestSourceParameter;
	tile.parameterID = 12;
	tile.mediaTime = CMTimeMake(48, 24);
	tile.requestError = [NSError errorWithDomain:@"Stub" code:1 userInfo:nil];
	NSError *error = nil;

	NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:tile requiringSecureCoding:YES error:&error];
	FxImageTile *decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:FxImageTile.class fromData:archive error:&error];

	XCTAssertTrue([FxImageTile supportsSecureCoding]);
	XCTAssertNil(error);
	XCTAssertTrue(FxRectsAreEqual(decoded.imagePixelBounds, tile.imagePixelBounds));
	XCTAssertTrue(FxRectsAreEqual(decoded.tilePixelBounds, tile.tilePixelBounds));
	XCTAssertEqualObjects(decoded.pixelTransform, tile.pixelTransform);
	XCTAssertEqualObjects(decoded.inversePixelTransform, tile.inversePixelTransform);
	XCTAssertEqual(decoded.deviceRegistryID, (uint64_t)99);
	XCTAssertEqual(decoded.field, (FxField)2);
	XCTAssertEqual(decoded.fieldOrder, (FxFieldOrder)1);
	XCTAssertEqual(decoded.imageOrigin, (FxImageOrigin)1);
	XCTAssertEqual(decoded.eyeType, (FxEyeType)1);
	XCTAssertEqual(decoded.imageSource, kFxImageTileRequestSourceParameter);
	XCTAssertEqual(decoded.parameterID, (UInt32)12);
	XCTAssertEqual(CMTimeCompare(decoded.mediaTime, CMTimeMake(48, 24)), 0);
	XCTAssertEqualObjects(decoded.requestError.domain, @"Stub");
	XCTAssertNil(decoded.ioSurface);
}

@end
