/*!
	@file       FxGripTileableEffectTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-10
	@header     FxGripTileableEffectTests
	@abstract   Verifies the FxPlug entry points FxGripTileableEffect implements for its host.
	@discussion Introduced in FxGrip 0.1.0. The tests drive the base class the way a host does:
	            the property dictionary it builds and locks, the setup and document callbacks, the
	            parameter-changed and parameter-clicked dispatch, the parameter policy applied to a
	            declared configuration, subscripting and enumeration of the registered parameters,
	            the notification handlers that construct and remove parameter objects, and the
	            passthrough render blit. A file-local subclass confines the notification traffic to
	            its own center and stages the plugin properties and the host API accessor.
*/

#import <XCTest/XCTest.h>
#import <CoreVideo/CoreVideo.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "FxPlugStub.h"
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripErrors.h>
#import <FxGrip/FxGripTileableEffect.h>
#import <FxGrip/FxGripTileableEffect+Notifications.h>
#import <FxGrip/FxGripAPINotifications.h>
#import <FxGrip/FxGripTileableEffect+Extensions.h>
#import <FxGrip/FxGripTileableEffect+Parameters.h>
#import <FxGrip/FxGripTileableEffect+PluginProperties.h>
#import <FxGrip/FxGripTileableGenerator.h>
#import <FxGrip/FxGripParameterUtility.h>
#import <FxGrip/FxGripMetaManager.h>
#import <FxGrip/FxGripParameter.h>
#import <FxGrip/NSCoder+FxPlug.h>
#import <FxGrip/FxGripImageRefParameter.h>
#import <FxPlug/FxOnScreenControl.h>
#import "FxGripParameterClassTestSupport.h"

/*! Implemented on FxGripTileableEffect but absent from the installed headers. */
@interface FxGripTileableEffect (FxGripTileableEffectTests)
- (BOOL)addParametersWithError:(NSError **)error;
- (nullable NSSet<Class> *)classesForCustomParameterID:(UInt32)parameterID;
- (nullable Class)classForCustomParameterID:(UInt32)parameterID;
- (BOOL)reconstructParametersWithGroupID:(FxParameterId)groupID;
- (BOOL)renderPassthroughDestinationImage:(FxImageTile *)destinationImage
							 sourceImages:(NSArray<FxImageTile *> *)sourceImages
									error:(NSError * _Nullable *)error;
@end

static const FxParameterId kEffectTestFloat = 11;
static const FxParameterId kEffectTestToggle = 12;
static const FxParameterId kEffectTestGroup = 13;
static const FxParameterId kEffectTestChild = 14;

static CMTime FxGripEffectTestTime(int64_t value, int32_t timescale)
{
	return (CMTime){ .value = value, .timescale = timescale, .flags = kCMTimeFlags_Valid, .epoch = 0 };
}

/*! Keyed-archive bytes standing in for the host's pluginState argument. */
static NSData *FxGripEffectTestState(void)
{
	NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:NO];
	[archiver encodeObject:@"probe" forKey:@"probe"];
	[archiver finishEncoding];
	return archiver.encodedData;
}

#pragma mark - Host API doubles

/*! Answers the parameter count and the ordinal-to-ID mapping the subscript path reads. */
@interface FxGripEffectTestDynamicAPI : NSObject
@property (nonatomic, copy) NSArray<NSNumber *> *parameterIDs;
@end

@implementation FxGripEffectTestDynamicAPI

- (UInt32)parameterCount
{
	return (UInt32)self.parameterIDs.count;
}

- (UInt32)parameterIDAtIndex:(UInt32)index
{
	return self.parameterIDs[index].unsignedIntValue;
}

@end

/*! Records the action bracket the click dispatch opens and closes. */
@interface FxGripEffectTestActionAPI : NSObject
@property (nonatomic, strong) NSMutableArray<NSString *> *calls;
@end

@implementation FxGripEffectTestActionAPI

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		_calls = NSMutableArray.array;
	}
	return self;
}

- (BOOL)startAction:(id)effect
{
	[self.calls addObject:@"startAction"];
	return YES;
}

- (BOOL)endAction:(id)effect
{
	[self.calls addObject:@"endAction"];
	return YES;
}

@end

/*! Vends the two host APIs the base class reaches for outside the render path. */
@interface FxGripEffectTestAPIManager : NSObject
@property (nonatomic, strong, nullable) FxGripEffectTestDynamicAPI *dynamicAPI;
@property (nonatomic, strong, nullable) FxGripEffectTestActionAPI *customParameterActionAPIv4;
@end

@implementation FxGripEffectTestAPIManager

- (id)apiForProtocol:(Protocol *)protocol
{
	return self.dynamicAPI;
}

@end

#pragma mark - Effect doubles

/*! Confines notification traffic to a private center and stages the plugin properties and host APIs. */
@interface FxGripEffectTestEffect : FxGripTileableEffect
@property (nonatomic, strong) NSNotificationCenter *privateNotifier;
@property (nonatomic, strong, nullable) NSDictionary<NSString *, id> *stubPluginProperties;
@property (nonatomic, strong, nullable) id stubAPIManager;
@property (nonatomic, assign) BOOL stubEffectPropertiesInInfo;
@end

@implementation FxGripEffectTestEffect

- (id)effectBase
{
	return self;
}

- (NSPriorityNotificationCenter *)notifier
{
	if (!_privateNotifier) {
		_privateNotifier = (NSNotificationCenter *)FxGripParamClassTestMakePriorityCenter();
	}
	return (NSPriorityNotificationCenter *)_privateNotifier;
}

- (NSDictionary<NSString *, id> *)pluginProperties
{
	if (_stubPluginProperties) {
		return _stubPluginProperties;
	}
	return [super pluginProperties];
}

- (id<FxGripAPIAccessing>)apiManager
{
	if (_stubAPIManager) {
		return (id<FxGripAPIAccessing>)_stubAPIManager;
	}
	return [super apiManager];
}

- (BOOL)isEffectPropertiesInInfo
{
	return _stubEffectPropertiesInInfo;
}

@end

/*! Records the configuration-declared click selector the dispatch performs. */
@interface FxGripEffectTestClickEffect : FxGripEffectTestEffect
@property (nonatomic, assign) NSUInteger declaredClicks;
@end

@implementation FxGripEffectTestClickEffect

- (void)fxGripEffectTestDeclaredAction
{
	self.declaredClicks += 1;
}

@end

/*! Answers the coder-based render callbacks, so the base takes the coder-state path. */
@interface FxGripEffectTestCoderEffect : FxGripEffectTestEffect <FxGripTileableEffectCoderState>
@property (nonatomic, assign) BOOL codedRenderCalled;
@property (nonatomic, assign) BOOL scheduleCalled;
@property (nonatomic, strong, nullable) NSArray<FxImageTileRequest *> *stagedRequests;
@end

@implementation FxGripEffectTestCoderEffect

- (BOOL)pluginCoder:(NSCoder *)coder
			 atTime:(CMTime)renderTime
			quality:(FxQuality)qualityLevel
			  error:(NSError * _Nullable *)error
{
	[coder encodeInt64:renderTime.value forKey:@"fxGripTestRenderTime"];
	return YES;
}

- (BOOL)destinationImageRect:(FxRect *)destinationImageRect
				sourceImages:(NSArray<FxImageTile *> *)sourceImages
			destinationImage:(FxImageTile *)destinationImage
				 pluginCoder:(NSCoder *)pluginCoder
					  atTime:(CMTime)renderTime
					   error:(NSError * _Nullable *)outError
{
	return YES;
}

- (BOOL)sourceTileRect:(FxRect *)sourceTileRect
	  sourceImageIndex:(NSUInteger)sourceImageIndex
		  sourceImages:(NSArray<FxImageTile *> *)sourceImages
   destinationTileRect:(FxRect)destinationTileRect
	  destinationImage:(FxImageTile *)destinationImage
		   pluginCoder:(NSCoder *)pluginCoder
				atTime:(CMTime)renderTime
				 error:(NSError * _Nullable *)outError
{
	return YES;
}

- (BOOL)renderDestinationImage:(FxImageTile *)destinationImage
				  sourceImages:(NSArray<FxImageTile *> *)sourceImages
				   pluginCoder:(NSCoder *)pluginCoder
						atTime:(CMTime)renderTime
						 error:(NSError * _Nullable *)outError
{
	self.codedRenderCalled = YES;
	return YES;
}

- (BOOL)scheduleInputs:(NSArray<FxImageTileRequest *> * _Nullable * _Nullable)inputImageRequests
		   pluginCoder:(NSCoder * _Nullable)pluginCoder
				atTime:(CMTime)renderTime
				 error:(NSError * _Nullable * _Nonnull)error
{
	self.scheduleCalled = YES;
	if (self.stagedRequests != nil) {
		*inputImageRequests = (NSArray<FxImageTileRequest *> *)self.stagedRequests.mutableCopy;
	}
	return YES;
}

@end

/*! Refuses every coder-based callback, so the base reports each stage's failure. */
@interface FxGripEffectTestRefusingCoderEffect : FxGripEffectTestCoderEffect
@property (nonatomic, assign) BOOL refusesPluginCoder;
@end

@implementation FxGripEffectTestRefusingCoderEffect

- (BOOL)pluginCoder:(NSCoder *)coder
			 atTime:(CMTime)renderTime
			quality:(FxQuality)qualityLevel
			  error:(NSError * _Nullable *)error
{
	return !self.refusesPluginCoder;
}

- (BOOL)destinationImageRect:(FxRect *)destinationImageRect
				sourceImages:(NSArray<FxImageTile *> *)sourceImages
			destinationImage:(FxImageTile *)destinationImage
				 pluginCoder:(NSCoder *)pluginCoder
					  atTime:(CMTime)renderTime
					   error:(NSError * _Nullable *)outError
{
	return NO;
}

- (BOOL)sourceTileRect:(FxRect *)sourceTileRect
	  sourceImageIndex:(NSUInteger)sourceImageIndex
		  sourceImages:(NSArray<FxImageTile *> *)sourceImages
   destinationTileRect:(FxRect)destinationTileRect
	  destinationImage:(FxImageTile *)destinationImage
		   pluginCoder:(NSCoder *)pluginCoder
				atTime:(CMTime)renderTime
				 error:(NSError * _Nullable *)outError
{
	return NO;
}

- (BOOL)renderDestinationImage:(FxImageTile *)destinationImage
				  sourceImages:(NSArray<FxImageTile *> *)sourceImages
				   pluginCoder:(NSCoder *)pluginCoder
						atTime:(CMTime)renderTime
						 error:(NSError * _Nullable *)outError
{
	return NO;
}

- (BOOL)scheduleInputs:(NSArray<FxImageTileRequest *> * _Nullable * _Nullable)inputImageRequests
		   pluginCoder:(NSCoder * _Nullable)pluginCoder
				atTime:(CMTime)renderTime
				 error:(NSError * _Nullable * _Nonnull)error
{
	return NO;
}

@end

/*! Acts as its own extension, so the loader installs the effect itself. */
@interface FxGripEffectTestSelfExtensionEffect : FxGripEffectTestEffect <FxGripExtension>
@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wprotocol"
@implementation FxGripEffectTestSelfExtensionEffect
@end
#pragma clang diagnostic pop

/*! Declares the on-screen-control protocol, which the click dispatch treats as needing no action bracket. */
@interface FxGripEffectTestOSCEffect : FxGripEffectTestEffect <FxOnScreenControl_v4>
@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wprotocol"
@implementation FxGripEffectTestOSCEffect
@end
#pragma clang diagnostic pop

/*! A generator subclass, which the render path exempts from the passthrough blit. */
@interface FxGripEffectTestGenerator : FxGripTileableGenerator
@property (nonatomic, strong) NSNotificationCenter *privateNotifier;
@end

@implementation FxGripEffectTestGenerator

- (id)effectBase
{
	return self;
}

- (NSPriorityNotificationCenter *)notifier
{
	if (!_privateNotifier) {
		_privateNotifier = (NSNotificationCenter *)FxGripParamClassTestMakePriorityCenter();
	}
	return (NSPriorityNotificationCenter *)_privateNotifier;
}

@end

#pragma mark - Tests

@interface FxGripTileableEffectTests : XCTestCase
@property (nonatomic, strong) FxGripEffectTestEffect *effect;
@property (nonatomic, strong) NSMutableArray *observerTokens;
@end

@implementation FxGripTileableEffectTests

- (void)setUp
{
	[super setUp];
	self.observerTokens = NSMutableArray.array;
}

- (void)tearDown
{
	self.observerTokens = nil;
	self.effect = nil;
	[super tearDown];
}

- (FxGripEffectTestEffect *)makeEffectOfClass:(Class)effectClass
{
	FxGripEffectTestEffect *effect = [[effectClass alloc] initWithAPIManager:(id _Nonnull)nil];
	XCTAssertNotNil(effect);
	self.effect = effect;
	return effect;
}

- (FxGripEffectTestEffect *)makeEffect
{
	return [self makeEffectOfClass:FxGripEffectTestEffect.class];
}

/*! Observes one notification on the effect's private center; the center holds observers weakly. */
- (void)onEffect:(FxGripEffectTestEffect *)effect
	 observeName:(NSNotificationName)name
	  usingBlock:(void (^)(NSNotification *notification))block
{
	id token = [effect.notifier addObserverForName:name object:nil queue:nil usingBlock:block];
	[self.observerTokens addObject:token];
}

/*! A plugin-qualified properties dictionary (uuid, className, group). */
- (NSMutableDictionary *)pluginPropertiesDictionary
{
	return [NSMutableDictionary dictionaryWithDictionary:@{
		kProPlugPlugIn_UuidProperty: @"AAAABBBB-CCCC-DDDD-EEEE-FFFF00003333",
		kProPlugPlugIn_ClassNameProperty: @"FxGripEffectTestEffect",
		kProPlugPlugIn_GroupUUIDProperty: @"33330000-FFFF-EEEE-DDDD-CCCCBBBBAAAA",
	}];
}

#pragma mark Effect properties

/*! @abstract A nil properties pointer is refused with an invalid-parameter error. */
- (void)testPropertiesRefusesANilPropertiesPointer
{
	FxGripEffectTestEffect *effect = [self makeEffect];
	NSError *error = nil;

	XCTAssertFalse([effect properties:NULL error:&error]);
	XCTAssertEqualObjects(error.domain, FxGripPlugErrorDomain);
	XCTAssertEqual(error.code, (NSInteger)kFxError_InvalidParameter);
	XCTAssertFalse(effect.finishedProperties, @"a refused call leaves the properties unlocked");
}

/*! @abstract The defaults write only the FxPlug keys that differ from the FxPlug default, and the call locks the properties. */
- (void)testPropertiesWritesOnlyTheKeysThatDifferFromTheFxPlugDefaults
{
	FxGripEffectTestEffect *effect = [self makeEffect];
	NSDictionary *properties = nil;
	NSError *error = nil;

	XCTAssertTrue([effect properties:&properties error:&error]);

	XCTAssertNil(error);
	XCTAssertNil(properties[kFxPropertyKey_NeedsFullBuffer], @"NO matches the FxPlug default");
	XCTAssertNil(properties[kFxPropertyKey_VariesWhenParamsAreStatic]);
	XCTAssertNil(properties[kFxPropertyKey_UsesNonmatchingTextureLayout]);
	XCTAssertNil(properties[kFxPropertyKey_DrawsInScreenSpace]);
	XCTAssertNil(properties[kFxPropertyKey_ChangesOutputSize], @"YES matches the FxGrip default");
	XCTAssertNil(properties[kFxPropertyKey_MayRemapTime]);
	XCTAssertNil(properties[kFxPropertyKey_DesiredProcessingColorInfo]);
	XCTAssertNil(properties[kFxPropertyKey_PixelTransformSupport]);
	XCTAssertTrue(effect.finishedProperties);
}

/*! @abstract Each effect setting that differs from its default is written into the property dictionary. */
- (void)testPropertiesWritesEverySettingThatDiffersFromItsDefault
{
	FxGripEffectTestEffect *effect = [self makeEffect];
	effect.needsFullBuffer = YES;
	effect.variesWhenParamsAreStatic = YES;
	effect.changesOutputSize = NO;
	effect.mayRemapTime = NO;
	effect.usesNonmatchingTextureLayout = YES;
	effect.drawsInScreenSpace = YES;
	effect.desiredProcessingColorInfo = kFxImageColorInfo_RGB_GAMMA_VIDEO;
	effect.pixelTransformSupport = kFxPixelTransform_Full;
	NSDictionary *properties = nil;
	NSError *error = nil;

	XCTAssertTrue([effect properties:&properties error:&error]);

	XCTAssertEqualObjects(properties[kFxPropertyKey_NeedsFullBuffer], @YES);
	XCTAssertEqualObjects(properties[kFxPropertyKey_VariesWhenParamsAreStatic], @YES);
	XCTAssertEqualObjects(properties[kFxPropertyKey_ChangesOutputSize], @NO);
	XCTAssertEqualObjects(properties[kFxPropertyKey_MayRemapTime], @NO);
	XCTAssertEqualObjects(properties[kFxPropertyKey_UsesNonmatchingTextureLayout], @YES);
	XCTAssertEqualObjects(properties[kFxPropertyKey_DrawsInScreenSpace], @YES);
	XCTAssertEqualObjects(properties[kFxPropertyKey_DesiredProcessingColorInfo], @(kFxImageColorInfo_RGB_GAMMA_VIDEO));
	XCTAssertEqualObjects(properties[kFxPropertyKey_PixelTransformSupport], @(kFxPixelTransform_Full));
}

/*! @abstract A property the caller supplies wins over the effect's own setting and updates it. */
- (void)testACallerSuppliedPropertyOverridesTheEffectSetting
{
	FxGripEffectTestEffect *effect = [self makeEffect];
	effect.needsFullBuffer = NO;
	effect.changesOutputSize = YES;
	NSDictionary *properties = @{
		kFxPropertyKey_NeedsFullBuffer: @YES,
		kFxPropertyKey_VariesWhenParamsAreStatic: @YES,
		kFxPropertyKey_ChangesOutputSize: @NO,
		kFxPropertyKey_MayRemapTime: @NO,
		kFxPropertyKey_UsesNonmatchingTextureLayout: @YES,
		kFxPropertyKey_DrawsInScreenSpace: @YES,
		kFxPropertyKey_DesiredProcessingColorInfo: @(kFxImageColorInfo_RGB_GAMMA_VIDEO),
		kFxPropertyKey_PixelTransformSupport: @(kFxPixelTransform_Scale),
	};
	NSError *error = nil;

	XCTAssertTrue([effect properties:&properties error:&error]);

	XCTAssertTrue(effect.needsFullBuffer);
	XCTAssertTrue(effect.variesWhenParamsAreStatic);
	XCTAssertFalse(effect.changesOutputSize);
	XCTAssertFalse(effect.mayRemapTime);
	XCTAssertTrue(effect.usesNonmatchingTextureLayout);
	XCTAssertTrue(effect.drawsInScreenSpace);
	XCTAssertEqual(effect.desiredProcessingColorInfo, (FxImageColorInfo)kFxImageColorInfo_RGB_GAMMA_VIDEO);
	XCTAssertEqual(effect.pixelTransformSupport, (FxPixelTransformSupport)kFxPixelTransform_Scale);
}

/*! @abstract An effect declaring its properties in the registration record starts from that dictionary. */
- (void)testPropertiesSeedFromTheRegistrationRecordWhenDeclaredThere
{
	FxGripEffectTestEffect *effect = [self makeEffect];
	NSMutableDictionary *pluginProperties = [self pluginPropertiesDictionary];
	pluginProperties[kProPlugPlugInX_EffectPropertiesProperty] = @{
		kFxPropertyKey_NeedsFullBuffer: @YES,
		@"fxGripTestExtra": @"declared",
	};
	effect.stubPluginProperties = pluginProperties;
	effect.stubEffectPropertiesInInfo = YES;
	NSDictionary *properties = nil;
	NSError *error = nil;

	XCTAssertTrue([effect properties:&properties error:&error]);

	XCTAssertEqualObjects(properties[kFxPropertyKey_NeedsFullBuffer], @YES);
	XCTAssertEqualObjects(properties[@"fxGripTestExtra"], @"declared");
	XCTAssertTrue(effect.needsFullBuffer, @"the declared record sets the effect's own flag");
}

/*! @abstract An observer revises the property dictionary before it reaches the host. */
- (void)testAnObserverRevisesThePropertyDictionary
{
	FxGripEffectTestEffect *effect = [self makeEffect];
	[self onEffect:effect observeName:FxGripTileableEffectPropertiesName usingBlock:^(NSNotification *notification) {
		notification.userInfo.fxEffectProperties[@"fxGripTestObserver"] = @"revised";
	}];
	NSDictionary *properties = nil;
	NSError *error = nil;

	XCTAssertTrue([effect properties:&properties error:&error]);

	XCTAssertEqualObjects(properties[@"fxGripTestObserver"], @"revised");
}

/*! @abstract An observer's error travels back to the host through the error pointer. */
- (void)testAnObserverErrorReachesTheHostFromTheProperties
{
	FxGripEffectTestEffect *effect = [self makeEffect];
	NSError *staged = [NSError errorWithDomain:@"FxGripEffectTest" code:7 userInfo:nil];
	[self onEffect:effect observeName:FxGripTileableEffectPropertiesName usingBlock:^(NSNotification *notification) {
		((NSMutableDictionary *)notification.userInfo).fxError = staged;
	}];
	NSDictionary *properties = nil;
	NSError *error = nil;

	XCTAssertTrue([effect properties:&properties error:&error]);

	XCTAssertEqualObjects(error, staged);
}

/*! @abstract The property setters are ignored once the properties callback has locked them. */
- (void)testThePropertySettersAreIgnoredOnceThePropertiesAreLocked
{
	FxGripEffectTestEffect *effect = [self makeEffect];
	NSDictionary *properties = nil;
	NSError *error = nil;
	XCTAssertTrue([effect properties:&properties error:&error]);

	effect.needsFullBuffer = YES;
	effect.variesWhenParamsAreStatic = YES;
	effect.changesOutputSize = NO;
	effect.mayRemapTime = NO;
	effect.usesNonmatchingTextureLayout = YES;
	effect.drawsInScreenSpace = YES;
	effect.desiredProcessingColorInfo = kFxImageColorInfo_RGB_GAMMA_VIDEO;
	effect.pixelTransformSupport = kFxPixelTransform_Full;

	XCTAssertFalse(effect.needsFullBuffer);
	XCTAssertFalse(effect.variesWhenParamsAreStatic);
	XCTAssertTrue(effect.changesOutputSize);
	XCTAssertTrue(effect.mayRemapTime);
	XCTAssertFalse(effect.usesNonmatchingTextureLayout);
	XCTAssertFalse(effect.drawsInScreenSpace);
	XCTAssertEqual(effect.desiredProcessingColorInfo, (FxImageColorInfo)kFxImageColorInfo_RGB_LINEAR);
	XCTAssertEqual(effect.pixelTransformSupport, (FxPixelTransformSupport)kFxPixelTransform_ScaleTranslate);
}

#pragma mark Setup callbacks

/*! @abstract finishInitialSetup: marks the effect set up and posts its notification. */
- (void)testFinishInitialSetupMarksTheEffectAndPostsItsNotification
{
	FxGripEffectTestEffect *effect = [self makeEffect];
	__block BOOL posted = NO;
	[self onEffect:effect observeName:FxGripTileableEffectFinishInitialSetupName usingBlock:^(NSNotification *notification) {
		posted = YES;
	}];
	NSError *error = nil;

	XCTAssertTrue([effect finishInitialSetup:&error]);

	XCTAssertTrue(posted);
	XCTAssertTrue(effect.finishedSetup);
	XCTAssertNil(error);
}

/*! @abstract An observer error makes finishInitialSetup: report failure. */
- (void)testFinishInitialSetupReportsAnObserverError
{
	FxGripEffectTestEffect *effect = [self makeEffect];
	NSError *staged = [NSError errorWithDomain:@"FxGripEffectTest" code:8 userInfo:nil];
	[self onEffect:effect observeName:FxGripTileableEffectFinishInitialSetupName usingBlock:^(NSNotification *notification) {
		((NSMutableDictionary *)notification.userInfo).fxError = staged;
	}];
	NSError *error = nil;

	XCTAssertFalse([effect finishInitialSetup:&error]);

	XCTAssertEqualObjects(error, staged);
}

/*! @abstract pluginInstanceAddedToDocument marks the effect and posts the added-to-document notification. */
- (void)testAddingToADocumentMarksTheEffectAndPostsItsNotification
{
	FxGripEffectTestEffect *effect = [self makeEffect];
	__block BOOL posted = NO;
	[self onEffect:effect observeName:FxGripTileableEffectAddedToDocumentName usingBlock:^(NSNotification *notification) {
		posted = YES;
	}];

	[effect pluginInstanceAddedToDocument];

	XCTAssertTrue(posted);
	XCTAssertTrue(effect.addedToDocument);
	XCTAssertTrue(effect.finishedSetup);
}

#pragma mark Custom parameter classes

/*! @abstract The instance-meta parameter decodes as the meta manager, and any other ID declares no class. */
- (void)testTheInstanceMetaParameterDeclaresTheMetaManagerClass
{
	FxGripEffectTestEffect *effect = [self makeEffect];

	XCTAssertEqualObjects([effect classForCustomParameterID:kFxParameterId_InstanceMeta], FxGripMetaManager.class);
	XCTAssertNil([effect classForCustomParameterID:kEffectTestFloat]);

	NSSet<Class> *classes = [effect classesForCustomParameterID:kFxParameterId_InstanceMeta];
	XCTAssertTrue([classes containsObject:FxGripMetaManager.class]);
	XCTAssertNil([effect classesForCustomParameterID:kEffectTestFloat], @"an unconfigured parameter declares none");
}

#pragma mark Parameter changed

/*! @abstract A parameter change posts the ID and time, and reports success. */
- (void)testAParameterChangePostsTheIdentifierAndTime
{
	FxGripEffectTestEffect *effect = [self makeEffect];
	__block NSNotification *seen = nil;
	[self onEffect:effect observeName:FxGripTileableEffectParameterChangedName usingBlock:^(NSNotification *notification) {
		seen = notification;
	}];
	NSError *error = nil;

	XCTAssertTrue([effect parameterChanged:kEffectTestFloat atTime:FxGripEffectTestTime(24, 24) error:&error]);

	XCTAssertNil(error);
	XCTAssertEqualObjects(seen.userInfo[FxGripTileableEffectParameterChangedIDKey], @(kEffectTestFloat));
	NSDictionary *timeDictionary = seen.userInfo[FxGripTileableEffectParameterChangedAtTimeKey];
	XCTAssertNotNil(timeDictionary);
	CMTime decoded = CMTimeMakeFromDictionary((__bridge CFDictionaryRef)timeDictionary);
	XCTAssertEqual(decoded.value, (int64_t)24);
	XCTAssertEqual(decoded.timescale, (int32_t)24);
}

/*! @abstract An observer error makes the parameter change report failure and reaches the host. */
- (void)testAParameterChangeReportsAnObserverError
{
	FxGripEffectTestEffect *effect = [self makeEffect];
	NSError *staged = [NSError errorWithDomain:@"FxGripEffectTest" code:9 userInfo:nil];
	[self onEffect:effect observeName:FxGripTileableEffectParameterChangedName usingBlock:^(NSNotification *notification) {
		((NSMutableDictionary *)notification.userInfo).fxError = staged;
	}];
	NSError *error = nil;

	XCTAssertFalse([effect parameterChanged:kEffectTestFloat atTime:FxGripEffectTestTime(0, 1) error:&error]);

	XCTAssertEqualObjects(error, staged);
}

#pragma mark Parameter clicks

/*! @abstract A click posts the parameter ID and brackets the dispatch with the host's action API. */
- (void)testAClickPostsTheParameterIDInsideAnActionBracket
{
	FxGripEffectTestEffect *effect = [self makeEffect];
	FxGripEffectTestAPIManager *apiManager = FxGripEffectTestAPIManager.new;
	apiManager.customParameterActionAPIv4 = FxGripEffectTestActionAPI.new;
	effect.stubAPIManager = apiManager;
	__block NSNotification *seen = nil;
	[self onEffect:effect observeName:FxGripTileableEffectParameterClickedName usingBlock:^(NSNotification *notification) {
		seen = notification;
	}];

	XCTAssertTrue([effect parameterClicked:kEffectTestFloat]);

	XCTAssertEqualObjects(seen.userInfo[FxGripTileableEffectParameterClickedIDKey], @(kEffectTestFloat));
	XCTAssertEqualObjects(apiManager.customParameterActionAPIv4.calls, (@[@"startAction", @"endAction"]));
}

/*! @abstract A click reports failure when an observer sets an error. */
- (void)testAClickReportsAnObserverError
{
	FxGripEffectTestEffect *effect = [self makeEffect];
	[self onEffect:effect observeName:FxGripTileableEffectParameterClickedName usingBlock:^(NSNotification *notification) {
		((NSMutableDictionary *)notification.userInfo).fxError =
			[NSError errorWithDomain:@"FxGripEffectTest" code:10 userInfo:nil];
	}];

	XCTAssertFalse([effect parameterClicked:kEffectTestFloat]);
}

/*! @abstract A configuration-declared selector the subclass implements is performed on the click. */
- (void)testAClickPerformsTheConfigurationDeclaredSelector
{
	FxGripEffectTestClickEffect *effect =
		(FxGripEffectTestClickEffect *)[self makeEffectOfClass:FxGripEffectTestClickEffect.class];
	NSMutableDictionary *properties = [self pluginPropertiesDictionary];
	properties[kProPlugPlugInX_ParametersProperty] = @[@{
		kFxParameterProperty_Id: @(kEffectTestFloat),
		kFxParameterProperty_Type: kFxParameterType_PushButton,
		kFxParameterProperty_Name: @"Go",
		kFxParameterProperty_Selector: @"fxGripEffectTestDeclaredAction",
	}];
	effect.stubPluginProperties = properties;
	NSError *error = nil;
	[effect addParametersWithError:&error];

	XCTAssertTrue([effect parameterClicked:kEffectTestFloat]);

	XCTAssertEqual(effect.declaredClicks, (NSUInteger)1);
}

/*! @abstract A synthesized click selector dispatches through the trampoline to parameterClicked:. */
- (void)testTheSynthesizedClickSelectorReachesTheClickDispatch
{
	FxGripEffectTestEffect *effect = [self makeEffect];
	__block NSNotification *seen = nil;
	[self onEffect:effect observeName:FxGripTileableEffectParameterClickedName usingBlock:^(NSNotification *notification) {
		seen = notification;
	}];
	SEL synthesized = NSSelectorFromString([FxGripParameterUtility clickSelectorNameForParameter:kEffectTestToggle]);

	XCTAssertTrue([effect respondsToSelector:synthesized]);
	((void (*)(id, SEL))objc_msgSend)(effect, synthesized);

	XCTAssertEqualObjects(seen.userInfo[FxGripTileableEffectParameterClickedIDKey], @(kEffectTestToggle));
}

#pragma mark Parameter policy

/*! @abstract A font menu with no declared font takes the effect's default font. */
- (void)testTheParameterPolicyFillsAFontMenuDefault
{
	FxGripEffectTestEffect *effect = [self makeEffect];
	NSMutableDictionary *configuration = [NSMutableDictionary dictionaryWithDictionary:@{
		kFxParameterProperty_Id: @(kEffectTestFloat),
		kFxParameterProperty_Type: kFxParameterType_FontMenu,
		kFxParameterProperty_Name: @"Font",
	}];

	[effect.notifier postNotificationName:FxGripTileableEffectParameterPolicyName
								   object:effect
								 userInfo:@{ FxGripNotifyAPI_ParameterKey: configuration }];

	XCTAssertEqualObjects(configuration[kFxParameterProperty_Default], effect.defaultFontName);
}

/*! @abstract A font menu that declares its own font keeps it. */
- (void)testTheParameterPolicyKeepsADeclaredFont
{
	FxGripEffectTestEffect *effect = [self makeEffect];
	NSMutableDictionary *configuration = [NSMutableDictionary dictionaryWithDictionary:@{
		kFxParameterProperty_Id: @(kEffectTestFloat),
		kFxParameterProperty_Type: kFxParameterType_FontMenu,
		kFxParameterProperty_Name: @"Font",
		kFxParameterProperty_Default: @"Courier",
	}];

	[effect.notifier postNotificationName:FxGripTileableEffectParameterPolicyName
								   object:effect
								 userInfo:@{ FxGripNotifyAPI_ParameterKey: configuration }];

	XCTAssertEqualObjects(configuration[kFxParameterProperty_Default], @"Courier");
}

/*! @abstract A color that declares no color space is left alone by the policy. */
- (void)testTheParameterPolicyLeavesAColorWithoutAColorSpaceAlone
{
	FxGripEffectTestEffect *effect = [self makeEffect];
	NSMutableDictionary *color = [NSMutableDictionary dictionaryWithDictionary:@{
		kFxParameterProperty_Red: @0.5, kFxParameterProperty_Green: @0.5, kFxParameterProperty_Blue: @0.5,
	}];
	NSMutableDictionary *configuration = [NSMutableDictionary dictionaryWithDictionary:@{
		kFxParameterProperty_Id: @(kEffectTestFloat),
		kFxParameterProperty_Type: kFxParameterType_RGBA,
		kFxParameterProperty_Name: @"Tint",
		kFxParameterProperty_Default: color,
	}];

	[effect.notifier postNotificationName:FxGripTileableEffectParameterPolicyName
								   object:effect
								 userInfo:@{ FxGripNotifyAPI_ParameterKey: configuration }];

	XCTAssertEqualObjects(color[kFxParameterProperty_Red], @0.5);
}

/*! @abstract A policy notification carrying no parameter dictionary is ignored. */
- (void)testTheParameterPolicyIgnoresANotificationWithoutAParameter
{
	FxGripEffectTestEffect *effect = [self makeEffect];

	XCTAssertNoThrow([effect.notifier postNotificationName:FxGripTileableEffectParameterPolicyName
													object:effect
												  userInfo:@{}]);
}

#pragma mark Group parameters

/*! @abstract A group announcing its subgroup adds the group's declared children. */
- (void)testAGroupNotificationAddsTheGroupsDeclaredChildren
{
	FxGripEffectTestEffect *effect = [self makeEffect];
	NSMutableDictionary *properties = [self pluginPropertiesDictionary];
	properties[kProPlugPlugInX_ParametersProperty] = @[
		@{
			kFxParameterProperty_Id: @(kEffectTestGroup),
			kFxParameterProperty_Type: kFxParameterType_Group,
			kFxParameterProperty_Name: @"Group",
		},
		@{
			kFxParameterProperty_Id: @(kEffectTestChild),
			kFxParameterProperty_Type: kFxParameterType_Float,
			kFxParameterProperty_Name: @"Child",
			kFxParameterProperty_ParentId: @(kEffectTestGroup),
		},
	];
	effect.stubPluginProperties = properties;
	NSError *error = nil;
	[effect addParametersWithError:&error];

	[effect.notifier postNotificationName:FxGripTileableEffectAddGroupParametersName
								   object:effect
								 userInfo:@{ FxGripTileableEffectGroupIDKey: @(kEffectTestGroup) }];

	XCTAssertNotNil([effect configurationForParameter:kEffectTestChild],
					@"the group's child is registered in the flattened configuration");
	XCTAssertNotNil([effect configurationForParameter:kEffectTestGroup]);
}

/*! @abstract A group notification carrying no group ID is ignored. */
- (void)testAGroupNotificationWithoutAGroupIdentifierIsIgnored
{
	FxGripEffectTestEffect *effect = [self makeEffect];

	XCTAssertNoThrow([effect.notifier postNotificationName:FxGripTileableEffectAddGroupParametersName
													object:effect
												  userInfo:@{ FxGripTileableEffectGroupIDKey: @"not a number" }]);
}

#pragma mark Parameter registry

/*! @abstract A parameter-add notification constructs the parameter object and the parameters dictionary reports it. */
- (void)testAParameterAddNotificationRegistersTheParameterObject
{
	FxGripEffectTestEffect *effect = [self makeEffect];

	[effect.notifier postNotificationName:FxGripNotifyAPI_ParameterAddName
								   object:effect
								 userInfo:FxGripParamClassTestConfig(kEffectTestFloat, kFxParameterType_Float, @"Level", nil)];

	id<FxGripParameter> parameter = effect.parameters[@(kEffectTestFloat)];
	XCTAssertNotNil(parameter);
	XCTAssertEqual(parameter.parameterID, kEffectTestFloat);
}

/*! @abstract A parameter-remove notification drops the parameter object. */
- (void)testAParameterRemoveNotificationDropsTheParameterObject
{
	FxGripEffectTestEffect *effect = [self makeEffect];
	[effect.notifier postNotificationName:FxGripNotifyAPI_ParameterAddName
								   object:effect
								 userInfo:FxGripParamClassTestConfig(kEffectTestFloat, kFxParameterType_Float, @"Level", nil)];
	XCTAssertNotNil(effect.parameters[@(kEffectTestFloat)]);

	[effect.notifier postNotificationName:FxGripNotifyAPI_ParameterRemoveName
								   object:effect
								 userInfo:@{ kFxParameterProperty_Id: @(kEffectTestFloat) }];

	XCTAssertNil(effect.parameters[@(kEffectTestFloat)]);
}

/*! @abstract A parameter-remove notification carrying no ID removes nothing. */
- (void)testAParameterRemoveNotificationWithoutAnIdentifierRemovesNothing
{
	FxGripEffectTestEffect *effect = [self makeEffect];
	[effect.notifier postNotificationName:FxGripNotifyAPI_ParameterAddName
								   object:effect
								 userInfo:FxGripParamClassTestConfig(kEffectTestFloat, kFxParameterType_Float, @"Level", nil)];

	[effect.notifier postNotificationName:FxGripNotifyAPI_ParameterRemoveName object:effect userInfo:@{}];

	XCTAssertNotNil(effect.parameters[@(kEffectTestFloat)]);
}

/*! @abstract The flush notification reaches every registered parameter. */
- (void)testTheFlushNotificationReachesEveryParameter
{
	FxGripEffectTestEffect *effect = [self makeEffect];
	[effect.notifier postNotificationName:FxGripNotifyAPI_ParameterAddName
								   object:effect
								 userInfo:FxGripParamClassTestConfig(kEffectTestFloat, kFxParameterType_Float, @"Level", nil)];

	XCTAssertNoThrow([effect.notifier postNotificationName:FxGripTileableEffectFlushName object:effect userInfo:@{}]);
}

/*! @abstract The add-pre notification copies the declared extension key onto the parameter being created. */
- (void)testTheAddPreNotificationCopiesTheDeclaredExtensionKey
{
	FxGripEffectTestEffect *effect = [self makeEffect];
	NSMutableDictionary *properties = [self pluginPropertiesDictionary];
	properties[kProPlugPlugInX_ParametersProperty] = @[@{
		kFxParameterProperty_Id: @(kEffectTestFloat),
		kFxParameterProperty_Type: kFxParameterType_Float,
		kFxParameterProperty_Name: @"Level",
		kFxParameterProperty_ExtensionKey: @"fxGripTestExtension",
	}];
	effect.stubPluginProperties = properties;
	NSError *error = nil;
	[effect addParametersWithError:&error];
	NSMutableDictionary *creating = [NSMutableDictionary dictionaryWithDictionary:@{
		kFxParameterProperty_Id: @(kEffectTestFloat),
		kFxParameterProperty_Type: kFxParameterType_Float,
		kFxParameterProperty_Name: @"Level",
	}];

	[effect.notifier postNotificationName:FxGripNotifyAPI_ParameterAddPreName
								   object:effect
								 userInfo:@{ FxGripNotifyAPI_ParameterKey: creating }];

	XCTAssertEqualObjects(creating[kFxParameterProperty_ExtensionKey], @"fxGripTestExtension");
}

/*! @abstract The add-pre notification ignores a parameter with no ID and one the configuration does not declare. */
- (void)testTheAddPreNotificationIgnoresUnknownParameters
{
	FxGripEffectTestEffect *effect = [self makeEffect];
	NSMutableDictionary *unknown = [NSMutableDictionary dictionaryWithDictionary:@{
		kFxParameterProperty_Id: @(kEffectTestToggle),
		kFxParameterProperty_Type: kFxParameterType_Toggle,
		kFxParameterProperty_Name: @"Invert",
	}];

	XCTAssertNoThrow([effect.notifier postNotificationName:FxGripNotifyAPI_ParameterAddPreName
													object:effect
												  userInfo:@{ FxGripNotifyAPI_ParameterKey: NSMutableDictionary.new }]);
	XCTAssertNoThrow([effect.notifier postNotificationName:FxGripNotifyAPI_ParameterAddPreName
													object:effect
												  userInfo:@{ FxGripNotifyAPI_ParameterKey: unknown }]);
	XCTAssertNil(unknown[kFxParameterProperty_ExtensionKey]);
}

/*! @abstract Reconstructing a group builds its parameter objects and attaches each child to its group. */
- (void)testReconstructingAGroupBuildsAndAttachesItsChildren
{
	FxGripEffectTestEffect *effect = [self makeEffect];
	NSMutableDictionary *properties = [self pluginPropertiesDictionary];
	properties[kProPlugPlugInX_ParametersProperty] = @[
		@{
			kFxParameterProperty_Id: @(kEffectTestGroup),
			kFxParameterProperty_Type: kFxParameterType_Group,
			kFxParameterProperty_Name: @"Group",
		},
		@{
			kFxParameterProperty_Id: @(kEffectTestChild),
			kFxParameterProperty_Type: kFxParameterType_Float,
			kFxParameterProperty_Name: @"Child",
			kFxParameterProperty_ParentId: @(kEffectTestGroup),
		},
	];
	effect.stubPluginProperties = properties;
	NSError *error = nil;
	[effect addParametersWithError:&error];

	XCTAssertTrue([effect reconstructParametersWithGroupID:kFxParameterId_TopLevelGroup]);

	id<FxGripParameter> group = effect.parameters[@(kEffectTestGroup)];
	id<FxGripParameter> child = effect.parameters[@(kEffectTestChild)];
	XCTAssertNotNil(group);
	XCTAssertNotNil(child);
	XCTAssertEqual(child.parameterParentID, kEffectTestGroup);
	XCTAssertTrue([(id)group conformsToProtocol:@protocol(FxGripSubParameters)]);
}

/*! @abstract A child whose declared parent holds no sub-parameters is still registered, unattached. */
- (void)testAChildOfANonGroupParentIsRegisteredUnattached
{
	FxGripEffectTestEffect *effect = [self makeEffect];
	NSMutableDictionary *properties = [self pluginPropertiesDictionary];
	properties[kProPlugPlugInX_ParametersProperty] = @[
		@{
			kFxParameterProperty_Id: @(kEffectTestToggle),
			kFxParameterProperty_Type: kFxParameterType_Toggle,
			kFxParameterProperty_Name: @"Invert",
		},
		@{
			kFxParameterProperty_Id: @(kEffectTestFloat),
			kFxParameterProperty_Type: kFxParameterType_Float,
			kFxParameterProperty_Name: @"Level",
			kFxParameterProperty_ParentId: @(kEffectTestToggle),
		},
	];
	effect.stubPluginProperties = properties;
	NSError *error = nil;
	[effect addParametersWithError:&error];

	XCTAssertTrue([effect reconstructParametersWithGroupID:kFxParameterId_TopLevelGroup]);
	XCTAssertTrue([effect reconstructParametersWithGroupID:kEffectTestToggle]);

	XCTAssertNotNil(effect.parameters[@(kEffectTestToggle)]);
	XCTAssertNotNil(effect.parameters[@(kEffectTestFloat)]);
}

/*! @abstract An effect added to a document without an add-parameters pass runs the load path and marks its parameters added. */
- (void)testAnEffectAddedToADocumentRunsTheParameterLoadPath
{
	FxGripEffectTestEffect *effect = [self makeEffect];
	XCTAssertFalse(effect.addedParameters);

	[effect pluginInstanceAddedToDocument];

	XCTAssertTrue(effect.addedParameters, @"the load path stands in for the add-parameters pass");
	XCTAssertFalse(effect.addingParameters);
}

#pragma mark Parameter subscripting

/*! @abstract A positive subscript reads the parameter by its identifier. */
- (void)testAPositiveSubscriptReadsTheParameterByIdentifier
{
	FxGripEffectTestEffect *effect = [self makeEffect];
	[effect.notifier postNotificationName:FxGripNotifyAPI_ParameterAddName
								   object:effect
								 userInfo:FxGripParamClassTestConfig(kEffectTestFloat, kFxParameterType_Float, @"Level", nil)];
	__unused NSDictionary *repopulate = effect.parameters;

	XCTAssertNotNil(effect[kEffectTestFloat]);
	XCTAssertEqualObjects(effect[@(kEffectTestFloat)], effect[kEffectTestFloat]);
	XCTAssertEqualObjects(effect[@"11"], effect[kEffectTestFloat], @"a digit string reads as an identifier");
}

/*! @abstract A zero or negative subscript reads the ordinal position through the host's dynamic parameter API. */
- (void)testANonPositiveSubscriptReadsTheOrdinalPositionFromTheHost
{
	FxGripEffectTestEffect *effect = [self makeEffect];
	FxGripEffectTestAPIManager *apiManager = FxGripEffectTestAPIManager.new;
	FxGripEffectTestDynamicAPI *dynamicAPI = FxGripEffectTestDynamicAPI.new;
	dynamicAPI.parameterIDs = @[@(kEffectTestFloat), @(kEffectTestToggle)];
	apiManager.dynamicAPI = dynamicAPI;
	[effect.notifier postNotificationName:FxGripNotifyAPI_ParameterAddName
								   object:effect
								 userInfo:FxGripParamClassTestConfig(kEffectTestToggle, kFxParameterType_Toggle, @"Invert", nil)];
	__unused NSDictionary *repopulate = effect.parameters;
	effect.stubAPIManager = apiManager;

	XCTAssertEqual(effect.parameterCount, (UInt32)2);
	XCTAssertNotNil(effect[-1], @"index 1 maps to the second declared parameter");
	XCTAssertNil(effect[-5], @"an index past the host's count reads nothing");
}

/*! @abstract A subscript key that is neither a number nor a string reads nothing, and a string key reads an extension. */
- (void)testASubscriptKeyOfAnUnsupportedTypeReadsNothing
{
	FxGripEffectTestEffect *effect = [self makeEffect];

	XCTAssertNil(effect[(id)nil]);
	XCTAssertNil(effect[@"fxGripTestUnknownExtension"], @"a non-digit string reads the extension dictionary");
	XCTAssertNil(effect[[NSDate date]]);
}

/*! @abstract The effect enumerates its parameters. */
- (void)testTheEffectEnumeratesItsParameters
{
	FxGripEffectTestEffect *effect = [self makeEffect];
	[effect.notifier postNotificationName:FxGripNotifyAPI_ParameterAddName
								   object:effect
								 userInfo:FxGripParamClassTestConfig(kEffectTestFloat, kFxParameterType_Float, @"Level", nil)];
	__unused NSDictionary *repopulate = effect.parameters;

	NSMutableArray<NSNumber *> *seen = NSMutableArray.array;
	for (NSNumber *identifier in effect) {
		[seen addObject:identifier];
	}

	XCTAssertEqualObjects(seen, (@[@(kEffectTestFloat)]));
}

#pragma mark Render path

/*! @abstract A nil plugin state is refused with an invalid-parameter error. */
- (void)testRenderingRefusesANilPluginState
{
	FxGripEffectTestEffect *effect = [self makeEffect];
	FxImageTile *destination = [FxImageTile stubTileWithPixelBounds:(FxRect){ 0, 0, 16, 16 }
														pixelFormat:kCVPixelFormatType_32BGRA
															 device:MTLCreateSystemDefaultDevice()];
	NSError *error = nil;

	BOOL rendered = [effect renderDestinationImage:destination
									  sourceImages:@[]
									   pluginState:(NSData * _Nonnull)nil
											atTime:FxGripEffectTestTime(0, 1)
											 error:&error];

	XCTAssertFalse(rendered);
	XCTAssertEqualObjects(error.domain, FxGripPlugErrorDomain);
	XCTAssertEqual(error.code, (NSInteger)kFxError_InvalidParameter);
}

/*! @abstract A destination tile with no surface is refused with an invalid-parameter error. */
- (void)testRenderingRefusesADestinationWithoutASurface
{
	FxGripEffectTestEffect *effect = [self makeEffect];
	FxImageTile *destination = [FxImageTile stubTileWithPixelBounds:(FxRect){ 0, 0, 16, 16 }];
	NSError *error = nil;

	BOOL rendered = [effect renderDestinationImage:destination
									  sourceImages:@[]
									   pluginState:FxGripEffectTestState()
											atTime:FxGripEffectTestTime(0, 1)
											 error:&error];

	XCTAssertFalse(rendered);
	XCTAssertEqual(error.code, (NSInteger)kFxError_InvalidParameter);
}

/*! @abstract A filter with no coder-state render blits its first source into the destination and posts the render notification. */
- (void)testAFilterRendersThePassthroughBlitAndPostsTheNotification
{
	id<MTLDevice> device = MTLCreateSystemDefaultDevice();
	XCTSkipIf(device == nil, @"No Metal device.");
	FxGripEffectTestEffect *effect = [self makeEffect];
	FxImageTile *destination = [FxImageTile stubTileWithPixelBounds:(FxRect){ 0, 0, 16, 16 }
														pixelFormat:kCVPixelFormatType_32BGRA
															 device:device];
	FxImageTile *source = [FxImageTile stubTileWithPixelBounds:(FxRect){ 0, 0, 16, 16 }
												  pixelFormat:kCVPixelFormatType_32BGRA
													   device:device];
	__block NSNotification *seen = nil;
	[self onEffect:effect observeName:FxGripTileableEffectRenderDestinationImageName usingBlock:^(NSNotification *notification) {
		seen = notification;
	}];
	NSError *error = nil;

	BOOL rendered = [effect renderDestinationImage:destination
									  sourceImages:@[source]
									   pluginState:FxGripEffectTestState()
											atTime:FxGripEffectTestTime(12, 24)
											 error:&error];

	XCTAssertTrue(rendered, @"%@", error);
	XCTAssertEqualObjects(seen.userInfo[FxGripTileableEffectRenderDestinationImageKey], destination);
	XCTAssertEqualObjects(seen.userInfo[FxGripTileableEffectRenderSourceImagesKey], (@[source]));
	XCTAssertNotNil(seen.userInfo[FxGripTileableEffectRenderAtTimeKey]);
}

/*! @abstract The passthrough blit is refused when there is no source tile with a surface. */
- (void)testThePassthroughBlitRefusesAnEmptySourceList
{
	FxGripEffectTestEffect *effect = [self makeEffect];
	FxImageTile *destination = [FxImageTile stubTileWithPixelBounds:(FxRect){ 0, 0, 16, 16 }
														pixelFormat:kCVPixelFormatType_32BGRA
															 device:MTLCreateSystemDefaultDevice()];
	NSError *error = nil;

	XCTAssertFalse([effect renderPassthroughDestinationImage:destination sourceImages:@[] error:&error]);
	XCTAssertEqual(error.code, (NSInteger)kFxError_InvalidParameter);

	FxImageTile *surfaceless = [FxImageTile stubTileWithPixelBounds:(FxRect){ 0, 0, 16, 16 }];
	NSError *surfacelessError = nil;
	XCTAssertFalse([effect renderPassthroughDestinationImage:destination
											   sourceImages:@[surfaceless]
													  error:&surfacelessError]);
	XCTAssertEqual(surfacelessError.code, (NSInteger)kFxError_InvalidParameter);
}

/*! @abstract A generator renders no passthrough blit, so it succeeds with no source tiles. */
- (void)testAGeneratorRendersNoPassthroughBlit
{
	id<MTLDevice> device = MTLCreateSystemDefaultDevice();
	XCTSkipIf(device == nil, @"No Metal device.");
	FxGripEffectTestGenerator *generator = [FxGripEffectTestGenerator.alloc initWithAPIManager:(id _Nonnull)nil];
	FxImageTile *destination = [FxImageTile stubTileWithPixelBounds:(FxRect){ 0, 0, 16, 16 }
														pixelFormat:kCVPixelFormatType_32BGRA
															 device:device];
	NSError *error = nil;

	BOOL rendered = [generator renderDestinationImage:destination
										 sourceImages:@[]
										  pluginState:FxGripEffectTestState()
											   atTime:FxGripEffectTestTime(0, 1)
												error:&error];

	XCTAssertTrue(rendered, @"%@", error);
}

/*! @abstract An observer error after a successful render makes the render report failure. */
- (void)testAnObserverErrorAfterTheRenderReportsFailure
{
	id<MTLDevice> device = MTLCreateSystemDefaultDevice();
	XCTSkipIf(device == nil, @"No Metal device.");
	FxGripEffectTestGenerator *generator = [FxGripEffectTestGenerator.alloc initWithAPIManager:(id _Nonnull)nil];
	NSError *staged = [NSError errorWithDomain:@"FxGripEffectTest" code:11 userInfo:nil];
	id token = [generator.notifier addObserverForName:FxGripTileableEffectRenderDestinationImageName
											   object:nil
												queue:nil
										   usingBlock:^(NSNotification *notification) {
		((NSMutableDictionary *)notification.userInfo).fxError = staged;
	}];
	[self.observerTokens addObject:token];
	FxImageTile *destination = [FxImageTile stubTileWithPixelBounds:(FxRect){ 0, 0, 16, 16 }
														pixelFormat:kCVPixelFormatType_32BGRA
															 device:device];
	NSError *error = nil;

	BOOL rendered = [generator renderDestinationImage:destination
										 sourceImages:@[]
										  pluginState:FxGripEffectTestState()
											   atTime:FxGripEffectTestTime(0, 1)
												error:&error];

	XCTAssertFalse(rendered);
	XCTAssertEqualObjects(error, staged);
}

#pragma mark Scheduling inputs

/*! @abstract A nil plugin state is refused by the input scheduler. */
- (void)testSchedulingRefusesANilPluginState
{
	FxGripEffectTestEffect *effect = [self makeEffect];
	NSArray<FxImageTileRequest *> *requests = nil;
	NSError *error = nil;

	XCTAssertFalse([effect scheduleInputs:&requests
						  withPluginState:nil
								   atTime:FxGripEffectTestTime(0, 1)
									error:&error]);
	XCTAssertEqualObjects(error.domain, FxGripPlugErrorDomain);
	XCTAssertNil(requests);
}

/*! @abstract An observer error stops the input scheduling and reaches the host. */
- (void)testSchedulingReportsAnObserverError
{
	FxGripEffectTestEffect *effect = [self makeEffect];
	NSError *staged = [NSError errorWithDomain:@"FxGripEffectTest" code:12 userInfo:nil];
	[self onEffect:effect observeName:FxGripTileableEffectScheduleInputsName usingBlock:^(NSNotification *notification) {
		((NSMutableDictionary *)notification.userInfo).fxError = staged;
	}];
	NSArray<FxImageTileRequest *> *requests = nil;
	NSError *error = nil;

	XCTAssertFalse([effect scheduleInputs:&requests
						  withPluginState:FxGripEffectTestState()
								   atTime:FxGripEffectTestTime(0, 1)
									error:&error]);
	XCTAssertEqualObjects(error, staged);
}

#pragma mark Plugin state

/*! @abstract The encoded plugin state is a fresh archive on every call and an observer error stops it. */
- (void)testThePluginStateEncodesAFreshArchiveAndHonorsAnObserverError
{
	FxGripEffectTestEffect *effect = [self makeEffect];
	NSData *first = nil, *second = nil;
	NSError *error = nil;

	XCTAssertTrue([effect pluginState:&first atTime:FxGripEffectTestTime(0, 1) quality:kFxQuality_HIGH error:&error]);
	XCTAssertTrue([effect pluginState:&second atTime:FxGripEffectTestTime(1, 24) quality:kFxQuality_HIGH error:&error]);
	XCTAssertNotNil(first);
	XCTAssertFalse(first == second, @"a new NSData is produced on every call");

	NSError *staged = [NSError errorWithDomain:@"FxGripEffectTest" code:13 userInfo:nil];
	[self onEffect:effect observeName:FxGripTileableEffectPluginStateName usingBlock:^(NSNotification *notification) {
		((NSMutableDictionary *)notification.userInfo).fxError = staged;
	}];
	NSData *refused = nil;
	NSError *refusedError = nil;

	XCTAssertFalse([effect pluginState:&refused atTime:FxGripEffectTestTime(0, 1) quality:kFxQuality_HIGH error:&refusedError]);
	XCTAssertEqualObjects(refusedError, staged);
}

#pragma mark Extension loading

/*! @abstract Every optional extension the plugin properties enable is installed. */
- (void)testThePluginPropertiesGateEveryOptionalExtension
{
	FxGripEffectTestEffect *effect = [FxGripEffectTestEffect.alloc init];
	NSMutableDictionary *properties = [self pluginPropertiesDictionary];
	properties[kProPlugPlugInX_TrackInstancesProperty] = @YES;
	properties[kProPlugPlugInX_ManagedParameterDataProperty] = @YES;
	properties[kProPlugPlugInX_ManagedMetaProperty] = @YES;
	properties[kProPlugPlugInX_DebugMenuProperty] = @YES;
	properties[kProPlugPlugInX_AboutMenuProperty] = @{ @"items": @[] };
	properties[kProPlugPlugInX_InternationalizeProperty] = @YES;
	properties[kProPlugPlugInX_RegressionProperty] = @YES;
	properties[kProPlugPlugInX_FxFactoryProperty] = @YES;
	effect.stubPluginProperties = properties;

	NSArray<id<FxGripExtension>> *extensions = [effect loadExtensions];
	NSMutableArray<NSString *> *classNames = NSMutableArray.array;
	for (id extension in extensions) {
		[classNames addObject:NSStringFromClass([extension class])];
	}

	XCTAssertTrue([classNames containsObject:@"FxGripInstanceTracker"]);
	XCTAssertTrue([classNames containsObject:@"FxGripParameterData"]);
	XCTAssertTrue([classNames containsObject:@"FxGripMeta"]);
	XCTAssertTrue([classNames containsObject:@"FxGripDebugMenu"]);
	XCTAssertTrue([classNames containsObject:@"FxGripAboutMenu"]);
	XCTAssertTrue([classNames containsObject:@"FxGripI18N"]);
	XCTAssertTrue([classNames containsObject:@"FxGripFxFactory"]);
}

#pragma mark Observer error payloads

/*! Stages a payload that is not an NSError under the notification's error key. */
- (void)onEffect:(FxGripEffectTestEffect *)effect stageMalformedErrorForName:(NSNotificationName)name
{
	[self onEffect:effect observeName:name usingBlock:^(NSNotification *notification) {
		((NSMutableDictionary *)notification.userInfo)[FxGripNotifyAPI_ErrorKey] = @"not an error";
	}];
}

/*! @abstract An observer payload that is not an NSError is reported as a failure by every entry point that carries one. */
- (void)testAMalformedObserverErrorIsReportedAsAFailure
{
	FxGripEffectTestEffect *effect = [self makeEffect];
	[self onEffect:effect stageMalformedErrorForName:FxGripTileableEffectFinishInitialSetupName];
	[self onEffect:effect stageMalformedErrorForName:FxGripTileableEffectParameterChangedName];
	[self onEffect:effect stageMalformedErrorForName:FxGripTileableEffectPluginStateName];
	[self onEffect:effect stageMalformedErrorForName:FxGripTileableEffectDestinationImageRectName];
	[self onEffect:effect stageMalformedErrorForName:FxGripTileableEffectSourceTileRectName];
	[self onEffect:effect stageMalformedErrorForName:FxGripTileableEffectScheduleInputsName];
	[self onEffect:effect stageMalformedErrorForName:FxGripTileableEffectParameterClickedName];
	NSError *error = nil;

	XCTAssertFalse([effect finishInitialSetup:&error]);
	XCTAssertFalse([effect parameterChanged:kEffectTestFloat atTime:FxGripEffectTestTime(0, 1) error:&error]);

	NSData *state = nil;
	XCTAssertFalse([effect pluginState:&state atTime:FxGripEffectTestTime(0, 1) quality:kFxQuality_HIGH error:&error]);

	FxImageTile *tile = [FxImageTile stubTileWithPixelBounds:(FxRect){ 0, 0, 16, 16 }];
	FxRect rect = { 0, 0, 0, 0 };
	XCTAssertFalse([effect destinationImageRect:&rect
								   sourceImages:@[]
							   destinationImage:tile
									pluginState:FxGripEffectTestState()
										 atTime:FxGripEffectTestTime(0, 1)
										  error:&error]);
	XCTAssertFalse([effect sourceTileRect:&rect
						 sourceImageIndex:0
							 sourceImages:@[tile]
					  destinationTileRect:rect
						 destinationImage:tile
							  pluginState:FxGripEffectTestState()
								   atTime:FxGripEffectTestTime(0, 1)
									error:&error]);
	NSArray<FxImageTileRequest *> *requests = nil;
	XCTAssertFalse([effect scheduleInputs:&requests
						  withPluginState:FxGripEffectTestState()
								   atTime:FxGripEffectTestTime(0, 1)
									error:&error]);
	XCTAssertFalse([effect parameterClicked:kEffectTestFloat], @"a malformed click payload is still reported as a failure");
}

#pragma mark Properties dictionary sizing

/*! @abstract A caller dictionary and a declared record larger than the base capacity are both merged whole. */
- (void)testALargePropertyDictionaryAndDeclaredRecordAreMergedWhole
{
	FxGripEffectTestEffect *effect = [self makeEffect];
	NSMutableDictionary *declared = NSMutableDictionary.new;
	NSMutableDictionary *incoming = NSMutableDictionary.new;
	for (NSUInteger index = 0; index < 20; index++) {
		declared[[NSString stringWithFormat:@"fxGripDeclared%lu", (unsigned long)index]] = @(index);
	}
	for (NSUInteger index = 0; index < 12; index++) {
		incoming[[NSString stringWithFormat:@"fxGripIncoming%lu", (unsigned long)index]] = @(index);
	}
	NSMutableDictionary *pluginProperties = [self pluginPropertiesDictionary];
	pluginProperties[kProPlugPlugInX_EffectPropertiesProperty] = declared;
	effect.stubPluginProperties = pluginProperties;
	effect.stubEffectPropertiesInInfo = YES;
	NSDictionary *properties = incoming;
	NSError *error = nil;

	XCTAssertTrue([effect properties:&properties error:&error]);

	XCTAssertEqualObjects(properties[@"fxGripDeclared19"], @19);
	XCTAssertEqualObjects(properties[@"fxGripIncoming11"], @11);
}

/*! @abstract An observer that replaces the properties with an immutable dictionary is tolerated. */
- (void)testAnObserverThatReplacesThePropertiesWithAnImmutableDictionaryIsTolerated
{
	FxGripEffectTestEffect *effect = [self makeEffect];
	[self onEffect:effect observeName:FxGripTileableEffectPropertiesName usingBlock:^(NSNotification *notification) {
		((NSMutableDictionary *)notification.userInfo)[FxGripTileableEffectPropertiesKey] = @{ @"fxGripFrozen": @YES };
		((NSMutableDictionary *)notification.userInfo)[FxGripNotifyAPI_ErrorKey] = @"not an error";
	}];
	NSDictionary *properties = nil;
	NSError *error = nil;

	XCTAssertTrue([effect properties:&properties error:&error]);

	XCTAssertEqualObjects(properties[@"fxGripFrozen"], @YES);
}

#pragma mark Adding parameters

/*! @abstract The add-parameters pass flattens the declared records and validates the registered parameters. */
- (void)testTheAddParametersPassFlattensTheDeclaredRecords
{
	FxGripEffectTestEffect *effect = [self makeEffect];
	NSMutableDictionary *properties = [self pluginPropertiesDictionary];
	properties[kProPlugPlugInX_ParametersProperty] = @[@{
		kFxParameterProperty_Id: @(kEffectTestGroup),
		kFxParameterProperty_Type: kFxParameterType_Group,
		kFxParameterProperty_Name: @"Group",
		kFxParameterProperty_GroupParameters: @[@{
			kFxParameterProperty_Id: @(kEffectTestChild),
			kFxParameterProperty_Type: kFxParameterType_Float,
			kFxParameterProperty_Name: @"Child",
		}],
	}];
	effect.stubPluginProperties = properties;
	__block NSUInteger observed = 0;
	[self onEffect:effect observeName:FxGripTileableEffectAddParametersName usingBlock:^(NSNotification *notification) {
		observed = notification.userInfo.fxEffectParameters.count;
	}];
	// A registered parameter object gives the validation loop something to walk.
	[effect.notifier postNotificationName:FxGripNotifyAPI_ParameterAddName
								   object:effect
								 userInfo:FxGripParamClassTestConfig(kEffectTestFloat, kFxParameterType_Float, @"Level", nil)];
	NSError *error = nil;

	[effect addParametersWithError:&error];

	XCTAssertEqual(observed, (NSUInteger)1, @"the observer sees the declared records before flattening");
	XCTAssertNotNil([effect configurationForParameter:kEffectTestChild],
					@"the nested child is flattened into the configuration");
	XCTAssertTrue(effect.addedParameters);
	XCTAssertFalse(effect.addingParameters);
}

#pragma mark Color parameter policy

/*! @abstract A gamma-declared color converts to the effect's linear working gamut. */
- (void)testTheParameterPolicyConvertsAGammaColorToLinear
{
	FxGripEffectTestEffect *effect = [self makeEffect];
	XCTAssertTrue(effect.isLinearColorParameters, @"the effect processes linearly by default");
	NSMutableDictionary *color = [NSMutableDictionary dictionaryWithDictionary:@{
		kFxParameterProperty_ColorSpace: @1,
		kFxParameterProperty_Red: @0.5, kFxParameterProperty_Green: @0.25, kFxParameterProperty_Blue: @1.0,
	}];
	NSMutableDictionary *configuration = [NSMutableDictionary dictionaryWithDictionary:@{
		kFxParameterProperty_Id: @(kEffectTestFloat),
		kFxParameterProperty_Type: kFxParameterType_RGBA,
		kFxParameterProperty_Name: @"Tint",
		kFxParameterProperty_Default: color,
	}];

	[effect.notifier postNotificationName:FxGripTileableEffectParameterPolicyName
								   object:effect
								 userInfo:@{ FxGripNotifyAPI_ParameterKey: configuration }];

	XCTAssertEqualWithAccuracy([color[kFxParameterProperty_Red] doubleValue], pow(0.5, 1.0 / 2.2), 1e-9);
	XCTAssertEqualWithAccuracy([color[kFxParameterProperty_Green] doubleValue], pow(0.25, 1.0 / 2.2), 1e-9);
	XCTAssertEqualWithAccuracy([color[kFxParameterProperty_Blue] doubleValue], 1.0, 1e-9);
}

/*! @abstract A linear-declared color converts to the effect's gamma working gamut. */
- (void)testTheParameterPolicyConvertsALinearColorToGamma
{
	FxGripEffectTestEffect *effect = [self makeEffect];
	effect.desiredProcessingColorInfo = kFxImageColorInfo_RGB_GAMMA_VIDEO;
	XCTAssertTrue(effect.isGammaColorParameters);
	NSMutableDictionary *color = [NSMutableDictionary dictionaryWithDictionary:@{
		kFxParameterProperty_ColorSpace: @0,
		kFxParameterProperty_Red: @0.5, kFxParameterProperty_Green: @"not a number", kFxParameterProperty_Blue: @0.25,
	}];
	NSMutableDictionary *configuration = [NSMutableDictionary dictionaryWithDictionary:@{
		kFxParameterProperty_Id: @(kEffectTestFloat),
		kFxParameterProperty_Type: kFxParameterType_RGBA,
		kFxParameterProperty_Name: @"Tint",
		kFxParameterProperty_Default: color,
	}];

	[effect.notifier postNotificationName:FxGripTileableEffectParameterPolicyName
								   object:effect
								 userInfo:@{ FxGripNotifyAPI_ParameterKey: configuration }];

	XCTAssertEqualWithAccuracy([color[kFxParameterProperty_Red] doubleValue], pow(0.5, 2.2), 1e-9);
	XCTAssertEqualObjects(color[kFxParameterProperty_Green], @"not a number", @"a non-numeric component is left alone");
}

/*! @abstract A color already in the effect's own space is left alone. */
- (void)testTheParameterPolicyLeavesAMatchingColorSpaceAlone
{
	FxGripEffectTestEffect *effect = [self makeEffect];
	NSMutableDictionary *color = [NSMutableDictionary dictionaryWithDictionary:@{
		kFxParameterProperty_ColorSpace: @0,
		kFxParameterProperty_Red: @0.5,
	}];
	NSMutableDictionary *configuration = [NSMutableDictionary dictionaryWithDictionary:@{
		kFxParameterProperty_Id: @(kEffectTestFloat),
		kFxParameterProperty_Type: kFxParameterType_RGB,
		kFxParameterProperty_Name: @"Tint",
		kFxParameterProperty_Default: color,
	}];

	[effect.notifier postNotificationName:FxGripTileableEffectParameterPolicyName
								   object:effect
								 userInfo:@{ FxGripNotifyAPI_ParameterKey: configuration }];

	XCTAssertEqualObjects(color[kFxParameterProperty_Red], @0.5);
}

/*! @abstract A color default that is not a mutable dictionary is left alone. */
- (void)testTheParameterPolicyLeavesANonDictionaryColorDefaultAlone
{
	FxGripEffectTestEffect *effect = [self makeEffect];
	NSMutableDictionary *configuration = [NSMutableDictionary dictionaryWithDictionary:@{
		kFxParameterProperty_Id: @(kEffectTestFloat),
		kFxParameterProperty_Type: kFxParameterType_RGBA,
		kFxParameterProperty_Name: @"Tint",
		kFxParameterProperty_Default: @"white",
	}];

	XCTAssertNoThrow([effect.notifier postNotificationName:FxGripTileableEffectParameterPolicyName
													object:effect
												  userInfo:@{ FxGripNotifyAPI_ParameterKey: configuration }]);
	XCTAssertEqualObjects(configuration[kFxParameterProperty_Default], @"white");
}

#pragma mark Group parameter errors

/*! @abstract An error raised while adding a group's children travels back through the notification. */
- (void)testAGroupAdditionErrorTravelsBackThroughTheNotification
{
	FxGripEffectTestEffect *effect = [self makeEffect];
	NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:@{
		FxGripTileableEffectGroupIDKey: @(kEffectTestGroup),
	}];

	[effect.notifier postNotificationName:FxGripTileableEffectAddGroupParametersName object:effect userInfo:userInfo];

	XCTAssertNil(userInfo.fxError, @"an empty group adds its children without error");
}

#pragma mark On-screen control clicks

/*! @abstract An on-screen control's click opens no action bracket, because the host already expects the change. */
- (void)testAnOnScreenControlClickOpensNoActionBracket
{
	FxGripEffectTestOSCEffect *effect =
		(FxGripEffectTestOSCEffect *)[self makeEffectOfClass:FxGripEffectTestOSCEffect.class];
	FxGripEffectTestAPIManager *apiManager = FxGripEffectTestAPIManager.new;
	apiManager.customParameterActionAPIv4 = FxGripEffectTestActionAPI.new;
	effect.stubAPIManager = apiManager;

	XCTAssertTrue([effect parameterClicked:kEffectTestFloat]);

	XCTAssertEqual(apiManager.customParameterActionAPIv4.calls.count, (NSUInteger)0);
}

#pragma mark Add-pre notification

/*! @abstract The add-pre notification ignores a parameter whose identifier is zero. */
- (void)testTheAddPreNotificationIgnoresAZeroIdentifier
{
	FxGripEffectTestEffect *effect = [self makeEffect];
	NSMutableDictionary *creating = [NSMutableDictionary dictionaryWithDictionary:@{
		kFxParameterProperty_Id: @0,
		kFxParameterProperty_Type: kFxParameterType_Float,
		kFxParameterProperty_Name: @"Level",
	}];

	XCTAssertNoThrow([effect.notifier postNotificationName:FxGripNotifyAPI_ParameterAddPreName
													object:effect
												  userInfo:@{ FxGripNotifyAPI_ParameterKey: creating }]);
	XCTAssertNil(creating[kFxParameterProperty_ExtensionKey]);
}

/*! @abstract The add-pre notification copies the declared gradient samples and depth onto the notification. */
- (void)testTheAddPreNotificationCopiesTheDeclaredGradientSamples
{
	FxGripEffectTestEffect *effect = [self makeEffect];
	NSMutableDictionary *properties = [self pluginPropertiesDictionary];
	properties[kProPlugPlugInX_ParametersProperty] = @[@{
		kFxParameterProperty_Id: @(kEffectTestFloat),
		kFxParameterProperty_Type: kFxParameterType_Gradient,
		kFxParameterProperty_Name: @"Ramp",
		kFxParameterProperty_GradientSamples: @64,
		kFxParameterProperty_GradientDepth: @8,
	}];
	effect.stubPluginProperties = properties;
	NSError *error = nil;
	[effect addParametersWithError:&error];
	NSMutableDictionary *creating = [NSMutableDictionary dictionaryWithDictionary:@{
		kFxParameterProperty_Id: @(kEffectTestFloat),
		kFxParameterProperty_Type: kFxParameterType_Gradient,
		kFxParameterProperty_Name: @"Ramp",
	}];
	NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:@{
		FxGripNotifyAPI_ParameterKey: creating,
	}];

	[effect.notifier postNotificationName:FxGripNotifyAPI_ParameterAddPreName object:effect userInfo:userInfo];

	XCTAssertEqualObjects(userInfo[kFxParameterProperty_GradientSamples], @64);
	XCTAssertEqualObjects(userInfo[kFxParameterProperty_GradientDepth], @8);
}

#pragma mark Coder-state render path

/*! @abstract A coder-state effect encodes through its coder callback and decodes on the render side. */
- (void)testACoderStateEffectRendersThroughItsCoderCallback
{
	id<MTLDevice> device = MTLCreateSystemDefaultDevice();
	XCTSkipIf(device == nil, @"No Metal device.");
	FxGripEffectTestCoderEffect *effect =
		(FxGripEffectTestCoderEffect *)[self makeEffectOfClass:FxGripEffectTestCoderEffect.class];
	NSData *state = nil;
	NSError *error = nil;
	XCTAssertTrue([effect pluginState:&state atTime:FxGripEffectTestTime(48, 24) quality:kFxQuality_HIGH error:&error]);
	FxImageTile *destination = [FxImageTile stubTileWithPixelBounds:(FxRect){ 0, 0, 16, 16 }
														pixelFormat:kCVPixelFormatType_32BGRA
															 device:device];

	BOOL rendered = [effect renderDestinationImage:destination
									  sourceImages:@[]
									   pluginState:state
											atTime:FxGripEffectTestTime(48, 24)
											 error:&error];

	XCTAssertTrue(rendered, @"%@", error);
	XCTAssertTrue(effect.codedRenderCalled, @"the base forwards to the coder-based render callback");
}

/*! @abstract A corrupt plugin state is refused by every render-path entry point. */
- (void)testACorruptPluginStateIsRefusedByTheRenderPath
{
	FxGripEffectTestCoderEffect *effect =
		(FxGripEffectTestCoderEffect *)[self makeEffectOfClass:FxGripEffectTestCoderEffect.class];
	NSData *corrupt = [@"not an archive" dataUsingEncoding:NSUTF8StringEncoding];
	FxImageTile *tile = [FxImageTile stubTileWithPixelBounds:(FxRect){ 0, 0, 16, 16 }
												pixelFormat:kCVPixelFormatType_32BGRA
													 device:MTLCreateSystemDefaultDevice()];
	FxRect rect = { 0, 0, 0, 0 };
	NSError *error = nil;

	XCTAssertFalse([effect destinationImageRect:&rect
								   sourceImages:@[]
							   destinationImage:tile
									pluginState:corrupt
										 atTime:FxGripEffectTestTime(0, 1)
										  error:&error]);
	XCTAssertFalse([effect sourceTileRect:&rect
						 sourceImageIndex:0
							 sourceImages:@[tile]
					  destinationTileRect:rect
						 destinationImage:tile
							  pluginState:corrupt
								   atTime:FxGripEffectTestTime(0, 1)
									error:&error]);
	XCTAssertFalse([effect renderDestinationImage:tile
									 sourceImages:@[]
									  pluginState:corrupt
										   atTime:FxGripEffectTestTime(0, 1)
											error:&error]);
}

#pragma mark Scheduling image references

/*! @abstract A filter that schedules nothing of its own gains the effect clip ahead of its image references. */
- (void)testImageReferencesFollowTheEffectClipForAFilter
{
	FxGripEffectTestEffect *effect = [self makeEffect];
	[effect.notifier postNotificationName:FxGripNotifyAPI_ParameterAddName
								   object:effect
								 userInfo:FxGripParamClassTestConfig(kEffectTestFloat, kFxParameterType_ImageRef, @"Layer", nil)];
	XCTAssertNotNil(effect.parameters[@(kEffectTestFloat)]);
	NSArray<FxImageTileRequest *> *requests = nil;
	NSError *error = nil;

	XCTAssertTrue([effect scheduleInputs:&requests
						 withPluginState:FxGripEffectTestState()
								  atTime:FxGripEffectTestTime(24, 24)
								   error:&error]);

	XCTAssertEqual(requests.count, (NSUInteger)2);
	XCTAssertEqual(requests[0].source, kFxImageTileRequestSourceEffectClip);
	XCTAssertEqual(requests[0].parameterID, (UInt32)0);
	XCTAssertEqual(requests[1].source, kFxImageTileRequestSourceParameter);
	XCTAssertEqual(requests[1].parameterID, (UInt32)kEffectTestFloat);
	XCTAssertEqual(requests[1].requestTime.value, (int64_t)24);
}

/*! @abstract An effect that schedules its own inputs keeps them, with its image references appended. */
- (void)testAnEffectThatSchedulesItsOwnInputsKeepsThem
{
	FxGripEffectTestCoderEffect *effect =
		(FxGripEffectTestCoderEffect *)[self makeEffectOfClass:FxGripEffectTestCoderEffect.class];
	FxImageTileRequest *staged = [FxImageTileRequest.alloc initWithSource:kFxImageTileRequestSourceEffectClip
																	time:FxGripEffectTestTime(0, 24)
														  includeFilters:NO
															 parameterID:0];
	effect.stagedRequests = @[staged];
	[effect.notifier postNotificationName:FxGripNotifyAPI_ParameterAddName
								   object:effect
								 userInfo:FxGripParamClassTestConfig(kEffectTestFloat, kFxParameterType_ImageRef, @"Layer", nil)];
	NSData *state = nil;
	NSError *error = nil;
	XCTAssertTrue([effect pluginState:&state atTime:FxGripEffectTestTime(0, 24) quality:kFxQuality_HIGH error:&error]);
	NSArray<FxImageTileRequest *> *requests = nil;

	XCTAssertTrue([effect scheduleInputs:&requests
						 withPluginState:state
								  atTime:FxGripEffectTestTime(24, 24)
								   error:&error]);

	XCTAssertTrue(effect.scheduleCalled);
	XCTAssertEqual(requests.count, (NSUInteger)2);
	XCTAssertEqualObjects(requests[0], staged, @"the subclass's own request stays first");
	XCTAssertEqual(requests[1].parameterID, (UInt32)kEffectTestFloat);
}

/*! @abstract An effect with no image references and no scheduling of its own leaves the host's default delivery. */
- (void)testAnEffectWithoutImageReferencesLeavesTheRequestsUntouched
{
	FxGripEffectTestEffect *effect = [self makeEffect];
	NSArray<FxImageTileRequest *> *requests = nil;
	NSError *error = nil;

	XCTAssertTrue([effect scheduleInputs:&requests
						 withPluginState:FxGripEffectTestState()
								  atTime:FxGripEffectTestTime(0, 1)
								   error:&error]);

	XCTAssertNil(requests);
}

#pragma mark Refusing coder callbacks

/*! @abstract Each coder-based callback that refuses stops its stage and reports failure. */
- (void)testARefusingCoderCallbackStopsItsStage
{
	id<MTLDevice> device = MTLCreateSystemDefaultDevice();
	XCTSkipIf(device == nil, @"No Metal device.");
	FxGripEffectTestRefusingCoderEffect *effect =
		(FxGripEffectTestRefusingCoderEffect *)[self makeEffectOfClass:FxGripEffectTestRefusingCoderEffect.class];
	NSData *state = nil;
	NSError *error = nil;
	XCTAssertTrue([effect pluginState:&state atTime:FxGripEffectTestTime(0, 24) quality:kFxQuality_HIGH error:&error]);
	FxImageTile *tile = [FxImageTile stubTileWithPixelBounds:(FxRect){ 0, 0, 16, 16 }
												pixelFormat:kCVPixelFormatType_32BGRA
													 device:device];
	FxRect rect = { 0, 0, 0, 0 };
	NSArray<FxImageTileRequest *> *requests = nil;

	XCTAssertFalse([effect destinationImageRect:&rect
								   sourceImages:@[]
							   destinationImage:tile
									pluginState:state
										 atTime:FxGripEffectTestTime(0, 24)
										  error:&error]);
	XCTAssertFalse([effect sourceTileRect:&rect
						 sourceImageIndex:0
							 sourceImages:@[tile]
					  destinationTileRect:rect
						 destinationImage:tile
							  pluginState:state
								   atTime:FxGripEffectTestTime(0, 24)
									error:&error]);
	XCTAssertFalse([effect scheduleInputs:&requests
						  withPluginState:state
								   atTime:FxGripEffectTestTime(0, 24)
									error:&error]);
	XCTAssertFalse([effect renderDestinationImage:tile
									 sourceImages:@[]
									  pluginState:state
										   atTime:FxGripEffectTestTime(0, 24)
											error:&error]);
	XCTAssertNil(requests);
}

/*! @abstract A coder callback that refuses to encode stops the plugin state. */
- (void)testARefusingPluginCoderStopsTheStateEncoding
{
	FxGripEffectTestRefusingCoderEffect *effect =
		(FxGripEffectTestRefusingCoderEffect *)[self makeEffectOfClass:FxGripEffectTestRefusingCoderEffect.class];
	effect.refusesPluginCoder = YES;
	NSData *state = nil;
	NSError *error = nil;

	XCTAssertFalse([effect pluginState:&state atTime:FxGripEffectTestTime(0, 24) quality:kFxQuality_HIGH error:&error]);
	XCTAssertNil(state);
}

/*! @abstract A coder-state effect carries the render time into the coder at each render stage. */
- (void)testACoderStateEffectCarriesTheRenderTimeIntoEachStage
{
	id<MTLDevice> device = MTLCreateSystemDefaultDevice();
	XCTSkipIf(device == nil, @"No Metal device.");
	FxGripEffectTestCoderEffect *effect =
		(FxGripEffectTestCoderEffect *)[self makeEffectOfClass:FxGripEffectTestCoderEffect.class];
	NSData *state = nil;
	NSError *error = nil;
	XCTAssertTrue([effect pluginState:&state atTime:FxGripEffectTestTime(0, 24) quality:kFxQuality_HIGH error:&error]);
	FxImageTile *tile = [FxImageTile stubTileWithPixelBounds:(FxRect){ 0, 0, 16, 16 }
												pixelFormat:kCVPixelFormatType_32BGRA
													 device:device];
	FxRect rect = { 0, 0, 0, 0 };
	__block NSMutableArray<NSNumber *> *seenTimes = NSMutableArray.array;
	for (NSNotificationName name in @[FxGripTileableEffectDestinationImageRectName, FxGripTileableEffectSourceTileRectName]) {
		[self onEffect:effect observeName:name usingBlock:^(NSNotification *notification) {
			[seenTimes addObject:@(((NSKeyedUnarchiver *)notification.userInfo.fxCoder).renderTime.value)];
		}];
	}

	XCTAssertTrue([effect destinationImageRect:&rect
								  sourceImages:@[]
							  destinationImage:tile
								   pluginState:state
										atTime:FxGripEffectTestTime(36, 24)
										 error:&error]);
	XCTAssertTrue([effect sourceTileRect:&rect
						sourceImageIndex:0
							sourceImages:@[tile]
					 destinationTileRect:rect
						destinationImage:tile
							 pluginState:state
								  atTime:FxGripEffectTestTime(36, 24)
								   error:&error]);

	XCTAssertEqualObjects(seenTimes, (@[@36, @36]));
}

/*! @abstract A real observer error stops the destination rect and the source tile rect. */
- (void)testARealObserverErrorStopsTheRectStages
{
	FxGripEffectTestEffect *effect = [self makeEffect];
	NSError *staged = [NSError errorWithDomain:@"FxGripEffectTest" code:14 userInfo:nil];
	for (NSNotificationName name in @[FxGripTileableEffectDestinationImageRectName, FxGripTileableEffectSourceTileRectName]) {
		[self onEffect:effect observeName:name usingBlock:^(NSNotification *notification) {
			((NSMutableDictionary *)notification.userInfo).fxError = staged;
		}];
	}
	FxImageTile *tile = [FxImageTile stubTileWithPixelBounds:(FxRect){ 0, 0, 16, 16 }];
	FxRect rect = { 0, 0, 0, 0 };
	NSError *error = nil;

	XCTAssertFalse([effect destinationImageRect:&rect
								   sourceImages:@[]
							   destinationImage:tile
									pluginState:FxGripEffectTestState()
										 atTime:FxGripEffectTestTime(0, 1)
										  error:&error]);
	XCTAssertEqualObjects(error, staged);

	error = nil;
	XCTAssertFalse([effect sourceTileRect:&rect
						 sourceImageIndex:0
							 sourceImages:@[tile]
					  destinationTileRect:rect
						 destinationImage:tile
							  pluginState:FxGripEffectTestState()
								   atTime:FxGripEffectTestTime(0, 1)
									error:&error]);
	XCTAssertEqualObjects(error, staged);
}

#pragma mark Stateful parameters

/*! @abstract A parameter that carries render state encodes itself into the plugin state. */
- (void)testAStatefulParameterEncodesItselfIntoThePluginState
{
	FxGripEffectTestEffect *effect = [self makeEffect];
	[effect.notifier postNotificationName:FxGripNotifyAPI_ParameterAddName
								   object:effect
								 userInfo:FxGripParamClassTestConfig(kEffectTestFloat, kFxParameterType_RGBA, @"Tint", nil)];
	id<FxGripParameter> parameter = effect.parameters[@(kEffectTestFloat)];
	XCTAssertNotNil(parameter);
	XCTAssertTrue(parameter.hasState, @"a color parameter carries render state");
	NSData *state = nil;
	NSError *error = nil;

	XCTAssertTrue([effect pluginState:&state atTime:FxGripEffectTestTime(0, 24) quality:kFxQuality_HIGH error:&error]);

	XCTAssertGreaterThan(state.length, (NSUInteger)0);
}

#pragma mark Extension gates

/*! @abstract An effect that is itself an extension joins its own extension list. */
- (void)testAnEffectThatIsItsOwnExtensionJoinsTheList
{
	FxGripEffectTestSelfExtensionEffect *effect =
		(FxGripEffectTestSelfExtensionEffect *)[self makeEffectOfClass:FxGripEffectTestSelfExtensionEffect.class];

	XCTAssertTrue([[effect loadExtensions] containsObject:(id<FxGripExtension>)effect]);
}

/*! @abstract The Google Analytics gate installs its extension from the plugin property. */
- (void)testTheGoogleAnalyticsGateInstallsItsExtension
{
	FxGripEffectTestEffect *effect = [FxGripEffectTestEffect.alloc init];
	NSMutableDictionary *properties = [self pluginPropertiesDictionary];
	properties[kProPlugPlugInX_GoogleAnalyticsProperty] = @"UA-FxGripTest";
	effect.stubPluginProperties = properties;

	NSMutableArray<NSString *> *classNames = NSMutableArray.array;
	for (id extension in [effect loadExtensions]) {
		[classNames addObject:NSStringFromClass([extension class])];
	}

	XCTAssertTrue([classNames containsObject:@"FxGripGoogleAnalytics"]);
}

@end
