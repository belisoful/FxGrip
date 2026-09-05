//
//  FxGripCustomUIParameterTests.m
//  FxGripTests
//
//  Unit tests for the custom-view parameter surface: FxGripSwitchParameter and
//  FxGripDividerParameter (type identity, the class creation entry point, the custom value
//  each hands the creation API, and the flags each forces on), the secure-coding
//  allow-list a parameter class declares and the effect resolves for a configured
//  parameter, the view host on FxGripTileableEffect, and the switch view's data push and
//  toggle write.
//
//  FxGripSwitchParameter.h is marked public but imports FxGripCustomViewDataDelegate.h,
//  which the target does not install, so the header cannot be included here; the switch
//  parameter and its view are reached by name through locally declared probe protocols.
//  FxGripDividerParameter.h imports only installed headers and is used directly. FXBox and
//  FxGripDividerData are not public and are reached by name.
//
//  AppKit is not linked into the test bundle. Its headers supply the view types and the
//  control-state constants; no AppKit class is ever named, so nothing is referenced at
//  link time.
//

#import <XCTest/XCTest.h>
#import <AppKit/AppKit.h>
#import "FxGripParameterClassTestSupport.h"
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripAPINotifications.h>
#import <FxGrip/FxGripParameter.h>
#import <FxGrip/FxGripDictionary.h>
#import <FxGrip/FxGripMetaManager.h>
#import <FxGrip/FxGripDividerParameter.h>
#import <FxGrip/FxGripSection.h>
#import <FxGrip/FxGripBanner.h>
#import <FxGrip/FxGripCapsule.h>
#import <FxGrip/FxGripWebView.h>
#import <FxGrip/FxGripVideoView.h>
#import <FxGrip/FxGripRandom.h>
#import <FxGrip/FxGripFloatParameter.h>
#import <FxGrip/FxGripTileableEffect.h>
#import <FxGrip/FxGripTileableEffect+CustomUI.h>
#import <FxGrip/FxGripTileableEffect+Parameters.h>

#pragma mark - Probes for the classes behind the uninstallable header

/*! The class-level parameter surface under test. */
@protocol FxGripCustomUIParameterClassProbe <NSObject>
+ (FxParameterType)parameterType;
+ (nullable NSString *)parameterTypeString;
+ (nullable NSSet<Class> *)customValueClasses;
+ (BOOL)addParameter:(NSDictionary *)parameter toEffect:(id)effect;
@end

/*! The instance surface a custom-view parameter adds to FxGripParameter. */
@protocol FxGripCustomUIParameterProbe <NSObject>
- (instancetype)initWithDictionary:(NSDictionary *)dictionary effect:(id)effect;
- (FxParameterType)parameterType;
- (nullable NSView *)newParameterView;
- (nullable NSView *)customView;
@end

/*! FxGripSwitchView. The state accessor is NSControl's; the rest is the framework's. */
@protocol FxGripCustomUISwitchViewProbe <NSObject>
- (instancetype)initWithFrame:(NSRect)frameRect;
@property (nonatomic, assign) NSControlStateValue state;
@property (nonatomic, assign) id parameterEffect;
@property (nonatomic, assign) FxParameterId parameterID;
- (void)updateFromCustomData:(nullable NSObject<NSSecureCoding, NSCopying> *)value;
- (void)fxSwitchToggled:(nullable id)sender;
@end

/*! The display views (FxGripStatusView, FxGripProgressView) take a value and redraw. */
@protocol FxGripCustomUIDisplayViewProbe <NSObject>
- (instancetype)initWithFrame:(NSRect)frameRect;
- (void)updateFromCustomData:(nullable NSObject<NSSecureCoding, NSCopying> *)value;
@end

/*! FxGripRandomView carries the parameter identity and writes its integer on reload. */
@protocol FxGripCustomUIRandomViewProbe <NSObject>
- (instancetype)initWithFrame:(NSRect)frameRect;
@property (nonatomic, assign, nullable) id<FxGripTileableEffect> parameterEffect;
@property (nonatomic, assign) FxParameterId parameterID;
- (void)updateFromCustomData:(nullable NSObject<NSSecureCoding, NSCopying> *)value;
- (void)reloadClicked:(nullable id)sender;
@end

/*! Implemented on FxGripTileableEffect but absent from the installed headers. */
@interface FxGripTileableEffect (FxGripCustomUIParameterTests)
- (BOOL)addParametersWithError:(NSError **)error;
- (nullable NSSet<Class> *)classesForCustomParameterID:(UInt32)parameterID;
- (NSMutableArray<NSDictionary *> *)parametersConfiguration;
@end

static const FxParameterId kCustomUITestSwitch = 81;
static const FxParameterId kCustomUITestDivider = 82;
static const FxParameterId kCustomUITestFloat = 83;
static const FxParameterId kCustomUITestUnconfigured = 84;
static const FxParameterId kCustomUITestStatus = 85;
static const FxParameterId kCustomUITestProgress = 86;
static const FxParameterId kCustomUITestSection = 87;
static const FxParameterId kCustomUITestBanner = 88;
static const FxParameterId kCustomUITestCapsule = 89;
static const FxParameterId kCustomUITestWebView = 90;
static const FxParameterId kCustomUITestVideo = 91;
static const FxParameterId kCustomUITestRandom = 92;

static Class FxGripCustomUITestSwitchClass(void)
{
	return NSClassFromString(@"FxGripSwitchParameter");
}

static Class FxGripCustomUITestSwitchViewClass(void)
{
	return NSClassFromString(@"FxGripSwitchView");
}

static Class FxGripCustomUITestStatusClass(void)
{
	return NSClassFromString(@"FxGripStatusParameter");
}

static Class FxGripCustomUITestProgressClass(void)
{
	return NSClassFromString(@"FxGripProgressParameter");
}

static Class FxGripCustomUITestSectionClass(void)
{
	return NSClassFromString(@"FxGripSectionParameter");
}

static Class FxGripCustomUITestBannerClass(void)
{
	return NSClassFromString(@"FxGripBannerParameter");
}

static Class FxGripCustomUITestCapsuleClass(void)
{
	return NSClassFromString(@"FxGripCapsuleParameter");
}

static Class FxGripCustomUITestWebViewClass(void)
{
	return NSClassFromString(@"FxGripWebViewParameter");
}

static Class FxGripCustomUITestVideoClass(void)
{
	return NSClassFromString(@"FxGripVideoViewParameter");
}

static Class FxGripCustomUITestRandomClass(void)
{
	return NSClassFromString(@"FxGripRandomParameter");
}

static Class FxGripCustomUITestRandomViewClass(void)
{
	return NSClassFromString(@"FxGripRandomView");
}

#pragma mark - Test doubles

/*! Stands in for the host's FxCustomParameterActionAPI_v4 that the out-of-band access
	context brackets its write with. */
@interface FxGripCustomUITestActionAPI : NSObject
@property (nonatomic, assign) CMTime currentTime;
@property (nonatomic, assign) NSUInteger startCount;
@property (nonatomic, assign) NSUInteger endCount;
@end

@implementation FxGripCustomUITestActionAPI

- (instancetype)init
{
	self = [super init];
	if (self) {
		_currentTime = FxGripParamClassTestTime(30, 60);
	}
	return self;
}

- (void)startAction:(id)sender
{
	self.startCount += 1;
}

- (void)endAction:(id)sender
{
	self.endCount += 1;
}

@end

/*! Adds the action API the shared manager double does not carry. */
@interface FxGripCustomUITestAPIManager : FxGripParamClassTestAPIManager
@property (nonatomic, strong) FxGripCustomUITestActionAPI *customParameterActionAPIv4;
@end

@implementation FxGripCustomUITestAPIManager

- (instancetype)init
{
	self = [super init];
	if (self) {
		_customParameterActionAPIv4 = [FxGripCustomUITestActionAPI.alloc init];
	}
	return self;
}

@end

/*!
	A real effect, for the parameter type map its initializer loads, the configuration
	record its parameter pass stores, and the view host. It answers a private notification
	center so no test touches the process-wide one.
*/
@interface FxGripCustomUITestHostEffect : FxGripTileableEffect
@property (nonatomic, strong) NSNotificationCenter *privateNotifier;
@property (nonatomic, strong, nullable) NSMutableArray<NSDictionary *> *stagedConfiguration;
@end

@implementation FxGripCustomUITestHostEffect

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

- (NSMutableArray<NSDictionary *> *)parametersConfiguration
{
	return self.stagedConfiguration ?: NSMutableArray.new;
}

@end

/*! Answers the parameter lookup the view host performs from a staged table. */
@interface FxGripCustomUITestViewHostEffect : FxGripCustomUITestHostEffect
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, id> *stagedParameters;
@end

@implementation FxGripCustomUITestViewHostEffect

- (id)effectBase
{
	// The stub plays the full effect; rich reads route back to it, as the old cast did.
	return self;
}


- (NSMutableDictionary<NSNumber *, id> *)stagedParameters
{
	if (!_stagedParameters) {
		_stagedParameters = NSMutableDictionary.new;
	}
	return _stagedParameters;
}

- (id<FxGripParameter>)objectAtIndexedSubscript:(NSInteger)index
{
	return self.stagedParameters[@(index)];
}

@end

#pragma mark - Tests

@interface FxGripCustomUIParameterTests : XCTestCase
@property (nonatomic, strong) FxGripParamClassTestEffect *effect;
@property (nonatomic, strong) FxGripCustomUITestAPIManager *apiManager;
@end

@implementation FxGripCustomUIParameterTests

- (void)setUp
{
	[super setUp];
	self.effect = [FxGripParamClassTestEffect.alloc init];
	self.apiManager = [FxGripCustomUITestAPIManager.alloc init];
	self.effect.apiManager = self.apiManager;
}

- (void)tearDown
{
	self.effect = nil;
	self.apiManager = nil;
	[super tearDown];
}

#pragma mark Helpers

- (NSDictionary *)call
{
	return self.effect.creationCall;
}

- (NSMutableDictionary *)switchConfigWithExtra:(nullable NSDictionary *)extra
{
	return FxGripParamClassTestConfig(kCustomUITestSwitch, kFxParameterType_Switch, @"Enabled", extra);
}

- (NSMutableDictionary *)dividerConfigWithExtra:(nullable NSDictionary *)extra
{
	return FxGripParamClassTestConfig(kCustomUITestDivider, kFxParameterType_Divider, @"Rule", extra);
}

- (Class<FxGripCustomUIParameterClassProbe>)switchClass
{
	Class parameterClass = FxGripCustomUITestSwitchClass();
	XCTAssertNotNil(parameterClass, @"FxGripSwitchParameter must be loaded from the framework");
	return (Class<FxGripCustomUIParameterClassProbe>)parameterClass;
}

- (id<FxGripCustomUIParameterProbe>)makeSwitchParameterWithExtra:(nullable NSDictionary *)extra
													  effect:(id)effect
{
	return [(id<FxGripCustomUIParameterProbe>)[FxGripCustomUITestSwitchClass() alloc]
			initWithDictionary:[self switchConfigWithExtra:extra] effect:effect];
}

- (id<FxGripCustomUISwitchViewProbe>)makeSwitchView
{
	Class viewClass = FxGripCustomUITestSwitchViewClass();
	XCTAssertNotNil(viewClass, @"FxGripSwitchView must be loaded from the framework");
	return [(id<FxGripCustomUISwitchViewProbe>)[viewClass alloc] initWithFrame:NSMakeRect(0, 0, 80, 24)];
}

/*! A real effect whose parameter pass has stored the switch, divider and float records. */
- (FxGripCustomUITestHostEffect *)makeConfiguredEffect
{
	FxGripCustomUITestHostEffect *effect = [FxGripCustomUITestHostEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	XCTAssertNotNil(effect);
	effect.stagedConfiguration = @[[self switchConfigWithExtra:nil],
								   [self dividerConfigWithExtra:nil],
								   FxGripParamClassTestConfig(kCustomUITestFloat, kFxParameterType_Float, @"Amount", nil)].mutableCopy;
	NSError *error = nil;
	[effect addParametersWithError:&error];
	return effect;
}

#pragma mark Switch creation

- (void)testTheSwitchParameterReportsItsTypeAndTypeString
{
	XCTAssertEqual([self.switchClass parameterType], FxParameterType_Switch);
	XCTAssertEqualObjects([self.switchClass parameterTypeString], kFxParameterType_Switch);
}

- (void)testASwitchInstanceReportsTheSwitchType
{
	id<FxGripCustomUIParameterProbe> parameter = [self makeSwitchParameterWithExtra:nil effect:(id)self.effect];

	XCTAssertEqual(parameter.parameterType, FxParameterType_Switch);
}

- (void)testASwitchIsCreatedAsACustomParameterCarryingAFalseDefault
{
	XCTAssertTrue([self.switchClass addParameter:[self switchConfigWithExtra:nil] toEffect:(id)self.effect]);

	XCTAssertEqualObjects(self.call[@"method"], @"custom");
	XCTAssertEqualObjects(self.call[@"id"], @(kCustomUITestSwitch));
	XCTAssertEqualObjects([self.call[@"default"] objectForKey:kCustomAPI_BoolKey], @NO);
}

- (void)testASwitchCarriesADeclaredTrueDefault
{
	NSDictionary *config = [self switchConfigWithExtra:@{kFxParameterProperty_Default: @YES}];

	XCTAssertTrue([self.switchClass addParameter:config toEffect:(id)self.effect]);

	XCTAssertEqualObjects([self.call[@"default"] objectForKey:kCustomAPI_BoolKey], @YES);
}

- (void)testASwitchDefaultValueIsAnFxGripDictionary
{
	XCTAssertTrue([self.switchClass addParameter:[self switchConfigWithExtra:nil] toEffect:(id)self.effect]);

	XCTAssertEqualObjects(NSStringFromClass([self.call[@"default"] class]), @"FxGripDictionary");
}

- (void)testASwitchForcesTheCustomInterfaceAndStatelessFlagsOnTopOfTheDeclaredFlags
{
	NSDictionary *config = [self switchConfigWithExtra:@{kFxParameterProperty_Flags: @(kFxParameterFlag_HIDDEN)}];

	XCTAssertTrue([self.switchClass addParameter:config toEffect:(id)self.effect]);

	XCTAssertEqualObjects(self.call[@"flags"], @(kFxParameterFlag_HIDDEN
												| kFxParameterFlag_CUSTOM_UI
												| kFxParameterFlag_NOSTATE));
}

- (void)testASwitchKeepsTheNameItsConfigurationDeclares
{
	NSDictionary *config = FxGripParamClassTestConfig(kCustomUITestSwitch, kFxParameterType_Switch, @"Motion Blur", nil);

	XCTAssertTrue([self.switchClass addParameter:config toEffect:(id)self.effect]);

	XCTAssertEqualObjects(self.call[@"name"], @"Motion Blur");
}

- (void)testASwitchReportsAHostRefusal
{
	self.effect.apiManager.paramCreateAPIv5.succeeds = NO;

	XCTAssertFalse([self.switchClass addParameter:[self switchConfigWithExtra:nil] toEffect:(id)self.effect]);
	XCTAssertEqual(self.effect.creationCalls.count, (NSUInteger)1);
}

#pragma mark Divider creation

- (void)testTheDividerParameterReportsItsTypeAndTypeString
{
	XCTAssertEqual(FxGripDividerParameter.parameterType, FxParameterType_Divider);
	XCTAssertEqualObjects(FxGripDividerParameter.parameterTypeString, kFxParameterType_Divider);
}

- (void)testADividerInstanceReportsTheDividerType
{
	FxGripDividerParameter *parameter = [FxGripDividerParameter.alloc
										 initWithDictionary:[self dividerConfigWithExtra:nil]
										 effect:(id)self.effect];

	XCTAssertEqual(parameter.parameterType, FxParameterType_Divider);
}

- (void)testADividerIsCreatedUnnamedAsACustomParameter
{
	XCTAssertTrue([FxGripDividerParameter addParameter:[self dividerConfigWithExtra:nil] toEffect:(id)self.effect]);

	XCTAssertEqualObjects(self.call[@"method"], @"custom");
	XCTAssertEqualObjects(self.call[@"name"], @"", @"a divider draws no label of its own");
	XCTAssertEqualObjects(self.call[@"id"], @(kCustomUITestDivider));
	XCTAssertEqualObjects(NSStringFromClass([self.call[@"default"] class]), @"FxGripDividerData");
}

- (void)testADividerAppliesTheDeclaredWidth
{
	NSDictionary *config = [self dividerConfigWithExtra:@{kFxParameterProperty_Default: @{@"width": @0.5}}];

	XCTAssertTrue([FxGripDividerParameter addParameter:config toEffect:(id)self.effect]);

	XCTAssertEqualObjects([self.call[@"default"] valueForKey:@"percentWidth"], @0.5);
}

- (void)testADividerIgnoresANonRecordDefault
{
	NSDictionary *config = [self dividerConfigWithExtra:@{kFxParameterProperty_Default: @"wide"}];

	XCTAssertTrue([FxGripDividerParameter addParameter:config toEffect:(id)self.effect]);

	XCTAssertEqualObjects(NSStringFromClass([self.call[@"default"] class]), @"FxGripDividerData");
	XCTAssertEqualObjects([self.call[@"default"] valueForKey:@"percentWidth"], @(phi - 1.0));
	XCTAssertEqualObjects([self.call[@"default"] valueForKey:@"marginTop"], @7);
	XCTAssertEqualObjects([self.call[@"default"] valueForKey:@"marginBottom"], @12);
}

- (void)testADividerForcesTheFullWidthStaticCustomInterfaceFlags
{
	NSDictionary *config = [self dividerConfigWithExtra:@{kFxParameterProperty_Flags: @(kFxParameterFlag_DISABLED)}];

	XCTAssertTrue([FxGripDividerParameter addParameter:config toEffect:(id)self.effect]);

	XCTAssertEqualObjects(self.call[@"flags"], @(kFxParameterFlag_DISABLED
												| kFxParameterFlag_CUSTOM_UI
												| kFxParameterFlag_NOT_ANIMATABLE
												| kFxParameterFlag_USE_FULL_VIEW_WIDTH
												| kFxParameterFlag_NOSTATE));
}

- (void)testADividerReportsAHostRefusal
{
	self.effect.apiManager.paramCreateAPIv5.succeeds = NO;

	XCTAssertFalse([FxGripDividerParameter addParameter:[self dividerConfigWithExtra:nil] toEffect:(id)self.effect]);
	XCTAssertEqual(self.effect.creationCalls.count, (NSUInteger)1);
}

#pragma mark Type gate

/*!
	The designated initializer compares the class's type against the configuration's, so a
	configuration declaring any other type builds nothing.
*/
- (void)testAConfigurationOfTheWrongTypeBuildsNoCustomUIParameter
{
	NSDictionary *config = FxGripParamClassTestConfig(kCustomUITestSwitch, kFxParameterType_Custom, @"Enabled", nil);

	id parameter = [(id<FxGripCustomUIParameterProbe>)[FxGripCustomUITestSwitchClass() alloc]
					initWithDictionary:config effect:(id)self.effect];

	XCTAssertNil(parameter);
}

#pragma mark Type map

- (void)testTheEffectResolvesTheSwitchTypeToTheSwitchParameterClass
{
	FxGripCustomUITestHostEffect *effect = [FxGripCustomUITestHostEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	XCTAssertNotNil(effect);

	XCTAssertEqualObjects([effect parameterClassWithTypeString:kFxParameterType_Switch], FxGripCustomUITestSwitchClass());
	XCTAssertEqualObjects([effect parameterClassWithType:FxParameterType_Switch], FxGripCustomUITestSwitchClass());
	XCTAssertEqual([effect parameterTypeWithString:kFxParameterType_Switch], FxParameterType_Switch);
}

- (void)testTheEffectResolvesTheDividerTypeToTheDividerParameterClass
{
	FxGripCustomUITestHostEffect *effect = [FxGripCustomUITestHostEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	XCTAssertNotNil(effect);

	XCTAssertEqualObjects([effect parameterClassWithTypeString:kFxParameterType_Divider], FxGripDividerParameter.class);
	XCTAssertEqualObjects([effect parameterClassWithType:FxParameterType_Divider], FxGripDividerParameter.class);
	XCTAssertEqual([effect parameterTypeWithString:kFxParameterType_Divider], FxParameterType_Divider);
}

#pragma mark Custom value classes

- (void)testTheSwitchDeclaresTheDictionaryValueClasses
{
	NSSet<Class> *classes = [self.switchClass customValueClasses];

	XCTAssertTrue([classes containsObject:FxGripDictionary.class]);
	XCTAssertTrue([classes containsObject:NSNumber.class]);
	XCTAssertTrue([classes containsObject:NSClassFromString(@"FxTime")],
				  @"the inherited dictionary list carries the time value class");
}

- (void)testTheDividerDeclaresOnlyItsOwnDataClass
{
	Class dataClass = NSClassFromString(@"FxGripDividerData");
	XCTAssertNotNil(dataClass);

	XCTAssertEqualObjects([FxGripDividerParameter customValueClasses], [NSSet setWithObject:dataClass]);
}

- (void)testAParameterClassWithoutACustomValueDeclaresNoClasses
{
	XCTAssertNil([FxGripFloatParameter customValueClasses]);
}

#pragma mark Effect-side value class resolution

- (void)testTheEffectStoresTheCustomUIConfigurationRecords
{
	FxGripCustomUITestHostEffect *effect = [self makeConfiguredEffect];

	XCTAssertEqualObjects([effect configurationForParameter:kCustomUITestSwitch][kFxParameterProperty_Type],
						  kFxParameterType_Switch);
	XCTAssertEqualObjects([effect configurationForParameter:kCustomUITestDivider][kFxParameterProperty_Type],
						  kFxParameterType_Divider);
}

- (void)testASwitchParameterResolvesTheDictionaryValueClasses
{
	FxGripCustomUITestHostEffect *effect = [self makeConfiguredEffect];

	NSSet<Class> *classes = [effect classesForCustomParameterID:kCustomUITestSwitch];

	XCTAssertEqualObjects(classes, [self.switchClass customValueClasses]);
	XCTAssertTrue([classes containsObject:FxGripDictionary.class]);
}

- (void)testADividerParameterResolvesItsOwnDataClass
{
	FxGripCustomUITestHostEffect *effect = [self makeConfiguredEffect];

	XCTAssertEqualObjects([effect classesForCustomParameterID:kCustomUITestDivider],
						  [NSSet setWithObject:NSClassFromString(@"FxGripDividerData")]);
}

- (void)testTheInstanceMetaParameterKeepsItsOwnValueClasses
{
	FxGripCustomUITestHostEffect *effect = [self makeConfiguredEffect];

	NSSet<Class> *classes = [effect classesForCustomParameterID:kFxParameterId_InstanceMeta];

	XCTAssertTrue([classes containsObject:FxGripMetaManager.class]);
	XCTAssertFalse([classes containsObject:NSClassFromString(@"FxGripDividerData")]);
}

- (void)testAParameterWithoutACustomValueResolvesNoClasses
{
	FxGripCustomUITestHostEffect *effect = [self makeConfiguredEffect];

	XCTAssertNil([effect classesForCustomParameterID:kCustomUITestFloat]);
}

- (void)testAnUnconfiguredParameterResolvesNoClasses
{
	FxGripCustomUITestHostEffect *effect = [self makeConfiguredEffect];

	XCTAssertNil([effect classesForCustomParameterID:kCustomUITestUnconfigured]);
}

#pragma mark Parameter views

- (void)testASwitchParameterBuildsASwitchViewCarryingItsIdentity
{
	id<FxGripCustomUIParameterProbe> parameter = [self makeSwitchParameterWithExtra:nil effect:(id)self.effect];
	XCTAssertNotNil(parameter);

	id<FxGripCustomUISwitchViewProbe> view = (id<FxGripCustomUISwitchViewProbe>)[parameter newParameterView];

	XCTAssertTrue([view isKindOfClass:FxGripCustomUITestSwitchViewClass()]);
	XCTAssertEqual(view.parameterID, kCustomUITestSwitch);
	XCTAssertEqualObjects(view.parameterEffect, self.effect);
}

- (void)testASwitchParameterViewStartsOffWithoutADeclaredDefault
{
	id<FxGripCustomUIParameterProbe> parameter = [self makeSwitchParameterWithExtra:nil effect:(id)self.effect];

	id<FxGripCustomUISwitchViewProbe> view = (id<FxGripCustomUISwitchViewProbe>)[parameter newParameterView];

	XCTAssertEqual(view.state, NSControlStateValueOff);
}

- (void)testASwitchParameterViewStartsOnForADeclaredTrueDefault
{
	id<FxGripCustomUIParameterProbe> parameter =
		[self makeSwitchParameterWithExtra:@{kFxParameterProperty_Default: @YES} effect:(id)self.effect];

	id<FxGripCustomUISwitchViewProbe> view = (id<FxGripCustomUISwitchViewProbe>)[parameter newParameterView];

	XCTAssertEqual(view.state, NSControlStateValueOn);
}

- (void)testADividerParameterAttachesItsBoxAndReturnsTheSizingContainer
{
	FxGripDividerParameter *parameter = [FxGripDividerParameter.alloc
										 initWithDictionary:[self dividerConfigWithExtra:nil]
										 effect:(id)self.effect];
	XCTAssertNotNil(parameter);

	NSView *container = [parameter newParameterView];
	NSView *box = parameter.customView;

	XCTAssertTrue([box isKindOfClass:NSClassFromString(@"FXBox")]);
	XCTAssertNotEqualObjects(container, box, @"the container wraps the box rather than being it");
	XCTAssertTrue([container.subviews containsObject:box]);
}

/*!
	DEFECT: FXBox reads a pushed dictionary under "percentWidth", "marginTop" and
	"marginBottom", while a divider configuration declares its default under "width",
	"margintop" and "marginbottom" — the shape FxGripDividerData consumes and the shape
	-newParameterView pushes into the box. The declared geometry never reaches the view.
*/
- (void)testADividerViewAdoptsTheDeclaredWidth
{
	NSDictionary *config = [self dividerConfigWithExtra:@{kFxParameterProperty_Default: @{@"width": @0.5}}];
	FxGripDividerParameter *parameter = [FxGripDividerParameter.alloc initWithDictionary:config
																				 effect:(id)self.effect];
	__unused NSView *container = [parameter newParameterView];

	XCTAssertEqualObjects([parameter.customView valueForKey:@"percentWidth"], @0.5);
}

#pragma mark View host

- (void)testTheViewHostReturnsAndAttachesASwitchView
{
	FxGripCustomUITestViewHostEffect *effect = [FxGripCustomUITestViewHostEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	id<FxGripCustomUIParameterProbe> parameter = [self makeSwitchParameterWithExtra:nil effect:(id)effect];
	effect.stagedParameters[@(kCustomUITestSwitch)] = parameter;

	NSView *view = [effect createViewForParameterID:kCustomUITestSwitch];

	XCTAssertTrue([view isKindOfClass:FxGripCustomUITestSwitchViewClass()]);
	XCTAssertEqualObjects(parameter.customView, view);
}

- (void)testTheViewHostReturnsTheDividerContainerAndLeavesTheAttachedBox
{
	FxGripCustomUITestViewHostEffect *effect = [FxGripCustomUITestViewHostEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	FxGripDividerParameter *parameter = [FxGripDividerParameter.alloc
										 initWithDictionary:[self dividerConfigWithExtra:nil]
										 effect:(id)effect];
	effect.stagedParameters[@(kCustomUITestDivider)] = parameter;

	NSView *container = [effect createViewForParameterID:kCustomUITestDivider];
	NSView *box = parameter.customView;

	XCTAssertTrue([box isKindOfClass:NSClassFromString(@"FXBox")],
				  @"the parameter attaches its box, so the host leaves the attachment alone");
	XCTAssertNotEqualObjects(container, box);
	XCTAssertTrue([container.subviews containsObject:box]);
}

- (void)testTheViewHostReturnsNothingForAParameterClassWithoutAView
{
	FxGripCustomUITestViewHostEffect *effect = [FxGripCustomUITestViewHostEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	NSDictionary *config = FxGripParamClassTestConfig(kCustomUITestFloat, kFxParameterType_Float, @"Amount", nil);
	FxGripFloatParameter *parameter = [FxGripFloatParameter.alloc initWithDictionary:config effect:(id)effect];
	effect.stagedParameters[@(kCustomUITestFloat)] = parameter;

	XCTAssertNil([effect createViewForParameterID:kCustomUITestFloat]);
	XCTAssertNil(parameter.customView);
}

- (void)testTheViewHostReturnsNothingForAnUnknownParameter
{
	FxGripCustomUITestViewHostEffect *effect = [FxGripCustomUITestViewHostEffect.alloc initWithAPIManager:(id _Nonnull)nil];

	XCTAssertNil([effect createViewForParameterID:kCustomUITestUnconfigured]);
}

#pragma mark View host against the effect's own parameter registry

- (void)testTheEffectRegistersAConstructedParameter
{
	FxGripCustomUITestHostEffect *effect = [FxGripCustomUITestHostEffect.alloc initWithAPIManager:(id _Nonnull)nil];

	[effect.notifier postNotificationName:FxGripNotifyAPI_ParameterAddName
								   object:effect
								 userInfo:[self dividerConfigWithExtra:nil]];

	XCTAssertTrue([effect.parameters[@(kCustomUITestDivider)] isKindOfClass:FxGripDividerParameter.class]);
}

/*!
	DEFECT: -objectAtIndexedSubscript: reads the _parameters cache directly, and
	-constructParameter: clears that cache after every registration. The subscript answers
	nil for a freshly constructed parameter until the -parameters getter repopulates it.
*/
- (void)testTheEffectFindsAConstructedParameterBySubscript
{
	FxGripCustomUITestHostEffect *effect = [FxGripCustomUITestHostEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	[effect.notifier postNotificationName:FxGripNotifyAPI_ParameterAddName
								   object:effect
								 userInfo:[self dividerConfigWithExtra:nil]];

	XCTAssertNotNil(effect[kCustomUITestDivider]);
}

/*!
	DEFECT (consequence of the subscript cache): the view host resolves the parameter
	through self[parameterID], so it builds no view for a parameter the effect has just
	constructed.
*/
- (void)testTheViewHostBuildsTheViewForAConstructedParameter
{
	FxGripCustomUITestHostEffect *effect = [FxGripCustomUITestHostEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	[effect.notifier postNotificationName:FxGripNotifyAPI_ParameterAddName
								   object:effect
								 userInfo:[self dividerConfigWithExtra:nil]];

	XCTAssertNotNil([effect createViewForParameterID:kCustomUITestDivider]);
}

- (void)testTheViewHostBuildsTheViewOnceTheParameterCacheIsPopulated
{
	FxGripCustomUITestHostEffect *effect = [FxGripCustomUITestHostEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	[effect.notifier postNotificationName:FxGripNotifyAPI_ParameterAddName
								   object:effect
								 userInfo:[self dividerConfigWithExtra:nil]];
	__unused NSDictionary *repopulate = effect.parameters;

	XCTAssertNotNil([effect createViewForParameterID:kCustomUITestDivider]);
}

#pragma mark Switch view data push

- (void)testTheSwitchViewTakesItsStateFromABoolCarryingDictionary
{
	id<FxGripCustomUISwitchViewProbe> view = [self makeSwitchView];

	[view updateFromCustomData:[FxGripDictionary dictionaryWithDictionary:@{kCustomAPI_BoolKey: @YES}]];

	XCTAssertEqual(view.state, NSControlStateValueOn);
}

- (void)testTheSwitchViewClearsItsStateForAFalseDictionary
{
	id<FxGripCustomUISwitchViewProbe> view = [self makeSwitchView];
	view.state = NSControlStateValueOn;

	[view updateFromCustomData:[FxGripDictionary dictionaryWithDictionary:@{kCustomAPI_BoolKey: @NO}]];

	XCTAssertEqual(view.state, NSControlStateValueOff);
}

- (void)testTheSwitchViewIgnoresAValueOfAnotherClass
{
	id<FxGripCustomUISwitchViewProbe> view = [self makeSwitchView];
	view.state = NSControlStateValueOn;

	[view updateFromCustomData:@"off"];
	[view updateFromCustomData:@{kCustomAPI_BoolKey: @NO}];
	[view updateFromCustomData:nil];

	XCTAssertEqual(view.state, NSControlStateValueOn);
}

- (void)testTheSwitchViewIgnoresADictionaryWithoutTheBooleanKey
{
	id<FxGripCustomUISwitchViewProbe> view = [self makeSwitchView];
	view.state = NSControlStateValueOn;

	[view updateFromCustomData:[FxGripDictionary dictionaryWithDictionary:@{@"tint": @"blue"}]];

	XCTAssertEqual(view.state, NSControlStateValueOn);
}

#pragma mark Switch view toggle

- (void)testTogglingTheSwitchWritesTheStateIntoTheParameterValue
{
	id<FxGripCustomUISwitchViewProbe> view = [self makeSwitchView];
	view.parameterEffect = (id)self.effect;
	view.parameterID = kCustomUITestSwitch;
	view.state = NSControlStateValueOn;

	@autoreleasepool {
		[view fxSwitchToggled:nil];
	}

	NSDictionary *write = self.apiManager.paramSetAPIv5.lastWrite;
	XCTAssertEqualObjects(write[@"accessor"], @"custom");
	XCTAssertEqualObjects(write[@"id"], @(kCustomUITestSwitch));
	XCTAssertEqualObjects(write[@"timevalue"], @30);
	XCTAssertEqualObjects(NSStringFromClass([write[@"value"] class]), @"FxGripDictionary");
	XCTAssertEqualObjects([write[@"value"] objectForKey:kCustomAPI_BoolKey], @YES);
}

- (void)testTogglingTheSwitchOffWritesAFalseValue
{
	id<FxGripCustomUISwitchViewProbe> view = [self makeSwitchView];
	view.parameterEffect = (id)self.effect;
	view.parameterID = kCustomUITestSwitch;
	view.state = NSControlStateValueOff;

	@autoreleasepool {
		[view fxSwitchToggled:nil];
	}

	XCTAssertEqualObjects([self.apiManager.paramSetAPIv5.lastWrite[@"value"] objectForKey:kCustomAPI_BoolKey], @NO);
}

- (void)testTogglingTheSwitchReadsTheParameterValueAtTheContextTime
{
	id<FxGripCustomUISwitchViewProbe> view = [self makeSwitchView];
	view.parameterEffect = (id)self.effect;
	view.parameterID = kCustomUITestSwitch;

	@autoreleasepool {
		[view fxSwitchToggled:nil];
	}

	NSDictionary *read = self.apiManager.paramGetAPIv6.lastRead;
	XCTAssertEqualObjects(read[@"accessor"], @"custom");
	XCTAssertEqualObjects(read[@"id"], @(kCustomUITestSwitch));
	XCTAssertEqualObjects(read[@"timevalue"], @30);
}

- (void)testTogglingTheSwitchKeepsTheOtherKeysOfTheParameterValue
{
	id<FxGripCustomUISwitchViewProbe> view = [self makeSwitchView];
	view.parameterEffect = (id)self.effect;
	view.parameterID = kCustomUITestSwitch;
	view.state = NSControlStateValueOn;
	self.apiManager.paramGetAPIv6.customValue =
		[FxGripDictionary dictionaryWithDictionary:@{kCustomAPI_BoolKey: @NO, @"tint": @"blue"}];

	@autoreleasepool {
		[view fxSwitchToggled:nil];
	}

	NSDictionary *written = self.apiManager.paramSetAPIv5.lastWrite[@"value"];
	XCTAssertEqualObjects([written objectForKey:kCustomAPI_BoolKey], @YES);
	XCTAssertEqualObjects([written objectForKey:@"tint"], @"blue");
}

- (void)testTogglingTheSwitchUnlocksALockedParameterValue
{
	id<FxGripCustomUISwitchViewProbe> view = [self makeSwitchView];
	view.parameterEffect = (id)self.effect;
	view.parameterID = kCustomUITestSwitch;
	view.state = NSControlStateValueOn;
	FxGripDictionary *locked = [FxGripDictionary dictionaryWithDictionary:@{}];
	locked.locked = YES;
	self.apiManager.paramGetAPIv6.customValue = locked;

	@autoreleasepool {
		[view fxSwitchToggled:nil];
	}

	XCTAssertEqualObjects([self.apiManager.paramSetAPIv5.lastWrite[@"value"] objectForKey:kCustomAPI_BoolKey], @YES);
}

- (void)testTogglingTheSwitchBracketsTheWriteInAnActionContext
{
	id<FxGripCustomUISwitchViewProbe> view = [self makeSwitchView];
	view.parameterEffect = (id)self.effect;
	view.parameterID = kCustomUITestSwitch;

	@autoreleasepool {
		[view fxSwitchToggled:nil];
	}

	XCTAssertEqual(self.apiManager.customParameterActionAPIv4.startCount, (NSUInteger)1);
	XCTAssertEqual(self.apiManager.customParameterActionAPIv4.endCount, (NSUInteger)1);
}

- (void)testTogglingTheSwitchWithoutAnEffectWritesNothing
{
	id<FxGripCustomUISwitchViewProbe> view = [self makeSwitchView];
	view.parameterID = kCustomUITestSwitch;
	view.state = NSControlStateValueOn;

	@autoreleasepool {
		[view fxSwitchToggled:nil];
	}

	XCTAssertEqualObjects(self.apiManager.paramSetAPIv5.writes, @[]);
	XCTAssertEqualObjects(self.apiManager.paramGetAPIv6.reads, @[]);
	XCTAssertEqual(self.apiManager.customParameterActionAPIv4.startCount, (NSUInteger)0);
}

#pragma mark Installed header closure

/*!
	DEFECT: FxGripSwitchParameter.h ships as a public header while
	FxGripCustomViewDataDelegate.h, which it imports, is not installed. Every client that
	imports the switch header — including the umbrella FxGrip.h — fails to compile.
*/
- (void)testThePublicSwitchHeaderResolvesTheHeadersItImports
{
	NSString *headers = [[NSBundle bundleForClass:FxGripDividerParameter.class].bundlePath
						 stringByAppendingPathComponent:@"Headers"];
	NSString *source = [NSString stringWithContentsOfFile:[headers stringByAppendingPathComponent:@"FxGripSwitchParameter.h"]
												 encoding:NSUTF8StringEncoding
													error:NULL];
	if (source == nil) {
		XCTSkip(@"the built framework's Headers folder is not reachable from the test runtime");
	}

	NSRegularExpression *quotedImport = [NSRegularExpression regularExpressionWithPattern:@"#import\\s+\"([^\"]+)\""
																				  options:0
																					error:NULL];
	NSMutableArray<NSString *> *missing = NSMutableArray.new;
	for (NSTextCheckingResult *match in [quotedImport matchesInString:source
															  options:0
																range:NSMakeRange(0, source.length)]) {
		NSString *imported = [source substringWithRange:[match rangeAtIndex:1]];
		if (![NSFileManager.defaultManager fileExistsAtPath:[headers stringByAppendingPathComponent:imported]]) {
			[missing addObject:imported];
		}
	}

	XCTAssertEqualObjects(missing, @[]);
}

#pragma mark Status display

- (Class<FxGripCustomUIParameterClassProbe>)statusClass
{
	Class cls = FxGripCustomUITestStatusClass();
	XCTAssertNotNil(cls, @"FxGripStatusParameter must be loaded from the framework");
	return (Class<FxGripCustomUIParameterClassProbe>)cls;
}

- (NSMutableDictionary *)statusConfigWithExtra:(nullable NSDictionary *)extra
{
	return FxGripParamClassTestConfig(kCustomUITestStatus, kFxParameterType_Status, @"State", extra);
}

- (void)testTheStatusParameterReportsItsTypeAndTypeString
{
	XCTAssertEqual([self.statusClass parameterType], FxParameterType_Status);
	XCTAssertEqualObjects([self.statusClass parameterTypeString], kFxParameterType_Status);
}

- (void)testAStatusIsCreatedAsACustomParameterCarryingAStateAndTextDefault
{
	XCTAssertTrue([self.statusClass addParameter:[self statusConfigWithExtra:nil] toEffect:(id)self.effect]);

	XCTAssertEqualObjects(self.call[@"method"], @"custom");
	XCTAssertEqualObjects(self.call[@"id"], @(kCustomUITestStatus));
	XCTAssertEqualObjects(NSStringFromClass([self.call[@"default"] class]), @"FxGripDictionary");
	XCTAssertEqualObjects([self.call[@"default"] objectForKey:kCustomAPI_IntKey], @0);
	XCTAssertEqualObjects([self.call[@"default"] objectForKey:kCustomAPI_StringKey], @"");
}

- (void)testAStatusCarriesADeclaredStateAndTextDefault
{
	NSDictionary *config = [self statusConfigWithExtra:@{kFxParameterProperty_Default:
		@{kCustomAPI_IntKey: @3, kCustomAPI_StringKey: @"Error"}}];

	XCTAssertTrue([self.statusClass addParameter:config toEffect:(id)self.effect]);

	XCTAssertEqualObjects([self.call[@"default"] objectForKey:kCustomAPI_IntKey], @3);
	XCTAssertEqualObjects([self.call[@"default"] objectForKey:kCustomAPI_StringKey], @"Error");
}

- (void)testAStatusForcesTheCustomInterfaceAndStatelessFlags
{
	XCTAssertTrue([self.statusClass addParameter:[self statusConfigWithExtra:nil] toEffect:(id)self.effect]);

	NSInteger flags = [self.call[@"flags"] integerValue];
	XCTAssertTrue((flags & kFxParameterFlag_CUSTOM_UI) != 0);
	XCTAssertTrue((flags & kFxParameterFlag_NOSTATE) != 0);
}

- (void)testAStatusViewBuildsAndAcceptsAValueWithoutThrowing
{
	id<FxGripCustomUIParameterProbe> parameter = [(id<FxGripCustomUIParameterProbe>)[FxGripCustomUITestStatusClass() alloc]
		initWithDictionary:[self statusConfigWithExtra:nil] effect:(id)self.effect];
	NSView *view = [parameter newParameterView];
	XCTAssertNotNil(view, @"the status parameter vends a view");

	id<FxGripCustomUIDisplayViewProbe> probe = (id<FxGripCustomUIDisplayViewProbe>)view;
	FxGripDictionary *value = [FxGripDictionary dictionaryWithDictionary:@{
		kCustomAPI_IntKey: @1, kCustomAPI_StringKey: @"Ready"}];
	NSDictionary *plain = @{kCustomAPI_IntKey: @1};
	XCTAssertNoThrow([probe updateFromCustomData:value]);
	XCTAssertNoThrow([probe updateFromCustomData:(NSObject<NSSecureCoding,NSCopying>*)plain], @"a plain dictionary is ignored");
}

#pragma mark Progress display

- (Class<FxGripCustomUIParameterClassProbe>)progressClass
{
	Class cls = FxGripCustomUITestProgressClass();
	XCTAssertNotNil(cls, @"FxGripProgressParameter must be loaded from the framework");
	return (Class<FxGripCustomUIParameterClassProbe>)cls;
}

- (NSMutableDictionary *)progressConfigWithExtra:(nullable NSDictionary *)extra
{
	return FxGripParamClassTestConfig(kCustomUITestProgress, kFxParameterType_Progress, @"Progress", extra);
}

- (void)testTheProgressParameterReportsItsTypeAndTypeString
{
	XCTAssertEqual([self.progressClass parameterType], FxParameterType_Progress);
	XCTAssertEqualObjects([self.progressClass parameterTypeString], kFxParameterType_Progress);
}

- (void)testAProgressIsCreatedAsACustomParameterCarryingAFractionStateAndTextDefault
{
	XCTAssertTrue([self.progressClass addParameter:[self progressConfigWithExtra:nil] toEffect:(id)self.effect]);

	XCTAssertEqualObjects(self.call[@"id"], @(kCustomUITestProgress));
	XCTAssertEqualObjects(NSStringFromClass([self.call[@"default"] class]), @"FxGripDictionary");
	XCTAssertEqualObjects([self.call[@"default"] objectForKey:kCustomAPI_FloatKey], @0.0);
	XCTAssertEqualObjects([self.call[@"default"] objectForKey:kCustomAPI_IntKey], @0);
	XCTAssertEqualObjects([self.call[@"default"] objectForKey:kCustomAPI_StringKey], @"");
}

- (void)testAProgressCarriesADeclaredFractionDefault
{
	NSDictionary *config = [self progressConfigWithExtra:@{kFxParameterProperty_Default:
		@{kCustomAPI_FloatKey: @0.5}}];

	XCTAssertTrue([self.progressClass addParameter:config toEffect:(id)self.effect]);

	XCTAssertEqualObjects([self.call[@"default"] objectForKey:kCustomAPI_FloatKey], @0.5);
}

- (void)testAProgressViewBuildsAndAcceptsDeterminateAndIndeterminateValues
{
	id<FxGripCustomUIParameterProbe> parameter = [(id<FxGripCustomUIParameterProbe>)[FxGripCustomUITestProgressClass() alloc]
		initWithDictionary:[self progressConfigWithExtra:nil] effect:(id)self.effect];
	NSView *view = [parameter newParameterView];
	XCTAssertNotNil(view, @"the progress parameter vends a view");

	id<FxGripCustomUIDisplayViewProbe> probe = (id<FxGripCustomUIDisplayViewProbe>)view;
	FxGripDictionary *determinate = [FxGripDictionary dictionaryWithDictionary:@{
		kCustomAPI_FloatKey: @0.45, kCustomAPI_IntKey: @4, kCustomAPI_StringKey: @"Generating"}];
	FxGripDictionary *indeterminate = [FxGripDictionary dictionaryWithDictionary:@{kCustomAPI_FloatKey: @(-1.0)}];
	FxGripDictionary *complete = [FxGripDictionary dictionaryWithDictionary:@{kCustomAPI_FloatKey: @1.0}];
	XCTAssertNoThrow([probe updateFromCustomData:determinate]);
	// A negative fraction switches the bar to indeterminate; back to a value returns it.
	XCTAssertNoThrow([probe updateFromCustomData:indeterminate]);
	XCTAssertNoThrow([probe updateFromCustomData:complete]);
}

#pragma mark Section header

- (Class<FxGripCustomUIParameterClassProbe>)sectionClass
{
	Class cls = FxGripCustomUITestSectionClass();
	XCTAssertNotNil(cls, @"FxGripSectionParameter must be loaded from the framework");
	return (Class<FxGripCustomUIParameterClassProbe>)cls;
}

- (NSMutableDictionary *)sectionConfigWithExtra:(nullable NSDictionary *)extra
{
	return FxGripParamClassTestConfig(kCustomUITestSection, kFxParameterType_Section, @"Adjustments", extra);
}

- (void)testTheSectionParameterReportsItsTypeAndTypeString
{
	XCTAssertEqual([self.sectionClass parameterType], FxParameterType_Section);
	XCTAssertEqualObjects([self.sectionClass parameterTypeString], kFxParameterType_Section);
}

- (void)testASectionIsCreatedUnnamedAsAFullWidthStaticCustomParameter
{
	XCTAssertTrue([self.sectionClass addParameter:[self sectionConfigWithExtra:nil] toEffect:(id)self.effect]);

	XCTAssertEqualObjects(self.call[@"method"], @"custom");
	XCTAssertEqualObjects(self.call[@"name"], @"", @"a section draws its own title, not the row label");
	XCTAssertEqualObjects(self.call[@"id"], @(kCustomUITestSection));
	XCTAssertEqualObjects(NSStringFromClass([self.call[@"default"] class]), @"FxGripSectionData");

	NSInteger flags = [self.call[@"flags"] integerValue];
	XCTAssertTrue((flags & kFxParameterFlag_CUSTOM_UI) != 0);
	XCTAssertTrue((flags & kFxParameterFlag_NOT_ANIMATABLE) != 0);
	XCTAssertTrue((flags & kFxParameterFlag_USE_FULL_VIEW_WIDTH) != 0);
	XCTAssertTrue((flags & kFxParameterFlag_NOSTATE) != 0);
}

- (void)testASectionWithoutADeclaredTitleFallsBackToTheParameterName
{
	XCTAssertTrue([self.sectionClass addParameter:[self sectionConfigWithExtra:nil] toEffect:(id)self.effect]);

	XCTAssertEqualObjects([self.call[@"default"] objectForKey:kCustomAPI_StringKey], @"Adjustments");
}

- (void)testASectionKeepsADeclaredTitleOverTheParameterName
{
	NSDictionary *config = [self sectionConfigWithExtra:@{kFxParameterProperty_Default:
		@{kCustomAPI_StringKey: @"Color"}}];

	XCTAssertTrue([self.sectionClass addParameter:config toEffect:(id)self.effect]);

	XCTAssertEqualObjects([self.call[@"default"] objectForKey:kCustomAPI_StringKey], @"Color");
}

- (void)testASectionViewBuildsAndAcceptsAStyledConfigurationWithoutThrowing
{
	NSDictionary *config = [self sectionConfigWithExtra:@{kFxParameterProperty_Default:
		@{kCustomAPI_StringKey: @"Color", kFxGripSectionKey_Transform: @(FxGripSectionTransformUppercase),
		  kFxGripSectionKey_Alignment: @(NSTextAlignmentCenter), kCustomAPI_FloatKey: @14.0,
		  kFxGripSectionKey_MarginTop: @6, kFxGripSectionKey_MarginBottom: @2}}];

	id<FxGripCustomUIParameterProbe> parameter = [(id<FxGripCustomUIParameterProbe>)[FxGripCustomUITestSectionClass() alloc]
		initWithDictionary:config effect:(id)self.effect];
	NSView *view = [parameter newParameterView];
	XCTAssertNotNil(view, @"the section parameter vends a view");

	id<FxGripCustomUIDisplayViewProbe> probe = (id<FxGripCustomUIDisplayViewProbe>)view;
	NSDictionary *plain = @{kCustomAPI_StringKey: @"Detail"};
	XCTAssertNoThrow([probe updateFromCustomData:(NSObject<NSSecureCoding,NSCopying>*)plain]);
}

#pragma mark Banner strip

- (Class<FxGripCustomUIParameterClassProbe>)bannerClass
{
	Class cls = FxGripCustomUITestBannerClass();
	XCTAssertNotNil(cls, @"FxGripBannerParameter must be loaded from the framework");
	return (Class<FxGripCustomUIParameterClassProbe>)cls;
}

- (NSMutableDictionary *)bannerConfigWithExtra:(nullable NSDictionary *)extra
{
	return FxGripParamClassTestConfig(kCustomUITestBanner, kFxParameterType_Banner, @"Notice", extra);
}

- (void)testTheBannerParameterReportsItsTypeAndTypeString
{
	XCTAssertEqual([self.bannerClass parameterType], FxParameterType_Banner);
	XCTAssertEqualObjects([self.bannerClass parameterTypeString], kFxParameterType_Banner);
}

- (void)testABannerIsCreatedUnnamedAsAFullWidthStaticCustomParameter
{
	XCTAssertTrue([self.bannerClass addParameter:[self bannerConfigWithExtra:nil] toEffect:(id)self.effect]);

	XCTAssertEqualObjects(self.call[@"method"], @"custom");
	XCTAssertEqualObjects(self.call[@"name"], @"", @"a banner spans the width and draws its own title");
	XCTAssertEqualObjects(self.call[@"id"], @(kCustomUITestBanner));
	XCTAssertEqualObjects(NSStringFromClass([self.call[@"default"] class]), @"FxGripDictionary");

	NSInteger flags = [self.call[@"flags"] integerValue];
	XCTAssertTrue((flags & kFxParameterFlag_CUSTOM_UI) != 0);
	XCTAssertTrue((flags & kFxParameterFlag_NOT_ANIMATABLE) != 0);
	XCTAssertTrue((flags & kFxParameterFlag_USE_FULL_VIEW_WIDTH) != 0);
	XCTAssertTrue((flags & kFxParameterFlag_NOSTATE) != 0);
}

- (void)testABannerWithoutADeclaredTitleFallsBackToTheParameterName
{
	XCTAssertTrue([self.bannerClass addParameter:[self bannerConfigWithExtra:nil] toEffect:(id)self.effect]);

	XCTAssertEqualObjects([self.call[@"default"] objectForKey:kCustomAPI_StringKey], @"Notice");
}

- (void)testABannerViewBuildsAndAcceptsATitleSubtitleAndColorsWithoutThrowing
{
	NSDictionary *config = [self bannerConfigWithExtra:@{kFxParameterProperty_Default:
		@{kCustomAPI_StringKey: @"Licensed", kFxGripBannerKey_Subtitle: @"Pro features enabled",
		  kCustomAPI_FloatKey: @13.0, kCustomAPI_RGBAKey: @[@0.1, @0.5, @0.2, @1.0],
		  kFxGripBannerKey_TextColor: @[@1.0, @1.0, @1.0, @1.0], kFxGripBannerKey_CornerRadius: @4.0}}];

	id<FxGripCustomUIParameterProbe> parameter = [(id<FxGripCustomUIParameterProbe>)[FxGripCustomUITestBannerClass() alloc]
		initWithDictionary:config effect:(id)self.effect];
	NSView *view = [parameter newParameterView];
	XCTAssertNotNil(view, @"the banner parameter vends a view");

	id<FxGripCustomUIDisplayViewProbe> probe = (id<FxGripCustomUIDisplayViewProbe>)view;
	FxGripDictionary *update = [FxGripDictionary dictionaryWithDictionary:@{kCustomAPI_StringKey: @"Trial"}];
	XCTAssertNoThrow([probe updateFromCustomData:update]);
}

- (void)testAnImageBannerTakesNoTitleFallbackSoTheGraphicCanStandAlone
{
	NSDictionary *config = [self bannerConfigWithExtra:@{kFxParameterProperty_Default:
		@{kFxGripBannerKey_ImageName: @"NSApplicationIcon"}}];

	XCTAssertTrue([self.bannerClass addParameter:config toEffect:(id)self.effect]);

	XCTAssertNil([self.call[@"default"] objectForKey:kCustomAPI_StringKey],
				 @"an image banner is not given the parameter name as a title");
	XCTAssertEqualObjects([self.call[@"default"] objectForKey:kFxGripBannerKey_ImageName], @"NSApplicationIcon");
}

- (void)testABannerViewAcceptsImageTemplateLinkAndActionButtonKeysWithoutThrowing
{
	NSDictionary *config = [self bannerConfigWithExtra:@{kFxParameterProperty_Default:
		@{kFxGripBannerKey_ImageName: @"NSApplicationIcon", kFxGripBannerKey_TemplateImage: @YES,
		  kFxGripBannerKey_LinkURL: @"https://example.com/docs", kFxGripBannerKey_ActionButton: @YES}}];

	id<FxGripCustomUIParameterProbe> parameter = [(id<FxGripCustomUIParameterProbe>)[FxGripCustomUITestBannerClass() alloc]
		initWithDictionary:config effect:(id)self.effect];
	NSView *view = [parameter newParameterView];
	XCTAssertNotNil(view, @"an image banner vends a view");

	id<FxGripCustomUIDisplayViewProbe> probe = (id<FxGripCustomUIDisplayViewProbe>)view;
	FxGripDictionary *update = [FxGripDictionary dictionaryWithDictionary:@{
		kFxGripBannerKey_ImageName: @"NSInfo", kFxGripBannerKey_LinkURL: @""}];
	XCTAssertNoThrow([probe updateFromCustomData:update], @"clearing the link and swapping the image is safe");
}

#pragma mark Capsule badge

- (Class<FxGripCustomUIParameterClassProbe>)capsuleClass
{
	Class cls = FxGripCustomUITestCapsuleClass();
	XCTAssertNotNil(cls, @"FxGripCapsuleParameter must be loaded from the framework");
	return (Class<FxGripCustomUIParameterClassProbe>)cls;
}

- (NSMutableDictionary *)capsuleConfigWithExtra:(nullable NSDictionary *)extra
{
	return FxGripParamClassTestConfig(kCustomUITestCapsule, kFxParameterType_Capsule, @"Tier", extra);
}

- (void)testTheCapsuleParameterReportsItsTypeAndTypeString
{
	XCTAssertEqual([self.capsuleClass parameterType], FxParameterType_Capsule);
	XCTAssertEqualObjects([self.capsuleClass parameterTypeString], kFxParameterType_Capsule);
}

- (void)testACapsuleIsCreatedAsAStaticCustomParameterKeepingItsRowLabel
{
	XCTAssertTrue([self.capsuleClass addParameter:[self capsuleConfigWithExtra:nil] toEffect:(id)self.effect]);

	XCTAssertEqualObjects(self.call[@"method"], @"custom");
	XCTAssertEqualObjects(self.call[@"name"], @"Tier", @"a capsule is a control on a named row");
	XCTAssertEqualObjects(self.call[@"id"], @(kCustomUITestCapsule));
	XCTAssertEqualObjects(NSStringFromClass([self.call[@"default"] class]), @"FxGripDictionary");

	NSInteger flags = [self.call[@"flags"] integerValue];
	XCTAssertTrue((flags & kFxParameterFlag_CUSTOM_UI) != 0);
	XCTAssertTrue((flags & kFxParameterFlag_NOT_ANIMATABLE) != 0);
	XCTAssertTrue((flags & kFxParameterFlag_NOSTATE) != 0);
	XCTAssertTrue((flags & kFxParameterFlag_USE_FULL_VIEW_WIDTH) == 0, @"a capsule is not full width");
}

- (void)testACapsuleViewBuildsAndAcceptsTextColorsAndRadiusWithoutThrowing
{
	NSDictionary *config = [self capsuleConfigWithExtra:@{kFxParameterProperty_Default:
		@{kCustomAPI_StringKey: @"PRO", kCustomAPI_FloatKey: @11.0,
		  kCustomAPI_RGBAKey: @[@0.2, @0.2, @0.9, @1.0],
		  kFxGripCapsuleKey_TextColor: @[@1.0, @1.0, @1.0, @1.0], kFxGripCapsuleKey_CornerRadius: @6.0}}];

	id<FxGripCustomUIParameterProbe> parameter = [(id<FxGripCustomUIParameterProbe>)[FxGripCustomUITestCapsuleClass() alloc]
		initWithDictionary:config effect:(id)self.effect];
	NSView *view = [parameter newParameterView];
	XCTAssertNotNil(view, @"the capsule parameter vends a view");

	id<FxGripCustomUIDisplayViewProbe> probe = (id<FxGripCustomUIDisplayViewProbe>)view;
	FxGripDictionary *pill = [FxGripDictionary dictionaryWithDictionary:@{kCustomAPI_StringKey: @"FREE"}];
	XCTAssertNoThrow([probe updateFromCustomData:pill], @"an absent corner radius draws a full pill");
}

#pragma mark WebView

- (Class<FxGripCustomUIParameterClassProbe>)webViewClass
{
	Class cls = FxGripCustomUITestWebViewClass();
	XCTAssertNotNil(cls, @"FxGripWebViewParameter must be loaded from the framework");
	return (Class<FxGripCustomUIParameterClassProbe>)cls;
}

- (NSMutableDictionary *)webViewConfigWithExtra:(nullable NSDictionary *)extra
{
	return FxGripParamClassTestConfig(kCustomUITestWebView, kFxParameterType_WebView, @"Docs", extra);
}

- (void)testTheWebViewParameterReportsItsTypeAndTypeString
{
	XCTAssertEqual([self.webViewClass parameterType], FxParameterType_WebView);
	XCTAssertEqualObjects([self.webViewClass parameterTypeString], kFxParameterType_WebView);
}

- (void)testAWebViewIsCreatedUnnamedAsAFullWidthStaticCustomParameter
{
	XCTAssertTrue([self.webViewClass addParameter:[self webViewConfigWithExtra:nil] toEffect:(id)self.effect]);

	XCTAssertEqualObjects(self.call[@"method"], @"custom");
	XCTAssertEqualObjects(self.call[@"name"], @"");
	XCTAssertEqualObjects(self.call[@"id"], @(kCustomUITestWebView));
	XCTAssertEqualObjects(NSStringFromClass([self.call[@"default"] class]), @"FxGripDictionary");

	NSInteger flags = [self.call[@"flags"] integerValue];
	XCTAssertTrue((flags & kFxParameterFlag_CUSTOM_UI) != 0);
	XCTAssertTrue((flags & kFxParameterFlag_NOT_ANIMATABLE) != 0);
	XCTAssertTrue((flags & kFxParameterFlag_USE_FULL_VIEW_WIDTH) != 0);
	XCTAssertTrue((flags & kFxParameterFlag_NOSTATE) != 0);
}

- (void)testAWebViewWithoutADeclaredWhitelistDefaultsToAllSites
{
	XCTAssertTrue([self.webViewClass addParameter:[self webViewConfigWithExtra:nil] toEffect:(id)self.effect]);

	XCTAssertEqualObjects([self.call[@"default"] objectForKey:kFxGripWebViewKey_Whitelist], (@[@"*"]));
}

- (void)testAWebViewKeepsADeclaredWhitelist
{
	NSArray *list = @[@"apple.com", @"developer.apple.com"];
	NSDictionary *config = [self webViewConfigWithExtra:@{kFxParameterProperty_Default:
		@{kFxGripWebViewKey_URL: @"https://developer.apple.com/", kFxGripWebViewKey_Whitelist: list}}];

	XCTAssertTrue([self.webViewClass addParameter:config toEffect:(id)self.effect]);

	XCTAssertEqualObjects([self.call[@"default"] objectForKey:kFxGripWebViewKey_Whitelist], list);
}

- (void)testAWebViewViewBuildsWithoutStartingAWebProcess
{
	NSDictionary *config = [self webViewConfigWithExtra:@{kFxParameterProperty_Default:
		@{kFxGripWebViewKey_URL: @"https://developer.apple.com/", kFxGripWebViewKey_Whitelist: @[@"apple.com"],
		  kFxGripWebViewKey_Height: @240.0}}];

	id<FxGripCustomUIParameterProbe> parameter = [(id<FxGripCustomUIParameterProbe>)[FxGripCustomUITestWebViewClass() alloc]
		initWithDictionary:config effect:(id)self.effect];
	NSView *view = [parameter newParameterView];
	XCTAssertNotNil(view, @"the web-view parameter vends a view");

	// The view is off-window here, so applying content must not create the WKWebView.
	id<FxGripCustomUIDisplayViewProbe> probe = (id<FxGripCustomUIDisplayViewProbe>)view;
	FxGripDictionary *update = [FxGripDictionary dictionaryWithDictionary:@{kFxGripWebViewKey_URL: @"https://developer.apple.com/x"}];
	XCTAssertNoThrow([probe updateFromCustomData:update]);
}

#pragma mark Video

- (Class<FxGripCustomUIParameterClassProbe>)videoClass
{
	Class cls = FxGripCustomUITestVideoClass();
	XCTAssertNotNil(cls, @"FxGripVideoViewParameter must be loaded from the framework");
	return (Class<FxGripCustomUIParameterClassProbe>)cls;
}

- (NSMutableDictionary *)videoConfigWithExtra:(nullable NSDictionary *)extra
{
	return FxGripParamClassTestConfig(kCustomUITestVideo, kFxParameterType_VideoView, @"Tutorial", extra);
}

- (void)testTheVideoParameterReportsItsTypeAndTypeString
{
	XCTAssertEqual([self.videoClass parameterType], FxParameterType_VideoView);
	XCTAssertEqualObjects([self.videoClass parameterTypeString], kFxParameterType_VideoView);
}

- (void)testAVideoIsCreatedUnnamedAsAFullWidthStaticCustomParameter
{
	XCTAssertTrue([self.videoClass addParameter:[self videoConfigWithExtra:nil] toEffect:(id)self.effect]);

	XCTAssertEqualObjects(self.call[@"method"], @"custom");
	XCTAssertEqualObjects(self.call[@"name"], @"");
	XCTAssertEqualObjects(self.call[@"id"], @(kCustomUITestVideo));
	XCTAssertEqualObjects(NSStringFromClass([self.call[@"default"] class]), @"FxGripDictionary");

	NSInteger flags = [self.call[@"flags"] integerValue];
	XCTAssertTrue((flags & kFxParameterFlag_CUSTOM_UI) != 0);
	XCTAssertTrue((flags & kFxParameterFlag_NOT_ANIMATABLE) != 0);
	XCTAssertTrue((flags & kFxParameterFlag_USE_FULL_VIEW_WIDTH) != 0);
	XCTAssertTrue((flags & kFxParameterFlag_NOSTATE) != 0);
}

- (void)testAVideoWithoutADeclaredWhitelistDefaultsToTheVideoDomains
{
	XCTAssertTrue([self.videoClass addParameter:[self videoConfigWithExtra:nil] toEffect:(id)self.effect]);

	NSArray *whitelist = [self.call[@"default"] objectForKey:kFxGripVideoKey_Whitelist];
	XCTAssertTrue([whitelist containsObject:@"youtube.com"]);
	XCTAssertTrue([whitelist containsObject:@"rumble.com"]);
}

- (void)testAVideoViewBuildsWithoutStartingAPlayer
{
	NSDictionary *config = [self videoConfigWithExtra:@{kFxParameterProperty_Default:
		@{kFxGripVideoKey_URL: @"https://www.youtube.com/watch?v=abc",
		  kFxGripVideoKey_Autoplay: @YES, kFxGripVideoKey_Loop: @YES, kFxGripVideoKey_Height: @200.0}}];

	id<FxGripCustomUIParameterProbe> parameter = [(id<FxGripCustomUIParameterProbe>)[FxGripCustomUITestVideoClass() alloc]
		initWithDictionary:config effect:(id)self.effect];
	NSView *view = [parameter newParameterView];
	XCTAssertNotNil(view, @"the video parameter vends a view");

	// Off-window, so applying content must not create a WKWebView or AVPlayerView.
	id<FxGripCustomUIDisplayViewProbe> probe = (id<FxGripCustomUIDisplayViewProbe>)view;
	FxGripDictionary *media = [FxGripDictionary dictionaryWithDictionary:@{kFxGripVideoKey_URL: @"https://youtu.be/xyz"}];
	XCTAssertNoThrow([probe updateFromCustomData:media]);
}

#pragma mark Random

- (Class<FxGripCustomUIParameterClassProbe>)randomClass
{
	Class cls = FxGripCustomUITestRandomClass();
	XCTAssertNotNil(cls, @"FxGripRandomParameter must be loaded from the framework");
	return (Class<FxGripCustomUIParameterClassProbe>)cls;
}

- (NSMutableDictionary *)randomConfigWithExtra:(nullable NSDictionary *)extra
{
	return FxGripParamClassTestConfig(kCustomUITestRandom, kFxParameterType_Random, @"Seed", extra);
}

- (id<FxGripCustomUIRandomViewProbe>)makeRandomViewForID:(FxParameterId)parameterID
{
	id<FxGripCustomUIRandomViewProbe> view = [(id<FxGripCustomUIRandomViewProbe>)[FxGripCustomUITestRandomViewClass() alloc]
		initWithFrame:NSMakeRect(0, 0, 120, 22)];
	view.parameterEffect = (id)self.effect;
	view.parameterID = parameterID;
	return view;
}

- (void)testTheRandomParameterReportsItsTypeAndTypeString
{
	XCTAssertEqual([self.randomClass parameterType], FxParameterType_Random);
	XCTAssertEqualObjects([self.randomClass parameterTypeString], kFxParameterType_Random);
}

- (void)testARandomIsCreatedAsACustomParameterDefaultingToZeroWithARange
{
	XCTAssertTrue([self.randomClass addParameter:[self randomConfigWithExtra:nil] toEffect:(id)self.effect]);

	XCTAssertEqualObjects(self.call[@"id"], @(kCustomUITestRandom));
	XCTAssertEqualObjects(NSStringFromClass([self.call[@"default"] class]), @"FxGripDictionary");
	XCTAssertEqualObjects([self.call[@"default"] objectForKey:kFxGripRandomKey_Value], @0);
	XCTAssertEqualObjects([self.call[@"default"] objectForKey:kFxGripRandomKey_Min], @(kFxGripRandomDefaultMin));
	XCTAssertEqualObjects([self.call[@"default"] objectForKey:kFxGripRandomKey_Max], @(kFxGripRandomDefaultMax));

	NSInteger flags = [self.call[@"flags"] integerValue];
	XCTAssertTrue((flags & kFxParameterFlag_CUSTOM_UI) != 0);
	XCTAssertTrue((flags & kFxParameterFlag_NOSTATE) != 0);
}

- (void)testARandomCarriesADeclaredValueAndRange
{
	NSDictionary *config = [self randomConfigWithExtra:@{kFxParameterProperty_Default:
		@{kFxGripRandomKey_Value: @7, kFxGripRandomKey_Min: @1, kFxGripRandomKey_Max: @9, kFxGripRandomKey_Step: @2}}];

	XCTAssertTrue([self.randomClass addParameter:config toEffect:(id)self.effect]);

	XCTAssertEqualObjects([self.call[@"default"] objectForKey:kFxGripRandomKey_Value], @7);
	XCTAssertEqualObjects([self.call[@"default"] objectForKey:kFxGripRandomKey_Min], @1);
	XCTAssertEqualObjects([self.call[@"default"] objectForKey:kFxGripRandomKey_Max], @9);
	XCTAssertEqualObjects([self.call[@"default"] objectForKey:kFxGripRandomKey_Step], @2);
}

- (void)testTheRandomViewCarriesItsIdentity
{
	id<FxGripCustomUIParameterProbe> parameter = [(id<FxGripCustomUIParameterProbe>)[FxGripCustomUITestRandomClass() alloc]
		initWithDictionary:[self randomConfigWithExtra:nil] effect:(id)self.effect];
	id<FxGripCustomUIRandomViewProbe> view = (id<FxGripCustomUIRandomViewProbe>)[parameter newParameterView];

	XCTAssertTrue([view isKindOfClass:FxGripCustomUITestRandomViewClass()]);
	XCTAssertEqual(view.parameterID, kCustomUITestRandom);
	XCTAssertEqualObjects(view.parameterEffect, self.effect);
}

- (void)testReloadWritesTheDrawnValueIntoTheParameter
{
	id<FxGripCustomUIRandomViewProbe> view = [self makeRandomViewForID:kCustomUITestRandom];
	// A single-value range makes the draw deterministic.
	FxGripDictionary *pinned = [FxGripDictionary dictionaryWithDictionary:@{
		kFxGripRandomKey_Min: @42, kFxGripRandomKey_Max: @42}];
	[view updateFromCustomData:pinned];

	@autoreleasepool {
		[view reloadClicked:nil];
	}

	NSDictionary *write = self.apiManager.paramSetAPIv5.lastWrite;
	XCTAssertEqualObjects(write[@"accessor"], @"custom");
	XCTAssertEqualObjects(write[@"id"], @(kCustomUITestRandom));
	XCTAssertEqualObjects(NSStringFromClass([write[@"value"] class]), @"FxGripDictionary");
	XCTAssertEqualObjects([write[@"value"] objectForKey:kCustomAPI_IntKey], @42);
}

- (void)testReloadStaysWithinTheConfiguredRange
{
	id<FxGripCustomUIRandomViewProbe> view = [self makeRandomViewForID:kCustomUITestRandom];
	FxGripDictionary *range = [FxGripDictionary dictionaryWithDictionary:@{
		kFxGripRandomKey_Min: @10, kFxGripRandomKey_Max: @20}];
	[view updateFromCustomData:range];

	for (int i = 0; i < 50; i++) {
		@autoreleasepool {
			[view reloadClicked:nil];
		}
		int drawn = [[self.apiManager.paramSetAPIv5.lastWrite[@"value"] objectForKey:kCustomAPI_IntKey] intValue];
		XCTAssertGreaterThanOrEqual(drawn, 10);
		XCTAssertLessThanOrEqual(drawn, 20);
	}
}

@end
