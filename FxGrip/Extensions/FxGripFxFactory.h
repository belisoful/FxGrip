/*!
	@file       FxGripFxFactory.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripFxFactory
	@abstract   The extension that integrates a plugin with FxFactory licensing, watermarking, and updates.
	@discussion Introduced in FxGrip 0.1.0. The extension backs a hidden licensing toggle whose value
	            tracks the FxFactory license status for the plugin's product UUID. It adds the
	            product UUID, version, watermark, buy, product, and update-checking parameters that
	            the plugin does not hard-code, registers a licensing status change handler, checks
	            for product updates, and watermarks the rendered image while unlicensed. Each
	            FxFactory SDK entry point is reached through an overridable seam, so the licensing
	            logic is testable without a live FxFactory installation. The FxFactory symbols are
	            weak-linked; the extension loads and runs with the integration inert when FxFactory
	            is absent.
*/

#ifndef FxGripFxFactory_h
#define FxGripFxFactory_h

#import <FxFactory/FxFactory.h>
#import "FxGripToggleExtension.h"
#import "FxGripTileableEffect.h"

/*! A DEBUG-only Boolean plugin property that forces the licensed state. */
#define kPropertiesFxFactoryDebugSetLicensed @"FxFactoryDebugSetLicensed"

/*! The plugin property or parameter key for the FxFactory product UUID. */
#define kPropertiesFxFactoryPluginUUID @"FxFactoryPluginUUID"
/*! The plugin property or parameter key for the FxFactory product version. */
#define kPropertiesFxFactoryPluginVersion @"FxFactoryPluginVersion"
/*! The parameter key that hard-codes the FxFactory-active state. */
#define kPropertiesFxFactoryActive @"FxFactoryActive"
/*! The parameter key that hard-codes the unlicensed watermark state. */
#define kPropertiesFxFactoryWatermarkUnlicensed @"FxFactoryWatermark"
/*! The parameter key that hard-codes the buy button state. */
#define kPropertiesFxFactoryShowBuyButton @"FxFactoryShowBuyButton"
/*! The parameter key that hard-codes the show product button state. */
#define kPropertiesFxFactoryShowProductButton @"FxFactoryShowProductButton"
/*! The parameter key that hard-codes the update-checking state. */
#define kPropertiesFxFactoryAutoChecking @"FxFactoryAutoChecking"

/*! The FxFactory package identifier the update security policy must allow. */
#define kFxFactoryPackageID @"AZLNLGPTT3"
/*! The FxFactory application bundle process the update security policy must allow. */
#define kFxFactoryBundleProcess @"com.fxfactory.FxFactory"
/*! The FxFactory helper bundle process the update security policy must allow. */
#define kFxFactoryBundleProcessHelper @"com.fxfactory.FxFactory.helper"


/*! The parameter type string that marks an fxfactory parameter in the configuration. */
#define kFxParameterType_FxFactory @"fxfactory"

/*! The FxParameterType four-char code the fxfactory type string maps to. */
#define FxParameterType_FxFactory 'FxFy'

// Post Notification Messages.
/*! Posted when the update-checking state is set. */
#define kFxFactoryBroadcastSetUpdateChecking @"FxFactory::IsUpdateChecking"
/*! Posted when the FxFactory product page is shown. */
#define kFxFactoryBroadcastShowProduct @"FxFactory::ShowProduct"
/*! Posted when the buy flow is shown. */
#define kFxFactoryBroadcastShowBuy @"FxFactory::ShowBuy"
/*! Posted when the contact form is shown. */
#define kFxFactoryBroadcastContactForm @"FxFactory::ContactForm"
/*! The contact form recipient, carried in the contact form notification. */
#define kFxFactoryBroadcastContactFormRecipient @"FxFactoryValue::Recipient"
/*! The contact form subject, carried in the contact form notification. */
#define kFxFactoryBroadcastContactFormSubject @"FxFactoryValue::Subject"
/*! The contact form message, carried in the contact form notification. */
#define kFxFactoryBroadcastContactFormMessage @"FxFactoryValue::Message"
/*! Posted when a product update response arrives. */
#define kFxFactoryBroadcastProductUpdate @"FxFactory::ProductUpdate"
/*! Posted when the product license status changes. */
#define kFxFactoryBroadcastProductLicenseChange @"FxFactory::LicenseChange"
/*! The new licensing status, carried in the license change notification. */
#define kFxFactoryBroadcastProductLicenseStatus @"FxFactoryValue::Status"


// Parameter ID offsets from the licensing toggle's own ID.
/*! The offset to the FxFactory-active toggle. */
#define kParameterFxFactoryActiveOffset					1
/*! The offset to the product UUID string parameter. */
#define kParameterFxFactoryProductUUIDOffset			2
/*! The offset to the product version string parameter. */
#define kParameterFxFactoryProductVersionOffset			3
/*! The offset to the unlicensed watermark toggle. */
#define kParameterFxFactoryWaterMarkUnlicensedOffset	4
/*! The offset to the buy button. */
#define kParameterFxFactoryBuyButtonOffset				5
/*! The offset to the buy button label string. */
#define kParameterFxFactoryBuyButtonLabelOffset			6
/*! The offset to the show product button. */
#define kParameterFxFactoryProductButtonOffset			7
/*! The offset to the product button label string. */
#define kParameterFxFactoryProductButtonLabelOffset		8
/*! The offset to the update-checking toggle. */
#define kParameterFxFactoryAutoCheckingOffset			9


/*!
	@protocol	FxGripFxFactorySettings
	@abstract	The optional hooks a plugin implements to hard-code FxFactory settings in code.
	@discussion	Introduced in FxGrip 0.1.0. A value supplied here takes precedence over the parameter
				and plugin-property sources, and the corresponding parameter is not added.
*/
// These can be set by the plugin to hard code
@protocol FxGripFxFactorySettings <NSObject>

@optional

/*! YES when FxFactory integration is active. */
- (BOOL)fxFactoryActive;
/*! The FxFactory product UUID. */
- (nonnull NSString*)fxFactoryProductUUID;
/*! The FxFactory product version. */
- (nonnull NSString*)fxFactoryProductVersion;
/*! YES when unlicensed frames carry a watermark. */
- (BOOL)fxFactoryWaterMarkUnlicensed;
/*! YES when the buy button is shown. */
- (BOOL)fxFactoryShowBuyButton;
/*! YES when the show product button is shown. */
- (BOOL)fxFactoryShowProductButton;
/*! YES when automatic update checking is enabled. */
- (BOOL)fxFactoryAutoChecking;

@end



/*!
	@class		FxGripFxFactory
	@abstract	The extension that drives a plugin's FxFactory licensing, watermarking, and updates.
	@discussion	Introduced in FxGrip 0.1.0. The extension is a toggle extension whose value mirrors the
				FxFactory license status. It resolves each setting from the settings object, the
				parameter, or the plugin property in that order, and adds the parameters the plugin
				does not hard-code.
*/
@interface FxGripFxFactory : FxGripToggleExtension <FxGripStateParameter>
{
	NSNumber *_fxFactoryActive;
	NSNumber *_fxFactoryWaterMarkUnlicensed;
	NSNumber *_fxFactoryShowBuyButton;
	NSNumber *_fxFactoryShowProductButton;
	NSNumber *_fxFactoryAutoChecking;

	NSNumber *_pluginLicenseStatus;

}

/*! YES when FxFactory is installed on the machine. */
// This indicates if the user has FxFactory installed on their machine
@property (readonly) BOOL				fxFactoryIsInstalled;
/*! The installed FxFactory version, or a zero version when FxFactory is absent. */
@property (readonly) FxFactoryVersion	fxFactoryVersion;

/*! The plugin's FxFactory product UUID, resolved from the settings, parameter, or property. */
@property (readonly, nonatomic) NSString* _Nonnull fxFactoryPluginUUID;
/*! The plugin's FxFactory product version, resolved from the settings, parameter, or property. */
@property (readonly, nonatomic) NSString* _Nonnull fxFactoryPluginVersion;

/*! YES when the plugin's product is licensed in FxFactory. */
// This indicates if the plugin is licensed in FxFactory
@property (readonly) BOOL pluginIsLicensed;

/*! The FxFactory licensing status of the plugin's product. */
// This returns the status of the plugin license in FxFactory
@property (readonly) FxFactoryLicensingStatus pluginLicenseStatus;

/*! Whether automatic update checking is enabled for the plugin's product. */
@property (readwrite) BOOL pluginIsUpdateChecking;

/*! The object supplying hard-coded settings; the effect itself when it conforms. */
@property (readonly, nonnull) id<FxGripFxFactorySettings> fxFactorySettingsObject;

/*! YES when the active state is supplied by settings or the plugin product. */
@property (readonly) BOOL fxFactoryHasActive;
/*! YES when both the product UUID and version are supplied. */
@property (readonly) BOOL fxFactoryHasPluginProduct; // UUID and Version
/*! YES when the watermark state is supplied. */
@property (readonly) BOOL fxFactoryHasWaterMarkUnlicensed;
/*! YES when the buy button state is supplied. */
@property (readonly) BOOL fxFactoryHasShowBuyButton;
/*! YES when the show product button state is supplied. */
@property (readonly) BOOL fxFactoryHasShowProductButton;
/*! YES when the update-checking state is supplied. */
@property (readonly) BOOL fxFactoryHasAutoChecking;

/*! Whether FxFactory integration is active. */
@property (readwrite, nonatomic) BOOL fxFactoryActive;
/*! Whether unlicensed frames carry a watermark; also requires an active integration. */
@property (readwrite, nonatomic) BOOL fxFactoryWaterMarkUnlicensed;
/*! Whether the buy button is shown. */
@property (readwrite, nonatomic) BOOL fxFactoryShowBuyButton;
/*! Whether the show product button is shown. */
@property (readwrite, nonatomic) BOOL fxFactoryShowProductButton;
/*! Whether automatic update checking is enabled. */
@property (readwrite, nonatomic) BOOL fxFactoryAutoChecking;

/*! Sets the object that supplies hard-coded settings. */
- (void)setFxFactorySettingsObject:(nullable id<FxGripFxFactorySettings>)settingsObject;

/*! Shows the FxFactory product page for the plugin's product; returns YES on success. */
- (BOOL)showFxFactoryProduct;
/*! Starts the FxFactory buy flow for the plugin's product; returns YES on success. */
- (BOOL)showFxFactoryBuyPlugin;

/*!
	@method		showContactForm:message:
	@abstract	Shows the FxFactory contact form with no explicit recipient.
	@return		YES when the form is shown. */
//recipient must be "@fxfactory.com", like for sending fxFactory errors back to them.
- (BOOL)showContactForm:(NSString * _Nullable)subject message:(NSString * _Nullable) message;
/*!
	@method		showContactForm:subject:message:
	@abstract	Shows the FxFactory contact form addressed to a recipient.
	@param		recipient	The recipient; must end in "@fxfactory.com" when given.
	@return		YES when the form is shown; NO when the form is unavailable or the recipient is
				external. */
- (BOOL)showContactForm:(NSString * _Nullable)recipient subject:(NSString * _Nullable)subject message:(NSString * _Nullable) message;


/*! Binds the extension to the effect and runs the FxFactory regression check when installed. */
- (BOOL)extLoadWithEffect:(id<FxGripTileableEffect>_Nonnull)effect;
/*! Maps the fxfactory type string to FxParameterType_FxFactory. */
- (FxParameterType)extParameterTypeForString:(nullable NSString *)typeString;
/*! Maps FxParameterType_FxFactory to this class. */
- (nullable Class)extParameterClassForType:(FxParameterType)type;

@end




/*!
	@abstract	Typed accessors for an FxFactory product update response dictionary.
	@discussion	Introduced in FxGrip 0.1.0. Each accessor reads one response key and coerces its
				value, returning a safe default when the key is absent or the wrong type.
*/
@interface NSDictionary (FxFactoryProductUpdateResponse)

/*! YES when update checking is enabled. */
- (BOOL) fxFactoryUpdateCheckingEnabled;
/*! YES when update checking is postponed. */
- (BOOL) fxFactoryUpdateCheckingPostponed;
/*! YES when a new version was found. */
- (BOOL) fxFactoryUpdateCheckingNewVersionFound;
/*! The update-checking error, or nil. */
- (nullable NSError *) fxFactoryUpdateCheckingError;
/*! The nested product info dictionary, or nil. */
- (nullable NSDictionary *) fxFactoryUpdateCheckingProductInfo;

@end

/*!
	@abstract	Typed accessors for an FxFactory product info dictionary.
	@discussion	Introduced in FxGrip 0.1.0. The accessors read the product info returned in an update
				response, coercing each value and returning a safe default when it is absent.
*/
@interface NSDictionary (FxFactoryProductInfoResponse)

/*! The product name, or nil. */
- (nullable NSString *) fxFactoryProductName;
/*! The latest product version, or nil. */
- (nullable NSString *) fxFactoryProductLatestVersion;
/*! The macOS version the latest product version requires, or nil. */
- (nullable NSString *) fxFactoryProductLatestVersionRequiredOSVersion;
/*! The FxFactory version the latest product version requires, or nil. */
- (nullable NSString *) fxFactoryProductLatestVersionRequiredFxFactoryVersion;
/*! YES when the product is discontinued. */
- (BOOL) fxFactoryProductIsDiscontinued;
/*! The product price in USD, or NAN when absent. */
- (float) fxFactoryProductPriceInUSD;

@end




/*!
	@abstract	The effect-side hooks and accessors for the FxFactory extension.
	@discussion	Introduced in FxGrip 0.1.0. A subclass overrides the license and update hooks to react
				to a licensing change or an update response.
*/
@interface FxGripTileableEffect (FxFactory)

/*!
	@method		setFxFactoryLicenseState:
	@abstract	Adjusts the plugin's parameters and state for a licensed or unlicensed product.
	@discussion	Introduced in FxGrip 0.1.0. The default is empty. A subclass overrides it to reflect
				the license state in the UI. */
// change plugin parameter UI
- (void)setFxFactoryLicenseState:(BOOL)licensed;

/*! Called when the license status changes; calls setFxFactoryLicenseState:. Overridable. */
- (void)onFxFactoryRegisterLicensingStatusChange:(FxFactoryLicensingStatus) status;
/*! Called when a product update response arrives. The default is empty. Overridable. */
- (void)onFxFactoryShowProductUpdates:(NSDictionary * _Nonnull) response;


/*! The installed FxFactory extension, or nil when none is installed. */
- (FxGripFxFactory*_Nullable)fxFactory;
/*! The FxFactory product UUID of the installed extension. */
- (NSString * _Nullable)fxFactoryPluginUUID;
/*! The FxFactory product version of the installed extension. */
- (NSString * _Nullable)fxFactoryPluginVersion;
/*! Creates the FxFactory extension instance for the loader to install. */
- (FxGripFxFactory * _Nullable)newFxFactoryExtension;

@end


#endif
