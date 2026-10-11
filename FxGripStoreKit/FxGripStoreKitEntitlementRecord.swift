/*!
	@file       FxGripStoreKitEntitlementRecord.swift
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-03
	@header     FxGripStoreKitEntitlementRecord
	@abstract   The record the wrapper app writes for each purchased product, and the store that holds it.
	@discussion Introduced in FxGrip 0.1.0. StoreKit is unavailable to an app extension, so the wrapper
	            app verifies the App Store transactions and writes one record per product into the App
	            Group container. The plugin's provider reads the records and derives the license status.
*/

import Foundation
import FxGrip
import Security

/// One product's verified App Store entitlement, as the wrapper app recorded it.
///
/// Introduced in FxGrip 0.1.0. The record is a property list the app and the plugin share through
/// the App Group container. The app writes it after verifying the transaction with StoreKit; the
/// plugin reads it and derives the ``status(at:)``.
public struct FxGripStoreKitEntitlementRecord: Codable, Equatable, Sendable {

	/// The App Store product identifier.
	public var productID: String
	/// The original transaction identifier, which identifies the purchase across renewals.
	public var originalTransactionID: String?
	/// The purchase model: a non-consumable is perpetual, an auto-renewable product a subscription.
	public var kind: FxGripLicenseKind
	/// YES while the purchase is inside an introductory free trial.
	public var isTrial: Bool
	/// When the product was first purchased.
	public var purchaseDate: Date?
	/// When a subscription lapses; nil for a perpetual purchase.
	public var expiresAt: Date?
	/// When the App Store revoked the purchase, through a refund or a family-sharing change.
	public var revokedAt: Date?
	/// YES while the subscription auto-renews.
	public var willRenew: Bool
	/// YES while the App Store retries a failed renewal.
	public var inBillingRetry: Bool
	/// YES while the App Store grants access during a billing grace period.
	public var inGracePeriod: Bool
	/// When the wrapper app last verified the entitlement with StoreKit.
	public var verifiedAt: Date
	/// The signed transaction, for audit; the plugin does not verify it.
	public var jws: String?

	public init(productID: String,
				originalTransactionID: String? = nil,
				kind: FxGripLicenseKind = .perpetual,
				isTrial: Bool = false,
				purchaseDate: Date? = nil,
				expiresAt: Date? = nil,
				revokedAt: Date? = nil,
				willRenew: Bool = false,
				inBillingRetry: Bool = false,
				inGracePeriod: Bool = false,
				verifiedAt: Date = Date(),
				jws: String? = nil) {
		self.productID = productID
		self.originalTransactionID = originalTransactionID
		self.kind = kind
		self.isTrial = isTrial
		self.purchaseDate = purchaseDate
		self.expiresAt = expiresAt
		self.revokedAt = revokedAt
		self.willRenew = willRenew
		self.inBillingRetry = inBillingRetry
		self.inGracePeriod = inGracePeriod
		self.verifiedAt = verifiedAt
		self.jws = jws
	}

	/// The license status the record supports at a moment.
	///
	/// - Revoked when the App Store revoked the purchase.
	/// - Licensed for a perpetual purchase, or Trial while inside the introductory trial.
	/// - Licensed or Trial for a subscription that has not lapsed.
	/// - OfflineGrace for a lapsed subscription inside the App Store's billing grace period.
	/// - Expired for a lapsed subscription otherwise.
	public func status(at now: Date = Date()) -> FxGripLicenseStatus {
		if revokedAt != nil {
			return .revoked
		}
		guard let expiresAt else {
			return isTrial ? .trial : .licensed
		}
		if expiresAt > now {
			return isTrial ? .trial : .licensed
		}
		return inGracePeriod ? .offlineGrace : .expired
	}

	/// The record as the store-neutral entitlement.
	public func entitlement(at now: Date = Date()) -> FxGripLicenseEntitlement {
		FxGripLicenseEntitlement(productID: productID,
								 providerName: FxGripStoreKitProvider.providerName,
								 status: status(at: now),
								 kind: kind,
								 email: nil,
								 issuedAt: purchaseDate,
								 expiresAt: expiresAt,
								 updatesUntil: nil,
								 willRenew: willRenew,
								 inBillingRetry: inBillingRetry,
								 activationID: originalTransactionID,
								 machineID: nil)
	}

	private enum CodingKeys: String, CodingKey {
		case productID, originalTransactionID, kind, isTrial, purchaseDate, expiresAt, revokedAt
		case willRenew, inBillingRetry, inGracePeriod, verifiedAt, jws
	}

	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		productID = try container.decode(String.self, forKey: .productID)
		originalTransactionID = try container.decodeIfPresent(String.self, forKey: .originalTransactionID)
		// An Objective-C enum accepts any raw value, so the range is checked here.
		let rawKind = try container.decodeIfPresent(Int.self, forKey: .kind) ?? 0
		kind = (FxGripLicenseKind.perpetual.rawValue...FxGripLicenseKind.trial.rawValue).contains(rawKind) ? FxGripLicenseKind(rawValue: rawKind)! : .perpetual
		isTrial = try container.decodeIfPresent(Bool.self, forKey: .isTrial) ?? false
		purchaseDate = try container.decodeIfPresent(Date.self, forKey: .purchaseDate)
		expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
		revokedAt = try container.decodeIfPresent(Date.self, forKey: .revokedAt)
		willRenew = try container.decodeIfPresent(Bool.self, forKey: .willRenew) ?? false
		inBillingRetry = try container.decodeIfPresent(Bool.self, forKey: .inBillingRetry) ?? false
		inGracePeriod = try container.decodeIfPresent(Bool.self, forKey: .inGracePeriod) ?? false
		verifiedAt = try container.decodeIfPresent(Date.self, forKey: .verifiedAt) ?? .distantPast
		jws = try container.decodeIfPresent(String.self, forKey: .jws)
	}

	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(productID, forKey: .productID)
		try container.encodeIfPresent(originalTransactionID, forKey: .originalTransactionID)
		try container.encode(kind.rawValue, forKey: .kind)
		try container.encode(isTrial, forKey: .isTrial)
		try container.encodeIfPresent(purchaseDate, forKey: .purchaseDate)
		try container.encodeIfPresent(expiresAt, forKey: .expiresAt)
		try container.encodeIfPresent(revokedAt, forKey: .revokedAt)
		try container.encode(willRenew, forKey: .willRenew)
		try container.encode(inBillingRetry, forKey: .inBillingRetry)
		try container.encode(inGracePeriod, forKey: .inGracePeriod)
		try container.encode(verifiedAt, forKey: .verifiedAt)
		try container.encodeIfPresent(jws, forKey: .jws)
	}
}


/// The file in the App Group container that holds the entitlement records.
///
/// Introduced in FxGrip 0.1.0. The wrapper app writes through ``save(_:)``; the plugin reads through
/// ``records()`` and watches for changes through ``observe(_:)``. The file is a property list keyed
/// by product identifier. The App Group is read from the running process's own entitlements, so a
/// plugin and its wrapper app find the same file without configuration.
public final class FxGripStoreKitEntitlementStore: @unchecked Sendable {

	/// The sandbox entitlement that lists the process's App Groups.
	public static let applicationGroupsEntitlement = "com.apple.security.application-groups"

	/// The records file.
	public let fileURL: URL

	private let queue = DispatchQueue(label: "com.belisoful.FxGripStoreKit.entitlements")

	/// A store over an explicit file.
	public init(fileURL: URL) {
		self.fileURL = fileURL
	}

	/// A store in an App Group's container, or nil when the container is unavailable.
	public convenience init?(appGroup: String) {
		guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
			return nil
		}
		let directory = container.appendingPathComponent("Library/Application Support/FxGripStoreKit", isDirectory: true)
		self.init(fileURL: directory.appendingPathComponent("entitlements.plist"))
	}

	/// A store in the first App Group the running process is entitled to, or nil when it has none.
	public static func sharedStore() -> FxGripStoreKitEntitlementStore? {
		guard let group = applicationGroupIdentifiers().first else {
			return nil
		}
		return FxGripStoreKitEntitlementStore(appGroup: group)
	}

	/// The App Groups in the running process's code-signing entitlements.
	public static func applicationGroupIdentifiers() -> [String] {
		guard let task = SecTaskCreateFromSelf(nil) else {
			return []
		}
		let value = SecTaskCopyValueForEntitlement(task, applicationGroupsEntitlement as CFString, nil)
		return (value as? [String]) ?? []
	}

	/// Every record, keyed by product identifier. An unreadable or absent file reads as empty.
	public func records() -> [String: FxGripStoreKitEntitlementRecord] {
		queue.sync {
			guard let data = try? Data(contentsOf: fileURL) else {
				return [:]
			}
			return (try? PropertyListDecoder().decode([String: FxGripStoreKitEntitlementRecord].self, from: data)) ?? [:]
		}
	}

	/// The record for a product, or nil when the product was never recorded.
	public func record(for productID: String) -> FxGripStoreKitEntitlementRecord? {
		records()[productID]
	}

	/// Replaces every record, writing the file atomically. Creates the directory when needed.
	public func save(_ records: [String: FxGripStoreKitEntitlementRecord]) throws {
		try queue.sync {
			let directory = fileURL.deletingLastPathComponent()
			try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
			let encoder = PropertyListEncoder()
			encoder.outputFormat = .xml
			let data = try encoder.encode(records)
			try data.write(to: fileURL, options: .atomic)
		}
	}

	/// Replaces one product's record, or removes it when `record` is nil.
	public func save(_ record: FxGripStoreKitEntitlementRecord?, for productID: String) throws {
		var all = records()
		all[productID] = record
		try save(all)
	}

	/// Runs the handler after each write to the records file, from a background queue.
	///
	/// The directory is watched, because an atomic write replaces the file. The returned token stops
	/// the watch when it is cancelled or deallocated.
	public func observe(_ handler: @escaping @Sendable () -> Void) -> FxGripStoreKitObservation? {
		let directory = fileURL.deletingLastPathComponent()
		try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		let descriptor = open(directory.path, O_EVTONLY)
		guard descriptor >= 0 else {
			return nil
		}
		// Events are delivered off the storage queue, because a handler reads the records through it.
		let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: [.write, .rename, .delete], queue: DispatchQueue.global(qos: .utility))
		source.setEventHandler(handler: handler)
		source.setCancelHandler { close(descriptor) }
		source.resume()
		return FxGripStoreKitObservation(source: source)
	}
}

/// A file watch started by ``FxGripStoreKitEntitlementStore/observe(_:)``; cancel it or let it go.
public final class FxGripStoreKitObservation: @unchecked Sendable {
	private let source: DispatchSourceFileSystemObject

	init(source: DispatchSourceFileSystemObject) {
		self.source = source
	}

	/// Stops the watch.
	public func cancel() {
		source.cancel()
	}

	deinit {
		source.cancel()
	}
}
