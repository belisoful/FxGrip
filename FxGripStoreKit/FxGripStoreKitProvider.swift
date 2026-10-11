/*!
	@file       FxGripStoreKitProvider.swift
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-03
	@header     FxGripStoreKitProvider
	@abstract   The licensing provider for a plugin sold through the Mac App Store.
	@discussion Introduced in FxGrip 0.1.0. The provider runs in the plugin's extension process, where
	            StoreKit is unsupported, so it never calls StoreKit. It reads the entitlement records the
	            wrapper app writes into the App Group container, watches them for changes, and opens the
	            wrapper app for a purchase, the product page, or a refresh. It registers under `storekit`
	            when the framework loads.
*/

import Foundation
import FxGrip

/// The Mac App Store licensing provider for `FxGripLicensing`.
///
/// Introduced in FxGrip 0.1.0. A plugin selects it with the `licensing` plugin property set to
/// `storekit`, and its `productID` setting names the App Store product identifier. The provider's
/// status comes from the ``FxGripStoreKitEntitlementStore`` in the first App Group the extension is
/// entitled to; the wrapper app keeps that store current through `FxGripStoreKitStore`.
///
/// The provider implements no update checking, because the App Store updates the app, and no
/// license entry, because App Store builds sell through in-app purchase only.
@objc(FxGripStoreKitProvider)
public final class FxGripStoreKitProvider: NSObject, FxGripLicensingProvider {

	/// The registry name.
	public static let providerName = "storekit"

	/// A record older than this starts a background refresh of the wrapper app when observation begins.
	public static let refreshInterval: TimeInterval = 24 * 60 * 60

	/// The records the wrapper app writes, or nil when the extension has no App Group.
	public let store: FxGripStoreKitEntitlementStore?
	/// Opens the wrapper app for an action.
	public let launcher: FxGripStoreKitLaunching
	/// The clock the status reads; a test substitutes a fixed date.
	public var now: @Sendable () -> Date = { Date() }

	private let lock = NSLock()
	private var observations: [String: FxGripStoreKitObservation] = [:]
	private var refreshedProducts: Set<String> = []

	/// A provider over the shared App Group store and the containing application.
	@objc public override convenience init() {
		self.init(store: FxGripStoreKitEntitlementStore.sharedStore(), launcher: FxGripStoreKitLauncher())
	}

	/// A provider over an explicit store and launcher.
	public init(store: FxGripStoreKitEntitlementStore?, launcher: FxGripStoreKitLaunching) {
		self.store = store
		self.launcher = launcher
		super.init()
	}

	deinit {
		for observation in observations.values {
			observation.cancel()
		}
	}

	/// Registers the provider with `FxGripLicensing` under `storekit`. The framework calls this when it loads.
	@objc public static func register() {
		FxGripLicensing.registerProviderClass(self, forName: providerName)
	}

	// MARK: FxGripLicensingProvider

	public var providerName: String { Self.providerName }

	public var isAvailable: Bool { store != nil }

	public func licenseStatus(forProduct productID: String) -> FxGripLicenseStatus {
		guard let store else {
			return .unknown
		}
		guard let record = store.record(for: productID) else {
			return .unlicensed
		}
		return record.status(at: now())
	}

	public func startObservingProduct(_ productID: String, handler: @escaping FxGripLicenseStatusHandler) {
		stopObservingProduct(productID)
		guard let store else {
			return
		}
		let observation = store.observe { [weak self] in
			guard let self else {
				return
			}
			handler(self.licenseStatus(forProduct: productID))
		}
		lock.lock()
		observations[productID] = observation
		lock.unlock()
		refreshIfStale(productID)
	}

	public func stopObservingProduct(_ productID: String) {
		lock.lock()
		let observation = observations.removeValue(forKey: productID)
		lock.unlock()
		observation?.cancel()
	}

	public func entitlement(forProduct productID: String) -> FxGripLicenseEntitlement? {
		guard let record = store?.record(for: productID) else {
			return nil
		}
		let entitlement = record.entitlement(at: now())
		return entitlement.isLicensed ? entitlement : nil
	}

	public func buyProduct(_ productID: String) -> Bool {
		launcher.open(.buy, productID: productID)
	}

	public func showProduct(_ productID: String) -> Bool {
		launcher.open(.show, productID: productID)
	}

	/// The Info.plist problems that keep an App Store plugin from reading its entitlements.
	///
	/// The sandbox must be on, the plugin must belong to an App Group, and library validation
	/// must stay enabled. The plugin mirrors its entitlements into its Info.plist, as the FxFactory
	/// check expects.
	public func hostConfigurationProblems(for bundle: Bundle) -> [String] {
		Self.hostConfigurationProblems(info: bundle.infoDictionary ?? [:])
	}

	/// The problems in an Info.plist dictionary; see ``hostConfigurationProblems(for:)``.
	public static func hostConfigurationProblems(info: [String: Any]) -> [String] {
		var problems: [String] = []

		let sandbox = info["com.apple.security.app-sandbox"]
		if sandbox == nil {
			problems.append("Info.plist must have property 'com.apple.security.app-sandbox'")
		} else if let flag = sandbox as? NSNumber, !flag.boolValue {
			problems.append("Info.plist property 'com.apple.security.app-sandbox' must be set to YES/true for the App Store")
		} else if !(sandbox is NSNumber) {
			problems.append("Info.plist property 'com.apple.security.app-sandbox' must be a Boolean")
		}

		let groups = info[FxGripStoreKitEntitlementStore.applicationGroupsEntitlement]
		if groups == nil {
			problems.append("Info.plist must have property '\(FxGripStoreKitEntitlementStore.applicationGroupsEntitlement)' naming the App Group the wrapper app shares")
		} else if let list = groups as? [Any], list.isEmpty || !list.allSatisfy({ $0 is String }) {
			problems.append("Info.plist property '\(FxGripStoreKitEntitlementStore.applicationGroupsEntitlement)' must be a non-empty array of strings")
		} else if !(groups is [Any]) {
			problems.append("Info.plist property '\(FxGripStoreKitEntitlementStore.applicationGroupsEntitlement)' must be an array")
		}

		if let validation = info["com.apple.security.cs.disable-library-validation"] as? NSNumber, validation.boolValue {
			problems.append("Info.plist property 'com.apple.security.cs.disable-library-validation' must not be YES/true for the App Store")
		}
		return problems
	}

	// MARK: Refresh

	/// Opens the wrapper app in the background once per product when its record is stale or absent.
	private func refreshIfStale(_ productID: String) {
		lock.lock()
		let alreadyRefreshed = refreshedProducts.contains(productID)
		if !alreadyRefreshed {
			refreshedProducts.insert(productID)
		}
		lock.unlock()
		if alreadyRefreshed {
			return
		}
		let verifiedAt = store?.record(for: productID)?.verifiedAt ?? .distantPast
		if now().timeIntervalSince(verifiedAt) > Self.refreshInterval {
			_ = launcher.open(.refresh, productID: productID)
		}
	}
}
