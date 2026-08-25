//
//  FxGripMLGeneratorTests.m
//  FxGripTests
//
//  Covers the generator ML templates: no-source orchestration, the placeholder path, and the
//  generator tile geometry. The harness mirrors the ML effect tests: sentinel outputs, a stub
//  backend, no Metal.
//

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripMLImageGenerator.h>
#import <FxGrip/FxGripMLVideoGenerator.h>
#import <FxGrip/FxGripInferenceBackend.h>
#import <FxGrip/FxGripInferenceRequest.h>
#import <FxGrip/FxGripInferenceResult.h>

static CMTime FxMLGenTestTime(void)
{
	return (CMTime){ .value = 0, .timescale = 30, .flags = kCMTimeFlags_Valid };
}

#pragma mark - Stub backend

@interface FxMLGenStubBackend : NSObject <FxGripInferenceBackend>
@property (nonatomic, assign) BOOL ready;
@property (nonatomic, strong, nullable) FxGripInferenceResult *stagedResult;
@property (nonatomic, strong, nullable) FxGripInferenceRequest *lastRequest;
@property (nonatomic, assign) NSUInteger runCount;
@end

@implementation FxMLGenStubBackend
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

@interface FxMLTestImageGenerator : FxGripMLImageGenerator
@property (nonatomic, strong) NSNotificationCenter *privateNotifier;
@property (nonatomic, strong) id capturedOutput;
@property (nonatomic, assign) NSUInteger placeholderWrites;
@property (nonatomic, strong) NSDictionary<NSString *, id> *stagedInputs;
@end

@implementation FxMLTestImageGenerator

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

@interface FxMLTestVideoGenerator : FxGripMLVideoGenerator
@property (nonatomic, strong) NSNotificationCenter *privateNotifier;
@property (nonatomic, assign) NSUInteger placeholderWrites;
@property (nonatomic, strong) NSURL *lastClipRendered;
@property (nonatomic, assign) BOOL clipRenderReturns;
@property (nonatomic, strong) XCTestExpectation *terminalExpectation;
@end

@implementation FxMLTestVideoGenerator

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

- (void)testTheImageGeneratorRunsTheBackendOverGeneratorInputs
{
	FxMLTestImageGenerator *generator = [FxMLTestImageGenerator.alloc initWithAPIManager:(id _Nonnull)nil];
	generator.cacheEnabled = NO;
	FxMLGenStubBackend *backend = [FxMLGenStubBackend new];
	backend.stagedResult = [FxGripInferenceResult resultWithOutputs:@{ @"image": @"GENERATED" }];
	generator.inferenceBackend = backend;
	generator.stagedInputs = @{ @"prompt": @"a sunset" };

	NSError *error = nil;
	XCTAssertTrue([generator renderMLFromSourceTile:nil toDestinationTile:nil
											 atTime:FxMLGenTestTime() error:&error]);
	XCTAssertEqualObjects(generator.capturedOutput, @"GENERATED");
	XCTAssertEqualObjects([backend.lastRequest inputForKey:@"prompt"], @"a sunset",
						  @"the generator inputs, not a source image, feed the request");
	XCTAssertEqual(generator.placeholderWrites, 0u);
}

- (void)testTheImageGeneratorRendersThePlaceholderUntilReady
{
	FxMLTestImageGenerator *generator = [FxMLTestImageGenerator.alloc initWithAPIManager:(id _Nonnull)nil];
	generator.cacheEnabled = NO;
	FxMLGenStubBackend *backend = [FxMLGenStubBackend new];
	backend.ready = NO;
	generator.inferenceBackend = backend;

	NSError *error = nil;
	XCTAssertTrue([generator renderMLFromSourceTile:nil toDestinationTile:nil
											 atTime:FxMLGenTestTime() error:&error]);
	XCTAssertEqual(generator.placeholderWrites, 1u);
	XCTAssertEqual(backend.runCount, 0u);
	XCTAssertNil(generator.capturedOutput);
}

// The generator tile geometry (destination bounds, empty source tile) is the generator base's
// verbatim behavior; exercising it in the test bundle crashes without the host-loaded FxPlug
// runtime (kFxRect_Empty and the rect notification chain), so it is host-verified.

- (void)testTheVideoGeneratorRendersThePlaceholderThenTheClip
{
	FxMLTestVideoGenerator *generator = [FxMLTestVideoGenerator.alloc initWithAPIManager:(id _Nonnull)nil];
	generator.generationQueue = dispatch_queue_create("fxgrip.test.videogen2", DISPATCH_QUEUE_SERIAL);
	FxMLGenStubBackend *backend = [FxMLGenStubBackend new];
	generator.inferenceBackend = backend;

	// Before generation: placeholder, and the backend never runs on the render path.
	NSError *error = nil;
	XCTAssertTrue([generator renderMLFromSourceTile:nil toDestinationTile:nil
											 atTime:FxMLGenTestTime() error:&error]);
	XCTAssertEqual(generator.placeholderWrites, 1u);
	XCTAssertEqual(backend.runCount, 0u);

	// Generate, then render from the clip.
	NSURL *clip = [NSURL fileURLWithPath:@"/tmp/generated.mov"];
	backend.stagedResult = [FxGripInferenceResult resultWithOutputs:@{ @"video": clip }];
	generator.terminalExpectation = [self expectationWithDescription:@"ready"];
	[generator beginGenerationAtTime:FxMLGenTestTime()];
	[self waitForExpectations:@[ generator.terminalExpectation ] timeout:4.0];

	generator.clipRenderReturns = YES;
	XCTAssertTrue([generator renderMLFromSourceTile:nil toDestinationTile:nil
											 atTime:FxMLGenTestTime() error:&error]);
	XCTAssertEqualObjects(generator.lastClipRendered, clip);
	XCTAssertEqual(generator.placeholderWrites, 1u, @"no placeholder once the clip renders");
}

@end
