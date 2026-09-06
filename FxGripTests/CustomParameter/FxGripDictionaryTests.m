//
//  FxGripDictionaryTests.m
//  FxGripTests
//

#import <XCTest/XCTest.h>
#import <objc/message.h>
#import <FxPlug/FxTypes.h>

// FxGripDictionary.h is not a public framework header, so the surface under test is
// re-declared locally. The reserved keys mirror the #defines in that header.
#define kCustomAPI_BoolKey		@"boolValue"
#define kCustomAPI_FloatKey		@"floatValue"
#define kCustomAPI_HistogramKey	@"histogramValue"
#define kCustomAPI_IntKey		@"intValue"
#define kCustomAPI_RGBAKey		@"rgbaValue"
#define kCustomAPI_RGBKey		@"rgbValue"
#define kCustomAPI_PathIDKey	@"pathIdValue"
#define kCustomAPI_StringKey	@"stringValue"
#define kCustomAPI_PointKey		@"xyValue"
#define kCustomAPI_IsLocked		@"__locked"
#define kCustomAPI_ExemptKeysKey	@"exemptKeys"
#define kCustomAPI_LastChangedKey	@"__lastChangedKey"

// BEFoundation is not linked into the test bundle, so FxTime is reached through
// NSClassFromString and only the members this file uses are declared.
@interface FxTime : NSObject <NSSecureCoding, NSCopying>
- (instancetype)initWithTime:(int64_t)value timescale:(int32_t)timescale;
@property (assign, readonly) double seconds;
@end


@interface FxGripDictionary : NSMutableDictionary

@property (strong, readonly) NSMutableDictionary *data;
@property (assign, readonly) NSMutableArray *exemptKeys;
@property (assign, readonly) BOOL isLocked;
@property (assign, getter=isLocked) BOOL locked;

- (instancetype)initWithDictionary:(NSDictionary *)dictionary;
+ (NSOrderedSet<Class> *)classesForParameter;
- (NSOrderedSet<Class> *)classesForParameter;

- (BOOL)getBoolValue:(BOOL *)boolValue forKey:(id<NSCopying>)aKey;
- (BOOL)setBoolValue:(BOOL)boolValue forKey:(id<NSCopying>)aKey;
- (BOOL)getBoolValue:(BOOL *)boolValue;
- (BOOL)setBoolValue:(BOOL)boolValue;

- (BOOL)getFloatValue:(double *)floatValue forKey:(id<NSCopying>)aKey;
- (BOOL)setFloatValue:(double)floatValue forKey:(id<NSCopying>)aKey;
- (BOOL)getFloatValue:(double *)floatValue;
- (BOOL)setFloatValue:(double)floatValue;

- (BOOL)getHistogramBlackIn:(double *)blackIn
				   blackOut:(double *)blackOut
					whiteIn:(double *)whiteIn
				   whiteOut:(double *)whiteOut
					  gamma:(double *)gamma
				 forChannel:(FxHistogramChannel)channel
					 forKey:(id<NSCopying>)aKey;

- (BOOL)setHistogramBlackIn:(double)blackIn
				   blackOut:(double)blackOut
					whiteIn:(double)whiteIn
				   whiteOut:(double)whiteOut
					  gamma:(double)gamma
				 forChannel:(FxHistogramChannel)channel
					 forKey:(id<NSCopying>)aKey;

- (BOOL)getHistogramBlackIn:(double *)blackIn
				   blackOut:(double *)blackOut
					whiteIn:(double *)whiteIn
				   whiteOut:(double *)whiteOut
					  gamma:(double *)gamma
				 forChannel:(FxHistogramChannel)channel;

- (BOOL)setHistogramBlackIn:(double)blackIn
				   blackOut:(double)blackOut
					whiteIn:(double)whiteIn
				   whiteOut:(double)whiteOut
					  gamma:(double)gamma
				 forChannel:(FxHistogramChannel)channel;

- (BOOL)getIntValue:(int *)intValue forKey:(id<NSCopying>)aKey;
- (BOOL)setIntValue:(int)intValue forKey:(id<NSCopying>)aKey;
- (BOOL)getIntValue:(int *)intValue;
- (BOOL)setIntValue:(int)intValue;

- (BOOL)getPathID:(FxPathID *)pathID forKey:(id<NSCopying>)aKey;
- (BOOL)setPathID:(FxPathID)pathID forKey:(id<NSCopying>)aKey;
- (BOOL)getPathID:(FxPathID *)pathID;
- (BOOL)setPathID:(FxPathID)pathID;

- (BOOL)getRedValue:(double *)red greenValue:(double *)green blueValue:(double *)blue alphaValue:(double *)alpha forKey:(id<NSCopying>)aKey;
- (BOOL)setRedValue:(double)red greenValue:(double)green blueValue:(double)blue alphaValue:(double)alpha forKey:(id<NSCopying>)aKey;
- (BOOL)getRedValue:(double *)red greenValue:(double *)green blueValue:(double *)blue alphaValue:(double *)alpha;
- (BOOL)setRedValue:(double)red greenValue:(double)green blueValue:(double)blue alphaValue:(double)alpha;

- (BOOL)getRedValue:(double *)red greenValue:(double *)green blueValue:(double *)blue forKey:(id<NSCopying>)aKey;
- (BOOL)setRedValue:(double)red greenValue:(double)green blueValue:(double)blue forKey:(id<NSCopying>)aKey;
- (BOOL)getRedValue:(double *)red greenValue:(double *)green blueValue:(double *)blue;
- (BOOL)setRedValue:(double)red greenValue:(double)green blueValue:(double)blue;

- (BOOL)getStringParameterValue:(NSString **)string forKey:(id<NSCopying>)aKey;
- (BOOL)setStringParameterValue:(NSString *)string forKey:(id<NSCopying>)aKey;
- (BOOL)getStringParameterValue:(NSString **)string;
- (BOOL)setStringParameterValue:(NSString *)string;

- (BOOL)getXValue:(double *)x YValue:(double *)y forKey:(id<NSCopying>)aKey;
- (BOOL)setXValue:(double)x YValue:(double)y forKey:(id<NSCopying>)aKey;
- (BOOL)getXValue:(double *)x YValue:(double *)y;
- (BOOL)setXValue:(double)x YValue:(double)y;

@end


@interface FxGripDictionaryTests : XCTestCase
@property (nonatomic, strong) FxGripDictionary *dict;
@end

@implementation FxGripDictionaryTests

- (void)setUp
{
	[super setUp];
	self.dict = [FxGripDictionary.alloc init];
}

- (void)tearDown
{
	self.dict = nil;
	[super tearDown];
}

- (void)assertDictionary:(FxGripDictionary *)lhs matches:(NSDictionary *)expected
{
	XCTAssertTrue([lhs.data isEqualToDictionary:expected], @"backing store %@ != %@", lhs.data, expected);
}

#pragma mark - Construction

- (void)testInitCreatesAnEmptyBackingDictionary
{
	XCTAssertNotNil(self.dict.data);
	XCTAssertEqual(self.dict.count, 0u);
	XCTAssertEqual(self.dict.data.count, 0u);
}

- (void)testInitWithDictionaryTakesAMutableSnapshotOfTheSource
{
	NSMutableDictionary *source = [@{@"a": @(1), @"b": @"two"} mutableCopy];
	FxGripDictionary *d = [FxGripDictionary.alloc initWithDictionary:source];

	source[@"c"] = @"added after";

	[self assertDictionary:d matches:@{@"a": @(1), @"b": @"two"}];
	XCTAssertEqual(d.count, 2u);
}

- (void)testInitWithObjectsForKeysCountPopulatesTheBackingDictionary
{
	id objects[2] = {@"alpha", @"beta"};
	id<NSCopying> keys[2] = {@"one", @"two"};

	FxGripDictionary *d = [FxGripDictionary.alloc initWithObjects:objects forKeys:keys count:2];

	XCTAssertEqual(d.count, 2u);
	XCTAssertEqualObjects([d objectForKey:@"one"], @"alpha");
	XCTAssertEqualObjects([d objectForKey:@"two"], @"beta");
}

#pragma mark - Collection Primitives

- (void)testSetObjectForKeyWritesThroughToTheBackingDictionary
{
	[self.dict setObject:@"value" forKey:@"key"];

	XCTAssertEqualObjects([self.dict objectForKey:@"key"], @"value");
	XCTAssertEqualObjects(self.dict.data[@"key"], @"value");
	XCTAssertEqual(self.dict.count, 1u);
}

- (void)testKeyedSubscriptingRoutesThroughThePrimitives
{
	self.dict[@"key"] = @"value";

	XCTAssertEqualObjects(self.dict[@"key"], @"value");
	XCTAssertEqualObjects(self.dict.data[@"key"], @"value");
}

- (void)testRemoveObjectForKeyDeletesTheEntry
{
	[self.dict setObject:@"value" forKey:@"key"];

	[self.dict removeObjectForKey:@"key"];

	XCTAssertNil([self.dict objectForKey:@"key"]);
	XCTAssertEqual(self.dict.count, 0u);
}

- (void)testObjectForMissingKeyIsNil
{
	XCTAssertNil([self.dict objectForKey:@"absent"]);
}

- (void)testKeyEnumeratorWalksTheBackingDictionary
{
	[self.dict setObject:@(1) forKey:@"a"];
	[self.dict setObject:@(2) forKey:@"b"];

	NSMutableSet *seen = NSMutableSet.set;
	for (id key in [self.dict keyEnumerator]) {
		[seen addObject:key];
	}

	XCTAssertEqualObjects(seen, ([NSSet setWithArray:@[@"a", @"b"]]));
}

#pragma mark - Keyed Typed Accessors

- (void)testBoolValueRoundTripsForAnArbitraryKey
{
	XCTAssertTrue([self.dict setBoolValue:YES forKey:@"flag"]);

	BOOL value = NO;
	XCTAssertTrue([self.dict getBoolValue:&value forKey:@"flag"]);
	XCTAssertTrue(value);
	XCTAssertEqualObjects(self.dict.data[@"flag"], @(YES));
}

- (void)testBoolGetterRejectsMissingAndNonNumberValues
{
	[self.dict setObject:@"not a number" forKey:@"text"];

	BOOL value = YES;
	XCTAssertFalse([self.dict getBoolValue:&value forKey:@"absent"]);
	XCTAssertFalse([self.dict getBoolValue:&value forKey:@"text"]);
	XCTAssertTrue(value, @"the out parameter stays untouched when the getter fails");
}

- (void)testFloatValueRoundTripsForAnArbitraryKey
{
	XCTAssertTrue([self.dict setFloatValue:2.5 forKey:@"f"]);

	double value = 0.0;
	XCTAssertTrue([self.dict getFloatValue:&value forKey:@"f"]);
	XCTAssertEqual(value, 2.5);
}

- (void)testFloatGetterAcceptsAnyStoredNumber
{
	[self.dict setObject:@(7) forKey:@"i"];

	double value = 0.0;
	XCTAssertTrue([self.dict getFloatValue:&value forKey:@"i"]);
	XCTAssertEqual(value, 7.0);
}

- (void)testIntValueRoundTripsForAnArbitraryKey
{
	XCTAssertTrue([self.dict setIntValue:-42 forKey:@"i"]);

	int value = 0;
	XCTAssertTrue([self.dict getIntValue:&value forKey:@"i"]);
	XCTAssertEqual(value, -42);
}

- (void)testIntGetterTruncatesAStoredDouble
{
	[self.dict setObject:@(3.9) forKey:@"i"];

	int value = 0;
	XCTAssertTrue([self.dict getIntValue:&value forKey:@"i"]);
	XCTAssertEqual(value, 3);
}

- (void)testPathIDRoundTripsAsAnUnsignedNumber
{
	FxPathID path = (FxPathID)(uintptr_t)0xABCDEF;
	XCTAssertTrue([self.dict setPathID:path forKey:@"p"]);
	XCTAssertEqualObjects(self.dict.data[@"p"], @((unsigned long long)0xABCDEF));

	FxPathID readBack = NULL;
	XCTAssertTrue([self.dict getPathID:&readBack forKey:@"p"]);
	XCTAssertEqual(readBack, path);
}

- (void)testPathIDGetterRejectsANonNumberValue
{
	[self.dict setObject:@"nope" forKey:@"p"];

	FxPathID readBack = NULL;
	XCTAssertFalse([self.dict getPathID:&readBack forKey:@"p"]);
}

- (void)testStringParameterValueRoundTripsForAnArbitraryKey
{
	XCTAssertTrue([self.dict setStringParameterValue:@"hello" forKey:@"s"]);

	NSString *value = nil;
	XCTAssertTrue([self.dict getStringParameterValue:&value forKey:@"s"]);
	XCTAssertEqualObjects(value, @"hello");
}

- (void)testStringGetterFormatsAStoredNumber
{
	[self.dict setObject:@(12) forKey:@"s"];

	NSString *value = nil;
	XCTAssertTrue([self.dict getStringParameterValue:&value forKey:@"s"]);
	XCTAssertEqualObjects(value, @"12");
}

- (void)testStringGetterRejectsAStoredArray
{
	[self.dict setObject:@[@"a"] forKey:@"s"];

	NSString *value = nil;
	XCTAssertFalse([self.dict getStringParameterValue:&value forKey:@"s"]);
	XCTAssertNil(value);
}

- (void)testRGBAValueRoundTripsAsAFourElementArray
{
	XCTAssertTrue([self.dict setRedValue:0.1 greenValue:0.2 blueValue:0.3 alphaValue:0.4 forKey:@"c"]);
	XCTAssertEqualObjects(self.dict.data[@"c"], (@[@(0.1), @(0.2), @(0.3), @(0.4)]));

	double r = 0, g = 0, b = 0, a = 0;
	XCTAssertTrue([self.dict getRedValue:&r greenValue:&g blueValue:&b alphaValue:&a forKey:@"c"]);
	XCTAssertEqual(r, 0.1);
	XCTAssertEqual(g, 0.2);
	XCTAssertEqual(b, 0.3);
	XCTAssertEqual(a, 0.4);
}

- (void)testRGBAGetterExpandsAOneElementArrayToOpaqueGray
{
	[self.dict setObject:@[@(0.5)] forKey:@"c"];

	double r = 0, g = 0, b = 0, a = 0;
	XCTAssertTrue([self.dict getRedValue:&r greenValue:&g blueValue:&b alphaValue:&a forKey:@"c"]);
	XCTAssertEqual(r, 0.5);
	XCTAssertEqual(g, 0.5);
	XCTAssertEqual(b, 0.5);
	XCTAssertEqual(a, 1.0);
}

- (void)testRGBAGetterReadsATwoElementArrayAsGrayPlusAlpha
{
	[self.dict setObject:@[@(0.5), @(0.25)] forKey:@"c"];

	double r = 0, g = 0, b = 0, a = 0;
	XCTAssertTrue([self.dict getRedValue:&r greenValue:&g blueValue:&b alphaValue:&a forKey:@"c"]);
	XCTAssertEqual(r, 0.5);
	XCTAssertEqual(b, 0.5);
	XCTAssertEqual(a, 0.25);
}

- (void)testRGBAGetterDefaultsAlphaForAThreeElementArray
{
	[self.dict setObject:@[@(0.1), @(0.2), @(0.3)] forKey:@"c"];

	double r = 0, g = 0, b = 0, a = 0;
	XCTAssertTrue([self.dict getRedValue:&r greenValue:&g blueValue:&b alphaValue:&a forKey:@"c"]);
	XCTAssertEqual(g, 0.2);
	XCTAssertEqual(a, 1.0);
}

- (void)testRGBAGetterRejectsAnEmptyArrayAndANonArray
{
	[self.dict setObject:@[] forKey:@"empty"];
	[self.dict setObject:@(1) forKey:@"number"];

	double r = 0, g = 0, b = 0, a = 0;
	XCTAssertFalse([self.dict getRedValue:&r greenValue:&g blueValue:&b alphaValue:&a forKey:@"empty"]);
	XCTAssertFalse([self.dict getRedValue:&r greenValue:&g blueValue:&b alphaValue:&a forKey:@"number"]);
	XCTAssertFalse([self.dict getRedValue:&r greenValue:&g blueValue:&b alphaValue:&a forKey:@"absent"]);
}

- (void)testRGBValueRoundTripsAsAThreeElementArray
{
	XCTAssertTrue([self.dict setRedValue:0.1 greenValue:0.2 blueValue:0.3 forKey:@"c"]);
	XCTAssertEqualObjects(self.dict.data[@"c"], (@[@(0.1), @(0.2), @(0.3)]));

	double r = 0, g = 0, b = 0;
	XCTAssertTrue([self.dict getRedValue:&r greenValue:&g blueValue:&b forKey:@"c"]);
	XCTAssertEqual(r, 0.1);
	XCTAssertEqual(g, 0.2);
	XCTAssertEqual(b, 0.3);
}

- (void)testRGBGetterRejectsAnEmptyArrayAndANonArray
{
	[self.dict setObject:@[] forKey:@"empty"];
	[self.dict setObject:@"text" forKey:@"text"];

	double r = 0, g = 0, b = 0;
	XCTAssertFalse([self.dict getRedValue:&r greenValue:&g blueValue:&b forKey:@"empty"]);
	XCTAssertFalse([self.dict getRedValue:&r greenValue:&g blueValue:&b forKey:@"text"]);
	XCTAssertFalse([self.dict getRedValue:&r greenValue:&g blueValue:&b forKey:@"absent"]);
}

- (void)testRGBGetterExpandsAShortArrayToGray
{
	[self.dict setObject:@[@(0.75), @(0.0)] forKey:@"c"];

	double r = 0, g = 0, b = 0;
	XCTAssertTrue([self.dict getRedValue:&r greenValue:&g blueValue:&b forKey:@"c"]);
	XCTAssertEqual(r, 0.75);
	XCTAssertEqual(g, 0.75);
	XCTAssertEqual(b, 0.75);
}

- (void)testRGBSetterPreservesTheAlphaSlotOfAnExistingRGBAArray
{
	[self.dict setRedValue:0.1 greenValue:0.2 blueValue:0.3 alphaValue:0.4 forKey:@"c"];

	[self.dict setRedValue:0.9 greenValue:0.8 blueValue:0.7 forKey:@"c"];

	XCTAssertEqualObjects(self.dict.data[@"c"], (@[@(0.9), @(0.8), @(0.7), @(0.4)]));
}

- (void)testXYValueRoundTripsAsATwoElementArray
{
	XCTAssertTrue([self.dict setXValue:-1.5 YValue:2.5 forKey:@"pt"]);
	XCTAssertEqualObjects(self.dict.data[@"pt"], (@[@(-1.5), @(2.5)]));

	double x = 0, y = 0;
	XCTAssertTrue([self.dict getXValue:&x YValue:&y forKey:@"pt"]);
	XCTAssertEqual(x, -1.5);
	XCTAssertEqual(y, 2.5);
}

- (void)testXYGetterRequiresExactlyTwoElements
{
	[self.dict setObject:@[@(1.0)] forKey:@"short"];
	[self.dict setObject:@[@(1.0), @(2.0), @(3.0)] forKey:@"long"];

	double x = 0, y = 0;
	XCTAssertFalse([self.dict getXValue:&x YValue:&y forKey:@"short"]);
	XCTAssertFalse([self.dict getXValue:&x YValue:&y forKey:@"long"]);
}

#pragma mark - Reserved Keys And Locking

- (void)testAFreshDictionaryIsLocked
{
	XCTAssertTrue(self.dict.isLocked);
	XCTAssertNil([self.dict objectForKey:kCustomAPI_IsLocked]);
}

- (void)testALockedDictionaryRefusesToCreateReservedKeys
{
	XCTAssertFalse([self.dict setBoolValue:YES]);
	XCTAssertFalse([self.dict setFloatValue:1.0]);
	XCTAssertFalse([self.dict setIntValue:1]);
	XCTAssertFalse([self.dict setStringParameterValue:@"s"]);
	XCTAssertFalse([self.dict setXValue:1.0 YValue:2.0]);
	XCTAssertFalse([self.dict setRedValue:0.1 greenValue:0.2 blueValue:0.3]);
	XCTAssertFalse([self.dict setRedValue:0.1 greenValue:0.2 blueValue:0.3 alphaValue:0.4]);
	XCTAssertEqual(self.dict.count, 0u);
}

- (void)testUnlockingStoresTheLockFlagAndAdmitsReservedKeys
{
	self.dict.locked = NO;

	XCTAssertFalse(self.dict.isLocked);
	XCTAssertEqualObjects([self.dict objectForKey:kCustomAPI_IsLocked], @(NO));
	XCTAssertTrue([self.dict setIntValue:11]);
	XCTAssertEqualObjects(self.dict.data[kCustomAPI_IntKey], @(11));
}

- (void)testRelockingRemovesTheLockFlagAndLeavesOtherKeys
{
	self.dict.locked = NO;
	[self.dict setIntValue:11];

	self.dict.locked = YES;

	XCTAssertTrue(self.dict.isLocked);
	XCTAssertNil([self.dict objectForKey:kCustomAPI_IsLocked]);
	XCTAssertEqualObjects(self.dict.data[kCustomAPI_IntKey], @(11));
}

- (void)testRelockingAnAlreadyLockedDictionaryIsANoOp
{
	self.dict.locked = YES;

	XCTAssertTrue(self.dict.isLocked);
	XCTAssertEqual(self.dict.count, 0u);
}

- (void)testALockedDictionaryStillUpdatesReservedKeysThatAlreadyExist
{
	[self.dict setObject:@(1) forKey:kCustomAPI_IntKey];
	[self.dict setObject:@(NO) forKey:kCustomAPI_BoolKey];

	XCTAssertTrue(self.dict.isLocked);
	XCTAssertTrue([self.dict setIntValue:99]);
	XCTAssertTrue([self.dict setBoolValue:YES]);
	XCTAssertEqualObjects(self.dict.data[kCustomAPI_IntKey], @(99));
	XCTAssertEqualObjects(self.dict.data[kCustomAPI_BoolKey], @(YES));
}

- (void)testAnUnlockedDictionaryAcceptsEveryReservedSetter
{
	self.dict.locked = NO;

	XCTAssertTrue([self.dict setBoolValue:YES]);
	XCTAssertTrue([self.dict setFloatValue:1.5]);
	XCTAssertTrue([self.dict setIntValue:3]);
	XCTAssertTrue([self.dict setStringParameterValue:@"s"]);
	XCTAssertTrue([self.dict setXValue:1.0 YValue:2.0]);
	XCTAssertTrue([self.dict setRedValue:0.1 greenValue:0.2 blueValue:0.3]);
	XCTAssertTrue([self.dict setRedValue:0.4 greenValue:0.5 blueValue:0.6 alphaValue:0.7]);

	XCTAssertEqualObjects(self.dict.data[kCustomAPI_BoolKey], @(YES));
	XCTAssertEqualObjects(self.dict.data[kCustomAPI_FloatKey], @(1.5));
	XCTAssertEqualObjects(self.dict.data[kCustomAPI_IntKey], @(3));
	XCTAssertEqualObjects(self.dict.data[kCustomAPI_StringKey], @"s");
	XCTAssertEqualObjects(self.dict.data[kCustomAPI_PointKey], (@[@(1.0), @(2.0)]));
	XCTAssertEqualObjects(self.dict.data[kCustomAPI_RGBKey], (@[@(0.1), @(0.2), @(0.3)]));
	XCTAssertEqualObjects(self.dict.data[kCustomAPI_RGBAKey], (@[@(0.4), @(0.5), @(0.6), @(0.7)]));
}

- (void)testTheDefaultAccessorsReadTheReservedKeys
{
	[self.dict setObject:@(YES) forKey:kCustomAPI_BoolKey];
	[self.dict setObject:@(1.25) forKey:kCustomAPI_FloatKey];
	[self.dict setObject:@(7) forKey:kCustomAPI_IntKey];
	[self.dict setObject:@"str" forKey:kCustomAPI_StringKey];
	[self.dict setObject:@(9) forKey:kCustomAPI_PathIDKey];
	[self.dict setObject:@[@(1.0), @(2.0)] forKey:kCustomAPI_PointKey];
	[self.dict setObject:@[@(0.1), @(0.2), @(0.3), @(0.4)] forKey:kCustomAPI_RGBAKey];
	[self.dict setObject:@[@(0.5), @(0.6), @(0.7)] forKey:kCustomAPI_RGBKey];

	BOOL flag = NO;
	double f = 0, x = 0, y = 0, r = 0, g = 0, b = 0, a = 0;
	int i = 0;
	NSString *s = nil;
	FxPathID path = NULL;

	XCTAssertTrue([self.dict getBoolValue:&flag]);
	XCTAssertTrue([self.dict getFloatValue:&f]);
	XCTAssertTrue([self.dict getIntValue:&i]);
	XCTAssertTrue([self.dict getStringParameterValue:&s]);
	XCTAssertTrue([self.dict getPathID:&path]);
	XCTAssertTrue([self.dict getXValue:&x YValue:&y]);
	XCTAssertTrue([self.dict getRedValue:&r greenValue:&g blueValue:&b alphaValue:&a]);

	XCTAssertTrue(flag);
	XCTAssertEqual(f, 1.25);
	XCTAssertEqual(i, 7);
	XCTAssertEqualObjects(s, @"str");
	XCTAssertEqual((uintptr_t)path, 9u);
	XCTAssertEqual(x, 1.0);
	XCTAssertEqual(y, 2.0);
	XCTAssertEqual(a, 0.4);

	XCTAssertTrue([self.dict getRedValue:&r greenValue:&g blueValue:&b]);
	XCTAssertEqual(r, 0.5);
	XCTAssertEqual(b, 0.7);
}

- (void)testTheDefaultGettersFailOnAnEmptyDictionary
{
	BOOL flag = NO;
	double f = 0;
	int i = 0;
	NSString *s = nil;

	XCTAssertFalse([self.dict getBoolValue:&flag]);
	XCTAssertFalse([self.dict getFloatValue:&f]);
	XCTAssertFalse([self.dict getIntValue:&i]);
	XCTAssertFalse([self.dict getStringParameterValue:&s]);
}

#pragma mark - Copying And Equality

- (void)testCopyProducesAnIndependentDictionaryWithEqualContents
{
	[self.dict setObject:@"value" forKey:@"key"];

	FxGripDictionary *copy = [self.dict copy];

	XCTAssertTrue([copy isKindOfClass:FxGripDictionary.class]);
	XCTAssertTrue([self.dict isEqual:copy]);

	[copy setObject:@"other" forKey:@"key"];
	XCTAssertEqualObjects([self.dict objectForKey:@"key"], @"value");
}

- (void)testIsEqualComparesTheBackingDictionaries
{
	[self.dict setObject:@(1) forKey:@"a"];
	FxGripDictionary *same = [FxGripDictionary.alloc initWithDictionary:@{@"a": @(1)}];
	FxGripDictionary *different = [FxGripDictionary.alloc initWithDictionary:@{@"a": @(2)}];

	XCTAssertTrue([self.dict isEqual:same]);
	XCTAssertFalse([self.dict isEqual:different]);
}

- (void)testIsEqualWithNilIsFalse
{
	XCTAssertFalse([self.dict isEqual:nil]);
}

#pragma mark - Secure Coding

- (void)testTheClassAdvertisesSecureCoding
{
	XCTAssertTrue([FxGripDictionary supportsSecureCoding]);
}

- (void)testTheClassLevelParameterClassListCoversTheSupportedPayloads
{
	NSOrderedSet<Class> *classes = [FxGripDictionary classesForParameter];

	XCTAssertTrue([classes containsObject:NSMutableDictionary.class]);
	XCTAssertTrue([classes containsObject:NSString.class]);
	XCTAssertTrue([classes containsObject:NSNumber.class]);
	XCTAssertTrue([classes containsObject:NSClassFromString(@"FxTime")]);
	XCTAssertEqual(classes.count, 19u);
}

#pragma mark - Class Cluster Contract

- (void)testFastEnumerationVisitsEveryKey
{
	[self.dict setObject:@(1) forKey:@"a"];
	[self.dict setObject:@(2) forKey:@"b"];

	NSMutableSet *seen = NSMutableSet.set;
	for (id key in self.dict) {
		[seen addObject:key];
	}

	XCTAssertEqualObjects(seen, ([NSSet setWithArray:@[@"a", @"b"]]));
}

- (void)testAllKeysReturnsTheStoredKeys
{
	[self.dict setObject:@(1) forKey:@"a"];

	XCTAssertEqualObjects([self.dict allKeys], @[@"a"]);
}

- (void)testAllKeysAndAllValuesAgreeOnEveryEntry
{
	[self.dict setObject:@(1) forKey:@"a"];
	[self.dict setObject:@"two" forKey:@"b"];
	[self.dict setObject:@[@(3)] forKey:@"c"];

	NSArray *keys = [self.dict allKeys];
	NSArray *values = [self.dict allValues];

	XCTAssertEqual(keys.count, 3u);
	XCTAssertEqual(values.count, 3u);
	XCTAssertEqualObjects([NSSet setWithArray:keys], ([NSSet setWithArray:@[@"a", @"b", @"c"]]));
	XCTAssertEqualObjects([NSSet setWithArray:values], ([NSSet setWithArray:@[@(1), @"two", @[@(3)]]]));

	for (id key in keys) {
		XCTAssertTrue([values containsObject:[self.dict objectForKey:key]]);
	}
}

- (void)testDescriptionListsTheStoredEntries
{
	[self.dict setObject:@"value" forKey:@"key"];

	NSString *description = nil;
	XCTAssertNoThrow(description = self.dict.description);

	XCTAssertTrue([description containsString:@"key"]);
	XCTAssertTrue([description containsString:@"value"]);
}

- (void)testMutableCopyProducesAUsableDictionary
{
	[self.dict setObject:@(1) forKey:@"a"];

	id copy = [self.dict mutableCopy];

	XCTAssertNotNil(copy);
	XCTAssertEqual([copy count], 1u);
	XCTAssertEqualObjects([copy objectForKey:@"a"], @(1));
}

- (void)testMutableCopyIsIndependentOfTheReceiver
{
	[self.dict setObject:@(1) forKey:@"a"];

	NSMutableDictionary *copy = [self.dict mutableCopy];
	[copy setObject:@(2) forKey:@"a"];
	[copy setObject:@(3) forKey:@"b"];

	XCTAssertEqualObjects([self.dict objectForKey:@"a"], @(1));
	XCTAssertNil([self.dict objectForKey:@"b"]);
	XCTAssertEqual(self.dict.count, 1u);
}

- (void)testTheInstanceParameterClassListMatchesTheClassLevelList
{
	XCTAssertEqualObjects([self.dict classesForParameter], [FxGripDictionary classesForParameter]);
}

#pragma mark - Exempt Keys

- (void)testExemptKeysIsNonNilAsTheHeaderDeclares
{
	XCTAssertNotNil(self.dict.exemptKeys);
}

- (void)testExemptKeysSeedsTheReservedKeysAndWritesItselfBack
{
	NSMutableArray *exempt = self.dict.exemptKeys;

	XCTAssertEqualObjects(exempt, (@[kCustomAPI_ExemptKeysKey, kCustomAPI_LastChangedKey]));
	XCTAssertEqualObjects([self.dict objectForKey:kCustomAPI_ExemptKeysKey], exempt);
}

- (void)testExemptKeysPreservesCallerSuppliedEntries
{
	[self.dict setObject:@[@"mine"] forKey:kCustomAPI_ExemptKeysKey];

	XCTAssertEqualObjects(self.dict.exemptKeys, (@[@"mine", kCustomAPI_ExemptKeysKey, kCustomAPI_LastChangedKey]));
}

#pragma mark - Histogram

- (void)testHistogramGetterReadsAWellFormedChannelArray
{
	NSArray *channel = @[@(0.1), @(0.2), @(0.8), @(0.9), @(1.5)];
	[self.dict setObject:@[channel, channel, channel, channel] forKey:kCustomAPI_HistogramKey];

	double blackIn = -1, blackOut = -1, whiteIn = -1, whiteOut = -1, gamma = -1;
	BOOL read = [self.dict getHistogramBlackIn:&blackIn
									  blackOut:&blackOut
									   whiteIn:&whiteIn
									  whiteOut:&whiteOut
										 gamma:&gamma
									forChannel:kFxHistogramChannel_Red
										forKey:kCustomAPI_HistogramKey];

	XCTAssertTrue(read);
	XCTAssertEqual(blackIn, 0.1);
	XCTAssertEqual(gamma, 1.5);
}

- (void)testHistogramGetterRejectsAMissingOrNonArrayValue
{
	[self.dict setObject:@(1) forKey:@"number"];

	double blackIn = -1, blackOut = -1, whiteIn = -1, whiteOut = -1, gamma = -1;

	XCTAssertFalse([self.dict getHistogramBlackIn:&blackIn blackOut:&blackOut whiteIn:&whiteIn
										 whiteOut:&whiteOut gamma:&gamma
									   forChannel:kFxHistogramChannel_Red forKey:@"absent"]);
	XCTAssertFalse([self.dict getHistogramBlackIn:&blackIn blackOut:&blackOut whiteIn:&whiteIn
										 whiteOut:&whiteOut gamma:&gamma
									   forChannel:kFxHistogramChannel_Red forKey:@"number"]);
}

- (void)testHistogramSetterBuildsTheFourChannelStructureFromNothing
{
	XCTAssertTrue([self.dict setHistogramBlackIn:0.1 blackOut:0.2 whiteIn:0.3 whiteOut:0.4 gamma:0.5
									  forChannel:kFxHistogramChannel_Red forKey:@"h"]);

	NSArray *histogram = (NSArray *)[self.dict objectForKey:@"h"];

	XCTAssertEqual(histogram.count, 4u);
	XCTAssertEqualObjects(histogram[0], (@[@(0.1), @(0.2), @(0.3), @(0.4), @(0.5)]));
	XCTAssertEqualObjects(histogram[1], (@[@(0.0), @(0.0), @(1.0), @(1.0), @(1.0)]));
	XCTAssertEqualObjects(histogram[2], (@[@(0.0), @(0.0), @(1.0), @(1.0), @(1.0)]));
	XCTAssertEqualObjects(histogram[3], (@[@(0.0), @(0.0), @(1.0), @(1.0), @(1.0)]));
}

- (void)testEveryHistogramChannelRoundTripsIndependently
{
	FxHistogramChannel channels[4] = {kFxHistogramChannel_Red, kFxHistogramChannel_Green,
									  kFxHistogramChannel_Blue, kFxHistogramChannel_Alpha};

	for (int c = 0; c < 4; c++) {
		double base = (c + 1) * 10.0;
		XCTAssertTrue([self.dict setHistogramBlackIn:base blackOut:base + 1 whiteIn:base + 2
											whiteOut:base + 3 gamma:base + 4
										  forChannel:channels[c] forKey:@"h"]);
	}

	for (int c = 0; c < 4; c++) {
		double base = (c + 1) * 10.0;
		double blackIn = -1, blackOut = -1, whiteIn = -1, whiteOut = -1, gamma = -1;

		XCTAssertTrue([self.dict getHistogramBlackIn:&blackIn blackOut:&blackOut whiteIn:&whiteIn
											whiteOut:&whiteOut gamma:&gamma
										  forChannel:channels[c] forKey:@"h"]);
		XCTAssertEqual(blackIn, base);
		XCTAssertEqual(blackOut, base + 1);
		XCTAssertEqual(whiteIn, base + 2);
		XCTAssertEqual(whiteOut, base + 3);
		XCTAssertEqual(gamma, base + 4);
	}
}

- (void)testTheRGBChannelWritesTheThreeColorChannelsAndLeavesAlphaAlone
{
	[self.dict setHistogramBlackIn:9.0 blackOut:9.1 whiteIn:9.2 whiteOut:9.3 gamma:9.4
						forChannel:kFxHistogramChannel_Alpha forKey:@"h"];

	XCTAssertTrue([self.dict setHistogramBlackIn:1.0 blackOut:2.0 whiteIn:3.0 whiteOut:4.0 gamma:5.0
									  forChannel:kFxHistogramChannel_RGB forKey:@"h"]);

	NSArray *histogram = (NSArray *)[self.dict objectForKey:@"h"];
	NSArray *written = @[@(1.0), @(2.0), @(3.0), @(4.0), @(5.0)];

	XCTAssertEqualObjects(histogram[0], written);
	XCTAssertEqualObjects(histogram[1], written);
	XCTAssertEqualObjects(histogram[2], written);
	XCTAssertEqualObjects(histogram[3], (@[@(9.0), @(9.1), @(9.2), @(9.3), @(9.4)]));
}

- (void)testTheRGBChannelGetterAveragesTheThreeColorChannels
{
	[self.dict setHistogramBlackIn:0 blackOut:1 whiteIn:2 whiteOut:3 gamma:4
						forChannel:kFxHistogramChannel_Red forKey:@"h"];
	[self.dict setHistogramBlackIn:3 blackOut:4 whiteIn:5 whiteOut:6 gamma:7
						forChannel:kFxHistogramChannel_Green forKey:@"h"];
	[self.dict setHistogramBlackIn:6 blackOut:7 whiteIn:8 whiteOut:9 gamma:10
						forChannel:kFxHistogramChannel_Blue forKey:@"h"];

	double blackIn = -1, blackOut = -1, whiteIn = -1, whiteOut = -1, gamma = -1;
	XCTAssertTrue([self.dict getHistogramBlackIn:&blackIn blackOut:&blackOut whiteIn:&whiteIn
										whiteOut:&whiteOut gamma:&gamma
									  forChannel:kFxHistogramChannel_RGB forKey:@"h"]);

	XCTAssertEqualWithAccuracy(blackIn, 3.0, 1e-12);
	XCTAssertEqualWithAccuracy(blackOut, 4.0, 1e-12);
	XCTAssertEqualWithAccuracy(whiteIn, 5.0, 1e-12);
	XCTAssertEqualWithAccuracy(whiteOut, 6.0, 1e-12);
	XCTAssertEqualWithAccuracy(gamma, 7.0, 1e-12);
}

- (void)testTheReservedHistogramKeyObeysTheLock
{
	XCTAssertFalse([self.dict setHistogramBlackIn:1 blackOut:2 whiteIn:3 whiteOut:4 gamma:5
									   forChannel:kFxHistogramChannel_Red]);
	XCTAssertEqual(self.dict.count, 0u);

	self.dict.locked = NO;
	XCTAssertTrue([self.dict setHistogramBlackIn:1 blackOut:2 whiteIn:3 whiteOut:4 gamma:5
									  forChannel:kFxHistogramChannel_Red]);

	double blackIn = -1, blackOut = -1, whiteIn = -1, whiteOut = -1, gamma = -1;
	XCTAssertTrue([self.dict getHistogramBlackIn:&blackIn blackOut:&blackOut whiteIn:&whiteIn
										whiteOut:&whiteOut gamma:&gamma
									  forChannel:kFxHistogramChannel_Red]);
	XCTAssertEqual(blackIn, 1.0);
	XCTAssertEqual(gamma, 5.0);
}

#pragma mark - Path ID

- (void)testTheProtocolLevelPathIDSetterExists
{
	XCTAssertTrue([self.dict respondsToSelector:NSSelectorFromString(@"setPathID:")]);
}

- (void)testTheMisspelledPathIDSetterNoLongerExists
{
	XCTAssertFalse([self.dict respondsToSelector:NSSelectorFromString(@"etPathID:")]);
}

- (void)testTheProtocolLevelPathIDSetterWritesTheReservedKeyWhenUnlocked
{
	FxPathID path = (FxPathID)(uintptr_t)0x40;

	XCTAssertFalse([self.dict setPathID:path], @"a locked dictionary refuses the reserved key");

	self.dict.locked = NO;
	XCTAssertTrue([self.dict setPathID:path]);
	XCTAssertEqualObjects(self.dict.data[kCustomAPI_PathIDKey], @(0x40));

	FxPathID readBack = NULL;
	XCTAssertTrue([self.dict getPathID:&readBack]);
	XCTAssertEqual(readBack, path);
}

#pragma mark - Equality

- (void)testIsEqualToAForeignObjectAnswersFalse
{
	BOOL equal = YES;
	XCTAssertNoThrow(equal = [self.dict isEqual:@"a string"]);
	XCTAssertFalse(equal);
}

- (void)testEqualDictionariesShareAHash
{
	[self.dict setObject:@(1) forKey:@"a"];
	FxGripDictionary *same = [FxGripDictionary.alloc initWithDictionary:@{@"a": @(1)}];

	XCTAssertTrue([self.dict isEqual:same]);
	XCTAssertEqual(self.dict.hash, same.hash);
}

#pragma mark - Archiving

- (void)testSecureCodingRoundTripPreservesClassAndContents
{
	FxGripDictionary *original = [FxGripDictionary.alloc initWithDictionary:@{@"s": @"str", @"n": @(3.5)}];

	NSError *encodeError = nil;
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:original requiringSecureCoding:YES error:&encodeError];
	XCTAssertNil(encodeError);
	XCTAssertNotNil(data);

	NSError *decodeError = nil;
	FxGripDictionary *decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:FxGripDictionary.class fromData:data error:&decodeError];

	XCTAssertNil(decodeError);
	XCTAssertTrue([decoded isKindOfClass:FxGripDictionary.class]);
	XCTAssertEqual(decoded.count, 2u);
	XCTAssertEqualObjects([decoded objectForKey:@"s"], @"str");
	XCTAssertEqualObjects([decoded objectForKey:@"n"], @(3.5));
	XCTAssertTrue([decoded isEqual:original]);
}

- (void)testSecureCodingRoundTripCarriesNestedContainersAndFxTimeValues
{
	FxTime *time = (FxTime *)[[NSClassFromString(@"FxTime") alloc] initWithTime:300 timescale:600];
	XCTAssertNotNil(time);

	FxGripDictionary *original = [FxGripDictionary.alloc initWithDictionary:@{@"nested": @{@"inner": @[@(1), @"two"]},
																			 @"list": @[@[@(3)]],
																			 @"time": time}];

	NSError *encodeError = nil;
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:original requiringSecureCoding:YES error:&encodeError];
	XCTAssertNil(encodeError);

	NSError *decodeError = nil;
	FxGripDictionary *decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:FxGripDictionary.class fromData:data error:&decodeError];

	XCTAssertNil(decodeError);
	XCTAssertTrue([decoded isKindOfClass:FxGripDictionary.class]);
	XCTAssertEqual(decoded.count, 3u);

	NSDictionary *nested = (NSDictionary *)[decoded objectForKey:@"nested"];
	NSArray *list = (NSArray *)[decoded objectForKey:@"list"];
	XCTAssertEqualObjects(nested[@"inner"], (@[@(1), @"two"]));
	XCTAssertEqualObjects(list[0], @[@(3)]);

	FxTime *decodedTime = (FxTime *)[decoded objectForKey:@"time"];
	XCTAssertTrue([decodedTime isKindOfClass:NSClassFromString(@"FxTime")]);
	XCTAssertEqualWithAccuracy(decodedTime.seconds, 0.5, 1e-12);
}

- (void)testADecodedDictionaryIsDeeplyMutable
{
	FxGripDictionary *original = [FxGripDictionary.alloc initWithDictionary:@{@"nested": @{@"inner": @[@(1)]}}];
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:original requiringSecureCoding:YES error:NULL];

	FxGripDictionary *decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:FxGripDictionary.class fromData:data error:NULL];

	NSMutableDictionary *nested = (NSMutableDictionary *)[decoded objectForKey:@"nested"];
	XCTAssertTrue([nested isKindOfClass:NSMutableDictionary.class]);

	NSMutableArray *inner = nested[@"inner"];
	XCTAssertTrue([inner isKindOfClass:NSMutableArray.class]);

	XCTAssertNoThrow([inner addObject:@(2)]);
	XCTAssertNoThrow(nested[@"added"] = @"ok");
	XCTAssertEqual(inner.count, 2u);
}

@end
