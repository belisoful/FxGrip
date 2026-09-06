//
//  FxGripParameterSettingAPI_v6Tests.m
//  FxGripTests
//
//  Unit tests for FxGripParameterSettingAPI_v6, which adds the read-modify-write flag
//  helpers on top of the version-five setting wrapper. The helpers read the current flags,
//  apply the change, and run the version-five notification flow.
//

#import "FxGripSettingAPITestSupport.h"
#import <FxGrip/FxGripParameterFlags.h>
#import <FxGrip/FxGripAPINotifications.h>
#import <FxGrip/FxGripParameterSettingAPI_v6.h>

@interface FxGripParameterSettingAPI_v6Tests : FxGripSettingAPITestCase
@end

@implementation FxGripParameterSettingAPI_v6Tests

- (void)testAddFlagsOrsTheNewBitsIntoTheCurrentFlags
{
	self.retrievalAPI.flags = kFxParameterFlag_HIDDEN;

	XCTAssertTrue([self.settingAPIv6 addFlags:kFxParameterFlag_DISABLED
								  toParameter:kSettingTestParameter]);

	XCTAssertEqualObjects(self.hostCall[@"value"],
						  @(kFxParameterFlag_HIDDEN | kFxParameterFlag_DISABLED));
}

- (void)testRemoveFlagsClearsOnlyTheNamedBits
{
	self.retrievalAPI.flags = kFxParameterFlag_HIDDEN | kFxParameterFlag_DISABLED;

	XCTAssertTrue([self.settingAPIv6 removeFlags:kFxParameterFlag_HIDDEN
								   fromParameter:kSettingTestParameter]);

	XCTAssertEqualObjects(self.hostCall[@"value"], @(kFxParameterFlag_DISABLED));
}

- (void)testAddFlagsReportsFailureWhenTheCurrentFlagsCannotBeRead
{
	self.retrievalAPI.flagsSucceed = NO;

	XCTAssertFalse([self.settingAPIv6 addFlags:kFxParameterFlag_DISABLED
								   toParameter:kSettingTestParameter]);

	XCTAssertEqualObjects(self.hostAPI.calls, @[]);
	XCTAssertEqualObjects(self.posted, @[]);
}

- (void)testRemoveFlagsReportsFailureWhenTheCurrentFlagsCannotBeRead
{
	self.retrievalAPI.flagsSucceed = NO;

	XCTAssertFalse([self.settingAPIv6 removeFlags:kFxParameterFlag_HIDDEN
									fromParameter:kSettingTestParameter]);

	XCTAssertEqualObjects(self.hostAPI.calls, @[]);
}

- (void)testTheV6FlagHelpersRunTheV5NotificationFlow
{
	self.retrievalAPI.flags = kFxParameterFlag_HIDDEN;

	XCTAssertTrue([self.settingAPIv6 addFlags:kFxParameterFlag_DISABLED
								  toParameter:kSettingTestParameter]);

	XCTAssertEqualObjects(self.postedNames, (@[FxGripNotifyAPI_ParameterSetFlagsPreName,
											   FxGripNotifyAPI_ParameterSetFlagsName]));
}

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
