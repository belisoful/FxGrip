/*!
	@file       FxGripStoreKitLauncherTests.swift
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-03
	@header     FxGripStoreKitLauncherTests
	@abstract   Unit tests for the wrapper-app launcher.
	@discussion Introduced in FxGrip 0.1.0. The tests cover the containing-app search from an extension
	            bundle, the action URL round trip, and the refusal to open when no app contains the process.
*/

import Foundation
import XCTest

@testable import FxGripStoreKit

final class FxGripStoreKitLauncherTests: XCTestCase {

	/// The search walks up from an extension bundle to its .app and stops at an app bundle.
	func testTheContainingApplicationIsFoundFromTheExtension() throws {
		let root = FileManager.default.temporaryDirectory.appendingPathComponent("FxGripStoreKitLauncherTests-\(UUID().uuidString)", isDirectory: true)
		addTeardownBlock { try? FileManager.default.removeItem(at: root) }
		let app = root.appendingPathComponent("Wrapper.app", isDirectory: true)
		let appex = app.appendingPathComponent("Contents/PlugIns/Plugin.appex", isDirectory: true)
		try FileManager.default.createDirectory(at: appex.appendingPathComponent("Contents"), withIntermediateDirectories: true)

		let extensionBundle = try XCTUnwrap(Bundle(url: appex))
		XCTAssertEqual(FxGripStoreKitLauncher.containingApplicationURL(for: extensionBundle)?.standardizedFileURL, app.standardizedFileURL)

		let appBundle = try XCTUnwrap(Bundle(url: app))
		XCTAssertEqual(FxGripStoreKitLauncher.containingApplicationURL(for: appBundle)?.standardizedFileURL, app.standardizedFileURL, "an app is its own container")

		let loose = root.appendingPathComponent("Loose.bundle", isDirectory: true)
		try FileManager.default.createDirectory(at: loose, withIntermediateDirectories: true)
		XCTAssertNil(FxGripStoreKitLauncher.containingApplicationURL(for: try XCTUnwrap(Bundle(url: loose))), "a bundle outside an app has no container")
	}

	/// An action URL carries the action and the product and parses back; other URLs parse to nil.
	func testTheActionURLRoundTrips() {
		for action in FxGripStoreKitAction.allCases {
			let url = FxGripStoreKitLauncher.url(for: action, productID: "com.example.product one")
			XCTAssertEqual(url.scheme, "fxgripstorekit")
			let parsed = FxGripStoreKitLauncher.action(from: url)
			XCTAssertEqual(parsed?.action, action)
			XCTAssertEqual(parsed?.productID, "com.example.product one")
		}
		XCTAssertNil(FxGripStoreKitLauncher.action(from: URL(string: "https://example.com/buy?product=p")!))
		XCTAssertNil(FxGripStoreKitLauncher.action(from: URL(string: "fxgripstorekit://dance?product=p")!))
		XCTAssertEqual(FxGripStoreKitLauncher.action(from: URL(string: "FXGRIPSTOREKIT://Refresh")!)?.action, .refresh)
		XCTAssertNil(FxGripStoreKitLauncher.action(from: URL(string: "fxgripstorekit://refresh")!)?.productID)
	}

	/// A launcher with no containing application refuses to open.
	func testALauncherWithoutAnApplicationRefuses() {
		let launcher = FxGripStoreKitLauncher(applicationURL: nil)
		XCTAssertFalse(launcher.open(.buy, productID: "p"))
	}

	/// The product page is subscription management for a subscription, the app's page with an ID, and the store without one.
	func testTheProductPageURL() {
		XCTAssertEqual(FxGripStoreKitStore.productPageURL(isSubscription: true, appStoreID: "123").absoluteString, "https://apps.apple.com/account/subscriptions")
		XCTAssertEqual(FxGripStoreKitStore.productPageURL(isSubscription: false, appStoreID: "123").absoluteString, "macappstore://apps.apple.com/app/id123")
		XCTAssertEqual(FxGripStoreKitStore.productPageURL(isSubscription: false, appStoreID: nil).absoluteString, "macappstore://apps.apple.com")
		XCTAssertEqual(FxGripStoreKitStore.productPageURL(isSubscription: false, appStoreID: "").absoluteString, "macappstore://apps.apple.com")
	}
}
