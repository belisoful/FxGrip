//
//  FxGripButtonParameterTests.m
//  FxGripTests
//
//  Unit tests for FxGripPushButtonParameter and FxGripHelpParameter creation: the
//  synthesized click selector each registers with the host, the validation of the optional
//  configuration-declared selector hook, and the push button's selector-capturing
//  initializer. The click dispatch itself is covered by FxGripParameterClickTests.
//

#import <XCTest/XCTest.h>
#import "FxGripParameterClassTestSupport.h"
#import <FxGrip/FxGripPushButtonParameter.h>
#import <FxGrip/FxGripHelpParameter.h>
#import <FxGrip/FxGripParameterUtility.h>

// The single-argument initializer is implemented but absent from the public header.
@interface FxGripPushButtonParameter (FxGripButtonParameterTests)
- (instancetype)initWithDictionary:(NSDictionary *)dictionary;
@end

static const FxParameterId kButtonTestParameter = 61;

@interface FxGripButtonParameterTests : XCTestCase
@property (nonatomic, strong) FxParamClassTestEffect *effect;
@end

@implementation FxGripButtonParameterTests

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

- (BOOL)add:(Class)parameterClass type:(NSString *)type declaredSelector:(NSString *)declaredSelector
{
	NSDictionary *extra = declaredSelector ? @{kFxParameterProperty_Selector: declaredSelector} : nil;
	NSDictionary *config = FxParamClassTestConfig(kButtonTestParameter, type, @"Reset", extra);
	return [parameterClass addParameter:config toEffect:(id)self.effect];
}

- (NSString *)synthesizedSelectorName
{
	return [FxGripParameterUtility clickSelectorNameForParameter:kButtonTestParameter];
}

#pragma mark Type identity

- (void)testEachButtonClassReportsItsFxPlugTypeAndTypeString
{
	XCTAssertEqual(FxGripPushButtonParameter.parameterType, FxParameterType_PushButton);
	XCTAssertEqualObjects(FxGripPushButtonParameter.parameterTypeString, kFxParameterType_PushButton);

	XCTAssertEqual(FxGripHelpParameter.parameterType, FxParameterType_Help);
	XCTAssertEqualObjects(FxGripHelpParameter.parameterTypeString, kFxParameterType_Help);
}

#pragma mark Push button creation

- (void)testAPushButtonRegistersTheSelectorThatEncodesItsParameterID
{
	XCTAssertTrue([self add:FxGripPushButtonParameter.class
					   type:kFxParameterType_PushButton
		   declaredSelector:nil]);

	XCTAssertEqualObjects(self.call, (@{@"method": @"button",
										@"name": @"Reset",
										@"id": @(kButtonTestParameter),
										@"selector": self.synthesizedSelectorName,
										@"flags": @(kFxParameterFlag_DEFAULT)}));
}

/*!
	The configuration's "selector" is the subclass hook, not the registered selector: the
	host still receives the synthesized name that encodes the parameter ID.
*/
- (void)testADeclaredSelectorDoesNotReplaceTheRegisteredSelector
{
	XCTAssertTrue([self add:FxGripPushButtonParameter.class
					   type:kFxParameterType_PushButton
		   declaredSelector:@"clickReset"]);

	XCTAssertEqualObjects(self.call[@"selector"], self.synthesizedSelectorName);
}

- (void)testADeclaredSelectorWithoutTheClickPrefixIsRefusedBeforeTheHostIsCalled
{
	XCTAssertFalse([self add:FxGripPushButtonParameter.class
						type:kFxParameterType_PushButton
			declaredSelector:@"resetEverything"]);

	XCTAssertEqualObjects(self.effect.creationCalls, @[]);
}

- (void)testTheClickPrefixCheckIsCaseInsensitive
{
	XCTAssertTrue([self add:FxGripPushButtonParameter.class
					   type:kFxParameterType_PushButton
		   declaredSelector:@"ClickReset"]);
	XCTAssertTrue([self add:FxGripPushButtonParameter.class
					   type:kFxParameterType_PushButton
		   declaredSelector:@"CLICKRESET"]);

	XCTAssertEqual(self.effect.creationCalls.count, (NSUInteger)2);
}

- (void)testADeclaredSelectorNamingOnlyThePrefixIsAccepted
{
	XCTAssertTrue([self add:FxGripPushButtonParameter.class
					   type:kFxParameterType_PushButton
		   declaredSelector:kFxParameterProperty_SelectorPrefix]);

	XCTAssertEqual(self.effect.creationCalls.count, (NSUInteger)1);
}

- (void)testAPushButtonReportsAHostRefusal
{
	self.effect.apiManager.paramCreateAPIv5.succeeds = NO;

	XCTAssertFalse([self add:FxGripPushButtonParameter.class
						type:kFxParameterType_PushButton
			declaredSelector:nil]);
	XCTAssertEqual(self.effect.creationCalls.count, (NSUInteger)1);
}

- (void)testEveryPushButtonRegistersItsOwnSelector
{
	NSDictionary *first = FxParamClassTestConfig(7, kFxParameterType_PushButton, @"First", nil);
	NSDictionary *second = FxParamClassTestConfig(8, kFxParameterType_PushButton, @"Second", nil);

	XCTAssertTrue([FxGripPushButtonParameter addParameter:first toEffect:(id)self.effect]);
	XCTAssertTrue([FxGripPushButtonParameter addParameter:second toEffect:(id)self.effect]);

	XCTAssertEqualObjects(self.effect.creationCalls[0][@"selector"],
						  [FxGripParameterUtility clickSelectorNameForParameter:7]);
	XCTAssertEqualObjects(self.effect.creationCalls[1][@"selector"],
						  [FxGripParameterUtility clickSelectorNameForParameter:8]);
}

#pragma mark Help button creation

- (void)testAHelpButtonRegistersTheSelectorThatEncodesItsParameterID
{
	XCTAssertTrue([self add:FxGripHelpParameter.class type:kFxParameterType_Help declaredSelector:nil]);

	XCTAssertEqualObjects(self.call, (@{@"method": @"help",
										@"name": @"Reset",
										@"id": @(kButtonTestParameter),
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
	NSDictionary *config = FxParamClassTestConfig(kButtonTestParameter, kFxParameterType_Help, @"Help",
												  @{kFxParameterProperty_Flags: declared});

	XCTAssertTrue([FxGripHelpParameter addParameter:config toEffect:(id)self.effect]);

	XCTAssertEqualObjects(self.call[@"flags"], @(kFxParameterFlag_DISABLED));
}

#pragma mark Selector capture

- (void)testThePushButtonInitializerCapturesTheDeclaredSelector
{
	NSDictionary *config = FxParamClassTestConfig(kButtonTestParameter, kFxParameterType_PushButton, @"Reset",
												  @{kFxParameterProperty_Selector: @"clickReset"});

	FxGripPushButtonParameter *parameter = [FxGripPushButtonParameter.alloc initWithDictionary:config effect:(id)self.effect];

	XCTAssertEqualObjects(parameter.selectorString, @"clickReset");
	XCTAssertEqualObjects(NSStringFromSelector(parameter.selector), @"clickReset");
}

- (void)testThePushButtonInitializerLeavesTheSelectorEmptyWithoutADeclaration
{
	NSDictionary *config = FxParamClassTestConfig(kButtonTestParameter, kFxParameterType_PushButton, @"Reset", nil);

	FxGripPushButtonParameter *parameter = [FxGripPushButtonParameter.alloc initWithDictionary:config effect:(id)self.effect];

	XCTAssertNil(parameter.selectorString);
	XCTAssertTrue(parameter.selector == NULL, @"an empty selector name resolves to no selector");
}

@end
