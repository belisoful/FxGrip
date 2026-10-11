# The Wrapper App

Give the wrapper app of an App Store plugin its StoreKit duties: the URL scheme, the App Group, the store, and the purchase flow.

## Overview

Every FxPlug 4 plugin ships inside a wrapper application. For a plugin sold on the Mac App Store
that app also owns StoreKit, because StoreKit is unsupported in the plugin's extension process.
The app verifies purchases with ``FxGripStoreKitStore`` and writes the records the plugin's
``FxGripStoreKitProvider`` reads. This article lists what the app declares and the code it runs.

## Entitlements and Info.plist

Both the app and the plugin extension carry:

- `com.apple.security.app-sandbox` → `YES`.
- `com.apple.security.application-groups` → one App Group both share, for example
  `group.com.example.myplugin`. The store finds it in each process's own entitlements; nothing
  names it in code.

The plugin's `Info.plist` mirrors those two keys, so the provider's host configuration check reads
them when the regression extension is loaded.

The app's `Info.plist` adds:

- `CFBundleURLTypes` with the `fxgripstorekit` scheme (``FxGripStoreKitLauncher/scheme``), which the
  plugin opens the app with.
- `FxGripStoreKitAppStoreID` (``FxGripStoreKitStore/appStoreIDInfoKey``), the app's numeric App
  Store identifier, so Show Product opens the app's page. Without it the App Store opens on its
  front page.
- `LSUIElement` → `YES` when the app has no window of its own; a refresh then runs without a Dock
  icon. An app with a window keeps its UI and still handles the refresh.

## The store

Create one store for the app's product identifiers, start it at launch, and pass every URL the app
receives to it:

```swift
import FxGripStoreKit

@main
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var store: FxGripStoreKitStore?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let entitlements = FxGripStoreKitEntitlementStore.sharedStore() else {
            NSLog("The app is not in an App Group; the plugin cannot read its entitlements.")
            return
        }
        let store = FxGripStoreKitStore(productIDs: ["com.example.myplugin.full"], entitlements: entitlements)
        store.start()
        self.store = store
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            store?.handle(url)
        }
    }
}
```

`start()` re-verifies the current entitlements and listens for transaction updates for the life
of the app. `handle(_:)` performs the action a launcher URL carries:

| URL | Action |
| --- | --- |
| `fxgripstorekit://buy?product=…` | `purchase(_:)`, then a refresh |
| `fxgripstorekit://show?product=…` | `showProduct(_:)` |
| `fxgripstorekit://refresh?product=…` | `refresh()`; the plugin sends this in the background |
| `fxgripstorekit://restore?product=…` | `restore()`, which runs `AppStore.sync()` |

An app with its own purchase UI calls `purchase(_:)` and `restore()` directly from its buttons.
A Restore Purchases button is an App Review expectation for non-consumables.

## What the plugin sees

After each verified change the store rewrites the records file in the App Group container. The
plugin's provider watches that file: the licensing toggle, the watermark, and the Buy and Show
Product buttons follow within the same second, and the host re-renders the frame on the next
request. A frame the host has already cached keeps its watermark until the host renders it again.

The plugin declares the provider and the product in its registration record:

```objc
kProPlugPlugInX_LicensingProperty: @{
    @"provider":  @"storekit",
    @"productID": @"com.example.myplugin.full",
}
```

## Testing

- **StoreKit configuration file.** Add one to the app's scheme in Xcode and the app's purchases run
  against local products, with no App Store Connect setup. The plugin reads whatever the app wrote,
  so the whole path from Buy to a clean frame runs locally once the app is launched from Xcode.
- **Sandbox Apple ID.** Products configured in App Store Connect test the real flow, including
  renewals and refunds, with a sandbox account signed in to the App Store.
- **Debug override.** The plugin's `LicensingDebugSetStatus` property previews each status without
  any purchase, in a DEBUG build.

## App Review

An App Store build sells through in-app purchase only. A Buy button that opens a web store from an
App Store build falls under guideline 3.1.1, which changes often; read the current text before any
button targets a page outside the App Store. FxFactory licensing cannot ship in an App Store build
either, because FxFactory requires the sandbox off; a plugin sold on both stores builds twice with a
different `licensing` property.
