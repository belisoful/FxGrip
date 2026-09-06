//
//  FxGripMLImageEffectTests.m
//  FxGripTests
//

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

- (void)testTheDefaultBackendIsPassthrough
{
	XCTAssertEqualObjects(self.effect.inferenceBackend.backendIdentifier, @"passthrough");
	XCTAssertEqualObjects([self.effect inputImageName], @"image");
	XCTAssertEqualObjects([self.effect outputImageName], @"image");
}

- (void)testDefaultInferenceBackendSeamReturnsPassthrough
{
	XCTAssertEqualObjects([self.effect defaultInferenceBackend].backendIdentifier, @"passthrough");
}

- (void)testOverridingTheDefaultBackendSeamChangesTheLazyDefault
{
	FxGripMLDefaultOverrideEffect *effect = [FxGripMLDefaultOverrideEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	XCTAssertEqualObjects(effect.inferenceBackend.backendIdentifier, @"stub");
}

- (void)testUseInferKitBackendIsANoOpWithoutInferKit
{
	id<FxGripInferenceBackend> before = self.effect.inferenceBackend;
	XCTAssertFalse([self.effect useInferKitBackend:NSObject.new], @"InferKit is not linked in the test bundle");
	XCTAssertFalse([self.effect useInferKitBackend:nil]);
	XCTAssertEqual(self.effect.inferenceBackend, before, @"a failed bridge leaves the backend unchanged");
}

- (void)testTheDefaultBackendEchoesTheSourceToTheDestination
{
	NSError *error = nil;
	BOOL rendered = [self.effect renderMLFromSourceTile:nil toDestinationTile:nil atTime:FxGripMLTestTime() error:&error];
	XCTAssertTrue(rendered);
	XCTAssertNil(error);
	XCTAssertEqualObjects(self.effect.capturedOutput, @"SOURCE", @"passthrough routes the source straight through");
}

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

- (void)testTheSameFrameRunsInferenceOnce
{
	[self renderFrame:5];
	[self renderFrame:5];
	XCTAssertEqual(self.backend.runCount, (NSUInteger)1, @"the second render is a cache hit");
	XCTAssertEqualObjects(self.effect.capturedOutput, @"GEN");
}

- (void)testADifferentFrameRunsInferenceAgain
{
	[self renderFrame:5];
	[self renderFrame:6];
	XCTAssertEqual(self.backend.runCount, (NSUInteger)2);
}

- (void)testChangingParametersInvalidatesTheCache
{
	[self renderFrame:5];
	XCTAssertEqual(self.backend.runCount, (NSUInteger)1);
	self.effect.stagedParameters = @{ @"seed": @99 };
	[self renderFrame:5];
	XCTAssertEqual(self.backend.runCount, (NSUInteger)2, @"a new signature clears the cache");
}

- (void)testDisablingTheCacheRunsEveryFrame
{
	self.effect.cacheEnabled = NO;
	[self renderFrame:5];
	[self renderFrame:5];
	XCTAssertEqual(self.backend.runCount, (NSUInteger)2);
}

@end
