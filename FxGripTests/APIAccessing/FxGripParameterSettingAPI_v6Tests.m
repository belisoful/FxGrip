/*!
	@file       FxGripParameterSettingAPI_v6Tests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripParameterSettingAPI_v6Tests
	@abstract   Tests the read-modify-write flag helpers of FxGripParameterSettingAPI_v6.
	@discussion Introduced in FxGrip 0.1.0. The suite covers addFlags: and removeFlags:
	            over the current flags, the failure path when the current flags cannot be read, and
	            the version-five pre and post notification flow the helpers run.
*/

#import "FxGripSettingAPITestSupport.h"
#import <FxGrip/FxGripParameterFlags.h>
#import <FxGrip/FxGripAPINotifications.h>
#import <FxGrip/FxGripParameterSettingAPI_v6.h>

@interface FxGripParameterSettingAPI_v6Tests : FxGripSettingAPITestCase
@end

@implementation FxGripParameterSettingAPI_v6Tests

/*! @abstract addFlags: ORs the named bits into the current flags before the write. */
- (void)testAddFlagsOrsTheNewBitsIntoTheCurrentFlags
{
	self.retrievalAPI.flags = kFxParameterFlag_HIDDEN;

	XCTAssertTrue([self.settingAPIv6 addFlags:kFxParameterFlag_DISABLED
								  toParameter:kSettingTestParameter]);

	XCTAssertEqualObjects(self.hostCall[@"value"],
						  @(kFxParameterFlag_HIDDEN | kFxParameterFlag_DISABLED));
}

/*! @abstract removeFlags: clears only the named bits and keeps the rest. */
- (void)testRemoveFlagsClearsOnlyTheNamedBits
{
	self.retrievalAPI.flags = kFxParameterFlag_HIDDEN | kFxParameterFlag_DISABLED;

	XCTAssertTrue([self.settingAPIv6 removeFlags:kFxParameterFlag_HIDDEN
								   fromParameter:kSettingTestParameter]);

	XCTAssertEqualObjects(self.hostCall[@"value"], @(kFxParameterFlag_DISABLED));
}

/*! @abstract addFlags: returns NO and calls no host setter when the current flags cannot be read. */
- (void)testAddFlagsReportsFailureWhenTheCurrentFlagsCannotBeRead
{
	self.retrievalAPI.flagsSucceed = NO;

	XCTAssertFalse([self.settingAPIv6 addFlags:kFxParameterFlag_DISABLED
								   toParameter:kSettingTestParameter]);

	XCTAssertEqualObjects(self.hostAPI.calls, @[]);
	XCTAssertEqualObjects(self.posted, @[]);
}

/*! @abstract removeFlags: returns NO and calls no host setter when the current flags cannot be read. */
- (void)testRemoveFlagsReportsFailureWhenTheCurrentFlagsCannotBeRead
{
	self.retrievalAPI.flagsSucceed = NO;

	XCTAssertFalse([self.settingAPIv6 removeFlags:kFxParameterFlag_HIDDEN
									fromParameter:kSettingTestParameter]);

	XCTAssertEqualObjects(self.hostAPI.calls, @[]);
}

/*! @abstract The v6 flag helpers post the version-five set-flags pre and post notifications. */
- (void)testTheV6FlagHelpersRunTheV5NotificationFlow
{
	self.retrievalAPI.flags = kFxParameterFlag_HIDDEN;

	XCTAssertTrue([self.settingAPIv6 addFlags:kFxParameterFlag_DISABLED
								  toParameter:kSettingTestParameter]);

	XCTAssertEqualObjects(self.postedNames, (@[FxGripNotifyAPI_ParameterSetFlagsPreName,
											   FxGripNotifyAPI_ParameterSetFlagsName]));
}

/*! @abstract An observer answering the set-flags pre-notification short-circuits the host call. */
- (void)testAnObserverAnsweringThePreNotificationAlsoShortCircuitsTheV6Helpers
{
	self.retrievalAPI.flags = kFxParameterFlag_HIDDEN;
	[self observeName:FxGripNotifyAPI_ParameterSetFlagsPreName usingBlock:^(NSNotification *notification) {
		((NSMutableDictionary *)notification.userInfo).fxResult = @YES;
	}];

	XCTAssertTrue([self.settingAPIv6 addFlags:kFxParameterFlag_DISABLED
								  toParameter:kSettingTestParameter]);

	XCTAssertEqualObjects(self.hostAPI.calls, @[]);
}

@end
