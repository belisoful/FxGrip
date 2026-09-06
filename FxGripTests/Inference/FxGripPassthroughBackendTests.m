//
//  FxGripPassthroughBackendTests.m
//  FxGripTests
//
//  Unit tests for FxGripPassthroughBackend: it is always ready, echoes inputs by default,
//  routes through its output map, fails on a mapped input that is missing, and conforms to
//  the FxGripInferenceBackend protocol.
//

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripInferenceRequest.h>
#import <FxGrip/FxGripInferenceResult.h>
#import <FxGrip/FxGripInferenceBackend.h>
#import <FxGrip/FxGripPassthroughBackend.h>
#import <FxGrip/FxGripErrors.h>

@interface FxGripPassthroughBackendTests : XCTestCase
@end

@implementation FxGripPassthroughBackendTests

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
