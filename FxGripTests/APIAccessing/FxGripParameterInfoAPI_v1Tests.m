/*!
	@file       FxGripParameterInfoAPI_v1Tests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripParameterInfoAPI_v1Tests
	@abstract   Verifies FxGripParameterInfoAPI_v1's existence, ID enumeration, type, and menu-entry queries.
	@discussion Introduced in FxGrip 0.1.0. The existence and enumeration queries walk the host's parameter IDs. The type and menu queries are answered by notification observers rather than the host.
*/

#import "FxGripDynamicAPITestSupport.h"
#import <FxGrip/FxGripAPINotifications.h>
#import <FxGrip/FxGripParameterInfoAPI_v1.h>

@interface FxGripParameterInfoAPI_v1Tests : FxGripDynamicAPITestCase
@end

@implementation FxGripParameterInfoAPI_v1Tests

#pragma mark parameterExists: and allParameterIDs

/*! @abstract parameterExists: is YES for an ID the host reports. */
- (void)testParameterExistsFindsAnIDTheHostReports
{
	self.hostAPI.parameterIDs = @[@1, @(kDynamicTestParameter), @3];

	XCTAssertTrue([self.apiInfo parameterExists:kDynamicTestParameter]);
}

/*! @abstract parameterExists: is NO for an ID the host does not report. */
- (void)testParameterExistsIsNOForAnIDTheHostDoesNotReport
{
	self.hostAPI.parameterIDs = @[@1, @2];

	XCTAssertFalse([self.apiInfo parameterExists:kDynamicTestParameter]);
}

/*! @abstract parameterExists: is NO and reads only the host count when the host has no parameters. */
- (void)testParameterExistsIsNOWhenTheHostHasNoParameters
{
	XCTAssertFalse([self.apiInfo parameterExists:kDynamicTestParameter]);
	XCTAssertEqualObjects(self.hostMethods, @[@"count"]);
}

/*! @abstract parameterExists: stops walking the host IDs at the first matching index. */
- (void)testParameterExistsStopsAtTheMatchingIndex
{
	self.hostAPI.parameterIDs = @[@(kDynamicTestParameter), @2, @3];

	XCTAssertTrue([self.apiInfo parameterExists:kDynamicTestParameter]);
	XCTAssertEqualObjects(self.hostMethods, (@[@"count", @"idatindex"]));
}

/*! @abstract allParameterIDs reports every host ID in index order. */
- (void)testAllParameterIDsReportsEveryHostIDInIndexOrder
{
	self.hostAPI.parameterIDs = @[@10, @20, @30];

	XCTAssertEqualObjects([self.apiInfo allParameterIDs], (@[@10, @20, @30]));
}

/*! @abstract allParameterIDs is empty when the host has no parameters. */
- (void)testAllParameterIDsIsEmptyWhenTheHostHasNoParameters
{
	XCTAssertEqualObjects([self.apiInfo allParameterIDs], @[]);
}

#pragma mark parameterType:

/*! @abstract parameterType: is None and posts the get-type notification when no observer answers. */
- (void)testParameterTypeIsNoneWhenNoObserverAnswers
{
	XCTAssertEqual([self.apiInfo parameterType:kDynamicTestParameter], FxParameterType_None);
	XCTAssertEqualObjects(self.postedNames, @[FxGripNotifyAPI_ParameterGetTypeName]);
}

/*! @abstract parameterType: reports the type an observer writes into the notification payload. */
- (void)testParameterTypeReportsTheTypeAnObserverWrites
{
	[self observeName:FxGripNotifyAPI_ParameterGetTypeName usingBlock:^(NSNotification *notification) {
		notification.userInfo.mutableFxParameter[kFxParameterProperty_Type] =
			@(FxParameterType_Custom);
	}];

	XCTAssertEqual([self.apiInfo parameterType:kDynamicTestParameter], FxParameterType_Custom);
}

/*! @abstract The type query carries the parameter ID in both the top-level userInfo and the nested payload and calls no host. */
- (void)testTheTypeQueryCarriesTheParameterIDAtBothLevelsAndAsksNoHost
{
	__block NSDictionary *seen = nil;
	[self observeName:FxGripNotifyAPI_ParameterGetTypeName usingBlock:^(NSNotification *notification) {
		seen = @{@"outer": notification.userInfo[kFxParameterProperty_Id],
				 @"nested": notification.userInfo.fxParameter[kFxParameterProperty_Id]};
	}];

	[self.apiInfo parameterType:kDynamicTestParameter];

	XCTAssertEqualObjects(seen, (@{@"outer": @(kDynamicTestParameter),
								   @"nested": @(kDynamicTestParameter)}));
	XCTAssertEqualObjects(self.hostAPI.calls, @[]);
}

#pragma mark parameter:entries:

/*! @abstract parameter:entries: fills the caller with an empty array when no observer answers. */
- (void)testMenuEntriesAreEmptyWhenNoObserverAnswers
{
	NSArray<NSString *> *entries = nil;

	XCTAssertNil([self.apiInfo parameter:kDynamicTestParameter entries:&entries]);

	XCTAssertEqualObjects(entries, @[]);
}

/*! @abstract parameter:entries: returns the error an observer sets on the get-menu notification. */
- (void)testMenuEntriesReportAnObserverError
{
	[self observeName:FxGripNotifyAPI_ParameterGetMenuName usingBlock:^(NSNotification *notification) {
		((NSMutableDictionary *)notification.userInfo).fxError = FxGripDynamicTestError();
	}];
	NSArray<NSString *> *entries = nil;

	XCTAssertEqualObjects([self.apiInfo parameter:kDynamicTestParameter entries:&entries],
						  FxGripDynamicTestError());
}

@end
