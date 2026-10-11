/*!
	@file       FxGripStoreKitEntitlementRecordTests.swift
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-03
	@header     FxGripStoreKitEntitlementRecordTests
	@abstract   Unit tests for the shared entitlement record and its file store.
	@discussion Introduced in FxGrip 0.1.0. The tests cover the status a record derives at a moment, the
	            entitlement it exports, its property-list round trip, and the store's read, write, remove,
	            and change observation over a temporary file.
*/

import Foundation
import FxGrip
import XCTest

@testable import FxGripStoreKit

final class FxGripStoreKitEntitlementRecordTests: XCTestCase {

	let now = Date(timeIntervalSince1970: 1_700_000_000)

	func temporaryStore() -> FxGripStoreKitEntitlementStore {
		let directory = FileManager.default.temporaryDirectory
			.appendingPathComponent("FxGripStoreKitTests-\(UUID().uuidString)", isDirectory: true)
		addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
		return FxGripStoreKitEntitlementStore(fileURL: directory.appendingPathComponent("entitlements.plist"))
	}

	// MARK: Status

	/// A perpetual purchase is licensed, or a trial inside the introductory offer, and revocation wins.
	func testAPerpetualPurchaseIsLicensedUnlessRevoked() {
		var record = FxGripStoreKitEntitlementRecord(productID: "p", verifiedAt: now)
		XCTAssertEqual(record.status(at: now), .licensed)
		record.isTrial = true
		XCTAssertEqual(record.status(at: now), .trial)
		record.revokedAt = now
		XCTAssertEqual(record.status(at: now), .revoked)
	}

	/// A subscription is licensed before its expiry, in grace inside the billing grace period, and expired otherwise.
	func testASubscriptionFollowsItsExpiry() {
		var record = FxGripStoreKitEntitlementRecord(productID: "s", kind: .subscription, expiresAt: now.addingTimeInterval(60), verifiedAt: now)
		XCTAssertEqual(record.status(at: now), .licensed)
		record.isTrial = true
		XCTAssertEqual(record.status(at: now), .trial)
		record.isTrial = false
		XCTAssertEqual(record.status(at: now.addingTimeInterval(120)), .expired)
		record.inGracePeriod = true
		XCTAssertEqual(record.status(at: now.addingTimeInterval(120)), .offlineGrace)
		record.revokedAt = now
		XCTAssertEqual(record.status(at: now), .revoked)
	}

	/// The exported entitlement carries the record's fields and the storekit provider name.
	func testTheEntitlementCarriesTheRecord() {
		let record = FxGripStoreKitEntitlementRecord(productID: "s", originalTransactionID: "1234", kind: .subscription,
													 purchaseDate: now, expiresAt: now.addingTimeInterval(60),
													 willRenew: true, inBillingRetry: true, verifiedAt: now)
		let entitlement = record.entitlement(at: now)
		XCTAssertEqual(entitlement.productID, "s")
		XCTAssertEqual(entitlement.providerName, "storekit")
		XCTAssertEqual(entitlement.status, .licensed)
		XCTAssertEqual(entitlement.kind, .subscription)
		XCTAssertEqual(entitlement.issuedAt, now)
		XCTAssertEqual(entitlement.expiresAt, now.addingTimeInterval(60))
		XCTAssertTrue(entitlement.willRenew)
		XCTAssertTrue(entitlement.inBillingRetry)
		XCTAssertEqual(entitlement.activationID, "1234")
		XCTAssertNil(entitlement.email)
		XCTAssertTrue(entitlement.isLicensed)
	}

	// MARK: Coding

	/// The record round-trips through a property list, and a minimal plist decodes with defaults.
	func testTheRecordRoundTripsAsAPropertyList() throws {
		let record = FxGripStoreKitEntitlementRecord(productID: "s", originalTransactionID: "1", kind: .subscription, isTrial: true,
													 purchaseDate: now, expiresAt: now.addingTimeInterval(60), revokedAt: nil,
													 willRenew: true, inBillingRetry: false, inGracePeriod: true, verifiedAt: now, jws: "jws")
		let data = try PropertyListEncoder().encode(record)
		let decoded = try PropertyListDecoder().decode(FxGripStoreKitEntitlementRecord.self, from: data)
		XCTAssertEqual(decoded, record)

		let minimal = try PropertyListSerialization.data(fromPropertyList: ["productID": "m", "kind": 99], format: .xml, options: 0)
		let sparse = try PropertyListDecoder().decode(FxGripStoreKitEntitlementRecord.self, from: minimal)
		XCTAssertEqual(sparse.productID, "m")
		XCTAssertEqual(sparse.kind, .perpetual, "an unknown kind reads as perpetual")
		XCTAssertFalse(sparse.isTrial)
		XCTAssertNil(sparse.expiresAt)
		XCTAssertEqual(sparse.verifiedAt, .distantPast, "an absent verification date reads as stale")
	}

	// MARK: The store

	/// The store reads empty when the file is absent, round-trips a save, and removes a product on a nil save.
	func testTheStoreReadsWritesAndRemoves() throws {
		let store = temporaryStore()
		XCTAssertEqual(store.records(), [:])
		XCTAssertNil(store.record(for: "p"))

		let record = FxGripStoreKitEntitlementRecord(productID: "p", verifiedAt: now)
		try store.save([record.productID: record])
		XCTAssertEqual(store.record(for: "p"), record)

		let second = FxGripStoreKitEntitlementRecord(productID: "s", kind: .subscription, verifiedAt: now)
		try store.save(second, for: "s")
		XCTAssertEqual(store.records().count, 2)

		try store.save(nil, for: "p")
		XCTAssertNil(store.record(for: "p"))
		XCTAssertEqual(store.record(for: "s"), second)
	}

	/// An unreadable file reads as empty.
	func testACorruptFileReadsAsEmpty() throws {
		let store = temporaryStore()
		try FileManager.default.createDirectory(at: store.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
		try Data("not a plist".utf8).write(to: store.fileURL)
		XCTAssertEqual(store.records(), [:])
	}

	/// A save after observation starts runs the handler.
	func testASaveRunsTheObserver() throws {
		let store = temporaryStore()
		let fired = expectation(description: "observer")
		fired.assertForOverFulfill = false
		let observation = store.observe { fired.fulfill() }
		XCTAssertNotNil(observation)
		try store.save([:])
		wait(for: [fired], timeout: 5)
		observation?.cancel()
	}

	/// The App Group lookup reads the process's entitlements and never fails.
	func testTheAppGroupLookupReadsTheEntitlements() {
		let groups = FxGripStoreKitEntitlementStore.applicationGroupIdentifiers()
		XCTAssertNotNil(groups)
		if groups.isEmpty {
			XCTAssertNil(FxGripStoreKitEntitlementStore.sharedStore(), "a process without an App Group has no shared store")
		}
		XCTAssertNil(FxGripStoreKitEntitlementStore(appGroup: "group.fxgrip.tests.nonexistent.\(UUID().uuidString)")?.records().first,
					 "an unknown App Group yields no readable records")
	}
}
