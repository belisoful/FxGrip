//
//  FxGripMetaTests.m
//  FxGripTests
//
//  Unit tests for the meta wiring: the FxGripMeta extension's InstanceMeta
//  parameter registration, record seeding from the parameter configuration,
//  the document merge, flush persistence, and the tag/meta delegation the
//  parameter APIs perform through the effect's manager.
//

#import <XCTest/XCTest.h>
#import <dlfcn.h>
#import <CoreMedia/CoreMedia.h>
#import <FxPlug/FxTypes.h>
#import "FxGrip/FxGripTypes.h"
#import "FxGrip/FxGripErrors.h"
#import "FxGrip/FxParameterFlags.h"
#import "FxGrip/FxGripMetaManager.h"
#import "FxGrip/FxAPINotifications.h"
#import "FxGrip/FxTileableEffectBase+Notifications.h"
#import "FxGrip/FxParameterTagsAPI_v1.h"
#import "FxGrip/FxGripDynamicParameterAPI_v4.h"

// FxGripMeta.h reaches its superclass through a flat angled include, and
// FxGripParameterTagsAPI_v1.h is not a public framework header, so neither resolves
// outside the framework target. Both classes are declared here with the members the
// tests exercise; the implementations come from the linked framework.
@interface FxGripMeta : NSObject
@property (readonly, nonatomic, nullable) FxGripMetaManager *manager;
@property (readonly, nonatomic) FxParameterId parameterID;
@property (readonly, nonnull, retain) NSSet *dataClasses;
- (BOOL)extLoadWithEffect:(nonnull id)effect;
- (void)extAddParameters:(nonnull NSNotification *)notification;
- (void)extAddedToDocument:(nonnull NSNotification *)notification;
- (void)extAPIParameterAdd:(nonnull NSNotification *)notification;
- (void)extAPIParameterRemove:(nonnull NSNotification *)notification;
- (void)extParameterChanged:(nonnull NSNotification *)notification;
- (void)extFlush:(nonnull NSNotification *)notification;
- (NSInteger)ncPriority:(nullable NSNotificationName)aName;
@end

@interface FxGripParameterTagsAPI_v1 : NSObject <FxParameterTagsAPI_v1>
- (nullable instancetype)initWithAPI:(nullable id<FxParameterTagsAPI_v1>)api effect:(nonnull id)effect;
@end

static const FxParameterId kMetaTestParamA = 10;
static const FxParameterId kMetaTestParamB = 11;

// The test target links only FxGrip and XCTest, so NSPriorityNotificationCenter
// (from BEFoundation) is resolved at runtime by name to avoid an unlinked symbol.
static NSNotificationCenter *FxMetaTestMakePriorityCenter(void)
{
	Class cls = NSClassFromString(@"NSPriorityNotificationCenter");
	return [[cls alloc] init];
}

/*!
	The test bundle does not link FxPlug.framework, and FxPlug is weak-linked by FxGrip, so
	the constant is read from the loaded images. Outside an FxPlug host the symbol is absent
	and FxGripErrors.h substitutes FxGripPlugErrorDomain.
*/
static NSString *FxMetaTestExpectedErrorDomain(void)
{
	NSString * __unsafe_unretained *domain = (NSString * __unsafe_unretained *)dlsym(RTLD_DEFAULT, "FxPlugErrorDomain");
	return domain ? *domain : FxGripPlugErrorDomainConstant;
}

/*!
	Builds an API parameter notification payload. The wrapper APIs carry the parameter
	dictionary under FxNotifyAPI_ParameterKey and repeat the ID at the top level; the
	NSDictionary(FxTileableEffect) accessors resolve only for a dictionary that also
	carries "type" and "name", so both levels carry the full triple.
*/
static NSDictionary *FxMetaTestParameterUserInfo(FxParameterId parameterID)
{
	NSDictionary *parameter = @{
		kFxParameterProperty_Id: @(parameterID),
		kFxParameterProperty_Type: kFxParameterType_Float,
		kFxParameterProperty_Name: @"Test Parameter"
	};
	NSMutableDictionary *userInfo = parameter.mutableCopy;
	userInfo[FxNotifyAPI_ParameterKey] = parameter;
	return userInfo;
}

/*!
	The payload FxGripParameterCreationAPI_v5 posts: the parameter dictionary sits under
	FxNotifyAPI_ParameterKey and the top level carries only the ID.
*/
static NSDictionary *FxMetaTestHostAddUserInfo(FxParameterId parameterID)
{
	return @{
		kFxParameterProperty_Id: @(parameterID),
		FxNotifyAPI_ParameterKey: @{
			kFxParameterProperty_Type: @(FxParameterType_Float),
			kFxParameterProperty_Name: @"Test Parameter",
			kFxParameterProperty_Id: @(parameterID),
			kFxParameterProperty_ParentId: @(kFxParameterId_TopLevelGroup)
		}.mutableCopy
	};
}

/*! The payload FxGripDynamicParameterAPI_v3 removeParameter: posts. */
static NSDictionary *FxMetaTestHostRemoveUserInfo(FxParameterId parameterID)
{
	return @{
		kFxParameterProperty_Id: @(parameterID),
		FxNotifyAPI_ParameterKey: @{kFxParameterProperty_Id: @(parameterID)}
	};
}

static NSNotification *FxMetaTestParameterNotification(NSNotificationName name, FxParameterId parameterID, id object)
{
	return [NSNotification notificationWithName:name
										 object:object
									   userInfo:FxMetaTestParameterUserInfo(parameterID)];
}

/*!
	The test bundle links neither CoreMedia nor FxPlug, so the CMTime dictionary bridge is
	resolved from the loaded images the way FxTileableEffectNotificationTests does.
*/
typedef CFDictionaryRef (*FxMetaTestTimeToDictionaryFn)(CMTime, CFAllocatorRef);

static NSDictionary *FxMetaTestTimeDictionary(CMTime time)
{
	FxMetaTestTimeToDictionaryFn fn =
		(FxMetaTestTimeToDictionaryFn)dlsym(RTLD_DEFAULT, "CMTimeCopyAsDictionary");
	NSCAssert(fn != NULL, @"CoreMedia CMTimeCopyAsDictionary must be resolvable in-process");
	return (__bridge_transfer NSDictionary *)fn(time, kCFAllocatorDefault);
}

static CMTime FxMetaTestMakeTime(int64_t value, int32_t timescale)
{
	return (CMTime){.value = value, .timescale = timescale, .flags = kCMTimeFlags_Valid, .epoch = 0};
}

static BOOL FxMetaTestTimesEqual(CMTime lhs, CMTime rhs)
{
	return lhs.value == rhs.value && lhs.timescale == rhs.timescale
		&& lhs.flags == rhs.flags && lhs.epoch == rhs.epoch;
}

/*! One recorded step of the parameter-changed pass, tagged with the options it carried. */
static NSString *FxMetaTestTriggerEvent(FxGripPresetOptions options)
{
	return [NSString stringWithFormat:@"target:%lu", (unsigned long)options];
}

static NSString * const kFxMetaTestResetEvent = @"reset";

#pragma mark - Test doubles

// Records the value the extension writes on flush, and the reset value the
// parameter-changed pass writes between the two target-preset calls.
@interface FxMetaTestStubSetAPI : NSObject
@property (nonatomic, strong) NSMutableArray *values;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *parameterIDs;
@property (nonatomic, strong) NSMutableArray<NSString *> *events;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *resetValues;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *resetParameterIDs;
@property (nonatomic, assign) CMTime lastResetTime;
@end

@implementation FxMetaTestStubSetAPI

- (instancetype)init
{
	self = [super init];
	if (self) {
		_values = NSMutableArray.new;
		_parameterIDs = NSMutableArray.new;
		_events = NSMutableArray.new;
		_resetValues = NSMutableArray.new;
		_resetParameterIDs = NSMutableArray.new;
	}
	return self;
}

- (BOOL)setCustomParameterValue:(NSObject<NSSecureCoding, NSCopying> *)value
					toParameter:(UInt32)parameterID
						 atTime:(CMTime)time
{
	[self.values addObject:value];
	[self.parameterIDs addObject:@(parameterID)];
	return YES;
}

- (BOOL)setFloatValue:(double)value toParameter:(UInt32)parameterID atTime:(CMTime)time
{
	[self.events addObject:kFxMetaTestResetEvent];
	[self.resetValues addObject:@(value)];
	[self.resetParameterIDs addObject:@(parameterID)];
	self.lastResetTime = time;
	return YES;
}

@end

// Records each target-preset trigger the parameter-changed pass performs.
@interface FxMetaTestStubTagsAPI : NSObject
@property (nonatomic, strong) NSMutableArray<NSString *> *events;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *parameterIDs;
@property (nonatomic, assign) CMTime lastTime;
@end

@implementation FxMetaTestStubTagsAPI

- (instancetype)init
{
	self = [super init];
	if (self) {
		_events = NSMutableArray.new;
		_parameterIDs = NSMutableArray.new;
	}
	return self;
}

- (BOOL)applyTargetPresetForParameter:(FxParameterId)parameterID
							   atTime:(CMTime)time
							  options:(FxGripPresetOptions)options
{
	[self.events addObject:FxMetaTestTriggerEvent(options)];
	[self.parameterIDs addObject:@(parameterID)];
	self.lastTime = time;
	return YES;
}

@end

// Hands the extension the manager stored in the document.
@interface FxMetaTestStubGetAPI : NSObject
@property (nonatomic, strong) NSObject<NSSecureCoding, NSCopying> *storedValue;
@property (nonatomic, assign) FxParameterId lastRequestedParameter;
@end

@implementation FxMetaTestStubGetAPI

- (BOOL)getCustomParameterValue:(NSObject<NSSecureCoding, NSCopying> * _Nullable * _Nonnull)value
				  fromParameter:(UInt32)parameterID
						 atTime:(CMTime)time
{
	self.lastRequestedParameter = parameterID;
	if (!self.storedValue) {
		return NO;
	}
	*value = self.storedValue;
	return YES;
}

@end

@interface FxMetaTestStubAPIManager : NSObject
@property (nonatomic, strong) FxMetaTestStubGetAPI *paramGetAPIv6;
@property (nonatomic, strong) FxMetaTestStubSetAPI *paramSetAPIv5;
@property (nonatomic, strong) id paramTagsAPIv1;
@end

@implementation FxMetaTestStubAPIManager
@end

// FxTileableEffectBase's designated initializer registers into the process-wide
// notification center, so the extension is exercised against a stub exposing the
// members the meta wiring reads.
@interface FxMetaTestStubEffect : NSObject
@property (nonatomic, assign) BOOL addedToDocument;
@property (nonatomic, strong) NSNotificationCenter *notifier;
@property (nonatomic, strong) FxMetaTestStubAPIManager *apiManager;
@property (nonatomic, assign) BOOL hasMeta;
@property (nonatomic, strong) FxGripMetaManager *meta;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSDictionary *> *configurations;
@end

@implementation FxMetaTestStubEffect

- (id)effectBase
{
	// The stub plays the full effect; rich reads route back to it, as the old cast did.
	return self;
}


- (instancetype)init
{
	self = [super init];
	if (self) {
		_notifier = FxMetaTestMakePriorityCenter();
		_apiManager = FxMetaTestStubAPIManager.new;
		_apiManager.paramGetAPIv6 = FxMetaTestStubGetAPI.new;
		_apiManager.paramSetAPIv5 = FxMetaTestStubSetAPI.new;
		_apiManager.paramTagsAPIv1 = FxMetaTestStubTagsAPI.new;
		_configurations = NSMutableDictionary.new;
	}
	return self;
}

- (NSDictionary *)configurationForParameter:(FxParameterId)parameterID
{
	return self.configurations[@(parameterID)];
}

@end

#pragma mark - Tests

@interface FxGripMetaTests : XCTestCase
@property (nonatomic, strong) FxGripMeta *extension;
@property (nonatomic, strong) FxMetaTestStubEffect *effect;
@end

@implementation FxGripMetaTests

- (void)setUp
{
	[super setUp];
	self.extension = [FxGripMeta.alloc init];
	self.effect = [FxMetaTestStubEffect.alloc init];
}

- (void)tearDown
{
	self.extension = nil;
	self.effect = nil;
	[super tearDown];
}

/*! Registers a configuration and drives the seeding notification for one parameter. */
- (void)seedParameter:(FxParameterId)parameterID withConfiguration:(NSDictionary *)configuration
{
	if (configuration) {
		self.effect.configurations[@(parameterID)] = configuration;
	}
	[self.extension extAPIParameterAdd:FxMetaTestParameterNotification(FxNotifyAPI_ParameterAddName,
																	  parameterID,
																	  self.effect)];
}

/*! A parameter configuration carrying every entry the seeding transfers. */
- (NSDictionary *)configurationWithTags:(NSArray *)tags meta:(NSDictionary *)meta
{
	return @{
		kFxParameterProperty_Id: @(kMetaTestParamA),
		kFxParameterProperty_Type: kFxParameterType_Float,
		kFxParameterProperty_Name: @"Test Parameter",
		kFxParameterProperty_Tags: tags,
		kFxParameterProperty_Meta: meta,
		kFxParameterProperty_ResetValue: @5,
		kFxParameterProperty_TargetPreset: @"presetTag"
	};
}

#pragma mark Extension Registration

- (void)testInitUsesTheInstanceMetaParameterIDAndHasNoManager
{
	XCTAssertEqual(self.extension.parameterID, (FxParameterId)kFxParameterId_InstanceMeta);
	XCTAssertEqual(self.extension.parameterID, (FxParameterId)9995);
	XCTAssertNil(self.extension.manager);
}

- (void)testDataClassesIncludeTheManagerAndTheInheritedContainers
{
	NSSet *dataClasses = self.extension.dataClasses;

	XCTAssertTrue([dataClasses containsObject:NSClassFromString(@"FxGripMetaManager")]);
	XCTAssertTrue([dataClasses containsObject:FxGripMetaManager.class]);
	XCTAssertTrue([dataClasses containsObject:NSDictionary.class]);
	XCTAssertTrue([dataClasses containsObject:NSArray.class]);
}

- (void)testExtAddParametersRegistersTheHiddenInstanceMetaParameter
{
	NSMutableArray *parameters = NSMutableArray.new;
	NSNotification *notification = [NSNotification notificationWithName:FxTileableEffectAddParametersName
																 object:self.effect
															   userInfo:@{FxTileableEffectParametersKey: parameters}];

	[self.extension extAddParameters:notification];

	XCTAssertEqual(parameters.count, (NSUInteger)1);

	NSDictionary *parameter = parameters.firstObject;
	XCTAssertEqualObjects(parameter[kFxParameterProperty_Id], @(kFxParameterId_InstanceMeta));
	XCTAssertEqualObjects(parameter[kFxParameterProperty_Name], @"Plugin Data");
	XCTAssertEqualObjects(parameter[kFxParameterProperty_Type], kFxParameterType_Custom);
	XCTAssertEqualObjects(parameter[kFxParameterProperty_Factory], self.extension);

	NSArray *flags = parameter[kFxParameterProperty_Flags];
	XCTAssertTrue([flags containsObject:kParameterFlagString_PRESETNOMETA]);
	XCTAssertTrue([flags containsObject:kParameterFlagString_HIDDEN]);
	XCTAssertTrue([flags containsObject:kParameterFlagString_DONT_DISPLAY]);
	XCTAssertTrue([flags containsObject:kParameterFlagString_NO_STATE]);
	XCTAssertTrue([flags containsObject:kParameterFlagString_NO_DEBUG]);
	XCTAssertTrue([flags containsObject:kParameterFlagString_NOT_ANIMATABLE]);
}

#pragma mark Seeding

- (void)testParameterAddSeedsTagsMetaAndConfigurationRecordEntries
{
	[self.extension extLoadWithEffect:(id)self.effect];
	[self seedParameter:kMetaTestParamA
	  withConfiguration:[self configurationWithTags:@[@"a", @"b"] meta:@{@"k": @"v"}]];

	FxGripMetaManager *manager = self.extension.manager;
	XCTAssertNotNil(manager);
	XCTAssertTrue([manager parameterExists:kMetaTestParamA]);

	NSArray *tags = [manager parameterTags:kMetaTestParamA];
	XCTAssertTrue([tags containsObject:@"a"]);
	XCTAssertTrue([tags containsObject:@"b"]);

	NSObject<NSSecureCoding, NSCopying> *value = nil;
	XCTAssertTrue([manager getMeta:&value forKey:@"k" fromParameter:kMetaTestParamA]);
	XCTAssertEqualObjects(value, @"v");

	NSMutableDictionary *record = [manager parameterData:kMetaTestParamA];
	XCTAssertEqualObjects(record[kFxParameterProperty_ResetValue], @5);
	XCTAssertEqualObjects(record[kFxParameterProperty_TargetPreset], @"presetTag");

	XCTAssertTrue(manager.unsaved);
}

- (void)testParameterAddWithoutConfigurationStillCreatesTheRecord
{
	[self.extension extLoadWithEffect:(id)self.effect];
	[self seedParameter:kMetaTestParamA withConfiguration:nil];

	XCTAssertNotNil(self.extension.manager);
	XCTAssertTrue([self.extension.manager parameterExists:kMetaTestParamA]);
}

- (void)testRepeatedSeedingKeepsExistingRecordValuesAndAddsConfigurationTags
{
	[self.extension extLoadWithEffect:(id)self.effect];
	[self seedParameter:kMetaTestParamA withConfiguration:nil];

	FxGripMetaManager *manager = self.extension.manager;
	XCTAssertTrue([manager setMeta:@"user" forKey:@"k" toParameter:kMetaTestParamA]);
	XCTAssertNil([manager addTag:@"user" toParameter:kMetaTestParamA]);
	[manager parameterData:kMetaTestParamA][kFxParameterProperty_TargetPreset] = @"custom";

	[self seedParameter:kMetaTestParamA
	  withConfiguration:[self configurationWithTags:@[@"a", @"b"] meta:@{@"k": @"v"}]];

	NSObject<NSSecureCoding, NSCopying> *value = nil;
	XCTAssertTrue([manager getMeta:&value forKey:@"k" fromParameter:kMetaTestParamA]);
	XCTAssertEqualObjects(value, @"user");

	NSMutableDictionary *record = [manager parameterData:kMetaTestParamA];
	XCTAssertEqualObjects(record[kFxParameterProperty_TargetPreset], @"custom");
	XCTAssertEqualObjects(record[kFxParameterProperty_ResetValue], @5);

	NSArray *tags = [manager parameterTags:kMetaTestParamA];
	XCTAssertTrue([tags containsObject:@"a"]);
	XCTAssertTrue([tags containsObject:@"b"]);
	XCTAssertTrue([tags containsObject:@"user"]);
}

- (void)testParameterRemoveDropsTheRecord
{
	[self.extension extLoadWithEffect:(id)self.effect];
	[self seedParameter:kMetaTestParamA withConfiguration:nil];
	XCTAssertTrue([self.extension.manager parameterExists:kMetaTestParamA]);

	[self.extension extAPIParameterRemove:FxMetaTestParameterNotification(FxNotifyAPI_ParameterRemoveName,
																		  kMetaTestParamA,
																		  self.effect)];

	XCTAssertFalse([self.extension.manager parameterExists:kMetaTestParamA]);
}

- (void)testInstanceMetaParameterIsNeverSeeded
{
	[self.extension extLoadWithEffect:(id)self.effect];

	[self.extension extAPIParameterAdd:FxMetaTestParameterNotification(FxNotifyAPI_ParameterAddName,
																	   kFxParameterId_InstanceMeta,
																	   self.effect)];

	XCTAssertNil(self.extension.manager);
}

- (void)testParameterAddSeedsTheParameterIDCarriedByTheCreationAPINotification
{
	[self.extension extLoadWithEffect:(id)self.effect];

	[self.extension extAPIParameterAdd:[NSNotification notificationWithName:FxNotifyAPI_ParameterAddName
																	 object:self.effect
																   userInfo:FxMetaTestHostAddUserInfo(kMetaTestParamA)]];

	XCTAssertEqualObjects(self.extension.manager.parameterIDs, @[@(kMetaTestParamA)],
						  @"the seeded record carries the parameter ID the creation API announced");
}

- (void)testParameterRemoveDropsTheRecordNamedByTheDynamicAPINotification
{
	[self.extension extLoadWithEffect:(id)self.effect];
	[self seedParameter:kMetaTestParamA withConfiguration:nil];

	[self.extension extAPIParameterRemove:[NSNotification notificationWithName:FxNotifyAPI_ParameterRemoveName
																		object:self.effect
																	  userInfo:FxMetaTestHostRemoveUserInfo(kMetaTestParamA)]];

	XCTAssertFalse([self.extension.manager parameterExists:kMetaTestParamA],
				   @"the removed record is the one the dynamic API announced");
}

#pragma mark Document Load

- (void)testAddedToDocumentAdoptsTheDocumentManagerAndMergesSeededRecords
{
	FxGripMetaManager *documentManager = [FxGripMetaManager.alloc initWithEffect:nil];
	[documentManager addParameter:kMetaTestParamA];
	[documentManager addTag:@"doc" toParameter:kMetaTestParamA];
	[documentManager setMeta:@"docval" forKey:@"k" toParameter:kMetaTestParamA];
	self.effect.apiManager.paramGetAPIv6.storedValue = documentManager;

	[self.extension extLoadWithEffect:(id)self.effect];
	[self seedParameter:kMetaTestParamA
	  withConfiguration:[self configurationWithTags:@[@"cfg"] meta:@{@"k": @"cfgval"}]];
	[self seedParameter:kMetaTestParamB
	  withConfiguration:@{
		  kFxParameterProperty_Id: @(kMetaTestParamB),
		  kFxParameterProperty_Type: kFxParameterType_Float,
		  kFxParameterProperty_Name: @"Second Parameter",
		  kFxParameterProperty_Tags: @[@"second"],
		  kFxParameterProperty_Meta: @{@"only": @"seeded"}
	  }];

	[self.extension extAddedToDocument:[NSNotification notificationWithName:FxTileableEffectAddedToDocumentName
																	object:self.effect
																  userInfo:nil]];

	XCTAssertTrue(self.extension.manager == documentManager);
	XCTAssertEqual(self.effect.apiManager.paramGetAPIv6.lastRequestedParameter,
				   (FxParameterId)kFxParameterId_InstanceMeta);

	NSArray *tags = [documentManager parameterTags:kMetaTestParamA];
	XCTAssertTrue([tags containsObject:@"doc"]);
	XCTAssertTrue([tags containsObject:@"cfg"]);

	NSObject<NSSecureCoding, NSCopying> *value = nil;
	XCTAssertTrue([documentManager getMeta:&value forKey:@"k" fromParameter:kMetaTestParamA]);
	XCTAssertEqualObjects(value, @"docval", @"the document value wins over the configuration default");

	XCTAssertTrue([documentManager parameterExists:kMetaTestParamB]);
	XCTAssertTrue([[documentManager parameterTags:kMetaTestParamB] containsObject:@"second"]);
	XCTAssertTrue([documentManager getMeta:&value forKey:@"only" fromParameter:kMetaTestParamB]);
	XCTAssertEqualObjects(value, @"seeded");
}

- (void)testAddedToDocumentCreatesAManagerWhenTheDocumentHoldsNone
{
	[self.extension extLoadWithEffect:(id)self.effect];

	[self.extension extAddedToDocument:[NSNotification notificationWithName:FxTileableEffectAddedToDocumentName
																	object:self.effect
																  userInfo:nil]];

	XCTAssertNotNil(self.extension.manager);
}

// extAddedToDocument: clears the loaded manager's unsaved flag before merging the seeded
// records. A seeded reset/target key merges through a direct record write that bypasses the
// manager's mutators, so it must raise the unsaved flag by hand or the entry never flushes.
- (void)testMergingASeededResetKeyLeavesTheDocumentManagerUnsaved
{
	FxGripMetaManager *documentManager = [FxGripMetaManager.alloc initWithEffect:nil];
	[documentManager addParameter:kMetaTestParamA];
	self.effect.apiManager.paramGetAPIv6.storedValue = documentManager;

	[self.extension extLoadWithEffect:(id)self.effect];
	// The only transferable entry is the reset value: no tags or meta, so the merge's only
	// change to the loaded record is the direct write.
	[self seedParameter:kMetaTestParamA withConfiguration:@{
		kFxParameterProperty_Id: @(kMetaTestParamA),
		kFxParameterProperty_Type: kFxParameterType_Float,
		kFxParameterProperty_Name: @"Reset Only",
		kFxParameterProperty_ResetValue: @9
	}];

	[self.extension extAddedToDocument:[NSNotification notificationWithName:FxTileableEffectAddedToDocumentName
																	object:self.effect
																  userInfo:nil]];

	XCTAssertTrue(self.extension.manager == documentManager);
	XCTAssertEqualObjects([documentManager parameterData:kMetaTestParamA][kFxParameterProperty_ResetValue], @9,
						  @"the seeded reset value merges into the loaded record");
	XCTAssertTrue(documentManager.unsaved,
				  @"the merged reset key raises unsaved so the next flush persists it");
}

#pragma mark Parameter Changed

- (FxMetaTestStubTagsAPI *)stubTagsAPI
{
	return self.effect.apiManager.paramTagsAPIv1;
}

- (FxMetaTestStubSetAPI *)stubSetAPI
{
	return self.effect.apiManager.paramSetAPIv5;
}

/*! Routes the target-preset triggers and the reset-value write into one ordering record. */
- (NSMutableArray<NSString *> *)installChangeRecorder
{
	NSMutableArray<NSString *> *events = NSMutableArray.new;
	self.stubTagsAPI.events = events;
	self.stubSetAPI.events = events;
	return events;
}

- (NSString *)valueSectionsTriggerEvent
{
	return FxMetaTestTriggerEvent(FxGripPresetValues | FxGripPresetFlags
								  | FxGripPresetTags | FxGripPresetMeta);
}

- (NSString *)namesTriggerEvent
{
	return FxMetaTestTriggerEvent(FxGripPresetNames);
}

- (void)changeParameter:(FxParameterId)parameterID atTimeDictionary:(NSDictionary *)timeDictionary
{
	NSMutableDictionary *userInfo = NSMutableDictionary.new;
	userInfo[FxTileableEffectParameterChangedIDKey] = @(parameterID);
	if (timeDictionary) {
		userInfo[FxTileableEffectParameterChangedAtTimeKey] = timeDictionary;
	}
	[self.extension extParameterChanged:
		[NSNotification notificationWithName:FxTileableEffectParameterChangedName
									  object:self.effect
									userInfo:userInfo]];
}

- (void)testParameterChangedWithoutAParameterIDAppliesNothing
{
	[self.extension extLoadWithEffect:(id)self.effect];
	[self seedParameter:kMetaTestParamA withConfiguration:[self configurationWithTags:@[] meta:@{}]];
	NSMutableArray<NSString *> *events = [self installChangeRecorder];

	[self.extension extParameterChanged:
		[NSNotification notificationWithName:FxTileableEffectParameterChangedName
									  object:self.effect
									userInfo:@{}]];

	XCTAssertEqualObjects(events, @[]);
}

- (void)testParameterChangedAppliesTheValueSectionsThenTheResetValueThenTheNames
{
	[self.extension extLoadWithEffect:(id)self.effect];
	[self seedParameter:kMetaTestParamA withConfiguration:[self configurationWithTags:@[] meta:@{}]];
	NSMutableArray<NSString *> *events = [self installChangeRecorder];

	[self changeParameter:kMetaTestParamA atTimeDictionary:nil];

	XCTAssertEqualObjects(events, (@[self.valueSectionsTriggerEvent,
									 kFxMetaTestResetEvent,
									 self.namesTriggerEvent]),
						  @"names run last: the host misreports string parameters otherwise");
	XCTAssertEqualObjects(self.stubSetAPI.resetValues, @[@5]);
	XCTAssertEqualObjects(self.stubSetAPI.resetParameterIDs, @[@(kMetaTestParamA)]);
}

- (void)testParameterChangedAppliesOnlyTheTriggersWhenTheRecordCarriesNoResetValue
{
	[self.extension extLoadWithEffect:(id)self.effect];
	[self seedParameter:kMetaTestParamA withConfiguration:nil];
	NSMutableArray<NSString *> *events = [self installChangeRecorder];

	[self changeParameter:kMetaTestParamA atTimeDictionary:nil];

	XCTAssertEqualObjects(events, (@[self.valueSectionsTriggerEvent, self.namesTriggerEvent]));
	XCTAssertEqualObjects(self.stubSetAPI.resetValues, @[]);
}

- (void)testParameterChangedTriggersTheChangedParameter
{
	[self.extension extLoadWithEffect:(id)self.effect];
	[self seedParameter:kMetaTestParamB withConfiguration:nil];
	[self installChangeRecorder];

	[self changeParameter:kMetaTestParamB atTimeDictionary:nil];

	XCTAssertEqualObjects(self.stubTagsAPI.parameterIDs, (@[@(kMetaTestParamB), @(kMetaTestParamB)]));
}

- (void)testParameterChangedForwardsTheTimeCarriedByTheNotification
{
	[self.extension extLoadWithEffect:(id)self.effect];
	[self seedParameter:kMetaTestParamA withConfiguration:[self configurationWithTags:@[] meta:@{}]];
	[self installChangeRecorder];
	CMTime time = FxMetaTestMakeTime(1001, 30000);

	[self changeParameter:kMetaTestParamA atTimeDictionary:FxMetaTestTimeDictionary(time)];

	XCTAssertTrue(FxMetaTestTimesEqual(self.stubTagsAPI.lastTime, time));
	XCTAssertTrue(FxMetaTestTimesEqual(self.stubSetAPI.lastResetTime, time));
}

- (void)testParameterChangedWithoutATimeUsesTheZeroTime
{
	[self.extension extLoadWithEffect:(id)self.effect];
	[self seedParameter:kMetaTestParamA withConfiguration:[self configurationWithTags:@[] meta:@{}]];
	[self installChangeRecorder];

	[self changeParameter:kMetaTestParamA atTimeDictionary:nil];

	XCTAssertTrue(FxMetaTestTimesEqual(self.stubTagsAPI.lastTime, FxMetaTestMakeTime(0, 1)));
	XCTAssertTrue(FxMetaTestTimesEqual(self.stubSetAPI.lastResetTime, FxMetaTestMakeTime(0, 1)));
}

- (void)testParameterChangedAppliesNothingWhenTheTagsAPILacksTheTrigger
{
	[self.extension extLoadWithEffect:(id)self.effect];
	[self seedParameter:kMetaTestParamA withConfiguration:[self configurationWithTags:@[] meta:@{}]];
	NSMutableArray<NSString *> *events = [self installChangeRecorder];
	self.effect.apiManager.paramTagsAPIv1 = NSObject.new;

	[self changeParameter:kMetaTestParamA atTimeDictionary:nil];

	XCTAssertEqualObjects(events, @[], @"the reset value is not written without the trigger");
}

- (void)testParameterChangedPriorityFollowsThePerParameterHandlers
{
	XCTAssertEqual([self.extension ncPriority:FxTileableEffectParameterChangedName], (NSInteger)-10);
}

#pragma mark Persistence

- (void)testFlushWritesTheManagerOncePerMutation
{
	[self.extension extLoadWithEffect:(id)self.effect];
	[self seedParameter:kMetaTestParamA withConfiguration:nil];

	FxGripMetaManager *manager = self.extension.manager;
	[manager setEffect:(id)self.effect];
	XCTAssertTrue(manager.unsaved);

	FxMetaTestStubSetAPI *setAPI = self.effect.apiManager.paramSetAPIv5;
	NSNotification *flush = [NSNotification notificationWithName:FxTileableEffectFlushName
														 object:self.effect
													   userInfo:nil];

	[self.extension extFlush:flush];

	XCTAssertEqual(setAPI.values.count, (NSUInteger)1);
	XCTAssertEqualObjects(setAPI.parameterIDs.firstObject, @(kFxParameterId_InstanceMeta));
	XCTAssertTrue(setAPI.values.firstObject == manager);
	XCTAssertFalse(manager.unsaved);

	[self.extension extFlush:flush];

	XCTAssertEqual(setAPI.values.count, (NSUInteger)1, @"an unchanged manager is not written again");
}

#pragma mark Tags API Delegation

- (FxGripParameterTagsAPI_v1 *)tagsAPI
{
	return [FxGripParameterTagsAPI_v1.alloc initWithAPI:nil effect:(id)self.effect];
}

- (void)assertError:(NSError *)error isNoMetaFailureForParameter:(FxParameterId)parameterID
{
	XCTAssertNotNil(error);
	XCTAssertEqualObjects(error.domain, FxMetaTestExpectedErrorDomain());
	XCTAssertEqual(error.code, kFxError_ThirdPartyDeveloperStart + parameterID);
}

- (void)testTagsAPIReturnsSentinelsWhenTheEffectHasNoMeta
{
	self.effect.hasMeta = NO;
	FxGripParameterTagsAPI_v1 *api = self.tagsAPI;

	XCTAssertNil([api tags]);
	XCTAssertEqual([api tagCount], 0);
	XCTAssertEqual([api tagCount:kMetaTestParamA], -1);
	XCTAssertNil([api parameterTags:kMetaTestParamA]);
	XCTAssertNil([api parametersWithTag:@"a"]);

	[self assertError:[api setTags:@[@"a"] toParameter:kMetaTestParamA] isNoMetaFailureForParameter:kMetaTestParamA];
	[self assertError:[api addTag:@"a" toParameter:kMetaTestParamA] isNoMetaFailureForParameter:kMetaTestParamA];
	[self assertError:[api removeTag:@"a" fromParameter:kMetaTestParamA] isNoMetaFailureForParameter:kMetaTestParamA];
	[self assertError:[api removeAllTags:kMetaTestParamA] isNoMetaFailureForParameter:kMetaTestParamA];

	NSError *error = nil;
	XCTAssertFalse([api parameter:kMetaTestParamA hasTag:@"a" error:&error]);
	[self assertError:error isNoMetaFailureForParameter:kMetaTestParamA];
}

- (void)testTagsAPIForwardsToTheManagerWhenTheEffectHasMeta
{
	FxGripMetaManager *manager = [FxGripMetaManager.alloc initWithEffect:nil];
	[manager addParameter:kMetaTestParamA];
	self.effect.meta = manager;
	self.effect.hasMeta = YES;

	FxGripParameterTagsAPI_v1 *api = self.tagsAPI;

	XCTAssertNil([api addTag:@"round" toParameter:kMetaTestParamA]);
	XCTAssertTrue([[api parameterTags:kMetaTestParamA] containsObject:@"round"]);
	XCTAssertEqual([api tagCount:kMetaTestParamA], 1);
	XCTAssertEqual([api tagCount], 1);
	XCTAssertTrue([[api tags] containsObject:@"round"]);
	XCTAssertEqualObjects([api parametersWithTag:@"round"], @[@(kMetaTestParamA)]);

	NSError *error = nil;
	XCTAssertTrue([api parameter:kMetaTestParamA hasTag:@"round" error:&error]);
	XCTAssertNil(error);

	XCTAssertNil([api removeTag:@"round" fromParameter:kMetaTestParamA]);
	XCTAssertEqual([api tagCount:kMetaTestParamA], 0);
}

#pragma mark Dynamic API Meta Delegation

- (FxGripDynamicParameterAPI_v4 *)dynamicAPI
{
	id<FxDynamicParameterAPI_v3> hostAPI = nil;
	return [FxGripDynamicParameterAPI_v4.alloc initWithAPI:hostAPI effect:(id)self.effect];
}

- (void)testDynamicAPIMetaReturnsSentinelsWhenTheEffectHasNoMeta
{
	self.effect.hasMeta = NO;
	FxGripDynamicParameterAPI_v4 *api = self.dynamicAPI;

	XCTAssertEqual([api metaCountFromParameter:kMetaTestParamA], -1);

	NSDictionary *meta = nil;
	[self assertError:[api getMeta:&meta fromParameter:kMetaTestParamA] isNoMetaFailureForParameter:kMetaTestParamA];
	[self assertError:[api setMeta:@{} toParameter:kMetaTestParamA] isNoMetaFailureForParameter:kMetaTestParamA];
	[self assertError:[api removeAllMeta:kMetaTestParamA] isNoMetaFailureForParameter:kMetaTestParamA];

	XCTAssertFalse([api setMeta:@"v" forKey:@"k" toParameter:kMetaTestParamA]);
	XCTAssertFalse([api removeMetaKey:@"k" fromParameter:kMetaTestParamA]);

	NSError *error = nil;
	XCTAssertFalse([api parameter:kMetaTestParamA hasMetaKey:@"k" error:&error]);
	[self assertError:error isNoMetaFailureForParameter:kMetaTestParamA];
}

- (void)testDynamicAPIMetaForwardsToTheManagerWhenTheEffectHasMeta
{
	FxGripMetaManager *manager = [FxGripMetaManager.alloc initWithEffect:nil];
	[manager addParameter:kMetaTestParamA];
	self.effect.meta = manager;
	self.effect.hasMeta = YES;

	FxGripDynamicParameterAPI_v4 *api = self.dynamicAPI;

	XCTAssertEqual([api metaCountFromParameter:kMetaTestParamA], 0);
	XCTAssertTrue([api setMeta:@"v" forKey:@"k" toParameter:kMetaTestParamA]);
	XCTAssertEqual([api metaCountFromParameter:kMetaTestParamA], 1);

	id<NSSecureCoding, NSCopying> value = nil;
	XCTAssertTrue([api getMeta:&value forKey:@"k" fromParameter:kMetaTestParamA]);
	XCTAssertEqualObjects((id)value, @"v");

	NSError *error = nil;
	XCTAssertTrue([api parameter:kMetaTestParamA hasMetaKey:@"k" error:&error]);
	XCTAssertNil(error);

	NSDictionary *meta = nil;
	XCTAssertNil([api getMeta:&meta fromParameter:kMetaTestParamA]);
	XCTAssertEqualObjects(meta, @{@"k": @"v"});

	XCTAssertTrue([api removeMetaKey:@"k" fromParameter:kMetaTestParamA]);
	XCTAssertEqual([api metaCountFromParameter:kMetaTestParamA], 0);
}

- (void)testOrphanMetaStubsAreAbsentFromTheParameterAPIs
{
	SEL metaCount = NSSelectorFromString(@"parameterMetaCount:");
	SEL removeMeta = NSSelectorFromString(@"removeMeta:fromParameter:");

	XCTAssertFalse([(id)self.dynamicAPI respondsToSelector:metaCount]);
	XCTAssertFalse([(id)self.dynamicAPI respondsToSelector:removeMeta]);
	XCTAssertFalse([(id)self.tagsAPI respondsToSelector:metaCount]);
	XCTAssertFalse([(id)self.tagsAPI respondsToSelector:removeMeta]);
}

@end
