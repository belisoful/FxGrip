//
//  FxGripDynamicParameterAPI_v3Tests.m
//  FxGripTests
//
//  Unit tests for FxGripDynamicParameterAPI_v3, which forwards the host's dynamic API and
//  posts a notification for each mutation it completes: parameter enumeration, removal, name
//  read and write, float and int bounds, and the popup menu setter.
//

#import "FxGripDynamicAPITestSupport.h"
#import <FxGrip/FxGripAPINotifications.h>
#import <FxGrip/FxGripDynamicParameterAPI_v3.h>

@interface FxGripDynamicParameterAPI_v3Tests : FxGripDynamicAPITestCase
@end

@implementation FxGripDynamicParameterAPI_v3Tests

#pragma mark Pass-through

- (void)testParameterCountReportsTheHostCount
{
	self.hostAPI.parameterIDs = @[@1, @2, @3];

	XCTAssertEqual([self.apiV3 parameterCount], (UInt32)3);
	XCTAssertEqualObjects(self.hostMethods, @[@"count"]);
}

- (void)testParameterIDAtIndexReportsTheHostID
{
	self.hostAPI.parameterIDs = @[@10, @20, @30];

	XCTAssertEqual([self.apiV3 parameterIDAtIndex:1], (UInt32)20);
	XCTAssertEqualObjects([self hostCallNamed:@"idatindex"][@"index"], @1);
}

- (void)testSetAsDefaultsForwardsTheTimeAndTheResult
{
	NSError *error = nil;

	XCTAssertTrue([self.apiV3 setAsDefaultsAtTime:FxGripDynamicTestTime() withError:&error]);

	XCTAssertNil(error);
	XCTAssertEqual(self.hostAPI.lastDefaultsTime.value, (int64_t)4);
	XCTAssertEqual(self.hostAPI.lastDefaultsTime.timescale, (int32_t)25);
}

- (void)testSetAsDefaultsReportsTheHostFailureAndItsError
{
	self.hostAPI.defaultsSucceed = NO;
	NSError *error = nil;

	XCTAssertFalse([self.apiV3 setAsDefaultsAtTime:FxGripDynamicTestTime() withError:&error]);

	XCTAssertEqualObjects(error.domain, @"FxGripDynamicTest");
}

#pragma mark removeParameter:

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

- (void)testAFailedRemovalReturnsTheHostErrorAndPostsNothing
{
	self.hostAPI.nextError = FxGripDynamicTestError();

	XCTAssertEqualObjects([self.apiV3 removeParameter:kDynamicTestParameter], FxGripDynamicTestError());

	XCTAssertEqualObjects(self.posted, @[]);
}

#pragma mark parameter:name:

- (void)testGetNamePostsTheReadNotificationCarryingTheHostName
{
	self.hostAPI.hostName = @"HostName";
	NSString *name = nil;

	XCTAssertNil([self.apiV3 parameter:kDynamicTestParameter name:&name]);

	XCTAssertEqualObjects(name, @"HostName");
	XCTAssertEqualObjects(self.postedNames, @[FxGripNotifyAPI_ParameterGetNameName]);
}

- (void)testANameReadTheHostAnswersWithNoNameAndNoErrorPostsNothing
{
	self.hostAPI.hostName = nil;
	NSString *name = @"Untouched";

	XCTAssertNil([self.apiV3 parameter:kDynamicTestParameter name:&name]);

	XCTAssertNil(name, @"the caller's pointer keeps the host's nil");
	XCTAssertEqualObjects(self.posted, @[]);
}

- (void)testAFailedNameReadReturnsTheHostErrorAndPostsNothing
{
	self.hostAPI.nextError = FxGripDynamicTestError();
	NSString *name = nil;

	XCTAssertEqualObjects([self.apiV3 parameter:kDynamicTestParameter name:&name], FxGripDynamicTestError());

	XCTAssertEqualObjects(self.posted, @[]);
	XCTAssertNil(name);
}

#pragma mark setParameter:name:

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

- (void)testARenameTheHostRefusesPostsOnlyThePreNotification
{
	self.hostAPI.nextError = FxGripDynamicTestError();

	XCTAssertEqualObjects([self.apiV3 setParameter:kDynamicTestParameter name:@"NewName"],
						  FxGripDynamicTestError());

	XCTAssertEqualObjects(self.postedNames, @[FxGripNotifyAPI_ParameterSetNamePreName]);
}

#pragma mark Bounds

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

- (void)testFloatBoundsTheHostRefusesPostNothing
{
	self.hostAPI.nextError = FxGripDynamicTestError();

	XCTAssertNotNil([self.apiV3 setParameter:kDynamicTestParameter
								floatMinimum:0 maximum:1 sliderMinimum:0 sliderMaximum:1]);

	XCTAssertEqualObjects(self.posted, @[]);
}

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

- (void)testIntBoundsTheHostRefusesPostNothing
{
	self.hostAPI.nextError = FxGripDynamicTestError();

	XCTAssertNotNil([self.apiV3 setParameter:kDynamicTestParameter
								  intMinimum:0 maximum:1 sliderMinimum:0 sliderMaximum:1]);

	XCTAssertEqualObjects(self.posted, @[]);
}

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

- (void)testSetPopupMenuPostsBothNotificationsOnSuccess
{
	NSArray<NSString *> *entries = @[@"One", @"Two"];

	XCTAssertNil([self.apiV3 setPopupMenuParameter:kDynamicTestParameter
										   entries:entries
									  defaultValue:1]);

	XCTAssertEqualObjects(self.postedNames, (@[FxGripNotifyAPI_ParameterSetMenuPreName,
											   FxGripNotifyAPI_ParameterSetMenuName]));
}

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
