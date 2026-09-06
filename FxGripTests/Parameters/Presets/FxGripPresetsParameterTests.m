/*!
	@file       FxGripPresetsParameterTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripPresetsParameterTests
	@abstract   Tests the FxGripPresetsParameter tag, menu, creation, selection, and live refresh.
	@discussion Introduced in FxGrip 0.1.0. The tests cover the preset tag a configuration declares, the menu layout built from the user and plugin preset sources, the popup-menu creation call, the type-map entry, the selection handling the change notification drives, the reveal and save action entries, selection restoration, the user-preset folder watcher, and the live menu refresh.
*/

#import <XCTest/XCTest.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import "FxGripParameterClassTestSupport.h"
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripPresetsParameter.h>
#import <FxGrip/FxGripPresetsAPI_v1.h>
#import <FxGrip/FxGripPreset.h>
#import <FxGrip/FxGripMetaManager.h>
#import <FxGrip/FxGripAPINotifications.h>
#import <FxGrip/FxGripTileableEffect.h>
#import <FxGrip/FxGripTileableEffect+Notifications.h>
#import <FxGrip/FxGripTileableEffect+Parameters.h>

// Implemented on FxGripPresetsParameter and its base but absent from the public headers.
@interface FxGripPresetsParameter (FxGripPresetsParameterTests)
- (instancetype)initWithDictionary:(NSDictionary *)dictionary;
- (void)revealUserPresetsAtTime:(CMTime)time;
- (void)saveCurrentStateAsPresetAtTime:(CMTime)time;
- (void)restoreSelectionAtTime:(CMTime)time;
- (nullable NSString *)menuEntryNameAtIndex:(int)index;
- (void)attachUserPresetWatcher;
// The argument is the watcher, which the handler ignores; BEFoundation is not linked.
- (void)userPresetFolderChanged:(nullable id)watcher;
- (void)refreshMenuEntriesAtTime:(CMTime)time;
@end

static const FxParameterId kPresetsParamTestParameter = 71;
static const FxParameterId kPresetsParamTestOtherParameter = 72;
static NSString *const kPresetsParamTestTag = @"look";
static NSString *const kPresetsParamTestPluginUuid = @"11111111-2222-3333-4444-555555555555";

/*!
	The CMTime dictionary the change notification carries. CoreMedia is not linked into the
	test bundle, so the encoder is read from the loaded images; the literal keys stand in
	when the symbol is absent.
*/
static NSDictionary *FxGripPresetsParamTestTimeDictionary(CMTime time)
{
	CFDictionaryRef (*copyAsDictionary)(CMTime, CFAllocatorRef) =
		(CFDictionaryRef (*)(CMTime, CFAllocatorRef))dlsym(RTLD_DEFAULT, "CMTimeCopyAsDictionary");
	if (copyAsDictionary != NULL) {
		return CFBridgingRelease(copyAsDictionary(time, kCFAllocatorDefault));
	}
	return @{@"value": @(time.value),
			 @"timescale": @(time.timescale),
			 @"flags": @(time.flags),
			 @"epoch": @(time.epoch)};
}

#pragma mark - Test doubles

/*! Records the two action entries instead of reaching Finder and the save panel. */
@interface FxGripPresetsParamTestParameter : FxGripPresetsParameter
@property (nonatomic, assign) NSUInteger revealCount;
@property (nonatomic, assign) NSUInteger saveCount;
@property (nonatomic, assign) CMTime actionTime;
@end

@implementation FxGripPresetsParamTestParameter

- (void)revealUserPresetsAtTime:(CMTime)time
{
	self.revealCount += 1;
	self.actionTime = time;
}

- (void)saveCurrentStateAsPresetAtTime:(CMTime)time
{
	self.saveCount += 1;
	self.actionTime = time;
}

@end

/*!
	Redirects both preset folders into the sandbox and records the preset application. The
	capture and the save answer with the staged results, so the save action reaches no
	panel; -saveHandler stands in for what the panel writes to disk.
*/
@interface FxGripPresetsParamTestPresetsAPI : FxGripPresetsAPI_v1
@property (nonatomic, strong) NSURL *userFolderURL;
@property (nonatomic, strong) NSURL *pluginFolderURL;
@property (nonatomic, assign) NSUInteger applyCount;
@property (nonatomic, strong) FxGripPreset *appliedPreset;
@property (nonatomic, assign) FxGripParameterPresetFlags appliedOptions;
@property (nonatomic, assign) CMTime appliedTime;
@property (nonatomic, strong) NSError *applyError;

@property (nonatomic, assign) NSUInteger generateCount;
@property (nonatomic, copy) NSString *generatedLabel;
@property (nonatomic, strong) FxGripPreset *generatedPreset;
@property (nonatomic, strong) NSError *generateError;
@property (nonatomic, assign) NSUInteger saveCount;
@property (nonatomic, strong) FxGripPreset *savedPreset;
@property (nonatomic, assign) BOOL saveSucceeds;
@property (nonatomic, copy) void (^saveHandler)(FxGripPreset *preset);
@end

@implementation FxGripPresetsParamTestPresetsAPI

- (NSURL *)userPresetURL
{
	return self.userFolderURL;
}

- (NSURL *)pluginPresetURL
{
	return self.pluginFolderURL;
}

- (NSError *)setPreset:(FxGripPreset *)preset options:(FxGripParameterPresetFlags)flags atTime:(CMTime)time
{
	self.applyCount += 1;
	self.appliedPreset = preset;
	self.appliedOptions = flags;
	self.appliedTime = time;
	return self.applyError;
}

- (NSError *)generatePreset:(FxGripPreset **)preset fromLabel:(NSString *)label
{
	self.generateCount += 1;
	self.generatedLabel = label;
	if (preset != NULL) {
		*preset = self.generatedPreset;
	}
	return self.generateError;
}

- (BOOL)savePreset:(FxGripPreset *)preset remap:(NSDictionary *)keyMap
{
	self.saveCount += 1;
	self.savedPreset = preset;
	if (self.saveHandler != nil) {
		self.saveHandler(preset);
	}
	return self.saveSucceeds;
}

@end

/*! Records the menu rebuilds the live refresh pushes, and answers with the staged error. */
@interface FxGripPresetsParamTestDynamicAPI : FxGripParamClassTestDynamicAPI
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *menuCalls;
@property (nonatomic, strong) NSError *menuError;
@property (nonatomic, readonly) NSDictionary *lastMenuCall;
@end

@implementation FxGripPresetsParamTestDynamicAPI

- (instancetype)init
{
	self = [super init];
	if (self) {
		_menuCalls = NSMutableArray.new;
	}
	return self;
}

- (NSDictionary *)lastMenuCall
{
	return self.menuCalls.lastObject;
}

- (NSError *)setPopupMenuParameter:(UInt32)parameterID
						   entries:(NSArray<NSString *> *)entries
					  defaultValue:(UInt32)defaultIndex
{
	[self.menuCalls addObject:@{@"id": @(parameterID),
								@"items": entries ?: @[],
								@"default": @(defaultIndex)}];
	return self.menuError;
}

@end

// The parameter class reaches the preset layer through -presetsAPIv1 alone.
@class FxGripPresetsParamTestEffect;

/*! Counts out-of-band contexts: FxGripOOBParameterAccess asks the manager for this API. */
@interface FxGripPresetsParamTestActionAPI : NSObject
@property (nonatomic, weak) FxGripPresetsParamTestEffect *effect;
@end

@interface FxGripPresetsParamTestAPIManager : NSObject
@property (nonatomic, strong, nullable) FxGripPresetsParamTestActionAPI *customParameterActionAPIv4;
@property (nonatomic, assign) unsigned long long sessionID;
@property (nonatomic, strong, nullable) FxGripParamClassTestCreationAPI *paramCreateAPIv5;
@property (nonatomic, strong, nullable) FxGripParamClassTestRetrievalAPI *paramGetAPIv6;
@property (nonatomic, strong, nullable) FxGripParamClassTestSettingAPI *paramSetAPIv5;
@property (nonatomic, strong, nullable) FxGripPresetsParamTestDynamicAPI *dynamicParamAPIv3;
@property (nonatomic, strong, nullable) id presetsAPIv1;
@end

@implementation FxGripPresetsParamTestAPIManager

- (instancetype)init
{
	self = [super init];
	if (self) {
		_sessionID = 1;
		_paramCreateAPIv5 = [FxGripParamClassTestCreationAPI.alloc init];
		_paramGetAPIv6 = [FxGripParamClassTestRetrievalAPI.alloc init];
		_paramSetAPIv5 = [FxGripParamClassTestSettingAPI.alloc init];
		_dynamicParamAPIv3 = [FxGripPresetsParamTestDynamicAPI.alloc init];
	}
	return self;
}

@end

/*! Supplies the live menu the index resolution consults. */
@interface FxGripPresetsParamTestParameterData : NSObject
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSArray<NSString *> *> *menusByParameter;
@end

@implementation FxGripPresetsParamTestParameterData

- (instancetype)init
{
	self = [super init];
	if (self) {
		_menusByParameter = NSMutableDictionary.new;
	}
	return self;
}

- (NSArray<NSString *> *)storedMenus:(FxParameterId)parameterID
{
	return self.menusByParameter[@(parameterID)];
}

@end

/*!
	FxGripTileableEffect's designated initializer needs a live host, so the parameter is
	exercised against a stub answering the members it reads.
*/
@interface FxGripPresetsParamTestEffect : NSObject
@property (nonatomic, strong) FxGripPresetsParamTestAPIManager *apiManager;
@property (nonatomic, strong) NSNotificationCenter *notifier;
@property (nonatomic, strong) FxGripPresetsParamTestParameterData *parameterData;
@property (nonatomic, assign) BOOL hasMeta;
@property (nonatomic, strong) FxGripMetaManager *meta;
@property (nonatomic, strong) NSDictionary<NSString *, id> *pluginProperties;
@property (nonatomic, copy) NSString *pluginUUID;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, id> *parameters;
@property (nonatomic, assign) NSUInteger startContextCount;   // counted via the manager's action API
- (nullable id)objectForKeyedSubscript:(nullable id)key;
- (nullable id)objectAtIndexedSubscript:(NSInteger)index;
/*! The out-of-band access context the refresh opens. The context object is unused, so the
	stub counts the call and answers nil. */
- (nullable id)startContext;
@end

@implementation FxGripPresetsParamTestActionAPI
- (void)startAction:(id)sender
{
	self.effect.startContextCount += 1;
}
- (void)endAction:(id)sender
{
}
- (CMTime)currentTime
{
	CMTime time = { .value = 0, .timescale = 600, .flags = kCMTimeFlags_Valid };
	return time;
}
@end

@implementation FxGripPresetsParamTestEffect

- (id)effectBase
{
	// The stub plays the full effect; rich reads route back to it, as the old cast did.
	return self;
}

- (instancetype)init
{
	self = [super init];
	if (self) {
		_apiManager = [FxGripPresetsParamTestAPIManager.alloc init];
		_apiManager.customParameterActionAPIv4 = [FxGripPresetsParamTestActionAPI.alloc init];
		_apiManager.customParameterActionAPIv4.effect = self;
		_notifier = FxGripParamClassTestMakePriorityCenter();
		_parameterData = [FxGripPresetsParamTestParameterData.alloc init];
		_parameters = NSMutableDictionary.new;
		_pluginProperties = @{};
		_pluginUUID = kPresetsParamTestPluginUuid;
	}
	return self;
}

- (id)objectForKeyedSubscript:(id)key
{
	return key ? self.parameters[key] : nil;
}

- (id)objectAtIndexedSubscript:(NSInteger)index
{
	return self.parameters[@(index)];
}

- (id)startContext
{
	self.startContextCount += 1;
	return nil;
}

@end

/*! A real effect, for the parameter type map its initializer loads. */
@interface FxGripPresetsParamTestHostEffect : FxGripTileableEffect
@property (nonatomic, strong) NSNotificationCenter *privateNotifier;
@end

@implementation FxGripPresetsParamTestHostEffect

- (id)effectBase
{
	// The stub plays the full effect; rich reads route back to it, as the old cast did.
	return self;
}


- (NSPriorityNotificationCenter *)notifier
{
	if (!_privateNotifier) {
		Class cls = NSClassFromString(@"NSPriorityNotificationCenter");
		_privateNotifier = [[cls alloc] init];
	}
	return (NSPriorityNotificationCenter *)_privateNotifier;
}

@end

#pragma mark - Tests

@interface FxGripPresetsParameterTests : XCTestCase
@property (nonatomic, strong) FxGripPresetsParamTestEffect *effect;
@property (nonatomic, strong) FxGripPresetsParamTestPresetsAPI *presetsAPI;
@property (nonatomic, strong) NSURL *sandboxURL;
// The notifier holds its observers weakly, so every parameter under test is retained.
@property (nonatomic, strong) NSMutableArray *retainedParameters;
@end

@implementation FxGripPresetsParameterTests

- (void)setUp
{
	[super setUp];
	self.retainedParameters = NSMutableArray.new;
	self.sandboxURL = [[NSURL fileURLWithPath:NSTemporaryDirectory()]
					   URLByAppendingPathComponent:NSUUID.UUID.UUIDString isDirectory:YES];
	[NSFileManager.defaultManager createDirectoryAtURL:self.sandboxURL
						   withIntermediateDirectories:YES
											attributes:nil
												 error:NULL];

	self.effect = [FxGripPresetsParamTestEffect.alloc init];
	self.presetsAPI = [FxGripPresetsParamTestPresetsAPI.alloc initWithAPI:nil effect:(id)self.effect];
	self.presetsAPI.userFolderURL = [self.sandboxURL URLByAppendingPathComponent:@"user" isDirectory:YES];
	self.presetsAPI.pluginFolderURL = [self.sandboxURL URLByAppendingPathComponent:@"bundled" isDirectory:YES];
	self.effect.apiManager.presetsAPIv1 = self.presetsAPI;

	FxGripMetaManager *meta = [FxGripMetaManager.alloc initWithEffect:nil];
	[meta addParameter:kPresetsParamTestParameter];
	[meta addParameter:kPresetsParamTestOtherParameter];
	self.effect.meta = meta;
	self.effect.hasMeta = YES;
}

- (void)tearDown
{
	self.retainedParameters = nil;
	self.presetsAPI = nil;
	self.effect = nil;
	[NSFileManager.defaultManager removeItemAtURL:self.sandboxURL error:NULL];
	self.sandboxURL = nil;
	[super tearDown];
}

#pragma mark Helpers

- (NSMutableDictionary *)configWithExtra:(NSDictionary *)extra
{
	NSMutableDictionary *config = FxGripParamClassTestConfig(kPresetsParamTestParameter,
														kFxParameterType_Presets,
														@"Preset",
														extra);
	return config;
}

- (NSMutableDictionary *)taggedConfig
{
	return [self configWithExtra:@{kFxParameterProperty_Tags: @[kPresetsParamTestTag]}];
}

- (FxGripPresetsParamTestParameter *)makeParameter
{
	FxGripPresetsParamTestParameter *parameter =
		[FxGripPresetsParamTestParameter.alloc initWithDictionary:[self taggedConfig] effect:(id)self.effect];
	XCTAssertNotNil(parameter);
	[self.retainedParameters addObject:parameter];
	return parameter;
}

/*! The class under test, with the two action entries left to run their own bodies. */
- (FxGripPresetsParameter *)makeUnwrappedParameter
{
	FxGripPresetsParameter *parameter =
		[FxGripPresetsParameter.alloc initWithDictionary:[self taggedConfig] effect:(id)self.effect];
	XCTAssertNotNil(parameter);
	[self.retainedParameters addObject:parameter];
	return parameter;
}

- (FxGripPresetsParamTestDynamicAPI *)dynamicAPI
{
	return self.effect.apiManager.dynamicParamAPIv3;
}

- (NSURL *)userTagFolderURL
{
	return [self.presetsAPI.userFolderURL URLByAppendingPathComponent:kPresetsParamTestTag isDirectory:YES];
}

- (void)createUserTagFolder
{
	XCTAssertTrue([NSFileManager.defaultManager createDirectoryAtURL:[self userTagFolderURL]
										 withIntermediateDirectories:YES
														  attributes:nil
															   error:NULL]);
}

/*! The watcher as an opaque object: BEFoundation is not linked into the test bundle. */
- (id)watcherOfParameter:(FxGripPresetsParameter *)parameter
{
	Ivar ivar = class_getInstanceVariable(FxGripPresetsParameter.class, "_userPresetWatcher");
	XCTAssertTrue(ivar != NULL, @"the parameter no longer carries a _userPresetWatcher");
	return ivar != NULL ? object_getIvar(parameter, ivar) : nil;
}

/*! Spins the main runloop until the condition holds, so the queued refresh can run. */
- (BOOL)waitFor:(BOOL (^)(void))condition within:(NSTimeInterval)seconds
{
	NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:seconds];
	while (!condition() && deadline.timeIntervalSinceNow > 0) {
		[NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode
							   beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
	}
	return condition();
}

- (BOOL)waitForMenuRefreshWithin:(NSTimeInterval)seconds
{
	return [self waitFor:^BOOL {
		return self.dynamicAPI.menuCalls.count > 0;
	} within:seconds];
}

- (FxGripPreset *)presetNamed:(NSString *)name
{
	FxGripPreset *preset = [FxGripPreset.alloc init];
	preset.name = name;
	preset.uuid = NSUUID.UUID.UUIDString;
	preset.pluginUuid = kPresetsParamTestPluginUuid;
	return preset;
}

/*! Writes one preset file into the per-tag subfolder of a redirected preset folder. */
- (FxGripPreset *)writePresetNamed:(NSString *)name inFolder:(NSURL *)folderURL
{
	NSURL *tagURL = [folderURL URLByAppendingPathComponent:kPresetsParamTestTag isDirectory:YES];
	[NSFileManager.defaultManager createDirectoryAtURL:tagURL
						   withIntermediateDirectories:YES
											attributes:nil
												 error:NULL];
	FxGripPreset *preset = [self presetNamed:name];
	NSString *fileName = [name stringByAppendingPathExtension:kFxPreset_Extension];
	XCTAssertTrue([preset savePresetToURL:[tagURL URLByAppendingPathComponent:fileName]]);
	return preset;
}

- (FxGripPreset *)writeUserPresetNamed:(NSString *)name
{
	return [self writePresetNamed:name inFolder:self.presetsAPI.userFolderURL];
}

- (FxGripPreset *)writePluginPresetNamed:(NSString *)name
{
	return [self writePresetNamed:name inFolder:self.presetsAPI.pluginFolderURL];
}

- (NSArray<NSString *> *)entriesForConfig:(NSDictionary *)config
{
	return [FxGripPresetsParameter menuEntriesForParameter:config effect:(id)self.effect];
}

- (NSArray<NSString *> *)taggedEntries
{
	return [self entriesForConfig:[self taggedConfig]];
}

/*! The trailing entries every menu carries. */
- (NSArray<NSString *> *)tailEntries
{
	return @[kFxPresetsMenuEntry_Separator, kFxPresetsMenuEntry_Reveal, kFxPresetsMenuEntry_Save];
}

- (void)postChangeForParameter:(FxParameterId)parameterID atTime:(CMTime)time
{
	NSMutableDictionary *userInfo = NSMutableDictionary.new;
	userInfo[FxGripTileableEffectParameterChangedIDKey] = @(parameterID);
	userInfo[FxGripTileableEffectParameterChangedAtTimeKey] = FxGripPresetsParamTestTimeDictionary(time);
	[self.effect.notifier postNotificationName:FxGripTileableEffectParameterChangedName
										object:self.effect
									  userInfo:userInfo];
}

/*! The payload without the time entry, so the handler falls back to time zero. */
- (void)postUntimedChangeForParameter:(FxParameterId)parameterID
{
	[self.effect.notifier postNotificationName:FxGripTileableEffectParameterChangedName
										object:self.effect
									  userInfo:@{FxGripTileableEffectParameterChangedIDKey: @(parameterID)}];
}

/*! Stages the selected index the handler reads and posts the change. */
- (void)selectIndex:(int)index atTime:(CMTime)time
{
	self.effect.apiManager.paramGetAPIv6.intValue = index;
	[self postChangeForParameter:kPresetsParamTestParameter atTime:time];
}

- (void)selectIndex:(int)index
{
	[self selectIndex:index atTime:FxGripParamClassTestTime(9, 30)];
}

- (NSString *)recordedSelectionOfParameter:(FxParameterId)parameterID
{
	NSObject<NSSecureCoding, NSCopying> *recorded = nil;
	[self.effect.meta getMeta:&recorded forKey:kFxMetaProperty_SelectedPreset fromParameter:parameterID];
	return [recorded isKindOfClass:NSString.class] ? (NSString *)recorded : nil;
}

- (NSString *)recordedSelection
{
	return [self recordedSelectionOfParameter:kPresetsParamTestParameter];
}

- (void)recordSelection:(NSString *)name
{
	XCTAssertTrue([self.effect.meta setMeta:name
									 forKey:kFxMetaProperty_SelectedPreset
								toParameter:kPresetsParamTestParameter]);
}

- (void)stageStoredMenu:(NSArray<NSString *> *)entries
{
	self.effect.parameterData.menusByParameter[@(kPresetsParamTestParameter)] = entries;
}

#pragma mark presetTagForParameter:

/*! @abstract The preset tag is the first entry under the tags key. */
- (void)testThePresetTagIsTheFirstEntryUnderTags
{
	NSDictionary *config = [self configWithExtra:@{kFxParameterProperty_Tags: @[@"look", @"feel"]}];

	XCTAssertEqualObjects([FxGripPresetsParameter presetTagForParameter:config], @"look");
}

/*! @abstract A non-string first tag yields no preset tag. */
- (void)testANonStringFirstTagYieldsNoPresetTag
{
	NSDictionary *config = [self configWithExtra:@{kFxParameterProperty_Tags: @[@42, @"look"]}];

	XCTAssertNil([FxGripPresetsParameter presetTagForParameter:config]);
}

/*! @abstract A configuration with no tags has no preset tag. */
- (void)testAConfigurationWithoutTagsHasNoPresetTag
{
	XCTAssertNil([FxGripPresetsParameter presetTagForParameter:[self configWithExtra:nil]]);
}

/*! @abstract An empty tag list has no preset tag. */
- (void)testAnEmptyTagListHasNoPresetTag
{
	NSDictionary *config = [self configWithExtra:@{kFxParameterProperty_Tags: @[]}];

	XCTAssertNil([FxGripPresetsParameter presetTagForParameter:config]);
}

/*! @abstract A comma-divided tag string contributes its first tag as the preset tag. */
- (void)testADividedTagStringContributesItsFirstTag
{
	NSDictionary *config = [self configWithExtra:@{kFxParameterProperty_Tags: @"look, feel"}];

	XCTAssertEqualObjects([FxGripPresetsParameter presetTagForParameter:config], @"look");
}

#pragma mark menuEntriesForParameter:effect:

/*! @abstract The menu lists the default entry, then the user preset section, then the plugin preset section, then the reveal and save entries. */
- (void)testTheMenuListsTheUserSectionThenThePluginSection
{
	[self writeUserPresetNamed:@"Ambient"];
	[self writeUserPresetNamed:@"Cool"];
	[self writePluginPresetNamed:@"Bundled"];

	XCTAssertEqualObjects([self taggedEntries], (@[kFxPresetsMenuEntry_Default,
												   kFxPresetsMenuEntry_Separator,
												   @"Ambient", @"Cool",
												   kFxPresetsMenuEntry_Separator,
												   @"Bundled",
												   kFxPresetsMenuEntry_Separator,
												   kFxPresetsMenuEntry_Reveal,
												   kFxPresetsMenuEntry_Save]));
}

/*! @abstract An empty user section drops its separator along with it. */
- (void)testAnEmptyUserSectionDropsItsSeparatorWithIt
{
	[self writePluginPresetNamed:@"Bundled"];

	XCTAssertEqualObjects([self taggedEntries], (@[kFxPresetsMenuEntry_Default,
												   kFxPresetsMenuEntry_Separator,
												   @"Bundled",
												   kFxPresetsMenuEntry_Separator,
												   kFxPresetsMenuEntry_Reveal,
												   kFxPresetsMenuEntry_Save]));
}

/*! @abstract An empty plugin section drops its separator along with it. */
- (void)testAnEmptyPluginSectionDropsItsSeparatorWithIt
{
	[self writeUserPresetNamed:@"Ambient"];

	XCTAssertEqualObjects([self taggedEntries], (@[kFxPresetsMenuEntry_Default,
												   kFxPresetsMenuEntry_Separator,
												   @"Ambient",
												   kFxPresetsMenuEntry_Separator,
												   kFxPresetsMenuEntry_Reveal,
												   kFxPresetsMenuEntry_Save]));
}

/*! @abstract A tag with no presets carries only the default, reveal, and save entries. */
- (void)testATagWithNoPresetsCarriesTheFourFixedEntries
{
	NSArray *expected = [@[kFxPresetsMenuEntry_Default] arrayByAddingObjectsFromArray:[self tailEntries]];

	XCTAssertEqualObjects([self taggedEntries], expected);
}

/*! @abstract A configuration with no tag lists no presets and carries only the fixed entries. */
- (void)testAConfigurationWithoutATagCarriesTheFourFixedEntries
{
	[self writeUserPresetNamed:@"Ambient"];
	NSArray *expected = [@[kFxPresetsMenuEntry_Default] arrayByAddingObjectsFromArray:[self tailEntries]];

	XCTAssertEqualObjects([self entriesForConfig:[self configWithExtra:nil]], expected);
}

/*! @abstract An effect with no presets API lists no presets and carries only the fixed entries. */
- (void)testAnEffectWithoutAPresetsAPICarriesTheFourFixedEntries
{
	[self writeUserPresetNamed:@"Ambient"];
	self.effect.apiManager.presetsAPIv1 = nil;
	NSArray *expected = [@[kFxPresetsMenuEntry_Default] arrayByAddingObjectsFromArray:[self tailEntries]];

	XCTAssertEqualObjects([self taggedEntries], expected);
}

/*! @abstract No two separators appear next to each other in the menu. */
- (void)testNoMenuPlacesTwoSeparatorsTogether
{
	[self writeUserPresetNamed:@"Ambient"];
	[self writePluginPresetNamed:@"Bundled"];

	NSArray<NSString *> *entries = [self taggedEntries];

	NSString *previous = nil;
	for (NSString *entry in entries) {
		BOOL bothSeparators = [entry isEqualToString:kFxPresetsMenuEntry_Separator]
			&& [previous isEqualToString:kFxPresetsMenuEntry_Separator];
		XCTAssertFalse(bothSeparators, @"%@", entries);
		previous = entry;
	}
}

/*! @abstract With both sections present the menu carries exactly three separators. */
- (void)testEachSectionContributesExactlyOneSeparator
{
	[self writeUserPresetNamed:@"Ambient"];
	[self writeUserPresetNamed:@"Cool"];
	[self writePluginPresetNamed:@"Bundled"];

	NSCountedSet *counts = [NSCountedSet setWithArray:[self taggedEntries]];

	XCTAssertEqual([counts countForObject:kFxPresetsMenuEntry_Separator], (NSUInteger)3);
}

/*! @abstract A preset name reaches the menu unchanged. */
- (void)testThePresetNameReachesTheMenuUnchanged
{
	[self writeUserPresetNamed:@"Warm Look 2"];

	XCTAssertEqualObjects([self taggedEntries][2], @"Warm Look 2");
}

#pragma mark addParameter:toEffect:

/*! @abstract Creation registers a popup-menu parameter carrying the computed entries. */
- (void)testAddParameterCreatesAPopupMenuCarryingTheEntries
{
	[self writeUserPresetNamed:@"Ambient"];

	XCTAssertTrue([FxGripPresetsParameter addParameter:[self taggedConfig] toEffect:(id)self.effect]);

	NSDictionary *call = self.effect.apiManager.paramCreateAPIv5.lastCall;
	XCTAssertEqualObjects(call[@"method"], @"menu");
	XCTAssertEqualObjects(call[@"name"], @"Preset");
	XCTAssertEqualObjects(call[@"id"], @(kPresetsParamTestParameter));
	XCTAssertEqualObjects(call[@"items"], [self taggedEntries]);
}

/*! @abstract Creation selects the default entry at index zero. */
- (void)testAddParameterSelectsTheDefaultEntry
{
	XCTAssertTrue([FxGripPresetsParameter addParameter:[self taggedConfig] toEffect:(id)self.effect]);

	XCTAssertEqualObjects(self.effect.apiManager.paramCreateAPIv5.lastCall[@"default"], @0);
}

/*! @abstract Creation keeps the default entry selected even when the configuration names another default index. */
- (void)testAddParameterKeepsTheDefaultEntryEvenWhenTheConfigurationNamesAnother
{
	NSDictionary *config = [self configWithExtra:@{kFxParameterProperty_Tags: @[kPresetsParamTestTag],
												   kFxParameterProperty_Default: @3}];

	XCTAssertTrue([FxGripPresetsParameter addParameter:config toEffect:(id)self.effect]);

	XCTAssertEqualObjects(self.effect.apiManager.paramCreateAPIv5.lastCall[@"default"], @0);
}

/*! @abstract Creation forwards the declared flags to the host. */
- (void)testAddParameterForwardsTheDeclaredFlags
{
	NSDictionary *config = [self configWithExtra:@{kFxParameterProperty_Tags: @[kPresetsParamTestTag],
												   kFxParameterProperty_Flags: @(kFxParameterFlag_HIDDEN)}];

	XCTAssertTrue([FxGripPresetsParameter addParameter:config toEffect:(id)self.effect]);

	XCTAssertEqualObjects(self.effect.apiManager.paramCreateAPIv5.lastCall[@"flags"],
						  @(kFxParameterFlag_HIDDEN));
}

/*! @abstract A host that refuses creation makes the add call return false. */
- (void)testAddParameterReportsAHostRefusal
{
	self.effect.apiManager.paramCreateAPIv5.succeeds = NO;

	XCTAssertFalse([FxGripPresetsParameter addParameter:[self taggedConfig] toEffect:(id)self.effect]);
}

#pragma mark Type identity

/*! @abstract The parameter reports the presets FxPlug type and the matching type string. */
- (void)testThePresetsParameterReportsItsTypeAndTypeString
{
	XCTAssertEqual(FxGripPresetsParameter.parameterType, FxParameterType_Presets);
	XCTAssertEqualObjects(FxGripPresetsParameter.parameterTypeString, kFxParameterType_Presets);
}

/*! @abstract The effect resolves the presets type string and type to the presets parameter class. */
- (void)testTheEffectResolvesThePresetsTypeToThePresetsParameterClass
{
	FxGripPresetsParamTestHostEffect *effect = [FxGripPresetsParamTestHostEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	XCTAssertNotNil(effect);

	XCTAssertEqualObjects([effect parameterClassWithTypeString:kFxParameterType_Presets],
						  FxGripPresetsParameter.class);
	XCTAssertEqualObjects([effect parameterClassWithType:FxParameterType_Presets],
						  FxGripPresetsParameter.class);
	XCTAssertEqual([effect parameterTypeWithString:kFxParameterType_Presets], FxParameterType_Presets);
}

#pragma mark Change dispatch

/*! @abstract A change notification naming another parameter is ignored and reads no value. */
- (void)testAChangeNamingAnotherParameterIsIgnored
{
	[self writeUserPresetNamed:@"Ambient"];
	[self makeParameter];
	self.effect.apiManager.paramGetAPIv6.intValue = 2;

	[self postChangeForParameter:kPresetsParamTestOtherParameter atTime:FxGripParamClassTestTime(9, 30)];

	XCTAssertEqual(self.presetsAPI.applyCount, (NSUInteger)0);
	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.reads, @[]);
}

/*! @abstract A change whose identifier is a string rather than a number is ignored. */
- (void)testAChangeWithoutAParameterIdIsIgnored
{
	[self writeUserPresetNamed:@"Ambient"];
	[self makeParameter];
	self.effect.apiManager.paramGetAPIv6.intValue = 2;

	[self.effect.notifier postNotificationName:FxGripTileableEffectParameterChangedName
										object:self.effect
									  userInfo:@{FxGripTileableEffectParameterChangedIDKey: @"71"}];

	XCTAssertEqual(self.presetsAPI.applyCount, (NSUInteger)0,
				   @"the identifier must be a number, not a string spelling the same value");
	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.reads, @[]);
}

/*! @abstract The selected index is read from the host at the notification's time. */
- (void)testTheSelectedIndexIsReadAtTheNotificationTime
{
	[self makeParameter];

	[self selectIndex:0 atTime:FxGripParamClassTestTime(13, 30)];

	NSDictionary *read = self.effect.apiManager.paramGetAPIv6.lastRead;
	XCTAssertEqualObjects(read[@"accessor"], @"int");
	XCTAssertEqualObjects(read[@"id"], @(kPresetsParamTestParameter));
	XCTAssertEqualObjects(read[@"timevalue"], @13);
	XCTAssertEqualObjects(read[@"timescale"], @30);
}

/*! @abstract A change carrying no time reads the value at time zero. */
- (void)testAChangeWithoutATimeReadsTheValueAtTimeZero
{
	[self makeParameter];
	self.effect.apiManager.paramGetAPIv6.intValue = 0;

	[self postUntimedChangeForParameter:kPresetsParamTestParameter];

	XCTAssertEqualObjects(self.effect.apiManager.paramGetAPIv6.lastRead[@"timevalue"], @0);
	XCTAssertEqualObjects([self recordedSelection], kFxPresetsMenuEntry_Default);
}

/*! @abstract A selected-index read the host refuses applies no preset and records no selection. */
- (void)testAValueTheHostRefusesLeavesTheSelectionAlone
{
	[self writeUserPresetNamed:@"Ambient"];
	[self makeParameter];
	self.effect.apiManager.paramGetAPIv6.succeeds = NO;

	[self selectIndex:2];

	XCTAssertEqual(self.presetsAPI.applyCount, (NSUInteger)0);
	XCTAssertNil([self recordedSelection]);
}

/*! @abstract Selecting a separator index applies no preset and records no selection. */
- (void)testASeparatorSelectionChangesNothing
{
	[self writeUserPresetNamed:@"Ambient"];
	[self makeParameter];

	[self selectIndex:1];

	XCTAssertEqual(self.presetsAPI.applyCount, (NSUInteger)0);
	XCTAssertNil([self recordedSelection]);
}

/*! @abstract An index beyond the menu applies no preset and records no selection. */
- (void)testAnIndexBeyondTheMenuChangesNothing
{
	[self makeParameter];

	[self selectIndex:99];

	XCTAssertEqual(self.presetsAPI.applyCount, (NSUInteger)0);
	XCTAssertNil([self recordedSelection]);
}

/*! @abstract A negative index applies no preset and records no selection. */
- (void)testANegativeIndexChangesNothing
{
	[self makeParameter];

	[self selectIndex:-1];

	XCTAssertEqual(self.presetsAPI.applyCount, (NSUInteger)0);
	XCTAssertNil([self recordedSelection]);
}

/*! @abstract Selecting the default entry records its name and applies no preset. */
- (void)testTheDefaultEntryRecordsItsNameWithoutApplyingAPreset
{
	[self makeParameter];

	[self selectIndex:0];

	XCTAssertEqualObjects([self recordedSelection], kFxPresetsMenuEntry_Default);
	XCTAssertEqual(self.presetsAPI.applyCount, (NSUInteger)0);
}

/*! @abstract Selecting a preset applies it with the default options at the notification's time. */
- (void)testAPresetSelectionAppliesThePresetAtTheNotificationTime
{
	FxGripPreset *written = [self writeUserPresetNamed:@"Ambient"];
	[self makeParameter];

	[self selectIndex:2 atTime:FxGripParamClassTestTime(13, 30)];

	XCTAssertEqual(self.presetsAPI.applyCount, (NSUInteger)1);
	XCTAssertEqualObjects(self.presetsAPI.appliedPreset.name, @"Ambient");
	XCTAssertEqualObjects(self.presetsAPI.appliedPreset.uuid, written.uuid);
	XCTAssertEqual(self.presetsAPI.appliedOptions, (FxGripParameterPresetFlags)kFxParameterPreset_Default);
	XCTAssertEqual(self.presetsAPI.appliedTime.value, (int64_t)13);
	XCTAssertEqual(self.presetsAPI.appliedTime.timescale, (int32_t)30);
}

/*! @abstract Selecting a preset records the applied preset's name. */
- (void)testAPresetSelectionRecordsTheAppliedName
{
	[self writeUserPresetNamed:@"Ambient"];
	[self makeParameter];

	[self selectIndex:2];

	XCTAssertEqualObjects([self recordedSelection], @"Ambient");
}

/*! @abstract A preset application that fails records no selection. */
- (void)testAnApplicationThatFailsRecordsNothing
{
	[self writeUserPresetNamed:@"Ambient"];
	[self makeParameter];
	self.presetsAPI.applyError = [NSError errorWithDomain:@"FxGripPresetsParameterTest" code:7 userInfo:nil];

	[self selectIndex:2];

	XCTAssertEqual(self.presetsAPI.applyCount, (NSUInteger)1);
	XCTAssertNil([self recordedSelection]);
}

/*! @abstract A user preset shadows a plugin preset of the same name, so the user one applies. */
- (void)testAUserPresetShadowsThePluginPresetOfTheSameName
{
	FxGripPreset *userPreset = [self writeUserPresetNamed:@"Shared"];
	FxGripPreset *pluginPreset = [self writePluginPresetNamed:@"Shared"];
	[self makeParameter];

	[self selectIndex:2];

	XCTAssertEqualObjects(self.presetsAPI.appliedPreset.uuid, userPreset.uuid);
	XCTAssertNotEqualObjects(self.presetsAPI.appliedPreset.uuid, pluginPreset.uuid);
}

/*! @abstract A plugin preset applies from its own section and records its name. */
- (void)testAPluginPresetAppliesFromItsOwnSection
{
	FxGripPreset *pluginPreset = [self writePluginPresetNamed:@"Bundled"];
	[self writeUserPresetNamed:@"Ambient"];
	[self makeParameter];

	[self selectIndex:4];

	XCTAssertEqualObjects(self.presetsAPI.appliedPreset.uuid, pluginPreset.uuid);
	XCTAssertEqualObjects([self recordedSelection], @"Bundled");
}

/*! @abstract An entry naming no known preset applies nothing and records nothing. */
- (void)testAnEntryNamingNoKnownPresetAppliesNothingAndRecordsNothing
{
	[self makeParameter];
	[self stageStoredMenu:@[kFxPresetsMenuEntry_Default, kFxPresetsMenuEntry_Separator, @"Ghost",
							kFxPresetsMenuEntry_Separator, kFxPresetsMenuEntry_Reveal, kFxPresetsMenuEntry_Save]];

	[self selectIndex:2];

	XCTAssertEqual(self.presetsAPI.applyCount, (NSUInteger)0);
	XCTAssertNil([self recordedSelection]);
}

/*! @abstract A configuration with no tag resolves no preset for a selected entry. */
- (void)testAConfigurationWithoutATagResolvesNoPreset
{
	[self writeUserPresetNamed:@"Ambient"];
	FxGripPresetsParamTestParameter *parameter =
		[FxGripPresetsParamTestParameter.alloc initWithDictionary:[self configWithExtra:nil] effect:(id)self.effect];
	[self.retainedParameters addObject:parameter];
	[self stageStoredMenu:@[kFxPresetsMenuEntry_Default, kFxPresetsMenuEntry_Separator, @"Ambient",
							kFxPresetsMenuEntry_Separator, kFxPresetsMenuEntry_Reveal, kFxPresetsMenuEntry_Save]];

	[self selectIndex:2];

	XCTAssertEqual(self.presetsAPI.applyCount, (NSUInteger)0);
	XCTAssertNil([self recordedSelection]);
}

#pragma mark Index resolution

/*! @abstract The index resolves against the stored menu rather than a fresh rebuild. */
- (void)testTheStoredMenuResolvesTheIndexAheadOfARebuild
{
	[self writeUserPresetNamed:@"Ambient"];
	FxGripPreset *cool = [self writeUserPresetNamed:@"Cool"];
	[self makeParameter];
	[self stageStoredMenu:@[kFxPresetsMenuEntry_Default, kFxPresetsMenuEntry_Separator, @"Cool", @"Ambient",
							kFxPresetsMenuEntry_Separator, kFxPresetsMenuEntry_Reveal, kFxPresetsMenuEntry_Save]];

	[self selectIndex:2];

	XCTAssertEqualObjects(self.presetsAPI.appliedPreset.uuid, cool.uuid,
						  @"the recorded position names Cool, while a rebuild would name Ambient");
}

/*! @abstract The entries are rebuilt to resolve an index when no menu was stored. */
- (void)testTheEntriesAreRebuiltWhenNoMenuWasStored
{
	[self writeUserPresetNamed:@"Ambient"];
	FxGripPresetsParamTestParameter *parameter = [self makeParameter];

	XCTAssertEqualObjects([parameter menuEntryNameAtIndex:2], @"Ambient");
}

/*! @abstract A non-array stored menu falls back to a rebuild to resolve the index. */
- (void)testANonArrayStoredMenuFallsBackToARebuild
{
	[self writeUserPresetNamed:@"Ambient"];
	FxGripPresetsParamTestParameter *parameter = [self makeParameter];
	self.effect.parameterData.menusByParameter[@(kPresetsParamTestParameter)] = (id)@"not a menu";

	XCTAssertEqualObjects([parameter menuEntryNameAtIndex:2], @"Ambient");
}

#pragma mark Action entries

/*! @abstract Selecting the reveal entry runs the reveal action at the notification's time. */
- (void)testTheRevealEntryRunsTheRevealActionAtTheNotificationTime
{
	FxGripPresetsParamTestParameter *parameter = [self makeParameter];

	[self selectIndex:2 atTime:FxGripParamClassTestTime(13, 30)];

	XCTAssertEqual(parameter.revealCount, (NSUInteger)1);
	XCTAssertEqual(parameter.saveCount, (NSUInteger)0);
	XCTAssertEqual(parameter.actionTime.value, (int64_t)13);
	XCTAssertEqual(parameter.actionTime.timescale, (int32_t)30);
}

/*! @abstract Selecting the save entry runs the save action at the notification's time. */
- (void)testTheSaveEntryRunsTheSaveActionAtTheNotificationTime
{
	FxGripPresetsParamTestParameter *parameter = [self makeParameter];

	[self selectIndex:3 atTime:FxGripParamClassTestTime(13, 30)];

	XCTAssertEqual(parameter.saveCount, (NSUInteger)1);
	XCTAssertEqual(parameter.revealCount, (NSUInteger)0);
	XCTAssertEqual(parameter.actionTime.value, (int64_t)13);
}

/*! @abstract Selecting an action entry applies no preset and records no selection. */
- (void)testAnActionEntryAppliesNoPreset
{
	[self writeUserPresetNamed:@"Ambient"];
	[self makeParameter];

	[self selectIndex:4];

	XCTAssertEqual(self.presetsAPI.applyCount, (NSUInteger)0);
	XCTAssertNil([self recordedSelection]);
}

#pragma mark restoreSelectionAtTime:

/*! @abstract Restoring the selection writes the recorded name's position in the stored menu. */
- (void)testTheRestoredIndexIsTheRecordedNamesPositionInTheStoredMenu
{
	[self writeUserPresetNamed:@"Ambient"];
	[self writeUserPresetNamed:@"Cool"];
	FxGripPresetsParamTestParameter *parameter = [self makeParameter];
	[self stageStoredMenu:@[kFxPresetsMenuEntry_Default, kFxPresetsMenuEntry_Separator, @"Zeta", @"Ambient", @"Cool",
							kFxPresetsMenuEntry_Separator, kFxPresetsMenuEntry_Reveal, kFxPresetsMenuEntry_Save]];
	[self recordSelection:@"Cool"];

	[parameter restoreSelectionAtTime:FxGripParamClassTestTime(13, 30)];

	NSDictionary *write = self.effect.apiManager.paramSetAPIv5.lastWrite;
	XCTAssertEqualObjects(write[@"accessor"], @"int");
	XCTAssertEqualObjects(write[@"id"], @(kPresetsParamTestParameter));
	XCTAssertEqualObjects(write[@"value"], @4, @"the rebuilt menu would place Cool at index 3");
	XCTAssertEqualObjects(write[@"timevalue"], @13);
}

/*! @abstract Restoring the selection uses the rebuilt menu's position when no menu was stored. */
- (void)testTheRestoredIndexComesFromTheRebuiltMenuWhenNoneWasStored
{
	[self writeUserPresetNamed:@"Ambient"];
	[self writeUserPresetNamed:@"Cool"];
	FxGripPresetsParamTestParameter *parameter = [self makeParameter];
	[self recordSelection:@"Cool"];

	[parameter restoreSelectionAtTime:FxGripParamClassTestTime(0, 1)];

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.lastWrite[@"value"], @3);
}

/*! @abstract The default entry is restored when nothing was recorded. */
- (void)testTheDefaultEntryIsRestoredWhenNothingWasRecorded
{
	[self writeUserPresetNamed:@"Ambient"];
	FxGripPresetsParamTestParameter *parameter = [self makeParameter];

	[parameter restoreSelectionAtTime:FxGripParamClassTestTime(0, 1)];

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.lastWrite[@"value"], @0);
}

/*! @abstract The default entry is restored when the recorded name has left the menu. */
- (void)testTheDefaultEntryIsRestoredWhenTheRecordedNameLeftTheMenu
{
	[self writeUserPresetNamed:@"Ambient"];
	FxGripPresetsParamTestParameter *parameter = [self makeParameter];
	[self recordSelection:@"Removed"];

	[parameter restoreSelectionAtTime:FxGripParamClassTestTime(0, 1)];

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.lastWrite[@"value"], @0);
}

/*! @abstract The default entry is restored for an effect with no meta. */
- (void)testTheDefaultEntryIsRestoredForAnEffectWithoutMeta
{
	FxGripPresetsParamTestParameter *parameter = [self makeParameter];
	self.effect.hasMeta = NO;

	[parameter restoreSelectionAtTime:FxGripParamClassTestTime(0, 1)];

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.lastWrite[@"value"], @0);
}

#pragma mark Meta gating

/*! @abstract An effect with no meta still applies the preset but records no selection. */
- (void)testAnEffectWithoutMetaRecordsNoSelection
{
	[self writeUserPresetNamed:@"Ambient"];
	[self makeParameter];
	self.effect.hasMeta = NO;

	[self selectIndex:2];

	XCTAssertEqual(self.presetsAPI.applyCount, (NSUInteger)1, @"the preset still applies");
	XCTAssertNil([self recordedSelection]);
}

/*! @abstract The selection is recorded on the parameter it names and not on another parameter. */
- (void)testTheSelectionIsRecordedOnTheParameterItNames
{
	[self writeUserPresetNamed:@"Ambient"];
	[self makeParameter];

	[self selectIndex:2];

	XCTAssertEqualObjects([self recordedSelection], @"Ambient");
	XCTAssertNil([self recordedSelectionOfParameter:kPresetsParamTestOtherParameter]);
}

#pragma mark Notifications

/*! @abstract The parameter's priority for the change notification follows the meta trigger priority. */
- (void)testThePriorityOfTheChangeNotificationFollowsTheMetaTrigger
{
	FxGripPresetsParamTestParameter *parameter = [self makeParameter];

	XCTAssertEqual([parameter ncPriority:FxGripTileableEffectParameterChangedName], (NSInteger)-8);
}

/*! @abstract Every other notification keeps the base priority. */
- (void)testEveryOtherNotificationKeepsTheBasePriority
{
	FxGripPresetsParamTestParameter *parameter = [self makeParameter];

	XCTAssertEqual([parameter ncPriority:FxGripNotifyAPI_ParameterGetFlagsPreName], (NSInteger)-17);
	XCTAssertEqual([parameter ncPriority:FxGripNotifyAPI_ParameterSetFlagsName], (NSInteger)-19);
	XCTAssertEqual([parameter ncPriority:nil], (NSInteger)-19);
}

/*! The override calls super, so the base flag observers stay installed. */
- (void)testTheBaseFlagObserversAreInstalledAlongsideTheChangeObserver
{
	NSMutableDictionary *config = [self taggedConfig];
	config[kFxParameterProperty_Flags] = @(kFxParameterFlag_CACHE | kFxParameterFlag_HIDDEN);
	FxGripPresetsParamTestParameter *parameter =
		[FxGripPresetsParamTestParameter.alloc initWithDictionary:config effect:(id)self.effect];
	[self.retainedParameters addObject:parameter];

	NSMutableDictionary *nested = NSMutableDictionary.new;
	nested[kFxParameterProperty_Id] = @(kPresetsParamTestParameter);
	nested[kFxParameterProperty_Flags] = @(kFxParameterFlag_DEFAULT);
	NSMutableDictionary *userInfo = NSMutableDictionary.new;
	userInfo[kFxParameterProperty_Id] = @(kPresetsParamTestParameter);
	userInfo.fxParameter = nested;

	[self.effect.notifier postNotificationName:FxGripNotifyAPI_ParameterGetFlagsPreName
										object:self.effect
									  userInfo:userInfo];

	XCTAssertEqualObjects(userInfo.fxResult, @YES);
	XCTAssertEqualObjects(userInfo.fxParameter[kFxParameterProperty_Flags],
						  @(kFxParameterFlag_CACHE | kFxParameterFlag_HIDDEN));
}

/*! @abstract After removeObservers, a selection change applies no preset. */
- (void)testRemovingTheObserversEndsTheSelectionHandling
{
	[self writeUserPresetNamed:@"Ambient"];
	FxGripPresetsParamTestParameter *parameter = [self makeParameter];

	[parameter removeObservers];
	[self selectIndex:2];

	XCTAssertEqual(self.presetsAPI.applyCount, (NSUInteger)0);
}

#pragma mark Watcher attachment

/*! @abstract The folder watcher attaches when the user preset folder exists at install. */
- (void)testTheWatcherAttachesWhenTheUserPresetFolderExistsAtInstall
{
	[self createUserTagFolder];

	FxGripPresetsParamTestParameter *parameter = [self makeParameter];

	XCTAssertNotNil([self watcherOfParameter:parameter]);
}

/*! @abstract No watcher attaches while the user preset folder is absent. */
- (void)testNoWatcherAttachesWhileTheUserPresetFolderIsAbsent
{
	FxGripPresetsParamTestParameter *parameter = [self makeParameter];

	XCTAssertNil([self watcherOfParameter:parameter]);
}

/*! @abstract No watcher attaches for a configuration with no tag. */
- (void)testNoWatcherAttachesForAConfigurationWithoutATag
{
	[self createUserTagFolder];

	FxGripPresetsParameter *parameter =
		[FxGripPresetsParameter.alloc initWithDictionary:[self configWithExtra:nil] effect:(id)self.effect];
	[self.retainedParameters addObject:parameter];

	XCTAssertNil([self watcherOfParameter:parameter]);
}

/*! The reveal and save actions attach after creating the folder. */
- (void)testTheWatcherAttachesOnceTheFolderAppears
{
	FxGripPresetsParamTestParameter *parameter = [self makeParameter];
	XCTAssertNil([self watcherOfParameter:parameter]);

	[self createUserTagFolder];
	[parameter attachUserPresetWatcher];

	XCTAssertNotNil([self watcherOfParameter:parameter]);
}

/*! @abstract A second attach keeps the first watcher. */
- (void)testASecondAttachKeepsTheFirstWatcher
{
	[self createUserTagFolder];
	FxGripPresetsParamTestParameter *parameter = [self makeParameter];
	id watcher = [self watcherOfParameter:parameter];

	[parameter attachUserPresetWatcher];

	XCTAssertEqual([self watcherOfParameter:parameter], watcher);
}

/*! @abstract removeObservers releases the folder watcher. */
- (void)testRemovingTheObserversReleasesTheWatcher
{
	[self createUserTagFolder];
	FxGripPresetsParamTestParameter *parameter = [self makeParameter];
	XCTAssertNotNil([self watcherOfParameter:parameter]);

	[parameter removeObservers];

	XCTAssertNil([self watcherOfParameter:parameter]);
}

/*! @abstract A folder change after removeObservers refreshes nothing. */
- (void)testAFolderChangeAfterTheObserversAreRemovedRefreshesNothing
{
	[self createUserTagFolder];
	FxGripPresetsParamTestParameter *parameter = [self makeParameter];
	[parameter removeObservers];

	[self writeUserPresetNamed:@"Cool"];
	[self waitForMenuRefreshWithin:1.0];

	XCTAssertEqual(self.dynamicAPI.menuCalls.count, (NSUInteger)0);
}

/*! A watcher stops for good when its folder is deleted; re-attaching after the folder
	returns discards the stopped watcher and resumes the live refresh. */
- (void)testTheWatcherFollowsAFolderThatIsRemovedAndRecreated
{
	[self createUserTagFolder];
	FxGripPresetsParamTestParameter *parameter = [self makeParameter];
	XCTAssertTrue([NSFileManager.defaultManager removeItemAtURL:[self userTagFolderURL] error:NULL]);
	// The removal is itself a change, and it reaches the menu before the folder returns.
	[self waitForMenuRefreshWithin:2.0];
	[self createUserTagFolder];
	[parameter attachUserPresetWatcher];
	[self.dynamicAPI.menuCalls removeAllObjects];

	[self writeUserPresetNamed:@"Cool"];

	XCTAssertTrue([self waitFor:^BOOL {
		return [self.dynamicAPI.lastMenuCall[@"items"] containsObject:@"Cool"];
	} within:10.0]);
}

#pragma mark refreshMenuEntriesAtTime:

/*! @abstract A refresh pushes the current menu entries and the default index to the host. */
- (void)testARefreshPushesTheCurrentEntriesToTheHost
{
	[self writeUserPresetNamed:@"Ambient"];
	FxGripPresetsParamTestParameter *parameter = [self makeParameter];
	[self writeUserPresetNamed:@"Cool"];

	[parameter refreshMenuEntriesAtTime:FxGripParamClassTestTime(0, 1)];

	XCTAssertEqual(self.dynamicAPI.menuCalls.count, (NSUInteger)1);
	NSDictionary *call = self.dynamicAPI.lastMenuCall;
	XCTAssertEqualObjects(call[@"id"], @(kPresetsParamTestParameter));
	XCTAssertEqualObjects(call[@"items"], (@[kFxPresetsMenuEntry_Default,
											 kFxPresetsMenuEntry_Separator,
											 @"Ambient", @"Cool",
											 kFxPresetsMenuEntry_Separator,
											 kFxPresetsMenuEntry_Reveal,
											 kFxPresetsMenuEntry_Save]));
	XCTAssertEqualObjects(call[@"default"], @0);
}

/*! @abstract A refresh runs inside a single out-of-band access context. */
- (void)testARefreshRunsInsideAnOutOfBandAccessContext
{
	FxGripPresetsParamTestParameter *parameter = [self makeParameter];

	[parameter refreshMenuEntriesAtTime:FxGripParamClassTestTime(0, 1)];

	XCTAssertEqual(self.effect.startContextCount, (NSUInteger)1);
}

/*! @abstract A refresh restores the recorded selection at its new index after the menu changes. */
- (void)testARefreshRestoresTheRecordedSelectionAtItsNewIndex
{
	[self writeUserPresetNamed:@"Ambient"];
	FxGripPresetsParamTestParameter *parameter = [self makeParameter];
	[self recordSelection:@"Ambient"];
	[self writeUserPresetNamed:@"Aaa"];

	[parameter refreshMenuEntriesAtTime:FxGripParamClassTestTime(0, 1)];

	XCTAssertEqualObjects(self.dynamicAPI.lastMenuCall[@"items"][2], @"Aaa");
	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.lastWrite[@"value"], @3,
						  @"the added preset moved Ambient one place down");
}

/*! @abstract A refresh resolves the recorded selection through the stored menu when restoring. */
- (void)testARefreshResolvesTheRecordedSelectionThroughTheStoredMenu
{
	[self writeUserPresetNamed:@"Ambient"];
	[self writeUserPresetNamed:@"Cool"];
	FxGripPresetsParamTestParameter *parameter = [self makeParameter];
	[self stageStoredMenu:@[kFxPresetsMenuEntry_Default, kFxPresetsMenuEntry_Separator, @"Zeta", @"Ambient", @"Cool",
							kFxPresetsMenuEntry_Separator, kFxPresetsMenuEntry_Reveal, kFxPresetsMenuEntry_Save]];
	[self recordSelection:@"Cool"];

	[parameter refreshMenuEntriesAtTime:FxGripParamClassTestTime(0, 1)];

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.lastWrite[@"value"], @4,
						  @"the rebuilt menu would place Cool at index 3");
}

/*! @abstract A refresh restores the default entry when nothing was recorded. */
- (void)testARefreshRestoresTheDefaultEntryWhenNothingWasRecorded
{
	[self writeUserPresetNamed:@"Ambient"];
	FxGripPresetsParamTestParameter *parameter = [self makeParameter];

	[parameter refreshMenuEntriesAtTime:FxGripParamClassTestTime(0, 1)];

	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.lastWrite[@"value"], @0);
}

/*! @abstract A refresh restores the default entry when the recorded name has left the menu. */
- (void)testARefreshRestoresTheDefaultEntryWhenTheRecordedNameLeftTheMenu
{
	FxGripPreset *preset = [self writeUserPresetNamed:@"Ambient"];
	FxGripPresetsParamTestParameter *parameter = [self makeParameter];
	[self recordSelection:@"Ambient"];
	NSString *fileName = [preset.name stringByAppendingPathExtension:kFxPreset_Extension];
	XCTAssertTrue([NSFileManager.defaultManager
				   removeItemAtURL:[[self userTagFolderURL] URLByAppendingPathComponent:fileName] error:NULL]);

	[parameter refreshMenuEntriesAtTime:FxGripParamClassTestTime(0, 1)];

	XCTAssertFalse([self.dynamicAPI.lastMenuCall[@"items"] containsObject:@"Ambient"]);
	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.lastWrite[@"value"], @0);
}

/*! @abstract A refresh restores the selection at the given time. */
- (void)testARefreshRestoresTheSelectionAtTheGivenTime
{
	[self writeUserPresetNamed:@"Ambient"];
	FxGripPresetsParamTestParameter *parameter = [self makeParameter];
	[self recordSelection:@"Ambient"];

	[parameter refreshMenuEntriesAtTime:FxGripParamClassTestTime(13, 30)];

	NSDictionary *write = self.effect.apiManager.paramSetAPIv5.lastWrite;
	XCTAssertEqualObjects(write[@"accessor"], @"int");
	XCTAssertEqualObjects(write[@"value"], @2);
	XCTAssertEqualObjects(write[@"timevalue"], @13);
}

/*! @abstract A host refusal of the menu rebuild leaves the selection untouched. */
- (void)testAHostRefusalOfTheMenuRebuildLeavesTheSelectionUntouched
{
	[self writeUserPresetNamed:@"Ambient"];
	FxGripPresetsParamTestParameter *parameter = [self makeParameter];
	[self recordSelection:@"Ambient"];
	self.dynamicAPI.menuError = [NSError errorWithDomain:@"FxGripPresetsParameterTest" code:9 userInfo:nil];

	[parameter refreshMenuEntriesAtTime:FxGripParamClassTestTime(0, 1)];

	XCTAssertEqual(self.dynamicAPI.menuCalls.count, (NSUInteger)1);
	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.writes, @[]);
}

#pragma mark Folder change delivery

/*! @abstract A folder change queues the menu refresh on the main queue rather than running it immediately. */
- (void)testAFolderChangeRefreshesTheMenuOnTheMainQueue
{
	[self writeUserPresetNamed:@"Ambient"];
	FxGripPresetsParamTestParameter *parameter = [self makeParameter];

	[parameter userPresetFolderChanged:nil];

	XCTAssertEqual(self.dynamicAPI.menuCalls.count, (NSUInteger)0, @"the refresh is queued, not immediate");
	XCTAssertTrue([self waitForMenuRefreshWithin:5.0]);
	XCTAssertEqualObjects(self.dynamicAPI.lastMenuCall[@"id"], @(kPresetsParamTestParameter));
	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.lastWrite[@"timevalue"], @0,
						  @"the queued refresh restores at time zero");
}

/*! The one test that leaves the deterministic path and waits on the filesystem. */
- (void)testWritingAPresetIntoTheWatchedFolderRefreshesTheMenu
{
	[self createUserTagFolder];
	FxGripPresetsParamTestParameter *parameter = [self makeParameter];
	XCTAssertNotNil([self watcherOfParameter:parameter]);

	[self writeUserPresetNamed:@"Cool"];

	BOOL refreshed = [self waitFor:^BOOL {
		return [self.dynamicAPI.lastMenuCall[@"items"] containsObject:@"Cool"];
	} within:10.0];
	XCTAssertTrue(refreshed, @"the watched folder delivered no change carrying the new preset");
}

#pragma mark Save action refresh

/*! @abstract A successful save attaches the watcher and refreshes the menu with the new preset. */
- (void)testASuccessfulSaveAttachesTheWatcherAndRefreshesTheMenu
{
	FxGripPresetsParameter *parameter = [self makeUnwrappedParameter];
	XCTAssertNil([self watcherOfParameter:parameter], @"the folder does not exist yet");
	self.presetsAPI.generatedPreset = [self presetNamed:@"Fresh"];
	self.presetsAPI.saveSucceeds = YES;
	__weak typeof(self) weakSelf = self;
	self.presetsAPI.saveHandler = ^(FxGripPreset *preset) {
		[weakSelf writeUserPresetNamed:preset.name];
	};

	[parameter saveCurrentStateAsPresetAtTime:FxGripParamClassTestTime(0, 1)];

	XCTAssertNotNil([self watcherOfParameter:parameter]);
	XCTAssertEqual(self.dynamicAPI.menuCalls.count, (NSUInteger)1);
	XCTAssertTrue([self.dynamicAPI.lastMenuCall[@"items"] containsObject:@"Fresh"]);
}

/*! @abstract A successful save restores the selection exactly once. */
- (void)testASuccessfulSaveRestoresTheSelectionOnce
{
	FxGripPresetsParameter *parameter = [self makeUnwrappedParameter];
	self.presetsAPI.generatedPreset = [self presetNamed:@"Fresh"];
	self.presetsAPI.saveSucceeds = YES;
	__weak typeof(self) weakSelf = self;
	self.presetsAPI.saveHandler = ^(FxGripPreset *preset) {
		[weakSelf writeUserPresetNamed:preset.name];
	};
	[self recordSelection:@"Fresh"];

	[parameter saveCurrentStateAsPresetAtTime:FxGripParamClassTestTime(0, 1)];

	XCTAssertEqual(self.effect.apiManager.paramSetAPIv5.writes.count, (NSUInteger)1,
				   @"the refresh restores the selection, and the save adds no second restore");
	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.lastWrite[@"value"], @2);
}

/*! @abstract The saved preset carries the parameter name as its generate label and the configuration tag. */
- (void)testTheSavedPresetCarriesTheParameterNameAndTheConfigurationTag
{
	FxGripPresetsParameter *parameter = [self makeUnwrappedParameter];
	self.presetsAPI.generatedPreset = [self presetNamed:@"Fresh"];
	self.presetsAPI.saveSucceeds = NO;

	[parameter saveCurrentStateAsPresetAtTime:FxGripParamClassTestTime(0, 1)];

	XCTAssertEqual(self.presetsAPI.generateCount, (NSUInteger)1);
	XCTAssertEqualObjects(self.presetsAPI.generatedLabel, @"Preset");
	XCTAssertEqualObjects(self.presetsAPI.savedPreset.tag, kPresetsParamTestTag);
}

/*! @abstract A save the user abandons restores the selection without refreshing the menu. */
- (void)testASaveTheUserAbandonsRestoresTheSelectionWithoutRefreshing
{
	[self writeUserPresetNamed:@"Ambient"];
	FxGripPresetsParameter *parameter = [self makeUnwrappedParameter];
	self.presetsAPI.generatedPreset = [self presetNamed:@"Fresh"];
	self.presetsAPI.saveSucceeds = NO;
	[self recordSelection:@"Ambient"];

	[parameter saveCurrentStateAsPresetAtTime:FxGripParamClassTestTime(0, 1)];

	XCTAssertEqual(self.presetsAPI.saveCount, (NSUInteger)1);
	XCTAssertEqual(self.dynamicAPI.menuCalls.count, (NSUInteger)0);
	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.lastWrite[@"value"], @2);
}

/*! @abstract A capture the host refuses restores the selection without saving or refreshing. */
- (void)testACaptureTheHostRefusesRestoresTheSelectionWithoutSavingOrRefreshing
{
	[self writeUserPresetNamed:@"Ambient"];
	FxGripPresetsParameter *parameter = [self makeUnwrappedParameter];
	self.presetsAPI.generateError = [NSError errorWithDomain:@"FxGripPresetsParameterTest" code:5 userInfo:nil];

	[parameter saveCurrentStateAsPresetAtTime:FxGripParamClassTestTime(0, 1)];

	XCTAssertEqual(self.presetsAPI.saveCount, (NSUInteger)0);
	XCTAssertEqual(self.dynamicAPI.menuCalls.count, (NSUInteger)0);
	XCTAssertEqualObjects(self.effect.apiManager.paramSetAPIv5.lastWrite[@"value"], @0);
}

#pragma mark Construction

/*! The designated initializer is the construction path the effect uses, so a parameter
	built that way observes and applies. */
- (void)testAParameterBuiltTheWayTheEffectBuildsItHandlesASelection
{
	[self writeUserPresetNamed:@"Ambient"];
	FxGripPresetsParameter *parameter = [FxGripPresetsParameter.alloc initWithDictionary:[self taggedConfig]
																				   effect:(id)self.effect];
	[self.retainedParameters addObject:parameter];

	[self selectIndex:2];

	XCTAssertEqual(self.presetsAPI.applyCount, (NSUInteger)1);
	XCTAssertEqualObjects([self recordedSelection], @"Ambient");
}

@end
