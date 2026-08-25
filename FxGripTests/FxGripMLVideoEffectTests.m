//
//  FxGripMLVideoEffectTests.m
//  FxGripTests
//
//  Covers the whole-clip generation lifecycle: state moves, clip-output conversion, failure
//  paths, cancellation tokens, and the render gate. The generation queue is a private serial
//  queue and each terminal state fulfills an expectation, so the async runs are deterministic.
//

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripMLVideoEffect.h>
#import <FxGrip/FxGripInferenceBackend.h>
#import <FxGrip/FxGripInferenceRequest.h>
#import <FxGrip/FxGripInferenceResult.h>
#import <FxGrip/FxGripErrors.h>

static CMTime FxMLVideoTestTime(void)
{
	return (CMTime){ .value = 0, .timescale = 30, .flags = kCMTimeFlags_Valid };
}

#pragma mark - Stubs

/*! A backend whose readiness and result are staged; optionally blocks until released so a test
	can cancel mid-run. */
@interface FxMLVideoStubBackend : NSObject <FxGripInferenceBackend>
@property (nonatomic, assign) BOOL ready;
@property (nonatomic, strong, nullable) FxGripInferenceResult *stagedResult;
@property (nonatomic, strong, nullable) NSError *stagedError;
@property (nonatomic, assign) NSUInteger runCount;
@property (nonatomic, strong, nullable) dispatch_semaphore_t gate;
@end

@implementation FxMLVideoStubBackend

- (instancetype)init
{
	self = [super init];
	if (self) {
		_ready = YES;
	}
	return self;
}

- (BOOL)isReady { return self.ready; }
- (NSString *)backendIdentifier { return @"video-stub"; }

- (FxGripInferenceResult *)runInferenceForRequest:(FxGripInferenceRequest *)request error:(NSError **)error
{
	self.runCount += 1;
	if (self.gate != nil) {
		dispatch_semaphore_wait(self.gate, DISPATCH_TIME_FOREVER);
	}
	if (self.stagedError != nil && error != NULL) {
		*error = self.stagedError;
	}
	return self.stagedResult;
}

@end

/*! An InferKit-video-asset-shaped object: only a fileURL. */
@interface FxVideoAssetStub : NSObject
@property (nonatomic, strong) NSURL *fileURL;
@end
@implementation FxVideoAssetStub
@end

#pragma mark - Test effect

/*! Bypasses the host: sentinel source image, captured output, expectation-driven state hook. */
@interface FxMLVideoTestEffect : FxGripMLVideoEffect
@property (nonatomic, strong) NSNotificationCenter *privateNotifier;
@property (nonatomic, strong) id capturedOutput;
@property (nonatomic, strong) NSDictionary<NSString *, id> *stagedInputs;
@property (nonatomic, strong) XCTestExpectation *terminalExpectation;
@property (nonatomic, assign) NSUInteger stateChanges;
@property (nonatomic, assign) BOOL clipRenderReturns;
@property (nonatomic, strong) NSURL *lastClipRendered;
@end

@implementation FxMLVideoTestEffect

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

- (NSDictionary<NSString *, id> *)generationInputsAtTime:(CMTime)time
{
	return self.stagedInputs ?: @{};
}

- (void)generationStateDidChange
{
	self.stateChanges += 1;
	FxGripMLVideoState state = self.generationState;
	if (state == FxGripMLVideoStateReady || state == FxGripMLVideoStateFailed) {
		[self.terminalExpectation fulfill];
	}
}

- (BOOL)renderFrameFromGeneratedClip:(NSURL *)clipURL
				   toDestinationTile:(FxImageTile *)destinationTile
							  atTime:(CMTime)time
							   error:(NSError **)outError
{
	self.lastClipRendered = clipURL;
	return self.clipRenderReturns;
}

@end

#pragma mark - Tests

@interface FxGripMLVideoEffectTests : XCTestCase
@property (nonatomic, strong) FxMLVideoTestEffect *effect;
@property (nonatomic, strong) FxMLVideoStubBackend *backend;
@end

@implementation FxGripMLVideoEffectTests

- (void)setUp
{
	[super setUp];
	self.effect = [FxMLVideoTestEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	self.effect.generationQueue = dispatch_queue_create("fxgrip.test.videogen", DISPATCH_QUEUE_SERIAL);
	self.backend = [FxMLVideoStubBackend new];
	self.effect.inferenceBackend = self.backend;
}

- (void)waitForTerminalState
{
	self.effect.terminalExpectation = [self expectationWithDescription:@"terminal generation state"];
	[self waitForExpectations:@[ self.effect.terminalExpectation ] timeout:4.0];
}

- (void)testTheInitialStateIsIdleWithoutACache
{
	XCTAssertEqual(self.effect.generationState, FxGripMLVideoStateIdle);
	XCTAssertEqualWithAccuracy(self.effect.generationProgress, -1.0, 1e-12);
	XCTAssertNil(self.effect.generatedClipURL);
	XCTAssertFalse(self.effect.cacheEnabled, @"the clip file is the cache");
	XCTAssertEqualObjects([self.effect videoOutputName], @"video");
}

- (void)testAGenerationFinishesReadyWithTheClipURL
{
	NSURL *clip = [NSURL fileURLWithPath:@"/tmp/generated.mov"];
	self.backend.stagedResult = [FxGripInferenceResult resultWithOutputs:@{ @"video": clip }];
	self.effect.terminalExpectation = [self expectationWithDescription:@"ready"];

	[self.effect beginGenerationAtTime:FxMLVideoTestTime()];
	[self waitForExpectations:@[ self.effect.terminalExpectation ] timeout:4.0];

	XCTAssertEqual(self.effect.generationState, FxGripMLVideoStateReady);
	XCTAssertEqualObjects(self.effect.generatedClipURL, clip);
	XCTAssertEqualWithAccuracy(self.effect.generationProgress, 1.0, 1e-12);
	XCTAssertEqual(self.backend.runCount, 1u);
}

- (void)testAPathStringAndAFileURLShapedOutputBothResolve
{
	self.backend.stagedResult = [FxGripInferenceResult resultWithOutputs:@{ @"video": @"/tmp/path.mov" }];
	self.effect.terminalExpectation = [self expectationWithDescription:@"path string"];
	[self.effect beginGenerationAtTime:FxMLVideoTestTime()];
	[self waitForExpectations:@[ self.effect.terminalExpectation ] timeout:4.0];
	XCTAssertEqualObjects(self.effect.generatedClipURL, [NSURL fileURLWithPath:@"/tmp/path.mov"]);

	FxVideoAssetStub *asset = [FxVideoAssetStub new];
	asset.fileURL = [NSURL fileURLWithPath:@"/tmp/asset.mov"];
	self.backend.stagedResult = [FxGripInferenceResult resultWithOutputs:@{ @"video": asset }];
	[self.effect resetGeneration];
	self.effect.terminalExpectation = [self expectationWithDescription:@"asset shape"];
	[self.effect beginGenerationAtTime:FxMLVideoTestTime()];
	[self waitForExpectations:@[ self.effect.terminalExpectation ] timeout:4.0];
	XCTAssertEqualObjects(self.effect.generatedClipURL, asset.fileURL,
						  @"an object with a fileURL admits an InferKit video asset");
}

- (void)testAResultWithoutAClipFails
{
	self.backend.stagedResult = [FxGripInferenceResult resultWithOutputs:@{ @"text": @"no clip" }];
	self.effect.terminalExpectation = [self expectationWithDescription:@"failed"];
	[self.effect beginGenerationAtTime:FxMLVideoTestTime()];
	[self waitForExpectations:@[ self.effect.terminalExpectation ] timeout:4.0];

	XCTAssertEqual(self.effect.generationState, FxGripMLVideoStateFailed);
	XCTAssertEqual(self.effect.generationError.code, kFxGripError_InferenceBackendFailure);
}

- (void)testANotReadyBackendFailsWithoutRunning
{
	self.backend.ready = NO;
	self.effect.terminalExpectation = [self expectationWithDescription:@"not ready"];
	[self.effect beginGenerationAtTime:FxMLVideoTestTime()];
	[self waitForExpectations:@[ self.effect.terminalExpectation ] timeout:4.0];

	XCTAssertEqual(self.effect.generationState, FxGripMLVideoStateFailed);
	XCTAssertEqual(self.effect.generationError.code, kFxGripError_InferenceNotReady);
	XCTAssertEqual(self.backend.runCount, 0u);
}

- (void)testCancellingDiscardsTheLateResult
{
	self.backend.gate = dispatch_semaphore_create(0);
	self.backend.stagedResult = [FxGripInferenceResult resultWithOutputs:
								 @{ @"video": [NSURL fileURLWithPath:@"/tmp/late.mov"] }];

	[self.effect beginGenerationAtTime:FxMLVideoTestTime()];
	XCTAssertEqual(self.effect.generationState, FxGripMLVideoStateGenerating);

	[self.effect cancelGeneration];
	XCTAssertEqual(self.effect.generationState, FxGripMLVideoStateIdle);

	dispatch_semaphore_signal(self.backend.gate);
	// Drain the serial generation queue so the late finish has run before asserting.
	dispatch_sync(self.effect.generationQueue, ^{});

	XCTAssertEqual(self.effect.generationState, FxGripMLVideoStateIdle, @"the late result is ignored");
	XCTAssertNil(self.effect.generatedClipURL);
}

- (void)testASecondBeginWhileGeneratingIsANoOp
{
	self.backend.gate = dispatch_semaphore_create(0);
	self.backend.stagedResult = [FxGripInferenceResult resultWithOutputs:
								 @{ @"video": [NSURL fileURLWithPath:@"/tmp/one.mov"] }];

	[self.effect beginGenerationAtTime:FxMLVideoTestTime()];
	[self.effect beginGenerationAtTime:FxMLVideoTestTime()];
	self.effect.terminalExpectation = [self expectationWithDescription:@"single run"];
	dispatch_semaphore_signal(self.backend.gate);
	[self waitForExpectations:@[ self.effect.terminalExpectation ] timeout:4.0];

	XCTAssertEqual(self.backend.runCount, 1u, @"only one generation ran");
}

- (void)testRenderFallsBackToTheSourceUntilReady
{
	NSError *error = nil;
	XCTAssertTrue([self.effect renderMLFromSourceTile:nil toDestinationTile:nil
											   atTime:FxMLVideoTestTime() error:&error]);
	XCTAssertEqualObjects(self.effect.capturedOutput, @"SOURCE");
	XCTAssertEqual(self.backend.runCount, 0u, @"the render path never runs the backend");
}

- (void)testRenderUsesTheClipOnceReady
{
	NSURL *clip = [NSURL fileURLWithPath:@"/tmp/generated.mov"];
	self.backend.stagedResult = [FxGripInferenceResult resultWithOutputs:@{ @"video": clip }];
	self.effect.terminalExpectation = [self expectationWithDescription:@"ready"];
	[self.effect beginGenerationAtTime:FxMLVideoTestTime()];
	[self waitForExpectations:@[ self.effect.terminalExpectation ] timeout:4.0];

	self.effect.clipRenderReturns = YES;
	NSError *error = nil;
	XCTAssertTrue([self.effect renderMLFromSourceTile:nil toDestinationTile:nil
											   atTime:FxMLVideoTestTime() error:&error]);
	XCTAssertEqualObjects(self.effect.lastClipRendered, clip);
	XCTAssertNil(self.effect.capturedOutput, @"the clip frame, not the source, was written");
}

- (void)testAFailedClipFrameFallsBackToTheSource
{
	NSURL *clip = [NSURL fileURLWithPath:@"/tmp/generated.mov"];
	self.backend.stagedResult = [FxGripInferenceResult resultWithOutputs:@{ @"video": clip }];
	self.effect.terminalExpectation = [self expectationWithDescription:@"ready"];
	[self.effect beginGenerationAtTime:FxMLVideoTestTime()];
	[self waitForExpectations:@[ self.effect.terminalExpectation ] timeout:4.0];

	self.effect.clipRenderReturns = NO;   // the default implementation's behavior
	NSError *error = nil;
	XCTAssertTrue([self.effect renderMLFromSourceTile:nil toDestinationTile:nil
											   atTime:FxMLVideoTestTime() error:&error]);
	XCTAssertEqualObjects(self.effect.capturedOutput, @"SOURCE");
}

- (void)testResetReturnsAReadyEffectToIdle
{
	self.backend.stagedResult = [FxGripInferenceResult resultWithOutputs:
								 @{ @"video": [NSURL fileURLWithPath:@"/tmp/x.mov"] }];
	self.effect.terminalExpectation = [self expectationWithDescription:@"ready"];
	[self.effect beginGenerationAtTime:FxMLVideoTestTime()];
	[self waitForExpectations:@[ self.effect.terminalExpectation ] timeout:4.0];

	[self.effect resetGeneration];
	XCTAssertEqual(self.effect.generationState, FxGripMLVideoStateIdle);
	XCTAssertNil(self.effect.generatedClipURL);
}

@end
