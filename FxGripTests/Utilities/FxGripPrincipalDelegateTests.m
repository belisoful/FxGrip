/*!
	@file       FxGripPrincipalDelegateTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-10
	@header     FxGripPrincipalDelegateTests
	@abstract   Unit tests for the FxGripPrincipalDelegate singleton.
	@discussion Introduced in FxGrip 0.1.0. The tests cover the singleton accessor, the empty state
	            before a host connects, the connection callback that records the host identity, and
	            the Motion detection derived from the recorded bundle identifier.
*/

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripPrincipalDelegate.h>

@interface FxGripPrincipalDelegateTests : XCTestCase
@end

@implementation FxGripPrincipalDelegateTests

/*! @abstract The class declares itself a singleton and conforms to FxPrincipalDelegate. */
- (void)testClassIsASingletonPrincipalDelegate
{
	XCTAssertTrue(FxGripPrincipalDelegate.isSingleton);
	XCTAssertTrue([FxGripPrincipalDelegate conformsToProtocol:@protocol(FxPrincipalDelegate)]);
}

/*! @abstract sharedInstance returns one FxGripPrincipalDelegate instance on every access. */
- (void)testSharedInstanceIsStableAndOfTheDelegateClass
{
	FxGripPrincipalDelegate *first = FxGripPrincipalDelegate.sharedInstance;

	XCTAssertNotNil(first);
	XCTAssertTrue([first isKindOfClass:FxGripPrincipalDelegate.class]);
	XCTAssertTrue(first == FxGripPrincipalDelegate.sharedInstance);
}

/*! @abstract A fresh delegate reports no host identifier, no host version, and not Motion. */
- (void)testFreshDelegateHasNoHostIdentity
{
	FxGripPrincipalDelegate *delegate = [[FxGripPrincipalDelegate alloc] init];

	XCTAssertNil(delegate.hostBundleIdentifier);
	XCTAssertNil(delegate.hostVersion);
	XCTAssertFalse(delegate.hostIsMotion);
}

/*! @abstract The connection callback records the host bundle identifier and version. */
- (void)testConnectionCallbackRecordsTheHostIdentity
{
	FxGripPrincipalDelegate *delegate = [[FxGripPrincipalDelegate alloc] init];

	[delegate didEstablishConnectionWithHost:@"com.apple.FinalCut" version:@"11.0"];

	XCTAssertEqualObjects(delegate.hostBundleIdentifier, @"com.apple.FinalCut");
	XCTAssertEqualObjects(delegate.hostVersion, @"11.0");
	XCTAssertFalse(delegate.hostIsMotion);
}

/*! @abstract hostIsMotion is YES after connecting to either Motion bundle identifier. */
- (void)testHostIsMotionFollowsTheRecordedBundleIdentifier
{
	FxGripPrincipalDelegate *delegate = [[FxGripPrincipalDelegate alloc] init];

	[delegate didEstablishConnectionWithHost:@"com.apple.motionapp" version:@"5.9"];
	XCTAssertTrue(delegate.hostIsMotion);

	[delegate didEstablishConnectionWithHost:@"com.apple.motionappApp" version:@"5.9"];
	XCTAssertTrue(delegate.hostIsMotion);
}

/*! @abstract A non-singleton instance is released when its last reference goes away. */
- (void)testInstanceDeallocatesWhenReleased
{
	__weak FxGripPrincipalDelegate *weakDelegate = nil;
	@autoreleasepool {
		FxGripPrincipalDelegate *delegate = [[FxGripPrincipalDelegate alloc] init];
		[delegate didEstablishConnectionWithHost:@"com.apple.motionapp" version:@"5.9"];
		weakDelegate = delegate;
		XCTAssertNotNil(weakDelegate);
	}

	XCTAssertNil(weakDelegate);
}

@end
