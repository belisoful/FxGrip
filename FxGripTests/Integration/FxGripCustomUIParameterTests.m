/*!
	@file       FxGripCustomUIParameterTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripCustomUIParameterTests
	@abstract   Verifies the custom-view parameter surface across creation, type resolution, secure-coding classes, views, and the view host.
	@discussion Introduced in FxGrip 0.1.0. The switch, divider, status, progress, and other custom-view parameters are reached by name through probe protocols because their public headers cannot be included in the test bundle. The tests confirm each parameter's type identity, the custom value it hands the creation API, the flags it forces, the secure-coding classes it declares and the effect resolves, the views it builds, the view host on FxGripTileableEffect, and the switch view's data push and toggle write.
*/

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

/*! @abstract The switch parameter class reports the switch type and type string. */
- (void)testTheSwitchParameterReportsItsTypeAndTypeString
{
	XCTAssertEqual([self.switchClass parameterType], FxParameterType_Switch);
	XCTAssertEqualObjects([self.switchClass parameterTypeString], kFxParameterType_Switch);
}

/*! @abstract A switch parameter instance reports the switch type. */
- (void)testASwitchInstanceReportsTheSwitchType
{
	id<FxGripCustomUIParameterProbe> parameter = [self makeSwitchParameterWithExtra:nil effect:(id)self.effect];

	XCTAssertEqual(parameter.parameterType, FxParameterType_Switch);
}

/*! @abstract A switch registers as a custom parameter with a false boolean default. */
- (void)testASwitchIsCreatedAsACustomParameterCarryingAFalseDefault
{
	XCTAssertTrue([self.switchClass addParameter:[self switchConfigWithExtra:nil] toEffect:(id)self.effect]);

	XCTAssertEqualObjects(self.call[@"method"], @"custom");
	XCTAssertEqualObjects(self.call[@"id"], @(kCustomUITestSwitch));
	XCTAssertEqualObjects([self.call[@"default"] objectForKey:kCustomAPI_BoolKey], @NO);
}

/*! @abstract A switch registers a declared true default. */
- (void)testASwitchCarriesADeclaredTrueDefault
{
	NSDictionary *config = [self switchConfigWithExtra:@{kFxParameterProperty_Default: @YES}];

	XCTAssertTrue([self.switchClass addParameter:config toEffect:(id)self.effect]);

	XCTAssertEqualObjects([self.call[@"default"] objectForKey:kCustomAPI_BoolKey], @YES);
}

/*! @abstract A switch default value is an FxGripDictionary. */
- (void)testASwitchDefaultValueIsAnFxGripDictionary
{
	XCTAssertTrue([self.switchClass addParameter:[self switchConfigWithExtra:nil] toEffect:(id)self.effect]);

	XCTAssertEqualObjects(NSStringFromClass([self.call[@"default"] class]), @"FxGripDictionary");
}

/*! @abstract A switch adds the custom-UI and stateless flags on top of the declared flags. */
- (void)testASwitchForcesTheCustomInterfaceAndStatelessFlagsOnTopOfTheDeclaredFlags
{
	NSDictionary *config = [self switchConfigWithExtra:@{kFxParameterProperty_Flags: @(kFxParameterFlag_HIDDEN)}];

	XCTAssertTrue([self.switchClass addParameter:config toEffect:(id)self.effect]);

	XCTAssertEqualObjects(self.call[@"flags"], @(kFxParameterFlag_HIDDEN
												| kFxParameterFlag_CUSTOM_UI
												| kFxParameterFlag_NOSTATE));
}

/*! @abstract A switch keeps the name its configuration declares. */
- (void)testASwitchKeepsTheNameItsConfigurationDeclares
{
	NSDictionary *config = FxGripParamClassTestConfig(kCustomUITestSwitch, kFxParameterType_Switch, @"Motion Blur", nil);

	XCTAssertTrue([self.switchClass addParameter:config toEffect:(id)self.effect]);

	XCTAssertEqualObjects(self.call[@"name"], @"Motion Blur");
}

/*! @abstract A switch reports a host refusal of the creation call as a failure after one call. */
- (void)testASwitchReportsAHostRefusal
{
	self.effect.apiManager.paramCreateAPIv5.succeeds = NO;

	XCTAssertFalse([self.switchClass addParameter:[self switchConfigWithExtra:nil] toEffect:(id)self.effect]);
	XCTAssertEqual(self.effect.creationCalls.count, (NSUInteger)1);
}

#pragma mark Divider creation

/*! @abstract The divider parameter class reports the divider type and type string. */
- (void)testTheDividerParameterReportsItsTypeAndTypeString
{
	XCTAssertEqual(FxGripDividerParameter.parameterType, FxParameterType_Divider);
	XCTAssertEqualObjects(FxGripDividerParameter.parameterTypeString, kFxParameterType_Divider);
}

/*! @abstract A divider parameter instance reports the divider type. */
- (void)testADividerInstanceReportsTheDividerType
{
	FxGripDividerParameter *parameter = [FxGripDividerParameter.alloc
										 initWithDictionary:[self dividerConfigWithExtra:nil]
										 effect:(id)self.effect];

	XCTAssertEqual(parameter.parameterType, FxParameterType_Divider);
}

/*! @abstract A divider registers unnamed as a custom parameter with an FxGripDividerData default. */
- (void)testADividerIsCreatedUnnamedAsACustomParameter
{
	XCTAssertTrue([FxGripDividerParameter addParameter:[self dividerConfigWithExtra:nil] toEffect:(id)self.effect]);

	XCTAssertEqualObjects(self.call[@"method"], @"custom");
	XCTAssertEqualObjects(self.call[@"name"], @"", @"a divider draws no label of its own");
	XCTAssertEqualObjects(self.call[@"id"], @(kCustomUITestDivider));
	XCTAssertEqualObjects(NSStringFromClass([self.call[@"default"] class]), @"FxGripDividerData");
}

/*! @abstract A divider applies the declared percent width to its data default. */
- (void)testADividerAppliesTheDeclaredWidth
{
	NSDictionary *config = [self dividerConfigWithExtra:@{kFxParameterProperty_Default: @{@"width": @0.5}}];

	XCTAssertTrue([FxGripDividerParameter addParameter:config toEffect:(id)self.effect]);

	XCTAssertEqualObjects([self.call[@"default"] valueForKey:@"percentWidth"], @0.5);
}

/*! @abstract A divider ignores a non-record default and keeps its standard data geometry. */
- (void)testADividerIgnoresANonRecordDefault
{
	NSDictionary *config = [self dividerConfigWithExtra:@{kFxParameterProperty_Default: @"wide"}];

	XCTAssertTrue([FxGripDividerParameter addParameter:config toEffect:(id)self.effect]);

	XCTAssertEqualObjects(NSStringFromClass([self.call[@"default"] class]), @"FxGripDividerData");
	XCTAssertEqualObjects([self.call[@"default"] valueForKey:@"percentWidth"], @(phi - 1.0));
	XCTAssertEqualObjects([self.call[@"default"] valueForKey:@"marginTop"], @7);
	XCTAssertEqualObjects([self.call[@"default"] valueForKey:@"marginBottom"], @12);
}

/*! @abstract A divider forces the full-width static custom-UI stateless flags on top of the declared flags. */
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

/*! @abstract A divider reports a host refusal of the creation call as a failure after one call. */
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

/*! @abstract The effect resolves the switch type string and type to the switch parameter class. */
- (void)testTheEffectResolvesTheSwitchTypeToTheSwitchParameterClass
{
	FxGripCustomUITestHostEffect *effect = [FxGripCustomUITestHostEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	XCTAssertNotNil(effect);

	XCTAssertEqualObjects([effect parameterClassWithTypeString:kFxParameterType_Switch], FxGripCustomUITestSwitchClass());
	XCTAssertEqualObjects([effect parameterClassWithType:FxParameterType_Switch], FxGripCustomUITestSwitchClass());
	XCTAssertEqual([effect parameterTypeWithString:kFxParameterType_Switch], FxParameterType_Switch);
}

/*! @abstract The effect resolves the divider type string and type to the divider parameter class. */
- (void)testTheEffectResolvesTheDividerTypeToTheDividerParameterClass
{
	FxGripCustomUITestHostEffect *effect = [FxGripCustomUITestHostEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	XCTAssertNotNil(effect);

	XCTAssertEqualObjects([effect parameterClassWithTypeString:kFxParameterType_Divider], FxGripDividerParameter.class);
	XCTAssertEqualObjects([effect parameterClassWithType:FxParameterType_Divider], FxGripDividerParameter.class);
	XCTAssertEqual([effect parameterTypeWithString:kFxParameterType_Divider], FxParameterType_Divider);
}

#pragma mark Custom value classes

/*! @abstract The switch declares the inherited dictionary value classes, including FxGripDictionary, NSNumber, and FxTime. */
- (void)testTheSwitchDeclaresTheDictionaryValueClasses
{
	NSSet<Class> *classes = [self.switchClass customValueClasses];

	XCTAssertTrue([classes containsObject:FxGripDictionary.class]);
	XCTAssertTrue([classes containsObject:NSNumber.class]);
	XCTAssertTrue([classes containsObject:NSClassFromString(@"FxTime")],
				  @"the inherited dictionary list carries the time value class");
}

/*! @abstract The divider declares only its own FxGripDividerData value class. */
- (void)testTheDividerDeclaresOnlyItsOwnDataClass
{
	Class dataClass = NSClassFromString(@"FxGripDividerData");
	XCTAssertNotNil(dataClass);

	XCTAssertEqualObjects([FxGripDividerParameter customValueClasses], [NSSet setWithObject:dataClass]);
}

/*! @abstract A parameter class with no custom value declares no value classes. */
- (void)testAParameterClassWithoutACustomValueDeclaresNoClasses
{
	XCTAssertNil([FxGripFloatParameter customValueClasses]);
}

#pragma mark Effect-side value class resolution

/*! @abstract The effect stores the custom-UI configuration records keyed by parameter type. */
- (void)testTheEffectStoresTheCustomUIConfigurationRecords
{
	FxGripCustomUITestHostEffect *effect = [self makeConfiguredEffect];

	XCTAssertEqualObjects([effect configurationForParameter:kCustomUITestSwitch][kFxParameterProperty_Type],
						  kFxParameterType_Switch);
	XCTAssertEqualObjects([effect configurationForParameter:kCustomUITestDivider][kFxParameterProperty_Type],
						  kFxParameterType_Divider);
}

/*! @abstract The effect resolves a configured switch parameter's value classes to the switch's declared dictionary classes. */
- (void)testASwitchParameterResolvesTheDictionaryValueClasses
{
	FxGripCustomUITestHostEffect *effect = [self makeConfiguredEffect];

	NSSet<Class> *classes = [effect classesForCustomParameterID:kCustomUITestSwitch];

	XCTAssertEqualObjects(classes, [self.switchClass customValueClasses]);
	XCTAssertTrue([classes containsObject:FxGripDictionary.class]);
}

/*! @abstract The effect resolves a configured divider parameter's value classes to its own data class. */
- (void)testADividerParameterResolvesItsOwnDataClass
{
	FxGripCustomUITestHostEffect *effect = [self makeConfiguredEffect];

	XCTAssertEqualObjects([effect classesForCustomParameterID:kCustomUITestDivider],
						  [NSSet setWithObject:NSClassFromString(@"FxGripDividerData")]);
}

/*! @abstract The instance-meta parameter keeps its own value classes, including FxGripMetaManager and not the divider data. */
- (void)testTheInstanceMetaParameterKeepsItsOwnValueClasses
{
	FxGripCustomUITestHostEffect *effect = [self makeConfiguredEffect];

	NSSet<Class> *classes = [effect classesForCustomParameterID:kFxParameterId_InstanceMeta];

	XCTAssertTrue([classes containsObject:FxGripMetaManager.class]);
	XCTAssertFalse([classes containsObject:NSClassFromString(@"FxGripDividerData")]);
}

/*! @abstract The effect resolves no value classes for a configured parameter that carries no custom value. */
- (void)testAParameterWithoutACustomValueResolvesNoClasses
{
	FxGripCustomUITestHostEffect *effect = [self makeConfiguredEffect];

	XCTAssertNil([effect classesForCustomParameterID:kCustomUITestFloat]);
}

/*! @abstract The effect resolves no value classes for an unconfigured parameter ID. */
- (void)testAnUnconfiguredParameterResolvesNoClasses
{
	FxGripCustomUITestHostEffect *effect = [self makeConfiguredEffect];

	XCTAssertNil([effect classesForCustomParameterID:kCustomUITestUnconfigured]);
}

#pragma mark Parameter views

/*! @abstract A switch parameter builds a switch view carrying the parameter ID and effect. */
- (void)testASwitchParameterBuildsASwitchViewCarryingItsIdentity
{
	id<FxGripCustomUIParameterProbe> parameter = [self makeSwitchParameterWithExtra:nil effect:(id)self.effect];
	XCTAssertNotNil(parameter);

	id<FxGripCustomUISwitchViewProbe> view = (id<FxGripCustomUISwitchViewProbe>)[parameter newParameterView];

	XCTAssertTrue([view isKindOfClass:FxGripCustomUITestSwitchViewClass()]);
	XCTAssertEqual(view.parameterID, kCustomUITestSwitch);
	XCTAssertEqualObjects(view.parameterEffect, self.effect);
}

/*! @abstract A switch view starts in the off state when no true default is declared. */
- (void)testASwitchParameterViewStartsOffWithoutADeclaredDefault
{
	id<FxGripCustomUIParameterProbe> parameter = [self makeSwitchParameterWithExtra:nil effect:(id)self.effect];

	id<FxGripCustomUISwitchViewProbe> view = (id<FxGripCustomUISwitchViewProbe>)[parameter newParameterView];

	XCTAssertEqual(view.state, NSControlStateValueOff);
}

/*! @abstract A switch view starts in the on state for a declared true default. */
- (void)testASwitchParameterViewStartsOnForADeclaredTrueDefault
{
	id<FxGripCustomUIParameterProbe> parameter =
		[self makeSwitchParameterWithExtra:@{kFxParameterProperty_Default: @YES} effect:(id)self.effect];

	id<FxGripCustomUISwitchViewProbe> view = (id<FxGripCustomUISwitchViewProbe>)[parameter newParameterView];

	XCTAssertEqual(view.state, NSControlStateValueOn);
}

/*! @abstract A divider parameter attaches its box and returns a sizing container that wraps it. */
- (void)testADividerParameterAttachesItsBoxAndReturnsTheSizingContainer
{
	FxGripDividerParameter *parameter = [FxGripDividerParameter.alloc
										 initWithDictionary:[self dividerConfigWithExtra:nil]
										 effect:(id)self.effect];
	XCTAssertNotNil(parameter);

	NSView *container = [parameter newParameterView];
	NSView *box = parameter.customView;

	XCTAssertTrue([box isKindOfClass:NSClassFromString(@"FxGripDividerBox")]);
	XCTAssertNotEqualObjects(container, box, @"the container wraps the box rather than being it");
	XCTAssertTrue([container.subviews containsObject:box]);
}

/*!
	DEFECT: FxGripDividerBox reads a pushed dictionary under "percentWidth", "marginTop" and
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

/*! @abstract The view host returns and attaches a switch view for a switch parameter. */
- (void)testTheViewHostReturnsAndAttachesASwitchView
{
	FxGripCustomUITestViewHostEffect *effect = [FxGripCustomUITestViewHostEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	id<FxGripCustomUIParameterProbe> parameter = [self makeSwitchParameterWithExtra:nil effect:(id)effect];
	effect.stagedParameters[@(kCustomUITestSwitch)] = parameter;

	NSView *view = [effect createViewForParameterID:kCustomUITestSwitch];

	XCTAssertTrue([view isKindOfClass:FxGripCustomUITestSwitchViewClass()]);
	XCTAssertEqualObjects(parameter.customView, view);
}

/*! @abstract The view host returns the divider's container and leaves the parameter's attached box in place. */
- (void)testTheViewHostReturnsTheDividerContainerAndLeavesTheAttachedBox
{
	FxGripCustomUITestViewHostEffect *effect = [FxGripCustomUITestViewHostEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	FxGripDividerParameter *parameter = [FxGripDividerParameter.alloc
										 initWithDictionary:[self dividerConfigWithExtra:nil]
										 effect:(id)effect];
	effect.stagedParameters[@(kCustomUITestDivider)] = parameter;

	NSView *container = [effect createViewForParameterID:kCustomUITestDivider];
	NSView *box = parameter.customView;

	XCTAssertTrue([box isKindOfClass:NSClassFromString(@"FxGripDividerBox")],
				  @"the parameter attaches its box, so the host leaves the attachment alone");
	XCTAssertNotEqualObjects(container, box);
	XCTAssertTrue([container.subviews containsObject:box]);
}

/*! @abstract The view host returns nothing for a parameter class that vends no view. */
- (void)testTheViewHostReturnsNothingForAParameterClassWithoutAView
{
	FxGripCustomUITestViewHostEffect *effect = [FxGripCustomUITestViewHostEffect.alloc initWithAPIManager:(id _Nonnull)nil];
	NSDictionary *config = FxGripParamClassTestConfig(kCustomUITestFloat, kFxParameterType_Float, @"Amount", nil);
	FxGripFloatParameter *parameter = [FxGripFloatParameter.alloc initWithDictionary:config effect:(id)effect];
	effect.stagedParameters[@(kCustomUITestFloat)] = parameter;

	XCTAssertNil([effect createViewForParameterID:kCustomUITestFloat]);
	XCTAssertNil(parameter.customView);
}

/*! @abstract The view host returns nothing for an unknown parameter ID. */
- (void)testTheViewHostReturnsNothingForAnUnknownParameter
{
	FxGripCustomUITestViewHostEffect *effect = [FxGripCustomUITestViewHostEffect.alloc initWithAPIManager:(id _Nonnull)nil];

	XCTAssertNil([effect createViewForParameterID:kCustomUITestUnconfigured]);
}

#pragma mark View host against the effect's own parameter registry

/*! @abstract A parameter-add notification registers a constructed parameter of the right class in the effect. */
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

/*! @abstract The view host builds the view for a constructed parameter once the parameter cache is repopulated. */
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

/*! @abstract The switch view turns on for a dictionary carrying a true boolean value. */
- (void)testTheSwitchViewTakesItsStateFromABoolCarryingDictionary
{
	id<FxGripCustomUISwitchViewProbe> view = [self makeSwitchView];

	[view updateFromCustomData:[FxGripDictionary dictionaryWithDictionary:@{kCustomAPI_BoolKey: @YES}]];

	XCTAssertEqual(view.state, NSControlStateValueOn);
}

/*! @abstract The switch view turns off for a dictionary carrying a false boolean value. */
- (void)testTheSwitchViewClearsItsStateForAFalseDictionary
{
	id<FxGripCustomUISwitchViewProbe> view = [self makeSwitchView];
	view.state = NSControlStateValueOn;

	[view updateFromCustomData:[FxGripDictionary dictionaryWithDictionary:@{kCustomAPI_BoolKey: @NO}]];

	XCTAssertEqual(view.state, NSControlStateValueOff);
}

/*! @abstract The switch view keeps its state for a value of another class, a plain dictionary, or nil. */
- (void)testTheSwitchViewIgnoresAValueOfAnotherClass
{
	id<FxGripCustomUISwitchViewProbe> view = [self makeSwitchView];
	view.state = NSControlStateValueOn;

	[view updateFromCustomData:@"off"];
	[view updateFromCustomData:@{kCustomAPI_BoolKey: @NO}];
	[view updateFromCustomData:nil];

	XCTAssertEqual(view.state, NSControlStateValueOn);
}

/*! @abstract The switch view keeps its state for a dictionary that lacks the boolean key. */
- (void)testTheSwitchViewIgnoresADictionaryWithoutTheBooleanKey
{
	id<FxGripCustomUISwitchViewProbe> view = [self makeSwitchView];
	view.state = NSControlStateValueOn;

	[view updateFromCustomData:[FxGripDictionary dictionaryWithDictionary:@{@"tint": @"blue"}]];

	XCTAssertEqual(view.state, NSControlStateValueOn);
}

#pragma mark Switch view toggle

/*! @abstract Toggling the switch writes a custom dictionary carrying the new boolean state to the parameter at the context time. */
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

/*! @abstract Toggling the switch off writes a false boolean value. */
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

/*! @abstract Toggling the switch reads the current parameter value at the out-of-band context time. */
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

/*! @abstract Toggling the switch writes the new boolean while keeping the other keys of the parameter value. */
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

/*! @abstract Toggling the switch unlocks a locked parameter value before writing the new state. */
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

/*! @abstract Toggling the switch brackets the write in a single start and end of the host action context. */
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

/*! @abstract Toggling a switch view with no effect writes nothing, reads nothing, and opens no action context. */
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

/*! @abstract The status parameter class reports the status type and type string. */
- (void)testTheStatusParameterReportsItsTypeAndTypeString
{
	XCTAssertEqual([self.statusClass parameterType], FxParameterType_Status);
	XCTAssertEqualObjects([self.statusClass parameterTypeString], kFxParameterType_Status);
}

/*! @abstract A status registers as a custom parameter with a default carrying a zero state and empty text. */
- (void)testAStatusIsCreatedAsACustomParameterCarryingAStateAndTextDefault
{
	XCTAssertTrue([self.statusClass addParameter:[self statusConfigWithExtra:nil] toEffect:(id)self.effect]);

	XCTAssertEqualObjects(self.call[@"method"], @"custom");
	XCTAssertEqualObjects(self.call[@"id"], @(kCustomUITestStatus));
	XCTAssertEqualObjects(NSStringFromClass([self.call[@"default"] class]), @"FxGripDictionary");
	XCTAssertEqualObjects([self.call[@"default"] objectForKey:kCustomAPI_IntKey], @0);
	XCTAssertEqualObjects([self.call[@"default"] objectForKey:kCustomAPI_StringKey], @"");
}

/*! @abstract A status registers a declared state and text default. */
- (void)testAStatusCarriesADeclaredStateAndTextDefault
{
	NSDictionary *config = [self statusConfigWithExtra:@{kFxParameterProperty_Default:
		@{kCustomAPI_IntKey: @3, kCustomAPI_StringKey: @"Error"}}];

	XCTAssertTrue([self.statusClass addParameter:config toEffect:(id)self.effect]);

	XCTAssertEqualObjects([self.call[@"default"] objectForKey:kCustomAPI_IntKey], @3);
	XCTAssertEqualObjects([self.call[@"default"] objectForKey:kCustomAPI_StringKey], @"Error");
}

/*! @abstract A status forces the custom-UI and stateless flags. */
- (void)testAStatusForcesTheCustomInterfaceAndStatelessFlags
{
	XCTAssertTrue([self.statusClass addParameter:[self statusConfigWithExtra:nil] toEffect:(id)self.effect]);

	NSInteger flags = [self.call[@"flags"] integerValue];
	XCTAssertTrue((flags & kFxParameterFlag_CUSTOM_UI) != 0);
	XCTAssertTrue((flags & kFxParameterFlag_NOSTATE) != 0);
}

/*! @abstract A status view builds and accepts an FxGripDictionary value and a plain dictionary without throwing. */
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

/*! @abstract The progress parameter class reports the progress type and type string. */
- (void)testTheProgressParameterReportsItsTypeAndTypeString
{
	XCTAssertEqual([self.progressClass parameterType], FxParameterType_Progress);
	XCTAssertEqualObjects([self.progressClass parameterTypeString], kFxParameterType_Progress);
}

/*! @abstract A progress registers as a custom parameter with a default carrying a zero fraction, state, and empty text. */
- (void)testAProgressIsCreatedAsACustomParameterCarryingAFractionStateAndTextDefault
{
	XCTAssertTrue([self.progressClass addParameter:[self progressConfigWithExtra:nil] toEffect:(id)self.effect]);

	XCTAssertEqualObjects(self.call[@"id"], @(kCustomUITestProgress));
	XCTAssertEqualObjects(NSStringFromClass([self.call[@"default"] class]), @"FxGripDictionary");
	XCTAssertEqualObjects([self.call[@"default"] objectForKey:kCustomAPI_FloatKey], @0.0);
	XCTAssertEqualObjects([self.call[@"default"] objectForKey:kCustomAPI_IntKey], @0);
	XCTAssertEqualObjects([self.call[@"default"] objectForKey:kCustomAPI_StringKey], @"");
}

/*! @abstract A progress registers a declared fraction default. */
- (void)testAProgressCarriesADeclaredFractionDefault
{
	NSDictionary *config = [self progressConfigWithExtra:@{kFxParameterProperty_Default:
		@{kCustomAPI_FloatKey: @0.5}}];

	XCTAssertTrue([self.progressClass addParameter:config toEffect:(id)self.effect]);

	XCTAssertEqualObjects([self.call[@"default"] objectForKey:kCustomAPI_FloatKey], @0.5);
}

/*! @abstract A progress view builds and accepts determinate, indeterminate, and complete fractions without throwing. */
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

/*! @abstract The section parameter class reports the section type and type string. */
- (void)testTheSectionParameterReportsItsTypeAndTypeString
{
	XCTAssertEqual([self.sectionClass parameterType], FxParameterType_Section);
	XCTAssertEqualObjects([self.sectionClass parameterTypeString], kFxParameterType_Section);
}

/*! @abstract A section registers unnamed as a full-width static custom parameter with an FxGripSectionData default. */
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

/*! @abstract A section with no declared title falls back to the parameter name. */
- (void)testASectionWithoutADeclaredTitleFallsBackToTheParameterName
{
	XCTAssertTrue([self.sectionClass addParameter:[self sectionConfigWithExtra:nil] toEffect:(id)self.effect]);

	XCTAssertEqualObjects([self.call[@"default"] objectForKey:kCustomAPI_StringKey], @"Adjustments");
}

/*! @abstract A section keeps a declared title over the parameter name. */
- (void)testASectionKeepsADeclaredTitleOverTheParameterName
{
	NSDictionary *config = [self sectionConfigWithExtra:@{kFxParameterProperty_Default:
		@{kCustomAPI_StringKey: @"Color"}}];

	XCTAssertTrue([self.sectionClass addParameter:config toEffect:(id)self.effect]);

	XCTAssertEqualObjects([self.call[@"default"] objectForKey:kCustomAPI_StringKey], @"Color");
}

/*! @abstract A section view builds from a styled configuration and accepts a plain dictionary without throwing. */
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

/*! @abstract The banner parameter class reports the banner type and type string. */
- (void)testTheBannerParameterReportsItsTypeAndTypeString
{
	XCTAssertEqual([self.bannerClass parameterType], FxParameterType_Banner);
	XCTAssertEqualObjects([self.bannerClass parameterTypeString], kFxParameterType_Banner);
}

/*! @abstract A banner registers unnamed as a full-width static custom parameter with an FxGripDictionary default. */
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

/*! @abstract A banner with no declared title falls back to the parameter name. */
- (void)testABannerWithoutADeclaredTitleFallsBackToTheParameterName
{
	XCTAssertTrue([self.bannerClass addParameter:[self bannerConfigWithExtra:nil] toEffect:(id)self.effect]);

	XCTAssertEqualObjects([self.call[@"default"] objectForKey:kCustomAPI_StringKey], @"Notice");
}

/*! @abstract A banner view builds from a title, subtitle, and colors and accepts an updated title without throwing. */
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

/*! @abstract An image banner takes no title fallback and keeps its declared image name. */
- (void)testAnImageBannerTakesNoTitleFallbackSoTheGraphicCanStandAlone
{
	NSDictionary *config = [self bannerConfigWithExtra:@{kFxParameterProperty_Default:
		@{kFxGripBannerKey_ImageName: @"NSApplicationIcon"}}];

	XCTAssertTrue([self.bannerClass addParameter:config toEffect:(id)self.effect]);

	XCTAssertNil([self.call[@"default"] objectForKey:kCustomAPI_StringKey],
				 @"an image banner is not given the parameter name as a title");
	XCTAssertEqualObjects([self.call[@"default"] objectForKey:kFxGripBannerKey_ImageName], @"NSApplicationIcon");
}

/*! @abstract A banner view builds from image, template, link, and action-button keys and accepts an update that clears the link without throwing. */
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

/*! @abstract The capsule parameter class reports the capsule type and type string. */
- (void)testTheCapsuleParameterReportsItsTypeAndTypeString
{
	XCTAssertEqual([self.capsuleClass parameterType], FxParameterType_Capsule);
	XCTAssertEqualObjects([self.capsuleClass parameterTypeString], kFxParameterType_Capsule);
}

/*! @abstract A capsule registers as a static custom parameter that keeps its row label and is not full width. */
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

/*! @abstract A capsule view builds from text, colors, and a corner radius and accepts an update without throwing. */
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

/*! @abstract The web-view parameter class reports the web-view type and type string. */
- (void)testTheWebViewParameterReportsItsTypeAndTypeString
{
	XCTAssertEqual([self.webViewClass parameterType], FxParameterType_WebView);
	XCTAssertEqualObjects([self.webViewClass parameterTypeString], kFxParameterType_WebView);
}

/*! @abstract A web view registers unnamed as a full-width static custom parameter with an FxGripDictionary default. */
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

/*! @abstract A web view with no declared whitelist defaults to all sites. */
- (void)testAWebViewWithoutADeclaredWhitelistDefaultsToAllSites
{
	XCTAssertTrue([self.webViewClass addParameter:[self webViewConfigWithExtra:nil] toEffect:(id)self.effect]);

	XCTAssertEqualObjects([self.call[@"default"] objectForKey:kFxGripWebViewKey_Whitelist], (@[@"*"]));
}

/*! @abstract A web view keeps a declared whitelist. */
- (void)testAWebViewKeepsADeclaredWhitelist
{
	NSArray *list = @[@"apple.com", @"developer.apple.com"];
	NSDictionary *config = [self webViewConfigWithExtra:@{kFxParameterProperty_Default:
		@{kFxGripWebViewKey_URL: @"https://developer.apple.com/", kFxGripWebViewKey_Whitelist: list}}];

	XCTAssertTrue([self.webViewClass addParameter:config toEffect:(id)self.effect]);

	XCTAssertEqualObjects([self.call[@"default"] objectForKey:kFxGripWebViewKey_Whitelist], list);
}

/*! @abstract A web-view view builds and accepts a URL update off-window without starting a web process. */
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

/*! @abstract The video parameter class reports the video-view type and type string. */
- (void)testTheVideoParameterReportsItsTypeAndTypeString
{
	XCTAssertEqual([self.videoClass parameterType], FxParameterType_VideoView);
	XCTAssertEqualObjects([self.videoClass parameterTypeString], kFxParameterType_VideoView);
}

/*! @abstract A video registers unnamed as a full-width static custom parameter with an FxGripDictionary default. */
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

/*! @abstract A video with no declared whitelist defaults to the known video domains. */
- (void)testAVideoWithoutADeclaredWhitelistDefaultsToTheVideoDomains
{
	XCTAssertTrue([self.videoClass addParameter:[self videoConfigWithExtra:nil] toEffect:(id)self.effect]);

	NSArray *whitelist = [self.call[@"default"] objectForKey:kFxGripVideoKey_Whitelist];
	XCTAssertTrue([whitelist containsObject:@"youtube.com"]);
	XCTAssertTrue([whitelist containsObject:@"rumble.com"]);
}

/*! @abstract A video view builds and accepts a media update off-window without starting a player. */
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

/*! @abstract The random parameter class reports the random type and type string. */
- (void)testTheRandomParameterReportsItsTypeAndTypeString
{
	XCTAssertEqual([self.randomClass parameterType], FxParameterType_Random);
	XCTAssertEqualObjects([self.randomClass parameterTypeString], kFxParameterType_Random);
}

/*! @abstract A random registers as a custom parameter defaulting to zero with the default min and max range. */
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

/*! @abstract A random registers a declared value, min, max, and step. */
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

/*! @abstract A random parameter builds a random view carrying the parameter ID and effect. */
- (void)testTheRandomViewCarriesItsIdentity
{
	id<FxGripCustomUIParameterProbe> parameter = [(id<FxGripCustomUIParameterProbe>)[FxGripCustomUITestRandomClass() alloc]
		initWithDictionary:[self randomConfigWithExtra:nil] effect:(id)self.effect];
	id<FxGripCustomUIRandomViewProbe> view = (id<FxGripCustomUIRandomViewProbe>)[parameter newParameterView];

	XCTAssertTrue([view isKindOfClass:FxGripCustomUITestRandomViewClass()]);
	XCTAssertEqual(view.parameterID, kCustomUITestRandom);
	XCTAssertEqualObjects(view.parameterEffect, self.effect);
}

/*! @abstract Reloading the random view writes the drawn value into the parameter as a custom dictionary. */
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

/*! @abstract Repeated reloads of the random view draw values within the configured range. */
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
