# ``FxGripStoreKit``

The Mac App Store licensing provider for FxGrip, written in Swift.

## Overview

``FxGripStoreKitProvider`` is an `FxGripLicensingProvider` for a plugin sold through the Mac App
Store. It registers under `storekit` when the framework loads, and a plugin selects it with the
`licensing` plugin property. The module is Swift because StoreKit 2 is Swift-only; FxGrip itself
stays Objective-C and the provider reaches it through the FxGrip module.

### StoreKit stays in the wrapper app

StoreKit is unsupported in app extensions, and in-app purchases belong to the containing app's
bundle identifier. An FxPlug plugin runs as a PlugInKit extension, so the plugin process cannot
read its entitlements or purchase. The module therefore splits in two:

- ``FxGripStoreKitStore`` runs in the wrapper app. It verifies the current entitlements, listens
  for transaction updates, purchases, restores, and after each change writes one
  ``FxGripStoreKitEntitlementRecord`` per product into the ``FxGripStoreKitEntitlementStore``.
- ``FxGripStoreKitProvider`` runs in the plugin. It reads the records, watches the file for
  changes, derives the license status, and opens the wrapper app through
  ``FxGripStoreKitLauncher`` for a purchase, the product page, or a refresh.

The two share the store through the App Group container. Both read the App Group from their own
code-signing entitlements, so no configuration names it.

### What the wrapper app does

<doc:WrapperApp> lists the declarations and the code in full.

1. Declares the `fxgripstorekit` URL scheme in `CFBundleURLTypes`.
2. Creates one `FxGripStoreKitStore` for its product identifiers and calls `start()` at launch.
3. Passes each URL it receives to `handle(_:)`.
4. Optionally sets `FxGripStoreKitAppStoreID` in its Info.plist, so Show Product opens its App
   Store page.

A refresh opens the app without activating it. The provider requests one when observation starts
and the product's record is older than a day or absent, so a subscription renewed while the app
was closed is picked up the next time the plugin loads.

### Status

A record maps to the license status as follows:

- revoked → Revoked
- a perpetual purchase → Licensed, or Trial inside the introductory trial
- a subscription before its expiry → Licensed, or Trial inside the introductory trial
- a lapsed subscription inside the App Store's billing grace period → OfflineGrace
- a lapsed subscription otherwise → Expired
- no record → Unlicensed
- no App Group → Unknown; the provider reports `isAvailable` NO

### Host configuration

The provider's host configuration check requires the app sandbox on, a non-empty
`com.apple.security.application-groups`, and library validation enabled. Those requirements are
the reverse of FxFactory's, so one build cannot carry both providers; a plugin sold on both stores
builds twice with a different `licensing` property.

### Deployment floor

The module requires macOS 13.5, the same floor as FxGrip. StoreKit 2 arrived in macOS 12.

## Topics

### The provider

- ``FxGripStoreKitProvider``

### The shared records

- ``FxGripStoreKitEntitlementRecord``
- ``FxGripStoreKitEntitlementStore``
- ``FxGripStoreKitObservation``

### The wrapper app

- <doc:WrapperApp>
- ``FxGripStoreKitStore``
- ``FxGripStoreKitTransactionInfo``
- ``FxGripStoreKitRenewalState``
- ``FxGripStoreKitLauncher``
- ``FxGripStoreKitLaunching``
- ``FxGripStoreKitAction``
