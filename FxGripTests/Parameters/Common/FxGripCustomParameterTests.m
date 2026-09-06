//
//  FxGripCustomParameterTests.m
//  FxGripTests
//
//  Unit tests for FxGripCustomParameter: the type identity, the fresh empty dictionary the
//  creation hands the API, the codable data classes it accepts, the value plumbing through
//  the retrieval and version-six setting APIs, and the subclass data-initialization hook.
//

#import <XCTest/XCTest.h>
#import "FxGripParameterClassTestSupport.h"
#import <FxGrip/FxGripCustomParameter.h>

// Implemented as the subclass hook but absent from the public header.
@interface FxGripCustomParameter (FxGripCustomParameterTests)
- (void)initializeCustomData:(NSObject<NSSecureCoding, NSCopying> *_Nullable *_Nonnull)customDefaultValue
				 parameterID:(FxParameterId)parameterID;
@end

static const FxParameterId kCustomTestParameter = 51;

@interface FxGripCustomParameterTests : XCTestCase
@property (nonatomic, strong) FxGripParamClassTestEffect *effect;
@end

@implementation FxGripCustomParameterTests

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
	NSDictionary *config = FxGripParamClassTestConfig(kCustomTestParameter, type, @"Levels", extra);
	return [parameterClass addParameter:config toEffect:(id)self.effect];
}

- (FxGripCustomParameter *)makeCustomParameter
{
	NSDictionary *config = FxGripParamClassTestConfig(kCustomTestParameter, kFxParameterType_Custom, @"Levels", nil);
	return [FxGripCustomParameter.alloc initWithDictionary:config effect:(id)self.effect];
}

#pragma mark Type identity

- (void)testReportsItsFxPlugTypeAndTypeString
{
	XCTAssertEqual(FxGripCustomParameter.parameterType, FxParameterType_Custom);
	XCTAssertEqualObjects(FxGripCustomParameter.parameterTypeString, kFxParameterType_Custom);
}

#pragma mark Creation payload

- (void)testCustomSendsAFreshEmptyDictionaryAsItsDefault
{
	XCTAssertTrue([self add:FxGripCustomParameter.class type:kFxParameterType_Custom extra:nil]);

	XCTAssertEqualObjects(self.call[@"method"], @"custom");
	XCTAssertEqualObjects(self.call[@"default"], NSMutableDictionary.new);
	XCTAssertTrue([self.call[@"default"] isKindOfClass:NSMutableDictionary.class]);
}

/*! The custom creation ignores any declared default, so the host always sees the empty record. */
- (void)testCustomIgnoresADeclaredDefault
{
	NSDictionary *extra = @{kFxParameterProperty_Default: @{@"seed": @7}};

	XCTAssertTrue([self add:FxGripCustomParameter.class type:kFxParameterType_Custom extra:extra]);

	XCTAssertEqualObjects(self.call[@"default"], NSMutableDictionary.new);
}

- (void)testReportsAHostRefusal
{
	self.effect.apiManager.paramCreateAPIv5.succeeds = NO;

	XCTAssertFalse([self add:FxGripCustomParameter.class type:kFxParameterType_Custom extra:nil]);
}

#pragma mark Values

- (void)testTheCustomParameterAdvertisesTheCodableDataClassesItAccepts
{
	NSSet<Class> *classes = [self makeCustomParameter].dataClasses;

	XCTAssertTrue([classes containsObject:NSMutableDictionary.class]);
	XCTAssertTrue([classes containsObject:NSString.class]);
	XCTAssertTrue([classes containsObject:NSNumber.class]);
	XCTAssertTrue([classes containsObject:NSUUID.class]);
	XCTAssertTrue([classes containsObject:NSClassFromString(@"FxGripInterpolatingDictionary")]);
	XCTAssertFalse([classes containsObject:XCTestCase.class]);
}

- (void)testCustomValueAtTimeReturnsWhatTheRetrievalAPIProvides
{
	FxGripCustomParameter *parameter = [self makeCustomParameter];
	NSDictionary *stored = @{@"seed": @7};
	self.effect.apiManager.paramGetAPIv6.customValue = stored;

	XCTAssertEqualObjects([parameter valueAtTime:FxGripParamClassTestTime(3, 30)], stored);
	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.lastRead[@"accessor"], @"custom");
	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.lastRead[@"timevalue"], @3);
}

- (void)testTheCustomValueAccessorReadsAtTheZeroTime
{
	FxGripCustomParameter *parameter = [self makeCustomParameter];
	self.effect.apiManager.paramGetAPIv6.customValue = @"stored";

	XCTAssertEqualObjects(parameter.value, @"stored");
	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.lastRead[@"timevalue"], @0);
}

- (void)testCustomValueAtTimeIsNilWhenTheReadFails
{
	FxGripCustomParameter *parameter = [self makeCustomParameter];
	self.effect.apiManager.paramGetAPIv6.customValue = @"stored";
	self.effect.apiManager.paramGetAPIv6.succeeds = NO;

	XCTAssertNil([parameter valueAtTime:FxGripParamClassTestTime(0, 1)]);
}

- (void)testSettingTheCustomValueWritesThroughTheVersionSixSettingAPI
{
	FxGripCustomParameter *parameter = [self makeCustomParameter];

	[parameter setValue:@"stored" atTime:FxGripParamClassTestTime(5, 30)];

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv6.lastWrite,
						  (@{@"accessor": @"custom",
							 @"id": @(kCustomTestParameter),
							 @"value": @"stored",
							 @"timevalue": @5}));
}

- (void)testTheCustomValueSetterWritesAtTheZeroTime
{
	FxGripCustomParameter *parameter = [self makeCustomParameter];

	parameter.value = @"stored";

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv6.lastWrite[@"timevalue"], @0);
}

- (void)testTheCustomDataInitializationHookLeavesTheValueUntouched
{
	FxGripCustomParameter *parameter = [self makeCustomParameter];
	NSObject<NSSecureCoding, NSCopying> *value = nil;

	[parameter initializeCustomData:&value parameterID:kCustomTestParameter];

	XCTAssertNil(value, @"the base hook is the subclass extension point and stages nothing");
}

@end
