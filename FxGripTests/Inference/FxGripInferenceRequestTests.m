//
//  FxGripInferenceRequestTests.m
//  FxGripTests
//
//  Unit tests for FxGripInferenceRequest: inputs and parameters stay in separate namespaces,
//  both default to empty collections, equality considers both, and the value is immutable
//  under copy.
//

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripInferenceRequest.h>

@interface FxGripInferenceRequestTests : XCTestCase
@end

@implementation FxGripInferenceRequestTests

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

@end
