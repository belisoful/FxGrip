//
//  FxGripPointParameterTests.m
//  FxGripTests
//
//  Unit tests for FxGripPointParameter: the type identity, the payload
//  +addParameter:toEffect: derives from the nested, top-level, array, and string default
//  forms, and the value plumbing through the retrieval and setting APIs.
//

#import <XCTest/XCTest.h>
#import "FxGripParameterClassTestSupport.h"
#import <FxGrip/FxGripPointParameter.h>

static const FxParameterId kPointTestParameter = 31;

@interface FxGripPointParameterTests : XCTestCase
@property (nonatomic, strong) FxGripParamClassTestEffect *effect;
@end

@implementation FxGripPointParameterTests

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
	NSDictionary *config = FxGripParamClassTestConfig(kPointTestParameter, type, @"Tint", extra);
	return [parameterClass addParameter:config toEffect:(id)self.effect];
}

- (FxGripPointParameter *)makePointParameter
{
	NSDictionary *config = FxGripParamClassTestConfig(kPointTestParameter, kFxParameterType_Point, @"Center", nil);
	return [FxGripPointParameter.alloc initWithDictionary:config effect:(id)self.effect];
}

#pragma mark Type identity

- (void)testReportsItsFxPlugTypeAndTypeString
{
	XCTAssertEqual(FxGripPointParameter.parameterType, FxParameterType_Point);
	XCTAssertEqualObjects(FxGripPointParameter.parameterTypeString, kFxParameterType_Point);
}

#pragma mark Creation

- (void)testPointWithoutADefaultCentersTheParameter
{
	XCTAssertTrue([self add:FxGripPointParameter.class type:kFxParameterType_Point extra:nil]);

	XCTAssertEqualObjects(self.call, (@{@"method": @"point",
										@"name": @"Tint",
										@"id": @(kPointTestParameter),
										@"x": @0.5,
										@"y": @0.5,
										@"flags": @(kFxParameterFlag_DEFAULT)}));
}

- (void)testPointForwardsBothCoordinatesOfTheNestedDefault
{
	NSDictionary *point = @{kFxParameterProperty_X: @0.25, kFxParameterProperty_Y: @0.75};
	NSDictionary *extra = @{kFxParameterProperty_Default: point};

	XCTAssertTrue([self add:FxGripPointParameter.class type:kFxParameterType_Point extra:extra]);

	XCTAssertEqualObjects(self.call[@"x"], @0.25);
	XCTAssertEqualObjects(self.call[@"y"], @0.75);
}

/*!
	A nested default record answers zero for the coordinate it omits, so declaring one
	coordinate moves the other to the origin rather than leaving it centered.
*/
- (void)testAHalfDeclaredPointDefaultZeroesTheUndeclaredCoordinate
{
	NSDictionary *extra = @{kFxParameterProperty_Default: @{kFxParameterProperty_X: @0.25}};

	XCTAssertTrue([self add:FxGripPointParameter.class type:kFxParameterType_Point extra:extra]);

	XCTAssertEqualObjects(self.call[@"x"], @0.25);
	XCTAssertEqualObjects(self.call[@"y"], @0.0);
}

- (void)testTopLevelCoordinateKeysSupplyTheDefault
{
	NSDictionary *extra = @{kFxParameterProperty_X: @0.25, kFxParameterProperty_Y: @0.75};

	XCTAssertTrue([self add:FxGripPointParameter.class type:kFxParameterType_Point extra:extra]);

	XCTAssertEqualObjects(self.call[@"x"], @0.25);
	XCTAssertEqualObjects(self.call[@"y"], @0.75);
}

/*! A lone declared coordinate is honored; the undeclared one reads as zero. */
- (void)testATopLevelYWithoutAnXSuppliesTheYDefault
{
	NSDictionary *extra = @{kFxParameterProperty_Y: @0.75};

	XCTAssertTrue([self add:FxGripPointParameter.class type:kFxParameterType_Point extra:extra]);

	XCTAssertEqualObjects(self.call[@"x"], @0);
	XCTAssertEqualObjects(self.call[@"y"], @0.75);
}

- (void)testAnArrayPointDefaultIsReadInOrder
{
	NSDictionary *extra = @{kFxParameterProperty_Default: @[@0.25, @0.75]};

	XCTAssertTrue([self add:FxGripPointParameter.class type:kFxParameterType_Point extra:extra]);

	XCTAssertEqualObjects(self.call[@"x"], @0.25);
	XCTAssertEqualObjects(self.call[@"y"], @0.75);
}

/*! A whitespace separated string default names the coordinates in the same order. */
- (void)testAStringPointDefaultIsSplitIntoCoordinates
{
	NSDictionary *extra = @{kFxParameterProperty_Default: @"0.25 0.75"};

	XCTAssertTrue([self add:FxGripPointParameter.class type:kFxParameterType_Point extra:extra]);

	XCTAssertEqualObjects(self.call[@"x"], @0.25);
	XCTAssertEqualObjects(self.call[@"y"], @0.75);
}

- (void)testPointReportsAHostRefusal
{
	self.effect.apiManager.paramCreateAPIv5.succeeds = NO;

	XCTAssertFalse([self add:FxGripPointParameter.class type:kFxParameterType_Point extra:nil]);
}

#pragma mark Values

- (void)testPointValueAtTimeReadsBothCoordinates
{
	FxGripPointParameter *parameter = [self makePointParameter];
	self.effect.apiManager.paramGetAPIv6.x = 0.3;
	self.effect.apiManager.paramGetAPIv6.y = 0.6;

	FxGripPoint point = [parameter valueAtTime:FxGripParamClassTestTime(5, 30)];

	XCTAssertEqual(point.x, 0.3);
	XCTAssertEqual(point.y, 0.6);
	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.lastRead[@"accessor"], @"point");
}

- (void)testPointValueAtTimeIsTheOriginWhenTheReadFails
{
	FxGripPointParameter *parameter = [self makePointParameter];
	self.effect.apiManager.paramGetAPIv6.succeeds = NO;
	self.effect.apiManager.paramGetAPIv6.x = 0.3;

	FxGripPoint point = [parameter valueAtTime:FxGripParamClassTestTime(0, 1)];

	XCTAssertEqual(point.x, 0.0);
	XCTAssertEqual(point.y, 0.0);
}

- (void)testPointSetValueWritesBothCoordinates
{
	FxGripPointParameter *parameter = [self makePointParameter];
	FxGripPoint point = { .x = 0.2, .y = 0.8 };

	[parameter setValue:&point atTime:FxGripParamClassTestTime(0, 1)];

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.lastWrite,
						  (@{@"accessor": @"point",
							 @"id": @(kPointTestParameter),
							 @"x": @0.2,
							 @"y": @0.8}));
}

- (void)testPointSetValueIgnoresANullPoint
{
	FxGripPointParameter *parameter = [self makePointParameter];

	[parameter setValue:NULL atTime:FxGripParamClassTestTime(0, 1)];

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.writes, @[]);
}

- (void)testPointSetXValueYValueWritesTheCoordinatesDirectly
{
	FxGripPointParameter *parameter = [self makePointParameter];

	[parameter setXValue:0.4 YValue:0.9 atTime:FxGripParamClassTestTime(0, 1)];

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.lastWrite[@"x"], @0.4);
	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.lastWrite[@"y"], @0.9);
}

@end
