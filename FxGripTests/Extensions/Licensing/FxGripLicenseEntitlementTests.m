/*!
	@file       FxGripLicenseEntitlementTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-03
	@header     FxGripLicenseEntitlementTests
	@abstract   Unit tests for the FxGripLicenseEntitlement value.
	@discussion Introduced in FxGrip 0.1.0. The tests cover the required-field initializer's defaults, the full initializer, the dictionary and secure-coding round trips, the immutable copy, equality, and the licensed predicate.
*/

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripLicenseEntitlement.h>

@interface FxGripLicenseEntitlementTests : XCTestCase
@end

@implementation FxGripLicenseEntitlementTests

- (FxGripLicenseEntitlement *)fullEntitlement
{
	return [FxGripLicenseEntitlement.alloc initWithProductID:@"product"
												providerName:@"remote"
													  status:FxGripLicenseStatusTrial
														kind:FxGripLicenseKindSubscription
													   email:@"user@example.com"
													issuedAt:[NSDate dateWithTimeIntervalSince1970:1000]
												   expiresAt:[NSDate dateWithTimeIntervalSince1970:2000]
												updatesUntil:[NSDate dateWithTimeIntervalSince1970:3000]
												   willRenew:YES
											  inBillingRetry:YES
												activationID:@"activation"
												   machineID:@"machine"];
}

/*! @abstract The required-field initializer leaves every other field nil, NO, or Perpetual. */
- (void)testTheRequiredInitializerDefaultsTheOptionalFields
{
	FxGripLicenseEntitlement *entitlement = [FxGripLicenseEntitlement entitlementWithProductID:@"p" providerName:@"fxfactory" status:FxGripLicenseStatusLicensed];
	XCTAssertEqualObjects(entitlement.productID, @"p");
	XCTAssertEqualObjects(entitlement.providerName, @"fxfactory");
	XCTAssertEqual(entitlement.status, FxGripLicenseStatusLicensed);
	XCTAssertEqual(entitlement.kind, FxGripLicenseKindPerpetual);
	XCTAssertNil(entitlement.email);
	XCTAssertNil(entitlement.issuedAt);
	XCTAssertNil(entitlement.expiresAt);
	XCTAssertNil(entitlement.updatesUntil);
	XCTAssertFalse(entitlement.willRenew);
	XCTAssertFalse(entitlement.inBillingRetry);
	XCTAssertNil(entitlement.activationID);
	XCTAssertNil(entitlement.machineID);
	XCTAssertTrue(entitlement.isLicensed);
}

/*! @abstract The full initializer stores every field. */
- (void)testTheFullInitializerStoresEveryField
{
	FxGripLicenseEntitlement *entitlement = [self fullEntitlement];
	XCTAssertEqual(entitlement.kind, FxGripLicenseKindSubscription);
	XCTAssertEqualObjects(entitlement.email, @"user@example.com");
	XCTAssertEqualObjects(entitlement.issuedAt, [NSDate dateWithTimeIntervalSince1970:1000]);
	XCTAssertEqualObjects(entitlement.expiresAt, [NSDate dateWithTimeIntervalSince1970:2000]);
	XCTAssertEqualObjects(entitlement.updatesUntil, [NSDate dateWithTimeIntervalSince1970:3000]);
	XCTAssertTrue(entitlement.willRenew);
	XCTAssertTrue(entitlement.inBillingRetry);
	XCTAssertEqualObjects(entitlement.activationID, @"activation");
	XCTAssertEqualObjects(entitlement.machineID, @"machine");
	XCTAssertTrue(entitlement.isLicensed, @"a trial unlocks the plugin");
}

/*! @abstract The dictionary form round-trips, and a dictionary missing a required field rebuilds nothing. */
- (void)testTheDictionaryFormRoundTrips
{
	FxGripLicenseEntitlement *entitlement = [self fullEntitlement];
	NSDictionary *dictionary = entitlement.dictionaryRepresentation;
	XCTAssertEqualObjects(dictionary[@"productID"], @"product");
	XCTAssertEqualObjects(dictionary[@"status"], @(FxGripLicenseStatusTrial));
	XCTAssertEqualObjects(dictionary[@"willRenew"], @YES);

	FxGripLicenseEntitlement *rebuilt = [FxGripLicenseEntitlement.alloc initWithDictionary:dictionary];
	XCTAssertEqualObjects(rebuilt, entitlement);
	XCTAssertEqual(rebuilt.hash, entitlement.hash);

	XCTAssertNil([FxGripLicenseEntitlement.alloc initWithDictionary:@{@"productID": @"p"}]);
	XCTAssertNil([FxGripLicenseEntitlement.alloc initWithDictionary:(@{@"providerName": @"x", @"productID": @7})]);

	FxGripLicenseEntitlement *sparse = [FxGripLicenseEntitlement.alloc initWithDictionary:(@{@"productID": @"p", @"providerName": @"x", @"email": @12})];
	XCTAssertNil(sparse.email, @"a mistyped optional field reads as absent");
	XCTAssertEqual(sparse.status, FxGripLicenseStatusUnknown);
}

/*! @abstract Secure coding round-trips the value. */
- (void)testSecureCodingRoundTrips
{
	FxGripLicenseEntitlement *entitlement = [self fullEntitlement];
	NSError *error = nil;
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:entitlement requiringSecureCoding:YES error:&error];
	XCTAssertNotNil(data, @"%@", error);
	FxGripLicenseEntitlement *decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:FxGripLicenseEntitlement.class fromData:data error:&error];
	XCTAssertEqualObjects(decoded, entitlement, @"%@", error);
	XCTAssertTrue(FxGripLicenseEntitlement.supportsSecureCoding);
}

/*! @abstract Copying returns the receiver, and equality compares every field. */
- (void)testCopyAndEquality
{
	FxGripLicenseEntitlement *entitlement = [self fullEntitlement];
	XCTAssertEqual([entitlement copy], entitlement, @"an immutable value copies to itself");
	XCTAssertEqualObjects(entitlement, [self fullEntitlement]);
	XCTAssertNotEqualObjects(entitlement, [FxGripLicenseEntitlement entitlementWithProductID:@"product" providerName:@"remote" status:FxGripLicenseStatusTrial]);
	XCTAssertNotEqualObjects(entitlement, @"product");
	XCTAssertTrue([entitlement.description containsString:@"remote"]);
}

/*! @abstract The licensed predicate follows the status. */
- (void)testIsLicensedFollowsTheStatus
{
	for (NSNumber *status in @[@(FxGripLicenseStatusLicensed), @(FxGripLicenseStatusTrial), @(FxGripLicenseStatusOfflineGrace)]) {
		XCTAssertTrue([FxGripLicenseEntitlement entitlementWithProductID:@"p" providerName:@"x" status:status.integerValue].isLicensed);
	}
	for (NSNumber *status in @[@(FxGripLicenseStatusUnknown), @(FxGripLicenseStatusInvalidProduct), @(FxGripLicenseStatusUnlicensed),
							   @(FxGripLicenseStatusExpired), @(FxGripLicenseStatusRevoked)]) {
		XCTAssertFalse([FxGripLicenseEntitlement entitlementWithProductID:@"p" providerName:@"x" status:status.integerValue].isLicensed);
	}
}

@end
