/*!
	@file       FxGripMLGeneratorTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripMLGeneratorTests
	@abstract   Verifies the FxGripMLImageGenerator and FxGripMLVideoGenerator templates.
	@discussion Introduced in FxGrip 0.1.0. A stub backend stages a result and records the request, and test generator subclasses capture the written output, count placeholder writes, and drive a terminal-state expectation. The tests confirm the image generator feeds its generator inputs to the backend and writes the generated output, renders the placeholder while the backend is not ready, and the video generator renders the placeholder until the clip is generated and then draws from the clip.
*/

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripMLImageGenerator.h>
#import <FxGrip/FxGripMLVideoGenerator.h>
#import <FxGrip/FxGripInferenceBackend.h>
#import <FxGrip/FxGripInferenceRequest.h>
#import <FxGrip/FxGripInferenceResult.h>

static CMTime FxGripMLGenTestTime(void)
{
	return (CMTime){ .value = 0, .timescale = 30, .flags = kCMTimeFlags_Valid };
}

#pragma mark - Stub backend

@interface FxGripMLGenStubBackend : NSObject <FxGripInferenceBackend>
@property (nonatomic, assign) BOOL ready;
@property (nonatomic, strong, nullable) FxGripInferenceResult *stagedResult;
@property (nonatomic, strong, nullable) FxGripInferenceRequest *lastRequest;
@property (nonatomic, assign) NSUInteger runCount;
@end

@implementation FxGripMLGenStubBackend
- (instancetype)init
{
	self = [super init];
	if (self) { _ready = YES; }
	return self;
}
- (BOOL)isReady { return self.ready; }
- (NSString *)backendIdentifier { return @"gen-stub"; }
- (FxGripInferenceResult *)runInferenceForRequest:(FxGripInferenceRequest *)request error:(NSError **)error
{
	self.lastRequest = request;
	self.runCount += 1;
	return self.stagedResult;
}
@end

#pragma mark - Test generators

@interface FxGripMLTestImageGenerator : FxGripMLImageGenerator
@property (nonatomic, strong) NSNotificationCenter *privateNotifier;
@property (nonatomic, strong) id capturedOutput;
@property (nonatomic, assign) NSUInteger placeholderWrites;
@property (nonatomic, strong) NSDictionary<NSString *, id> *stagedInputs;
@end

@implementation FxGripMLTestImageGenerator

- (NSPriorityNotificationCenter *)notifier
{
	if (!_privateNotifier) {
		_privateNotifier = [[NSClassFromString(@"NSPriorityNotificationCenter") alloc] init];
	}
	return (NSPriorityNotificationCenter *)_privateNotifier;
}

- (id<FxGripAPIAccessing>)apiManager { return nil; }

- (NSDictionary<NSString *, id> *)generatorInputsAtTime:(CMTime)time
{
	return self.stagedInputs ?: @{};
}

- (BOOL)writeImageOutput:(id)output toDestinationTile:(FxImageTile *)destinationTile atTime:(CMTime)time error:(NSError **)outError
{
	self.capturedOutput = output;
	return YES;
}

- (BOOL)writePlaceholderToDestinationTile:(FxImageTile *)destinationTile atTime:(CMTime)time error:(NSError **)outError
{
	self.placeholderWrites += 1;
	return YES;
}

@end

@interface FxGripMLTestVideoGenerator : FxGripMLVideoGenerator
@property (nonatomic, strong) NSNotificationCenter *privateNotifier;
@property (nonatomic, assign) NSUInteger placeholderWrites;
@property (nonatomic, strong) NSURL *lastClipRendered;
@property (nonatomic, assign) BOOL clipRenderReturns;
@property (nonatomic, strong) XCTestExpectation *terminalExpectation;
@end

@implementation FxGripMLTestVideoGenerator

- (NSPriorityNotificationCenter *)notifier
{
	if (!_privateNotifier) {
		_privateNotifier = [[NSClassFromString(@"NSPriorityNotificationCenter") alloc] init];
	}
	return (NSPriorityNotificationCenter *)_privateNotifier;
}

- (id<FxGripAPIAccessing>)apiManager { return nil; }

- (BOOL)writePlaceholderToDestinationTile:(FxImageTile *)destinationTile atTime:(CMTime)time error:(NSError **)outError
{
	self.placeholderWrites += 1;
	return YES;
}

- (BOOL)renderFrameFromGeneratedClip:(NSURL *)clipURL toDestinationTile:(FxImageTile *)destinationTile atTime:(CMTime)time error:(NSError **)outError
{
	self.lastClipRendered = clipURL;
	return self.clipRenderReturns;
}

- (void)generationStateDidChange
{
	FxGripMLVideoState state = self.generationState;
	if (state == FxGripMLVideoStateReady || state == FxGripMLVideoStateFailed) {
		[self.terminalExpectation fulfill];
	}
}

@end

#pragma mark - Tests

@interface FxGripMLGeneratorTests : XCTestCase
@end

@implementation FxGripMLGeneratorTests

/*! @abstract The image generator sends its generator inputs to the backend, writes the generated output, and skips the placeholder. */
- (void)testTheImageGeneratorRunsTheBackendOverGeneratorInputs
{
	FxGripMLTestImageGenerator *generator = [FxGripMLTestImageGenerator.alloc initWithAPIManager:(id _Nonnull)nil];
	generator.cacheEnabled = NO;
	FxGripMLGenStubBackend *backend = [FxGripMLGenStubBackend new];
	backend.stagedResult = [FxGripInferenceResult resultWithOutputs:@{ @"image": @"GENERATED" }];
	generator.inferenceBackend = backend;
	generator.stagedInputs = @{ @"prompt": @"a sunset" };

	NSError *error = nil;
	XCTAssertTrue([generator renderMLFromSourceTile:nil toDestinationTile:nil
											 atTime:FxGripMLGenTestTime() error:&error]);
	XCTAssertEqualObjects(generator.capturedOutput, @"GENERATED");
	XCTAssertEqualObjects([backend.lastRequest inputForKey:@"prompt"], @"a sunset",
						  @"the generator inputs, not a source image, feed the request");
	XCTAssertEqual(generator.placeholderWrites, 0u);
}

/*! @abstract A not-ready backend makes the image generator write the placeholder once and run no inference. */
- (void)testTheImageGeneratorRendersThePlaceholderUntilReady
{
	FxGripMLTestImageGenerator *generator = [FxGripMLTestImageGenerator.alloc initWithAPIManager:(id _Nonnull)nil];
	generator.cacheEnabled = NO;
	FxGripMLGenStubBackend *backend = [FxGripMLGenStubBackend new];
	backend.ready = NO;
	generator.inferenceBackend = backend;

	NSError *error = nil;
	XCTAssertTrue([generator renderMLFromSourceTile:nil toDestinationTile:nil
											 atTime:FxGripMLGenTestTime() error:&error]);
	XCTAssertEqual(generator.placeholderWrites, 1u);
	XCTAssertEqual(backend.runCount, 0u);
	XCTAssertNil(generator.capturedOutput);
}

// The generator tile geometry (destination bounds, empty source tile) is the generator base's
// verbatim behavior; exercising it in the test bundle crashes without the host-loaded FxPlug
// runtime (kFxRect_Empty and the rect notification chain), so it is host-verified.

/*! @abstract The video generator writes the placeholder before generation and draws from the clip once it is ready, without a further placeholder write. */
- (void)testTheVideoGeneratorRendersThePlaceholderThenTheClip
{
	FxGripMLTestVideoGenerator *generator = [FxGripMLTestVideoGenerator.alloc initWithAPIManager:(id _Nonnull)nil];
	generator.generationQueue = dispatch_queue_create("fxgrip.test.videogen2", DISPATCH_QUEUE_SERIAL);
	FxGripMLGenStubBackend *backend = [FxGripMLGenStubBackend new];
	generator.inferenceBackend = backend;

	// Before generation: placeholder, and the backend never runs on the render path.
	NSError *error = nil;
	XCTAssertTrue([generator renderMLFromSourceTile:nil toDestinationTile:nil
											 atTime:FxGripMLGenTestTime() error:&error]);
	XCTAssertEqual(generator.placeholderWrites, 1u);
	XCTAssertEqual(backend.runCount, 0u);

	// Generate, then render from the clip.
	NSURL *clip = [NSURL fileURLWithPath:@"/tmp/generated.mov"];
	backend.stagedResult = [FxGripInferenceResult resultWithOutputs:@{ @"video": clip }];
	generator.terminalExpectation = [self expectationWithDescription:@"ready"];
	[generator beginGenerationAtTime:FxGripMLGenTestTime()];
	[self waitForExpectations:@[ generator.terminalExpectation ] timeout:4.0];

	generator.clipRenderReturns = YES;
	XCTAssertTrue([generator renderMLFromSourceTile:nil toDestinationTile:nil
											 atTime:FxGripMLGenTestTime() error:&error]);
	XCTAssertEqualObjects(generator.lastClipRendered, clip);
	XCTAssertEqual(generator.placeholderWrites, 1u, @"no placeholder once the clip renders");
}

@end
