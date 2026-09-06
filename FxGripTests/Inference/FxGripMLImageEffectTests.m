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
	XCTAssertFalse([self.effect useInferKitBackend:nil]);
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
