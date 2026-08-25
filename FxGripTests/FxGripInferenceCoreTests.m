//
//  FxGripInferenceCoreTests.m
//  FxGripTests
//

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripInferenceRequest.h>
#import <FxGrip/FxGripInferenceResult.h>
#import <FxGrip/FxGripInferenceBackend.h>
#import <FxGrip/FxGripPassthroughBackend.h>
#import <FxGrip/FxGripErrors.h>

@interface FxGripInferenceCoreTests : XCTestCase
@end

@implementation FxGripInferenceCoreTests

#pragma mark Request

- (void)testARequestKeepsInputsAndParametersSeparate
{
	FxGripInferenceRequest *request = [FxGripInferenceRequest requestWithInputs:@{ @"image": @"plate" }
																	 parameters:@{ @"seed": @42 }];
	XCTAssertEqualObjects([request inputForKey:@"image"], @"plate");
	XCTAssertEqualObjects([request parameterForKey:@"seed"], @42);
	XCTAssertNil([request inputForKey:@"seed"], @"a parameter is not an input");
	XCTAssertNil([request parameterForKey:@"image"], @"an input is not a parameter");
}

- (void)testARequestDefaultsToEmptyCollections
{
	FxGripInferenceRequest *request = [FxGripInferenceRequest requestWithInputs:@{}];
	XCTAssertEqualObjects(request.inputs, @{});
	XCTAssertEqualObjects(request.parameters, @{});
}

- (void)testRequestEqualityConsidersInputsAndParameters
{
	FxGripInferenceRequest *a = [FxGripInferenceRequest requestWithInputs:@{ @"image": @"plate" } parameters:@{ @"seed": @1 }];
	FxGripInferenceRequest *b = [FxGripInferenceRequest requestWithInputs:@{ @"image": @"plate" } parameters:@{ @"seed": @1 }];
	FxGripInferenceRequest *c = [FxGripInferenceRequest requestWithInputs:@{ @"image": @"plate" } parameters:@{ @"seed": @2 }];
	XCTAssertEqualObjects(a, b);
	XCTAssertNotEqualObjects(a, c);
}

- (void)testARequestIsImmutableUnderCopy
{
	FxGripInferenceRequest *request = [FxGripInferenceRequest requestWithInputs:@{ @"image": @"plate" }];
	XCTAssertEqual([request copy], request, @"an immutable value copies to itself");
}

#pragma mark Result

- (void)testAResultExposesItsOutputs
{
	FxGripInferenceResult *result = [FxGripInferenceResult resultWithOutputs:@{ @"image": @"generated" }];
	XCTAssertEqualObjects([result outputForKey:@"image"], @"generated");
	XCTAssertNil([result outputForKey:@"missing"]);
}

#pragma mark Passthrough backend

- (void)testThePassthroughBackendIsAlwaysReady
{
	FxGripPassthroughBackend *backend = [FxGripPassthroughBackend backend];
	XCTAssertTrue(backend.isReady);
	XCTAssertEqualObjects(backend.backendIdentifier, @"passthrough");
}

- (void)testThePassthroughBackendEchoesInputsByDefault
{
	FxGripPassthroughBackend *backend = [FxGripPassthroughBackend backend];
	FxGripInferenceRequest *request = [FxGripInferenceRequest requestWithInputs:@{ @"image": @"plate" }];
	NSError *error = nil;
	FxGripInferenceResult *result = [backend runInferenceForRequest:request error:&error];
	XCTAssertNil(error);
	XCTAssertEqualObjects([result outputForKey:@"image"], @"plate");
}

- (void)testThePassthroughBackendRoutesThroughItsOutputMap
{
	FxGripPassthroughBackend *backend = [FxGripPassthroughBackend backend];
	backend.outputMap = @{ @"fg": @"rgb", @"matte": @"hint" };
	FxGripInferenceRequest *request = [FxGripInferenceRequest requestWithInputs:@{ @"rgb": @"plate", @"hint": @"alpha" }];
	NSError *error = nil;
	FxGripInferenceResult *result = [backend runInferenceForRequest:request error:&error];
	XCTAssertNil(error);
	XCTAssertEqualObjects([result outputForKey:@"fg"], @"plate");
	XCTAssertEqualObjects([result outputForKey:@"matte"], @"alpha");
	XCTAssertNil([result outputForKey:@"rgb"], @"only mapped outputs are produced");
}

- (void)testThePassthroughBackendFailsOnAMappedInputThatIsMissing
{
	FxGripPassthroughBackend *backend = [FxGripPassthroughBackend backend];
	backend.outputMap = @{ @"fg": @"rgb" };
	FxGripInferenceRequest *request = [FxGripInferenceRequest requestWithInputs:@{ @"hint": @"alpha" }];
	NSError *error = nil;
	FxGripInferenceResult *result = [backend runInferenceForRequest:request error:&error];
	XCTAssertNil(result);
	XCTAssertNotNil(error);
	XCTAssertEqual(error.code, (NSInteger)kFxGripError_InferenceMissingInput);
}

- (void)testThePassthroughBackendConformsToTheBackendProtocol
{
	id<FxGripInferenceBackend> backend = [FxGripPassthroughBackend backend];
	XCTAssertTrue([backend conformsToProtocol:@protocol(FxGripInferenceBackend)]);
	XCTAssertTrue([backend respondsToSelector:@selector(runInferenceForRequest:error:)]);
}

@end
