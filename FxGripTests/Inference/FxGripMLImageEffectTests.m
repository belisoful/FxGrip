/*!
	@file       FxGripMLImageEffectTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripMLImageEffectTests
	@abstract   Verifies the FxGripMLImageEffect per-frame inference render and its output cache.
	@discussion Introduced in FxGrip 0.1.0. A stub backend stages readiness and a result, and a test effect subclass bypasses Metal with a sentinel source image and a captured output. The tests confirm the default backend is passthrough, the default-backend seam is overridable, the InferKit hook is a no-op without the framework, and the render routes source and parameters to the backend and the named output back to the destination. A cache test class confirms one inference per frame, a rerun for a new frame, invalidation on a changed parameter signature, and a run every frame when the cache is disabled.
*/

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripMLImageEffect.h>
#import <FxGrip/FxGripInferenceBackend.h>
#import <FxGrip/FxGripInferenceRequest.h>
#import <FxGrip/FxGripInferenceResult.h>
#import <FxGrip/FxGripPassthroughBackend.h>
#import <FxGrip/FxGripErrors.h>
#import <FxGrip/FxGripFrameData.h>
#import <FxGrip/FxGripMLCache.h>
#import <FxGrip/FxGripImageBuffer.h>
#import <CoreVideo/CoreVideo.h>
#import "FxPlugStub.h"

static CMTime FxGripMLTestTime(void)
{
	return (CMTime){ .value = 0, .timescale = 30, .flags = kCMTimeFlags_Valid };
}

#pragma mark - Stub backend

/*! A backend whose readiness and result are staged, recording the request it received. */
@interface FxGripMLStubBackend : NSObject <FxGripInferenceBackend>
@property (nonatomic, assign) BOOL ready;
@property (nonatomic, strong, nullable) FxGripInferenceResult *stagedResult;
@property (nonatomic, strong, nullable) FxGripInferenceRequest *lastRequest;
@property (nonatomic, assign) NSUInteger runCount;
@end

@implementation FxGripMLStubBackend

- (instancetype)init
{
	self = [super init];
	if (self) {
		_ready = YES;
	}
	return self;
}

- (BOOL)isReady { return self.ready; }
- (NSString *)backendIdentifier { return @"stub"; }

- (FxGripInferenceResult *)runInferenceForRequest:(FxGripInferenceRequest *)request error:(NSError **)error
{
	self.lastRequest = request;
	self.runCount += 1;
	return self.stagedResult;
}

@end

#pragma mark - Test effect

/*! Bypasses Metal: the source image is a sentinel string, and the written output is captured. */
@interface FxGripMLTestEffect : FxGripMLImageEffect
@property (nonatomic, strong) NSNotificationCenter *privateNotifier;
@property (nonatomic, strong) id capturedOutput;
@property (nonatomic, strong) NSDictionary<NSString *, id> *stagedParameters;
@end

@implementation FxGripMLTestEffect

- (id)effectBase
{
	// The stub plays the full effect; rich reads route back to it, as the old cast did.
	return self;
}


- (NSPriorityNotificationCenter *)notifier
{
	if (!_privateNotifier) {
		Class cls = NSClassFromString(@"NSPriorityNotificationCenter");
		_privateNotifier = [[cls alloc] init];
	}
	return (NSPriorityNotificationCenter *)_privateNotifier;
}

- (id<FxGripAPIAccessing>)apiManager
{
	return nil;
}

- (id)imageInputForSourceTile:(FxImageTile *)sourceTile atTime:(CMTime)time error:(NSError **)outError
{
	return @"SOURCE";
}

- (BOOL)writeImageOutput:(id)output toDestinationTile:(FxImageTile *)destinationTile atTime:(CMTime)time error:(NSError **)outError
{
	self.capturedOutput = output;
	return YES;
}

- (NSDictionary<NSString *, id> *)inferenceParametersAtTime:(CMTime)time
{
	return self.stagedParameters ?: @{};
}

@end

/*! Overrides the default-backend seam to prove the lazy default is customizable. */
@interface FxGripMLDefaultOverrideEffect : FxGripMLTestEffect
@end

@implementation FxGripMLDefaultOverrideEffect
- (id<FxGripInferenceBackend>)defaultInferenceBackend
{
	return FxGripMLStubBackend.new;
}
@end

#pragma mark - Tests

@interface FxGripMLImageEffectTests : XCTestCase
@property (nonatomic, strong) FxGripMLTestEffect *effect;
@end

@implementation FxGripMLImageEffectTests

- (void)setUp
{
	[super setUp];
	self.effect = [FxGripMLTestEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	// These tests exercise pure orchestration; the cache has its own tests.
	self.effect.cacheEnabled = NO;
}

/*! @abstract A new effect uses the passthrough backend and the default input and output image name of "image". */
- (void)testTheDefaultBackendIsPassthrough
{
	XCTAssertEqualObjects(self.effect.inferenceBackend.backendIdentifier, @"passthrough");
	XCTAssertEqualObjects([self.effect inputImageName], @"image");
	XCTAssertEqualObjects([self.effect outputImageName], @"image");
}

/*! @abstract The default-backend seam returns a passthrough backend. */
- (void)testDefaultInferenceBackendSeamReturnsPassthrough
{
	XCTAssertEqualObjects([self.effect defaultInferenceBackend].backendIdentifier, @"passthrough");
}

/*! @abstract A subclass that overrides the default-backend seam supplies that backend as the lazy default. */
- (void)testOverridingTheDefaultBackendSeamChangesTheLazyDefault
{
	FxGripMLDefaultOverrideEffect *effect = [FxGripMLDefaultOverrideEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	XCTAssertEqualObjects(effect.inferenceBackend.backendIdentifier, @"stub");
}

/*! @abstract Using an InferKit backend fails and leaves the current backend in place while InferKit is not linked. */
- (void)testUseInferKitBackendIsANoOpWithoutInferKit
{
	id<FxGripInferenceBackend> before = self.effect.inferenceBackend;
	XCTAssertFalse([self.effect useInferKitBackend:NSObject.new], @"InferKit is not linked in the test bundle");
	id noBackend = nil;
	XCTAssertFalse([self.effect useInferKitBackend:noBackend]);
	XCTAssertEqual(self.effect.inferenceBackend, before, @"a failed bridge leaves the backend unchanged");
}

/*! @abstract With the passthrough backend, the render writes the source image unchanged to the destination. */
- (void)testTheDefaultBackendEchoesTheSourceToTheDestination
{
	NSError *error = nil;
	BOOL rendered = [self.effect renderMLFromSourceTile:nil toDestinationTile:nil atTime:FxGripMLTestTime() error:&error];
	XCTAssertTrue(rendered);
	XCTAssertNil(error);
	XCTAssertEqualObjects(self.effect.capturedOutput, @"SOURCE", @"passthrough routes the source straight through");
}

/*! @abstract A not-ready backend renders the source unchanged and is never run. */
- (void)testANotReadyBackendRendersTheSourceUnchanged
{
	FxGripMLStubBackend *backend = FxGripMLStubBackend.new;
	backend.ready = NO;
	self.effect.inferenceBackend = backend;

	NSError *error = nil;
	BOOL rendered = [self.effect renderMLFromSourceTile:nil toDestinationTile:nil atTime:FxGripMLTestTime() error:&error];
	XCTAssertTrue(rendered);
	XCTAssertEqualObjects(self.effect.capturedOutput, @"SOURCE");
	XCTAssertNil(backend.lastRequest, @"a not-ready backend is not run");
}

/*! @abstract The backend output stored under the output image name is written to the destination. */
- (void)testTheBackendOutputIsRoutedByOutputName
{
	FxGripMLStubBackend *backend = FxGripMLStubBackend.new;
	backend.stagedResult = [FxGripInferenceResult resultWithOutputs:@{ @"image": @"GENERATED" }];
	self.effect.inferenceBackend = backend;

	NSError *error = nil;
	BOOL rendered = [self.effect renderMLFromSourceTile:nil toDestinationTile:nil atTime:FxGripMLTestTime() error:&error];
	XCTAssertTrue(rendered);
	XCTAssertEqualObjects(self.effect.capturedOutput, @"GENERATED");
}

/*! @abstract A result that lacks the output image name fails the render with the backend-failure error and writes nothing. */
- (void)testAMissingOutputFailsTheRender
{
	FxGripMLStubBackend *backend = FxGripMLStubBackend.new;
	backend.stagedResult = [FxGripInferenceResult resultWithOutputs:@{ @"wrongName": @"GENERATED" }];
	self.effect.inferenceBackend = backend;

	NSError *error = nil;
	BOOL rendered = [self.effect renderMLFromSourceTile:nil toDestinationTile:nil atTime:FxGripMLTestTime() error:&error];
	XCTAssertFalse(rendered);
	XCTAssertNotNil(error);
	XCTAssertEqual(error.code, (NSInteger)kFxGripError_InferenceBackendFailure);
	XCTAssertNil(self.effect.capturedOutput);
}

/*! @abstract The source image reaches the backend request as the named input and the inference parameters pass through unchanged. */
- (void)testTheImageInputAndParametersFlowToTheBackend
{
	FxGripMLStubBackend *backend = FxGripMLStubBackend.new;
	backend.stagedResult = [FxGripInferenceResult resultWithOutputs:@{ @"image": @"GENERATED" }];
	self.effect.inferenceBackend = backend;
	self.effect.stagedParameters = @{ @"seed": @7 };

	NSError *error = nil;
	[self.effect renderMLFromSourceTile:nil toDestinationTile:nil atTime:FxGripMLTestTime() error:&error];

	XCTAssertEqualObjects([backend.lastRequest inputForKey:@"image"], @"SOURCE");
	XCTAssertEqualObjects([backend.lastRequest parameterForKey:@"seed"], @7);
}

/*! @abstract Setting the backend to nil restores the passthrough backend. */
- (void)testSettingTheBackendToNilRestoresThePassthrough
{
	self.effect.inferenceBackend = FxGripMLStubBackend.new;
	XCTAssertEqualObjects(self.effect.inferenceBackend.backendIdentifier, @"stub");
	self.effect.inferenceBackend = nil;
	XCTAssertEqualObjects(self.effect.inferenceBackend.backendIdentifier, @"passthrough");
}

@end

#pragma mark - Cache tests

/*! Replaces the FrameData/ImageBuffer storage with an in-memory store keyed by frame index. */
@interface FxGripMLCacheTestEffect : FxGripMLImageEffect
@property (nonatomic, strong) NSNotificationCenter *privateNotifier;
@property (nonatomic, strong) id capturedOutput;
@property (nonatomic, strong) NSDictionary<NSString *, id> *stagedParameters;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, id> *store;
@property (nonatomic, copy, nullable) NSString *storedSignature;
@end

@implementation FxGripMLCacheTestEffect

- (id)effectBase
{
	// The stub plays the full effect; rich reads route back to it, as the old cast did.
	return self;
}


- (instancetype)initWithAPIManager:(id<PROAPIAccessing>)apiManager
{
	self = [super initWithAPIManager:apiManager];
	if (self) {
		_store = NSMutableDictionary.new;
	}
	return self;
}

- (NSPriorityNotificationCenter *)notifier
{
	if (!_privateNotifier) {
		Class cls = NSClassFromString(@"NSPriorityNotificationCenter");
		_privateNotifier = [[cls alloc] init];
	}
	return (NSPriorityNotificationCenter *)_privateNotifier;
}

- (id<FxGripAPIAccessing>)apiManager { return nil; }

- (id)imageInputForSourceTile:(FxImageTile *)sourceTile atTime:(CMTime)time error:(NSError **)outError
{
	return @"SOURCE";
}

- (BOOL)writeImageOutput:(id)output toDestinationTile:(FxImageTile *)destinationTile atTime:(CMTime)time error:(NSError **)outError
{
	self.capturedOutput = output;
	return YES;
}

- (NSDictionary<NSString *, id> *)inferenceParametersAtTime:(CMTime)time
{
	return self.stagedParameters ?: @{};
}

// Index straight off the time value keeps the tests explicit.
- (NSInteger)cacheFrameIndexForTime:(CMTime)time { return (NSInteger)time.value; }

- (id)cachedOutputForFrameIndex:(NSInteger)index device:(id<MTLDevice>)device
{
	return self.store[@(index)];
}

- (void)storeOutput:(id)output forFrameIndex:(NSInteger)index
{
	self.store[@(index)] = output;
}

- (void)invalidateCacheIfSignatureChanged:(NSString *)signature
{
	if (self.storedSignature != nil && [self.storedSignature isEqualToString:signature]) {
		return;
	}
	[self.store removeAllObjects];
	self.storedSignature = signature;
}

@end

static CMTime FxGripMLCacheFrame(int64_t value)
{
	return (CMTime){ .value = value, .timescale = 30, .flags = kCMTimeFlags_Valid };
}

@interface FxGripMLCacheTests : XCTestCase
@property (nonatomic, strong) FxGripMLCacheTestEffect *effect;
@property (nonatomic, strong) FxGripMLStubBackend *backend;
@end

@implementation FxGripMLCacheTests

- (void)setUp
{
	[super setUp];
	self.effect = [FxGripMLCacheTestEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	self.backend = FxGripMLStubBackend.new;
	self.backend.stagedResult = [FxGripInferenceResult resultWithOutputs:@{ @"image": @"GEN" }];
	self.effect.inferenceBackend = self.backend;
}

- (void)renderFrame:(int64_t)value
{
	[self.effect renderMLFromSourceTile:nil toDestinationTile:nil atTime:FxGripMLCacheFrame(value) error:NULL];
}

/*! @abstract Rendering the same frame twice runs inference once and serves the second render from the cache. */
- (void)testTheSameFrameRunsInferenceOnce
{
	[self renderFrame:5];
	[self renderFrame:5];
	XCTAssertEqual(self.backend.runCount, (NSUInteger)1, @"the second render is a cache hit");
	XCTAssertEqualObjects(self.effect.capturedOutput, @"GEN");
}

/*! @abstract A different frame index misses the cache and runs inference again. */
- (void)testADifferentFrameRunsInferenceAgain
{
	[self renderFrame:5];
	[self renderFrame:6];
	XCTAssertEqual(self.backend.runCount, (NSUInteger)2);
}

/*! @abstract Changing the inference parameters clears the cache, so the same frame runs inference again. */
- (void)testChangingParametersInvalidatesTheCache
{
	[self renderFrame:5];
	XCTAssertEqual(self.backend.runCount, (NSUInteger)1);
	self.effect.stagedParameters = @{ @"seed": @99 };
	[self renderFrame:5];
	XCTAssertEqual(self.backend.runCount, (NSUInteger)2, @"a new signature clears the cache");
}

/*! @abstract With the cache disabled, every render of the same frame runs inference. */
- (void)testDisablingTheCacheRunsEveryFrame
{
	self.effect.cacheEnabled = NO;
	[self renderFrame:5];
	[self renderFrame:5];
	XCTAssertEqual(self.backend.runCount, (NSUInteger)2);
}

@end

#pragma mark - Real cache and Metal seams

/*!
	Runs the shipped cache and Metal seams rather than replacing them. mlCacheData reads through
	the FxGripMLCache extension, which answers nil without a host, so the cache is supplied here.
*/
@interface FxGripMLRealSeamEffect : FxGripMLImageEffect
@property (nonatomic, strong) NSNotificationCenter *privateNotifier;
@property (nonatomic, strong, nullable) FxGripFrameData *suppliedCache;
@property (nonatomic, strong, nullable) NSDictionary<NSString *, id> *stagedParameters;
@end

@implementation FxGripMLRealSeamEffect

- (id)effectBase
{
	return self;
}

- (NSPriorityNotificationCenter *)notifier
{
	if (!_privateNotifier) {
		Class cls = NSClassFromString(@"NSPriorityNotificationCenter");
		_privateNotifier = [[cls alloc] init];
	}
	return (NSPriorityNotificationCenter *)_privateNotifier;
}

- (id<FxGripAPIAccessing>)apiManager { return nil; }

- (FxGripFrameData *)mlCacheData { return self.suppliedCache; }

- (NSDictionary<NSString *, id> *)inferenceParametersAtTime:(CMTime)time { return self.stagedParameters; }

@end

@interface FxGripMLImageEffectSeamTests : XCTestCase
@property (nonatomic, strong) FxGripMLRealSeamEffect *effect;
@property (nonatomic, strong) id<MTLDevice> device;
@end

@implementation FxGripMLImageEffectSeamTests

- (void)setUp
{
	[super setUp];
	self.effect = [FxGripMLRealSeamEffect.alloc initWithAPIManager:nil];
	self.device = MTLCreateSystemDefaultDevice();
}

- (void)tearDown
{
	self.effect = nil;
	self.device = nil;
	[super tearDown];
}

/*! A tile carrying a real IOSurface-backed texture on the default device. */
- (FxImageTile *)tileWithBounds:(FxRect)bounds
{
	return [FxImageTile stubTileWithPixelBounds:bounds
									pixelFormat:kCVPixelFormatType_64RGBAHalf
										 device:self.device];
}

#pragma mark Frame index

/*! @abstract cacheFrameIndexForTime: normalizes the render time to a 600 timescale. */
- (void)testTheCacheFrameIndexNormalizesToA600Timescale
{
	XCTAssertEqual([self.effect cacheFrameIndexForTime:CMTimeMake(1, 30)], 20);
	XCTAssertEqual([self.effect cacheFrameIndexForTime:CMTimeMake(2, 1)], 1200);
	XCTAssertEqual([self.effect cacheFrameIndexForTime:CMTimeMake(600, 600)], 600);
}

/*! @abstract cacheFrameIndexForTime: maps an invalid time to frame zero. */
- (void)testTheCacheFrameIndexOfAnInvalidTimeIsZero
{
	XCTAssertEqual([self.effect cacheFrameIndexForTime:kCMTimeInvalid], 0);
}

#pragma mark Reading the cache

/*! @abstract cachedOutputForFrameIndex:device: answers nil without a device. */
- (void)testTheCachedOutputIsNilWithoutADevice
{
	XCTAssertNil([self.effect cachedOutputForFrameIndex:0 device:nil]);
}

/*! @abstract cachedOutputForFrameIndex:device: answers nil on a miss and for a record of another class. */
- (void)testTheCachedOutputIsNilOnAMissAndForAForeignRecord
{
	XCTSkipIf(self.device == nil, @"No Metal device.");
	FxGripFrameData *cache = FxGripFrameData.new;
	self.effect.suppliedCache = cache;

	XCTAssertNil([self.effect cachedOutputForFrameIndex:7 device:self.device]);

	[cache setRecord:(NSObject<NSSecureCoding, NSCopying> *)@"not a buffer" atIndex:7];

	XCTAssertNil([self.effect cachedOutputForFrameIndex:7 device:self.device]);
}

/*! @abstract A stored output comes back from the cache as a texture of the same size. */
- (void)testAStoredOutputComesBackAsATexture
{
	XCTSkipIf(self.device == nil, @"No Metal device.");
	self.effect.suppliedCache = FxGripFrameData.new;
	FxImageTile *tile = [self tileWithBounds:(FxRect){ 0, 0, 16, 8 }];
	id<MTLTexture> source = [tile metalTextureForDevice:self.device];
	XCTAssertNotNil(source);

	[self.effect storeOutput:source forFrameIndex:12];
	id<MTLTexture> restored = [self.effect cachedOutputForFrameIndex:12 device:self.device];

	XCTAssertNotNil(restored);
	XCTAssertEqual(restored.width, source.width);
	XCTAssertEqual(restored.height, source.height);
}

#pragma mark Writing the cache

/*! @abstract storeOutput:forFrameIndex: ignores an output that is not a Metal texture. */
- (void)testStoringANonTextureIsIgnored
{
	self.effect.suppliedCache = FxGripFrameData.new;

	[self.effect storeOutput:@"not a texture" forFrameIndex:3];

	XCTAssertEqual(self.effect.suppliedCache.frameIndexes.count, 0u);
}

/*! @abstract storeOutput:forFrameIndex: does nothing when the effect has no cache. */
- (void)testStoringWithoutACacheDoesNothing
{
	XCTSkipIf(self.device == nil, @"No Metal device.");
	FxImageTile *tile = [self tileWithBounds:(FxRect){ 0, 0, 8, 8 }];
	self.effect.suppliedCache = nil;

	[self.effect storeOutput:[tile metalTextureForDevice:self.device] forFrameIndex:1];

	XCTAssertNil([self.effect cachedOutputForFrameIndex:1 device:self.device]);
}

#pragma mark Invalidation

/*! @abstract A cache carrying no signature yet is treated as stale, so the first call clears it. */
- (void)testACacheWithNoSignatureIsClearedOnTheFirstCall
{
	XCTSkipIf(self.device == nil, @"No Metal device.");
	FxGripFrameData *cache = FxGripFrameData.new;
	self.effect.suppliedCache = cache;
	FxImageTile *tile = [self tileWithBounds:(FxRect){ 0, 0, 8, 8 }];
	[self.effect storeOutput:[tile metalTextureForDevice:self.device] forFrameIndex:4];
	XCTAssertEqual(cache.frameIndexes.count, 1u);

	[self.effect invalidateCacheIfSignatureChanged:@"signature-a"];

	XCTAssertEqual(cache.frameIndexes.count, 0u);
}

/*! @abstract An unchanged signature leaves every cached frame in place. */
- (void)testAnUnchangedSignatureKeepsTheCachedFrames
{
	XCTSkipIf(self.device == nil, @"No Metal device.");
	FxGripFrameData *cache = FxGripFrameData.new;
	self.effect.suppliedCache = cache;
	FxImageTile *tile = [self tileWithBounds:(FxRect){ 0, 0, 8, 8 }];

	// The signature has to be recorded before a frame is worth keeping.
	[self.effect invalidateCacheIfSignatureChanged:@"signature-a"];
	[self.effect storeOutput:[tile metalTextureForDevice:self.device] forFrameIndex:4];

	[self.effect invalidateCacheIfSignatureChanged:@"signature-a"];

	XCTAssertEqual(cache.frameIndexes.count, 1u);
}

/*! @abstract A changed signature clears every cached frame and records the new signature. */
- (void)testAChangedSignatureClearsEveryCachedFrame
{
	XCTSkipIf(self.device == nil, @"No Metal device.");
	FxGripFrameData *cache = FxGripFrameData.new;
	self.effect.suppliedCache = cache;
	FxImageTile *tile = [self tileWithBounds:(FxRect){ 0, 0, 8, 8 }];
	[self.effect invalidateCacheIfSignatureChanged:@"signature-a"];
	[self.effect storeOutput:[tile metalTextureForDevice:self.device] forFrameIndex:4];
	[self.effect storeOutput:[tile metalTextureForDevice:self.device] forFrameIndex:9];
	XCTAssertEqual(cache.frameIndexes.count, 2u);

	[self.effect invalidateCacheIfSignatureChanged:@"signature-b"];

	XCTAssertEqual(cache.frameIndexes.count, 0u);

	// The new signature replaced the old one, so a frame stored after it survives.
	[self.effect storeOutput:[tile metalTextureForDevice:self.device] forFrameIndex:11];
	[self.effect invalidateCacheIfSignatureChanged:@"signature-b"];
	XCTAssertEqual(cache.frameIndexes.count, 1u);
}

/*! @abstract invalidateCacheIfSignatureChanged: does nothing when the effect has no cache. */
- (void)testInvalidatingWithoutACacheDoesNothing
{
	self.effect.suppliedCache = nil;

	XCTAssertNoThrow([self.effect invalidateCacheIfSignatureChanged:@"signature-a"]);
}

/*! @abstract The signature joins the backend identifier to the frame's parameters. */
- (void)testTheSignatureJoinsTheBackendIdentifierAndTheParameters
{
	self.effect.stagedParameters = @{ @"strength": @2 };

	NSString *signature = [self.effect cacheSignatureForParametersAtTime:FxGripMLTestTime()];

	XCTAssertTrue([signature hasPrefix:self.effect.inferenceBackend.backendIdentifier]);
	XCTAssertTrue([signature containsString:@"strength"]);
}

#pragma mark The image input seam

/*! @abstract imageInputForSourceTile: reports a missing-input error without a tile. */
- (void)testTheImageInputReportsAMissingInputWithoutATile
{
	NSError *error = nil;

	XCTAssertNil([self.effect imageInputForSourceTile:nil atTime:FxGripMLTestTime() error:&error]);

	XCTAssertNotNil(error);
	XCTAssertEqual(error.code, kFxGripError_InferenceMissingInput);
}

/*! @abstract imageInputForSourceTile: reports a backend failure when the tile has no texture. */
- (void)testTheImageInputReportsAFailureWhenTheTileHasNoTexture
{
	FxImageTile *tile = [FxImageTile stubTileWithPixelBounds:(FxRect){ 0, 0, 8, 8 }];
	NSError *error = nil;

	XCTAssertNil([self.effect imageInputForSourceTile:tile atTime:FxGripMLTestTime() error:&error]);

	XCTAssertNotNil(error);
	XCTAssertEqual(error.code, kFxGripError_InferenceBackendFailure);
}

/*! @abstract imageInputForSourceTile: answers the tile's own Metal texture. */
- (void)testTheImageInputIsTheTilesMetalTexture
{
	XCTSkipIf(self.device == nil, @"No Metal device.");
	FxImageTile *tile = [self tileWithBounds:(FxRect){ 0, 0, 16, 16 }];
	NSError *error = nil;

	id input = [self.effect imageInputForSourceTile:tile atTime:FxGripMLTestTime() error:&error];

	XCTAssertNil(error);
	XCTAssertEqual(input, [tile metalTextureForDevice:self.device]);
}

#pragma mark The output seam

/*! @abstract writeImageOutput: reports a backend failure for an output that is not a texture. */
- (void)testWritingANonTextureReportsAFailure
{
	NSError *error = nil;

	XCTAssertFalse([self.effect writeImageOutput:@"not a texture" toDestinationTile:nil
										  atTime:FxGripMLTestTime() error:&error]);

	XCTAssertNotNil(error);
	XCTAssertEqual(error.code, kFxGripError_InferenceBackendFailure);
}

/*! @abstract writeImageOutput: reports a missing input without a destination tile. */
- (void)testWritingWithoutADestinationReportsAMissingInput
{
	XCTSkipIf(self.device == nil, @"No Metal device.");
	FxImageTile *source = [self tileWithBounds:(FxRect){ 0, 0, 8, 8 }];
	NSError *error = nil;

	XCTAssertFalse([self.effect writeImageOutput:[source metalTextureForDevice:self.device]
							   toDestinationTile:nil atTime:FxGripMLTestTime() error:&error]);

	XCTAssertNotNil(error);
	XCTAssertEqual(error.code, kFxGripError_InferenceMissingInput);
}

/*! @abstract writeImageOutput: reports a failure when the destination tile has no texture. */
- (void)testWritingToATileWithoutATextureReportsAFailure
{
	XCTSkipIf(self.device == nil, @"No Metal device.");
	FxImageTile *source = [self tileWithBounds:(FxRect){ 0, 0, 8, 8 }];
	FxImageTile *destination = [FxImageTile stubTileWithPixelBounds:(FxRect){ 0, 0, 8, 8 }];
	NSError *error = nil;

	XCTAssertFalse([self.effect writeImageOutput:[source metalTextureForDevice:self.device]
							   toDestinationTile:destination atTime:FxGripMLTestTime() error:&error]);

	XCTAssertNotNil(error);
	XCTAssertEqual(error.code, kFxGripError_InferenceBackendFailure);
}

/*! @abstract Writing a tile's own texture back to it is a no-op that reports success. */
- (void)testWritingATilesOwnTextureBackToItSucceedsWithoutABlit
{
	XCTSkipIf(self.device == nil, @"No Metal device.");
	FxImageTile *tile = [self tileWithBounds:(FxRect){ 0, 0, 8, 8 }];
	NSError *error = nil;

	XCTAssertTrue([self.effect writeImageOutput:[tile metalTextureForDevice:self.device]
							  toDestinationTile:tile atTime:FxGripMLTestTime() error:&error]);

	XCTAssertNil(error);
}

/*! @abstract writeImageOutput: blits the output into the destination tile's texture. */
- (void)testWritingBlitsTheOutputIntoTheDestination
{
	XCTSkipIf(self.device == nil, @"No Metal device.");
	FxImageTile *source = [self tileWithBounds:(FxRect){ 0, 0, 8, 8 }];
	FxImageTile *destination = [self tileWithBounds:(FxRect){ 0, 0, 8, 8 }];
	id<MTLTexture> sourceTexture = [source metalTextureForDevice:self.device];
	id<MTLTexture> destinationTexture = [destination metalTextureForDevice:self.device];

	// A known half-float red pixel, so the blit is observable rather than assumed.
	const uint16_t red[4] = { 0x3C00, 0x0000, 0x0000, 0x3C00 };
	[sourceTexture replaceRegion:MTLRegionMake2D(0, 0, 1, 1) mipmapLevel:0 withBytes:red bytesPerRow:8 * 8];
	NSError *error = nil;

	XCTAssertTrue([self.effect writeImageOutput:sourceTexture toDestinationTile:destination
										 atTime:FxGripMLTestTime() error:&error]);

	XCTAssertNil(error);
	uint16_t readBack[4] = { 0, 0, 0, 0 };
	[destinationTexture getBytes:readBack bytesPerRow:8 * 8 fromRegion:MTLRegionMake2D(0, 0, 1, 1) mipmapLevel:0];
	XCTAssertEqual(readBack[0], red[0]);
	XCTAssertEqual(readBack[3], red[3]);
}

#pragma mark The render entry point

/*! @abstract renderDestinationImage:sourceImages:pluginCoder:atTime:error: runs the pass on the first source tile. */
- (void)testTheRenderEntryPointUsesTheFirstSourceTile
{
	XCTSkipIf(self.device == nil, @"No Metal device.");
	FxImageTile *source = [self tileWithBounds:(FxRect){ 0, 0, 8, 8 }];
	FxImageTile *destination = [self tileWithBounds:(FxRect){ 0, 0, 8, 8 }];
	NSError *error = nil;
	NSCoder *noCoder = nil;

	BOOL rendered = [self.effect renderDestinationImage:destination
										   sourceImages:@[source]
											pluginCoder:noCoder
												 atTime:FxGripMLTestTime()
												  error:&error];

	// The default backend is the passthrough, so the pass completes and writes the source through.
	XCTAssertTrue(rendered, @"%@", error);
	XCTAssertNil(error);
}

@end
