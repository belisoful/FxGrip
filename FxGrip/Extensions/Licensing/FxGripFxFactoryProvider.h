/*!
	@file       FxGripFxFactoryProvider.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-03
	@header     FxGripFxFactoryProvider
	@abstract   The licensing provider that drives FxFactory licensing, product pages, updates, and support.
	@discussion Introduced in FxGrip 0.1.0. The provider wraps the FxFactory SDK for ``FxGripLicensing``.
	            Each SDK entry point is reached through an overridable seam, so the licensing logic
	            is testable without a live FxFactory installation. The SDK symbols are weak-linked and
	            imported only by the implementation, so this header compiles without the SDK; the
	            seams use plain integers where the SDK uses its enums. The provider registers under
	            `fxfactory` when the framework loads. A plugin sold through FxFactory sets the
	            `fxFactory` plugin property, or names `fxfactory` in its `licensing` property.
*/

#ifndef FxGripFxFactoryProvider_h
#define FxGripFxFactoryProvider_h

#import <Foundation/Foundation.h>
#import <FxGrip/FxGripLicensingProvider.h>

/*! The registry name of the FxFactory provider. */
#define kFxGripLicensingProviderName_FxFactory	@"fxfactory"

/*! The FxFactory package identifier the update security policy must allow. */
#define kFxFactoryPackageID @"AZLNLGPTT3"
/*! The FxFactory application bundle process the update security policy must allow. */
#define kFxFactoryBundleProcess @"com.fxfactory.FxFactory"
/*! The FxFactory helper bundle process the update security policy must allow. */
#define kFxFactoryBundleProcessHelper @"com.fxfactory.FxFactory.helper"
/*! The entitlement a sandboxed plugin needs to read FxFactory's preferences. */
#define kFxFactorySharedPreferenceEntitlement @"com.apple.security.temporary-exception.shared-preference.read-only"

// The FxFactory licensing status and action values, as the SDK defines them.
/*! `kFxFactoryLicensingStatusProductUnlicensed`. */
#define kFxGripFxFactoryStatusUnlicensed	2
/*! `kFxFactoryLicensingStatusProductLicensed`. */
#define kFxGripFxFactoryStatusLicensed		3
/*! `kFxFactoryLicensingActionShow`. */
#define kFxGripFxFactoryActionShow			(1 << 0)
/*! `kFxFactoryLicensingActionBuy`. */
#define kFxGripFxFactoryActionBuy			(1 << 1)


/*!
	@class		FxGripFxFactoryProvider
	@abstract	The FxFactory licensing provider.
	@discussion	Introduced in FxGrip 0.1.0. FxFactory's four product statuses equal the first four
				`FxGripLicenseStatus` values; any other SDK value reads as Unknown. The provider
				keys each observation by product UUID and reaches itself from the SDK callback
				through the registered context, so the callback block captures nothing. Update
				responses and product information are translated into the
				`FxGripLicensingUpdateInfo*` and `FxGripLicensingProductInfo*` keys, with the SDK's
				own dictionary under the `ProviderResponse` key. Version-gated status and the
				upgrade check need FxFactory 9.0.6; an older FxFactory reports the product's
				status and no upgrade. The host configuration check verifies the Info.plist keys
				FxFactory requires: library validation disabled, `NSUpdateSecurityPolicy` allowing
				the FxFactory package and processes, and either the app sandbox off or the
				read-only shared-preference exception for `com.fxfactory.FxFactory`.
*/
@interface FxGripFxFactoryProvider : NSObject <FxGripLicensingProvider>

/*! YES when FxFactory is installed on the machine. */
@property (readonly) BOOL fxFactoryIsInstalled;
/*! The installed FxFactory version, or a zero version when FxFactory is absent. */
@property (readonly) NSOperatingSystemVersion fxFactoryVersion;

/*!
	@method		showContactFormToRecipient:subject:message:
	@abstract	Shows the FxFactory contact form addressed to a recipient.
	@param		recipient	The recipient; must end in "@fxfactory.com" when given. nil uses FxFactory's default.
	@param		subject		The prefilled subject, or nil.
	@param		message		The prefilled message, or nil.
	@return		YES when the form is shown; NO when the form is unavailable or the recipient is
				external. */
- (BOOL)showContactFormToRecipient:(nullable NSString *)recipient subject:(nullable NSString *)subject message:(nullable NSString *)message;

#pragma mark FxFactory SDK seams

// Every FxFactory SDK entry point is reached through one of these methods. A subclass
// overrides them with a mock to drive the licensing, update, and support logic end to end
// without a live FxFactory installation. The SDK symbols are weak-linked, so each guards its
// own null symbol.

/*! `FxFactoryIsInstalled()`. */
- (BOOL)factoryInstalled;
/*! `FxFactoryGetVersion()`, or zero when the symbol is absent. */
- (NSOperatingSystemVersion)factoryVersion;
/*! `FxFactoryGetLicensingStatus()`, as its raw `FxFactoryLicensingStatus` value. */
- (NSUInteger)factoryLicensingStatusForProduct:(nonnull NSString *)productUUID;
/*! `FxFactoryGetLicensingStatusForVersion()` (FxFactory 9.0.6); falls back to `FxFactoryGetLicensingStatus()` on an older FxFactory. */
- (NSUInteger)factoryLicensingStatusForProduct:(nonnull NSString *)productUUID version:(NSOperatingSystemVersion)version;
/*! `FxFactoryLicenseIsUpgradable()` (FxFactory 9.0.6); NO on an older FxFactory. */
- (BOOL)factoryLicenseIsUpgradableForProduct:(nonnull NSString *)productUUID;
/*! `FxFactoryGetProductInfo()`; an absent symbol reports nil information and no error. */
- (void)factoryProductInfoForProduct:(nonnull NSString *)productUUID
							 handler:(nonnull void (^)(NSDictionary *_Nullable productInfo, NSError *_Nullable error))handler;
/*! `FxFactoryRegisterLicensingStatusChangeHandler()` with the provider as context; returns the registration. */
- (nullable id)factoryRegisterLicensingHandlerForProduct:(nonnull NSString *)productUUID
												 handler:(nonnull void (^)(NSUInteger status, id _Nullable context))handler;
/*! `FxFactoryUnregisterLicensingStatusHandler()`. */
- (void)factoryUnregisterLicensingHandler:(nonnull id)handle forProduct:(nonnull NSString *)productUUID;
/*! `FxFactoryShowProductUpdates()`. */
- (void)factoryShowProductUpdatesForProduct:(nonnull NSString *)productUUID
									version:(nonnull NSString *)version
									  force:(BOOL)force
									handler:(nullable void (^)(NSDictionary *_Nonnull response))handler;
/*! `FxFactoryIsProductUpdateCheckingEnabled()`. */
- (BOOL)factoryUpdateCheckingEnabledForProduct:(nonnull NSString *)productUUID;
/*! `FxFactorySetProductUpdateCheckingEnabled()`. */
- (void)factorySetUpdateCheckingEnabled:(BOOL)enabled forProduct:(nonnull NSString *)productUUID;
/*! `FxFactoryPerformLicensingAction()`, with the raw `FxFactoryLicensingAction` mask. */
- (BOOL)factoryPerformLicensingAction:(NSUInteger)action forProduct:(nonnull NSString *)productUUID;
/*! YES when `FxFactoryShowContactForm` is linked. */
- (BOOL)factoryContactFormAvailable;
/*! `FxFactoryShowContactForm()`. */
- (BOOL)factoryShowContactFormToRecipient:(nullable NSString *)recipient subject:(nullable NSString *)subject message:(nullable NSString *)message;

@end


/*!
	@abstract	Typed accessors for an FxFactory product update response dictionary.
	@discussion	Introduced in FxGrip 0.1.0. Each accessor reads one response key and coerces its
				value, returning a safe default when the key is absent or the wrong type. The
				response is the dictionary under `FxGripLicensingUpdateInfoProviderResponse`.
*/
@interface NSDictionary (FxFactoryProductUpdateResponse)

/*! YES when update checking is enabled. */
- (BOOL)fxFactoryUpdateCheckingEnabled;
/*! YES when update checking is postponed. */
- (BOOL)fxFactoryUpdateCheckingPostponed;
/*! YES when a new version was found. */
- (BOOL)fxFactoryUpdateCheckingNewVersionFound;
/*! The update-checking error, or nil. */
- (nullable NSError *)fxFactoryUpdateCheckingError;
/*! The nested product info dictionary, or nil. */
- (nullable NSDictionary *)fxFactoryUpdateCheckingProductInfo;

@end

/*!
	@abstract	Typed accessors for an FxFactory product info dictionary.
	@discussion	Introduced in FxGrip 0.1.0. The accessors read the product info returned in an update
				response, coercing each value and returning a safe default when it is absent.
*/
@interface NSDictionary (FxFactoryProductInfoResponse)

/*! The product name, or nil. */
- (nullable NSString *)fxFactoryProductName;
/*! The latest product version, or nil. */
- (nullable NSString *)fxFactoryProductLatestVersion;
/*! The macOS version the latest product version requires, or nil. */
- (nullable NSString *)fxFactoryProductLatestVersionRequiredOSVersion;
/*! The FxFactory version the latest product version requires, or nil. */
- (nullable NSString *)fxFactoryProductLatestVersionRequiredFxFactoryVersion;
/*! YES when the product is discontinued. */
- (BOOL)fxFactoryProductIsDiscontinued;
/*! The product price in USD, or NAN when absent. */
- (float)fxFactoryProductPriceInUSD;

@end

#endif
