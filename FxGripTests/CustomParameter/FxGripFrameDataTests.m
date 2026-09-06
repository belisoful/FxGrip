/*!
	@file       FxGripFrameDataTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripFrameDataTests
	@abstract   Tests for FxGripFrameData, the per-frame record store with size-gated spill to a cache folder.
	@discussion Introduced in FxGrip 0.1.0. The tests cover inline records under frame indexes, the sorted frame index that excludes the reserved header keys, the seek helpers, the threshold-driven spill to and reload from the cache folder, media-folder attachment, and secure coding.
*/

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

/*! @abstract A record set at a frame index reads back equal at that index. */
- (void)testARecordRoundTripsThroughItsFrameIndex
{
	XCTAssertTrue([self.store setRecord:@"frame seven" atIndex:7]);

	XCTAssertEqualObjects([self.store recordAtIndex:7], @"frame seven");
}

/*! @abstract An unset frame index has no record. */
- (void)testAnUnsetFrameIndexHasNoRecord
{
	[self.store setRecord:@"frame seven" atIndex:7];

	XCTAssertNil([self.store recordAtIndex:8]);
}

/*! @abstract A record set at a negative index reads back equal. */
- (void)testARecordAtANegativeIndexRoundTrips
{
	XCTAssertTrue([self.store setRecord:@"before zero" atIndex:-4]);

	XCTAssertEqualObjects([self.store recordAtIndex:-4], @"before zero");
}

/*! @abstract Setting a record twice at one index keeps the last value and one frame index. */
- (void)testSettingARecordTwiceKeepsTheLastOne
{
	[self.store setRecord:@"first" atIndex:3];
	[self.store setRecord:@"second" atIndex:3];

	XCTAssertEqualObjects([self.store recordAtIndex:3], @"second");
	XCTAssertEqual(self.store.frameIndexes.count, 1u);
}

/*! @abstract Setting a nil record returns NO and stores nothing. */
- (void)testSetRecordRefusesANilRecord
{
	NSObject<NSSecureCoding, NSCopying> *record = nil;

	XCTAssertFalse([self.store setRecord:record atIndex:1]);
	XCTAssertEqualObjects(self.store.frameIndexes, @[]);
}

/*! @abstract Removing a record clears it and drops its frame index. */
- (void)testRemoveRecordDropsTheFrameIndex
{
	[self.store setRecord:@"frame" atIndex:2];

	[self.store removeRecordAtIndex:2];

	XCTAssertNil([self.store recordAtIndex:2]);
	XCTAssertEqualObjects(self.store.frameIndexes, @[]);
}

/*! @abstract Removing an absent record leaves the store empty. */
- (void)testRemovingAnAbsentRecordIsHarmless
{
	[self.store removeRecordAtIndex:99];

	XCTAssertEqualObjects(self.store.frameIndexes, @[]);
}

#pragma mark frameIndexes

/*! @abstract frameIndexes returns the stored indexes sorted ascending. */
- (void)testFrameIndexesAreSortedAscending
{
	[self.store setRecord:@"c" atIndex:12];
	[self.store setRecord:@"a" atIndex:-3];
	[self.store setRecord:@"b" atIndex:4];

	XCTAssertEqualObjects(self.store.frameIndexes, (@[@(-3), @4, @12]));
}

/*! @abstract frameIndexes excludes the reserved header keys that share the backing dictionary. */
- (void)testFrameIndexesExcludeTheHeaderKeys
{
	self.store.spillThreshold = 2048;
	(void)self.store.instanceUUID;
	[self.store setRecord:@"a" atIndex:1];

	XCTAssertEqualObjects(self.store.frameIndexes, @[@1]);
	XCTAssertNotNil([self.store objectForKey:kFxGripFrameDataKey_SpillThreshold]);
	XCTAssertNotNil([self.store objectForKey:kFxGripFrameDataKey_InstanceUUID]);
}

/*! @abstract frameIndexes of a fresh store is empty. */
- (void)testFrameIndexesOfAFreshStoreAreEmpty
{
	XCTAssertEqualObjects(self.store.frameIndexes, @[]);
}

#pragma mark latestIndexAtOrBefore:

/*! @abstract -latestIndexAtOrBefore: returns a stored index when queried at that index. */
- (void)testLatestIndexAtAStoredIndexIsThatIndex
{
	[self.store setRecord:@"a" atIndex:10];
	[self.store setRecord:@"b" atIndex:20];

	XCTAssertEqual([self.store latestIndexAtOrBefore:20], 20);
}

/*! @abstract -latestIndexAtOrBefore: between two stored indexes returns the preceding one. */
- (void)testLatestIndexBetweenStoredIndexesIsThePrecedingOne
{
	[self.store setRecord:@"a" atIndex:10];
	[self.store setRecord:@"b" atIndex:20];

	XCTAssertEqual([self.store latestIndexAtOrBefore:15], 10);
}

/*! @abstract -latestIndexAtOrBefore: past the last stored index returns that last index. */
- (void)testLatestIndexBeyondTheLastStoredIndexIsThatIndex
{
	[self.store setRecord:@"a" atIndex:10];
	[self.store setRecord:@"b" atIndex:20];

	XCTAssertEqual([self.store latestIndexAtOrBefore:1000], 20);
}

/*! @abstract -latestIndexAtOrBefore: an index below the first record returns NSNotFound. */
- (void)testLatestIndexBeforeTheFirstRecordIsNotFound
{
	[self.store setRecord:@"a" atIndex:10];

	XCTAssertEqual([self.store latestIndexAtOrBefore:9], (NSInteger)NSNotFound);
}

/*! @abstract -latestIndexAtOrBefore: on an empty store returns NSNotFound. */
- (void)testLatestIndexOfAnEmptyStoreIsNotFound
{
	XCTAssertEqual([self.store latestIndexAtOrBefore:0], (NSInteger)NSNotFound);
}

/*! @abstract -latestIndexAtOrBefore: resolves negative indexes and returns NSNotFound below the first. */
- (void)testLatestIndexResolvesNegativeIndexes
{
	[self.store setRecord:@"a" atIndex:-10];
	[self.store setRecord:@"b" atIndex:-2];

	XCTAssertEqual([self.store latestIndexAtOrBefore:-3], -10);
	XCTAssertEqual([self.store latestIndexAtOrBefore:-2], -2);
	XCTAssertEqual([self.store latestIndexAtOrBefore:-11], (NSInteger)NSNotFound);
}

/*! @abstract -latestIndexAtOrBefore: ignores the reserved header keys and returns NSNotFound when only they are present. */
- (void)testLatestIndexIgnoresTheHeaderKeys
{
	self.store.spillThreshold = 2048;
	(void)self.store.instanceUUID;

	XCTAssertEqual([self.store latestIndexAtOrBefore:1000], (NSInteger)NSNotFound);
}

#pragma mark latestRecordAtOrBefore:

/*! @abstract -latestRecordAtOrBefore: serves the record at the preceding stored index. */
- (void)testLatestRecordServesThePrecedingRecord
{
	[self.store setRecord:@"a" atIndex:10];
	[self.store setRecord:@"b" atIndex:20];

	XCTAssertEqualObjects([self.store latestRecordAtOrBefore:19], @"a");
}

/*! @abstract -latestRecordAtOrBefore: a stored index returns that index's own record. */
- (void)testLatestRecordAtAStoredIndexIsItsOwnRecord
{
	[self.store setRecord:@"a" atIndex:10];

	XCTAssertEqualObjects([self.store latestRecordAtOrBefore:10], @"a");
}

/*! @abstract -latestRecordAtOrBefore: an index below the first record is nil. */
- (void)testLatestRecordBeforeTheFirstRecordIsNil
{
	[self.store setRecord:@"a" atIndex:10];

	XCTAssertNil([self.store latestRecordAtOrBefore:9]);
}

#pragma mark Spill

/*! @abstract A record above the spill threshold writes a file into the cache folder. */
- (void)testARecordAboveTheThresholdWritesToTheCacheFolder
{
	[self enableSpillWithThreshold:1024];

	XCTAssertTrue([self.store setRecord:[self largeRecord] atIndex:7]);

	XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:[self spillFileURLForIndex:7].path]);
}

/*! @abstract A spilled record leaves a marker dictionary naming its file and length in the store. */
- (void)testASpilledRecordLeavesAMarkerInTheStore
{
	[self enableSpillWithThreshold:1024];
	[self.store setRecord:[self largeRecord] atIndex:7];

	id marker = [self.store objectForKey:@7];

	XCTAssertTrue([marker isKindOfClass:NSDictionary.class]);
	XCTAssertEqualObjects(((NSDictionary *)marker)[kFxGripFrameDataKey_SpillFile], @"7.fxframe");
	XCTAssertGreaterThan(((NSNumber *)((NSDictionary *)marker)[kFxGripFrameDataKey_SpillLength]).unsignedIntegerValue, 1024u);
}

/*! @abstract A spilled record loads back from its file equal to the original. */
- (void)testASpilledRecordLoadsBackEqualToTheOriginal
{
	[self enableSpillWithThreshold:1024];
	FxGripImageBuffer *record = [self largeRecord];
	[self.store setRecord:record atIndex:7];

	XCTAssertEqualObjects([self.store recordAtIndex:7], record);
}

/*! @abstract A spilled record is served through the seek helpers. */
- (void)testASpilledRecordServesTheSeekHelpers
{
	[self enableSpillWithThreshold:1024];
	FxGripImageBuffer *record = [self largeRecord];
	[self.store setRecord:record atIndex:7];

	XCTAssertEqual([self.store latestIndexAtOrBefore:9], 7);
	XCTAssertEqualObjects([self.store latestRecordAtOrBefore:9], record);
}

/*! @abstract A spilled record at a negative index names its file for the index and loads back equal. */
- (void)testASpilledRecordAtANegativeIndexNamesItsFileForTheIndex
{
	[self enableSpillWithThreshold:1024];
	FxGripImageBuffer *record = [self largeRecord];

	[self.store setRecord:record atIndex:-5];

	XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:[self spillFileURLForIndex:-5].path]);
	XCTAssertEqualObjects([self.store recordAtIndex:-5], record);
}

/*! @abstract Removing a spilled record deletes its cache file and clears the record. */
- (void)testRemovingASpilledRecordDeletesItsCacheFile
{
	[self enableSpillWithThreshold:1024];
	[self.store setRecord:[self largeRecord] atIndex:7];
	NSURL *fileURL = [self spillFileURLForIndex:7];

	[self.store removeRecordAtIndex:7];

	XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:fileURL.path]);
	XCTAssertNil([self.store recordAtIndex:7]);
}

/*! @abstract A spilled record whose cache file is gone reads as nil while its frame index remains. */
- (void)testASpilledRecordWhoseCacheFileIsGoneIsNil
{
	[self enableSpillWithThreshold:1024];
	[self.store setRecord:[self largeRecord] atIndex:7];

	[NSFileManager.defaultManager removeItemAtURL:[self spillFileURLForIndex:7] error:NULL];

	XCTAssertNil([self.store recordAtIndex:7]);
	XCTAssertEqualObjects(self.store.frameIndexes, @[@7]);
}

/*! @abstract A record below the threshold stays inline and writes no cache file. */
- (void)testARecordBelowTheThresholdStaysInline
{
	[self enableSpillWithThreshold:kFrameDataDefaultSpillThreshold];
	FxGripImageBuffer *record = [self largeRecord];

	[self.store setRecord:record atIndex:7];

	XCTAssertTrue([self.store objectForKey:@7] == record);
	XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:[self spillFileURLForIndex:7].path]);
}

/*! @abstract The never-spill threshold keeps every record inline. */
- (void)testTheNeverSpillThresholdKeepsEveryRecordInline
{
	[self enableSpillWithThreshold:kFxGripFrameDataNeverSpill];
	FxGripImageBuffer *record = [self largeRecord];

	[self.store setRecord:record atIndex:7];

	XCTAssertTrue([self.store objectForKey:@7] == record);
	XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:[self spillFileURLForIndex:7].path]);
}

/*! @abstract A zero threshold spills every record, including a tiny one, and loads it back. */
- (void)testAZeroThresholdSpillsEveryRecord
{
	[self enableSpillWithThreshold:0];

	[self.store setRecord:@"tiny" atIndex:7];

	XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:[self spillFileURLForIndex:7].path]);
	XCTAssertEqualObjects([self.store recordAtIndex:7], @"tiny");
}

/*! @abstract Attaching an effect that has a project media folder activates spilling into that folder. */
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

/*! @abstract Attaching a nil effect returns NO and clears the cache URL. */
- (void)testAttachingANilEffectClearsTheCache
{
	[self enableSpillWithThreshold:0];

	XCTAssertFalse([self.store attachProjectMediaCacheForEffect:nil]);

	XCTAssertNil(self.store.cacheURL);
}

/*! @abstract Without a cache URL a large record stays inline and reads back equal. */
- (void)testWithoutACacheURLNothingSpills
{
	self.store.spillThreshold = 1024;
	FxGripImageBuffer *record = [self largeRecord];

	XCTAssertTrue([self.store setRecord:record atIndex:7]);

	XCTAssertTrue([self.store objectForKey:@7] == record);
	XCTAssertEqualObjects([self.store recordAtIndex:7], record);
}

/*! @abstract The spill folder is named for the store's instance UUID. */
- (void)testTheSpillFolderIsNamedForTheInstanceUUID
{
	[self enableSpillWithThreshold:1024];
	[self.store setRecord:[self largeRecord] atIndex:7];

	NSURL *folderURL = [self.sandboxURL URLByAppendingPathComponent:self.store.instanceUUID isDirectory:YES];

	XCTAssertEqualObjects([NSFileManager.defaultManager contentsOfDirectoryAtPath:folderURL.path error:NULL],
						  @[@"7.fxframe"]);
}

#pragma mark Configuration

/*! @abstract The default spill threshold is four megabytes. */
- (void)testTheDefaultSpillThresholdIsFourMegabytes
{
	XCTAssertEqual(self.store.spillThreshold, kFrameDataDefaultSpillThreshold);
}

/*! @abstract The spill threshold is stored under its reserved key. */
- (void)testTheSpillThresholdIsStoredUnderItsReservedKey
{
	self.store.spillThreshold = 2048;

	XCTAssertEqual(self.store.spillThreshold, 2048u);
	XCTAssertEqualObjects([self.store objectForKey:kFxGripFrameDataKey_SpillThreshold], @2048);
}

/*! @abstract The instance UUID is a stable, valid UUID across reads. */
- (void)testTheInstanceUUIDIsStableAcrossReads
{
	NSString *first = self.store.instanceUUID;

	XCTAssertEqualObjects(self.store.instanceUUID, first);
	XCTAssertNotNil([NSUUID.alloc initWithUUIDString:first]);
}

/*! @abstract Two stores carry different instance UUIDs. */
- (void)testTwoStoresCarryDifferentInstanceUUIDs
{
	XCTAssertNotEqualObjects(self.store.instanceUUID, [FxGripFrameData.alloc init].instanceUUID);
}

/*! @abstract The cache URL reads back the value that was set. */
- (void)testTheCacheURLReadsBackWhatWasSet
{
	self.store.cacheURL = self.sandboxURL;

	XCTAssertEqualObjects(self.store.cacheURL, self.sandboxURL);
}

#pragma mark classesForParameter

/*! @abstract The parameter class list carries FxGripImageBuffer at both the class and instance level. */
- (void)testTheParameterClassListCarriesTheImageBuffer
{
	XCTAssertTrue([FxGripFrameData.classesForParameter containsObject:FxGripImageBuffer.class]);
	XCTAssertTrue([self.store.classesForParameter containsObject:FxGripImageBuffer.class]);
}

/*! @abstract The parameter class list adds the image buffer to the classes inherited from the base dictionary. */
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

/*! @abstract An inline record survives the archive round trip. */
- (void)testAnInlineRecordSurvivesTheArchiveRoundTrip
{
	[self.store setRecord:@"frame seven" atIndex:7];

	XCTAssertEqualObjects([[self decodedStore] recordAtIndex:7], @"frame seven");
}

/*! @abstract An inline image-buffer record survives the archive round trip. */
- (void)testAnInlineImageBufferRecordSurvivesTheArchiveRoundTrip
{
	FxGripImageBuffer *record = [self largeRecord];
	[self.store setRecord:record atIndex:7];

	XCTAssertEqualObjects([[self decodedStore] recordAtIndex:7], record);
}

/*! @abstract The spill threshold survives the archive round trip. */
- (void)testTheSpillThresholdSurvivesTheArchiveRoundTrip
{
	self.store.spillThreshold = 2048;

	XCTAssertEqual([self decodedStore].spillThreshold, 2048u);
}

/*! @abstract The instance UUID survives the archive round trip. */
- (void)testTheInstanceUUIDSurvivesTheArchiveRoundTrip
{
	NSString *uuid = self.store.instanceUUID;

	XCTAssertEqualObjects([self decodedStore].instanceUUID, uuid);
}

/*! @abstract The cache URL is not encoded, so a decoded store carries no cache URL. */
- (void)testTheCacheURLIsNotEncoded
{
	self.store.cacheURL = self.sandboxURL;
	[self.store setRecord:@"frame" atIndex:1];

	XCTAssertNil([self decodedStore].cacheURL);
}

/*! @abstract A spilled marker survives the archive round trip and resolves to its record once the cache URL is restored. */
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
