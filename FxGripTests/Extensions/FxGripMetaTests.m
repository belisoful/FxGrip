/*!
	@file       FxGripMetaTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripMetaTests
	@abstract   Unit tests for the FxGripMeta extension and the tag and meta parameter-API delegation.
	@discussion Introduced in FxGrip 0.1.0. Stub host API objects record the writes and triggers the extension performs. The tests cover the InstanceMeta parameter registration, record seeding from the parameter configuration, the document manager adoption and merge, the parameter-changed target-preset and reset-value pass, and flush persistence. They cover the FxGripParameterTagsAPI_v1 and FxGripMetaAPI_v1 delegation to the effect's manager, with sentinel returns when the effect has no meta.
*/

#import <XCTest/XCTest.h>
#import <dlfcn.h>
#import <CoreMedia/CoreMedia.h>
#import <FxPlug/FxTypes.h>
#import "FxGrip/FxGripTypes.h"
#import "FxGrip/FxGripErrors.h"
#import "FxGrip/FxGripParameterFlags.h"
#import "FxGrip/FxGripMetaManager.h"
#import "FxGrip/FxGripAPINotifications.h"
#import "FxGrip/FxGripTileableEffect+Notifications.h"
#import "FxGrip/FxGripParameterTagsAPI_v1.h"
#import "FxGrip/FxGripMetaAPI_v1.h"

// FxGripMeta.h reaches its superclass through a flat angled include that does not resolve
// outside the framework target, so it is declared here with the members the tests
// exercise; the implementation comes from the linked framework.
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

static const FxParameterId kMetaTestParamA = 10;
static const FxParameterId kMetaTestParamB = 11;

// The test target links only FxGrip and XCTest, so NSPriorityNotificationCenter
// (from BEFoundation) is resolved at runtime by name to avoid an unlinked symbol.
static NSNotificationCenter *FxGripMetaTestMakePriorityCenter(void)
{
	Class cls = NSClassFromString(@"NSPriorityNotificationCenter");
	return [[cls alloc] init];
}

/*!
	The test bundle does not link FxPlug.framework, and FxPlug is weak-linked by FxGrip, so
	the constant is read from the loaded images. Outside an FxPlug host the symbol is absent
	and FxGripErrors.h substitutes FxGripPlugErrorDomain.
*/
static NSString *FxGripMetaTestExpectedErrorDomain(void)
{
	NSString * __unsafe_unretained *domain = (NSString * __unsafe_unretained *)dlsym(RTLD_DEFAULT, "FxPlugErrorDomain");
	return domain ? *domain : FxGripPlugErrorDomainConstant;
}

/*!
	Builds an API parameter notification payload. The wrapper APIs carry the parameter
	dictionary under FxGripNotifyAPI_ParameterKey and repeat the ID at the top level; the
	NSDictionary(FxGripTileableEffect) accessors resolve only for a dictionary that also
	carries "type" and "name", so both levels carry the full triple.
*/
static NSDictionary *FxGripMetaTestParameterUserInfo(FxParameterId parameterID)
{
	NSDictionary *parameter = @{
		kFxParameterProperty_Id: @(parameterID),
		kFxParameterProperty_Type: kFxParameterType_Float,
		kFxParameterProperty_Name: @"Test Parameter"
	};
	NSMutableDictionary *userInfo = parameter.mutableCopy;
	userInfo[FxGripNotifyAPI_ParameterKey] = parameter;
	return userInfo;
}

/*!
	The payload FxGripParameterCreationAPI_v5 posts: the parameter dictionary sits under
	FxGripNotifyAPI_ParameterKey and the top level carries only the ID.
*/
static NSDictionary *FxGripMetaTestHostAddUserInfo(FxParameterId parameterID)
{
	return @{
		kFxParameterProperty_Id: @(parameterID),
		FxGripNotifyAPI_ParameterKey: @{
			kFxParameterProperty_Type: @(FxParameterType_Float),
			kFxParameterProperty_Name: @"Test Parameter",
			kFxParameterProperty_Id: @(parameterID),
			kFxParameterProperty_ParentId: @(kFxParameterId_TopLevelGroup)
		}.mutableCopy
	};
}

/*! The payload FxGripDynamicParameterAPI_v3 removeParameter: posts. */
static NSDictionary *FxGripMetaTestHostRemoveUserInfo(FxParameterId parameterID)
{
	return @{
		kFxParameterProperty_Id: @(parameterID),
		FxGripNotifyAPI_ParameterKey: @{kFxParameterProperty_Id: @(parameterID)}
	};
}

static NSNotification *FxGripMetaTestParameterNotification(NSNotificationName name, FxParameterId parameterID, id object)
{
	return [NSNotification notificationWithName:name
										 object:object
									   userInfo:FxGripMetaTestParameterUserInfo(parameterID)];
}

/*!
	The test bundle links neither CoreMedia nor FxPlug, so the CMTime dictionary bridge is
	resolved from the loaded images the way FxGripTileableEffectNotificationTests does.
*/
typedef CFDictionaryRef (*FxGripMetaTestTimeToDictionaryFn)(CMTime, CFAllocatorRef);

static NSDictionary *FxGripMetaTestTimeDictionary(CMTime time)
{
	FxGripMetaTestTimeToDictionaryFn fn =
		(FxGripMetaTestTimeToDictionaryFn)dlsym(RTLD_DEFAULT, "CMTimeCopyAsDictionary");
	NSCAssert(fn != NULL, @"CoreMedia CMTimeCopyAsDictionary must be resolvable in-process");
	return (__bridge_transfer NSDictionary *)fn(time, kCFAllocatorDefault);
}

static CMTime FxGripMetaTestMakeTime(int64_t value, int32_t timescale)
{
	return (CMTime){.value = value, .timescale = timescale, .flags = kCMTimeFlags_Valid, .epoch = 0};
}

static BOOL FxGripMetaTestTimesEqual(CMTime lhs, CMTime rhs)
{
	return lhs.value == rhs.value && lhs.timescale == rhs.timescale
		&& lhs.flags == rhs.flags && lhs.epoch == rhs.epoch;
}

/*! One recorded step of the parameter-changed pass, tagged with the options it carried. */
static NSString *FxGripMetaTestTriggerEvent(FxGripPresetOptions options)
{
	return [NSString stringWithFormat:@"target:%lu", (unsigned long)options];
}

static NSString * const kFxMetaTestResetEvent = @"reset";

#pragma mark - Test doubles

// Records the value the extension writes on flush, and the reset value the
// parameter-changed pass writes between the two target-preset calls.
@interface FxGripMetaTestStubSetAPI : NSObject
@property (nonatomic, strong) NSMutableArray *values;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *parameterIDs;
@property (nonatomic, strong) NSMutableArray<NSString *> *events;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *resetValues;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *resetParameterIDs;
@property (nonatomic, assign) CMTime lastResetTime;
@end

@implementation FxGripMetaTestStubSetAPI

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
@interface FxGripMetaTestStubTagsAPI : NSObject
@property (nonatomic, strong) NSMutableArray<NSString *> *events;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *parameterIDs;
@property (nonatomic, assign) CMTime lastTime;
@end

@implementation FxGripMetaTestStubTagsAPI

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
	[self.events addObject:FxGripMetaTestTriggerEvent(options)];
	[self.parameterIDs addObject:@(parameterID)];
	self.lastTime = time;
	return YES;
}

@end

// Hands the extension the manager stored in the document.
@interface FxGripMetaTestStubGetAPI : NSObject
@property (nonatomic, strong) NSObject<NSSecureCoding, NSCopying> *storedValue;
@property (nonatomic, assign) FxParameterId lastRequestedParameter;
@end

@implementation FxGripMetaTestStubGetAPI

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

@interface FxGripMetaTestStubAPIManager : NSObject
@property (nonatomic, strong) FxGripMetaTestStubGetAPI *paramGetAPIv6;
@property (nonatomic, strong) FxGripMetaTestStubSetAPI *paramSetAPIv5;
@property (nonatomic, strong) id paramTagsAPIv1;
@end

@implementation FxGripMetaTestStubAPIManager
@end

// FxGripTileableEffect's designated initializer registers into the process-wide
// notification center, so the extension is exercised against a stub exposing the
// members the meta wiring reads.
@interface FxGripMetaTestStubEffect : NSObject
@property (nonatomic, assign) BOOL addedToDocument;
@property (nonatomic, strong) NSNotificationCenter *notifier;
@property (nonatomic, strong) FxGripMetaTestStubAPIManager *apiManager;
@property (nonatomic, assign) BOOL hasMeta;
@property (nonatomic, strong) FxGripMetaManager *meta;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSDictionary *> *configurations;
@end

@implementation FxGripMetaTestStubEffect

- (id)effectBase
{
	// The stub plays the full effect; rich reads route back to it, as the old cast did.
	return self;
}


- (instancetype)init
{
	self = [super init];
	if (self) {
		_notifier = FxGripMetaTestMakePriorityCenter();
		_apiManager = FxGripMetaTestStubAPIManager.new;
		_apiManager.paramGetAPIv6 = FxGripMetaTestStubGetAPI.new;
		_apiManager.paramSetAPIv5 = FxGripMetaTestStubSetAPI.new;
		_apiManager.paramTagsAPIv1 = FxGripMetaTestStubTagsAPI.new;
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
@property (nonatomic, strong) FxGripMetaTestStubEffect *effect;
@end

@implementation FxGripMetaTests

- (void)setUp
{
	[super setUp];
	self.extension = [FxGripMeta.alloc init];
	self.effect = [FxGripMetaTestStubEffect.alloc init];
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
	[self.extension extAPIParameterAdd:FxGripMetaTestParameterNotification(FxGripNotifyAPI_ParameterAddName,
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

/*! @abstract A freshly initialized extension targets the InstanceMeta parameter id and has no manager. */
- (void)testInitUsesTheInstanceMetaParameterIDAndHasNoManager
{
	XCTAssertEqual(self.extension.parameterID, (FxParameterId)kFxParameterId_InstanceMeta);
	XCTAssertEqual(self.extension.parameterID, (FxParameterId)9995);
	XCTAssertNil(self.extension.manager);
}

/*! @abstract The data classes include the meta manager and the inherited dictionary and array container classes. */
- (void)testDataClassesIncludeTheManagerAndTheInheritedContainers
{
	NSSet *dataClasses = self.extension.dataClasses;

	XCTAssertTrue([dataClasses containsObject:NSClassFromString(@"FxGripMetaManager")]);
	XCTAssertTrue([dataClasses containsObject:FxGripMetaManager.class]);
	XCTAssertTrue([dataClasses containsObject:NSDictionary.class]);
	XCTAssertTrue([dataClasses containsObject:NSArray.class]);
}

/*! @abstract Adding parameters registers the hidden custom InstanceMeta parameter with its factory and preset-no-meta flags. */
- (void)testExtAddParametersRegistersTheHiddenInstanceMetaParameter
{
	NSMutableArray *parameters = NSMutableArray.new;
	NSNotification *notification = [NSNotification notificationWithName:FxGripTileableEffectAddParametersName
																 object:self.effect
															   userInfo:@{FxGripTileableEffectParametersKey: parameters}];

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

/*! @abstract A parameter add seeds the manager with the configuration's tags, meta, and reset and target-preset record entries, and marks it unsaved. */
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

/*! @abstract A parameter add with no configuration still creates the manager record for the parameter. */
- (void)testParameterAddWithoutConfigurationStillCreatesTheRecord
{
	[self.extension extLoadWithEffect:(id)self.effect];
	[self seedParameter:kMetaTestParamA withConfiguration:nil];

	XCTAssertNotNil(self.extension.manager);
	XCTAssertTrue([self.extension.manager parameterExists:kMetaTestParamA]);
}

/*! @abstract Reseeding keeps the existing user meta, target preset, and reset values and adds the configuration tags. */
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

/*! @abstract A parameter remove drops the manager record for the parameter. */
- (void)testParameterRemoveDropsTheRecord
{
	[self.extension extLoadWithEffect:(id)self.effect];
	[self seedParameter:kMetaTestParamA withConfiguration:nil];
	XCTAssertTrue([self.extension.manager parameterExists:kMetaTestParamA]);

	[self.extension extAPIParameterRemove:FxGripMetaTestParameterNotification(FxGripNotifyAPI_ParameterRemoveName,
																		  kMetaTestParamA,
																		  self.effect)];

	XCTAssertFalse([self.extension.manager parameterExists:kMetaTestParamA]);
}

/*! @abstract A parameter add for the InstanceMeta parameter itself seeds no manager. */
- (void)testInstanceMetaParameterIsNeverSeeded
{
	[self.extension extLoadWithEffect:(id)self.effect];

	[self.extension extAPIParameterAdd:FxGripMetaTestParameterNotification(FxGripNotifyAPI_ParameterAddName,
																	   kFxParameterId_InstanceMeta,
																	   self.effect)];

	XCTAssertNil(self.extension.manager);
}

/*! @abstract A parameter add seeds the record under the parameter id the creation-API notification carries. */
- (void)testParameterAddSeedsTheParameterIDCarriedByTheCreationAPINotification
{
	[self.extension extLoadWithEffect:(id)self.effect];

	[self.extension extAPIParameterAdd:[NSNotification notificationWithName:FxGripNotifyAPI_ParameterAddName
																	 object:self.effect
																   userInfo:FxGripMetaTestHostAddUserInfo(kMetaTestParamA)]];

	XCTAssertEqualObjects(self.extension.manager.parameterIDs, @[@(kMetaTestParamA)],
						  @"the seeded record carries the parameter ID the creation API announced");
}

/*! @abstract A parameter remove drops the record named by the dynamic-API notification. */
- (void)testParameterRemoveDropsTheRecordNamedByTheDynamicAPINotification
{
	[self.extension extLoadWithEffect:(id)self.effect];
	[self seedParameter:kMetaTestParamA withConfiguration:nil];

	[self.extension extAPIParameterRemove:[NSNotification notificationWithName:FxGripNotifyAPI_ParameterRemoveName
																		object:self.effect
																	  userInfo:FxGripMetaTestHostRemoveUserInfo(kMetaTestParamA)]];

	XCTAssertFalse([self.extension.manager parameterExists:kMetaTestParamA],
				   @"the removed record is the one the dynamic API announced");
}

#pragma mark Document Load

/*! @abstract Added-to-document adopts the stored document manager and merges the seeded records, with document values winning over configuration defaults. */
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

	[self.extension extAddedToDocument:[NSNotification notificationWithName:FxGripTileableEffectAddedToDocumentName
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

/*! @abstract Added-to-document creates a manager when the document holds none. */
- (void)testAddedToDocumentCreatesAManagerWhenTheDocumentHoldsNone
{
	[self.extension extLoadWithEffect:(id)self.effect];

	[self.extension extAddedToDocument:[NSNotification notificationWithName:FxGripTileableEffectAddedToDocumentName
																	object:self.effect
																  userInfo:nil]];

	XCTAssertNotNil(self.extension.manager);
}

// extAddedToDocument: clears the loaded manager's unsaved flag before merging the seeded
// records. A seeded reset/target key merges through a direct record write that bypasses the
// manager's mutators, so it must raise the unsaved flag by hand or the entry never flushes.
/*! @abstract Merging a seeded reset key into the loaded document manager raises its unsaved flag so the next flush persists it. */
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

	[self.extension extAddedToDocument:[NSNotification notificationWithName:FxGripTileableEffectAddedToDocumentName
																	object:self.effect
																  userInfo:nil]];

	XCTAssertTrue(self.extension.manager == documentManager);
	XCTAssertEqualObjects([documentManager parameterData:kMetaTestParamA][kFxParameterProperty_ResetValue], @9,
						  @"the seeded reset value merges into the loaded record");
	XCTAssertTrue(documentManager.unsaved,
				  @"the merged reset key raises unsaved so the next flush persists it");
}

#pragma mark Parameter Changed

- (FxGripMetaTestStubTagsAPI *)stubTagsAPI
{
	return self.effect.apiManager.paramTagsAPIv1;
}

- (FxGripMetaTestStubSetAPI *)stubSetAPI
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
	return FxGripMetaTestTriggerEvent(FxGripPresetValues | FxGripPresetFlags
								  | FxGripPresetTags | FxGripPresetMeta);
}

- (NSString *)namesTriggerEvent
{
	return FxGripMetaTestTriggerEvent(FxGripPresetNames);
}

- (void)changeParameter:(FxParameterId)parameterID atTimeDictionary:(NSDictionary *)timeDictionary
{
	NSMutableDictionary *userInfo = NSMutableDictionary.new;
	userInfo[FxGripTileableEffectParameterChangedIDKey] = @(parameterID);
	if (timeDictionary) {
		userInfo[FxGripTileableEffectParameterChangedAtTimeKey] = timeDictionary;
	}
	[self.extension extParameterChanged:
		[NSNotification notificationWithName:FxGripTileableEffectParameterChangedName
									  object:self.effect
									userInfo:userInfo]];
}

/*! @abstract A parameter-changed notification with no parameter id applies no triggers. */
- (void)testParameterChangedWithoutAParameterIDAppliesNothing
{
	[self.extension extLoadWithEffect:(id)self.effect];
	[self seedParameter:kMetaTestParamA withConfiguration:[self configurationWithTags:@[] meta:@{}]];
	NSMutableArray<NSString *> *events = [self installChangeRecorder];

	[self.extension extParameterChanged:
		[NSNotification notificationWithName:FxGripTileableEffectParameterChangedName
									  object:self.effect
									userInfo:@{}]];

	XCTAssertEqualObjects(events, @[]);
}

/*! @abstract A parameter change applies the value sections, then the reset value, then the names, in that order. */
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

/*! @abstract A parameter change applies only the value and name triggers and writes no reset value when the record carries none. */
- (void)testParameterChangedAppliesOnlyTheTriggersWhenTheRecordCarriesNoResetValue
{
	[self.extension extLoadWithEffect:(id)self.effect];
	[self seedParameter:kMetaTestParamA withConfiguration:nil];
	NSMutableArray<NSString *> *events = [self installChangeRecorder];

	[self changeParameter:kMetaTestParamA atTimeDictionary:nil];

	XCTAssertEqualObjects(events, (@[self.valueSectionsTriggerEvent, self.namesTriggerEvent]));
	XCTAssertEqualObjects(self.stubSetAPI.resetValues, @[]);
}

/*! @abstract A parameter change fires the target-preset triggers against the changed parameter id. */
- (void)testParameterChangedTriggersTheChangedParameter
{
	[self.extension extLoadWithEffect:(id)self.effect];
	[self seedParameter:kMetaTestParamB withConfiguration:nil];
	[self installChangeRecorder];

	[self changeParameter:kMetaTestParamB atTimeDictionary:nil];

	XCTAssertEqualObjects(self.stubTagsAPI.parameterIDs, (@[@(kMetaTestParamB), @(kMetaTestParamB)]));
}

/*! @abstract A parameter change forwards the CMTime carried by the notification to the tags and set APIs. */
- (void)testParameterChangedForwardsTheTimeCarriedByTheNotification
{
	[self.extension extLoadWithEffect:(id)self.effect];
	[self seedParameter:kMetaTestParamA withConfiguration:[self configurationWithTags:@[] meta:@{}]];
	[self installChangeRecorder];
	CMTime time = FxGripMetaTestMakeTime(1001, 30000);

	[self changeParameter:kMetaTestParamA atTimeDictionary:FxGripMetaTestTimeDictionary(time)];

	XCTAssertTrue(FxGripMetaTestTimesEqual(self.stubTagsAPI.lastTime, time));
	XCTAssertTrue(FxGripMetaTestTimesEqual(self.stubSetAPI.lastResetTime, time));
}

/*! @abstract A parameter change with no time uses the zero time for the tags and set APIs. */
- (void)testParameterChangedWithoutATimeUsesTheZeroTime
{
	[self.extension extLoadWithEffect:(id)self.effect];
	[self seedParameter:kMetaTestParamA withConfiguration:[self configurationWithTags:@[] meta:@{}]];
	[self installChangeRecorder];

	[self changeParameter:kMetaTestParamA atTimeDictionary:nil];

	XCTAssertTrue(FxGripMetaTestTimesEqual(self.stubTagsAPI.lastTime, FxGripMetaTestMakeTime(0, 1)));
	XCTAssertTrue(FxGripMetaTestTimesEqual(self.stubSetAPI.lastResetTime, FxGripMetaTestMakeTime(0, 1)));
}

/*! @abstract A parameter change writes nothing, including the reset value, when the tags API lacks the target-preset trigger. */
- (void)testParameterChangedAppliesNothingWhenTheTagsAPILacksTheTrigger
{
	[self.extension extLoadWithEffect:(id)self.effect];
	[self seedParameter:kMetaTestParamA withConfiguration:[self configurationWithTags:@[] meta:@{}]];
	NSMutableArray<NSString *> *events = [self installChangeRecorder];
	self.effect.apiManager.paramTagsAPIv1 = NSObject.new;

	[self changeParameter:kMetaTestParamA atTimeDictionary:nil];

	XCTAssertEqualObjects(events, @[], @"the reset value is not written without the trigger");
}

/*! @abstract The parameter-changed handler runs at priority -10. */
- (void)testParameterChangedPriorityFollowsThePerParameterHandlers
{
	XCTAssertEqual([self.extension ncPriority:FxGripTileableEffectParameterChangedName], (NSInteger)-10);
}

#pragma mark Persistence

/*! @abstract Flush writes the manager once to the InstanceMeta parameter, clears its unsaved flag, and does not write an unchanged manager again. */
- (void)testFlushWritesTheManagerOncePerMutation
{
	[self.extension extLoadWithEffect:(id)self.effect];
	[self seedParameter:kMetaTestParamA withConfiguration:nil];

	FxGripMetaManager *manager = self.extension.manager;
	[manager setEffect:(id)self.effect];
	XCTAssertTrue(manager.unsaved);

	FxGripMetaTestStubSetAPI *setAPI = self.effect.apiManager.paramSetAPIv5;
	NSNotification *flush = [NSNotification notificationWithName:FxGripTileableEffectFlushName
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
	XCTAssertEqualObjects(error.domain, FxGripMetaTestExpectedErrorDomain());
	XCTAssertEqual(error.code, kFxError_ThirdPartyDeveloperStart + parameterID);
}

/*! @abstract The tags API returns nil and sentinel counts and no-meta errors when the effect has no meta. */
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

/*! @abstract The tags API forwards add, query, count, and remove operations to the manager when the effect has meta. */
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

- (FxGripMetaAPI_v1 *)dynamicAPI
{
	return [FxGripMetaAPI_v1.alloc initWithEffect:(id)self.effect];
}

/*! @abstract The meta API returns sentinel counts and no-meta errors when the effect has no meta. */
- (void)testDynamicAPIMetaReturnsSentinelsWhenTheEffectHasNoMeta
{
	self.effect.hasMeta = NO;
	FxGripMetaAPI_v1 *api = self.dynamicAPI;

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

/*! @abstract The meta API forwards set, get, count, query, and remove operations to the manager when the effect has meta. */
- (void)testDynamicAPIMetaForwardsToTheManagerWhenTheEffectHasMeta
{
	FxGripMetaManager *manager = [FxGripMetaManager.alloc initWithEffect:nil];
	[manager addParameter:kMetaTestParamA];
	self.effect.meta = manager;
	self.effect.hasMeta = YES;

	FxGripMetaAPI_v1 *api = self.dynamicAPI;

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

/*! @abstract The orphan meta-count and remove-meta selectors are absent from both parameter APIs. */
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
