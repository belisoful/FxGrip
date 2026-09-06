/*!
	@file       FxGripInferenceRequestTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripInferenceRequestTests
	@abstract   Verifies the FxGripInferenceRequest value type.
	@discussion Introduced in FxGrip 0.1.0. The tests confirm that inputs and parameters stay in separate namespaces, both default to empty dictionaries, equality considers both, and a copy returns the same immutable instance.
*/

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripInferenceRequest.h>

@interface FxGripInferenceRequestTests : XCTestCase
@end

@implementation FxGripInferenceRequestTests

/*! @abstract An input is read only through the input accessor and a parameter only through the parameter accessor. */
- (void)testARequestKeepsInputsAndParametersSeparate
{
	FxGripInferenceRequest *request = [FxGripInferenceRequest requestWithInputs:@{ @"image": @"plate" }
																	 parameters:@{ @"seed": @42 }];
	XCTAssertEqualObjects([request inputForKey:@"image"], @"plate");
	XCTAssertEqualObjects([request parameterForKey:@"seed"], @42);
	XCTAssertNil([request inputForKey:@"seed"], @"a parameter is not an input");
	XCTAssertNil([request parameterForKey:@"image"], @"an input is not a parameter");
}

/*! @abstract A request built from inputs alone exposes empty inputs and parameters dictionaries. */
- (void)testARequestDefaultsToEmptyCollections
{
	FxGripInferenceRequest *request = [FxGripInferenceRequest requestWithInputs:@{}];
	XCTAssertEqualObjects(request.inputs, @{});
	XCTAssertEqualObjects(request.parameters, @{});
}

/*! @abstract Two requests are equal when both inputs and parameters match, and unequal when a parameter differs. */
- (void)testRequestEqualityConsidersInputsAndParameters
{
	FxGripInferenceRequest *a = [FxGripInferenceRequest requestWithInputs:@{ @"image": @"plate" } parameters:@{ @"seed": @1 }];
	FxGripInferenceRequest *b = [FxGripInferenceRequest requestWithInputs:@{ @"image": @"plate" } parameters:@{ @"seed": @1 }];
	FxGripInferenceRequest *c = [FxGripInferenceRequest requestWithInputs:@{ @"image": @"plate" } parameters:@{ @"seed": @2 }];
	XCTAssertEqualObjects(a, b);
	XCTAssertNotEqualObjects(a, c);
}

/*! @abstract Copying an immutable request returns the same instance. */
- (void)testARequestIsImmutableUnderCopy
{
	FxGripInferenceRequest *request = [FxGripInferenceRequest requestWithInputs:@{ @"image": @"plate" }];
	XCTAssertEqual([request copy], request, @"an immutable value copies to itself");
}

@end
