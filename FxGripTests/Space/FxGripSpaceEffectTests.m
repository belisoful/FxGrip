/*!
	@file       FxGripSpaceEffectTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-09
	@header     FxGripSpaceEffectTests
	@abstract   Tests for FxGripSpaceEffect, the engine-neutral base of a 3D Space effect.
	@discussion Introduced in FxGrip 0.1.0. The tests cover the whole-frame render flags, the capture
	            ordering of the engine and plugin hooks, the inter-particle force round trip through
	            plugin state, and the decode helpers on a coder that holds no host state. Hook
	            subclasses stand in for an engine and for a plugin; no render engine is imported.
*/

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripSpaceEffect.h>
#import <FxGrip/FxGripParticleInteraction.h>
#import <FxGrip/FxGripPhysicsSimulationStore.h>
#import <FxGrip/FxGripErrors.h>
#import <FxGrip/NSCoder+FxPlug.h>
#import <CoreVideo/CoreVideo.h>
#import <Metal/Metal.h>
#import "FxPlugStub.h"

#pragma mark - Hook subclass

// Records the order in which the engine hook and the plugin seam run.
@interface FxGripSpaceHookEffect : FxGripSpaceEffect
@property (nonatomic, strong) NSMutableArray<NSString *> *calls;
@property (nonatomic, assign) BOOL engineFails;
@end

@implementation FxGripSpaceHookEffect
- (instancetype)initWithAPIManager:(id<PROAPIAccessing>)apiManager
{
	self = [super initWithAPIManager:apiManager];
	if (self != nil) {
		_calls = [NSMutableArray array];
	}
	return self;
}
- (BOOL)encodeEngineStateIntoCoder:(NSCoder *)coder atTime:(CMTime)renderTime error:(NSError **)error
{
	[self.calls addObject:@"engine"];
	[coder encodeInteger:7 forKey:@"engineValue"];
	return !self.engineFails;
}
- (BOOL)encodeSceneParametersIntoCoder:(NSCoder *)coder atTime:(CMTime)renderTime error:(NSError **)error
{
	[self.calls addObject:@"plugin"];
	[coder encodeInteger:42 forKey:@"customValue"];
	return YES;
}
@end

#pragma mark - Tests

@interface FxGripSpaceEffectTests : XCTestCase
@property (nonatomic, strong) FxGripSpaceEffect *effect;
@end

@implementation FxGripSpaceEffectTests

- (void)setUp
{
	[super setUp];
	self.effect = [FxGripSpaceEffect.alloc initWithAPIManager:(id _Nonnull)nil];
}

// Runs the capture pass on `effect` and returns a decoder over the plugin state it produced.
- (NSCoder *)decoderForCaptureOfEffect:(FxGripSpaceEffect *)effect
{
	NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:YES];
	NSError *error = nil;
	XCTAssertTrue([effect pluginCoder:archiver atTime:kCMTimeZero quality:(FxQuality)kFxQuality_HIGH error:&error], @"%@", error);
	[archiver finishEncoding];
	NSKeyedUnarchiver *decoder = [[NSKeyedUnarchiver alloc] initForReadingFromData:archiver.encodedData error:nil];
	decoder.requiresSecureCoding = NO;
	return decoder;
}

/*! @abstract An effect renders the source layer plane by default. */
- (void)testRendersSourceLayerPlaneDefaultsYes
{
	XCTAssertTrue(self.effect.rendersSourceLayerPlane);
}

/*! @abstract An effect needs the full buffer, since it renders the whole frame. */
- (void)testNeedsFullBufferForWholeFrameRender
{
	XCTAssertTrue(self.effect.needsFullBuffer);
}

/*! @abstract The base capture hooks succeed and report no error without encoding anything. */
- (void)testDefaultHooksAreNoOps
{
	NSKeyedArchiver *coder = [[NSKeyedArchiver alloc] initRequiringSecureCoding:YES];
	NSError *error = nil;
	XCTAssertTrue([self.effect encodeSceneParametersIntoCoder:coder atTime:kCMTimeZero error:&error]);
	XCTAssertTrue([self.effect encodeEngineStateIntoCoder:coder atTime:kCMTimeZero error:&error]);
	XCTAssertNil(error);
}

/*! @abstract -pluginCoder: runs the engine hook before the plugin seam, and both values reach the plugin state. */
- (void)testCaptureRunsEngineHookThenPluginSeam
{
	FxGripSpaceHookEffect *effect = [FxGripSpaceHookEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	NSCoder *decoder = [self decoderForCaptureOfEffect:effect];

	XCTAssertEqualObjects(effect.calls, (@[@"engine", @"plugin"]));
	XCTAssertEqual([decoder decodeIntegerForKey:@"engineValue"], 7);
	XCTAssertEqual([decoder decodeIntegerForKey:@"customValue"], 42);
}

/*! @abstract A failing engine hook fails the capture and skips the plugin seam. */
- (void)testFailingEngineHookStopsTheCapture
{
	FxGripSpaceHookEffect *effect = [FxGripSpaceHookEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	effect.engineFails = YES;
	NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:YES];
	NSError *error = nil;

	XCTAssertFalse([effect pluginCoder:archiver atTime:kCMTimeZero quality:(FxQuality)kFxQuality_HIGH error:&error]);
	XCTAssertEqualObjects(effect.calls, @[@"engine"]);
}

/*! @abstract The scene-wide interaction and the field configurations round-trip through plugin state. */
- (void)testParticleInteractionsRoundTripThroughPluginState
{
	FxGripParticleInteraction *interaction = [FxGripParticleInteraction gravityWithStrength:1.5];
	interaction.softening = 0.3;
	self.effect.particleInteraction = interaction;
	self.effect.particleInteractionFields = @{ @"emitter": [FxGripParticleInteraction gravityWithStrength:2.0] };

	NSCoder *decoder = [self decoderForCaptureOfEffect:self.effect];
	FxGripParticleInteraction *decoded = [self.effect decodeParticleInteractionFromCoder:decoder];
	XCTAssertEqualWithAccuracy(decoded.gravityStrength, 1.5, 1e-9);
	XCTAssertEqualWithAccuracy(decoded.softening, 0.3, 1e-9);

	NSDictionary<NSString *, FxGripParticleInteraction *> *fields = [self.effect decodeParticleInteractionFieldsFromCoder:decoder];
	XCTAssertEqual(fields.count, 1u);
	XCTAssertEqualWithAccuracy(fields[@"emitter"].gravityStrength, 2.0, 1e-9);
}

/*! @abstract An effect with no interactions leaves nothing in plugin state for the decoders to find. */
- (void)testNoParticleInteractionsDecodeToNil
{
	NSCoder *decoder = [self decoderForCaptureOfEffect:self.effect];
	XCTAssertNil([self.effect decodeParticleInteractionFromCoder:decoder]);
	XCTAssertNil([self.effect decodeParticleInteractionFieldsFromCoder:decoder]);
}

/*! @abstract Without host state the transform decoders return NO and leave the output untouched. */
- (void)testTransformDecodersReportAbsentHostState
{
	NSCoder *decoder = [self decoderForCaptureOfEffect:self.effect];
	simd_float4x4 transform = matrix_identity_float4x4;
	transform.columns[3].x = 5.0f;

	XCTAssertFalse([self.effect decodeCameraTransform:&transform fromCoder:decoder]);
	XCTAssertFalse([self.effect decodeLayerTransform:&transform fromCoder:decoder]);
	XCTAssertFalse([self.effect decodeProjectionMatrix:&transform fromCoder:decoder]);
	XCTAssertEqual(transform.columns[3].x, 5.0f, @"an absent matrix leaves the output unchanged");
}

/*! @abstract The projection decoder returns the host matrix transposed into the simd column-vector
	convention, which is what an engine installs on its camera. */
- (void)testProjectionMatrixDecodesFromHostRowMajorIntoColumns
{
	NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:NO];
	// Row-major, the layout the host reports and Matrix44Data stores.
	Matrix44Data stored = {
		{  1.0,  2.0,  3.0,  4.0 },
		{  5.0,  6.0,  7.0,  8.0 },
		{  9.0, 10.0, 11.0, 12.0 },
		{ 13.0, 14.0, 15.0, 16.0 }
	};
	[archiver encodeMatrix44Data:&stored
						  forKey:[FxGrip3DCoderCurrentTimeKey stringByAppendingString:FxGrip3DCoderProjectionMatrixKey]];
	[archiver finishEncoding];
	NSKeyedUnarchiver *decoder = [[NSKeyedUnarchiver alloc] initForReadingFromData:archiver.encodedData error:nil];
	decoder.requiresSecureCoding = NO;

	simd_float4x4 projection = matrix_identity_float4x4;
	XCTAssertTrue([self.effect decodeProjectionMatrix:&projection fromCoder:decoder]);

	// Row 0 of the host matrix becomes column 0 in simd.
	XCTAssertEqual(projection.columns[0].x, 1.0f);
	XCTAssertEqual(projection.columns[0].y, 2.0f);
	XCTAssertEqual(projection.columns[3].w, 16.0f);
	XCTAssertEqual(projection.columns[1].x, 5.0f);
}

/*! @abstract Without the view-matrix samples the camera motion is zero. */
- (void)testCameraMotionIsZeroWithoutSamples
{
	NSCoder *decoder = [self decoderForCaptureOfEffect:self.effect];
	FxGripCameraMotion motion = [self.effect cameraMotionFromCoder:decoder];
	XCTAssertEqual(simd_length(motion.linearVelocity), 0.0f);
	XCTAssertEqual(simd_length(motion.angularVelocity), 0.0f);
}

/*! @abstract The engine-neutral store seam refuses on the base, which owns no render engine, so a
	physics bake loaded onto a bare space effect stays inert. */
- (void)testInstallingASimulationStoreRefusesOnTheBase
{
	FxGripPhysicsMemoryStore *store = [FxGripPhysicsMemoryStore.alloc init];
	XCTAssertFalse([self.effect installPhysicsSimulationStore:store]);
}

/*! @abstract The space error carries the space-render code and the reason. */
- (void)testSpaceErrorCarriesCodeAndReason
{
	NSError *error = [self.effect spaceErrorWithReason:@"why"];
	XCTAssertNotNil(error.domain);
	XCTAssertEqual(error.code, kFxGripError_SpaceRenderFailure);
	XCTAssertEqualObjects(error.localizedDescription, @"why");
}

@end

#pragma mark - The tile-facing entry points

/*!
	Drives the FxPlug entry points that take image tiles. FxPlug ships no binary, so FxImageTile did
	not exist in the test process and these never ran; the FxPlugStub test framework supplies the
	class, and these tests hand the effect real IOSurface-backed tiles.
*/
@interface FxGripSpaceEffectTileTests : XCTestCase
@property (nonatomic, strong) FxGripSpaceEffect *effect;
@property (nonatomic, strong) id<MTLDevice> device;
@end

@implementation FxGripSpaceEffectTileTests

- (void)setUp
{
	[super setUp];
	self.effect = [FxGripSpaceEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	self.device = MTLCreateSystemDefaultDevice();
}

- (void)tearDown
{
	self.effect = nil;
	self.device = nil;
	[super tearDown];
}

- (FxImageTile *)tileWithBounds:(FxRect)bounds
{
	return [FxImageTile stubTileWithPixelBounds:bounds
									pixelFormat:kCVPixelFormatType_64RGBAHalf
										 device:self.device];
}

- (NSCoder *)emptyCoder
{
	NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:NO];
	[archiver finishEncoding];
	NSKeyedUnarchiver *decoder = [[NSKeyedUnarchiver alloc] initForReadingFromData:archiver.encodedData error:nil];
	decoder.requiresSecureCoding = NO;
	return decoder;
}

/*! @abstract The destination image rect is the destination tile's own image bounds. */
- (void)testTheDestinationImageRectIsTheDestinationTilesImageBounds
{
	FxRect bounds = { 10, 20, 110, 220 };
	FxImageTile *destination = [FxImageTile stubTileWithPixelBounds:bounds];
	FxRect result = { 0, 0, 0, 0 };
	NSError *error = nil;

	XCTAssertTrue([self.effect destinationImageRect:&result
									   sourceImages:@[]
								   destinationImage:destination
										pluginCoder:[self emptyCoder]
											 atTime:kCMTimeZero
											  error:&error]);

	XCTAssertTrue(FxRectsAreEqual(result, bounds));
	XCTAssertNil(error);
}

/*! @abstract The source tile rect is the indexed source's full image bounds, so the whole layer is available. */
- (void)testTheSourceTileRectIsTheIndexedSourcesImageBounds
{
	FxRect first = { 0, 0, 50, 50 };
	FxRect second = { 5, 5, 105, 205 };
	NSArray *sources = @[[FxImageTile stubTileWithPixelBounds:first],
						 [FxImageTile stubTileWithPixelBounds:second]];
	FxRect result = { 0, 0, 0, 0 };
	NSError *error = nil;

	XCTAssertTrue([self.effect sourceTileRect:&result
							 sourceImageIndex:1
								 sourceImages:sources
						  destinationTileRect:((FxRect){ 0, 0, 10, 10 })
							 destinationImage:[FxImageTile stubTileWithPixelBounds:first]
								  pluginCoder:[self emptyCoder]
									   atTime:kCMTimeZero
										error:&error]);

	XCTAssertTrue(FxRectsAreEqual(result, second));
	XCTAssertNil(error);
}

/*! @abstract An out-of-range source index falls back to the destination tile rect. */
- (void)testAnOutOfRangeSourceIndexFallsBackToTheDestinationTileRect
{
	FxRect destinationTileRect = { 1, 2, 3, 4 };
	FxRect result = { 0, 0, 0, 0 };
	NSError *error = nil;

	XCTAssertTrue([self.effect sourceTileRect:&result
							 sourceImageIndex:5
								 sourceImages:@[]
						  destinationTileRect:destinationTileRect
							 destinationImage:[FxImageTile stubTileWithPixelBounds:destinationTileRect]
								  pluginCoder:[self emptyCoder]
									   atTime:kCMTimeZero
										error:&error]);

	XCTAssertTrue(FxRectsAreEqual(result, destinationTileRect));
	XCTAssertNil(error);
}

/*! @abstract The render reports an error when the destination tile carries no Metal texture. */
- (void)testTheRenderReportsAnErrorWithoutADestinationTexture
{
	FxImageTile *destination = [FxImageTile stubTileWithPixelBounds:((FxRect){ 0, 0, 8, 8 })];
	NSError *error = nil;

	XCTAssertFalse([self.effect renderDestinationImage:destination
										  sourceImages:@[]
										   pluginCoder:[self emptyCoder]
												atTime:kCMTimeZero
												 error:&error]);

	XCTAssertNotNil(error);
	XCTAssertTrue([error.localizedDescription containsString:@"Metal texture"]);
}

/*! @abstract With a destination texture and no source, the base's passthrough render succeeds. */
- (void)testTheRenderSucceedsWithNoSourceTile
{
	XCTSkipIf(self.device == nil, @"No Metal device.");
	FxImageTile *destination = [self tileWithBounds:((FxRect){ 0, 0, 8, 8 })];
	NSError *error = nil;

	XCTAssertTrue([self.effect renderDestinationImage:destination
										 sourceImages:@[]
										  pluginCoder:[self emptyCoder]
											   atTime:kCMTimeZero
												error:&error]);

	XCTAssertNil(error);
}

/*! @abstract The base's passthrough copies the source tile's pixels into the destination texture. */
- (void)testThePassthroughCopiesTheSourceIntoTheDestination
{
	XCTSkipIf(self.device == nil, @"No Metal device.");
	FxImageTile *source = [self tileWithBounds:((FxRect){ 0, 0, 8, 8 })];
	FxImageTile *destination = [self tileWithBounds:((FxRect){ 0, 0, 8, 8 })];
	id<MTLTexture> sourceTexture = [source metalTextureForDevice:self.device];
	id<MTLTexture> destinationTexture = [destination metalTextureForDevice:self.device];

	// A known half-float green pixel, so the copy is observable rather than assumed.
	const uint16_t green[4] = { 0x0000, 0x3C00, 0x0000, 0x3C00 };
	[sourceTexture replaceRegion:MTLRegionMake2D(0, 0, 1, 1) mipmapLevel:0 withBytes:green bytesPerRow:8 * 8];
	NSError *error = nil;

	XCTAssertTrue([self.effect renderDestinationImage:destination
										 sourceImages:@[source]
										  pluginCoder:[self emptyCoder]
											   atTime:kCMTimeZero
												error:&error]);

	XCTAssertNil(error);
	uint16_t readBack[4] = { 0, 0, 0, 0 };
	[destinationTexture getBytes:readBack bytesPerRow:8 * 8 fromRegion:MTLRegionMake2D(0, 0, 1, 1) mipmapLevel:0];
	XCTAssertEqual(readBack[1], green[1]);
	XCTAssertEqual(readBack[3], green[3]);
}

/*! @abstract A source tile with no Metal texture leaves the destination untouched and still succeeds. */
- (void)testAPassthroughFromATileWithoutATextureSucceedsWithoutCopying
{
	XCTSkipIf(self.device == nil, @"No Metal device.");
	FxImageTile *destination = [self tileWithBounds:((FxRect){ 0, 0, 8, 8 })];
	FxImageTile *source = [FxImageTile stubTileWithPixelBounds:((FxRect){ 0, 0, 8, 8 })];
	NSError *error = nil;

	XCTAssertTrue([self.effect renderDestinationImage:destination
										 sourceImages:@[source]
										  pluginCoder:[self emptyCoder]
											   atTime:kCMTimeZero
												error:&error]);

	XCTAssertNil(error);
}

/*! @abstract The passthrough copies only the overlap when the two tiles differ in size. */
- (void)testThePassthroughCopiesOnlyTheOverlappingRegion
{
	XCTSkipIf(self.device == nil, @"No Metal device.");
	FxImageTile *source = [self tileWithBounds:((FxRect){ 0, 0, 16, 16 })];
	FxImageTile *destination = [self tileWithBounds:((FxRect){ 0, 0, 8, 8 })];
	NSError *error = nil;

	XCTAssertTrue([self.effect renderDestinationImage:destination
										 sourceImages:@[source]
										  pluginCoder:[self emptyCoder]
											   atTime:kCMTimeZero
												error:&error]);

	XCTAssertNil(error);
}

@end
