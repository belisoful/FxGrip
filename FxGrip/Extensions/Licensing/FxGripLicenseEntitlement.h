/*!
	@file       FxGripLicenseEntitlement.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-03
	@header     FxGripLicenseEntitlement
	@abstract   The value behind a license status: who holds it, for what, and until when.
	@discussion Introduced in FxGrip 0.1.0. A provider fills the fields it knows. FxFactory fills the
	            product ID, the provider name, and the status. A license-key provider fills the
	            holder's email, the dates, the activation and machine IDs, and the purchase kind.
	            The entitlement is immutable and secure-codable.
*/

#ifndef FxGripLicenseEntitlement_h
#define FxGripLicenseEntitlement_h

#import <Foundation/Foundation.h>
#import <FxGrip/FxGripLicensingProvider.h>

/*!
	@enum		FxGripLicenseKind
	@abstract	The purchase model behind an entitlement.
*/
typedef NS_ENUM(NSInteger, FxGripLicenseKind) {
	/*! A one-time purchase. `updatesUntil` bounds the releases it covers, when set. */
	FxGripLicenseKindPerpetual		= 0,
	/*! A recurring purchase that lapses when it is not renewed. */
	FxGripLicenseKindSubscription	= 1,
	/*! A time-limited evaluation. */
	FxGripLicenseKindTrial			= 2,
};

/*!
	@class		FxGripLicenseEntitlement
	@abstract	An immutable record of one product's license.
	@discussion	Introduced in FxGrip 0.1.0. Every field but the product ID, provider name, and
				status is optional. `dictionaryRepresentation` carries the same fields with
				property-list types, for a notification's userInfo or a provider's cache.
*/
@interface FxGripLicenseEntitlement : NSObject <NSCopying, NSSecureCoding>

/*! The product the entitlement covers. */
@property (readonly, copy, nonnull) NSString *productID;
/*! The registry name of the provider that issued the entitlement. */
@property (readonly, copy, nonnull) NSString *providerName;
/*! The license status the entitlement supports. */
@property (readonly) FxGripLicenseStatus status;
/*! The purchase model. Defaults to Perpetual. */
@property (readonly) FxGripLicenseKind kind;
/*! The license holder's email, when the store reports one. */
@property (readonly, copy, nullable) NSString *email;
/*! When the entitlement was issued. */
@property (readonly, copy, nullable) NSDate *issuedAt;
/*! When the entitlement lapses, or nil for a license without an end. */
@property (readonly, copy, nullable) NSDate *expiresAt;
/*! The last release date a perpetual license covers, or nil for every release. */
@property (readonly, copy, nullable) NSDate *updatesUntil;
/*! YES while a subscription auto-renews. */
@property (readonly) BOOL willRenew;
/*! YES while the store retries a failed renewal and still grants access. */
@property (readonly) BOOL inBillingRetry;
/*! The store's identifier for this activation. */
@property (readonly, copy, nullable) NSString *activationID;
/*! The identifier of the machine the activation is bound to. */
@property (readonly, copy, nullable) NSString *machineID;

/*! An entitlement with only the required fields. */
+ (nonnull instancetype)entitlementWithProductID:(nonnull NSString *)productID
									providerName:(nonnull NSString *)providerName
										  status:(FxGripLicenseStatus)status;

/*! An entitlement with only the required fields; the remaining fields are nil, NO, or Perpetual. */
- (nonnull instancetype)initWithProductID:(nonnull NSString *)productID
							 providerName:(nonnull NSString *)providerName
								   status:(FxGripLicenseStatus)status;

/*! The designated initializer. */
- (nonnull instancetype)initWithProductID:(nonnull NSString *)productID
							 providerName:(nonnull NSString *)providerName
								   status:(FxGripLicenseStatus)status
									 kind:(FxGripLicenseKind)kind
									email:(nullable NSString *)email
								 issuedAt:(nullable NSDate *)issuedAt
								expiresAt:(nullable NSDate *)expiresAt
							 updatesUntil:(nullable NSDate *)updatesUntil
								willRenew:(BOOL)willRenew
						   inBillingRetry:(BOOL)inBillingRetry
							 activationID:(nullable NSString *)activationID
								machineID:(nullable NSString *)machineID NS_DESIGNATED_INITIALIZER;

/*!
	@method		initWithDictionary:
	@abstract	Rebuilds an entitlement from its `dictionaryRepresentation`.
	@return		The entitlement, or nil when the product ID or provider name is absent. */
- (nullable instancetype)initWithDictionary:(nonnull NSDictionary<NSString *, id> *)dictionary;

- (nonnull instancetype)init NS_UNAVAILABLE;

/*! The fields as a property list: strings, numbers, and dates, keyed by the property names. */
@property (readonly, copy, nonnull) NSDictionary<NSString *, id> *dictionaryRepresentation;

/*! YES when `status` unlocks the plugin; see `FxGripLicenseStatusIsLicensed`. */
@property (readonly) BOOL isLicensed;

@end

#endif
