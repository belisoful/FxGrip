/*!
	@file       FxGripFxFactoryProvider.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-03
	@header     FxGripFxFactoryProvider
	@abstract   Implements the FxFactory licensing provider.
	@discussion Introduced in FxGrip 0.1.0. Every FxFactory SDK entry point is reached through an
	            overridable seam, so the provider is testable with a mock. The SDK calls its status
	            handler on its own thread, so the observation table is synchronized.
*/

#import <FxFactory/FxFactory.h>
#import "FxGripFxFactoryProvider.h"
#import "FxGripLicensing.h"
#import "FxGripLicenseEntitlement.h"

/*!
	@abstract	The FxFactory licensing provider.
	@discussion	Introduced in FxGrip 0.1.0. Observations are keyed by product UUID. The SDK callback
				reaches the provider through its registered context and captures only the product
				UUID, so the provider deallocates and unregisters.
*/
@implementation FxGripFxFactoryProvider
{
	NSMutableDictionary<NSString *, id> *_registrations;
	NSMutableDictionary<NSString *, FxGripLicenseStatusHandler> *_handlers;
	BOOL _installed;
}

+ (void)load
{
	[FxGripLicensing registerProviderClass:self forName:kFxGripLicensingProviderName_FxFactory];
}

- (instancetype)init
{
	self = [super init];
	if (self) {
		_registrations = NSMutableDictionary.new;
		_handlers = NSMutableDictionary.new;
		_installed = [self factoryInstalled];
	}
	return self;
}

- (void)dealloc
{
	for (NSString *productUUID in [self observedProducts]) {
		[self stopObservingProduct:productUUID];
	}
}

- (NSArray<NSString *> *)observedProducts
{
	@synchronized (_handlers) {
		return _handlers.allKeys;
	}
}

#pragma mark -
#pragma mark FxGripLicensingProvider

- (NSString *)providerName
{
	return kFxGripLicensingProviderName_FxFactory;
}

- (BOOL)isAvailable
{
	return _installed;
}

- (BOOL)fxFactoryIsInstalled
{
	return _installed;
}

- (NSOperatingSystemVersion)fxFactoryVersion
{
	return [self factoryVersion];
}

/*! FxFactory's four product statuses map directly; any other value, such as the Swift-only
	APIUnavailable, reads as Unknown. */
static FxGripLicenseStatus FxGripStatusFromFxFactory(NSUInteger status)
{
	return status <= kFxGripFxFactoryStatusLicensed ? (FxGripLicenseStatus)status : FxGripLicenseStatusUnknown;
}

- (FxGripLicenseStatus)licenseStatusForProduct:(NSString *)productUUID
{
	return FxGripStatusFromFxFactory([self factoryLicensingStatusForProduct:productUUID]);
}

- (FxGripLicenseStatus)licenseStatusForProduct:(NSString *)productUUID version:(NSOperatingSystemVersion)version
{
	return FxGripStatusFromFxFactory([self factoryLicensingStatusForProduct:productUUID version:version]);
}

- (BOOL)upgradeAvailableForProduct:(NSString *)productUUID
{
	return [self factoryLicenseIsUpgradableForProduct:productUUID];
}

- (void)fetchProductInfoForProduct:(NSString *)productUUID handler:(FxGripLicenseProductInfoHandler)handler
{
	[self factoryProductInfoForProduct:productUUID handler:^(NSDictionary *productInfo, NSError *error) {
		handler(productInfo != nil ? [FxGripFxFactoryProvider productInfoForResponse:productInfo] : nil, error);
	}];
}

+ (NSDictionary<NSString *, id> *)productInfoForResponse:(NSDictionary *)response
{
	NSMutableDictionary *info = NSMutableDictionary.new;
	info[FxGripLicensingProductInfoProductName] = response.fxFactoryProductName;
	info[FxGripLicensingProductInfoLatestVersion] = response.fxFactoryProductLatestVersion;
	info[FxGripLicensingProductInfoRequiredOSVersion] = response.fxFactoryProductLatestVersionRequiredOSVersion;
	info[FxGripLicensingProductInfoRequiredStoreVersion] = response.fxFactoryProductLatestVersionRequiredFxFactoryVersion;
	info[FxGripLicensingProductInfoDiscontinued] = @(response.fxFactoryProductIsDiscontinued);
	float price = response.fxFactoryProductPriceInUSD;
	if (!isnan(price)) {
		info[FxGripLicensingProductInfoPriceUSD] = @(price);
	}
	info[FxGripLicensingProductInfoProviderResponse] = response;
	return info;
}

- (void)startObservingProduct:(NSString *)productUUID handler:(FxGripLicenseStatusHandler)handler
{
	[self stopObservingProduct:productUUID];

	@synchronized (_handlers) {
		_handlers[productUUID] = [handler copy];
	}
	// Reach the provider only through the registered context. Capturing self would retain it
	// for the life of the FxFactory registration, so dealloc (and the unregister it runs)
	// could never fire, leaking the handler.
	NSString *observedUUID = [productUUID copy];
	id registration = [self factoryRegisterLicensingHandlerForProduct:productUUID handler:^(NSUInteger status, id _Nullable context) {
		FxGripFxFactoryProvider *provider = (FxGripFxFactoryProvider *)context;
		[provider deliverStatus:status forProduct:observedUUID];
	}];
	if (registration != nil) {
		@synchronized (_handlers) {
			_registrations[productUUID] = registration;
		}
	}
}

- (void)stopObservingProduct:(NSString *)productUUID
{
	id registration = nil;
	@synchronized (_handlers) {
		registration = _registrations[productUUID];
		[_registrations removeObjectForKey:productUUID];
		[_handlers removeObjectForKey:productUUID];
	}
	if (registration != nil) {
		[self factoryUnregisterLicensingHandler:registration forProduct:productUUID];
	}
}

/*! Runs the handler observing a product with the SDK's status. */
- (void)deliverStatus:(NSUInteger)status forProduct:(NSString *)productUUID
{
	FxGripLicenseStatusHandler handler = nil;
	@synchronized (_handlers) {
		handler = _handlers[productUUID];
	}
	if (handler) {
		handler(FxGripStatusFromFxFactory(status));
	}
}

- (FxGripLicenseEntitlement *)entitlementForProduct:(NSString *)productUUID
{
	FxGripLicenseStatus status = [self licenseStatusForProduct:productUUID];
	if (status != FxGripLicenseStatusLicensed) {
		return nil;
	}
	return [FxGripLicenseEntitlement entitlementWithProductID:productUUID providerName:self.providerName status:status];
}

- (BOOL)buyProduct:(NSString *)productUUID
{
	// The SDK recommends combining Buy with Show.
	return [self factoryPerformLicensingAction:kFxGripFxFactoryActionShow | kFxGripFxFactoryActionBuy forProduct:productUUID];
}

- (BOOL)showProduct:(NSString *)productUUID
{
	return [self factoryPerformLicensingAction:kFxGripFxFactoryActionShow forProduct:productUUID];
}

- (BOOL)updateCheckingEnabledForProduct:(NSString *)productUUID
{
	return [self factoryUpdateCheckingEnabledForProduct:productUUID];
}

- (void)setUpdateCheckingEnabled:(BOOL)enabled forProduct:(NSString *)productUUID
{
	[self factorySetUpdateCheckingEnabled:enabled forProduct:productUUID];
}

/*!
	@method		checkForUpdatesForProduct:version:force:handler:
	@abstract	Checks for product updates and reports the translated response.
	@discussion	Introduced in FxGrip 0.1.0. The FxFactory response is translated into the
				`FxGripLicensingUpdateInfo*` keys and carried whole under
				`FxGripLicensingUpdateInfoProviderResponse`. A nil response reports nothing. */
- (void)checkForUpdatesForProduct:(NSString *)productUUID version:(NSString *)version force:(BOOL)force handler:(FxGripLicenseUpdateInfoHandler)handler
{
	[self factoryShowProductUpdatesForProduct:productUUID version:version force:force handler:^(NSDictionary *response) {
		if (response == nil || handler == nil) {
			return;
		}
		handler([FxGripFxFactoryProvider updateInfoForResponse:response]);
	}];
}

+ (NSDictionary<NSString *, id> *)updateInfoForResponse:(NSDictionary *)response
{
	NSMutableDictionary *info = NSMutableDictionary.new;
	info[FxGripLicensingUpdateInfoNewVersionFound] = @(response.fxFactoryUpdateCheckingNewVersionFound);
	info[FxGripLicensingUpdateInfoPostponed] = @(response.fxFactoryUpdateCheckingPostponed);
	info[FxGripLicensingUpdateInfoError] = response.fxFactoryUpdateCheckingError;
	NSDictionary *product = response.fxFactoryUpdateCheckingProductInfo;
	if (product != nil) {
		info[FxGripLicensingUpdateInfoProductInfo] = [self productInfoForResponse:product];
	}
	info[FxGripLicensingUpdateInfoProviderResponse] = response;
	return info;
}

- (BOOL)showSupportFormWithSubject:(NSString *)subject message:(NSString *)message
{
	return [self showContactFormToRecipient:nil subject:subject message:message];
}

- (BOOL)showContactFormToRecipient:(NSString *)recipient subject:(NSString *)subject message:(NSString *)message
{
	if (![self factoryContactFormAvailable]) {
		return NO;
	}
	if (recipient && ![recipient hasSuffix:@"@fxfactory.com"]) {
		NSLog(@"Error: The FxFactory Show Contact Form recipient '%@' must have an '@fxfactory.com' address.  External addresses are not allowed.", recipient);
		return NO;
	}
	return [self factoryShowContactFormToRecipient:recipient subject:subject message:message];
}

/*!
	@method		hostConfigurationProblemsForBundle:
	@abstract	Lists the Info.plist problems that keep FxFactory from licensing or updating the plugin.
	@discussion	Introduced in FxGrip 0.1.0. From https://fxfactory.com/developer/fxfactory-framework/:
				library validation must be disabled, `NSUpdateSecurityPolicy` must allow the
				FxFactory package and its two processes, and the app sandbox must be off unless the
				read-only shared-preference exception names `com.fxfactory.FxFactory`. */
- (NSArray<NSString *> *)hostConfigurationProblemsForBundle:(NSBundle *)bundle
{
	NSMutableArray<NSString *> *problems = NSMutableArray.new;

	id prop = [bundle objectForInfoDictionaryKey:@"com.apple.security.app-sandbox"];
	if (!prop) {
		[problems addObject:@"Info.plist must have property 'com.apple.security.app-sandbox'"];
	} else if (![prop isKindOfClass:NSNumber.class]) {
		[problems addObject:@"Info.plist property 'com.apple.security.app-sandbox' must be a Boolean"];
	} else if (((NSNumber *)prop).boolValue) {
		id exception = [bundle objectForInfoDictionaryKey:kFxFactorySharedPreferenceEntitlement];
		BOOL allowed = ([exception isKindOfClass:NSString.class] && [exception isEqualToString:kFxFactoryBundleProcess])
			|| ([exception isKindOfClass:NSArray.class] && [(NSArray *)exception containsObject:kFxFactoryBundleProcess]);
		if (!allowed) {
			[problems addObject:[NSString stringWithFormat:@"Info.plist property 'com.apple.security.app-sandbox' is YES/true, so property '%@' must contain '%@'", kFxFactorySharedPreferenceEntitlement, kFxFactoryBundleProcess]];
		}
	}

	prop = [bundle objectForInfoDictionaryKey:@"com.apple.security.cs.disable-library-validation"];
	if (!prop) {
		[problems addObject:@"Info.plist must have property 'com.apple.security.cs.disable-library-validation'"];
	} else if (![prop isKindOfClass:NSNumber.class]) {
		[problems addObject:@"Info.plist property 'com.apple.security.cs.disable-library-validation' must be a Boolean"];
	} else if (!((NSNumber *)prop).boolValue) {
		[problems addObject:@"Info.plist property 'com.apple.security.cs.disable-library-validation' must be set to YES/true"];
	}

	prop = [bundle objectForInfoDictionaryKey:@"NSUpdateSecurityPolicy"];
	if (!prop) {
		[problems addObject:@"Info.plist must have property 'NSUpdateSecurityPolicy'"];
	} else if (![prop isKindOfClass:NSDictionary.class]) {
		[problems addObject:@"Info.plist property 'NSUpdateSecurityPolicy' must be a Dictionary"];
	} else {
		NSDictionary *policy = (NSDictionary *)prop;
		id packages = policy[@"AllowPackages"];
		if (!packages) {
			[problems addObject:@"Info.plist property 'NSUpdateSecurityPolicy' does not have dictionary key 'AllowPackages' for software updating"];
		} else if (![packages isKindOfClass:NSArray.class]) {
			[problems addObject:@"Info.plist property 'NSUpdateSecurityPolicy' key 'AllowPackages' must be an array"];
		} else if (![(NSArray *)packages containsObject:kFxFactoryPackageID]) {
			[problems addObject:[NSString stringWithFormat:@"Info.plist property 'NSUpdateSecurityPolicy' key 'AllowPackages' array does not contain value '%@'", kFxFactoryPackageID]];
		}

		id processes = policy[@"AllowProcesses"];
		if (!processes) {
			[problems addObject:@"Info.plist property 'NSUpdateSecurityPolicy' does not have dictionary key 'AllowProcesses' for software updating"];
		} else if (![processes isKindOfClass:NSDictionary.class]) {
			[problems addObject:@"Info.plist property 'NSUpdateSecurityPolicy' key 'AllowProcesses' must be a dictionary for software updating"];
		} else {
			id packageProcesses = ((NSDictionary *)processes)[kFxFactoryPackageID];
			if (!packageProcesses) {
				[problems addObject:[NSString stringWithFormat:@"Info.plist property 'NSUpdateSecurityPolicy' key 'AllowProcesses' must have key '%@' for software updating", kFxFactoryPackageID]];
			} else if (![packageProcesses isKindOfClass:NSArray.class]) {
				[problems addObject:[NSString stringWithFormat:@"Info.plist property 'NSUpdateSecurityPolicy' key 'AllowProcesses' key '%@' is not an Array for software updating", kFxFactoryPackageID]];
			} else {
				NSArray *names = (NSArray *)packageProcesses;
				if (![names containsObject:kFxFactoryBundleProcess]) {
					[problems addObject:[NSString stringWithFormat:@"Info.plist property 'NSUpdateSecurityPolicy' key 'AllowProcesses' key '%@' array does not contain value '%@'", kFxFactoryPackageID, kFxFactoryBundleProcess]];
				}
				if (![names containsObject:kFxFactoryBundleProcessHelper]) {
					[problems addObject:[NSString stringWithFormat:@"Info.plist property 'NSUpdateSecurityPolicy' key 'AllowProcesses' key '%@' array does not contain value '%@'", kFxFactoryPackageID, kFxFactoryBundleProcessHelper]];
				}
			}
		}
	}
	return problems;
}

#pragma mark -
#pragma mark FxFactory SDK seams

- (BOOL)factoryInstalled
{
	// The SDK's own test for its presence: a weak symbol resolves only when FxFactory is installed.
	return FxFactoryGetLicensingStatus != NULL;
}

- (NSOperatingSystemVersion)factoryVersion
{
	if (FxFactoryGetVersion == NULL) {
		return (NSOperatingSystemVersion){0, 0, 0};
	}
	FxFactoryVersion version = FxFactoryGetVersion();
	return (NSOperatingSystemVersion){(NSInteger)version.major, (NSInteger)version.minor, (NSInteger)version.patch};
}

- (NSUInteger)factoryLicensingStatusForProduct:(NSString *)productUUID
{
	if (FxFactoryGetLicensingStatus == NULL) {
		return 0;
	}
	return FxFactoryGetLicensingStatus(productUUID);
}

- (NSUInteger)factoryLicensingStatusForProduct:(NSString *)productUUID version:(NSOperatingSystemVersion)version
{
	if (FxFactoryGetLicensingStatusForVersion == NULL) {
		// Before FxFactory 9.0.6 a license covers every version.
		return [self factoryLicensingStatusForProduct:productUUID];
	}
	FxFactoryVersion factoryVersion = {(NSUInteger)MAX(version.majorVersion, 0), (NSUInteger)MAX(version.minorVersion, 0), (NSUInteger)MAX(version.patchVersion, 0)};
	return FxFactoryGetLicensingStatusForVersion(productUUID, factoryVersion);
}

- (BOOL)factoryLicenseIsUpgradableForProduct:(NSString *)productUUID
{
	if (FxFactoryLicenseIsUpgradable == NULL) {
		return NO;
	}
	return FxFactoryLicenseIsUpgradable(productUUID);
}

- (void)factoryProductInfoForProduct:(NSString *)productUUID handler:(void (^)(NSDictionary *_Nullable, NSError *_Nullable))handler
{
	if (FxFactoryGetProductInfo == NULL) {
		handler(nil, nil);
		return;
	}
	// A nil queue would put the handler on the main queue, which the render thread may be
	// waiting on; a background queue keeps the fetch off it.
	FxFactoryGetProductInfo(productUUID, dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), handler);
}

- (id)factoryRegisterLicensingHandlerForProduct:(NSString *)productUUID handler:(void (^)(NSUInteger, id _Nullable))handler
{
	if (FxFactoryRegisterLicensingStatusChangeHandler == NULL) {
		return nil;
	}
	// FxFactoryLicensingStatus is an NSUInteger enum, so the block layouts match.
	return FxFactoryRegisterLicensingStatusChangeHandler(productUUID, self, (FxFactoryLicensingStatusChangeHandler)handler);
}

- (void)factoryUnregisterLicensingHandler:(id)handle forProduct:(NSString *)productUUID
{
	if (FxFactoryUnregisterLicensingStatusHandler != NULL) {
		FxFactoryUnregisterLicensingStatusHandler(productUUID, handle);
	}
}

- (void)factoryShowProductUpdatesForProduct:(NSString *)productUUID version:(NSString *)version force:(BOOL)force handler:(void (^)(NSDictionary *_Nonnull))handler
{
	if (FxFactoryShowProductUpdates != NULL) {
		FxFactoryShowProductUpdates(productUUID, version, force, handler);
	}
}

- (BOOL)factoryUpdateCheckingEnabledForProduct:(NSString *)productUUID
{
	if (FxFactoryIsProductUpdateCheckingEnabled == NULL) {
		return NO;
	}
	return FxFactoryIsProductUpdateCheckingEnabled(productUUID);
}

- (void)factorySetUpdateCheckingEnabled:(BOOL)enabled forProduct:(NSString *)productUUID
{
	if (FxFactorySetProductUpdateCheckingEnabled != NULL) {
		FxFactorySetProductUpdateCheckingEnabled(productUUID, enabled);
	}
}

- (BOOL)factoryPerformLicensingAction:(NSUInteger)action forProduct:(NSString *)productUUID
{
	if (FxFactoryPerformLicensingAction == NULL) {
		return NO;
	}
	return FxFactoryPerformLicensingAction((FxFactoryLicensingAction)action, productUUID);
}

- (BOOL)factoryContactFormAvailable
{
	return FxFactoryShowContactForm != NULL;
}

- (BOOL)factoryShowContactFormToRecipient:(NSString *)recipient subject:(NSString *)subject message:(NSString *)message
{
	return FxFactoryShowContactForm(recipient, subject, message);
}

@end


#pragma mark -

/*!
	@abstract	Typed accessors for an FxFactory product update response dictionary.
	@discussion	Introduced in FxGrip 0.1.0. Each accessor coerces one response key to its type.
*/
@implementation NSDictionary (FxFactoryProductUpdateResponse)

- (BOOL)fxFactoryUpdateCheckingEnabled
{
	NSNumber *value = self[kFxFactoryUpdateCheckingEnabled];
	return [value isKindOfClass:NSNumber.class] ? value.boolValue : NO;
}

- (BOOL)fxFactoryUpdateCheckingPostponed
{
	NSNumber *value = self[kFxFactoryUpdateCheckingPostponed];
	return [value isKindOfClass:NSNumber.class] ? value.boolValue : NO;
}

- (BOOL)fxFactoryUpdateCheckingNewVersionFound
{
	NSNumber *value = self[kFxFactoryUpdateCheckingNewVersionFound];
	return [value isKindOfClass:NSNumber.class] ? value.boolValue : NO;
}

- (NSError *)fxFactoryUpdateCheckingError
{
	NSError *value = self[kFxFactoryUpdateCheckingError];
	return [value isKindOfClass:NSError.class] ? value : nil;
}

- (NSDictionary *)fxFactoryUpdateCheckingProductInfo
{
	NSDictionary *value = self[kFxFactoryUpdateCheckingProductInfo];
	return [value isKindOfClass:NSDictionary.class] ? value : nil;
}

@end


#pragma mark -

/*!
	@abstract	Typed accessors for an FxFactory product info dictionary.
	@discussion	Introduced in FxGrip 0.1.0. The accessors read the product info in an update response.
*/
@implementation NSDictionary (FxFactoryProductInfoResponse)

- (NSString *)fxFactoryProductName
{
	NSString *value = self[kFxFactoryLicensingProductName];
	return [value isKindOfClass:NSString.class] ? value : nil;
}

- (NSString *)fxFactoryProductLatestVersion
{
	NSString *value = self[kFxFactoryLicensingProductLatestVersion];
	return [value isKindOfClass:NSString.class] ? value : nil;
}

- (NSString *)fxFactoryProductLatestVersionRequiredOSVersion
{
	NSString *value = self[kFxFactoryLicensingProductLatestVersionRequiredOSVersion];
	return [value isKindOfClass:NSString.class] ? value : nil;
}

- (NSString *)fxFactoryProductLatestVersionRequiredFxFactoryVersion
{
	NSString *value = self[kFxFactoryLicensingProductLatestVersionRequiredFxFactoryVersion];
	return [value isKindOfClass:NSString.class] ? value : nil;
}

- (BOOL)fxFactoryProductIsDiscontinued
{
	NSNumber *value = self[kFxFactoryLicensingProductIsDiscontinued];
	return [value isKindOfClass:NSNumber.class] ? value.boolValue : NO;
}

// NAN when absent; test with isnan().
- (float)fxFactoryProductPriceInUSD
{
	NSNumber *value = self[kFxFactoryLicensingProductPriceInUSD];
	return [value isKindOfClass:NSNumber.class] ? value.floatValue : NAN;
}

@end
