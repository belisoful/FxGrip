/*!
	@file       FxGripPushButtonParameterTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripPushButtonParameterTests
	@abstract   Tests FxGripPushButtonParameter creation: the synthesized click selector it
	            registers with the host.
	@discussion Introduced in FxGrip 0.1.0. The tests confirm the validation of the optional
	            configuration-declared selector hook and the selector-capturing initializer.
	            FxGripParameterClickTests covers the click dispatch itself.
*/

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

/*! @abstract The class reports the FxPlug push-button type and its type string. */
- (void)testReportsItsFxPlugTypeAndTypeString
{
	XCTAssertEqual(FxGripPushButtonParameter.parameterType, FxParameterType_PushButton);
	XCTAssertEqualObjects(FxGripPushButtonParameter.parameterTypeString, kFxParameterType_PushButton);
}

#pragma mark Creation

/*! @abstract A push button registers the synthesized selector that encodes its parameter ID. */
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

/*! @abstract A declared selector lacking the click prefix is refused before the host is called. */
- (void)testADeclaredSelectorWithoutTheClickPrefixIsRefusedBeforeTheHostIsCalled
{
	XCTAssertFalse([self add:FxGripPushButtonParameter.class
						type:kFxParameterType_PushButton
			declaredSelector:@"resetEverything"]);

	XCTAssertEqualObjects(self.effect.creationCalls, @[]);
}

/*! @abstract The click-prefix check accepts declared selectors regardless of case. */
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

/*! @abstract A declared selector naming only the click prefix is accepted. */
- (void)testADeclaredSelectorNamingOnlyThePrefixIsAccepted
{
	XCTAssertTrue([self add:FxGripPushButtonParameter.class
					   type:kFxParameterType_PushButton
		   declaredSelector:kFxParameterProperty_SelectorPrefix]);

	XCTAssertEqual(self.effect.creationCalls.count, (NSUInteger)1);
}

/*! @abstract When the host creation API refuses, +addParameter:toEffect: returns false. */
- (void)testAPushButtonReportsAHostRefusal
{
	self.effect.apiManager.paramCreateAPIv5.succeeds = NO;

	XCTAssertFalse([self add:FxGripPushButtonParameter.class
						type:kFxParameterType_PushButton
			declaredSelector:nil]);
	XCTAssertEqual(self.effect.creationCalls.count, (NSUInteger)1);
}

/*! @abstract Each push button registers the synthesized selector encoding its own parameter ID. */
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

/*! @abstract The initializer captures the declared selector as both a string and a selector. */
- (void)testThePushButtonInitializerCapturesTheDeclaredSelector
{
	NSDictionary *config = FxGripParamClassTestConfig(kPushButtonTestParameter, kFxParameterType_PushButton, @"Reset",
												  @{kFxParameterProperty_Selector: @"clickReset"});

	FxGripPushButtonParameter *parameter = [FxGripPushButtonParameter.alloc initWithDictionary:config effect:(id)self.effect];

	XCTAssertEqualObjects(parameter.selectorString, @"clickReset");
	XCTAssertEqualObjects(NSStringFromSelector(parameter.selector), @"clickReset");
}

/*! @abstract The initializer leaves the selector nil when the configuration declares none. */
- (void)testThePushButtonInitializerLeavesTheSelectorEmptyWithoutADeclaration
{
	NSDictionary *config = FxGripParamClassTestConfig(kPushButtonTestParameter, kFxParameterType_PushButton, @"Reset", nil);

	FxGripPushButtonParameter *parameter = [FxGripPushButtonParameter.alloc initWithDictionary:config effect:(id)self.effect];

	XCTAssertNil(parameter.selectorString);
	XCTAssertTrue(parameter.selector == NULL, @"an empty selector name resolves to no selector");
}

@end
