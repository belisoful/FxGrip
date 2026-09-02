//
//  FxGripParameterTagsAPI_v1Tests.m
//  FxGripTests
//
//  Unit tests for the preset section of FxParameterTagsAPI_v1: tag-to-definition
//  resolution from the plugin's plist table, target-preset resolution with the
//  instance meta record overriding the parameter configuration, the preset
//  application core (section order, option gating, the tag boundary, and the five
//  section semantics), and the wiring that keeps the FxGrip-implemented tags API
//  reachable through FxGripAPIAccessing.
//

#import <XCTest/XCTest.h>
#import <objc/runtime.h>
#import <CoreMedia/CoreMedia.h>
#import <FxPlug/FxTypes.h>
#import "FxGrip/FxGripTypes.h"
#import "FxGrip/FxGripMetaManager.h"
#import "FxGrip/FxGripParameterFlags.h"
#import "FxGrip/FxParameterTagsAPI_v1.h"

// FxGripParameterTagsAPI_v1.h and FxGripAPIAccessing.h reach their dependencies through
// flat quoted includes that do not resolve outside the framework target, so both classes
// are declared here with the members the tests exercise; the implementations come from
// the linked framework.
@interface FxGripParameterTagsAPI_v1 : NSObject <FxParameterTagsAPI_v1>
- (nullable instancetype)initWithAPI:(nullable id<FxParameterTagsAPI_v1>)api effect:(nonnull id)effect;
@end

@interface FxGripAPIAccessing : NSObject
- (nullable instancetype)initWithAPIManager:(nullable id)apiManager effect:(nonnull id)effect;
- (nullable id)apiForProtocol:(nonnull Protocol *)apiProtocol;
@property (readonly, nullable) id paramTagsAPIv1;
@end

static const FxParameterId kTagsTestParam = 20;
static const FxParameterId kTagsTestOtherParam = 21;

// FxGripPresetsAPI_v1.h is not a public framework header, so the one preset flag these
// tests exercise is declared here with its shipped value.
static const FxParameterPresetFlags kTagsTestIgnoreTagBoundary = (1 << 1);

// The test bundle links only FxGrip and XCTest, so CMTime values are built without the
// CoreMedia symbols.
static CMTime FxGripTagsTestTime(void)
{
	return (CMTime){.value = 5, .timescale = 30, .flags = kCMTimeFlags_Valid, .epoch = 0};
}

static BOOL FxGripTagsTestTimesEqual(CMTime lhs, CMTime rhs)
{
	return lhs.value == rhs.value && lhs.timescale == rhs.timescale
		&& lhs.flags == rhs.flags && lhs.epoch == rhs.epoch;
}

/*! One recorded side effect: the section that produced it and the parameter it touched. */
static NSString *FxGripTagsTestEvent(NSString *section, FxParameterId parameterID)
{
	return [NSString stringWithFormat:@"%@:%u", section, parameterID];
}

/*! A one-section preset entry, so which entry a definition selected is readable by name. */
static NSDictionary *FxGripTagsTestNamesEntry(FxParameterId parameterID, NSString *name)
{
	return @{kFxParameterProperty_TargetPresetNames: @{@(parameterID).stringValue: name}};
}

#pragma mark - Test doubles

// Serves both paramSetAPIv5 (preset values) and paramSetAPIv6 (preset flags). It does not
// vend a dynamic API, so FxGripPreset dispatches on the encoded value's own shape.
@interface FxGripTagsTestSettingAPI : NSObject
@property (nonatomic, strong, nonnull) NSMutableArray<NSString *> *events;
@property (nonatomic, strong, nonnull) NSMutableDictionary<NSNumber *, id> *values;
@property (nonatomic, strong, nonnull) NSMutableDictionary<NSNumber *, NSNumber *> *flags;
@property (nonatomic, strong, nonnull) NSMutableSet<NSNumber *> *failingValueParameters;
@property (nonatomic, strong, nonnull) NSMutableSet<NSNumber *> *failingFlagParameters;
@property (nonatomic, assign) CMTime lastValueTime;
@end

@implementation FxGripTagsTestSettingAPI

- (instancetype)init
{
	self = [super init];
	if (self) {
		_events = NSMutableArray.new;
		_values = NSMutableDictionary.new;
		_flags = NSMutableDictionary.new;
		_failingValueParameters = NSMutableSet.new;
		_failingFlagParameters = NSMutableSet.new;
	}
	return self;
}

- (BOOL)setFloatValue:(double)value toParameter:(UInt32)parameterID atTime:(CMTime)time
{
	[self.events addObject:FxGripTagsTestEvent(kFxParameterProperty_TargetPresetValues, parameterID)];
	self.lastValueTime = time;
	if ([self.failingValueParameters containsObject:@(parameterID)]) {
		return NO;
	}
	self.values[@(parameterID)] = @(value);
	return YES;
}

- (BOOL)setStringParameterValue:(NSString *)string toParameter:(UInt32)parameterID
{
	[self.events addObject:FxGripTagsTestEvent(kFxParameterProperty_TargetPresetValues, parameterID)];
	if ([self.failingValueParameters containsObject:@(parameterID)]) {
		return NO;
	}
	self.values[@(parameterID)] = string;
	return YES;
}

- (BOOL)setParameterFlags:(FxParameterFlags)flags toParameter:(UInt32)parameterID
{
	[self.events addObject:FxGripTagsTestEvent(kFxParameterProperty_TargetPresetFlags, parameterID)];
	if ([self.failingFlagParameters containsObject:@(parameterID)]) {
		return NO;
	}
	self.flags[@(parameterID)] = @(flags);
	return YES;
}

@end

// Serves dynamicParamAPIv3 for the names section.
@interface FxGripTagsTestDynamicAPI : NSObject
@property (nonatomic, strong, nonnull) NSMutableArray<NSString *> *events;
@property (nonatomic, strong, nonnull) NSMutableDictionary<NSNumber *, NSString *> *names;
@property (nonatomic, strong, nonnull) NSMutableSet<NSNumber *> *failingParameters;
@end

@implementation FxGripTagsTestDynamicAPI

- (instancetype)init
{
	self = [super init];
	if (self) {
		_events = NSMutableArray.new;
		_names = NSMutableDictionary.new;
		_failingParameters = NSMutableSet.new;
	}
	return self;
}

- (NSError *)setParameter:(UInt32)parameterID name:(NSString *)newName
{
	[self.events addObject:FxGripTagsTestEvent(kFxParameterProperty_TargetPresetNames, parameterID)];
	if ([self.failingParameters containsObject:@(parameterID)]) {
		return [NSError errorWithDomain:@"FxGripTagsTest" code:1 userInfo:nil];
	}
	self.names[@(parameterID)] = newName;
	return nil;
}

@end

// Serves paramGetAPIv6: the current value of the Menu or Toggle parameter whose target
// preset is applied.
@interface FxGripTagsTestRetrievalAPI : NSObject
@property (nonatomic, strong, nonnull) NSMutableArray<NSNumber *> *requestedParameters;
@property (nonatomic, assign) int intValue;
@property (nonatomic, assign) BOOL boolValue;
@property (nonatomic, assign) BOOL succeeds;
@property (nonatomic, assign) CMTime lastTime;
@end

@implementation FxGripTagsTestRetrievalAPI

- (instancetype)init
{
	self = [super init];
	if (self) {
		_requestedParameters = NSMutableArray.new;
		_succeeds = YES;
	}
	return self;
}

- (BOOL)getIntValue:(int *)value fromParameter:(UInt32)parameterID atTime:(CMTime)time
{
	[self.requestedParameters addObject:@(parameterID)];
	self.lastTime = time;
	if (!self.succeeds) {
		return NO;
	}
	*value = self.intValue;
	return YES;
}

- (BOOL)getBoolValue:(BOOL *)value fromParameter:(UInt32)parameterID atTime:(CMTime)time
{
	[self.requestedParameters addObject:@(parameterID)];
	self.lastTime = time;
	if (!self.succeeds) {
		return NO;
	}
	*value = self.boolValue;
	return YES;
}

@end

@interface FxGripTagsTestAPIManager : NSObject
@property (nonatomic, strong, nullable) FxGripTagsTestSettingAPI *settingAPI;
@property (nonatomic, strong, nullable) FxGripTagsTestDynamicAPI *dynamicAPI;
@property (nonatomic, strong, nullable) FxGripTagsTestRetrievalAPI *retrievalAPI;
@end

@implementation FxGripTagsTestAPIManager

- (id)paramSetAPIv5
{
	return self.settingAPI;
}

- (id)paramSetAPIv6
{
	return self.settingAPI;
}

- (id)paramGetAPIv6
{
	return self.retrievalAPI;
}

- (id)dynamicParamAPIv3
{
	return self.dynamicAPI;
}

@end

// Supplies the current flags the flags, tags, and meta sections read, and the live menu
// entries the name-keyed definition lookup consults.
@interface FxGripTagsTestParameterData : NSObject
@property (nonatomic, strong, nonnull) NSMutableDictionary<NSNumber *, NSNumber *> *flagsByParameter;
@property (nonatomic, strong, nonnull) NSMutableDictionary<NSNumber *, NSArray<NSString *> *> *menusByParameter;
@end

@implementation FxGripTagsTestParameterData

- (instancetype)init
{
	self = [super init];
	if (self) {
		_flagsByParameter = NSMutableDictionary.new;
		_menusByParameter = NSMutableDictionary.new;
	}
	return self;
}

- (FxParameterFlags)storedFlags:(FxParameterId)parameterID
{
	return (FxParameterFlags)self.flagsByParameter[@(parameterID)].unsignedIntValue;
}

- (NSArray<NSString *> *)storedMenus:(FxParameterId)parameterID
{
	return self.menusByParameter[@(parameterID)];
}

@end

// A real meta manager that also reports the order of the tag and meta writes.
@interface FxGripTagsTestMetaManager : FxGripMetaManager
@property (nonatomic, strong, nonnull) NSMutableArray<NSString *> *events;
@end

@implementation FxGripTagsTestMetaManager

- (NSError *)addTag:(NSString *)tag toParameter:(FxParameterId)parameterID
{
	[self.events addObject:FxGripTagsTestEvent(kFxParameterProperty_TargetPresetTags, parameterID)];
	return [super addTag:tag toParameter:parameterID];
}

- (NSError *)removeTag:(NSString *)tag fromParameter:(FxParameterId)parameterID
{
	[self.events addObject:FxGripTagsTestEvent(kFxParameterProperty_TargetPresetTags, parameterID)];
	return [super removeTag:tag fromParameter:parameterID];
}

- (BOOL)setMeta:(NSObject<NSSecureCoding, NSCopying> *)value
		 forKey:(NSString *)key
	toParameter:(FxParameterId)parameterID
{
	[self.events addObject:FxGripTagsTestEvent(kFxParameterProperty_TargetPresetMeta, parameterID)];
	return [super setMeta:value forKey:key toParameter:parameterID];
}

@end

// FxGripTileableEffect's designated initializer registers into the process-wide
// notification center, so the API wrapper is exercised against a stub exposing the
// members the preset resolution reads.
@interface FxGripTagsTestStubEffect : NSObject
@property (nonatomic, strong, nullable) NSDictionary<NSString *, id> *pluginProperties;
@property (nonatomic, assign) BOOL hasMeta;
@property (nonatomic, strong, nullable) FxGripMetaManager *meta;
@property (nonatomic, strong, nullable) FxGripTagsTestAPIManager *apiManager;
@property (nonatomic, strong, nullable) FxGripTagsTestParameterData *parameterData;
@property (nonatomic, strong, nonnull) NSMutableDictionary<NSNumber *, NSDictionary *> *configurations;
@end

@implementation FxGripTagsTestStubEffect

- (id)effectBase
{
	// The stub plays the full effect; rich reads route back to it, as the old cast did.
	return self;
}


- (instancetype)init
{
	self = [super init];
	if (self) {
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

@interface FxGripParameterTagsAPI_v1Tests : XCTestCase
@property (nonatomic, strong) FxGripTagsTestStubEffect *effect;
@property (nonatomic, strong) NSMutableArray<NSString *> *events;
@property (nonatomic, strong) FxGripTagsTestMetaManager *metaManager;
@property (nonatomic, strong) FxGripTagsTestParameterData *parameterData;
@property (nonatomic, strong) FxGripTagsTestSettingAPI *settingAPI;
@property (nonatomic, strong) FxGripTagsTestDynamicAPI *dynamicAPI;
@property (nonatomic, strong) FxGripTagsTestRetrievalAPI *retrievalAPI;
@end

@implementation FxGripParameterTagsAPI_v1Tests

- (void)setUp
{
	[super setUp];
	self.effect = [FxGripTagsTestStubEffect.alloc init];
}

- (void)tearDown
{
	self.effect = nil;
	self.events = nil;
	self.metaManager = nil;
	self.parameterData = nil;
	self.settingAPI = nil;
	self.dynamicAPI = nil;
	self.retrievalAPI = nil;
	[super tearDown];
}

- (FxGripParameterTagsAPI_v1 *)tagsAPI
{
	return [FxGripParameterTagsAPI_v1.alloc initWithAPI:nil effect:(id)self.effect];
}

/*!
	A plist-shaped plugin properties dictionary carrying one presets table entry. The
	NSDictionary(FxGripTileableEffect) accessors resolve only for a dictionary that also carries
	the plugin identity triple, so every entry is present.
*/
- (void)installPresetDefinition:(NSDictionary *)definition forTag:(NSString *)tag
{
	self.effect.pluginProperties = @{
		kProPlugPlugIn_UuidProperty: @"00000000-0000-0000-0000-000000000001",
		kProPlugPlugIn_ClassNameProperty: @"FxGripTagsTestEffect",
		kProPlugPlugIn_GroupUUIDProperty: @"00000000-0000-0000-0000-000000000002",
		kProPlugPlugInX_PresetsProperty: @{tag: definition}
	};
}

/*! Attaches a meta manager holding a record for one parameter and returns that record. */
- (NSMutableDictionary *)installInstanceRecordForParameter:(FxParameterId)parameterID
{
	FxGripMetaManager *manager = [FxGripMetaManager.alloc initWithEffect:nil];
	[manager addParameter:parameterID];
	self.effect.meta = manager;
	self.effect.hasMeta = YES;
	return [manager parameterData:parameterID];
}

#pragma mark presetDefinitionForTag:

- (void)testPresetDefinitionForTagReturnsTheDefinitionFromThePluginPresetsTable
{
	NSDictionary *definition = @{kFxParameterProperty_TargetPresetValues: @{@"1": @2}};
	[self installPresetDefinition:definition forTag:@"warm"];

	XCTAssertEqualObjects([self.tagsAPI presetDefinitionForTag:@"warm"], definition);
}

- (void)testPresetDefinitionForUnknownTagIsNil
{
	[self installPresetDefinition:@{} forTag:@"warm"];

	XCTAssertNil([self.tagsAPI presetDefinitionForTag:@"cool"]);
}

- (void)testPresetDefinitionForNilTagIsNil
{
	[self installPresetDefinition:@{} forTag:@"warm"];

	NSString *absentTag = nil;
	XCTAssertNil([self.tagsAPI presetDefinitionForTag:absentTag]);
}

- (void)testPresetDefinitionIsNilWhenThePluginCarriesNoPresetsTable
{
	XCTAssertNil([self.tagsAPI presetDefinitionForTag:@"warm"]);
}

- (void)testPresetDefinitionIsNilWhenThePropertiesLackThePluginIdentityKeys
{
	self.effect.pluginProperties = @{kProPlugPlugInX_PresetsProperty: @{@"warm": @{}}};

	XCTAssertNil([self.tagsAPI presetDefinitionForTag:@"warm"],
				 @"the presets accessor rejects a dictionary that is not a plugin record");
}

#pragma mark targetPresetForParameter:record:

- (void)testTargetPresetReturnsAnInlineDefinitionFromTheInstanceRecord
{
	NSDictionary *definition = @{kFxParameterProperty_TargetPresetValues: @{@"1": @2}};
	NSMutableDictionary *instanceRecord = [self installInstanceRecordForParameter:kTagsTestParam];
	instanceRecord[kFxParameterProperty_TargetPreset] = definition;

	NSDictionary *record = nil;
	id resolved = [self.tagsAPI targetPresetForParameter:kTagsTestParam record:&record];

	XCTAssertEqualObjects(resolved, definition);
	XCTAssertTrue(record == instanceRecord, @"the record out-param names the source of the definition");
}

- (void)testTargetPresetResolvesAStringDefinitionThroughThePluginPresetsTable
{
	NSDictionary *definition = @{kFxParameterProperty_TargetPresetValues: @{@"1": @2}};
	[self installPresetDefinition:definition forTag:@"warm"];
	NSMutableDictionary *instanceRecord = [self installInstanceRecordForParameter:kTagsTestParam];
	instanceRecord[kFxParameterProperty_TargetPreset] = @"warm";

	NSDictionary *record = nil;
	id resolved = [self.tagsAPI targetPresetForParameter:kTagsTestParam record:&record];

	XCTAssertEqualObjects(resolved, definition);
	XCTAssertTrue(record == instanceRecord);
}

- (void)testTargetPresetPrefersTheInstanceRecordOverTheConfiguration
{
	NSDictionary *instanceDefinition = @{kFxParameterProperty_TargetPresetValues: @{@"1": @"instance"}};
	NSDictionary *configurationDefinition = @{kFxParameterProperty_TargetPresetValues: @{@"1": @"configuration"}};

	NSMutableDictionary *instanceRecord = [self installInstanceRecordForParameter:kTagsTestParam];
	instanceRecord[kFxParameterProperty_TargetPreset] = instanceDefinition;
	self.effect.configurations[@(kTagsTestParam)] = @{
		kFxParameterProperty_Id: @(kTagsTestParam),
		kFxParameterProperty_Type: kFxParameterType_Float,
		kFxParameterProperty_Name: @"Test Parameter",
		kFxParameterProperty_TargetPreset: configurationDefinition
	};

	NSDictionary *record = nil;
	id resolved = [self.tagsAPI targetPresetForParameter:kTagsTestParam record:&record];

	XCTAssertEqualObjects(resolved, instanceDefinition, @"the per-instance override wins");
	XCTAssertTrue(record == instanceRecord);
}

- (void)testTargetPresetFallsBackToTheConfigurationWhenNoInstanceRecordExists
{
	NSDictionary *definition = @{kFxParameterProperty_TargetPresetValues: @{@"1": @2}};
	NSDictionary *configuration = @{
		kFxParameterProperty_Id: @(kTagsTestParam),
		kFxParameterProperty_Type: kFxParameterType_Float,
		kFxParameterProperty_Name: @"Test Parameter",
		kFxParameterProperty_TargetPreset: definition
	};
	self.effect.configurations[@(kTagsTestParam)] = configuration;

	NSDictionary *record = nil;
	id resolved = [self.tagsAPI targetPresetForParameter:kTagsTestParam record:&record];

	XCTAssertEqualObjects(resolved, definition);
	XCTAssertTrue(record == configuration);
}

- (void)testTargetPresetFallsBackToTheConfigurationForAParameterTheManagerDoesNotHold
{
	NSDictionary *definition = @{kFxParameterProperty_TargetPresetValues: @{@"1": @2}};
	[self installInstanceRecordForParameter:kTagsTestOtherParam];
	self.effect.configurations[@(kTagsTestParam)] = @{kFxParameterProperty_TargetPreset: definition};

	NSDictionary *record = nil;
	id resolved = [self.tagsAPI targetPresetForParameter:kTagsTestParam record:&record];

	XCTAssertEqualObjects(resolved, definition);
}

- (void)testTargetPresetIsNilWhenNeitherSourceHoldsARecord
{
	NSDictionary *record = nil;
	id resolved = [self.tagsAPI targetPresetForParameter:kTagsTestParam record:&record];

	XCTAssertNil(resolved);
	XCTAssertNil(record, @"no source means no record to report");
}

- (void)testTargetPresetIsNilWhenTheStringTagMatchesNoPluginPreset
{
	[self installPresetDefinition:@{} forTag:@"warm"];
	NSMutableDictionary *instanceRecord = [self installInstanceRecordForParameter:kTagsTestParam];
	instanceRecord[kFxParameterProperty_TargetPreset] = @"missing";

	NSDictionary *record = nil;
	id resolved = [self.tagsAPI targetPresetForParameter:kTagsTestParam record:&record];

	XCTAssertNil(resolved);
	XCTAssertTrue(record == instanceRecord, @"the record is reported even when the tag resolves to nothing");
}

- (void)testTargetPresetIsNilWhenTheRecordNamesNoTargetPreset
{
	[self installInstanceRecordForParameter:kTagsTestParam];

	NSDictionary *record = nil;
	XCTAssertNil([self.tagsAPI targetPresetForParameter:kTagsTestParam record:&record]);
}

- (void)testTargetPresetAcceptsANullRecordOutParameter
{
	NSDictionary *definition = @{kFxParameterProperty_TargetPresetValues: @{@"1": @2}};
	NSMutableDictionary *instanceRecord = [self installInstanceRecordForParameter:kTagsTestParam];
	instanceRecord[kFxParameterProperty_TargetPreset] = definition;

	XCTAssertEqualObjects([self.tagsAPI targetPresetForParameter:kTagsTestParam record:NULL], definition);
	XCTAssertNil([self.tagsAPI targetPresetForParameter:kTagsTestOtherParam record:NULL]);
}

#pragma mark applyPreset: harness

/*!
	Attaches the recording collaborators the five sections write through: a real meta
	manager holding a record for each named parameter, the stored-flags source, the
	setting APIs, and the dynamic API. Every side effect appends to one events array, so
	the order across sections is observable.
*/
- (void)installApplyEnvironmentForParameters:(NSArray<NSNumber *> *)parameterIDs
{
	self.events = NSMutableArray.new;

	FxGripTagsTestMetaManager *manager = [FxGripTagsTestMetaManager.alloc initWithEffect:nil];
	manager.events = self.events;
	for (NSNumber *parameterID in parameterIDs) {
		[manager addParameter:parameterID.unsignedIntValue];
	}
	self.metaManager = manager;
	self.effect.meta = manager;
	self.effect.hasMeta = YES;

	self.parameterData = FxGripTagsTestParameterData.new;
	self.effect.parameterData = self.parameterData;

	self.settingAPI = FxGripTagsTestSettingAPI.new;
	self.settingAPI.events = self.events;
	self.dynamicAPI = FxGripTagsTestDynamicAPI.new;
	self.dynamicAPI.events = self.events;
	self.retrievalAPI = FxGripTagsTestRetrievalAPI.new;

	FxGripTagsTestAPIManager *apiManager = FxGripTagsTestAPIManager.new;
	apiManager.settingAPI = self.settingAPI;
	apiManager.dynamicAPI = self.dynamicAPI;
	apiManager.retrievalAPI = self.retrievalAPI;
	self.effect.apiManager = apiManager;
}

/*! Tags a parameter as setup; the write is not part of the apply call under test. */
- (void)installTag:(NSString *)tag onParameter:(FxParameterId)parameterID
{
	[self.metaManager addTag:tag toParameter:parameterID];
	[self.events removeAllObjects];
}

/*! A definition naming all five sections for each key, in whichever key form is given. */
- (NSDictionary *)allSectionsPresetKeyedBy:(NSArray *)keys
{
	NSMutableDictionary *values = NSMutableDictionary.new;
	NSMutableDictionary *flags = NSMutableDictionary.new;
	NSMutableDictionary *tags = NSMutableDictionary.new;
	NSMutableDictionary *meta = NSMutableDictionary.new;
	NSMutableDictionary *names = NSMutableDictionary.new;

	for (id key in keys) {
		values[key] = @0.5;
		flags[key] = kParameterFlagString_HIDDEN;
		tags[key] = @"warm";
		meta[key] = @{@"role": @"primary"};
		names[key] = @"Renamed";
	}
	return @{
		kFxParameterProperty_TargetPresetValues: values,
		kFxParameterProperty_TargetPresetFlags: flags,
		kFxParameterProperty_TargetPresetTags: tags,
		kFxParameterProperty_TargetPresetMeta: meta,
		kFxParameterProperty_TargetPresetNames: names
	};
}

- (NSDictionary *)allSectionsPresetForParameter:(FxParameterId)parameterID
{
	return [self allSectionsPresetKeyedBy:@[@(parameterID).stringValue]];
}

/*! Applies from the plugin with no tag, so no boundary narrows the sections. */
- (NSError *)applyDefinition:(NSDictionary *)preset options:(FxGripPresetOptions)options
{
	return [self.tagsAPI applyPreset:preset
							  atTime:FxGripTagsTestTime()
							 options:options
						 presetFlags:0
							  source:FxGripPresetSourcePlugin
								 tag:nil];
}

/*! The section each recorded side effect came from, in order. */
- (NSArray<NSString *> *)recordedSections
{
	NSMutableArray<NSString *> *sections = NSMutableArray.new;
	for (NSString *event in self.events) {
		[sections addObject:[event componentsSeparatedByString:@":"].firstObject];
	}
	return sections;
}

- (NSArray<NSString *> *)allSectionsInOrder
{
	return @[kFxParameterProperty_TargetPresetValues,
			 kFxParameterProperty_TargetPresetFlags,
			 kFxParameterProperty_TargetPresetTags,
			 kFxParameterProperty_TargetPresetMeta,
			 kFxParameterProperty_TargetPresetNames];
}

#pragma mark applyPreset: section order

- (void)testApplyPresetRunsTheSectionsInValuesFlagsTagsMetaNamesOrder
{
	[self installApplyEnvironmentForParameters:@[@(kTagsTestParam)]];

	NSError *error = [self applyDefinition:[self allSectionsPresetForParameter:kTagsTestParam]
								   options:FxGripPresetAll];

	XCTAssertNil(error);
	XCTAssertEqualObjects(self.recordedSections, self.allSectionsInOrder,
						  @"names run last: the host misreports string parameters otherwise");
}

#pragma mark applyPreset: option gating

- (void)testApplyPresetValuesOptionRunsOnlyTheValuesSection
{
	[self installApplyEnvironmentForParameters:@[@(kTagsTestParam)]];

	[self applyDefinition:[self allSectionsPresetForParameter:kTagsTestParam] options:FxGripPresetValues];

	XCTAssertEqualObjects(self.recordedSections, @[kFxParameterProperty_TargetPresetValues]);
}

- (void)testApplyPresetFlagsOptionRunsOnlyTheFlagsSection
{
	[self installApplyEnvironmentForParameters:@[@(kTagsTestParam)]];

	[self applyDefinition:[self allSectionsPresetForParameter:kTagsTestParam] options:FxGripPresetFlags];

	XCTAssertEqualObjects(self.recordedSections, @[kFxParameterProperty_TargetPresetFlags]);
}

- (void)testApplyPresetTagsOptionRunsOnlyTheTagsSection
{
	[self installApplyEnvironmentForParameters:@[@(kTagsTestParam)]];

	[self applyDefinition:[self allSectionsPresetForParameter:kTagsTestParam] options:FxGripPresetTags];

	XCTAssertEqualObjects(self.recordedSections, @[kFxParameterProperty_TargetPresetTags]);
}

- (void)testApplyPresetMetaOptionRunsOnlyTheMetaSection
{
	[self installApplyEnvironmentForParameters:@[@(kTagsTestParam)]];

	[self applyDefinition:[self allSectionsPresetForParameter:kTagsTestParam] options:FxGripPresetMeta];

	XCTAssertEqualObjects(self.recordedSections, @[kFxParameterProperty_TargetPresetMeta]);
}

- (void)testApplyPresetNamesOptionRunsOnlyTheNamesSection
{
	[self installApplyEnvironmentForParameters:@[@(kTagsTestParam)]];

	[self applyDefinition:[self allSectionsPresetForParameter:kTagsTestParam] options:FxGripPresetNames];

	XCTAssertEqualObjects(self.recordedSections, @[kFxParameterProperty_TargetPresetNames]);
}

- (void)testApplyPresetAllOptionRunsEverySection
{
	[self installApplyEnvironmentForParameters:@[@(kTagsTestParam)]];

	[self applyDefinition:[self allSectionsPresetForParameter:kTagsTestParam] options:FxGripPresetAll];

	XCTAssertEqualObjects(self.recordedSections, self.allSectionsInOrder);
}

#pragma mark applyPreset: section key normalization

- (void)testApplyPresetResolvesSectionKeysWrittenAsStrings
{
	[self installApplyEnvironmentForParameters:@[@(kTagsTestParam)]];

	[self applyDefinition:[self allSectionsPresetKeyedBy:@[@(kTagsTestParam).stringValue]]
				  options:FxGripPresetAll];

	XCTAssertEqualObjects(self.recordedSections, self.allSectionsInOrder);
	XCTAssertEqualObjects(self.settingAPI.values[@(kTagsTestParam)], @0.5);
	XCTAssertEqualObjects(self.dynamicAPI.names[@(kTagsTestParam)], @"Renamed");
}

- (void)testApplyPresetResolvesSectionKeysWrittenAsNumbers
{
	[self installApplyEnvironmentForParameters:@[@(kTagsTestParam)]];

	[self applyDefinition:[self allSectionsPresetKeyedBy:@[@(kTagsTestParam)]] options:FxGripPresetAll];

	XCTAssertEqualObjects(self.recordedSections, self.allSectionsInOrder);
	XCTAssertEqualObjects(self.settingAPI.values[@(kTagsTestParam)], @0.5);
	XCTAssertEqualObjects(self.dynamicAPI.names[@(kTagsTestParam)], @"Renamed");
}

#pragma mark applyPreset: tag boundary

- (void)testApplyPresetFromThePluginTouchesEveryNamedParameterWithoutTheTag
{
	[self installApplyEnvironmentForParameters:@[@(kTagsTestParam)]];

	[self.tagsAPI applyPreset:[self allSectionsPresetForParameter:kTagsTestParam]
					   atTime:FxGripTagsTestTime()
					  options:FxGripPresetAll
				  presetFlags:0
					   source:FxGripPresetSourcePlugin
						  tag:@"bounded"];

	XCTAssertEqualObjects(self.recordedSections, self.allSectionsInOrder,
						  @"a plugin definition names IDs that are current by construction");
}

- (void)testApplyPresetFromAFileAppliesEverySectionOnlyToParametersCarryingTheTag
{
	[self installApplyEnvironmentForParameters:@[@(kTagsTestParam), @(kTagsTestOtherParam)]];
	[self installTag:@"bounded" onParameter:kTagsTestParam];

	[self.tagsAPI applyPreset:[self allSectionsPresetKeyedBy:@[@(kTagsTestParam).stringValue,
															   @(kTagsTestOtherParam).stringValue]]
					   atTime:FxGripTagsTestTime()
					  options:FxGripPresetAll
				  presetFlags:0
					   source:FxGripPresetSourceFile
						  tag:@"bounded"];

	NSMutableArray<NSString *> *expected = NSMutableArray.new;
	for (NSString *section in self.allSectionsInOrder) {
		[expected addObject:FxGripTagsTestEvent(section, kTagsTestParam)];
	}
	XCTAssertEqualObjects(self.events, expected, @"the boundary filters all five sections");
}

- (void)testApplyPresetFromAFileIgnoresTheBoundaryWhenThePresetFlagsRequestIt
{
	[self installApplyEnvironmentForParameters:@[@(kTagsTestParam)]];

	[self.tagsAPI applyPreset:[self allSectionsPresetForParameter:kTagsTestParam]
					   atTime:FxGripTagsTestTime()
					  options:FxGripPresetAll
				  presetFlags:kTagsTestIgnoreTagBoundary
					   source:FxGripPresetSourceFile
						  tag:@"bounded"];

	XCTAssertEqualObjects(self.recordedSections, self.allSectionsInOrder);
}

- (void)testApplyPresetFromAFileWithoutATagAppliesToEveryNamedParameter
{
	[self installApplyEnvironmentForParameters:@[@(kTagsTestParam), @(kTagsTestOtherParam)]];

	[self.tagsAPI applyPreset:[self allSectionsPresetKeyedBy:@[@(kTagsTestParam).stringValue,
															   @(kTagsTestOtherParam).stringValue]]
					   atTime:FxGripTagsTestTime()
					  options:FxGripPresetAll
				  presetFlags:0
					   source:FxGripPresetSourceFile
						  tag:nil];

	for (NSString *section in self.allSectionsInOrder) {
		XCTAssertTrue([self.events containsObject:FxGripTagsTestEvent(section, kTagsTestParam)]);
		XCTAssertTrue([self.events containsObject:FxGripTagsTestEvent(section, kTagsTestOtherParam)]);
	}
}

#pragma mark applyPreset: values section

- (void)testApplyPresetValuesSectionWritesTheEncodedValueAtTheSuppliedTime
{
	[self installApplyEnvironmentForParameters:@[@(kTagsTestParam)]];
	NSDictionary *preset = @{kFxParameterProperty_TargetPresetValues:
								 @{@(kTagsTestParam).stringValue: @0.25}};

	[self applyDefinition:preset options:FxGripPresetValues];

	XCTAssertEqualObjects(self.settingAPI.values[@(kTagsTestParam)], @0.25);
	XCTAssertTrue(FxGripTagsTestTimesEqual(self.settingAPI.lastValueTime, FxGripTagsTestTime()));
}

#pragma mark applyPreset: flags section

- (void)testApplyPresetFlagsSectionAddsAndRemovesAgainstTheStoredFlags
{
	[self installApplyEnvironmentForParameters:@[@(kTagsTestParam)]];
	self.parameterData.flagsByParameter[@(kTagsTestParam)] =
		@(kFxParameterFlag_HIDDEN | kFxParameterFlag_DISABLED);
	NSString *spec = [NSString stringWithFormat:@"+%@ -%@",
					  kParameterFlagString_COLLAPSED, kParameterFlagString_HIDDEN];
	NSDictionary *preset = @{kFxParameterProperty_TargetPresetFlags:
								 @{@(kTagsTestParam).stringValue: spec}};

	[self applyDefinition:preset options:FxGripPresetFlags];

	XCTAssertEqualObjects(self.settingAPI.flags[@(kTagsTestParam)],
						  @(kFxParameterFlag_DISABLED | kFxParameterFlag_COLLAPSED));
}

- (void)testApplyPresetFlagsSectionAcceptsAFlagSpecArray
{
	[self installApplyEnvironmentForParameters:@[@(kTagsTestParam)]];
	self.parameterData.flagsByParameter[@(kTagsTestParam)] =
		@(kFxParameterFlag_HIDDEN | kFxParameterFlag_DISABLED);
	NSArray *spec = @[[@"+" stringByAppendingString:kParameterFlagString_COLLAPSED],
					  [@"-" stringByAppendingString:kParameterFlagString_HIDDEN]];
	NSDictionary *preset = @{kFxParameterProperty_TargetPresetFlags:
								 @{@(kTagsTestParam).stringValue: spec}};

	[self applyDefinition:preset options:FxGripPresetFlags];

	XCTAssertEqualObjects(self.settingAPI.flags[@(kTagsTestParam)],
						  @(kFxParameterFlag_DISABLED | kFxParameterFlag_COLLAPSED));
}

- (void)testApplyPresetFlagsSectionTreatsABareNameAsAnAddition
{
	[self installApplyEnvironmentForParameters:@[@(kTagsTestParam)]];
	NSDictionary *preset = @{kFxParameterProperty_TargetPresetFlags:
								 @{@(kTagsTestParam).stringValue: kParameterFlagString_HIDDEN}};

	[self applyDefinition:preset options:FxGripPresetFlags];

	XCTAssertEqualObjects(self.settingAPI.flags[@(kTagsTestParam)], @(kFxParameterFlag_HIDDEN));
}

- (void)testApplyPresetFlagsSectionSkipsTheWriteWhenTheResultMatchesTheStoredFlags
{
	[self installApplyEnvironmentForParameters:@[@(kTagsTestParam)]];
	self.parameterData.flagsByParameter[@(kTagsTestParam)] = @(kFxParameterFlag_HIDDEN);
	NSDictionary *preset = @{kFxParameterProperty_TargetPresetFlags:
								 @{@(kTagsTestParam).stringValue: kParameterFlagString_HIDDEN}};

	[self applyDefinition:preset options:FxGripPresetFlags];

	XCTAssertEqualObjects(self.events, @[], @"an unchanged result writes nothing");
}

- (void)testApplyPresetFlagsSectionIgnoresUnknownFlagNames
{
	[self installApplyEnvironmentForParameters:@[@(kTagsTestParam)]];
	self.parameterData.flagsByParameter[@(kTagsTestParam)] = @(kFxParameterFlag_HIDDEN);
	NSDictionary *unknownOnly = @{kFxParameterProperty_TargetPresetFlags:
									  @{@(kTagsTestParam).stringValue: @"notaflag"}};

	[self applyDefinition:unknownOnly options:FxGripPresetFlags];

	XCTAssertEqualObjects(self.events, @[], @"an unknown name contributes no bits");

	NSString *spec = [NSString stringWithFormat:@"notaflag +%@", kParameterFlagString_COLLAPSED];
	NSDictionary *mixed = @{kFxParameterProperty_TargetPresetFlags:
								@{@(kTagsTestParam).stringValue: spec}};

	[self applyDefinition:mixed options:FxGripPresetFlags];

	XCTAssertEqualObjects(self.settingAPI.flags[@(kTagsTestParam)],
						  @(kFxParameterFlag_HIDDEN | kFxParameterFlag_COLLAPSED));
}

#pragma mark applyPreset: tags section

- (void)testApplyPresetTagsSectionAddsAndRemovesTagsThroughTheMetaManager
{
	[self installApplyEnvironmentForParameters:@[@(kTagsTestParam)]];
	[self installTag:@"beta" onParameter:kTagsTestParam];
	NSDictionary *preset = @{kFxParameterProperty_TargetPresetTags:
								 @{@(kTagsTestParam).stringValue: @"+alpha -beta gamma"}};

	NSError *error = [self applyDefinition:preset options:FxGripPresetTags];

	XCTAssertNil(error);
	NSArray *tags = [[self.metaManager parameterTags:kTagsTestParam]
					 sortedArrayUsingSelector:@selector(compare:)];
	XCTAssertEqualObjects(tags, (@[@"alpha", @"gamma"]));
}

- (void)testApplyPresetTagsSectionAcceptsATagSpecArray
{
	[self installApplyEnvironmentForParameters:@[@(kTagsTestParam)]];
	[self installTag:@"beta" onParameter:kTagsTestParam];
	NSDictionary *preset = @{kFxParameterProperty_TargetPresetTags:
								 @{@(kTagsTestParam).stringValue: @[@"+alpha", @"-beta"]}};

	[self applyDefinition:preset options:FxGripPresetTags];

	XCTAssertEqualObjects([self.metaManager parameterTags:kTagsTestParam], @[@"alpha"]);
}

- (void)testApplyPresetTagsSectionSkipsParametersFlaggedPresetNoTags
{
	[self installApplyEnvironmentForParameters:@[@(kTagsTestParam)]];
	self.parameterData.flagsByParameter[@(kTagsTestParam)] = @(kFxParameterFlag_PRESETNOTAGS);
	NSDictionary *preset = @{kFxParameterProperty_TargetPresetTags:
								 @{@(kTagsTestParam).stringValue: @"warm"}};

	[self applyDefinition:preset options:FxGripPresetTags];

	XCTAssertEqualObjects(self.events, @[]);
	XCTAssertEqualObjects([self.metaManager parameterTags:kTagsTestParam], @[]);
}

#pragma mark applyPreset: meta section

- (void)testApplyPresetMetaSectionSetsEachEntryOnTheMetaManager
{
	[self installApplyEnvironmentForParameters:@[@(kTagsTestParam)]];
	NSDictionary *preset = @{kFxParameterProperty_TargetPresetMeta:
								 @{@(kTagsTestParam).stringValue: @{@"role": @"primary", @"order": @3}}};

	NSError *error = [self applyDefinition:preset options:FxGripPresetMeta];

	XCTAssertNil(error);
	NSDictionary *meta = nil;
	XCTAssertNil([self.metaManager getMeta:&meta fromParameter:kTagsTestParam]);
	XCTAssertEqualObjects(meta, (@{@"role": @"primary", @"order": @3}));
}

- (void)testApplyPresetMetaSectionSkipsParametersFlaggedPresetNoMeta
{
	[self installApplyEnvironmentForParameters:@[@(kTagsTestParam)]];
	self.parameterData.flagsByParameter[@(kTagsTestParam)] = @(kFxParameterFlag_PRESETNOMETA);
	NSDictionary *preset = @{kFxParameterProperty_TargetPresetMeta:
								 @{@(kTagsTestParam).stringValue: @{@"role": @"primary"}}};

	[self applyDefinition:preset options:FxGripPresetMeta];

	XCTAssertEqualObjects(self.events, @[]);
	NSDictionary *meta = nil;
	[self.metaManager getMeta:&meta fromParameter:kTagsTestParam];
	XCTAssertEqualObjects(meta, @{});
}

#pragma mark applyPreset: names section

- (void)testApplyPresetNamesSectionRenamesThroughTheDynamicAPI
{
	[self installApplyEnvironmentForParameters:@[@(kTagsTestParam)]];
	NSDictionary *preset = @{kFxParameterProperty_TargetPresetNames:
								 @{@(kTagsTestParam).stringValue: @"Renamed"}};

	NSError *error = [self applyDefinition:preset options:FxGripPresetNames];

	XCTAssertNil(error);
	XCTAssertEqualObjects(self.dynamicAPI.names[@(kTagsTestParam)], @"Renamed");
}

#pragma mark applyPreset: error contract

- (void)testApplyPresetContinuesPastAFailedEntryAndReturnsTheFirstError
{
	[self installApplyEnvironmentForParameters:@[@(kTagsTestParam), @(kTagsTestOtherParam)]];
	[self.settingAPI.failingValueParameters addObject:@(kTagsTestParam)];
	[self.dynamicAPI.failingParameters addObject:@(kTagsTestOtherParam)];
	NSDictionary *preset = @{
		kFxParameterProperty_TargetPresetValues: @{@(kTagsTestParam).stringValue: @0.5,
												   @(kTagsTestOtherParam).stringValue: @0.75},
		kFxParameterProperty_TargetPresetNames: @{@(kTagsTestOtherParam).stringValue: @"Renamed"}
	};

	NSError *error = [self applyDefinition:preset options:FxGripPresetAll];

	XCTAssertEqual(error.code, kFxError_ThirdPartyDeveloperStart + kTagsTestParam,
				   @"the first error comes from the earliest failing entry");
	XCTAssertEqualObjects(self.settingAPI.values[@(kTagsTestOtherParam)], @0.75,
						  @"the section continues past the failure");
	XCTAssertTrue([self.events containsObject:
				   FxGripTagsTestEvent(kFxParameterProperty_TargetPresetNames, kTagsTestOtherParam)],
				  @"the later sections still run");
}

- (void)testApplyPresetReturnsNilWhenEveryEntrySucceeds
{
	[self installApplyEnvironmentForParameters:@[@(kTagsTestParam)]];

	XCTAssertNil([self applyDefinition:[self allSectionsPresetForParameter:kTagsTestParam]
							   options:FxGripPresetAll]);
}

- (void)testApplyPresetIgnoresAPresetThatIsNotADictionary
{
	[self installApplyEnvironmentForParameters:@[@(kTagsTestParam)]];

	NSError *error = [self applyDefinition:(NSDictionary *)@"not a preset" options:FxGripPresetAll];

	XCTAssertNil(error);
	XCTAssertEqualObjects(self.events, @[]);
}

#pragma mark getMetaKeys:forPreset:fromParameter:

- (void)testGetMetaKeysReturnsTheDefinitionsMetaKeysForTheParameter
{
	[self installPresetDefinition:@{kFxParameterProperty_TargetPresetMeta:
										@{@(kTagsTestParam).stringValue: @{@"role": @"primary",
																		   @"order": @3}}}
						   forTag:@"warm"];

	NSArray<NSString *> *keys = nil;
	NSError *error = [self.tagsAPI getMetaKeys:&keys forPreset:@"warm" fromParameter:kTagsTestParam];

	XCTAssertNil(error);
	XCTAssertEqualObjects([keys sortedArrayUsingSelector:@selector(compare:)], (@[@"order", @"role"]));
}

- (void)testGetMetaKeysIsEmptyWhenTheDefinitionCarriesNoMetaSection
{
	[self installPresetDefinition:@{kFxParameterProperty_TargetPresetValues:
										@{@(kTagsTestParam).stringValue: @2}}
						   forTag:@"warm"];

	NSArray<NSString *> *keys = nil;
	NSError *error = [self.tagsAPI getMetaKeys:&keys forPreset:@"warm" fromParameter:kTagsTestParam];

	XCTAssertNil(error);
	XCTAssertEqualObjects(keys, @[]);
}

- (void)testGetMetaKeysIsEmptyWhenTheMetaSectionHasNoEntryForTheParameter
{
	[self installPresetDefinition:@{kFxParameterProperty_TargetPresetMeta:
										@{@(kTagsTestOtherParam).stringValue: @{@"role": @"primary"}}}
						   forTag:@"warm"];

	NSArray<NSString *> *keys = nil;
	NSError *error = [self.tagsAPI getMetaKeys:&keys forPreset:@"warm" fromParameter:kTagsTestParam];

	XCTAssertNil(error);
	XCTAssertEqualObjects(keys, @[]);
}

- (void)testGetMetaKeysErrorsWhenNoKeysOutParameterIsSupplied
{
	[self installPresetDefinition:@{kFxParameterProperty_TargetPresetMeta:
										@{@(kTagsTestParam).stringValue: @{@"role": @"primary"}}}
						   forTag:@"warm"];

	XCTAssertNotNil([self.tagsAPI getMetaKeys:(NSArray<NSString*>* _Nullable __autoreleasing * _Nonnull)NULL forPreset:@"warm" fromParameter:kTagsTestParam]);
}

- (void)testGetMetaKeysErrorsWhenTheTagResolvesToNoDefinition
{
	[self installPresetDefinition:@{} forTag:@"warm"];

	NSArray<NSString *> *keys = nil;
	NSError *error = [self.tagsAPI getMetaKeys:&keys forPreset:@"cool" fromParameter:kTagsTestParam];

	XCTAssertNotNil(error);
	XCTAssertNil(keys);
}

#pragma mark applyTargetPresetForParameter:atTime:options: harness

/*!
	Registers the changed parameter's configuration, which supplies the type the trigger
	branches on, and installs its target-preset definition in the instance record.
*/
- (void)installTargetPresetDefinition:(id)definition ofType:(NSString *)type
{
	self.effect.configurations[@(kTagsTestParam)] = @{
		kFxParameterProperty_Id: @(kTagsTestParam),
		kFxParameterProperty_Type: type,
		kFxParameterProperty_Name: @"Test Parameter"
	};
	if (definition) {
		[self.metaManager parameterData:kTagsTestParam][kFxParameterProperty_TargetPreset] = definition;
	}
}

- (BOOL)applyTargetPresetForParameter:(FxParameterId)parameterID options:(FxGripPresetOptions)options
{
	return [self.tagsAPI applyTargetPresetForParameter:parameterID
												atTime:FxGripTagsTestTime()
											   options:options];
}

/*! Two entries a Menu or Toggle value indexes, each renaming the parameter distinctly. */
- (NSArray *)twoEntryDefinition
{
	return @[FxGripTagsTestNamesEntry(kTagsTestParam, @"Zero"),
			 FxGripTagsTestNamesEntry(kTagsTestParam, @"One")];
}

#pragma mark applyTargetPresetForParameter: gating

- (void)testApplyTargetPresetReturnsNOWhenNeitherSourceHoldsARecord
{
	[self installApplyEnvironmentForParameters:@[@(kTagsTestParam)]];

	XCTAssertFalse([self applyTargetPresetForParameter:kTagsTestOtherParam options:FxGripPresetAll]);
	XCTAssertEqualObjects(self.events, @[]);
}

- (void)testApplyTargetPresetLeavesAParameterThatIsNeitherMenuNorToggleUntouched
{
	[self installApplyEnvironmentForParameters:@[@(kTagsTestParam)]];
	[self installTargetPresetDefinition:self.twoEntryDefinition ofType:kFxParameterType_Float];

	XCTAssertTrue([self applyTargetPresetForParameter:kTagsTestParam options:FxGripPresetAll],
				  @"only Menu and Toggle parameters select a target preset");
	XCTAssertEqualObjects(self.events, @[]);
	XCTAssertEqualObjects(self.retrievalAPI.requestedParameters, @[],
						  @"the type check precedes the value read");
}

- (void)testApplyTargetPresetReturnsNOWhenTheMenuValueCannotBeRead
{
	[self installApplyEnvironmentForParameters:@[@(kTagsTestParam)]];
	[self installTargetPresetDefinition:self.twoEntryDefinition ofType:kFxParameterType_Menu];
	self.retrievalAPI.succeeds = NO;

	XCTAssertFalse([self applyTargetPresetForParameter:kTagsTestParam options:FxGripPresetAll]);
	XCTAssertEqualObjects(self.events, @[]);
}

- (void)testApplyTargetPresetReturnsNOWhenTheToggleValueCannotBeRead
{
	[self installApplyEnvironmentForParameters:@[@(kTagsTestParam)]];
	[self installTargetPresetDefinition:self.twoEntryDefinition ofType:kFxParameterType_Toggle];
	self.retrievalAPI.succeeds = NO;

	XCTAssertFalse([self applyTargetPresetForParameter:kTagsTestParam options:FxGripPresetAll]);
	XCTAssertEqualObjects(self.events, @[]);
}

- (void)testApplyTargetPresetReturnsYESWhenTheRecordNamesNoDefinition
{
	[self installApplyEnvironmentForParameters:@[@(kTagsTestParam)]];
	[self installTargetPresetDefinition:nil ofType:kFxParameterType_Menu];

	XCTAssertTrue([self applyTargetPresetForParameter:kTagsTestParam options:FxGripPresetAll]);
	XCTAssertEqualObjects(self.events, @[]);
	XCTAssertEqualObjects(self.retrievalAPI.requestedParameters, @[@(kTagsTestParam)],
						  @"the value read precedes the definition check");
}

- (void)testApplyTargetPresetReturnsYESWhenTheSelectedEntryIsNotADictionary
{
	[self installApplyEnvironmentForParameters:@[@(kTagsTestParam)]];
	[self installTargetPresetDefinition:@[@"not a preset"] ofType:kFxParameterType_Menu];
	self.retrievalAPI.intValue = 0;

	XCTAssertTrue([self applyTargetPresetForParameter:kTagsTestParam options:FxGripPresetAll]);
	XCTAssertEqualObjects(self.events, @[]);
}

#pragma mark applyTargetPresetForParameter: index resolution

- (void)testApplyTargetPresetAppliesTheArrayEntryTheMenuValueIndexes
{
	[self installApplyEnvironmentForParameters:@[@(kTagsTestParam)]];
	[self installTargetPresetDefinition:self.twoEntryDefinition ofType:kFxParameterType_Menu];
	self.retrievalAPI.intValue = 1;

	XCTAssertTrue([self applyTargetPresetForParameter:kTagsTestParam options:FxGripPresetAll]);
	XCTAssertEqualObjects(self.dynamicAPI.names[@(kTagsTestParam)], @"One");
}

#pragma mark Name-keyed definitions

// A name-keyed definition survives entries moving, because the reference does not depend
// on position.
- (void)testApplyTargetPresetResolvesADefinitionByMenuEntryName
{
	[self installApplyEnvironmentForParameters:@[@(kTagsTestParam)]];
	[self installTargetPresetDefinition:@{@"Advanced": FxGripTagsTestNamesEntry(kTagsTestParam, @"ByName")}
								 ofType:kFxParameterType_Menu];
	self.parameterData.menusByParameter[@(kTagsTestParam)] = @[@"Basic", @"Advanced"];
	self.retrievalAPI.intValue = 1;

	XCTAssertTrue([self applyTargetPresetForParameter:kTagsTestParam options:FxGripPresetAll]);
	XCTAssertEqualObjects(self.dynamicAPI.names[@(kTagsTestParam)], @"ByName");
}

- (void)testANameKeyedDefinitionFollowsTheEntryWhenEntriesAreAppendedBefore
{
	[self installApplyEnvironmentForParameters:@[@(kTagsTestParam)]];
	[self installTargetPresetDefinition:@{@"Advanced": FxGripTagsTestNamesEntry(kTagsTestParam, @"ByName")}
								 ofType:kFxParameterType_Menu];
	// "Advanced" moved to index 2 by an inserted entry; the name still resolves it.
	self.parameterData.menusByParameter[@(kTagsTestParam)] = @[@"Basic", @"Custom", @"Advanced"];
	self.retrievalAPI.intValue = 2;

	XCTAssertTrue([self applyTargetPresetForParameter:kTagsTestParam options:FxGripPresetAll]);
	XCTAssertEqualObjects(self.dynamicAPI.names[@(kTagsTestParam)], @"ByName");
}

- (void)testANameKeyedDefinitionTakesPrecedenceOverTheIndexEntry
{
	[self installApplyEnvironmentForParameters:@[@(kTagsTestParam)]];
	[self installTargetPresetDefinition:@{@"Advanced": FxGripTagsTestNamesEntry(kTagsTestParam, @"ByName"),
										  @1: FxGripTagsTestNamesEntry(kTagsTestParam, @"ByIndex")}
								 ofType:kFxParameterType_Menu];
	self.parameterData.menusByParameter[@(kTagsTestParam)] = @[@"Basic", @"Advanced"];
	self.retrievalAPI.intValue = 1;

	XCTAssertTrue([self applyTargetPresetForParameter:kTagsTestParam options:FxGripPresetAll]);
	XCTAssertEqualObjects(self.dynamicAPI.names[@(kTagsTestParam)], @"ByName");
}

// The existing index-keyed shape keeps working when no entry name matches.
- (void)testAnIndexKeyedDefinitionStillResolvesWhenTheNameDoesNotMatch
{
	[self installApplyEnvironmentForParameters:@[@(kTagsTestParam)]];
	[self installTargetPresetDefinition:self.twoEntryDefinition ofType:kFxParameterType_Menu];
	self.parameterData.menusByParameter[@(kTagsTestParam)] = @[@"Basic", @"Advanced"];
	self.retrievalAPI.intValue = 1;

	XCTAssertTrue([self applyTargetPresetForParameter:kTagsTestParam options:FxGripPresetAll]);
	XCTAssertEqualObjects(self.dynamicAPI.names[@(kTagsTestParam)], @"One");
}

- (void)testApplyTargetPresetAppliesNothingWhenTheMenuValueFallsOutsideTheArray
{
	[self installApplyEnvironmentForParameters:@[@(kTagsTestParam)]];
	[self installTargetPresetDefinition:self.twoEntryDefinition ofType:kFxParameterType_Menu];

	self.retrievalAPI.intValue = 5;
	XCTAssertTrue([self applyTargetPresetForParameter:kTagsTestParam options:FxGripPresetAll],
				  @"an index past the end raises nothing and applies nothing");
	XCTAssertEqualObjects(self.events, @[]);

	self.retrievalAPI.intValue = -1;
	XCTAssertTrue([self applyTargetPresetForParameter:kTagsTestParam options:FxGripPresetAll]);
	XCTAssertEqualObjects(self.events, @[]);
}

- (void)testApplyTargetPresetResolvesADictionaryDefinitionByNumberKey
{
	[self installApplyEnvironmentForParameters:@[@(kTagsTestParam)]];
	[self installTargetPresetDefinition:@{@1: FxGripTagsTestNamesEntry(kTagsTestParam, @"One")}
								 ofType:kFxParameterType_Menu];
	self.retrievalAPI.intValue = 1;

	XCTAssertTrue([self applyTargetPresetForParameter:kTagsTestParam options:FxGripPresetAll]);
	XCTAssertEqualObjects(self.dynamicAPI.names[@(kTagsTestParam)], @"One");
}

- (void)testApplyTargetPresetResolvesADictionaryDefinitionByStringKey
{
	[self installApplyEnvironmentForParameters:@[@(kTagsTestParam)]];
	[self installTargetPresetDefinition:@{@"1": FxGripTagsTestNamesEntry(kTagsTestParam, @"One")}
								 ofType:kFxParameterType_Menu];
	self.retrievalAPI.intValue = 1;

	XCTAssertTrue([self applyTargetPresetForParameter:kTagsTestParam options:FxGripPresetAll]);
	XCTAssertEqualObjects(self.dynamicAPI.names[@(kTagsTestParam)], @"One");
}

- (void)testApplyTargetPresetFallsBackToTheDefaultEntryWhenTheIndexIsAbsent
{
	[self installApplyEnvironmentForParameters:@[@(kTagsTestParam)]];
	[self installTargetPresetDefinition:@{@"0": FxGripTagsTestNamesEntry(kTagsTestParam, @"Zero"),
										  kFxParameterProperty_Default:
											  FxGripTagsTestNamesEntry(kTagsTestParam, @"Fallback")}
								 ofType:kFxParameterType_Menu];
	self.retrievalAPI.intValue = 7;

	XCTAssertTrue([self applyTargetPresetForParameter:kTagsTestParam options:FxGripPresetAll]);
	XCTAssertEqualObjects(self.dynamicAPI.names[@(kTagsTestParam)], @"Fallback");
}

- (void)testApplyTargetPresetIndexesTheDefinitionWithZeroForAToggleThatIsOff
{
	[self installApplyEnvironmentForParameters:@[@(kTagsTestParam)]];
	[self installTargetPresetDefinition:self.twoEntryDefinition ofType:kFxParameterType_Toggle];
	self.retrievalAPI.boolValue = NO;

	XCTAssertTrue([self applyTargetPresetForParameter:kTagsTestParam options:FxGripPresetAll]);
	XCTAssertEqualObjects(self.dynamicAPI.names[@(kTagsTestParam)], @"Zero");
}

- (void)testApplyTargetPresetIndexesTheDefinitionWithOneForAToggleThatIsOn
{
	[self installApplyEnvironmentForParameters:@[@(kTagsTestParam)]];
	[self installTargetPresetDefinition:self.twoEntryDefinition ofType:kFxParameterType_Toggle];
	self.retrievalAPI.boolValue = YES;

	XCTAssertTrue([self applyTargetPresetForParameter:kTagsTestParam options:FxGripPresetAll]);
	XCTAssertEqualObjects(self.dynamicAPI.names[@(kTagsTestParam)], @"One");
}

#pragma mark applyTargetPresetForParameter: application

- (void)testApplyTargetPresetAppliesAnInlineDefinitionFromTheInstanceRecord
{
	[self installApplyEnvironmentForParameters:@[@(kTagsTestParam)]];
	[self installTargetPresetDefinition:@[[self allSectionsPresetForParameter:kTagsTestParam]]
								 ofType:kFxParameterType_Menu];

	XCTAssertTrue([self applyTargetPresetForParameter:kTagsTestParam options:FxGripPresetAll]);
	XCTAssertEqualObjects(self.recordedSections, self.allSectionsInOrder,
						  @"an inline definition carries no tag and still applies");
}

- (void)testApplyTargetPresetAppliesADefinitionResolvedThroughThePluginPresetsTable
{
	[self installApplyEnvironmentForParameters:@[@(kTagsTestParam)]];
	[self installPresetDefinition:@{@"1": [self allSectionsPresetForParameter:kTagsTestParam]}
						   forTag:@"warm"];
	[self installTargetPresetDefinition:@"warm" ofType:kFxParameterType_Menu];
	self.retrievalAPI.intValue = 1;

	XCTAssertTrue([self applyTargetPresetForParameter:kTagsTestParam options:FxGripPresetAll]);
	XCTAssertEqualObjects(self.recordedSections, self.allSectionsInOrder,
						  @"the tag the record declared bounds the application, which the plugin source waives");
}

- (void)testApplyTargetPresetForwardsTheOptionsToTheApplication
{
	[self installApplyEnvironmentForParameters:@[@(kTagsTestParam)]];
	[self installTargetPresetDefinition:@[[self allSectionsPresetForParameter:kTagsTestParam]]
								 ofType:kFxParameterType_Menu];

	XCTAssertTrue([self applyTargetPresetForParameter:kTagsTestParam options:FxGripPresetNames]);

	XCTAssertEqualObjects(self.recordedSections, @[kFxParameterProperty_TargetPresetNames]);
	XCTAssertEqualObjects(self.dynamicAPI.names[@(kTagsTestParam)], @"Renamed");
}

- (void)testApplyTargetPresetForwardsTheSuppliedTimeToTheValueReadAndTheValueWrite
{
	[self installApplyEnvironmentForParameters:@[@(kTagsTestParam)]];
	[self installTargetPresetDefinition:@[[self allSectionsPresetForParameter:kTagsTestParam]]
								 ofType:kFxParameterType_Menu];

	XCTAssertTrue([self applyTargetPresetForParameter:kTagsTestParam options:FxGripPresetValues]);

	XCTAssertTrue(FxGripTagsTestTimesEqual(self.retrievalAPI.lastTime, FxGripTagsTestTime()));
	XCTAssertTrue(FxGripTagsTestTimesEqual(self.settingAPI.lastValueTime, FxGripTagsTestTime()));
}

- (void)testApplyTargetPresetReturnsNOWhenTheApplicationFails
{
	[self installApplyEnvironmentForParameters:@[@(kTagsTestParam)]];
	[self installTargetPresetDefinition:@[[self allSectionsPresetForParameter:kTagsTestParam]]
								 ofType:kFxParameterType_Menu];
	[self.settingAPI.failingValueParameters addObject:@(kTagsTestParam)];

	XCTAssertFalse([self applyTargetPresetForParameter:kTagsTestParam options:FxGripPresetAll]);
}

#pragma mark Protocol Consolidation

/*!
	The duplicate declaration of this protocol in FxGrip/Utilities/FxGripTagAPI.h was deleted,
	so exactly one runtime protocol carries the name and the wrapper conforms to it.
*/
- (void)testTheTagsProtocolIsRegisteredOnceAndTheWrapperConformsToIt
{
	Protocol *tagsProtocol = objc_getProtocol("FxParameterTagsAPI_v1");

	XCTAssertTrue(tagsProtocol != NULL);
	XCTAssertTrue(protocol_isEqual(tagsProtocol, @protocol(FxParameterTagsAPI_v1)));
	XCTAssertTrue([FxGripParameterTagsAPI_v1 conformsToProtocol:@protocol(FxParameterTagsAPI_v1)]);
	XCTAssertTrue([self.tagsAPI conformsToProtocol:@protocol(FxParameterTagsAPI_v1)]);
}

- (void)testThePresetResolutionMethodsAreRequiredProtocolMembers
{
	Protocol *tagsProtocol = @protocol(FxParameterTagsAPI_v1);
	SEL required[] = {
		@selector(presetDefinitionForTag:),
		@selector(targetPresetForParameter:record:)
	};

	for (size_t i = 0; i < sizeof(required) / sizeof(required[0]); i++) {
		struct objc_method_description description =
			protocol_getMethodDescription(tagsProtocol, required[i], YES, YES);
		XCTAssertTrue(description.name != NULL, @"%@ is required", NSStringFromSelector(required[i]));
		XCTAssertTrue([self.tagsAPI respondsToSelector:required[i]]);
	}
}

/*! The apply/meta members are declared @optional; steps 10-12 implement them. */
// Required-ness tracks implementation. Every preset method is implemented, so the
// protocol declares them all as required.
- (void)testTheImplementedPresetMethodsAreRequiredProtocolMembers
{
	Protocol *tagsProtocol = @protocol(FxParameterTagsAPI_v1);
	SEL required[] = {
		@selector(presetDefinitionForTag:),
		@selector(targetPresetForParameter:record:),
		@selector(applyPreset:atTime:options:presetFlags:source:tag:),
		@selector(applyTargetPresetForParameter:atTime:options:),
		@selector(getMetaKeys:forPreset:fromParameter:)
	};

	for (size_t i = 0; i < sizeof(required) / sizeof(required[0]); i++) {
		struct objc_method_description asRequired =
			protocol_getMethodDescription(tagsProtocol, required[i], YES, YES);
		XCTAssertTrue(asRequired.name != NULL, @"%@ is required", NSStringFromSelector(required[i]));
	}
}

- (void)testThePresetProtocolDeclaresNoOptionalMembers
{
	Protocol *tagsProtocol = @protocol(FxParameterTagsAPI_v1);
	unsigned int count = 0;
	struct objc_method_description *optional =
		protocol_copyMethodDescriptionList(tagsProtocol, NO, YES, &count);
	free(optional);

	XCTAssertEqual(count, 0u, @"every declared method is implemented, so none stay optional");
}

#pragma mark Reachability Through FxGripAPIAccessing

- (void)testTheAPIManagerIsConstructibleWithoutAHostAPIManager
{
	FxGripAPIAccessing *manager = [FxGripAPIAccessing.alloc initWithAPIManager:nil effect:(id)self.effect];

	XCTAssertNotNil(manager);
}

/*!
	No host vends FxParameterTagsAPI_v1, so gating the wrapper on a host API left the whole
	tags and preset delegation unreachable.
*/
- (void)testTheTagsAPIIsVendedEvenThoughNoHostSuppliesTheProtocol
{
	FxGripAPIAccessing *manager = [FxGripAPIAccessing.alloc initWithAPIManager:nil effect:(id)self.effect];

	id tagsAPI = manager.paramTagsAPIv1;

	XCTAssertNotNil(tagsAPI);
	XCTAssertTrue([tagsAPI conformsToProtocol:@protocol(FxParameterTagsAPI_v1)]);
	XCTAssertTrue([tagsAPI isKindOfClass:FxGripParameterTagsAPI_v1.class]);
}

- (void)testApiForProtocolVendsTheTagsWrapperDirectly
{
	FxGripAPIAccessing *manager = [FxGripAPIAccessing.alloc initWithAPIManager:nil effect:(id)self.effect];

	id tagsAPI = [manager apiForProtocol:@protocol(FxParameterTagsAPI_v1)];

	XCTAssertTrue([tagsAPI isKindOfClass:FxGripParameterTagsAPI_v1.class]);
}

- (void)testTheVendedTagsAPIResolvesPresetsAgainstTheEffect
{
	NSDictionary *definition = @{kFxParameterProperty_TargetPresetValues: @{@"1": @2}};
	[self installPresetDefinition:definition forTag:@"warm"];
	FxGripAPIAccessing *manager = [FxGripAPIAccessing.alloc initWithAPIManager:nil effect:(id)self.effect];

	id<FxParameterTagsAPI_v1> tagsAPI = manager.paramTagsAPIv1;

	XCTAssertEqualObjects([tagsAPI presetDefinitionForTag:@"warm"], definition);
}

@end
