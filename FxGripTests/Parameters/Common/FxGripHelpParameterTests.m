/*!
	@file       FxGripHelpParameterTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripHelpParameterTests
	@abstract   Tests FxGripHelpParameter creation: the synthesized click selector it registers
	            with the host.
	@discussion Introduced in FxGrip 0.1.0. The tests confirm the validation of the optional
	            configuration-declared selector hook, the host-refusal result, and the
	            configured flags it carries through.
*/

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

/*! @abstract The class reports the FxPlug help type and its type string. */
- (void)testReportsItsFxPlugTypeAndTypeString
{
	XCTAssertEqual(FxGripHelpParameter.parameterType, FxParameterType_Help);
	XCTAssertEqualObjects(FxGripHelpParameter.parameterTypeString, kFxParameterType_Help);
}

#pragma mark Creation

/*! @abstract A help button registers the synthesized selector that encodes its parameter ID. */
- (void)testAHelpButtonRegistersTheSelectorThatEncodesItsParameterID
{
	XCTAssertTrue([self add:FxGripHelpParameter.class type:kFxParameterType_Help declaredSelector:nil]);

	XCTAssertEqualObjects(self.call, (@{@"method": @"help",
										@"name": @"Reset",
										@"id": @(kHelpTestParameter),
										@"selector": self.synthesizedSelectorName,
										@"flags": @(kFxParameterFlag_DEFAULT)}));
}

/*! @abstract A declared selector lacking the click prefix is refused before the host is called. */
- (void)testAHelpButtonRefusesADeclaredSelectorWithoutTheClickPrefix
{
	XCTAssertFalse([self add:FxGripHelpParameter.class
						type:kFxParameterType_Help
			declaredSelector:@"showTheManual"]);

	XCTAssertEqualObjects(self.effect.creationCalls, @[]);
}

/*! @abstract A declared selector with the click prefix is accepted, and the registered selector remains the synthesized name. */
- (void)testAHelpButtonAcceptsADeclaredSelectorWithTheClickPrefix
{
	XCTAssertTrue([self add:FxGripHelpParameter.class
					   type:kFxParameterType_Help
		   declaredSelector:@"clickShowTheManual"]);

	XCTAssertEqualObjects(self.call[@"method"], @"help");
	XCTAssertEqualObjects(self.call[@"selector"], self.synthesizedSelectorName);
}

/*! @abstract When the host creation API refuses, +addParameter:toEffect: returns false. */
- (void)testAHelpButtonReportsAHostRefusal
{
	self.effect.apiManager.paramCreateAPIv5.succeeds = NO;

	XCTAssertFalse([self add:FxGripHelpParameter.class type:kFxParameterType_Help declaredSelector:nil]);
}

/*! @abstract A help button carries the declared flag into the flag bitmask sent to the host. */
- (void)testAHelpButtonCarriesTheConfiguredFlags
{
	NSArray *declared = @[kParameterFlagString_DISABLED];
	NSDictionary *config = FxGripParamClassTestConfig(kHelpTestParameter, kFxParameterType_Help, @"Help",
												  @{kFxParameterProperty_Flags: declared});

	XCTAssertTrue([FxGripHelpParameter addParameter:config toEffect:(id)self.effect]);

	XCTAssertEqualObjects(self.call[@"flags"], @(kFxParameterFlag_DISABLED));
}

@end
