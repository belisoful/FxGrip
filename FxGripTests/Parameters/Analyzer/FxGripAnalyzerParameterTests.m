//
//  FxGripAnalyzerParameterTests.m
//  FxGripTests
//
//  Unit tests for FxGripAnalyzerParameter creation: the type identity, the push button it
//  registers using its parameter name as the title, the configured button title and the
//  analyze fallback title, the selector-prefix validation, and the safe no-op action on a
//  host without an analysis pass.
//

#import <XCTest/XCTest.h>
#import "FxGripParameterClassTestSupport.h"
#import <FxGrip/FxGripAnalyzerParameter.h>
#import <FxGrip/FxGripParameterUtility.h>

static const FxParameterId kAnalyzerTestParameter = 61;

@interface FxGripAnalyzerParameterTests : XCTestCase
@property (nonatomic, strong) FxGripParamClassTestEffect *effect;
@end

@implementation FxGripAnalyzerParameterTests

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
	NSDictionary *config = FxGripParamClassTestConfig(kAnalyzerTestParameter, type, @"Reset", extra);
	return [parameterClass addParameter:config toEffect:(id)self.effect];
}

- (NSString *)synthesizedSelectorName
{
	return [FxGripParameterUtility clickSelectorNameForParameter:kAnalyzerTestParameter];
}

#pragma mark Type identity

- (void)testTheAnalyzerButtonReportsItsFxPlugTypeAndTypeString
{
	XCTAssertEqual(FxGripAnalyzerParameter.parameterType, FxParameterType_Analyzer);
	XCTAssertEqualObjects(FxGripAnalyzerParameter.parameterTypeString, kFxParameterType_Analyzer);
}

#pragma mark Creation

- (void)testTheAnalyzerButtonRegistersAPushButtonUsingItsParameterNameAsTheTitle
{
	XCTAssertTrue([self add:FxGripAnalyzerParameter.class type:kFxParameterType_Analyzer declaredSelector:nil]);

	XCTAssertEqualObjects(self.call, (@{@"method": @"button",
										@"name": @"Reset",
										@"id": @(kAnalyzerTestParameter),
										@"selector": self.synthesizedSelectorName,
										@"flags": @(kFxParameterFlag_DEFAULT)}));
}

- (void)testTheAnalyzerButtonPrefersTheConfiguredButtonTitle
{
	NSDictionary *config = FxGripParamClassTestConfig(kAnalyzerTestParameter, kFxParameterType_Analyzer, @"Reset",
													  @{kFxParameterProperty_ButtonTitle: @"Detect Motion"});

	XCTAssertTrue([FxGripAnalyzerParameter addParameter:config toEffect:(id)self.effect]);

	XCTAssertEqualObjects(self.call[@"name"], @"Detect Motion");
}

- (void)testTheAnalyzerButtonFallsBackToAnalyzeWhenNoNameOrTitleIsGiven
{
	NSDictionary *config = @{kFxParameterProperty_Id: @(kAnalyzerTestParameter),
							 kFxParameterProperty_Type: kFxParameterType_Analyzer};

	XCTAssertTrue([FxGripAnalyzerParameter addParameter:config toEffect:(id)self.effect]);

	XCTAssertEqualObjects(self.call[@"name"], kFxGripAnalyzerDefaultTitle);
}

- (void)testTheAnalyzerButtonRefusesADeclaredSelectorWithoutTheClickPrefix
{
	XCTAssertFalse([self add:FxGripAnalyzerParameter.class type:kFxParameterType_Analyzer declaredSelector:@"runAnalysis"]);

	XCTAssertEqualObjects(self.effect.creationCalls, @[]);
}

/*! The click hook is a no-op when the host is not an FxGrip effect that conforms to
	FxAnalyzer, so a misconfigured analyzer button never throws. */
- (void)testTheAnalyzerActionIsSafeOnAHostWithoutAnAnalysisPass
{
	NSDictionary *config = FxGripParamClassTestConfig(kAnalyzerTestParameter, kFxParameterType_Analyzer, @"Analyze", nil);
	FxGripAnalyzerParameter *parameter = [FxGripAnalyzerParameter.alloc initWithDictionary:config effect:(id)self.effect];

	XCTAssertNoThrow([parameter defaultParameterAction]);
}

@end
