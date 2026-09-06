/*!
	@file       FxGripDynamicParameterAPI_v3Tests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripDynamicParameterAPI_v3Tests
	@abstract   Verifies that FxGripDynamicParameterAPI_v3 forwards each dynamic-API call to the host and posts the matching FxGrip notifications.
	@discussion Introduced in FxGrip 0.1.0. The tests cover parameter count and ID reads, defaults, removal, name read and write, float and int bounds, and the popup menu setter. Each mutation asserts the host call and the notification payload. Pre-notification observers and host refusals are exercised to confirm the abort path.
*/

#import "FxGripDynamicAPITestSupport.h"
#import <FxGrip/FxGripAPINotifications.h>
#import <FxGrip/FxGripDynamicParameterAPI_v3.h>

@interface FxGripDynamicParameterAPI_v3Tests : FxGripDynamicAPITestCase
@end

@implementation FxGripDynamicParameterAPI_v3Tests

#pragma mark Pass-through

/*! @abstract parameterCount returns the host's parameter count and issues the host count call. */
- (void)testParameterCountReportsTheHostCount
{
	self.hostAPI.parameterIDs = @[@1, @2, @3];

	XCTAssertEqual([self.apiV3 parameterCount], (UInt32)3);
	XCTAssertEqualObjects(self.hostMethods, @[@"count"]);
}

/*! @abstract parameterIDAtIndex: returns the host ID at the index and forwards that index to the host. */
- (void)testParameterIDAtIndexReportsTheHostID
{
	self.hostAPI.parameterIDs = @[@10, @20, @30];

	XCTAssertEqual([self.apiV3 parameterIDAtIndex:1], (UInt32)20);
	XCTAssertEqualObjects([self hostCallNamed:@"idatindex"][@"index"], @1);
}

/*! @abstract setAsDefaultsAtTime:withError: returns YES, reports no error, and forwards the time value and timescale to the host. */
- (void)testSetAsDefaultsForwardsTheTimeAndTheResult
{
	NSError *error = nil;

	XCTAssertTrue([self.apiV3 setAsDefaultsAtTime:FxGripDynamicTestTime() withError:&error]);

	XCTAssertNil(error);
	XCTAssertEqual(self.hostAPI.lastDefaultsTime.value, (int64_t)4);
	XCTAssertEqual(self.hostAPI.lastDefaultsTime.timescale, (int32_t)25);
}

/*! @abstract setAsDefaultsAtTime:withError: returns NO and reports the host error domain when the host declines. */
- (void)testSetAsDefaultsReportsTheHostFailureAndItsError
{
	self.hostAPI.defaultsSucceed = NO;
	NSError *error = nil;

	XCTAssertFalse([self.apiV3 setAsDefaultsAtTime:FxGripDynamicTestTime() withError:&error]);

	XCTAssertEqualObjects(error.domain, @"FxGripDynamicTest");
}

#pragma mark removeParameter:

/*! @abstract removeParameter: returns nil, calls the host remove, and posts the remove notification carrying the parameter ID. */
- (void)testRemoveParameterPostsTheRemoveNotificationCarryingTheID
{
	XCTAssertNil([self.apiV3 removeParameter:kDynamicTestParameter]);

	XCTAssertEqualObjects(self.hostMethods, @[@"remove"]);
	XCTAssertEqualObjects(self.postedNames, @[FxGripNotifyAPI_ParameterRemoveName]);
	NSDictionary *userInfo = [self notificationNamed:FxGripNotifyAPI_ParameterRemoveName].userInfo;
	XCTAssertEqualObjects(userInfo[kFxParameterProperty_Id], @(kDynamicTestParameter));
	XCTAssertEqualObjects(userInfo.fxParameter,
						  @{kFxParameterProperty_Id: @(kDynamicTestParameter)});
}

/*! @abstract removeParameter: returns the host error and posts no notification when the host removal fails. */
- (void)testAFailedRemovalReturnsTheHostErrorAndPostsNothing
{
	self.hostAPI.nextError = FxGripDynamicTestError();

	XCTAssertEqualObjects([self.apiV3 removeParameter:kDynamicTestParameter], FxGripDynamicTestError());

	XCTAssertEqualObjects(self.posted, @[]);
}

#pragma mark parameter:name:

/*! @abstract parameter:name: fills the caller pointer with the host name and posts the get-name notification. */
- (void)testGetNamePostsTheReadNotificationCarryingTheHostName
{
	self.hostAPI.hostName = @"HostName";
	NSString *name = nil;

	XCTAssertNil([self.apiV3 parameter:kDynamicTestParameter name:&name]);

	XCTAssertEqualObjects(name, @"HostName");
	XCTAssertEqualObjects(self.postedNames, @[FxGripNotifyAPI_ParameterGetNameName]);
}

/*! @abstract parameter:name: leaves the caller pointer at the host's nil and posts nothing when the host returns no name and no error. */
- (void)testANameReadTheHostAnswersWithNoNameAndNoErrorPostsNothing
{
	self.hostAPI.hostName = nil;
	NSString *name = @"Untouched";

	XCTAssertNil([self.apiV3 parameter:kDynamicTestParameter name:&name]);

	XCTAssertNil(name, @"the caller's pointer keeps the host's nil");
	XCTAssertEqualObjects(self.posted, @[]);
}

/*! @abstract parameter:name: returns the host error, leaves the name nil, and posts nothing when the host read fails. */
- (void)testAFailedNameReadReturnsTheHostErrorAndPostsNothing
{
	self.hostAPI.nextError = FxGripDynamicTestError();
	NSString *name = nil;

	XCTAssertEqualObjects([self.apiV3 parameter:kDynamicTestParameter name:&name], FxGripDynamicTestError());

	XCTAssertEqualObjects(self.posted, @[]);
	XCTAssertNil(name);
}

#pragma mark setParameter:name:

/*! @abstract setParameter:name: forwards the name to the host and posts the pre and post set-name notifications carrying the ID and name. */
- (void)testSetNameForwardsTheNameAndPostsBothNotifications
{
	XCTAssertNil([self.apiV3 setParameter:kDynamicTestParameter name:@"NewName"]);

	XCTAssertEqualObjects([self hostCallNamed:@"setname"][@"name"], @"NewName");
	XCTAssertEqualObjects(self.postedNames, (@[FxGripNotifyAPI_ParameterSetNamePreName,
											   FxGripNotifyAPI_ParameterSetNameName]));
	NSDictionary *payload = [self notificationNamed:FxGripNotifyAPI_ParameterSetNameName].userInfo.fxParameter;
	XCTAssertEqualObjects(payload[kFxParameterProperty_Id], @(kDynamicTestParameter));
	XCTAssertEqualObjects(payload[kFxParameterProperty_Name], @"NewName");
}

/*! @abstract setParameter:name: returns the observer's error, skips the host call, and posts only the pre-notification when an observer sets an error on the set-name pre-notification. */
- (void)testAnObserverSettingAnErrorOnTheNamePreNotificationAbortsTheRename
{
	[self observeName:FxGripNotifyAPI_ParameterSetNamePreName usingBlock:^(NSNotification *notification) {
		((NSMutableDictionary *)notification.userInfo).fxError = FxGripDynamicTestError();
	}];

	XCTAssertEqualObjects([self.apiV3 setParameter:kDynamicTestParameter name:@"NewName"],
						  FxGripDynamicTestError());

	XCTAssertEqualObjects(self.hostAPI.calls, @[]);
	XCTAssertEqualObjects(self.postedNames, @[FxGripNotifyAPI_ParameterSetNamePreName]);
}

/*! @abstract setParameter:name: returns the host error and posts only the pre-notification when the host refuses the rename. */
- (void)testARenameTheHostRefusesPostsOnlyThePreNotification
{
	self.hostAPI.nextError = FxGripDynamicTestError();

	XCTAssertEqualObjects([self.apiV3 setParameter:kDynamicTestParameter name:@"NewName"],
						  FxGripDynamicTestError());

	XCTAssertEqualObjects(self.postedNames, @[FxGripNotifyAPI_ParameterSetNamePreName]);
}

#pragma mark Bounds

/*! @abstract setParameter:floatMinimum:maximum:sliderMinimum:sliderMaximum: forwards every bound to the host and posts them in the float-bounds notification. */
- (void)testSetFloatBoundsForwardsEveryBoundAndPostsThem
{
	XCTAssertNil([self.apiV3 setParameter:kDynamicTestParameter
							 floatMinimum:-1.0
								  maximum:1.0
							sliderMinimum:-0.5
							sliderMaximum:0.5]);

	XCTAssertEqualObjects([self hostCallNamed:@"setfloatbounds"], (@{@"method": @"setfloatbounds",
																	@"id": @(kDynamicTestParameter),
																	@"min": @(-1.0),
																	@"max": @1.0,
																	@"slidermin": @(-0.5),
																	@"slidermax": @0.5}));
	NSDictionary *payload = [self notificationNamed:FxGripNotifyAPI_ParameterSetFloatBoundsName].userInfo.fxParameter;
	XCTAssertEqualObjects(payload[kFxParameterProperty_Minimum], @(-1.0));
	XCTAssertEqualObjects(payload[kFxParameterProperty_Maximum], @1.0);
	XCTAssertEqualObjects(payload[kFxParameterProperty_SliderMinimum], @(-0.5));
	XCTAssertEqualObjects(payload[kFxParameterProperty_SliderMaximum], @0.5);
}

/*! @abstract Setting float bounds returns an error and posts nothing when the host refuses. */
- (void)testFloatBoundsTheHostRefusesPostNothing
{
	self.hostAPI.nextError = FxGripDynamicTestError();

	XCTAssertNotNil([self.apiV3 setParameter:kDynamicTestParameter
								floatMinimum:0 maximum:1 sliderMinimum:0 sliderMaximum:1]);

	XCTAssertEqualObjects(self.posted, @[]);
}

/*! @abstract parameter:floatMinimum:maximum:sliderMinimum:sliderMaximum: fills each out-parameter with the host's float bound. */
- (void)testGetFloatBoundsFillsEveryValueFromTheHost
{
	self.hostAPI.floatMinimum = -2;
	self.hostAPI.floatMaximum = 2;
	self.hostAPI.floatSliderMinimum = -1;
	self.hostAPI.floatSliderMaximum = 1;
	double min = 0, max = 0, sliderMin = 0, sliderMax = 0;

	XCTAssertNil([self.apiV3 parameter:kDynamicTestParameter
						  floatMinimum:&min
							   maximum:&max
						 sliderMinimum:&sliderMin
						 sliderMaximum:&sliderMax]);

	XCTAssertEqual(min, -2);
	XCTAssertEqual(max, 2);
	XCTAssertEqual(sliderMin, -1);
	XCTAssertEqual(sliderMax, 1);
}

/*! @abstract setParameter:intMinimum:maximum:sliderMinimum:sliderMaximum: forwards every bound to the host and posts them in the int-bounds notification. */
- (void)testSetIntBoundsForwardsEveryBoundAndPostsThem
{
	XCTAssertNil([self.apiV3 setParameter:kDynamicTestParameter
							   intMinimum:1
								  maximum:100
							sliderMinimum:2
							sliderMaximum:50]);

	XCTAssertEqualObjects([self hostCallNamed:@"setintbounds"], (@{@"method": @"setintbounds",
																   @"id": @(kDynamicTestParameter),
																   @"min": @1,
																   @"max": @100,
																   @"slidermin": @2,
																   @"slidermax": @50}));
	NSDictionary *payload = [self notificationNamed:FxGripNotifyAPI_ParameterSetIntBoundsName].userInfo.fxParameter;
	XCTAssertEqualObjects(payload[kFxParameterProperty_Minimum], @1);
	XCTAssertEqualObjects(payload[kFxParameterProperty_SliderMaximum], @50);
}

/*! @abstract Setting int bounds returns an error and posts nothing when the host refuses. */
- (void)testIntBoundsTheHostRefusesPostNothing
{
	self.hostAPI.nextError = FxGripDynamicTestError();

	XCTAssertNotNil([self.apiV3 setParameter:kDynamicTestParameter
								  intMinimum:0 maximum:1 sliderMinimum:0 sliderMaximum:1]);

	XCTAssertEqualObjects(self.posted, @[]);
}

/*! @abstract parameter:intMinimum:maximum:sliderMinimum:sliderMaximum: fills each out-parameter with the host's int bound. */
- (void)testGetIntBoundsFillsEveryValueFromTheHost
{
	self.hostAPI.intMinimum = 1;
	self.hostAPI.intMaximum = 9;
	self.hostAPI.intSliderMinimum = 2;
	self.hostAPI.intSliderMaximum = 8;
	int min = 0, max = 0, sliderMin = 0, sliderMax = 0;

	XCTAssertNil([self.apiV3 parameter:kDynamicTestParameter
							intMinimum:&min
							   maximum:&max
						 sliderMinimum:&sliderMin
						 sliderMaximum:&sliderMax]);

	XCTAssertEqual(min, 1);
	XCTAssertEqual(max, 9);
	XCTAssertEqual(sliderMin, 2);
	XCTAssertEqual(sliderMax, 8);
}

#pragma mark setPopupMenuParameter:

/*! @abstract setPopupMenuParameter:entries:defaultValue: posts a pre-notification carrying the ID, the menu entries, and the default index. */
- (void)testSetPopupMenuPostsThePreNotificationCarryingTheEntriesAndDefault
{
	__block NSDictionary *seen = nil;
	[self observeName:FxGripNotifyAPI_ParameterSetMenuPreName usingBlock:^(NSNotification *notification) {
		seen = notification.userInfo.fxParameter.copy;
	}];

	[self.apiV3 setPopupMenuParameter:kDynamicTestParameter
							  entries:@[@"One", @"Two"]
						 defaultValue:1];

	XCTAssertEqualObjects(seen, (@{kFxParameterProperty_Id: @(kDynamicTestParameter),
								   kFxParameterProperty_MenuItems: (@[@"One", @"Two"]),
								   kFxParameterProperty_Default: @1}));
}

/*! @abstract setPopupMenuParameter:entries:defaultValue: returns nil and posts both the pre and post menu notifications on success. */
- (void)testSetPopupMenuPostsBothNotificationsOnSuccess
{
	NSArray<NSString *> *entries = @[@"One", @"Two"];

	XCTAssertNil([self.apiV3 setPopupMenuParameter:kDynamicTestParameter
										   entries:entries
									  defaultValue:1]);

	XCTAssertEqualObjects(self.postedNames, (@[FxGripNotifyAPI_ParameterSetMenuPreName,
											   FxGripNotifyAPI_ParameterSetMenuName]));
}

/*! @abstract setPopupMenuParameter:entries:defaultValue: returns the observer's error and skips the host call when an observer sets an error on the menu pre-notification. */
- (void)testAnObserverSettingAnErrorOnTheMenuPreNotificationAbortsTheChange
{
	[self observeName:FxGripNotifyAPI_ParameterSetMenuPreName usingBlock:^(NSNotification *notification) {
		((NSMutableDictionary *)notification.userInfo).fxError = FxGripDynamicTestError();
	}];

	XCTAssertEqualObjects([self.apiV3 setPopupMenuParameter:kDynamicTestParameter
													entries:@[@"One"]
											   defaultValue:0],
						  FxGripDynamicTestError());

	XCTAssertEqualObjects(self.hostAPI.calls, @[]);
}

/*! @abstract setPopupMenuParameter:entries:defaultValue: returns an error and posts only the pre-notification when the host refuses the change. */
- (void)testAMenuChangeTheHostRefusesPostsOnlyThePreNotification
{
	self.hostAPI.nextError = FxGripDynamicTestError();

	XCTAssertNotNil([self.apiV3 setPopupMenuParameter:kDynamicTestParameter
											  entries:@[@"One"]
										 defaultValue:0]);

	XCTAssertEqualObjects(self.postedNames, @[FxGripNotifyAPI_ParameterSetMenuPreName]);
}

/*!
	DEFECT: setPopupMenuParameter:entries:defaultValue: reads the entries and the default
	index back through the guarded NSDictionary(FxGripTileableEffect) accessors, which answer
	only for a payload carrying an ID, a type, and a name. The payload the method builds
	carries an ID alone, so the host always receives nil entries and index 0. This test
	states the intended forwarding and fails today.
*/
- (void)testSetPopupMenuForwardsTheEntriesAndTheDefaultIndexToTheHost
{
	[self.apiV3 setPopupMenuParameter:kDynamicTestParameter
							  entries:@[@"One", @"Two"]
						 defaultValue:1];

	XCTAssertEqualObjects([self hostCallNamed:@"setmenu"], (@{@"method": @"setmenu",
															  @"id": @(kDynamicTestParameter),
															  @"items": (@[@"One", @"Two"]),
															  @"default": @1}));
}

@end
