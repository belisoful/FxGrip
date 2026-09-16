/*!
	@file       FxGripAPINotificationsTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-10
	@header     FxGripAPINotificationsTests
	@abstract   Verifies the userInfo accessors FxGripAPINotifications adds to NSDictionary and NSMutableDictionary.
	@discussion Introduced in FxGrip 0.1.0. The readers return the parameter, result, and error stored under the notification keys; mutableFxParameter answers only a mutable parameter dictionary. Each writer stores its value under the matching key and removes the key for nil.
*/

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripAPINotifications.h>

@interface FxGripAPINotificationsTests : XCTestCase
@end

@implementation FxGripAPINotificationsTests

static NSError *FxGripNotificationsTestError(void)
{
	return [NSError errorWithDomain:@"FxGripNotificationsTest" code:3 userInfo:nil];
}

#pragma mark Readers

/*! @abstract fxParameter, fxResult, and fxError read the values stored under the notification keys. */
- (void)testReadersReturnTheStoredValues
{
	NSDictionary *parameter = @{@"id": @4};
	NSError *error = FxGripNotificationsTestError();
	NSDictionary *userInfo = @{FxGripNotifyAPI_ParameterKey: parameter,
							   FxGripNotifyAPI_ResultKey: @"done",
							   FxGripNotifyAPI_ErrorKey: error};

	XCTAssertEqualObjects(userInfo.fxParameter, parameter);
	XCTAssertEqualObjects(userInfo.fxResult, @"done");
	XCTAssertEqualObjects(userInfo.fxError, error);
}

/*! @abstract The readers answer nil for keys that are absent. */
- (void)testReadersAnswerNilForAbsentKeys
{
	NSDictionary *userInfo = @{};

	XCTAssertNil(userInfo.fxParameter);
	XCTAssertNil(userInfo.mutableFxParameter);
	XCTAssertNil(userInfo.fxResult);
	XCTAssertNil(userInfo.fxError);
}

/*! @abstract mutableFxParameter returns the stored parameter when it is mutable. */
- (void)testMutableFxParameterReturnsAMutableParameter
{
	NSMutableDictionary *parameter = [@{@"id": @4} mutableCopy];
	NSDictionary *userInfo = @{FxGripNotifyAPI_ParameterKey: parameter};

	XCTAssertEqual(userInfo.mutableFxParameter, parameter);
}

/*! @abstract mutableFxParameter is nil when the stored parameter is immutable, while fxParameter still returns it. */
- (void)testMutableFxParameterIsNilForAnImmutableParameter
{
	NSDictionary *parameter = @{@"id": @4};
	NSDictionary *userInfo = @{FxGripNotifyAPI_ParameterKey: parameter};

	XCTAssertNil(userInfo.mutableFxParameter);
	XCTAssertEqualObjects(userInfo.fxParameter, parameter);
}

#pragma mark Writers

/*! @abstract Each writer stores its value under the matching notification key. */
- (void)testWritersStoreUnderTheNotificationKeys
{
	NSMutableDictionary *userInfo = NSMutableDictionary.new;
	NSError *error = FxGripNotificationsTestError();

	userInfo.fxParameter = @{@"id": @9};
	userInfo.fxResult = @1;
	userInfo.fxError = error;

	XCTAssertEqualObjects(userInfo[FxGripNotifyAPI_ParameterKey], @{@"id": @9});
	XCTAssertEqualObjects(userInfo[FxGripNotifyAPI_ResultKey], @1);
	XCTAssertEqualObjects(userInfo[FxGripNotifyAPI_ErrorKey], error);
	XCTAssertEqual(userInfo.count, 3u);
}

/*! @abstract Writing nil through each writer removes its key. */
- (void)testWritingNilRemovesTheKey
{
	NSMutableDictionary *userInfo = [@{FxGripNotifyAPI_ParameterKey: @{@"id": @9},
									   FxGripNotifyAPI_ResultKey: @1,
									   FxGripNotifyAPI_ErrorKey: FxGripNotificationsTestError()} mutableCopy];

	userInfo.fxParameter = nil;
	XCTAssertNil(userInfo[FxGripNotifyAPI_ParameterKey]);
	userInfo.fxResult = nil;
	XCTAssertNil(userInfo[FxGripNotifyAPI_ResultKey]);
	userInfo.fxError = nil;
	XCTAssertNil(userInfo[FxGripNotifyAPI_ErrorKey]);
	XCTAssertEqual(userInfo.count, 0u);
}

/*! @abstract Writing nil for a key that is already absent leaves the dictionary unchanged. */
- (void)testWritingNilForAnAbsentKeyIsHarmless
{
	NSMutableDictionary *userInfo = [@{@"other": @1} mutableCopy];

	userInfo.fxParameter = nil;
	userInfo.fxResult = nil;
	userInfo.fxError = nil;

	XCTAssertEqualObjects(userInfo, @{@"other": @1});
}

/*! @abstract A parameter written through the setter reads back through both the plain and the mutable reader. */
- (void)testAWrittenMutableParameterReadsBackMutable
{
	NSMutableDictionary *userInfo = NSMutableDictionary.new;
	NSMutableDictionary *parameter = [@{@"id": @2} mutableCopy];

	userInfo.fxParameter = parameter;

	XCTAssertEqual(userInfo.mutableFxParameter, parameter);
	XCTAssertEqual(userInfo.fxParameter, parameter);
}

@end
