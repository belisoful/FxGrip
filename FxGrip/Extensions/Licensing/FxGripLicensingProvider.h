/*!
	@file       FxGripLicensingProvider.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-03
	@header     FxGripLicensingProvider
	@abstract   The store-neutral license status model and the protocol a licensing provider adopts.
	@discussion Introduced in FxGrip 0.1.0. ``FxGripLicensing`` owns one provider and asks it for the
	            status of the plugin's product, observes status changes through it, and routes the
	            buy, product-page, update, support, and license-key actions to it. The three required
	            methods cover status and observation. Every other method is optional; the extension
	            probes each with `respondsToSelector:` and adds the inspector parameter that drives it
	            only when the provider implements it. An abstract provider class therefore implements
	            no optional method, because a subclass inherits the capability along with the method.
*/

#ifndef FxGripLicensingProvider_h
#define FxGripLicensingProvider_h

#import <Foundation/Foundation.h>

@class FxGripLicenseEntitlement;

/*!
	@enum		FxGripLicenseStatus
	@abstract	The license status of one product.
	@discussion	Introduced in FxGrip 0.1.0. The first four values equal FxFactory's
				`FxFactoryLicensingStatus`. The remaining values carry what the App Store and
				license-key stores report and FxFactory does not. `FxGripLicenseStatusIsLicensed`
				names the statuses that unlock the plugin.
*/
typedef NS_ENUM(NSInteger, FxGripLicenseStatus) {
	/*! The provider is absent or has not been queried. */
	FxGripLicenseStatusUnknown			= 0,
	/*! The product identifier is not one the provider knows. */
	FxGripLicenseStatusInvalidProduct	= 1,
	/*! No license exists for the product. */
	FxGripLicenseStatusUnlicensed		= 2,
	/*! A license exists and is in force. */
	FxGripLicenseStatusLicensed			= 3,
	/*! The product is licensed for a limited period. */
	FxGripLicenseStatusTrial			= 4,
	/*! A trial or subscription has lapsed. */
	FxGripLicenseStatusExpired			= 5,
	/*! The last validation is stale, and the offline grace period has not ended. */
	FxGripLicenseStatusOfflineGrace		= 6,
	/*! The license was revoked by a refund, a chargeback, or a disabled key. */
	FxGripLicenseStatusRevoked			= 7,
};

/*!
	@function	FxGripLicenseStatusIsLicensed
	@abstract	Returns YES for the statuses that unlock the plugin: Licensed, Trial, and OfflineGrace.
	@discussion	Introduced in FxGrip 0.1.0. Whether a status renders clean is a separate decision made
				by ``FxGripLicensing``'s watermark configuration.
*/
NS_INLINE BOOL FxGripLicenseStatusIsLicensed(FxGripLicenseStatus status)
{
	return status == FxGripLicenseStatusLicensed
		|| status == FxGripLicenseStatusTrial
		|| status == FxGripLicenseStatusOfflineGrace;
}

/*! Receives a status reported by a provider's observation. May run on any thread. */
typedef void (^FxGripLicenseStatusHandler)(FxGripLicenseStatus status);

/*! Receives the result of an activate, validate, or deactivate call. May run on any thread. */
typedef void (^FxGripLicenseCompletion)(FxGripLicenseStatus status, NSError *_Nullable error);

/*! Receives the product update information a provider reports. The keys are the
	`FxGripLicensingUpdateInfo*` constants. */
typedef void (^FxGripLicenseUpdateInfoHandler)(NSDictionary<NSString *, id> *_Nonnull info);

/*! Receives the product information a provider fetches, keyed by the `FxGripLicensingProductInfo*`
	constants, or an error. Both are nil when the store answered nothing. */
typedef void (^FxGripLicenseProductInfoHandler)(NSDictionary<NSString *, id> *_Nullable info, NSError *_Nullable error);


// Update info keys. A provider that checks for updates reports these in its handler dictionary.

/*! `NSNumber` Boolean: a newer product version exists. */
extern NSString *const _Nonnull FxGripLicensingUpdateInfoNewVersionFound;
/*! `NSNumber` Boolean: the provider postponed the check. */
extern NSString *const _Nonnull FxGripLicensingUpdateInfoPostponed;
/*! `NSError`: the check failed. */
extern NSString *const _Nonnull FxGripLicensingUpdateInfoError;
/*! `NSDictionary`: the product information the check retrieved, keyed by `FxGripLicensingProductInfo*`. */
extern NSString *const _Nonnull FxGripLicensingUpdateInfoProductInfo;
/*! `NSDictionary`: the provider's own response, untranslated. */
extern NSString *const _Nonnull FxGripLicensingUpdateInfoProviderResponse;

// Product info keys. A provider that fetches product information reports these.

/*! `NSString`: the product name on the store. */
extern NSString *const _Nonnull FxGripLicensingProductInfoProductName;
/*! `NSString`: the newest product version. */
extern NSString *const _Nonnull FxGripLicensingProductInfoLatestVersion;
/*! `NSString`: the macOS version the newest product version requires. */
extern NSString *const _Nonnull FxGripLicensingProductInfoRequiredOSVersion;
/*! `NSString`: the store runtime version the newest product version requires. */
extern NSString *const _Nonnull FxGripLicensingProductInfoRequiredStoreVersion;
/*! `NSNumber` Boolean: the product is discontinued. */
extern NSString *const _Nonnull FxGripLicensingProductInfoDiscontinued;
/*! `NSNumber`: the price in US dollars. */
extern NSString *const _Nonnull FxGripLicensingProductInfoPriceUSD;
/*! `NSDictionary`: the provider's own response, untranslated. */
extern NSString *const _Nonnull FxGripLicensingProductInfoProviderResponse;


/*!
	@protocol	FxGripLicensingProvider
	@abstract	The store-specific half of licensing: status, observation, and the store's actions.
	@discussion	Introduced in FxGrip 0.1.0. A provider is a plain object, registered with
				``FxGripLicensing`` under a name and created from a plugin's registration record.
				The required methods never touch the network: `licenseStatusForProduct:` answers
				from the provider's cache, because the render path reads it. Optional methods are
				capabilities. The extension adds the Buy, Show Product, Update Checking, Enter
				License, and Deactivate parameters only when the matching method exists.
*/
@protocol FxGripLicensingProvider <NSObject>

/*! The registry name, for example `fxfactory` or `storekit`. */
@property (readonly, nonnull) NSString *providerName;

/*! YES when the store runtime is reachable from this process. */
@property (readonly) BOOL isAvailable;

/*!
	@method		licenseStatusForProduct:
	@abstract	The current status of a product, from the provider's cache.
	@discussion	Introduced in FxGrip 0.1.0. The call is synchronous and must not block on the
				network. A provider that has not yet validated reports Unknown. */
- (FxGripLicenseStatus)licenseStatusForProduct:(nonnull NSString *)productID;

/*!
	@method		startObservingProduct:handler:
	@abstract	Starts reporting status changes for a product to the handler.
	@discussion	Introduced in FxGrip 0.1.0. The provider keys the observation by product ID. A
				second start for the same product replaces the first. The handler may run on any
				thread, and the provider must not retain the handler past `stopObservingProduct:`. */
- (void)startObservingProduct:(nonnull NSString *)productID handler:(nonnull FxGripLicenseStatusHandler)handler;

/*! Stops the observation started for a product. A product with no observation is ignored. */
- (void)stopObservingProduct:(nonnull NSString *)productID;

@optional

/*! The entitlement behind the current status, or nil when the product is unlicensed. */
- (nullable FxGripLicenseEntitlement *)entitlementForProduct:(nonnull NSString *)productID;

// Version-gated licenses. Absent → every version of the product shares one status.

/*!
	@method		licenseStatusForProduct:version:
	@abstract	The status of a product for a version, from the provider's cache.
	@discussion	Introduced in FxGrip 0.1.0. Licensed means a license exists for this version or a
				later one. A version of all zeros asks whether any version is licensed. */
- (FxGripLicenseStatus)licenseStatusForProduct:(nonnull NSString *)productID version:(NSOperatingSystemVersion)version;
/*! YES when the holder is licensed for an earlier version only, so a paid upgrade applies. */
- (BOOL)upgradeAvailableForProduct:(nonnull NSString *)productID;

// Product information. Absent → fetchProductInfo: reports nothing.

/*! Fetches the store's information about the product; the handler may run on any thread. */
- (void)fetchProductInfoForProduct:(nonnull NSString *)productID handler:(nonnull FxGripLicenseProductInfoHandler)handler;

// Purchase and product page. Absent → no Buy or Show Product parameters.

/*! Starts the store's purchase flow for the product. Returns YES when the flow opened. */
- (BOOL)buyProduct:(nonnull NSString *)productID;
/*! Shows the store's page for the product. Returns YES when the page opened. */
- (BOOL)showProduct:(nonnull NSString *)productID;

// Update checking. Absent → no Product Version or Update Checking parameters.

/*! YES when the store checks the product for updates. */
- (BOOL)updateCheckingEnabledForProduct:(nonnull NSString *)productID;
/*! Enables or disables the store's update checking for the product. */
- (void)setUpdateCheckingEnabled:(BOOL)enabled forProduct:(nonnull NSString *)productID;
/*!
	@method		checkForUpdatesForProduct:version:force:handler:
	@abstract	Asks the store whether a newer version exists.
	@param		productID	The product.
	@param		version		The installed version.
	@param		force		YES checks now, ignoring any postpone interval.
	@param		handler		Receives the update information; may be nil. */
- (void)checkForUpdatesForProduct:(nonnull NSString *)productID
						  version:(nonnull NSString *)version
							force:(BOOL)force
						  handler:(nullable FxGripLicenseUpdateInfoHandler)handler;

// Support. Absent → the extension's showSupportFormWithSubject:message: returns NO.

/*! Shows the store's support form. Returns YES when the form opened. */
- (BOOL)showSupportFormWithSubject:(nullable NSString *)subject message:(nullable NSString *)message;

// License keys. Absent → no Enter License or Deactivate parameters.

/*! Presents the store's license entry, in the plugin's wrapper app. Returns YES when it opened. */
- (BOOL)showLicenseEntryForProduct:(nonnull NSString *)productID;
/*! Activates a license key for the product on this machine. */
- (void)activateLicenseKey:(nonnull NSString *)key
				forProduct:(nonnull NSString *)productID
				completion:(nonnull FxGripLicenseCompletion)completion;
/*! Revalidates the product's license with the store. */
- (void)validateLicenseForProduct:(nonnull NSString *)productID completion:(nonnull FxGripLicenseCompletion)completion;
/*! Releases this machine's activation. */
- (void)deactivateLicenseForProduct:(nonnull NSString *)productID completion:(nonnull FxGripLicenseCompletion)completion;

// Host configuration.

/*!
	@method		hostConfigurationProblemsForBundle:
	@abstract	Lists the Info.plist and entitlement problems that would keep the store from working.
	@discussion	Introduced in FxGrip 0.1.0. Each string names one problem. The extension logs them
				when the regression extension is loaded. An empty array means the bundle is
				configured for the store. */
- (nonnull NSArray<NSString *> *)hostConfigurationProblemsForBundle:(nonnull NSBundle *)bundle;

@end

#endif
