//
//  FxGripAdoptionTests.m
//  FxGripTests
//
//  Verifies the incremental-adoption contract: a plain FxPlug-style plug-in that does not use
//  FxGripTileableEffect drives the parameter subsystem through the narrow FxGripEffectHost
//  protocol, with only the two required members. The optional-member fallbacks (font default,
//  gamut conversion, group recursion, preset meta) must degrade, not crash.
//

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripDictionary.h>
#import <FxGrip/FxGripEffectHost.h>
#import <FxGrip/FxGripTileableEffect.h>
#import <FxGrip/FxGripPluginHost.h>
#import <FxGrip/FxGripAllParameters.h>
#import <FxGrip/FxGripStatusParameter.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripAPIAccessing.h>
#import <FxGrip/FxGripCustomCreationAPI_v1.h>
#import <FxGrip/FxGripExtensionSystem.h>
#import <FxGrip/FxGripTileableEffect+Notifications.h>
#import "FxGripParameterClassTestSupport.h"

#pragma mark - Minimal host

/*! An "existing plug-in" host: the two required FxGripEffectHost members and nothing else. */
@interface FxGripAdoptionMinimalHost : NSObject <FxGripEffectHost>
@property (nonatomic, strong) FxGripParamClassTestAPIManager *manager;
@property (nonatomic, strong) NSNotificationCenter *center;
@end

@implementation FxGripAdoptionMinimalHost

- (id<FxGripAPIAccessing>)apiManager
{
	return (id<FxGripAPIAccessing>)self.manager;
}

- (NSPriorityNotificationCenter *)notifier
{
	return (NSPriorityNotificationCenter *)self.center;
}

- (nullable FxGripTileableEffect *)effectBase
{
	return nil;
}

@end

/*! A bare PROAPIAccessing for the plugin-host wrapper. */
@interface FxGripAdoptionStubPRO : NSObject <PROAPIAccessing>
@end

@implementation FxGripAdoptionStubPRO
- (id)apiForProtocol:(Protocol *)apiProtocol
{
	return nil;
}
- (NSString *)pluginUUID
{
	return @"ADOPTION-STUB-UUID";
}
@end

/*! A host that answers the identity and configuration attributes directly, with no effect base. */
@interface FxGripAdoptionAttributedHost : FxGripAdoptionMinimalHost
@end

@implementation FxGripAdoptionAttributedHost
- (NSDictionary<NSString *, id> *)pluginProperties
{
	return @{ @"name": @"Attributed" };
}
- (NSDictionary *)configurationForParameter:(UInt32)parameterID
{
	return @{ @"id": @(parameterID) };
}
@end

#pragma mark - Tests

@interface FxGripAdoptionTests : XCTestCase
@property (nonatomic, strong) FxGripAdoptionMinimalHost *host;
@end

@implementation FxGripAdoptionTests

- (void)setUp
{
	[super setUp];
	self.host = [FxGripAdoptionMinimalHost new];
	self.host.manager = [FxGripParamClassTestAPIManager new];
	self.host.manager.paramCreateAPIv5 = [FxGripParamClassTestCreationAPI new];
	self.host.center = [NSNotificationCenter new];
}

- (void)testTheEffectBaseConformsToTheHostProtocol
{
	XCTAssertTrue([NSClassFromString(@"FxGripTileableEffect")
					  conformsToProtocol:@protocol(FxGripEffectHost)],
				  @"a subclassed effect satisfies every host-typed entry point");
}

- (void)testAMinimalHostRegistersAStandardParameter
{
	NSDictionary *parameter = @{
		kFxParameterProperty_Id:      @101,
		kFxParameterProperty_Name:    @"Amount",
		kFxParameterProperty_Type:    kFxParameterType_Float,
		kFxParameterProperty_Default: @0.5,
	};
	XCTAssertTrue([FxGripFloatParameter addParameter:parameter toEffect:self.host]);
	NSDictionary *call = self.host.manager.paramCreateAPIv5.lastCall;
	XCTAssertNotNil(call, @"the creation call reached the host's API manager");
	XCTAssertEqualObjects(call[@"id"], @101);
}

- (void)testAMinimalHostRegistersACustomControl
{
	NSDictionary *parameter = @{
		kFxParameterProperty_Id:   @102,
		kFxParameterProperty_Name: @"State",
		kFxParameterProperty_Type: kFxParameterType_Status,
	};
	XCTAssertTrue([FxGripStatusParameter addParameter:parameter toEffect:self.host]);
	XCTAssertNotNil(self.host.manager.paramCreateAPIv5.lastCall);
}

- (void)testTheFontMenuFallsBackToTheDefaultFontOnAMinimalHost
{
	NSDictionary *parameter = @{
		kFxParameterProperty_Id:   @103,
		kFxParameterProperty_Name: @"Font",
		kFxParameterProperty_Type: kFxParameterType_FontMenu,
	};
	XCTAssertTrue([FxGripFontMenuParameter addParameter:parameter toEffect:self.host]);
	NSDictionary *call = self.host.manager.paramCreateAPIv5.lastCall;
	XCTAssertEqualObjects(call[@"default"], kFxParameterType_FontNameDefault,
						  @"no defaultFontName on the host; the shipped default is used");
}

- (void)testAColorWithAColorSpaceSkipsConversionOnAMinimalHost
{
	NSDictionary *parameter = @{
		kFxParameterProperty_Id:      @104,
		kFxParameterProperty_Name:    @"Tint",
		kFxParameterProperty_Type:    kFxParameterType_RGB,
		kFxParameterProperty_Default: @{ @"red": @0.5, @"green": @0.5, @"blue": @0.5,
										 @"colorSpace": @1 },
	};
	XCTAssertTrue([FxGripRGBParameter addParameter:parameter toEffect:self.host],
				  @"the gamut flags are absent, so the color registers unconverted");
}

- (void)testAGroupOnAMinimalHostOpensAndClosesWithoutRecursion
{
	NSDictionary *parameter = @{
		kFxParameterProperty_Id:   @105,
		kFxParameterProperty_Name: @"Controls",
		kFxParameterProperty_Type: kFxParameterType_Group,
	};
	XCTAssertTrue([FxGripGroupParameter addParameter:parameter toEffect:self.host]);
	NSArray<NSDictionary *> *calls = self.host.manager.paramCreateAPIv5.calls;
	XCTAssertEqual(calls.count, 2u, @"the group opens and closes; the host adds its own children");
}

- (void)testThePluginHostWrapsARawAPIManager
{
	FxGripPluginHost *host = [[FxGripPluginHost alloc] initWithAPIManager:[FxGripAdoptionStubPRO new]];
	XCTAssertTrue([host conformsToProtocol:@protocol(FxGripEffectHost)]);
	XCTAssertNotNil(host.apiManager, @"the FxGrip API layer stands up over a bare PROAPIAccessing");
	XCTAssertNotNil(host.notifier);
}

#pragma mark The effectBase seam

- (void)testHostsWithoutABaseReportANilEffectBase
{
	XCTAssertNil(self.host.effectBase, @"a plain plug-in host has no effect base");
	FxGripPluginHost *pluginHost = [[FxGripPluginHost alloc] initWithAPIManager:[FxGripAdoptionStubPRO new]];
	XCTAssertNil(pluginHost.effectBase);
}

- (void)testRichReadsDegradeThroughANilEffectBase
{
	// The API layer reads base-only members as host.effectBase.<member>; nil messaging makes a
	// baseless host return nil instead of crashing.
	FxGripTileableEffect *base = self.host.effectBase;
	XCTAssertNil(base.pluginProperties);
	XCTAssertNil([base configurationForParameter:1]);
}

- (void)testTheHostAttributeHelpersPreferTheDirectMembers
{
	FxGripAdoptionAttributedHost *host = [FxGripAdoptionAttributedHost new];
	XCTAssertEqualObjects(FxGripHostPluginProperties(host)[@"name"], @"Attributed",
						  @"the host's own attribute answers, no effect base involved");
	XCTAssertEqualObjects(FxGripHostConfigurationForParameter(host, 7)[@"id"], @7);
	XCTAssertNil(host.effectBase, @"the attributes did not come from a base");
}

- (void)testTheHostAttributeHelpersDegradeToNilWithoutABase
{
	XCTAssertNil(FxGripHostPluginProperties(self.host));
	XCTAssertNil(FxGripHostConfigurationForParameter(self.host, 7));
	XCTAssertNil(FxGripHostMeta(self.host));
	XCTAssertFalse(FxGripHostHasMeta(self.host));
	XCTAssertNil(FxGripHostParameterData(self.host));
}

- (void)testThePluginHostAnswersThePluginUUIDFromItsManager
{
	FxGripPluginHost *host = [[FxGripPluginHost alloc] initWithAPIManager:[FxGripAdoptionStubPRO new]];
	XCTAssertEqualObjects(FxGripHostPluginUUID(host), @"ADOPTION-STUB-UUID",
						  @"identity flows from the wrapped manager, so presets match on a plain host");
}

#pragma mark Custom creation API

- (void)testTheCustomCreationAPICreatesControlsAppleStyle
{
	FxGripCustomCreationAPI_v1 *api = [[FxGripCustomCreationAPI_v1 alloc] initWithEffect:self.host];
	XCTAssertNotNil(api);

	XCTAssertTrue([api addStatusWithName:@"State" parameterID:201 state:1 label:@"Ready" parameterFlags:0]);
	XCTAssertTrue([api addBannerWithName:@"Info" parameterID:202 title:@"Rendering" subtitle:nil parameterFlags:0]);
	XCTAssertTrue([api addRandomWithName:@"Seed" parameterID:203 defaultValue:7 minimum:1 maximum:100 step:1 parameterFlags:0]);
	XCTAssertEqual(self.host.manager.paramCreateAPIv5.calls.count, 3u,
				   @"each Apple-style call registered a custom control");
	NSDictionary *statusDefault = self.host.manager.paramCreateAPIv5.calls.firstObject[@"default"];
	XCTAssertEqualObjects(statusDefault[kCustomAPI_StringKey], @"Ready",
						  @"the configuration carries a type, so the declared default reaches the control");

	XCTAssertNil([[FxGripCustomCreationAPI_v1 alloc] initWithEffect:(id _Nonnull)nil],
				 @"no effect host, no API");
}

- (void)testThePluginHostVendsTheCustomCreationAPIThroughTheRoutingLayer
{
	FxGripPluginHost *host = [[FxGripPluginHost alloc] initWithAPIManager:[FxGripAdoptionStubPRO new]];
	FxGripCustomCreationAPI_v1 *api = (FxGripCustomCreationAPI_v1 *)host.apiManager.customCreationAPIv1;
	XCTAssertNotNil(api, @"the routing layer vends the creation API over the plugin host");
	XCTAssertEqual(api.effect, (id)host, @"the API registers against the host that owns the manager");
}

@end

#pragma mark - Extension system

/*! Records the lifecycle calls it observes and mutates the payloads it may. */
@interface FxGripSysTestExtension : FxGripExtensionBase
@property (nonatomic, assign) NSUInteger propertiesCalls;
@property (nonatomic, assign) NSUInteger addParametersCalls;
@property (nonatomic, assign) NSUInteger flushCalls;
@property (nonatomic, strong, nullable) NSNumber *changedParameterID;
@end

@implementation FxGripSysTestExtension

- (void)extProperties:(NSNotification *)notification
{
	self.propertiesCalls += 1;
	notification.userInfo.fxEffectProperties[@"sysTest"] = @YES;
}

- (void)extAddParameters:(NSNotification *)notification
{
	self.addParametersCalls += 1;
	[notification.userInfo.fxEffectParameters addObject:@{ @"added": @"bySysTest" }.mutableCopy];
}

- (void)extParameterChanged:(NSNotification *)notification
{
	self.changedParameterID = notification.userInfo[FxGripTileableEffectParameterChangedIDKey];
}

- (void)extFlush:(NSNotification *)notification
{
	self.flushCalls += 1;
}

@end

@interface FxGripExtensionSystemTests : XCTestCase
@property (nonatomic, strong) FxGripAdoptionMinimalHost *host;
@property (nonatomic, strong) FxGripExtensionSystem *system;
@property (nonatomic, strong) FxGripSysTestExtension *extension;
@end

@implementation FxGripExtensionSystemTests

- (void)setUp
{
	[super setUp];
	self.host = [FxGripAdoptionMinimalHost new];
	self.host.manager = [FxGripParamClassTestAPIManager new];
	// The extension dispatch uses the priority notification center's postBlock: variant.
	self.host.center = [[NSClassFromString(@"NSPriorityNotificationCenter") alloc] init];
	self.system = [[FxGripExtensionSystem alloc] initWithHost:self.host];
	self.extension = [FxGripSysTestExtension new];
	XCTAssertTrue([self.system loadExtension:self.extension]);
}

- (void)testTheSystemFindsALoadedExtensionByClass
{
	XCTAssertEqual([self.system extensionForClass:FxGripSysTestExtension.class], self.extension);
	XCTAssertEqual(self.system.extensions.count, 1u);
}

- (void)testPropertiesDispatchReachesTheExtensionAndReturnsItsEdits
{
	NSMutableDictionary *result = [self.system dispatchProperties:@{ @"base": @1 }];
	XCTAssertEqual(self.extension.propertiesCalls, 1u);
	XCTAssertEqualObjects(result[@"sysTest"], @YES, @"the extension's edit came back");
	XCTAssertEqualObjects(result[@"base"], @1);
}

- (void)testAddParametersDispatchLetsTheExtensionAppend
{
	NSMutableArray *result = [self.system dispatchAddParameters:@[ @{ @"mine": @1 } ]];
	XCTAssertEqual(self.extension.addParametersCalls, 1u);
	XCTAssertEqual(result.count, 2u, @"the plug-in's parameter plus the extension's");
}

- (void)testParameterChangedAndFlushDispatch
{
	CMTime time = { .value = 0, .timescale = 30, .flags = kCMTimeFlags_Valid };
	[self.system dispatchParameterChanged:77 atTime:time];
	XCTAssertEqualObjects(self.extension.changedParameterID, @77);

	XCTAssertNil([self.system flush]);
	XCTAssertEqual(self.extension.flushCalls, 1u);
}

@end
