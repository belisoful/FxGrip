/*!
	@file       FxGripStoreKitLauncher.swift
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-03
	@header     FxGripStoreKitLauncher
	@abstract   Opens the plugin's wrapper app with a StoreKit action.
	@discussion Introduced in FxGrip 0.1.0. The plugin runs in a PlugInKit extension, where StoreKit is
	            unsupported, so every purchase, product page, and entitlement refresh happens in the
	            wrapper app. The launcher finds that app from the extension's bundle and opens it with a
	            `fxgripstorekit:` URL that names the action and the product.
*/

import AppKit
import Foundation

/// An action the wrapper app performs for the plugin.
public enum FxGripStoreKitAction: String, CaseIterable, Sendable {
	/// Start the purchase of a product.
	case buy
	/// Show the product's App Store page or subscription management.
	case show
	/// Re-verify the entitlements with StoreKit and rewrite the records, without activating.
	case refresh
	/// Restore purchases through `AppStore.sync()`.
	case restore
}

/// Something that opens the wrapper app with an action; the provider's seam for tests.
public protocol FxGripStoreKitLaunching: Sendable {
	/// Opens the wrapper app with the action for the product. Returns NO when no app can be opened.
	func open(_ action: FxGripStoreKitAction, productID: String) -> Bool
}

/// Opens the containing application of the running extension with a `fxgripstorekit:` URL.
///
/// Introduced in FxGrip 0.1.0. The wrapper app declares the ``scheme`` in its `CFBundleURLTypes`
/// and passes the URL it receives to `FxGripStoreKitStore/handle(_:)`. A refresh opens the app
/// without activating it; the other actions bring it to the front.
public struct FxGripStoreKitLauncher: FxGripStoreKitLaunching {

	/// The URL scheme the wrapper app declares.
	public static let scheme = "fxgripstorekit"
	/// The query item that names the product.
	public static let productQueryItem = "product"

	/// The application to open, or nil when the running process is not inside one.
	public let applicationURL: URL?

	/// A launcher for the running process's containing application.
	public init(applicationURL: URL? = FxGripStoreKitLauncher.containingApplicationURL()) {
		self.applicationURL = applicationURL
	}

	/// The `.app` bundle that contains a bundle, or the bundle itself when it is an app.
	///
	/// A PlugInKit extension lives at `<App>.app/Contents/PlugIns/<Plugin>.appex`; the search
	/// walks up until it finds a path with the `app` extension.
	public static func containingApplicationURL(for bundle: Bundle = .main) -> URL? {
		var url = bundle.bundleURL.standardizedFileURL
		while true {
			if url.pathExtension == "app" {
				return url
			}
			let parent = url.deletingLastPathComponent()
			if parent.path == url.path || parent.path == "/" {
				return nil
			}
			url = parent
		}
	}

	/// The URL that carries an action and a product to the wrapper app.
	public static func url(for action: FxGripStoreKitAction, productID: String) -> URL {
		var components = URLComponents()
		components.scheme = scheme
		components.host = action.rawValue
		components.queryItems = [URLQueryItem(name: productQueryItem, value: productID)]
		return components.url!
	}

	/// The action and product a launcher URL carries, or nil for a URL the launcher did not make.
	public static func action(from url: URL) -> (action: FxGripStoreKitAction, productID: String?)? {
		guard url.scheme?.lowercased() == scheme,
			  let host = url.host, let action = FxGripStoreKitAction(rawValue: host.lowercased()) else {
			return nil
		}
		let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
		let product = components?.queryItems?.first(where: { $0.name == productQueryItem })?.value
		return (action, product)
	}

	public func open(_ action: FxGripStoreKitAction, productID: String) -> Bool {
		guard let applicationURL else {
			return false
		}
		let configuration = NSWorkspace.OpenConfiguration()
		configuration.activates = action != .refresh
		configuration.promptsUserIfNeeded = action != .refresh
		NSWorkspace.shared.open([Self.url(for: action, productID: productID)],
								withApplicationAt: applicationURL,
								configuration: configuration) { _, error in
			if let error {
				NSLog("Error: FxGripStoreKit could not open \(applicationURL.lastPathComponent) for \(action.rawValue): \(error)")
			}
		}
		return true
	}
}
