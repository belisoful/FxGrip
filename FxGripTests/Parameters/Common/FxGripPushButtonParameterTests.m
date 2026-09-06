//
//  FxGripPushButtonParameterTests.m
//  FxGripTests
//
//  Unit tests for FxGripPushButtonParameter creation: the synthesized click selector it
//  registers with the host, the validation of the optional configuration-declared selector
//  hook, and the selector-capturing initializer. The click dispatch itself is covered by
//  FxGripParameterClickTests.
//

#import <XCTest/XCTest.h>
#import "FxGripParameterClassTestSupport.h"
#import <FxGrip/FxGripPushButtonParameter.h>
#import <FxGrip/FxGripParameterUtility.h>

static const FxParameterId kPushButtonTestParameter = 61;

@interface FxGripPushButtonParameterTests : XCTestCase
@property (nonatomic, strong) FxGripParamClassTestEffect *effect;
@end

@implementation FxGripPushButtonParameterTests

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
	NSDictionary *config = FxGripParamClassTestConfig(kPushButtonTestParameter, type, @"Reset", extra);
	return [parameterClass addParameter:config toEffect:(id)self.effect];
}

- (NSString *)synthesizedSelectorName
{
	return [FxGripParameterUtility clickSelectorNameForParameter:kPushButtonTestParameter];
}

#pragma mark Type identity

- (void)testReportsItsFxPlugTypeAndTypeString
{
	XCTAssertEqual(FxGripPushButtonParameter.parameterType, FxParameterType_PushButton);
	XCTAssertEqualObjects(FxGripPushButtonParameter.parameterTypeString, kFxParameterType_PushButton);
}

#pragma mark Creation

- (void)testAPushButtonRegistersTheSelectorThatEncodesItsParameterID
{
	XCTAssertTrue([self add:FxGripPushButtonParameter.class
					   type:kFxParameterType_PushButton
		   declaredSelector:nil]);

	XCTAssertEqualObjects(self.call, (@{@"method": @"button",
										@"name": @"Reset",
										@"id": @(kPushButtonTestParameter),
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
	NSDictionary *first = FxGripParamClassTestConfig(7, kFxParameterType_PushButton, @"First", nil);
	NSDictionary *second = FxGripParamClassTestConfig(8, kFxParameterType_PushButton, @"Second", nil);

	XCTAssertTrue([FxGripPushButtonParameter addParameter:first toEffect:(id)self.effect]);
	XCTAssertTrue([FxGripPushButtonParameter addParameter:second toEffect:(id)self.effect]);

	XCTAssertEqualObjects(self.effect.creationCalls[0][@"selector"],
						  [FxGripParameterUtility clickSelectorNameForParameter:7]);
	XCTAssertEqualObjects(self.effect.creationCalls[1][@"selector"],
						  [FxGripParameterUtility clickSelectorNameForParameter:8]);
}

#pragma mark Selector capture

- (void)testThePushButtonInitializerCapturesTheDeclaredSelector
{
	NSDictionary *config = FxGripParamClassTestConfig(kPushButtonTestParameter, kFxParameterType_PushButton, @"Reset",
												  @{kFxParameterProperty_Selector: @"clickReset"});

	FxGripPushButtonParameter *parameter = [FxGripPushButtonParameter.alloc initWithDictionary:config effect:(id)self.effect];

	XCTAssertEqualObjects(parameter.selectorString, @"clickReset");
	XCTAssertEqualObjects(NSStringFromSelector(parameter.selector), @"clickReset");
}

- (void)testThePushButtonInitializerLeavesTheSelectorEmptyWithoutADeclaration
{
	NSDictionary *config = FxGripParamClassTestConfig(kPushButtonTestParameter, kFxParameterType_PushButton, @"Reset", nil);

	FxGripPushButtonParameter *parameter = [FxGripPushButtonParameter.alloc initWithDictionary:config effect:(id)self.effect];

	XCTAssertNil(parameter.selectorString);
	XCTAssertTrue(parameter.selector == NULL, @"an empty selector name resolves to no selector");
}

@end
