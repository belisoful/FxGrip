# Licensing

License a plugin through a store-neutral extension and a provider for the store it sells through.

## Overview

``FxGripLicensing`` is an extension in the notification-driven system described in
<doc:ExtensionArchitecture>. It is a hidden toggle whose value is YES while the product is
licensed. It owns one ``FxGripLicensingProvider``, the store-specific half: the provider answers
the product's status, reports status changes, and performs the store's actions. The extension
adds the inspector parameters, keeps the toggle in sync, and watermarks the rendered frame by
status.

Providers register by name. ``FxGripFxFactoryProvider`` registers as `fxfactory` when the
framework loads. A plugin selects its provider in its registration record, and the loader
installs the extension when the record names one.

## Choosing a provider

The `licensing` plugin property (``kProPlugPlugInX_LicensingProperty``) names the provider, either
as a string or as a dictionary whose `provider` key names it and whose other keys hard-code
settings:

```objc
// One provider, defaults.
kProPlugPlugInX_LicensingProperty: @"fxfactory"

// Provider plus hard-coded settings.
kProPlugPlugInX_LicensingProperty: @{
    @"provider":            @"fxfactory",
    @"productID":           @"3F2504E0-4F89-11D3-9A0C-0305E82C3301",
    @"productVersion":      @"1.2.0",
    @"watermarkUnlicensed": @YES,
    @"watermarkTrial":      @YES,
    @"trialWatermark":      @{ @"style": @"corner", @"corner": @"topRight", @"opacity": @0.4 },
}

// Shorthand for @"fxfactory".
kProPlugPlugInX_FxFactoryProperty: @YES
```

A name no loaded framework registered logs once and installs no extension; the plugin loads
without licensing. `+[FxGripLicensing registeredProviderNames]` lists what is available.

A product ships with one provider per distribution channel. FxFactory requires the app sandbox
off and library validation disabled; the App Store requires the sandbox on. A plugin sold on both
builds twice with a different `licensing` property.

## Settings

Each setting resolves from three sources in order: the ``FxGripLicensingSettings`` object (the
effect itself when it conforms, or the object passed to `setSettingsObject:`), the licensing
parameter's dictionary, and the `licensing` plugin property. A setting found in any source is
hard-coded: its parameter is not added, and its writer refuses. A setting found in none gets a
parameter the plugin can drive at run time.

| Key | Setting | Default |
| --- | --- | --- |
| `active` | The integration is on | On when a product is declared; otherwise the hidden Licensing Active toggle |
| `productID` | The product identifier; `YES` means the plugin's UUID | The Product ID parameter |
| `productVersion` | The product version; `YES` means the plugin's version | The plugin's version |
| `licensedVersion` | The version a license must cover for this build; `YES` means the plugin's version | None: every version shares one status |
| `watermarkUnlicensed` | Unlicensed frames carry the unlicensed watermark | YES |
| `watermarkTrial` | Trial frames carry the trial watermark | NO |
| `unlicensedWatermark` | The unlicensed watermark, as a configuration dictionary | Single, 99 pt, 10°, white with a blue shadow, 0.73 opacity |
| `trialWatermark` | The trial watermark, as a configuration dictionary | Corner, bottom right, 48 pt, 0.5 opacity |
| `showBuyButton` | The extension adds the Buy button | YES when the provider can buy |
| `showProductButton` | The extension adds the Show Product button | YES when the provider has a product page |
| `autoChecking` | Update checking is on | YES when the provider checks for updates |

The watermark dictionaries use the `FxGripWatermarkConfiguration` dictionary form; see
`+[FxGripWatermarkConfiguration configurationWithDictionary:]`. An absent key keeps the default
above, and an absent `text` resolves to the plugin display name (followed by "Trial" for the
trial watermark).

## Parameters

The licensing parameter is declared with the `licensing` type string (or `fxfactory`, which means
the same), or created at ``kFxParameterId_Licensing`` when the plugin declares none. The support
parameters follow it at fixed offsets, in the declared parameter's group. A parameter is added
only when its setting is not hard-coded and the provider implements the capability behind it.

| Offset | Parameter | Added when |
| --- | --- | --- |
| 0 | Product Licensed (hidden toggle, the extension itself) | always |
| 1 | Licensing Active (hidden toggle) | no active state and no product is declared |
| 2 | Product ID | no product is declared |
| 3 | Product Version | no product is declared and the provider checks for updates |
| 4 | Unlicensed Watermark (hidden toggle) | the unlicensed watermark state is not declared |
| 5, 6 | Buy button, Buy Button Label | `showBuyButton` and the provider implements `buyProduct:` |
| 7, 8 | Show Product button, Product Button Label | `showProductButton` and the provider implements `showProduct:` |
| 9 | Update Checking | not declared and the provider checks for updates |
| 10 | Enter License… | the provider implements `showLicenseEntryForProduct:` |
| 11 | Deactivate This Machine | the provider implements `deactivateLicenseForProduct:completion:` |
| 12 | Trial Watermark (hidden toggle) | the trial watermark state is not declared |

An edit to the Product Licensed toggle is reverted to the true status. Enter License shows while
the product is unlicensed and Deactivate shows while it is licensed. A button label change renames
its button, and a button press runs its action through the provider.

## Status

``FxGripLicenseStatus`` has eight values. The first four equal FxFactory's statuses, so the
FxFactory provider casts. ``FxGripLicenseStatusIsLicensed`` names the three that unlock the
plugin: Licensed, Trial, and OfflineGrace.

The extension caches the status. The render path reads the cache and never waits on a store, so
Compressor, render farms, and offline machines behave the same. The cache updates when the
provider reports a change through its observation or a completion, on whatever thread that
happens: the extension writes the toggle out of band, applies the button flags, calls the
effect's `licensingStatusDidChange:` hook (which calls `setLicenseState:`), and posts
``FxGripLicensingStatusChangeName`` with the status, provider name, and entitlement.

``FxGripLicenseEntitlement`` is the value behind the status: product, provider, kind, holder,
dates, and activation. A provider fills what it knows; FxFactory fills the product, provider, and
status.

### Version-gated licenses and upgrades

A provider that gates licenses by version implements `licenseStatusForProduct:version:`. When the
plugin declares `licensedVersion`, the extension asks for that version, so a customer licensed for
1.x sees a 2.0 build as Unlicensed. `upgradeAvailable` is YES when the holder is licensed for an
earlier version only, which is the cue to label the Buy button as an upgrade. A provider without
version gating reports the product's status and no upgrade.

### Product information

`fetchProductInfo:` asks the store for the product's name, newest version, requirements, and
price, reports them to the handler under the `FxGripLicensingProductInfo*` keys, and posts
``FxGripLicensingProductInfoName``. An update check carries the same dictionary under
``FxGripLicensingUpdateInfoProductInfo``.

## Watermark by status

`watermarkConfigurationForStatus:` decides what a frame carries, or returns nil for a clean frame:

- Licensed, OfflineGrace → clean.
- Trial → the trial watermark when `watermarkTrial` is YES, else clean.
- Unknown, InvalidProduct, Unlicensed, Expired, Revoked → the unlicensed watermark when
  `watermarkUnlicensed` is YES, else clean.

A subclass overrides the method for another mapping. The render itself goes through
`renderWatermark:ontoImage:error:` and ``FxGripWatermark``. The host caches rendered frames, so a
frame rendered under one status keeps its watermark until the host renders it again.

## Debug overrides

In a DEBUG build, the plugin property ``kPropertiesLicensingDebugSetLicensed`` forces the licensed
or unlicensed status, and ``kPropertiesLicensingDebugSetStatus`` forces any status, so a trial
watermark can be previewed without a trial entitlement. Both compile out of a Release build.

## Writing a provider

A provider adopts ``FxGripLicensingProvider`` and registers with
`+[FxGripLicensing registerProviderClass:forName:]`, in `+load` or when its framework starts. Three
methods are required: `licenseStatusForProduct:` (synchronous, from cache), and
`startObservingProduct:handler:` / `stopObservingProduct:`, keyed by product. Every other method
is a capability the extension probes with `respondsToSelector:`. An abstract provider class must
implement no optional method, because a subclass inherits the capability with the method; shared
logic goes behind non-protocol helper names.

`hostConfigurationProblemsForBundle:` lists the Info.plist and entitlement problems that would
keep the store from working. The extension logs them at load when ``FxGripRegression`` is
installed.

## The FxFactory provider

``FxGripFxFactoryProvider`` wraps the FxFactory SDK. Every SDK entry point is reached through an
overridable seam, so the provider is testable without FxFactory installed. The SDK is weak-linked
and imported only by the implementation; with FxFactory absent the provider reports
`isAvailable` NO and the extension loads disconnected. Buy requests the SDK's Show and Buy actions
together. Update responses and product information are translated into the
`FxGripLicensingUpdateInfo*` and `FxGripLicensingProductInfo*` keys, with the SDK response under
the `ProviderResponse` key. Version-gated status and the upgrade check use FxFactory 9.0.6's
`FxFactoryGetLicensingStatusForVersion` and `FxFactoryLicenseIsUpgradable`; on an older FxFactory
the provider reports the product's status and no upgrade. The host configuration check requires
library validation disabled, an `NSUpdateSecurityPolicy` that allows the FxFactory package and its
two processes, and either the app sandbox off or the read-only shared-preference exception naming
`com.fxfactory.FxFactory`.

## Topics

### The extension

- ``FxGripLicensing``
- ``FxGripLicensingSettings``
- ``kProPlugPlugInX_LicensingProperty``
- ``kFxParameterId_Licensing``
- ``kFxParameterType_Licensing``
- ``kFxParameterType_FxFactory``
- ``FxParameterType_Licensing``

### Settings keys

- ``kFxGripLicensingProperty_Provider``
- ``kFxGripLicensingProperty_Active``
- ``kFxGripLicensingProperty_ProductID``
- ``kFxGripLicensingProperty_ProductVersion``
- ``kFxGripLicensingProperty_LicensedVersion``
- ``kFxGripLicensingProperty_WatermarkUnlicensed``
- ``kFxGripLicensingProperty_WatermarkTrial``
- ``kFxGripLicensingProperty_UnlicensedWatermark``
- ``kFxGripLicensingProperty_TrialWatermark``
- ``kFxGripLicensingProperty_ShowBuyButton``
- ``kFxGripLicensingProperty_ShowProductButton``
- ``kFxGripLicensingProperty_AutoChecking``
- ``kPropertiesLicensingDebugSetLicensed``
- ``kPropertiesLicensingDebugSetStatus``

### Parameter offsets

- ``kParameterLicensingActiveOffset``
- ``kParameterLicensingProductIDOffset``
- ``kParameterLicensingProductVersionOffset``
- ``kParameterLicensingWatermarkUnlicensedOffset``
- ``kParameterLicensingBuyButtonOffset``
- ``kParameterLicensingBuyButtonLabelOffset``
- ``kParameterLicensingProductButtonOffset``
- ``kParameterLicensingProductButtonLabelOffset``
- ``kParameterLicensingAutoCheckingOffset``
- ``kParameterLicensingLicenseEntryButtonOffset``
- ``kParameterLicensingDeactivateButtonOffset``
- ``kParameterLicensingWatermarkTrialOffset``

### Status and entitlement

- ``FxGripLicensingProvider``
- ``FxGripLicenseStatus``
- ``FxGripLicenseStatusIsLicensed``
- ``FxGripLicenseStatusHandler``
- ``FxGripLicenseCompletion``
- ``FxGripLicenseUpdateInfoHandler``
- ``FxGripLicenseProductInfoHandler``
- ``FxGripLicenseEntitlement``
- ``FxGripLicenseKind``

### Update and product information keys

- ``FxGripLicensingUpdateInfoNewVersionFound``
- ``FxGripLicensingUpdateInfoPostponed``
- ``FxGripLicensingUpdateInfoError``
- ``FxGripLicensingUpdateInfoProductInfo``
- ``FxGripLicensingUpdateInfoProviderResponse``
- ``FxGripLicensingProductInfoProductName``
- ``FxGripLicensingProductInfoLatestVersion``
- ``FxGripLicensingProductInfoRequiredOSVersion``
- ``FxGripLicensingProductInfoRequiredStoreVersion``
- ``FxGripLicensingProductInfoDiscontinued``
- ``FxGripLicensingProductInfoPriceUSD``
- ``FxGripLicensingProductInfoProviderResponse``

### Notifications

- ``FxGripLicensingStatusChangeName``
- ``FxGripLicensingShowBuyName``
- ``FxGripLicensingShowProductName``
- ``FxGripLicensingShowLicenseEntryName``
- ``FxGripLicensingDeactivateName``
- ``FxGripLicensingSetUpdateCheckingName``
- ``FxGripLicensingProductUpdateName``
- ``FxGripLicensingProductInfoName``
- ``FxGripLicensingSupportFormName``
- ``FxGripLicensingStatusKey``
- ``FxGripLicensingProviderNameKey``
- ``FxGripLicensingEntitlementKey``
- ``FxGripLicensingEnabledKey``
- ``FxGripLicensingSubjectKey``
- ``FxGripLicensingMessageKey``
- ``FxGripLicensingErrorKey``

### The FxFactory provider

- ``FxGripFxFactoryProvider``
- ``kFxGripLicensingProviderName_FxFactory``
- ``kFxFactoryPackageID``
- ``kFxFactoryBundleProcess``
- ``kFxFactoryBundleProcessHelper``
- ``kFxFactorySharedPreferenceEntitlement``
- ``kFxGripFxFactoryStatusUnlicensed``
- ``kFxGripFxFactoryStatusLicensed``
- ``kFxGripFxFactoryActionShow``
- ``kFxGripFxFactoryActionBuy``
- <doc:ExtensionArchitecture>
- <doc:TextAndWatermark>
