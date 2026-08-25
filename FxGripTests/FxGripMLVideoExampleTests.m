//
//  FxGripMLVideoExampleTests.m
//  FxGripTests
//
//  FxMLVideoExampleEffect is the worked example for FxGripMLVideoEffect: a prompt, a Generate
//  push-button, and a status and progress control that mirror the generation lifecycle. The
//  Inference DocC article quotes the class verbatim, and these tests keep the sample honest.
//

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripMLVideoEffect.h>
#import <FxGrip/FxGripInferenceBackend.h>
#import <FxGrip/FxGripInferenceRequest.h>
#import <FxGrip/FxGripInferenceResult.h>
#import <FxGrip/FxGripAllParameters.h>
#import <FxGrip/FxGripStatusParameter.h>
#import <FxGrip/FxGripProgressParameter.h>
#import <FxGrip/FxGripDictionary.h>
#import <FxGrip/FxGripOOBParameterAccess.h>
#import <FxGrip/FxGripTypes.h>
#import <BEFoundation/BEDotView.h>
#import "FxGripParameterClassTestSupport.h"

#pragma mark - The worked example (the DocC sample)

enum : UInt32 {
	kExamplePromptID   = 1,
	kExampleGenerateID = 2,
	kExampleStatusID   = 3,
	kExampleProgressID = 4,
};

/*! A text-to-video effect: type a prompt, press Generate, and watch the status and progress
	controls follow the generation; the clip renders once it is ready. */
@interface FxMLVideoExampleEffect : FxGripMLVideoEffect
@end

@implementation FxMLVideoExampleEffect

/*! The inspector: a prompt, the Generate button, and the two lifecycle displays. */
- (NSArray<NSDictionary *> *)exampleParameters
{
	return @[
		@{ kFxParameterProperty_Id:      @(kExamplePromptID),
		   kFxParameterProperty_Name:    @"Prompt",
		   kFxParameterProperty_Type:    kFxParameterType_String,
		   kFxParameterProperty_Default: @"" },
		@{ kFxParameterProperty_Id:      @(kExampleGenerateID),
		   kFxParameterProperty_Name:    @"Generate",
		   kFxParameterProperty_Type:    kFxParameterType_PushButton },
		@{ kFxParameterProperty_Id:      @(kExampleStatusID),
		   kFxParameterProperty_Name:    @"State",
		   kFxParameterProperty_Type:    kFxParameterType_Status,
		   kFxParameterProperty_Default: @{ kCustomAPI_IntKey:    @(BEDotStateOff),
											kCustomAPI_StringKey: @"Idle" } },
		@{ kFxParameterProperty_Id:      @(kExampleProgressID),
		   kFxParameterProperty_Name:    @"Progress",
		   kFxParameterProperty_Type:    kFxParameterType_Progress,
		   kFxParameterProperty_Default: @{ kCustomAPI_IntKey:    @(BEDotStateOff),
											kCustomAPI_StringKey: @"Idle",
											kCustomAPI_FloatKey:  @0.0 } },
	];
}

/*! The prompt parameter feeds the generation request. */
- (NSDictionary<NSString *, id> *)generationInputsAtTime:(CMTime)time
{
	NSString *prompt = nil;
	[self.apiManager.paramGetAPIv6 getStringParameterValue:&prompt fromParameter:kExamplePromptID];
	return prompt.length > 0 ? @{ @"prompt": prompt } : @{};
}

/*! The Generate button starts the run; every other click keeps the base behavior. */
- (BOOL)parameterClicked:(FxParameterId)parameterID
{
	if (parameterID == kExampleGenerateID) {
		[self beginGenerationAtTime:[FxGripOOBParameterAccess access:self].currentTime];
		return YES;
	}
	return [super parameterClicked:parameterID];
}

/*! Mirrors the lifecycle into the status and progress controls. The hook fires off the host's
	calls, so the writes run inside an out-of-band access context. */
- (void)generationStateDidChange
{
	NSInteger dot = BEDotStateOff;
	NSString *label = @"Idle";
	double fraction = 0.0;
	switch (self.generationState) {
		case FxGripMLVideoStateGenerating:
			dot = BEDotStateActive;
			label = @"Generating…";
			fraction = self.generationProgress;   // negative shows the indeterminate bar
			break;
		case FxGripMLVideoStateReady:
			dot = BEDotStateOk;
			label = @"Clip ready";
			fraction = 1.0;
			break;
		case FxGripMLVideoStateFailed:
			dot = BEDotStateError;
			label = self.generationError.localizedDescription ?: @"Failed";
			break;
		case FxGripMLVideoStateIdle:
			break;
	}

	FxGripOOBParameterAccess *__attribute__((unused)) access = [FxGripOOBParameterAccess access:self];
	CMTime time = access.currentTime;
	[self.apiManager.paramSetAPIv5 setCustomParameterValue:
		 [FxGripDictionary dictionaryWithDictionary:@{ kCustomAPI_IntKey:    @(dot),
													   kCustomAPI_StringKey: label }]
											   toParameter:kExampleStatusID
													atTime:time];
	[self.apiManager.paramSetAPIv5 setCustomParameterValue:
		 [FxGripDictionary dictionaryWithDictionary:@{ kCustomAPI_IntKey:    @(dot),
													   kCustomAPI_StringKey: label,
													   kCustomAPI_FloatKey:  @(fraction) }]
											   toParameter:kExampleProgressID
													atTime:time];
}

@end

#pragma mark - Test scaffolding

/*! The stub manager plus the action API the out-of-band access asks for (nil: no host action). */
@interface FxMLVideoExampleTestAPIManager : FxParamClassTestAPIManager
@property (nonatomic, strong, nullable) id customParameterActionAPIv4;
@end
@implementation FxMLVideoExampleTestAPIManager
@end

/*! The example, bent to the test bundle: a private notifier, the stub API manager, and a
	terminal-state expectation. The example's own logic is untouched. */
@interface FxMLVideoExampleTestEffect : FxMLVideoExampleEffect
@property (nonatomic, strong) NSNotificationCenter *privateNotifier;
@property (nonatomic, strong) FxMLVideoExampleTestAPIManager *stubManager;
@property (nonatomic, strong) XCTestExpectation *terminalExpectation;
@end

@implementation FxMLVideoExampleTestEffect

- (id)effectBase
{
	return self;
}

- (NSPriorityNotificationCenter *)notifier
{
	if (!_privateNotifier) {
		_privateNotifier = [[NSClassFromString(@"NSPriorityNotificationCenter") alloc] init];
	}
	return (NSPriorityNotificationCenter *)_privateNotifier;
}

- (id<FxGripAPIAccessing>)apiManager
{
	return (id<FxGripAPIAccessing>)self.stubManager;
}

- (void)generationStateDidChange
{
	[super generationStateDidChange];
	FxGripMLVideoState state = self.generationState;
	if (state == FxGripMLVideoStateReady || state == FxGripMLVideoStateFailed) {
		[self.terminalExpectation fulfill];
	}
}

@end

/*! A staged backend returning a clip. */
@interface FxMLVideoExampleStubBackend : NSObject <FxGripInferenceBackend>
@property (nonatomic, strong, nullable) FxGripInferenceRequest *lastRequest;
@property (nonatomic, strong, nullable) FxGripInferenceResult *stagedResult;
@end

@implementation FxMLVideoExampleStubBackend
- (BOOL)isReady { return YES; }
- (NSString *)backendIdentifier { return @"example-stub"; }
- (FxGripInferenceResult *)runInferenceForRequest:(FxGripInferenceRequest *)request error:(NSError **)error
{
	self.lastRequest = request;
	return self.stagedResult;
}
@end

#pragma mark - Tests

@interface FxGripMLVideoExampleTests : XCTestCase
@property (nonatomic, strong) FxMLVideoExampleTestEffect *effect;
@property (nonatomic, strong) FxMLVideoExampleStubBackend *backend;
@end

@implementation FxGripMLVideoExampleTests

- (void)setUp
{
	[super setUp];
	self.effect = [FxMLVideoExampleTestEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	self.effect.generationQueue = dispatch_queue_create("fxgrip.test.videoexample", DISPATCH_QUEUE_SERIAL);
	self.effect.stubManager = [FxMLVideoExampleTestAPIManager new];
	self.effect.stubManager.paramGetAPIv6 = [FxParamClassTestRetrievalAPI new];
	self.effect.stubManager.paramSetAPIv5 = [FxParamClassTestSettingAPI new];
	self.backend = [FxMLVideoExampleStubBackend new];
	self.effect.inferenceBackend = self.backend;
}

/*! The recorded custom write for a parameter, or nil. */
- (nullable NSDictionary *)lastCustomWriteFor:(UInt32)parameterID
{
	for (NSDictionary *write in self.effect.stubManager.paramSetAPIv5.writes.reverseObjectEnumerator) {
		if ([write[@"accessor"] isEqualToString:@"custom"] && [write[@"id"] isEqual:@(parameterID)]) {
			return write;
		}
	}
	return nil;
}

- (void)testTheExampleDeclaresThePromptButtonStatusAndProgress
{
	NSArray *parameters = [self.effect exampleParameters];
	XCTAssertEqual(parameters.count, 4u);
	XCTAssertEqualObjects(parameters[1][kFxParameterProperty_Type], kFxParameterType_PushButton);
	XCTAssertEqualObjects(parameters[2][kFxParameterProperty_Type], kFxParameterType_Status);
	XCTAssertEqualObjects(parameters[3][kFxParameterProperty_Type], kFxParameterType_Progress);
}

- (void)testTheGenerateClickRunsTheGenerationWithThePrompt
{
	self.effect.stubManager.paramGetAPIv6.stringValue = @"a slow sunrise";
	self.backend.stagedResult = [FxGripInferenceResult resultWithOutputs:
								 @{ @"video": [NSURL fileURLWithPath:@"/tmp/example.mov"] }];
	self.effect.terminalExpectation = [self expectationWithDescription:@"ready"];

	XCTAssertTrue([self.effect parameterClicked:kExampleGenerateID]);
	[self waitForExpectations:@[ self.effect.terminalExpectation ] timeout:4.0];

	XCTAssertEqual(self.effect.generationState, FxGripMLVideoStateReady);
	XCTAssertEqualObjects([self.backend.lastRequest inputForKey:@"prompt"], @"a slow sunrise",
						  @"the prompt parameter fed the request");
}

- (void)testAnUnrelatedClickFallsThroughToTheBase
{
	XCTAssertNoThrow([self.effect parameterClicked:999]);
	XCTAssertEqual(self.effect.generationState, FxGripMLVideoStateIdle);
}

- (void)testTheLifecycleMirrorsIntoTheStatusAndProgressControls
{
	self.backend.stagedResult = [FxGripInferenceResult resultWithOutputs:
								 @{ @"video": [NSURL fileURLWithPath:@"/tmp/example.mov"] }];
	self.effect.terminalExpectation = [self expectationWithDescription:@"ready"];
	[self.effect parameterClicked:kExampleGenerateID];
	[self waitForExpectations:@[ self.effect.terminalExpectation ] timeout:4.0];

	FxGripDictionary *status = [self lastCustomWriteFor:kExampleStatusID][@"value"];
	FxGripDictionary *progress = [self lastCustomWriteFor:kExampleProgressID][@"value"];
	XCTAssertNotNil(status);
	XCTAssertNotNil(progress);

	int dot = 0;
	NSString *label = nil;
	[status getIntValue:&dot];
	[status getStringParameterValue:&label];
	XCTAssertEqual(dot, (int)BEDotStateOk);
	XCTAssertEqualObjects(label, @"Clip ready");

	double fraction = 0.0;
	[progress getFloatValue:&fraction];
	XCTAssertEqualWithAccuracy(fraction, 1.0, 1e-12);
}

- (void)testAFailureShowsTheErrorOnTheStatusLight
{
	self.backend.stagedResult = [FxGripInferenceResult resultWithOutputs:@{ @"text": @"no clip" }];
	self.effect.terminalExpectation = [self expectationWithDescription:@"failed"];
	[self.effect parameterClicked:kExampleGenerateID];
	[self waitForExpectations:@[ self.effect.terminalExpectation ] timeout:4.0];

	FxGripDictionary *status = [self lastCustomWriteFor:kExampleStatusID][@"value"];
	int dot = 0;
	[status getIntValue:&dot];
	XCTAssertEqual(dot, (int)BEDotStateError, @"the failure reaches the dot");
}

@end
