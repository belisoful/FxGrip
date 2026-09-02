//
//  FxGripTileableEffectCategoriesTests.m
//  FxGripTests
//
//  Unit tests for the FxGripTileableEffect categories: extension loading and
//  lookup, the flush pass, the color-gamut, plugin-property, versioning, timing
//  and project-property delegations to the effect's API manager.
//
//  FxGripTileableEffect registers its observers with the notification center its
//  -notifier getter returns. Every effect built here is an instance of a local
//  subclass that returns a private NSPriorityNotificationCenter, so no test
//  touches the process-wide center.
//

#import <XCTest/XCTest.h>
#import <dlfcn.h>
#import <CoreMedia/CoreMedia.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripErrors.h>
#import <FxGrip/FxGripExtension.h>
#import <FxGrip/FxGripAPINotifications.h>
#import <FxGrip/FxGripTileableEffect.h>
#import <FxGrip/FxGripTileableEffect+Notifications.h>
#import <FxGrip/FxGripTileableEffect+Extensions.h>
#import <FxGrip/FxGripTileableEffect+Parameters.h>
#import <FxGrip/FxGripTileableEffect+ColorGamut.h>
#import <FxGrip/FxGripColorGamut.h>
#import <FxGrip/FxGripTileableEffect+PluginProperties.h>
#import <FxGrip/FxGripTileableEffect+Versioning.h>
#import <FxGrip/FxGripTileableEffect+Timing.h>
#import <FxGrip/FxGripTileableEffect+ProjectProperties.h>
#import <FxGrip/FxGripParameterData.h>
#import <FxGrip/FxGripDebugMenu.h>
#import <FxGrip/FxGripRegression.h>
#import <FxGrip/FxGripInstanceTracker.h>
#import <FxGrip/FxGripTileableEffect+Analyze.h>
#import <FxGrip/FxGripAnalysis.h>

/*!
	The test bundle links neither CoreMedia nor FxPlug, so the error domain FxGripErrors.h
	names is read from the loaded images the way FxGripMetaTests does.
*/
static NSString *FxGripCatTestExpectedErrorDomain(void)
{
	NSString * __unsafe_unretained *domain = (NSString * __unsafe_unretained *)dlsym(RTLD_DEFAULT, "FxPlugErrorDomain");
	return domain ? *domain : FxGripPlugErrorDomainConstant;
}

static CMTime FxGripCatTestMakeTime(int64_t value, int32_t timescale)
{
	return (CMTime){.value = value, .timescale = timescale, .flags = kCMTimeFlags_Valid, .epoch = 0};
}

static BOOL FxGripCatTestTimesEqual(CMTime lhs, CMTime rhs)
{
	return lhs.value == rhs.value && lhs.timescale == rhs.timescale
		&& lhs.flags == rhs.flags && lhs.epoch == rhs.epoch;
}

static BOOL FxGripCatTestTimeIsInvalid(CMTime time)
{
	return (time.flags & kCMTimeFlags_Valid) == 0;
}

#pragma mark - Extension doubles

@protocol FxGripCatTestMarkerProtocol <NSObject>
@end

@interface FxGripCatTestExtension : FxGripExtension
@property (nonatomic, assign) NSUInteger initCount;
@end

@implementation FxGripCatTestExtension
- (void)extInit:(NSNotification *)notification
{
	self.initCount += 1;
}
@end

@interface FxGripCatTestMarkerExtension : FxGripExtension <FxGripCatTestMarkerProtocol>
@end

@implementation FxGripCatTestMarkerExtension
@end

// Declares a custom parameter type so the effect's type resolution consults it when the
// built-in type map has no entry.
@interface FxGripCatTestTypeExtension : FxGripExtension
@end

@implementation FxGripCatTestTypeExtension
- (FxParameterType)extParameterTypeForString:(NSString *)typeString
{
	return [typeString isEqualToString:@"cattype"] ? (FxParameterType)'CatT' : FxParameterType_None;
}
- (nullable Class)extParameterClassForType:(FxParameterType)type
{
	return type == (FxParameterType)'CatT' ? FxGripCatTestTypeExtension.class : Nil;
}
@end

// Stands in for a parameter extension: claims FxParameter conformance and records the
// configuration call the loader must make. conformsToProtocol: is overridden so the stub
// need not implement the whole FxParameter surface.
@interface FxGripCatTestParameterExtension : FxGripExtension
@property (nonatomic, assign) BOOL configuredFromDictionary;
@property (nonatomic, copy) NSDictionary *configuredData;
- (nullable id)parameterForDictionary:(nullable NSDictionary *)data;
@end

@implementation FxGripCatTestParameterExtension
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

@interface FxGripCatTestIndividuatedExtension : FxGripExtension
@end

@implementation FxGripCatTestIndividuatedExtension
- (BOOL)extIndividuate
{
	return YES;
}
@end

@interface FxGripCatTestIncludedWhenDisabledExtension : FxGripExtension
@end

@implementation FxGripCatTestIncludedWhenDisabledExtension
- (BOOL)extIncludeWhenDisabled
{
	return YES;
}
@end

/*!
	An extension that implements the protocol without inheriting FxGripExtensionBase, so the
	loading pass takes the branches that probe for each load selector.
*/
@interface FxGripCatTestBareExtension : NSObject <FxGripExtension>
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

@implementation FxGripCatTestBareExtension

- (instancetype)init
{
	self = [super init];
	if (self) {
		_bareKey = self.className;
		_bareKeyIndex = -1;
		_barePriority = FxGripExtensionDefaultPriority;
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
- (id<FxGripTileableEffect>)effect { return _bareEffect; }
- (NSString *)extKey { return _bareKey; }
- (NSInteger)extKeyIndex { return _bareKeyIndex; }
- (NSInteger)extDefaultPriority { return _barePriority; }
- (void)setExtDefaultPriority:(NSInteger)priority { _barePriority = priority; }
- (NSInteger)ncPriority:(NSNotificationName)aName { return _barePriority; }

@end

// Announces only the effect-taking load selector.
@interface FxGripCatTestEffectLoadExtension : FxGripCatTestBareExtension
@end

@implementation FxGripCatTestEffectLoadExtension
- (BOOL)extLoadWithEffect:(id<FxGripTileableEffect>)effect
{
	_bareEffect = effect;
	return self.loadResult;
}
@end

// Announces both load selectors, so the index pass runs after the effect pass.
@interface FxGripCatTestBothLoadsExtension : FxGripCatTestEffectLoadExtension
@end

@implementation FxGripCatTestBothLoadsExtension
- (BOOL)extLoadWithIndex:(NSInteger)index
{
	_bareKeyIndex = index;
	return self.loadResult;
}
@end

// Announces only the index-taking load selector.
@interface FxGripCatTestIndexLoadExtension : FxGripCatTestBareExtension
@end

@implementation FxGripCatTestIndexLoadExtension
- (BOOL)extLoadWithIndex:(NSInteger)index
{
	_bareKeyIndex = index;
	return self.loadResult;
}
@end

// Announces no load selector at all.
@interface FxGripCatTestNoLoadExtension : FxGripCatTestBareExtension
@end

@implementation FxGripCatTestNoLoadExtension
@end

// Writes whatever the test installs into the flush notification's userInfo.
@interface FxGripCatTestFlushExtension : FxGripExtension
@property (nonatomic, strong) id errorToReport;
@property (nonatomic, assign) NSUInteger flushCount;
@end

@implementation FxGripCatTestFlushExtension
- (void)extFlush:(NSNotification *)notification
{
	self.flushCount += 1;
	if (self.errorToReport) {
		((NSMutableDictionary *)notification.userInfo)[FxGripNotifyAPI_ErrorKey] = self.errorToReport;
	}
}
@end

#pragma mark - Host API doubles

@interface FxGripCatTestStubColorGamutAPI : NSObject
@property (nonatomic, assign) FxColorPrimaries primaries;
@end

@implementation FxGripCatTestStubColorGamutAPI
- (FxColorPrimaries)colorPrimaries
{
	return self.primaries;
}
@end

@interface FxGripCatTestStubVersioningAPI : NSObject
@property (nonatomic, assign) unsigned int versionAtCreation;
@property (nonatomic, assign) BOOL updateSucceeds;
@property (nonatomic, assign) UInt32 updatedVersion;
@property (nonatomic, assign) NSUInteger updateCount;
@end

@implementation FxGripCatTestStubVersioningAPI

- (BOOL)updateVersionAtCreation:(UInt32)newVersion
{
	self.updatedVersion = newVersion;
	self.updateCount += 1;
	return self.updateSucceeds;
}

@end

@interface FxGripCatTestStubTimingAPI : NSObject
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

@implementation FxGripCatTestStubTimingAPI

- (instancetype)init
{
	self = [super init];
	if (self) {
		_frameDuration = FxGripCatTestMakeTime(1, 30);
		_sampleDuration = FxGripCatTestMakeTime(1, 30);
		_effectStartTime = FxGripCatTestMakeTime(0, 30);
		_effectDuration = FxGripCatTestMakeTime(60, 30);
		_inputStartTime = FxGripCatTestMakeTime(0, 30);
		_inputDuration = FxGripCatTestMakeTime(90, 30);
		_inPoint = FxGripCatTestMakeTime(5, 30);
		_outPoint = FxGripCatTestMakeTime(65, 30);
		_timelineTime = FxGripCatTestMakeTime(300, 30);
		_inputTime = FxGripCatTestMakeTime(400, 30);
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

@interface FxGripCatTestStubProjectAPI : NSObject
@property (nonatomic, assign) NSUInteger documentID;
@property (nonatomic, assign) BOOL documentIDSucceeds;
@property (nonatomic, strong) NSURL *mediaFolder;
@property (nonatomic, assign) BOOL mediaFolderSucceeds;
@property (nonatomic, assign) float aspectRatio;
@property (nonatomic, assign) BOOL aspectRatioSucceeds;
@end

@implementation FxGripCatTestStubProjectAPI

- (BOOL)documentID:(NSUInteger *)documentID error:(NSError **)error
{
	if (!self.documentIDSucceeds) {
		if (error) {
			*error = [NSError errorWithDomain:@"FxGripCatTest" code:7 userInfo:nil];
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

@interface FxGripCatTestStubAPIManager : NSObject
@property (nonatomic, strong) id colorGamutAPIv2;
@property (nonatomic, strong) id versioningAPIv1;
@property (nonatomic, strong) id timingAPIv4;
@property (nonatomic, strong) id projectAPIv1;
@property (nonatomic, strong) id projectAPIv2;
@property (nonatomic, assign) UInt64 sessionID;
@end

@implementation FxGripCatTestStubAPIManager
@end

#pragma mark - Effect subclass

// Supplies the extension list the effect loads. The effect builds its extensions inside
// its initializer, so the list is installed before construction.
static NSMutableArray *(^gCatTestExtensionBuilder)(void) = nil;

@interface FxGripCatTestEffect : FxGripTileableEffect
@property (nonatomic, strong) NSNotificationCenter *privateNotifier;
@property (nonatomic, strong) id stubAPIManager;
@property (nonatomic, strong) NSDictionary<NSString *, id> *stubPluginProperties;
@end

@implementation FxGripCatTestEffect

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

- (NSMutableArray<id<FxGripExtension>> *)loadExtensions
{
	if (gCatTestExtensionBuilder) {
		return gCatTestExtensionBuilder();
	}
	return [super loadExtensions];
}

@end

// Refuses every version upgrade.
@interface FxGripCatTestRefusingEffect : FxGripCatTestEffect
@end

@implementation FxGripCatTestRefusingEffect

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
@interface FxGripAnalysisTestEffect : FxGripCatTestEffect <FxAnalyzer>
@end

// The stub needs only conformsToProtocol: for the loader gate; the host-called
// FxAnalyzer methods live on the real base's Analyze category.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wprotocol"
@implementation FxGripAnalysisTestEffect

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
#pragma clang diagnostic pop

// The test bundle does not link CoreMedia, so times are built as struct literals rather than
// through CMTimeMake.
static CMTime FxGripAnalysisTestCMTime(int64_t value, int32_t timescale)
{
	return (CMTime){ .value = value, .timescale = timescale, .flags = kCMTimeFlags_Valid, .epoch = 0 };
}

#pragma mark - Tests

@interface FxGripTileableEffectCategoriesTests : XCTestCase
@property (nonatomic, strong) FxGripCatTestEffect *effect;
@end

@implementation FxGripTileableEffectCategoriesTests

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
- (FxGripCatTestEffect *)makeEffect
{
	FxGripCatTestEffect *effect = [FxGripCatTestEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	XCTAssertNotNil(effect, @"FxGripTileableEffect must be constructible with no host API manager");
	self.effect = effect;
	return effect;
}

- (FxGripCatTestStubAPIManager *)installStubAPIManager
{
	FxGripCatTestStubAPIManager *manager = FxGripCatTestStubAPIManager.new;
	self.effect.stubAPIManager = manager;
	return manager;
}

#pragma mark Construction

- (void)testEffectConstructsWithoutAHostAndKeepsItsNotificationTrafficPrivate
{
	FxGripCatTestEffect *effect = [self makeEffect];

	XCTAssertNotNil(effect.apiManager);
	XCTAssertNotNil(effect.extensions);
	XCTAssertNotNil(effect.pluginProperties);
	XCTAssertNotNil(effect.privateNotifier);
	XCTAssertTrue((id)effect.notifier == (id)effect.privateNotifier,
				  @"the subclass keeps the process-wide center out of the tests");
	XCTAssertEqualObjects(effect.extKey, FxGripTileableEffectExtKey);
}

- (void)testEffectWithoutManagedPropertiesLoadsNoExtensions
{
	FxGripCatTestEffect *effect = [self makeEffect];

	XCTAssertEqual(effect.extensions.count, (NSUInteger)0);
}

#pragma mark Extension Loading

- (void)testExtensionsAreKeyedByExtensionKeyAndSurviveLoading
{
	gCatTestExtensionBuilder = ^NSMutableArray *{
		return @[FxGripCatTestExtension.new, FxGripCatTestMarkerExtension.new].mutableCopy;
	};
	FxGripCatTestEffect *effect = [self makeEffect];

	XCTAssertEqual(effect.extensions.count, (NSUInteger)2);

	FxGripCatTestExtension *loaded = (FxGripCatTestExtension *)effect.extensions[@"FxGripCatTestExtension"];
	XCTAssertNotNil(loaded);
	XCTAssertTrue(loaded.effect == effect);
	XCTAssertEqual(loaded.extKeyIndex, (NSInteger)0);
	XCTAssertEqual(loaded.initCount, (NSUInteger)1, @"the load posts the init notification to the extension");
}

- (void)testTheEffectResolvesACustomParameterTypeThroughALoadedExtension
{
	gCatTestExtensionBuilder = ^NSMutableArray *{
		return @[FxGripCatTestTypeExtension.new].mutableCopy;
	};
	FxGripCatTestEffect *effect = [self makeEffect];

	XCTAssertEqual([effect parameterTypeWithString:@"cattype"], (FxParameterType)'CatT');
	XCTAssertEqualObjects([effect parameterClassWithTypeString:@"cattype"], FxGripCatTestTypeExtension.class);
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
		return @[FxGripCatTestParameterExtension.new].mutableCopy;
	};
	FxGripCatTestEffect *effect = [self makeEffect];
	FxGripCatTestParameterExtension *ext =
		(FxGripCatTestParameterExtension *)effect.extensions[@"FxGripCatTestParameterExtension"];
	XCTAssertNotNil(ext);
	XCTAssertFalse(ext.configuredFromDictionary);

	NSDictionary *data = @{
		kFxParameterProperty_ExtensionKey: @"FxGripCatTestParameterExtension",
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
		kProPlugPlugIn_ClassNameProperty: @"FxGripCatTestEffect",
		kProPlugPlugIn_GroupUUIDProperty: @"33330000-FFFF-EEEE-DDDD-CCCCBBBBAAAA",
	};

	FxGripCatTestEffect *off = [self makeEffect];
	off.stubPluginProperties = base;
	XCTAssertFalse(off.isTrackingInstances, @"tracking is off by default");

	NSMutableDictionary *withTracking = base.mutableCopy;
	withTracking[kProPlugPlugInX_TrackInstancesProperty] = @YES;
	FxGripCatTestEffect *on = [self makeEffect];
	on.stubPluginProperties = withTracking;
	XCTAssertTrue(on.isTrackingInstances, @"the plist property turns tracking on");
}

- (void)testRepeatedExtensionClassesGetDistinctKeysInPriorityOrder
{
	gCatTestExtensionBuilder = ^NSMutableArray *{
		FxGripCatTestExtension *low = FxGripCatTestExtension.new;
		low.extDefaultPriority = 15;
		FxGripCatTestExtension *high = FxGripCatTestExtension.new;
		high.extDefaultPriority = -5;
		return @[low, high].mutableCopy;
	};
	FxGripCatTestEffect *effect = [self makeEffect];

	XCTAssertEqual(effect.extensions.count, (NSUInteger)2);

	FxGripExtension *first = (FxGripExtension *)effect.extensions[@"FxGripCatTestExtension"];
	FxGripExtension *second = (FxGripExtension *)effect.extensions[@"FxGripCatTestExtension1"];
	XCTAssertNotNil(first);
	XCTAssertNotNil(second);
	XCTAssertEqual(first.extDefaultPriority, (NSInteger)-5, @"the higher priority instance loads first");
	XCTAssertEqual(second.extDefaultPriority, (NSInteger)15);
	XCTAssertEqual(second.extKeyIndex, (NSInteger)1);
}

- (void)testAnIndividuatedExtensionCarriesItsIndexInTheFirstKey
{
	gCatTestExtensionBuilder = ^NSMutableArray *{
		return @[FxGripCatTestIndividuatedExtension.new].mutableCopy;
	};
	FxGripCatTestEffect *effect = [self makeEffect];

	XCTAssertNotNil(effect.extensions[@"FxGripCatTestIndividuatedExtension0"]);
	XCTAssertNil(effect.extensions[@"FxGripCatTestIndividuatedExtension"]);
}

- (void)testADisabledExtensionIsDroppedUnlessItAsksToBeIncluded
{
	gCatTestExtensionBuilder = ^NSMutableArray *{
		FxGripCatTestExtension *dropped = FxGripCatTestExtension.new;
		[dropped setExtActive:NO];
		FxGripCatTestIncludedWhenDisabledExtension *kept = FxGripCatTestIncludedWhenDisabledExtension.new;
		[kept setExtActive:NO];
		return @[dropped, kept].mutableCopy;
	};
	FxGripCatTestEffect *effect = [self makeEffect];

	XCTAssertEqual(effect.extensions.count, (NSUInteger)1);
	XCTAssertNotNil(effect.extensions[@"FxGripCatTestIncludedWhenDisabledExtension"]);
	XCTAssertNil(effect.extensions[@"FxGripCatTestExtension"]);
}

- (void)testAnEffectThatLoadsNoExtensionListStillGetsAnExtensionDictionary
{
	gCatTestExtensionBuilder = ^NSMutableArray *{
		return nil;
	};
	FxGripCatTestEffect *effect = [self makeEffect];

	XCTAssertNotNil(effect.extensions);
	XCTAssertEqual(effect.extensions.count, (NSUInteger)0);
}

- (void)testEachLoadSelectorAnExtensionAnnouncesIsUsedInTurn
{
	gCatTestExtensionBuilder = ^NSMutableArray *{
		return @[FxGripCatTestEffectLoadExtension.new,
				 FxGripCatTestBothLoadsExtension.new,
				 FxGripCatTestIndexLoadExtension.new,
				 FxGripCatTestNoLoadExtension.new].mutableCopy;
	};
	FxGripCatTestEffect *effect = [self makeEffect];

	FxGripCatTestEffectLoadExtension *effectLoad = effect.extensions[@"FxGripCatTestEffectLoadExtension"];
	XCTAssertNotNil(effectLoad);
	XCTAssertTrue(effectLoad.effect == (id)effect);
	XCTAssertEqual(effectLoad.extKeyIndex, (NSInteger)-1, @"only the index selector assigns an index");

	FxGripCatTestBothLoadsExtension *bothLoads = effect.extensions[@"FxGripCatTestBothLoadsExtension"];
	XCTAssertNotNil(bothLoads);
	XCTAssertTrue(bothLoads.effect == (id)effect);
	XCTAssertEqual(bothLoads.extKeyIndex, (NSInteger)0);

	FxGripCatTestIndexLoadExtension *indexLoad = effect.extensions[@"FxGripCatTestIndexLoadExtension"];
	XCTAssertNotNil(indexLoad);
	XCTAssertNil(indexLoad.effect, @"an index-only extension is never handed the effect");
	XCTAssertEqual(indexLoad.extKeyIndex, (NSInteger)0);

	XCTAssertNil(effect.extensions[@"FxGripCatTestNoLoadExtension"],
				 @"an extension that announces no load selector and asks for nothing is dropped");
}

- (void)testAnExtensionThatRefusesTheEffectIsDropped
{
	gCatTestExtensionBuilder = ^NSMutableArray *{
		FxGripCatTestEffectLoadExtension *refusing = FxGripCatTestEffectLoadExtension.new;
		refusing.loadResult = NO;
		return @[refusing].mutableCopy;
	};
	FxGripCatTestEffect *effect = [self makeEffect];

	XCTAssertEqual(effect.extensions.count, (NSUInteger)0);
}

- (void)testAnExtensionWithNoLoadSelectorIsKeptWhenItAsksToBeIncluded
{
	gCatTestExtensionBuilder = ^NSMutableArray *{
		FxGripCatTestNoLoadExtension *kept = FxGripCatTestNoLoadExtension.new;
		[kept setExtIncludeWhenDisabled:YES];
		return @[kept].mutableCopy;
	};
	FxGripCatTestEffect *effect = [self makeEffect];

	XCTAssertNotNil(effect.extensions[@"FxGripCatTestNoLoadExtension"]);
}

#pragma mark Extension Lookup

- (FxGripCatTestEffect *)effectWithMarkerAndPlainExtensions
{
	gCatTestExtensionBuilder = ^NSMutableArray *{
		FxGripCatTestMarkerExtension *first = FxGripCatTestMarkerExtension.new;
		first.extDefaultPriority = -5;
		FxGripCatTestMarkerExtension *second = FxGripCatTestMarkerExtension.new;
		return @[FxGripCatTestExtension.new, first, second].mutableCopy;
	};
	return [self makeEffect];
}

- (void)testLookupFindsALoadedExtensionByClassProtocolAndKey
{
	FxGripCatTestEffect *effect = [self effectWithMarkerAndPlainExtensions];

	XCTAssertTrue([effect hasExtensionClass:FxGripCatTestExtension.class]);
	XCTAssertTrue([effect hasExtensionProtocol:@protocol(FxGripCatTestMarkerProtocol)]);
	XCTAssertTrue([effect hasExtensionKey:@"FxGripCatTestExtension"]);

	XCTAssertTrue([[effect extensionForClass:FxGripCatTestExtension.class] isKindOfClass:FxGripCatTestExtension.class]);
	XCTAssertTrue([[effect extensionForProtocol:@protocol(FxGripCatTestMarkerProtocol)]
				   conformsToProtocol:@protocol(FxGripCatTestMarkerProtocol)]);
	XCTAssertEqualObjects([effect extensionForKey:@"FxGripCatTestMarkerExtension1"].extKey,
						  @"FxGripCatTestMarkerExtension1");
}

- (void)testLookupReportsNothingForUnknownClassesProtocolsAndKeys
{
	FxGripCatTestEffect *effect = [self effectWithMarkerAndPlainExtensions];

	XCTAssertFalse([effect hasExtensionClass:FxGripCatTestIndividuatedExtension.class]);
	XCTAssertFalse([effect hasExtensionProtocol:@protocol(FxParameter)]);
	XCTAssertFalse([effect hasExtensionKey:@"Absent"]);
	XCTAssertFalse([effect hasExtensionKey:nil]);

	XCTAssertNil([effect extensionForClass:FxGripCatTestIndividuatedExtension.class]);
	XCTAssertNil([effect extensionForClass:nil]);
	XCTAssertNil([effect extensionForProtocol:@protocol(FxParameter)]);
	XCTAssertNil([effect extensionForProtocol:nil]);
	XCTAssertNil([effect extensionForKey:@"Absent"]);
	XCTAssertNil([effect extensionForKey:nil]);
}

- (void)testPluralLookupCollectsEveryMatchingExtension
{
	FxGripCatTestEffect *effect = [self effectWithMarkerAndPlainExtensions];

	XCTAssertEqual([effect extensionsForClass:FxGripCatTestMarkerExtension.class].count, (NSUInteger)2);
	XCTAssertEqual([effect extensionsForProtocol:@protocol(FxGripCatTestMarkerProtocol)].count, (NSUInteger)2);
	XCTAssertEqual([effect extensionsForClass:FxGripExtension.class].count, (NSUInteger)3);
	XCTAssertEqual([effect extensionsForKey:@"FxGripCatTestMarkerExtension"].count, (NSUInteger)1);
	XCTAssertEqual([effect extensionsForKey:@"Absent"].count, (NSUInteger)0);

	XCTAssertNil([effect extensionsForClass:nil]);
	XCTAssertNil([effect extensionsForProtocol:nil]);
	XCTAssertNil([effect extensionsForKey:nil]);
}

- (void)testExtensionCountReportsTheInstancesOfTheOwnClass
{
	FxGripCatTestEffect *effect = [self effectWithMarkerAndPlainExtensions];

	FxGripExtension *marker = (FxGripExtension *)[effect extensionForClass:FxGripCatTestMarkerExtension.class];
	XCTAssertEqual([marker extensionCount], (NSUInteger)2);

	FxGripExtension *plain = (FxGripExtension *)[effect extensionForClass:FxGripCatTestExtension.class];
	XCTAssertEqual([plain extensionCount], (NSUInteger)1);
}

#pragma mark Extension Flush

- (void)testExtensionsFlushReachesEveryExtensionAndReportsNoError
{
	__block FxGripCatTestFlushExtension *flusher = nil;
	gCatTestExtensionBuilder = ^NSMutableArray *{
		flusher = FxGripCatTestFlushExtension.new;
		return @[flusher].mutableCopy;
	};
	FxGripCatTestEffect *effect = [self makeEffect];

	XCTAssertNil([effect extensionsFlush]);
	XCTAssertEqual(flusher.flushCount, (NSUInteger)1);
}

- (void)testExtensionsFlushReturnsTheErrorAnExtensionReports
{
	NSError *reported = [NSError errorWithDomain:@"FxGripCatTest" code:99 userInfo:nil];
	__block FxGripCatTestFlushExtension *flusher = nil;
	gCatTestExtensionBuilder = ^NSMutableArray *{
		flusher = FxGripCatTestFlushExtension.new;
		flusher.errorToReport = reported;
		return @[flusher].mutableCopy;
	};
	FxGripCatTestEffect *effect = [self makeEffect];

	XCTAssertEqualObjects([effect extensionsFlush], reported);
}

- (void)testExtensionsFlushPassesBackAnObjectThatIsNotAnError
{
	__block FxGripCatTestFlushExtension *flusher = nil;
	gCatTestExtensionBuilder = ^NSMutableArray *{
		flusher = FxGripCatTestFlushExtension.new;
		flusher.errorToReport = @"not an error";
		return @[flusher].mutableCopy;
	};
	FxGripCatTestEffect *effect = [self makeEffect];

	XCTAssertEqualObjects((id)[effect extensionsFlush], @"not an error");
}

#pragma mark Color Gamut

- (void)testColorPrimariesFollowTheHostGamutAPI
{
	[self makeEffect];
	FxGripCatTestStubAPIManager *manager = [self installStubAPIManager];
	FxGripCatTestStubColorGamutAPI *gamut = FxGripCatTestStubColorGamutAPI.new;
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
	FxGripCatTestStubAPIManager *manager = [self installStubAPIManager];
	FxGripCatTestStubColorGamutAPI *gamut = FxGripCatTestStubColorGamutAPI.new;
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
	FxGripCatTestEffect *effect = [self makeEffect];

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
	FxGripCatTestEffect *effect = [self makeEffect];

	effect.stubPluginProperties = @{kProPlugPlugIn_VersionProperty: @7};
	XCTAssertEqual(effect.pluginVersion, (UInt32)7);

	effect.stubPluginProperties = @{kProPlugPlugIn_VersionProperty: @"11"};
	XCTAssertEqual(effect.pluginVersion, (UInt32)11);
}

- (void)testPluginVersionFallsBackToOneForAMissingOrUnusableVersion
{
	FxGripCatTestEffect *effect = [self makeEffect];

	effect.stubPluginProperties = @{};
	XCTAssertEqual(effect.pluginVersion, (UInt32)1);

	effect.stubPluginProperties = @{kProPlugPlugIn_VersionProperty: @"1.2.3"};
	XCTAssertEqual(effect.pluginVersion, (UInt32)1);
}

- (void)testPluginStringVersionReadsTheShortVersionString
{
	FxGripCatTestEffect *effect = [self makeEffect];

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
	FxGripCatTestStubAPIManager *manager = [self installStubAPIManager];
	FxGripCatTestStubVersioningAPI *versioning = FxGripCatTestStubVersioningAPI.new;
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
	XCTAssertEqualObjects(error.domain, FxGripCatTestExpectedErrorDomain());
	XCTAssertEqual(error.code, (NSInteger)kFxError_APIUnavailable);
}

- (void)testCheckVersionUpgradesWhenTheDocumentIsOlderThanThePlugin
{
	FxGripCatTestEffect *effect = [self makeEffect];
	FxGripCatTestStubAPIManager *manager = [self installStubAPIManager];
	FxGripCatTestStubVersioningAPI *versioning = FxGripCatTestStubVersioningAPI.new;
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
	FxGripCatTestEffect *effect = [self makeEffect];
	FxGripCatTestStubAPIManager *manager = [self installStubAPIManager];
	FxGripCatTestStubVersioningAPI *versioning = FxGripCatTestStubVersioningAPI.new;
	versioning.versionAtCreation = 5;
	versioning.updateSucceeds = YES;
	manager.versioningAPIv1 = versioning;
	effect.stubPluginProperties = @{kProPlugPlugIn_VersionProperty: @5};

	XCTAssertFalse([effect checkVersion:NULL]);
	XCTAssertEqual(versioning.updateCount, (NSUInteger)0);
}

- (void)testUpgradeFromVersionAcceptsEveryUpgradeByDefault
{
	FxGripCatTestEffect *effect = [self makeEffect];

	XCTAssertTrue([effect upgradeFromVersion:1 currentVersion:2 error:NULL]);
}

- (void)testCheckVersionFailsWhenTheHostRefusesToRecordTheNewVersion
{
	FxGripCatTestEffect *effect = [self makeEffect];
	FxGripCatTestStubAPIManager *manager = [self installStubAPIManager];
	FxGripCatTestStubVersioningAPI *versioning = FxGripCatTestStubVersioningAPI.new;
	versioning.versionAtCreation = 2;
	versioning.updateSucceeds = NO;
	manager.versioningAPIv1 = versioning;
	effect.stubPluginProperties = @{kProPlugPlugIn_VersionProperty: @5};

	XCTAssertFalse([effect checkVersion:NULL]);
	XCTAssertEqual(versioning.updateCount, (NSUInteger)1);
}

- (void)testCheckVersionFailsWhenTheEffectRefusesTheUpgrade
{
	FxGripCatTestRefusingEffect *effect = [FxGripCatTestRefusingEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	XCTAssertNotNil(effect);
	self.effect = effect;
	FxGripCatTestStubAPIManager *manager = [self installStubAPIManager];
	FxGripCatTestStubVersioningAPI *versioning = FxGripCatTestStubVersioningAPI.new;
	versioning.versionAtCreation = 2;
	versioning.updateSucceeds = YES;
	manager.versioningAPIv1 = versioning;
	effect.stubPluginProperties = @{kProPlugPlugIn_VersionProperty: @5};

	XCTAssertFalse([effect checkVersion:NULL]);
	XCTAssertEqual(versioning.updateCount, (NSUInteger)0);
}

#pragma mark Timing

- (FxGripCatTestStubTimingAPI *)installTimingAPI
{
	FxGripCatTestStubAPIManager *manager = [self installStubAPIManager];
	FxGripCatTestStubTimingAPI *timing = FxGripCatTestStubTimingAPI.new;
	manager.timingAPIv4 = timing;
	return timing;
}

- (void)testTimingPropertiesReadTheHostTimingAPI
{
	[self makeEffect];
	FxGripCatTestStubTimingAPI *timing = [self installTimingAPI];

	XCTAssertTrue(FxGripCatTestTimesEqual(self.effect.frameDuration, timing.frameDuration));
	XCTAssertTrue(FxGripCatTestTimesEqual(self.effect.sampleDuration, timing.sampleDuration));
	XCTAssertTrue(FxGripCatTestTimesEqual(self.effect.effectStartTime, timing.effectStartTime));
	XCTAssertTrue(FxGripCatTestTimesEqual(self.effect.effectDurationTime, timing.effectDuration));
	XCTAssertTrue(FxGripCatTestTimesEqual(self.effect.inputStartTime, timing.inputStartTime));
	XCTAssertTrue(FxGripCatTestTimesEqual(self.effect.inputDurationTime, timing.inputDuration));
	XCTAssertTrue(FxGripCatTestTimesEqual(self.effect.effectInPointOfTimeLine, timing.inPoint));
	XCTAssertTrue(FxGripCatTestTimesEqual(self.effect.effectOutPointOfTimeLine, timing.outPoint));
}

- (void)testTimingPropertiesAreInvalidWithoutTheTimingAPI
{
	[self makeEffect];
	[self installStubAPIManager];

	XCTAssertTrue(FxGripCatTestTimeIsInvalid(self.effect.frameDuration));
	XCTAssertTrue(FxGripCatTestTimeIsInvalid(self.effect.sampleDuration));
	XCTAssertTrue(FxGripCatTestTimeIsInvalid(self.effect.effectStartTime));
	XCTAssertTrue(FxGripCatTestTimeIsInvalid(self.effect.effectDurationTime));
	XCTAssertTrue(FxGripCatTestTimeIsInvalid(self.effect.inputStartTime));
	XCTAssertTrue(FxGripCatTestTimeIsInvalid(self.effect.inputDurationTime));
}

- (void)testFrameOffsetFunctionMovesTimeByWholeFrames
{
	CMTime base = FxGripCatTestMakeTime(0, 30);
	CMTime frameDuration = FxGripCatTestMakeTime(1, 30);

	CMTime forward = FxGripTimeByOffsettingFrames(base, 5, frameDuration);
	XCTAssertEqual(forward.value, 5);
	XCTAssertEqual(forward.timescale, 30);

	CMTime backward = FxGripTimeByOffsettingFrames(base, -2, frameDuration);
	XCTAssertEqual(backward.value, -2);

	CMTime unchanged = FxGripTimeByOffsettingFrames(FxGripCatTestMakeTime(90, 30), 0, frameDuration);
	XCTAssertEqual(unchanged.value, 90);
}

- (void)testTimeByOffsettingUsesTheHostFrameDuration
{
	[self makeEffect];
	[self installTimingAPI];		// frame duration defaults to 1/30

	CMTime result = [self.effect timeByOffsettingTime:FxGripCatTestMakeTime(0, 30) byFrames:3];
	XCTAssertEqual(result.value, 3);
	XCTAssertEqual(result.timescale, 30);
}

- (void)testFrameCountsConvertTheTimesWithTheTimelineFrameRate
{
	[self makeEffect];
	FxGripCatTestStubTimingAPI *timing = [self installTimingAPI];
	timing.effectStartTime = FxGripCatTestMakeTime(60, 30);		// 2 seconds
	timing.effectDuration = FxGripCatTestMakeTime(90, 30);		// 3 seconds
	timing.inputStartTime = FxGripCatTestMakeTime(120, 30);		// 4 seconds
	timing.inputDuration = FxGripCatTestMakeTime(150, 30);		// 5 seconds

	XCTAssertEqual(self.effect.effectStartFrame, (NSInteger)60);
	XCTAssertEqual(self.effect.effectDurationFrames, (NSInteger)90);
	XCTAssertEqual(self.effect.inputStartFrame, (NSInteger)120);
	XCTAssertEqual(self.effect.inputDurationFrames, (NSInteger)150);
	XCTAssertEqual([self.effect frameForTime:FxGripCatTestMakeTime(1, 2)], (NSInteger)15);
}

- (void)testTimelineFrameRateIsReportedAsFractionAndSeconds
{
	[self makeEffect];
	FxGripCatTestStubTimingAPI *timing = [self installTimingAPI];
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
	FxGripCatTestStubTimingAPI *timing = [self installTimingAPI];
	timing.fpsNumerator = 30;
	timing.fpsDenominator = 1;

	timing.frameDuration = FxGripCatTestMakeTime(1, 30);
	XCTAssertEqualWithAccuracy(self.effect.retimingSpeed, 1.0, 0.0001);

	timing.frameDuration = FxGripCatTestMakeTime(2, 30);
	XCTAssertEqualWithAccuracy(self.effect.retimingSpeed, 0.5, 0.0001);

	timing.frameDuration = FxGripCatTestMakeTime(1, 60);
	XCTAssertEqualWithAccuracy(self.effect.retimingSpeed, 2.0, 0.0001);
}

- (void)testInterlacedClipsAreRecognizedByTheSampleDuration
{
	[self makeEffect];
	FxGripCatTestStubTimingAPI *timing = [self installTimingAPI];

	timing.frameDuration = FxGripCatTestMakeTime(1, 30);
	timing.sampleDuration = FxGripCatTestMakeTime(1, 30);
	XCTAssertTrue(self.effect.isInterlacedClip);

	timing.sampleDuration = FxGripCatTestMakeTime(1, 60);
	XCTAssertFalse(self.effect.isInterlacedClip);
}

/*!
	A frame count that lands a hair below the next whole frame is reported as that frame:
	the conversion rounds up within one ten-thousandth to absorb the timebase's rounding.
*/
- (void)testAFrameCountJustShortOfAWholeFrameRoundsUp
{
	[self makeEffect];
	FxGripCatTestStubTimingAPI *timing = [self installTimingAPI];
	timing.fpsNumerator = 30;
	timing.fpsDenominator = 1;

	XCTAssertEqual([self.effect frameForTime:FxGripCatTestMakeTime(3333333, 100000000)], (NSInteger)1);
	XCTAssertEqual([self.effect frameForTime:FxGripCatTestMakeTime(3000000, 100000000)], (NSInteger)0);
}

- (void)testTimelineConversionsForwardToTheHostTimingAPI
{
	[self makeEffect];
	FxGripCatTestStubTimingAPI *timing = [self installTimingAPI];

	XCTAssertTrue(FxGripCatTestTimesEqual(self.effect.effectStartTimeInTimeline, timing.timelineTime));
	XCTAssertTrue(FxGripCatTestTimesEqual(timing.lastInputTimeArgument, timing.effectStartTime));

	XCTAssertTrue(FxGripCatTestTimesEqual(self.effect.inputStartTimeInTimeline, timing.timelineTime));
	XCTAssertTrue(FxGripCatTestTimesEqual(timing.lastInputTimeArgument, timing.inputStartTime));

	CMTime converted = FxGripCatTestMakeTime(0, 1);
	[self.effect timelineTime:&converted fromInputTime:FxGripCatTestMakeTime(7, 30)];
	XCTAssertTrue(FxGripCatTestTimesEqual(converted, timing.timelineTime));
	XCTAssertTrue(FxGripCatTestTimesEqual(timing.lastInputTimeArgument, FxGripCatTestMakeTime(7, 30)));

	[self.effect inputTime:&converted fromTimelineTime:FxGripCatTestMakeTime(9, 30)];
	XCTAssertTrue(FxGripCatTestTimesEqual(converted, timing.inputTime));
	XCTAssertTrue(FxGripCatTestTimesEqual(timing.lastTimelineTimeArgument, FxGripCatTestMakeTime(9, 30)));
}

#pragma mark Project Properties

- (FxGripCatTestStubProjectAPI *)installProjectAPI
{
	FxGripCatTestStubAPIManager *manager = [self installStubAPIManager];
	FxGripCatTestStubProjectAPI *project = FxGripCatTestStubProjectAPI.new;
	manager.projectAPIv1 = project;
	manager.projectAPIv2 = project;
	return project;
}

- (void)testDocumentIdentifiesAFinalCutProProject
{
	[self makeEffect];
	FxGripCatTestStubProjectAPI *project = [self installProjectAPI];
	project.documentIDSucceeds = YES;
	project.documentID = 12;

	XCTAssertEqual(self.effect.projectDocumentID, (NSUInteger)12);
	XCTAssertTrue(self.effect.isProjectFinalCutPro);
	XCTAssertFalse(self.effect.isProjectMotion);
}

- (void)testAZeroDocumentIdentifiesAMotionProject
{
	[self makeEffect];
	FxGripCatTestStubProjectAPI *project = [self installProjectAPI];
	project.documentIDSucceeds = YES;
	project.documentID = 0;

	XCTAssertEqual(self.effect.projectDocumentID, (NSUInteger)0);
	XCTAssertTrue(self.effect.isProjectMotion);
	XCTAssertFalse(self.effect.isProjectFinalCutPro);
}

- (void)testDocumentIDReportsTheHostError
{
	[self makeEffect];
	FxGripCatTestStubProjectAPI *project = [self installProjectAPI];
	project.documentIDSucceeds = NO;

	NSError *error = nil;
	XCTAssertEqual([self.effect projectDocumentIDWithError:&error], (NSUInteger)0);
	XCTAssertEqualObjects(error.domain, @"FxGripCatTest");
}

- (void)testTheDocumentIDPropertySwallowsTheHostError
{
	[self makeEffect];
	FxGripCatTestStubProjectAPI *project = [self installProjectAPI];
	project.documentIDSucceeds = NO;

	XCTAssertEqual(self.effect.projectDocumentID, (NSUInteger)0);
	XCTAssertTrue(self.effect.isProjectMotion, @"a project that cannot be identified reads as Motion");
}

- (void)testMediaFolderReturnsTheHostURLOrNothing
{
	[self makeEffect];
	FxGripCatTestStubProjectAPI *project = [self installProjectAPI];
	project.mediaFolderSucceeds = YES;
	project.mediaFolder = [NSURL fileURLWithPath:@"/tmp/fxcat-media"];

	XCTAssertEqualObjects(self.effect.projectMediaFolder, project.mediaFolder);

	project.mediaFolderSucceeds = NO;
	XCTAssertNil(self.effect.projectMediaFolder);
}

- (void)testAspectRatioFallsBackToSixteenByNine
{
	[self makeEffect];
	FxGripCatTestStubProjectAPI *project = [self installProjectAPI];
	project.aspectRatioSucceeds = YES;
	project.aspectRatio = 2.35f;

	XCTAssertEqualWithAccuracy(self.effect.projectAspectRatio, 2.35f, 0.0001);

	project.aspectRatioSucceeds = NO;
	XCTAssertEqualWithAccuracy(self.effect.projectAspectRatio, (float)kAspectRatio16x9, 0.0001);
}

#pragma mark Extension Accessors

- (void)testTheEffectBuildsAndFindsItsOptionalExtensions
{
	FxGripCatTestEffect *effect = [self makeEffect];

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
- (FxGripAnalysisTestEffect *)makeAnalysisEffect
{
	FxGripAnalysisTestEffect *effect = [FxGripAnalysisTestEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	XCTAssertNotNil(effect);
	self.effect = effect;
	return effect;
}

- (void)testConformingToFxAnalyzerLoadsTheAnalysisExtension
{
	FxGripAnalysisTestEffect *effect = [self makeAnalysisEffect];
	XCTAssertTrue(effect.hasAnalysis);
	XCTAssertNotNil(effect.analysisData);
}

- (void)testANonConformingEffectDoesNotLoadAnalysis
{
	FxGripCatTestEffect *effect = [self makeEffect];   // FxGripCatTestEffect does not conform to FxAnalyzer
	XCTAssertFalse(effect.hasAnalysis);
	XCTAssertNil(effect.analysisData);
}

- (void)testTheFrameIndexUsesTheAnalysisFrameDuration
{
	FxGripAnalysisTestEffect *effect = [self makeAnalysisEffect];
	CMTimeRange range = { .start = FxGripAnalysisTestCMTime(0, 1), .duration = FxGripAnalysisTestCMTime(60, 30) };
	NSError *error = nil;
	XCTAssertTrue([effect setupAnalysisForTimeRange:range frameDuration:FxGripAnalysisTestCMTime(1, 30) error:&error]);

	XCTAssertEqual([effect analysisFrameIndexForTime:FxGripAnalysisTestCMTime(30, 30)], (NSInteger)30);   // 1.0s / (1/30)
	XCTAssertEqual([effect analysisFrameIndexForTime:FxGripAnalysisTestCMTime(0, 1)], (NSInteger)0);
}

- (void)testAnalyzeFrameStoresTheSubclassRecordAndReadsItBack
{
	FxGripAnalysisTestEffect *effect = [self makeAnalysisEffect];
	CMTimeRange range = { .start = FxGripAnalysisTestCMTime(0, 1), .duration = FxGripAnalysisTestCMTime(60, 30) };
	[effect setupAnalysisForTimeRange:range frameDuration:FxGripAnalysisTestCMTime(1, 30) error:NULL];

	CMTime frameTime = FxGripAnalysisTestCMTime(30, 30);   // frame index 30
	NSError *error = nil;
	XCTAssertTrue([effect analyzeFrame:(FxImageTile * _Nonnull)nil atTime:frameTime error:&error]);

	XCTAssertEqualObjects([effect analysisRecordAtTime:frameTime], @(30));
	// A later time before the next analyzed frame reads the latest at or before it.
	XCTAssertEqualObjects([effect analysisRecordAtTime:FxGripAnalysisTestCMTime(35, 30)], @(30));
	// Before any analyzed frame there is no record.
	XCTAssertNil([effect analysisRecordAtTime:FxGripAnalysisTestCMTime(0, 1)]);
}

- (void)testDesiredRangeDefaultsToTheFullInput
{
	FxGripAnalysisTestEffect *effect = [self makeAnalysisEffect];
	CMTimeRange input = { .start = FxGripAnalysisTestCMTime(10, 30), .duration = FxGripAnalysisTestCMTime(50, 30) };
	CMTimeRange desired = { 0 };

	XCTAssertTrue([effect desiredAnalysisTimeRange:&desired forInputWithTimeRange:input error:NULL]);
	XCTAssertEqual(desired.start.value, (int64_t)10);
	XCTAssertEqual(desired.start.timescale, (int32_t)30);
	XCTAssertEqual(desired.duration.value, (int64_t)50);
	XCTAssertEqual(desired.duration.timescale, (int32_t)30);
}

@end
