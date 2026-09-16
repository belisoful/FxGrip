/*!
	@file       FxGripDynamicParameterAPI_v4Tests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-10
	@header     FxGripDynamicParameterAPI_v4Tests
	@abstract   Verifies the FxGrip additions FxGripDynamicParameterAPI_v4 layers over the v3 wrapper: single-edge bounds setters, existence and type queries, menu-entry retrieval, and metadata forwarding.
	@discussion Introduced in FxGrip 0.1.0. Each single-edge setter reads the current range from the host and writes it back with one edge changed, so the tests assert the full four-value host write. The type and menu queries resolve through the notification observers. The metadata methods forward to a real meta manager the stub effect vends, and answer the not-found result when the effect has none.
*/

#import "FxGripDynamicAPITestSupport.h"
#import <FxGrip/FxGripAPINotifications.h>
#import <FxGrip/FxGripDynamicParameterAPI_v4.h>
#import <FxGrip/FxGripMetaManager.h>
#import <FxGrip/FxGripErrors.h>

/*! The dynamic-test effect plus the meta manager FxGripCommonAPI resolves through -meta. */
@interface FxGripDynamicV4TestEffect : FxGripDynamicTestStubEffect
@property (nonatomic, strong, nullable) FxGripMetaManager *meta;
@end

@implementation FxGripDynamicV4TestEffect
@end

@interface FxGripDynamicParameterAPI_v4Tests : FxGripDynamicAPITestCase
@end

@implementation FxGripDynamicParameterAPI_v4Tests

- (void)setUp
{
	[super setUp];
	// The base wires its observers to the plain stub; the v4 tests need the meta-carrying one.
	self.effect = [FxGripDynamicV4TestEffect.alloc init];
	for (NSNotificationName name in self.recordedNotificationNames) {
		[self observeName:name usingBlock:^(NSNotification *notification) {
			[self.posted addObject:notification];
		}];
	}
	self.hostAPI.floatMinimum = -2;
	self.hostAPI.floatMaximum = 2;
	self.hostAPI.floatSliderMinimum = -1;
	self.hostAPI.floatSliderMaximum = 1;
	self.hostAPI.intMinimum = 10;
	self.hostAPI.intMaximum = 90;
	self.hostAPI.intSliderMinimum = 20;
	self.hostAPI.intSliderMaximum = 80;
}

- (FxGripDynamicV4TestEffect *)v4Effect
{
	return (FxGripDynamicV4TestEffect *)self.effect;
}

- (FxGripDynamicParameterAPI_v4 *)apiV4
{
	return [FxGripDynamicParameterAPI_v4.alloc initWithAPI:(id)self.hostAPI effect:(id)self.effect];
}

- (FxGripMetaManager *)installMetaManager
{
	FxGripMetaManager *manager = [FxGripMetaManager.alloc initWithEffect:nil];
	[manager addParameter:kDynamicTestParameter];
	self.v4Effect.meta = manager;
	return manager;
}

- (void)assertFloatWriteMin:(double)min max:(double)max sliderMin:(double)sliderMin sliderMax:(double)sliderMax
{
	XCTAssertEqualObjects(self.hostMethods, (@[@"getfloatbounds", @"setfloatbounds"]));
	XCTAssertEqualObjects([self hostCallNamed:@"setfloatbounds"], (@{@"method": @"setfloatbounds",
																	@"id": @(kDynamicTestParameter),
																	@"min": @(min),
																	@"max": @(max),
																	@"slidermin": @(sliderMin),
																	@"slidermax": @(sliderMax)}));
	XCTAssertEqualObjects(self.postedNames, @[FxGripNotifyAPI_ParameterSetFloatBoundsName]);
}

- (void)assertIntWriteMin:(int)min max:(int)max sliderMin:(int)sliderMin sliderMax:(int)sliderMax
{
	XCTAssertEqualObjects(self.hostMethods, (@[@"getintbounds", @"setintbounds"]));
	XCTAssertEqualObjects([self hostCallNamed:@"setintbounds"], (@{@"method": @"setintbounds",
																   @"id": @(kDynamicTestParameter),
																   @"min": @(min),
																   @"max": @(max),
																   @"slidermin": @(sliderMin),
																   @"slidermax": @(sliderMax)}));
	XCTAssertEqualObjects(self.postedNames, @[FxGripNotifyAPI_ParameterSetIntBoundsName]);
}

- (void)assertNoMetaError:(NSError *)error
{
	XCTAssertNotNil(error);
	XCTAssertEqualObjects(error.domain, FxGripPlugErrorDomain);
	XCTAssertEqual(error.code, kFxError_ThirdPartyDeveloperStart + kDynamicTestParameter);
}

#pragma mark Wrapper

/*! @abstract The v4 wrapper is a v3 wrapper and conforms to both dynamic protocols. */
- (void)testTheV4WrapperIsAlsoAV3Wrapper
{
	FxGripDynamicParameterAPI_v4 *api = self.apiV4;

	XCTAssertTrue([api isKindOfClass:FxGripDynamicParameterAPI_v3.class]);
	XCTAssertTrue([api conformsToProtocol:@protocol(FxGripDynamicParameterAPI_v4)]);
	XCTAssertTrue([api conformsToProtocol:@protocol(FxDynamicParameterAPI_v3)]);
	XCTAssertEqual((id)api.api, (id)self.hostAPI);
}

#pragma mark Float single-edge setters

/*! @abstract setParameter:floatMinimum: writes the new minimum with the host's other three float bounds and posts the float-bounds notification. */
- (void)testSetFloatMinimumKeepsTheOtherBounds
{
	XCTAssertNil([self.apiV4 setParameter:kDynamicTestParameter floatMinimum:-5]);

	[self assertFloatWriteMin:-5 max:2 sliderMin:-1 sliderMax:1];
}

/*! @abstract setParameter:floatMaximum: writes the new maximum with the host's other three float bounds. */
- (void)testSetFloatMaximumKeepsTheOtherBounds
{
	XCTAssertNil([self.apiV4 setParameter:kDynamicTestParameter floatMaximum:5]);

	[self assertFloatWriteMin:-2 max:5 sliderMin:-1 sliderMax:1];
}

/*! @abstract setParameter:floatMinimum:maximum: writes both value bounds and keeps the host's slider bounds. */
- (void)testSetFloatMinimumAndMaximumKeepsTheSliderBounds
{
	XCTAssertNil([self.apiV4 setParameter:kDynamicTestParameter floatMinimum:-7 maximum:7]);

	[self assertFloatWriteMin:-7 max:7 sliderMin:-1 sliderMax:1];
}

/*! @abstract setParameter:floatSliderMinimum: writes the new slider minimum and keeps the other float bounds. */
- (void)testSetFloatSliderMinimumKeepsTheOtherBounds
{
	XCTAssertNil([self.apiV4 setParameter:kDynamicTestParameter floatSliderMinimum:-0.5]);

	[self assertFloatWriteMin:-2 max:2 sliderMin:-0.5 sliderMax:1];
}

/*! @abstract setParameter:floatSliderMaximum: writes the new slider maximum and keeps the other float bounds. */
- (void)testSetFloatSliderMaximumKeepsTheOtherBounds
{
	XCTAssertNil([self.apiV4 setParameter:kDynamicTestParameter floatSliderMaximum:0.5]);

	[self assertFloatWriteMin:-2 max:2 sliderMin:-1 sliderMax:0.5];
}

/*! @abstract setParameter:floatSliderMinimum:sliderMaximum: writes both slider bounds and keeps the host's value bounds. */
- (void)testSetFloatSliderBoundsKeepsTheValueBounds
{
	XCTAssertNil([self.apiV4 setParameter:kDynamicTestParameter floatSliderMinimum:-0.25 sliderMaximum:0.25]);

	[self assertFloatWriteMin:-2 max:2 sliderMin:-0.25 sliderMax:0.25];
}

/*! @abstract Every float single-edge setter returns the host's read error and skips the write when the bounds read fails. */
- (void)testFloatSettersReturnTheReadErrorAndSkipTheWrite
{
	self.hostAPI.nextError = FxGripDynamicTestError();
	FxGripDynamicParameterAPI_v4 *api = self.apiV4;

	XCTAssertEqualObjects([api setParameter:kDynamicTestParameter floatMinimum:0], FxGripDynamicTestError());
	XCTAssertEqualObjects([api setParameter:kDynamicTestParameter floatMaximum:0], FxGripDynamicTestError());
	XCTAssertEqualObjects([api setParameter:kDynamicTestParameter floatMinimum:0 maximum:1], FxGripDynamicTestError());
	XCTAssertEqualObjects([api setParameter:kDynamicTestParameter floatSliderMinimum:0], FxGripDynamicTestError());
	XCTAssertEqualObjects([api setParameter:kDynamicTestParameter floatSliderMaximum:0], FxGripDynamicTestError());
	XCTAssertEqualObjects([api setParameter:kDynamicTestParameter floatSliderMinimum:0 sliderMaximum:1], FxGripDynamicTestError());

	XCTAssertEqualObjects(self.hostMethods, (@[@"getfloatbounds", @"getfloatbounds", @"getfloatbounds",
											   @"getfloatbounds", @"getfloatbounds", @"getfloatbounds"]));
	XCTAssertEqualObjects(self.posted, @[]);
}

#pragma mark Int single-edge setters

/*! @abstract setParameter:intMinimum: writes the new minimum with the host's other three int bounds and posts the int-bounds notification. */
- (void)testSetIntMinimumKeepsTheOtherBounds
{
	XCTAssertNil([self.apiV4 setParameter:kDynamicTestParameter intMinimum:5]);

	[self assertIntWriteMin:5 max:90 sliderMin:20 sliderMax:80];
}

/*! @abstract setParameter:intMaximum: writes the new maximum with the host's other three int bounds. */
- (void)testSetIntMaximumKeepsTheOtherBounds
{
	XCTAssertNil([self.apiV4 setParameter:kDynamicTestParameter intMaximum:95]);

	[self assertIntWriteMin:10 max:95 sliderMin:20 sliderMax:80];
}

/*! @abstract setParameter:intMinimum:maximum: writes both value bounds and keeps the host's slider bounds. */
- (void)testSetIntMinimumAndMaximumKeepsTheSliderBounds
{
	XCTAssertNil([self.apiV4 setParameter:kDynamicTestParameter intMinimum:1 maximum:99]);

	[self assertIntWriteMin:1 max:99 sliderMin:20 sliderMax:80];
}

/*! @abstract setParameter:intSliderMinimum: writes the new slider minimum and keeps the other int bounds. */
- (void)testSetIntSliderMinimumKeepsTheOtherBounds
{
	XCTAssertNil([self.apiV4 setParameter:kDynamicTestParameter intSliderMinimum:25]);

	[self assertIntWriteMin:10 max:90 sliderMin:25 sliderMax:80];
}

/*! @abstract setParameter:intSliderMaximum: writes the new slider maximum and keeps the other int bounds. */
- (void)testSetIntSliderMaximumKeepsTheOtherBounds
{
	XCTAssertNil([self.apiV4 setParameter:kDynamicTestParameter intSliderMaximum:75]);

	[self assertIntWriteMin:10 max:90 sliderMin:20 sliderMax:75];
}

/*! @abstract setParameter:intSliderMinimum:sliderMaximum: writes both slider bounds and keeps the host's value bounds. */
- (void)testSetIntSliderBoundsKeepsTheValueBounds
{
	XCTAssertNil([self.apiV4 setParameter:kDynamicTestParameter intSliderMinimum:30 sliderMaximum:70]);

	[self assertIntWriteMin:10 max:90 sliderMin:30 sliderMax:70];
}

/*! @abstract Every int single-edge setter returns the host's read error and skips the write when the bounds read fails. */
- (void)testIntSettersReturnTheReadErrorAndSkipTheWrite
{
	self.hostAPI.nextError = FxGripDynamicTestError();
	FxGripDynamicParameterAPI_v4 *api = self.apiV4;

	XCTAssertEqualObjects([api setParameter:kDynamicTestParameter intMinimum:0], FxGripDynamicTestError());
	XCTAssertEqualObjects([api setParameter:kDynamicTestParameter intMaximum:0], FxGripDynamicTestError());
	XCTAssertEqualObjects([api setParameter:kDynamicTestParameter intMinimum:0 maximum:1], FxGripDynamicTestError());
	XCTAssertEqualObjects([api setParameter:kDynamicTestParameter intSliderMinimum:0], FxGripDynamicTestError());
	XCTAssertEqualObjects([api setParameter:kDynamicTestParameter intSliderMaximum:0], FxGripDynamicTestError());
	XCTAssertEqualObjects([api setParameter:kDynamicTestParameter intSliderMinimum:0 sliderMaximum:1], FxGripDynamicTestError());

	XCTAssertEqualObjects(self.hostMethods, (@[@"getintbounds", @"getintbounds", @"getintbounds",
											   @"getintbounds", @"getintbounds", @"getintbounds"]));
	XCTAssertEqualObjects(self.posted, @[]);
}

#pragma mark Existence, type, entries, roster

/*! @abstract parameterExists: is YES for an ID in the host roster and NO for one that is absent. */
- (void)testParameterExistsWalksTheHostRoster
{
	self.hostAPI.parameterIDs = @[@1, @(kDynamicTestParameter), @3];
	FxGripDynamicParameterAPI_v4 *api = self.apiV4;

	XCTAssertTrue([api parameterExists:kDynamicTestParameter]);
	XCTAssertFalse([api parameterExists:7]);
}

/*! @abstract parameterExists: is NO on an empty roster and issues only the count call. */
- (void)testParameterExistsIsNoOnAnEmptyRoster
{
	self.hostAPI.parameterIDs = @[];

	XCTAssertFalse([self.apiV4 parameterExists:kDynamicTestParameter]);
	XCTAssertEqualObjects(self.hostMethods, @[@"count"]);
}

/*! @abstract allParameterIDs lists every host ID in index order. */
- (void)testAllParameterIDsListsTheHostRosterInOrder
{
	self.hostAPI.parameterIDs = @[@30, @10, @20];

	XCTAssertEqualObjects([self.apiV4 allParameterIDs], (@[@30, @10, @20]));
}

/*! @abstract allParameterIDs is empty for an empty roster. */
- (void)testAllParameterIDsIsEmptyForAnEmptyRoster
{
	self.hostAPI.parameterIDs = @[];

	XCTAssertEqualObjects([self.apiV4 allParameterIDs], @[]);
}

/*! @abstract parameterType: posts the get-type notification carrying the ID and returns the type an observer writes into the payload. */
- (void)testParameterTypeReturnsTheTypeAnObserverAnswers
{
	__block NSNumber *askedID = nil;
	[self observeName:FxGripNotifyAPI_ParameterGetTypeName usingBlock:^(NSNotification *notification) {
		askedID = notification.userInfo[kFxParameterProperty_Id];
		notification.userInfo.mutableFxParameter[kFxParameterProperty_Type] = @(FxParameterType_Int);
	}];

	XCTAssertEqual([self.apiV4 parameterType:kDynamicTestParameter], FxParameterType_Int);
	XCTAssertEqualObjects(askedID, @(kDynamicTestParameter));
	XCTAssertEqualObjects(self.postedNames, @[FxGripNotifyAPI_ParameterGetTypeName]);
}

/*! @abstract parameterType: is None when no observer answers. */
- (void)testParameterTypeIsNoneWithoutAnObserver
{
	XCTAssertEqual([self.apiV4 parameterType:kDynamicTestParameter], FxParameterType_None);
	XCTAssertEqualObjects(self.hostAPI.calls, @[], @"the type resolves from observers, not the host");
}

/*! @abstract parameter:entries: posts the get-menu notification and fills the entries an observer writes into the payload. */
- (void)testParameterEntriesReturnsTheEntriesAnObserverAnswers
{
	[self observeName:FxGripNotifyAPI_ParameterGetMenuName usingBlock:^(NSNotification *notification) {
		notification.userInfo.mutableFxParameter[kFxParameterProperty_MenuItems] = @[@"One", @"Two"];
	}];
	NSArray<NSString *> *entries = nil;

	XCTAssertNil([self.apiV4 parameter:kDynamicTestParameter entries:&entries]);

	XCTAssertEqualObjects(entries, (@[@"One", @"Two"]));
	NSDictionary *payload = [self notificationNamed:FxGripNotifyAPI_ParameterGetMenuName].userInfo;
	XCTAssertEqualObjects(payload[kFxParameterProperty_Id], @(kDynamicTestParameter));
}

/*! @abstract parameter:entries: fills an empty list and returns nil when no observer answers. */
- (void)testParameterEntriesIsEmptyWithoutAnObserver
{
	NSArray<NSString *> *entries = nil;

	XCTAssertNil([self.apiV4 parameter:kDynamicTestParameter entries:&entries]);

	XCTAssertEqualObjects(entries, @[]);
}

/*! @abstract parameter:entries: returns the error an observer sets on the payload. */
- (void)testParameterEntriesReturnsTheObserverError
{
	[self observeName:FxGripNotifyAPI_ParameterGetMenuName usingBlock:^(NSNotification *notification) {
		((NSMutableDictionary *)notification.userInfo).fxError = FxGripDynamicTestError();
	}];
	NSArray<NSString *> *entries = nil;

	XCTAssertEqualObjects([self.apiV4 parameter:kDynamicTestParameter entries:&entries], FxGripDynamicTestError());
}

#pragma mark Meta without a manager

/*! @abstract The count, dictionary, key-list, and remove-all meta methods answer -1 or a no-meta error when the effect has no meta manager. */
- (void)testMetaDictionaryMethodsAnswerNotFoundWithoutAManager
{
	FxGripDynamicParameterAPI_v4 *api = self.apiV4;

	XCTAssertEqual([api metaCountFromParameter:kDynamicTestParameter], -1);

	NSDictionary *meta = nil;
	[self assertNoMetaError:[api getMeta:&meta fromParameter:kDynamicTestParameter]];
	XCTAssertNil(meta);
	[self assertNoMetaError:[api setMeta:@{@"k": @"v"} toParameter:kDynamicTestParameter]];
	NSArray *keys = nil;
	[self assertNoMetaError:[api getMetaKeys:&keys fromParameter:kDynamicTestParameter]];
	XCTAssertNil(keys);
	[self assertNoMetaError:[api removeAllMeta:kDynamicTestParameter]];
}

/*! @abstract The keyed meta methods answer NO without a meta manager, and hasMetaKey fills the error when asked. */
- (void)testKeyedMetaMethodsAnswerNoWithoutAManager
{
	FxGripDynamicParameterAPI_v4 *api = self.apiV4;

	NSError *error = nil;
	XCTAssertFalse([api parameter:kDynamicTestParameter hasMetaKey:@"k" error:&error]);
	[self assertNoMetaError:error];
	XCTAssertFalse([api parameter:kDynamicTestParameter hasMetaKey:@"k" error:NULL]);

	id<NSSecureCoding, NSCopying> value = nil;
	XCTAssertFalse([api getMeta:&value forKey:@"k" fromParameter:kDynamicTestParameter]);
	XCTAssertNil(value);
	XCTAssertFalse([api setMeta:@"v" forKey:@"k" toParameter:kDynamicTestParameter]);
	XCTAssertFalse([api removeMetaKey:@"k" fromParameter:kDynamicTestParameter]);
}

#pragma mark Meta with a manager

/*! @abstract The keyed meta methods forward to the effect's manager: a set is counted, readable, present, and removable. */
- (void)testKeyedMetaMethodsForwardToTheManager
{
	[self installMetaManager];
	FxGripDynamicParameterAPI_v4 *api = self.apiV4;

	XCTAssertEqual([api metaCountFromParameter:kDynamicTestParameter], 0);
	XCTAssertTrue([api setMeta:@"v" forKey:@"k" toParameter:kDynamicTestParameter]);
	XCTAssertEqual([api metaCountFromParameter:kDynamicTestParameter], 1);

	id<NSSecureCoding, NSCopying> value = nil;
	XCTAssertTrue([api getMeta:&value forKey:@"k" fromParameter:kDynamicTestParameter]);
	XCTAssertEqualObjects((id)value, @"v");

	NSError *error = nil;
	XCTAssertTrue([api parameter:kDynamicTestParameter hasMetaKey:@"k" error:&error]);
	XCTAssertNil(error);
	XCTAssertFalse([api parameter:kDynamicTestParameter hasMetaKey:@"absent" error:&error]);

	XCTAssertTrue([api removeMetaKey:@"k" fromParameter:kDynamicTestParameter]);
	XCTAssertEqual([api metaCountFromParameter:kDynamicTestParameter], 0);
}

/*! @abstract The dictionary meta methods forward to the manager: a set dictionary reads back whole, by key list, and clears with remove-all. */
- (void)testMetaDictionaryMethodsForwardToTheManager
{
	[self installMetaManager];
	FxGripDynamicParameterAPI_v4 *api = self.apiV4;

	XCTAssertNil(([api setMeta:@{@"a": @1, @"b": @2} toParameter:kDynamicTestParameter]));

	NSDictionary *meta = nil;
	XCTAssertNil([api getMeta:&meta fromParameter:kDynamicTestParameter]);
	XCTAssertEqualObjects(meta, (@{@"a": @1, @"b": @2}));

	NSArray *keys = nil;
	XCTAssertNil([api getMetaKeys:&keys fromParameter:kDynamicTestParameter]);
	XCTAssertEqualObjects([keys sortedArrayUsingSelector:@selector(compare:)], (@[@"a", @"b"]));

	XCTAssertNil([api removeAllMeta:kDynamicTestParameter]);
	XCTAssertEqual([api metaCountFromParameter:kDynamicTestParameter], 0);
}

/*! @abstract The wrapper resolves the meta manager once: a manager installed after the first query stays unseen by that wrapper. */
- (void)testTheWrapperCachesTheMetaResolution
{
	FxGripDynamicParameterAPI_v4 *api = self.apiV4;
	XCTAssertEqual([api metaCountFromParameter:kDynamicTestParameter], -1);

	[self installMetaManager];

	XCTAssertEqual([api metaCountFromParameter:kDynamicTestParameter], -1);
	XCTAssertEqual([self.apiV4 metaCountFromParameter:kDynamicTestParameter], 0, @"a new wrapper resolves afresh");
}

@end
