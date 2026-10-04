/*!
	@file       FxGripFxFactoryProviderTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-03
	@header     FxGripFxFactoryProviderTests
	@abstract   Unit tests for the FxFactory licensing provider.
	@discussion Introduced in FxGrip 0.1.0. Mock subclasses override the FxFactory SDK seams so the status cast, the observation table, the callback delivery through the registered context, the licensing actions, the update translation, the contact-form guard, and the host configuration check run without a live FxFactory installation. The read-only seams run against the real SDK when it is installed.
*/

#import <XCTest/XCTest.h>
#import <dlfcn.h>
#import <FxGrip/FxGripLicensing.h>
#import <FxGrip/FxGripFxFactoryProvider.h>

/*! Resolves one of the FxFactory SDK's weak-linked response keys; nil when FxFactory is absent. */
static NSString *FxGripFxFactoryTestResponseKey(const char *symbol)
{
	NSString *const *address = (NSString *const *)dlsym(RTLD_DEFAULT, symbol);
	return address ? *address : nil;
}

/*! Overrides the SDK seams: installed, a scripted status, a captured handler, and recorded actions. */
@interface FxGripFxFactoryProviderMock : FxGripFxFactoryProvider
@property (nonatomic, assign) NSUInteger mockStatus;
@property (nonatomic, assign) BOOL installed;
@property (nonatomic, copy) void (^capturedHandler)(NSUInteger status, id context);
@property (nonatomic, strong) NSMutableArray<NSString *> *registeredUUIDs;
@property (nonatomic, strong) NSMutableArray<NSString *> *unregisteredUUIDs;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *actions;
@property (nonatomic, assign) BOOL contactFormAvailable;
@property (nonatomic, strong) NSMutableArray<NSString *> *contactRecipients;
@property (nonatomic, copy) NSDictionary *cannedResponse;
@property (nonatomic, assign) BOOL recordedForce;
@property (nonatomic, copy) NSString *recordedVersion;
@property (nonatomic, assign) BOOL updateCheckingEnabled;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *updateCheckingWrites;
@property (nonatomic, assign) NSUInteger versionStatus;
@property (nonatomic, assign) NSOperatingSystemVersion recordedVersionQuery;
@property (nonatomic, assign) BOOL upgradable;
@property (nonatomic, copy) NSDictionary *cannedProductInfo;
@property (nonatomic, strong) NSError *cannedProductInfoError;
@end

@implementation FxGripFxFactoryProviderMock

- (instancetype)init
{
	_installed = YES;
	_mockStatus = kFxGripFxFactoryStatusUnlicensed;
	_registeredUUIDs = NSMutableArray.new;
	_unregisteredUUIDs = NSMutableArray.new;
	_actions = NSMutableArray.new;
	_contactFormAvailable = YES;
	_contactRecipients = NSMutableArray.new;
	_updateCheckingWrites = NSMutableArray.new;
	return [super init];
}

- (BOOL)factoryInstalled { return self.installed; }
- (NSOperatingSystemVersion)factoryVersion { return ((NSOperatingSystemVersion){7, 1, 4}); }
- (NSUInteger)factoryLicensingStatusForProduct:(NSString *)productUUID { return self.mockStatus; }
- (NSUInteger)factoryLicensingStatusForProduct:(NSString *)productUUID version:(NSOperatingSystemVersion)version
{
	self.recordedVersionQuery = version;
	return self.versionStatus;
}
- (BOOL)factoryLicenseIsUpgradableForProduct:(NSString *)productUUID { return self.upgradable; }
- (void)factoryProductInfoForProduct:(NSString *)productUUID handler:(void (^)(NSDictionary *, NSError *))handler
{
	handler(self.cannedProductInfo, self.cannedProductInfoError);
}

- (id)factoryRegisterLicensingHandlerForProduct:(NSString *)productUUID handler:(void (^)(NSUInteger, id))handler
{
	[self.registeredUUIDs addObject:productUUID];
	self.capturedHandler = handler;
	return [NSString stringWithFormat:@"handle-%@", productUUID];
}

- (void)factoryUnregisterLicensingHandler:(id)handle forProduct:(NSString *)productUUID
{
	XCTAssertEqualObjects(handle, ([NSString stringWithFormat:@"handle-%@", productUUID]), @"the handle registered for the product is the one released");
	[self.unregisteredUUIDs addObject:productUUID];
}

- (void)factoryShowProductUpdatesForProduct:(NSString *)productUUID version:(NSString *)version force:(BOOL)force handler:(void (^)(NSDictionary *))handler
{
	self.recordedForce = force;
	self.recordedVersion = version;
	if (handler) {
		handler(self.cannedResponse);
	}
}

- (BOOL)factoryUpdateCheckingEnabledForProduct:(NSString *)productUUID { return self.updateCheckingEnabled; }
- (void)factorySetUpdateCheckingEnabled:(BOOL)enabled forProduct:(NSString *)productUUID { [self.updateCheckingWrites addObject:@(enabled)]; }

- (BOOL)factoryPerformLicensingAction:(NSUInteger)action forProduct:(NSString *)productUUID
{
	[self.actions addObject:@(action)];
	return YES;
}

- (BOOL)factoryContactFormAvailable { return self.contactFormAvailable; }

- (BOOL)factoryShowContactFormToRecipient:(NSString *)recipient subject:(NSString *)subject message:(NSString *)message
{
	[self.contactRecipients addObject:recipient ?: @""];
	return YES;
}

@end

/*! Reports FxFactory as absent. */
@interface FxGripFxFactoryAbsentProviderMock : FxGripFxFactoryProviderMock
@end
@implementation FxGripFxFactoryAbsentProviderMock
- (BOOL)factoryInstalled { return NO; }
@end

/*! Stands in for the bundle whose Info.plist the host configuration check reads. */
@interface FxGripFxFactoryProviderInfoBundleStub : NSObject
@property (nonatomic, copy) NSDictionary *info;
@end

@implementation FxGripFxFactoryProviderInfoBundleStub
- (id)objectForInfoDictionaryKey:(NSString *)key { return self.info[key]; }
@end


@interface FxGripFxFactoryProviderTests : XCTestCase
@property (nonatomic, strong) FxGripFxFactoryProviderMock *provider;
@end

@implementation FxGripFxFactoryProviderTests

- (void)setUp
{
	[super setUp];
	self.provider = [FxGripFxFactoryProviderMock.alloc init];
}

#pragma mark Identity

/*! @abstract The provider registers under fxfactory when the framework loads. */
- (void)testTheProviderIsRegisteredUnderItsName
{
	XCTAssertEqual([FxGripLicensing providerClassForName:kFxGripLicensingProviderName_FxFactory], FxGripFxFactoryProvider.class);
	XCTAssertEqualObjects(self.provider.providerName, @"fxfactory");
}

/*! @abstract Availability and the version come from the installed and version seams. */
- (void)testAvailabilityAndVersionFollowTheSeams
{
	XCTAssertTrue(self.provider.isAvailable);
	XCTAssertTrue(self.provider.fxFactoryIsInstalled);
	NSOperatingSystemVersion version = self.provider.fxFactoryVersion;
	XCTAssertEqual(version.majorVersion, (NSInteger)7);
	XCTAssertEqual(version.minorVersion, (NSInteger)1);
	XCTAssertEqual(version.patchVersion, (NSInteger)4);

	FxGripFxFactoryAbsentProviderMock *absent = [FxGripFxFactoryAbsentProviderMock.alloc init];
	XCTAssertFalse(absent.isAvailable);
	XCTAssertFalse(absent.fxFactoryIsInstalled);

	// The installed state is read once, at init; the SDK's presence cannot change in-process.
	self.provider.installed = NO;
	XCTAssertTrue(self.provider.isAvailable);
}

#pragma mark Status

/*! @abstract The FxFactory status casts directly to the licensing status. */
- (void)testTheStatusCastsDirectly
{
	self.provider.mockStatus = kFxGripFxFactoryStatusLicensed;
	XCTAssertEqual([self.provider licenseStatusForProduct:@"p"], FxGripLicenseStatusLicensed);
	self.provider.mockStatus = kFxGripFxFactoryStatusUnlicensed;
	XCTAssertEqual([self.provider licenseStatusForProduct:@"p"], FxGripLicenseStatusUnlicensed);
	self.provider.mockStatus = 1;
	XCTAssertEqual([self.provider licenseStatusForProduct:@"p"], FxGripLicenseStatusInvalidProduct);
	self.provider.mockStatus = 0;
	XCTAssertEqual([self.provider licenseStatusForProduct:@"p"], FxGripLicenseStatusUnknown);
	self.provider.mockStatus = 4;
	XCTAssertEqual([self.provider licenseStatusForProduct:@"p"], FxGripLicenseStatusUnknown, @"the Swift-only APIUnavailable value is not Trial");
}

/*! @abstract The version-gated status passes the version to the seam and casts the result. */
- (void)testTheVersionGatedStatusQueriesTheSeam
{
	self.provider.versionStatus = kFxGripFxFactoryStatusUnlicensed;
	self.provider.mockStatus = kFxGripFxFactoryStatusLicensed;
	XCTAssertEqual([self.provider licenseStatusForProduct:@"p" version:((NSOperatingSystemVersion){2, 1, 0})], FxGripLicenseStatusUnlicensed,
				   @"a license for an earlier version does not cover this one");
	XCTAssertEqual(self.provider.recordedVersionQuery.majorVersion, (NSInteger)2);
	XCTAssertEqual(self.provider.recordedVersionQuery.minorVersion, (NSInteger)1);
	XCTAssertEqual([self.provider licenseStatusForProduct:@"p"], FxGripLicenseStatusLicensed, @"the plain status is unchanged");
}

/*! @abstract The upgrade check follows the seam. */
- (void)testTheUpgradeCheckFollowsTheSeam
{
	XCTAssertFalse([self.provider upgradeAvailableForProduct:@"p"]);
	self.provider.upgradable = YES;
	XCTAssertTrue([self.provider upgradeAvailableForProduct:@"p"]);
}

/*! @abstract A product information fetch translates the SDK dictionary, keeps the raw response, and passes an error through. */
- (void)testAProductInfoFetchTranslatesTheResponse
{
	NSString *name = FxGripFxFactoryTestResponseKey("kFxFactoryLicensingProductName");
	NSString *latest = FxGripFxFactoryTestResponseKey("kFxFactoryLicensingProductLatestVersion");
	NSString *requiredFx = FxGripFxFactoryTestResponseKey("kFxFactoryLicensingProductLatestVersionRequiredFxFactoryVersion");
	NSString *price = FxGripFxFactoryTestResponseKey("kFxFactoryLicensingProductPriceInUSD");
	if (!name || !latest || !requiredFx || !price) {
		XCTSkip(@"the FxFactory response keys are weak-linked constants and FxFactory is not installed");
	}
	self.provider.cannedProductInfo = @{name: @"Product", latest: @"2.0", requiredFx: @"9.0.6", price: @49.5f};

	__block NSDictionary *info = nil;
	__block NSError *error = nil;
	[self.provider fetchProductInfoForProduct:@"p" handler:^(NSDictionary *reported, NSError *reportedError) { info = reported; error = reportedError; }];
	XCTAssertEqualObjects(info[FxGripLicensingProductInfoProductName], @"Product");
	XCTAssertEqualObjects(info[FxGripLicensingProductInfoLatestVersion], @"2.0");
	XCTAssertEqualObjects(info[FxGripLicensingProductInfoRequiredStoreVersion], @"9.0.6");
	XCTAssertEqualWithAccuracy([info[FxGripLicensingProductInfoPriceUSD] floatValue], 49.5f, 0.001);
	XCTAssertNil(info[FxGripLicensingProductInfoRequiredOSVersion]);
	XCTAssertEqualObjects(info[FxGripLicensingProductInfoDiscontinued], @NO);
	XCTAssertEqualObjects(info[FxGripLicensingProductInfoProviderResponse], self.provider.cannedProductInfo);
	XCTAssertNil(error);

	self.provider.cannedProductInfo = nil;
	self.provider.cannedProductInfoError = [NSError errorWithDomain:@"FxGripFxFactoryProviderTests" code:3 userInfo:nil];
	[self.provider fetchProductInfoForProduct:@"p" handler:^(NSDictionary *reported, NSError *reportedError) { info = reported; error = reportedError; }];
	XCTAssertNil(info);
	XCTAssertEqualObjects(error, self.provider.cannedProductInfoError);
}

/*! @abstract The entitlement names the product and provider while licensed and is nil otherwise. */
- (void)testTheEntitlementFollowsTheStatus
{
	self.provider.mockStatus = kFxGripFxFactoryStatusLicensed;
	FxGripLicenseEntitlement *entitlement = [self.provider entitlementForProduct:@"product-uuid"];
	XCTAssertEqualObjects(entitlement.productID, @"product-uuid");
	XCTAssertEqualObjects(entitlement.providerName, @"fxfactory");
	XCTAssertEqual(entitlement.status, FxGripLicenseStatusLicensed);
	XCTAssertEqual(entitlement.kind, FxGripLicenseKindPerpetual);

	self.provider.mockStatus = kFxGripFxFactoryStatusUnlicensed;
	XCTAssertNil([self.provider entitlementForProduct:@"product-uuid"]);
}

#pragma mark Observation

/*! @abstract Starting an observation registers with the SDK and the callback reaches the handler through the registered context. */
- (void)testTheCallbackReachesTheHandlerThroughTheContext
{
	__block FxGripLicenseStatus reported = FxGripLicenseStatusUnknown;
	[self.provider startObservingProduct:@"uuid-A" handler:^(FxGripLicenseStatus status) { reported = status; }];
	XCTAssertEqualObjects(self.provider.registeredUUIDs, @[@"uuid-A"]);
	XCTAssertNotNil(self.provider.capturedHandler);

	self.provider.capturedHandler(kFxGripFxFactoryStatusLicensed, self.provider);
	XCTAssertEqual(reported, FxGripLicenseStatusLicensed);
}

/*! @abstract Re-observing a product unregisters the previous registration, and stopping releases it under its own UUID. */
- (void)testObservationsAreKeyedByProduct
{
	[self.provider startObservingProduct:@"uuid-A" handler:^(FxGripLicenseStatus status) {}];
	[self.provider startObservingProduct:@"uuid-A" handler:^(FxGripLicenseStatus status) {}];
	XCTAssertEqualObjects(self.provider.unregisteredUUIDs, @[@"uuid-A"], @"a second start replaces the first");

	[self.provider startObservingProduct:@"uuid-B" handler:^(FxGripLicenseStatus status) {}];
	[self.provider stopObservingProduct:@"uuid-A"];
	[self.provider stopObservingProduct:@"uuid-B"];
	[self.provider stopObservingProduct:@"uuid-C"];
	XCTAssertEqualObjects(self.provider.unregisteredUUIDs, (@[@"uuid-A", @"uuid-A", @"uuid-B"]), @"an unobserved product is ignored");
}

/*! @abstract A callback for a product that stopped observing reaches no handler. */
- (void)testACallbackAfterStopReachesNoHandler
{
	__block NSUInteger calls = 0;
	[self.provider startObservingProduct:@"uuid-A" handler:^(FxGripLicenseStatus status) { calls += 1; }];
	void (^handler)(NSUInteger, id) = self.provider.capturedHandler;
	[self.provider stopObservingProduct:@"uuid-A"];
	handler(kFxGripFxFactoryStatusLicensed, self.provider);
	XCTAssertEqual(calls, (NSUInteger)0);
}

/*! @abstract Deallocating the provider releases every registration. */
- (void)testDeallocationReleasesEveryRegistration
{
	NSMutableArray<NSString *> *unregistered = nil;
	@autoreleasepool {
		FxGripFxFactoryProviderMock *provider = [FxGripFxFactoryProviderMock.alloc init];
		unregistered = provider.unregisteredUUIDs;
		[provider startObservingProduct:@"uuid-A" handler:^(FxGripLicenseStatus status) {}];
		[provider startObservingProduct:@"uuid-B" handler:^(FxGripLicenseStatus status) {}];
		provider = nil;
	}
	XCTAssertEqual(unregistered.count, (NSUInteger)2);
	XCTAssertTrue([unregistered containsObject:@"uuid-A"]);
	XCTAssertTrue([unregistered containsObject:@"uuid-B"]);
}

#pragma mark Actions

/*! @abstract Buy requests Show and Buy together, and Show Product requests Show alone. */
- (void)testTheActionsRequestTheirLicensingActionMask
{
	XCTAssertTrue([self.provider buyProduct:@"p"]);
	XCTAssertTrue([self.provider showProduct:@"p"]);
	XCTAssertEqualObjects(self.provider.actions, (@[@(kFxGripFxFactoryActionShow | kFxGripFxFactoryActionBuy), @(kFxGripFxFactoryActionShow)]));
}

/*! @abstract Update checking reads and writes through the seams. */
- (void)testUpdateCheckingReadsAndWritesThroughTheSeams
{
	self.provider.updateCheckingEnabled = YES;
	XCTAssertTrue([self.provider updateCheckingEnabledForProduct:@"p"]);
	[self.provider setUpdateCheckingEnabled:NO forProduct:@"p"];
	XCTAssertEqualObjects(self.provider.updateCheckingWrites, @[@NO]);
}

/*! @abstract An update check translates the FxFactory response into the neutral keys and carries the response whole. */
- (void)testAnUpdateCheckTranslatesTheResponse
{
	NSString *newVersion = FxGripFxFactoryTestResponseKey("kFxFactoryUpdateCheckingNewVersionFound");
	NSString *postponed = FxGripFxFactoryTestResponseKey("kFxFactoryUpdateCheckingPostponed");
	NSString *productInfo = FxGripFxFactoryTestResponseKey("kFxFactoryUpdateCheckingProductInfo");
	NSString *latest = FxGripFxFactoryTestResponseKey("kFxFactoryLicensingProductLatestVersion");
	NSString *discontinued = FxGripFxFactoryTestResponseKey("kFxFactoryLicensingProductIsDiscontinued");
	if (!newVersion || !postponed || !productInfo || !latest || !discontinued) {
		XCTSkip(@"the FxFactory response keys are weak-linked constants and FxFactory is not installed");
	}
	self.provider.cannedResponse = @{newVersion: @YES, postponed: @NO, productInfo: @{latest: @"2.0", discontinued: @YES}};

	__block NSDictionary *info = nil;
	[self.provider checkForUpdatesForProduct:@"p" version:@"1.0" force:YES handler:^(NSDictionary *reported) { info = reported; }];

	XCTAssertTrue(self.provider.recordedForce);
	XCTAssertEqualObjects(self.provider.recordedVersion, @"1.0");
	XCTAssertEqualObjects(info[FxGripLicensingUpdateInfoNewVersionFound], @YES);
	XCTAssertEqualObjects(info[FxGripLicensingUpdateInfoPostponed], @NO);
	NSDictionary *product = info[FxGripLicensingUpdateInfoProductInfo];
	XCTAssertEqualObjects(product[FxGripLicensingProductInfoLatestVersion], @"2.0");
	XCTAssertEqualObjects(product[FxGripLicensingProductInfoDiscontinued], @YES);
	XCTAssertNil(product[FxGripLicensingProductInfoPriceUSD], @"an absent price is omitted");
	XCTAssertNil(info[FxGripLicensingUpdateInfoError]);
	XCTAssertEqualObjects(info[FxGripLicensingUpdateInfoProviderResponse], self.provider.cannedResponse);
}

/*! @abstract A nil response reports nothing. */
- (void)testANilResponseReportsNothing
{
	__block NSUInteger reports = 0;
	[self.provider checkForUpdatesForProduct:@"p" version:@"1.0" force:NO handler:^(NSDictionary *reported) { reports += 1; }];
	XCTAssertEqual(reports, (NSUInteger)0);
	XCTAssertFalse(self.provider.recordedForce);
}

#pragma mark The contact form

/*! @abstract The support form sends with no recipient, and the explicit form sends only to an fxfactory.com address. */
- (void)testTheContactFormGuardsTheRecipient
{
	XCTAssertTrue([self.provider showSupportFormWithSubject:@"s" message:@"m"]);
	XCTAssertTrue([self.provider showContactFormToRecipient:@"support@fxfactory.com" subject:@"s" message:@"m"]);
	XCTAssertFalse([self.provider showContactFormToRecipient:@"someone@external.example" subject:@"s" message:@"m"]);
	XCTAssertEqualObjects(self.provider.contactRecipients, (@[@"", @"support@fxfactory.com"]), @"the external recipient was rejected before the send");
}

/*! @abstract The contact form refuses when the SDK form is unavailable. */
- (void)testTheContactFormRefusesWhenUnavailable
{
	self.provider.contactFormAvailable = NO;
	XCTAssertFalse([self.provider showSupportFormWithSubject:@"s" message:@"m"]);
	XCTAssertFalse([self.provider showContactFormToRecipient:@"support@fxfactory.com" subject:@"s" message:@"m"]);
	XCTAssertEqual(self.provider.contactRecipients.count, (NSUInteger)0);
}

#pragma mark The host configuration check

- (NSMutableDictionary *)validInfo
{
	return @{
		@"com.apple.security.app-sandbox": @NO,
		@"com.apple.security.cs.disable-library-validation": @YES,
		@"NSUpdateSecurityPolicy": @{
			@"AllowPackages": @[kFxFactoryPackageID],
			@"AllowProcesses": @{kFxFactoryPackageID: @[kFxFactoryBundleProcess, kFxFactoryBundleProcessHelper]}
		}
	}.mutableCopy;
}

- (NSArray<NSString *> *)problemsForInfo:(NSDictionary *)info
{
	FxGripFxFactoryProviderInfoBundleStub *bundle = [FxGripFxFactoryProviderInfoBundleStub.alloc init];
	bundle.info = info;
	return [self.provider hostConfigurationProblemsForBundle:(NSBundle *)bundle];
}

/*! @abstract A complete entitlement set reports no problem. */
- (void)testACompleteEntitlementSetPassesTheCheck
{
	XCTAssertEqualObjects([self problemsForInfo:[self validInfo]], @[]);
}

/*! @abstract A missing or mistyped app sandbox is reported, and an enabled one is reported unless the shared-preference exception names FxFactory. */
- (void)testTheCheckReportsABadAppSandboxEntitlement
{
	NSMutableDictionary *info = [self validInfo];
	[info removeObjectForKey:@"com.apple.security.app-sandbox"];
	XCTAssertEqual([self problemsForInfo:info].count, (NSUInteger)1);
	info[@"com.apple.security.app-sandbox"] = @"NO";
	XCTAssertEqual([self problemsForInfo:info].count, (NSUInteger)1);
	info[@"com.apple.security.app-sandbox"] = @YES;
	XCTAssertEqual([self problemsForInfo:info].count, (NSUInteger)1);
	XCTAssertTrue([[self problemsForInfo:info].firstObject containsString:kFxFactorySharedPreferenceEntitlement]);

	info[kFxFactorySharedPreferenceEntitlement] = @[@"com.other.app"];
	XCTAssertEqual([self problemsForInfo:info].count, (NSUInteger)1, @"the exception must name FxFactory");
	info[kFxFactorySharedPreferenceEntitlement] = @[@"com.other.app", kFxFactoryBundleProcess];
	XCTAssertEqualObjects([self problemsForInfo:info], @[], @"a sandboxed plugin with the exception is configured");
	info[kFxFactorySharedPreferenceEntitlement] = kFxFactoryBundleProcess;
	XCTAssertEqualObjects([self problemsForInfo:info], @[], @"the exception may be a single string");
}

/*! @abstract A missing, mistyped, or enabled library validation is reported. */
- (void)testTheCheckReportsABadLibraryValidationEntitlement
{
	NSMutableDictionary *info = [self validInfo];
	[info removeObjectForKey:@"com.apple.security.cs.disable-library-validation"];
	XCTAssertEqual([self problemsForInfo:info].count, (NSUInteger)1);
	info[@"com.apple.security.cs.disable-library-validation"] = @"YES";
	XCTAssertEqual([self problemsForInfo:info].count, (NSUInteger)1);
	info[@"com.apple.security.cs.disable-library-validation"] = @NO;
	XCTAssertEqual([self problemsForInfo:info].count, (NSUInteger)1);
}

/*! @abstract Every shape of a bad update security policy is reported. */
- (void)testTheCheckReportsABadUpdatePolicy
{
	NSArray *packages = @[kFxFactoryPackageID];
	NSDictionary *processes = @{kFxFactoryPackageID: @[kFxFactoryBundleProcess, kFxFactoryBundleProcessHelper]};
	NSMutableDictionary *info = [self validInfo];

	[info removeObjectForKey:@"NSUpdateSecurityPolicy"];
	XCTAssertEqual([self problemsForInfo:info].count, (NSUInteger)1, @"the policy must be present");
	info[@"NSUpdateSecurityPolicy"] = @[@"not a dictionary"];
	XCTAssertEqual([self problemsForInfo:info].count, (NSUInteger)1, @"the policy must be a dictionary");

	info[@"NSUpdateSecurityPolicy"] = @{@"AllowProcesses": processes};
	XCTAssertEqual([self problemsForInfo:info].count, (NSUInteger)1, @"AllowPackages must be present");
	info[@"NSUpdateSecurityPolicy"] = @{@"AllowPackages": kFxFactoryPackageID, @"AllowProcesses": processes};
	XCTAssertEqual([self problemsForInfo:info].count, (NSUInteger)1, @"AllowPackages must be an array");
	info[@"NSUpdateSecurityPolicy"] = @{@"AllowPackages": @[@"OTHER"], @"AllowProcesses": processes};
	XCTAssertEqual([self problemsForInfo:info].count, (NSUInteger)1, @"AllowPackages must name the FxFactory package");

	info[@"NSUpdateSecurityPolicy"] = @{@"AllowPackages": packages};
	XCTAssertEqual([self problemsForInfo:info].count, (NSUInteger)1, @"AllowProcesses must be present");
	info[@"NSUpdateSecurityPolicy"] = @{@"AllowPackages": packages, @"AllowProcesses": @[@"nope"]};
	XCTAssertEqual([self problemsForInfo:info].count, (NSUInteger)1, @"AllowProcesses must be a dictionary");
	info[@"NSUpdateSecurityPolicy"] = @{@"AllowPackages": packages, @"AllowProcesses": @{@"OTHER": @[]}};
	XCTAssertEqual([self problemsForInfo:info].count, (NSUInteger)1, @"AllowProcesses must key the FxFactory package");
	info[@"NSUpdateSecurityPolicy"] = @{@"AllowPackages": packages, @"AllowProcesses": @{kFxFactoryPackageID: @"nope"}};
	XCTAssertEqual([self problemsForInfo:info].count, (NSUInteger)1, @"the package's process list must be an array");

	info[@"NSUpdateSecurityPolicy"] = @{@"AllowPackages": packages, @"AllowProcesses": @{kFxFactoryPackageID: @[kFxFactoryBundleProcessHelper]}};
	XCTAssertEqual([self problemsForInfo:info].count, (NSUInteger)1, @"the FxFactory process must be listed");
	info[@"NSUpdateSecurityPolicy"] = @{@"AllowPackages": packages, @"AllowProcesses": @{kFxFactoryPackageID: @[kFxFactoryBundleProcess]}};
	XCTAssertEqual([self problemsForInfo:info].count, (NSUInteger)1, @"the FxFactory helper process must be listed");

	info[@"NSUpdateSecurityPolicy"] = @{@"AllowPackages": @[@"OTHER"], @"AllowProcesses": @{@"OTHER": @[]}};
	XCTAssertEqual([self problemsForInfo:info].count, (NSUInteger)2, @"each problem is reported, and the check continues");
}

#pragma mark The response dictionary accessors

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
}

/*! @abstract The update-response error and product info are returned only when they carry the expected type. */
- (void)testTheUpdateResponseErrorAndProductInfoAreTypeChecked
{
	NSString *errorKey = [self responseKeyOrSkip:"kFxFactoryUpdateCheckingError"];
	NSString *productKey = [self responseKeyOrSkip:"kFxFactoryUpdateCheckingProductInfo"];

	NSError *error = [NSError errorWithDomain:@"FxGripFxFactoryProviderTests" code:1 userInfo:nil];
	NSDictionary *response = @{errorKey: error, productKey: @{@"name": @"Product"}};
	XCTAssertEqualObjects(response.fxFactoryUpdateCheckingError, error);
	XCTAssertEqualObjects(response.fxFactoryUpdateCheckingProductInfo, @{@"name": @"Product"});

	NSDictionary *mistyped = @{errorKey: @"not an error", productKey: @"not a dictionary"};
	XCTAssertNil(mistyped.fxFactoryUpdateCheckingError);
	XCTAssertNil(mistyped.fxFactoryUpdateCheckingProductInfo);
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

	NSDictionary *info = @{name: @"Product", latest: @"2.0", requiredOS: @"14.0", requiredFx: @"8.0", discontinued: @YES, price: @49.5f};
	XCTAssertEqualObjects(info.fxFactoryProductName, @"Product");
	XCTAssertEqualObjects(info.fxFactoryProductLatestVersion, @"2.0");
	XCTAssertEqualObjects(info.fxFactoryProductLatestVersionRequiredOSVersion, @"14.0");
	XCTAssertEqualObjects(info.fxFactoryProductLatestVersionRequiredFxFactoryVersion, @"8.0");
	XCTAssertTrue(info.fxFactoryProductIsDiscontinued);
	XCTAssertEqualWithAccuracy(info.fxFactoryProductPriceInUSD, 49.5f, 0.001);

	NSDictionary *mistyped = @{name: @1, latest: @1, requiredOS: @1, requiredFx: @1, discontinued: @"YES", price: @"49.5"};
	XCTAssertNil(mistyped.fxFactoryProductName);
	XCTAssertNil(mistyped.fxFactoryProductLatestVersion);
	XCTAssertNil(mistyped.fxFactoryProductLatestVersionRequiredOSVersion);
	XCTAssertNil(mistyped.fxFactoryProductLatestVersionRequiredFxFactoryVersion);
	XCTAssertFalse(mistyped.fxFactoryProductIsDiscontinued);
	XCTAssertTrue(isnan(mistyped.fxFactoryProductPriceInUSD), @"an absent price reads as NAN");
}

#pragma mark The read-only SDK seams

// Only the seams that read state run against a live FxFactory. The seams that perform a
// licensing action, start an update check, write the update-checking preference, or open the
// contact form drive real UI, network, and preference side effects, so they are left to a host.

/*! @abstract The version seam reports zero without FxFactory and a real version with it. */
- (void)testTheVersionSeamReportsZeroWithoutFxFactory
{
	FxGripFxFactoryProvider *provider = [FxGripFxFactoryProvider.alloc init];
	NSOperatingSystemVersion version = [provider factoryVersion];
	if (!provider.fxFactoryIsInstalled) {
		XCTAssertEqual(version.majorVersion, (NSInteger)0);
		XCTAssertEqual(version.minorVersion, (NSInteger)0);
		XCTAssertEqual(version.patchVersion, (NSInteger)0);
	} else {
		XCTAssertGreaterThan(version.majorVersion, (NSInteger)0, @"an installed FxFactory reports a real version");
	}
}

/*! @abstract The status seam never reports a product FxFactory does not know as licensed. */
- (void)testTheStatusSeamReportsAnUnknownProductUnlicensed
{
	FxGripFxFactoryProvider *provider = [FxGripFxFactoryProvider.alloc init];
	XCTAssertNotEqual([provider factoryLicensingStatusForProduct:@"FXGRIP-TEST-UNKNOWN-PRODUCT"], (NSUInteger)kFxGripFxFactoryStatusLicensed);
	XCTAssertNotEqual([provider licenseStatusForProduct:@"FXGRIP-TEST-UNKNOWN-PRODUCT"], FxGripLicenseStatusLicensed);
	XCTAssertNotEqual([provider licenseStatusForProduct:@"FXGRIP-TEST-UNKNOWN-PRODUCT" version:((NSOperatingSystemVersion){1, 0, 0})], FxGripLicenseStatusLicensed);
	XCTAssertFalse([provider upgradeAvailableForProduct:@"FXGRIP-TEST-UNKNOWN-PRODUCT"]);
	XCTAssertFalse([provider factoryUpdateCheckingEnabledForProduct:@"FXGRIP-TEST-UNKNOWN-PRODUCT"]);
}

/*! @abstract Registering and unregistering through the SDK seams leaves no handler behind. */
- (void)testTheRegistrationSeamsRegisterAndUnregister
{
	FxGripFxFactoryProvider *provider = [FxGripFxFactoryProvider.alloc init];
	[provider startObservingProduct:@"FXGRIP-TEST-UNKNOWN-PRODUCT" handler:^(FxGripLicenseStatus status) {}];
	XCTAssertNoThrow([provider stopObservingProduct:@"FXGRIP-TEST-UNKNOWN-PRODUCT"]);
	XCTAssertNoThrow([provider stopObservingProduct:@"FXGRIP-TEST-UNKNOWN-PRODUCT"]);
}

@end
