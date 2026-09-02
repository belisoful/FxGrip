//
//  FxGripChoiceParameterTests.m
//  FxGripTests
//
//  Unit tests for the parameter classes whose value is a choice or a piece of text:
//  FxGripMenuParameter, FxGripFontMenuParameter, FxGripStringParameter (and its base), and
//  FxGripToggleParameter. Coverage spans the type identity, the payload
//  +addParameter:toEffect: derives from a configuration, the menu-item list, the font-name
//  fallback, and the value plumbing through the retrieval and setting APIs.
//

#import <XCTest/XCTest.h>
#import "FxGripParameterClassTestSupport.h"
#import <FxGrip/FxGripMenuParameter.h>
#import <FxGrip/FxGripFontMenuParameter.h>
#import <FxGrip/FxGripStringParameter.h>
#import <FxGrip/FxGripToggleParameter.h>

// Declared in the implementations rather than the public headers.
@interface FxGripMenuParameter (FxGripChoiceParameterTests)
- (instancetype)initWithDictionary:(NSDictionary *)dictionary;
@end

@interface FxGripToggleParameter (FxGripChoiceParameterTests)
- (BOOL)valueAtTime:(CMTime)renderTime;
- (void)setValue:(BOOL)value atTime:(CMTime)time;
@end

@interface FxGripFontMenuParameter (FxGripChoiceParameterTests)
- (nullable NSString *)valueAtTime:(CMTime)renderTime;
@end

static const FxParameterId kChoiceTestParameter = 41;

@interface FxGripChoiceParameterTests : XCTestCase
@property (nonatomic, strong) FxGripParamClassTestEffect *effect;
@end

@implementation FxGripChoiceParameterTests

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
	NSDictionary *config = FxGripParamClassTestConfig(kChoiceTestParameter, type, @"Mode", extra);
	return [parameterClass addParameter:config toEffect:(id)self.effect];
}

- (id)makeParameter:(Class)parameterClass type:(NSString *)type
{
	NSDictionary *config = FxGripParamClassTestConfig(kChoiceTestParameter, type, @"Mode", nil);
	return [[parameterClass alloc] initWithDictionary:config effect:(id)self.effect];
}

#pragma mark Type identity

- (void)testEachChoiceClassReportsItsFxPlugTypeAndTypeString
{
	XCTAssertEqual(FxGripMenuParameter.parameterType, FxParameterType_Menu);
	XCTAssertEqualObjects(FxGripMenuParameter.parameterTypeString, kFxParameterType_Menu);

	XCTAssertEqual(FxGripFontMenuParameter.parameterType, FxParameterType_FontMenu);
	XCTAssertEqualObjects(FxGripFontMenuParameter.parameterTypeString, kFxParameterType_FontMenu);

	XCTAssertEqual(FxGripStringParameterBase.parameterType, FxParameterType_String);
	XCTAssertEqualObjects(FxGripStringParameterBase.parameterTypeString, kFxParameterType_String);

	XCTAssertEqual(FxGripStringParameter.parameterType, FxParameterType_String);
	XCTAssertEqualObjects(FxGripStringParameter.parameterTypeString, kFxParameterType_String);

	XCTAssertEqual(FxGripToggleParameter.parameterType, FxParameterType_Toggle);
	XCTAssertEqualObjects(FxGripToggleParameter.parameterTypeString, kFxParameterType_Toggle);
}

#pragma mark Menu

- (void)testMenuForwardsTheEntriesAndTheDefaultIndex
{
	NSArray *items = @[@"One", @"Two", @"Three"];
	NSDictionary *extra = @{kFxParameterProperty_MenuItems: items,
							kFxParameterProperty_Default: @2};

	XCTAssertTrue([self add:FxGripMenuParameter.class type:kFxParameterType_Menu extra:extra]);

	XCTAssertEqualObjects(self.call, (@{@"method": @"menu",
										@"name": @"Mode",
										@"id": @(kChoiceTestParameter),
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

- (void)testTheInitializerCapturesTheItemList
{
	NSArray *items = @[@"One", @"Two"];
	NSDictionary *config = FxGripParamClassTestConfig(kChoiceTestParameter, kFxParameterType_Menu, @"Mode",
												  @{kFxParameterProperty_MenuItems: items});

	FxGripMenuParameter *parameter = [FxGripMenuParameter.alloc initWithDictionary:config effect:(id)self.effect];

	XCTAssertNotNil(parameter);
	XCTAssertEqualObjects(parameter.parameterMenuItems, items);
	XCTAssertEqualObjects((id)parameter.effect, self.effect);
}

- (void)testTheInitializerLeavesTheItemListEmptyForAMenuWithoutEntries
{
	NSDictionary *config = FxGripParamClassTestConfig(kChoiceTestParameter, kFxParameterType_Menu, @"Mode", nil);

	FxGripMenuParameter *parameter = [FxGripMenuParameter.alloc initWithDictionary:config effect:(id)self.effect];

	XCTAssertEqualObjects(parameter.parameterMenuItems, @[]);
}

#pragma mark Font menu

- (void)testFontMenuForwardsTheDeclaredFontName
{
	NSDictionary *extra = @{kFxParameterProperty_Default: @"Futura"};

	XCTAssertTrue([self add:FxGripFontMenuParameter.class type:kFxParameterType_FontMenu extra:extra]);

	XCTAssertEqualObjects(self.call, (@{@"method": @"font",
										@"name": @"Mode",
										@"id": @(kChoiceTestParameter),
										@"default": @"Futura",
										@"flags": @(kFxParameterFlag_DEFAULT)}));
}

- (void)testFontMenuFallsBackToTheEffectDefaultFontName
{
	self.effect.defaultFontName = @"Optima";

	XCTAssertTrue([self add:FxGripFontMenuParameter.class type:kFxParameterType_FontMenu extra:nil]);

	XCTAssertEqualObjects(self.call[@"default"], @"Optima");
}

- (void)testFontMenuReportsAHostRefusal
{
	self.effect.apiManager.paramCreateAPIv5.succeeds = NO;

	XCTAssertFalse([self add:FxGripFontMenuParameter.class type:kFxParameterType_FontMenu extra:nil]);
}

- (void)testFontMenuValueAtTimeReadsTheFontNameFromTheRetrievalAPI
{
	FxGripFontMenuParameter *parameter = [self makeParameter:FxGripFontMenuParameter.class
													   type:kFxParameterType_FontMenu];
	self.effect.apiManager.paramGetAPIv6.fontName = @"Baskerville";

	XCTAssertEqualObjects([parameter valueAtTime:FxGripParamClassTestTime(4, 30)], @"Baskerville");
	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.lastRead[@"accessor"], @"font");
	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.lastRead[@"timevalue"], @4);
}

- (void)testFontMenuValueAtTimeIsNilWhenTheReadFails
{
	FxGripFontMenuParameter *parameter = [self makeParameter:FxGripFontMenuParameter.class
													   type:kFxParameterType_FontMenu];
	self.effect.apiManager.paramGetAPIv6.succeeds = NO;
	self.effect.apiManager.paramGetAPIv6.fontName = @"Baskerville";

	XCTAssertNil([parameter valueAtTime:FxGripParamClassTestTime(0, 1)]);
}

#pragma mark String creation

- (void)testStringWithoutADefaultSendsAnEmptyString
{
	XCTAssertTrue([self add:FxGripStringParameter.class type:kFxParameterType_String extra:nil]);

	XCTAssertEqualObjects(self.call, (@{@"method": @"string",
										@"name": @"Mode",
										@"id": @(kChoiceTestParameter),
										@"default": @"",
										@"flags": @(kFxParameterFlag_DEFAULT)}));
}

- (void)testStringRendersANumericDefaultAsText
{
	NSDictionary *extra = @{kFxParameterProperty_Default: @42};

	XCTAssertTrue([self add:FxGripStringParameter.class type:kFxParameterType_String extra:extra]);

	XCTAssertEqualObjects(self.call[@"default"], @"42");
}

- (void)testStringForwardsAStringDefault
{
	NSDictionary *extra = @{kFxParameterProperty_Default: @"Hello"};

	XCTAssertTrue([self add:FxGripStringParameter.class type:kFxParameterType_String extra:extra]);

	XCTAssertEqualObjects(self.call[@"default"], @"Hello");
}

- (void)testStringReportsAHostRefusal
{
	self.effect.apiManager.paramCreateAPIv5.succeeds = NO;

	XCTAssertFalse([self add:FxGripStringParameter.class type:kFxParameterType_String extra:nil]);
}

/*! The base class declares no creation; the abstract implementation refuses. */
- (void)testTheStringBaseClassHasNoCreationOfItsOwn
{
	NSDictionary *config = FxGripParamClassTestConfig(kChoiceTestParameter, kFxParameterType_String, @"Mode", nil);

	XCTAssertThrowsSpecificNamed([FxGripStringParameterBase addParameter:config toEffect:(id)self.effect],
								 NSException,
								 NSInternalInconsistencyException);
}

#pragma mark String values

- (FxGripStringParameter *)makeStringParameter
{
	return [self makeParameter:FxGripStringParameter.class type:kFxParameterType_String];
}

- (void)testStringValueReadsFromTheRetrievalAPI
{
	FxGripStringParameter *parameter = [self makeStringParameter];
	self.effect.apiManager.paramGetAPIv6.stringValue = @"Caption";

	XCTAssertEqualObjects(parameter.stringValue, @"Caption");
	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.lastRead[@"accessor"], @"string");
	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.lastRead[@"id"], @(kChoiceTestParameter));
}

- (void)testStringValueAtTimeIsTheSameReadAsTheStringValue
{
	FxGripStringParameter *parameter = [self makeStringParameter];
	self.effect.apiManager.paramGetAPIv6.stringValue = @"Caption";

	XCTAssertEqualObjects([parameter valueAtTime:FxGripParamClassTestTime(9, 30)], @"Caption");
}

- (void)testSettingTheStringValueWritesThroughTheSettingAPI
{
	FxGripStringParameter *parameter = [self makeStringParameter];

	parameter.stringValue = @"Caption";

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.lastWrite,
						  (@{@"accessor": @"string",
							 @"id": @(kChoiceTestParameter),
							 @"value": @"Caption"}));
}

- (void)testANilStringValueIsWrittenAsTheEmptyString
{
	FxGripStringParameter *parameter = [self makeStringParameter];

	parameter.stringValue = nil;

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.lastWrite[@"value"], @"");
}

- (void)testSetValueAtTimeWritesTheSameStringAsTheSetter
{
	FxGripStringParameter *parameter = [self makeStringParameter];

	[parameter setValue:@"Caption" atTime:FxGripParamClassTestTime(0, 1)];

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.lastWrite[@"value"], @"Caption");
}

#pragma mark Toggle

- (void)testToggleWithoutADefaultIsOff
{
	XCTAssertTrue([self add:FxGripToggleParameter.class type:kFxParameterType_Toggle extra:nil]);

	XCTAssertEqualObjects(self.call, (@{@"method": @"toggle",
										@"name": @"Mode",
										@"id": @(kChoiceTestParameter),
										@"default": @NO,
										@"flags": @(kFxParameterFlag_DEFAULT)}));
}

- (void)testToggleForwardsATrueDefault
{
	NSDictionary *extra = @{kFxParameterProperty_Default: @YES};

	XCTAssertTrue([self add:FxGripToggleParameter.class type:kFxParameterType_Toggle extra:extra]);

	XCTAssertEqualObjects(self.call[@"default"], @YES);
}

- (void)testToggleReadsANonZeroNumberAsTrue
{
	NSDictionary *extra = @{kFxParameterProperty_Default: @3};

	XCTAssertTrue([self add:FxGripToggleParameter.class type:kFxParameterType_Toggle extra:extra]);

	XCTAssertEqualObjects(self.call[@"default"], @YES);
}

- (void)testToggleReportsAHostRefusal
{
	self.effect.apiManager.paramCreateAPIv5.succeeds = NO;

	XCTAssertFalse([self add:FxGripToggleParameter.class type:kFxParameterType_Toggle extra:nil]);
}

- (FxGripToggleParameter *)makeToggleParameter
{
	return [self makeParameter:FxGripToggleParameter.class type:kFxParameterType_Toggle];
}

- (void)testToggleValueAtTimeReadsTheBoolFromTheRetrievalAPI
{
	FxGripToggleParameter *parameter = [self makeToggleParameter];
	self.effect.apiManager.paramGetAPIv6.boolValue = YES;

	XCTAssertTrue([parameter valueAtTime:FxGripParamClassTestTime(6, 30)]);
	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.lastRead[@"accessor"], @"bool");
	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.lastRead[@"timevalue"], @6);
}

- (void)testToggleValueAtTimeIsFalseWhenTheReadFails
{
	FxGripToggleParameter *parameter = [self makeToggleParameter];
	self.effect.apiManager.paramGetAPIv6.boolValue = YES;
	self.effect.apiManager.paramGetAPIv6.succeeds = NO;

	XCTAssertFalse([parameter valueAtTime:FxGripParamClassTestTime(0, 1)]);
}

- (void)testTheToggleBoolValueReadsAtTheZeroTime
{
	FxGripToggleParameter *parameter = [self makeToggleParameter];
	self.effect.apiManager.paramGetAPIv6.boolValue = YES;

	XCTAssertTrue(parameter.boolValue);
	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.lastRead[@"timevalue"], @0);
}

- (void)testSettingTheToggleBoolValueWritesAtTheZeroTime
{
	FxGripToggleParameter *parameter = [self makeToggleParameter];

	parameter.boolValue = YES;

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.lastWrite,
						  (@{@"accessor": @"bool",
							 @"id": @(kChoiceTestParameter),
							 @"value": @YES,
							 @"timevalue": @0}));
}

- (void)testToggleSetValueAtTimeCarriesTheRequestedTime
{
	FxGripToggleParameter *parameter = [self makeToggleParameter];

	[parameter setValue:NO atTime:FxGripParamClassTestTime(12, 30)];

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.lastWrite[@"value"], @NO);
	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.lastWrite[@"timevalue"], @12);
}

@end
