/*!
	@file       FxGripStoreKitStoreTests.swift
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-03
	@header     FxGripStoreKitStoreTests
	@abstract   Unit tests for the wrapper app's record building and URL handling.
	@discussion Introduced in FxGrip 0.1.0. Fake transactions stand in for StoreKit, so the tests cover the
	            record a transaction builds, the per-product merge, the rewrite into the shared store, and
	            the launcher URL dispatch. The StoreKit calls themselves are verified in the App Store sandbox.
*/

import Foundation
import FxGrip
import XCTest

@testable import FxGripStoreKit

struct FxGripStoreKitFakeTransaction: FxGripStoreKitTransactionInfo {
	var fxProductID: String
	var fxOriginalTransactionID: String = "1"
	var fxPurchaseDate: Date = Date(timeIntervalSince1970: 1_700_000_000)
	var fxExpirationDate: Date? = nil
	var fxRevocationDate: Date? = nil
	var fxIsAutoRenewable: Bool = false
	var fxIsIntroductoryOffer: Bool = false
	var fxJWS: String? = "jws"
}

final class FxGripStoreKitStoreTests: XCTestCase {

	let now = Date(timeIntervalSince1970: 1_700_000_000)

	func temporaryStore() -> FxGripStoreKitEntitlementStore {
		let directory = FileManager.default.temporaryDirectory
			.appendingPathComponent("FxGripStoreKitStoreTests-\(UUID().uuidString)", isDirectory: true)
		addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
		return FxGripStoreKitEntitlementStore(fileURL: directory.appendingPathComponent("entitlements.plist"))
	}

	/// A non-consumable builds a perpetual record and an auto-renewable a subscription record with its renewal state.
	func testATransactionBuildsItsRecord() {
		let perpetual = FxGripStoreKitEntitlementRecord(transaction: FxGripStoreKitFakeTransaction(fxProductID: "p"), renewal: nil, verifiedAt: now)
		XCTAssertEqual(perpetual.productID, "p")
		XCTAssertEqual(perpetual.kind, .perpetual)
		XCTAssertNil(perpetual.expiresAt)
		XCTAssertFalse(perpetual.willRenew)
		XCTAssertEqual(perpetual.jws, "jws")
		XCTAssertEqual(perpetual.verifiedAt, now)
		XCTAssertEqual(perpetual.status(at: now), .licensed)

		let subscription = FxGripStoreKitEntitlementRecord(
			transaction: FxGripStoreKitFakeTransaction(fxProductID: "s", fxOriginalTransactionID: "9", fxExpirationDate: now.addingTimeInterval(30),
													   fxIsAutoRenewable: true, fxIsIntroductoryOffer: true),
			renewal: FxGripStoreKitRenewalState(willAutoRenew: true, inBillingRetry: true, inGracePeriod: false),
			verifiedAt: now)
		XCTAssertEqual(subscription.kind, .subscription)
		XCTAssertEqual(subscription.originalTransactionID, "9")
		XCTAssertTrue(subscription.isTrial)
		XCTAssertTrue(subscription.willRenew)
		XCTAssertTrue(subscription.inBillingRetry)
		XCTAssertEqual(subscription.status(at: now), .trial)
	}

	/// Several transactions for one product keep the one with the later expiry.
	func testTheLaterExpiryWinsPerProduct() {
		let early = FxGripStoreKitFakeTransaction(fxProductID: "s", fxExpirationDate: now.addingTimeInterval(10), fxIsAutoRenewable: true)
		let late = FxGripStoreKitFakeTransaction(fxProductID: "s", fxOriginalTransactionID: "2", fxExpirationDate: now.addingTimeInterval(20), fxIsAutoRenewable: true)
		let perpetual = FxGripStoreKitFakeTransaction(fxProductID: "p")
		let records = FxGripStoreKitEntitlementRecord.records(for: [(late, nil), (early, nil), (perpetual, nil), (perpetual, nil)], verifiedAt: now)
		XCTAssertEqual(records.count, 2)
		XCTAssertEqual(records["s"]?.originalTransactionID, "2")
		XCTAssertEqual(records["p"]?.kind, .perpetual)
	}

	/// A rewrite replaces the store's records with those built from the transactions.
	@MainActor
	func testARewriteReplacesTheRecords() throws {
		let entitlements = temporaryStore()
		try entitlements.save(FxGripStoreKitEntitlementRecord(productID: "stale", verifiedAt: now), for: "stale")
		let store = FxGripStoreKitStore(productIDs: ["p", "s"], entitlements: entitlements)

		store.rewrite([(FxGripStoreKitFakeTransaction(fxProductID: "p"), nil)], verifiedAt: now)

		XCTAssertEqual(store.productIDs, ["p", "s"])
		XCTAssertEqual(entitlements.records().keys.sorted(), ["p"], "a product with no transaction loses its record")
		XCTAssertEqual(entitlements.record(for: "p")?.verifiedAt, now)
	}

	/// A launcher URL is accepted and any other URL refused.
	@MainActor
	func testURLHandlingAcceptsOnlyLauncherURLs() {
		let store = FxGripStoreKitStore(productIDs: ["p"], entitlements: temporaryStore())
		XCTAssertFalse(store.handle(URL(string: "https://example.com")!))
		XCTAssertTrue(store.handle(FxGripStoreKitLauncher.url(for: .refresh, productID: "p")))
		store.stop()
	}
}
