//
//  FxGripToggleParameterTests.m
//  FxGripTests
//
//  Unit tests for FxGripToggleParameter: the type identity, the payload
//  +addParameter:toEffect: derives from a configuration, the boolean default coercion, the
//  host-refusal result, and the value plumbing through the retrieval and setting APIs.
//

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

- (void)testReportsItsFxPlugTypeAndTypeString
{
	XCTAssertEqual(FxGripToggleParameter.parameterType, FxParameterType_Toggle);
	XCTAssertEqualObjects(FxGripToggleParameter.parameterTypeString, kFxParameterType_Toggle);
}

#pragma mark Creation payload

- (void)testToggleWithoutADefaultIsOff
{
	XCTAssertTrue([self add:FxGripToggleParameter.class type:kFxParameterType_Toggle extra:nil]);

	XCTAssertEqualObjects(self.call, (@{@"method": @"toggle",
										@"name": @"Mode",
										@"id": @(kToggleTestParameter),
										@"default": @NO,
										@"flags": @(kFxParameterFlag_DEFAULT)}));
}

- (void)testToggleForwardsATrueDefault
{
	NSDictionary *extra = @{kFxParameterProperty_Default: @YES};

	XCTAssertTrue([self add:FxGripToggleParameter.class type:kFxParameterType_Toggle extra:extra]);

	XCTAssertEqualObjects(self.call[@"default"], @YES);
}

- (void)testToggleReadsANonZeroNumberAsTrue
{
	NSDictionary *extra = @{kFxParameterProperty_Default: @3};

	XCTAssertTrue([self add:FxGripToggleParameter.class type:kFxParameterType_Toggle extra:extra]);

	XCTAssertEqualObjects(self.call[@"default"], @YES);
}

- (void)testToggleReportsAHostRefusal
{
	self.effect.apiManager.paramCreateAPIv5.succeeds = NO;

	XCTAssertFalse([self add:FxGripToggleParameter.class type:kFxParameterType_Toggle extra:nil]);
}

#pragma mark Values

- (void)testToggleValueAtTimeReadsTheBoolFromTheRetrievalAPI
{
	FxGripToggleParameter *parameter = [self makeToggleParameter];
	self.effect.apiManager.paramGetAPIv6.boolValue = YES;

	XCTAssertTrue([parameter valueAtTime:FxGripParamClassTestTime(6, 30)]);
	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.lastRead[@"accessor"], @"bool");
	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.lastRead[@"timevalue"], @6);
}

- (void)testToggleValueAtTimeIsFalseWhenTheReadFails
{
	FxGripToggleParameter *parameter = [self makeToggleParameter];
	self.effect.apiManager.paramGetAPIv6.boolValue = YES;
	self.effect.apiManager.paramGetAPIv6.succeeds = NO;

	XCTAssertFalse([parameter valueAtTime:FxGripParamClassTestTime(0, 1)]);
}

- (void)testTheToggleBoolValueReadsAtTheZeroTime
{
	FxGripToggleParameter *parameter = [self makeToggleParameter];
	self.effect.apiManager.paramGetAPIv6.boolValue = YES;

	XCTAssertTrue(parameter.boolValue);
	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.lastRead[@"timevalue"], @0);
}

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

- (void)testToggleSetValueAtTimeCarriesTheRequestedTime
{
	FxGripToggleParameter *parameter = [self makeToggleParameter];

	[parameter setValue:NO atTime:FxGripParamClassTestTime(12, 30)];

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.lastWrite[@"value"], @NO);
	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.lastWrite[@"timevalue"], @12);
}

@end
