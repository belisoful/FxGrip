//
//  FxTileableEffectBaseCategoriesTests.m
//  FxGripTests
//
//  Unit tests for the FxTileableEffectBase categories: extension loading and
//  lookup, the flush pass, the color-gamut, plugin-property, versioning, timing
//  and project-property delegations to the effect's API manager.
//
//  FxTileableEffectBase registers its observers with the notification center its
//  -notifier getter returns. Every effect built here is an instance of a local
//  subclass that returns a private NSPriorityNotificationCenter, so no test
//  touches the process-wide center.
//

#import <XCTest/XCTest.h>
#import <dlfcn.h>
#import <CoreMedia/CoreMedia.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripErrors.h>
#import <FxGrip/FxExtension.h>
#import <FxGrip/FxAPINotifications.h>
#import <FxGrip/FxTileableEffectBase.h>
#import <FxGrip/FxTileableEffectBase+Notifications.h>
#import <FxGrip/FxTileableEffectBase+Extensions.h>
#import <FxGrip/FxTileableEffectBase+Parameters.h>
#import <FxGrip/FxTileableEffectBase+ColorGamut.h>
#import <FxGrip/FxGripColorGamut.h>
#import <FxGrip/FxTileableEffectBase+PluginProperties.h>
#import <FxGrip/FxTileableEffectBase+Versioning.h>
#import <FxGrip/FxTileableEffectBase+Timing.h>
#import <FxGrip/FxTileableEffectBase+ProjectProperties.h>
#import <FxGrip/FxGripParameterData.h>
#import <FxGrip/FxGripDebugMenu.h>
#import <FxGrip/FxGripRegression.h>
#import <FxGrip/FxGripInstanceTracker.h>
#import <FxGrip/FxTileableEffectBase+Analyze.h>
#import <FxGrip/FxGripAnalysis.h>

/*!
	The test bundle links neither CoreMedia nor FxPlug, so the error domain FxGripErrors.h
	names is read from the loaded images the way FxGripMetaTests does.
*/
static NSString *FxCatTestExpectedErrorDomain(void)
{
	NSString * __unsafe_unretained *domain = (NSString * __unsafe_unretained *)dlsym(RTLD_DEFAULT, "FxPlugErrorDomain");
	return domain ? *domain : FxGripPlugErrorDomainConstant;
}

static CMTime FxCatTestMakeTime(int64_t value, int32_t timescale)
{
	return (CMTime){.value = value, .timescale = timescale, .flags = kCMTimeFlags_Valid, .epoch = 0};
}

static BOOL FxCatTestTimesEqual(CMTime lhs, CMTime rhs)
{
	return lhs.value == rhs.value && lhs.timescale == rhs.timescale
		&& lhs.flags == rhs.flags && lhs.epoch == rhs.epoch;
}

static BOOL FxCatTestTimeIsInvalid(CMTime time)
{
	return (time.flags & kCMTimeFlags_Valid) == 0;
}

#pragma mark - Extension doubles

@protocol FxCatTestMarkerProtocol <NSObject>
@end

@interface FxCatTestExtension : FxExtension
@property (nonatomic, assign) NSUInteger initCount;
@end

@implementation FxCatTestExtension
- (void)extInit:(NSNotification *)notification
{
	self.initCount += 1;
}
@end

@interface FxCatTestMarkerExtension : FxExtension <FxCatTestMarkerProtocol>
@end

@implementation FxCatTestMarkerExtension
@end

// Declares a custom parameter type so the effect's type resolution consults it when the
// built-in type map has no entry.
@interface FxCatTestTypeExtension : FxExtension
@end

@implementation FxCatTestTypeExtension
- (FxParameterType)extParameterTypeForString:(NSString *)typeString
{
	return [typeString isEqualToString:@"cattype"] ? (FxParameterType)'CatT' : FxParameterType_None;
}
- (nullable Class)extParameterClassForType:(FxParameterType)type
{
	return type == (FxParameterType)'CatT' ? FxCatTestTypeExtension.class : Nil;
}
@end

// Stands in for a parameter extension: claims FxParameter conformance and records the
// configuration call the loader must make. conformsToProtocol: is overridden so the stub
// need not implement the whole FxParameter surface.
@interface FxCatTestParameterExtension : FxExtension
@property (nonatomic, assign) BOOL configuredFromDictionary;
@property (nonatomic, copy) NSDictionary *configuredData;
- (nullable id)parameterForDictionary:(nullable NSDictionary *)data;
@end

@implementation FxCatTestParameterExtension
- (BOOL)conformsToProtocol:(Protocol *)aProtocol
{
	if (aProtocol == @protocol(FxParameter)) {
		return YES;
	}
	return [super conformsToProtocol:aProtocol];
}
- (nullable id)parameterForDictionary:(nullable NSDictionary *)data
{
	self.configuredFromDictionary = YES;
	self.configuredData = data;
	return self;
}
@end

@interface FxCatTestIndividuatedExtension : FxExtension
@end

@implementation FxCatTestIndividuatedExtension
- (BOOL)extIndividuate
{
	return YES;
}
@end

@interface FxCatTestIncludedWhenDisabledExtension : FxExtension
@end

@implementation FxCatTestIncludedWhenDisabledExtension
- (BOOL)extIncludeWhenDisabled
{
	return YES;
}
@end

/*!
	An extension that implements the protocol without inheriting FxExtensionBase, so the
	loading pass takes the branches that probe for each load selector.
*/
@interface FxCatTestBareExtension : NSObject <FxExtension>
{
	NSString *_bareKey;
	NSInteger _bareKeyIndex;
	NSInteger _barePriority;
	BOOL _bareActive;
	BOOL _bareIncludeWhenDisabled;
	__unsafe_unretained id _bareEffect;
}
@property (nonatomic, assign) BOOL loadResult;
@end

@implementation FxCatTestBareExtension

- (instancetype)init
{
	self = [super init];
	if (self) {
		_bareKey = self.className;
		_bareKeyIndex = -1;
		_barePriority = FxExtensionDefaultPriority;
		_bareActive = YES;
		_bareIncludeWhenDisabled = NO;
		_loadResult = YES;
	}
	return self;
}

- (BOOL)extActive { return _bareActive; }
- (void)setExtActive:(BOOL)active { _bareActive = active; }
- (BOOL)extIncludeWhenDisabled { return _bareIncludeWhenDisabled; }
- (void)setExtIncludeWhenDisabled:(BOOL)include { _bareIncludeWhenDisabled = include; }
- (id<FxTileableEffectBase>)effect { return _bareEffect; }
- (NSString *)extKey { return _bareKey; }
- (NSInteger)extKeyIndex { return _bareKeyIndex; }
- (NSInteger)extDefaultPriority { return _barePriority; }
- (void)setExtDefaultPriority:(NSInteger)priority { _barePriority = priority; }
- (NSInteger)ncPriority:(NSNotificationName)aName { return _barePriority; }

@end

// Announces only the effect-taking load selector.
@interface FxCatTestEffectLoadExtension : FxCatTestBareExtension
@end

@implementation FxCatTestEffectLoadExtension
- (BOOL)extLoadWithEffect:(id<FxTileableEffectBase>)effect
{
	_bareEffect = effect;
	return self.loadResult;
}
@end

// Announces both load selectors, so the index pass runs after the effect pass.
@interface FxCatTestBothLoadsExtension : FxCatTestEffectLoadExtension
@end

@implementation FxCatTestBothLoadsExtension
- (BOOL)extLoadWithIndex:(NSInteger)index
{
	_bareKeyIndex = index;
	return self.loadResult;
}
@end

// Announces only the index-taking load selector.
@interface FxCatTestIndexLoadExtension : FxCatTestBareExtension
@end

@implementation FxCatTestIndexLoadExtension
- (BOOL)extLoadWithIndex:(NSInteger)index
{
	_bareKeyIndex = index;
	return self.loadResult;
}
@end

// Announces no load selector at all.
@interface FxCatTestNoLoadExtension : FxCatTestBareExtension
@end

@implementation FxCatTestNoLoadExtension
@end

// Writes whatever the test installs into the flush notification's userInfo.
@interface FxCatTestFlushExtension : FxExtension
@property (nonatomic, strong) id errorToReport;
@property (nonatomic, assign) NSUInteger flushCount;
@end

@implementation FxCatTestFlushExtension
- (void)extFlush:(NSNotification *)notification
{
	self.flushCount += 1;
	if (self.errorToReport) {
		((NSMutableDictionary *)notification.userInfo)[FxNotifyAPI_ErrorKey] = self.errorToReport;
	}
}
@end

#pragma mark - Host API doubles

@interface FxCatTestStubColorGamutAPI : NSObject
@property (nonatomic, assign) FxColorPrimaries primaries;
@end

@implementation FxCatTestStubColorGamutAPI
- (FxColorPrimaries)colorPrimaries
{
	return self.primaries;
}
@end

@interface FxCatTestStubVersioningAPI : NSObject
@property (nonatomic, assign) unsigned int versionAtCreation;
@property (nonatomic, assign) BOOL updateSucceeds;
@property (nonatomic, assign) UInt32 updatedVersion;
@property (nonatomic, assign) NSUInteger updateCount;
@end

@implementation FxCatTestStubVersioningAPI

- (BOOL)updateVersionAtCreation:(UInt32)newVersion
{
	self.updatedVersion = newVersion;
	self.updateCount += 1;
	return self.updateSucceeds;
}

@end

@interface FxCatTestStubTimingAPI : NSObject
@property (nonatomic, assign) CMTime frameDuration;
@property (nonatomic, assign) CMTime sampleDuration;
@property (nonatomic, assign) CMTime effectStartTime;
@property (nonatomic, assign) CMTime effectDuration;
@property (nonatomic, assign) CMTime inputStartTime;
@property (nonatomic, assign) CMTime inputDuration;
@property (nonatomic, assign) CMTime inPoint;
@property (nonatomic, assign) CMTime outPoint;
@property (nonatomic, assign) CMTime timelineTime;
@property (nonatomic, assign) CMTime inputTime;
@property (nonatomic, assign) CMTime lastInputTimeArgument;
@property (nonatomic, assign) CMTime lastTimelineTimeArgument;
@property (nonatomic, assign) NSUInteger fpsNumerator;
@property (nonatomic, assign) NSUInteger fpsDenominator;
@property (nonatomic, strong) id lastEffectArgument;
@end

@implementation FxCatTestStubTimingAPI

- (instancetype)init
{
	self = [super init];
	if (self) {
		_frameDuration = FxCatTestMakeTime(1, 30);
		_sampleDuration = FxCatTestMakeTime(1, 30);
		_effectStartTime = FxCatTestMakeTime(0, 30);
		_effectDuration = FxCatTestMakeTime(60, 30);
		_inputStartTime = FxCatTestMakeTime(0, 30);
		_inputDuration = FxCatTestMakeTime(90, 30);
		_inPoint = FxCatTestMakeTime(5, 30);
		_outPoint = FxCatTestMakeTime(65, 30);
		_timelineTime = FxCatTestMakeTime(300, 30);
		_inputTime = FxCatTestMakeTime(400, 30);
		_fpsNumerator = 30;
		_fpsDenominator = 1;
	}
	return self;
}

- (void)frameDuration:(CMTime *)duration { *duration = self.frameDuration; }
- (void)sampleDuration:(CMTime *)duration { *duration = self.sampleDuration; }
- (void)startTimeForEffect:(CMTime *)startTime { *startTime = self.effectStartTime; }
- (void)durationTimeForEffect:(CMTime *)duration { *duration = self.effectDuration; }
- (void)startTimeOfInputToFilter:(CMTime *)startTime { *startTime = self.inputStartTime; }
- (void)durationTimeOfInputToFilter:(CMTime *)duration { *duration = self.inputDuration; }
- (void)inPointTimeOfTimelineForEffect:(CMTime *)inPoint { *inPoint = self.inPoint; }
- (void)outPointTimeOfTimelineForEffect:(CMTime *)outPoint { *outPoint = self.outPoint; }

- (void)timelineTime:(CMTime *)timelineTime fromInputTime:(CMTime)time
{
	self.lastInputTimeArgument = time;
	*timelineTime = self.timelineTime;
}

- (void)inputTime:(CMTime *)inputTime fromTimelineTime:(CMTime)time
{
	self.lastTimelineTimeArgument = time;
	*inputTime = self.inputTime;
}

- (NSUInteger)timelineFpsNumeratorForEffect:(id)effect
{
	self.lastEffectArgument = effect;
	return self.fpsNumerator;
}

- (NSUInteger)timelineFpsDenominatorForEffect:(id)effect
{
	self.lastEffectArgument = effect;
	return self.fpsDenominator;
}

@end

@interface FxCatTestStubProjectAPI : NSObject
@property (nonatomic, assign) NSUInteger documentID;
@property (nonatomic, assign) BOOL documentIDSucceeds;
@property (nonatomic, strong) NSURL *mediaFolder;
@property (nonatomic, assign) BOOL mediaFolderSucceeds;
@property (nonatomic, assign) float aspectRatio;
@property (nonatomic, assign) BOOL aspectRatioSucceeds;
@end

@implementation FxCatTestStubProjectAPI

- (BOOL)documentID:(NSUInteger *)documentID error:(NSError **)error
{
	if (!self.documentIDSucceeds) {
		if (error) {
			*error = [NSError errorWithDomain:@"FxCatTest" code:7 userInfo:nil];
		}
		return NO;
	}
	*documentID = self.documentID;
	return YES;
}

- (BOOL)mediaFolderURL:(NSURL **)mediaURL error:(NSError **)error
{
	if (!self.mediaFolderSucceeds) {
		return NO;
	}
	*mediaURL = self.mediaFolder;
	return YES;
}

- (BOOL)projectAspectRatio:(float *)aspectRatio error:(NSError **)error
{
	if (!self.aspectRatioSucceeds) {
		return NO;
	}
	*aspectRatio = self.aspectRatio;
	return YES;
}

@end

@interface FxCatTestStubAPIManager : NSObject
@property (nonatomic, strong) id colorGamutAPIv2;
@property (nonatomic, strong) id versioningAPIv1;
@property (nonatomic, strong) id timingAPIv4;
@property (nonatomic, strong) id projectAPIv1;
@property (nonatomic, strong) id projectAPIv2;
@property (nonatomic, assign) UInt64 sessionID;
@end

@implementation FxCatTestStubAPIManager
@end

#pragma mark - Effect subclass

// Supplies the extension list the effect loads. The effect builds its extensions inside
// its initializer, so the list is installed before construction.
static NSMutableArray *(^gCatTestExtensionBuilder)(void) = nil;

@interface FxCatTestEffect : FxTileableEffectBase
@property (nonatomic, strong) NSNotificationCenter *privateNotifier;
@property (nonatomic, strong) id stubAPIManager;
@property (nonatomic, strong) NSDictionary<NSString *, id> *stubPluginProperties;
@end

@implementation FxCatTestEffect

// The initializer registers its observers through this getter, so the private center is
// created on first use rather than in the subclass initializer.
- (NSPriorityNotificationCenter *)notifier
{
	if (!_privateNotifier) {
		Class cls = NSClassFromString(@"NSPriorityNotificationCenter");
		_privateNotifier = [[cls alloc] init];
	}
	return (NSPriorityNotificationCenter *)_privateNotifier;
}

- (id<FxGripAPIAccessing>)apiManager
{
	if (_stubAPIManager) {
		return (id<FxGripAPIAccessing>)_stubAPIManager;
	}
	return [super apiManager];
}

- (NSDictionary<NSString *, id> *)pluginProperties
{
	if (_stubPluginProperties) {
		return _stubPluginProperties;
	}
	return [super pluginProperties];
}

- (NSMutableArray<id<FxExtension>> *)loadExtensions
{
	if (gCatTestExtensionBuilder) {
		return gCatTestExtensionBuilder();
	}
	return [super loadExtensions];
}

@end

// Refuses every version upgrade.
@interface FxCatTestRefusingEffect : FxCatTestEffect
@end

@implementation FxCatTestRefusingEffect

- (id)effectBase
{
	// The stub plays the full effect; rich reads route back to it, as the old cast did.
	return self;
}


- (BOOL)upgradeFromVersion:(unsigned int)fromVersion
			currentVersion:(unsigned int)currentVersion
					 error:(NSError * _Nullable * _Nullable)error
{
	return NO;
}

@end

// Conforms to FxAnalyzer, so the loader adds the analysis storage extension. Its compute
// hook returns the frame index boxed, ignoring the (test-nil) tile.
@interface FxAnalysisTestEffect : FxCatTestEffect <FxAnalyzer>
@end

@implementation FxAnalysisTestEffect

- (id)effectBase
{
	// The stub plays the full effect; rich reads route back to it, as the old cast did.
	return self;
}

- (id<NSSecureCoding, NSCopying>)analyzeImageTile:(FxImageTile *)frame
										  atTime:(CMTime)frameTime
									  frameIndex:(NSInteger)frameIndex
										   error:(NSError * _Nullable * _Nullable)error
{
	return @(frameIndex);
}
@end

// The test bundle does not link CoreMedia, so times are built as struct literals rather than
// through CMTimeMake.
static CMTime FxAnalysisTestCMTime(int64_t value, int32_t timescale)
{
	return (CMTime){ .value = value, .timescale = timescale, .flags = kCMTimeFlags_Valid, .epoch = 0 };
}

#pragma mark - Tests

@interface FxTileableEffectBaseCategoriesTests : XCTestCase
@property (nonatomic, strong) FxCatTestEffect *effect;
@end

@implementation FxTileableEffectBaseCategoriesTests

- (void)tearDown
{
	gCatTestExtensionBuilder = nil;
	self.effect = nil;
	[super tearDown];
}

/*!
	Builds an effect whose notification traffic is confined to its own center. The
	construction is guarded so a failure reports as a test failure rather than leaving
	later assertions to dereference nil.
*/
- (FxCatTestEffect *)makeEffect
{
	FxCatTestEffect *effect = [FxCatTestEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	XCTAssertNotNil(effect, @"FxTileableEffectBase must be constructible with no host API manager");
	self.effect = effect;
	return effect;
}

- (FxCatTestStubAPIManager *)installStubAPIManager
{
	FxCatTestStubAPIManager *manager = FxCatTestStubAPIManager.new;
	self.effect.stubAPIManager = manager;
	return manager;
}

#pragma mark Construction

- (void)testEffectConstructsWithoutAHostAndKeepsItsNotificationTrafficPrivate
{
	FxCatTestEffect *effect = [self makeEffect];

	XCTAssertNotNil(effect.apiManager);
	XCTAssertNotNil(effect.extensions);
	XCTAssertNotNil(effect.pluginProperties);
	XCTAssertNotNil(effect.privateNotifier);
	XCTAssertTrue((id)effect.notifier == (id)effect.privateNotifier,
				  @"the subclass keeps the process-wide center out of the tests");
	XCTAssertEqualObjects(effect.extKey, FxTileableEffectExtKey);
}

- (void)testEffectWithoutManagedPropertiesLoadsNoExtensions
{
	FxCatTestEffect *effect = [self makeEffect];

	XCTAssertEqual(effect.extensions.count, (NSUInteger)0);
}

#pragma mark Extension Loading

- (void)testExtensionsAreKeyedByExtensionKeyAndSurviveLoading
{
	gCatTestExtensionBuilder = ^NSMutableArray *{
		return @[FxCatTestExtension.new, FxCatTestMarkerExtension.new].mutableCopy;
	};
	FxCatTestEffect *effect = [self makeEffect];

	XCTAssertEqual(effect.extensions.count, (NSUInteger)2);

	FxCatTestExtension *loaded = (FxCatTestExtension *)effect.extensions[@"FxCatTestExtension"];
	XCTAssertNotNil(loaded);
	XCTAssertTrue(loaded.effect == effect);
	XCTAssertEqual(loaded.extKeyIndex, (NSInteger)0);
	XCTAssertEqual(loaded.initCount, (NSUInteger)1, @"the load posts the init notification to the extension");
}

- (void)testTheEffectResolvesACustomParameterTypeThroughALoadedExtension
{
	gCatTestExtensionBuilder = ^NSMutableArray *{
		return @[FxCatTestTypeExtension.new].mutableCopy;
	};
	FxCatTestEffect *effect = [self makeEffect];

	XCTAssertEqual([effect parameterTypeWithString:@"cattype"], (FxParameterType)'CatT');
	XCTAssertEqualObjects([effect parameterClassWithTypeString:@"cattype"], FxCatTestTypeExtension.class);
	// An unknown type still resolves to none / nil.
	XCTAssertEqual([effect parameterTypeWithString:@"nope"], FxParameterType_None);
	XCTAssertNil([effect parameterClassWithTypeString:@"nope"]);
	// A built-in type still resolves from the map rather than the extension.
	XCTAssertEqualObjects([effect parameterClassWithTypeString:@"float"], NSClassFromString(@"FxGripFloatParameter"));
}

// The loader must configure a parameter-backed extension through parameterForDictionary:
// (which marks it addedToEffect and syncs its id/name/flags) rather than returning it
// raw; returning it unconfigured left custom parameter values permanently nil.
- (void)testParameterForDictionaryConfiguresTheBackingExtension
{
	gCatTestExtensionBuilder = ^NSMutableArray *{
		return @[FxCatTestParameterExtension.new].mutableCopy;
	};
	FxCatTestEffect *effect = [self makeEffect];
	FxCatTestParameterExtension *ext =
		(FxCatTestParameterExtension *)effect.extensions[@"FxCatTestParameterExtension"];
	XCTAssertNotNil(ext);
	XCTAssertFalse(ext.configuredFromDictionary);

	NSDictionary *data = @{
		kFxParameterProperty_ExtensionKey: @"FxCatTestParameterExtension",
		kFxParameterProperty_Id: @7,
		kFxParameterProperty_Type: @"custom",
		kFxParameterProperty_Name: @"Backed",
	};
	id result = [effect parameterForDictionary:data];

	XCTAssertEqual(result, ext, @"the configured extension is returned as the parameter");
	XCTAssertTrue(ext.configuredFromDictionary, @"parameterForDictionary: must be called on the extension");
	XCTAssertEqualObjects(ext.configuredData, data);
}

// The tracking gate consults the plugin property (opt-in, default off) instead of a
// hardcoded NO, so a plugin can enable neighbour-instance tracking through its plist.
- (void)testInstanceTrackingGateFollowsThePluginProperty
{
	NSDictionary *base = @{
		kProPlugPlugIn_UuidProperty: @"AAAABBBB-CCCC-DDDD-EEEE-FFFF00003333",
		kProPlugPlugIn_ClassNameProperty: @"FxCatTestEffect",
		kProPlugPlugIn_GroupUUIDProperty: @"33330000-FFFF-EEEE-DDDD-CCCCBBBBAAAA",
	};

	FxCatTestEffect *off = [self makeEffect];
	off.stubPluginProperties = base;
	XCTAssertFalse(off.isTrackingInstances, @"tracking is off by default");

	NSMutableDictionary *withTracking = base.mutableCopy;
	withTracking[kProPlugPlugInX_TrackInstancesProperty] = @YES;
	FxCatTestEffect *on = [self makeEffect];
	on.stubPluginProperties = withTracking;
	XCTAssertTrue(on.isTrackingInstances, @"the plist property turns tracking on");
}

- (void)testRepeatedExtensionClassesGetDistinctKeysInPriorityOrder
{
	gCatTestExtensionBuilder = ^NSMutableArray *{
		FxCatTestExtension *low = FxCatTestExtension.new;
		low.extDefaultPriority = 15;
		FxCatTestExtension *high = FxCatTestExtension.new;
		high.extDefaultPriority = -5;
		return @[low, high].mutableCopy;
	};
	FxCatTestEffect *effect = [self makeEffect];

	XCTAssertEqual(effect.extensions.count, (NSUInteger)2);

	FxExtension *first = (FxExtension *)effect.extensions[@"FxCatTestExtension"];
	FxExtension *second = (FxExtension *)effect.extensions[@"FxCatTestExtension1"];
	XCTAssertNotNil(first);
	XCTAssertNotNil(second);
	XCTAssertEqual(first.extDefaultPriority, (NSInteger)-5, @"the higher priority instance loads first");
	XCTAssertEqual(second.extDefaultPriority, (NSInteger)15);
	XCTAssertEqual(second.extKeyIndex, (NSInteger)1);
}

- (void)testAnIndividuatedExtensionCarriesItsIndexInTheFirstKey
{
	gCatTestExtensionBuilder = ^NSMutableArray *{
		return @[FxCatTestIndividuatedExtension.new].mutableCopy;
	};
	FxCatTestEffect *effect = [self makeEffect];

	XCTAssertNotNil(effect.extensions[@"FxCatTestIndividuatedExtension0"]);
	XCTAssertNil(effect.extensions[@"FxCatTestIndividuatedExtension"]);
}

- (void)testADisabledExtensionIsDroppedUnlessItAsksToBeIncluded
{
	gCatTestExtensionBuilder = ^NSMutableArray *{
		FxCatTestExtension *dropped = FxCatTestExtension.new;
		[dropped setExtActive:NO];
		FxCatTestIncludedWhenDisabledExtension *kept = FxCatTestIncludedWhenDisabledExtension.new;
		[kept setExtActive:NO];
		return @[dropped, kept].mutableCopy;
	};
	FxCatTestEffect *effect = [self makeEffect];

	XCTAssertEqual(effect.extensions.count, (NSUInteger)1);
	XCTAssertNotNil(effect.extensions[@"FxCatTestIncludedWhenDisabledExtension"]);
	XCTAssertNil(effect.extensions[@"FxCatTestExtension"]);
}

- (void)testAnEffectThatLoadsNoExtensionListStillGetsAnExtensionDictionary
{
	gCatTestExtensionBuilder = ^NSMutableArray *{
		return nil;
	};
	FxCatTestEffect *effect = [self makeEffect];

	XCTAssertNotNil(effect.extensions);
	XCTAssertEqual(effect.extensions.count, (NSUInteger)0);
}

- (void)testEachLoadSelectorAnExtensionAnnouncesIsUsedInTurn
{
	gCatTestExtensionBuilder = ^NSMutableArray *{
		return @[FxCatTestEffectLoadExtension.new,
				 FxCatTestBothLoadsExtension.new,
				 FxCatTestIndexLoadExtension.new,
				 FxCatTestNoLoadExtension.new].mutableCopy;
	};
	FxCatTestEffect *effect = [self makeEffect];

	FxCatTestEffectLoadExtension *effectLoad = effect.extensions[@"FxCatTestEffectLoadExtension"];
	XCTAssertNotNil(effectLoad);
	XCTAssertTrue(effectLoad.effect == (id)effect);
	XCTAssertEqual(effectLoad.extKeyIndex, (NSInteger)-1, @"only the index selector assigns an index");

	FxCatTestBothLoadsExtension *bothLoads = effect.extensions[@"FxCatTestBothLoadsExtension"];
	XCTAssertNotNil(bothLoads);
	XCTAssertTrue(bothLoads.effect == (id)effect);
	XCTAssertEqual(bothLoads.extKeyIndex, (NSInteger)0);

	FxCatTestIndexLoadExtension *indexLoad = effect.extensions[@"FxCatTestIndexLoadExtension"];
	XCTAssertNotNil(indexLoad);
	XCTAssertNil(indexLoad.effect, @"an index-only extension is never handed the effect");
	XCTAssertEqual(indexLoad.extKeyIndex, (NSInteger)0);

	XCTAssertNil(effect.extensions[@"FxCatTestNoLoadExtension"],
				 @"an extension that announces no load selector and asks for nothing is dropped");
}

- (void)testAnExtensionThatRefusesTheEffectIsDropped
{
	gCatTestExtensionBuilder = ^NSMutableArray *{
		FxCatTestEffectLoadExtension *refusing = FxCatTestEffectLoadExtension.new;
		refusing.loadResult = NO;
		return @[refusing].mutableCopy;
	};
	FxCatTestEffect *effect = [self makeEffect];

	XCTAssertEqual(effect.extensions.count, (NSUInteger)0);
}

- (void)testAnExtensionWithNoLoadSelectorIsKeptWhenItAsksToBeIncluded
{
	gCatTestExtensionBuilder = ^NSMutableArray *{
		FxCatTestNoLoadExtension *kept = FxCatTestNoLoadExtension.new;
		[kept setExtIncludeWhenDisabled:YES];
		return @[kept].mutableCopy;
	};
	FxCatTestEffect *effect = [self makeEffect];

	XCTAssertNotNil(effect.extensions[@"FxCatTestNoLoadExtension"]);
}

#pragma mark Extension Lookup

- (FxCatTestEffect *)effectWithMarkerAndPlainExtensions
{
	gCatTestExtensionBuilder = ^NSMutableArray *{
		FxCatTestMarkerExtension *first = FxCatTestMarkerExtension.new;
		first.extDefaultPriority = -5;
		FxCatTestMarkerExtension *second = FxCatTestMarkerExtension.new;
		return @[FxCatTestExtension.new, first, second].mutableCopy;
	};
	return [self makeEffect];
}

- (void)testLookupFindsALoadedExtensionByClassProtocolAndKey
{
	FxCatTestEffect *effect = [self effectWithMarkerAndPlainExtensions];

	XCTAssertTrue([effect hasExtensionClass:FxCatTestExtension.class]);
	XCTAssertTrue([effect hasExtensionProtocol:@protocol(FxCatTestMarkerProtocol)]);
	XCTAssertTrue([effect hasExtensionKey:@"FxCatTestExtension"]);

	XCTAssertTrue([[effect extensionForClass:FxCatTestExtension.class] isKindOfClass:FxCatTestExtension.class]);
	XCTAssertTrue([[effect extensionForProtocol:@protocol(FxCatTestMarkerProtocol)]
				   conformsToProtocol:@protocol(FxCatTestMarkerProtocol)]);
	XCTAssertEqualObjects([effect extensionForKey:@"FxCatTestMarkerExtension1"].extKey,
						  @"FxCatTestMarkerExtension1");
}

- (void)testLookupReportsNothingForUnknownClassesProtocolsAndKeys
{
	FxCatTestEffect *effect = [self effectWithMarkerAndPlainExtensions];

	XCTAssertFalse([effect hasExtensionClass:FxCatTestIndividuatedExtension.class]);
	XCTAssertFalse([effect hasExtensionProtocol:@protocol(FxParameter)]);
	XCTAssertFalse([effect hasExtensionKey:@"Absent"]);
	XCTAssertFalse([effect hasExtensionKey:nil]);

	XCTAssertNil([effect extensionForClass:FxCatTestIndividuatedExtension.class]);
	XCTAssertNil([effect extensionForClass:nil]);
	XCTAssertNil([effect extensionForProtocol:@protocol(FxParameter)]);
	XCTAssertNil([effect extensionForProtocol:nil]);
	XCTAssertNil([effect extensionForKey:@"Absent"]);
	XCTAssertNil([effect extensionForKey:nil]);
}

- (void)testPluralLookupCollectsEveryMatchingExtension
{
	FxCatTestEffect *effect = [self effectWithMarkerAndPlainExtensions];

	XCTAssertEqual([effect extensionsForClass:FxCatTestMarkerExtension.class].count, (NSUInteger)2);
	XCTAssertEqual([effect extensionsForProtocol:@protocol(FxCatTestMarkerProtocol)].count, (NSUInteger)2);
	XCTAssertEqual([effect extensionsForClass:FxExtension.class].count, (NSUInteger)3);
	XCTAssertEqual([effect extensionsForKey:@"FxCatTestMarkerExtension"].count, (NSUInteger)1);
	XCTAssertEqual([effect extensionsForKey:@"Absent"].count, (NSUInteger)0);

	XCTAssertNil([effect extensionsForClass:nil]);
	XCTAssertNil([effect extensionsForProtocol:nil]);
	XCTAssertNil([effect extensionsForKey:nil]);
}

- (void)testExtensionCountReportsTheInstancesOfTheOwnClass
{
	FxCatTestEffect *effect = [self effectWithMarkerAndPlainExtensions];

	FxExtension *marker = (FxExtension *)[effect extensionForClass:FxCatTestMarkerExtension.class];
	XCTAssertEqual([marker extensionCount], (NSUInteger)2);

	FxExtension *plain = (FxExtension *)[effect extensionForClass:FxCatTestExtension.class];
	XCTAssertEqual([plain extensionCount], (NSUInteger)1);
}

#pragma mark Extension Flush

- (void)testExtensionsFlushReachesEveryExtensionAndReportsNoError
{
	__block FxCatTestFlushExtension *flusher = nil;
	gCatTestExtensionBuilder = ^NSMutableArray *{
		flusher = FxCatTestFlushExtension.new;
		return @[flusher].mutableCopy;
	};
	FxCatTestEffect *effect = [self makeEffect];

	XCTAssertNil([effect extensionsFlush]);
	XCTAssertEqual(flusher.flushCount, (NSUInteger)1);
}

- (void)testExtensionsFlushReturnsTheErrorAnExtensionReports
{
	NSError *reported = [NSError errorWithDomain:@"FxCatTest" code:99 userInfo:nil];
	__block FxCatTestFlushExtension *flusher = nil;
	gCatTestExtensionBuilder = ^NSMutableArray *{
		flusher = FxCatTestFlushExtension.new;
		flusher.errorToReport = reported;
		return @[flusher].mutableCopy;
	};
	FxCatTestEffect *effect = [self makeEffect];

	XCTAssertEqualObjects([effect extensionsFlush], reported);
}

- (void)testExtensionsFlushPassesBackAnObjectThatIsNotAnError
{
	__block FxCatTestFlushExtension *flusher = nil;
	gCatTestExtensionBuilder = ^NSMutableArray *{
		flusher = FxCatTestFlushExtension.new;
		flusher.errorToReport = @"not an error";
		return @[flusher].mutableCopy;
	};
	FxCatTestEffect *effect = [self makeEffect];

	XCTAssertEqualObjects((id)[effect extensionsFlush], @"not an error");
}

#pragma mark Color Gamut

- (void)testColorPrimariesFollowTheHostGamutAPI
{
	[self makeEffect];
	FxCatTestStubAPIManager *manager = [self installStubAPIManager];
	FxCatTestStubColorGamutAPI *gamut = FxCatTestStubColorGamutAPI.new;
	gamut.primaries = kFxColorPrimaries_Rec2020;
	manager.colorGamutAPIv2 = gamut;

	XCTAssertEqual(self.effect.colorPrimaries, kFxColorPrimaries_Rec2020);
	XCTAssertTrue(self.effect.isRec2020Gamut);
	XCTAssertFalse(self.effect.isRec709Gamut);

	gamut.primaries = kFxColorPrimaries_Rec709;
	XCTAssertTrue(self.effect.isRec709Gamut);
	XCTAssertFalse(self.effect.isRec2020Gamut);
}

- (void)testColorPrimariesFallBackToRec709WithoutTheGamutAPI
{
	[self makeEffect];
	[self installStubAPIManager];

	XCTAssertEqual(self.effect.colorPrimaries, kFxColorPrimaries_Rec709);
	XCTAssertTrue(self.effect.isRec709Gamut);
}

- (void)testColorMatricesFollowTheWorkingGamut
{
	[self makeEffect];
	FxCatTestStubAPIManager *manager = [self installStubAPIManager];
	FxCatTestStubColorGamutAPI *gamut = FxCatTestStubColorGamutAPI.new;
	gamut.primaries = kFxColorPrimaries_Rec2020;
	manager.colorGamutAPIv2 = gamut;

	simd_float3 weights = self.effect.colorLuminanceWeights;
	XCTAssertEqualWithAccuracy(weights.x, 0.2627f, 1e-5);
	XCTAssertEqualWithAccuracy(weights.y, 0.6780f, 1e-5);

	// The category delegates to the pure functions for the working gamut.
	simd_float3x3 expected = FxGripRGBToXYZMatrix(kFxColorPrimaries_Rec2020);
	simd_float3x3 actual = self.effect.rgbToXYZMatrix;
	XCTAssertEqualWithAccuracy(actual.columns[0].x, expected.columns[0].x, 1e-5);
	XCTAssertEqualWithAccuracy(actual.columns[2].z, expected.columns[2].z, 1e-5);

	gamut.primaries = kFxColorPrimaries_Rec709;
	XCTAssertEqualWithAccuracy(self.effect.colorLuminanceWeights.x, 0.2126f, 1e-5);

	// Working Rec709 → Rec2020 conversion, and the identity to its own gamut.
	simd_float3x3 toWide = [self.effect gamutMatrixToPrimaries:kFxColorPrimaries_Rec2020];
	simd_float3x3 pureToWide = FxGripGamutConversionMatrix(kFxColorPrimaries_Rec709, kFxColorPrimaries_Rec2020);
	XCTAssertEqualWithAccuracy(toWide.columns[0].x, pureToWide.columns[0].x, 1e-5);
	simd_float3x3 identity = [self.effect gamutMatrixToPrimaries:kFxColorPrimaries_Rec709];
	XCTAssertEqualWithAccuracy(identity.columns[0].x, 1.0f, 1e-5);
	XCTAssertEqualWithAccuracy(identity.columns[1].x, 0.0f, 1e-5);
}

- (void)testColorParameterModeFollowsTheDesiredProcessingColorInfo
{
	FxCatTestEffect *effect = [self makeEffect];

	XCTAssertEqual(effect.desiredProcessingColorInfo, kFxImageColorInfo_RGB_LINEAR);
	XCTAssertTrue(effect.isLinearColorParameters);
	XCTAssertFalse(effect.isGammaColorParameters);

	effect.desiredProcessingColorInfo = kFxImageColorInfo_RGB_GAMMA_VIDEO;
	XCTAssertTrue(effect.isGammaColorParameters);
	XCTAssertFalse(effect.isLinearColorParameters);
}

#pragma mark Plugin Properties

- (void)testEffectPropertiesAreNotReadFromTheInfoPlist
{
	XCTAssertFalse([self makeEffect].isEffectPropertiesInInfo);
}

#pragma mark Versioning

- (void)testPluginVersionReadsTheNumberFromThePluginProperties
{
	FxCatTestEffect *effect = [self makeEffect];

	effect.stubPluginProperties = @{kProPlugPlugIn_VersionProperty: @7};
	XCTAssertEqual(effect.pluginVersion, (UInt32)7);

	effect.stubPluginProperties = @{kProPlugPlugIn_VersionProperty: @"11"};
	XCTAssertEqual(effect.pluginVersion, (UInt32)11);
}

- (void)testPluginVersionFallsBackToOneForAMissingOrUnusableVersion
{
	FxCatTestEffect *effect = [self makeEffect];

	effect.stubPluginProperties = @{};
	XCTAssertEqual(effect.pluginVersion, (UInt32)1);

	effect.stubPluginProperties = @{kProPlugPlugIn_VersionProperty: @"1.2.3"};
	XCTAssertEqual(effect.pluginVersion, (UInt32)1);
}

- (void)testPluginStringVersionReadsTheShortVersionString
{
	FxCatTestEffect *effect = [self makeEffect];

	effect.stubPluginProperties = @{@"CFBundleShortVersionString": @"2.4.1"};
	XCTAssertEqualObjects(effect.pluginStringVersion, @"2.4.1");

	effect.stubPluginProperties = @{};
	XCTAssertNil(effect.pluginStringVersion);
}

- (void)testInstalledVersionIsZeroWithoutTheVersioningAPI
{
	[self makeEffect];
	[self installStubAPIManager];

	XCTAssertEqual(self.effect.installedVersion, (UInt32)0);
}

- (void)testInstalledVersionReadsTheVersionAtCreation
{
	[self makeEffect];
	FxCatTestStubAPIManager *manager = [self installStubAPIManager];
	FxCatTestStubVersioningAPI *versioning = FxCatTestStubVersioningAPI.new;
	versioning.versionAtCreation = 4;
	manager.versioningAPIv1 = versioning;

	XCTAssertEqual(self.effect.installedVersion, (UInt32)4);
}

- (void)testCheckVersionFailsWithAnUnavailableAPIError
{
	[self makeEffect];
	[self installStubAPIManager];

	NSError *error = nil;
	XCTAssertFalse([self.effect checkVersion:&error]);
	XCTAssertNotNil(error);
	XCTAssertEqualObjects(error.domain, FxCatTestExpectedErrorDomain());
	XCTAssertEqual(error.code, (NSInteger)kFxError_APIUnavailable);
}

- (void)testCheckVersionUpgradesWhenTheDocumentIsOlderThanThePlugin
{
	FxCatTestEffect *effect = [self makeEffect];
	FxCatTestStubAPIManager *manager = [self installStubAPIManager];
	FxCatTestStubVersioningAPI *versioning = FxCatTestStubVersioningAPI.new;
	versioning.versionAtCreation = 2;
	versioning.updateSucceeds = YES;
	manager.versioningAPIv1 = versioning;
	effect.stubPluginProperties = @{kProPlugPlugIn_VersionProperty: @5};

	NSError *error = nil;
	XCTAssertTrue([effect checkVersion:&error]);
	XCTAssertNil(error);
	XCTAssertEqual(versioning.updatedVersion, (UInt32)5);
}

- (void)testCheckVersionDoesNothingWhenTheDocumentIsCurrent
{
	FxCatTestEffect *effect = [self makeEffect];
	FxCatTestStubAPIManager *manager = [self installStubAPIManager];
	FxCatTestStubVersioningAPI *versioning = FxCatTestStubVersioningAPI.new;
	versioning.versionAtCreation = 5;
	versioning.updateSucceeds = YES;
	manager.versioningAPIv1 = versioning;
	effect.stubPluginProperties = @{kProPlugPlugIn_VersionProperty: @5};

	XCTAssertFalse([effect checkVersion:NULL]);
	XCTAssertEqual(versioning.updateCount, (NSUInteger)0);
}

- (void)testUpgradeFromVersionAcceptsEveryUpgradeByDefault
{
	FxCatTestEffect *effect = [self makeEffect];

	XCTAssertTrue([effect upgradeFromVersion:1 currentVersion:2 error:NULL]);
}

- (void)testCheckVersionFailsWhenTheHostRefusesToRecordTheNewVersion
{
	FxCatTestEffect *effect = [self makeEffect];
	FxCatTestStubAPIManager *manager = [self installStubAPIManager];
	FxCatTestStubVersioningAPI *versioning = FxCatTestStubVersioningAPI.new;
	versioning.versionAtCreation = 2;
	versioning.updateSucceeds = NO;
	manager.versioningAPIv1 = versioning;
	effect.stubPluginProperties = @{kProPlugPlugIn_VersionProperty: @5};

	XCTAssertFalse([effect checkVersion:NULL]);
	XCTAssertEqual(versioning.updateCount, (NSUInteger)1);
}

- (void)testCheckVersionFailsWhenTheEffectRefusesTheUpgrade
{
	FxCatTestRefusingEffect *effect = [FxCatTestRefusingEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	XCTAssertNotNil(effect);
	self.effect = effect;
	FxCatTestStubAPIManager *manager = [self installStubAPIManager];
	FxCatTestStubVersioningAPI *versioning = FxCatTestStubVersioningAPI.new;
	versioning.versionAtCreation = 2;
	versioning.updateSucceeds = YES;
	manager.versioningAPIv1 = versioning;
	effect.stubPluginProperties = @{kProPlugPlugIn_VersionProperty: @5};

	XCTAssertFalse([effect checkVersion:NULL]);
	XCTAssertEqual(versioning.updateCount, (NSUInteger)0);
}

#pragma mark Timing

- (FxCatTestStubTimingAPI *)installTimingAPI
{
	FxCatTestStubAPIManager *manager = [self installStubAPIManager];
	FxCatTestStubTimingAPI *timing = FxCatTestStubTimingAPI.new;
	manager.timingAPIv4 = timing;
	return timing;
}

- (void)testTimingPropertiesReadTheHostTimingAPI
{
	[self makeEffect];
	FxCatTestStubTimingAPI *timing = [self installTimingAPI];

	XCTAssertTrue(FxCatTestTimesEqual(self.effect.frameDuration, timing.frameDuration));
	XCTAssertTrue(FxCatTestTimesEqual(self.effect.sampleDuration, timing.sampleDuration));
	XCTAssertTrue(FxCatTestTimesEqual(self.effect.effectStartTime, timing.effectStartTime));
	XCTAssertTrue(FxCatTestTimesEqual(self.effect.effectDurationTime, timing.effectDuration));
	XCTAssertTrue(FxCatTestTimesEqual(self.effect.inputStartTime, timing.inputStartTime));
	XCTAssertTrue(FxCatTestTimesEqual(self.effect.inputDurationTime, timing.inputDuration));
	XCTAssertTrue(FxCatTestTimesEqual(self.effect.effectInPointOfTimeLine, timing.inPoint));
	XCTAssertTrue(FxCatTestTimesEqual(self.effect.effectOutPointOfTimeLine, timing.outPoint));
}

- (void)testTimingPropertiesAreInvalidWithoutTheTimingAPI
{
	[self makeEffect];
	[self installStubAPIManager];

	XCTAssertTrue(FxCatTestTimeIsInvalid(self.effect.frameDuration));
	XCTAssertTrue(FxCatTestTimeIsInvalid(self.effect.sampleDuration));
	XCTAssertTrue(FxCatTestTimeIsInvalid(self.effect.effectStartTime));
	XCTAssertTrue(FxCatTestTimeIsInvalid(self.effect.effectDurationTime));
	XCTAssertTrue(FxCatTestTimeIsInvalid(self.effect.inputStartTime));
	XCTAssertTrue(FxCatTestTimeIsInvalid(self.effect.inputDurationTime));
}

- (void)testFrameOffsetFunctionMovesTimeByWholeFrames
{
	CMTime base = FxCatTestMakeTime(0, 30);
	CMTime frameDuration = FxCatTestMakeTime(1, 30);

	CMTime forward = FxGripTimeByOffsettingFrames(base, 5, frameDuration);
	XCTAssertEqual(forward.value, 5);
	XCTAssertEqual(forward.timescale, 30);

	CMTime backward = FxGripTimeByOffsettingFrames(base, -2, frameDuration);
	XCTAssertEqual(backward.value, -2);

	CMTime unchanged = FxGripTimeByOffsettingFrames(FxCatTestMakeTime(90, 30), 0, frameDuration);
	XCTAssertEqual(unchanged.value, 90);
}

- (void)testTimeByOffsettingUsesTheHostFrameDuration
{
	[self makeEffect];
	[self installTimingAPI];		// frame duration defaults to 1/30

	CMTime result = [self.effect timeByOffsettingTime:FxCatTestMakeTime(0, 30) byFrames:3];
	XCTAssertEqual(result.value, 3);
	XCTAssertEqual(result.timescale, 30);
}

- (void)testFrameCountsConvertTheTimesWithTheTimelineFrameRate
{
	[self makeEffect];
	FxCatTestStubTimingAPI *timing = [self installTimingAPI];
	timing.effectStartTime = FxCatTestMakeTime(60, 30);		// 2 seconds
	timing.effectDuration = FxCatTestMakeTime(90, 30);		// 3 seconds
	timing.inputStartTime = FxCatTestMakeTime(120, 30);		// 4 seconds
	timing.inputDuration = FxCatTestMakeTime(150, 30);		// 5 seconds

	XCTAssertEqual(self.effect.effectStartFrame, (NSInteger)60);
	XCTAssertEqual(self.effect.effectDurationFrames, (NSInteger)90);
	XCTAssertEqual(self.effect.inputStartFrame, (NSInteger)120);
	XCTAssertEqual(self.effect.inputDurationFrames, (NSInteger)150);
	XCTAssertEqual([self.effect frameForTime:FxCatTestMakeTime(1, 2)], (NSInteger)15);
}

- (void)testTimelineFrameRateIsReportedAsFractionAndSeconds
{
	[self makeEffect];
	FxCatTestStubTimingAPI *timing = [self installTimingAPI];
	timing.fpsNumerator = 24000;
	timing.fpsDenominator = 1001;

	XCTAssertEqual(self.effect.timelineFpsNumerator, (NSUInteger)24000);
	XCTAssertEqual(self.effect.timelineFpsDenominator, (NSUInteger)1001);

	CMTime frameDuration = self.effect.timelineFrameDuration;
	XCTAssertEqual(frameDuration.value, (int64_t)1001);
	XCTAssertEqual(frameDuration.timescale, (int32_t)24000);

	CMTime frameRate = self.effect.timelineFrameRate;
	XCTAssertEqual(frameRate.value, (int64_t)24000);
	XCTAssertEqual(frameRate.timescale, (int32_t)1001);

	XCTAssertEqualWithAccuracy(self.effect.timelineFps, 23.976, 0.001);
	XCTAssertEqualWithAccuracy(self.effect.timelineFrameDurationFloat, 1.0 / 23.976, 0.0001);
	XCTAssertTrue(timing.lastEffectArgument == self.effect, @"the effect identifies itself to the host");
}

/*!
	The retiming speed is the timeline frame duration divided by the clip's retimed frame
	duration: a clip whose frame lasts one timeline frame runs at 1.0, and a clip whose
	frame lasts two timeline frames runs at 0.5.
*/
- (void)testRetimingSpeedComparesTheClipAndTimelineFrameDurations
{
	[self makeEffect];
	FxCatTestStubTimingAPI *timing = [self installTimingAPI];
	timing.fpsNumerator = 30;
	timing.fpsDenominator = 1;

	timing.frameDuration = FxCatTestMakeTime(1, 30);
	XCTAssertEqualWithAccuracy(self.effect.retimingSpeed, 1.0, 0.0001);

	timing.frameDuration = FxCatTestMakeTime(2, 30);
	XCTAssertEqualWithAccuracy(self.effect.retimingSpeed, 0.5, 0.0001);

	timing.frameDuration = FxCatTestMakeTime(1, 60);
	XCTAssertEqualWithAccuracy(self.effect.retimingSpeed, 2.0, 0.0001);
}

- (void)testInterlacedClipsAreRecognizedByTheSampleDuration
{
	[self makeEffect];
	FxCatTestStubTimingAPI *timing = [self installTimingAPI];

	timing.frameDuration = FxCatTestMakeTime(1, 30);
	timing.sampleDuration = FxCatTestMakeTime(1, 30);
	XCTAssertTrue(self.effect.isInterlacedClip);

	timing.sampleDuration = FxCatTestMakeTime(1, 60);
	XCTAssertFalse(self.effect.isInterlacedClip);
}

/*!
	A frame count that lands a hair below the next whole frame is reported as that frame:
	the conversion rounds up within one ten-thousandth to absorb the timebase's rounding.
*/
- (void)testAFrameCountJustShortOfAWholeFrameRoundsUp
{
	[self makeEffect];
	FxCatTestStubTimingAPI *timing = [self installTimingAPI];
	timing.fpsNumerator = 30;
	timing.fpsDenominator = 1;

	XCTAssertEqual([self.effect frameForTime:FxCatTestMakeTime(3333333, 100000000)], (NSInteger)1);
	XCTAssertEqual([self.effect frameForTime:FxCatTestMakeTime(3000000, 100000000)], (NSInteger)0);
}

- (void)testTimelineConversionsForwardToTheHostTimingAPI
{
	[self makeEffect];
	FxCatTestStubTimingAPI *timing = [self installTimingAPI];

	XCTAssertTrue(FxCatTestTimesEqual(self.effect.effectStartTimeInTimeline, timing.timelineTime));
	XCTAssertTrue(FxCatTestTimesEqual(timing.lastInputTimeArgument, timing.effectStartTime));

	XCTAssertTrue(FxCatTestTimesEqual(self.effect.inputStartTimeInTimeline, timing.timelineTime));
	XCTAssertTrue(FxCatTestTimesEqual(timing.lastInputTimeArgument, timing.inputStartTime));

	CMTime converted = FxCatTestMakeTime(0, 1);
	[self.effect timelineTime:&converted fromInputTime:FxCatTestMakeTime(7, 30)];
	XCTAssertTrue(FxCatTestTimesEqual(converted, timing.timelineTime));
	XCTAssertTrue(FxCatTestTimesEqual(timing.lastInputTimeArgument, FxCatTestMakeTime(7, 30)));

	[self.effect inputTime:&converted fromTimelineTime:FxCatTestMakeTime(9, 30)];
	XCTAssertTrue(FxCatTestTimesEqual(converted, timing.inputTime));
	XCTAssertTrue(FxCatTestTimesEqual(timing.lastTimelineTimeArgument, FxCatTestMakeTime(9, 30)));
}

#pragma mark Project Properties

- (FxCatTestStubProjectAPI *)installProjectAPI
{
	FxCatTestStubAPIManager *manager = [self installStubAPIManager];
	FxCatTestStubProjectAPI *project = FxCatTestStubProjectAPI.new;
	manager.projectAPIv1 = project;
	manager.projectAPIv2 = project;
	return project;
}

- (void)testDocumentIdentifiesAFinalCutProProject
{
	[self makeEffect];
	FxCatTestStubProjectAPI *project = [self installProjectAPI];
	project.documentIDSucceeds = YES;
	project.documentID = 12;

	XCTAssertEqual(self.effect.projectDocumentID, (NSUInteger)12);
	XCTAssertTrue(self.effect.isProjectFinalCutPro);
	XCTAssertFalse(self.effect.isProjectMotion);
}

- (void)testAZeroDocumentIdentifiesAMotionProject
{
	[self makeEffect];
	FxCatTestStubProjectAPI *project = [self installProjectAPI];
	project.documentIDSucceeds = YES;
	project.documentID = 0;

	XCTAssertEqual(self.effect.projectDocumentID, (NSUInteger)0);
	XCTAssertTrue(self.effect.isProjectMotion);
	XCTAssertFalse(self.effect.isProjectFinalCutPro);
}

- (void)testDocumentIDReportsTheHostError
{
	[self makeEffect];
	FxCatTestStubProjectAPI *project = [self installProjectAPI];
	project.documentIDSucceeds = NO;

	NSError *error = nil;
	XCTAssertEqual([self.effect projectDocumentIDWithError:&error], (NSUInteger)0);
	XCTAssertEqualObjects(error.domain, @"FxCatTest");
}

- (void)testTheDocumentIDPropertySwallowsTheHostError
{
	[self makeEffect];
	FxCatTestStubProjectAPI *project = [self installProjectAPI];
	project.documentIDSucceeds = NO;

	XCTAssertEqual(self.effect.projectDocumentID, (NSUInteger)0);
	XCTAssertTrue(self.effect.isProjectMotion, @"a project that cannot be identified reads as Motion");
}

- (void)testMediaFolderReturnsTheHostURLOrNothing
{
	[self makeEffect];
	FxCatTestStubProjectAPI *project = [self installProjectAPI];
	project.mediaFolderSucceeds = YES;
	project.mediaFolder = [NSURL fileURLWithPath:@"/tmp/fxcat-media"];

	XCTAssertEqualObjects(self.effect.projectMediaFolder, project.mediaFolder);

	project.mediaFolderSucceeds = NO;
	XCTAssertNil(self.effect.projectMediaFolder);
}

- (void)testAspectRatioFallsBackToSixteenByNine
{
	[self makeEffect];
	FxCatTestStubProjectAPI *project = [self installProjectAPI];
	project.aspectRatioSucceeds = YES;
	project.aspectRatio = 2.35f;

	XCTAssertEqualWithAccuracy(self.effect.projectAspectRatio, 2.35f, 0.0001);

	project.aspectRatioSucceeds = NO;
	XCTAssertEqualWithAccuracy(self.effect.projectAspectRatio, (float)kAspectRatio16x9, 0.0001);
}

#pragma mark Extension Accessors

- (void)testTheEffectBuildsAndFindsItsOptionalExtensions
{
	FxCatTestEffect *effect = [self makeEffect];

	XCTAssertNil(effect.parameterData, @"the extension is absent until the plugin asks for it");
	XCTAssertNil(effect.debugMenu);
	XCTAssertNil(effect.regression);
	XCTAssertNil(effect.instanceTracker);

	XCTAssertTrue([effect.newParameterDataExtension isKindOfClass:FxGripParameterData.class]);
	XCTAssertTrue([effect.newRegressionExtension isKindOfClass:FxGripRegression.class]);
	XCTAssertTrue([effect.newFxInstanceTracker isKindOfClass:FxGripInstanceTracker.class]);
}

#pragma mark Frame analysis

// gCatTestExtensionBuilder stays nil, so the effect runs the real loadExtensions gates.
- (FxAnalysisTestEffect *)makeAnalysisEffect
{
	FxAnalysisTestEffect *effect = [FxAnalysisTestEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	XCTAssertNotNil(effect);
	self.effect = effect;
	return effect;
}

- (void)testConformingToFxAnalyzerLoadsTheAnalysisExtension
{
	FxAnalysisTestEffect *effect = [self makeAnalysisEffect];
	XCTAssertTrue(effect.hasAnalysis);
	XCTAssertNotNil(effect.analysisData);
}

- (void)testANonConformingEffectDoesNotLoadAnalysis
{
	FxCatTestEffect *effect = [self makeEffect];   // FxCatTestEffect does not conform to FxAnalyzer
	XCTAssertFalse(effect.hasAnalysis);
	XCTAssertNil(effect.analysisData);
}

- (void)testTheFrameIndexUsesTheAnalysisFrameDuration
{
	FxAnalysisTestEffect *effect = [self makeAnalysisEffect];
	CMTimeRange range = { .start = FxAnalysisTestCMTime(0, 1), .duration = FxAnalysisTestCMTime(60, 30) };
	NSError *error = nil;
	XCTAssertTrue([effect setupAnalysisForTimeRange:range frameDuration:FxAnalysisTestCMTime(1, 30) error:&error]);

	XCTAssertEqual([effect analysisFrameIndexForTime:FxAnalysisTestCMTime(30, 30)], (NSInteger)30);   // 1.0s / (1/30)
	XCTAssertEqual([effect analysisFrameIndexForTime:FxAnalysisTestCMTime(0, 1)], (NSInteger)0);
}

- (void)testAnalyzeFrameStoresTheSubclassRecordAndReadsItBack
{
	FxAnalysisTestEffect *effect = [self makeAnalysisEffect];
	CMTimeRange range = { .start = FxAnalysisTestCMTime(0, 1), .duration = FxAnalysisTestCMTime(60, 30) };
	[effect setupAnalysisForTimeRange:range frameDuration:FxAnalysisTestCMTime(1, 30) error:NULL];

	CMTime frameTime = FxAnalysisTestCMTime(30, 30);   // frame index 30
	NSError *error = nil;
	XCTAssertTrue([effect analyzeFrame:(FxImageTile * _Nonnull)nil atTime:frameTime error:&error]);

	XCTAssertEqualObjects([effect analysisRecordAtTime:frameTime], @(30));
	// A later time before the next analyzed frame reads the latest at or before it.
	XCTAssertEqualObjects([effect analysisRecordAtTime:FxAnalysisTestCMTime(35, 30)], @(30));
	// Before any analyzed frame there is no record.
	XCTAssertNil([effect analysisRecordAtTime:FxAnalysisTestCMTime(0, 1)]);
}

- (void)testDesiredRangeDefaultsToTheFullInput
{
	FxAnalysisTestEffect *effect = [self makeAnalysisEffect];
	CMTimeRange input = { .start = FxAnalysisTestCMTime(10, 30), .duration = FxAnalysisTestCMTime(50, 30) };
	CMTimeRange desired = { 0 };

	XCTAssertTrue([effect desiredAnalysisTimeRange:&desired forInputWithTimeRange:input error:NULL]);
	XCTAssertEqual(desired.start.value, (int64_t)10);
	XCTAssertEqual(desired.start.timescale, (int32_t)30);
	XCTAssertEqual(desired.duration.value, (int64_t)50);
	XCTAssertEqual(desired.duration.timescale, (int32_t)30);
}

@end
