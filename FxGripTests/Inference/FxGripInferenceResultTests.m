//
//  FxGripInferenceResultTests.m
//  FxGripTests
//
//  Unit tests for FxGripInferenceResult: the outputs it exposes and the nil it answers for a
//  key it does not carry.
//

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripInferenceResult.h>

@interface FxGripInferenceResultTests : XCTestCase
@end

@implementation FxGripInferenceResultTests

- (void)testAResultExposesItsOutputs
{
	FxGripInferenceResult *result = [FxGripInferenceResult resultWithOutputs:@{ @"image": @"generated" }];
	XCTAssertEqualObjects([result outputForKey:@"image"], @"generated");
	XCTAssertNil([result outputForKey:@"missing"]);
}

@end
