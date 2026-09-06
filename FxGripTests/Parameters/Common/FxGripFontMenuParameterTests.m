//
//  FxGripFontMenuParameterTests.m
//  FxGripTests
//
//  Unit tests for FxGripFontMenuParameter: the type identity, the payload
//  +addParameter:toEffect: derives from a configuration, the fallback to the effect default
//  font name, the host-refusal result, and the font name -valueAtTime: reads from the
//  retrieval API.
//

#import <XCTest/XCTest.h>
#import "FxGripParameterClassTestSupport.h"
#import <FxGrip/FxGripFontMenuParameter.h>

// Declared in the implementation rather than the public header.
@interface FxGripFontMenuParameter (FxGripFontMenuParameterTests)
- (nullable NSString *)valueAtTime:(CMTime)renderTime;
@end

static const FxParameterId kFontMenuTestParameter = 41;

@interface FxGripFontMenuParameterTests : XCTestCase
@property (nonatomic, strong) FxGripParamClassTestEffect *effect;
@end

@implementation FxGripFontMenuParameterTests

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
	NSDictionary *config = FxGripParamClassTestConfig(kFontMenuTestParameter, type, @"Mode", extra);
	return [parameterClass addParameter:config toEffect:(id)self.effect];
}

- (id)makeParameter:(Class)parameterClass type:(NSString *)type
{
	NSDictionary *config = FxGripParamClassTestConfig(kFontMenuTestParameter, type, @"Mode", nil);
	return [[parameterClass alloc] initWithDictionary:config effect:(id)self.effect];
}

#pragma mark Type identity

- (void)testReportsItsFxPlugTypeAndTypeString
{
	XCTAssertEqual(FxGripFontMenuParameter.parameterType, FxParameterType_FontMenu);
	XCTAssertEqualObjects(FxGripFontMenuParameter.parameterTypeString, kFxParameterType_FontMenu);
}

#pragma mark Creation payload

- (void)testFontMenuForwardsTheDeclaredFontName
{
	NSDictionary *extra = @{kFxParameterProperty_Default: @"Futura"};

	XCTAssertTrue([self add:FxGripFontMenuParameter.class type:kFxParameterType_FontMenu extra:extra]);

	XCTAssertEqualObjects(self.call, (@{@"method": @"font",
										@"name": @"Mode",
										@"id": @(kFontMenuTestParameter),
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

#pragma mark Value

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

@end
