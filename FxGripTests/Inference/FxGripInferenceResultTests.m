/*!
	@file       FxGripInferenceResultTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripInferenceResultTests
	@abstract   Verifies the FxGripInferenceResult output accessor.
	@discussion Introduced in FxGrip 0.1.0. The test confirms that a result returns each stored output by key and returns nil for a key it does not carry.
*/

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripInferenceResult.h>

@interface FxGripInferenceResultTests : XCTestCase
@end

@implementation FxGripInferenceResultTests

/*! @abstract A stored output is returned by its key, and an unknown key returns nil. */
- (void)testAResultExposesItsOutputs
{
	FxGripInferenceResult *result = [FxGripInferenceResult resultWithOutputs:@{ @"image": @"generated" }];
	XCTAssertEqualObjects([result outputForKey:@"image"], @"generated");
	XCTAssertNil([result outputForKey:@"missing"]);
}

@end

#pragma mark - Value semantics

@interface FxGripInferenceResultEqualityTests : XCTestCase
@end

@implementation FxGripInferenceResultEqualityTests

/*! @abstract Two results carrying equal outputs are equal and hash alike. */
- (void)testResultsWithEqualOutputsAreEqual
{
	FxGripInferenceResult *one = [FxGripInferenceResult resultWithOutputs:@{ @"image": @"A", @"score": @2 }];
	FxGripInferenceResult *two = [FxGripInferenceResult resultWithOutputs:@{ @"image": @"A", @"score": @2 }];

	XCTAssertEqualObjects(one, two);
	XCTAssertEqual(one.hash, two.hash);
}

/*! @abstract A result equals itself. */
- (void)testAResultEqualsItself
{
	FxGripInferenceResult *result = [FxGripInferenceResult resultWithOutputs:@{ @"image": @"A" }];

	XCTAssertEqualObjects(result, result);
}

/*! @abstract Results carrying different outputs are unequal, as is an object of another class. */
- (void)testResultsWithDifferentOutputsAreNotEqual
{
	FxGripInferenceResult *one = [FxGripInferenceResult resultWithOutputs:@{ @"image": @"A" }];
	FxGripInferenceResult *two = [FxGripInferenceResult resultWithOutputs:@{ @"image": @"B" }];

	XCTAssertNotEqualObjects(one, two);
	XCTAssertNotEqualObjects(one, @"not a result");
	XCTAssertNotEqualObjects(one, [FxGripInferenceResult resultWithOutputs:@{}]);
}

/*! @abstract The result is immutable, so a copy is the same object and stays equal. */
- (void)testCopyingAnImmutableResultReturnsTheSameObject
{
	FxGripInferenceResult *result = [FxGripInferenceResult resultWithOutputs:@{ @"image": @"A" }];

	FxGripInferenceResult *copy = [result copy];

	XCTAssertEqual(copy, result);
	XCTAssertEqualObjects(copy, result);
}

/*! @abstract An empty result hashes like an empty output dictionary and equals another empty result. */
- (void)testEmptyResultsAreEqual
{
	FxGripInferenceResult *one = [FxGripInferenceResult resultWithOutputs:@{}];
	FxGripInferenceResult *two = [FxGripInferenceResult resultWithOutputs:@{}];

	XCTAssertEqualObjects(one, two);
	XCTAssertEqual(one.hash, two.hash);
}

@end
