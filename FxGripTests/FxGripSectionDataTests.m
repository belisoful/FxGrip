//
//  FxGripSectionDataTests.m
//  FxGripTests
//

#import <XCTest/XCTest.h>
#import <objc/message.h>
#import <FxPlug/FxTypes.h>

// FxGripSectionData.h is not a public framework header, so the surface under test is
// re-declared locally. The reserved keys mirror the #defines in FxGripDictionary.h.
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

@interface FxGripSectionData : NSObject <NSSecureCoding, NSCopying>

@property (strong, readonly) NSMutableDictionary *data;
@property (assign, readonly) NSMutableArray *exemptKeys;
@property (assign, readonly) BOOL isLocked;
@property (assign, getter=isLocked) BOOL locked;

- (instancetype)initWithDictionary:(NSDictionary *)dictionary;
- (instancetype)initWithObjects:(id const *)objects forKeys:(id<NSCopying> const *)keys count:(NSUInteger)cnt;
- (NSOrderedSet<Class> *)classesForParameter;

- (NSUInteger)count;
- (NSObject *)objectForKey:(id)aKey;
- (NSEnumerator *)keyEnumerator;
- (void)setObject:(id)anObject forKey:(id<NSCopying>)aKey;
- (void)removeObjectForKey:(id)aKey;

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


@interface FxGripSectionDataTests : XCTestCase
@property (nonatomic, strong) FxGripSectionData *section;
@end

@implementation FxGripSectionDataTests

- (void)setUp
{
	[super setUp];
	self.section = [FxGripSectionData.alloc init];
}

- (void)tearDown
{
	self.section = nil;
	[super tearDown];
}

#pragma mark - Construction

- (void)testInitCreatesAnEmptyBackingDictionary
{
	XCTAssertNotNil(self.section.data);
	XCTAssertEqual(self.section.count, 0u);
}

- (void)testInitWithDictionaryTakesAMutableSnapshotOfTheSource
{
	NSMutableDictionary *source = [@{@"a": @(1)} mutableCopy];
	FxGripSectionData *section = [FxGripSectionData.alloc initWithDictionary:source];

	source[@"b"] = @(2);

	XCTAssertEqualObjects(section.data, @{@"a": @(1)});
	XCTAssertEqual(section.count, 1u);
}

- (void)testInitWithObjectsForKeysCountPopulatesTheBackingDictionary
{
	id objects[2] = {@"alpha", @"beta"};
	id<NSCopying> keys[2] = {@"one", @"two"};

	FxGripSectionData *section = [FxGripSectionData.alloc initWithObjects:objects forKeys:keys count:2];

	XCTAssertEqual(section.count, 2u);
	XCTAssertEqualObjects([section objectForKey:@"two"], @"beta");
}

#pragma mark - Collection Primitives

- (void)testSetObjectForKeyWritesThroughToTheBackingDictionary
{
	[self.section setObject:@"value" forKey:@"key"];

	XCTAssertEqualObjects([self.section objectForKey:@"key"], @"value");
	XCTAssertEqualObjects(self.section.data[@"key"], @"value");
	XCTAssertEqual(self.section.count, 1u);
}

- (void)testRemoveObjectForKeyDeletesTheEntry
{
	[self.section setObject:@"value" forKey:@"key"];

	[self.section removeObjectForKey:@"key"];

	XCTAssertNil([self.section objectForKey:@"key"]);
	XCTAssertEqual(self.section.count, 0u);
}

- (void)testKeyEnumeratorWalksTheBackingDictionary
{
	[self.section setObject:@(1) forKey:@"a"];
	[self.section setObject:@(2) forKey:@"b"];

	NSMutableSet *seen = NSMutableSet.set;
	for (id key in [self.section keyEnumerator]) {
		[seen addObject:key];
	}

	XCTAssertEqualObjects(seen, ([NSSet setWithArray:@[@"a", @"b"]]));
}

#pragma mark - Keyed Typed Accessors

- (void)testBoolValueRoundTripsForAnArbitraryKey
{
	XCTAssertTrue([self.section setBoolValue:YES forKey:@"flag"]);

	BOOL value = NO;
	XCTAssertTrue([self.section getBoolValue:&value forKey:@"flag"]);
	XCTAssertTrue(value);
}

- (void)testBoolGetterRejectsMissingAndNonNumberValues
{
	[self.section setObject:@"text" forKey:@"s"];

	BOOL value = YES;
	XCTAssertFalse([self.section getBoolValue:&value forKey:@"absent"]);
	XCTAssertFalse([self.section getBoolValue:&value forKey:@"s"]);
}

- (void)testFloatValueRoundTripsForAnArbitraryKey
{
	XCTAssertTrue([self.section setFloatValue:-0.75 forKey:@"f"]);

	double value = 0.0;
	XCTAssertTrue([self.section getFloatValue:&value forKey:@"f"]);
	XCTAssertEqual(value, -0.75);
}

- (void)testIntValueRoundTripsForAnArbitraryKey
{
	XCTAssertTrue([self.section setIntValue:31 forKey:@"i"]);

	int value = 0;
	XCTAssertTrue([self.section getIntValue:&value forKey:@"i"]);
	XCTAssertEqual(value, 31);
}

- (void)testPathIDRoundTripsAsAnUnsignedNumber
{
	FxPathID path = (FxPathID)(uintptr_t)0xABCDEF;
	XCTAssertTrue([self.section setPathID:path forKey:@"p"]);
	XCTAssertEqualObjects(self.section.data[@"p"], @((unsigned long long)0xABCDEF));

	FxPathID readBack = NULL;
	XCTAssertTrue([self.section getPathID:&readBack forKey:@"p"]);
	XCTAssertEqual(readBack, path);
}

- (void)testPathIDGetterRejectsANonNumberValue
{
	[self.section setObject:@"nope" forKey:@"p"];

	FxPathID readBack = NULL;
	XCTAssertFalse([self.section getPathID:&readBack forKey:@"p"]);
	XCTAssertFalse([self.section getPathID:&readBack forKey:@"absent"]);
}

- (void)testStringParameterValueRoundTripsAndFormatsNumbers
{
	XCTAssertTrue([self.section setStringParameterValue:@"hello" forKey:@"s"]);
	[self.section setObject:@(12) forKey:@"n"];

	NSString *value = nil;
	XCTAssertTrue([self.section getStringParameterValue:&value forKey:@"s"]);
	XCTAssertEqualObjects(value, @"hello");

	XCTAssertTrue([self.section getStringParameterValue:&value forKey:@"n"]);
	XCTAssertEqualObjects(value, @"12");

	XCTAssertFalse([self.section getStringParameterValue:&value forKey:@"absent"]);
}

- (void)testRGBAValueRoundTripsAsAFourElementArray
{
	XCTAssertTrue([self.section setRedValue:0.1 greenValue:0.2 blueValue:0.3 alphaValue:0.4 forKey:@"c"]);
	XCTAssertEqualObjects(self.section.data[@"c"], (@[@(0.1), @(0.2), @(0.3), @(0.4)]));

	double r = 0, g = 0, b = 0, a = 0;
	XCTAssertTrue([self.section getRedValue:&r greenValue:&g blueValue:&b alphaValue:&a forKey:@"c"]);
	XCTAssertEqual(r, 0.1);
	XCTAssertEqual(a, 0.4);
}

- (void)testRGBAGetterExpandsShortArrays
{
	[self.section setObject:@[@(0.5)] forKey:@"gray"];
	[self.section setObject:@[@(0.1), @(0.2), @(0.3)] forKey:@"rgb"];

	double r = 0, g = 0, b = 0, a = 0;
	XCTAssertTrue([self.section getRedValue:&r greenValue:&g blueValue:&b alphaValue:&a forKey:@"gray"]);
	XCTAssertEqual(g, 0.5);
	XCTAssertEqual(a, 1.0);

	XCTAssertTrue([self.section getRedValue:&r greenValue:&g blueValue:&b alphaValue:&a forKey:@"rgb"]);
	XCTAssertEqual(b, 0.3);
	XCTAssertEqual(a, 1.0);
}

- (void)testRGBAGetterRejectsAnEmptyArrayAndANonArray
{
	[self.section setObject:@[] forKey:@"empty"];
	[self.section setObject:@(1) forKey:@"number"];

	double r = 0, g = 0, b = 0, a = 0;
	XCTAssertFalse([self.section getRedValue:&r greenValue:&g blueValue:&b alphaValue:&a forKey:@"empty"]);
	XCTAssertFalse([self.section getRedValue:&r greenValue:&g blueValue:&b alphaValue:&a forKey:@"number"]);
	XCTAssertFalse([self.section getRedValue:&r greenValue:&g blueValue:&b alphaValue:&a forKey:@"absent"]);
}

- (void)testRGBValueRoundTripsAsAThreeElementArray
{
	XCTAssertTrue([self.section setRedValue:0.9 greenValue:0.8 blueValue:0.7 forKey:@"c"]);

	double r = 0, g = 0, b = 0;
	XCTAssertTrue([self.section getRedValue:&r greenValue:&g blueValue:&b forKey:@"c"]);
	XCTAssertEqual(r, 0.9);
	XCTAssertEqual(g, 0.8);
	XCTAssertEqual(b, 0.7);
}

- (void)testRGBGetterExpandsAShortArrayAndRejectsEmptyValues
{
	[self.section setObject:@[@(0.75), @(0.0)] forKey:@"gray"];
	[self.section setObject:@[] forKey:@"empty"];

	double r = 0, g = 0, b = 0;
	XCTAssertTrue([self.section getRedValue:&r greenValue:&g blueValue:&b forKey:@"gray"]);
	XCTAssertEqual(r, 0.75);
	XCTAssertEqual(g, 0.75);
	XCTAssertEqual(b, 0.75);

	XCTAssertFalse([self.section getRedValue:&r greenValue:&g blueValue:&b forKey:@"empty"]);
	XCTAssertFalse([self.section getRedValue:&r greenValue:&g blueValue:&b forKey:@"absent"]);
}

- (void)testXYValueRoundTripsAsATwoElementArray
{
	XCTAssertTrue([self.section setXValue:3.0 YValue:-4.0 forKey:@"pt"]);
	XCTAssertEqualObjects(self.section.data[@"pt"], (@[@(3.0), @(-4.0)]));

	double x = 0, y = 0;
	XCTAssertTrue([self.section getXValue:&x YValue:&y forKey:@"pt"]);
	XCTAssertEqual(x, 3.0);
	XCTAssertEqual(y, -4.0);
}

- (void)testXYGetterRequiresExactlyTwoElements
{
	[self.section setObject:@[@(1.0), @(2.0), @(3.0)] forKey:@"pt"];

	double x = 0, y = 0;
	XCTAssertFalse([self.section getXValue:&x YValue:&y forKey:@"pt"]);
}

#pragma mark - Reserved Keys And Locking

- (void)testAFreshSectionIsLocked
{
	XCTAssertTrue(self.section.isLocked);
	XCTAssertNil([self.section objectForKey:kCustomAPI_IsLocked]);
}

- (void)testALockedSectionRefusesToCreateReservedKeys
{
	XCTAssertFalse([self.section setBoolValue:YES]);
	XCTAssertFalse([self.section setFloatValue:1.0]);
	XCTAssertFalse([self.section setIntValue:1]);
	XCTAssertFalse([self.section setStringParameterValue:@"s"]);
	XCTAssertFalse([self.section setXValue:1.0 YValue:2.0]);
	XCTAssertFalse([self.section setRedValue:0.1 greenValue:0.2 blueValue:0.3]);
	XCTAssertFalse([self.section setRedValue:0.1 greenValue:0.2 blueValue:0.3 alphaValue:0.4]);
	XCTAssertEqual(self.section.count, 0u);
}

- (void)testUnlockingStoresTheLockFlagAndAdmitsReservedKeys
{
	self.section.locked = NO;

	XCTAssertFalse(self.section.isLocked);
	XCTAssertEqualObjects([self.section objectForKey:kCustomAPI_IsLocked], @(NO));
	XCTAssertTrue([self.section setFloatValue:2.5]);
	XCTAssertEqualObjects(self.section.data[kCustomAPI_FloatKey], @(2.5));
}

- (void)testRelockingRemovesTheLockFlagAndLeavesOtherKeys
{
	self.section.locked = NO;
	[self.section setFloatValue:2.5];

	self.section.locked = YES;

	XCTAssertTrue(self.section.isLocked);
	XCTAssertNil([self.section objectForKey:kCustomAPI_IsLocked]);
	XCTAssertEqualObjects(self.section.data[kCustomAPI_FloatKey], @(2.5));
}

- (void)testALockedSectionStillUpdatesReservedKeysThatAlreadyExist
{
	[self.section setObject:@(1) forKey:kCustomAPI_IntKey];

	XCTAssertTrue([self.section setIntValue:99]);
	XCTAssertEqualObjects(self.section.data[kCustomAPI_IntKey], @(99));
}

- (void)testAnUnlockedSectionAcceptsEveryReservedSetter
{
	self.section.locked = NO;

	XCTAssertTrue([self.section setBoolValue:YES]);
	XCTAssertTrue([self.section setFloatValue:1.5]);
	XCTAssertTrue([self.section setIntValue:3]);
	XCTAssertTrue([self.section setStringParameterValue:@"s"]);
	XCTAssertTrue([self.section setXValue:1.0 YValue:2.0]);
	XCTAssertTrue([self.section setRedValue:0.1 greenValue:0.2 blueValue:0.3]);
	XCTAssertTrue([self.section setRedValue:0.4 greenValue:0.5 blueValue:0.6 alphaValue:0.7]);

	XCTAssertEqualObjects(self.section.data[kCustomAPI_BoolKey], @(YES));
	XCTAssertEqualObjects(self.section.data[kCustomAPI_StringKey], @"s");
	XCTAssertEqualObjects(self.section.data[kCustomAPI_PointKey], (@[@(1.0), @(2.0)]));
	XCTAssertEqualObjects(self.section.data[kCustomAPI_RGBKey], (@[@(0.1), @(0.2), @(0.3)]));
	XCTAssertEqualObjects(self.section.data[kCustomAPI_RGBAKey], (@[@(0.4), @(0.5), @(0.6), @(0.7)]));
}

- (void)testTheDefaultAccessorsReadTheReservedKeys
{
	[self.section setObject:@(YES) forKey:kCustomAPI_BoolKey];
	[self.section setObject:@(1.25) forKey:kCustomAPI_FloatKey];
	[self.section setObject:@(7) forKey:kCustomAPI_IntKey];
	[self.section setObject:@"str" forKey:kCustomAPI_StringKey];
	[self.section setObject:@(9) forKey:kCustomAPI_PathIDKey];
	[self.section setObject:@[@(1.0), @(2.0)] forKey:kCustomAPI_PointKey];
	[self.section setObject:@[@(0.1), @(0.2), @(0.3), @(0.4)] forKey:kCustomAPI_RGBAKey];
	[self.section setObject:@[@(0.5), @(0.6), @(0.7)] forKey:kCustomAPI_RGBKey];

	BOOL flag = NO;
	double f = 0, x = 0, y = 0, r = 0, g = 0, b = 0, a = 0;
	int i = 0;
	NSString *s = nil;
	FxPathID path = NULL;

	XCTAssertTrue([self.section getBoolValue:&flag]);
	XCTAssertTrue([self.section getFloatValue:&f]);
	XCTAssertTrue([self.section getIntValue:&i]);
	XCTAssertTrue([self.section getStringParameterValue:&s]);
	XCTAssertTrue([self.section getPathID:&path]);
	XCTAssertTrue([self.section getXValue:&x YValue:&y]);
	XCTAssertTrue([self.section getRedValue:&r greenValue:&g blueValue:&b alphaValue:&a]);
	XCTAssertTrue([self.section getRedValue:&r greenValue:&g blueValue:&b]);

	XCTAssertTrue(flag);
	XCTAssertEqual(f, 1.25);
	XCTAssertEqual(i, 7);
	XCTAssertEqualObjects(s, @"str");
	XCTAssertEqual((uintptr_t)path, 9u);
	XCTAssertEqual(y, 2.0);
	XCTAssertEqual(r, 0.5);
}

- (void)testTheDefaultGettersFailOnAnEmptySection
{
	BOOL flag = NO;
	double f = 0;
	int i = 0;

	XCTAssertFalse([self.section getBoolValue:&flag]);
	XCTAssertFalse([self.section getFloatValue:&f]);
	XCTAssertFalse([self.section getIntValue:&i]);
}

#pragma mark - Copying, Equality, Coding

- (void)testCopyProducesAnIndependentSectionWithEqualContents
{
	[self.section setObject:@"value" forKey:@"key"];

	FxGripSectionData *copy = [self.section copy];

	XCTAssertTrue([copy isKindOfClass:FxGripSectionData.class]);
	XCTAssertEqualObjects(self.section, copy);

	[copy setObject:@"other" forKey:@"key"];
	XCTAssertEqualObjects([self.section objectForKey:@"key"], @"value");
	XCTAssertNotEqualObjects(self.section, copy);
}

- (void)testIsEqualComparesTheBackingDictionaries
{
	[self.section setObject:@(1) forKey:@"a"];

	XCTAssertEqualObjects(self.section, [FxGripSectionData.alloc initWithDictionary:@{@"a": @(1)}]);
	XCTAssertNotEqualObjects(self.section, [FxGripSectionData.alloc initWithDictionary:@{@"a": @(2)}]);
	XCTAssertFalse([self.section isEqual:nil]);
}

- (void)testTheClassAdvertisesSecureCoding
{
	XCTAssertTrue([FxGripSectionData supportsSecureCoding]);
}

- (void)testTheParameterClassListCoversTheSupportedPayloadsWithoutNSColor
{
	NSOrderedSet<Class> *classes = [self.section classesForParameter];

	XCTAssertTrue([classes containsObject:NSMutableDictionary.class]);
	XCTAssertTrue([classes containsObject:NSString.class]);
	XCTAssertTrue([classes containsObject:NSNumber.class]);
	XCTAssertTrue([classes containsObject:NSClassFromString(@"FxTime")]);
	XCTAssertFalse([classes containsObject:NSClassFromString(@"NSColor")]);
	XCTAssertEqual(classes.count, 18u);
}

/*!
	-encodeWithCoder: writes the backing store as a property list, so decoding needs the
	container and leaf classes in the allow list alongside FxGripSectionData itself.
*/
- (void)testSecureCodingRoundTripPreservesTheBackingDictionary
{
	FxGripSectionData *original = [FxGripSectionData.alloc initWithDictionary:@{@"s": @"str",
																				@"n": @(3.5),
																				@"a": @[@(1), @(2)],
																				@"d": @{@"z": @"y"}}];

	NSError *encodeError = nil;
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:original requiringSecureCoding:YES error:&encodeError];
	XCTAssertNil(encodeError);
	XCTAssertNotNil(data);

	NSSet *allowed = [NSSet setWithArray:@[FxGripSectionData.class, NSMutableDictionary.class, NSDictionary.class,
										   NSMutableArray.class, NSArray.class, NSString.class, NSNumber.class]];
	NSError *decodeError = nil;
	FxGripSectionData *decoded = [NSKeyedUnarchiver unarchivedObjectOfClasses:allowed fromData:data error:&decodeError];

	XCTAssertNil(decodeError);
	XCTAssertTrue([decoded isKindOfClass:FxGripSectionData.class]);
	XCTAssertEqualObjects(decoded, original);
}

- (void)testNonSecureCodingRoundTripPreservesTheBackingDictionary
{
	[self.section setObject:@"v" forKey:@"k"];

	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.section requiringSecureCoding:NO error:NULL];
	NSSet *allowed = [NSSet setWithArray:@[FxGripSectionData.class, NSDictionary.class, NSString.class, NSNumber.class]];
	FxGripSectionData *decoded = [NSKeyedUnarchiver unarchivedObjectOfClasses:allowed fromData:data error:NULL];

	XCTAssertEqualObjects(decoded.data, @{@"k": @"v"});
}

#pragma mark - Histogram

- (void)testHistogramGetterReadsAWellFormedChannelArray
{
	NSArray *channel = @[@(0.1), @(0.2), @(0.8), @(0.9), @(1.5)];
	[self.section setObject:@[channel, channel, channel, channel] forKey:kCustomAPI_HistogramKey];

	double blackIn = -1, blackOut = -1, whiteIn = -1, whiteOut = -1, gamma = -1;
	BOOL read = [self.section getHistogramBlackIn:&blackIn
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

- (void)testHistogramSetterBuildsTheFourChannelStructureFromNothing
{
	XCTAssertTrue([self.section setHistogramBlackIn:0.1 blackOut:0.2 whiteIn:0.3 whiteOut:0.4 gamma:0.5
										 forChannel:kFxHistogramChannel_Green forKey:@"h"]);

	NSArray *histogram = (NSArray *)[self.section objectForKey:@"h"];

	XCTAssertEqual(histogram.count, 4u);
	XCTAssertEqualObjects(histogram[0], (@[@(0.0), @(0.0), @(1.0), @(1.0), @(1.0)]));
	XCTAssertEqualObjects(histogram[1], (@[@(0.1), @(0.2), @(0.3), @(0.4), @(0.5)]));
}

- (void)testEveryHistogramChannelRoundTripsIndependently
{
	FxHistogramChannel channels[4] = {kFxHistogramChannel_Red, kFxHistogramChannel_Green,
									  kFxHistogramChannel_Blue, kFxHistogramChannel_Alpha};

	for (int c = 0; c < 4; c++) {
		double base = (c + 1) * 10.0;
		XCTAssertTrue([self.section setHistogramBlackIn:base blackOut:base + 1 whiteIn:base + 2
											   whiteOut:base + 3 gamma:base + 4
											 forChannel:channels[c] forKey:@"h"]);
	}

	for (int c = 0; c < 4; c++) {
		double base = (c + 1) * 10.0;
		double blackIn = -1, blackOut = -1, whiteIn = -1, whiteOut = -1, gamma = -1;

		XCTAssertTrue([self.section getHistogramBlackIn:&blackIn blackOut:&blackOut whiteIn:&whiteIn
											   whiteOut:&whiteOut gamma:&gamma
											 forChannel:channels[c] forKey:@"h"]);
		XCTAssertEqual(blackIn, base);
		XCTAssertEqual(gamma, base + 4);
	}
}

- (void)testTheRGBChannelWritesTheThreeColorChannelsAndLeavesAlphaAlone
{
	[self.section setHistogramBlackIn:9.0 blackOut:9.1 whiteIn:9.2 whiteOut:9.3 gamma:9.4
						   forChannel:kFxHistogramChannel_Alpha forKey:@"h"];

	XCTAssertTrue([self.section setHistogramBlackIn:1.0 blackOut:2.0 whiteIn:3.0 whiteOut:4.0 gamma:5.0
										 forChannel:kFxHistogramChannel_RGB forKey:@"h"]);

	NSArray *histogram = (NSArray *)[self.section objectForKey:@"h"];
	NSArray *written = @[@(1.0), @(2.0), @(3.0), @(4.0), @(5.0)];

	XCTAssertEqualObjects(histogram[0], written);
	XCTAssertEqualObjects(histogram[1], written);
	XCTAssertEqualObjects(histogram[2], written);
	XCTAssertEqualObjects(histogram[3], (@[@(9.0), @(9.1), @(9.2), @(9.3), @(9.4)]));
}

#pragma mark - Path ID

- (void)testTheProtocolLevelPathIDSetterExists
{
	XCTAssertTrue([self.section respondsToSelector:NSSelectorFromString(@"setPathID:")]);
}

- (void)testTheMisspelledPathIDSetterNoLongerExists
{
	XCTAssertFalse([self.section respondsToSelector:NSSelectorFromString(@"etPathID:")]);
}

- (void)testTheProtocolLevelPathIDSetterWritesTheReservedKeyWhenUnlocked
{
	FxPathID path = (FxPathID)(uintptr_t)0x40;

	XCTAssertFalse([self.section setPathID:path], @"a locked section refuses the reserved key");

	self.section.locked = NO;
	XCTAssertTrue([self.section setPathID:path]);
	XCTAssertEqualObjects(self.section.data[kCustomAPI_PathIDKey], @(0x40));
}

#pragma mark - Equality

- (void)testEqualSectionsShareAHash
{
	[self.section setObject:@(1) forKey:@"a"];
	FxGripSectionData *same = [FxGripSectionData.alloc initWithDictionary:@{@"a": @(1)}];

	XCTAssertEqualObjects(self.section, same);
	XCTAssertEqual(self.section.hash, same.hash);
}

- (void)testIsEqualToAForeignObjectAnswersFalse
{
	BOOL equal = YES;
	XCTAssertNoThrow(equal = [self.section isEqual:@"a string"]);
	XCTAssertFalse(equal);
}

- (void)testDecodingWithOnlyTheReceiverClassAllowedSucceeds
{
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.section requiringSecureCoding:YES error:NULL];

	NSError *decodeError = nil;
	FxGripSectionData *decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:FxGripSectionData.class fromData:data error:&decodeError];

	XCTAssertNil(decodeError);
	XCTAssertNotNil(decoded);
	XCTAssertEqualObjects(decoded, self.section);
}

- (void)testExemptKeysSeedsTheReservedKeysAndWritesItselfBack
{
	NSMutableArray *exemptKeys = self.section.exemptKeys;

	XCTAssertNotNil(exemptKeys);
	XCTAssertTrue([exemptKeys containsObject:kCustomAPI_ExemptKeysKey]);
	XCTAssertTrue([exemptKeys containsObject:kCustomAPI_LastChangedKey]);
	XCTAssertEqualObjects([self.section objectForKey:kCustomAPI_ExemptKeysKey], exemptKeys);
}

@end
