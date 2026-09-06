//
//  FxGripInterpolatingDictionaryTests.m
//  FxGripTests
//

#import <XCTest/XCTest.h>
#import <FxPlug/FxTypes.h>

// FxGripDictionary.h is not a public framework header, so the surface under test is
// re-declared locally.
#define kCustomAPI_ExemptKeysKey			@"exemptKeys"
#define kCustomAPI_LastChangedKey			@"__lastChangedKey"
#define kInterpolatingDictionaryNonePrefix	@"_"

@interface FxGripDictionary : NSMutableDictionary
@property (strong, readonly) NSMutableDictionary *data;
@property (assign, readonly) NSMutableArray *exemptKeys;
- (instancetype)initWithDictionary:(NSDictionary *)dictionary;
@end

@interface FxGripInterpolatingDictionary : FxGripDictionary
- (NSObject<NSSecureCoding, NSCopying> *)interpolateBetween:(NSObject<NSSecureCoding, NSCopying> *)rightValue
												 withWeight:(float)weight;
- (id)interpolateValue:(id)left rightValue:(id)right withWeight:(float)weight;
- (id)interpolateValue:(id)left rightValue:(id)right path:(NSString *)path withWeight:(float)weight;
- (id)customInterpolateValue:(id)left rightValue:(id)right path:(NSString *)path withWeight:(float)weight;
@end


@interface FxGripInterpolatingDictionaryTests : XCTestCase
@property (nonatomic, strong) FxGripInterpolatingDictionary *dict;
@end

@implementation FxGripInterpolatingDictionaryTests

- (void)setUp
{
	[super setUp];
	self.dict = [FxGripInterpolatingDictionary.alloc init];
}

- (void)tearDown
{
	self.dict = nil;
	[super tearDown];
}

#pragma mark - Inheritance

- (void)testTheInterpolatingDictionaryIsAnFxGripDictionary
{
	XCTAssertTrue([self.dict isKindOfClass:FxGripDictionary.class]);
	XCTAssertTrue([FxGripInterpolatingDictionary supportsSecureCoding]);
}

- (void)testTheKeyedStoreStillWorks
{
	[self.dict setObject:@(1) forKey:@"a"];

	XCTAssertEqualObjects([self.dict objectForKey:@"a"], @(1));
	XCTAssertEqual(self.dict.count, 1u);
}

#pragma mark - Exempt Keys

- (void)testExemptKeysSeedsTheReservedKeysAndWritesItselfBack
{
	NSMutableArray *exempt = self.dict.exemptKeys;

	XCTAssertEqualObjects(exempt, (@[kCustomAPI_ExemptKeysKey, kCustomAPI_LastChangedKey]));
	XCTAssertEqualObjects([self.dict objectForKey:kCustomAPI_ExemptKeysKey], exempt);
}

- (void)testExemptKeysIsIdempotent
{
	NSMutableArray *first = self.dict.exemptKeys;
	NSMutableArray *second = self.dict.exemptKeys;

	XCTAssertEqualObjects(first, second);
	XCTAssertEqual(second.count, 2u);
}

- (void)testExemptKeysPreservesCallerSuppliedEntries
{
	[self.dict setObject:@[@"mine"] forKey:kCustomAPI_ExemptKeysKey];

	XCTAssertEqualObjects(self.dict.exemptKeys, (@[@"mine", kCustomAPI_ExemptKeysKey, kCustomAPI_LastChangedKey]));
}

- (void)testExemptKeysWrapsANonArrayValue
{
	[self.dict setObject:@"solo" forKey:kCustomAPI_ExemptKeysKey];

	XCTAssertEqualObjects(self.dict.exemptKeys, (@[@"solo", kCustomAPI_ExemptKeysKey, kCustomAPI_LastChangedKey]));
}

- (void)testExemptKeysUpgradesAnImmutableArrayInPlace
{
	[self.dict setObject:@[@"mine"] forKey:kCustomAPI_ExemptKeysKey];

	NSMutableArray *exempt = self.dict.exemptKeys;
	[exempt addObject:@"later"];

	XCTAssertEqualObjects([self.dict objectForKey:kCustomAPI_ExemptKeysKey], exempt);
}

#pragma mark - Scalar Interpolation

- (void)testMismatchedOperandClassesInterpolateToNil
{
	XCTAssertNil([self.dict interpolateValue:@"text" rightValue:@(1) withWeight:0.5f]);
}

- (void)testTwoNilOperandsInterpolateToNil
{
	XCTAssertNil([self.dict interpolateValue:nil rightValue:nil withWeight:0.5f]);
}

- (void)testDoublesInterpolateLinearly
{
	XCTAssertEqualObjects([self.dict interpolateValue:@(0.0) rightValue:@(10.0) withWeight:0.25f], @(2.5));
	XCTAssertEqualObjects([self.dict interpolateValue:@(0.0) rightValue:@(10.0) withWeight:0.0f], @(0.0));
	XCTAssertEqualObjects([self.dict interpolateValue:@(0.0) rightValue:@(10.0) withWeight:1.0f], @(10.0));
}

- (void)testWeightsOutsideZeroToOneExtrapolate
{
	XCTAssertEqualObjects([self.dict interpolateValue:@(0.0) rightValue:@(10.0) withWeight:2.0f], @(20.0));
	XCTAssertEqualObjects([self.dict interpolateValue:@(0.0) rightValue:@(10.0) withWeight:-1.0f], @(-10.0));
}

- (void)testFloatsInterpolateAtFloatPrecision
{
	NSNumber *left = [NSNumber numberWithFloat:1.0f];
	NSNumber *right = [NSNumber numberWithFloat:2.0f];

	NSNumber *result = [self.dict interpolateValue:left rightValue:right withWeight:0.5f];

	XCTAssertEqualWithAccuracy(result.floatValue, 1.5f, 1e-6);
}

- (void)testIntegersInterpolateWithRounding
{
	XCTAssertEqualObjects([self.dict interpolateValue:@(0) rightValue:@(11) withWeight:0.5f], @(6));
	XCTAssertEqualObjects([self.dict interpolateValue:@(0) rightValue:@(10) withWeight:0.5f], @(5));
	XCTAssertEqualObjects([self.dict interpolateValue:@(10) rightValue:@(0) withWeight:0.25f], @(7),
						  @"round() breaks the -2.5 tie away from zero");
}

- (void)testShortsInterpolateWithRounding
{
	NSNumber *left = [NSNumber numberWithShort:0];
	NSNumber *right = [NSNumber numberWithShort:10];

	XCTAssertEqual([[self.dict interpolateValue:left rightValue:right withWeight:0.5f] shortValue], (short)5);
}

- (void)testLongLongsInterpolateWithRounding
{
	NSNumber *left = [NSNumber numberWithLongLong:3];
	NSNumber *right = [NSNumber numberWithLongLong:13];

	XCTAssertEqual([[self.dict interpolateValue:left rightValue:right withWeight:0.5f] longLongValue], 8LL);
}

/*!
	Booleans are stored as CFNumber char values and are deliberately not blended; the left
	operand is returned unchanged so a toggle never lands between states.
*/
- (void)testBooleansHoldTheLeftOperand
{
	XCTAssertEqualObjects([self.dict interpolateValue:@(YES) rightValue:@(NO) withWeight:0.9f], @(YES));
	XCTAssertEqualObjects([self.dict interpolateValue:@(NO) rightValue:@(YES) withWeight:0.9f], @(NO));
}

- (void)testStringsCopyTheLeftOperand
{
	NSMutableString *left = [NSMutableString stringWithString:@"left"];
	NSMutableString *right = [NSMutableString stringWithString:@"right"];

	id result = [self.dict interpolateValue:left rightValue:right withWeight:0.5f];

	XCTAssertEqualObjects(result, @"left");
}

- (void)testAnUninterpolatableClassCopiesTheLeftOperand
{
	NSDate *left = [NSDate dateWithTimeIntervalSince1970:0];
	NSDate *right = [NSDate dateWithTimeIntervalSince1970:100];

	XCTAssertEqualObjects([self.dict interpolateValue:left rightValue:right withWeight:0.5f], left);
}

- (void)testCustomInterpolateValueIsANilHookByDefault
{
	XCTAssertNil([self.dict customInterpolateValue:@(1.0) rightValue:@(2.0) path:@"/a" withWeight:0.5f]);
}

#pragma mark - Container Interpolation

- (void)testArraysInterpolateElementwise
{
	NSArray *left = @[@(0.0), @(0.0)];
	NSArray *right = @[@(2.0), @(4.0)];

	XCTAssertEqualObjects([self.dict interpolateValue:left rightValue:right withWeight:0.5f], (@[@(1.0), @(2.0)]));
}

- (void)testArrayInterpolationIsDrivenByTheLeftOperandAndDropsUnpairedElements
{
	NSArray *left = @[@(0.0), @(0.0), @(0.0)];
	NSArray *right = @[@(2.0)];

	XCTAssertEqualObjects([self.dict interpolateValue:left rightValue:right withWeight:0.5f], (@[@(1.0)]));
}

- (void)testNestedArraysInterpolateRecursively
{
	NSArray *left = @[@[@(0.0), @(0.0)]];
	NSArray *right = @[@[@(4.0), @(8.0)]];

	XCTAssertEqualObjects([self.dict interpolateValue:left rightValue:right withWeight:0.25f], (@[@[@(1.0), @(2.0)]]));
}

- (void)testDictionariesInterpolateByKey
{
	NSDictionary *left = @{@"a": @(0.0), @"b": @(10.0)};
	NSDictionary *right = @{@"a": @(4.0), @"b": @(20.0)};

	XCTAssertEqualObjects([self.dict interpolateValue:left rightValue:right withWeight:0.5f],
						  (@{@"a": @(2.0), @"b": @(15.0)}));
}

- (void)testDictionaryKeysPrefixedWithUnderscoreAreDropped
{
	NSDictionary *left = @{@"a": @(0.0), @"_b": @(0.0)};
	NSDictionary *right = @{@"a": @(4.0), @"_b": @(4.0)};

	XCTAssertEqualObjects([self.dict interpolateValue:left rightValue:right withWeight:0.25f], (@{@"a": @(1.0)}));
}

- (void)testKeysMissingFromTheRightOperandAreDropped
{
	NSDictionary *left = @{@"a": @(0.0), @"orphan": @(1.0)};
	NSDictionary *right = @{@"a": @(4.0)};

	XCTAssertEqualObjects([self.dict interpolateValue:left rightValue:right withWeight:0.5f], (@{@"a": @(2.0)}));
}

#pragma mark - Exempt Paths

- (void)testAnExemptPathCopiesTheLeftOperandInsteadOfBlending
{
	[self.dict setObject:[@[@"/locked"] mutableCopy] forKey:kCustomAPI_ExemptKeysKey];

	id result = [self.dict interpolateValue:@(0.0) rightValue:@(10.0) path:@"/locked" withWeight:0.5f];

	XCTAssertEqualObjects(result, @(0.0));
}

- (void)testANonExemptPathStillBlends
{
	[self.dict setObject:[@[@"/locked"] mutableCopy] forKey:kCustomAPI_ExemptKeysKey];

	XCTAssertEqualObjects([self.dict interpolateValue:@(0.0) rightValue:@(10.0) path:@"/open" withWeight:0.5f], @(5.0));
}

- (void)testNestedDictionaryPathsAreBuiltFromTheKeyNames
{
	[self.dict setObject:[@[@"/outer/inner"] mutableCopy] forKey:kCustomAPI_ExemptKeysKey];

	NSDictionary *left = @{@"outer": @{@"inner": @(0.0), @"other": @(0.0)}};
	NSDictionary *right = @{@"outer": @{@"inner": @(8.0), @"other": @(8.0)}};

	NSDictionary *result = [self.dict interpolateValue:left rightValue:right path:nil withWeight:0.5f];

	XCTAssertEqualObjects(result[@"outer"][@"inner"], @(0.0));
	XCTAssertEqualObjects(result[@"outer"][@"other"], @(4.0));
}

- (void)testArrayPathsAreBuiltFromTheElementIndex
{
	[self.dict setObject:[@[@"/1"] mutableCopy] forKey:kCustomAPI_ExemptKeysKey];

	NSArray *left = @[@(0.0), @(0.0)];
	NSArray *right = @[@(8.0), @(8.0)];

	XCTAssertEqualObjects([self.dict interpolateValue:left rightValue:right path:nil withWeight:0.5f], (@[@(4.0), @(0.0)]));
}

#pragma mark - Interpolate Between

/*!
	-interpolateBetween:withWeight: is the entry point the host calls for
	FxCustomParameterInterpolation_v2.
*/
- (void)testInterpolateBetweenBlendsTheTwoDictionaries
{
	FxGripInterpolatingDictionary *right = [FxGripInterpolatingDictionary.alloc init];
	[self.dict setObject:@(0.0) forKey:@"f"];
	[right setObject:@(10.0) forKey:@"f"];

	__block id result = nil;
	XCTAssertNoThrow(result = [self.dict interpolateBetween:right withWeight:0.5f]);
	XCTAssertNotNil(result);
	XCTAssertTrue([result isKindOfClass:FxGripInterpolatingDictionary.class]);
	XCTAssertEqualObjects([result objectForKey:@"f"], @(5.0));
}

- (void)testInterpolateBetweenReturnsTheEndpointsAtWeightZeroAndOne
{
	FxGripInterpolatingDictionary *right = [FxGripInterpolatingDictionary.alloc init];
	[self.dict setObject:@(0.0) forKey:@"f"];
	[right setObject:@(10.0) forKey:@"f"];

	id atZero = [self.dict interpolateBetween:right withWeight:0.0f];
	id atOne = [self.dict interpolateBetween:right withWeight:1.0f];

	XCTAssertEqualObjects([atZero objectForKey:@"f"], @(0.0));
	XCTAssertEqualObjects([atOne objectForKey:@"f"], @(10.0));
}

- (void)testInterpolateBetweenCopiesStringsAndDropsUnderscoreKeys
{
	FxGripInterpolatingDictionary *right = [FxGripInterpolatingDictionary.alloc init];
	[self.dict setObject:@(0.0) forKey:@"f"];
	[self.dict setObject:@"left" forKey:@"s"];
	[self.dict setObject:@(0.0) forKey:@"_skipped"];
	[right setObject:@(10.0) forKey:@"f"];
	[right setObject:@"right" forKey:@"s"];
	[right setObject:@(10.0) forKey:@"_skipped"];

	id result = [self.dict interpolateBetween:right withWeight:0.5f];

	XCTAssertEqualObjects([result objectForKey:@"f"], @(5.0));
	XCTAssertEqualObjects([result objectForKey:@"s"], @"left");
	XCTAssertNil([result objectForKey:@"_skipped"]);
	XCTAssertEqual([result count], 2u);
}

- (void)testInterpolateBetweenDropsKeysMissingFromTheRightOperand
{
	FxGripInterpolatingDictionary *right = [FxGripInterpolatingDictionary.alloc init];
	[self.dict setObject:@(0.0) forKey:@"f"];
	[self.dict setObject:@(1.0) forKey:@"orphan"];
	[right setObject:@(10.0) forKey:@"f"];

	id result = [self.dict interpolateBetween:right withWeight:0.5f];

	XCTAssertEqualObjects([result objectForKey:@"f"], @(5.0));
	XCTAssertNil([result objectForKey:@"orphan"]);
}

/*!
	-interpolateBetween:withWeight: passes a nil path for each top-level key, so the path an
	exempt entry has to match starts at the first nested key.
*/
- (void)testInterpolateBetweenHonorsAnExemptNestedPath
{
	[self.dict setObject:[@[@"/inner"] mutableCopy] forKey:kCustomAPI_ExemptKeysKey];

	FxGripInterpolatingDictionary *right = [FxGripInterpolatingDictionary.alloc init];
	[self.dict setObject:@{@"inner": @(0.0), @"other": @(0.0)} forKey:@"outer"];
	[right setObject:@{@"inner": @(8.0), @"other": @(8.0)} forKey:@"outer"];

	id result = [self.dict interpolateBetween:right withWeight:0.5f];
	NSDictionary *outer = (NSDictionary *)[result objectForKey:@"outer"];

	XCTAssertEqualObjects(outer[@"inner"], @(0.0));
	XCTAssertEqualObjects(outer[@"other"], @(4.0));
}

@end
