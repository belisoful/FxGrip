//
//  FxGripFloatParameterTests.m
//  FxGripTests
//
//  Unit tests for FxGripFloatParameter: the type identity, the payload
//  +addParameter:toEffect: derives from a configuration, the defaults applied when the
//  configuration omits a bound, the delta fallback, and the host-refusal result.
//

#import <XCTest/XCTest.h>
#import "FxGripParameterClassTestSupport.h"
#import <FxGrip/FxGripFloatParameter.h>

static const FxParameterId kFloatTestParameter = 21;

@interface FxGripFloatParameterTests : XCTestCase
@property (nonatomic, strong) FxGripParamClassTestEffect *effect;
@end

@implementation FxGripFloatParameterTests

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
	NSDictionary *config = FxGripParamClassTestConfig(kFloatTestParameter, type, @"Amount", extra);
	return [parameterClass addParameter:config toEffect:(id)self.effect];
}

#pragma mark Type identity

- (void)testReportsItsFxPlugTypeAndTypeString
{
	XCTAssertEqual(FxGripFloatParameter.parameterType, FxParameterType_Float);
	XCTAssertEqualObjects(FxGripFloatParameter.parameterTypeString, kFxParameterType_Float);
}

- (void)testAnInstanceReportsTheClassTypeThroughTheInstanceAccessor
{
	NSDictionary *config = FxGripParamClassTestConfig(kFloatTestParameter, kFxParameterType_Float, @"Amount", nil);
	FxGripFloatParameter *parameter = [FxGripFloatParameter.alloc initWithDictionary:config
																			  effect:(id)self.effect];

	XCTAssertNotNil(parameter);
	XCTAssertEqual(parameter.parameterType, FxParameterType_Float);
}

#pragma mark Creation payload

- (void)testFloatWithoutBoundsUsesZeroToOneAndTheHundredthDelta
{
	XCTAssertTrue([self add:FxGripFloatParameter.class type:kFxParameterType_Float extra:nil]);

	XCTAssertEqualObjects(self.call, (@{@"method": @"float",
										@"name": @"Amount",
										@"id": @(kFloatTestParameter),
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
										@"id": @(kFloatTestParameter),
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

#pragma mark Incomplete configurations

/*!
	The NSDictionary+FxGripTileableEffect accessors answer only for a record carrying "id",
	"type", and "name". A configuration missing the name reads back as an unnamed parameter
	whose every property is the fallback, which is what the host then receives.
*/
- (void)testAConfigurationMissingTheNameFallsBackToTheUnnamedParameterID
{
	NSDictionary *config = @{kFxParameterProperty_Id: @(kFloatTestParameter),
							 kFxParameterProperty_Type: kFxParameterType_Float,
							 kFxParameterProperty_Default: @0.5};

	XCTAssertTrue([FxGripFloatParameter addParameter:config toEffect:(id)self.effect]);

	XCTAssertEqualObjects(self.call[@"name"], NSNull.null);
	XCTAssertEqualObjects(self.call[@"id"], @((UInt32)kFxParameterId_None));
	XCTAssertEqualObjects(self.call[@"default"], @0.0, @"the declared default is unreachable");
	XCTAssertEqualObjects(self.call[@"flags"], @(kFxParameterFlag_INVALID));
}

@end
