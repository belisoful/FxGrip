/*!
	@file       FxGripMenuParameterTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripMenuParameterTests
	@abstract   Tests FxGripMenuParameter: its FxPlug type identity and the creation payload
	            +addParameter:toEffect: derives from a configuration.
	@discussion Introduced in FxGrip 0.1.0. The tests confirm the menu-item list and default
	            index handling, the host-refusal result, and the item list the initializer
	            captures.
*/

#import <XCTest/XCTest.h>
#import "FxGripParameterClassTestSupport.h"
#import <FxGrip/FxGripMenuParameter.h>

static const FxParameterId kMenuTestParameter = 41;

@interface FxGripMenuParameterTests : XCTestCase
@property (nonatomic, strong) FxGripParamClassTestEffect *effect;
@end

@implementation FxGripMenuParameterTests

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
	NSDictionary *config = FxGripParamClassTestConfig(kMenuTestParameter, type, @"Mode", extra);
	return [parameterClass addParameter:config toEffect:(id)self.effect];
}

#pragma mark Type identity

/*! @abstract The class reports the FxPlug menu type and its type string. */
- (void)testReportsItsFxPlugTypeAndTypeString
{
	XCTAssertEqual(FxGripMenuParameter.parameterType, FxParameterType_Menu);
	XCTAssertEqualObjects(FxGripMenuParameter.parameterTypeString, kFxParameterType_Menu);
}

#pragma mark Creation payload

/*! @abstract A menu forwards its item list and declared default index to the creation call. */
- (void)testMenuForwardsTheEntriesAndTheDefaultIndex
{
	NSArray *items = @[@"One", @"Two", @"Three"];
	NSDictionary *extra = @{kFxParameterProperty_MenuItems: items,
							kFxParameterProperty_Default: @2};

	XCTAssertTrue([self add:FxGripMenuParameter.class type:kFxParameterType_Menu extra:extra]);

	XCTAssertEqualObjects(self.call, (@{@"method": @"menu",
										@"name": @"Mode",
										@"id": @(kMenuTestParameter),
										@"default": @2,
										@"items": items,
										@"flags": @(kFxParameterFlag_DEFAULT)}));
}

/*! @abstract A menu with no declared default selects the first entry. */
- (void)testMenuWithoutADefaultSelectsTheFirstEntry
{
	NSDictionary *extra = @{kFxParameterProperty_MenuItems: @[@"One", @"Two"]};

	XCTAssertTrue([self add:FxGripMenuParameter.class type:kFxParameterType_Menu extra:extra]);

	XCTAssertEqualObjects(self.call[@"default"], @0);
}

/*! @abstract A menu with no declared item list sends an empty list. */
- (void)testMenuWithoutAnItemListSendsAnEmptyList
{
	XCTAssertTrue([self add:FxGripMenuParameter.class type:kFxParameterType_Menu extra:nil]);

	XCTAssertEqualObjects(self.call[@"items"], @[]);
}

/*! @abstract A fractional default index is truncated to an integer. */
- (void)testMenuTruncatesAFractionalDefaultIndex
{
	NSDictionary *extra = @{kFxParameterProperty_Default: @1.9};

	XCTAssertTrue([self add:FxGripMenuParameter.class type:kFxParameterType_Menu extra:extra]);

	XCTAssertEqualObjects(self.call[@"default"], @1);
}

/*! @abstract When the host creation API refuses, +addParameter:toEffect: returns false. */
- (void)testMenuReportsAHostRefusal
{
	self.effect.apiManager.paramCreateAPIv5.succeeds = NO;

	XCTAssertFalse([self add:FxGripMenuParameter.class type:kFxParameterType_Menu extra:nil]);
}

#pragma mark Initializer

/*! @abstract The initializer captures the declared item list and the owning effect. */
- (void)testTheInitializerCapturesTheItemList
{
	NSArray *items = @[@"One", @"Two"];
	NSDictionary *config = FxGripParamClassTestConfig(kMenuTestParameter, kFxParameterType_Menu, @"Mode",
												  @{kFxParameterProperty_MenuItems: items});

	FxGripMenuParameter *parameter = [FxGripMenuParameter.alloc initWithDictionary:config effect:(id)self.effect];

	XCTAssertNotNil(parameter);
	XCTAssertEqualObjects(parameter.parameterMenuItems, items);
	XCTAssertEqualObjects((id)parameter.effect, self.effect);
}

/*! @abstract The initializer leaves the item list empty for a menu declaring no entries. */
- (void)testTheInitializerLeavesTheItemListEmptyForAMenuWithoutEntries
{
	NSDictionary *config = FxGripParamClassTestConfig(kMenuTestParameter, kFxParameterType_Menu, @"Mode", nil);

	FxGripMenuParameter *parameter = [FxGripMenuParameter.alloc initWithDictionary:config effect:(id)self.effect];

	XCTAssertEqualObjects(parameter.parameterMenuItems, @[]);
}

@end
