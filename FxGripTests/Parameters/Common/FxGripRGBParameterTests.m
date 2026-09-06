/*!
	@file       FxGripRGBParameterTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripRGBParameterTests
	@abstract   Tests FxGripRGBParameter (RGB plus its separate alpha parameter): its FxPlug type
	            identity and the three-component payload +addParameter:toEffect: derives.
	@discussion Introduced in FxGrip 0.1.0. The tests confirm the color-space gamma conversion,
	            the value plumbing through the retrieval and setting APIs, and the companion
	            alpha-parameter validation.
*/

#import <XCTest/XCTest.h>
#import "FxGripParameterClassTestSupport.h"
#import <FxGrip/FxGripRGBParameter.h>
#import <FxGrip/FxGripFloatParameter.h>
#import <FxGrip/FxGripStringParameter.h>

// -setRGBAValue:atTime: is implemented but absent from the public header.
@interface FxGripRGBParameter (FxGripRGBParameterTests)
- (void)setRGBAValue:(FxGripColor *_Nullable)color atTime:(CMTime)time;
@end

static const FxParameterId kRGBTestParameter = 31;
static const FxParameterId kRGBTestAlphaParameter = 32;
static const double kRGBTestGamma = 2.2;

@interface FxGripRGBParameterTests : XCTestCase
@property (nonatomic, strong) FxGripParamClassTestEffect *effect;
@end

@implementation FxGripRGBParameterTests

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
	NSDictionary *config = FxGripParamClassTestConfig(kRGBTestParameter, type, @"Tint", extra);
	return [parameterClass addParameter:config toEffect:(id)self.effect];
}

- (double)callDouble:(NSString *)key
{
	return ((NSNumber *)self.call[key]).doubleValue;
}

- (FxGripRGBParameter *)makeRGBParameter
{
	NSDictionary *config = FxGripParamClassTestConfig(kRGBTestParameter, kFxParameterType_RGB, @"Tint", nil);
	return [FxGripRGBParameter.alloc initWithDictionary:config effect:(id)self.effect];
}

- (id)makeFloatParameterWithID:(FxParameterId)parameterID
{
	NSDictionary *config = FxGripParamClassTestConfig(parameterID, kFxParameterType_Float, @"Opacity", nil);
	return [FxGripFloatParameter.alloc initWithDictionary:config effect:(id)self.effect];
}

#pragma mark Type identity

/*! @abstract The class reports the FxPlug RGB type and its type string. */
- (void)testReportsItsFxPlugTypeAndTypeString
{
	XCTAssertEqual(FxGripRGBParameter.parameterType, FxParameterType_RGB);
	XCTAssertEqualObjects(FxGripRGBParameter.parameterTypeString, kFxParameterType_RGB);
}

#pragma mark Creation

/*! @abstract An RGB color created with no default sends black to the creation call. */
- (void)testRGBWithoutADefaultIsBlack
{
	XCTAssertTrue([self add:FxGripRGBParameter.class type:kFxParameterType_RGB extra:nil]);

	XCTAssertEqualObjects(self.call, (@{@"method": @"rgb",
										@"name": @"Tint",
										@"id": @(kRGBTestParameter),
										@"red": @0.0,
										@"green": @0.0,
										@"blue": @0.0,
										@"flags": @(kFxParameterFlag_DEFAULT)}));
}

/*! @abstract An RGB color forwards the three components and omits alpha, which the creation method does not take. */
- (void)testRGBForwardsThreeComponentsAndNoAlpha
{
	NSDictionary *color = @{kFxParameterProperty_Red: @0.1,
							kFxParameterProperty_Green: @0.2,
							kFxParameterProperty_Blue: @0.3,
							kFxParameterProperty_Alpha: @0.4};
	NSDictionary *extra = @{kFxParameterProperty_Default: color};

	XCTAssertTrue([self add:FxGripRGBParameter.class type:kFxParameterType_RGB extra:extra]);

	XCTAssertEqualObjects(self.call[@"method"], @"rgb");
	XCTAssertEqualObjects(self.call[@"red"], @0.1);
	XCTAssertNil(self.call[@"alpha"], @"the three-component creation method takes no alpha");
}

/*! @abstract An RGB color applies the same color-space gamma conversion as the RGBA parameter. */
- (void)testRGBAppliesTheSameGammaConversionAsRGBA
{
	self.effect.isLinearColorParameters = YES;
	NSDictionary *color = @{kFxParameterProperty_Green: @0.25,
							kFxParameterProperty_ColorSpace: @1};
	NSDictionary *extra = @{kFxParameterProperty_Default: color};

	XCTAssertTrue([self add:FxGripRGBParameter.class type:kFxParameterType_RGB extra:extra]);

	XCTAssertEqualWithAccuracy([self callDouble:@"green"], pow(0.25, 1.0 / kRGBTestGamma), 1e-12);
}

/*! @abstract When the host creation API refuses, +addParameter:toEffect: returns false. */
- (void)testRGBReportsAHostRefusal
{
	self.effect.apiManager.paramCreateAPIv5.succeeds = NO;

	XCTAssertFalse([self add:FxGripRGBParameter.class type:kFxParameterType_RGB extra:nil]);
}

#pragma mark Values and validation

/*! @abstract The alpha property is a plain stored component. */
- (void)testRGBAlphaIsAPlainStoredComponent
{
	FxGripRGBParameter *parameter = [self makeRGBParameter];

	parameter.alpha = 0.35;

	XCTAssertEqual(parameter.alpha, 0.35);
}

/*! @abstract -valueAtTime: reads the three color components and returns the stored alpha unchanged. */
- (void)testRGBValueAtTimeReadsThreeComponentsAndLeavesAlphaAlone
{
	FxGripRGBParameter *parameter = [self makeRGBParameter];
	FxGripParamClassTestRetrievalAPI *retrieval = self.effect.apiManager.paramGetAPIv6;
	retrieval.red = 0.1;
	retrieval.green = 0.2;
	retrieval.blue = 0.3;
	parameter.alpha = 0.9;

	FxGripColor color = [parameter valueAtTime:FxGripParamClassTestTime(3, 30)];

	XCTAssertEqual(color.red, 0.1);
	XCTAssertEqual(color.alpha, 0.9);
	XCTAssertEqualObjects(retrieval.lastRead[@"accessor"], @"rgb");
}

/*! @abstract -valueAtTime: reads the alpha from the companion float parameter when one is set. */
- (void)testRGBValueAtTimeReadsTheAlphaFromTheCompanionParameter
{
	FxGripRGBParameter *parameter = [self makeRGBParameter];
	parameter.alphaParameter = kRGBTestAlphaParameter;
	FxGripParamClassTestRetrievalAPI *retrieval = self.effect.apiManager.paramGetAPIv6;
	retrieval.floatValue = 0.45;

	FxGripColor color = [parameter valueAtTime:FxGripParamClassTestTime(0, 1)];

	XCTAssertEqual(color.alpha, 0.45);
	XCTAssertEqualObjects(retrieval.reads.firstObject[@"accessor"], @"float");
	XCTAssertEqualObjects(retrieval.reads.firstObject[@"id"], @(kRGBTestAlphaParameter));
}

/*! @abstract -setValue:atTime: writes only the three color components. */
- (void)testRGBSetValueWritesOnlyTheThreeComponents
{
	FxGripRGBParameter *parameter = [self makeRGBParameter];
	FxGripColor color = { .red = 0.1, .green = 0.2, .blue = 0.3, .alpha = 0.4 };

	[parameter setValue:&color atTime:FxGripParamClassTestTime(0, 1)];

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.lastWrite,
						  (@{@"accessor": @"rgb",
							 @"id": @(kRGBTestParameter),
							 @"red": @0.1,
							 @"green": @0.2,
							 @"blue": @0.3}));
}

/*! @abstract -setRGBAValue:atTime: stores the alpha and writes the three color components. */
- (void)testRGBSetRGBAValueStoresTheAlphaAndWritesTheComponents
{
	FxGripRGBParameter *parameter = [self makeRGBParameter];
	FxGripColor color = { .red = 0.1, .green = 0.2, .blue = 0.3, .alpha = 0.4 };

	[parameter setRGBAValue:&color atTime:FxGripParamClassTestTime(0, 1)];

	XCTAssertEqual(parameter.alpha, 0.4);
	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.lastWrite[@"accessor"], @"rgb");
}

/*! @abstract An RGB parameter with no companion alpha parameter validates. */
- (void)testRGBValidatesWithoutACompanionAlphaParameter
{
	XCTAssertTrue([self makeRGBParameter].validate);
}

/*! @abstract Validation fails when the named companion alpha parameter is absent from the effect. */
- (void)testRGBRejectsACompanionAlphaParameterTheEffectDoesNotHave
{
	FxGripRGBParameter *parameter = [self makeRGBParameter];
	parameter.alphaParameter = kRGBTestAlphaParameter;

	XCTAssertFalse(parameter.validate);
}

/*! @abstract Validation passes when the companion alpha parameter is a float parameter on the effect. */
- (void)testRGBAcceptsAFloatCompanionAlphaParameter
{
	FxGripRGBParameter *parameter = [self makeRGBParameter];
	parameter.alphaParameter = kRGBTestAlphaParameter;
	self.effect.parameters[@(kRGBTestAlphaParameter)] = [self makeFloatParameterWithID:kRGBTestAlphaParameter];

	XCTAssertTrue(parameter.validate);
}

/*! @abstract Validation fails when the companion alpha parameter is of the wrong type. */
- (void)testRGBRejectsACompanionAlphaParameterOfTheWrongType
{
	FxGripRGBParameter *parameter = [self makeRGBParameter];
	parameter.alphaParameter = kRGBTestAlphaParameter;
	NSDictionary *config = FxGripParamClassTestConfig(kRGBTestAlphaParameter, kFxParameterType_String, @"Label", nil);
	self.effect.parameters[@(kRGBTestAlphaParameter)] =
		[FxGripStringParameter.alloc initWithDictionary:config effect:(id)self.effect];

	XCTAssertFalse(parameter.validate);
}

@end
