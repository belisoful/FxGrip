/*!
	@file       FxGripLicensing.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-03
	@header     FxGripLicensing
	@abstract   The extension that licenses a plugin through a store-neutral provider.
	@discussion Introduced in FxGrip 0.1.0. The extension is a hidden toggle whose value mirrors
	            whether the product is licensed. It owns one ``FxGripLicensingProvider`` and routes
	            every store call through it. It resolves each setting from the settings object, the
	            licensing parameter's dictionary, or the plugin's `licensing` registration dictionary
	            in that order, and adds the product, watermark, buy, product-page, update-checking,
	            license-entry, and deactivation parameters the plugin does not hard-code and the
	            provider can back. It caches the status, keeps the toggle in sync with the provider's
	            status changes, and watermarks the rendered frame by status. Providers register by
	            name; a plugin selects one through the `licensing` plugin property, or through the
	            `fxFactory` property as shorthand for the `fxfactory` provider.
*/

#ifndef FxGripLicensing_h
#define FxGripLicensing_h

#import <FxGrip/FxGripToggleExtension.h>
#import <FxGrip/FxGripTileableEffect.h>
#import <FxGrip/FxGripLicensingProvider.h>
#import <FxGrip/FxGripLicenseEntitlement.h>
#import <FxGrip/FxGripWatermark.h>

// Settings keys, read from the licensing parameter's dictionary and from the `licensing`
// plugin property when it is a dictionary.

/*! The registry name of the provider. Only read from the `licensing` plugin property. */
#define kFxGripLicensingProperty_Provider				@"provider"
/*! Boolean: the integration is active. */
#define kFxGripLicensingProperty_Active					@"active"
/*! String: the product identifier. `YES` means the plugin's own UUID. */
#define kFxGripLicensingProperty_ProductID				@"productID"
/*! String: the product version. `YES` means the plugin's own version. */
#define kFxGripLicensingProperty_ProductVersion			@"productVersion"
/*! String: the version a license must cover for this build. `YES` means the plugin's own version. */
#define kFxGripLicensingProperty_LicensedVersion		@"licensedVersion"
/*! Boolean: unlicensed frames carry the unlicensed watermark. Default YES. */
#define kFxGripLicensingProperty_WatermarkUnlicensed		@"watermarkUnlicensed"
/*! Boolean: trial frames carry the trial watermark. Default NO. */
#define kFxGripLicensingProperty_WatermarkTrial			@"watermarkTrial"
/*! Dictionary: the unlicensed watermark, in `FxGripWatermarkConfiguration` dictionary form. */
#define kFxGripLicensingProperty_UnlicensedWatermark		@"unlicensedWatermark"
/*! Dictionary: the trial watermark, in `FxGripWatermarkConfiguration` dictionary form. */
#define kFxGripLicensingProperty_TrialWatermark			@"trialWatermark"
/*! Boolean: the extension adds the Buy button. Default YES when the provider can buy. */
#define kFxGripLicensingProperty_ShowBuyButton			@"showBuyButton"
/*! Boolean: the extension adds the Show Product button. Default YES when the provider can. */
#define kFxGripLicensingProperty_ShowProductButton		@"showProductButton"
/*! Boolean: update checking is on. Default YES when the provider checks for updates. */
#define kFxGripLicensingProperty_AutoChecking			@"autoChecking"

/*! A DEBUG-only Boolean plugin property that forces the licensed or unlicensed status. */
#define kPropertiesLicensingDebugSetLicensed	@"LicensingDebugSetLicensed"
/*! A DEBUG-only `FxGripLicenseStatus` plugin property that forces any status. */
#define kPropertiesLicensingDebugSetStatus		@"LicensingDebugSetStatus"

/*! The parameter type string that marks the licensing parameter in the configuration. */
#define kFxParameterType_Licensing	@"licensing"
/*! The parameter type string that marked the FxFactory parameter; it means `licensing`. */
#define kFxParameterType_FxFactory	@"fxfactory"
/*! The FxParameterType four-char code the licensing type strings map to. */
#define FxParameterType_Licensing	'FxLc'

// Parameter ID offsets from the licensing toggle's own ID.
/*! The offset to the hidden Licensing Active toggle. */
#define kParameterLicensingActiveOffset					1
/*! The offset to the Product ID string parameter. */
#define kParameterLicensingProductIDOffset				2
/*! The offset to the Product Version string parameter. */
#define kParameterLicensingProductVersionOffset			3
/*! The offset to the hidden Unlicensed Watermark toggle. */
#define kParameterLicensingWatermarkUnlicensedOffset	4
/*! The offset to the Buy button. */
#define kParameterLicensingBuyButtonOffset				5
/*! The offset to the Buy Button Label string parameter. */
#define kParameterLicensingBuyButtonLabelOffset			6
/*! The offset to the Show Product button. */
#define kParameterLicensingProductButtonOffset			7
/*! The offset to the Product Button Label string parameter. */
#define kParameterLicensingProductButtonLabelOffset		8
/*! The offset to the Update Checking toggle. */
#define kParameterLicensingAutoCheckingOffset			9
/*! The offset to the Enter License button. */
#define kParameterLicensingLicenseEntryButtonOffset		10
/*! The offset to the Deactivate This Machine button. */
#define kParameterLicensingDeactivateButtonOffset		11
/*! The offset to the hidden Trial Watermark toggle. */
#define kParameterLicensingWatermarkTrialOffset			12

// Notifications, posted on the effect's notifier with the extension as the object.

/*! Posted when the license status changes. The userInfo carries the status, provider name, and entitlement. */
extern NSNotificationName const _Nonnull FxGripLicensingStatusChangeName;
/*! Posted before the buy flow starts. */
extern NSNotificationName const _Nonnull FxGripLicensingShowBuyName;
/*! Posted before the product page is shown. */
extern NSNotificationName const _Nonnull FxGripLicensingShowProductName;
/*! Posted before license entry is shown. */
extern NSNotificationName const _Nonnull FxGripLicensingShowLicenseEntryName;
/*! Posted before this machine's activation is released. */
extern NSNotificationName const _Nonnull FxGripLicensingDeactivateName;
/*! Posted when update checking is turned on or off. The userInfo carries the enabled flag. */
extern NSNotificationName const _Nonnull FxGripLicensingSetUpdateCheckingName;
/*! Posted when an update check reports. The userInfo is the `FxGripLicensingUpdateInfo*` dictionary. */
extern NSNotificationName const _Nonnull FxGripLicensingProductUpdateName;
/*! Posted when a product information fetch reports. The userInfo is the `FxGripLicensingProductInfo*` dictionary, or carries the error. */
extern NSNotificationName const _Nonnull FxGripLicensingProductInfoName;
/*! Posted before the support form is shown. The userInfo carries the subject and message. */
extern NSNotificationName const _Nonnull FxGripLicensingSupportFormName;

/*! userInfo key: the `FxGripLicenseStatus`, as an `NSNumber`. */
extern NSString *const _Nonnull FxGripLicensingStatusKey;
/*! userInfo key: the provider's registry name. */
extern NSString *const _Nonnull FxGripLicensingProviderNameKey;
/*! userInfo key: the ``FxGripLicenseEntitlement``, when the provider reports one. */
extern NSString *const _Nonnull FxGripLicensingEntitlementKey;
/*! userInfo key: an `NSNumber` Boolean. */
extern NSString *const _Nonnull FxGripLicensingEnabledKey;
/*! userInfo key: the support form subject. */
extern NSString *const _Nonnull FxGripLicensingSubjectKey;
/*! userInfo key: the support form message. */
extern NSString *const _Nonnull FxGripLicensingMessageKey;
/*! userInfo key: the `NSError` a fetch failed with. */
extern NSString *const _Nonnull FxGripLicensingErrorKey;


/*!
	@protocol	FxGripLicensingSettings
	@abstract	The optional hooks a plugin implements to hard-code licensing settings in code.
	@discussion	Introduced in FxGrip 0.1.0. A value supplied here takes precedence over the parameter
				dictionary and the `licensing` plugin property, and the corresponding parameter is
				not added. The effect itself is the settings object when it conforms.
*/
@protocol FxGripLicensingSettings <NSObject>

@optional

/*! YES when the integration is active. */
- (BOOL)licensingActive;
/*! The product identifier. */
- (nonnull NSString *)licensingProductID;
/*! The product version. */
- (nonnull NSString *)licensingProductVersion;
/*! The version a license must cover for this build. */
- (nonnull NSString *)licensingLicensedVersion;
/*! YES when unlicensed frames carry the unlicensed watermark. */
- (BOOL)licensingWatermarkUnlicensed;
/*! YES when trial frames carry the trial watermark. */
- (BOOL)licensingWatermarkTrial;
/*! The unlicensed watermark. */
- (nonnull FxGripWatermarkConfiguration *)licensingUnlicensedWatermarkConfiguration;
/*! The trial watermark. */
- (nonnull FxGripWatermarkConfiguration *)licensingTrialWatermarkConfiguration;
/*! YES when the extension adds the Buy button. */
- (BOOL)licensingShowBuyButton;
/*! YES when the extension adds the Show Product button. */
- (BOOL)licensingShowProductButton;
/*! YES when update checking is on. */
- (BOOL)licensingAutoChecking;

@end


/*!
	@class		FxGripLicensing
	@abstract	The extension that drives a plugin's licensing through a provider.
	@discussion	Introduced in FxGrip 0.1.0. The toggle value is YES while the status unlocks the
				plugin; an edit to it is reverted. Status reads come from a cache the provider's
				observation updates, so the render path never waits on a store. The watermark is
				chosen per status by `watermarkConfigurationForStatus:`.
*/
@interface FxGripLicensing : FxGripToggleExtension <FxGripStateParameter>

#pragma mark Provider registry

/*! Registers a provider class under a name. The class must adopt ``FxGripLicensingProvider``. */
+ (void)registerProviderClass:(nonnull Class)providerClass forName:(nonnull NSString *)name;
/*! The class registered under a name, or nil. Names compare case-insensitively. */
+ (nullable Class)providerClassForName:(nonnull NSString *)name;
/*! The registered names, sorted. */
+ (nonnull NSArray<NSString *> *)registeredProviderNames;
/*!
	@method		providerNameForPluginProperties:
	@abstract	The provider a plugin's registration record selects.
	@return		The `licensing` property's string, its dictionary's `provider`, `fxfactory` when
				only the `fxFactory` property is set, or nil. */
+ (nullable NSString *)providerNameForPluginProperties:(nullable NSDictionary *)pluginProperties;

#pragma mark Creation

/*! Creates the extension with its provider. A nil provider leaves the extension inert. */
- (nonnull instancetype)initWithProvider:(nullable id<FxGripLicensingProvider>)provider NS_DESIGNATED_INITIALIZER;
/*! Creates the extension without a provider. */
- (nonnull instancetype)init;

/*! The provider, or nil when none was supplied. */
@property (readonly, nullable) id<FxGripLicensingProvider> provider;

#pragma mark Status

/*! The product identifier, resolved from the settings, parameter, or plugin property. */
@property (readonly, nonatomic, nonnull) NSString *productID;
/*! The product version, resolved the same way; the plugin's own version when none is declared. */
@property (readonly, nonatomic, nonnull) NSString *productVersion;
/*!
	@property	licensedVersion
	@abstract	The version a license must cover, or nil when every version shares one status.
	@discussion	Introduced in FxGrip 0.1.0. When set and the provider gates licenses by version,
				`licenseStatus` asks for this version, so a license for an earlier major version
				reports Unlicensed and the holder is offered an upgrade. A provider without
				version gating reports the product's status. */
@property (readonly, nonatomic, nullable) NSString *licensedVersion;
/*! The cached license status. Unknown without a provider. */
@property (readonly) FxGripLicenseStatus licenseStatus;
/*! The status for a version, from the provider; Unknown when the provider cannot gate by version. */
- (FxGripLicenseStatus)licenseStatusForVersion:(NSOperatingSystemVersion)version;
/*! YES when the holder is licensed for an earlier version only, so a paid upgrade applies. */
@property (readonly) BOOL upgradeAvailable;
/*! The entitlement behind the status, when the provider reports one. */
@property (readonly, nullable) FxGripLicenseEntitlement *entitlement;
/*! YES when the status unlocks the plugin. */
@property (readonly) BOOL isLicensed;
/*! Whether the provider checks the product for updates. NO when the provider cannot. */
@property (readwrite) BOOL updateChecking;

#pragma mark Settings

/*! Sets the object that supplies hard-coded settings; nil falls back to a conforming effect. */
- (void)setSettingsObject:(nullable id<FxGripLicensingSettings>)settingsObject;
/*! The object supplying hard-coded settings; the effect itself when it conforms. */
@property (readonly, nullable) id<FxGripLicensingSettings> settingsObject;

/*! Whether the integration is active. */
@property (readwrite, nonatomic) BOOL licensingActive;
/*! Whether unlicensed frames carry the unlicensed watermark; also requires an active integration. */
@property (readwrite, nonatomic) BOOL watermarkUnlicensed;
/*! Whether trial frames carry the trial watermark; also requires an active integration. */
@property (readwrite, nonatomic) BOOL watermarkTrial;
/*! The unlicensed watermark. Empty text resolves to the plugin display name. */
@property (readwrite, copy, nonatomic, nonnull) FxGripWatermarkConfiguration *unlicensedWatermarkConfiguration;
/*! The trial watermark. Empty text resolves to the plugin display name followed by "Trial". */
@property (readwrite, copy, nonatomic, nonnull) FxGripWatermarkConfiguration *trialWatermarkConfiguration;
/*! Whether the extension adds the Buy button. */
@property (readonly, nonatomic) BOOL showBuyButton;
/*! Whether the extension adds the Show Product button. */
@property (readonly, nonatomic) BOOL showProductButton;
/*! Whether update checking is on. */
@property (readwrite, nonatomic) BOOL autoChecking;

/*! YES when the active state is hard-coded or implied by a declared product. */
@property (readonly) BOOL hasActive;
/*! YES when the product identifier is hard-coded. */
@property (readonly) BOOL hasProduct;
/*! YES when the unlicensed watermark state is hard-coded. */
@property (readonly) BOOL hasWatermarkUnlicensed;
/*! YES when the trial watermark state is hard-coded. */
@property (readonly) BOOL hasWatermarkTrial;
/*! YES when the Buy button state is hard-coded. */
@property (readonly) BOOL hasShowBuyButton;
/*! YES when the Show Product button state is hard-coded. */
@property (readonly) BOOL hasShowProductButton;
/*! YES when the update-checking state is hard-coded. */
@property (readonly) BOOL hasAutoChecking;

#pragma mark Actions

/*! Starts the provider's buy flow. NO when the provider cannot buy. */
- (BOOL)buyProduct;
/*! Shows the provider's product page. NO when the provider cannot. */
- (BOOL)showProduct;
/*! Shows the provider's license entry. NO when the provider has none. */
- (BOOL)showLicenseEntry;
/*! Releases this machine's activation through the provider and applies the resulting status. */
- (void)deactivateLicense;
/*! Shows the provider's support form. NO when the provider has none. */
- (BOOL)showSupportFormWithSubject:(nullable NSString *)subject message:(nullable NSString *)message;
/*! Checks for updates without forcing, reporting through the effect hook and the notification. */
- (void)checkForUpdates;
/*!
	@method		checkForUpdates:handler:
	@abstract	Checks for product updates and reports the information.
	@param		force	YES forces the check regardless of the provider's postpone interval.
	@param		handler	An optional block that receives the update information.
	@discussion	Introduced in FxGrip 0.1.0. On a report the effect's `licensingDidReceiveUpdateInfo:`
				hook runs, the handler runs, and the product update notification is posted. */
- (void)checkForUpdates:(BOOL)force handler:(nullable FxGripLicenseUpdateInfoHandler)handler;
/*!
	@method		fetchProductInfo:
	@abstract	Fetches the store's product information: name, newest version, requirements, price.
	@param		handler	An optional block that receives the information or the error.
	@discussion	Introduced in FxGrip 0.1.0. On a report the handler runs and the product information
				notification is posted. A provider without the capability reports nothing. */
- (void)fetchProductInfo:(nullable FxGripLicenseProductInfoHandler)handler;

#pragma mark Host configuration

/*!
	@method		hostConfigurationProblems
	@abstract	Asks the provider for the host bundle's configuration problems and logs each.
	@return		The problems; empty when the bundle is configured for the provider's store. */
- (nonnull NSArray<NSString *> *)hostConfigurationProblems;
/*! The bundle whose Info.plist the configuration check reads. The main bundle; overridable. */
- (nonnull NSBundle *)hostConfigurationBundle;

#pragma mark Overridable seams

/*!
	@method		watermarkConfigurationForStatus:
	@abstract	The watermark a frame rendered under a status carries, or nil for a clean frame.
	@discussion	Introduced in FxGrip 0.1.0. Licensed and OfflineGrace are clean. Trial carries the
				trial watermark when `watermarkTrial` is YES. Every other status carries the
				unlicensed watermark when `watermarkUnlicensed` is YES. A subclass overrides the
				method for another mapping. */
- (nullable FxGripWatermarkConfiguration *)watermarkConfigurationForStatus:(FxGripLicenseStatus)status;
/*! Renders a watermark onto the destination tile. Isolated so the decision is testable without a GPU. */
- (BOOL)renderWatermark:(nonnull FxGripWatermarkConfiguration *)configuration
			  ontoImage:(nonnull FxImageTile *)destinationImage
				  error:(NSError *_Nullable *_Nullable)outError;

#pragma mark Extension hooks

/*! Binds the extension to the effect and runs the host configuration check when the regression extension is loaded. */
- (BOOL)extLoadWithEffect:(id<FxGripTileableEffect>_Nonnull)effect;
/*! Maps the `licensing` and `fxfactory` type strings to FxParameterType_Licensing. */
- (FxParameterType)extParameterTypeForString:(nullable NSString *)typeString;
/*! Maps FxParameterType_Licensing to this class. */
- (nullable Class)extParameterClassForType:(FxParameterType)type;

@end


/*!
	@abstract	The effect-side hooks and accessors for the licensing extension.
	@discussion	Introduced in FxGrip 0.1.0. A subclass overrides the hooks to react to a status change
				or an update report.
*/
@interface FxGripTileableEffect (Licensing)

/*!
	@method		setLicenseState:
	@abstract	Adjusts the plugin's parameters and state for a licensed or unlicensed product.
	@discussion	Introduced in FxGrip 0.1.0. The default is empty. A subclass overrides it to reflect
				the license state in the UI. */
- (void)setLicenseState:(BOOL)licensed;
/*! Called when the status changes; calls `setLicenseState:`. Overridable. */
- (void)licensingStatusDidChange:(FxGripLicenseStatus)status;
/*! Called when an update check reports. The default is empty. Overridable. */
- (void)licensingDidReceiveUpdateInfo:(nonnull NSDictionary<NSString *, id> *)info;

/*! The installed licensing extension, or nil when none is installed. */
- (nullable FxGripLicensing *)licensing;
/*! The product identifier of the installed extension. */
- (nullable NSString *)licensingProductID;
/*! YES when the installed extension reports the product as licensed. */
- (BOOL)isProductLicensed;
/*!
	@method		newLicensingExtension
	@abstract	Creates the licensing extension for the loader to install.
	@return		The extension with the provider the plugin properties select, or nil when they select
				none or name an unregistered provider. */
- (nullable FxGripLicensing *)newLicensingExtension;

@end

#endif
