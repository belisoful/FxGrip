/*!
	@file       FxGripFxFactoryTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripFxFactoryTests
	@abstract   Unit tests for the FxGripFxFactory extension's licensing, contact form, watermark, and settings behavior.
	@discussion Introduced in FxGrip 0.1.0. Mock subclasses override the FxFactory SDK seams so the licensing, contact-form, watermark-render, and handler-registration logic runs end to end without a live FxFactory installation. The tests cover the ported notification dispatch selectors, the inactive-configuration and missing-payload guards, the contact-form recipient guard, the debug license override, the watermark render decision, handler re-registration teardown, a settings-object watermark opt-out, and cache invalidation on a product UUID change.
*/

#import <XCTest/XCTest.h>
#import <dlfcn.h>
#import <Metal/Metal.h>
#import <CoreVideo/CoreVideo.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripParameter.h>
#import <FxGrip/FxGripParameterFlags.h>
#import <FxGrip/FxGripExtension.h>
#import <FxGrip/FxGripTileableEffect.h>
#import <FxGrip/FxGripTileableEffect+Extensions.h>
#import <FxGrip/FxGripTileableEffect+Notifications.h>
#import "FxPlugStub.h"

// The configuration keys the extension reads. They are #defines in the SDK-importing
// FxGripFxFactory.h, so the test mirrors the ones it drives.
#define kPropertiesFxFactoryActive @"FxFactoryActive"
#define kPropertiesFxFactoryPluginUUID @"FxFactoryPluginUUID"
#define kPropertiesFxFactoryPluginVersion @"FxFactoryPluginVersion"

/*! The FxFactory version triple, laid out as the SDK's FxFactoryVersion, which the test target
	does not link. */
typedef struct {
	NSUInteger major;
	NSUInteger minor;
	NSUInteger patch;
} FxGripFxFactoryTestVersion;

/*! The FxFactory licensing statuses the seams report; the SDK enum is not linked here. */
static const NSUInteger FxGripFxFactoryTestStatusUnlicensed = 2;
static const NSUInteger FxGripFxFactoryTestStatusLicensed = 3;

/*!
	The hard-coded settings hooks a plugin implements. The protocol mirrors the SDK-importing
	FxGripFxFactorySettings declaration; the runtime matches protocols by name, so an object
	adopting this one satisfies the extension's conformance test.
*/
@protocol FxGripFxFactorySettings <NSObject>
@optional
- (BOOL)fxFactoryActive;
- (nonnull NSString *)fxFactoryProductUUID;
- (nonnull NSString *)fxFactoryProductVersion;
- (BOOL)fxFactoryWaterMarkUnlicensed;
- (BOOL)fxFactoryShowBuyButton;
- (BOOL)fxFactoryShowProductButton;
- (BOOL)fxFactoryAutoChecking;
@end

// FxGripFxFactory.h is not a public framework header (it imports the third-party FxFactory
// SDK), so the surface under test is redeclared locally. The implementation comes from the
// linked framework.
@interface FxGripFxFactory : NSObject
- (instancetype)init;
- (void)extAddParameters:(nonnull NSNotification *)notification;
- (void)extParameterChanged:(nonnull NSNotification *)notification;
- (void)extAddedToDocument:(nonnull NSNotification *)notification;
- (void)extRenderDestinationImage:(nonnull NSNotification *)notification;
- (BOOL)showContactForm:(nullable NSString *)recipient subject:(nullable NSString *)subject message:(nullable NSString *)message;
- (BOOL)showContactForm:(nullable NSString *)subject message:(nullable NSString *)message;
- (BOOL)pluginIsLicensed;
- (void)setFxFactoryPluginUUID:(nonnull NSString *)uuid;
- (BOOL)extLoadWithEffect:(nonnull id)effect;
- (BOOL)fxFactoryActive;
- (void)registerLicenseHandler:(nullable NSString *)productUUID;
- (void)unregisterLicenseHandler;
- (void)showProductUpdates;
- (void)setBoolValue:(BOOL)value;
- (BOOL)boolValue;
- (void)setFxFactorySettingsObject:(nullable id)settingsObject;
- (BOOL)fxFactoryHasWaterMarkUnlicensed;
- (void)extParameterChanged:(nonnull NSNotification *)notification;
// Overridable FxFactory SDK seams.
- (BOOL)factoryInstalled;
- (NSUInteger)factoryLicensingStatusForProduct:(nullable NSString *)productUUID;
- (nullable id)factoryRegisterLicensingHandlerForProduct:(nullable NSString *)productUUID handler:(nonnull id)handler;
- (void)factoryUnregisterLicensingHandler:(nullable id)handle forProduct:(nullable NSString *)productUUID;
- (BOOL)factoryContactFormAvailable;
- (BOOL)factoryShowContactFormToRecipient:(nullable NSString *)recipient subject:(nullable NSString *)subject message:(nullable NSString *)message;
- (BOOL)fxFactoryWaterMarkUnlicensed;
- (BOOL)renderWatermarkOntoImage:(nullable id)destinationImage error:(NSError *_Nullable *_Nullable)outError;

// The remainder of the surface these tests drive.
- (FxParameterId)parameterID;
- (nullable id)parameterForDictionary:(nonnull NSDictionary *)data;
- (BOOL)fxFactoryRegression;
- (nonnull id)fxFactoryRegressionBundle;
- (FxGripFxFactoryTestVersion)fxFactoryVersion;
- (FxGripFxFactoryTestVersion)factoryVersion;
- (BOOL)fxFactoryIsInstalled;
- (nullable id)fxFactorySettingsObject;
- (void)setCachedLicenseStatus:(nullable NSNumber *)status;
- (NSUInteger)pluginLicenseStatus;
- (void)showProductUpdates:(BOOL)forceCheck handler:(nullable void (^)(NSDictionary *_Nonnull))handler;
- (void)showProductUpdates:(nullable void (^)(NSDictionary *_Nonnull))handler;
- (void)factoryShowProductUpdatesForProduct:(nullable NSString *)productUUID
									version:(nullable NSString *)version
									  force:(BOOL)force
									handler:(nullable void (^)(NSDictionary *_Nonnull))handler;
- (BOOL)factoryUpdateCheckingEnabledForProduct:(nullable NSString *)productUUID;
- (void)factorySetUpdateCheckingEnabled:(BOOL)enabled forProduct:(nullable NSString *)productUUID;
- (BOOL)factoryPerformLicensingAction:(NSUInteger)action forProduct:(nullable NSString *)productUUID;
- (BOOL)pluginIsUpdateChecking;
- (void)setPluginIsUpdateChecking:(BOOL)enabled;
- (BOOL)showFxFactoryProduct;
- (BOOL)showFxFactoryBuyPlugin;
- (nullable NSString *)fxFactoryPluginUUID;
- (nullable NSString *)fxFactoryPluginVersion;
- (void)setFxFactoryPluginVersion:(nonnull NSString *)version;
- (void)clearFxFactoryPluginUUID;
- (void)clearFxFactoryPluginVersion;
- (BOOL)fxFactoryHasActive;
- (BOOL)fxFactoryHasPluginProduct;
- (BOOL)fxFactoryHasShowBuyButton;
- (BOOL)fxFactoryHasShowProductButton;
- (BOOL)fxFactoryHasAutoChecking;
- (void)setFxFactoryActive:(BOOL)active;
- (void)setFxFactoryWaterMarkUnlicensed:(BOOL)active;
- (BOOL)fxFactoryShowBuyButton;
- (void)setFxFactoryShowBuyButton:(BOOL)active;
- (BOOL)fxFactoryShowProductButton;
- (void)setFxFactoryShowProductButton:(BOOL)active;
- (BOOL)fxFactoryAutoChecking;
- (void)setFxFactoryAutoChecking:(BOOL)active;
- (FxParameterType)extParameterTypeForString:(nullable NSString *)typeString;
- (nullable Class)extParameterClassForType:(FxParameterType)type;
@end

/*! The typed accessors the extension adds to an FxFactory response dictionary. */
@interface NSDictionary (FxGripFxFactoryTestResponse)
- (BOOL)fxFactoryUpdateCheckingEnabled;
- (BOOL)fxFactoryUpdateCheckingPostponed;
- (BOOL)fxFactoryUpdateCheckingNewVersionFound;
- (nullable NSError *)fxFactoryUpdateCheckingError;
- (nullable NSDictionary *)fxFactoryUpdateCheckingProductInfo;
- (nullable NSString *)fxFactoryProductName;
- (nullable NSString *)fxFactoryProductLatestVersion;
- (nullable NSString *)fxFactoryProductLatestVersionRequiredOSVersion;
- (nullable NSString *)fxFactoryProductLatestVersionRequiredFxFactoryVersion;
- (BOOL)fxFactoryProductIsDiscontinued;
- (float)fxFactoryProductPriceInUSD;
@end

/*! The effect-side FxFactory hooks and accessors, declared in the SDK-importing header. */
@interface FxGripTileableEffect (FxGripFxFactoryTestHooks)
- (void)setFxFactoryLicenseState:(BOOL)licensed;
- (void)onFxFactoryRegisterLicensingStatusChange:(NSUInteger)status;
- (void)onFxFactoryShowProductUpdates:(nonnull NSDictionary *)response;
- (nullable id)fxFactory;
- (nullable NSString *)fxFactoryPluginUUID;
- (nullable NSString *)fxFactoryPluginVersion;
- (BOOL)fxFactoryPluginLicensed;
- (nullable id)newFxFactoryExtension;
@end

/*!
	Resolves one of the FxFactory SDK's weak-linked response keys from the loaded framework.
	The test target does not link FxFactory, so the constants are read by symbol name; nil when
	FxFactory is not installed.
*/
static NSString *FxGripFxFactoryTestResponseKey(const char *symbol)
{
	NSString *const *address = (NSString *const *)dlsym(RTLD_DEFAULT, symbol);
	return address ? *address : nil;
}

// A mock end that overrides the SDK seams, so the licensing and contact-form logic runs end
// to end without a live FxFactory installation. FxFactoryLicensingStatus is an NSUInteger
// enum; ProductUnlicensed is 2 and ProductLicensed is 3.
@interface FxGripFxFactoryMock : FxGripFxFactory
@property (nonatomic, assign) NSUInteger mockStatus;
@property (nonatomic, strong) NSMutableArray<NSString *> *contactRecipients;
@end

@implementation FxGripFxFactoryMock
- (instancetype)init
{
	self = [super init];
	if (self) {
		_mockStatus = 2;
		_contactRecipients = NSMutableArray.new;
	}
	return self;
}
- (BOOL)factoryInstalled { return YES; }
- (NSUInteger)factoryLicensingStatusForProduct:(NSString *)productUUID { return self.mockStatus; }
- (BOOL)factoryContactFormAvailable { return YES; }
- (BOOL)factoryShowContactFormToRecipient:(NSString *)recipient subject:(NSString *)subject message:(NSString *)message
{
	[self.contactRecipients addObject:recipient ?: @""];
	return YES;
}
@end

/*! A parameter stand-in the extension's property accessors read and write through the effect
	subscript. */
@interface FxGripFxFactoryStubParameter : NSObject
@property (nonatomic, assign) BOOL boolValue;
@property (nonatomic, copy) NSString *stringValue;
@property (nonatomic, copy) NSString *parameterName;
@property (nonatomic, assign) NSUInteger boolWriteCount;
@end

@implementation FxGripFxFactoryStubParameter

- (void)setBoolValue:(BOOL)boolValue
{
	_boolValue = boolValue;
	_boolWriteCount += 1;
}

@end

// A stub effect the extAddedToDocument: path reads: the debug property, the regression gate,
// and the license-state application (a category on the real effect, redeclared here as a
// plain method the stub answers).
@interface FxGripFxFactoryStubEffect : NSObject
@property (nonatomic, strong) NSDictionary<NSString *, id> *pluginProperties;
@property (nonatomic, assign) BOOL licenseStateApplied;
@property (nonatomic, assign) BOOL appliedLicenseState;
@property (nonatomic, assign) BOOL reportsExtensionClass;
@property (nonatomic, copy) NSString *pluginUUID;
@property (nonatomic, copy) NSString *pluginStringVersion;
@property (nonatomic, copy) NSString *pluginDisplayName;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *productUpdateResponses;
@property (nonatomic, strong, readonly) NSMutableDictionary<NSNumber *, FxGripFxFactoryStubParameter *> *stubParameters;
/*! The parameter registered under an ID, created on first use. */
- (FxGripFxFactoryStubParameter *)stubParameterForID:(NSInteger)parameterID;
@end

@implementation FxGripFxFactoryStubEffect {
	NSNotificationCenter *_notifier;
}

- (instancetype)init
{
	self = [super init];
	if (self) {
		// extLoadWithEffect: reads the notifier to register observers; a real priority center
		// keeps that registration harmless. It is stored so a posted notification reaches an
		// observer registered at load.
		Class cls = NSClassFromString(@"NSPriorityNotificationCenter");
		_notifier = [[cls alloc] init];
		_pluginProperties = @{};
		_pluginUUID = @"stub-plugin-uuid";
		_pluginStringVersion = @"1.2.3";
		_pluginDisplayName = @"Stub Plugin";
		_productUpdateResponses = NSMutableArray.new;
		_stubParameters = NSMutableDictionary.new;
	}
	return self;
}

- (id)effectBase
{
	// The stub plays the full effect; rich reads route back to it, as the old cast did.
	return self;
}

- (NSNotificationCenter *)notifier
{
	return _notifier;
}

- (BOOL)hasExtensionClass:(Class)cls { return self.reportsExtensionClass; }

- (void)setFxFactoryLicenseState:(BOOL)licensed
{
	self.licenseStateApplied = YES;
	self.appliedLicenseState = licensed;
}

- (void)onFxFactoryShowProductUpdates:(NSDictionary *)response
{
	[self.productUpdateResponses addObject:response];
}

- (void)onFxFactoryRegisterLicensingStatusChange:(NSUInteger)status
{
	[self setFxFactoryLicenseState:status == FxGripFxFactoryTestStatusLicensed];
}

- (FxGripFxFactoryStubParameter *)stubParameterForID:(NSInteger)parameterID
{
	FxGripFxFactoryStubParameter *parameter = self.stubParameters[@(parameterID)];
	if (parameter == nil) {
		parameter = [FxGripFxFactoryStubParameter.alloc init];
		self.stubParameters[@(parameterID)] = parameter;
	}
	return parameter;
}

- (id)objectAtIndexedSubscript:(NSInteger)index
{
	return [self stubParameterForID:index];
}

// The licensing callback opens an out-of-band parameter access, which reads the manager's
// custom-action API; a hostless stub reports none and the access stays inert.
- (id)apiManager
{
	return nil;
}

@end

/*! A stub effect that also declares the hard-coded settings conformance, so the extension
	falls back to the effect as its settings object. */
@interface FxGripFxFactorySettingsEffect : FxGripFxFactoryStubEffect <FxGripFxFactorySettings>
@end

@implementation FxGripFxFactorySettingsEffect
- (BOOL)fxFactoryActive { return YES; }
@end

/*! Stands in for the bundle whose Info.plist the FxFactory regression check reads. */
@interface FxGripFxFactoryInfoBundleStub : NSObject
@property (nonatomic, copy) NSDictionary *info;
@end

@implementation FxGripFxFactoryInfoBundleStub
- (id)objectForInfoDictionaryKey:(NSString *)key { return self.info[key]; }
@end

// Extends the mock so extAddedToDocument: runs without touching a host: it is active, its
// side-effecting handler installs are no-ops, and the license toggle records locally.
@interface FxGripFxFactoryDocumentMock : FxGripFxFactoryMock
@property (nonatomic, assign) BOOL recordedBoolValue;
@property (nonatomic, assign) BOOL boolValueWasSet;
@end

@implementation FxGripFxFactoryDocumentMock
- (BOOL)fxFactoryActive { return YES; }
- (NSString *)fxFactoryPluginUUID { return @"test-uuid"; }
- (void)registerLicenseHandler:(NSString *)productUUID {}
- (void)showProductUpdates {}
- (void)setBoolValue:(BOOL)value { self.recordedBoolValue = value; self.boolValueWasSet = YES; }
- (BOOL)boolValue { return self.recordedBoolValue; }
@end

// Records the watermark-render seam so the render DECISION is testable without the GPU.
@interface FxGripFxFactoryWatermarkMock : FxGripFxFactoryMock
@property (nonatomic, assign) BOOL watermarkEnabled;
@property (nonatomic, assign) NSUInteger renderCount;
@end

@implementation FxGripFxFactoryWatermarkMock
- (BOOL)fxFactoryWaterMarkUnlicensed { return self.watermarkEnabled; }
- (BOOL)renderWatermarkOntoImage:(id)destinationImage error:(NSError *_Nullable *_Nullable)outError
{
	self.renderCount += 1;
	return YES;
}
@end

// Records the product UUID passed to the unregister seam, and stubs the register seam so a
// handler is installed without a live FxFactory. Drives the register/unregister UUID pairing.
@interface FxGripFxFactoryHandlerMock : FxGripFxFactoryMock
@property (nonatomic, strong) NSMutableArray<NSString *> *unregisteredUUIDs;
@end

@implementation FxGripFxFactoryHandlerMock
- (instancetype)init
{
	self = [super init];
	if (self) {
		_unregisteredUUIDs = NSMutableArray.new;
	}
	return self;
}
- (id)factoryRegisterLicensingHandlerForProduct:(NSString *)productUUID handler:(id)handler
{
	return @"handle";
}
- (void)factoryUnregisterLicensingHandler:(id)handle forProduct:(NSString *)productUUID
{
	[self.unregisteredUUIDs addObject:productUUID ?: @""];
}
@end

// A hard-coded settings object: the plugin declares its FxFactory preferences in code rather
// than through the plist parameter. respondsToSelector drives the extAddParameters branches.
@interface FxGripFxFactorySettingsMock : NSObject
@property (nonatomic, assign) BOOL watermark;
@end

@implementation FxGripFxFactorySettingsMock
- (BOOL)fxFactoryActive { return YES; }
- (NSString *)fxFactoryProductUUID { return @"settings-uuid"; }
- (BOOL)fxFactoryWaterMarkUnlicensed { return self.watermark; }
@end

/*! A settings object that declares the integration inactive. */
@interface FxGripFxFactoryInactiveSettingsMock : NSObject
@end

@implementation FxGripFxFactoryInactiveSettingsMock
- (BOOL)fxFactoryActive { return NO; }
@end

/*! A settings object that hard-codes every FxFactory setting, so extAddParameters: reads each
	one from the settings hooks and adds none of the fallback parameters. */
@interface FxGripFxFactoryFullSettingsMock : NSObject
@end

@implementation FxGripFxFactoryFullSettingsMock
- (BOOL)fxFactoryActive { return YES; }
- (NSString *)fxFactoryProductUUID { return @"full-uuid"; }
- (NSString *)fxFactoryProductVersion { return @"9.9.9"; }
- (BOOL)fxFactoryWaterMarkUnlicensed { return YES; }
- (BOOL)fxFactoryShowBuyButton { return YES; }
- (BOOL)fxFactoryShowProductButton { return YES; }
- (BOOL)fxFactoryAutoChecking { return YES; }
@end

/*! A settings object that names the product but leaves the active state open, so the product
	identity alone drives the defaults. */
@interface FxGripFxFactoryProductOnlySettingsMock : NSObject
@end

@implementation FxGripFxFactoryProductOnlySettingsMock
- (NSString *)fxFactoryProductUUID { return @"product-only-uuid"; }
@end

/*! Substitutes the regression check's bundle so the Info.plist entitlements the check reads
	are supplied by the test. */
@interface FxGripFxFactoryRegressionMock : FxGripFxFactoryMock
@property (nonatomic, strong) FxGripFxFactoryInfoBundleStub *bundleStub;
@end

@implementation FxGripFxFactoryRegressionMock

- (instancetype)init
{
	self = [super init];
	if (self) {
		_bundleStub = [FxGripFxFactoryInfoBundleStub.alloc init];
	}
	return self;
}

- (id)fxFactoryRegressionBundle { return self.bundleStub; }

@end

/*! Records the update-check seam and replies with a canned response, so the update handler
	chain runs without a live FxFactory or a network call. */
@interface FxGripFxFactoryUpdateMock : FxGripFxFactoryMock
@property (nonatomic, copy) NSDictionary *cannedResponse;
@property (nonatomic, assign) BOOL recordedForce;
@property (nonatomic, copy) NSString *recordedVersion;
@property (nonatomic, assign) NSUInteger showUpdatesCallCount;
@property (nonatomic, assign) BOOL updateCheckingEnabled;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *updateCheckingWrites;
@end

@implementation FxGripFxFactoryUpdateMock

- (instancetype)init
{
	self = [super init];
	if (self) {
		_updateCheckingWrites = NSMutableArray.new;
	}
	return self;
}

- (void)factoryShowProductUpdatesForProduct:(NSString *)productUUID
									version:(NSString *)version
									  force:(BOOL)force
									handler:(void (^)(NSDictionary *))handler
{
	self.showUpdatesCallCount += 1;
	self.recordedForce = force;
	self.recordedVersion = version;
	if (handler) {
		handler(self.cannedResponse);
	}
}

- (BOOL)factoryUpdateCheckingEnabledForProduct:(NSString *)productUUID { return self.updateCheckingEnabled; }

- (void)factorySetUpdateCheckingEnabled:(BOOL)enabled forProduct:(NSString *)productUUID
{
	[self.updateCheckingWrites addObject:@(enabled)];
}

@end

/*! Records the licensing actions the buy and show-product flows request. */
@interface FxGripFxFactoryActionMock : FxGripFxFactoryMock
@property (nonatomic, strong) NSMutableArray<NSNumber *> *actions;
@property (nonatomic, assign) BOOL actionResult;
@end

@implementation FxGripFxFactoryActionMock

- (instancetype)init
{
	self = [super init];
	if (self) {
		_actions = NSMutableArray.new;
	}
	return self;
}

- (BOOL)factoryPerformLicensingAction:(NSUInteger)action forProduct:(NSString *)productUUID
{
	[self.actions addObject:@(action)];
	return self.actionResult;
}

@end

/*! Reports a failing watermark render, so the render handler's failure path runs. */
@interface FxGripFxFactoryFailingWatermarkMock : FxGripFxFactoryMock
@property (nonatomic, assign) NSUInteger renderCount;
@end

@implementation FxGripFxFactoryFailingWatermarkMock
- (BOOL)fxFactoryWaterMarkUnlicensed { return YES; }
- (BOOL)renderWatermarkOntoImage:(id)destinationImage error:(NSError *_Nullable *_Nullable)outError
{
	self.renderCount += 1;
	if (outError) {
		*outError = [NSError errorWithDomain:@"FxGripFxFactoryTests" code:7 userInfo:nil];
	}
	return NO;
}
@end

/*! Reports the contact form as unavailable, so the availability guard runs. */
@interface FxGripFxFactoryNoContactFormMock : FxGripFxFactoryMock
@end

@implementation FxGripFxFactoryNoContactFormMock
- (BOOL)factoryContactFormAvailable { return NO; }
@end

/*! Captures the licensing status change handler, so the callback runs on demand. */
@interface FxGripFxFactoryCallbackMock : FxGripFxFactoryMock
@property (nonatomic, copy) void (^capturedHandler)(NSUInteger status, id context);
@end

@implementation FxGripFxFactoryCallbackMock
- (id)factoryRegisterLicensingHandlerForProduct:(NSString *)productUUID handler:(id)handler
{
	self.capturedHandler = (void (^)(NSUInteger, id))handler;
	return @"handle";
}
- (void)factoryUnregisterLicensingHandler:(id)handle forProduct:(NSString *)productUUID {}
@end

/*! Reports FxFactory as absent, so the load pass stops before connecting. */
@interface FxGripFxFactoryAbsentMock : FxGripFxFactoryMock
@end

@implementation FxGripFxFactoryAbsentMock
- (BOOL)factoryInstalled { return NO; }
@end

/*! Reports a fixed FxFactory version through the SDK seam. */
@interface FxGripFxFactoryVersionMock : FxGripFxFactoryMock
@end

@implementation FxGripFxFactoryVersionMock
- (FxGripFxFactoryTestVersion)factoryVersion { return (FxGripFxFactoryTestVersion){7, 1, 4}; }
@end

/*! A real effect that installs a mock FxFactory extension, so the effect-side category
	accessors resolve without a live FxFactory installation. */
@interface FxGripFxFactoryHostEffect : FxGripTileableEffect
@property (nonatomic, assign) BOOL recordedLicenseState;
@property (nonatomic, assign) NSUInteger licenseStateCallCount;
@end

@implementation FxGripFxFactoryHostEffect

- (NSMutableArray<id<FxGripExtension>> *)loadExtensions
{
	NSMutableArray<id<FxGripExtension>> *extensions = [super loadExtensions];
	FxGripFxFactoryMock *factory = [FxGripFxFactoryMock.alloc init];
	[factory setFxFactoryPluginUUID:@"host-effect-uuid"];
	[extensions addObject:(id<FxGripExtension>)factory];
	return extensions;
}

- (void)setFxFactoryLicenseState:(BOOL)licensed
{
	self.recordedLicenseState = licensed;
	self.licenseStateCallCount += 1;
}

@end

/*! A real effect with no FxFactory extension installed, so the effect-side factory accessor
	and the empty default hooks are reachable. */
@interface FxGripFxFactoryPlainEffect : FxGripTileableEffect
@end

@implementation FxGripFxFactoryPlainEffect
@end

@interface FxGripFxFactoryTests : XCTestCase
@property (nonatomic, strong) FxGripFxFactory *factory;
@end

@implementation FxGripFxFactoryTests

- (void)setUp
{
	[super setUp];
	self.factory = [NSClassFromString(@"FxGripFxFactory") alloc];
	self.factory = [self.factory init];
}

- (void)tearDown
{
	self.factory = nil;
	[super tearDown];
}

#pragma mark The notification-dispatch port

/*! @abstract The extension responds to the single-notification dispatch selectors for parameters, changes, document add, and render. */
- (void)testTheExtensionRespondsToThePortedNotificationSelectors
{
	// The live dispatch table delivers each hook a single NSNotification; the legacy
	// signatures were never called.
	XCTAssertTrue([self.factory respondsToSelector:@selector(extAddParameters:)]);
	XCTAssertTrue([self.factory respondsToSelector:@selector(extParameterChanged:)]);
	XCTAssertTrue([self.factory respondsToSelector:@selector(extAddedToDocument:)]);
	XCTAssertTrue([self.factory respondsToSelector:@selector(extRenderDestinationImage:)]);
}

/*! @abstract The extension no longer responds to the legacy multi-argument hook selectors. */
- (void)testTheExtensionNoLongerRespondsToTheLegacySelectors
{
	XCTAssertFalse([self.factory respondsToSelector:NSSelectorFromString(@"extProcessParameters:")]);
	XCTAssertFalse([self.factory respondsToSelector:NSSelectorFromString(@"extAddedToDocument")]);
	XCTAssertFalse([self.factory respondsToSelector:NSSelectorFromString(@"extParameterChanged:atTime:error:")]);
	XCTAssertFalse([self.factory respondsToSelector:NSSelectorFromString(@"extRenderDestinationImage:sourceImages:pluginState:atTime:error:")]);
}

#pragma mark Handler behavior

/*! @abstract A configuration that declares the integration inactive adds no parameters to the list. */
- (void)testAnInactiveConfigurationAddsNoParameters
{
	[self.factory setFxFactorySettingsObject:(id)[FxGripFxFactoryInactiveSettingsMock.alloc init]];
	NSMutableArray<NSMutableDictionary *> *parameters = NSMutableArray.new;
	NSNotification *note = [NSNotification notificationWithName:FxGripTileableEffectAddParametersName
														object:nil
													  userInfo:@{FxGripTileableEffectParametersKey: parameters}];

	XCTAssertNoThrow([self.factory extAddParameters:note]);
	XCTAssertEqual(parameters.count, (NSUInteger)0);
}

/*! @abstract The parameter-changed handler ignores a notification carrying no parameter id without throwing. */
- (void)testParameterChangedIgnoresANotificationWithoutAParameterID
{
	NSNotification *note = [NSNotification notificationWithName:FxGripTileableEffectParameterChangedName
														object:nil
													  userInfo:@{}];
	XCTAssertNoThrow([self.factory extParameterChanged:note]);
}

/*! @abstract The render handler ignores a notification carrying no destination image without throwing. */
- (void)testRenderIgnoresANotificationWithoutADestinationImage
{
	NSNotification *note = [NSNotification notificationWithName:FxGripTileableEffectRenderDestinationImageName
														object:nil
													  userInfo:@{}];
	XCTAssertNoThrow([self.factory extRenderDestinationImage:note]);
}

#pragma mark #35 — contact-form recipient guard

/*! @abstract The contact form refuses an external recipient address. */
- (void)testTheContactFormRejectsExternalRecipients
{
	// An external recipient is refused. On a machine without FxFactory the SDK guard also
	// refuses, so the assertion holds either way; the fix keeps it from silently allowing
	// external addresses when FxFactory is present.
	XCTAssertFalse([self.factory showContactForm:@"someone@external.example" subject:@"s" message:@"m"]);
}

#pragma mark End-to-end via the mock seams

/*! @abstract pluginIsLicensed follows the licensing seam status, true for licensed and false for unlicensed. */
- (void)testLicenseDecisionFollowsTheLicensingSeam
{
	FxGripFxFactoryMock *licensed = [FxGripFxFactoryMock.alloc init];
	[licensed setFxFactoryPluginUUID:@"test-uuid"];
	licensed.mockStatus = 3;   // ProductLicensed
	XCTAssertTrue([licensed pluginIsLicensed]);

	FxGripFxFactoryMock *unlicensed = [FxGripFxFactoryMock.alloc init];
	[unlicensed setFxFactoryPluginUUID:@"test-uuid"];
	unlicensed.mockStatus = 2; // ProductUnlicensed
	XCTAssertFalse([unlicensed pluginIsLicensed]);
}

/*! @abstract The contact form sends to an fxfactory.com recipient and refuses an external recipient before the send. */
- (void)testTheContactFormGuardRunsEndToEndThroughTheSeam
{
	FxGripFxFactoryMock *mock = [FxGripFxFactoryMock.alloc init];

	// With the form "available" via the seam, the recipient guard is reached: an
	// @fxfactory.com address is sent, an external address is refused before the send.
	XCTAssertTrue([mock showContactForm:@"support@fxfactory.com" subject:@"s" message:@"m"]);
	XCTAssertEqualObjects(mock.contactRecipients, (@[@"support@fxfactory.com"]));

	XCTAssertFalse([mock showContactForm:@"someone@external.example" subject:@"s" message:@"m"]);
	XCTAssertEqual(mock.contactRecipients.count, (NSUInteger)1,
				   @"the external recipient was rejected before the send");
}

#pragma mark #34 — the DEBUG license override (end to end)

- (FxGripFxFactoryDocumentMock *)runAddedToDocumentWithDebugProperty:(nullable id)debugValue
													  realStatus:(NSUInteger)realStatus
														  effect:(FxGripFxFactoryStubEffect **)outEffect
{
	FxGripFxFactoryDocumentMock *mock = [FxGripFxFactoryDocumentMock.alloc init];
	mock.mockStatus = realStatus;   // what the real FxFactory seam would report

	FxGripFxFactoryStubEffect *effect = [FxGripFxFactoryStubEffect.alloc init];
	effect.pluginProperties = debugValue ? @{@"FxFactoryDebugSetLicensed": debugValue} : @{};
	[mock extLoadWithEffect:(id)effect];

	[mock extAddedToDocument:[NSNotification notificationWithName:@"added" object:effect userInfo:nil]];
	if (outEffect) {
		*outEffect = effect;
	}
	return mock;
}

/*! @abstract The debug override forces licensed over an unlicensed real status and applies the licensed UI state. */
- (void)testTheDebugOverrideForcesLicensedOverTheRealStatus
{
	FxGripFxFactoryStubEffect *effect = nil;
	// Real status is Unlicensed (2); the debug override forces licensed.
	FxGripFxFactoryDocumentMock *mock = [self runAddedToDocumentWithDebugProperty:@YES realStatus:2 effect:&effect];

	XCTAssertTrue([mock pluginIsLicensed], @"the debug override drives pluginIsLicensed, not the real status");
	XCTAssertTrue(mock.boolValueWasSet);
	XCTAssertTrue(mock.recordedBoolValue, @"the license toggle mirrors the override");
	XCTAssertTrue(effect.appliedLicenseState, @"the license UI state is applied");
}

/*! @abstract The debug override forces unlicensed over a licensed real status and applies the unlicensed UI state. */
- (void)testTheDebugOverrideForcesUnlicensedOverTheRealStatus
{
	FxGripFxFactoryStubEffect *effect = nil;
	// Real status is Licensed (3); the debug override forces unlicensed.
	FxGripFxFactoryDocumentMock *mock = [self runAddedToDocumentWithDebugProperty:@NO realStatus:3 effect:&effect];

	XCTAssertFalse([mock pluginIsLicensed]);
	XCTAssertTrue(mock.boolValueWasSet);
	XCTAssertFalse(mock.recordedBoolValue);
	XCTAssertFalse(effect.appliedLicenseState);
}

/*! @abstract An absent debug override falls through to the real licensing status and syncs the toggle to it. */
- (void)testAnAbsentDebugPropertyFallsThroughToTheRealLicensingSync
{
	FxGripFxFactoryStubEffect *effect = nil;
	// No override property: the real status (Licensed) is used. The prior #34 bug forced
	// every debug build unlicensed here; now it must honor the real status.
	FxGripFxFactoryDocumentMock *mock = [self runAddedToDocumentWithDebugProperty:nil realStatus:3 effect:&effect];

	XCTAssertTrue([mock pluginIsLicensed], @"an absent override falls through to the real licensed status");
	XCTAssertTrue(mock.recordedBoolValue, @"the toggle syncs to the real licensed state");
}

#pragma mark #36 — the watermark render decision (end to end)

- (NSUInteger)renderCountForWatermark:(BOOL)watermark licensedStatus:(NSUInteger)status
{
	FxGripFxFactoryWatermarkMock *mock = [FxGripFxFactoryWatermarkMock.alloc init];
	mock.watermarkEnabled = watermark;
	mock.mockStatus = status;
	[mock setFxFactoryPluginUUID:@"test-uuid"];

	// A non-nil placeholder passes the destination-image guard; the mock's render seam
	// records the call rather than touching the GPU.
	NSNotification *note = [NSNotification notificationWithName:@"render"
														object:nil
													  userInfo:@{FxGripTileableEffectRenderDestinationImageKey: NSObject.new}];
	[mock extRenderDestinationImage:note];
	return mock.renderCount;
}

/*! @abstract An unlicensed plugin with watermarking enabled runs the watermark render once. */
- (void)testUnlicensedWithWatermarkingRunsTheWatermarkRender
{
	// 2 == ProductUnlicensed
	XCTAssertEqual([self renderCountForWatermark:YES licensedStatus:2], (NSUInteger)1);
}

/*! @abstract A licensed plugin skips the watermark render. */
- (void)testLicensedSkipsTheWatermarkRender
{
	// 3 == ProductLicensed
	XCTAssertEqual([self renderCountForWatermark:YES licensedStatus:3], (NSUInteger)0);
}

/*! @abstract Disabled watermarking skips the render even when unlicensed. */
- (void)testWatermarkingDisabledSkipsTheRender
{
	XCTAssertEqual([self renderCountForWatermark:NO licensedStatus:2], (NSUInteger)0);
}

#pragma mark License handler unregisters the UUID it registered

/*! @abstract Re-registering a license handler first unregisters the previous product's UUID. */
- (void)testReRegisteringTearsDownThePreviousProductsHandler
{
	FxGripFxFactoryHandlerMock *mock = [FxGripFxFactoryHandlerMock.alloc init];

	[mock registerLicenseHandler:@"uuid-A"];
	[mock registerLicenseHandler:@"uuid-B"];   // re-register must first unregister uuid-A

	XCTAssertEqualObjects(mock.unregisteredUUIDs, (@[@"uuid-A"]),
						  @"unregister targets the UUID the handler was registered with, not the current one");
}

#pragma mark A settings-object watermark preference is honored

/*! @abstract A settings-object watermark opt-out registers as present and is honored rather than overridden to YES. */
- (void)testASettingsObjectWatermarkOptOutIsHonored
{
	FxGripFxFactory *factory = [NSClassFromString(@"FxGripFxFactory") alloc];
	factory = [factory init];

	FxGripFxFactorySettingsMock *settings = FxGripFxFactorySettingsMock.new;
	settings.watermark = NO;   // the plugin explicitly opts out of the unlicensed watermark
	[factory setFxFactorySettingsObject:(id)settings];

	// A fxfactory-typed parameter with a parent id, so the fallback parameters the path may add
	// carry a non-nil parent id.
	NSMutableDictionary *fxFactoryParameter = @{ kFxParameterProperty_Type: @"fxfactory",
												 kFxParameterProperty_ParentId: @0 }.mutableCopy;
	NSMutableArray *parameters = @[ fxFactoryParameter ].mutableCopy;
	NSNotification *note = [NSNotification notificationWithName:FxGripTileableEffectAddParametersName
														object:nil
													  userInfo:@{FxGripTileableEffectParametersKey: parameters}];
	[factory extAddParameters:note];

	XCTAssertTrue([factory fxFactoryHasWaterMarkUnlicensed],
				  @"a settings-object value registers as present, like every other configuration flag");
	XCTAssertFalse([factory fxFactoryWaterMarkUnlicensed],
				   @"the explicit opt-out is honored, not overridden to YES by the product default");
}

#pragma mark Changing the product UUID invalidates the cached license verdict

/*! @abstract Changing the product UUID clears the cached license verdict so it recomputes for the new product. */
- (void)testChangingTheProductUUIDInvalidatesTheCachedLicenseVerdict
{
	FxGripFxFactoryDocumentMock *mock = [FxGripFxFactoryDocumentMock.alloc init];
	mock.mockStatus = 3;   // the current product is Licensed
	XCTAssertTrue([mock pluginIsLicensed], @"first read caches the verdict");

	mock.mockStatus = 2;   // the newly chosen product is Unlicensed
	// paramID = parameterID (0) + kParameterFxFactoryProductUUIDOffset (2)
	NSNotification *note = [NSNotification notificationWithName:FxGripTileableEffectParameterChangedName
														object:nil
													  userInfo:@{FxGripTileableEffectParameterChangedIDKey: @(2)}];
	[mock extParameterChanged:note];

	XCTAssertFalse([mock pluginIsLicensed],
				   @"the UUID change clears the cached verdict so it recomputes for the new product");
}

#pragma mark The Info.plist regression check

/*! A complete, correct FxFactory entitlement set. */
- (NSMutableDictionary *)validRegressionInfo
{
	return @{
		@"com.apple.security.app-sandbox": @NO,
		@"com.apple.security.cs.disable-library-validation": @YES,
		@"NSUpdateSecurityPolicy": @{
			@"AllowPackages": @[@"AZLNLGPTT3"],
			@"AllowProcesses": @{@"AZLNLGPTT3": @[@"com.fxfactory.FxFactory", @"com.fxfactory.FxFactory.helper"]}
		}
	}.mutableCopy;
}

- (BOOL)regressionResultForInfo:(NSDictionary *)info
{
	FxGripFxFactoryRegressionMock *mock = [FxGripFxFactoryRegressionMock.alloc init];
	mock.bundleStub.info = info;
	return [mock fxFactoryRegression];
}

/*! @abstract A complete FxFactory entitlement set passes the regression check. */
- (void)testTheRegressionCheckPassesACompleteEntitlementSet
{
	XCTAssertTrue([self regressionResultForInfo:[self validRegressionInfo]]);
}

/*! @abstract The regression check fails when the app-sandbox entitlement is missing, mistyped, or enabled. */
- (void)testTheRegressionCheckFailsOnABadAppSandboxEntitlement
{
	NSMutableDictionary *info = [self validRegressionInfo];
	[info removeObjectForKey:@"com.apple.security.app-sandbox"];
	XCTAssertFalse([self regressionResultForInfo:info], @"the entitlement must be present");

	info[@"com.apple.security.app-sandbox"] = @"NO";
	XCTAssertFalse([self regressionResultForInfo:info], @"the entitlement must be a Boolean");

	info[@"com.apple.security.app-sandbox"] = @YES;
	XCTAssertFalse([self regressionResultForInfo:info], @"the sandbox must be off");
}

/*! @abstract The regression check fails when the library-validation entitlement is missing, mistyped, or off. */
- (void)testTheRegressionCheckFailsOnABadLibraryValidationEntitlement
{
	NSMutableDictionary *info = [self validRegressionInfo];
	[info removeObjectForKey:@"com.apple.security.cs.disable-library-validation"];
	XCTAssertFalse([self regressionResultForInfo:info]);

	info[@"com.apple.security.cs.disable-library-validation"] = @"YES";
	XCTAssertFalse([self regressionResultForInfo:info], @"the entitlement must be a Boolean");

	info[@"com.apple.security.cs.disable-library-validation"] = @NO;
	XCTAssertFalse([self regressionResultForInfo:info], @"library validation must be disabled");
}

/*! @abstract The regression check fails when the update security policy is missing or is not a dictionary. */
- (void)testTheRegressionCheckFailsOnAMissingOrMistypedUpdatePolicy
{
	NSMutableDictionary *info = [self validRegressionInfo];
	[info removeObjectForKey:@"NSUpdateSecurityPolicy"];
	XCTAssertFalse([self regressionResultForInfo:info]);

	info[@"NSUpdateSecurityPolicy"] = @[@"not a dictionary"];
	XCTAssertFalse([self regressionResultForInfo:info]);
}

/*! @abstract The regression check fails when the allowed-packages list is missing, mistyped, or omits the FxFactory package. */
- (void)testTheRegressionCheckFailsOnABadAllowPackagesList
{
	NSDictionary *processes = @{@"AZLNLGPTT3": @[@"com.fxfactory.FxFactory", @"com.fxfactory.FxFactory.helper"]};

	NSMutableDictionary *info = [self validRegressionInfo];
	info[@"NSUpdateSecurityPolicy"] = @{@"AllowProcesses": processes};
	XCTAssertFalse([self regressionResultForInfo:info], @"AllowPackages must be present");

	info[@"NSUpdateSecurityPolicy"] = @{@"AllowPackages": @"AZLNLGPTT3", @"AllowProcesses": processes};
	XCTAssertFalse([self regressionResultForInfo:info], @"AllowPackages must be an array");

	info[@"NSUpdateSecurityPolicy"] = @{@"AllowPackages": @[@"OTHER"], @"AllowProcesses": processes};
	XCTAssertFalse([self regressionResultForInfo:info], @"AllowPackages must name the FxFactory package");
}

/*! @abstract The regression check fails when the allowed-processes map is missing, mistyped, or lacks the FxFactory package key. */
- (void)testTheRegressionCheckFailsOnABadAllowProcessesMap
{
	NSArray *packages = @[@"AZLNLGPTT3"];

	NSMutableDictionary *info = [self validRegressionInfo];
	info[@"NSUpdateSecurityPolicy"] = @{@"AllowPackages": packages};
	XCTAssertFalse([self regressionResultForInfo:info], @"AllowProcesses must be present");

	info[@"NSUpdateSecurityPolicy"] = @{@"AllowPackages": packages, @"AllowProcesses": @[@"nope"]};
	XCTAssertFalse([self regressionResultForInfo:info], @"AllowProcesses must be a dictionary");

	info[@"NSUpdateSecurityPolicy"] = @{@"AllowPackages": packages, @"AllowProcesses": @{@"OTHER": @[]}};
	XCTAssertFalse([self regressionResultForInfo:info], @"AllowProcesses must key the FxFactory package");

	info[@"NSUpdateSecurityPolicy"] = @{@"AllowPackages": packages, @"AllowProcesses": @{@"AZLNLGPTT3": @"nope"}};
	XCTAssertFalse([self regressionResultForInfo:info], @"the package's process list must be an array");
}

/*! @abstract The regression check fails when either FxFactory process is absent from the allowed-processes list. */
- (void)testTheRegressionCheckFailsWhenAnFxFactoryProcessIsAbsent
{
	NSArray *packages = @[@"AZLNLGPTT3"];

	NSMutableDictionary *info = [self validRegressionInfo];
	info[@"NSUpdateSecurityPolicy"] = @{@"AllowPackages": packages,
										@"AllowProcesses": @{@"AZLNLGPTT3": @[@"com.fxfactory.FxFactory.helper"]}};
	XCTAssertFalse([self regressionResultForInfo:info], @"the FxFactory process must be listed");

	info[@"NSUpdateSecurityPolicy"] = @{@"AllowPackages": packages,
										@"AllowProcesses": @{@"AZLNLGPTT3": @[@"com.fxfactory.FxFactory"]}};
	XCTAssertFalse([self regressionResultForInfo:info], @"the FxFactory helper process must be listed");
}

/*! @abstract Loading against an effect that carries the regression extension runs the Info.plist check. */
- (void)testLoadRunsTheRegressionCheckWhenTheRegressionExtensionIsPresent
{
	FxGripFxFactoryRegressionMock *mock = [FxGripFxFactoryRegressionMock.alloc init];
	mock.bundleStub.info = [self validRegressionInfo];
	FxGripFxFactoryStubEffect *effect = [FxGripFxFactoryStubEffect.alloc init];
	effect.reportsExtensionClass = YES;

	XCTAssertTrue([mock extLoadWithEffect:(id)effect]);
	XCTAssertTrue([mock fxFactoryRegression], @"the same bundle the load pass read still validates");
}

#pragma mark Configuration properties

/*! Marks the extension as added to an effect, the state the property writers require. */
- (void)addFactory:(FxGripFxFactory *)factory toEffect:(FxGripFxFactoryStubEffect *)effect
{
	[factory extLoadWithEffect:(id)effect];
	[factory parameterForDictionary:@{kFxParameterProperty_Id: @0,
									  kFxParameterProperty_Type: kFxParameterType_Toggle,
									  kFxParameterProperty_Name: @"FxFactory Product Licensed"}];
}

/*! Registers the extension against a parameter that hard-codes the integration active, so the
	licensing toggle sits at parameter 0 and the change handlers run. */
- (void)activateFactory:(FxGripFxFactory *)factory
{
	NSMutableDictionary *seed = @{kFxParameterProperty_Type: @"fxfactory",
								  kFxParameterProperty_Id: @0,
								  kFxParameterProperty_ParentId: @0,
								  kPropertiesFxFactoryActive: @YES}.mutableCopy;
	[self parametersAddedByFactory:factory seededBy:seed];
	[factory parameterForDictionary:@{kFxParameterProperty_Id: @0,
									  kFxParameterProperty_Type: kFxParameterType_Toggle,
									  kFxParameterProperty_Name: @"FxFactory Product Licensed"}];
	XCTAssertTrue([factory fxFactoryActive]);
}

/*! @abstract Each configuration writer sets its own parameter once the extension is added to an effect. */
- (void)testTheConfigurationWritersSetTheirParameterOnceAdded
{
	FxGripFxFactoryStubEffect *effect = [FxGripFxFactoryStubEffect.alloc init];
	FxGripFxFactoryMock *factory = [FxGripFxFactoryMock.alloc init];
	[self addFactory:factory toEffect:effect];

	[factory setFxFactoryActive:YES];
	[factory setFxFactoryWaterMarkUnlicensed:YES];
	[factory setFxFactoryShowBuyButton:YES];
	[factory setFxFactoryShowProductButton:YES];
	[factory setFxFactoryAutoChecking:YES];

	// Offsets from the licensing toggle: active 1, watermark 4, buy 5, product 7, checking 9.
	XCTAssertTrue([effect stubParameterForID:1].boolValue);
	XCTAssertTrue([effect stubParameterForID:4].boolValue);
	XCTAssertTrue([effect stubParameterForID:5].boolValue);
	XCTAssertTrue([effect stubParameterForID:7].boolValue);
	XCTAssertTrue([effect stubParameterForID:9].boolValue);
}

/*! @abstract Each configuration writer refuses before the extension is added to an effect. */
- (void)testTheConfigurationWritersRefuseBeforeTheExtensionIsAdded
{
	FxGripFxFactoryStubEffect *effect = [FxGripFxFactoryStubEffect.alloc init];
	FxGripFxFactoryMock *factory = [FxGripFxFactoryMock.alloc init];
	[factory extLoadWithEffect:(id)effect];

	[factory setFxFactoryActive:YES];
	[factory setFxFactoryWaterMarkUnlicensed:YES];
	[factory setFxFactoryShowBuyButton:YES];
	[factory setFxFactoryShowProductButton:YES];
	[factory setFxFactoryAutoChecking:YES];

	XCTAssertEqual(effect.stubParameters.count, (NSUInteger)0, @"no parameter was written");
}

/*! @abstract A hard-coded settings object makes every configuration writer refuse the write. */
- (void)testTheConfigurationWritersRefuseAHardCodedSetting
{
	FxGripFxFactoryStubEffect *effect = [FxGripFxFactoryStubEffect.alloc init];
	FxGripFxFactory *factory = [FxGripFxFactoryMock.alloc init];
	[factory setFxFactorySettingsObject:(id)[FxGripFxFactoryFullSettingsMock.alloc init]];
	[self addFactory:factory toEffect:effect];

	NSMutableArray *parameters = NSMutableArray.new;
	[factory extAddParameters:[NSNotification notificationWithName:FxGripTileableEffectAddParametersName
															object:nil
														  userInfo:@{FxGripTileableEffectParametersKey: parameters}]];
	[effect.stubParameters removeAllObjects];

	[factory setFxFactoryActive:NO];
	[factory setFxFactoryWaterMarkUnlicensed:NO];
	[factory setFxFactoryShowBuyButton:NO];
	[factory setFxFactoryShowProductButton:NO];
	[factory setFxFactoryAutoChecking:NO];

	XCTAssertEqual(effect.stubParameters.count, (NSUInteger)0,
				   @"a hard-coded setting cannot be overwritten through a parameter");
}

/*! @abstract The active, watermark, and update-checking readers fall back to their parameter value once added to an effect. */
- (void)testTheConfigurationReadersFallBackToTheirParameter
{
	FxGripFxFactoryStubEffect *effect = [FxGripFxFactoryStubEffect.alloc init];
	FxGripFxFactoryMock *factory = [FxGripFxFactoryMock.alloc init];
	[self addFactory:factory toEffect:effect];

	[effect stubParameterForID:1].boolValue = YES;
	[effect stubParameterForID:4].boolValue = YES;
	[effect stubParameterForID:9].boolValue = YES;

	XCTAssertTrue([factory fxFactoryActive]);
	XCTAssertTrue([factory fxFactoryWaterMarkUnlicensed]);
	XCTAssertTrue([factory fxFactoryAutoChecking]);

	[effect stubParameterForID:1].boolValue = NO;
	XCTAssertFalse([factory fxFactoryActive]);
	XCTAssertFalse([factory fxFactoryWaterMarkUnlicensed],
				   @"the watermark also requires an active integration");
}

/*! @abstract The button readers report the hard-coded settings value and default to NO without one. */
- (void)testTheButtonReadersReportTheHardCodedSettingAndDefaultToNo
{
	FxGripFxFactory *bare = [FxGripFxFactoryMock.alloc init];
	XCTAssertFalse([bare fxFactoryShowBuyButton], @"an unconfigured extension shows no buttons");
	XCTAssertFalse([bare fxFactoryShowProductButton]);
	XCTAssertFalse([bare fxFactoryAutoChecking]);

	FxGripFxFactory *configured = [FxGripFxFactoryMock.alloc init];
	[configured setFxFactorySettingsObject:(id)[FxGripFxFactoryFullSettingsMock.alloc init]];
	NSMutableArray *parameters = NSMutableArray.new;
	[configured extAddParameters:[NSNotification notificationWithName:FxGripTileableEffectAddParametersName
															   object:nil
															 userInfo:@{FxGripTileableEffectParametersKey: parameters}]];

	XCTAssertTrue([configured fxFactoryHasShowBuyButton]);
	XCTAssertTrue([configured fxFactoryShowBuyButton]);
	XCTAssertTrue([configured fxFactoryHasShowProductButton]);
	XCTAssertTrue([configured fxFactoryShowProductButton]);
	XCTAssertTrue([configured fxFactoryHasAutoChecking]);
	XCTAssertTrue([configured fxFactoryAutoChecking]);
}

/*! @abstract The product UUID and version accept one write, refuse a second, and read from their parameter once cleared. */
- (void)testTheProductIdentityAcceptsOneWriteAndReadsItsParameterWhenCleared
{
	FxGripFxFactoryStubEffect *effect = [FxGripFxFactoryStubEffect.alloc init];
	FxGripFxFactoryMock *factory = [FxGripFxFactoryMock.alloc init];
	[self addFactory:factory toEffect:effect];

	[factory setFxFactoryPluginUUID:@"first-uuid"];
	[factory setFxFactoryPluginUUID:@"second-uuid"];
	XCTAssertEqualObjects([factory fxFactoryPluginUUID], @"first-uuid", @"a set identity is not replaced");

	[factory setFxFactoryPluginVersion:@"1.0.0"];
	[factory setFxFactoryPluginVersion:@"2.0.0"];
	XCTAssertEqualObjects([factory fxFactoryPluginVersion], @"1.0.0");

	// Offsets from the licensing toggle: product UUID 2, product version 3.
	[effect stubParameterForID:2].stringValue = @"parameter-uuid";
	[effect stubParameterForID:3].stringValue = @"3.0.0";
	[factory clearFxFactoryPluginUUID];
	[factory clearFxFactoryPluginVersion];

	XCTAssertEqualObjects([factory fxFactoryPluginUUID], @"parameter-uuid");
	XCTAssertEqualObjects([factory fxFactoryPluginVersion], @"3.0.0");
}

/*! @abstract The settings object falls back to the effect when the effect declares the settings conformance. */
- (void)testTheSettingsObjectFallsBackToAConformingEffect
{
	FxGripFxFactorySettingsEffect *effect = [FxGripFxFactorySettingsEffect.alloc init];
	FxGripFxFactoryMock *factory = [FxGripFxFactoryMock.alloc init];
	[factory extLoadWithEffect:(id)effect];

	XCTAssertEqual((id)[factory fxFactorySettingsObject], (id)effect);

	FxGripFxFactoryStubEffect *plain = [FxGripFxFactoryStubEffect.alloc init];
	FxGripFxFactoryMock *unconfigured = [FxGripFxFactoryMock.alloc init];
	[unconfigured extLoadWithEffect:(id)plain];
	XCTAssertNil([unconfigured fxFactorySettingsObject], @"a non-conforming effect supplies no settings");
}

#pragma mark Product updates

/*! @abstract A forced update check reports the response to the effect hook, the caller's handler, and the update notification. */
- (void)testAForcedUpdateCheckReportsTheResponseThroughEveryChannel
{
	FxGripFxFactoryStubEffect *effect = [FxGripFxFactoryStubEffect.alloc init];
	FxGripFxFactoryUpdateMock *mock = [FxGripFxFactoryUpdateMock.alloc init];
	mock.cannedResponse = @{@"answer": @42};
	[mock extLoadWithEffect:(id)effect];
	[mock setFxFactoryPluginUUID:@"update-uuid"];
	[mock setFxFactoryPluginVersion:@"4.5.6"];

	__block NSDictionary *posted = nil;
	id token = [effect.notifier addObserverForName:@"FxFactory::ProductUpdate" object:nil queue:nil
										usingBlock:^(NSNotification *note) { posted = note.userInfo; }];

	__block NSDictionary *handled = nil;
	[mock showProductUpdates:^(NSDictionary *response) { handled = response; }];
	[effect.notifier removeObserver:token];

	XCTAssertEqual(mock.showUpdatesCallCount, (NSUInteger)1);
	XCTAssertTrue(mock.recordedForce, @"the handler form forces the check");
	XCTAssertEqualObjects(mock.recordedVersion, @"4.5.6");
	XCTAssertEqualObjects(effect.productUpdateResponses, (@[@{@"answer": @42}]));
	XCTAssertEqualObjects(handled, (@{@"answer": @42}));
	XCTAssertEqualObjects(posted, (@{@"answer": @42}));
}

/*! @abstract The unforced update check runs without forcing and reports nothing when the response is nil. */
- (void)testTheUnforcedUpdateCheckIgnoresANilResponse
{
	FxGripFxFactoryStubEffect *effect = [FxGripFxFactoryStubEffect.alloc init];
	FxGripFxFactoryUpdateMock *mock = [FxGripFxFactoryUpdateMock.alloc init];
	mock.cannedResponse = nil;
	[mock extLoadWithEffect:(id)effect];

	[mock showProductUpdates];

	XCTAssertEqual(mock.showUpdatesCallCount, (NSUInteger)1);
	XCTAssertFalse(mock.recordedForce, @"the automatic check honors the postpone interval");
	XCTAssertEqual(effect.productUpdateResponses.count, (NSUInteger)0);
}

/*! @abstract The update-checking property reads the seam and its writer posts the state before applying it. */
- (void)testTheUpdateCheckingPropertyReadsAndWritesThroughTheSeam
{
	FxGripFxFactoryStubEffect *effect = [FxGripFxFactoryStubEffect.alloc init];
	FxGripFxFactoryUpdateMock *mock = [FxGripFxFactoryUpdateMock.alloc init];
	[mock extLoadWithEffect:(id)effect];

	mock.updateCheckingEnabled = YES;
	XCTAssertTrue([mock pluginIsUpdateChecking]);

	__block NSDictionary *posted = nil;
	id token = [effect.notifier addObserverForName:@"FxFactory::IsUpdateChecking" object:nil queue:nil
										usingBlock:^(NSNotification *note) { posted = note.userInfo; }];
	[mock setPluginIsUpdateChecking:NO];
	[effect.notifier removeObserver:token];

	XCTAssertEqualObjects(mock.updateCheckingWrites, (@[@NO]));
	XCTAssertEqualObjects(posted, (@{@"enabled": @NO}));
}

#pragma mark Licensing actions

/*! @abstract Showing the product and starting the buy flow post their notification and request the matching licensing action. */
- (void)testTheProductAndBuyFlowsRequestTheirLicensingAction
{
	FxGripFxFactoryStubEffect *effect = [FxGripFxFactoryStubEffect.alloc init];
	FxGripFxFactoryActionMock *mock = [FxGripFxFactoryActionMock.alloc init];
	mock.actionResult = YES;
	[mock extLoadWithEffect:(id)effect];

	NSMutableArray<NSString *> *names = NSMutableArray.new;
	id show = [effect.notifier addObserverForName:@"FxFactory::ShowProduct" object:nil queue:nil
									   usingBlock:^(NSNotification *note) { [names addObject:note.name]; }];
	id buy = [effect.notifier addObserverForName:@"FxFactory::ShowBuy" object:nil queue:nil
									  usingBlock:^(NSNotification *note) { [names addObject:note.name]; }];

	XCTAssertTrue([mock showFxFactoryProduct]);
	XCTAssertTrue([mock showFxFactoryBuyPlugin]);

	[effect.notifier removeObserver:show];
	[effect.notifier removeObserver:buy];

	// kFxFactoryLicensingActionShow is 1 << 0 and kFxFactoryLicensingActionBuy is 1 << 1.
	XCTAssertEqualObjects(mock.actions, (@[@1, @2]));
	XCTAssertEqualObjects(names, (@[@"FxFactory::ShowProduct", @"FxFactory::ShowBuy"]));
}

/*! @abstract The contact form refuses to send when the FxFactory form is unavailable. */
- (void)testTheContactFormRefusesWhenTheFormIsUnavailable
{
	FxGripFxFactoryNoContactFormMock *mock = [FxGripFxFactoryNoContactFormMock.alloc init];
	XCTAssertFalse([mock showContactForm:@"support@fxfactory.com" subject:@"s" message:@"m"]);
	XCTAssertEqual(mock.contactRecipients.count, (NSUInteger)0);
}

/*! @abstract The recipient-free contact form sends with an empty recipient and posts the form payload. */
- (void)testTheRecipientFreeContactFormSendsWithAnEmptyRecipient
{
	FxGripFxFactoryStubEffect *effect = [FxGripFxFactoryStubEffect.alloc init];
	FxGripFxFactoryMock *mock = [FxGripFxFactoryMock.alloc init];
	[mock extLoadWithEffect:(id)effect];

	__block NSDictionary *posted = nil;
	id token = [effect.notifier addObserverForName:@"FxFactory::ContactForm" object:nil queue:nil
										usingBlock:^(NSNotification *note) { posted = note.userInfo; }];
	XCTAssertTrue([mock showContactForm:@"Subject" message:@"Message"]);
	[effect.notifier removeObserver:token];

	XCTAssertEqualObjects(mock.contactRecipients, (@[@""]));
	XCTAssertEqualObjects(posted[@"FxFactoryValue::Recipient"], @"");
	XCTAssertEqualObjects(posted[@"FxFactoryValue::Subject"], @"Subject");
	XCTAssertEqualObjects(posted[@"FxFactoryValue::Message"], @"Message");
}

/*! @abstract The FxFactory version property reports what the SDK version seam returns. */
- (void)testTheVersionPropertyReportsTheSeamVersion
{
	FxGripFxFactoryVersionMock *mock = [FxGripFxFactoryVersionMock.alloc init];
	FxGripFxFactoryTestVersion version = [mock fxFactoryVersion];

	XCTAssertEqual(version.major, (NSUInteger)7);
	XCTAssertEqual(version.minor, (NSUInteger)1);
	XCTAssertEqual(version.patch, (NSUInteger)4);
}

/*! @abstract The unguarded version seam reports a zero version when FxFactory is absent. */
- (void)testTheVersionSeamReportsZeroWithoutFxFactory
{
	FxGripFxFactory *factory = [NSClassFromString(@"FxGripFxFactory") alloc];
	factory = [factory init];
	FxGripFxFactoryTestVersion version = [factory factoryVersion];

	if (![factory fxFactoryIsInstalled]) {
		XCTAssertEqual(version.major, (NSUInteger)0);
		XCTAssertEqual(version.minor, (NSUInteger)0);
		XCTAssertEqual(version.patch, (NSUInteger)0);
	} else {
		XCTAssertGreaterThan(version.major, (NSUInteger)0,
							 @"an installed FxFactory reports a real version");
	}
}

#pragma mark The parameter type factory

/*! @abstract The extension maps the fxfactory type string to its parameter type and back to its own class. */
- (void)testTheExtensionMapsTheFxFactoryParameterType
{
	FxParameterType type = [self.factory extParameterTypeForString:@"fxfactory"];

	XCTAssertEqual(type, (FxParameterType)'FxFy');
	XCTAssertEqual([self.factory extParameterClassForType:type], NSClassFromString(@"FxGripFxFactory"));
}

/*! @abstract An unrecognized type string maps to None and an unrecognized type maps to no class. */
- (void)testAnUnrecognizedParameterTypeMapsToNothing
{
	XCTAssertEqual([self.factory extParameterTypeForString:@"toggle"], FxParameterType_None);
	XCTAssertEqual([self.factory extParameterTypeForString:nil], FxParameterType_None);
	XCTAssertNil([self.factory extParameterClassForType:FxParameterType_Toggle]);
}

#pragma mark The response dictionary accessors

/*! Skips the test when FxFactory is not installed, so its weak-linked response keys resolve. */
- (NSString *)responseKeyOrSkip:(const char *)symbol
{
	NSString *key = FxGripFxFactoryTestResponseKey(symbol);
	if (key == nil) {
		XCTSkip(@"the FxFactory response keys are weak-linked constants and FxFactory is not installed");
	}
	return key;
}

/*! @abstract The update-response flags report their Boolean value and default to NO when absent or mistyped. */
- (void)testTheUpdateResponseFlagsCoerceTheirValues
{
	NSString *enabled = [self responseKeyOrSkip:"kFxFactoryUpdateCheckingEnabled"];
	NSString *postponed = [self responseKeyOrSkip:"kFxFactoryUpdateCheckingPostponed"];
	NSString *newVersion = [self responseKeyOrSkip:"kFxFactoryUpdateCheckingNewVersionFound"];

	NSDictionary *response = @{enabled: @YES, postponed: @YES, newVersion: @YES};
	XCTAssertTrue(response.fxFactoryUpdateCheckingEnabled);
	XCTAssertTrue(response.fxFactoryUpdateCheckingPostponed);
	XCTAssertTrue(response.fxFactoryUpdateCheckingNewVersionFound);

	NSDictionary *mistyped = @{enabled: @"YES", postponed: @"YES", newVersion: @"YES"};
	XCTAssertFalse(mistyped.fxFactoryUpdateCheckingEnabled);
	XCTAssertFalse(mistyped.fxFactoryUpdateCheckingPostponed);
	XCTAssertFalse(mistyped.fxFactoryUpdateCheckingNewVersionFound);

	XCTAssertFalse(@{}.fxFactoryUpdateCheckingEnabled);
	XCTAssertFalse(@{}.fxFactoryUpdateCheckingPostponed);
	XCTAssertFalse(@{}.fxFactoryUpdateCheckingNewVersionFound);
}

/*! @abstract The update-response error and product info are returned only when they carry the expected type. */
- (void)testTheUpdateResponseErrorAndProductInfoAreTypeChecked
{
	NSString *errorKey = [self responseKeyOrSkip:"kFxFactoryUpdateCheckingError"];
	NSString *productKey = [self responseKeyOrSkip:"kFxFactoryUpdateCheckingProductInfo"];

	NSError *error = [NSError errorWithDomain:@"FxGripFxFactoryTests" code:1 userInfo:nil];
	NSDictionary *response = @{errorKey: error, productKey: @{@"name": @"Product"}};
	XCTAssertEqualObjects(response.fxFactoryUpdateCheckingError, error);
	XCTAssertEqualObjects(response.fxFactoryUpdateCheckingProductInfo, (@{@"name": @"Product"}));

	NSDictionary *mistyped = @{errorKey: @"not an error", productKey: @"not a dictionary"};
	XCTAssertNil(mistyped.fxFactoryUpdateCheckingError);
	XCTAssertNil(mistyped.fxFactoryUpdateCheckingProductInfo);

	XCTAssertNil(@{}.fxFactoryUpdateCheckingError);
	XCTAssertNil(@{}.fxFactoryUpdateCheckingProductInfo);
}

/*! @abstract The product info accessors return their typed value and a safe default when absent or mistyped. */
- (void)testTheProductInfoAccessorsCoerceTheirValues
{
	NSString *name = [self responseKeyOrSkip:"kFxFactoryLicensingProductName"];
	NSString *latest = [self responseKeyOrSkip:"kFxFactoryLicensingProductLatestVersion"];
	NSString *requiredOS = [self responseKeyOrSkip:"kFxFactoryLicensingProductLatestVersionRequiredOSVersion"];
	NSString *requiredFx = [self responseKeyOrSkip:"kFxFactoryLicensingProductLatestVersionRequiredFxFactoryVersion"];
	NSString *discontinued = [self responseKeyOrSkip:"kFxFactoryLicensingProductIsDiscontinued"];
	NSString *price = [self responseKeyOrSkip:"kFxFactoryLicensingProductPriceInUSD"];

	NSDictionary *info = @{name: @"Product", latest: @"2.0", requiredOS: @"14.0",
						   requiredFx: @"8.0", discontinued: @YES, price: @49.5f};
	XCTAssertEqualObjects(info.fxFactoryProductName, @"Product");
	XCTAssertEqualObjects(info.fxFactoryProductLatestVersion, @"2.0");
	XCTAssertEqualObjects(info.fxFactoryProductLatestVersionRequiredOSVersion, @"14.0");
	XCTAssertEqualObjects(info.fxFactoryProductLatestVersionRequiredFxFactoryVersion, @"8.0");
	XCTAssertTrue(info.fxFactoryProductIsDiscontinued);
	XCTAssertEqualWithAccuracy(info.fxFactoryProductPriceInUSD, 49.5f, 0.001);

	NSDictionary *mistyped = @{name: @1, latest: @1, requiredOS: @1,
							   requiredFx: @1, discontinued: @"YES", price: @"49.5"};
	XCTAssertNil(mistyped.fxFactoryProductName);
	XCTAssertNil(mistyped.fxFactoryProductLatestVersion);
	XCTAssertNil(mistyped.fxFactoryProductLatestVersionRequiredOSVersion);
	XCTAssertNil(mistyped.fxFactoryProductLatestVersionRequiredFxFactoryVersion);
	XCTAssertFalse(mistyped.fxFactoryProductIsDiscontinued);
	XCTAssertTrue(isnan(mistyped.fxFactoryProductPriceInUSD), @"an absent price reads as NAN");

	XCTAssertNil(@{}.fxFactoryProductName);
	XCTAssertTrue(isnan(@{}.fxFactoryProductPriceInUSD));
}

#pragma mark Parameter registration

- (NSArray<NSMutableDictionary *> *)parametersAddedByFactory:(FxGripFxFactory *)factory
													seededBy:(NSMutableDictionary *)seed
{
	NSMutableArray *parameters = seed ? @[seed].mutableCopy : NSMutableArray.new;
	[factory extAddParameters:[NSNotification notificationWithName:FxGripTileableEffectAddParametersName
															object:nil
														  userInfo:@{FxGripTileableEffectParametersKey: parameters}]];
	return parameters;
}

/*! @abstract An unconfigured fxfactory parameter grows the full set of FxFactory support parameters. */
- (void)testAnUnconfiguredFactoryParameterAddsEverySupportParameter
{
	FxGripFxFactoryStubEffect *effect = [FxGripFxFactoryStubEffect.alloc init];
	FxGripFxFactoryMock *factory = [FxGripFxFactoryMock.alloc init];
	[factory extLoadWithEffect:(id)effect];

	NSMutableDictionary *seed = @{kFxParameterProperty_Type: @"fxfactory",
								  kFxParameterProperty_ParentId: @0,
								  kPropertiesFxFactoryActive: @YES}.mutableCopy;
	NSArray<NSMutableDictionary *> *parameters = [self parametersAddedByFactory:factory seededBy:seed];

	XCTAssertEqualObjects(parameters.firstObject[kFxParameterProperty_Type], kFxParameterType_Toggle,
						  @"the fxfactory entry becomes the licensing toggle");
	XCTAssertEqualObjects(parameters.firstObject[kFxParameterProperty_Name], @"FxFactory Product Licensed");
	XCTAssertEqual((id)parameters.firstObject[kFxParameterProperty_Factory], (id)factory);

	// The declared entry is configured in place; the extension-system path registers the array
	// as-is, so a repeat would register the same parameter twice.
	XCTAssertTrue(parameters.firstObject == seed, @"the declared entry keeps its position");
	for (NSUInteger index = 1; index < parameters.count; index++) {
		XCTAssertFalse(parameters[index] == seed, @"the declared entry is not appended again");
	}

	NSMutableArray<NSNumber *> *ids = NSMutableArray.new;
	for (NSMutableDictionary *parameter in parameters) {
		if (![ids containsObject:parameter[kFxParameterProperty_Id]]) {
			[ids addObject:parameter[kFxParameterProperty_Id]];
		}
	}
	// The licensing toggle plus the product UUID, product version, watermark, buy button and
	// its label, product button and its label, and update checking.
	const FxParameterId base = kFxParameterId_FxFactoryLicense;
	XCTAssertEqualObjects(ids, (@[@(base), @(base + 2), @(base + 3), @(base + 4), @(base + 5),
								  @(base + 6), @(base + 7), @(base + 8), @(base + 9)]),
						  @"the support parameters carry the licensing toggle's ID plus their offset");
}

/*! @abstract A fully hard-coded settings object adds only the licensing toggle. */
- (void)testHardCodedSettingsAddOnlyTheLicensingToggle
{
	FxGripFxFactoryStubEffect *effect = [FxGripFxFactoryStubEffect.alloc init];
	FxGripFxFactoryMock *factory = [FxGripFxFactoryMock.alloc init];
	[factory extLoadWithEffect:(id)effect];
	[factory setFxFactorySettingsObject:(id)[FxGripFxFactoryFullSettingsMock.alloc init]];

	NSArray<NSMutableDictionary *> *parameters = [self parametersAddedByFactory:factory seededBy:nil];

	XCTAssertEqual(parameters.count, (NSUInteger)1);
	XCTAssertEqualObjects([factory fxFactoryPluginUUID], @"full-uuid");
	XCTAssertEqualObjects([factory fxFactoryPluginVersion], @"9.9.9");
	XCTAssertTrue([factory fxFactoryHasActive]);
	XCTAssertTrue([factory fxFactoryHasPluginProduct]);
}

/*! @abstract An explicitly deactivated integration adds nothing beyond the licensing toggle it was given. */
- (void)testADeactivatedIntegrationStopsAfterTheLicensingToggle
{
	FxGripFxFactoryMock *factory = [FxGripFxFactoryMock.alloc init];
	NSMutableDictionary *seed = @{kFxParameterProperty_Type: @"fxfactory",
								  kFxParameterProperty_ParentId: @0,
								  kPropertiesFxFactoryActive: @NO}.mutableCopy;
	NSArray<NSMutableDictionary *> *parameters = [self parametersAddedByFactory:factory seededBy:seed];

	XCTAssertEqual(parameters.count, (NSUInteger)1, @"the seeded entry alone survives");
	XCTAssertTrue([factory fxFactoryHasActive]);
	XCTAssertFalse([factory fxFactoryActive]);
}

/*! @abstract The parameter's own ID, name, and description are kept, and the enforcement flags are applied. */
- (void)testTheConfiguredParameterKeepsItsIdentityAndGainsTheEnforcementFlags
{
	FxGripFxFactoryMock *factory = [FxGripFxFactoryMock.alloc init];
	NSMutableDictionary *seed = @{kFxParameterProperty_Type: @"fxfactory",
								  kFxParameterProperty_Id: @400,
								  kFxParameterProperty_ParentId: @0,
								  kFxParameterProperty_Name: @"My License",
								  kFxParameterProperty_Description: @"My Integration",
								  kPropertiesFxFactoryActive: @YES,
								  kFxParameterProperty_Flags: @[kParameterFlagString_HIDDEN]}.mutableCopy;
	NSArray<NSMutableDictionary *> *parameters = [self parametersAddedByFactory:factory seededBy:seed];

	NSMutableDictionary *toggle = parameters.firstObject;
	XCTAssertEqualObjects(toggle[kFxParameterProperty_Name], @"My License");
	XCTAssertEqualObjects(toggle[kFxParameterProperty_Description], @"My Integration");
	XCTAssertEqual([factory parameterID], (FxParameterId)400);
	XCTAssertEqualObjects(toggle[kFxParameterProperty_Flags],
						  (@[kParameterFlagString_HIDDEN, kParameterFlagString_NOT_ANIMATABLE,
							 kParameterFlagString_PRESETNOMETA, kParameterFlagString_NO_DEBUG]),
						  @"the enforcement flags are applied once, in order");
	XCTAssertEqualObjects(parameters[1][kFxParameterProperty_Id], @(400 + 2),
						  @"the support parameters follow the toggle's ID");
}

/*! @abstract The product identity falls back to the plugin properties, and a Boolean entry there means the plugin's own UUID and version. */
- (void)testTheProductIdentityFallsBackToThePluginProperties
{
	FxGripFxFactoryStubEffect *effect = [FxGripFxFactoryStubEffect.alloc init];
	effect.pluginProperties = @{kPropertiesFxFactoryPluginUUID: @"property-uuid",
								kPropertiesFxFactoryPluginVersion: @"property-version"};
	FxGripFxFactoryMock *named = [FxGripFxFactoryMock.alloc init];
	[named extLoadWithEffect:(id)effect];
	NSMutableDictionary *seed = @{kFxParameterProperty_Type: @"fxfactory",
								  kFxParameterProperty_ParentId: @0,
								  kPropertiesFxFactoryActive: @YES}.mutableCopy;
	[self parametersAddedByFactory:named seededBy:seed];

	XCTAssertEqualObjects([named fxFactoryPluginUUID], @"property-uuid");
	XCTAssertEqualObjects([named fxFactoryPluginVersion], @"property-version");

	FxGripFxFactoryStubEffect *ownIdentity = [FxGripFxFactoryStubEffect.alloc init];
	ownIdentity.pluginProperties = @{kPropertiesFxFactoryPluginUUID: @YES,
									 kPropertiesFxFactoryPluginVersion: @YES};
	FxGripFxFactoryMock *inherited = [FxGripFxFactoryMock.alloc init];
	[inherited extLoadWithEffect:(id)ownIdentity];
	NSMutableDictionary *ownSeed = @{kFxParameterProperty_Type: @"fxfactory",
									 kFxParameterProperty_ParentId: @0,
									 kPropertiesFxFactoryActive: @YES}.mutableCopy;
	[self parametersAddedByFactory:inherited seededBy:ownSeed];

	XCTAssertEqualObjects([inherited fxFactoryPluginUUID], @"stub-plugin-uuid",
						  @"a Boolean entry means the plugin's own UUID");
	XCTAssertEqualObjects([inherited fxFactoryPluginVersion], @"1.2.3",
						  @"a Boolean entry means the plugin's own version");
}

/*! @abstract A product identity declared on the parameter suppresses the UUID and version parameters. */
- (void)testADeclaredProductIdentitySuppressesTheIdentityParameters
{
	FxGripFxFactoryMock *factory = [FxGripFxFactoryMock.alloc init];
	NSMutableDictionary *seed = @{kFxParameterProperty_Type: @"fxfactory",
								  kFxParameterProperty_ParentId: @0,
								  kPropertiesFxFactoryActive: @YES,
								  kPropertiesFxFactoryPluginUUID: @"declared-uuid",
								  kPropertiesFxFactoryPluginVersion: @"5.0.0"}.mutableCopy;
	NSArray<NSMutableDictionary *> *parameters = [self parametersAddedByFactory:factory seededBy:seed];

	XCTAssertTrue([factory fxFactoryHasPluginProduct]);
	XCTAssertEqualObjects([factory fxFactoryPluginUUID], @"declared-uuid");
	XCTAssertEqualObjects([factory fxFactoryPluginVersion], @"5.0.0");

	NSMutableArray<NSNumber *> *ids = NSMutableArray.new;
	for (NSMutableDictionary *parameter in parameters) {
		if (![ids containsObject:parameter[kFxParameterProperty_Id]]) {
			[ids addObject:parameter[kFxParameterProperty_Id]];
		}
	}
	// The licensing toggle plus the watermark, buy button and label, product button and label,
	// and update checking; the UUID and version parameters are suppressed.
	const FxParameterId base = kFxParameterId_FxFactoryLicense;
	XCTAssertEqualObjects(ids, (@[@(base), @(base + 4), @(base + 5), @(base + 6),
								  @(base + 7), @(base + 8), @(base + 9)]));
}

/*! @abstract A named product with no explicit active state activates the integration, enables the watermark, and locks the configuration writers. */
- (void)testANamedProductActivatesTheIntegrationAndLocksTheWriters
{
	FxGripFxFactoryStubEffect *effect = [FxGripFxFactoryStubEffect.alloc init];
	FxGripFxFactoryMock *factory = [FxGripFxFactoryMock.alloc init];
	[factory extLoadWithEffect:(id)effect];
	[factory setFxFactorySettingsObject:(id)[FxGripFxFactoryProductOnlySettingsMock.alloc init]];

	NSMutableDictionary *seed = @{kFxParameterProperty_Type: @"fxfactory",
								  kFxParameterProperty_Id: @0,
								  kFxParameterProperty_ParentId: @0}.mutableCopy;
	[self parametersAddedByFactory:factory seededBy:seed];
	[factory parameterForDictionary:seed];

	XCTAssertFalse([factory fxFactoryHasActive]);
	XCTAssertTrue([factory fxFactoryHasPluginProduct]);
	XCTAssertTrue([factory fxFactoryActive], @"a named product activates the integration");
	XCTAssertTrue([factory fxFactoryWaterMarkUnlicensed], @"a named product watermarks by default");

	XCTAssertFalse([factory fxFactoryShowBuyButton], @"a named product shows no buy button by default");
	XCTAssertFalse([factory fxFactoryShowProductButton]);
	XCTAssertFalse([factory fxFactoryAutoChecking]);

	[effect.stubParameters removeAllObjects];
	[factory setFxFactoryWaterMarkUnlicensed:NO];
	[factory setFxFactoryShowBuyButton:YES];
	[factory setFxFactoryShowProductButton:YES];
	[factory setFxFactoryAutoChecking:YES];
	XCTAssertEqual(effect.stubParameters.count, (NSUInteger)0,
				   @"a named product presets the configuration, so the writers refuse");
}

/*! @abstract A configuration that declares neither an active state nor a product adds the hidden FxFactory Active toggle. */
- (void)testAnUndeclaredActiveStateAddsTheHiddenActiveToggle
{
	FxGripFxFactoryStubEffect *effect = [FxGripFxFactoryStubEffect.alloc init];
	FxGripFxFactoryMock *factory = [FxGripFxFactoryMock.alloc init];
	[factory extLoadWithEffect:(id)effect];

	NSMutableDictionary *seed = @{kFxParameterProperty_Type: @"fxfactory",
								  kFxParameterProperty_Id: @0,
								  kFxParameterProperty_ParentId: @0}.mutableCopy;
	NSArray<NSMutableDictionary *> *parameters = [self parametersAddedByFactory:factory seededBy:seed];

	XCTAssertFalse([factory fxFactoryHasActive]);
	XCTAssertFalse([factory fxFactoryHasPluginProduct]);
	XCTAssertFalse([factory fxFactoryActive], @"the integration waits for the Active toggle");

	NSMutableDictionary *activeParameter = nil;
	for (NSMutableDictionary *parameter in parameters) {
		if ([parameter[kFxParameterProperty_Name] isEqualToString:@"FxFactory Active"]) {
			activeParameter = parameter;
		}
	}
	XCTAssertNotNil(activeParameter, @"the active state needs a parameter to live in");
	XCTAssertEqualObjects(activeParameter[kFxParameterProperty_Id], @1);
	XCTAssertEqualObjects(activeParameter[kFxParameterProperty_Type], kFxParameterType_Toggle);
	XCTAssertEqualObjects(activeParameter[kFxParameterProperty_Flags],
						  (@[kParameterFlagString_HIDDEN, kParameterFlagString_NOT_ANIMATABLE,
							 kParameterFlagString_PRESETNOMETA]),
						  @"licensing enforcement is not a user control");
}

/*! @abstract A product declared only in the plugin properties activates the integration without a declared active state. */
- (void)testAProductInThePluginPropertiesActivatesTheIntegration
{
	FxGripFxFactoryStubEffect *effect = [FxGripFxFactoryStubEffect.alloc init];
	effect.pluginProperties = @{kPropertiesFxFactoryPluginUUID: @"properties-product-uuid"};
	FxGripFxFactoryMock *factory = [FxGripFxFactoryMock.alloc init];
	[factory extLoadWithEffect:(id)effect];

	NSArray<NSMutableDictionary *> *parameters = [self parametersAddedByFactory:factory seededBy:nil];

	XCTAssertFalse([factory fxFactoryHasActive]);
	XCTAssertTrue([factory fxFactoryHasPluginProduct]);
	XCTAssertEqualObjects([factory fxFactoryPluginUUID], @"properties-product-uuid");
	XCTAssertTrue([factory fxFactoryActive], @"a named product activates the integration");
	XCTAssertEqualObjects(parameters.firstObject[kFxParameterProperty_Name], @"FxFactory Product Licensed");
	XCTAssertGreaterThan(parameters.count, (NSUInteger)1, @"the support parameters are added");
}

/*! @abstract A configuration that declares the integration inactive stops before adding any support parameter. */
- (void)testAnExplicitlyInactiveIntegrationAddsNoSupportParameters
{
	FxGripFxFactoryStubEffect *effect = [FxGripFxFactoryStubEffect.alloc init];
	effect.pluginProperties = @{kPropertiesFxFactoryPluginUUID: @"ignored-product-uuid"};
	FxGripFxFactoryMock *factory = [FxGripFxFactoryMock.alloc init];
	[factory extLoadWithEffect:(id)effect];
	NSMutableDictionary *seed = @{kFxParameterProperty_Type: @"fxfactory",
								  kFxParameterProperty_Id: @0,
								  kFxParameterProperty_ParentId: @0,
								  kPropertiesFxFactoryActive: @NO}.mutableCopy;

	NSArray<NSMutableDictionary *> *parameters = [self parametersAddedByFactory:factory seededBy:seed];

	XCTAssertEqual(parameters.count, (NSUInteger)1, @"only the declared entry remains");
	XCTAssertTrue(parameters.firstObject == seed);
	XCTAssertFalse([factory fxFactoryHasPluginProduct], @"an inactive integration resolves no product");
	XCTAssertFalse([factory fxFactoryActive]);
}

/*! @abstract A missing fxfactory entry is created and appended exactly once, alongside each support parameter once. */
- (void)testACreatedLicensingToggleIsAppendedOnce
{
	FxGripFxFactoryStubEffect *effect = [FxGripFxFactoryStubEffect.alloc init];
	FxGripFxFactoryMock *factory = [FxGripFxFactoryMock.alloc init];
	[factory extLoadWithEffect:(id)effect];

	NSArray<NSMutableDictionary *> *parameters = [self parametersAddedByFactory:factory seededBy:nil];

	NSMutableSet<NSNumber *> *ids = NSMutableSet.new;
	NSUInteger licensingToggles = 0;
	for (NSMutableDictionary *parameter in parameters) {
		XCTAssertFalse([ids containsObject:parameter[kFxParameterProperty_Id]],
					   @"parameter %@ is added once", parameter[kFxParameterProperty_Id]);
		[ids addObject:parameter[kFxParameterProperty_Id]];
		if ([parameter[kFxParameterProperty_Name] isEqualToString:@"FxFactory Product Licensed"]) {
			licensingToggles += 1;
		}
	}
	XCTAssertEqual(licensingToggles, (NSUInteger)1);
	XCTAssertEqualObjects(parameters.firstObject[kFxParameterProperty_Factory], factory);
	for (NSUInteger index = 1; index < parameters.count; index++) {
		XCTAssertEqualObjects(parameters[index][kFxParameterProperty_ParentId], @(kFxParameterId_TopLevelGroup),
							  @"an undeclared parent places the support parameters at the top level");
	}
}

/*! @abstract The support parameters join the group the declared fxfactory parameter belongs to. */
- (void)testTheSupportParametersShareTheDeclaredParent
{
	FxGripFxFactoryMock *factory = [FxGripFxFactoryMock.alloc init];
	NSMutableDictionary *seed = @{kFxParameterProperty_Type: @"fxfactory",
								  kFxParameterProperty_Id: @500,
								  kFxParameterProperty_ParentId: @77,
								  kPropertiesFxFactoryActive: @YES}.mutableCopy;

	NSArray<NSMutableDictionary *> *parameters = [self parametersAddedByFactory:factory seededBy:seed];

	XCTAssertGreaterThan(parameters.count, (NSUInteger)1);
	for (NSUInteger index = 1; index < parameters.count; index++) {
		XCTAssertEqualObjects(parameters[index][kFxParameterProperty_ParentId], @77);
	}
}

#pragma mark Parameter changes

/*! @abstract A change to the licensing toggle is reverted to the true license status. */
- (void)testAChangeToTheLicensingToggleIsReverted
{
	FxGripFxFactoryStubEffect *effect = [FxGripFxFactoryStubEffect.alloc init];
	FxGripFxFactoryDocumentMock *mock = [FxGripFxFactoryDocumentMock.alloc init];
	mock.mockStatus = FxGripFxFactoryTestStatusLicensed;
	[mock extLoadWithEffect:(id)effect];
	[mock setBoolValue:NO];

	[mock extParameterChanged:[NSNotification notificationWithName:FxGripTileableEffectParameterChangedName
															object:nil
														  userInfo:@{FxGripTileableEffectParameterChangedIDKey: @0}]];

	XCTAssertTrue(mock.recordedBoolValue, @"the toggle is restored to the licensed status");
}

/*! @abstract Toggling the FxFactory active parameter registers the licensing handler and switching it off unregisters it. */
- (void)testTogglingTheActiveParameterRegistersAndUnregistersTheHandler
{
	FxGripFxFactoryStubEffect *effect = [FxGripFxFactoryStubEffect.alloc init];
	FxGripFxFactoryHandlerMock *mock = [FxGripFxFactoryHandlerMock.alloc init];
	[mock extLoadWithEffect:(id)effect];
	[mock setFxFactoryPluginUUID:@"active-uuid"];
	// The integration is hard-coded active, so the active parameter drives the handler
	// registration alone rather than also gating the change handler.
	[self activateFactory:mock];

	NSNotification *change = [NSNotification notificationWithName:FxGripTileableEffectParameterChangedName
														   object:nil
														 userInfo:@{FxGripTileableEffectParameterChangedIDKey: @1}];
	[effect stubParameterForID:1].boolValue = YES;
	[mock extParameterChanged:change];
	XCTAssertEqualObjects(mock.unregisteredUUIDs, @[], @"the first registration tears nothing down");

	[effect stubParameterForID:1].boolValue = NO;
	[mock extParameterChanged:change];
	XCTAssertEqualObjects(mock.unregisteredUUIDs, (@[@"active-uuid"]));
}

/*! @abstract A button label change renames the button that precedes it. */
- (void)testAButtonLabelChangeRenamesItsButton
{
	FxGripFxFactoryStubEffect *effect = [FxGripFxFactoryStubEffect.alloc init];
	FxGripFxFactoryMock *mock = [FxGripFxFactoryMock.alloc init];
	[mock extLoadWithEffect:(id)effect];
	[self activateFactory:mock];

	// Offsets from the licensing toggle: buy button 5, buy label 6, product button 7,
	// product label 8.
	[effect stubParameterForID:6].stringValue = @"Buy Now...";
	[effect stubParameterForID:8].stringValue = @"Open Product...";

	for (NSNumber *labelID in @[@6, @8]) {
		[mock extParameterChanged:[NSNotification notificationWithName:FxGripTileableEffectParameterChangedName
																object:nil
															  userInfo:@{FxGripTileableEffectParameterChangedIDKey: labelID}]];
	}

	XCTAssertEqualObjects([effect stubParameterForID:5].parameterName, @"Buy Now...");
	XCTAssertEqualObjects([effect stubParameterForID:7].parameterName, @"Open Product...");
}

/*! @abstract A change to the update-checking parameter applies the new state through the seam. */
- (void)testAnUpdateCheckingChangeAppliesTheNewState
{
	FxGripFxFactoryStubEffect *effect = [FxGripFxFactoryStubEffect.alloc init];
	FxGripFxFactoryUpdateMock *mock = [FxGripFxFactoryUpdateMock.alloc init];
	[mock extLoadWithEffect:(id)effect];
	[self activateFactory:mock];

	[effect stubParameterForID:9].boolValue = YES;
	[mock extParameterChanged:[NSNotification notificationWithName:FxGripTileableEffectParameterChangedName
															object:nil
														  userInfo:@{FxGripTileableEffectParameterChangedIDKey: @9}]];

	XCTAssertEqualObjects(mock.updateCheckingWrites, (@[@YES]));
}

/*! @abstract An inactive integration ignores every parameter change and skips the document-add pass. */
- (void)testAnInactiveIntegrationIgnoresChangesAndTheDocumentAdd
{
	FxGripFxFactoryStubEffect *effect = [FxGripFxFactoryStubEffect.alloc init];
	FxGripFxFactoryUpdateMock *mock = [FxGripFxFactoryUpdateMock.alloc init];
	[self addFactory:mock toEffect:effect];
	XCTAssertFalse([mock fxFactoryActive], @"nothing declares the integration active");

	[effect stubParameterForID:9].boolValue = YES;
	[mock extParameterChanged:[NSNotification notificationWithName:FxGripTileableEffectParameterChangedName
															object:nil
														  userInfo:@{FxGripTileableEffectParameterChangedIDKey: @9}]];
	[mock extAddedToDocument:[NSNotification notificationWithName:@"added" object:effect userInfo:nil]];

	XCTAssertEqualObjects(mock.updateCheckingWrites, @[]);
	XCTAssertEqual(mock.showUpdatesCallCount, (NSUInteger)0);
}

#pragma mark The watermark render

/*! @abstract A failed watermark render leaves the frame unmarked rather than aborting the render. */
- (void)testAFailedWatermarkRenderLeavesTheFrameUnmarked
{
	FxGripFxFactoryFailingWatermarkMock *mock = [FxGripFxFactoryFailingWatermarkMock.alloc init];
	mock.mockStatus = FxGripFxFactoryTestStatusUnlicensed;

	NSNotification *note = [NSNotification notificationWithName:@"render"
														object:nil
													  userInfo:@{FxGripTileableEffectRenderDestinationImageKey: NSObject.new}];
	XCTAssertNoThrow([mock extRenderDestinationImage:note]);
	XCTAssertEqual(mock.renderCount, (NSUInteger)1);
}

/*! @abstract The watermark seam draws the plugin's display name onto a real destination tile. */
- (void)testTheWatermarkSeamRendersOntoARealDestinationTile
{
	id<MTLDevice> device = MTLCreateSystemDefaultDevice();
	if (device == nil) {
		XCTSkip(@"no Metal device");
	}
	FxImageTile *tile = [FxImageTile stubTileWithPixelBounds:(FxRect){0, 0, 64, 64}
												 pixelFormat:kCVPixelFormatType_32BGRA
													  device:device];
	if (tile == nil) {
		XCTSkip(@"the destination tile could not be created");
	}

	FxGripFxFactoryStubEffect *effect = [FxGripFxFactoryStubEffect.alloc init];
	effect.pluginDisplayName = @"Watermarked Plugin";
	FxGripFxFactoryMock *mock = [FxGripFxFactoryMock.alloc init];
	[mock extLoadWithEffect:(id)effect];

	NSError *error = nil;
	XCTAssertTrue([mock renderWatermarkOntoImage:tile error:&error], @"%@", error);
	XCTAssertNil(error);
}

#pragma mark The effect-side accessors

/*! @abstract An effect that installs the FxFactory extension resolves it and reports its product identity. */
- (void)testAnEffectResolvesItsInstalledFxFactoryExtension
{
	FxGripFxFactoryHostEffect *effect = [FxGripFxFactoryHostEffect.alloc initWithAPIManager:(id _Nonnull)nil];

	XCTAssertNotNil(effect.fxFactory);
	XCTAssertEqualObjects(effect.fxFactoryPluginUUID, @"host-effect-uuid");
	XCTAssertFalse(effect.fxFactoryPluginLicensed, @"the mock reports the product unlicensed");

	[(FxGripFxFactory *)effect.fxFactory setFxFactoryPluginVersion:@"6.6.6"];
	XCTAssertEqualObjects(effect.fxFactoryPluginVersion, @"6.6.6");
}

/*! @abstract A licensing status change applies the matching license state to the effect. */
- (void)testALicensingStatusChangeAppliesTheLicenseStateToTheEffect
{
	FxGripFxFactoryHostEffect *effect = [FxGripFxFactoryHostEffect.alloc initWithAPIManager:(id _Nonnull)nil];

	[effect onFxFactoryRegisterLicensingStatusChange:FxGripFxFactoryTestStatusLicensed];
	XCTAssertEqual(effect.licenseStateCallCount, (NSUInteger)1);
	XCTAssertTrue(effect.recordedLicenseState);

	[effect onFxFactoryRegisterLicensingStatusChange:FxGripFxFactoryTestStatusUnlicensed];
	XCTAssertEqual(effect.licenseStateCallCount, (NSUInteger)2);
	XCTAssertFalse(effect.recordedLicenseState);
}

#pragma mark The licensing status callback

/*! @abstract The registered licensing callback caches the new status, mirrors it into the toggle, applies the license state, and posts the change. */
- (void)testTheLicensingCallbackCachesAppliesAndBroadcastsTheNewStatus
{
	FxGripFxFactoryStubEffect *effect = [FxGripFxFactoryStubEffect.alloc init];
	FxGripFxFactoryCallbackMock *mock = [FxGripFxFactoryCallbackMock.alloc init];
	mock.mockStatus = FxGripFxFactoryTestStatusUnlicensed;
	[mock extLoadWithEffect:(id)effect];
	[self addFactory:mock toEffect:effect];
	[mock registerLicenseHandler:@"callback-uuid"];
	XCTAssertNotNil(mock.capturedHandler);

	__block NSDictionary *posted = nil;
	id token = [effect.notifier addObserverForName:@"FxFactory::LicenseChange" object:nil queue:nil
										usingBlock:^(NSNotification *note) { posted = note.userInfo; }];
	mock.capturedHandler(FxGripFxFactoryTestStatusLicensed, mock);
	[effect.notifier removeObserver:token];

	XCTAssertTrue([mock pluginIsLicensed], @"the callback status replaces the cached verdict");
	XCTAssertTrue(effect.licenseStateApplied);
	XCTAssertTrue(effect.appliedLicenseState);
	XCTAssertEqualObjects(posted, (@{@"FxFactoryValue::Status": @(FxGripFxFactoryTestStatusLicensed)}));
}

/*! @abstract A callback reporting an unlicensed product applies the unlicensed state. */
- (void)testTheLicensingCallbackAppliesAnUnlicensedStatus
{
	FxGripFxFactoryStubEffect *effect = [FxGripFxFactoryStubEffect.alloc init];
	FxGripFxFactoryCallbackMock *mock = [FxGripFxFactoryCallbackMock.alloc init];
	mock.mockStatus = FxGripFxFactoryTestStatusLicensed;
	[mock extLoadWithEffect:(id)effect];
	[self addFactory:mock toEffect:effect];
	[mock registerLicenseHandler:@"callback-uuid"];

	mock.capturedHandler(FxGripFxFactoryTestStatusUnlicensed, mock);

	XCTAssertFalse([mock pluginIsLicensed]);
	XCTAssertTrue(effect.licenseStateApplied);
	XCTAssertFalse(effect.appliedLicenseState);
}

/*! @abstract Registering with an empty or absent product UUID installs no handler. */
- (void)testRegisteringWithoutAProductUUIDInstallsNoHandler
{
	FxGripFxFactoryCallbackMock *mock = [FxGripFxFactoryCallbackMock.alloc init];

	[mock registerLicenseHandler:nil];
	XCTAssertNil(mock.capturedHandler);

	[mock registerLicenseHandler:@""];
	XCTAssertNil(mock.capturedHandler, @"an empty product names no product to observe");
}

#pragma mark Load and render guards

/*! @abstract An absent FxFactory installation loads the extension but leaves it disconnected. */
- (void)testAnAbsentFxFactoryLoadsTheExtensionDisconnected
{
	FxGripFxFactoryStubEffect *effect = [FxGripFxFactoryStubEffect.alloc init];
	effect.reportsExtensionClass = YES;
	FxGripFxFactoryAbsentMock *mock = [FxGripFxFactoryAbsentMock.alloc init];

	XCTAssertFalse([mock fxFactoryIsInstalled]);
	XCTAssertTrue([mock extLoadWithEffect:(id)effect],
				  @"the extension loads, and the regression pass is skipped with FxFactory absent");
}

/*! @abstract The render handler passes the watermark decision and then stops on a notification carrying no destination image. */
- (void)testTheRenderHandlerStopsOnAMissingDestinationImage
{
	FxGripFxFactoryFailingWatermarkMock *mock = [FxGripFxFactoryFailingWatermarkMock.alloc init];
	mock.mockStatus = FxGripFxFactoryTestStatusUnlicensed;

	NSNotification *note = [NSNotification notificationWithName:@"render" object:nil userInfo:@{}];
	XCTAssertNoThrow([mock extRenderDestinationImage:note]);

	XCTAssertEqual(mock.renderCount, (NSUInteger)0, @"there is nothing to watermark");
}

/*! @abstract An active integration ignores a parameter change carrying no parameter ID. */
- (void)testAnActiveIntegrationIgnoresAChangeWithoutAParameterID
{
	FxGripFxFactoryStubEffect *effect = [FxGripFxFactoryStubEffect.alloc init];
	FxGripFxFactoryUpdateMock *mock = [FxGripFxFactoryUpdateMock.alloc init];
	[mock extLoadWithEffect:(id)effect];
	[self activateFactory:mock];

	XCTAssertNoThrow([mock extParameterChanged:
					  [NSNotification notificationWithName:FxGripTileableEffectParameterChangedName
													object:nil
												  userInfo:@{}]]);
	XCTAssertEqualObjects(mock.updateCheckingWrites, @[]);
}

/*! @abstract The regression check reads the plug-in's own main bundle by default. */
- (void)testTheRegressionCheckReadsTheMainBundleByDefault
{
	FxGripFxFactory *factory = [NSClassFromString(@"FxGripFxFactory") alloc];
	factory = [factory init];

	XCTAssertEqual((id)[factory fxFactoryRegressionBundle], (id)NSBundle.mainBundle);
}

#pragma mark The read-only FxFactory SDK seams

// Only the seams that read state are driven against a live FxFactory. The seams that
// perform a licensing action, start an update check, write the update-checking preference,
// or open the contact form drive real UI, network, and preference side effects, so they are
// left to a live host.

/*! @abstract The licensing status seam reports a status for a product that FxFactory does not know. */
- (void)testTheLicensingStatusSeamReportsAStatusForAnUnknownProduct
{
	FxGripFxFactory *factory = [NSClassFromString(@"FxGripFxFactory") alloc];
	factory = [factory init];

	NSUInteger status = [factory factoryLicensingStatusForProduct:@"FXGRIP-TEST-UNKNOWN-PRODUCT"];

	XCTAssertNotEqual(status, FxGripFxFactoryTestStatusLicensed,
					  @"a product FxFactory does not know is never reported licensed");
}

/*! @abstract The update-checking seam reports checking off for a product FxFactory does not know. */
- (void)testTheUpdateCheckingSeamReportsOffForAnUnknownProduct
{
	FxGripFxFactory *factory = [NSClassFromString(@"FxGripFxFactory") alloc];
	factory = [factory init];

	XCTAssertFalse([factory factoryUpdateCheckingEnabledForProduct:@"FXGRIP-TEST-UNKNOWN-PRODUCT"]);
}

/*! @abstract Registering and unregistering a licensing handler through the SDK seams leaves no handler behind. */
- (void)testTheHandlerRegistrationSeamsRegisterAndUnregister
{
	FxGripFxFactory *factory = [NSClassFromString(@"FxGripFxFactory") alloc];
	factory = [factory init];

	[factory registerLicenseHandler:@"FXGRIP-TEST-UNKNOWN-PRODUCT"];
	XCTAssertNoThrow([factory unregisterLicenseHandler]);
	// A second unregister is a no-op: the handler reference was cleared by the first.
	XCTAssertNoThrow([factory unregisterLicenseHandler]);
}

/*! @abstract An effect with no FxFactory extension resolves none, and the default license and update hooks are inert. */
- (void)testAnEffectWithoutTheExtensionResolvesNoneAndTheDefaultHooksAreInert
{
	FxGripFxFactoryPlainEffect *effect = [FxGripFxFactoryPlainEffect.alloc initWithAPIManager:(id _Nonnull)nil];

	XCTAssertNil(effect.fxFactory);
	XCTAssertNil(effect.fxFactoryPluginUUID);
	XCTAssertNil(effect.fxFactoryPluginVersion);

	XCTAssertNoThrow([effect setFxFactoryLicenseState:YES], @"the default license hook is an empty override point");
	XCTAssertNoThrow([effect onFxFactoryShowProductUpdates:@{}], @"the default update hook is an empty override point");
	XCTAssertNoThrow([effect onFxFactoryRegisterLicensingStatusChange:FxGripFxFactoryTestStatusLicensed]);

	XCTAssertTrue([[effect newFxFactoryExtension] isKindOfClass:NSClassFromString(@"FxGripFxFactory")]);
}

@end
