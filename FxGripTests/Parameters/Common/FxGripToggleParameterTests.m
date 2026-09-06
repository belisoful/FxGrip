/*!
	@file       FxGripToggleParameterTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripToggleParameterTests
	@abstract   Tests FxGripToggleParameter: its FxPlug type identity and the creation payload
	            +addParameter:toEffect: derives from a configuration.
	@discussion Introduced in FxGrip 0.1.0. The tests confirm the boolean default coercion, the
	            host-refusal result, and the value plumbing through the retrieval and setting
	            APIs.
*/

#import <XCTest/XCTest.h>
#import "FxGripParameterClassTestSupport.h"
#import <FxGrip/FxGripToggleParameter.h>

// Declared in the implementation rather than the public header.
@interface FxGripToggleParameter (FxGripToggleParameterTests)
- (BOOL)valueAtTime:(CMTime)renderTime;
- (void)setValue:(BOOL)value atTime:(CMTime)time;
@end

static const FxParameterId kToggleTestParameter = 41;

@interface FxGripToggleParameterTests : XCTestCase
@property (nonatomic, strong) FxGripParamClassTestEffect *effect;
@end

@implementation FxGripToggleParameterTests

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
	NSDictionary *config = FxGripParamClassTestConfig(kToggleTestParameter, type, @"Mode", extra);
	return [parameterClass addParameter:config toEffect:(id)self.effect];
}

- (FxGripToggleParameter *)makeToggleParameter
{
	NSDictionary *config = FxGripParamClassTestConfig(kToggleTestParameter, kFxParameterType_Toggle, @"Mode", nil);
	return [FxGripToggleParameter.alloc initWithDictionary:config effect:(id)self.effect];
}

#pragma mark Type identity

/*! @abstract The class reports the FxPlug toggle type and its type string. */
- (void)testReportsItsFxPlugTypeAndTypeString
{
	XCTAssertEqual(FxGripToggleParameter.parameterType, FxParameterType_Toggle);
	XCTAssertEqualObjects(FxGripToggleParameter.parameterTypeString, kFxParameterType_Toggle);
}

#pragma mark Creation payload

/*! @abstract A toggle created with no default is off. */
- (void)testToggleWithoutADefaultIsOff
{
	XCTAssertTrue([self add:FxGripToggleParameter.class type:kFxParameterType_Toggle extra:nil]);

	XCTAssertEqualObjects(self.call, (@{@"method": @"toggle",
										@"name": @"Mode",
										@"id": @(kToggleTestParameter),
										@"default": @NO,
										@"flags": @(kFxParameterFlag_DEFAULT)}));
}

/*! @abstract A toggle forwards a true default to the creation call. */
- (void)testToggleForwardsATrueDefault
{
	NSDictionary *extra = @{kFxParameterProperty_Default: @YES};

	XCTAssertTrue([self add:FxGripToggleParameter.class type:kFxParameterType_Toggle extra:extra]);

	XCTAssertEqualObjects(self.call[@"default"], @YES);
}

/*! @abstract A non-zero numeric default is coerced to a true default. */
- (void)testToggleReadsANonZeroNumberAsTrue
{
	NSDictionary *extra = @{kFxParameterProperty_Default: @3};

	XCTAssertTrue([self add:FxGripToggleParameter.class type:kFxParameterType_Toggle extra:extra]);

	XCTAssertEqualObjects(self.call[@"default"], @YES);
}

/*! @abstract When the host creation API refuses, +addParameter:toEffect: returns false. */
- (void)testToggleReportsAHostRefusal
{
	self.effect.apiManager.paramCreateAPIv5.succeeds = NO;

	XCTAssertFalse([self add:FxGripToggleParameter.class type:kFxParameterType_Toggle extra:nil]);
}

#pragma mark Values

/*! @abstract -valueAtTime: reads the boolean and render time from the retrieval API. */
- (void)testToggleValueAtTimeReadsTheBoolFromTheRetrievalAPI
{
	FxGripToggleParameter *parameter = [self makeToggleParameter];
	self.effect.apiManager.paramGetAPIv6.boolValue = YES;

	XCTAssertTrue([parameter valueAtTime:FxGripParamClassTestTime(6, 30)]);
	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.lastRead[@"accessor"], @"bool");
	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.lastRead[@"timevalue"], @6);
}

/*! @abstract -valueAtTime: is false when the retrieval read fails. */
- (void)testToggleValueAtTimeIsFalseWhenTheReadFails
{
	FxGripToggleParameter *parameter = [self makeToggleParameter];
	self.effect.apiManager.paramGetAPIv6.boolValue = YES;
	self.effect.apiManager.paramGetAPIv6.succeeds = NO;

	XCTAssertFalse([parameter valueAtTime:FxGripParamClassTestTime(0, 1)]);
}

/*! @abstract The boolValue accessor reads at the zero time. */
- (void)testTheToggleBoolValueReadsAtTheZeroTime
{
	FxGripToggleParameter *parameter = [self makeToggleParameter];
	self.effect.apiManager.paramGetAPIv6.boolValue = YES;

	XCTAssertTrue(parameter.boolValue);
	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.lastRead[@"timevalue"], @0);
}

/*! @abstract Setting boolValue writes the value at the zero time. */
- (void)testSettingTheToggleBoolValueWritesAtTheZeroTime
{
	FxGripToggleParameter *parameter = [self makeToggleParameter];

	parameter.boolValue = YES;

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.lastWrite,
						  (@{@"accessor": @"bool",
							 @"id": @(kToggleTestParameter),
							 @"value": @YES,
							 @"timevalue": @0}));
}

/*! @abstract -setValue:atTime: writes the value and carries the requested render time. */
- (void)testToggleSetValueAtTimeCarriesTheRequestedTime
{
	FxGripToggleParameter *parameter = [self makeToggleParameter];

	[parameter setValue:NO atTime:FxGripParamClassTestTime(12, 30)];

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.lastWrite[@"value"], @NO);
	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.lastWrite[@"timevalue"], @12);
}

@end
