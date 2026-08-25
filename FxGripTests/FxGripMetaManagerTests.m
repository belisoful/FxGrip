//
//  FxGripMetaManagerTests.m
//  FxGripTests
//

#import <XCTest/XCTest.h>
#import <dlfcn.h>
#import <FxPlug/FxTypes.h>
#import "FxGrip/FxGripTypes.h"
#import "FxGrip/FxGripMetaManager.h"

static const FxParameterId kParamA = 101;
static const FxParameterId kParamB = 202;
static const FxParameterId kParamMissing = 909;

/*!
	The test bundle does not link FxPlug.framework, and FxPlug is weak-linked by FxGrip, so
	the constant is read from the loaded images. Outside an FxPlug host the symbol is absent
	and FxGripErrors.h substitutes FxGripPlugErrorDomain.
*/
static NSString *FxGripTestsExpectedErrorDomain(void)
{
	NSString * __unsafe_unretained *domain = (NSString * __unsafe_unretained *)dlsym(RTLD_DEFAULT, "FxPlugErrorDomain");
	return domain ? *domain : FxGripPlugErrorDomainConstant;
}


@interface FxGripMetaManagerTests : XCTestCase
@property (nonatomic, strong) FxGripMetaManager *manager;
@end

@implementation FxGripMetaManagerTests

- (void)setUp
{
	[super setUp];
	self.manager = [FxGripMetaManager.alloc initWithEffect:nil];
}

- (void)tearDown
{
	self.manager = nil;
	[super tearDown];
}

- (void)assertError:(NSError *)error isFailureForParameter:(FxParameterId)parameterID
{
	NSString *domain = FxGripTestsExpectedErrorDomain();
	XCTAssertNotNil(error);
	XCTAssertEqualObjects(error.domain, domain);
	XCTAssertEqual(error.code, kFxError_ThirdPartyDeveloperStart + parameterID);
}

#pragma mark - Record Management

- (void)testAddParameterCreatesTheRecord
{
	XCTAssertFalse([self.manager parameterExists:kParamA]);
	XCTAssertTrue([self.manager addParameter:kParamA]);
	XCTAssertTrue([self.manager parameterExists:kParamA]);

	NSMutableDictionary *record = [self.manager parameterData:kParamA];
	XCTAssertNotNil(record);
	XCTAssertEqualObjects(record[kFxMetaProperty_ParamId], @(kParamA));
	XCTAssertEqual([self.manager tagCount:kParamA], 0);
	XCTAssertEqual([self.manager metaCountFromParameter:kParamA], 0);
}

- (void)testParameterDataReturnsTheLiveRecord
{
	XCTAssertTrue([self.manager addParameter:kParamA]);

	NSMutableDictionary *record = [self.manager parameterData:kParamA];
	record[@"scratch"] = @"visible";

	XCTAssertEqualObjects([self.manager parameterData:kParamA][@"scratch"], @"visible");
}

- (void)testDuplicateAddParameterReturnsNo
{
	XCTAssertTrue([self.manager addParameter:kParamA]);
	XCTAssertFalse([self.manager addParameter:kParamA]);
}

- (void)testAddParameterAdoptsARecordMissingItsIdAndPreservesOtherKeys
{
	XCTAssertTrue([self.manager addParameter:kParamA]);
	NSMutableDictionary *record = [self.manager parameterData:kParamA];
	record[@"preseeded"] = @"kept";
	XCTAssertNil([self.manager addTag:@"seed" toParameter:kParamA]);
	[record removeObjectForKey:kFxMetaProperty_ParamId];

	XCTAssertTrue([self.manager addParameter:kParamA]);

	NSMutableDictionary *adopted = [self.manager parameterData:kParamA];
	XCTAssertEqualObjects(adopted[kFxMetaProperty_ParamId], @(kParamA));
	XCTAssertEqualObjects(adopted[@"preseeded"], @"kept");
	XCTAssertEqualObjects([self.manager parameterTags:kParamA], @[@"seed"]);
}

- (void)testRemoveParameterReturnsNoForAMissingRecord
{
	XCTAssertFalse([self.manager removeParameter:kParamMissing]);
}

- (void)testRemoveParameterDeletesTheRecord
{
	XCTAssertTrue([self.manager addParameter:kParamA]);
	XCTAssertTrue([self.manager removeParameter:kParamA]);
	XCTAssertFalse([self.manager parameterExists:kParamA]);
	XCTAssertNil([self.manager parameterData:kParamA]);
}

- (void)testRemoveParameterScrubsTheTagReverseIndex
{
	XCTAssertTrue([self.manager addParameter:kParamA]);
	XCTAssertTrue([self.manager addParameter:kParamB]);
	XCTAssertNil([self.manager addTag:@"shared" toParameter:kParamA]);
	XCTAssertNil([self.manager addTag:@"shared" toParameter:kParamB]);

	XCTAssertTrue([self.manager removeParameter:kParamA]);
	XCTAssertEqualObjects([self.manager parametersWithTag:@"shared"], @[@(kParamB)]);

	XCTAssertTrue([self.manager removeParameter:kParamB]);
	XCTAssertNil([self.manager parametersWithTag:@"shared"]);
}

#pragma mark - Tag API

- (void)testFreshManagerHasNoTags
{
	XCTAssertEqual(self.manager.tagCount, 0);
	XCTAssertEqualObjects(self.manager.tags, @[]);
}

- (void)testTagCountForAMissingRecordIsNegativeOne
{
	XCTAssertEqual([self.manager tagCount:kParamMissing], -1);
}

- (void)testAddTagRoundTripsThroughBothIndexes
{
	XCTAssertTrue([self.manager addParameter:kParamA]);
	XCTAssertNil([self.manager addTag:@"color" toParameter:kParamA]);

	XCTAssertEqualObjects([self.manager parameterTags:kParamA], @[@"color"]);
	XCTAssertEqualObjects([self.manager parametersWithTag:@"color"], @[@(kParamA)]);
	XCTAssertEqual([self.manager tagCount:kParamA], 1);
	XCTAssertEqual(self.manager.tagCount, 1);
	XCTAssertEqualObjects(self.manager.tags, @[@"color"]);

	NSError *error = nil;
	XCTAssertTrue([self.manager parameter:kParamA hasTag:@"color" error:&error]);
	XCTAssertNil(error);
	XCTAssertFalse([self.manager parameter:kParamA hasTag:@"absent" error:&error]);
	XCTAssertNil(error);
}

- (void)testAddTagIsIdempotent
{
	XCTAssertTrue([self.manager addParameter:kParamA]);
	XCTAssertNil([self.manager addTag:@"color" toParameter:kParamA]);
	XCTAssertNil([self.manager addTag:@"color" toParameter:kParamA]);

	XCTAssertEqual([self.manager tagCount:kParamA], 1);
	XCTAssertEqualObjects([self.manager parametersWithTag:@"color"], @[@(kParamA)]);
}

- (void)testTagMutatorsOnAMissingRecordReturnAnError
{
	[self assertError:[self.manager addTag:@"color" toParameter:kParamMissing]
 isFailureForParameter:kParamMissing];
	[self assertError:[self.manager removeTag:@"color" fromParameter:kParamMissing]
 isFailureForParameter:kParamMissing];
	[self assertError:[self.manager setTags:@[@"color"] toParameter:kParamMissing]
 isFailureForParameter:kParamMissing];
	[self assertError:[self.manager removeAllTags:kParamMissing]
 isFailureForParameter:kParamMissing];
}

- (void)testRemoveTagClearsBothIndexesAndDeletesTheEmptiedEntry
{
	XCTAssertTrue([self.manager addParameter:kParamA]);
	XCTAssertTrue([self.manager addParameter:kParamB]);
	XCTAssertNil([self.manager addTag:@"shared" toParameter:kParamA]);
	XCTAssertNil([self.manager addTag:@"shared" toParameter:kParamB]);

	XCTAssertNil([self.manager removeTag:@"shared" fromParameter:kParamA]);
	XCTAssertEqualObjects([self.manager parameterTags:kParamA], @[]);
	XCTAssertEqualObjects([self.manager parametersWithTag:@"shared"], @[@(kParamB)]);

	XCTAssertNil([self.manager removeTag:@"shared" fromParameter:kParamB]);
	XCTAssertNil([self.manager parametersWithTag:@"shared"]);
	XCTAssertEqual(self.manager.tagCount, 0);
}

- (void)testRemoveAllTagsEmptiesTheParameterAndScrubsTheIndex
{
	XCTAssertTrue([self.manager addParameter:kParamA]);
	XCTAssertNil(([self.manager setTags:@[@"one", @"two"] toParameter:kParamA]));

	XCTAssertNil([self.manager removeAllTags:kParamA]);
	XCTAssertEqual([self.manager tagCount:kParamA], 0);
	XCTAssertNil([self.manager parametersWithTag:@"one"]);
	XCTAssertNil([self.manager parametersWithTag:@"two"]);
	XCTAssertEqual(self.manager.tagCount, 0);
}

- (void)testSetTagsReplacesTheExistingTagsInOrder
{
	XCTAssertTrue([self.manager addParameter:kParamA]);
	XCTAssertNil([self.manager setTags:@[@"old"] toParameter:kParamA]);

	XCTAssertNil(([self.manager setTags:@[@"first", @"second", @"third"] toParameter:kParamA]));

	XCTAssertEqualObjects([self.manager parameterTags:kParamA], (@[@"first", @"second", @"third"]));
	XCTAssertNil([self.manager parametersWithTag:@"old"]);
	XCTAssertEqualObjects([self.manager parametersWithTag:@"second"], @[@(kParamA)]);
	XCTAssertEqual(self.manager.tagCount, 3);
}

- (void)testParametersWithTagReturnsACopy
{
	XCTAssertTrue([self.manager addParameter:kParamA]);
	XCTAssertTrue([self.manager addParameter:kParamB]);
	XCTAssertNil([self.manager addTag:@"shared" toParameter:kParamA]);

	NSArray<NSNumber*> *snapshot = [self.manager parametersWithTag:@"shared"];
	XCTAssertFalse([snapshot isKindOfClass:NSMutableArray.class]);

	XCTAssertNil([self.manager addTag:@"shared" toParameter:kParamB]);
	XCTAssertEqualObjects(snapshot, @[@(kParamA)]);
	XCTAssertEqual([self.manager parametersWithTag:@"shared"].count, 2u);
}

- (void)testParametersWithNilTagIsNil
{
	XCTAssertNil([self.manager parametersWithTag:nil]);
}

- (void)testNilTagMutatorsReturnAnError
{
	XCTAssertTrue([self.manager addParameter:kParamA]);
	[self assertError:[self.manager addTag:nil toParameter:kParamA] isFailureForParameter:kParamA];
	[self assertError:[self.manager removeTag:nil fromParameter:kParamA] isFailureForParameter:kParamA];
}

#pragma mark - Meta API

- (void)testMetaCountFromParameterReflectsTheRecordState
{
	XCTAssertEqual([self.manager metaCountFromParameter:kParamMissing], -1);

	XCTAssertTrue([self.manager addParameter:kParamA]);
	XCTAssertEqual([self.manager metaCountFromParameter:kParamA], 0);

	XCTAssertTrue([self.manager setMeta:@"value" forKey:@"one" toParameter:kParamA]);
	XCTAssertTrue([self.manager setMeta:@2 forKey:@"two" toParameter:kParamA]);
	XCTAssertEqual([self.manager metaCountFromParameter:kParamA], 2);
}

- (void)testSetAndGetMetaValueForKeyRoundTrip
{
	XCTAssertTrue([self.manager addParameter:kParamA]);
	XCTAssertTrue([self.manager setMeta:@"hello" forKey:@"greeting" toParameter:kParamA]);

	NSObject<NSSecureCoding,NSCopying> *value = nil;
	XCTAssertTrue([self.manager getMeta:&value forKey:@"greeting" fromParameter:kParamA]);
	XCTAssertEqualObjects((id)value, @"hello");
}

- (void)testGetMetaForKeyWithANilOutPointerIsAnExistenceCheck
{
	XCTAssertTrue([self.manager addParameter:kParamA]);
	XCTAssertTrue([self.manager setMeta:@42 forKey:@"answer" toParameter:kParamA]);

	XCTAssertTrue([self.manager getMeta:nil forKey:@"answer" fromParameter:kParamA]);
	XCTAssertFalse([self.manager getMeta:nil forKey:@"missing" fromParameter:kParamA]);
}

- (void)testGetMetaForKeyIsNoForAMissingKeyOrMissingRecord
{
	XCTAssertTrue([self.manager addParameter:kParamA]);

	NSObject<NSSecureCoding,NSCopying> *value = nil;
	XCTAssertFalse([self.manager getMeta:&value forKey:@"missing" fromParameter:kParamA]);
	XCTAssertNil(value);
	XCTAssertFalse([self.manager getMeta:&value forKey:@"anything" fromParameter:kParamMissing]);
	XCTAssertNil(value);
	XCTAssertFalse([self.manager getMeta:&value forKey:nil fromParameter:kParamA]);
}

- (void)testSetMetaToParameterReplacesTheWholeMetaDictionary
{
	XCTAssertTrue([self.manager addParameter:kParamA]);
	XCTAssertTrue([self.manager setMeta:@"gone" forKey:@"stale" toParameter:kParamA]);

	XCTAssertNil(([self.manager setMeta:@{@"fresh": @1, @"other": @"two"} toParameter:kParamA]));

	XCTAssertEqual([self.manager metaCountFromParameter:kParamA], 2);
	XCTAssertFalse([self.manager parameter:kParamA hasMetaKey:@"stale" error:NULL]);
	XCTAssertTrue([self.manager parameter:kParamA hasMetaKey:@"fresh" error:NULL]);
}

- (void)testGetMetaFromParameterAssignsACopy
{
	XCTAssertTrue([self.manager addParameter:kParamA]);
	XCTAssertTrue([self.manager setMeta:@"one" forKey:@"first" toParameter:kParamA]);

	NSDictionary *meta = nil;
	XCTAssertNil([self.manager getMeta:&meta fromParameter:kParamA]);
	XCTAssertEqualObjects(meta, @{@"first": @"one"});

	XCTAssertTrue([self.manager setMeta:@"two" forKey:@"second" toParameter:kParamA]);
	XCTAssertEqualObjects(meta, @{@"first": @"one"});
}

- (void)testMetaAccessorsOnAMissingRecordReturnAnError
{
	NSDictionary *meta = nil;
	[self assertError:[self.manager getMeta:&meta fromParameter:kParamMissing]
 isFailureForParameter:kParamMissing];
	[self assertError:[self.manager setMeta:@{} toParameter:kParamMissing]
 isFailureForParameter:kParamMissing];

	NSArray *keys = nil;
	[self assertError:[self.manager getMetaKeys:&keys fromParameter:kParamMissing]
 isFailureForParameter:kParamMissing];
	[self assertError:[self.manager removeAllMeta:kParamMissing]
 isFailureForParameter:kParamMissing];
}

- (void)testGetMetaKeysAssignsTheStoredKeys
{
	XCTAssertTrue([self.manager addParameter:kParamA]);
	XCTAssertTrue([self.manager setMeta:@1 forKey:@"alpha" toParameter:kParamA]);
	XCTAssertTrue([self.manager setMeta:@2 forKey:@"beta" toParameter:kParamA]);

	NSArray *keys = nil;
	XCTAssertNil([self.manager getMetaKeys:&keys fromParameter:kParamA]);
	XCTAssertEqualObjects([NSSet setWithArray:keys], ([NSSet setWithArray:@[@"alpha", @"beta"]]));
}

- (void)testRemoveAllMetaEmptiesTheContainer
{
	XCTAssertTrue([self.manager addParameter:kParamA]);
	XCTAssertTrue([self.manager setMeta:@1 forKey:@"alpha" toParameter:kParamA]);

	XCTAssertNil([self.manager removeAllMeta:kParamA]);
	XCTAssertEqual([self.manager metaCountFromParameter:kParamA], 0);
}

- (void)testRemoveMetaKeyReportsWhetherTheKeyExisted
{
	XCTAssertTrue([self.manager addParameter:kParamA]);
	XCTAssertTrue([self.manager setMeta:@1 forKey:@"alpha" toParameter:kParamA]);

	XCTAssertTrue([self.manager removeMetaKey:@"alpha" fromParameter:kParamA]);
	XCTAssertFalse([self.manager removeMetaKey:@"alpha" fromParameter:kParamA]);
	XCTAssertFalse([self.manager removeMetaKey:@"never" fromParameter:kParamA]);
	XCTAssertFalse([self.manager removeMetaKey:nil fromParameter:kParamA]);
}

- (void)testHasMetaKeyReportsPresence
{
	XCTAssertTrue([self.manager addParameter:kParamA]);
	XCTAssertTrue([self.manager setMeta:@1 forKey:@"alpha" toParameter:kParamA]);

	NSError *error = nil;
	XCTAssertTrue([self.manager parameter:kParamA hasMetaKey:@"alpha" error:&error]);
	XCTAssertNil(error);
	XCTAssertFalse([self.manager parameter:kParamA hasMetaKey:@"beta" error:&error]);
	XCTAssertNil(error);
}

- (void)testHasMetaKeyOnAMissingRecordIsNoWithAnError
{
	NSError *error = nil;
	XCTAssertFalse([self.manager parameter:kParamMissing hasMetaKey:@"alpha" error:&error]);
	[self assertError:error isFailureForParameter:kParamMissing];
}

#pragma mark - Unsaved Marking

- (void)testFreshManagerIsNotUnsaved
{
	XCTAssertFalse(self.manager.unsaved);
}

- (void)testEveryMutatorMarksTheManagerUnsaved
{
	XCTAssertTrue([self.manager addParameter:kParamA]);
	XCTAssertTrue(self.manager.unsaved);

	[self.manager setUnsaved:NO];
	XCTAssertTrue([self.manager addParameter:kParamB]);
	XCTAssertTrue(self.manager.unsaved);

	[self.manager setUnsaved:NO];
	XCTAssertTrue([self.manager removeParameter:kParamB]);
	XCTAssertTrue(self.manager.unsaved);

	[self.manager setUnsaved:NO];
	XCTAssertNil([self.manager addTag:@"color" toParameter:kParamA]);
	XCTAssertTrue(self.manager.unsaved);

	[self.manager setUnsaved:NO];
	XCTAssertNil([self.manager removeTag:@"color" fromParameter:kParamA]);
	XCTAssertTrue(self.manager.unsaved);

	[self.manager setUnsaved:NO];
	XCTAssertNil(([self.manager setTags:@[@"one", @"two"] toParameter:kParamA]));
	XCTAssertTrue(self.manager.unsaved);

	[self.manager setUnsaved:NO];
	XCTAssertNil([self.manager removeAllTags:kParamA]);
	XCTAssertTrue(self.manager.unsaved);

	[self.manager setUnsaved:NO];
	XCTAssertTrue([self.manager setMeta:@1 forKey:@"alpha" toParameter:kParamA]);
	XCTAssertTrue(self.manager.unsaved);

	[self.manager setUnsaved:NO];
	XCTAssertNil([self.manager setMeta:@{@"beta": @2} toParameter:kParamA]);
	XCTAssertTrue(self.manager.unsaved);

	[self.manager setUnsaved:NO];
	XCTAssertTrue([self.manager removeMetaKey:@"beta" fromParameter:kParamA]);
	XCTAssertTrue(self.manager.unsaved);

	[self.manager setUnsaved:NO];
	XCTAssertTrue([self.manager setMeta:@3 forKey:@"gamma" toParameter:kParamA]);
	[self.manager setUnsaved:NO];
	XCTAssertNil([self.manager removeAllMeta:kParamA]);
	XCTAssertTrue(self.manager.unsaved);
}

- (void)testNoOpMutationsDoNotMarkTheManagerUnsaved
{
	XCTAssertTrue([self.manager addParameter:kParamA]);
	XCTAssertNil([self.manager addTag:@"color" toParameter:kParamA]);

	[self.manager setUnsaved:NO];
	XCTAssertFalse([self.manager removeMetaKey:@"never" fromParameter:kParamA]);
	XCTAssertFalse(self.manager.unsaved);

	XCTAssertNil([self.manager addTag:@"color" toParameter:kParamA]);
	XCTAssertFalse(self.manager.unsaved);

	XCTAssertNil([self.manager removeAllTags:kParamA]);
	[self.manager setUnsaved:NO];
	XCTAssertNil([self.manager removeAllTags:kParamA]);
	XCTAssertFalse(self.manager.unsaved);

	XCTAssertNil([self.manager removeAllMeta:kParamA]);
	XCTAssertFalse(self.manager.unsaved);
}

#pragma mark - Persistence

- (void)testSaveMetaSucceedsWhenNothingIsUnsaved
{
	XCTAssertFalse(self.manager.unsaved);
	XCTAssertTrue([self.manager saveMeta]);
}

- (void)testSaveMetaWithoutAnEffectFailsAndKeepsTheUnsavedState
{
	XCTAssertTrue([self.manager addParameter:kParamA]);
	XCTAssertTrue(self.manager.unsaved);

	XCTAssertFalse([self.manager saveMeta]);
	XCTAssertTrue(self.manager.unsaved);
}

#pragma mark - Coding, Copying, Equality

- (FxGripMetaManager *)populatedManager
{
	FxGripMetaManager *manager = FxGripMetaManager.new;
	XCTAssertTrue([manager addParameter:kParamA]);
	XCTAssertTrue([manager addParameter:kParamB]);
	XCTAssertNil(([manager setTags:@[@"shared", @"alpha"] toParameter:kParamA]));
	XCTAssertNil([manager setTags:@[@"shared"] toParameter:kParamB]);
	XCTAssertTrue([manager setMeta:@"text" forKey:@"string" toParameter:kParamA]);
	XCTAssertTrue([manager setMeta:@3.5 forKey:@"number" toParameter:kParamA]);
	XCTAssertTrue(([manager setMeta:@{@"inner": @[@1, @2]} forKey:@"dictionary" toParameter:kParamA]));
	XCTAssertTrue(([manager setMeta:@[@"a", @"b"] forKey:@"array" toParameter:kParamB]));
	return manager;
}

- (void)testSecureCodingRoundTripPreservesTagsAndMeta
{
	FxGripMetaManager *original = [self populatedManager];

	NSError *error = nil;
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:original
										requiringSecureCoding:YES
														error:&error];
	XCTAssertNil(error);
	XCTAssertNotNil(data);

	FxGripMetaManager *decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:FxGripMetaManager.class
																  fromData:data
																	 error:&error];
	XCTAssertNil(error);
	XCTAssertNotNil(decoded);

	XCTAssertEqualObjects([decoded parameterTags:kParamA], (@[@"shared", @"alpha"]));
	XCTAssertEqualObjects([decoded parameterTags:kParamB], @[@"shared"]);
	XCTAssertEqual([decoded parametersWithTag:@"shared"].count, 2u);
	XCTAssertEqualObjects([decoded parametersWithTag:@"alpha"], @[@(kParamA)]);

	NSDictionary *meta = nil;
	XCTAssertNil([decoded getMeta:&meta fromParameter:kParamA]);
	XCTAssertEqualObjects(meta[@"string"], @"text");
	XCTAssertEqualObjects(meta[@"number"], @3.5);
	XCTAssertEqualObjects(meta[@"dictionary"], (@{@"inner": @[@1, @2]}));

	NSDictionary *metaB = nil;
	XCTAssertNil([decoded getMeta:&metaB fromParameter:kParamB]);
	XCTAssertEqualObjects(metaB[@"array"], (@[@"a", @"b"]));

	XCTAssertEqualObjects(decoded, original);
}

// setMeta: accepts any secure-codable value; a date must survive the round trip. Before
// the decode allow-list admitted NSDate the archive succeeded but decode failed with
// NSCocoaErrorDomain 4864, silently discarding the whole record on reload.
- (void)testSecureCodingRoundTripPreservesADateMetaValue
{
	NSDate *when = [NSDate dateWithTimeIntervalSinceReferenceDate:12345.0];
	XCTAssertTrue([self.manager addParameter:kParamA]);
	XCTAssertTrue([self.manager setMeta:when forKey:@"captured" toParameter:kParamA]);

	NSError *error = nil;
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.manager
										requiringSecureCoding:YES
														error:&error];
	XCTAssertNil(error);

	FxGripMetaManager *decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:FxGripMetaManager.class
																  fromData:data
																	 error:&error];
	XCTAssertNil(error);
	NSDictionary *meta = nil;
	XCTAssertNil([decoded getMeta:&meta fromParameter:kParamA]);
	XCTAssertEqualObjects(meta[@"captured"], when);
}

- (void)testDecodedManagerIsFullyMutable
{
	FxGripMetaManager *original = [self populatedManager];
	NSError *error = nil;
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:original
										requiringSecureCoding:YES
														error:&error];
	FxGripMetaManager *decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:FxGripMetaManager.class
																  fromData:data
																	 error:&error];
	XCTAssertNotNil(decoded);

	XCTAssertNil([decoded addTag:@"added" toParameter:kParamA]);
	XCTAssertTrue([decoded parameter:kParamA hasTag:@"added" error:NULL]);
	XCTAssertEqualObjects([decoded parametersWithTag:@"added"], @[@(kParamA)]);

	XCTAssertTrue([decoded setMeta:@"new" forKey:@"added" toParameter:kParamB]);
	XCTAssertTrue([decoded parameter:kParamB hasMetaKey:@"added" error:NULL]);

	XCTAssertTrue([decoded addParameter:303]);
	XCTAssertTrue([decoded removeParameter:kParamA]);
}

- (void)testCopyIsEqualAndDeeplyIndependent
{
	FxGripMetaManager *original = [self populatedManager];
	FxGripMetaManager *duplicate = [original copy];

	XCTAssertEqualObjects(duplicate, original);
	XCTAssertNotIdentical(duplicate, original);

	XCTAssertNil([duplicate addTag:@"copyOnly" toParameter:kParamA]);
	XCTAssertTrue([duplicate setMeta:@"copyOnly" forKey:@"copyOnly" toParameter:kParamA]);
	[duplicate parameterData:kParamA][@"scratch"] = @"copyOnly";

	XCTAssertFalse([original parameter:kParamA hasTag:@"copyOnly" error:NULL]);
	XCTAssertFalse([original parameter:kParamA hasMetaKey:@"copyOnly" error:NULL]);
	XCTAssertNil([original parametersWithTag:@"copyOnly"]);
	XCTAssertNil([original parameterData:kParamA][@"scratch"]);

	XCTAssertNil([original addTag:@"originalOnly" toParameter:kParamB]);
	XCTAssertFalse([duplicate parameter:kParamB hasTag:@"originalOnly" error:NULL]);
}

- (void)testEqualityDivergesWithContentAndHashMatchesWhenEqual
{
	FxGripMetaManager *original = [self populatedManager];
	FxGripMetaManager *duplicate = [original copy];

	XCTAssertEqualObjects(duplicate, original);
	XCTAssertEqual(duplicate.hash, original.hash);

	XCTAssertTrue([duplicate setMeta:@"diverged" forKey:@"diverged" toParameter:kParamA]);
	XCTAssertNotEqualObjects(duplicate, original);

	XCTAssertFalse([original isEqual:@"not a manager"]);
	XCTAssertTrue([original isEqual:original]);
}

- (void)testClassesForParameterAllowsTheArchivedContainerClasses
{
	NSOrderedSet<Class> *classes = FxGripMetaManager.classesForParameter;
	XCTAssertGreaterThan(classes.count, 0u);
	XCTAssertTrue([classes containsObject:NSDictionary.class]);
	XCTAssertTrue([classes containsObject:NSArray.class]);
	XCTAssertTrue([classes containsObject:NSString.class]);
	XCTAssertTrue([classes containsObject:NSNumber.class]);

	XCTAssertEqualObjects(self.manager.classesForParameter, classes);
}

#pragma mark - Locking

- (void)testLockIsRecursiveOnTheSameThread
{
	XCTAssertTrue([self.manager lock]);
	XCTAssertTrue([self.manager lockWithinTime:0]);
	[self.manager unlock];
	[self.manager unlock];

	XCTAssertTrue([self.manager lockWithinTime:0]);
	[self.manager unlock];
}

- (void)testLockWithinTimeFailsOnAnotherThreadWhileHeld
{
	XCTAssertTrue([self.manager lock]);

	XCTestExpectation *contended = [self expectationWithDescription:@"contended lock attempt"];
	__block BOOL acquiredWhileHeld = YES;
	dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
		acquiredWhileHeld = [self.manager lockWithinTime:0.05];
		if (acquiredWhileHeld) {
			[self.manager unlock];
		}
		[contended fulfill];
	});
	[self waitForExpectations:@[contended] timeout:5.0];
	XCTAssertFalse(acquiredWhileHeld);

	[self.manager unlock];

	XCTestExpectation *released = [self expectationWithDescription:@"uncontended lock attempt"];
	__block BOOL acquiredAfterRelease = NO;
	dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
		acquiredAfterRelease = [self.manager lockWithinTime:0.05];
		if (acquiredAfterRelease) {
			[self.manager unlock];
		}
		[released fulfill];
	});
	[self waitForExpectations:@[released] timeout:5.0];
	XCTAssertTrue(acquiredAfterRelease);
}

@end
