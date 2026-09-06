/*!
	@file       FxGripInterpolatingDictionaryTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripInterpolatingDictionaryTests
	@abstract   Tests for FxGripInterpolatingDictionary, the keyframe blend used by custom parameter interpolation.
	@discussion Introduced in FxGrip 0.1.0. The tests cover scalar interpolation across number types, container interpolation over arrays and dictionaries, the underscore-prefixed key and exempt-path rules, and the -interpolateBetween:withWeight: host entry point.
*/

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

/*! @abstract The interpolating dictionary is an FxGripDictionary and supports secure coding. */
- (void)testTheInterpolatingDictionaryIsAnFxGripDictionary
{
	XCTAssertTrue([self.dict isKindOfClass:FxGripDictionary.class]);
	XCTAssertTrue([FxGripInterpolatingDictionary supportsSecureCoding]);
}

/*! @abstract The inherited keyed store still reads and counts entries. */
- (void)testTheKeyedStoreStillWorks
{
	[self.dict setObject:@(1) forKey:@"a"];

	XCTAssertEqualObjects([self.dict objectForKey:@"a"], @(1));
	XCTAssertEqual(self.dict.count, 1u);
}

#pragma mark - Exempt Keys

/*! @abstract Reading exemptKeys seeds the two reserved keys and writes the array back under its reserved key. */
- (void)testExemptKeysSeedsTheReservedKeysAndWritesItselfBack
{
	NSMutableArray *exempt = self.dict.exemptKeys;

	XCTAssertEqualObjects(exempt, (@[kCustomAPI_ExemptKeysKey, kCustomAPI_LastChangedKey]));
	XCTAssertEqualObjects([self.dict objectForKey:kCustomAPI_ExemptKeysKey], exempt);
}

/*! @abstract Reading exemptKeys twice returns the same two-entry array without re-seeding. */
- (void)testExemptKeysIsIdempotent
{
	NSMutableArray *first = self.dict.exemptKeys;
	NSMutableArray *second = self.dict.exemptKeys;

	XCTAssertEqualObjects(first, second);
	XCTAssertEqual(second.count, 2u);
}

/*! @abstract A caller-supplied exempt array keeps its entries and gains the two reserved keys. */
- (void)testExemptKeysPreservesCallerSuppliedEntries
{
	[self.dict setObject:@[@"mine"] forKey:kCustomAPI_ExemptKeysKey];

	XCTAssertEqualObjects(self.dict.exemptKeys, (@[@"mine", kCustomAPI_ExemptKeysKey, kCustomAPI_LastChangedKey]));
}

/*! @abstract A non-array value under the exempt key is wrapped into an array alongside the reserved keys. */
- (void)testExemptKeysWrapsANonArrayValue
{
	[self.dict setObject:@"solo" forKey:kCustomAPI_ExemptKeysKey];

	XCTAssertEqualObjects(self.dict.exemptKeys, (@[@"solo", kCustomAPI_ExemptKeysKey, kCustomAPI_LastChangedKey]));
}

/*! @abstract An immutable exempt array is upgraded to a mutable one stored back under its key, so later additions persist. */
- (void)testExemptKeysUpgradesAnImmutableArrayInPlace
{
	[self.dict setObject:@[@"mine"] forKey:kCustomAPI_ExemptKeysKey];

	NSMutableArray *exempt = self.dict.exemptKeys;
	[exempt addObject:@"later"];

	XCTAssertEqualObjects([self.dict objectForKey:kCustomAPI_ExemptKeysKey], exempt);
}

#pragma mark - Scalar Interpolation

/*! @abstract Interpolating operands of mismatched classes returns nil. */
- (void)testMismatchedOperandClassesInterpolateToNil
{
	XCTAssertNil([self.dict interpolateValue:@"text" rightValue:@(1) withWeight:0.5f]);
}

/*! @abstract Interpolating two nil operands returns nil. */
- (void)testTwoNilOperandsInterpolateToNil
{
	XCTAssertNil([self.dict interpolateValue:nil rightValue:nil withWeight:0.5f]);
}

/*! @abstract Doubles interpolate linearly, returning the endpoints at weight zero and one. */
- (void)testDoublesInterpolateLinearly
{
	XCTAssertEqualObjects([self.dict interpolateValue:@(0.0) rightValue:@(10.0) withWeight:0.25f], @(2.5));
	XCTAssertEqualObjects([self.dict interpolateValue:@(0.0) rightValue:@(10.0) withWeight:0.0f], @(0.0));
	XCTAssertEqualObjects([self.dict interpolateValue:@(0.0) rightValue:@(10.0) withWeight:1.0f], @(10.0));
}

/*! @abstract Weights outside zero to one extrapolate past the endpoints. */
- (void)testWeightsOutsideZeroToOneExtrapolate
{
	XCTAssertEqualObjects([self.dict interpolateValue:@(0.0) rightValue:@(10.0) withWeight:2.0f], @(20.0));
	XCTAssertEqualObjects([self.dict interpolateValue:@(0.0) rightValue:@(10.0) withWeight:-1.0f], @(-10.0));
}

/*! @abstract Float operands interpolate at float precision. */
- (void)testFloatsInterpolateAtFloatPrecision
{
	NSNumber *left = [NSNumber numberWithFloat:1.0f];
	NSNumber *right = [NSNumber numberWithFloat:2.0f];

	NSNumber *result = [self.dict interpolateValue:left rightValue:right withWeight:0.5f];

	XCTAssertEqualWithAccuracy(result.floatValue, 1.5f, 1e-6);
}

/*! @abstract Integer operands interpolate with rounding, breaking a half tie away from zero. */
- (void)testIntegersInterpolateWithRounding
{
	XCTAssertEqualObjects([self.dict interpolateValue:@(0) rightValue:@(11) withWeight:0.5f], @(6));
	XCTAssertEqualObjects([self.dict interpolateValue:@(0) rightValue:@(10) withWeight:0.5f], @(5));
	XCTAssertEqualObjects([self.dict interpolateValue:@(10) rightValue:@(0) withWeight:0.25f], @(7),
						  @"round() breaks the -2.5 tie away from zero");
}

/*! @abstract Short operands interpolate with rounding and read back as a short. */
- (void)testShortsInterpolateWithRounding
{
	NSNumber *left = [NSNumber numberWithShort:0];
	NSNumber *right = [NSNumber numberWithShort:10];

	XCTAssertEqual([[self.dict interpolateValue:left rightValue:right withWeight:0.5f] shortValue], (short)5);
}

/*! @abstract Long long operands interpolate with rounding and read back as a long long. */
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

/*! @abstract Strings copy the left operand rather than blending. */
- (void)testStringsCopyTheLeftOperand
{
	NSMutableString *left = [NSMutableString stringWithString:@"left"];
	NSMutableString *right = [NSMutableString stringWithString:@"right"];

	id result = [self.dict interpolateValue:left rightValue:right withWeight:0.5f];

	XCTAssertEqualObjects(result, @"left");
}

/*! @abstract An uninterpolatable class, such as NSDate, returns the left operand. */
- (void)testAnUninterpolatableClassCopiesTheLeftOperand
{
	NSDate *left = [NSDate dateWithTimeIntervalSince1970:0];
	NSDate *right = [NSDate dateWithTimeIntervalSince1970:100];

	XCTAssertEqualObjects([self.dict interpolateValue:left rightValue:right withWeight:0.5f], left);
}

/*! @abstract The -customInterpolateValue: subclass hook returns nil by default. */
- (void)testCustomInterpolateValueIsANilHookByDefault
{
	XCTAssertNil([self.dict customInterpolateValue:@(1.0) rightValue:@(2.0) path:@"/a" withWeight:0.5f]);
}

#pragma mark - Container Interpolation

/*! @abstract Arrays interpolate element by element. */
- (void)testArraysInterpolateElementwise
{
	NSArray *left = @[@(0.0), @(0.0)];
	NSArray *right = @[@(2.0), @(4.0)];

	XCTAssertEqualObjects([self.dict interpolateValue:left rightValue:right withWeight:0.5f], (@[@(1.0), @(2.0)]));
}

/*! @abstract Array interpolation runs over the left operand and drops elements the right operand does not pair. */
- (void)testArrayInterpolationIsDrivenByTheLeftOperandAndDropsUnpairedElements
{
	NSArray *left = @[@(0.0), @(0.0), @(0.0)];
	NSArray *right = @[@(2.0)];

	XCTAssertEqualObjects([self.dict interpolateValue:left rightValue:right withWeight:0.5f], (@[@(1.0)]));
}

/*! @abstract Nested arrays interpolate recursively. */
- (void)testNestedArraysInterpolateRecursively
{
	NSArray *left = @[@[@(0.0), @(0.0)]];
	NSArray *right = @[@[@(4.0), @(8.0)]];

	XCTAssertEqualObjects([self.dict interpolateValue:left rightValue:right withWeight:0.25f], (@[@[@(1.0), @(2.0)]]));
}

/*! @abstract Dictionaries interpolate value by value under matching keys. */
- (void)testDictionariesInterpolateByKey
{
	NSDictionary *left = @{@"a": @(0.0), @"b": @(10.0)};
	NSDictionary *right = @{@"a": @(4.0), @"b": @(20.0)};

	XCTAssertEqualObjects([self.dict interpolateValue:left rightValue:right withWeight:0.5f],
						  (@{@"a": @(2.0), @"b": @(15.0)}));
}

/*! @abstract Dictionary keys prefixed with an underscore are dropped from the result. */
- (void)testDictionaryKeysPrefixedWithUnderscoreAreDropped
{
	NSDictionary *left = @{@"a": @(0.0), @"_b": @(0.0)};
	NSDictionary *right = @{@"a": @(4.0), @"_b": @(4.0)};

	XCTAssertEqualObjects([self.dict interpolateValue:left rightValue:right withWeight:0.25f], (@{@"a": @(1.0)}));
}

/*! @abstract Keys absent from the right operand are dropped from the result. */
- (void)testKeysMissingFromTheRightOperandAreDropped
{
	NSDictionary *left = @{@"a": @(0.0), @"orphan": @(1.0)};
	NSDictionary *right = @{@"a": @(4.0)};

	XCTAssertEqualObjects([self.dict interpolateValue:left rightValue:right withWeight:0.5f], (@{@"a": @(2.0)}));
}

#pragma mark - Exempt Paths

/*! @abstract An exempt path copies the left operand instead of blending. */
- (void)testAnExemptPathCopiesTheLeftOperandInsteadOfBlending
{
	[self.dict setObject:[@[@"/locked"] mutableCopy] forKey:kCustomAPI_ExemptKeysKey];

	id result = [self.dict interpolateValue:@(0.0) rightValue:@(10.0) path:@"/locked" withWeight:0.5f];

	XCTAssertEqualObjects(result, @(0.0));
}

/*! @abstract A path not in the exempt list still blends. */
- (void)testANonExemptPathStillBlends
{
	[self.dict setObject:[@[@"/locked"] mutableCopy] forKey:kCustomAPI_ExemptKeysKey];

	XCTAssertEqualObjects([self.dict interpolateValue:@(0.0) rightValue:@(10.0) path:@"/open" withWeight:0.5f], @(5.0));
}

/*! @abstract Nested dictionary paths are built from the key names, so an exempt nested key is copied while its sibling blends. */
- (void)testNestedDictionaryPathsAreBuiltFromTheKeyNames
{
	[self.dict setObject:[@[@"/outer/inner"] mutableCopy] forKey:kCustomAPI_ExemptKeysKey];

	NSDictionary *left = @{@"outer": @{@"inner": @(0.0), @"other": @(0.0)}};
	NSDictionary *right = @{@"outer": @{@"inner": @(8.0), @"other": @(8.0)}};

	NSDictionary *result = [self.dict interpolateValue:left rightValue:right path:nil withWeight:0.5f];

	XCTAssertEqualObjects(result[@"outer"][@"inner"], @(0.0));
	XCTAssertEqualObjects(result[@"outer"][@"other"], @(4.0));
}

/*! @abstract Array paths are built from the element index, so an exempt index is copied while the others blend. */
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

/*! @abstract -interpolateBetween:withWeight: returns the receiver's and the right dictionary's values at weight zero and one. */
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

/*! @abstract -interpolateBetween:withWeight: blends numbers, copies strings from the left, and drops underscore-prefixed keys. */
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

/*! @abstract -interpolateBetween:withWeight: drops keys the right dictionary does not carry. */
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
