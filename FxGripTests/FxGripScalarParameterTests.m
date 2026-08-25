//
//  FxGripScalarParameterTests.m
//  FxGripTests
//
//  Unit tests for the numeric slider parameter classes: FxGripFloatParameter,
//  FxGripPercentParameter, FxGripIntParameter, and FxGripAngleParameter. Each covers the
//  type identity, the creation-API method and payload +addParameter:toEffect: derives from
//  a configuration, the defaults applied when the configuration omits a bound, the delta
//  fallback, the host-refusal result, and the flag accessors an instance exposes.
//

#import <XCTest/XCTest.h>
#import "FxGripParameterClassTestSupport.h"
#import <FxGrip/FxGripFloatParameter.h>
#import <FxGrip/FxGripPercentParameter.h>
#import <FxGrip/FxGripIntParameter.h>
#import <FxGrip/FxGripAngleParameter.h>

static const FxParameterId kScalarTestParameter = 21;

@interface FxGripScalarParameterTests : XCTestCase
@property (nonatomic, strong) FxParamClassTestEffect *effect;
@end

@implementation FxGripScalarParameterTests

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
	NSDictionary *config = FxParamClassTestConfig(kScalarTestParameter, type, @"Amount", extra);
	return [parameterClass addParameter:config toEffect:(id)self.effect];
}

#pragma mark Type identity

- (void)testEachSliderClassReportsItsFxPlugTypeAndTypeString
{
	XCTAssertEqual(FxGripFloatParameter.parameterType, FxParameterType_Float);
	XCTAssertEqualObjects(FxGripFloatParameter.parameterTypeString, kFxParameterType_Float);

	XCTAssertEqual(FxGripPercentParameter.parameterType, FxParameterType_Percent);
	XCTAssertEqualObjects(FxGripPercentParameter.parameterTypeString, kFxParameterType_Percent);

	XCTAssertEqual(FxGripIntParameter.parameterType, FxParameterType_Int);
	XCTAssertEqualObjects(FxGripIntParameter.parameterTypeString, kFxParameterType_Integer);

	XCTAssertEqual(FxGripAngleParameter.parameterType, FxParameterType_Angle);
	XCTAssertEqualObjects(FxGripAngleParameter.parameterTypeString, kFxParameterType_Angle);
}

- (void)testAnInstanceReportsTheClassTypeThroughTheInstanceAccessor
{
	NSDictionary *config = FxParamClassTestConfig(kScalarTestParameter, kFxParameterType_Float, @"Amount", nil);
	FxGripFloatParameter *parameter = [FxGripFloatParameter.alloc initWithDictionary:config
																			  effect:(id)self.effect];

	XCTAssertNotNil(parameter);
	XCTAssertEqual(parameter.parameterType, FxParameterType_Float);
}

#pragma mark Float

- (void)testFloatWithoutBoundsUsesZeroToOneAndTheHundredthDelta
{
	XCTAssertTrue([self add:FxGripFloatParameter.class type:kFxParameterType_Float extra:nil]);

	XCTAssertEqualObjects(self.call, (@{@"method": @"float",
										@"name": @"Amount",
										@"id": @(kScalarTestParameter),
										@"default": @0.0,
										@"min": @0.0,
										@"max": @1.0,
										@"slidermin": @0.0,
										@"slidermax": @1.0,
										@"delta": @0.01,
										@"flags": @(kFxParameterFlag_DEFAULT)}));
}

- (void)testFloatForwardsEveryDeclaredBoundAndTheDeclaredDelta
{
	NSDictionary *extra = @{kFxParameterProperty_Default: @0.5,
							kFxParameterProperty_Minimum: @(-2.0),
							kFxParameterProperty_Maximum: @3.0,
							kFxParameterProperty_SliderMinimum: @(-1.0),
							kFxParameterProperty_SliderMaximum: @2.0,
							kFxParameterProperty_Delta: @0.25};

	XCTAssertTrue([self add:FxGripFloatParameter.class type:kFxParameterType_Float extra:extra]);

	XCTAssertEqualObjects(self.call, (@{@"method": @"float",
										@"name": @"Amount",
										@"id": @(kScalarTestParameter),
										@"default": @0.5,
										@"min": @(-2.0),
										@"max": @3.0,
										@"slidermin": @(-1.0),
										@"slidermax": @2.0,
										@"delta": @0.25,
										@"flags": @(kFxParameterFlag_DEFAULT)}));
}

- (void)testFloatSliderBoundsFallBackToTheParameterBounds
{
	NSDictionary *extra = @{kFxParameterProperty_Minimum: @(-5.0),
							kFxParameterProperty_Maximum: @5.0};

	XCTAssertTrue([self add:FxGripFloatParameter.class type:kFxParameterType_Float extra:extra]);

	XCTAssertEqualObjects(self.call[@"slidermin"], @(-5.0));
	XCTAssertEqualObjects(self.call[@"slidermax"], @5.0);
}

- (void)testFloatDeltaFallsBackToOneWhenTheRangeIsNotUnit
{
	NSDictionary *extra = @{kFxParameterProperty_Minimum: @0.0,
							kFxParameterProperty_Maximum: @10.0};

	XCTAssertTrue([self add:FxGripFloatParameter.class type:kFxParameterType_Float extra:extra]);

	XCTAssertEqualObjects(self.call[@"delta"], @1.0);
}

- (void)testFloatDeltaFallsBackToAHundredthForAnyUnitWideRange
{
	NSDictionary *extra = @{kFxParameterProperty_Minimum: @(-3.0),
							kFxParameterProperty_Maximum: @(-2.0)};

	XCTAssertTrue([self add:FxGripFloatParameter.class type:kFxParameterType_Float extra:extra]);

	XCTAssertEqualObjects(self.call[@"delta"], @0.01);
}

- (void)testFloatCarriesTheConfiguredFlagsThrough
{
	NSArray *flags = @[kParameterFlagString_HIDDEN, kParameterFlagString_DISABLED];
	NSDictionary *extra = @{kFxParameterProperty_Flags: flags};

	XCTAssertTrue([self add:FxGripFloatParameter.class type:kFxParameterType_Float extra:extra]);

	XCTAssertEqualObjects(self.call[@"flags"],
						  @(kFxParameterFlag_HIDDEN | kFxParameterFlag_DISABLED));
}

- (void)testFloatReportsAHostRefusal
{
	self.effect.apiManager.paramCreateAPIv5.succeeds = NO;

	XCTAssertFalse([self add:FxGripFloatParameter.class type:kFxParameterType_Float extra:nil]);
	XCTAssertEqual(self.effect.creationCalls.count, (NSUInteger)1);
}

#pragma mark Percent

- (void)testPercentWithoutBoundsMatchesTheFloatDefaults
{
	XCTAssertTrue([self add:FxGripPercentParameter.class type:kFxParameterType_Percent extra:nil]);

	XCTAssertEqualObjects(self.call, (@{@"method": @"percent",
										@"name": @"Amount",
										@"id": @(kScalarTestParameter),
										@"default": @0.0,
										@"min": @0.0,
										@"max": @1.0,
										@"slidermin": @0.0,
										@"slidermax": @1.0,
										@"delta": @0.01,
										@"flags": @(kFxParameterFlag_DEFAULT)}));
}

- (void)testPercentForwardsEveryDeclaredBoundAndTheDeclaredDelta
{
	NSDictionary *extra = @{kFxParameterProperty_Default: @0.75,
							kFxParameterProperty_Minimum: @0.0,
							kFxParameterProperty_Maximum: @2.0,
							kFxParameterProperty_SliderMinimum: @0.25,
							kFxParameterProperty_SliderMaximum: @1.75,
							kFxParameterProperty_Delta: @0.05};

	XCTAssertTrue([self add:FxGripPercentParameter.class type:kFxParameterType_Percent extra:extra]);

	XCTAssertEqualObjects(self.call, (@{@"method": @"percent",
										@"name": @"Amount",
										@"id": @(kScalarTestParameter),
										@"default": @0.75,
										@"min": @0.0,
										@"max": @2.0,
										@"slidermin": @0.25,
										@"slidermax": @1.75,
										@"delta": @0.05,
										@"flags": @(kFxParameterFlag_DEFAULT)}));
}

- (void)testPercentDeltaFallsBackToOneWhenTheRangeIsNotUnit
{
	NSDictionary *extra = @{kFxParameterProperty_Maximum: @4.0};

	XCTAssertTrue([self add:FxGripPercentParameter.class type:kFxParameterType_Percent extra:extra]);

	XCTAssertEqualObjects(self.call[@"delta"], @1.0);
}

- (void)testPercentReportsAHostRefusal
{
	self.effect.apiManager.paramCreateAPIv5.succeeds = NO;

	XCTAssertFalse([self add:FxGripPercentParameter.class type:kFxParameterType_Percent extra:nil]);
}

#pragma mark Int

- (void)testIntWithoutBoundsUsesZeroToOneHundredAndAUnitDelta
{
	XCTAssertTrue([self add:FxGripIntParameter.class type:kFxParameterType_Integer extra:nil]);

	XCTAssertEqualObjects(self.call, (@{@"method": @"int",
										@"name": @"Amount",
										@"id": @(kScalarTestParameter),
										@"default": @0,
										@"min": @0,
										@"max": @100,
										@"slidermin": @0,
										@"slidermax": @100,
										@"delta": @1,
										@"flags": @(kFxParameterFlag_DEFAULT)}));
}

/*!
	The creation wrapper had a defect forwarding every integer bound as the default value.
	This states the contract at the class boundary: the class reads each bound from its own
	configuration key before handing it to the API.
*/
- (void)testIntForwardsEachBoundFromItsOwnConfigurationKey
{
	NSDictionary *extra = @{kFxParameterProperty_Default: @5,
							kFxParameterProperty_Minimum: @1,
							kFxParameterProperty_Maximum: @100,
							kFxParameterProperty_SliderMinimum: @2,
							kFxParameterProperty_SliderMaximum: @50,
							kFxParameterProperty_Delta: @3};

	XCTAssertTrue([self add:FxGripIntParameter.class type:kFxParameterType_Integer extra:extra]);

	XCTAssertEqualObjects(self.call, (@{@"method": @"int",
										@"name": @"Amount",
										@"id": @(kScalarTestParameter),
										@"default": @5,
										@"min": @1,
										@"max": @100,
										@"slidermin": @2,
										@"slidermax": @50,
										@"delta": @3,
										@"flags": @(kFxParameterFlag_DEFAULT)}));
}

- (void)testIntSliderBoundsFallBackToTheParameterBounds
{
	NSDictionary *extra = @{kFxParameterProperty_Minimum: @(-10),
							kFxParameterProperty_Maximum: @10};

	XCTAssertTrue([self add:FxGripIntParameter.class type:kFxParameterType_Integer extra:extra]);

	XCTAssertEqualObjects(self.call[@"slidermin"], @(-10));
	XCTAssertEqualObjects(self.call[@"slidermax"], @10);
}

- (void)testIntTruncatesAFractionalConfigurationValue
{
	NSDictionary *extra = @{kFxParameterProperty_Default: @7.9,
							kFxParameterProperty_Delta: @2.5};

	XCTAssertTrue([self add:FxGripIntParameter.class type:kFxParameterType_Integer extra:extra]);

	XCTAssertEqualObjects(self.call[@"default"], @7);
	XCTAssertEqualObjects(self.call[@"delta"], @2);
}

- (void)testIntReportsAHostRefusal
{
	self.effect.apiManager.paramCreateAPIv5.succeeds = NO;

	XCTAssertFalse([self add:FxGripIntParameter.class type:kFxParameterType_Integer extra:nil]);
}

#pragma mark Int instance flags

- (FxGripIntParameter *)makeIntParameter
{
	NSDictionary *config = FxParamClassTestConfig(kScalarTestParameter, kFxParameterType_Integer, @"Count", nil);
	return [FxGripIntParameter.alloc initWithDictionary:config effect:(id)self.effect];
}

- (void)testIgnoreMinMaxReadsTheHostFlags
{
	FxGripIntParameter *parameter = [self makeIntParameter];
	self.effect.apiManager.paramGetAPIv6.flags = kFxParameterFlag_IGNORE_MINMAX;

	XCTAssertTrue(parameter.flagIgnoreMinMax);

	self.effect.apiManager.paramGetAPIv6.flags = kFxParameterFlag_DEFAULT;
	XCTAssertFalse(parameter.flagIgnoreMinMax);
}

- (void)testSettingIgnoreMinMaxWritesTheBitToTheHost
{
	FxGripIntParameter *parameter = [self makeIntParameter];
	self.effect.apiManager.paramGetAPIv6.flags = kFxParameterFlag_HIDDEN;

	parameter.flagIgnoreMinMax = YES;

	NSArray *expected = @[@{@"flags": @(kFxParameterFlag_HIDDEN | kFxParameterFlag_IGNORE_MINMAX),
							@"id": @(kScalarTestParameter)}];
	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.setFlagsCalls, expected);
}

- (void)testClearingIgnoreMinMaxRemovesOnlyThatBit
{
	FxGripIntParameter *parameter = [self makeIntParameter];
	self.effect.apiManager.paramGetAPIv6.flags = kFxParameterFlag_IGNORE_MINMAX | kFxParameterFlag_HIDDEN;

	parameter.flagIgnoreMinMax = NO;

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.setFlagsCalls.firstObject[@"flags"],
						  @(kFxParameterFlag_HIDDEN));
}

- (void)testSettingIgnoreMinMaxToItsCurrentStateWritesNothing
{
	FxGripIntParameter *parameter = [self makeIntParameter];
	self.effect.apiManager.paramGetAPIv6.flags = kFxParameterFlag_IGNORE_MINMAX;

	parameter.flagIgnoreMinMax = YES;

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.setFlagsCalls, @[]);
}

#pragma mark Angle

- (void)testAngleWithoutBoundsSpansAFullTurn
{
	XCTAssertTrue([self add:FxGripAngleParameter.class type:kFxParameterType_Angle extra:nil]);

	XCTAssertEqualObjects(self.call, (@{@"method": @"angle",
										@"name": @"Amount",
										@"id": @(kScalarTestParameter),
										@"default": @0.0,
										@"min": @0.0,
										@"max": @360.0,
										@"flags": @(kFxParameterFlag_DEFAULT)}));
}

- (void)testAngleForwardsTheDeclaredDegreesAndBounds
{
	NSDictionary *extra = @{kFxParameterProperty_Default: @45.0,
							kFxParameterProperty_Minimum: @(-180.0),
							kFxParameterProperty_Maximum: @180.0};

	XCTAssertTrue([self add:FxGripAngleParameter.class type:kFxParameterType_Angle extra:extra]);

	XCTAssertEqualObjects(self.call, (@{@"method": @"angle",
										@"name": @"Amount",
										@"id": @(kScalarTestParameter),
										@"default": @45.0,
										@"min": @(-180.0),
										@"max": @180.0,
										@"flags": @(kFxParameterFlag_DEFAULT)}));
}

- (void)testAngleIgnoresSliderBoundsAndDelta
{
	NSDictionary *extra = @{kFxParameterProperty_SliderMinimum: @10.0,
							kFxParameterProperty_SliderMaximum: @20.0,
							kFxParameterProperty_Delta: @5.0};

	XCTAssertTrue([self add:FxGripAngleParameter.class type:kFxParameterType_Angle extra:extra]);

	XCTAssertNil(self.call[@"slidermin"], @"the angle creation method takes no slider bounds");
	XCTAssertNil(self.call[@"delta"]);
	XCTAssertEqualObjects(self.call[@"max"], @360.0);
}

- (void)testAngleReportsAHostRefusal
{
	self.effect.apiManager.paramCreateAPIv5.succeeds = NO;

	XCTAssertFalse([self add:FxGripAngleParameter.class type:kFxParameterType_Angle extra:nil]);
}

#pragma mark Incomplete configurations

/*!
	The NSDictionary+FxTileableEffect accessors answer only for a record carrying "id",
	"type", and "name". A configuration missing the name reads back as an unnamed parameter
	whose every property is the fallback, which is what the host then receives.
*/
- (void)testAConfigurationMissingTheNameFallsBackToTheUnnamedParameterID
{
	NSDictionary *config = @{kFxParameterProperty_Id: @(kScalarTestParameter),
							 kFxParameterProperty_Type: kFxParameterType_Float,
							 kFxParameterProperty_Default: @0.5};

	XCTAssertTrue([FxGripFloatParameter addParameter:config toEffect:(id)self.effect]);

	XCTAssertEqualObjects(self.call[@"name"], NSNull.null);
	XCTAssertEqualObjects(self.call[@"id"], @((UInt32)kFxParameterId_None));
	XCTAssertEqualObjects(self.call[@"default"], @0.0, @"the declared default is unreachable");
	XCTAssertEqualObjects(self.call[@"flags"], @(kFxParameterFlag_INVALID));
}

@end
