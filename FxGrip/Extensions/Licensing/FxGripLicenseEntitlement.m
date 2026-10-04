/*!
	@file       FxGripLicenseEntitlement.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-03
	@header     FxGripLicenseEntitlement
	@abstract   Implements the immutable license entitlement value.
	@discussion Introduced in FxGrip 0.1.0. The dictionary form uses the property names as keys, so
	            a provider's cache and the status-change notification carry the same shape.
*/

#import "FxGripLicenseEntitlement.h"

static NSString *const kEntitlementKeyProductID		= @"productID";
static NSString *const kEntitlementKeyProviderName	= @"providerName";
static NSString *const kEntitlementKeyStatus		= @"status";
static NSString *const kEntitlementKeyKind			= @"kind";
static NSString *const kEntitlementKeyEmail			= @"email";
static NSString *const kEntitlementKeyIssuedAt		= @"issuedAt";
static NSString *const kEntitlementKeyExpiresAt		= @"expiresAt";
static NSString *const kEntitlementKeyUpdatesUntil	= @"updatesUntil";
static NSString *const kEntitlementKeyWillRenew		= @"willRenew";
static NSString *const kEntitlementKeyInBillingRetry	= @"inBillingRetry";
static NSString *const kEntitlementKeyActivationID	= @"activationID";
static NSString *const kEntitlementKeyMachineID		= @"machineID";

/*! Returns the value when it is of the class, else nil. */
static id FxGripEntitlementValue(NSDictionary *dictionary, NSString *key, Class cls)
{
	id value = dictionary[key];
	return [value isKindOfClass:cls] ? value : nil;
}

/*!
	@abstract	An immutable record of one product's license.
	@discussion	Introduced in FxGrip 0.1.0. Copying returns the receiver, since the value is immutable.
*/
@implementation FxGripLicenseEntitlement

+ (BOOL)supportsSecureCoding
{
	return YES;
}

+ (instancetype)entitlementWithProductID:(NSString *)productID providerName:(NSString *)providerName status:(FxGripLicenseStatus)status
{
	return [[self alloc] initWithProductID:productID providerName:providerName status:status];
}

- (instancetype)initWithProductID:(NSString *)productID providerName:(NSString *)providerName status:(FxGripLicenseStatus)status
{
	return [self initWithProductID:productID providerName:providerName status:status
							  kind:FxGripLicenseKindPerpetual email:nil issuedAt:nil expiresAt:nil
					  updatesUntil:nil willRenew:NO inBillingRetry:NO activationID:nil machineID:nil];
}

- (instancetype)initWithProductID:(NSString *)productID
					 providerName:(NSString *)providerName
						   status:(FxGripLicenseStatus)status
							 kind:(FxGripLicenseKind)kind
							email:(NSString *)email
						 issuedAt:(NSDate *)issuedAt
						expiresAt:(NSDate *)expiresAt
					 updatesUntil:(NSDate *)updatesUntil
						willRenew:(BOOL)willRenew
				   inBillingRetry:(BOOL)inBillingRetry
					 activationID:(NSString *)activationID
						machineID:(NSString *)machineID
{
	self = [super init];
	if (self) {
		_productID = [productID copy];
		_providerName = [providerName copy];
		_status = status;
		_kind = kind;
		_email = [email copy];
		_issuedAt = [issuedAt copy];
		_expiresAt = [expiresAt copy];
		_updatesUntil = [updatesUntil copy];
		_willRenew = willRenew;
		_inBillingRetry = inBillingRetry;
		_activationID = [activationID copy];
		_machineID = [machineID copy];
	}
	return self;
}

- (instancetype)initWithDictionary:(NSDictionary<NSString *, id> *)dictionary
{
	NSString *productID = FxGripEntitlementValue(dictionary, kEntitlementKeyProductID, NSString.class);
	NSString *providerName = FxGripEntitlementValue(dictionary, kEntitlementKeyProviderName, NSString.class);
	if (productID == nil || providerName == nil) {
		return nil;
	}
	NSNumber *status = FxGripEntitlementValue(dictionary, kEntitlementKeyStatus, NSNumber.class);
	NSNumber *kind = FxGripEntitlementValue(dictionary, kEntitlementKeyKind, NSNumber.class);
	NSNumber *willRenew = FxGripEntitlementValue(dictionary, kEntitlementKeyWillRenew, NSNumber.class);
	NSNumber *inBillingRetry = FxGripEntitlementValue(dictionary, kEntitlementKeyInBillingRetry, NSNumber.class);
	return [self initWithProductID:productID
					  providerName:providerName
							status:status.integerValue
							  kind:kind.integerValue
							 email:FxGripEntitlementValue(dictionary, kEntitlementKeyEmail, NSString.class)
						  issuedAt:FxGripEntitlementValue(dictionary, kEntitlementKeyIssuedAt, NSDate.class)
						 expiresAt:FxGripEntitlementValue(dictionary, kEntitlementKeyExpiresAt, NSDate.class)
					  updatesUntil:FxGripEntitlementValue(dictionary, kEntitlementKeyUpdatesUntil, NSDate.class)
						 willRenew:willRenew.boolValue
					inBillingRetry:inBillingRetry.boolValue
					  activationID:FxGripEntitlementValue(dictionary, kEntitlementKeyActivationID, NSString.class)
						 machineID:FxGripEntitlementValue(dictionary, kEntitlementKeyMachineID, NSString.class)];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	NSString *productID = [coder decodeObjectOfClass:NSString.class forKey:kEntitlementKeyProductID];
	NSString *providerName = [coder decodeObjectOfClass:NSString.class forKey:kEntitlementKeyProviderName];
	if (productID == nil || providerName == nil) {
		return nil;
	}
	return [self initWithProductID:productID
					  providerName:providerName
							status:[coder decodeIntegerForKey:kEntitlementKeyStatus]
							  kind:[coder decodeIntegerForKey:kEntitlementKeyKind]
							 email:[coder decodeObjectOfClass:NSString.class forKey:kEntitlementKeyEmail]
						  issuedAt:[coder decodeObjectOfClass:NSDate.class forKey:kEntitlementKeyIssuedAt]
						 expiresAt:[coder decodeObjectOfClass:NSDate.class forKey:kEntitlementKeyExpiresAt]
					  updatesUntil:[coder decodeObjectOfClass:NSDate.class forKey:kEntitlementKeyUpdatesUntil]
						 willRenew:[coder decodeBoolForKey:kEntitlementKeyWillRenew]
					inBillingRetry:[coder decodeBoolForKey:kEntitlementKeyInBillingRetry]
					  activationID:[coder decodeObjectOfClass:NSString.class forKey:kEntitlementKeyActivationID]
						 machineID:[coder decodeObjectOfClass:NSString.class forKey:kEntitlementKeyMachineID]];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:self.productID forKey:kEntitlementKeyProductID];
	[coder encodeObject:self.providerName forKey:kEntitlementKeyProviderName];
	[coder encodeInteger:self.status forKey:kEntitlementKeyStatus];
	[coder encodeInteger:self.kind forKey:kEntitlementKeyKind];
	[coder encodeObject:self.email forKey:kEntitlementKeyEmail];
	[coder encodeObject:self.issuedAt forKey:kEntitlementKeyIssuedAt];
	[coder encodeObject:self.expiresAt forKey:kEntitlementKeyExpiresAt];
	[coder encodeObject:self.updatesUntil forKey:kEntitlementKeyUpdatesUntil];
	[coder encodeBool:self.willRenew forKey:kEntitlementKeyWillRenew];
	[coder encodeBool:self.inBillingRetry forKey:kEntitlementKeyInBillingRetry];
	[coder encodeObject:self.activationID forKey:kEntitlementKeyActivationID];
	[coder encodeObject:self.machineID forKey:kEntitlementKeyMachineID];
}

- (id)copyWithZone:(NSZone *)zone
{
	return self;
}

- (NSDictionary<NSString *, id> *)dictionaryRepresentation
{
	NSMutableDictionary *dictionary = NSMutableDictionary.new;
	dictionary[kEntitlementKeyProductID] = self.productID;
	dictionary[kEntitlementKeyProviderName] = self.providerName;
	dictionary[kEntitlementKeyStatus] = @(self.status);
	dictionary[kEntitlementKeyKind] = @(self.kind);
	dictionary[kEntitlementKeyEmail] = self.email;
	dictionary[kEntitlementKeyIssuedAt] = self.issuedAt;
	dictionary[kEntitlementKeyExpiresAt] = self.expiresAt;
	dictionary[kEntitlementKeyUpdatesUntil] = self.updatesUntil;
	dictionary[kEntitlementKeyWillRenew] = @(self.willRenew);
	dictionary[kEntitlementKeyInBillingRetry] = @(self.inBillingRetry);
	dictionary[kEntitlementKeyActivationID] = self.activationID;
	dictionary[kEntitlementKeyMachineID] = self.machineID;
	return [dictionary copy];
}

- (BOOL)isLicensed
{
	return FxGripLicenseStatusIsLicensed(self.status);
}

- (BOOL)isEqual:(id)object
{
	if (self == object) {
		return YES;
	}
	if (![object isKindOfClass:FxGripLicenseEntitlement.class]) {
		return NO;
	}
	return [self.dictionaryRepresentation isEqualToDictionary:((FxGripLicenseEntitlement *)object).dictionaryRepresentation];
}

- (NSUInteger)hash
{
	return self.productID.hash ^ self.providerName.hash ^ (NSUInteger)self.status;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ %@ %@ status=%ld kind=%ld>", self.class, self.providerName, self.productID, (long)self.status, (long)self.kind];
}

@end
