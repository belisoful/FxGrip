//
//  FxGripHelpParameterTests.m
//  FxGripTests
//
//  Unit tests for FxGripHelpParameter creation: the synthesized click selector it registers
//  with the host, the validation of the optional configuration-declared selector hook, the
//  host-refusal result, and the configured flags it carries through.
//

#import <XCTest/XCTest.h>
#import "FxGripParameterClassTestSupport.h"
#import <FxGrip/FxGripHelpParameter.h>
#import <FxGrip/FxGripParameterUtility.h>

static const FxParameterId kHelpTestParameter = 61;

@interface FxGripHelpParameterTests : XCTestCase
@property (nonatomic, strong) FxGripParamClassTestEffect *effect;
@end

@implementation FxGripHelpParameterTests

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

- (BOOL)add:(Class)parameterClass type:(NSString *)type declaredSelector:(NSString *)declaredSelector
{
	NSDictionary *extra = declaredSelector ? @{kFxParameterProperty_Selector: declaredSelector} : nil;
	NSDictionary *config = FxGripParamClassTestConfig(kHelpTestParameter, type, @"Reset", extra);
	return [parameterClass addParameter:config toEffect:(id)self.effect];
}

- (NSString *)synthesizedSelectorName
{
	return [FxGripParameterUtility clickSelectorNameForParameter:kHelpTestParameter];
}

#pragma mark Type identity

- (void)testReportsItsFxPlugTypeAndTypeString
{
	XCTAssertEqual(FxGripHelpParameter.parameterType, FxParameterType_Help);
	XCTAssertEqualObjects(FxGripHelpParameter.parameterTypeString, kFxParameterType_Help);
}

#pragma mark Creation

- (void)testAHelpButtonRegistersTheSelectorThatEncodesItsParameterID
{
	XCTAssertTrue([self add:FxGripHelpParameter.class type:kFxParameterType_Help declaredSelector:nil]);

	XCTAssertEqualObjects(self.call, (@{@"method": @"help",
										@"name": @"Reset",
										@"id": @(kHelpTestParameter),
										@"selector": self.synthesizedSelectorName,
										@"flags": @(kFxParameterFlag_DEFAULT)}));
}

- (void)testAHelpButtonRefusesADeclaredSelectorWithoutTheClickPrefix
{
	XCTAssertFalse([self add:FxGripHelpParameter.class
						type:kFxParameterType_Help
			declaredSelector:@"showTheManual"]);

	XCTAssertEqualObjects(self.effect.creationCalls, @[]);
}

- (void)testAHelpButtonAcceptsADeclaredSelectorWithTheClickPrefix
{
	XCTAssertTrue([self add:FxGripHelpParameter.class
					   type:kFxParameterType_Help
		   declaredSelector:@"clickShowTheManual"]);

	XCTAssertEqualObjects(self.call[@"method"], @"help");
	XCTAssertEqualObjects(self.call[@"selector"], self.synthesizedSelectorName);
}

- (void)testAHelpButtonReportsAHostRefusal
{
	self.effect.apiManager.paramCreateAPIv5.succeeds = NO;

	XCTAssertFalse([self add:FxGripHelpParameter.class type:kFxParameterType_Help declaredSelector:nil]);
}

- (void)testAHelpButtonCarriesTheConfiguredFlags
{
	NSArray *declared = @[kParameterFlagString_DISABLED];
	NSDictionary *config = FxGripParamClassTestConfig(kHelpTestParameter, kFxParameterType_Help, @"Help",
												  @{kFxParameterProperty_Flags: declared});

	XCTAssertTrue([FxGripHelpParameter addParameter:config toEffect:(id)self.effect]);

	XCTAssertEqualObjects(self.call[@"flags"], @(kFxParameterFlag_DISABLED));
}

@end
