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
