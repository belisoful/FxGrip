//
//  FxGripColorParameterTests.m
//  FxGripTests
//
//  Unit tests for FxGripColorParameter (RGBA): the type identity, the payload
//  +addParameter:toEffect: derives from the nested default record, the color-space gamma
//  conversion, and the value plumbing through the retrieval and setting APIs.
//

#import <XCTest/XCTest.h>
#import "FxGripParameterClassTestSupport.h"
#import <FxGrip/FxGripColorParameter.h>

static const FxParameterId kColorTestParameter = 31;
static const double kColorTestGamma = 2.2;

@interface FxGripColorParameterTests : XCTestCase
@property (nonatomic, strong) FxGripParamClassTestEffect *effect;
@end

@implementation FxGripColorParameterTests

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
	NSDictionary *config = FxGripParamClassTestConfig(kColorTestParameter, type, @"Tint", extra);
	return [parameterClass addParameter:config toEffect:(id)self.effect];
}

- (double)callDouble:(NSString *)key
{
	return ((NSNumber *)self.call[key]).doubleValue;
}

- (FxGripColorParameter *)makeColorParameter
{
	NSDictionary *config = FxGripParamClassTestConfig(kColorTestParameter, kFxParameterType_RGBA, @"Tint", nil);
	return [FxGripColorParameter.alloc initWithDictionary:config effect:(id)self.effect];
}

#pragma mark Type identity

- (void)testReportsItsFxPlugTypeAndTypeString
{
	XCTAssertEqual(FxGripColorParameter.parameterType, FxParameterType_RGBA);
	XCTAssertEqualObjects(FxGripColorParameter.parameterTypeString, kFxParameterType_RGBA);
}

#pragma mark Creation

- (void)testColorWithoutADefaultIsOpaqueBlack
{
	XCTAssertTrue([self add:FxGripColorParameter.class type:kFxParameterType_RGBA extra:nil]);

	XCTAssertEqualObjects(self.call, (@{@"method": @"rgba",
										@"name": @"Tint",
										@"id": @(kColorTestParameter),
										@"red": @0.0,
										@"green": @0.0,
										@"blue": @0.0,
										@"alpha": @1.0,
										@"flags": @(kFxParameterFlag_DEFAULT)}));
}

- (void)testColorForwardsEveryComponentOfTheNestedDefault
{
	NSDictionary *color = @{kFxParameterProperty_Red: @0.1,
							kFxParameterProperty_Green: @0.2,
							kFxParameterProperty_Blue: @0.3,
							kFxParameterProperty_Alpha: @0.4};
	NSDictionary *extra = @{kFxParameterProperty_Default: color};

	XCTAssertTrue([self add:FxGripColorParameter.class type:kFxParameterType_RGBA extra:extra]);

	XCTAssertEqualObjects(self.call, (@{@"method": @"rgba",
										@"name": @"Tint",
										@"id": @(kColorTestParameter),
										@"red": @0.1,
										@"green": @0.2,
										@"blue": @0.3,
										@"alpha": @0.4,
										@"flags": @(kFxParameterFlag_DEFAULT)}));
}

- (void)testColorKeepsTheOpaqueAlphaWhenTheDefaultNamesNoAlpha
{
	NSDictionary *extra = @{kFxParameterProperty_Default: @{kFxParameterProperty_Red: @0.5}};

	XCTAssertTrue([self add:FxGripColorParameter.class type:kFxParameterType_RGBA extra:extra]);

	XCTAssertEqualObjects(self.call[@"red"], @0.5);
	XCTAssertEqualObjects(self.call[@"alpha"], @1.0);
}

- (void)testALinearDeclaredColorLosesItsGammaForALinearEffect
{
	self.effect.isLinearColorParameters = YES;
	NSDictionary *color = @{kFxParameterProperty_Red: @0.5,
							kFxParameterProperty_Green: @0.25,
							kFxParameterProperty_Blue: @0.75,
							kFxParameterProperty_ColorSpace: @1};
	NSDictionary *extra = @{kFxParameterProperty_Default: color};

	XCTAssertTrue([self add:FxGripColorParameter.class type:kFxParameterType_RGBA extra:extra]);

	XCTAssertEqualWithAccuracy([self callDouble:@"red"], pow(0.5, 1.0 / kColorTestGamma), 1e-12);
	XCTAssertEqualWithAccuracy([self callDouble:@"green"], pow(0.25, 1.0 / kColorTestGamma), 1e-12);
	XCTAssertEqualWithAccuracy([self callDouble:@"blue"], pow(0.75, 1.0 / kColorTestGamma), 1e-12);
	XCTAssertEqualObjects(self.call[@"alpha"], @1.0, @"alpha is never gamma adjusted");
}

- (void)testAGammaDeclaredColorGainsGammaForAGammaEffect
{
	self.effect.isGammaColorParameters = YES;
	NSDictionary *color = @{kFxParameterProperty_Red: @0.5,
							kFxParameterProperty_ColorSpace: @0};
	NSDictionary *extra = @{kFxParameterProperty_Default: color};

	XCTAssertTrue([self add:FxGripColorParameter.class type:kFxParameterType_RGBA extra:extra]);

	XCTAssertEqualWithAccuracy([self callDouble:@"red"], pow(0.5, kColorTestGamma), 1e-12);
}

- (void)testAColorSpaceThatMatchesTheEffectIsForwardedUnchanged
{
	NSDictionary *color = @{kFxParameterProperty_Red: @0.5,
							kFxParameterProperty_ColorSpace: @1};
	NSDictionary *extra = @{kFxParameterProperty_Default: color};

	XCTAssertTrue([self add:FxGripColorParameter.class type:kFxParameterType_RGBA extra:extra]);

	XCTAssertEqualObjects(self.call[@"red"], @0.5);
}

- (void)testColorReportsAHostRefusal
{
	self.effect.apiManager.paramCreateAPIv5.succeeds = NO;

	XCTAssertFalse([self add:FxGripColorParameter.class type:kFxParameterType_RGBA extra:nil]);
}

#pragma mark Values

- (void)testColorValueAtTimeReadsFourComponentsFromTheRetrievalAPI
{
	FxGripColorParameter *parameter = [self makeColorParameter];
	FxGripParamClassTestRetrievalAPI *retrieval = self.effect.apiManager.paramGetAPIv6;
	retrieval.red = 0.1;
	retrieval.green = 0.2;
	retrieval.blue = 0.3;
	retrieval.alpha = 0.4;

	FxGripColor color = [parameter valueAtTime:FxGripParamClassTestTime(7, 30)];

	XCTAssertEqual(color.red, 0.1);
	XCTAssertEqual(color.green, 0.2);
	XCTAssertEqual(color.blue, 0.3);
	XCTAssertEqual(color.alpha, 0.4);
	XCTAssertEqualObjects(retrieval.lastRead[@"accessor"], @"rgba");
	XCTAssertEqualObjects(retrieval.lastRead[@"id"], @(kColorTestParameter));
	XCTAssertEqualObjects(retrieval.lastRead[@"timevalue"], @7);
}

- (void)testColorSetValueWritesEveryComponent
{
	FxGripColorParameter *parameter = [self makeColorParameter];
	FxGripColor color = { .red = 0.1, .green = 0.2, .blue = 0.3, .alpha = 0.4 };

	[parameter setValue:&color atTime:FxGripParamClassTestTime(0, 1)];

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.lastWrite,
						  (@{@"accessor": @"rgba",
							 @"id": @(kColorTestParameter),
							 @"red": @0.1,
							 @"green": @0.2,
							 @"blue": @0.3,
							 @"alpha": @0.4}));
}

- (void)testColorSetValueIgnoresANullColor
{
	FxGripColorParameter *parameter = [self makeColorParameter];

	[parameter setValue:NULL atTime:FxGripParamClassTestTime(0, 1)];

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.writes, @[]);
}

/*! The three-component write reads the current alpha back before writing all four. */
- (void)testColorWritingOnlyRGBPreservesTheStoredAlpha
{
	FxGripColorParameter *parameter = [self makeColorParameter];
	self.effect.apiManager.paramGetAPIv6.alpha = 0.25;

	[parameter setRedValue:0.6 greenValue:0.7 blueValue:0.8 atTime:FxGripParamClassTestTime(0, 1)];

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.lastWrite[@"alpha"], @0.25);
	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.lastWrite[@"red"], @0.6);
}

- (void)testColorWritingOnlyRGBIsAbandonedWhenTheAlphaReadFails
{
	FxGripColorParameter *parameter = [self makeColorParameter];
	self.effect.apiManager.paramGetAPIv6.succeeds = NO;

	[parameter setRedValue:0.6 greenValue:0.7 blueValue:0.8 atTime:FxGripParamClassTestTime(0, 1)];

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.writes, @[]);
}

- (void)testDontRemapColorsReadsAndWritesItsFlagBit
{
	FxGripColorParameter *parameter = [self makeColorParameter];
	self.effect.apiManager.paramGetAPIv6.flags = kFxParameterFlag_DONT_REMAP_COLORS;

	XCTAssertTrue(parameter.flagDontRemapColors);

	self.effect.apiManager.paramGetAPIv6.flags = kFxParameterFlag_DEFAULT;
	XCTAssertFalse(parameter.flagDontRemapColors);

	parameter.flagDontRemapColors = YES;
	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.setFlagsCalls.firstObject[@"flags"],
						  @(kFxParameterFlag_DONT_REMAP_COLORS));
}

@end
