/*!
	@file       FxGripLicensingTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-03
	@header     FxGripLicensingTests
	@abstract   Unit tests for the store-neutral FxGripLicensing extension.
	@discussion Introduced in FxGrip 0.1.0. A mock provider adopts every optional capability and a minimal provider adopts none, so the tests cover capability-gated parameters, settings precedence, the toggle reversion, the status pipeline from a provider callback, the watermark decision per status, the debug overrides, the update and action routing, the host configuration check, and the provider registry.
*/

#import <XCTest/XCTest.h>
#import <Metal/Metal.h>
#import <CoreVideo/CoreVideo.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripParameter.h>
#import <FxGrip/FxGripParameterFlags.h>
#import <FxGrip/FxGripExtension.h>
#import <FxGrip/FxGripLicensing.h>
#import <FxGrip/FxGripTileableEffect.h>
#import <FxGrip/FxGripTileableEffect+Extensions.h>
#import <FxGrip/FxGripTileableEffect+Notifications.h>
#import "FxPlugStub.h"

#pragma mark - Providers

/*! A provider that adopts every optional capability and records each call. */
@interface FxGripLicensingMockProvider : NSObject <FxGripLicensingProvider>
@property (nonatomic, assign) FxGripLicenseStatus status;
@property (nonatomic, assign) BOOL available;
@property (nonatomic, strong) NSMutableArray<NSString *> *startedProducts;
@property (nonatomic, strong) NSMutableArray<NSString *> *stoppedProducts;
@property (nonatomic, copy) FxGripLicenseStatusHandler handler;
@property (nonatomic, strong) NSMutableArray<NSString *> *actions;
@property (nonatomic, assign) BOOL actionResult;
@property (nonatomic, copy) NSDictionary *cannedUpdateInfo;
@property (nonatomic, assign) BOOL recordedForce;
@property (nonatomic, copy) NSString *recordedVersion;
@property (nonatomic, assign) NSUInteger updateCheckCount;
@property (nonatomic, assign) BOOL updateCheckingEnabled;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *updateCheckingWrites;
@property (nonatomic, copy) NSArray<NSString *> *hostProblems;
@property (nonatomic, strong) NSBundle *checkedBundle;
@property (nonatomic, assign) FxGripLicenseStatus deactivateStatus;
@property (nonatomic, strong) NSError *deactivateError;
@property (nonatomic, strong) dispatch_queue_t completionQueue;
@property (nonatomic, strong) FxGripLicenseEntitlement *entitlement;
@property (nonatomic, copy) NSString *supportSubject;
@property (nonatomic, assign) FxGripLicenseStatus versionStatus;
@property (nonatomic, assign) NSOperatingSystemVersion recordedVersionQuery;
@property (nonatomic, assign) NSUInteger versionQueries;
@property (nonatomic, assign) BOOL upgradable;
@property (nonatomic, copy) NSDictionary *cannedProductInfo;
@property (nonatomic, strong) NSError *cannedProductInfoError;
@end

@implementation FxGripLicensingMockProvider

- (instancetype)init
{
	self = [super init];
	if (self) {
		_status = FxGripLicenseStatusUnlicensed;
		_available = YES;
		_startedProducts = NSMutableArray.new;
		_stoppedProducts = NSMutableArray.new;
		_actions = NSMutableArray.new;
		_actionResult = YES;
		_updateCheckingWrites = NSMutableArray.new;
		_hostProblems = @[];
		_deactivateStatus = FxGripLicenseStatusUnlicensed;
	}
	return self;
}

- (NSString *)providerName { return @"mock"; }
- (BOOL)isAvailable { return self.available; }
- (FxGripLicenseStatus)licenseStatusForProduct:(NSString *)productID { return self.status; }

- (void)startObservingProduct:(NSString *)productID handler:(FxGripLicenseStatusHandler)handler
{
	[self.startedProducts addObject:productID];
	self.handler = handler;
}

- (void)stopObservingProduct:(NSString *)productID
{
	[self.stoppedProducts addObject:productID];
	self.handler = nil;
}

- (FxGripLicenseEntitlement *)entitlementForProduct:(NSString *)productID { return self.entitlement; }

- (FxGripLicenseStatus)licenseStatusForProduct:(NSString *)productID version:(NSOperatingSystemVersion)version
{
	self.versionQueries += 1;
	self.recordedVersionQuery = version;
	return self.versionStatus;
}

- (BOOL)upgradeAvailableForProduct:(NSString *)productID { return self.upgradable; }

- (void)fetchProductInfoForProduct:(NSString *)productID handler:(FxGripLicenseProductInfoHandler)handler
{
	handler(self.cannedProductInfo, self.cannedProductInfoError);
}

- (BOOL)buyProduct:(NSString *)productID { [self.actions addObject:@"buy"]; return self.actionResult; }
- (BOOL)showProduct:(NSString *)productID { [self.actions addObject:@"show"]; return self.actionResult; }
- (BOOL)showLicenseEntryForProduct:(NSString *)productID { [self.actions addObject:@"enter"]; return self.actionResult; }

- (BOOL)updateCheckingEnabledForProduct:(NSString *)productID { return self.updateCheckingEnabled; }
- (void)setUpdateCheckingEnabled:(BOOL)enabled forProduct:(NSString *)productID { [self.updateCheckingWrites addObject:@(enabled)]; }

- (void)checkForUpdatesForProduct:(NSString *)productID version:(NSString *)version force:(BOOL)force handler:(FxGripLicenseUpdateInfoHandler)handler
{
	self.updateCheckCount += 1;
	self.recordedForce = force;
	self.recordedVersion = version;
	if (handler && self.cannedUpdateInfo) {
		handler(self.cannedUpdateInfo);
	}
}

- (BOOL)showSupportFormWithSubject:(NSString *)subject message:(NSString *)message
{
	self.supportSubject = subject;
	[self.actions addObject:@"support"];
	return self.actionResult;
}

- (void)activateLicenseKey:(NSString *)key forProduct:(NSString *)productID completion:(FxGripLicenseCompletion)completion
{
	completion(FxGripLicenseStatusLicensed, nil);
}

- (void)validateLicenseForProduct:(NSString *)productID completion:(FxGripLicenseCompletion)completion
{
	completion(self.status, nil);
}

- (void)deactivateLicenseForProduct:(NSString *)productID completion:(FxGripLicenseCompletion)completion
{
	[self.actions addObject:@"deactivate"];
	if (self.completionQueue) {
		dispatch_async(self.completionQueue, ^{ completion(self.deactivateStatus, self.deactivateError); });
	} else {
		completion(self.deactivateStatus, self.deactivateError);
	}
}

- (NSArray<NSString *> *)hostConfigurationProblemsForBundle:(NSBundle *)bundle
{
	self.checkedBundle = bundle;
	return self.hostProblems;
}

@end

/*! A provider with only the required methods, so no capability-gated parameter is added. */
@interface FxGripLicensingMinimalProvider : NSObject <FxGripLicensingProvider>
@property (nonatomic, assign) FxGripLicenseStatus status;
@end

@implementation FxGripLicensingMinimalProvider
- (NSString *)providerName { return @"minimal"; }
- (BOOL)isAvailable { return YES; }
- (FxGripLicenseStatus)licenseStatusForProduct:(NSString *)productID { return self.status; }
- (void)startObservingProduct:(NSString *)productID handler:(FxGripLicenseStatusHandler)handler {}
- (void)stopObservingProduct:(NSString *)productID {}
@end

#pragma mark - Effect doubles

/*! A parameter stand-in the extension reads and writes through the effect subscript. */
@interface FxGripLicensingStubParameter : NSObject
@property (nonatomic, assign) BOOL boolValue;
@property (nonatomic, copy) NSString *stringValue;
@property (nonatomic, copy) NSString *parameterName;
@property (nonatomic, assign) BOOL flagHidden;
@property (nonatomic, assign) NSUInteger boolWriteCount;
@end

@implementation FxGripLicensingStubParameter
- (void)setBoolValue:(BOOL)boolValue
{
	_boolValue = boolValue;
	_boolWriteCount += 1;
}
@end

/*! A stub effect: plugin properties, the notifier, the regression gate, the parameter subscript,
	and the (Licensing) category hooks, answered as plain methods. */
@interface FxGripLicensingStubEffect : NSObject
@property (nonatomic, strong) NSDictionary<NSString *, id> *pluginProperties;
@property (nonatomic, assign) BOOL reportsExtensionClass;
@property (nonatomic, copy) NSString *pluginUUID;
@property (nonatomic, copy) NSString *pluginStringVersion;
@property (nonatomic, copy) NSString *pluginDisplayName;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *statusChanges;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *updateInfos;
@property (nonatomic, strong, readonly) NSMutableDictionary<NSNumber *, FxGripLicensingStubParameter *> *stubParameters;
- (FxGripLicensingStubParameter *)stubParameterForID:(NSInteger)parameterID;
@end

@implementation FxGripLicensingStubEffect {
	NSNotificationCenter *_notifier;
}

- (instancetype)init
{
	self = [super init];
	if (self) {
		Class cls = NSClassFromString(@"NSPriorityNotificationCenter");
		_notifier = [[cls alloc] init];
		_pluginProperties = @{};
		_pluginUUID = @"stub-plugin-uuid";
		_pluginStringVersion = @"1.2.3";
		_pluginDisplayName = @"Stub Plugin";
		_statusChanges = NSMutableArray.new;
		_updateInfos = NSMutableArray.new;
		_stubParameters = NSMutableDictionary.new;
	}
	return self;
}

- (id)effectBase { return self; }
- (NSNotificationCenter *)notifier { return _notifier; }
- (BOOL)hasExtensionClass:(Class)cls { return self.reportsExtensionClass; }
- (void)licensingStatusDidChange:(FxGripLicenseStatus)status { [self.statusChanges addObject:@(status)]; }
- (void)licensingDidReceiveUpdateInfo:(NSDictionary *)info { [self.updateInfos addObject:info]; }

- (FxGripLicensingStubParameter *)stubParameterForID:(NSInteger)parameterID
{
	FxGripLicensingStubParameter *parameter = self.stubParameters[@(parameterID)];
	if (parameter == nil) {
		parameter = [FxGripLicensingStubParameter.alloc init];
		self.stubParameters[@(parameterID)] = parameter;
	}
	return parameter;
}

- (id)objectAtIndexedSubscript:(NSInteger)index { return [self stubParameterForID:index]; }

// The status pipeline opens an out-of-band parameter access, which reads the manager's
// custom-action API; a hostless stub reports none and the access stays inert.
- (id)apiManager { return nil; }

@end

/*! A stub effect that declares the settings conformance, so the extension falls back to it. */
@interface FxGripLicensingSettingsEffect : FxGripLicensingStubEffect <FxGripLicensingSettings>
@end
@implementation FxGripLicensingSettingsEffect
- (BOOL)licensingActive { return YES; }
@end

#pragma mark - Settings doubles

@interface FxGripLicensingInactiveSettings : NSObject
@end
@implementation FxGripLicensingInactiveSettings
- (BOOL)licensingActive { return NO; }
@end

/*! Hard-codes every setting; buttons off, so a minimal provider leaves only the toggle. */
@interface FxGripLicensingFullSettings : NSObject
@end
@implementation FxGripLicensingFullSettings
- (BOOL)licensingActive { return YES; }
- (NSString *)licensingProductID { return @"full-product"; }
- (NSString *)licensingProductVersion { return @"9.9.9"; }
- (BOOL)licensingWatermarkUnlicensed { return YES; }
- (BOOL)licensingWatermarkTrial { return YES; }
- (BOOL)licensingShowBuyButton { return NO; }
- (BOOL)licensingShowProductButton { return NO; }
- (BOOL)licensingAutoChecking { return YES; }
@end

@interface FxGripLicensingProductOnlySettings : NSObject
@end
@implementation FxGripLicensingProductOnlySettings
- (NSString *)licensingProductID { return @"product-only"; }
@end

@interface FxGripLicensingWatermarkSettings : NSObject
@property (nonatomic, assign) BOOL watermark;
@property (nonatomic, strong) FxGripWatermarkConfiguration *trialConfiguration;
@end
@implementation FxGripLicensingWatermarkSettings
- (BOOL)licensingActive { return YES; }
- (NSString *)licensingProductID { return @"settings-product"; }
- (BOOL)licensingWatermarkUnlicensed { return self.watermark; }
- (FxGripWatermarkConfiguration *)licensingTrialWatermarkConfiguration { return self.trialConfiguration; }
@end

#pragma mark - Extension doubles

/*! Records the toggle writes and the watermark renders, so the pipeline runs without a host or a GPU. */
@interface FxGripLicensingRecordingExtension : FxGripLicensing
@property (nonatomic, assign) BOOL recordedBoolValue;
@property (nonatomic, assign) NSUInteger boolWriteCount;
@property (nonatomic, assign) NSUInteger renderCount;
@property (nonatomic, assign) BOOL renderResult;
@property (nonatomic, strong) FxGripWatermarkConfiguration *renderedConfiguration;
@property (nonatomic, strong) NSBundle *bundleOverride;
@end

@implementation FxGripLicensingRecordingExtension
- (instancetype)initWithProvider:(id<FxGripLicensingProvider>)provider
{
	self = [super initWithProvider:provider];
	if (self) {
		_renderResult = YES;
	}
	return self;
}
- (void)setBoolValue:(BOOL)value { self.recordedBoolValue = value; self.boolWriteCount += 1; }
- (BOOL)boolValue { return self.recordedBoolValue; }
- (BOOL)renderWatermark:(FxGripWatermarkConfiguration *)configuration ontoImage:(FxImageTile *)destinationImage error:(NSError *_Nullable *_Nullable)outError
{
	self.renderCount += 1;
	self.renderedConfiguration = configuration;
	if (!self.renderResult && outError) {
		*outError = [NSError errorWithDomain:@"FxGripLicensingTests" code:7 userInfo:nil];
	}
	return self.renderResult;
}
- (NSBundle *)hostConfigurationBundle { return self.bundleOverride ?: [super hostConfigurationBundle]; }
@end

/*! Watermarks OfflineGrace too, to show the per-status seam is overridable. */
@interface FxGripLicensingGraceWatermarkExtension : FxGripLicensingRecordingExtension
@end
@implementation FxGripLicensingGraceWatermarkExtension
- (FxGripWatermarkConfiguration *)watermarkConfigurationForStatus:(FxGripLicenseStatus)status
{
	if (status == FxGripLicenseStatusOfflineGrace) {
		return [FxGripWatermarkConfiguration configurationWithText:@"GRACE"];
	}
	return [super watermarkConfigurationForStatus:status];
}
@end

/*! A real effect that installs the extension with a mock provider. */
@interface FxGripLicensingHostEffect : FxGripTileableEffect
@property (nonatomic, strong) FxGripLicensingMockProvider *mockProvider;
@property (nonatomic, assign) NSUInteger licenseStateCallCount;
@property (nonatomic, assign) BOOL recordedLicenseState;
@end

@implementation FxGripLicensingHostEffect
- (NSMutableArray<id<FxGripExtension>> *)loadExtensions
{
	NSMutableArray<id<FxGripExtension>> *extensions = [super loadExtensions];
	self.mockProvider = [FxGripLicensingMockProvider.alloc init];
	[extensions addObject:[FxGripLicensing.alloc initWithProvider:self.mockProvider]];
	return extensions;
}
- (void)setLicenseState:(BOOL)licensed
{
	self.recordedLicenseState = licensed;
	self.licenseStateCallCount += 1;
}
@end

@interface FxGripLicensingPlainEffect : FxGripTileableEffect
@end
@implementation FxGripLicensingPlainEffect
@end

#pragma mark - Tests

@interface FxGripLicensingTests : XCTestCase
@property (nonatomic, strong) FxGripLicensingMockProvider *provider;
@property (nonatomic, strong) FxGripLicensingRecordingExtension *licensing;
@property (nonatomic, strong) FxGripLicensingStubEffect *effect;
@end

@implementation FxGripLicensingTests

- (void)setUp
{
	[super setUp];
	self.provider = [FxGripLicensingMockProvider.alloc init];
	self.licensing = [FxGripLicensingRecordingExtension.alloc initWithProvider:self.provider];
	self.effect = [FxGripLicensingStubEffect.alloc init];
}

#pragma mark Helpers

- (NSNotification *)addParametersNotification:(NSMutableArray *)parameters
{
	return [NSNotification notificationWithName:FxGripTileableEffectAddParametersName object:nil
									   userInfo:@{FxGripTileableEffectParametersKey: parameters}];
}

- (NSNotification *)changeNotification:(NSInteger)parameterID
{
	return [NSNotification notificationWithName:FxGripTileableEffectParameterChangedName object:nil
									   userInfo:@{FxGripTileableEffectParameterChangedIDKey: @(parameterID)}];
}

- (NSNotification *)renderNotification
{
	// A non-nil placeholder passes the destination-image guard; the recording seam records
	// the call rather than touching the GPU.
	return [NSNotification notificationWithName:@"render" object:nil
									   userInfo:@{FxGripTileableEffectRenderDestinationImageKey: NSObject.new}];
}

- (NSArray<NSMutableDictionary *> *)parametersAddedBy:(FxGripLicensing *)licensing seededBy:(NSMutableDictionary *)seed
{
	NSMutableArray *parameters = seed ? @[seed].mutableCopy : NSMutableArray.new;
	[licensing extAddParameters:[self addParametersNotification:parameters]];
	return parameters;
}

- (NSArray<NSNumber *> *)idsOf:(NSArray<NSMutableDictionary *> *)parameters
{
	NSMutableArray<NSNumber *> *ids = NSMutableArray.new;
	for (NSMutableDictionary *parameter in parameters) {
		if (![ids containsObject:parameter[kFxParameterProperty_Id]]) {
			[ids addObject:parameter[kFxParameterProperty_Id]];
		}
	}
	return ids;
}

- (NSMutableDictionary *)parameterNamed:(NSString *)name in:(NSArray<NSMutableDictionary *> *)parameters
{
	for (NSMutableDictionary *parameter in parameters) {
		if ([parameter[kFxParameterProperty_Name] isEqualToString:name]) {
			return parameter;
		}
	}
	return nil;
}

/*! Marks the extension as added to an effect, the state the property writers require. */
- (void)add:(FxGripLicensing *)licensing to:(FxGripLicensingStubEffect *)effect
{
	[licensing extLoadWithEffect:(id)effect];
	[licensing parameterForDictionary:@{kFxParameterProperty_Id: @0,
										kFxParameterProperty_Type: kFxParameterType_Toggle,
										kFxParameterProperty_Name: @"Product Licensed"}];
}

/*! Registers the extension against a parameter that hard-codes the integration active, so the
	licensing toggle sits at parameter 0 and the change handlers run. */
- (void)activate:(FxGripLicensing *)licensing
{
	NSMutableDictionary *seed = @{kFxParameterProperty_Type: kFxParameterType_Licensing,
								  kFxParameterProperty_Id: @0,
								  kFxParameterProperty_ParentId: @0,
								  kFxGripLicensingProperty_Active: @YES}.mutableCopy;
	[self parametersAddedBy:licensing seededBy:seed];
	[licensing parameterForDictionary:@{kFxParameterProperty_Id: @0,
										kFxParameterProperty_Type: kFxParameterType_Toggle,
										kFxParameterProperty_Name: @"Product Licensed"}];
	XCTAssertTrue(licensing.licensingActive);
}

- (void)addedToDocument:(FxGripLicensing *)licensing
{
	[licensing extAddedToDocument:[NSNotification notificationWithName:@"added" object:self.effect userInfo:nil]];
}

#pragma mark Dispatch

/*! @abstract The extension responds to the single-notification dispatch selectors for parameters, changes, document add, and render. */
- (void)testTheExtensionRespondsToTheNotificationSelectors
{
	XCTAssertTrue([self.licensing respondsToSelector:@selector(extAddParameters:)]);
	XCTAssertTrue([self.licensing respondsToSelector:@selector(extParameterChanged:)]);
	XCTAssertTrue([self.licensing respondsToSelector:@selector(extAddedToDocument:)]);
	XCTAssertTrue([self.licensing respondsToSelector:@selector(extRenderDestinationImage:)]);
}

/*! @abstract A configuration that declares the integration inactive adds no parameters to the list. */
- (void)testAnInactiveConfigurationAddsNoParameters
{
	[self.licensing setSettingsObject:(id)[FxGripLicensingInactiveSettings.alloc init]];
	NSMutableArray *parameters = NSMutableArray.new;
	XCTAssertNoThrow([self.licensing extAddParameters:[self addParametersNotification:parameters]]);
	XCTAssertEqual(parameters.count, (NSUInteger)0);
}

/*! @abstract The change and render handlers ignore a notification missing its payload. */
- (void)testHandlersIgnoreANotificationWithoutAPayload
{
	[self activate:self.licensing];
	XCTAssertNoThrow([self.licensing extParameterChanged:[NSNotification notificationWithName:FxGripTileableEffectParameterChangedName object:nil userInfo:@{}]]);
	XCTAssertNoThrow([self.licensing extRenderDestinationImage:[NSNotification notificationWithName:@"render" object:nil userInfo:@{}]]);
	XCTAssertEqual(self.licensing.renderCount, (NSUInteger)0, @"there is nothing to watermark");
}

#pragma mark Status

/*! @abstract isLicensed follows the provider: Licensed, Trial, and OfflineGrace unlock; the rest do not. */
- (void)testIsLicensedFollowsTheProviderStatus
{
	NSDictionary<NSNumber *, NSNumber *> *expectations = @{
		@(FxGripLicenseStatusUnknown): @NO, @(FxGripLicenseStatusInvalidProduct): @NO,
		@(FxGripLicenseStatusUnlicensed): @NO, @(FxGripLicenseStatusLicensed): @YES,
		@(FxGripLicenseStatusTrial): @YES, @(FxGripLicenseStatusExpired): @NO,
		@(FxGripLicenseStatusOfflineGrace): @YES, @(FxGripLicenseStatusRevoked): @NO,
	};
	for (NSNumber *status in expectations) {
		FxGripLicensingMockProvider *provider = [FxGripLicensingMockProvider.alloc init];
		provider.status = status.integerValue;
		FxGripLicensing *licensing = [FxGripLicensing.alloc initWithProvider:provider];
		XCTAssertEqual(licensing.licenseStatus, status.integerValue);
		XCTAssertEqual(licensing.isLicensed, expectations[status].boolValue, @"status %@", status);
		XCTAssertEqual(FxGripLicenseStatusIsLicensed(status.integerValue), expectations[status].boolValue);
	}
}

/*! @abstract Without a provider the status is Unknown, nothing is licensed, and every action returns NO. */
- (void)testAMissingProviderLeavesTheExtensionInert
{
	FxGripLicensing *licensing = [FxGripLicensing.alloc init];
	XCTAssertNil(licensing.provider);
	XCTAssertEqual(licensing.licenseStatus, FxGripLicenseStatusUnknown);
	XCTAssertFalse(licensing.isLicensed);
	XCTAssertNil(licensing.entitlement);
	XCTAssertFalse([licensing buyProduct]);
	XCTAssertFalse([licensing showProduct]);
	XCTAssertFalse([licensing showLicenseEntry]);
	XCTAssertFalse([licensing showSupportFormWithSubject:@"s" message:@"m"]);
	XCTAssertNoThrow([licensing deactivateLicense]);
	XCTAssertNoThrow([licensing checkForUpdates]);
	XCTAssertEqualObjects([licensing hostConfigurationProblems], @[]);
	XCTAssertTrue([licensing extLoadWithEffect:(id)self.effect], @"the extension loads disconnected");
}

/*! @abstract The status is cached after the first read until the provider reports a change. */
- (void)testTheStatusIsCachedUntilTheProviderReports
{
	self.provider.status = FxGripLicenseStatusLicensed;
	XCTAssertTrue(self.licensing.isLicensed);
	self.provider.status = FxGripLicenseStatusUnlicensed;
	XCTAssertTrue(self.licensing.isLicensed, @"the cached verdict stands");
}

/*! @abstract The entitlement comes from the provider, and a provider without one reports nil. */
- (void)testTheEntitlementComesFromTheProvider
{
	self.provider.entitlement = [FxGripLicenseEntitlement entitlementWithProductID:@"p" providerName:@"mock" status:FxGripLicenseStatusLicensed];
	XCTAssertEqualObjects(self.licensing.entitlement, self.provider.entitlement);

	FxGripLicensing *minimal = [FxGripLicensing.alloc initWithProvider:[FxGripLicensingMinimalProvider.alloc init]];
	XCTAssertNil(minimal.entitlement);
}

/*! @abstract A declared licensed version routes the status query through the version-gated capability. */
- (void)testALicensedVersionGatesTheStatus
{
	self.provider.status = FxGripLicenseStatusLicensed;
	self.provider.versionStatus = FxGripLicenseStatusUnlicensed;
	[self.licensing extLoadWithEffect:(id)self.effect];
	[self parametersAddedBy:self.licensing seededBy:@{kFxParameterProperty_Type: kFxParameterType_Licensing,
														kFxGripLicensingProperty_ProductID: @"p",
														kFxGripLicensingProperty_LicensedVersion: @"2.1"}.mutableCopy];

	XCTAssertEqualObjects(self.licensing.licensedVersion, @"2.1");
	XCTAssertEqual(self.licensing.licenseStatus, FxGripLicenseStatusUnlicensed, @"a license for an earlier version does not cover this build");
	XCTAssertEqual(self.provider.versionQueries, (NSUInteger)1);
	XCTAssertEqual(self.provider.recordedVersionQuery.majorVersion, (NSInteger)2);
	XCTAssertEqual(self.provider.recordedVersionQuery.minorVersion, (NSInteger)1);
	XCTAssertEqual(self.provider.recordedVersionQuery.patchVersion, (NSInteger)0);

	// YES means the plugin's own version; a minimal provider ignores the gate.
	FxGripLicensing *own = [FxGripLicensing.alloc initWithProvider:self.provider];
	[own extLoadWithEffect:(id)self.effect];
	[self parametersAddedBy:own seededBy:@{kFxParameterProperty_Type: kFxParameterType_Licensing, kFxGripLicensingProperty_LicensedVersion: @YES}.mutableCopy];
	XCTAssertEqualObjects(own.licensedVersion, @"1.2.3");

	FxGripLicensingMinimalProvider *minimalProvider = [FxGripLicensingMinimalProvider.alloc init];
	minimalProvider.status = FxGripLicenseStatusLicensed;
	FxGripLicensing *minimal = [FxGripLicensing.alloc initWithProvider:minimalProvider];
	[minimal extLoadWithEffect:(id)self.effect];
	[self parametersAddedBy:minimal seededBy:@{kFxParameterProperty_Type: kFxParameterType_Licensing, kFxGripLicensingProperty_LicensedVersion: @"2.1"}.mutableCopy];
	XCTAssertEqual(minimal.licenseStatus, FxGripLicenseStatusLicensed, @"a provider without version gating reports the product's status");
	XCTAssertEqual([minimal licenseStatusForVersion:((NSOperatingSystemVersion){2, 0, 0})], FxGripLicenseStatusUnknown);
	XCTAssertFalse(minimal.upgradeAvailable);
}

/*! @abstract The version status and upgrade availability come from the provider. */
- (void)testVersionStatusAndUpgradeComeFromTheProvider
{
	self.provider.versionStatus = FxGripLicenseStatusLicensed;
	XCTAssertEqual([self.licensing licenseStatusForVersion:((NSOperatingSystemVersion){3, 0, 0})], FxGripLicenseStatusLicensed);
	XCTAssertEqual(self.provider.recordedVersionQuery.majorVersion, (NSInteger)3);
	XCTAssertFalse(self.licensing.upgradeAvailable);
	self.provider.upgradable = YES;
	XCTAssertTrue(self.licensing.upgradeAvailable);
}

/*! @abstract A product information fetch reports through the handler and the notification, carrying an error when the store fails. */
- (void)testAProductInfoFetchReportsThroughTheHandlerAndNotification
{
	[self add:self.licensing to:self.effect];
	self.provider.cannedProductInfo = @{FxGripLicensingProductInfoProductName: @"Product", FxGripLicensingProductInfoPriceUSD: @49.5};

	__block NSDictionary *posted = nil;
	id token = [self.effect.notifier addObserverForName:FxGripLicensingProductInfoName object:nil queue:nil
											 usingBlock:^(NSNotification *note) { posted = note.userInfo; }];
	__block NSDictionary *handled = nil;
	[self.licensing fetchProductInfo:^(NSDictionary *info, NSError *error) { handled = info; }];
	XCTAssertEqualObjects(handled, self.provider.cannedProductInfo);
	XCTAssertEqualObjects(posted, self.provider.cannedProductInfo);

	self.provider.cannedProductInfo = nil;
	self.provider.cannedProductInfoError = [NSError errorWithDomain:@"FxGripLicensingTests" code:9 userInfo:nil];
	__block NSError *handledError = nil;
	[self.licensing fetchProductInfo:^(NSDictionary *info, NSError *error) { handledError = error; }];
	[self.effect.notifier removeObserver:token];
	XCTAssertEqualObjects(handledError, self.provider.cannedProductInfoError);
	XCTAssertEqualObjects(posted[FxGripLicensingErrorKey], self.provider.cannedProductInfoError);

	FxGripLicensing *minimal = [FxGripLicensing.alloc initWithProvider:[FxGripLicensingMinimalProvider.alloc init]];
	__block BOOL called = NO;
	[minimal fetchProductInfo:^(NSDictionary *info, NSError *error) { called = YES; }];
	XCTAssertFalse(called, @"a provider without the capability reports nothing");
}

#pragma mark The status pipeline

/*! @abstract A status the provider reports is cached, mirrored into the toggle, applied to the effect, and posted with the status and provider name. */
- (void)testAProviderReportCachesAppliesAndBroadcastsTheStatus
{
	[self add:self.licensing to:self.effect];
	[self activate:self.licensing];
	[self.effect stubParameterForID:kParameterLicensingProductIDOffset].stringValue = @"stub-product";
	[self addedToDocument:self.licensing];
	XCTAssertEqualObjects(self.provider.startedProducts, @[@"stub-product"], @"an undeclared product reads its parameter");
	XCTAssertNotNil(self.provider.handler);

	__block NSDictionary *posted = nil;
	id token = [self.effect.notifier addObserverForName:FxGripLicensingStatusChangeName object:nil queue:nil
											 usingBlock:^(NSNotification *note) { posted = note.userInfo; }];
	self.provider.handler(FxGripLicenseStatusLicensed);
	[self.effect.notifier removeObserver:token];

	XCTAssertTrue(self.licensing.isLicensed, @"the reported status replaces the cached verdict");
	XCTAssertTrue(self.licensing.recordedBoolValue);
	XCTAssertEqualObjects(self.effect.statusChanges.lastObject, @(FxGripLicenseStatusLicensed));
	XCTAssertEqualObjects(posted[FxGripLicensingStatusKey], @(FxGripLicenseStatusLicensed));
	XCTAssertEqualObjects(posted[FxGripLicensingProviderNameKey], @"mock");
	XCTAssertNil(posted[FxGripLicensingEntitlementKey]);

	self.provider.handler(FxGripLicenseStatusRevoked);
	XCTAssertFalse(self.licensing.isLicensed);
	XCTAssertFalse(self.licensing.recordedBoolValue);
	XCTAssertEqualObjects(self.effect.statusChanges.lastObject, @(FxGripLicenseStatusRevoked));
}

/*! @abstract A report shows the Enter License button while unlicensed and the Deactivate button while licensed. */
- (void)testAProviderReportTogglesTheLicenseButtons
{
	[self add:self.licensing to:self.effect];
	[self activate:self.licensing];
	[self.effect stubParameterForID:kParameterLicensingProductIDOffset].stringValue = @"stub-product";
	[self addedToDocument:self.licensing];

	XCTAssertFalse([self.effect stubParameterForID:kParameterLicensingLicenseEntryButtonOffset].flagHidden);
	XCTAssertTrue([self.effect stubParameterForID:kParameterLicensingDeactivateButtonOffset].flagHidden);

	self.provider.handler(FxGripLicenseStatusLicensed);
	XCTAssertTrue([self.effect stubParameterForID:kParameterLicensingLicenseEntryButtonOffset].flagHidden);
	XCTAssertFalse([self.effect stubParameterForID:kParameterLicensingDeactivateButtonOffset].flagHidden);
}

/*! @abstract A completion that fires on another thread still applies the status. */
- (void)testACompletionOnABackgroundThreadAppliesTheStatus
{
	[self add:self.licensing to:self.effect];
	[self activate:self.licensing];
	self.provider.status = FxGripLicenseStatusLicensed;
	XCTAssertTrue(self.licensing.isLicensed);

	self.provider.completionQueue = dispatch_queue_create("FxGripLicensingTests.completion", DISPATCH_QUEUE_SERIAL);
	self.provider.deactivateStatus = FxGripLicenseStatusUnlicensed;
	XCTestExpectation *posted = [self expectationForNotification:FxGripLicensingStatusChangeName object:nil notificationCenter:self.effect.notifier handler:nil];
	[self.licensing deactivateLicense];
	[self waitForExpectations:@[posted] timeout:2.0];

	XCTAssertFalse(self.licensing.isLicensed);
	XCTAssertEqualObjects(self.provider.actions, @[@"deactivate"]);
}

/*! @abstract Observing a new product stops the previous observation under its own ID. */
- (void)testObservingANewProductStopsThePreviousOne
{
	[self add:self.licensing to:self.effect];
	[self activate:self.licensing];
	[self.effect stubParameterForID:kParameterLicensingProductIDOffset].stringValue = @"product-A";
	[self addedToDocument:self.licensing];

	[self.effect stubParameterForID:kParameterLicensingProductIDOffset].stringValue = @"product-B";
	[self.licensing extParameterChanged:[self changeNotification:kParameterLicensingProductIDOffset]];

	XCTAssertEqualObjects(self.provider.startedProducts, (@[@"product-A", @"product-B"]));
	XCTAssertEqualObjects(self.provider.stoppedProducts, @[@"product-A"], @"stop targets the ID the observation started with");
}

/*! @abstract Changing the product ID clears the cached verdict so it recomputes for the new product. */
- (void)testChangingTheProductIDInvalidatesTheCachedVerdict
{
	[self add:self.licensing to:self.effect];
	[self activate:self.licensing];
	self.provider.status = FxGripLicenseStatusLicensed;
	XCTAssertTrue(self.licensing.isLicensed, @"first read caches the verdict");

	self.provider.status = FxGripLicenseStatusUnlicensed;
	[self.licensing extParameterChanged:[self changeNotification:kParameterLicensingProductIDOffset]];
	XCTAssertFalse(self.licensing.isLicensed);
}

#pragma mark Document add

/*! @abstract Joining a document checks for updates, starts observing, and syncs the toggle to the status. */
- (void)testJoiningADocumentChecksUpdatesObservesAndSyncsTheToggle
{
	[self add:self.licensing to:self.effect];
	[self activate:self.licensing];
	[self.effect stubParameterForID:kParameterLicensingProductIDOffset].stringValue = @"stub-product";
	self.provider.status = FxGripLicenseStatusLicensed;

	[self addedToDocument:self.licensing];

	XCTAssertEqual(self.provider.updateCheckCount, (NSUInteger)1);
	XCTAssertFalse(self.provider.recordedForce, @"the automatic check honors the postpone interval");
	XCTAssertEqualObjects(self.provider.startedProducts, @[@"stub-product"]);
	XCTAssertTrue(self.licensing.recordedBoolValue, @"the toggle syncs to the licensed status");
	XCTAssertEqualObjects(self.effect.statusChanges, @[@(FxGripLicenseStatusLicensed)]);
}

/*! @abstract An empty product ID starts no observation. */
- (void)testAnEmptyProductStartsNoObservation
{
	[self add:self.licensing to:self.effect];
	[self activate:self.licensing];
	[self addedToDocument:self.licensing];
	XCTAssertEqualObjects(self.provider.startedProducts, @[]);
	XCTAssertNil(self.provider.handler);
}

/*! @abstract A toggle already matching the status is left alone and the effect hook does not run. */
- (void)testJoiningADocumentWithAMatchingToggleLeavesItAlone
{
	[self add:self.licensing to:self.effect];
	[self activate:self.licensing];
	self.provider.status = FxGripLicenseStatusUnlicensed;
	[self addedToDocument:self.licensing];
	XCTAssertEqual(self.licensing.boolWriteCount, (NSUInteger)0);
	XCTAssertEqual(self.effect.statusChanges.count, (NSUInteger)0);
}

#if DEBUG
/*! @abstract The debug licensed override forces the status over the provider's and applies the UI state. */
- (void)testTheDebugLicensedOverrideForcesTheStatus
{
	self.effect.pluginProperties = @{kPropertiesLicensingDebugSetLicensed: @YES};
	[self add:self.licensing to:self.effect];
	[self activate:self.licensing];
	self.provider.status = FxGripLicenseStatusUnlicensed;
	[self addedToDocument:self.licensing];

	XCTAssertTrue(self.licensing.isLicensed, @"the override drives isLicensed, not the provider");
	XCTAssertTrue(self.licensing.recordedBoolValue);
	XCTAssertEqualObjects(self.effect.statusChanges, @[@(FxGripLicenseStatusLicensed)]);

	FxGripLicensingRecordingExtension *other = [FxGripLicensingRecordingExtension.alloc initWithProvider:self.provider];
	FxGripLicensingStubEffect *effect = [FxGripLicensingStubEffect.alloc init];
	effect.pluginProperties = @{kPropertiesLicensingDebugSetLicensed: @NO};
	[self add:other to:effect];
	[self activate:other];
	self.provider.status = FxGripLicenseStatusLicensed;
	[other extAddedToDocument:[NSNotification notificationWithName:@"added" object:effect userInfo:nil]];
	XCTAssertFalse(other.isLicensed);
	XCTAssertEqualObjects(effect.statusChanges, @[@(FxGripLicenseStatusUnlicensed)]);
}

/*! @abstract The debug status override forces any status, so a trial watermark can be previewed. */
- (void)testTheDebugStatusOverrideForcesAnyStatus
{
	self.effect.pluginProperties = @{kPropertiesLicensingDebugSetStatus: @(FxGripLicenseStatusTrial)};
	[self add:self.licensing to:self.effect];
	[self activate:self.licensing];
	[self addedToDocument:self.licensing];

	XCTAssertEqual(self.licensing.licenseStatus, FxGripLicenseStatusTrial);
	XCTAssertTrue(self.licensing.isLicensed);
	XCTAssertEqualObjects(self.effect.statusChanges, @[@(FxGripLicenseStatusTrial)]);
}
#endif

#pragma mark The watermark decision

- (NSUInteger)renderCountForStatus:(FxGripLicenseStatus)status unlicensed:(BOOL)unlicensed trial:(BOOL)trial
{
	FxGripLicensingMockProvider *provider = [FxGripLicensingMockProvider.alloc init];
	provider.status = status;
	FxGripLicensingRecordingExtension *licensing = [FxGripLicensingRecordingExtension.alloc initWithProvider:provider];
	FxGripLicensingStubEffect *effect = [FxGripLicensingStubEffect.alloc init];
	[self add:licensing to:effect];
	[self activate:licensing];
	[effect stubParameterForID:kParameterLicensingWatermarkUnlicensedOffset].boolValue = unlicensed;
	[effect stubParameterForID:kParameterLicensingWatermarkTrialOffset].boolValue = trial;
	[licensing extRenderDestinationImage:[self renderNotification]];
	self.licensing = licensing;
	return licensing.renderCount;
}

/*! @abstract Unlicensed, Expired, Revoked, InvalidProduct, and Unknown carry the unlicensed watermark when it is on. */
- (void)testTheUnlicensedStatusesCarryTheUnlicensedWatermark
{
	for (NSNumber *status in @[@(FxGripLicenseStatusUnlicensed), @(FxGripLicenseStatusExpired), @(FxGripLicenseStatusRevoked),
							   @(FxGripLicenseStatusInvalidProduct), @(FxGripLicenseStatusUnknown)]) {
		XCTAssertEqual([self renderCountForStatus:status.integerValue unlicensed:YES trial:NO], (NSUInteger)1, @"status %@", status);
		XCTAssertEqualObjects(self.licensing.renderedConfiguration.text, @"Stub Plugin");
		XCTAssertEqual(self.licensing.renderedConfiguration.style, FxGripWatermarkStyleSingle);
		XCTAssertEqual([self renderCountForStatus:status.integerValue unlicensed:NO trial:NO], (NSUInteger)0, @"status %@ with the watermark off", status);
	}
}

/*! @abstract Licensed and OfflineGrace render clean whatever the switches say. */
- (void)testLicensedAndGraceRenderClean
{
	XCTAssertEqual([self renderCountForStatus:FxGripLicenseStatusLicensed unlicensed:YES trial:YES], (NSUInteger)0);
	XCTAssertEqual([self renderCountForStatus:FxGripLicenseStatusOfflineGrace unlicensed:YES trial:YES], (NSUInteger)0);
}

/*! @abstract Trial renders clean by default and carries the trial watermark when the trial switch is on. */
- (void)testTrialFollowsTheTrialSwitch
{
	XCTAssertEqual([self renderCountForStatus:FxGripLicenseStatusTrial unlicensed:YES trial:NO], (NSUInteger)0);
	XCTAssertEqual([self renderCountForStatus:FxGripLicenseStatusTrial unlicensed:NO trial:YES], (NSUInteger)1);
	XCTAssertEqualObjects(self.licensing.renderedConfiguration.text, @"Stub Plugin Trial");
	XCTAssertEqual(self.licensing.renderedConfiguration.style, FxGripWatermarkStyleCorner);
}

/*! @abstract A subclass maps a status to another watermark through the per-status seam. */
- (void)testTheWatermarkDecisionIsOverridablePerStatus
{
	self.provider.status = FxGripLicenseStatusOfflineGrace;
	FxGripLicensingGraceWatermarkExtension *licensing = [FxGripLicensingGraceWatermarkExtension.alloc initWithProvider:self.provider];
	[self add:licensing to:self.effect];
	[self activate:licensing];
	[licensing extRenderDestinationImage:[self renderNotification]];
	XCTAssertEqual(licensing.renderCount, (NSUInteger)1);
	XCTAssertEqualObjects(licensing.renderedConfiguration.text, @"GRACE");
}

/*! @abstract A failed watermark render leaves the frame unmarked rather than aborting the render. */
- (void)testAFailedWatermarkRenderLeavesTheFrameUnmarked
{
	[self add:self.licensing to:self.effect];
	[self activate:self.licensing];
	[self.effect stubParameterForID:kParameterLicensingWatermarkUnlicensedOffset].boolValue = YES;
	self.licensing.renderResult = NO;
	XCTAssertNoThrow([self.licensing extRenderDestinationImage:[self renderNotification]]);
	XCTAssertEqual(self.licensing.renderCount, (NSUInteger)1);
}

/*! @abstract A settings-object watermark opt-out registers as present and is honored. */
- (void)testASettingsObjectWatermarkOptOutIsHonored
{
	FxGripLicensingWatermarkSettings *settings = [FxGripLicensingWatermarkSettings.alloc init];
	settings.watermark = NO;
	[self.licensing setSettingsObject:(id)settings];
	[self add:self.licensing to:self.effect];
	[self parametersAddedBy:self.licensing seededBy:@{kFxParameterProperty_Type: kFxParameterType_Licensing, kFxParameterProperty_ParentId: @0}.mutableCopy];

	XCTAssertTrue(self.licensing.hasWatermarkUnlicensed);
	XCTAssertFalse(self.licensing.watermarkUnlicensed, @"the explicit opt-out is honored");
	self.provider.status = FxGripLicenseStatusUnlicensed;
	[self.licensing extRenderDestinationImage:[self renderNotification]];
	XCTAssertEqual(self.licensing.renderCount, (NSUInteger)0);
}

/*! @abstract The watermark configurations come from the settings object, the registration dictionary, or the defaults, with empty text resolving to the plugin name. */
- (void)testTheWatermarkConfigurationsResolveFromSettingsDictionaryOrDefaults
{
	self.effect.pluginProperties = @{kProPlugPlugInX_LicensingProperty: @{
		kFxGripLicensingProperty_Provider: @"mock",
		kFxGripLicensingProperty_UnlicensedWatermark: @{@"opacity": @0.4, @"style": @"diagonalTiled"},
		kFxGripLicensingProperty_TrialWatermark: @{@"text": @"Evaluation", @"corner": @"topRight"},
	}};
	[self add:self.licensing to:self.effect];
	[self activate:self.licensing];

	FxGripWatermarkConfiguration *unlicensed = self.licensing.unlicensedWatermarkConfiguration;
	XCTAssertEqualObjects(unlicensed.text, @"Stub Plugin", @"empty text resolves to the plugin display name");
	XCTAssertEqual(unlicensed.opacity, 0.4);
	XCTAssertEqual(unlicensed.style, FxGripWatermarkStyleDiagonalTiled);
	XCTAssertEqual(unlicensed.fontSize, 99.0, @"an absent key keeps the licensing default");

	FxGripWatermarkConfiguration *trial = self.licensing.trialWatermarkConfiguration;
	XCTAssertEqualObjects(trial.text, @"Evaluation");
	XCTAssertEqual(trial.corner, FxGripWatermarkCornerTopRight);

	// A settings object supplies the configuration whole.
	FxGripLicensingWatermarkSettings *settings = [FxGripLicensingWatermarkSettings.alloc init];
	settings.trialConfiguration = [FxGripWatermarkConfiguration configurationWithText:@"From Settings"];
	FxGripLicensing *fromSettings = [FxGripLicensing.alloc initWithProvider:self.provider];
	[fromSettings setSettingsObject:(id)settings];
	[self add:fromSettings to:self.effect];
	[self parametersAddedBy:fromSettings seededBy:nil];
	XCTAssertEqualObjects(fromSettings.trialWatermarkConfiguration.text, @"From Settings");
	XCTAssertEqualObjects(fromSettings.unlicensedWatermarkConfiguration.text, @"Stub Plugin");

	// A set configuration is copied and its empty text is resolved on read.
	fromSettings.unlicensedWatermarkConfiguration = [FxGripWatermarkConfiguration configurationWithText:@"Set"];
	XCTAssertEqualObjects(fromSettings.unlicensedWatermarkConfiguration.text, @"Set");
}

/*! @abstract The watermark seam draws a configuration onto a real destination tile. */
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
	FxGripLicensing *licensing = [FxGripLicensing.alloc initWithProvider:self.provider];
	[licensing extLoadWithEffect:(id)self.effect];

	NSError *error = nil;
	XCTAssertTrue([licensing renderWatermark:licensing.unlicensedWatermarkConfiguration ontoImage:tile error:&error], @"%@", error);
	XCTAssertNil(error);
}

#pragma mark Host configuration

/*! @abstract Loading against an effect that carries the regression extension runs the provider's host check against the configured bundle. */
- (void)testLoadRunsTheHostCheckWhenTheRegressionExtensionIsPresent
{
	self.effect.reportsExtensionClass = YES;
	self.provider.hostProblems = @[@"problem"];
	self.licensing.bundleOverride = [NSBundle bundleForClass:self.class];

	XCTAssertTrue([self.licensing extLoadWithEffect:(id)self.effect]);
	XCTAssertEqual(self.provider.checkedBundle, self.licensing.bundleOverride);
	XCTAssertEqualObjects([self.licensing hostConfigurationProblems], @[@"problem"]);
}

/*! @abstract An unavailable provider loads the extension disconnected and skips the host check. */
- (void)testAnUnavailableProviderLoadsDisconnected
{
	self.effect.reportsExtensionClass = YES;
	self.provider.available = NO;
	XCTAssertTrue([self.licensing extLoadWithEffect:(id)self.effect]);
	XCTAssertNil(self.provider.checkedBundle);
}

/*! @abstract The host check reads the main bundle by default and reports nothing for a provider without the capability. */
- (void)testTheHostCheckDefaultsToTheMainBundle
{
	XCTAssertEqual((id)[FxGripLicensing.alloc initWithProvider:self.provider].hostConfigurationBundle, (id)NSBundle.mainBundle);
	FxGripLicensing *minimal = [FxGripLicensing.alloc initWithProvider:[FxGripLicensingMinimalProvider.alloc init]];
	XCTAssertEqualObjects([minimal hostConfigurationProblems], @[]);
}

#pragma mark Configuration properties

/*! @abstract Each configuration writer sets its own parameter once the extension is added to an effect. */
- (void)testTheConfigurationWritersSetTheirParameterOnceAdded
{
	[self add:self.licensing to:self.effect];

	self.licensing.licensingActive = YES;
	self.licensing.watermarkUnlicensed = YES;
	self.licensing.watermarkTrial = YES;
	self.licensing.autoChecking = YES;

	XCTAssertTrue([self.effect stubParameterForID:kParameterLicensingActiveOffset].boolValue);
	XCTAssertTrue([self.effect stubParameterForID:kParameterLicensingWatermarkUnlicensedOffset].boolValue);
	XCTAssertTrue([self.effect stubParameterForID:kParameterLicensingWatermarkTrialOffset].boolValue);
	XCTAssertTrue([self.effect stubParameterForID:kParameterLicensingAutoCheckingOffset].boolValue);
}

/*! @abstract Each configuration writer refuses before the extension is added to an effect. */
- (void)testTheConfigurationWritersRefuseBeforeTheExtensionIsAdded
{
	[self.licensing extLoadWithEffect:(id)self.effect];
	self.licensing.licensingActive = YES;
	self.licensing.watermarkUnlicensed = YES;
	self.licensing.watermarkTrial = YES;
	self.licensing.autoChecking = YES;
	XCTAssertEqual(self.effect.stubParameters.count, (NSUInteger)0, @"no parameter was written");
}

/*! @abstract A hard-coded settings object makes every configuration writer refuse the write. */
- (void)testTheConfigurationWritersRefuseAHardCodedSetting
{
	[self.licensing setSettingsObject:(id)[FxGripLicensingFullSettings.alloc init]];
	[self add:self.licensing to:self.effect];
	[self parametersAddedBy:self.licensing seededBy:nil];
	[self.effect.stubParameters removeAllObjects];

	self.licensing.licensingActive = NO;
	self.licensing.watermarkUnlicensed = NO;
	self.licensing.watermarkTrial = NO;
	self.licensing.autoChecking = NO;

	XCTAssertEqual(self.effect.stubParameters.count, (NSUInteger)0, @"a hard-coded setting cannot be overwritten through a parameter");
}

/*! @abstract The active, watermark, and update-checking readers fall back to their parameter once added. */
- (void)testTheConfigurationReadersFallBackToTheirParameter
{
	[self add:self.licensing to:self.effect];

	[self.effect stubParameterForID:kParameterLicensingActiveOffset].boolValue = YES;
	[self.effect stubParameterForID:kParameterLicensingWatermarkUnlicensedOffset].boolValue = YES;
	[self.effect stubParameterForID:kParameterLicensingWatermarkTrialOffset].boolValue = YES;
	[self.effect stubParameterForID:kParameterLicensingAutoCheckingOffset].boolValue = YES;

	XCTAssertTrue(self.licensing.licensingActive);
	XCTAssertTrue(self.licensing.watermarkUnlicensed);
	XCTAssertTrue(self.licensing.watermarkTrial);
	XCTAssertTrue(self.licensing.autoChecking);

	[self.effect stubParameterForID:kParameterLicensingActiveOffset].boolValue = NO;
	XCTAssertFalse(self.licensing.licensingActive);
	XCTAssertFalse(self.licensing.watermarkUnlicensed, @"the watermark also requires an active integration");
	XCTAssertFalse(self.licensing.watermarkTrial);
}

/*! @abstract The button readers default to the provider's capability and report a hard-coded setting when given. */
- (void)testTheButtonReadersFollowTheCapabilityUnlessHardCoded
{
	XCTAssertTrue(self.licensing.showBuyButton, @"the mock provider can buy");
	XCTAssertTrue(self.licensing.showProductButton);

	FxGripLicensing *minimal = [FxGripLicensing.alloc initWithProvider:[FxGripLicensingMinimalProvider.alloc init]];
	XCTAssertFalse(minimal.showBuyButton, @"a provider without the capability shows no button");
	XCTAssertFalse(minimal.showProductButton);
	XCTAssertFalse(minimal.autoChecking);

	[self.licensing setSettingsObject:(id)[FxGripLicensingFullSettings.alloc init]];
	[self parametersAddedBy:self.licensing seededBy:nil];
	XCTAssertTrue(self.licensing.hasShowBuyButton);
	XCTAssertFalse(self.licensing.showBuyButton, @"the hard-coded NO wins over the capability");
	XCTAssertTrue(self.licensing.hasShowProductButton);
	XCTAssertFalse(self.licensing.showProductButton);
	XCTAssertTrue(self.licensing.hasAutoChecking);
	XCTAssertTrue(self.licensing.autoChecking);
}

/*! @abstract The settings object falls back to the effect when the effect declares the conformance. */
- (void)testTheSettingsObjectFallsBackToAConformingEffect
{
	FxGripLicensingSettingsEffect *effect = [FxGripLicensingSettingsEffect.alloc init];
	[self.licensing extLoadWithEffect:(id)effect];
	XCTAssertEqual((id)self.licensing.settingsObject, (id)effect);

	FxGripLicensing *unconfigured = [FxGripLicensing.alloc initWithProvider:self.provider];
	[unconfigured extLoadWithEffect:(id)self.effect];
	XCTAssertNil(unconfigured.settingsObject, @"a non-conforming effect supplies no settings");
}

#pragma mark Product identity

/*! @abstract An undeclared product reads its parameters, and the version defaults to the plugin's own when only the product is declared. */
- (void)testTheProductIdentityReadsItsParametersWhenUndeclared
{
	[self add:self.licensing to:self.effect];
	[self activate:self.licensing];
	[self.effect stubParameterForID:kParameterLicensingProductIDOffset].stringValue = @"parameter-product";
	[self.effect stubParameterForID:kParameterLicensingProductVersionOffset].stringValue = @"3.0.0";
	XCTAssertEqualObjects(self.licensing.productID, @"parameter-product");
	XCTAssertEqualObjects(self.licensing.productVersion, @"3.0.0");

	FxGripLicensing *declared = [FxGripLicensing.alloc initWithProvider:self.provider];
	[self add:declared to:self.effect];
	[self parametersAddedBy:declared seededBy:@{kFxParameterProperty_Type: kFxParameterType_Licensing,
												kFxGripLicensingProperty_ProductID: @"declared"}.mutableCopy];
	XCTAssertEqualObjects(declared.productID, @"declared");
	XCTAssertEqualObjects(declared.productVersion, @"1.2.3", @"a declared product without a version uses the plugin's own");
}

/*! @abstract The product identity falls back to the licensing plugin property, and a Boolean entry means the plugin's own UUID and version. */
- (void)testTheProductIdentityFallsBackToTheLicensingProperty
{
	self.effect.pluginProperties = @{kProPlugPlugInX_LicensingProperty: @{kFxGripLicensingProperty_Provider: @"mock",
																		  kFxGripLicensingProperty_ProductID: @"property-product",
																		  kFxGripLicensingProperty_ProductVersion: @"property-version"}};
	[self.licensing extLoadWithEffect:(id)self.effect];
	[self parametersAddedBy:self.licensing seededBy:nil];
	XCTAssertTrue(self.licensing.hasProduct);
	XCTAssertEqualObjects(self.licensing.productID, @"property-product");
	XCTAssertEqualObjects(self.licensing.productVersion, @"property-version");
	XCTAssertTrue(self.licensing.licensingActive, @"a named product activates the integration");

	FxGripLicensingStubEffect *own = [FxGripLicensingStubEffect.alloc init];
	own.pluginProperties = @{kProPlugPlugInX_LicensingProperty: @{kFxGripLicensingProperty_ProductID: @YES,
																  kFxGripLicensingProperty_ProductVersion: @YES}};
	FxGripLicensing *inherited = [FxGripLicensing.alloc initWithProvider:self.provider];
	[inherited extLoadWithEffect:(id)own];
	[self parametersAddedBy:inherited seededBy:nil];
	XCTAssertEqualObjects(inherited.productID, @"stub-plugin-uuid", @"a Boolean entry means the plugin's own UUID");
	XCTAssertEqualObjects(inherited.productVersion, @"1.2.3");
}

#pragma mark Parameter registration

/*! @abstract An unconfigured licensing parameter with a full-capability provider grows every support parameter. */
- (void)testAnUnconfiguredParameterAddsEverySupportParameter
{
	[self.licensing extLoadWithEffect:(id)self.effect];
	NSMutableDictionary *seed = @{kFxParameterProperty_Type: kFxParameterType_Licensing,
								  kFxParameterProperty_ParentId: @0,
								  kFxGripLicensingProperty_Active: @YES}.mutableCopy;
	NSArray<NSMutableDictionary *> *parameters = [self parametersAddedBy:self.licensing seededBy:seed];

	XCTAssertEqualObjects(parameters.firstObject[kFxParameterProperty_Type], kFxParameterType_Toggle, @"the licensing entry becomes the toggle");
	XCTAssertEqualObjects(parameters.firstObject[kFxParameterProperty_Name], @"Product Licensed");
	XCTAssertEqual((id)parameters.firstObject[kFxParameterProperty_Factory], (id)self.licensing);
	XCTAssertTrue(parameters.firstObject == seed, @"the declared entry keeps its position");
	for (NSUInteger index = 1; index < parameters.count; index++) {
		XCTAssertFalse(parameters[index] == seed, @"the declared entry is not appended again");
	}

	const FxParameterId base = kFxParameterId_Licensing;
	XCTAssertEqualObjects([self idsOf:parameters],
						  (@[@(base), @(base + 2), @(base + 3), @(base + 4), @(base + 12), @(base + 5), @(base + 6),
							 @(base + 7), @(base + 8), @(base + 9), @(base + 10), @(base + 11)]),
						  @"the support parameters carry the toggle's ID plus their offset");
	XCTAssertEqualObjects([self parameterNamed:@"Deactivate This Machine" in:parameters][kFxParameterProperty_Flags],
						  (@[kParameterFlagString_HIDDEN, kParameterFlagString_NOT_ANIMATABLE, kParameterFlagString_PRESETNOMETA]),
						  @"deactivation hides until the product is licensed");
}

/*! @abstract A provider without optional capabilities adds only the product, watermark, and active parameters. */
- (void)testAMinimalProviderAddsNoCapabilityParameters
{
	FxGripLicensing *minimal = [FxGripLicensing.alloc initWithProvider:[FxGripLicensingMinimalProvider.alloc init]];
	[minimal extLoadWithEffect:(id)self.effect];
	NSArray<NSMutableDictionary *> *parameters = [self parametersAddedBy:minimal seededBy:nil];

	const FxParameterId base = kFxParameterId_Licensing;
	XCTAssertEqualObjects([self idsOf:parameters], (@[@(base), @(base + 1), @(base + 2), @(base + 4), @(base + 12)]),
						  @"no version, buttons, update checking, license entry, or deactivation");
}

/*! @abstract A fully hard-coded settings object adds only the toggle, plus the capability buttons a provider backs. */
- (void)testHardCodedSettingsAddOnlyTheToggleAndCapabilityButtons
{
	FxGripLicensing *minimal = [FxGripLicensing.alloc initWithProvider:[FxGripLicensingMinimalProvider.alloc init]];
	[minimal extLoadWithEffect:(id)self.effect];
	[minimal setSettingsObject:(id)[FxGripLicensingFullSettings.alloc init]];
	NSArray<NSMutableDictionary *> *parameters = [self parametersAddedBy:minimal seededBy:nil];
	XCTAssertEqual(parameters.count, (NSUInteger)1);
	XCTAssertEqualObjects(minimal.productID, @"full-product");
	XCTAssertEqualObjects(minimal.productVersion, @"9.9.9");
	XCTAssertTrue(minimal.hasActive);
	XCTAssertTrue(minimal.hasProduct);
	XCTAssertTrue(minimal.hasWatermarkTrial);

	[self.licensing extLoadWithEffect:(id)self.effect];
	[self.licensing setSettingsObject:(id)[FxGripLicensingFullSettings.alloc init]];
	parameters = [self parametersAddedBy:self.licensing seededBy:nil];
	const FxParameterId base = kFxParameterId_Licensing;
	XCTAssertEqualObjects([self idsOf:parameters], (@[@(base), @(base + 10), @(base + 11)]),
						  @"license entry and deactivation follow the capability, not a setting");
}

/*! @abstract An explicitly deactivated integration adds nothing beyond the toggle it was given. */
- (void)testADeactivatedIntegrationStopsAfterTheToggle
{
	NSMutableDictionary *seed = @{kFxParameterProperty_Type: kFxParameterType_Licensing,
								  kFxParameterProperty_ParentId: @0,
								  kFxGripLicensingProperty_Active: @NO}.mutableCopy;
	NSArray<NSMutableDictionary *> *parameters = [self parametersAddedBy:self.licensing seededBy:seed];
	XCTAssertEqual(parameters.count, (NSUInteger)1, @"the seeded entry alone survives");
	XCTAssertTrue(self.licensing.hasActive);
	XCTAssertFalse(self.licensing.licensingActive);
	XCTAssertFalse(self.licensing.hasProduct, @"an inactive integration resolves no product");
}

/*! @abstract The parameter's own ID, name, and description are kept, the fxfactory type string is accepted, and the enforcement flags are applied. */
- (void)testTheConfiguredParameterKeepsItsIdentityAndGainsTheEnforcementFlags
{
	NSMutableDictionary *seed = @{kFxParameterProperty_Type: kFxParameterType_FxFactory,
								  kFxParameterProperty_Id: @400,
								  kFxParameterProperty_ParentId: @0,
								  kFxParameterProperty_Name: @"My License",
								  kFxParameterProperty_Description: @"My Integration",
								  kFxGripLicensingProperty_Active: @YES,
								  kFxParameterProperty_Flags: @[kParameterFlagString_HIDDEN]}.mutableCopy;
	NSArray<NSMutableDictionary *> *parameters = [self parametersAddedBy:self.licensing seededBy:seed];

	NSMutableDictionary *toggle = parameters.firstObject;
	XCTAssertEqualObjects(toggle[kFxParameterProperty_Name], @"My License");
	XCTAssertEqualObjects(toggle[kFxParameterProperty_Description], @"My Integration");
	XCTAssertEqual(self.licensing.parameterID, (FxParameterId)400);
	XCTAssertEqualObjects(toggle[kFxParameterProperty_Flags],
						  (@[kParameterFlagString_HIDDEN, kParameterFlagString_NOT_ANIMATABLE, kParameterFlagString_PRESETNOMETA, kParameterFlagString_NO_DEBUG]),
						  @"the enforcement flags are applied once, in order");
	XCTAssertEqualObjects(parameters[1][kFxParameterProperty_Id], @(400 + 2), @"the support parameters follow the toggle's ID");
}

/*! @abstract A product declared on the parameter suppresses the product parameters. */
- (void)testADeclaredProductSuppressesTheProductParameters
{
	NSMutableDictionary *seed = @{kFxParameterProperty_Type: kFxParameterType_Licensing,
								  kFxParameterProperty_ParentId: @0,
								  kFxGripLicensingProperty_Active: @YES,
								  kFxGripLicensingProperty_ProductID: @"declared-product",
								  kFxGripLicensingProperty_ProductVersion: @"5.0.0"}.mutableCopy;
	NSArray<NSMutableDictionary *> *parameters = [self parametersAddedBy:self.licensing seededBy:seed];

	XCTAssertTrue(self.licensing.hasProduct);
	XCTAssertEqualObjects(self.licensing.productID, @"declared-product");
	XCTAssertEqualObjects(self.licensing.productVersion, @"5.0.0");
	const FxParameterId base = kFxParameterId_Licensing;
	XCTAssertEqualObjects([self idsOf:parameters], (@[@(base), @(base + 4), @(base + 12), @(base + 5), @(base + 6),
													   @(base + 7), @(base + 8), @(base + 9), @(base + 10), @(base + 11)]));
}

/*! @abstract A named product with no explicit active state activates the integration, watermarks by default, and locks the writers. */
- (void)testANamedProductActivatesTheIntegrationAndLocksTheWriters
{
	[self.licensing extLoadWithEffect:(id)self.effect];
	[self.licensing setSettingsObject:(id)[FxGripLicensingProductOnlySettings.alloc init]];
	NSMutableDictionary *seed = @{kFxParameterProperty_Type: kFxParameterType_Licensing,
								  kFxParameterProperty_Id: @0,
								  kFxParameterProperty_ParentId: @0}.mutableCopy;
	[self parametersAddedBy:self.licensing seededBy:seed];
	[self.licensing parameterForDictionary:seed];

	XCTAssertFalse(self.licensing.hasActive);
	XCTAssertTrue(self.licensing.hasProduct);
	XCTAssertTrue(self.licensing.licensingActive, @"a named product activates the integration");
	// The watermark toggles read their parameters, which the host creates with the declared defaults.
	NSArray<NSMutableDictionary *> *parameters = [self parametersAddedBy:[FxGripLicensing.alloc initWithProvider:self.provider] seededBy:nil];
	XCTAssertEqualObjects([self parameterNamed:@"Unlicensed Watermark" in:parameters][kFxParameterProperty_Default], @YES, @"the unlicensed watermark is on by default");
	XCTAssertNil([self parameterNamed:@"Trial Watermark" in:parameters][kFxParameterProperty_Default], @"the trial watermark is off by default");
	[self.effect stubParameterForID:kParameterLicensingWatermarkUnlicensedOffset].boolValue = YES;
	XCTAssertTrue(self.licensing.watermarkUnlicensed);
	XCTAssertFalse(self.licensing.watermarkTrial);

	[self.effect.stubParameters removeAllObjects];
	self.licensing.licensingActive = NO;
	XCTAssertEqual(self.effect.stubParameters.count, (NSUInteger)0, @"a named product presets the active state, so the writer refuses");
}

/*! @abstract A configuration that declares neither an active state nor a product adds the hidden Licensing Active toggle. */
- (void)testAnUndeclaredActiveStateAddsTheHiddenActiveToggle
{
	[self.licensing extLoadWithEffect:(id)self.effect];
	NSMutableDictionary *seed = @{kFxParameterProperty_Type: kFxParameterType_Licensing,
								  kFxParameterProperty_Id: @0,
								  kFxParameterProperty_ParentId: @0}.mutableCopy;
	NSArray<NSMutableDictionary *> *parameters = [self parametersAddedBy:self.licensing seededBy:seed];

	XCTAssertFalse(self.licensing.hasActive);
	XCTAssertFalse(self.licensing.hasProduct);
	XCTAssertFalse(self.licensing.licensingActive, @"the integration waits for the Active toggle");

	NSMutableDictionary *active = [self parameterNamed:@"Licensing Active" in:parameters];
	XCTAssertNotNil(active);
	XCTAssertEqualObjects(active[kFxParameterProperty_Id], @1);
	XCTAssertEqualObjects(active[kFxParameterProperty_Type], kFxParameterType_Toggle);
	XCTAssertEqualObjects(active[kFxParameterProperty_Flags],
						  (@[kParameterFlagString_HIDDEN, kParameterFlagString_NOT_ANIMATABLE, kParameterFlagString_PRESETNOMETA]),
						  @"licensing enforcement is not a user control");
}

/*! @abstract A missing licensing entry is created and appended once, alongside each support parameter once, at the top level. */
- (void)testACreatedToggleIsAppendedOnce
{
	[self.licensing extLoadWithEffect:(id)self.effect];
	NSArray<NSMutableDictionary *> *parameters = [self parametersAddedBy:self.licensing seededBy:nil];

	NSMutableSet<NSNumber *> *ids = NSMutableSet.new;
	NSUInteger toggles = 0;
	for (NSMutableDictionary *parameter in parameters) {
		XCTAssertFalse([ids containsObject:parameter[kFxParameterProperty_Id]], @"parameter %@ is added once", parameter[kFxParameterProperty_Id]);
		[ids addObject:parameter[kFxParameterProperty_Id]];
		if ([parameter[kFxParameterProperty_Name] isEqualToString:@"Product Licensed"]) {
			toggles += 1;
		}
	}
	XCTAssertEqual(toggles, (NSUInteger)1);
	XCTAssertEqualObjects(parameters.firstObject[kFxParameterProperty_Factory], self.licensing);
	for (NSUInteger index = 1; index < parameters.count; index++) {
		XCTAssertEqualObjects(parameters[index][kFxParameterProperty_ParentId], @(kFxParameterId_TopLevelGroup));
	}
}

/*! @abstract The support parameters join the group the declared licensing parameter belongs to. */
- (void)testTheSupportParametersShareTheDeclaredParent
{
	NSMutableDictionary *seed = @{kFxParameterProperty_Type: kFxParameterType_Licensing,
								  kFxParameterProperty_Id: @500,
								  kFxParameterProperty_ParentId: @77,
								  kFxGripLicensingProperty_Active: @YES}.mutableCopy;
	NSArray<NSMutableDictionary *> *parameters = [self parametersAddedBy:self.licensing seededBy:seed];
	XCTAssertGreaterThan(parameters.count, (NSUInteger)1);
	for (NSUInteger index = 1; index < parameters.count; index++) {
		XCTAssertEqualObjects(parameters[index][kFxParameterProperty_ParentId], @77);
	}
}

#pragma mark Parameter changes

/*! @abstract A change to the licensing toggle is reverted to the true status. */
- (void)testAChangeToTheLicensingToggleIsReverted
{
	[self add:self.licensing to:self.effect];
	[self activate:self.licensing];
	self.provider.status = FxGripLicenseStatusLicensed;
	self.licensing.recordedBoolValue = NO;

	[self.licensing extParameterChanged:[self changeNotification:0]];
	XCTAssertTrue(self.licensing.recordedBoolValue, @"the toggle is restored to the licensed status");
}

/*! @abstract Toggling the active parameter starts observing and switching it off stops. */
- (void)testTogglingTheActiveParameterStartsAndStopsObserving
{
	[self add:self.licensing to:self.effect];
	[self activate:self.licensing];
	[self.effect stubParameterForID:kParameterLicensingProductIDOffset].stringValue = @"active-product";

	[self.effect stubParameterForID:kParameterLicensingActiveOffset].boolValue = YES;
	[self.licensing extParameterChanged:[self changeNotification:kParameterLicensingActiveOffset]];
	XCTAssertEqualObjects(self.provider.startedProducts, @[@"active-product"]);
	XCTAssertEqualObjects(self.provider.stoppedProducts, @[], @"the first start tears nothing down");

	[self.effect stubParameterForID:kParameterLicensingActiveOffset].boolValue = NO;
	[self.licensing extParameterChanged:[self changeNotification:kParameterLicensingActiveOffset]];
	XCTAssertEqualObjects(self.provider.stoppedProducts, @[@"active-product"]);
}

/*! @abstract A button label change renames the button that precedes it. */
- (void)testAButtonLabelChangeRenamesItsButton
{
	[self add:self.licensing to:self.effect];
	[self activate:self.licensing];
	[self.effect stubParameterForID:kParameterLicensingBuyButtonLabelOffset].stringValue = @"Buy Now…";
	[self.effect stubParameterForID:kParameterLicensingProductButtonLabelOffset].stringValue = @"Open Product…";

	[self.licensing extParameterChanged:[self changeNotification:kParameterLicensingBuyButtonLabelOffset]];
	[self.licensing extParameterChanged:[self changeNotification:kParameterLicensingProductButtonLabelOffset]];

	XCTAssertEqualObjects([self.effect stubParameterForID:kParameterLicensingBuyButtonOffset].parameterName, @"Buy Now…");
	XCTAssertEqualObjects([self.effect stubParameterForID:kParameterLicensingProductButtonOffset].parameterName, @"Open Product…");
}

/*! @abstract Pressing a button runs its action through the provider. */
- (void)testAButtonPressRunsItsAction
{
	[self add:self.licensing to:self.effect];
	[self activate:self.licensing];

	[self.licensing extParameterChanged:[self changeNotification:kParameterLicensingBuyButtonOffset]];
	[self.licensing extParameterChanged:[self changeNotification:kParameterLicensingProductButtonOffset]];
	[self.licensing extParameterChanged:[self changeNotification:kParameterLicensingLicenseEntryButtonOffset]];
	[self.licensing extParameterChanged:[self changeNotification:kParameterLicensingDeactivateButtonOffset]];

	XCTAssertEqualObjects(self.provider.actions, (@[@"buy", @"show", @"enter", @"deactivate"]));
}

/*! @abstract A change to the update-checking parameter applies the new state through the provider. */
- (void)testAnUpdateCheckingChangeAppliesTheNewState
{
	[self add:self.licensing to:self.effect];
	[self activate:self.licensing];
	[self.effect stubParameterForID:kParameterLicensingAutoCheckingOffset].boolValue = YES;
	[self.licensing extParameterChanged:[self changeNotification:kParameterLicensingAutoCheckingOffset]];
	XCTAssertEqualObjects(self.provider.updateCheckingWrites, @[@YES]);
}

/*! @abstract An inactive integration ignores every parameter change and skips the document-add pass. */
- (void)testAnInactiveIntegrationIgnoresChangesAndTheDocumentAdd
{
	[self add:self.licensing to:self.effect];
	XCTAssertFalse(self.licensing.licensingActive, @"nothing declares the integration active");

	[self.effect stubParameterForID:kParameterLicensingAutoCheckingOffset].boolValue = YES;
	[self.licensing extParameterChanged:[self changeNotification:kParameterLicensingAutoCheckingOffset]];
	[self.licensing extParameterChanged:[self changeNotification:kParameterLicensingBuyButtonOffset]];
	[self addedToDocument:self.licensing];

	XCTAssertEqualObjects(self.provider.updateCheckingWrites, @[]);
	XCTAssertEqualObjects(self.provider.actions, @[]);
	XCTAssertEqual(self.provider.updateCheckCount, (NSUInteger)0);
}

/*! @abstract A change outside the licensing parameter range is ignored. */
- (void)testAChangeOutsideTheRangeIsIgnored
{
	[self add:self.licensing to:self.effect];
	[self activate:self.licensing];
	XCTAssertNoThrow([self.licensing extParameterChanged:[self changeNotification:kParameterLicensingWatermarkTrialOffset + 1]]);
	XCTAssertNoThrow([self.licensing extParameterChanged:[self changeNotification:kParameterLicensingWatermarkTrialOffset]]);
	XCTAssertEqualObjects(self.provider.actions, @[]);
}

#pragma mark Updates and actions

/*! @abstract A forced update check reports the information to the effect hook, the caller's handler, and the notification. */
- (void)testAForcedUpdateCheckReportsThroughEveryChannel
{
	[self add:self.licensing to:self.effect];
	[self activate:self.licensing];
	self.provider.cannedUpdateInfo = @{FxGripLicensingUpdateInfoNewVersionFound: @YES};
	[self.effect stubParameterForID:kParameterLicensingProductVersionOffset].stringValue = @"4.5.6";

	__block NSDictionary *posted = nil;
	id token = [self.effect.notifier addObserverForName:FxGripLicensingProductUpdateName object:nil queue:nil
											 usingBlock:^(NSNotification *note) { posted = note.userInfo; }];
	__block NSDictionary *handled = nil;
	[self.licensing checkForUpdates:YES handler:^(NSDictionary *info) { handled = info; }];
	[self.effect.notifier removeObserver:token];

	XCTAssertEqual(self.provider.updateCheckCount, (NSUInteger)1);
	XCTAssertTrue(self.provider.recordedForce);
	XCTAssertEqualObjects(self.provider.recordedVersion, @"4.5.6");
	XCTAssertEqualObjects(self.effect.updateInfos, @[self.provider.cannedUpdateInfo]);
	XCTAssertEqualObjects(handled, self.provider.cannedUpdateInfo);
	XCTAssertEqualObjects(posted, self.provider.cannedUpdateInfo);
}

/*! @abstract The unforced check runs without forcing and reports nothing when the provider reports nothing. */
- (void)testTheUnforcedUpdateCheckIgnoresASilentProvider
{
	[self add:self.licensing to:self.effect];
	[self.licensing checkForUpdates];
	XCTAssertEqual(self.provider.updateCheckCount, (NSUInteger)1);
	XCTAssertFalse(self.provider.recordedForce);
	XCTAssertEqual(self.effect.updateInfos.count, (NSUInteger)0);
}

/*! @abstract The update-checking property reads the provider and its writer posts the state before applying it. */
- (void)testTheUpdateCheckingPropertyReadsAndWritesThroughTheProvider
{
	[self add:self.licensing to:self.effect];
	self.provider.updateCheckingEnabled = YES;
	XCTAssertTrue(self.licensing.updateChecking);

	__block NSDictionary *posted = nil;
	id token = [self.effect.notifier addObserverForName:FxGripLicensingSetUpdateCheckingName object:nil queue:nil
											 usingBlock:^(NSNotification *note) { posted = note.userInfo; }];
	self.licensing.updateChecking = NO;
	[self.effect.notifier removeObserver:token];

	XCTAssertEqualObjects(self.provider.updateCheckingWrites, @[@NO]);
	XCTAssertEqualObjects(posted, @{FxGripLicensingEnabledKey: @NO});

	FxGripLicensing *minimal = [FxGripLicensing.alloc initWithProvider:[FxGripLicensingMinimalProvider.alloc init]];
	XCTAssertFalse(minimal.updateChecking);
	XCTAssertNoThrow(minimal.updateChecking = YES);
}

/*! @abstract The buy, product, license-entry, and support actions post their notification and run through the provider. */
- (void)testTheActionsPostAndRunThroughTheProvider
{
	[self add:self.licensing to:self.effect];
	NSMutableArray<NSString *> *names = NSMutableArray.new;
	NSMutableArray *tokens = NSMutableArray.new;
	for (NSNotificationName name in @[FxGripLicensingShowBuyName, FxGripLicensingShowProductName, FxGripLicensingShowLicenseEntryName, FxGripLicensingSupportFormName]) {
		[tokens addObject:[self.effect.notifier addObserverForName:name object:nil queue:nil usingBlock:^(NSNotification *note) {
			[names addObject:note.name];
			if ([note.name isEqualToString:FxGripLicensingSupportFormName]) {
				XCTAssertEqualObjects(note.userInfo[FxGripLicensingSubjectKey], @"Subject");
				XCTAssertEqualObjects(note.userInfo[FxGripLicensingMessageKey], @"Message");
			}
		}]];
	}

	XCTAssertTrue([self.licensing buyProduct]);
	XCTAssertTrue([self.licensing showProduct]);
	XCTAssertTrue([self.licensing showLicenseEntry]);
	XCTAssertTrue([self.licensing showSupportFormWithSubject:@"Subject" message:@"Message"]);
	for (id token in tokens) {
		[self.effect.notifier removeObserver:token];
	}

	XCTAssertEqualObjects(self.provider.actions, (@[@"buy", @"show", @"enter", @"support"]));
	XCTAssertEqualObjects(names, (@[FxGripLicensingShowBuyName, FxGripLicensingShowProductName, FxGripLicensingShowLicenseEntryName, FxGripLicensingSupportFormName]));
	XCTAssertEqualObjects(self.provider.supportSubject, @"Subject");
}

/*! @abstract Deactivation posts, runs through the provider, and applies the status its completion reports, logging an error without dropping the status. */
- (void)testDeactivationAppliesTheCompletionStatus
{
	[self add:self.licensing to:self.effect];
	[self activate:self.licensing];
	self.provider.status = FxGripLicenseStatusLicensed;
	XCTAssertTrue(self.licensing.isLicensed);
	self.provider.deactivateStatus = FxGripLicenseStatusUnlicensed;
	self.provider.deactivateError = [NSError errorWithDomain:@"FxGripLicensingTests" code:1 userInfo:nil];

	__block NSUInteger posts = 0;
	id token = [self.effect.notifier addObserverForName:FxGripLicensingDeactivateName object:nil queue:nil usingBlock:^(NSNotification *note) { posts += 1; }];
	[self.licensing deactivateLicense];
	[self.effect.notifier removeObserver:token];

	XCTAssertEqual(posts, (NSUInteger)1);
	XCTAssertFalse(self.licensing.isLicensed);
	XCTAssertEqualObjects(self.effect.statusChanges.lastObject, @(FxGripLicenseStatusUnlicensed));
}

#pragma mark The parameter type factory

/*! @abstract The extension maps the licensing and fxfactory type strings to its parameter type and back to its own class. */
- (void)testTheExtensionMapsTheLicensingParameterTypes
{
	FxParameterType type = [self.licensing extParameterTypeForString:kFxParameterType_Licensing];
	XCTAssertEqual(type, (FxParameterType)'FxLc');
	XCTAssertEqual([self.licensing extParameterTypeForString:kFxParameterType_FxFactory], type);
	XCTAssertEqual([self.licensing extParameterClassForType:type], FxGripLicensingRecordingExtension.class);
	XCTAssertEqual([self.licensing extParameterTypeForString:@"toggle"], FxParameterType_None);
	XCTAssertEqual([self.licensing extParameterTypeForString:nil], FxParameterType_None);
	XCTAssertNil([self.licensing extParameterClassForType:FxParameterType_Toggle]);
}

#pragma mark The provider registry

/*! @abstract Providers register by name, resolve case-insensitively, list sorted, and a non-conforming class is refused. */
- (void)testTheRegistryRegistersAndResolvesProviders
{
	[FxGripLicensing registerProviderClass:FxGripLicensingMockProvider.class forName:@"MockTest"];
	XCTAssertEqual([FxGripLicensing providerClassForName:@"mocktest"], FxGripLicensingMockProvider.class);
	XCTAssertEqual([FxGripLicensing providerClassForName:@"MOCKTEST"], FxGripLicensingMockProvider.class);
	XCTAssertTrue([[FxGripLicensing registeredProviderNames] containsObject:@"mocktest"]);
	XCTAssertNil([FxGripLicensing providerClassForName:@"nobody"]);

	[FxGripLicensing registerProviderClass:NSObject.class forName:@"refused"];
	XCTAssertNil([FxGripLicensing providerClassForName:@"refused"], @"a class that does not adopt the protocol is refused");

	NSArray *names = [FxGripLicensing registeredProviderNames];
	XCTAssertEqualObjects(names, [names sortedArrayUsingSelector:@selector(compare:)]);
}

/*! @abstract The plugin properties select a provider by string, by dictionary, or by the fxFactory shorthand. */
- (void)testTheProviderNameComesFromThePluginProperties
{
	XCTAssertEqualObjects([FxGripLicensing providerNameForPluginProperties:@{kProPlugPlugInX_LicensingProperty: @"storekit"}], @"storekit");
	XCTAssertEqualObjects([FxGripLicensing providerNameForPluginProperties:@{kProPlugPlugInX_LicensingProperty: @{kFxGripLicensingProperty_Provider: @"mock"}}], @"mock");
	XCTAssertEqualObjects([FxGripLicensing providerNameForPluginProperties:@{kProPlugPlugInX_FxFactoryProperty: @YES}], @"fxfactory");
	XCTAssertNil([FxGripLicensing providerNameForPluginProperties:@{kProPlugPlugInX_FxFactoryProperty: @NO}]);
	XCTAssertNil([FxGripLicensing providerNameForPluginProperties:@{kProPlugPlugInX_LicensingProperty: @{}}]);
	XCTAssertNil([FxGripLicensing providerNameForPluginProperties:nil]);
}

#pragma mark The effect-side accessors

/*! @abstract An effect that installs the extension resolves it, reports its product, and follows its status. */
- (void)testAnEffectResolvesItsInstalledExtension
{
	id noManager = nil;
	FxGripLicensingHostEffect *effect = [FxGripLicensingHostEffect.alloc initWithAPIManager:noManager];

	XCTAssertNotNil(effect.licensing);
	XCTAssertEqual(effect.licensing.provider, effect.mockProvider);
	XCTAssertEqualObjects(effect.licensingProductID, @"", @"no product is declared");
	XCTAssertFalse(effect.isProductLicensed, @"the mock reports the product unlicensed");

	[effect licensingStatusDidChange:FxGripLicenseStatusTrial];
	XCTAssertEqual(effect.licenseStateCallCount, (NSUInteger)1);
	XCTAssertTrue(effect.recordedLicenseState);
	[effect licensingStatusDidChange:FxGripLicenseStatusExpired];
	XCTAssertFalse(effect.recordedLicenseState);
}

/*! @abstract An effect without the extension resolves none, the default hooks are inert, and no provider is selected. */
- (void)testAnEffectWithoutTheExtensionResolvesNone
{
	id noManager = nil;
	FxGripLicensingPlainEffect *effect = [FxGripLicensingPlainEffect.alloc initWithAPIManager:noManager];

	XCTAssertNil(effect.licensing);
	XCTAssertNil(effect.licensingProductID);
	XCTAssertFalse(effect.isProductLicensed);
	XCTAssertNoThrow([effect setLicenseState:YES]);
	XCTAssertNoThrow([effect licensingDidReceiveUpdateInfo:@{}]);
	XCTAssertNoThrow([effect licensingStatusDidChange:FxGripLicenseStatusLicensed]);
	XCTAssertNil([effect newLicensingExtension], @"no plugin property selects a provider");
}

@end
