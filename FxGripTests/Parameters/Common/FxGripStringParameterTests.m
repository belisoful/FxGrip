/*!
	@file       FxGripStringParameterTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripStringParameterTests
	@abstract   Tests FxGripStringParameter and its abstract base FxGripStringParameterBase: their
	            FxPlug type identity and the creation payload +addParameter:toEffect: derives.
	@discussion Introduced in FxGrip 0.1.0. The tests confirm the abstract base refusing creation
	            and the value plumbing through the retrieval and setting APIs.
*/

#import <XCTest/XCTest.h>
#import "FxGripParameterClassTestSupport.h"
#import <FxGrip/FxGripStringParameter.h>

static const FxParameterId kStringTestParameter = 41;

@interface FxGripStringParameterTests : XCTestCase
@property (nonatomic, strong) FxGripParamClassTestEffect *effect;
@end

@implementation FxGripStringParameterTests

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
	NSDictionary *config = FxGripParamClassTestConfig(kStringTestParameter, type, @"Mode", extra);
	return [parameterClass addParameter:config toEffect:(id)self.effect];
}

- (FxGripStringParameter *)makeStringParameter
{
	NSDictionary *config = FxGripParamClassTestConfig(kStringTestParameter, kFxParameterType_String, @"Mode", nil);
	return [FxGripStringParameter.alloc initWithDictionary:config effect:(id)self.effect];
}

#pragma mark Type identity

/*! @abstract The base and concrete classes both report the FxPlug string type and its type string. */
- (void)testReportsItsFxPlugTypeAndTypeString
{
	XCTAssertEqual(FxGripStringParameterBase.parameterType, FxParameterType_String);
	XCTAssertEqualObjects(FxGripStringParameterBase.parameterTypeString, kFxParameterType_String);

	XCTAssertEqual(FxGripStringParameter.parameterType, FxParameterType_String);
	XCTAssertEqualObjects(FxGripStringParameter.parameterTypeString, kFxParameterType_String);
}

#pragma mark Creation payload

/*! @abstract A string created with no default sends an empty string to the creation call. */
- (void)testStringWithoutADefaultSendsAnEmptyString
{
	XCTAssertTrue([self add:FxGripStringParameter.class type:kFxParameterType_String extra:nil]);

	XCTAssertEqualObjects(self.call, (@{@"method": @"string",
										@"name": @"Mode",
										@"id": @(kStringTestParameter),
										@"default": @"",
										@"flags": @(kFxParameterFlag_DEFAULT)}));
}

/*! @abstract A numeric default is rendered as its text form. */
- (void)testStringRendersANumericDefaultAsText
{
	NSDictionary *extra = @{kFxParameterProperty_Default: @42};

	XCTAssertTrue([self add:FxGripStringParameter.class type:kFxParameterType_String extra:extra]);

	XCTAssertEqualObjects(self.call[@"default"], @"42");
}

/*! @abstract A string default is forwarded unchanged. */
- (void)testStringForwardsAStringDefault
{
	NSDictionary *extra = @{kFxParameterProperty_Default: @"Hello"};

	XCTAssertTrue([self add:FxGripStringParameter.class type:kFxParameterType_String extra:extra]);

	XCTAssertEqualObjects(self.call[@"default"], @"Hello");
}

/*! @abstract When the host creation API refuses, +addParameter:toEffect: returns false. */
- (void)testStringReportsAHostRefusal
{
	self.effect.apiManager.paramCreateAPIv5.succeeds = NO;

	XCTAssertFalse([self add:FxGripStringParameter.class type:kFxParameterType_String extra:nil]);
}

/*! The base class declares no creation; the abstract implementation refuses. */
- (void)testTheStringBaseClassHasNoCreationOfItsOwn
{
	NSDictionary *config = FxGripParamClassTestConfig(kStringTestParameter, kFxParameterType_String, @"Mode", nil);

	XCTAssertThrowsSpecificNamed([FxGripStringParameterBase addParameter:config toEffect:(id)self.effect],
								 NSException,
								 NSInternalInconsistencyException);
}

#pragma mark Values

/*! @abstract The stringValue accessor reads the value from the retrieval API. */
- (void)testStringValueReadsFromTheRetrievalAPI
{
	FxGripStringParameter *parameter = [self makeStringParameter];
	self.effect.apiManager.paramGetAPIv6.stringValue = @"Caption";

	XCTAssertEqualObjects(parameter.stringValue, @"Caption");
	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.lastRead[@"accessor"], @"string");
	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.lastRead[@"id"], @(kStringTestParameter));
}

/*! @abstract -valueAtTime: performs the same read as the stringValue accessor. */
- (void)testStringValueAtTimeIsTheSameReadAsTheStringValue
{
	FxGripStringParameter *parameter = [self makeStringParameter];
	self.effect.apiManager.paramGetAPIv6.stringValue = @"Caption";

	XCTAssertEqualObjects([parameter valueAtTime:FxGripParamClassTestTime(9, 30)], @"Caption");
}

/*! @abstract Setting stringValue writes the value through the setting API. */
- (void)testSettingTheStringValueWritesThroughTheSettingAPI
{
	FxGripStringParameter *parameter = [self makeStringParameter];

	parameter.stringValue = @"Caption";

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.lastWrite,
						  (@{@"accessor": @"string",
							 @"id": @(kStringTestParameter),
							 @"value": @"Caption"}));
}

/*! @abstract Setting a nil stringValue writes the empty string. */
- (void)testANilStringValueIsWrittenAsTheEmptyString
{
	FxGripStringParameter *parameter = [self makeStringParameter];

	parameter.stringValue = nil;

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.lastWrite[@"value"], @"");
}

/*! @abstract -setValue:atTime: writes the same string as the stringValue setter. */
- (void)testSetValueAtTimeWritesTheSameStringAsTheSetter
{
	FxGripStringParameter *parameter = [self makeStringParameter];

	[parameter setValue:@"Caption" atTime:FxGripParamClassTestTime(0, 1)];

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.lastWrite[@"value"], @"Caption");
}

@end
