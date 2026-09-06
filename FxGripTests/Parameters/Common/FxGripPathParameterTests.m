/*!
	@file       FxGripPathParameterTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripPathParameterTests
	@abstract   Tests FxGripPathParameter: its FxPlug type identity and the name-ID-flags payload
	            it hands the creation API.
	@discussion Introduced in FxGrip 0.1.0. The tests confirm the host-refusal result and the
	            path ID the value read requests for its parameter.
*/

#import <XCTest/XCTest.h>
#import "FxGripParameterClassTestSupport.h"
#import <FxGrip/FxGripPathParameter.h>

static const FxParameterId kPathTestParameter = 51;

@interface FxGripPathParameterTests : XCTestCase
@property (nonatomic, strong) FxGripParamClassTestEffect *effect;
@end

@implementation FxGripPathParameterTests

- (void)setUp
{
	[super setUp];
	self.effect = [FxGripParamClassTestEffect.alloc init];
}

- (void)tearDown
{
	self.effect = nil;
	[super tearDown];
}

#pragma mark Helpers

- (NSDictionary *)call
{
	return self.effect.creationCall;
}

- (BOOL)add:(Class)parameterClass type:(NSString *)type extra:(NSDictionary *)extra
{
	NSDictionary *config = FxGripParamClassTestConfig(kPathTestParameter, type, @"Levels", extra);
	return [parameterClass addParameter:config toEffect:(id)self.effect];
}

- (FxGripPathParameter *)makePathParameter
{
	NSDictionary *config = FxGripParamClassTestConfig(kPathTestParameter, kFxParameterType_PathID, @"Levels", nil);
	return [FxGripPathParameter.alloc initWithDictionary:config effect:(id)self.effect];
}

#pragma mark Type identity

/*! @abstract The class reports the FxPlug path type and its type string. */
- (void)testReportsItsFxPlugTypeAndTypeString
{
	XCTAssertEqual(FxGripPathParameter.parameterType, FxParameterType_PathID);
	XCTAssertEqualObjects(FxGripPathParameter.parameterTypeString, kFxParameterType_PathID);
}

#pragma mark Creation payload

/*! @abstract A path picker hands the creation call only the name, ID, and flags. */
- (void)testPathPickerForwardsOnlyTheNameIDAndFlags
{
	XCTAssertTrue([self add:FxGripPathParameter.class type:kFxParameterType_PathID extra:nil]);

	XCTAssertEqualObjects(self.call, (@{@"method": @"path",
										@"name": @"Levels",
										@"id": @(kPathTestParameter),
										@"flags": @(kFxParameterFlag_DEFAULT)}));
}

/*! @abstract When the host creation API refuses, +addParameter:toEffect: returns false. */
- (void)testReportsAHostRefusal
{
	self.effect.apiManager.paramCreateAPIv5.succeeds = NO;

	XCTAssertFalse([self add:FxGripPathParameter.class type:kFxParameterType_PathID extra:nil]);
}

#pragma mark Values

/*! @abstract -valueAtTime: reads the path ID for its parameter and render time from the retrieval API. */
- (void)testPathValueAtTimeReadsThePathIDForItsParameter
{
	FxGripPathParameter *parameter = [self makePathParameter];

	[parameter valueAtTime:FxGripParamClassTestTime(8, 30)];

	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.lastRead[@"accessor"], @"path");
	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.lastRead[@"id"], @(kPathTestParameter));
	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.lastRead[@"timevalue"], @8);
}

@end
