//
//  FxGripStringParameterTests.m
//  FxGripTests
//
//  Unit tests for FxGripStringParameter and its abstract base FxGripStringParameterBase:
//  the type identity, the payload +addParameter:toEffect: derives from a configuration, the
//  abstract base refusing creation, and the value plumbing through the retrieval and setting
//  APIs.
//

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

- (void)testReportsItsFxPlugTypeAndTypeString
{
	XCTAssertEqual(FxGripStringParameterBase.parameterType, FxParameterType_String);
	XCTAssertEqualObjects(FxGripStringParameterBase.parameterTypeString, kFxParameterType_String);

	XCTAssertEqual(FxGripStringParameter.parameterType, FxParameterType_String);
	XCTAssertEqualObjects(FxGripStringParameter.parameterTypeString, kFxParameterType_String);
}

#pragma mark Creation payload

- (void)testStringWithoutADefaultSendsAnEmptyString
{
	XCTAssertTrue([self add:FxGripStringParameter.class type:kFxParameterType_String extra:nil]);

	XCTAssertEqualObjects(self.call, (@{@"method": @"string",
										@"name": @"Mode",
										@"id": @(kStringTestParameter),
										@"default": @"",
										@"flags": @(kFxParameterFlag_DEFAULT)}));
}

- (void)testStringRendersANumericDefaultAsText
{
	NSDictionary *extra = @{kFxParameterProperty_Default: @42};

	XCTAssertTrue([self add:FxGripStringParameter.class type:kFxParameterType_String extra:extra]);

	XCTAssertEqualObjects(self.call[@"default"], @"42");
}

- (void)testStringForwardsAStringDefault
{
	NSDictionary *extra = @{kFxParameterProperty_Default: @"Hello"};

	XCTAssertTrue([self add:FxGripStringParameter.class type:kFxParameterType_String extra:extra]);

	XCTAssertEqualObjects(self.call[@"default"], @"Hello");
}

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

- (void)testStringValueReadsFromTheRetrievalAPI
{
	FxGripStringParameter *parameter = [self makeStringParameter];
	self.effect.apiManager.paramGetAPIv6.stringValue = @"Caption";

	XCTAssertEqualObjects(parameter.stringValue, @"Caption");
	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.lastRead[@"accessor"], @"string");
	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.lastRead[@"id"], @(kStringTestParameter));
}

- (void)testStringValueAtTimeIsTheSameReadAsTheStringValue
{
	FxGripStringParameter *parameter = [self makeStringParameter];
	self.effect.apiManager.paramGetAPIv6.stringValue = @"Caption";

	XCTAssertEqualObjects([parameter valueAtTime:FxGripParamClassTestTime(9, 30)], @"Caption");
}

- (void)testSettingTheStringValueWritesThroughTheSettingAPI
{
	FxGripStringParameter *parameter = [self makeStringParameter];

	parameter.stringValue = @"Caption";

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.lastWrite,
						  (@{@"accessor": @"string",
							 @"id": @(kStringTestParameter),
							 @"value": @"Caption"}));
}

- (void)testANilStringValueIsWrittenAsTheEmptyString
{
	FxGripStringParameter *parameter = [self makeStringParameter];

	parameter.stringValue = nil;

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.lastWrite[@"value"], @"");
}

- (void)testSetValueAtTimeWritesTheSameStringAsTheSetter
{
	FxGripStringParameter *parameter = [self makeStringParameter];

	[parameter setValue:@"Caption" atTime:FxGripParamClassTestTime(0, 1)];

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.lastWrite[@"value"], @"Caption");
}

@end
