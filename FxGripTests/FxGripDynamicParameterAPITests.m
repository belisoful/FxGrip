//
//  FxGripDynamicParameterAPITests.m
//  FxGripTests
//
//  Unit tests for the dynamic parameter wrappers. FxGripDynamicParameterAPI_v3 forwards
//  the host's dynamic API and posts a notification for each mutation it completes.
//  FxGripParameterInfoAPI_v1 adds parameter existence and type queries, the ID
//  enumeration, and menu entries; FxGripParameterBoundsAPI_v1 adds the single-bound
//  convenience setters built on the v3 bounds pair.
//

#import <XCTest/XCTest.h>
#import <FxPlug/FxPlugSDK.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripAPINotifications.h>
#import <FxGrip/FxGripDynamicParameterAPI_v3.h>
#import <FxGrip/FxGripParameterInfoAPI_v1.h>
#import <FxGrip/FxGripParameterBoundsAPI_v1.h>

static const FxParameterId kDynamicTestParameter = 41;

// The test target links only FxGrip and XCTest, so NSPriorityNotificationCenter
// (from BEFoundation) is resolved at runtime by name to avoid an unlinked symbol.
static NSNotificationCenter *FxGripDynamicTestMakePriorityCenter(void)
{
	Class cls = NSClassFromString(@"NSPriorityNotificationCenter");
	return [[cls alloc] init];
}

// CoreMedia is not linked, so CMTime values are built without its symbols.
static CMTime FxGripDynamicTestTime(void)
{
	return (CMTime){.value = 4, .timescale = 25, .flags = kCMTimeFlags_Valid, .epoch = 0};
}

static NSError *FxGripDynamicTestError(void)
{
	return [NSError errorWithDomain:@"FxGripDynamicTest" code:7 userInfo:nil];
}

#pragma mark - Test doubles

/*! Stands in for the host's FxDynamicParameterAPI_v3, recording every forwarded call. */
@interface FxGripDynamicTestStubAPI : NSObject
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *calls;
@property (nonatomic, strong) NSError *nextError;
@property (nonatomic, copy) NSString *hostName;
@property (nonatomic, strong) NSArray<NSNumber *> *parameterIDs;
@property (nonatomic, assign) double floatMinimum;
@property (nonatomic, assign) double floatMaximum;
@property (nonatomic, assign) double floatSliderMinimum;
@property (nonatomic, assign) double floatSliderMaximum;
@property (nonatomic, assign) int intMinimum;
@property (nonatomic, assign) int intMaximum;
@property (nonatomic, assign) int intSliderMinimum;
@property (nonatomic, assign) int intSliderMaximum;
@property (nonatomic, assign) BOOL defaultsSucceed;
@property (nonatomic, assign) CMTime lastDefaultsTime;
@end

@implementation FxGripDynamicTestStubAPI

- (instancetype)init
{
	self = [super init];
	if (self) {
		_calls = NSMutableArray.new;
		_parameterIDs = @[];
		_defaultsSucceed = YES;
	}
	return self;
}

- (NSError *)record:(NSString *)method arguments:(NSDictionary *)arguments
{
	NSMutableDictionary *call = arguments.mutableCopy;
	call[@"method"] = method;
	[self.calls addObject:call.copy];
	return self.nextError;
}

- (UInt32)parameterCount
{
	[self record:@"count" arguments:@{}];
	return (UInt32)self.parameterIDs.count;
}

- (UInt32)parameterIDAtIndex:(UInt32)index
{
	[self record:@"idatindex" arguments:@{@"index": @(index)}];
	return self.parameterIDs[index].unsignedIntValue;
}

- (NSError *)removeParameter:(UInt32)parameterID
{
	return [self record:@"remove" arguments:@{@"id": @(parameterID)}];
}

- (NSError *)parameter:(UInt32)parameterID name:(NSString **)parameterName
{
	NSError *error = [self record:@"getname" arguments:@{@"id": @(parameterID)}];
	if (!error && parameterName) {
		*parameterName = self.hostName;
	}
	return error;
}

- (NSError *)setParameter:(UInt32)parameterID name:(NSString *)newName
{
	return [self record:@"setname" arguments:@{@"id": @(parameterID), @"name": newName ?: NSNull.null}];
}

- (NSError *)parameter:(UInt32)parameterID
		  floatMinimum:(double *)min
			   maximum:(double *)max
		 sliderMinimum:(double *)sliderMin
		 sliderMaximum:(double *)sliderMax
{
	NSError *error = [self record:@"getfloatbounds" arguments:@{@"id": @(parameterID)}];
	if (error) {
		return error;
	}
	*min = self.floatMinimum;
	*max = self.floatMaximum;
	*sliderMin = self.floatSliderMinimum;
	*sliderMax = self.floatSliderMaximum;
	return nil;
}

- (NSError *)setParameter:(UInt32)parameterID
			 floatMinimum:(double)min
				  maximum:(double)max
			sliderMinimum:(double)sliderMin
			sliderMaximum:(double)sliderMax
{
	return [self record:@"setfloatbounds" arguments:@{@"id": @(parameterID),
													  @"min": @(min),
													  @"max": @(max),
													  @"slidermin": @(sliderMin),
													  @"slidermax": @(sliderMax)}];
}

- (NSError *)parameter:(UInt32)parameterID
			intMinimum:(int *)min
			   maximum:(int *)max
		 sliderMinimum:(int *)sliderMin
		 sliderMaximum:(int *)sliderMax
{
	NSError *error = [self record:@"getintbounds" arguments:@{@"id": @(parameterID)}];
	if (error) {
		return error;
	}
	*min = self.intMinimum;
	*max = self.intMaximum;
	*sliderMin = self.intSliderMinimum;
	*sliderMax = self.intSliderMaximum;
	return nil;
}

- (NSError *)setParameter:(UInt32)parameterID
			   intMinimum:(int)min
				  maximum:(int)max
			sliderMinimum:(int)sliderMin
			sliderMaximum:(int)sliderMax
{
	return [self record:@"setintbounds" arguments:@{@"id": @(parameterID),
													@"min": @(min),
													@"max": @(max),
													@"slidermin": @(sliderMin),
													@"slidermax": @(sliderMax)}];
}

- (NSError *)setPopupMenuParameter:(UInt32)parameterID
						   entries:(NSArray<NSString *> *)newEntries
					  defaultValue:(UInt32)defaultIndex
{
	return [self record:@"setmenu" arguments:@{@"id": @(parameterID),
											   @"items": newEntries ?: NSNull.null,
											   @"default": @(defaultIndex)}];
}

- (BOOL)setAsDefaultsAtTime:(CMTime)time withError:(NSError **)error
{
	self.lastDefaultsTime = time;
	[self record:@"setdefaults" arguments:@{}];
	if (!self.defaultsSucceed && error) {
		*error = FxGripDynamicTestError();
	}
	return self.defaultsSucceed;
}

@end

/*!
	FxGripTileableEffect's designated initializer registers into the process-wide
	notification center, so the wrappers are exercised against a stub carrying an isolated
	notifier. The name and menu setters also subscript the effect for the object they post
	against; the stub reports no parameter object.
*/
@interface FxGripDynamicTestStubEffect : NSObject
@property (nonatomic, strong) NSNotificationCenter *notifier;
@property (nonatomic, assign) BOOL hasMeta;
@end

@implementation FxGripDynamicTestStubEffect

- (id)effectBase
{
	// The stub plays the full effect; rich reads route back to it, as the old cast did.
	return self;
}


- (instancetype)init
{
	self = [super init];
	if (self) {
		_notifier = FxGripDynamicTestMakePriorityCenter();
	}
	return self;
}

- (id)objectAtIndexedSubscript:(NSInteger)index
{
	return nil;
}

@end

#pragma mark - Tests

@interface FxGripDynamicParameterAPITests : XCTestCase
@property (nonatomic, strong) FxGripDynamicTestStubEffect *effect;
@property (nonatomic, strong) FxGripDynamicTestStubAPI *hostAPI;
@property (nonatomic, strong) NSMutableArray<NSNotification *> *posted;
// The notifier holds its observers weakly, so every token is retained for the test.
@property (nonatomic, strong) NSMutableArray *observerTokens;
@end

@implementation FxGripDynamicParameterAPITests

- (void)setUp
{
	[super setUp];
	self.effect = [FxGripDynamicTestStubEffect.alloc init];
	self.hostAPI = [FxGripDynamicTestStubAPI.alloc init];
	self.posted = NSMutableArray.new;
	self.observerTokens = NSMutableArray.new;
	for (NSNotificationName name in self.recordedNotificationNames) {
		[self observeName:name usingBlock:^(NSNotification *notification) {
			[self.posted addObject:notification];
		}];
	}
}

- (void)tearDown
{
	for (id token in self.observerTokens) {
		[self.effect.notifier removeObserver:token];
	}
	self.observerTokens = nil;
	self.posted = nil;
	self.hostAPI = nil;
	self.effect = nil;
	[super tearDown];
}

#pragma mark Helpers

- (NSArray<NSNotificationName> *)recordedNotificationNames
{
	return @[FxGripNotifyAPI_ParameterRemoveName,
			 FxGripNotifyAPI_ParameterGetNameName,
			 FxGripNotifyAPI_ParameterSetNamePreName,
			 FxGripNotifyAPI_ParameterSetNameName,
			 FxGripNotifyAPI_ParameterGetTypeName,
			 FxGripNotifyAPI_ParameterSetFloatBoundsName,
			 FxGripNotifyAPI_ParameterSetIntBoundsName,
			 FxGripNotifyAPI_ParameterGetMenuName,
			 FxGripNotifyAPI_ParameterSetMenuPreName,
			 FxGripNotifyAPI_ParameterSetMenuName];
}

- (void)observeName:(NSNotificationName)name usingBlock:(void (^)(NSNotification *notification))block
{
	id token = [self.effect.notifier addObserverForName:name object:nil queue:nil usingBlock:block];
	[self.observerTokens addObject:token];
}

- (NSArray<NSNotificationName> *)postedNames
{
	NSMutableArray<NSNotificationName> *names = NSMutableArray.new;
	for (NSNotification *notification in self.posted) {
		[names addObject:notification.name];
	}
	return names;
}

- (NSNotification *)notificationNamed:(NSNotificationName)name
{
	for (NSNotification *notification in self.posted) {
		if ([notification.name isEqualToString:name]) {
			return notification;
		}
	}
	return nil;
}

- (NSArray<NSString *> *)hostMethods
{
	NSMutableArray<NSString *> *methods = NSMutableArray.new;
	for (NSDictionary *call in self.hostAPI.calls) {
		[methods addObject:call[@"method"]];
	}
	return methods;
}

- (NSDictionary *)hostCallNamed:(NSString *)method
{
	for (NSDictionary *call in self.hostAPI.calls) {
		if ([call[@"method"] isEqualToString:method]) {
			return call;
		}
	}
	return nil;
}

- (FxGripDynamicParameterAPI_v3 *)apiV3
{
	return [FxGripDynamicParameterAPI_v3.alloc initWithAPI:(id)self.hostAPI effect:(id)self.effect];
}

- (FxGripParameterInfoAPI_v1 *)apiInfo
{
	return [FxGripParameterInfoAPI_v1.alloc initWithAPI:(id)self.hostAPI effect:(id)self.effect];
}

- (FxGripParameterBoundsAPI_v1 *)apiBounds
{
	return [FxGripParameterBoundsAPI_v1.alloc initWithAPI:(id)self.hostAPI effect:(id)self.effect];
}

#pragma mark v3 pass-through

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

#pragma mark v3 removeParameter:

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

#pragma mark v3 parameter:name:

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

#pragma mark v3 setParameter:name:

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

#pragma mark v3 bounds

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

#pragma mark v3 setPopupMenuParameter:

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

#pragma mark v4 parameterExists: and allParameterIDs

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

#pragma mark v4 parameterType:

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

#pragma mark v4 parameter:entries:

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

#pragma mark v4 single-bound float setters

- (void)testSettingOnlyTheFloatMinimumKeepsTheOtherBounds
{
	self.hostAPI.floatMinimum = -1;
	self.hostAPI.floatMaximum = 1;
	self.hostAPI.floatSliderMinimum = -0.5;
	self.hostAPI.floatSliderMaximum = 0.5;

	XCTAssertNil([self.apiBounds setParameter:kDynamicTestParameter floatMinimum:-3]);

	XCTAssertEqualObjects([self hostCallNamed:@"setfloatbounds"], (@{@"method": @"setfloatbounds",
																	@"id": @(kDynamicTestParameter),
																	@"min": @(-3.0),
																	@"max": @1.0,
																	@"slidermin": @(-0.5),
																	@"slidermax": @0.5}));
}

- (void)testSettingOnlyTheFloatMaximumKeepsTheOtherBounds
{
	self.hostAPI.floatMinimum = -1;
	self.hostAPI.floatMaximum = 1;

	XCTAssertNil([self.apiBounds setParameter:kDynamicTestParameter floatMaximum:5]);

	XCTAssertEqualObjects([self hostCallNamed:@"setfloatbounds"][@"min"], @(-1.0));
	XCTAssertEqualObjects([self hostCallNamed:@"setfloatbounds"][@"max"], @5.0);
}

- (void)testSettingTheFloatMinimumAndMaximumKeepsTheSliderBounds
{
	self.hostAPI.floatSliderMinimum = -0.5;
	self.hostAPI.floatSliderMaximum = 0.5;

	XCTAssertNil([self.apiBounds setParameter:kDynamicTestParameter floatMinimum:-2 maximum:2]);

	NSDictionary *call = [self hostCallNamed:@"setfloatbounds"];
	XCTAssertEqualObjects(call[@"min"], @(-2.0));
	XCTAssertEqualObjects(call[@"max"], @2.0);
	XCTAssertEqualObjects(call[@"slidermin"], @(-0.5));
	XCTAssertEqualObjects(call[@"slidermax"], @0.5);
}

- (void)testSettingTheFloatSliderBoundsKeepsTheParameterBounds
{
	self.hostAPI.floatMinimum = -10;
	self.hostAPI.floatMaximum = 10;

	XCTAssertNil([self.apiBounds setParameter:kDynamicTestParameter floatSliderMinimum:-1]);
	XCTAssertNil([self.apiBounds setParameter:kDynamicTestParameter floatSliderMaximum:1]);
	XCTAssertNil([self.apiBounds setParameter:kDynamicTestParameter floatSliderMinimum:-2 sliderMaximum:2]);

	NSDictionary *last = self.hostAPI.calls.lastObject;
	XCTAssertEqualObjects(last[@"min"], @(-10.0));
	XCTAssertEqualObjects(last[@"max"], @10.0);
	XCTAssertEqualObjects(last[@"slidermin"], @(-2.0));
	XCTAssertEqualObjects(last[@"slidermax"], @2.0);
}

- (void)testAFailedBoundsReadSkipsTheBoundsWrite
{
	self.hostAPI.nextError = FxGripDynamicTestError();

	XCTAssertEqualObjects([self.apiBounds setParameter:kDynamicTestParameter floatMinimum:-3],
						  FxGripDynamicTestError());

	XCTAssertEqualObjects(self.hostMethods, @[@"getfloatbounds"]);
}

#pragma mark v4 single-bound int setters

- (void)testSettingOnlyTheIntMinimumKeepsTheOtherBounds
{
	self.hostAPI.intMinimum = 1;
	self.hostAPI.intMaximum = 100;
	self.hostAPI.intSliderMinimum = 2;
	self.hostAPI.intSliderMaximum = 50;

	XCTAssertNil([self.apiBounds setParameter:kDynamicTestParameter intMinimum:0]);

	XCTAssertEqualObjects([self hostCallNamed:@"setintbounds"], (@{@"method": @"setintbounds",
																   @"id": @(kDynamicTestParameter),
																   @"min": @0,
																   @"max": @100,
																   @"slidermin": @2,
																   @"slidermax": @50}));
}

- (void)testSettingOnlyTheIntMaximumKeepsTheOtherBounds
{
	self.hostAPI.intMinimum = 1;
	self.hostAPI.intMaximum = 100;

	XCTAssertNil([self.apiBounds setParameter:kDynamicTestParameter intMaximum:7]);

	XCTAssertEqualObjects([self hostCallNamed:@"setintbounds"][@"min"], @1);
	XCTAssertEqualObjects([self hostCallNamed:@"setintbounds"][@"max"], @7);
}

- (void)testSettingTheIntMinimumAndMaximumKeepsTheSliderBounds
{
	self.hostAPI.intSliderMinimum = 3;
	self.hostAPI.intSliderMaximum = 30;

	XCTAssertNil([self.apiBounds setParameter:kDynamicTestParameter intMinimum:0 maximum:9]);

	NSDictionary *call = [self hostCallNamed:@"setintbounds"];
	XCTAssertEqualObjects(call[@"min"], @0);
	XCTAssertEqualObjects(call[@"max"], @9);
	XCTAssertEqualObjects(call[@"slidermin"], @3);
	XCTAssertEqualObjects(call[@"slidermax"], @30);
}

- (void)testSettingTheIntSliderBoundsKeepsTheParameterBounds
{
	self.hostAPI.intMinimum = -100;
	self.hostAPI.intMaximum = 100;

	XCTAssertNil([self.apiBounds setParameter:kDynamicTestParameter intSliderMinimum:-1]);
	XCTAssertNil([self.apiBounds setParameter:kDynamicTestParameter intSliderMaximum:1]);
	XCTAssertNil([self.apiBounds setParameter:kDynamicTestParameter intSliderMinimum:-2 sliderMaximum:2]);

	NSDictionary *last = self.hostAPI.calls.lastObject;
	XCTAssertEqualObjects(last[@"min"], @(-100));
	XCTAssertEqualObjects(last[@"max"], @100);
	XCTAssertEqualObjects(last[@"slidermin"], @(-2));
	XCTAssertEqualObjects(last[@"slidermax"], @2);
}

- (void)testAFailedIntBoundsReadSkipsTheBoundsWrite
{
	self.hostAPI.nextError = FxGripDynamicTestError();

	XCTAssertEqualObjects([self.apiBounds setParameter:kDynamicTestParameter intMinimum:0],
						  FxGripDynamicTestError());

	XCTAssertEqualObjects(self.hostMethods, @[@"getintbounds"]);
}

@end
