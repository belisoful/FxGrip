/*!
	@file       FxGripStoreKitProviderTests.swift
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-03
	@header     FxGripStoreKitProviderTests
	@abstract   Unit tests for the Mac App Store licensing provider.
	@discussion Introduced in FxGrip 0.1.0. A temporary record store and a recording launcher stand in for
	            the App Group container and the wrapper app, so the tests cover the status mapping, the
	            observation and stale refresh, the entitlement export, the launcher actions, the host
	            configuration check, and the registration with FxGripLicensing.
*/

import Foundation
import FxGrip
import XCTest

@testable import FxGripStoreKit

/// Records the actions the provider asks the wrapper app for.
final class FxGripStoreKitRecordingLauncher: FxGripStoreKitLaunching, @unchecked Sendable {
	private let lock = NSLock()
	private var storage: [(FxGripStoreKitAction, String)] = []
	var result = true

	var actions: [(FxGripStoreKitAction, String)] {
		lock.lock(); defer { lock.unlock() }
		return storage
	}

	func open(_ action: FxGripStoreKitAction, productID: String) -> Bool {
		lock.lock(); defer { lock.unlock() }
		storage.append((action, productID))
		return result
	}
}

final class FxGripStoreKitProviderTests: XCTestCase {

	let now = Date(timeIntervalSince1970: 1_700_000_000)
	var store: FxGripStoreKitEntitlementStore!
	var launcher: FxGripStoreKitRecordingLauncher!
	var provider: FxGripStoreKitProvider!

	override func setUp() {
		super.setUp()
		let directory = FileManager.default.temporaryDirectory
			.appendingPathComponent("FxGripStoreKitProviderTests-\(UUID().uuidString)", isDirectory: true)
		addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
		store = FxGripStoreKitEntitlementStore(fileURL: directory.appendingPathComponent("entitlements.plist"))
		launcher = FxGripStoreKitRecordingLauncher()
		provider = FxGripStoreKitProvider(store: store, launcher: launcher)
		let fixed = now
		provider.now = { fixed }
	}

	// MARK: Identity

	/// The provider registers under storekit when the framework loads and names itself the same.
	func testTheProviderIsRegisteredUnderItsName() {
		XCTAssertTrue(FxGripLicensing.providerClass(forName: "storekit") === FxGripStoreKitProvider.self)
		XCTAssertEqual(provider.providerName, "storekit")
		XCTAssertTrue(provider.isAvailable)
	}

	/// Without an App Group the provider is unavailable and reports Unknown.
	func testAMissingStoreMakesTheProviderUnavailable() {
		let absent = FxGripStoreKitProvider(store: nil, launcher: launcher)
		XCTAssertFalse(absent.isAvailable)
		XCTAssertEqual(absent.licenseStatus(forProduct: "p"), .unknown)
		XCTAssertNil(absent.entitlement(forProduct: "p"))
		absent.startObservingProduct("p") { _ in }
		XCTAssertTrue(launcher.actions.isEmpty, "nothing to refresh without a store")
	}

	// MARK: Status

	/// No record reads as Unlicensed, and a record maps through its status at the provider's clock.
	func testTheStatusComesFromTheRecord() throws {
		XCTAssertEqual(provider.licenseStatus(forProduct: "p"), .unlicensed)

		try store.save(FxGripStoreKitEntitlementRecord(productID: "p", verifiedAt: now), for: "p")
		XCTAssertEqual(provider.licenseStatus(forProduct: "p"), .licensed)

		try store.save(FxGripStoreKitEntitlementRecord(productID: "s", kind: .subscription, isTrial: true,
													   expiresAt: now.addingTimeInterval(10), verifiedAt: now), for: "s")
		XCTAssertEqual(provider.licenseStatus(forProduct: "s"), .trial)

		try store.save(FxGripStoreKitEntitlementRecord(productID: "e", kind: .subscription,
													   expiresAt: now.addingTimeInterval(-10), verifiedAt: now), for: "e")
		XCTAssertEqual(provider.licenseStatus(forProduct: "e"), .expired)
	}

	/// The entitlement is exported while licensed and nil otherwise.
	func testTheEntitlementFollowsTheStatus() throws {
		try store.save(FxGripStoreKitEntitlementRecord(productID: "p", originalTransactionID: "77", verifiedAt: now), for: "p")
		let entitlement = provider.entitlement(forProduct: "p")
		XCTAssertEqual(entitlement?.activationID, "77")
		XCTAssertEqual(entitlement?.providerName, "storekit")

		try store.save(FxGripStoreKitEntitlementRecord(productID: "p", revokedAt: now, verifiedAt: now), for: "p")
		XCTAssertNil(provider.entitlement(forProduct: "p"))
		XCTAssertNil(provider.entitlement(forProduct: "none"))
	}

	// MARK: Observation and refresh

	/// A write to the records runs the handler with the new status, and stopping ends the watch.
	func testObservationReportsTheNewStatus() throws {
		try store.save(FxGripStoreKitEntitlementRecord(productID: "p", verifiedAt: now), for: "p")
		let reported = expectation(description: "status")
		reported.assertForOverFulfill = false
		var statuses: [FxGripLicenseStatus] = []
		let lock = NSLock()
		// An atomic write can raise more than one event; the test waits for the one that carries the new status.
		provider.startObservingProduct("p") { status in
			lock.lock(); statuses.append(status); lock.unlock()
			if status == .revoked {
				reported.fulfill()
			}
		}
		try store.save(FxGripStoreKitEntitlementRecord(productID: "p", revokedAt: now, verifiedAt: now), for: "p")
		wait(for: [reported], timeout: 5)
		lock.lock()
		XCTAssertEqual(statuses.last, .revoked)
		lock.unlock()

		provider.stopObservingProduct("p")
		provider.stopObservingProduct("p")
		XCTAssertNoThrow(try store.save([:]), "a write after stop reaches no handler")
	}

	/// Observation of a stale or absent record opens the wrapper app for a refresh, once per product.
	func testAStaleRecordRequestsOneRefresh() throws {
		provider.startObservingProduct("absent") { _ in }
		provider.startObservingProduct("absent") { _ in }
		XCTAssertEqual(launcher.actions.map { $0.0 }, [.refresh])
		XCTAssertEqual(launcher.actions.first?.1, "absent")

		try store.save(FxGripStoreKitEntitlementRecord(productID: "fresh", verifiedAt: now.addingTimeInterval(-60)), for: "fresh")
		provider.startObservingProduct("fresh") { _ in }
		XCTAssertEqual(launcher.actions.count, 1, "a record verified within the interval needs no refresh")

		try store.save(FxGripStoreKitEntitlementRecord(productID: "old", verifiedAt: now.addingTimeInterval(-FxGripStoreKitProvider.refreshInterval - 1)), for: "old")
		provider.startObservingProduct("old") { _ in }
		XCTAssertEqual(launcher.actions.count, 2)
		XCTAssertEqual(launcher.actions.last?.0, .refresh)
	}

	// MARK: Actions

	/// Buy and Show Product open the wrapper app with their action, and report what the launcher reports.
	func testBuyAndShowOpenTheWrapperApp() {
		XCTAssertTrue(provider.buyProduct("p"))
		XCTAssertTrue(provider.showProduct("p"))
		XCTAssertEqual(launcher.actions.map { $0.0 }, [.buy, .show])
		launcher.result = false
		XCTAssertFalse(provider.buyProduct("p"))
	}

	/// The provider implements no update checking, license entry, or version gating.
	func testTheProviderOmitsTheCapabilitiesTheAppStoreOwns() {
		XCTAssertFalse(provider.responds(to: #selector(FxGripLicensingProvider.checkForUpdates(forProduct:version:force:handler:))))
		XCTAssertFalse(provider.responds(to: #selector(FxGripLicensingProvider.showLicenseEntry(forProduct:))))
		XCTAssertFalse(provider.responds(to: #selector(FxGripLicensingProvider.deactivateLicense(forProduct:completion:))))
		XCTAssertFalse(provider.responds(to: #selector(FxGripLicensingProvider.licenseStatus(forProduct:version:))))
		XCTAssertTrue(provider.responds(to: #selector(FxGripLicensingProvider.hostConfigurationProblems(for:))))
	}

	// MARK: Host configuration

	func problems(_ info: [String: Any]) -> [String] {
		FxGripStoreKitProvider.hostConfigurationProblems(info: info)
	}

	/// A sandboxed plugin in an App Group with library validation on is configured for the App Store.
	func testTheHostCheckRequiresTheAppStoreConfiguration() {
		let valid: [String: Any] = ["com.apple.security.app-sandbox": true,
									"com.apple.security.application-groups": ["group.example"]]
		XCTAssertEqual(problems(valid), [])

		var info = valid
		info["com.apple.security.app-sandbox"] = false
		XCTAssertEqual(problems(info).count, 1, "the sandbox must be on")
		info["com.apple.security.app-sandbox"] = "YES"
		XCTAssertEqual(problems(info).count, 1, "the sandbox flag must be a Boolean")
		info.removeValue(forKey: "com.apple.security.app-sandbox")
		XCTAssertEqual(problems(info).count, 1, "the sandbox flag must be present")

		info = valid
		info["com.apple.security.application-groups"] = []
		XCTAssertEqual(problems(info).count, 1, "the App Group list must not be empty")
		info["com.apple.security.application-groups"] = "group.example"
		XCTAssertEqual(problems(info).count, 1, "the App Group list must be an array")
		info.removeValue(forKey: "com.apple.security.application-groups")
		XCTAssertEqual(problems(info).count, 1)

		info = valid
		info["com.apple.security.cs.disable-library-validation"] = true
		XCTAssertEqual(problems(info).count, 1, "library validation must stay on")
		info["com.apple.security.cs.disable-library-validation"] = false
		XCTAssertEqual(problems(info), [])

		XCTAssertEqual(problems([:]).count, 2, "each problem is reported")

		let real = provider.hostConfigurationProblems(for: Bundle(for: Self.self))
		XCTAssertEqual(real, problems(Bundle(for: Self.self).infoDictionary ?? [:]), "the bundle form reads the bundle's Info.plist")
	}

	// MARK: Through the extension

	/// FxGripLicensing drives the provider like any other: the status and the capability-gated buttons follow it.
	func testTheExtensionDrivesTheProvider() throws {
		try store.save(FxGripStoreKitEntitlementRecord(productID: "p", verifiedAt: now), for: "p")
		let licensing = FxGripLicensing(provider: provider)
		XCTAssertTrue(licensing.provider === provider)
		XCTAssertTrue(licensing.showBuyButton)
		XCTAssertTrue(licensing.showProductButton)
		XCTAssertFalse(licensing.autoChecking)
		XCTAssertEqual(licensing.licenseStatus(for: OperatingSystemVersion(majorVersion: 1, minorVersion: 0, patchVersion: 0)), .unknown)
		XCTAssertFalse(licensing.upgradeAvailable)
	}
}
