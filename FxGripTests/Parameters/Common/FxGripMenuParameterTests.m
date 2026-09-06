//
//  FxGripMenuParameterTests.m
//  FxGripTests
//
//  Unit tests for FxGripMenuParameter: the type identity, the payload
//  +addParameter:toEffect: derives from a configuration, the menu-item list and default
//  index handling, the host-refusal result, and the item list the initializer captures.
//

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

- (void)testReportsItsFxPlugTypeAndTypeString
{
	XCTAssertEqual(FxGripMenuParameter.parameterType, FxParameterType_Menu);
	XCTAssertEqualObjects(FxGripMenuParameter.parameterTypeString, kFxParameterType_Menu);
}

#pragma mark Creation payload

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

- (void)testMenuWithoutADefaultSelectsTheFirstEntry
{
	NSDictionary *extra = @{kFxParameterProperty_MenuItems: @[@"One", @"Two"]};

	XCTAssertTrue([self add:FxGripMenuParameter.class type:kFxParameterType_Menu extra:extra]);

	XCTAssertEqualObjects(self.call[@"default"], @0);
}

- (void)testMenuWithoutAnItemListSendsAnEmptyList
{
	XCTAssertTrue([self add:FxGripMenuParameter.class type:kFxParameterType_Menu extra:nil]);

	XCTAssertEqualObjects(self.call[@"items"], @[]);
}

- (void)testMenuTruncatesAFractionalDefaultIndex
{
	NSDictionary *extra = @{kFxParameterProperty_Default: @1.9};

	XCTAssertTrue([self add:FxGripMenuParameter.class type:kFxParameterType_Menu extra:extra]);

	XCTAssertEqualObjects(self.call[@"default"], @1);
}

- (void)testMenuReportsAHostRefusal
{
	self.effect.apiManager.paramCreateAPIv5.succeeds = NO;

	XCTAssertFalse([self add:FxGripMenuParameter.class type:kFxParameterType_Menu extra:nil]);
}

#pragma mark Initializer

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

- (void)testTheInitializerLeavesTheItemListEmptyForAMenuWithoutEntries
{
	NSDictionary *config = FxGripParamClassTestConfig(kMenuTestParameter, kFxParameterType_Menu, @"Mode", nil);

	FxGripMenuParameter *parameter = [FxGripMenuParameter.alloc initWithDictionary:config effect:(id)self.effect];

	XCTAssertEqualObjects(parameter.parameterMenuItems, @[]);
}

@end
