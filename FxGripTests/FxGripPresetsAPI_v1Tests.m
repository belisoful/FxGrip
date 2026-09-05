//
//  FxGripPresetsAPI_v1Tests.m
//  FxGripTests
//
//  Unit tests for the preset file and discovery API: plugin compatibility, preset
//  application through the tag API core, the capture of the effect's state into a preset,
//  the managed folder locations, the premade and user preset listings, and the folder
//  watch.
//
//  Every disk location is redirected into a per-test temporary folder by subclassing the
//  API and overriding -userPresetURL and -pluginPresetURL; the listings read through those
//  accessors. The save and open panels run modally and are exercised only through the URL
//  primitives they delegate to.
//

#import <XCTest/XCTest.h>
#import <dlfcn.h>
#import <CoreMedia/CoreMedia.h>
#import <FxPlug/FxTypes.h>
#import "FxGrip/FxGripTypes.h"
#import "FxGrip/FxGripErrors.h"
#import "FxGrip/FxGripPreset.h"
#import "FxGrip/FxGripPresetsAPI_v1.h"
#import "FxGrip/FxGripParameterTagsAPI_v1.h"
#import "FxGrip/FxGripParameterFlags.h"
#import "FxGrip/FxGripParameterUtility.h"
#import "FxGrip/FxGripMetaManager.h"

// FxGripAPIAccessing.h reaches its dependencies through flat quoted includes that do not
// resolve outside the framework target, so the manager is declared here with the members
// the wiring test exercises; the implementation comes from the linked framework.
@interface FxGripAPIAccessing : NSObject
- (nullable instancetype)initWithAPIManager:(nullable id)apiManager effect:(nonnull id)effect;
@property (readonly, nullable) id presetsAPIv1;
@end

static NSString *const kPresetsTestPluginUuid = @"11111111-2222-3333-4444-555555555555";
static NSString *const kPresetsTestGroupUuid = @"GROUP-UUID-1";

/*!
	The test bundle does not link FxPlug.framework, and FxPlug is weak-linked by FxGrip, so
	the constant is read from the loaded images. Outside an FxPlug host the symbol is absent
	and FxGripErrors.h substitutes FxGripPlugErrorDomain.
*/
static NSString *FxGripPresetsTestExpectedErrorDomain(void)
{
	NSString * __unsafe_unretained *domain = (NSString * __unsafe_unretained *)dlsym(RTLD_DEFAULT, "FxPlugErrorDomain");
	return domain ? *domain : FxGripPlugErrorDomainConstant;
}

static const FxParameterId kPresetsTestParamA = 10;
static const FxParameterId kPresetsTestParamB = 20;

// The test bundle links only FxGrip and XCTest, so CMTime values are built and compared
// without the CoreMedia symbols.
static CMTime FxGripPresetsTestTime(void)
{
	return (CMTime){.value = 7, .timescale = 30, .flags = kCMTimeFlags_Valid, .epoch = 0};
}

static CMTime FxGripPresetsTestZeroTime(void)
{
	return (CMTime){.value = 0, .timescale = 1, .flags = kCMTimeFlags_Valid, .epoch = 0};
}

static BOOL FxGripPresetsTestTimesEqual(CMTime lhs, CMTime rhs)
{
	return lhs.value == rhs.value && lhs.timescale == rhs.timescale
		&& lhs.flags == rhs.flags && lhs.epoch == rhs.epoch;
}

#pragma mark - Test doubles

// Supplies the parameter type the preset value primitives dispatch on.
@interface FxGripPresetsTestDynamicAPI : NSObject
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *typesByParameter;
@end

@implementation FxGripPresetsTestDynamicAPI

- (instancetype)init
{
	self = [super init];
	if (self) {
		_typesByParameter = NSMutableDictionary.new;
	}
	return self;
}

- (FxParameterType)parameterType:(FxParameterId)parameterID
{
	NSNumber *type = self.typesByParameter[@(parameterID)];
	return type != nil ? (FxParameterType)type.unsignedIntValue : FxParameterType_Float;
}

@end

// Answers the value and flag reads the capture performs with the values staged on it.
@interface FxGripPresetsTestRetrievalAPI : NSObject
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *floatsByParameter;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSString *> *stringsByParameter;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *flagsByParameter;
@property (nonatomic, assign) CMTime lastReadTime;
@end

@implementation FxGripPresetsTestRetrievalAPI

- (instancetype)init
{
	self = [super init];
	if (self) {
		_floatsByParameter = NSMutableDictionary.new;
		_stringsByParameter = NSMutableDictionary.new;
		_flagsByParameter = NSMutableDictionary.new;
	}
	return self;
}

- (BOOL)getFloatValue:(double *)value fromParameter:(UInt32)parameterID atTime:(CMTime)time
{
	self.lastReadTime = time;
	NSNumber *staged = self.floatsByParameter[@(parameterID)];
	if (staged == nil) {
		return NO;
	}
	*value = staged.doubleValue;
	return YES;
}

- (BOOL)getStringParameterValue:(NSString * _Nonnull * _Nullable)string fromParameter:(UInt32)parameterID
{
	NSString *staged = self.stringsByParameter[@(parameterID)];
	if (staged == nil) {
		return NO;
	}
	*string = staged;
	return YES;
}

- (BOOL)getParameterFlags:(FxParameterFlags *)flags fromParameter:(UInt32)parameterID
{
	*flags = (FxParameterFlags)self.flagsByParameter[@(parameterID)].unsignedIntValue;
	return YES;
}

@end

// Stands in for the FxGrip setting wrapper: it exposes the retrieval and dynamic APIs the
// preset value primitives reach through.
@interface FxGripPresetsTestSettingAPI : NSObject
@property (nonatomic, strong) FxGripPresetsTestRetrievalAPI *retrievalAPI;
@property (nonatomic, strong) FxGripPresetsTestDynamicAPI *dynamicAPI;
@end

@implementation FxGripPresetsTestSettingAPI

- (id)paramGetAPIv6
{
	return self.retrievalAPI;
}

- (id)parameterInfoAPIv1
{
	return self.dynamicAPI;
}

@end

/*!
	The preset application funnels into the tag API core, and the wrapper casts what the
	manager vends to FxGripParameterTagsAPI_v1, so the spy is one. It records the arguments
	of the application instead of touching parameters.
*/
@interface FxGripPresetsTestTagsAPI : FxGripParameterTagsAPI_v1
@property (nonatomic, assign) NSUInteger applyCount;
@property (nonatomic, strong) NSDictionary *appliedPreset;
@property (nonatomic, assign) CMTime appliedTime;
@property (nonatomic, assign) FxGripPresetOptions appliedOptions;
@property (nonatomic, assign) FxGripParameterPresetFlags appliedFlags;
@property (nonatomic, assign) FxGripPresetSource appliedSource;
@property (nonatomic, copy) NSString *appliedTag;
@property (nonatomic, strong) NSError *applyError;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSArray<NSString *> *> *tagsByParameter;
@end

@implementation FxGripPresetsTestTagsAPI

- (NSArray<NSString *> *)parameterTags:(FxParameterId)parameterID
{
	return self.tagsByParameter[@(parameterID)];
}

- (NSError *)applyPreset:(NSDictionary *)preset
				  atTime:(CMTime)time
				 options:(FxGripPresetOptions)options
			 presetFlags:(FxGripParameterPresetFlags)presetFlags
				  source:(FxGripPresetSource)source
					 tag:(NSString *)tag
{
	self.applyCount += 1;
	self.appliedPreset = preset;
	self.appliedTime = time;
	self.appliedOptions = options;
	self.appliedFlags = presetFlags;
	self.appliedSource = source;
	self.appliedTag = tag;
	return self.applyError;
}

@end

@interface FxGripPresetsTestAPIManager : NSObject
@property (nonatomic, copy, nullable) NSString *pluginUUID;
@property (nonatomic, strong) FxGripPresetsTestSettingAPI *settingAPI;
@property (nonatomic, strong) FxGripPresetsTestRetrievalAPI *retrievalAPI;
@property (nonatomic, strong) FxGripPresetsTestTagsAPI *tagsAPI;
@end

@implementation FxGripPresetsTestAPIManager

- (id)paramSetAPIv5
{
	return self.settingAPI;
}

- (id)paramGetAPIv6
{
	return self.retrievalAPI;
}

- (id)paramTagsAPIv1
{
	return self.tagsAPI;
}

@end

// FxGripTileableEffect's designated initializer registers into the process-wide
// notification center and needs a live host, so the API is exercised against a stub
// exposing the members the preset layer reads.
@interface FxGripPresetsTestStubEffect : NSObject
@property (nonatomic, copy) NSString *pluginUUID;
@property (nonatomic, strong) NSDictionary<NSString *, id> *pluginProperties;
@property (nonatomic, strong) FxGripPresetsTestAPIManager *apiManager;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, id> *parameters;
@property (nonatomic, assign) BOOL hasMeta;
@property (nonatomic, strong) FxGripMetaManager *meta;
@end

@implementation FxGripPresetsTestStubEffect

- (id)effectBase
{
	// The stub plays the full effect; rich reads route back to it, as the old cast did.
	return self;
}


- (instancetype)init
{
	self = [super init];
	if (self) {
		_parameters = NSMutableDictionary.new;
	}
	return self;
}

@end

/*! Redirects both preset folders so no test reaches the real Application Support tree. */
@interface FxGripPresetsTestAPI : FxGripPresetsAPI_v1
@property (nonatomic, strong) NSURL *userFolderURL;
@property (nonatomic, strong) NSURL *pluginFolderURL;
@end

@implementation FxGripPresetsTestAPI

- (NSURL *)userPresetURL
{
	return self.userFolderURL;
}

- (NSURL *)pluginPresetURL
{
	return self.pluginFolderURL;
}

@end

#pragma mark - Tests

@interface FxGripPresetsAPI_v1Tests : XCTestCase
@property (nonatomic, strong) FxGripPresetsTestStubEffect *effect;
@property (nonatomic, strong) FxGripPresetsTestAPIManager *apiManager;
@property (nonatomic, strong) FxGripPresetsTestSettingAPI *settingAPI;
@property (nonatomic, strong) FxGripPresetsTestRetrievalAPI *retrievalAPI;
@property (nonatomic, strong) FxGripPresetsTestDynamicAPI *dynamicAPI;
@property (nonatomic, strong) FxGripPresetsTestTagsAPI *tagsAPI;
@property (nonatomic, strong) NSURL *sandboxURL;
@end

@implementation FxGripPresetsAPI_v1Tests

- (void)setUp
{
	[super setUp];
	self.sandboxURL = [[NSURL fileURLWithPath:NSTemporaryDirectory()]
					   URLByAppendingPathComponent:NSUUID.UUID.UUIDString isDirectory:YES];
	[NSFileManager.defaultManager createDirectoryAtURL:self.sandboxURL
						   withIntermediateDirectories:YES
											attributes:nil
												 error:NULL];

	self.effect = [FxGripPresetsTestStubEffect.alloc init];
	self.effect.pluginUUID = kPresetsTestPluginUuid;
	self.effect.pluginProperties = @{
		kProPlugPlugIn_UuidProperty: kPresetsTestPluginUuid,
		kProPlugPlugIn_ClassNameProperty: @"FxGripPresetsTestEffect",
		kProPlugPlugIn_DisplayNameProperty: @"Presets Test",
		kProPlugPlugIn_GroupUUIDProperty: kPresetsTestGroupUuid,
		kProPlugPlugIn_VersionProperty: @"2.5"
	};

	self.retrievalAPI = [FxGripPresetsTestRetrievalAPI.alloc init];
	self.dynamicAPI = [FxGripPresetsTestDynamicAPI.alloc init];
	self.settingAPI = [FxGripPresetsTestSettingAPI.alloc init];
	self.settingAPI.retrievalAPI = self.retrievalAPI;
	self.settingAPI.dynamicAPI = self.dynamicAPI;
	self.tagsAPI = [FxGripPresetsTestTagsAPI.alloc initWithAPI:nil effect:(id)self.effect];
	self.tagsAPI.tagsByParameter = NSMutableDictionary.new;

	self.apiManager = [FxGripPresetsTestAPIManager.alloc init];
	self.apiManager.settingAPI = self.settingAPI;
	self.apiManager.retrievalAPI = self.retrievalAPI;
	self.apiManager.tagsAPI = self.tagsAPI;
	self.apiManager.pluginUUID = self.effect.pluginUUID;   // identity now flows from the manager
	self.effect.apiManager = self.apiManager;
}

- (void)tearDown
{
	[NSFileManager.defaultManager removeItemAtURL:self.sandboxURL error:NULL];
	self.sandboxURL = nil;
	self.tagsAPI = nil;
	self.apiManager = nil;
	self.settingAPI = nil;
	self.retrievalAPI = nil;
	self.dynamicAPI = nil;
	self.effect = nil;
	[super tearDown];
}

/*! The redirected API: both folders live under the per-test sandbox. */
- (FxGripPresetsTestAPI *)api
{
	FxGripPresetsTestAPI *api = [FxGripPresetsTestAPI.alloc initWithAPI:nil effect:(id)self.effect];
	api.userFolderURL = [self.sandboxURL URLByAppendingPathComponent:@"user" isDirectory:YES];
	api.pluginFolderURL = [self.sandboxURL URLByAppendingPathComponent:@"bundled" isDirectory:YES];
	return api;
}

/*! The shipped API, for the accessors that must not be redirected. */
- (FxGripPresetsAPI_v1 *)plainAPI
{
	return [FxGripPresetsAPI_v1.alloc initWithAPI:nil effect:(id)self.effect];
}

- (FxGripPreset *)compatiblePreset
{
	FxGripPreset *preset = [FxGripPreset.alloc init];
	preset.pluginUuid = kPresetsTestPluginUuid;
	preset.tag = @"look";
	preset.parameterValues = @{@"10": @1.5};
	preset.parameterTags = @{@"10": @[@"look"]};
	preset.parameterMeta = @{@"10": @{@"note": @"n"}};
	return preset;
}

/*! Writes one preset file into a per-tag folder below `folderURL`, creating the folder. */
- (void)writePreset:(FxGripPreset *)preset named:(NSString *)fileName inFolder:(NSURL *)folderURL tag:(NSString *)tag
{
	NSURL *tagURL = [folderURL URLByAppendingPathComponent:tag isDirectory:YES];
	[NSFileManager.defaultManager createDirectoryAtURL:tagURL
						   withIntermediateDirectories:YES
											attributes:nil
												 error:NULL];
	XCTAssertTrue([preset savePresetToURL:[tagURL URLByAppendingPathComponent:fileName]]);
}

- (FxGripPreset *)presetNamed:(NSString *)name
{
	FxGripPreset *preset = [FxGripPreset.alloc init];
	preset.name = name;
	preset.pluginUuid = kPresetsTestPluginUuid;
	return preset;
}

#pragma mark compatiblePreset:

- (void)testCompatiblePresetAcceptsTheEffectPluginUuid
{
	XCTAssertTrue([self.api compatiblePreset:[self compatiblePreset]]);
}

- (void)testCompatiblePresetComparesTheUuidCaseInsensitively
{
	FxGripPreset *preset = [self compatiblePreset];
	preset.pluginUuid = kPresetsTestPluginUuid.lowercaseString;

	XCTAssertTrue([self.api compatiblePreset:preset]);
}

- (void)testCompatiblePresetAcceptsAnAlternativeFromTheSupportedPluginsList
{
	NSMutableDictionary *properties = [self.effect.pluginProperties mutableCopy];
	properties[kProPlugPlugIn_SupportedPluginsProperty] = @[@"OTHER-UUID", @"LEGACY-UUID"];
	self.effect.pluginProperties = properties;

	FxGripPreset *preset = [self compatiblePreset];
	preset.pluginUuid = @"legacy-uuid";

	XCTAssertTrue([self.api compatiblePreset:preset]);
}

- (void)testCompatiblePresetRejectsAnUnrelatedUuid
{
	FxGripPreset *preset = [self compatiblePreset];
	preset.pluginUuid = @"99999999-9999-9999-9999-999999999999";

	XCTAssertFalse([self.api compatiblePreset:preset]);
}

- (void)testCompatiblePresetRejectsANilPreset
{
	XCTAssertFalse([self.api compatiblePreset:nil]);
}

- (void)testCompatiblePresetRejectsAPresetWithNoPluginUuid
{
	XCTAssertFalse([self.api compatiblePreset:[FxGripPreset.alloc init]]);
}

- (void)testCompatiblePresetRejectsAnEmptyPluginUuid
{
	FxGripPreset *preset = [self compatiblePreset];
	preset.pluginUuid = @"";

	XCTAssertFalse([self.api compatiblePreset:preset]);
}

- (void)testCompatiblePresetIgnoresANonArraySupportedPluginsEntry
{
	NSMutableDictionary *properties = [self.effect.pluginProperties mutableCopy];
	properties[kProPlugPlugIn_SupportedPluginsProperty] = @"LEGACY-UUID";
	self.effect.pluginProperties = properties;

	FxGripPreset *preset = [self compatiblePreset];
	preset.pluginUuid = @"LEGACY-UUID";

	XCTAssertFalse([self.api compatiblePreset:preset]);
}

- (void)testCompatiblePresetIgnoresANonStringAlternative
{
	NSMutableDictionary *properties = [self.effect.pluginProperties mutableCopy];
	properties[kProPlugPlugIn_SupportedPluginsProperty] = @[@42];
	self.effect.pluginProperties = properties;

	FxGripPreset *preset = [self compatiblePreset];
	preset.pluginUuid = @"42";

	XCTAssertFalse([self.api compatiblePreset:preset]);
}

- (void)testCompatiblePresetRejectsAPresetWhenTheEffectHasNoPluginUuid
{
	// The identity's single source is the API manager.
	self.apiManager.pluginUUID = nil;

	XCTAssertFalse([self.api compatiblePreset:[self compatiblePreset]]);
}

#pragma mark setPreset:options:atTime:

- (void)testSetPresetAppliesTheSectionsThroughTheTagsCore
{
	FxGripPreset *preset = [self compatiblePreset];

	XCTAssertNil([self.api setPreset:preset options:kFxParameterPreset_Default atTime:FxGripPresetsTestTime()]);

	XCTAssertEqual(self.tagsAPI.applyCount, 1u);
	XCTAssertEqualObjects(self.tagsAPI.appliedPreset, preset.presetSections);
	XCTAssertTrue(FxGripPresetsTestTimesEqual(self.tagsAPI.appliedTime, FxGripPresetsTestTime()));
	XCTAssertEqual(self.tagsAPI.appliedSource, FxGripPresetSourceFile);
	XCTAssertEqualObjects(self.tagsAPI.appliedTag, @"look");
	XCTAssertEqual(self.tagsAPI.appliedFlags, (FxGripParameterPresetFlags)kFxParameterPreset_Default);
}

- (void)testSetPresetRequestsTheValuesTagsAndMetaSections
{
	XCTAssertNil([self.api setPreset:[self compatiblePreset] options:kFxParameterPreset_Default atTime:FxGripPresetsTestTime()]);

	XCTAssertEqual(self.tagsAPI.appliedOptions, (FxGripPresetOptions)(FxGripPresetValues | FxGripPresetTags | FxGripPresetMeta));
}

- (void)testIgnoreMetaDataDropsTheMetaOptionBit
{
	XCTAssertNil([self.api setPreset:[self compatiblePreset]
							 options:kFxParameterPreset_IgnoreMetaData
							  atTime:FxGripPresetsTestTime()]);

	XCTAssertEqual(self.tagsAPI.appliedOptions, (FxGripPresetOptions)(FxGripPresetValues | FxGripPresetTags));
	XCTAssertEqual(self.tagsAPI.appliedOptions & FxGripPresetMeta, (FxGripPresetOptions)0);
}

- (void)testSetPresetForwardsThePresetFlagsToTheTagsCore
{
	FxGripParameterPresetFlags flags = kFxParameterPreset_IgnoreTagBoundary;

	XCTAssertNil([self.api setPreset:[self compatiblePreset] options:flags atTime:FxGripPresetsTestTime()]);

	XCTAssertEqual(self.tagsAPI.appliedFlags, flags);
}

- (void)testSetPresetWithoutATimeAppliesAtTimeZero
{
	XCTAssertNil([self.api setPreset:[self compatiblePreset] options:kFxParameterPreset_Default]);

	XCTAssertEqual(self.tagsAPI.applyCount, 1u);
	XCTAssertTrue(FxGripPresetsTestTimesEqual(self.tagsAPI.appliedTime, FxGripPresetsTestZeroTime()));
}

- (void)testSetPresetRefusesAnIncompatiblePresetWithoutApplyingIt
{
	FxGripPreset *preset = [self compatiblePreset];
	preset.pluginUuid = @"99999999-9999-9999-9999-999999999999";

	NSError *error = [self.api setPreset:preset options:kFxParameterPreset_Default atTime:FxGripPresetsTestTime()];

	XCTAssertNotNil(error);
	XCTAssertEqualObjects(error.domain, FxGripPresetsTestExpectedErrorDomain());
	XCTAssertEqual(error.code, kFxGripError_Preset);
	XCTAssertEqual(self.tagsAPI.applyCount, 0u);
}

- (void)testIgnoreCompatibilityAppliesAnIncompatiblePreset
{
	FxGripPreset *preset = [self compatiblePreset];
	preset.pluginUuid = @"99999999-9999-9999-9999-999999999999";

	XCTAssertNil([self.api setPreset:preset
							 options:kFxParameterPreset_IgnoreCompatibility
							  atTime:FxGripPresetsTestTime()]);

	XCTAssertEqual(self.tagsAPI.applyCount, 1u);
}

- (void)testSetPresetRefusesANilPreset
{
	FxGripPreset *preset = nil;
	NSError *error = [self.api setPreset:preset options:kFxParameterPreset_Default atTime:FxGripPresetsTestTime()];

	XCTAssertNotNil(error);
	XCTAssertEqualObjects(error.domain, FxGripPresetsTestExpectedErrorDomain());
	XCTAssertEqual(error.code, kFxGripError_Preset);
	XCTAssertEqual(self.tagsAPI.applyCount, 0u);
}

- (void)testSetPresetReportsAnUnavailableTagsAPI
{
	self.apiManager.tagsAPI = nil;

	NSError *error = [self.api setPreset:[self compatiblePreset] options:kFxParameterPreset_Default atTime:FxGripPresetsTestTime()];

	XCTAssertNotNil(error);
	XCTAssertEqual(error.code, kFxGripError_Preset);
}

- (void)testSetPresetReturnsTheErrorFromTheTagsCore
{
	NSError *failure = [NSError errorWithDomain:@"Test" code:99 userInfo:nil];
	self.tagsAPI.applyError = failure;

	XCTAssertEqualObjects([self.api setPreset:[self compatiblePreset]
									  options:kFxParameterPreset_Default
									   atTime:FxGripPresetsTestTime()], failure);
}

- (void)testSetPresetPassesANilTagForAPresetWithoutOne
{
	FxGripPreset *preset = [self compatiblePreset];
	preset.tag = nil;

	XCTAssertNil([self.api setPreset:preset options:kFxParameterPreset_Default atTime:FxGripPresetsTestTime()]);

	XCTAssertNil(self.tagsAPI.appliedTag);
}

#pragma mark generatePreset:fromLabel:

/*! Two float parameters with staged values, so the capture is observable end to end. */
- (void)stageTwoParameters
{
	self.effect.parameters[@(kPresetsTestParamA)] = @"parameterA";
	self.effect.parameters[@(kPresetsTestParamB)] = @"parameterB";
	self.retrievalAPI.floatsByParameter[@(kPresetsTestParamA)] = @1.5;
	self.retrievalAPI.floatsByParameter[@(kPresetsTestParamB)] = @2.5;
}

- (FxGripPreset *)generateFromLabel:(NSString *)label
{
	FxGripPreset *preset = nil;
	XCTAssertNil([self.api generatePreset:&preset fromLabel:label]);
	XCTAssertNotNil(preset);
	return preset;
}

- (void)testGeneratePresetCapturesEveryParameterValueUnderStringKeys
{
	[self stageTwoParameters];

	XCTAssertEqualObjects([self generateFromLabel:@"Captured"].parameterValues,
						  (@{@"10": @1.5, @"20": @2.5}));
}

- (void)testGeneratePresetCapturesValuesAtTimeZero
{
	[self stageTwoParameters];

	[self generateFromLabel:@"Captured"];

	XCTAssertTrue(FxGripPresetsTestTimesEqual(self.retrievalAPI.lastReadTime, FxGripPresetsTestZeroTime()));
}

- (void)testGeneratePresetSkipsAParameterThatAnswersNoValue
{
	[self stageTwoParameters];
	[self.retrievalAPI.floatsByParameter removeObjectForKey:@(kPresetsTestParamB)];

	XCTAssertEqualObjects([self generateFromLabel:@"Captured"].parameterValues, (@{@"10": @1.5}));
}

- (void)testGeneratePresetCapturesTheTypedEncodingOfEachParameter
{
	[self stageTwoParameters];
	self.dynamicAPI.typesByParameter[@(kPresetsTestParamB)] = @(FxParameterType_String);
	self.retrievalAPI.stringsByParameter[@(kPresetsTestParamB)] = @"caption";

	XCTAssertEqualObjects([self generateFromLabel:@"Captured"].parameterValues,
						  (@{@"10": @1.5, @"20": @"caption"}));
}

- (void)testGeneratePresetFillsTheIdentityFields
{
	[self stageTwoParameters];

	FxGripPreset *preset = [self generateFromLabel:@"Captured"];

	XCTAssertEqualObjects(preset.name, @"Captured");
	XCTAssertEqualObjects(preset.framework, @"FxGrip");
	XCTAssertEqualObjects(preset.pluginUuid, kPresetsTestPluginUuid);
	XCTAssertEqualObjects(preset.pluginLocalizedName, @"Presets Test");
	XCTAssertEqualObjects(preset.pluginVersion, @"2.5");
	XCTAssertNotNil([NSUUID.alloc initWithUUIDString:preset.uuid]);
}

- (void)testGeneratePresetIssuesAFreshUuidEachTime
{
	[self stageTwoParameters];

	XCTAssertNotEqualObjects([self generateFromLabel:@"One"].uuid, [self generateFromLabel:@"Two"].uuid);
}

- (void)testGeneratePresetCreatedTimeParsesAsISO8601
{
	[self stageTwoParameters];

	NSString *createdTime = [self generateFromLabel:@"Captured"].createdTime;

	XCTAssertNotNil(createdTime);
	NSISO8601DateFormatter *formatter = [NSISO8601DateFormatter.alloc init];
	XCTAssertNotNil([formatter dateFromString:createdTime]);
}

- (void)testGeneratePresetAuthorFallsBackToTheGroupUuidWhenTheGroupIsNotRegistered
{
	[self stageTwoParameters];

	XCTAssertEqualObjects([self generateFromLabel:@"Captured"].pluginAuthor, kPresetsTestGroupUuid);
}

- (void)testGeneratePresetLeavesTheAuthorUnsetWithoutAGroup
{
	[self stageTwoParameters];
	NSMutableDictionary *properties = [self.effect.pluginProperties mutableCopy];
	[properties removeObjectForKey:kProPlugPlugIn_GroupUUIDProperty];
	self.effect.pluginProperties = properties;

	XCTAssertNil([self generateFromLabel:@"Captured"].pluginAuthor);
}

- (void)testGeneratePresetCapturesTheTagsOfEachParameter
{
	[self stageTwoParameters];
	self.tagsAPI.tagsByParameter[@(kPresetsTestParamA)] = @[@"look", @"color"];

	XCTAssertEqualObjects([self generateFromLabel:@"Captured"].parameterTags,
						  (@{@"10": @[@"look", @"color"]}));
}

- (void)testGeneratePresetSkipsTheTagsOfAParameterFlaggedPresetNoTags
{
	[self stageTwoParameters];
	self.tagsAPI.tagsByParameter[@(kPresetsTestParamA)] = @[@"look"];
	self.tagsAPI.tagsByParameter[@(kPresetsTestParamB)] = @[@"look"];
	self.retrievalAPI.flagsByParameter[@(kPresetsTestParamA)] = @(kFxParameterFlag_PRESETNOTAGS);

	XCTAssertEqualObjects([self generateFromLabel:@"Captured"].parameterTags, (@{@"20": @[@"look"]}));
}

- (void)testGeneratePresetOmitsTheTagsSectionWhenNoParameterCarriesTags
{
	[self stageTwoParameters];

	XCTAssertNil([self generateFromLabel:@"Captured"].parameterTags);
}

- (void)testGeneratePresetOmitsTheMetaSectionWithoutAMetaManager
{
	[self stageTwoParameters];

	XCTAssertNil([self generateFromLabel:@"Captured"].parameterMeta);
}

- (void)testGeneratePresetCapturesTheMetaOfEachParameter
{
	[self stageTwoParameters];
	[self installMetaValue:@"center" forKey:@"note" onParameter:kPresetsTestParamA];

	XCTAssertEqualObjects([self generateFromLabel:@"Captured"].parameterMeta[@"10"][@"note"], @"center");
}

- (void)testGeneratePresetSkipsTheMetaOfAParameterFlaggedPresetNoMeta
{
	[self stageTwoParameters];
	[self installMetaValue:@"center" forKey:@"note" onParameter:kPresetsTestParamA];
	self.retrievalAPI.flagsByParameter[@(kPresetsTestParamA)] = @(kFxParameterFlag_PRESETNOMETA);

	XCTAssertNil([self generateFromLabel:@"Captured"].parameterMeta);
}

- (void)installMetaValue:(id)value forKey:(NSString *)key onParameter:(FxParameterId)parameterID
{
	FxGripMetaManager *manager = self.effect.meta;
	if (manager == nil) {
		manager = [FxGripMetaManager.alloc initWithEffect:nil];
		self.effect.meta = manager;
		self.effect.hasMeta = YES;
	}
	[manager addParameter:parameterID];
	XCTAssertTrue([manager setMeta:value forKey:key toParameter:parameterID]);
}

- (void)testGeneratePresetSkipsTheValueOfAParameterFlaggedPresetNoValue
{
	[self stageTwoParameters];
	self.retrievalAPI.flagsByParameter[@(kPresetsTestParamA)] = @(kFxParameterFlag_PRESETNOVALUE);

	XCTAssertEqualObjects([self generateFromLabel:@"Captured"].parameterValues, (@{@"20": @2.5}));
}

- (void)testGeneratePresetStillCapturesTheTagsOfAParameterFlaggedPresetNoValue
{
	[self stageTwoParameters];
	self.tagsAPI.tagsByParameter[@(kPresetsTestParamA)] = @[@"look"];
	self.retrievalAPI.flagsByParameter[@(kPresetsTestParamA)] = @(kFxParameterFlag_PRESETNOVALUE);

	XCTAssertEqualObjects([self generateFromLabel:@"Captured"].parameterTags, (@{@"10": @[@"look"]}));
}

- (void)testGeneratePresetStillCapturesTheMetaOfAParameterFlaggedPresetNoValue
{
	[self stageTwoParameters];
	[self installMetaValue:@"center" forKey:@"note" onParameter:kPresetsTestParamA];
	self.retrievalAPI.flagsByParameter[@(kPresetsTestParamA)] = @(kFxParameterFlag_PRESETNOVALUE);

	XCTAssertEqualObjects([self generateFromLabel:@"Captured"].parameterMeta[@"10"][@"note"], @"center");
}

- (void)testGeneratePresetSkipsOnlyTheValueOfTheFlaggedParameter
{
	[self stageTwoParameters];
	self.retrievalAPI.flagsByParameter[@(kPresetsTestParamA)] = @(kFxParameterFlag_PRESETNOVALUE
																  | kFxParameterFlag_HIDDEN);

	FxGripPreset *preset = [self generateFromLabel:@"Captured"];

	XCTAssertNil(preset.parameterValues[@"10"]);
	XCTAssertEqualObjects(preset.parameterValues[@"20"], @2.5);
}

- (void)testPresetNoValueResolvesFromItsFlagString
{
	XCTAssertEqual([FxGripParameterUtility convertFlag:kParameterFlagString_PRESETNOVALUE],
				   (FxParameterFlags)kFxParameterFlag_PRESETNOVALUE);
	XCTAssertEqual([FxGripParameterUtility convertFlag:@"presetnovalue"],
				   (FxParameterFlags)kFxParameterFlag_PRESETNOVALUE);
}

- (void)testPresetNoValueOccupiesItsOwnFlagBit
{
	XCTAssertEqual(kFxParameterFlag_PRESETNOVALUE, (FxParameterFlags64)(1u << 21));
	XCTAssertEqual(kFxParameterFlag_PRESETNOVALUE & kFxParameterFlag_PRESETNOMETA, (FxParameterFlags64)0);
	XCTAssertEqual(kFxParameterFlag_PRESETNOVALUE & kFxParameterFlag_PRESETNOTAGS, (FxParameterFlags64)0);
	XCTAssertTrue(flagNoValue(kFxParameterFlag_PRESETNOVALUE));
	XCTAssertFalse(flagNoValue(kFxParameterFlag_PRESETNOMETA));
}

- (void)testGeneratePresetReportsMissingParameterAPIs
{
	self.apiManager.settingAPI = nil;

	FxGripPreset *preset = [FxGripPreset.alloc init];
	NSError *error = [self.api generatePreset:&preset fromLabel:@"Captured"];

	XCTAssertNotNil(error);
	XCTAssertEqual(error.code, kFxGripError_Preset);
	XCTAssertNil(preset);
}

- (void)testGeneratePresetRejectsANullOutParameter
{
	FxGripPreset * __autoreleasing *out = NULL;
	NSError *error = [self.api generatePreset:out fromLabel:@"Captured"];

	XCTAssertNotNil(error);
	XCTAssertEqual(error.code, kFxGripError_Preset);
}

- (void)testGeneratePresetOfAnEffectWithNoParametersCarriesAnEmptyValuesSection
{
	XCTAssertEqualObjects([self generateFromLabel:@"Captured"].parameterValues, @{});
}

- (void)testAGeneratedPresetSurvivesTheFileRoundTrip
{
	[self stageTwoParameters];
	self.tagsAPI.tagsByParameter[@(kPresetsTestParamA)] = @[@"look"];
	FxGripPreset *generated = [self generateFromLabel:@"Captured"];
	NSURL *url = [self.sandboxURL URLByAppendingPathComponent:@"Captured.fxpreset"];
	XCTAssertTrue([generated savePresetToURL:url]);

	FxGripPreset *reloaded = [FxGripPreset loadPresetFromURL:url];
	XCTAssertEqualObjects(reloaded.name, generated.name);
	XCTAssertEqualObjects(reloaded.uuid, generated.uuid);
	XCTAssertEqualObjects(reloaded.framework, @"FxGrip");
	XCTAssertEqualObjects(reloaded.parameterValues, generated.parameterValues);
	XCTAssertEqualObjects(reloaded.parameterTags, generated.parameterTags);
}

#pragma mark userPresetURL

- (void)testDefaultUserPresetURLSitsUnderApplicationSupport
{
	NSString *path = [self plainAPI].userPresetURL.path;
	NSString *suffix = [NSString stringWithFormat:@"/%@/Presets Test", kPresetsTestGroupUuid];

	XCTAssertTrue([path containsString:@"/Application Support/"], @"%@", path);
	XCTAssertTrue([path hasSuffix:suffix], @"%@", path);
}

- (void)testDefaultUserPresetURLNamesTheCompanyFxGripWithoutAGroup
{
	NSMutableDictionary *properties = [self.effect.pluginProperties mutableCopy];
	[properties removeObjectForKey:kProPlugPlugIn_GroupUUIDProperty];
	self.effect.pluginProperties = properties;

	XCTAssertTrue([[self plainAPI].userPresetURL.path hasSuffix:@"/FxGrip/Presets Test"]);
}

- (void)testDefaultUserPresetURLSanitizesSeparatorsInTheDisplayNames
{
	NSMutableDictionary *properties = [self.effect.pluginProperties mutableCopy];
	properties[kProPlugPlugIn_GroupUUIDProperty] = @"Acme/Co:Ltd";
	properties[kProPlugPlugIn_DisplayNameProperty] = @"Big/Plugin:Name";
	self.effect.pluginProperties = properties;

	XCTAssertTrue([[self plainAPI].userPresetURL.path hasSuffix:@"/Acme-Co-Ltd/Big-Plugin-Name"]);
}

- (void)testDefaultUserPresetURLReadsTheEnglishEntryOfALocalizedDisplayName
{
	NSMutableDictionary *properties = [self.effect.pluginProperties mutableCopy];
	properties[kProPlugPlugIn_DisplayNameProperty] = @{@"French": @"Cercle", @"English": @"Circle"};
	self.effect.pluginProperties = properties;

	XCTAssertTrue([[self plainAPI].userPresetURL.path hasSuffix:@"/Circle"]);
}

- (void)testDefaultUserPresetURLFallsBackToTheClassName
{
	NSMutableDictionary *properties = [self.effect.pluginProperties mutableCopy];
	[properties removeObjectForKey:kProPlugPlugIn_DisplayNameProperty];
	self.effect.pluginProperties = properties;

	XCTAssertTrue([[self plainAPI].userPresetURL.path hasSuffix:@"/FxGripPresetsTestEffect"]);
}

- (void)testDefaultUserPresetURLIsNilWithoutAPluginName
{
	self.effect.pluginProperties = @{kProPlugPlugIn_GroupUUIDProperty: kPresetsTestGroupUuid};

	XCTAssertNil([self plainAPI].userPresetURL);
}

- (void)testUserPresetURLForTagAppendsTheSanitizedTag
{
	NSString *path = [self.api userPresetURL:@"look/feel"].path;

	XCTAssertTrue([path hasSuffix:@"/user/look-feel"], @"%@", path);
}

- (void)testUserPresetURLForAnEmptyTagIsNil
{
	XCTAssertNil([self.api userPresetURL:@""]);
}

#pragma mark pluginPresetURL

- (void)testPluginPresetURLIsNilWhenTheBundleShipsNoPresetsFolder
{
	XCTAssertNil([self plainAPI].pluginPresetURL);
}

- (void)testPluginPresetURLForTagAppendsTheSanitizedTag
{
	NSString *path = [self.api pluginPresetURL:@"look:feel"].path;

	XCTAssertTrue([path hasSuffix:@"/bundled/look-feel"], @"%@", path);
}

- (void)testPluginPresetURLForAnEmptyTagIsNil
{
	XCTAssertNil([self.api pluginPresetURL:@""]);
}

#pragma mark pluginPresetsForTag:

/*! Installs the plist `presets` table with one entry for the tag. */
- (void)installPresetsTableEntry:(id)entry forTag:(NSString *)tag
{
	NSMutableDictionary *properties = [self.effect.pluginProperties mutableCopy];
	properties[kProPlugPlugInX_PresetsProperty] = @{tag: entry};
	self.effect.pluginProperties = properties;
}

- (void)testADefinitionShapedEntryListsAsOnePresetNamedForTheTag
{
	NSDictionary *definition = @{kFxParameterProperty_TargetPresetValues: @{@"10": @1.5},
								 kFxParameterProperty_TargetPresetTags: @{@"10": @[@"look"]},
								 kFxParameterProperty_TargetPresetMeta: @{@"10": @{@"note": @"n"}}};
	[self installPresetsTableEntry:definition forTag:@"look"];

	NSArray<FxGripPreset *> *presets = [self.api pluginPresetsForTag:@"look"];

	XCTAssertEqual(presets.count, 1u);
	XCTAssertEqualObjects(presets.firstObject.name, @"look");
	XCTAssertEqualObjects(presets.firstObject.tag, @"look");
	XCTAssertEqualObjects(presets.firstObject.framework, @"FxGrip");
	XCTAssertEqualObjects(presets.firstObject.pluginUuid, kPresetsTestPluginUuid);
	XCTAssertEqualObjects(presets.firstObject.parameterValues, (@{@"10": @1.5}));
	XCTAssertEqualObjects(presets.firstObject.parameterTags, (@{@"10": @[@"look"]}));
	XCTAssertEqualObjects(presets.firstObject.parameterMeta, (@{@"10": @{@"note": @"n"}}));
}

- (void)testAFlagsOnlyEntryStillCountsAsADefinition
{
	[self installPresetsTableEntry:@{kFxParameterProperty_TargetPresetFlags: @{@"10": @0}} forTag:@"look"];

	NSArray<FxGripPreset *> *presets = [self.api pluginPresetsForTag:@"look"];

	XCTAssertEqual(presets.count, 1u);
	XCTAssertEqualObjects(presets.firstObject.name, @"look");
	XCTAssertNil(presets.firstObject.parameterValues);
}

- (void)testANameKeyedTableListsEachNamedDefinitionSortedByName
{
	[self installPresetsTableEntry:@{@"Cool": @{kFxParameterProperty_TargetPresetValues: @{@"10": @3}},
									 @"Ambient": @{kFxParameterProperty_TargetPresetValues: @{@"10": @1}},
									 @"beta": @{kFxParameterProperty_TargetPresetValues: @{@"10": @2}}}
							forTag:@"look"];

	NSArray<FxGripPreset *> *presets = [self.api pluginPresetsForTag:@"look"];

	XCTAssertEqualObjects([presets valueForKey:@"name"], (@[@"Ambient", @"beta", @"Cool"]));
	XCTAssertEqualObjects([presets valueForKey:@"tag"], (@[@"look", @"look", @"look"]));
	XCTAssertEqualObjects(presets.firstObject.parameterValues, (@{@"10": @1}));
}

- (void)testANameKeyedTableSkipsAStringAlias
{
	[self installPresetsTableEntry:@{@"Ambient": @{kFxParameterProperty_TargetPresetValues: @{@"10": @1}},
									 @"Zalias": @"other"}
							forTag:@"look"];

	NSArray<FxGripPreset *> *presets = [self.api pluginPresetsForTag:@"look"];

	XCTAssertEqualObjects([presets valueForKey:@"name"], (@[@"Ambient"]));
}

- (void)testPluginPresetsForAnUnlistedTagIsEmpty
{
	[self installPresetsTableEntry:@{kFxParameterProperty_TargetPresetValues: @{}} forTag:@"look"];

	XCTAssertEqualObjects([self.api pluginPresetsForTag:@"other"], @[]);
}

- (void)testPluginPresetsForAnEmptyTagIsEmpty
{
	XCTAssertEqualObjects([self.api pluginPresetsForTag:@""], @[]);
}

- (void)testPluginPresetsIgnoresANonDictionaryPresetsTable
{
	NSMutableDictionary *properties = [self.effect.pluginProperties mutableCopy];
	properties[kProPlugPlugInX_PresetsProperty] = @[@"look"];
	self.effect.pluginProperties = properties;

	XCTAssertEqualObjects([self.api pluginPresetsForTag:@"look"], @[]);
}

- (void)testPluginPresetsListsTheBundledFilesAfterThePlistEntries
{
	[self installPresetsTableEntry:@{kFxParameterProperty_TargetPresetValues: @{@"10": @1}} forTag:@"look"];
	FxGripPresetsTestAPI *api = self.api;
	[self writePreset:[self presetNamed:@"Bundled"] named:@"Bundled.fxpreset" inFolder:api.pluginFolderURL tag:@"look"];

	NSArray<FxGripPreset *> *presets = [api pluginPresetsForTag:@"look"];

	XCTAssertEqualObjects([presets valueForKey:@"name"], (@[@"look", @"Bundled"]));
}

#pragma mark userPresetsForTag:

- (void)testUserPresetsForTagLoadsTheFilesSortedByFileName
{
	FxGripPresetsTestAPI *api = self.api;
	[self writePreset:[self presetNamed:@"Cool"] named:@"Cool.fxpreset" inFolder:api.userFolderURL tag:@"look"];
	[self writePreset:[self presetNamed:@"Ambient"] named:@"Ambient.fxpreset" inFolder:api.userFolderURL tag:@"look"];
	[self writePreset:[self presetNamed:@"beta"] named:@"beta.fxpreset" inFolder:api.userFolderURL tag:@"look"];

	XCTAssertEqualObjects([[api userPresetsForTag:@"look"] valueForKey:@"name"],
						  (@[@"Ambient", @"beta", @"Cool"]));
}

- (void)testUserPresetsForTagFillsAMissingTagFromTheFolder
{
	FxGripPresetsTestAPI *api = self.api;
	[self writePreset:[self presetNamed:@"Ambient"] named:@"Ambient.fxpreset" inFolder:api.userFolderURL tag:@"look"];

	XCTAssertEqualObjects([api userPresetsForTag:@"look"].firstObject.tag, @"look");
}

- (void)testUserPresetsForTagKeepsTheTagAFileCarries
{
	FxGripPresetsTestAPI *api = self.api;
	FxGripPreset *preset = [self presetNamed:@"Ambient"];
	preset.tag = @"carried";
	[self writePreset:preset named:@"Ambient.fxpreset" inFolder:api.userFolderURL tag:@"look"];

	XCTAssertEqualObjects([api userPresetsForTag:@"look"].firstObject.tag, @"carried");
}

- (void)testUserPresetsForTagFillsAMissingNameFromTheFileName
{
	FxGripPresetsTestAPI *api = self.api;
	FxGripPreset *preset = [FxGripPreset.alloc init];
	preset.pluginUuid = kPresetsTestPluginUuid;
	[self writePreset:preset named:@"From File Name.fxpreset" inFolder:api.userFolderURL tag:@"look"];

	XCTAssertEqualObjects([api userPresetsForTag:@"look"].firstObject.name, @"From File Name");
}

- (void)testUserPresetsForTagKeepsTheNameAFileCarries
{
	FxGripPresetsTestAPI *api = self.api;
	[self writePreset:[self presetNamed:@"Carried"] named:@"On Disk.fxpreset" inFolder:api.userFolderURL tag:@"look"];

	XCTAssertEqualObjects([api userPresetsForTag:@"look"].firstObject.name, @"Carried");
}

- (void)testUserPresetsForTagIgnoresFilesWithAnotherExtension
{
	FxGripPresetsTestAPI *api = self.api;
	[self writePreset:[self presetNamed:@"Ambient"] named:@"Ambient.fxpreset" inFolder:api.userFolderURL tag:@"look"];
	NSURL *tagURL = [api.userFolderURL URLByAppendingPathComponent:@"look" isDirectory:YES];
	XCTAssertTrue([[@"text" dataUsingEncoding:NSUTF8StringEncoding]
				   writeToURL:[tagURL URLByAppendingPathComponent:@"notes.txt"] atomically:YES]);

	XCTAssertEqualObjects([[api userPresetsForTag:@"look"] valueForKey:@"name"], (@[@"Ambient"]));
}

- (void)testUserPresetsForTagAcceptsAnUppercaseExtension
{
	FxGripPresetsTestAPI *api = self.api;
	[self writePreset:[self presetNamed:@"Ambient"] named:@"Ambient.FXPRESET" inFolder:api.userFolderURL tag:@"look"];

	XCTAssertEqual([api userPresetsForTag:@"look"].count, 1u);
}

- (void)testUserPresetsForTagSkipsAFileThatIsNotAPresetPropertyList
{
	FxGripPresetsTestAPI *api = self.api;
	NSURL *tagURL = [api.userFolderURL URLByAppendingPathComponent:@"look" isDirectory:YES];
	[NSFileManager.defaultManager createDirectoryAtURL:tagURL withIntermediateDirectories:YES attributes:nil error:NULL];
	XCTAssertTrue([[@"garbage" dataUsingEncoding:NSUTF8StringEncoding]
				   writeToURL:[tagURL URLByAppendingPathComponent:@"broken.fxpreset"] atomically:YES]);

	XCTAssertEqualObjects([api userPresetsForTag:@"look"], @[]);
}

- (void)testUserPresetsForAMissingFolderIsEmpty
{
	XCTAssertEqualObjects([self.api userPresetsForTag:@"look"], @[]);
}

- (void)testUserPresetsForAnEmptyTagIsEmpty
{
	XCTAssertEqualObjects([self.api userPresetsForTag:@""], @[]);
}

#pragma mark presetsForTag:

- (void)testPresetsForTagListsPluginPresetsBeforeUserPresets
{
	[self installPresetsTableEntry:@{kFxParameterProperty_TargetPresetValues: @{@"10": @1}} forTag:@"look"];
	FxGripPresetsTestAPI *api = self.api;
	[self writePreset:[self presetNamed:@"Bundled"] named:@"Bundled.fxpreset" inFolder:api.pluginFolderURL tag:@"look"];
	[self writePreset:[self presetNamed:@"Mine"] named:@"Mine.fxpreset" inFolder:api.userFolderURL tag:@"look"];

	XCTAssertEqualObjects([[api presetsForTag:@"look"] valueForKey:@"name"],
						  (@[@"look", @"Bundled", @"Mine"]));
}

- (void)testPresetsForTagIsEmptyWithNoSources
{
	XCTAssertEqualObjects([self.api presetsForTag:@"look"], @[]);
}

#pragma mark observeTag:observer:

- (void)testObserveTagIsNilForAMissingFolder
{
	XCTAssertNil([self.api observeTag:@"look" observer:^{}]);
}

- (void)testObserveTagReturnsAWatcherForAnExistingFolder
{
	FxGripPresetsTestAPI *api = self.api;
	[NSFileManager.defaultManager createDirectoryAtURL:[api userPresetURL:@"look"]
						   withIntermediateDirectories:YES
											attributes:nil
												 error:NULL];

	// BEFoundation is not linked by the test bundle, so the watcher is held as an untyped
	// object and dropped before the folder is removed.
	id watcher = [api observeTag:@"look" observer:^{}];

	XCTAssertNotNil(watcher);
	watcher = nil;
}

- (void)testObserveTagIsNilForANilHandler
{
	FxGripPresetsTestAPI *api = self.api;
	[NSFileManager.defaultManager createDirectoryAtURL:[api userPresetURL:@"look"]
						   withIntermediateDirectories:YES
											attributes:nil
												 error:NULL];
	void (^handler)(void) = nil;

	XCTAssertNil([api observeTag:@"look" observer:handler]);
}

- (void)testObserveTagIsNilForAnEmptyTag
{
	XCTAssertNil([self.api observeTag:@"" observer:^{}]);
}

#pragma mark Wiring

- (void)testPresetsAPIv1IsReachableThroughTheAPIManager
{
	FxGripAPIAccessing *manager = [FxGripAPIAccessing.alloc initWithAPIManager:nil effect:(id)self.effect];

	id presetsAPI = manager.presetsAPIv1;

	XCTAssertNotNil(presetsAPI);
	XCTAssertTrue([presetsAPI isKindOfClass:FxGripPresetsAPI_v1.class]);
	XCTAssertTrue([presetsAPI compatiblePreset:[self compatiblePreset]]);
}

@end
