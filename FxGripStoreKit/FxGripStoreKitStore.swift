/*!
	@file       FxGripStoreKitStore.swift
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-03
	@header     FxGripStoreKitStore
	@abstract   The wrapper app's StoreKit client, which keeps the shared entitlement records current.
	@discussion Introduced in FxGrip 0.1.0. The wrapper app owns every StoreKit call: it verifies the
	            current entitlements, listens for transaction updates, purchases, and restores, and
	            after each change rewrites the records the plugin reads. The record builder works from
	            a protocol over the transaction fields, so it is testable without the App Store.
*/

import Foundation
import FxGrip
import StoreKit

/// The transaction fields a record is built from; `StoreKit.Transaction` adopts it.
public protocol FxGripStoreKitTransactionInfo {
	var fxProductID: String { get }
	var fxOriginalTransactionID: String { get }
	var fxPurchaseDate: Date { get }
	var fxExpirationDate: Date? { get }
	var fxRevocationDate: Date? { get }
	var fxIsAutoRenewable: Bool { get }
	var fxIsIntroductoryOffer: Bool { get }
	var fxJWS: String? { get }
}

/// A subscription's renewal state, read from `Product.SubscriptionInfo.Status`.
public struct FxGripStoreKitRenewalState: Equatable, Sendable {
	public var willAutoRenew: Bool
	public var inBillingRetry: Bool
	public var inGracePeriod: Bool

	public init(willAutoRenew: Bool, inBillingRetry: Bool = false, inGracePeriod: Bool = false) {
		self.willAutoRenew = willAutoRenew
		self.inBillingRetry = inBillingRetry
		self.inGracePeriod = inGracePeriod
	}
}

extension FxGripStoreKitEntitlementRecord {

	/// A record for a verified transaction.
	public init(transaction: some FxGripStoreKitTransactionInfo, renewal: FxGripStoreKitRenewalState?, verifiedAt: Date = Date()) {
		self.init(productID: transaction.fxProductID,
				  originalTransactionID: transaction.fxOriginalTransactionID,
				  kind: transaction.fxIsAutoRenewable ? .subscription : .perpetual,
				  isTrial: transaction.fxIsIntroductoryOffer,
				  purchaseDate: transaction.fxPurchaseDate,
				  expiresAt: transaction.fxExpirationDate,
				  revokedAt: transaction.fxRevocationDate,
				  willRenew: renewal?.willAutoRenew ?? false,
				  inBillingRetry: renewal?.inBillingRetry ?? false,
				  inGracePeriod: renewal?.inGracePeriod ?? false,
				  verifiedAt: verifiedAt,
				  jws: transaction.fxJWS)
	}

	/// The records for a set of transactions, keyed by product; a later expiry wins for a product.
	public static func records(for transactions: [(any FxGripStoreKitTransactionInfo, FxGripStoreKitRenewalState?)],
							   verifiedAt: Date = Date()) -> [String: FxGripStoreKitEntitlementRecord] {
		var records: [String: FxGripStoreKitEntitlementRecord] = [:]
		for (transaction, renewal) in transactions {
			let record = FxGripStoreKitEntitlementRecord(transaction: transaction, renewal: renewal, verifiedAt: verifiedAt)
			if let existing = records[record.productID] {
				let existingExpiry = existing.expiresAt ?? .distantFuture
				let newExpiry = record.expiresAt ?? .distantFuture
				if newExpiry <= existingExpiry {
					continue
				}
			}
			records[record.productID] = record
		}
		return records
	}
}

extension Transaction: FxGripStoreKitTransactionInfo {
	public var fxProductID: String { productID }
	public var fxOriginalTransactionID: String { String(originalID) }
	public var fxPurchaseDate: Date { purchaseDate }
	public var fxExpirationDate: Date? { expirationDate }
	public var fxRevocationDate: Date? { revocationDate }
	public var fxIsAutoRenewable: Bool { productType == .autoRenewable }
	public var fxIsIntroductoryOffer: Bool {
		if #available(macOS 14.4, *) {
			return offer?.type == .introductory
		}
		return offerType == .introductory
	}
	/// The signed form lives on the verification result; see ``FxGripStoreKitVerifiedTransaction``.
	public var fxJWS: String? { nil }
}

/// A verified transaction together with its signed form.
public struct FxGripStoreKitVerifiedTransaction: FxGripStoreKitTransactionInfo {
	public let transaction: Transaction
	public let jws: String

	public init(_ result: VerificationResult<Transaction>) throws {
		transaction = try result.payloadValue
		jws = result.jwsRepresentation
	}

	public var fxProductID: String { transaction.fxProductID }
	public var fxOriginalTransactionID: String { transaction.fxOriginalTransactionID }
	public var fxPurchaseDate: Date { transaction.fxPurchaseDate }
	public var fxExpirationDate: Date? { transaction.fxExpirationDate }
	public var fxRevocationDate: Date? { transaction.fxRevocationDate }
	public var fxIsAutoRenewable: Bool { transaction.fxIsAutoRenewable }
	public var fxIsIntroductoryOffer: Bool { transaction.fxIsIntroductoryOffer }
	public var fxJWS: String? { jws }
}


/// The wrapper app's StoreKit client.
///
/// Introduced in FxGrip 0.1.0. The app creates one store for its product identifiers, calls
/// ``start()`` at launch, and passes every `fxgripstorekit:` URL it receives to ``handle(_:)``.
/// Each verified change rewrites the ``FxGripStoreKitEntitlementStore`` the plugin reads. The
/// StoreKit calls are verified in the App Store sandbox; the record logic is unit-tested.
@MainActor
public final class FxGripStoreKitStore {

	/// The App Store product identifiers the app sells.
	public let productIDs: [String]
	/// The records the plugin reads.
	public let entitlements: FxGripStoreKitEntitlementStore

	private var updatesTask: Task<Void, Never>?

	public init(productIDs: [String], entitlements: FxGripStoreKitEntitlementStore) {
		self.productIDs = productIDs
		self.entitlements = entitlements
	}

	/// Starts listening for transaction updates and refreshes the records once.
	public func start() {
		stop()
		updatesTask = Task { [weak self] in
			for await result in Transaction.updates {
				guard let self else {
					return
				}
				if case .verified(let transaction) = result {
					await transaction.finish()
				}
				await self.refresh()
			}
		}
		Task { await refresh() }
	}

	/// Stops listening for transaction updates.
	public func stop() {
		updatesTask?.cancel()
		updatesTask = nil
	}

	/// Re-verifies the current entitlements with StoreKit and rewrites the records.
	public func refresh() async {
		var verified: [(any FxGripStoreKitTransactionInfo, FxGripStoreKitRenewalState?)] = []
		for await result in Transaction.currentEntitlements {
			guard let transaction = try? FxGripStoreKitVerifiedTransaction(result) else {
				continue
			}
			let renewal = transaction.fxIsAutoRenewable ? await renewalState(for: transaction.fxProductID) : nil
			verified.append((transaction, renewal))
		}
		rewrite(verified)
	}

	/// Replaces the records with those built from the transactions, dropping products with none.
	public func rewrite(_ transactions: [(any FxGripStoreKitTransactionInfo, FxGripStoreKitRenewalState?)], verifiedAt: Date = Date()) {
		let records = FxGripStoreKitEntitlementRecord.records(for: transactions, verifiedAt: verifiedAt)
		do {
			try entitlements.save(records)
		} catch {
			NSLog("Error: FxGripStoreKit could not write the entitlement records: \(error)")
		}
	}

	/// Purchases a product. Returns YES when the purchase succeeded and the records were refreshed.
	public func purchase(_ productID: String) async throws -> Bool {
		guard let product = try await Product.products(for: [productID]).first else {
			return false
		}
		switch try await product.purchase() {
		case .success(let result):
			guard case .verified(let transaction) = result else {
				return false
			}
			await transaction.finish()
			await refresh()
			return true
		case .pending, .userCancelled:
			return false
		@unknown default:
			return false
		}
	}

	/// Restores purchases and refreshes the records.
	public func restore() async {
		try? await AppStore.sync()
		await refresh()
	}

	/// Performs the action a launcher URL carries. Returns NO for a URL the launcher did not make.
	@discardableResult
	public func handle(_ url: URL) -> Bool {
		guard let (action, productID) = FxGripStoreKitLauncher.action(from: url) else {
			return false
		}
		Task {
			switch action {
			case .buy:
				if let productID {
					_ = try? await purchase(productID)
				}
			case .show:
				if let productID {
					await showProduct(productID)
				}
			case .refresh:
				await refresh()
			case .restore:
				await restore()
			}
		}
		return true
	}

	/// The Info.plist key that names the app's App Store identifier, for the product page.
	nonisolated public static let appStoreIDInfoKey = "FxGripStoreKitAppStoreID"

	/// Opens subscription management for a subscription, or the app's App Store page otherwise.
	///
	/// The page needs the app's App Store identifier under ``appStoreIDInfoKey`` in the app's
	/// Info.plist; without it the App Store opens on its front page.
	public func showProduct(_ productID: String) async {
		let product = try? await Product.products(for: [productID]).first
		NSWorkspace.shared.open(Self.productPageURL(isSubscription: product?.type == .autoRenewable,
													appStoreID: Bundle.main.object(forInfoDictionaryKey: Self.appStoreIDInfoKey) as? String))
	}

	/// The URL Show Product opens: subscription management, the app's page, or the App Store.
	nonisolated public static func productPageURL(isSubscription: Bool, appStoreID: String?) -> URL {
		if isSubscription {
			return URL(string: "https://apps.apple.com/account/subscriptions")!
		}
		if let appStoreID, !appStoreID.isEmpty {
			return URL(string: "macappstore://apps.apple.com/app/id\(appStoreID)")!
		}
		return URL(string: "macappstore://apps.apple.com")!
	}

	private func renewalState(for productID: String) async -> FxGripStoreKitRenewalState? {
		guard let product = try? await Product.products(for: [productID]).first,
			  let statuses = try? await product.subscription?.status, let status = statuses.first else {
			return nil
		}
		var willRenew = false
		if case .verified(let renewal) = status.renewalInfo {
			willRenew = renewal.willAutoRenew
		}
		return FxGripStoreKitRenewalState(willAutoRenew: willRenew,
										  inBillingRetry: status.state == .inBillingRetryPeriod,
										  inGracePeriod: status.state == .inGracePeriod)
	}
}
