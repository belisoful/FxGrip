/*!
	@file       FxGripPassthroughBackendTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripPassthroughBackendTests
	@abstract   Verifies the FxGripPassthroughBackend inference backend.
	@discussion Introduced in FxGrip 0.1.0. The tests confirm that the backend reports itself ready, echoes inputs to outputs by default, renames outputs through its output map, fails when a mapped input is absent, and conforms to the FxGripInferenceBackend protocol.
*/

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripInferenceRequest.h>
#import <FxGrip/FxGripInferenceResult.h>
#import <FxGrip/FxGripInferenceBackend.h>
#import <FxGrip/FxGripPassthroughBackend.h>
#import <FxGrip/FxGripErrors.h>

@interface FxGripPassthroughBackendTests : XCTestCase
@end

@implementation FxGripPassthroughBackendTests

/*! @abstract The backend reports ready and identifies itself as "passthrough". */
- (void)testThePassthroughBackendIsAlwaysReady
{
	FxGripPassthroughBackend *backend = [FxGripPassthroughBackend backend];
	XCTAssertTrue(backend.isReady);
	XCTAssertEqualObjects(backend.backendIdentifier, @"passthrough");
}

/*! @abstract Without an output map, each input appears under the same key in the result. */
- (void)testThePassthroughBackendEchoesInputsByDefault
{
	FxGripPassthroughBackend *backend = [FxGripPassthroughBackend backend];
	FxGripInferenceRequest *request = [FxGripInferenceRequest requestWithInputs:@{ @"image": @"plate" }];
	NSError *error = nil;
	FxGripInferenceResult *result = [backend runInferenceForRequest:request error:&error];
	XCTAssertNil(error);
	XCTAssertEqualObjects([result outputForKey:@"image"], @"plate");
}

/*! @abstract The output map copies each named input to its output key, and only mapped outputs appear. */
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

/*! @abstract A mapped input absent from the request yields a nil result and the missing-input error. */
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

/*! @abstract The backend conforms to FxGripInferenceBackend and responds to the run selector. */
- (void)testThePassthroughBackendConformsToTheBackendProtocol
{
	id<FxGripInferenceBackend> backend = [FxGripPassthroughBackend backend];
	XCTAssertTrue([backend conformsToProtocol:@protocol(FxGripInferenceBackend)]);
	XCTAssertTrue([backend respondsToSelector:@selector(runInferenceForRequest:error:)]);
}

@end
