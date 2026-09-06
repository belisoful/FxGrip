//
//  FxGripParameterInfoAPI_v1Tests.m
//  FxGripTests
//
//  Unit tests for FxGripParameterInfoAPI_v1: parameter existence and type queries, the ID
//  enumeration, and the menu entries. The type and menu queries are answered by observers
//  rather than the host.
//

#import "FxGripDynamicAPITestSupport.h"
#import <FxGrip/FxGripAPINotifications.h>
#import <FxGrip/FxGripParameterInfoAPI_v1.h>

@interface FxGripParameterInfoAPI_v1Tests : FxGripDynamicAPITestCase
@end

@implementation FxGripParameterInfoAPI_v1Tests

#pragma mark parameterExists: and allParameterIDs

- (void)testParameterExistsFindsAnIDTheHostReports
{
	self.hostAPI.parameterIDs = @[@1, @(kDynamicTestParameter), @3];

	XCTAssertTrue([self.apiInfo parameterExists:kDynamicTestParameter]);
}

- (void)testParameterExistsIsNOForAnIDTheHostDoesNotReport
{
	self.hostAPI.parameterIDs = @[@1, @2];

	XCTAssertFalse([self.apiInfo parameterExists:kDynamicTestParameter]);
}

- (void)testParameterExistsIsNOWhenTheHostHasNoParameters
{
	XCTAssertFalse([self.apiInfo parameterExists:kDynamicTestParameter]);
	XCTAssertEqualObjects(self.hostMethods, @[@"count"]);
}

- (void)testParameterExistsStopsAtTheMatchingIndex
{
	self.hostAPI.parameterIDs = @[@(kDynamicTestParameter), @2, @3];

	XCTAssertTrue([self.apiInfo parameterExists:kDynamicTestParameter]);
	XCTAssertEqualObjects(self.hostMethods, (@[@"count", @"idatindex"]));
}

- (void)testAllParameterIDsReportsEveryHostIDInIndexOrder
{
	self.hostAPI.parameterIDs = @[@10, @20, @30];

	XCTAssertEqualObjects([self.apiInfo allParameterIDs], (@[@10, @20, @30]));
}

- (void)testAllParameterIDsIsEmptyWhenTheHostHasNoParameters
{
	XCTAssertEqualObjects([self.apiInfo allParameterIDs], @[]);
}

#pragma mark parameterType:

- (void)testParameterTypeIsNoneWhenNoObserverAnswers
{
	XCTAssertEqual([self.apiInfo parameterType:kDynamicTestParameter], FxParameterType_None);
	XCTAssertEqualObjects(self.postedNames, @[FxGripNotifyAPI_ParameterGetTypeName]);
}

- (void)testParameterTypeReportsTheTypeAnObserverWrites
{
	[self observeName:FxGripNotifyAPI_ParameterGetTypeName usingBlock:^(NSNotification *notification) {
		notification.userInfo.mutableFxParameter[kFxParameterProperty_Type] =
			@(FxParameterType_Custom);
	}];

	XCTAssertEqual([self.apiInfo parameterType:kDynamicTestParameter], FxParameterType_Custom);
}

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

- (void)testMenuEntriesAreEmptyWhenNoObserverAnswers
{
	NSArray<NSString *> *entries = nil;

	XCTAssertNil([self.apiInfo parameter:kDynamicTestParameter entries:&entries]);

	XCTAssertEqualObjects(entries, @[]);
}

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
