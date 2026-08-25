//
//  FxGripColorParameterTests.m
//  FxGripTests
//
//  Unit tests for the geometry and color parameter classes: FxGripColorParameter (RGBA),
//  FxGripRGBParameter (RGB plus its separate alpha parameter), and FxGripPointParameter.
//  Coverage spans the type identity, the payload +addParameter:toEffect: derives from the
//  nested default record, the color-space gamma conversion, the value plumbing through the
//  retrieval and setting APIs, and the RGB alpha-parameter validation.
//

#import <XCTest/XCTest.h>
#import "FxGripParameterClassTestSupport.h"
#import <FxGrip/FxGripColorParameter.h>
#import <FxGrip/FxGripRGBParameter.h>
#import <FxGrip/FxGripPointParameter.h>
#import <FxGrip/FxGripFloatParameter.h>
#import <FxGrip/FxGripStringParameter.h>

// -setRGBAValue:atTime: is implemented but absent from the public header.
@interface FxGripRGBParameter (FxGripColorParameterTests)
- (void)setRGBAValue:(FxGripColor *_Nullable)color atTime:(CMTime)time;
@end

static const FxParameterId kColorTestParameter = 31;
static const FxParameterId kColorTestAlphaParameter = 32;
static const double kColorTestGamma = 2.2;

@interface FxGripColorParameterTests : XCTestCase
@property (nonatomic, strong) FxParamClassTestEffect *effect;
@end

@implementation FxGripColorParameterTests

- (void)setUp
{
	[super setUp];
	self.effect = [FxParamClassTestEffect.alloc init];
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
	NSDictionary *config = FxParamClassTestConfig(kColorTestParameter, type, @"Tint", extra);
	return [parameterClass addParameter:config toEffect:(id)self.effect];
}

- (double)callDouble:(NSString *)key
{
	return ((NSNumber *)self.call[key]).doubleValue;
}

#pragma mark Type identity

- (void)testEachColorClassReportsItsFxPlugTypeAndTypeString
{
	XCTAssertEqual(FxGripColorParameter.parameterType, FxParameterType_RGBA);
	XCTAssertEqualObjects(FxGripColorParameter.parameterTypeString, kFxParameterType_RGBA);

	XCTAssertEqual(FxGripRGBParameter.parameterType, FxParameterType_RGB);
	XCTAssertEqualObjects(FxGripRGBParameter.parameterTypeString, kFxParameterType_RGB);

	XCTAssertEqual(FxGripPointParameter.parameterType, FxParameterType_Point);
	XCTAssertEqualObjects(FxGripPointParameter.parameterTypeString, kFxParameterType_Point);
}

#pragma mark RGBA creation

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

#pragma mark RGBA values

- (FxGripColorParameter *)makeColorParameter
{
	NSDictionary *config = FxParamClassTestConfig(kColorTestParameter, kFxParameterType_RGBA, @"Tint", nil);
	return [FxGripColorParameter.alloc initWithDictionary:config effect:(id)self.effect];
}

- (void)testColorValueAtTimeReadsFourComponentsFromTheRetrievalAPI
{
	FxGripColorParameter *parameter = [self makeColorParameter];
	FxParamClassTestRetrievalAPI *retrieval = self.effect.apiManager.paramGetAPIv6;
	retrieval.red = 0.1;
	retrieval.green = 0.2;
	retrieval.blue = 0.3;
	retrieval.alpha = 0.4;

	FxGripColor color = [parameter valueAtTime:FxParamClassTestTime(7, 30)];

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

	[parameter setValue:&color atTime:FxParamClassTestTime(0, 1)];

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

	[parameter setValue:NULL atTime:FxParamClassTestTime(0, 1)];

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.writes, @[]);
}

/*! The three-component write reads the current alpha back before writing all four. */
- (void)testColorWritingOnlyRGBPreservesTheStoredAlpha
{
	FxGripColorParameter *parameter = [self makeColorParameter];
	self.effect.apiManager.paramGetAPIv6.alpha = 0.25;

	[parameter setRedValue:0.6 greenValue:0.7 blueValue:0.8 atTime:FxParamClassTestTime(0, 1)];

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.lastWrite[@"alpha"], @0.25);
	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.lastWrite[@"red"], @0.6);
}

- (void)testColorWritingOnlyRGBIsAbandonedWhenTheAlphaReadFails
{
	FxGripColorParameter *parameter = [self makeColorParameter];
	self.effect.apiManager.paramGetAPIv6.succeeds = NO;

	[parameter setRedValue:0.6 greenValue:0.7 blueValue:0.8 atTime:FxParamClassTestTime(0, 1)];

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

#pragma mark RGB creation

- (void)testRGBWithoutADefaultIsBlack
{
	XCTAssertTrue([self add:FxGripRGBParameter.class type:kFxParameterType_RGB extra:nil]);

	XCTAssertEqualObjects(self.call, (@{@"method": @"rgb",
										@"name": @"Tint",
										@"id": @(kColorTestParameter),
										@"red": @0.0,
										@"green": @0.0,
										@"blue": @0.0,
										@"flags": @(kFxParameterFlag_DEFAULT)}));
}

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

- (void)testRGBAppliesTheSameGammaConversionAsRGBA
{
	self.effect.isLinearColorParameters = YES;
	NSDictionary *color = @{kFxParameterProperty_Green: @0.25,
							kFxParameterProperty_ColorSpace: @1};
	NSDictionary *extra = @{kFxParameterProperty_Default: color};

	XCTAssertTrue([self add:FxGripRGBParameter.class type:kFxParameterType_RGB extra:extra]);

	XCTAssertEqualWithAccuracy([self callDouble:@"green"], pow(0.25, 1.0 / kColorTestGamma), 1e-12);
}

- (void)testRGBReportsAHostRefusal
{
	self.effect.apiManager.paramCreateAPIv5.succeeds = NO;

	XCTAssertFalse([self add:FxGripRGBParameter.class type:kFxParameterType_RGB extra:nil]);
}

#pragma mark RGB values and validation

- (FxGripRGBParameter *)makeRGBParameter
{
	NSDictionary *config = FxParamClassTestConfig(kColorTestParameter, kFxParameterType_RGB, @"Tint", nil);
	return [FxGripRGBParameter.alloc initWithDictionary:config effect:(id)self.effect];
}

- (id)makeFloatParameterWithID:(FxParameterId)parameterID
{
	NSDictionary *config = FxParamClassTestConfig(parameterID, kFxParameterType_Float, @"Opacity", nil);
	return [FxGripFloatParameter.alloc initWithDictionary:config effect:(id)self.effect];
}

- (void)testRGBAlphaIsAPlainStoredComponent
{
	FxGripRGBParameter *parameter = [self makeRGBParameter];

	parameter.alpha = 0.35;

	XCTAssertEqual(parameter.alpha, 0.35);
}

- (void)testRGBValueAtTimeReadsThreeComponentsAndLeavesAlphaAlone
{
	FxGripRGBParameter *parameter = [self makeRGBParameter];
	FxParamClassTestRetrievalAPI *retrieval = self.effect.apiManager.paramGetAPIv6;
	retrieval.red = 0.1;
	retrieval.green = 0.2;
	retrieval.blue = 0.3;
	parameter.alpha = 0.9;

	FxGripColor color = [parameter valueAtTime:FxParamClassTestTime(3, 30)];

	XCTAssertEqual(color.red, 0.1);
	XCTAssertEqual(color.alpha, 0.9);
	XCTAssertEqualObjects(retrieval.lastRead[@"accessor"], @"rgb");
}

- (void)testRGBValueAtTimeReadsTheAlphaFromTheCompanionParameter
{
	FxGripRGBParameter *parameter = [self makeRGBParameter];
	parameter.alphaParameter = kColorTestAlphaParameter;
	FxParamClassTestRetrievalAPI *retrieval = self.effect.apiManager.paramGetAPIv6;
	retrieval.floatValue = 0.45;

	FxGripColor color = [parameter valueAtTime:FxParamClassTestTime(0, 1)];

	XCTAssertEqual(color.alpha, 0.45);
	XCTAssertEqualObjects(retrieval.reads.firstObject[@"accessor"], @"float");
	XCTAssertEqualObjects(retrieval.reads.firstObject[@"id"], @(kColorTestAlphaParameter));
}

- (void)testRGBSetValueWritesOnlyTheThreeComponents
{
	FxGripRGBParameter *parameter = [self makeRGBParameter];
	FxGripColor color = { .red = 0.1, .green = 0.2, .blue = 0.3, .alpha = 0.4 };

	[parameter setValue:&color atTime:FxParamClassTestTime(0, 1)];

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.lastWrite,
						  (@{@"accessor": @"rgb",
							 @"id": @(kColorTestParameter),
							 @"red": @0.1,
							 @"green": @0.2,
							 @"blue": @0.3}));
}

- (void)testRGBSetRGBAValueStoresTheAlphaAndWritesTheComponents
{
	FxGripRGBParameter *parameter = [self makeRGBParameter];
	FxGripColor color = { .red = 0.1, .green = 0.2, .blue = 0.3, .alpha = 0.4 };

	[parameter setRGBAValue:&color atTime:FxParamClassTestTime(0, 1)];

	XCTAssertEqual(parameter.alpha, 0.4);
	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.lastWrite[@"accessor"], @"rgb");
}

- (void)testRGBValidatesWithoutACompanionAlphaParameter
{
	XCTAssertTrue([self makeRGBParameter].validate);
}

- (void)testRGBRejectsACompanionAlphaParameterTheEffectDoesNotHave
{
	FxGripRGBParameter *parameter = [self makeRGBParameter];
	parameter.alphaParameter = kColorTestAlphaParameter;

	XCTAssertFalse(parameter.validate);
}

- (void)testRGBAcceptsAFloatCompanionAlphaParameter
{
	FxGripRGBParameter *parameter = [self makeRGBParameter];
	parameter.alphaParameter = kColorTestAlphaParameter;
	self.effect.parameters[@(kColorTestAlphaParameter)] = [self makeFloatParameterWithID:kColorTestAlphaParameter];

	XCTAssertTrue(parameter.validate);
}

- (void)testRGBRejectsACompanionAlphaParameterOfTheWrongType
{
	FxGripRGBParameter *parameter = [self makeRGBParameter];
	parameter.alphaParameter = kColorTestAlphaParameter;
	NSDictionary *config = FxParamClassTestConfig(kColorTestAlphaParameter, kFxParameterType_String, @"Label", nil);
	self.effect.parameters[@(kColorTestAlphaParameter)] =
		[FxGripStringParameter.alloc initWithDictionary:config effect:(id)self.effect];

	XCTAssertFalse(parameter.validate);
}

#pragma mark Point

- (void)testPointWithoutADefaultCentersTheParameter
{
	XCTAssertTrue([self add:FxGripPointParameter.class type:kFxParameterType_Point extra:nil]);

	XCTAssertEqualObjects(self.call, (@{@"method": @"point",
										@"name": @"Tint",
										@"id": @(kColorTestParameter),
										@"x": @0.5,
										@"y": @0.5,
										@"flags": @(kFxParameterFlag_DEFAULT)}));
}

- (void)testPointForwardsBothCoordinatesOfTheNestedDefault
{
	NSDictionary *point = @{kFxParameterProperty_X: @0.25, kFxParameterProperty_Y: @0.75};
	NSDictionary *extra = @{kFxParameterProperty_Default: point};

	XCTAssertTrue([self add:FxGripPointParameter.class type:kFxParameterType_Point extra:extra]);

	XCTAssertEqualObjects(self.call[@"x"], @0.25);
	XCTAssertEqualObjects(self.call[@"y"], @0.75);
}

/*!
	A nested default record answers zero for the coordinate it omits, so declaring one
	coordinate moves the other to the origin rather than leaving it centered.
*/
- (void)testAHalfDeclaredPointDefaultZeroesTheUndeclaredCoordinate
{
	NSDictionary *extra = @{kFxParameterProperty_Default: @{kFxParameterProperty_X: @0.25}};

	XCTAssertTrue([self add:FxGripPointParameter.class type:kFxParameterType_Point extra:extra]);

	XCTAssertEqualObjects(self.call[@"x"], @0.25);
	XCTAssertEqualObjects(self.call[@"y"], @0.0);
}

- (void)testTopLevelCoordinateKeysSupplyTheDefault
{
	NSDictionary *extra = @{kFxParameterProperty_X: @0.25, kFxParameterProperty_Y: @0.75};

	XCTAssertTrue([self add:FxGripPointParameter.class type:kFxParameterType_Point extra:extra]);

	XCTAssertEqualObjects(self.call[@"x"], @0.25);
	XCTAssertEqualObjects(self.call[@"y"], @0.75);
}

/*! A lone declared coordinate is honored; the undeclared one reads as zero. */
- (void)testATopLevelYWithoutAnXSuppliesTheYDefault
{
	NSDictionary *extra = @{kFxParameterProperty_Y: @0.75};

	XCTAssertTrue([self add:FxGripPointParameter.class type:kFxParameterType_Point extra:extra]);

	XCTAssertEqualObjects(self.call[@"x"], @0);
	XCTAssertEqualObjects(self.call[@"y"], @0.75);
}

- (void)testAnArrayPointDefaultIsReadInOrder
{
	NSDictionary *extra = @{kFxParameterProperty_Default: @[@0.25, @0.75]};

	XCTAssertTrue([self add:FxGripPointParameter.class type:kFxParameterType_Point extra:extra]);

	XCTAssertEqualObjects(self.call[@"x"], @0.25);
	XCTAssertEqualObjects(self.call[@"y"], @0.75);
}

/*! A whitespace separated string default names the coordinates in the same order. */
- (void)testAStringPointDefaultIsSplitIntoCoordinates
{
	NSDictionary *extra = @{kFxParameterProperty_Default: @"0.25 0.75"};

	XCTAssertTrue([self add:FxGripPointParameter.class type:kFxParameterType_Point extra:extra]);

	XCTAssertEqualObjects(self.call[@"x"], @0.25);
	XCTAssertEqualObjects(self.call[@"y"], @0.75);
}

- (void)testPointReportsAHostRefusal
{
	self.effect.apiManager.paramCreateAPIv5.succeeds = NO;

	XCTAssertFalse([self add:FxGripPointParameter.class type:kFxParameterType_Point extra:nil]);
}

#pragma mark Point values

- (FxGripPointParameter *)makePointParameter
{
	NSDictionary *config = FxParamClassTestConfig(kColorTestParameter, kFxParameterType_Point, @"Center", nil);
	return [FxGripPointParameter.alloc initWithDictionary:config effect:(id)self.effect];
}

- (void)testPointValueAtTimeReadsBothCoordinates
{
	FxGripPointParameter *parameter = [self makePointParameter];
	self.effect.apiManager.paramGetAPIv6.x = 0.3;
	self.effect.apiManager.paramGetAPIv6.y = 0.6;

	FxGripPoint point = [parameter valueAtTime:FxParamClassTestTime(5, 30)];

	XCTAssertEqual(point.x, 0.3);
	XCTAssertEqual(point.y, 0.6);
	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.lastRead[@"accessor"], @"point");
}

- (void)testPointValueAtTimeIsTheOriginWhenTheReadFails
{
	FxGripPointParameter *parameter = [self makePointParameter];
	self.effect.apiManager.paramGetAPIv6.succeeds = NO;
	self.effect.apiManager.paramGetAPIv6.x = 0.3;

	FxGripPoint point = [parameter valueAtTime:FxParamClassTestTime(0, 1)];

	XCTAssertEqual(point.x, 0.0);
	XCTAssertEqual(point.y, 0.0);
}

- (void)testPointSetValueWritesBothCoordinates
{
	FxGripPointParameter *parameter = [self makePointParameter];
	FxGripPoint point = { .x = 0.2, .y = 0.8 };

	[parameter setValue:&point atTime:FxParamClassTestTime(0, 1)];

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.lastWrite,
						  (@{@"accessor": @"point",
							 @"id": @(kColorTestParameter),
							 @"x": @0.2,
							 @"y": @0.8}));
}

- (void)testPointSetValueIgnoresANullPoint
{
	FxGripPointParameter *parameter = [self makePointParameter];

	[parameter setValue:NULL atTime:FxParamClassTestTime(0, 1)];

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.writes, @[]);
}

- (void)testPointSetXValueYValueWritesTheCoordinatesDirectly
{
	FxGripPointParameter *parameter = [self makePointParameter];

	[parameter setXValue:0.4 YValue:0.9 atTime:FxParamClassTestTime(0, 1)];

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.lastWrite[@"x"], @0.4);
	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.lastWrite[@"y"], @0.9);
}

@end
