/*!
	@file       FxGripColorParameterTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripColorParameterTests
	@abstract   Tests FxGripColorParameter (RGBA): its FxPlug type identity and the creation
	            payload +addParameter:toEffect: derives from a nested default record.
	@discussion Introduced in FxGrip 0.1.0. The tests confirm the opaque-black default, the
	            per-component forwarding, the color-space gamma conversion, and the value
	            plumbing through the retrieval and setting APIs.
*/

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

/*! @abstract The class reports the FxPlug RGBA type and its type string. */
- (void)testReportsItsFxPlugTypeAndTypeString
{
	XCTAssertEqual(FxGripColorParameter.parameterType, FxParameterType_RGBA);
	XCTAssertEqualObjects(FxGripColorParameter.parameterTypeString, kFxParameterType_RGBA);
}

#pragma mark Creation

/*! @abstract A color created with no default sends opaque black to the creation call. */
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

/*! @abstract A color forwards the red, green, blue, and alpha of its nested default record. */
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

/*! @abstract A default naming no alpha keeps the opaque alpha of one. */
- (void)testColorKeepsTheOpaqueAlphaWhenTheDefaultNamesNoAlpha
{
	NSDictionary *extra = @{kFxParameterProperty_Default: @{kFxParameterProperty_Red: @0.5}};

	XCTAssertTrue([self add:FxGripColorParameter.class type:kFxParameterType_RGBA extra:extra]);

	XCTAssertEqualObjects(self.call[@"red"], @0.5);
	XCTAssertEqualObjects(self.call[@"alpha"], @1.0);
}

/*! @abstract A gamma-encoded declared color is linearized for a linear effect, and alpha is left unchanged. */
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

/*! @abstract A linear declared color gains gamma encoding for a gamma effect. */
- (void)testAGammaDeclaredColorGainsGammaForAGammaEffect
{
	self.effect.isGammaColorParameters = YES;
	NSDictionary *color = @{kFxParameterProperty_Red: @0.5,
							kFxParameterProperty_ColorSpace: @0};
	NSDictionary *extra = @{kFxParameterProperty_Default: color};

	XCTAssertTrue([self add:FxGripColorParameter.class type:kFxParameterType_RGBA extra:extra]);

	XCTAssertEqualWithAccuracy([self callDouble:@"red"], pow(0.5, kColorTestGamma), 1e-12);
}

/*! @abstract A declared color whose color space matches the effect is forwarded without conversion. */
- (void)testAColorSpaceThatMatchesTheEffectIsForwardedUnchanged
{
	NSDictionary *color = @{kFxParameterProperty_Red: @0.5,
							kFxParameterProperty_ColorSpace: @1};
	NSDictionary *extra = @{kFxParameterProperty_Default: color};

	XCTAssertTrue([self add:FxGripColorParameter.class type:kFxParameterType_RGBA extra:extra]);

	XCTAssertEqualObjects(self.call[@"red"], @0.5);
}

/*! @abstract When the host creation API refuses, +addParameter:toEffect: returns false. */
- (void)testColorReportsAHostRefusal
{
	self.effect.apiManager.paramCreateAPIv5.succeeds = NO;

	XCTAssertFalse([self add:FxGripColorParameter.class type:kFxParameterType_RGBA extra:nil]);
}

#pragma mark Values

/*! @abstract -valueAtTime: reads all four color components and the render time from the retrieval API. */
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

/*! @abstract -setValue:atTime: writes every color component through the setting API. */
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

/*! @abstract -setValue:atTime: writes nothing when the color pointer is NULL. */
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

/*! @abstract The three-component write is abandoned with no write when the alpha read-back fails. */
- (void)testColorWritingOnlyRGBIsAbandonedWhenTheAlphaReadFails
{
	FxGripColorParameter *parameter = [self makeColorParameter];
	self.effect.apiManager.paramGetAPIv6.succeeds = NO;

	[parameter setRedValue:0.6 greenValue:0.7 blueValue:0.8 atTime:FxGripParamClassTestTime(0, 1)];

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.writes, @[]);
}

/*! @abstract The flagDontRemapColors accessor reads and writes the DONT_REMAP_COLORS flag bit. */
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
