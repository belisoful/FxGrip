/*!
	@file       FxGripAPIAccessingTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-10
	@header     FxGripAPIAccessingTests
	@abstract   Verifies that FxGripAPIAccessing resolves each host API through the wrapper layer, vends the raw host object on request, and builds FxGrip's own APIs without a host.
	@discussion Introduced in FxGrip 0.1.0. A scripted PROAPIAccessing answers each protocol with a distinct host object or with nil. A table names every typed accessor with its raw sibling and the wrapper class FxGrip layers over it, so one walk checks the wrapped, raw, bypassed, and absent-host answers for the whole surface. Further tests cover the identity reads at init, the wrapper composition for the setting and retrieval APIs, and the version ordering of the creation and retrieval branches.
*/

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripAPIAccessing.h>
#import <FxGrip/FxGripCommonAPI.h>
#import <FxGrip/FxGripDynamicParameterAPI_v3.h>
#import <FxGrip/FxGripParameterCreationAPI_v5.h>
#import <FxGrip/FxGripParameterCreationAPI_v6.h>
#import <FxGrip/FxGripParameterRetrievalAPI_v6.h>
#import <FxGrip/FxGripParameterRetrievalAPI_v7.h>
#import <FxGrip/FxGripParameterSettingAPI_v5.h>
#import <FxGrip/FxGripParameterSettingAPI_v6.h>
#import <FxGrip/FxGripTimingAPI_v4.h>
#import <FxGrip/FxGripParameterInfoAPI_v1.h>
#import <FxGrip/FxGripParameterBoundsAPI_v1.h>
#import <FxGrip/FxGripMetaAPI_v1.h>
#import <FxGrip/FxGripParameterTagsAPI_v1.h>
#import <FxGrip/FxGripPresetsAPI_v1.h>
#import <FxGrip/FxGripCustomCreationAPI_v1.h>

#pragma mark - Test doubles

/*!
	A scripted host API manager. A protocol answers with the object staged for it; when
	answersEveryProtocol is set, an unstaged protocol answers with a host object created
	once per protocol, so identity comparisons hold across calls.
*/
@interface FxGripAPIAccessingTestHostManager : NSObject <PROAPIAccessing>
@property (nonatomic, strong) NSMutableDictionary<NSString *, id> *answers;
@property (nonatomic, assign) BOOL answersEveryProtocol;
@property (nonatomic, strong) NSMutableArray<NSString *> *requested;
@property (nonatomic, copy, nullable) NSString *pluginUUID;
@property (nonatomic, assign) unsigned long long sessionID;
@end

@implementation FxGripAPIAccessingTestHostManager

- (instancetype)init
{
	self = [super init];
	if (self) {
		_answers = NSMutableDictionary.new;
		_requested = NSMutableArray.new;
	}
	return self;
}

- (id)hostObjectForProtocol:(Protocol *)apiProtocol
{
	NSString *name = NSStringFromProtocol(apiProtocol);
	id object = self.answers[name];
	if (object == nil && self.answersEveryProtocol) {
		object = NSObject.new;
		self.answers[name] = object;
	}
	return object;
}

- (id)apiForProtocol:(Protocol *)apiProtocol
{
	[self.requested addObject:NSStringFromProtocol(apiProtocol)];
	return [self hostObjectForProtocol:apiProtocol];
}

@end

/*! A host manager that answers nothing and carries no identity members. */
@interface FxGripAPIAccessingTestBareManager : NSObject <PROAPIAccessing>
@end

@implementation FxGripAPIAccessingTestBareManager
- (id)apiForProtocol:(Protocol *)apiProtocol
{
	return nil;
}
@end

/*! The effect the wrappers are built over; the manager never messages it during resolution. */
@interface FxGripAPIAccessingTestEffect : NSObject
@property (nonatomic, strong) NSNotificationCenter *notifier;
@end

@implementation FxGripAPIAccessingTestEffect
- (instancetype)init
{
	self = [super init];
	if (self) {
		_notifier = NSNotificationCenter.new;
	}
	return self;
}
@end

#pragma mark - Accessor table

static NSString *const kAccessorProtocol = @"protocol";
static NSString *const kAccessorPlain = @"plain";
static NSString *const kAccessorRaw = @"raw";
static NSString *const kAccessorWrapper = @"wrapper";

/*! One typed accessor: its protocol, plain and raw getters, and the wrapper class FxGrip vends (NSNull for none). */
static NSDictionary *FxGripAccessorEntry(Protocol *protocol, NSString *plain, NSString *raw, Class wrapper)
{
	return @{kAccessorProtocol: protocol,
			 kAccessorPlain: plain,
			 kAccessorRaw: raw,
			 kAccessorWrapper: wrapper ?: (id)NSNull.null};
}

#pragma mark - Tests

@interface FxGripAPIAccessingTests : XCTestCase
@property (nonatomic, strong) FxGripAPIAccessingTestHostManager *host;
@property (nonatomic, strong) FxGripAPIAccessingTestEffect *effect;
@end

@implementation FxGripAPIAccessingTests

- (void)setUp
{
	[super setUp];
	self.host = FxGripAPIAccessingTestHostManager.new;
	self.host.pluginUUID = @"ACCESSING-TEST-UUID";
	self.host.sessionID = 77;
	self.effect = FxGripAPIAccessingTestEffect.new;
}

- (void)tearDown
{
	self.host = nil;
	self.effect = nil;
	[super tearDown];
}

- (FxGripAPIAccessing *)manager
{
	return [FxGripAPIAccessing.alloc initWithAPIManager:self.host effect:(id)self.effect];
}

/*! Every Apple-protocol accessor pair, with the wrapper class FxGrip layers over the host object. */
- (NSArray<NSDictionary *> *)hostAccessorTable
{
	return @[
		FxGripAccessorEntry(@protocol(FxParameterCreationAPI_v5), @"paramCreateAPIv5", @"paramCreateAPIv5_Raw", FxGripParameterCreationAPI_v5.class),
		FxGripAccessorEntry(@protocol(FxParameterCreationAPI_v6), @"paramCreateAPIv6", @"paramCreateAPIv6_Raw", FxGripParameterCreationAPI_v6.class),
		FxGripAccessorEntry(@protocol(FxParameterRetrievalAPI_v6), @"paramGetAPIv6", @"paramGetAPIv6_Raw", FxGripParameterRetrievalAPI_v6.class),
		FxGripAccessorEntry(@protocol(FxParameterRetrievalAPI_v7), @"paramGetAPIv7", @"paramGetAPIv7_Raw", FxGripParameterRetrievalAPI_v7.class),
		FxGripAccessorEntry(@protocol(FxParameterSettingAPI_v5), @"paramSetAPIv5", @"paramSetAPIv5_Raw", FxGripParameterSettingAPI_v5.class),
		FxGripAccessorEntry(@protocol(FxParameterSettingAPI_v6), @"paramSetAPIv6", @"paramSetAPIv6_Raw", FxGripParameterSettingAPI_v6.class),
		FxGripAccessorEntry(@protocol(FxDynamicParameterAPI_v3), @"dynamicParamAPIv3", @"dynamicParamAPIv3_Raw", FxGripDynamicParameterAPI_v3.class),
		FxGripAccessorEntry(@protocol(FxCustomParameterActionAPI_v4), @"customParameterActionAPIv4", @"customParameterActionAPIv4_Raw", Nil),
		FxGripAccessorEntry(@protocol(FxOnScreenControlAPI), @"onScreenControlAPIv1", @"onScreenControlAPIv1_Raw", Nil),
		FxGripAccessorEntry(@protocol(FxOnScreenControlAPI_v2), @"onScreenControlAPIv2", @"onScreenControlAPIv2_Raw", Nil),
		FxGripAccessorEntry(@protocol(FxOnScreenControlAPI_v3), @"onScreenControlAPIv3", @"onScreenControlAPIv3_Raw", Nil),
		FxGripAccessorEntry(@protocol(FxOnScreenControlAPI_v4), @"onScreenControlAPIv4", @"onScreenControlAPIv4_Raw", Nil),
		FxGripAccessorEntry(@protocol(FxPathAPI_v3), @"pathAPIv3", @"pathAPIv3_Raw", Nil),
		FxGripAccessorEntry(@protocol(FxUndoAPI), @"undoAPIv1", @"undoAPIv1_Raw", Nil),
		FxGripAccessorEntry(@protocol(FxCommandAPI), @"commandAPIv1", @"commandAPIv1_Raw", Nil),
		FxGripAccessorEntry(@protocol(FxCommandAPI_v2), @"commandAPIv2", @"commandAPIv2_Raw", Nil),
		FxGripAccessorEntry(@protocol(FxRemoteWindowAPI), @"remoteWindowAPIv1", @"remoteWindowAPIv1_Raw", Nil),
		FxGripAccessorEntry(@protocol(FxRemoteWindowAPI_v2), @"remoteWindowAPIv2", @"remoteWindowAPIv2_Raw", Nil),
		FxGripAccessorEntry(@protocol(FxRemoteWindowAPI_v3), @"remoteWindowAPIv3", @"remoteWindowAPIv3_Raw", Nil),
		FxGripAccessorEntry(@protocol(Fx3DAPI_v5), @"spaceAPIv5", @"spaceAPIv5_Raw", Nil),
		FxGripAccessorEntry(@protocol(FxColorGamutAPI_v2), @"colorGamutAPIv2", @"colorGamutAPIv2_Raw", Nil),
		FxGripAccessorEntry(@protocol(FxTimingAPI_v4), @"timingAPIv4", @"timingAPIv4_Raw", FxGripTimingAPI_v4.class),
		FxGripAccessorEntry(@protocol(FxTimingAPI_v5), @"timingAPIv5", @"timingAPIv5_Raw", Nil),
		FxGripAccessorEntry(@protocol(FxKeyframeAPI_v3), @"keyframeAPIv3", @"keyframeAPIv3_Raw", Nil),
		FxGripAccessorEntry(@protocol(FxAnalysisAPI), @"analysisAPIv1", @"analysisAPIv1_Raw", Nil),
		FxGripAccessorEntry(@protocol(FxAnalysisAPI_v2), @"analysisAPIv2", @"analysisAPIv2_Raw", Nil),
		FxGripAccessorEntry(@protocol(FxProjectAPI), @"projectAPIv1", @"projectAPIv1_Raw", Nil),
		FxGripAccessorEntry(@protocol(FxProjectAPI_v2), @"projectAPIv2", @"projectAPIv2_Raw", Nil),
		FxGripAccessorEntry(@protocol(FxVersioningAPI), @"versioningAPIv1", @"versioningAPIv1_Raw", Nil),
	];
}

/*! FxGrip's own APIs: built by the manager with or without a host object behind them. */
- (NSDictionary<NSString *, Class> *)fxGripAccessorTable
{
	return @{@"parameterInfoAPIv1": FxGripParameterInfoAPI_v1.class,
			 @"parameterBoundsAPIv1": FxGripParameterBoundsAPI_v1.class,
			 @"metaAPIv1": FxGripMetaAPI_v1.class,
			 @"paramTagsAPIv1": FxGripParameterTagsAPI_v1.class,
			 @"presetsAPIv1": FxGripPresetsAPI_v1.class,
			 @"customCreationAPIv1": FxGripCustomCreationAPI_v1.class};
}

- (id)hostObjectFor:(Protocol *)protocol
{
	return [self.host hostObjectForProtocol:protocol];
}

#pragma mark Init

/*! @abstract Init reads the plugin UUID and session ID from a host manager that answers them, and retains the manager and effect. */
- (void)testInitReadsTheIdentityFromTheHostManager
{
	FxGripAPIAccessing *manager = self.manager;

	XCTAssertEqualObjects(manager.pluginUUID, @"ACCESSING-TEST-UUID");
	XCTAssertEqual(manager.sessionID, 77ull);
	XCTAssertEqual((id)manager.apiAccessing, (id)self.host);
	XCTAssertEqual((id)manager.effect, (id)self.effect);
}

/*! @abstract Init leaves the identity empty for a host manager that carries no UUID or session. */
- (void)testInitLeavesTheIdentityEmptyForABareHostManager
{
	FxGripAPIAccessing *manager = [FxGripAPIAccessing.alloc initWithAPIManager:FxGripAPIAccessingTestBareManager.new
																		 effect:(id)self.effect];

	XCTAssertNil(manager.pluginUUID);
	XCTAssertEqual(manager.sessionID, 0ull);
}

/*! @abstract The manager conforms to the FxGrip accessing protocol and the host's PROAPIAccessing. */
- (void)testTheManagerConformsToBothAccessingProtocols
{
	FxGripAPIAccessing *manager = self.manager;

	XCTAssertTrue([manager conformsToProtocol:@protocol(FxGripAPIAccessing)]);
	XCTAssertTrue([manager conformsToProtocol:@protocol(PROAPIAccessing)]);
}

#pragma mark Table walk

/*! @abstract With a host object behind every protocol, each plain accessor vends the wrapper class for its protocol or the host object itself, and each raw accessor vends the host object. */
- (void)testEveryAccessorVendsTheWrapperOrTheHostObject
{
	self.host.answersEveryProtocol = YES;
	FxGripAPIAccessing *manager = self.manager;

	for (NSDictionary *entry in self.hostAccessorTable) {
		Protocol *protocol = entry[kAccessorProtocol];
		id hostObject = [self hostObjectFor:protocol];
		id plain = [manager valueForKey:entry[kAccessorPlain]];
		id raw = [manager valueForKey:entry[kAccessorRaw]];
		Class wrapper = entry[kAccessorWrapper];

		XCTAssertEqual(raw, hostObject, @"%@ vends the host object", entry[kAccessorRaw]);
		if (wrapper == (Class)NSNull.null) {
			XCTAssertEqual(plain, hostObject, @"%@ has no wrapper and vends the host object", entry[kAccessorPlain]);
		} else {
			XCTAssertEqual([plain class], wrapper, @"%@ vends %@", entry[kAccessorPlain], NSStringFromClass(wrapper));
			XCTAssertEqual((id)[(FxGripCommonAPI *)plain effect], (id)self.effect);
			XCTAssertTrue([plain conformsToProtocol:protocol], @"the wrapper stands in for the protocol");
		}
	}
}

/*! @abstract apiForProtocol:bypass:YES vends the host object for every protocol, including ones FxGrip wraps. */
- (void)testBypassVendsTheHostObjectForEveryProtocol
{
	self.host.answersEveryProtocol = YES;
	FxGripAPIAccessing *manager = self.manager;

	for (NSDictionary *entry in self.hostAccessorTable) {
		Protocol *protocol = entry[kAccessorProtocol];
		XCTAssertEqual([manager apiForProtocol:protocol bypass:YES], [self hostObjectFor:protocol],
					   @"%@ bypasses the wrapper layer", NSStringFromProtocol(protocol));
	}
}

/*! @abstract apiForProtocol: resolves through the wrapper layer, the same as apiForProtocol:bypass:NO. */
- (void)testApiForProtocolResolvesThroughTheWrapperLayer
{
	self.host.answersEveryProtocol = YES;
	FxGripAPIAccessing *manager = self.manager;

	id viaPlain = [manager apiForProtocol:@protocol(FxDynamicParameterAPI_v3)];
	id viaBypassNo = [manager apiForProtocol:@protocol(FxDynamicParameterAPI_v3) bypass:NO];

	XCTAssertEqual([viaPlain class], FxGripDynamicParameterAPI_v3.class);
	XCTAssertEqual([viaBypassNo class], FxGripDynamicParameterAPI_v3.class);
	XCTAssertEqual((id)[(FxGripDynamicParameterAPI_v3 *)viaPlain api], [self hostObjectFor:@protocol(FxDynamicParameterAPI_v3)]);
}

/*! @abstract With no host object behind any protocol, every Apple-protocol accessor answers nil, plain and raw alike. */
- (void)testEveryHostAccessorIsNilWhenTheHostProvidesNothing
{
	FxGripAPIAccessing *manager = self.manager;

	for (NSDictionary *entry in self.hostAccessorTable) {
		XCTAssertNil([manager valueForKey:entry[kAccessorPlain]], @"%@ answers nil", entry[kAccessorPlain]);
		XCTAssertNil([manager valueForKey:entry[kAccessorRaw]], @"%@ answers nil", entry[kAccessorRaw]);
		XCTAssertNil([manager apiForProtocol:entry[kAccessorProtocol] bypass:YES]);
		XCTAssertNil([manager apiForProtocol:entry[kAccessorProtocol] bypass:NO]);
	}
}

/*! @abstract Each plain accessor asks the host for its own protocol. */
- (void)testEachAccessorAsksTheHostForItsProtocol
{
	FxGripAPIAccessing *manager = self.manager;

	for (NSDictionary *entry in self.hostAccessorTable) {
		[self.host.requested removeAllObjects];
		[manager valueForKey:entry[kAccessorRaw]];
		XCTAssertEqualObjects(self.host.requested, @[NSStringFromProtocol(entry[kAccessorProtocol])]);
	}
}

/*! @abstract FxGrip's own APIs are vended whether or not the host answers any protocol. */
- (void)testFxGripOwnAPIsAreVendedWithoutAHostObject
{
	FxGripAPIAccessing *bare = self.manager;
	self.host.answersEveryProtocol = YES;
	FxGripAPIAccessing *full = self.manager;

	[self.fxGripAccessorTable enumerateKeysAndObjectsUsingBlock:^(NSString *accessor, Class wrapper, BOOL *stop) {
		id fromBare = [bare valueForKey:accessor];
		id fromFull = [full valueForKey:accessor];
		XCTAssertEqual([fromBare class], wrapper, @"%@ builds without a host", accessor);
		XCTAssertEqual([fromFull class], wrapper, @"%@ builds with a host", accessor);
		XCTAssertEqual((id)[(FxGripCommonAPI *)fromBare effect], (id)self.effect);
	}];
}

/*! @abstract Each FxGrip-own protocol resolves through apiForProtocol: to its wrapper, and bypass answers nil because no host vends it. */
- (void)testFxGripOwnProtocolsResolveToTheirWrappers
{
	FxGripAPIAccessing *manager = self.manager;
	NSDictionary<NSString *, Class> *byProtocol = @{
		NSStringFromProtocol(@protocol(FxGripParameterInfoAPI_v1)): FxGripParameterInfoAPI_v1.class,
		NSStringFromProtocol(@protocol(FxGripParameterBoundsAPI_v1)): FxGripParameterBoundsAPI_v1.class,
		NSStringFromProtocol(@protocol(FxGripMetaAPI_v1)): FxGripMetaAPI_v1.class,
		NSStringFromProtocol(@protocol(FxGripParameterTagsAPI_v1)): FxGripParameterTagsAPI_v1.class,
		NSStringFromProtocol(@protocol(FxGripPresetsAPI_v1)): FxGripPresetsAPI_v1.class,
	};

	[byProtocol enumerateKeysAndObjectsUsingBlock:^(NSString *name, Class wrapper, BOOL *stop) {
		Protocol *protocol = NSProtocolFromString(name);
		XCTAssertEqual([[manager apiForProtocol:protocol] class], wrapper, @"%@", name);
		XCTAssertNil([manager apiForProtocol:protocol bypass:YES], @"%@ has no host object", name);
	}];
}

#pragma mark Composition

/*! @abstract The setting v5 wrapper is built over the host setter, the host retrieval v6, and an info wrapper over the host dynamic v3. */
- (void)testTheSettingWrapperIsComposedFromTheHostAPIs
{
	self.host.answersEveryProtocol = YES;
	FxGripParameterSettingAPI_v5 *setter = (FxGripParameterSettingAPI_v5 *)self.manager.paramSetAPIv5;

	XCTAssertEqual((id)setter.api, [self hostObjectFor:@protocol(FxParameterSettingAPI_v5)]);
	XCTAssertEqual((id)setter.paramGetAPIv6, [self hostObjectFor:@protocol(FxParameterRetrievalAPI_v6)]);
	XCTAssertEqual([setter.parameterInfoAPIv1 class], FxGripParameterInfoAPI_v1.class);
	XCTAssertEqual((id)[(FxGripParameterInfoAPI_v1 *)setter.parameterInfoAPIv1 api],
				   [self hostObjectFor:@protocol(FxDynamicParameterAPI_v3)]);
}

/*! @abstract The setting v6 wrapper is composed the same way over the host v6 setter. */
- (void)testTheSettingV6WrapperIsComposedFromTheHostAPIs
{
	self.host.answersEveryProtocol = YES;
	FxGripParameterSettingAPI_v6 *setter = (FxGripParameterSettingAPI_v6 *)self.manager.paramSetAPIv6;

	XCTAssertEqual((id)setter.api, [self hostObjectFor:@protocol(FxParameterSettingAPI_v6)]);
	XCTAssertEqual((id)setter.paramGetAPIv6, [self hostObjectFor:@protocol(FxParameterRetrievalAPI_v6)]);
	XCTAssertEqual([setter.parameterInfoAPIv1 class], FxGripParameterInfoAPI_v1.class);
}

/*! @abstract A setting wrapper built on a host without retrieval v6 carries a nil retrieval API and still vends. */
- (void)testTheSettingWrapperToleratesAHostWithoutRetrieval
{
	self.host.answers[NSStringFromProtocol(@protocol(FxParameterSettingAPI_v5))] = NSObject.new;
	self.host.answers[NSStringFromProtocol(@protocol(FxParameterSettingAPI_v6))] = NSObject.new;
	FxGripAPIAccessing *manager = self.manager;

	FxGripParameterSettingAPI_v5 *setterV5 = (FxGripParameterSettingAPI_v5 *)manager.paramSetAPIv5;
	FxGripParameterSettingAPI_v6 *setterV6 = (FxGripParameterSettingAPI_v6 *)manager.paramSetAPIv6;

	XCTAssertNotNil(setterV5);
	XCTAssertNil(setterV5.paramGetAPIv6);
	XCTAssertNil([(FxGripParameterInfoAPI_v1 *)setterV5.parameterInfoAPIv1 api]);
	XCTAssertNotNil(setterV6);
	XCTAssertNil(setterV6.paramGetAPIv6);
}

/*! @abstract The retrieval v6 and v7 wrappers carry the host getter and an info wrapper over the host dynamic v3. */
- (void)testTheRetrievalWrappersAreComposedFromTheHostAPIs
{
	self.host.answersEveryProtocol = YES;
	FxGripAPIAccessing *manager = self.manager;

	FxGripParameterRetrievalAPI_v6 *getterV6 = (FxGripParameterRetrievalAPI_v6 *)manager.paramGetAPIv6;
	FxGripParameterRetrievalAPI_v6 *getterV7 = (FxGripParameterRetrievalAPI_v6 *)manager.paramGetAPIv7;

	XCTAssertEqual((id)getterV6.api, [self hostObjectFor:@protocol(FxParameterRetrievalAPI_v6)]);
	XCTAssertEqual((id)[(FxGripParameterInfoAPI_v1 *)getterV6.parameterInfoAPIv1 api],
				   [self hostObjectFor:@protocol(FxDynamicParameterAPI_v3)]);
	XCTAssertEqual((id)getterV7.api, [self hostObjectFor:@protocol(FxParameterRetrievalAPI_v7)]);
	XCTAssertEqual([getterV7.parameterInfoAPIv1 class], FxGripParameterInfoAPI_v1.class);
}

/*! @abstract The info and bounds wrappers are built over the raw host dynamic v3, and carry nil when the host lacks it. */
- (void)testTheInfoAndBoundsWrappersWrapTheRawDynamicAPI
{
	FxGripAPIAccessing *bare = self.manager;
	XCTAssertNil([(FxGripParameterInfoAPI_v1 *)bare.parameterInfoAPIv1 api]);
	XCTAssertNil([(FxGripParameterBoundsAPI_v1 *)bare.parameterBoundsAPIv1 api]);

	self.host.answersEveryProtocol = YES;
	FxGripAPIAccessing *full = self.manager;
	id dynamicHost = [self hostObjectFor:@protocol(FxDynamicParameterAPI_v3)];

	XCTAssertEqual((id)[(FxGripParameterInfoAPI_v1 *)full.parameterInfoAPIv1 api], dynamicHost);
	XCTAssertEqual((id)[(FxGripParameterBoundsAPI_v1 *)full.parameterBoundsAPIv1 api], dynamicHost);
}

/*! @abstract The tags, presets, and timing wrappers carry the host object for their protocol, nil when the host has none. */
- (void)testTheTagsPresetsAndTimingWrappersCarryTheHostObject
{
	self.host.answersEveryProtocol = YES;
	FxGripAPIAccessing *manager = self.manager;

	XCTAssertEqual((id)[(FxGripParameterTagsAPI_v1 *)manager.paramTagsAPIv1 api],
				   [self hostObjectFor:@protocol(FxGripParameterTagsAPI_v1)]);
	XCTAssertEqual((id)[(FxGripPresetsAPI_v1 *)manager.presetsAPIv1 api],
				   [self hostObjectFor:@protocol(FxGripPresetsAPI_v1)]);
	XCTAssertEqual((id)[(FxGripTimingAPI_v4 *)manager.timingAPIv4 api],
				   [self hostObjectFor:@protocol(FxTimingAPI_v4)]);
}

/*! @abstract An FxGrip-implemented API still resolves when the host offers no object for its protocol, and wraps nothing. */
- (void)testTheTagsWrapperResolvesWithoutAHostObject
{
	XCTAssertNil([self hostObjectFor:@protocol(FxGripParameterTagsAPI_v1)]);

	id<FxGripParameterTagsAPI_v1> tags = self.manager.paramTagsAPIv1;

	XCTAssertNotNil(tags);
	XCTAssertNil([(FxGripParameterTagsAPI_v1 *)tags api]);
}

/*! @abstract Each accessor call builds a fresh wrapper over the same host object. */
- (void)testEachAccessorCallBuildsAFreshWrapper
{
	self.host.answersEveryProtocol = YES;
	FxGripAPIAccessing *manager = self.manager;

	id first = manager.dynamicParamAPIv3;
	id second = manager.dynamicParamAPIv3;

	XCTAssertNotEqual(first, second);
	XCTAssertEqual((id)[(FxGripDynamicParameterAPI_v3 *)first api], (id)[(FxGripDynamicParameterAPI_v3 *)second api]);
}

#pragma mark Version ordering

/*! @abstract A v5 creation request lands on the v5 wrapper and a v6 request on the v6 wrapper, so the ordered branches route by version. */
- (void)testCreationRequestsRouteByVersion
{
	self.host.answersEveryProtocol = YES;
	FxGripAPIAccessing *manager = self.manager;

	XCTAssertEqual([(NSObject *)manager.paramCreateAPIv5 class], FxGripParameterCreationAPI_v5.class);
	XCTAssertEqual([(NSObject *)manager.paramCreateAPIv6 class], FxGripParameterCreationAPI_v6.class);
	XCTAssertEqual((id)[(FxGripParameterCreationAPI_v5 *)manager.paramCreateAPIv5 api],
				   [self hostObjectFor:@protocol(FxParameterCreationAPI_v5)]);
	XCTAssertEqual((id)[(FxGripParameterCreationAPI_v6 *)manager.paramCreateAPIv6 api],
				   [self hostObjectFor:@protocol(FxParameterCreationAPI_v6)]);
}

/*! @abstract A v6 retrieval request lands on the v6 wrapper and a v7 request on the v7 wrapper. */
- (void)testRetrievalRequestsRouteByVersion
{
	self.host.answersEveryProtocol = YES;
	FxGripAPIAccessing *manager = self.manager;

	XCTAssertEqual([(NSObject *)manager.paramGetAPIv6 class], FxGripParameterRetrievalAPI_v6.class);
	XCTAssertEqual([(NSObject *)manager.paramGetAPIv7 class], FxGripParameterRetrievalAPI_v7.class);
}

/*! @abstract A v5 setting request lands on the v5 wrapper and a v6 request on the v6 wrapper. */
- (void)testSettingRequestsRouteByVersion
{
	self.host.answersEveryProtocol = YES;
	FxGripAPIAccessing *manager = self.manager;

	XCTAssertEqual([(NSObject *)manager.paramSetAPIv5 class], FxGripParameterSettingAPI_v5.class);
	XCTAssertEqual([(NSObject *)manager.paramSetAPIv6 class], FxGripParameterSettingAPI_v6.class);
}

/*! @abstract The timing v5 accessor vends the host object, because FxGrip wraps only timing v4. */
- (void)testTimingV5VendsTheHostObject
{
	self.host.answersEveryProtocol = YES;
	FxGripAPIAccessing *manager = self.manager;

	XCTAssertEqual((id)manager.timingAPIv5, [self hostObjectFor:@protocol(FxTimingAPI_v5)]);
	XCTAssertEqual([(NSObject *)manager.timingAPIv4 class], FxGripTimingAPI_v4.class);
}

#pragma mark Custom creation

/*! @abstract The custom creation API is built over the manager's effect, and is nil when the manager has no effect. */
- (void)testTheCustomCreationAPIRequiresAnEffect
{
	FxGripCustomCreationAPI_v1 *api = (FxGripCustomCreationAPI_v1 *)self.manager.customCreationAPIv1;
	XCTAssertEqual((id)api.effect, (id)self.effect);

	FxGripAPIAccessing *effectless = [FxGripAPIAccessing.alloc initWithAPIManager:self.host effect:(id _Nonnull)nil];
	XCTAssertNil(effectless.customCreationAPIv1);
}

@end
