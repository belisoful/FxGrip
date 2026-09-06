//
//  FxGripFrameDataTests.m
//  FxGripTests
//
//  Unit tests for the per-frame record store: inline records under NSNumber frame keys, the
//  reserved header entries, the seek helpers, and the size-gated spill to the machine-local
//  cache folder.
//
//  Every spill writes below a per-test folder under NSTemporaryDirectory(), removed in
//  tearDown. FxGripFrameData.h reaches its superclass through a quoted include that does not
//  resolve outside the framework target, so the surface under test is re-declared here and
//  the reserved keys mirror the #defines in that header.
//

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripImageBuffer.h>

#define kFxGripFrameDataKey_InstanceUUID	@"__instanceUUID"
#define kFxGripFrameDataKey_SpillThreshold	@"__spillThreshold"
#define kFxGripFrameDataKey_SpillFile		@"__fxSpilledFrame"
#define kFxGripFrameDataKey_SpillLength		@"__fxSpilledLength"

static const NSInteger kFrameDataDefaultSpillThreshold = 4 * 1024 * 1024;
static const NSInteger kFxGripFrameDataNeverSpill = -1;

@interface FxGripDictionary : NSMutableDictionary
+ (NSOrderedSet<Class> *)classesForParameter;
- (NSOrderedSet<Class> *)classesForParameter;
@end

@interface FxGripFrameData : FxGripDictionary

@property (copy, nullable, nonatomic) NSURL *cacheURL;
@property (assign, nonatomic) NSInteger spillThreshold;
@property (readonly, nonnull, nonatomic) NSString *instanceUUID;

- (nullable NSObject<NSSecureCoding, NSCopying> *)recordAtIndex:(NSInteger)index;
- (BOOL)setRecord:(nonnull NSObject<NSSecureCoding, NSCopying> *)record atIndex:(NSInteger)index;
- (void)removeRecordAtIndex:(NSInteger)index;
- (nonnull NSArray<NSNumber *> *)frameIndexes;
- (NSInteger)latestIndexAtOrBefore:(NSInteger)index;
- (nullable NSObject<NSSecureCoding, NSCopying> *)latestRecordAtOrBefore:(NSInteger)index;
- (BOOL)attachProjectMediaCacheForEffect:(nullable id)effect;

@end

/*! Stands in for an effect whose project may or may not have a media folder. */
@interface FxGripFrameDataTestMediaEffect : NSObject
@property (nonatomic, strong, nullable) NSURL *projectMediaFolder;
@end

@implementation FxGripFrameDataTestMediaEffect

- (id)effectBase
{
	// The stub plays the full effect; rich reads route back to it, as the old cast did.
	return self;
}

@end


@interface FxGripFrameDataTests : XCTestCase
@property (nonatomic, strong) FxGripFrameData *store;
@property (nonatomic, strong) NSURL *sandboxURL;
@end

@implementation FxGripFrameDataTests

- (void)setUp
{
	[super setUp];
	self.sandboxURL = [[NSURL fileURLWithPath:NSTemporaryDirectory()]
					   URLByAppendingPathComponent:NSUUID.UUID.UUIDString isDirectory:YES];
	[NSFileManager.defaultManager createDirectoryAtURL:self.sandboxURL
						   withIntermediateDirectories:YES
											attributes:nil
												 error:NULL];
	self.store = [FxGripFrameData.alloc init];
}

- (void)tearDown
{
	self.store = nil;
	[NSFileManager.defaultManager removeItemAtURL:self.sandboxURL error:NULL];
	self.sandboxURL = nil;
	[super tearDown];
}

#pragma mark Fixtures

/*! A record large enough to cross a small threshold, and one that compares by pixels. */
- (FxGripImageBuffer *)largeRecord
{
	const NSUInteger length = 32 * 32 * 4;
	NSMutableData *pixels = [NSMutableData dataWithLength:length];
	uint8_t *bytes = pixels.mutableBytes;
	uint32_t state = 0x7A5C1E3Du;
	for (NSUInteger index = 0; index < length; index++) {
		state = state * 1664525u + 1013904223u;
		bytes[index] = (uint8_t)(state >> 24);
	}
	return [FxGripImageBuffer.alloc initWithBytes:pixels.bytes
										 rowBytes:32 * 4
											width:32
										   height:32
										   format:FxGripPixelFormatRGBA8U
									  compression:FxGripCompressionLZFSE];
}

- (NSURL *)spillFileURLForIndex:(NSInteger)index
{
	return [[self.sandboxURL URLByAppendingPathComponent:self.store.instanceUUID isDirectory:YES]
			URLByAppendingPathComponent:[NSString stringWithFormat:@"%ld.fxframe", (long)index] isDirectory:NO];
}

/*! A store whose spill gate is open and set low enough for the large record to cross it. */
- (void)enableSpillWithThreshold:(NSInteger)threshold
{
	self.store.cacheURL = self.sandboxURL;
	self.store.spillThreshold = threshold;
}

- (NSData *)archivedStore
{
	return [NSKeyedArchiver archivedDataWithRootObject:self.store requiringSecureCoding:YES error:NULL];
}

/*! Reads the archive back through the same -initWithCoder: without the secure gate;
	testTheStoreSurvivesASecureArchiveRoundTrip covers the secure path. */
- (FxGripFrameData *)decodedStore
{
	NSKeyedUnarchiver *unarchiver = [NSKeyedUnarchiver.alloc initForReadingFromData:[self archivedStore] error:NULL];
	unarchiver.requiresSecureCoding = NO;
	return [unarchiver decodeObjectForKey:NSKeyedArchiveRootObjectKey];
}

#pragma mark Inline records

- (void)testARecordRoundTripsThroughItsFrameIndex
{
	XCTAssertTrue([self.store setRecord:@"frame seven" atIndex:7]);

	XCTAssertEqualObjects([self.store recordAtIndex:7], @"frame seven");
}

- (void)testAnUnsetFrameIndexHasNoRecord
{
	[self.store setRecord:@"frame seven" atIndex:7];

	XCTAssertNil([self.store recordAtIndex:8]);
}

- (void)testARecordAtANegativeIndexRoundTrips
{
	XCTAssertTrue([self.store setRecord:@"before zero" atIndex:-4]);

	XCTAssertEqualObjects([self.store recordAtIndex:-4], @"before zero");
}

- (void)testSettingARecordTwiceKeepsTheLastOne
{
	[self.store setRecord:@"first" atIndex:3];
	[self.store setRecord:@"second" atIndex:3];

	XCTAssertEqualObjects([self.store recordAtIndex:3], @"second");
	XCTAssertEqual(self.store.frameIndexes.count, 1u);
}

- (void)testSetRecordRefusesANilRecord
{
	NSObject<NSSecureCoding, NSCopying> *record = nil;

	XCTAssertFalse([self.store setRecord:record atIndex:1]);
	XCTAssertEqualObjects(self.store.frameIndexes, @[]);
}

- (void)testRemoveRecordDropsTheFrameIndex
{
	[self.store setRecord:@"frame" atIndex:2];

	[self.store removeRecordAtIndex:2];

	XCTAssertNil([self.store recordAtIndex:2]);
	XCTAssertEqualObjects(self.store.frameIndexes, @[]);
}

- (void)testRemovingAnAbsentRecordIsHarmless
{
	[self.store removeRecordAtIndex:99];

	XCTAssertEqualObjects(self.store.frameIndexes, @[]);
}

#pragma mark frameIndexes

- (void)testFrameIndexesAreSortedAscending
{
	[self.store setRecord:@"c" atIndex:12];
	[self.store setRecord:@"a" atIndex:-3];
	[self.store setRecord:@"b" atIndex:4];

	XCTAssertEqualObjects(self.store.frameIndexes, (@[@(-3), @4, @12]));
}

- (void)testFrameIndexesExcludeTheHeaderKeys
{
	self.store.spillThreshold = 2048;
	(void)self.store.instanceUUID;
	[self.store setRecord:@"a" atIndex:1];

	XCTAssertEqualObjects(self.store.frameIndexes, @[@1]);
	XCTAssertNotNil([self.store objectForKey:kFxGripFrameDataKey_SpillThreshold]);
	XCTAssertNotNil([self.store objectForKey:kFxGripFrameDataKey_InstanceUUID]);
}

- (void)testFrameIndexesOfAFreshStoreAreEmpty
{
	XCTAssertEqualObjects(self.store.frameIndexes, @[]);
}

#pragma mark latestIndexAtOrBefore:

- (void)testLatestIndexAtAStoredIndexIsThatIndex
{
	[self.store setRecord:@"a" atIndex:10];
	[self.store setRecord:@"b" atIndex:20];

	XCTAssertEqual([self.store latestIndexAtOrBefore:20], 20);
}

- (void)testLatestIndexBetweenStoredIndexesIsThePrecedingOne
{
	[self.store setRecord:@"a" atIndex:10];
	[self.store setRecord:@"b" atIndex:20];

	XCTAssertEqual([self.store latestIndexAtOrBefore:15], 10);
}

- (void)testLatestIndexBeyondTheLastStoredIndexIsThatIndex
{
	[self.store setRecord:@"a" atIndex:10];
	[self.store setRecord:@"b" atIndex:20];

	XCTAssertEqual([self.store latestIndexAtOrBefore:1000], 20);
}

- (void)testLatestIndexBeforeTheFirstRecordIsNotFound
{
	[self.store setRecord:@"a" atIndex:10];

	XCTAssertEqual([self.store latestIndexAtOrBefore:9], (NSInteger)NSNotFound);
}

- (void)testLatestIndexOfAnEmptyStoreIsNotFound
{
	XCTAssertEqual([self.store latestIndexAtOrBefore:0], (NSInteger)NSNotFound);
}

- (void)testLatestIndexResolvesNegativeIndexes
{
	[self.store setRecord:@"a" atIndex:-10];
	[self.store setRecord:@"b" atIndex:-2];

	XCTAssertEqual([self.store latestIndexAtOrBefore:-3], -10);
	XCTAssertEqual([self.store latestIndexAtOrBefore:-2], -2);
	XCTAssertEqual([self.store latestIndexAtOrBefore:-11], (NSInteger)NSNotFound);
}

- (void)testLatestIndexIgnoresTheHeaderKeys
{
	self.store.spillThreshold = 2048;
	(void)self.store.instanceUUID;

	XCTAssertEqual([self.store latestIndexAtOrBefore:1000], (NSInteger)NSNotFound);
}

#pragma mark latestRecordAtOrBefore:

- (void)testLatestRecordServesThePrecedingRecord
{
	[self.store setRecord:@"a" atIndex:10];
	[self.store setRecord:@"b" atIndex:20];

	XCTAssertEqualObjects([self.store latestRecordAtOrBefore:19], @"a");
}

- (void)testLatestRecordAtAStoredIndexIsItsOwnRecord
{
	[self.store setRecord:@"a" atIndex:10];

	XCTAssertEqualObjects([self.store latestRecordAtOrBefore:10], @"a");
}

- (void)testLatestRecordBeforeTheFirstRecordIsNil
{
	[self.store setRecord:@"a" atIndex:10];

	XCTAssertNil([self.store latestRecordAtOrBefore:9]);
}

#pragma mark Spill

- (void)testARecordAboveTheThresholdWritesToTheCacheFolder
{
	[self enableSpillWithThreshold:1024];

	XCTAssertTrue([self.store setRecord:[self largeRecord] atIndex:7]);

	XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:[self spillFileURLForIndex:7].path]);
}

- (void)testASpilledRecordLeavesAMarkerInTheStore
{
	[self enableSpillWithThreshold:1024];
	[self.store setRecord:[self largeRecord] atIndex:7];

	id marker = [self.store objectForKey:@7];

	XCTAssertTrue([marker isKindOfClass:NSDictionary.class]);
	XCTAssertEqualObjects(((NSDictionary *)marker)[kFxGripFrameDataKey_SpillFile], @"7.fxframe");
	XCTAssertGreaterThan(((NSNumber *)((NSDictionary *)marker)[kFxGripFrameDataKey_SpillLength]).unsignedIntegerValue, 1024u);
}

- (void)testASpilledRecordLoadsBackEqualToTheOriginal
{
	[self enableSpillWithThreshold:1024];
	FxGripImageBuffer *record = [self largeRecord];
	[self.store setRecord:record atIndex:7];

	XCTAssertEqualObjects([self.store recordAtIndex:7], record);
}

- (void)testASpilledRecordServesTheSeekHelpers
{
	[self enableSpillWithThreshold:1024];
	FxGripImageBuffer *record = [self largeRecord];
	[self.store setRecord:record atIndex:7];

	XCTAssertEqual([self.store latestIndexAtOrBefore:9], 7);
	XCTAssertEqualObjects([self.store latestRecordAtOrBefore:9], record);
}

- (void)testASpilledRecordAtANegativeIndexNamesItsFileForTheIndex
{
	[self enableSpillWithThreshold:1024];
	FxGripImageBuffer *record = [self largeRecord];

	[self.store setRecord:record atIndex:-5];

	XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:[self spillFileURLForIndex:-5].path]);
	XCTAssertEqualObjects([self.store recordAtIndex:-5], record);
}

- (void)testRemovingASpilledRecordDeletesItsCacheFile
{
	[self enableSpillWithThreshold:1024];
	[self.store setRecord:[self largeRecord] atIndex:7];
	NSURL *fileURL = [self spillFileURLForIndex:7];

	[self.store removeRecordAtIndex:7];

	XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:fileURL.path]);
	XCTAssertNil([self.store recordAtIndex:7]);
}

- (void)testASpilledRecordWhoseCacheFileIsGoneIsNil
{
	[self enableSpillWithThreshold:1024];
	[self.store setRecord:[self largeRecord] atIndex:7];

	[NSFileManager.defaultManager removeItemAtURL:[self spillFileURLForIndex:7] error:NULL];

	XCTAssertNil([self.store recordAtIndex:7]);
	XCTAssertEqualObjects(self.store.frameIndexes, @[@7]);
}

- (void)testARecordBelowTheThresholdStaysInline
{
	[self enableSpillWithThreshold:kFrameDataDefaultSpillThreshold];
	FxGripImageBuffer *record = [self largeRecord];

	[self.store setRecord:record atIndex:7];

	XCTAssertTrue([self.store objectForKey:@7] == record);
	XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:[self spillFileURLForIndex:7].path]);
}

- (void)testTheNeverSpillThresholdKeepsEveryRecordInline
{
	[self enableSpillWithThreshold:kFxGripFrameDataNeverSpill];
	FxGripImageBuffer *record = [self largeRecord];

	[self.store setRecord:record atIndex:7];

	XCTAssertTrue([self.store objectForKey:@7] == record);
	XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:[self spillFileURLForIndex:7].path]);
}

- (void)testAZeroThresholdSpillsEveryRecord
{
	[self enableSpillWithThreshold:0];

	[self.store setRecord:@"tiny" atIndex:7];

	XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:[self spillFileURLForIndex:7].path]);
	XCTAssertEqualObjects([self.store recordAtIndex:7], @"tiny");
}

- (void)testAttachingAnEffectWithAMediaFolderActivatesSpilling
{
	FxGripFrameDataTestMediaEffect *effect = FxGripFrameDataTestMediaEffect.new;
	effect.projectMediaFolder = self.sandboxURL;
	self.store.spillThreshold = 0;

	XCTAssertTrue([self.store attachProjectMediaCacheForEffect:effect]);
	[self.store setRecord:@"tiny" atIndex:3];

	XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:[self spillFileURLForIndex:3].path]);
}

/*! The user-domain folders are deliberately not a fallback: nothing ever clears them,
	while the media folder is deleted with its project. */
- (void)testAttachingAnEffectWithoutAMediaFolderClearsTheCacheAndKeepsRecordsInline
{
	[self enableSpillWithThreshold:0];
	FxGripFrameDataTestMediaEffect *effect = FxGripFrameDataTestMediaEffect.new;

	XCTAssertFalse([self.store attachProjectMediaCacheForEffect:effect]);
	[self.store setRecord:@"tiny" atIndex:3];

	XCTAssertNil(self.store.cacheURL);
	XCTAssertEqualObjects([self.store objectForKey:@3], @"tiny");
}

- (void)testAttachingANilEffectClearsTheCache
{
	[self enableSpillWithThreshold:0];

	XCTAssertFalse([self.store attachProjectMediaCacheForEffect:nil]);

	XCTAssertNil(self.store.cacheURL);
}

- (void)testWithoutACacheURLNothingSpills
{
	self.store.spillThreshold = 1024;
	FxGripImageBuffer *record = [self largeRecord];

	XCTAssertTrue([self.store setRecord:record atIndex:7]);

	XCTAssertTrue([self.store objectForKey:@7] == record);
	XCTAssertEqualObjects([self.store recordAtIndex:7], record);
}

- (void)testTheSpillFolderIsNamedForTheInstanceUUID
{
	[self enableSpillWithThreshold:1024];
	[self.store setRecord:[self largeRecord] atIndex:7];

	NSURL *folderURL = [self.sandboxURL URLByAppendingPathComponent:self.store.instanceUUID isDirectory:YES];

	XCTAssertEqualObjects([NSFileManager.defaultManager contentsOfDirectoryAtPath:folderURL.path error:NULL],
						  @[@"7.fxframe"]);
}

#pragma mark Configuration

- (void)testTheDefaultSpillThresholdIsFourMegabytes
{
	XCTAssertEqual(self.store.spillThreshold, kFrameDataDefaultSpillThreshold);
}

- (void)testTheSpillThresholdIsStoredUnderItsReservedKey
{
	self.store.spillThreshold = 2048;

	XCTAssertEqual(self.store.spillThreshold, 2048u);
	XCTAssertEqualObjects([self.store objectForKey:kFxGripFrameDataKey_SpillThreshold], @2048);
}

- (void)testTheInstanceUUIDIsStableAcrossReads
{
	NSString *first = self.store.instanceUUID;

	XCTAssertEqualObjects(self.store.instanceUUID, first);
	XCTAssertNotNil([NSUUID.alloc initWithUUIDString:first]);
}

- (void)testTwoStoresCarryDifferentInstanceUUIDs
{
	XCTAssertNotEqualObjects(self.store.instanceUUID, [FxGripFrameData.alloc init].instanceUUID);
}

- (void)testTheCacheURLReadsBackWhatWasSet
{
	self.store.cacheURL = self.sandboxURL;

	XCTAssertEqualObjects(self.store.cacheURL, self.sandboxURL);
}

#pragma mark classesForParameter

- (void)testTheParameterClassListCarriesTheImageBuffer
{
	XCTAssertTrue([FxGripFrameData.classesForParameter containsObject:FxGripImageBuffer.class]);
	XCTAssertTrue([self.store.classesForParameter containsObject:FxGripImageBuffer.class]);
}

- (void)testTheParameterClassListKeepsTheInheritedClasses
{
	NSOrderedSet<Class> *classes = FxGripFrameData.classesForParameter;

	XCTAssertTrue([classes containsObject:NSDictionary.class]);
	XCTAssertTrue([classes containsObject:NSNumber.class]);
	XCTAssertTrue([classes containsObject:NSString.class]);
	XCTAssertEqual(classes.count, FxGripDictionary.classesForParameter.count + 1u);
}

#pragma mark Secure coding

/*! The secure unarchiver rejects a concrete class that only inherits -classForCoder, so
	the store answers it itself. */
- (void)testTheStoreSurvivesASecureArchiveRoundTrip
{
	[self.store setRecord:@"frame seven" atIndex:7];

	FxGripFrameData *decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:FxGripFrameData.class
																fromData:[self archivedStore]
																   error:NULL];

	XCTAssertNotNil(decoded);
	XCTAssertEqualObjects([decoded recordAtIndex:7], @"frame seven");
}

/*! The root cause: the base class owns the override the subclass inherits. */
- (void)testTheBaseDictionarySurvivesASecureArchiveRoundTrip
{
	FxGripDictionary *base = [FxGripDictionary.alloc init];
	[base setObject:@"value" forKey:@"key"];
	NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:base requiringSecureCoding:YES error:NULL];

	FxGripDictionary *decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:FxGripDictionary.class
																 fromData:archive
																	error:NULL];

	XCTAssertEqualObjects([decoded objectForKey:@"key"], @"value");
}

- (void)testAnInlineRecordSurvivesTheArchiveRoundTrip
{
	[self.store setRecord:@"frame seven" atIndex:7];

	XCTAssertEqualObjects([[self decodedStore] recordAtIndex:7], @"frame seven");
}

- (void)testAnInlineImageBufferRecordSurvivesTheArchiveRoundTrip
{
	FxGripImageBuffer *record = [self largeRecord];
	[self.store setRecord:record atIndex:7];

	XCTAssertEqualObjects([[self decodedStore] recordAtIndex:7], record);
}

- (void)testTheSpillThresholdSurvivesTheArchiveRoundTrip
{
	self.store.spillThreshold = 2048;

	XCTAssertEqual([self decodedStore].spillThreshold, 2048u);
}

- (void)testTheInstanceUUIDSurvivesTheArchiveRoundTrip
{
	NSString *uuid = self.store.instanceUUID;

	XCTAssertEqualObjects([self decodedStore].instanceUUID, uuid);
}

- (void)testTheCacheURLIsNotEncoded
{
	self.store.cacheURL = self.sandboxURL;
	[self.store setRecord:@"frame" atIndex:1];

	XCTAssertNil([self decodedStore].cacheURL);
}

- (void)testASpilledMarkerSurvivesTheArchiveRoundTripAndResolvesOnceTheCacheURLIsRestored
{
	[self enableSpillWithThreshold:1024];
	FxGripImageBuffer *record = [self largeRecord];
	[self.store setRecord:record atIndex:7];

	FxGripFrameData *decoded = [self decodedStore];

	XCTAssertNil([decoded recordAtIndex:7]);
	XCTAssertEqualObjects(decoded.frameIndexes, @[@7]);

	decoded.cacheURL = self.sandboxURL;

	XCTAssertEqualObjects([decoded recordAtIndex:7], record);
}

@end
