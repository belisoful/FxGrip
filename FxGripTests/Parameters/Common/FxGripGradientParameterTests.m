//
//  FxGripGradientParameterTests.m
//  FxGripTests
//
//  Unit tests for FxGripGradientParameter: the type identity, the name-ID-flags payload it
//  hands the creation API, the host-refusal result, and the sample-count and depth the
//  value read asks of the retrieval API.
//

#import <XCTest/XCTest.h>
#import "FxGripParameterClassTestSupport.h"
#import <FxGrip/FxGripGradientParameter.h>

static const FxParameterId kGradientTestParameter = 51;

@interface FxGripGradientParameterTests : XCTestCase
@property (nonatomic, strong) FxGripParamClassTestEffect *effect;
@end

@implementation FxGripGradientParameterTests

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
	NSDictionary *config = FxGripParamClassTestConfig(kGradientTestParameter, type, @"Levels", extra);
	return [parameterClass addParameter:config toEffect:(id)self.effect];
}

- (FxGripGradientParameter *)makeGradientParameter
{
	NSDictionary *config = FxGripParamClassTestConfig(kGradientTestParameter, kFxParameterType_Gradient, @"Levels", nil);
	return [FxGripGradientParameter.alloc initWithDictionary:config effect:(id)self.effect];
}

#pragma mark Type identity

- (void)testReportsItsFxPlugTypeAndTypeString
{
	XCTAssertEqual(FxGripGradientParameter.parameterType, FxParameterType_Gradient);
	XCTAssertEqualObjects(FxGripGradientParameter.parameterTypeString, kFxParameterType_Gradient);
}

#pragma mark Creation payload

- (void)testGradientForwardsOnlyTheNameIDAndFlags
{
	XCTAssertTrue([self add:FxGripGradientParameter.class type:kFxParameterType_Gradient extra:nil]);

	XCTAssertEqualObjects(self.call, (@{@"method": @"gradient",
										@"name": @"Levels",
										@"id": @(kGradientTestParameter),
										@"flags": @(kFxParameterFlag_DEFAULT)}));
}

- (void)testGradientCarriesTheConfiguredFlags
{
	NSArray *declared = @[kParameterFlagString_HIDDEN];
	NSDictionary *extra = @{kFxParameterProperty_Flags: declared};

	XCTAssertTrue([self add:FxGripGradientParameter.class type:kFxParameterType_Gradient extra:extra]);

	XCTAssertEqualObjects(self.call[@"flags"], @(kFxParameterFlag_HIDDEN));
}

- (void)testReportsAHostRefusal
{
	self.effect.apiManager.paramCreateAPIv5.succeeds = NO;

	XCTAssertFalse([self add:FxGripGradientParameter.class type:kFxParameterType_Gradient extra:nil]);
}

#pragma mark Values

- (void)testGradientValueAtTimeAsksForTheConfiguredSampleCountAndDepth
{
	FxGripGradientParameter *parameter = [self makeGradientParameter];
	parameter.samples = 8;
	parameter.byteDepth = 4;
	parameter.fxDepth = kFxDepth_FLOAT32;

	FxGripGradient *gradient = [parameter valueAtTime:FxGripParamClassTestTime(2, 30)];

	XCTAssertTrue(gradient != NULL);
	XCTAssertEqual(gradient->count, (NSUInteger)8);
	XCTAssertEqual(gradient->depth, kFxDepth_FLOAT32);
	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.lastRead[@"accessor"], @"gradient");
	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.lastRead[@"samples"], @8);
	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.lastRead[@"depth"], @(kFxDepth_FLOAT32));
}

- (void)testGradientValueAtTimeIsNullWhenTheReadFails
{
	FxGripGradientParameter *parameter = [self makeGradientParameter];
	parameter.samples = 4;
	parameter.byteDepth = 4;
	parameter.fxDepth = kFxDepth_FLOAT32;
	self.effect.apiManager.paramGetAPIv6.succeeds = NO;

	XCTAssertTrue([parameter valueAtTime:FxGripParamClassTestTime(0, 1)] == NULL);
}

- (void)testRepeatedGradientReadsReplaceTheBuffer
{
	FxGripGradientParameter *parameter = [self makeGradientParameter];
	parameter.samples = 4;
	parameter.byteDepth = 1;
	parameter.fxDepth = kFxDepth_UINT8;

	[parameter valueAtTime:FxGripParamClassTestTime(0, 1)];
	FxGripGradient *second = [parameter valueAtTime:FxGripParamClassTestTime(1, 30)];

	XCTAssertTrue(second != NULL);
	XCTAssertEqual(self.effect.apiManager.paramGetAPIv6.reads.count, (NSUInteger)2);
}

@end
