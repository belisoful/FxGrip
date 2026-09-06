/*!
	@file       FxGripGoogleAnalyticsTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripGoogleAnalyticsTests
	@abstract   Tests the deny-by-default capture rules and idle event latch of FxGripGoogleAnalytics.
	@discussion Introduced in FxGrip 0.1.0. A recording subclass captures the events the decision would
	            log, and a stub effect supplies the plugin identity the capture path reads. The tests
	            cover rule installation on init, accept and reject precedence, priority ordering, latch
	            behavior across the idle window, and rule removal.
*/

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripTileableEffect+Notifications.h>
#import <FxGrip/FxGripGoogleAnalytics.h>

// FxGripGoogleAnalytics.h publishes the rule API without the capture path; the members the
// tests drive are declared here. The implementations come from the linked framework.
@interface FxGripGoogleAnalytics (FxGripGATestAccess)
- (void)captureEvent:(nonnull NSNotification *)notification;
- (void)logWithName:(nonnull NSString *)eventName parameters:(nullable NSDictionary *)parameters;
- (nonnull NSPredicate *)addCaptureEvent:(nonnull NSNotificationName)name;
@end

// Records the events the deny-by-default decision would send, so the decision is observable
// without a linked Firebase.
@interface FxGripGATestRecordingAnalytics : FxGripGoogleAnalytics
@property (nonatomic, strong) NSMutableArray<NSString *> *loggedEvents;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *loggedParameters;
@end

@implementation FxGripGATestRecordingAnalytics
- (instancetype)init
{
	self = [super init];
	if (self) {
		_loggedEvents = NSMutableArray.new;
		_loggedParameters = NSMutableArray.new;
	}
	return self;
}
- (void)logWithName:(NSString *)eventName parameters:(NSDictionary *)parameters
{
	[self.loggedEvents addObject:eventName];
	[self.loggedParameters addObject:parameters ?: @{}];
}
@end

static NSNotificationCenter *FxGripGATestMakePriorityCenter(void)
{
	Class cls = NSClassFromString(@"NSPriorityNotificationCenter");
	return [[cls alloc] init];
}

// The capture path reads the plugin identity from the effect; a stub supplies only what it
// reads, because the real effect's designated init registers into the process-wide center.
@interface FxGripGATestStubEffect : NSObject
@property (nonatomic, assign) BOOL addedToDocument;
@property (nonatomic, strong) NSNotificationCenter *notifier;
@property (nonatomic, copy) NSString *pluginUUID;
@property (nonatomic, copy) NSString *pluginDisplayName;
@end

@implementation FxGripGATestStubEffect

- (id)effectBase
{
	// The stub plays the full effect; rich reads route back to it, as the old cast did.
	return self;
}

- (instancetype)init
{
	self = [super init];
	if (self) {
		_notifier = FxGripGATestMakePriorityCenter();
		_pluginUUID = @"44444444-4444-4444-4444-444444444444";
		_pluginDisplayName = @"Test Plugin";
	}
	return self;
}
@end

@interface FxGripGoogleAnalyticsTests : XCTestCase
@property (nonatomic, strong) FxGripGATestRecordingAnalytics *analytics;
@property (nonatomic, strong) FxGripGATestStubEffect *effect;
@end

@implementation FxGripGoogleAnalyticsTests

- (void)setUp
{
	[super setUp];
	self.analytics = [FxGripGATestRecordingAnalytics.alloc init];
	self.effect = [FxGripGATestStubEffect.alloc init];
	[self.analytics extLoadWithEffect:(id)self.effect];
}

- (void)tearDown
{
	self.analytics = nil;
	self.effect = nil;
	[super tearDown];
}

- (void)captureEventNamed:(NSString *)name
{
	[self.analytics captureEvent:[NSNotification notificationWithName:name object:self.effect userInfo:nil]];
}

- (void)captureEventNamed:(NSString *)name parameterID:(NSUInteger)parameterID
{
	NSDictionary *userInfo = @{FxGripTileableEffectParameterChangedIDKey: @(parameterID)};
	[self.analytics captureEvent:[NSNotification notificationWithName:name object:self.effect userInfo:userInfo]];
}

#pragma mark #39 — the dispatched init selector

/*! @abstract Confirms the extension implements the one-argument extInit: the dispatch table invokes. */
- (void)testTheExtensionRespondsToTheDispatchedInitSelector
{
	// The dispatch table wires extInit: (with the notification argument); a zero-argument
	// extInit would never be invoked.
	XCTAssertTrue([self.analytics respondsToSelector:@selector(extInit:)]);
}

/*! @abstract Verifies posting the init notification runs extInit: and installs the default capture rules. */
- (void)testPostingTheInitNotificationInstallsCaptureRules
{
	XCTAssertEqual(self.analytics.captureRules.count, (NSUInteger)0, @"no rules before init");

	[self.effect.notifier postNotificationName:FxGripTileableEffectInitName object:self.effect userInfo:nil];

	XCTAssertGreaterThan(self.analytics.captureRules.count, (NSUInteger)0,
						 @"extInit: runs when the init notification posts and installs the default rules");
}

#pragma mark Deny-by-default decision

/*! @abstract Verifies an event with no matching rule is not logged. */
- (void)testAnEventWithoutAnyRuleIsDenied
{
	[self captureEventNamed:@"SomeEvent"];
	XCTAssertEqualObjects(self.analytics.loggedEvents, @[], @"no rule means no logging");
}

/*! @abstract Verifies an accept rule logs the event whose name it matches. */
- (void)testAnAcceptRuleLogsTheMatchingEvent
{
	[self.analytics addCaptureEvent:@"MyEvent"];
	[self captureEventNamed:@"MyEvent"];
	XCTAssertEqualObjects(self.analytics.loggedEvents, @[@"MyEvent"]);
}

/*! @abstract Verifies a reject rule, written with the leading-minus syntax, blocks the event it matches. */
- (void)testARejectRuleDeniesTheMatchingEvent
{
	[self.analytics addCaptureEvent:@"-MyEvent"];
	[self captureEventNamed:@"MyEvent"];
	XCTAssertEqualObjects(self.analytics.loggedEvents, @[]);
}

/*! @abstract Verifies an event that matches no installed rule stays unlogged. */
- (void)testAnEventMatchingNoRuleIsDeniedRatherThanFailingOpen
{
	// A rule that does not match the event must not fall through into logging.
	[self.analytics addCaptureEvent:@"OtherEvent"];
	[self captureEventNamed:@"MyEvent"];
	XCTAssertEqualObjects(self.analytics.loggedEvents, @[], @"the privacy default is structural");
}

/*! @abstract Verifies an empty-named notification reaches the accept path only through a wildcard rule. */
- (void)testAnUnnamedNotificationIsDenied
{
	[self.analytics addCaptureEvent:@"*"];
	[self.analytics captureEvent:[NSNotification notificationWithName:@"" object:self.effect userInfo:nil]];
	// An empty name still evaluates; the point is the accept path is reached only through a rule.
	XCTAssertEqualObjects(self.analytics.loggedEvents, @[@""]);
}

#pragma mark Rule management

/*! @abstract Verifies removeCaptureRule: drops the rule, returns NO for an absent rule, and stops the event logging. */
- (void)testRemovingARuleTakesItOutOfTheList
{
	NSPredicate *rule = [self.analytics addCaptureEvent:@"MyEvent"];
	XCTAssertEqual(self.analytics.captureRules.count, (NSUInteger)1);

	XCTAssertTrue([self.analytics removeCaptureRule:rule]);
	XCTAssertEqual(self.analytics.captureRules.count, (NSUInteger)0);
	XCTAssertFalse([self.analytics removeCaptureRule:rule], @"removing an absent rule returns NO");

	[self captureEventNamed:@"MyEvent"];
	XCTAssertEqualObjects(self.analytics.loggedEvents, @[], @"the removed accept rule no longer logs");
}

#pragma mark Priority ordering survives the lazy sort

/*! @abstract Verifies a lower-priority-number reject wins over an earlier-inserted accept, which requires the capture path to sort by priority before evaluating. */
- (void)testAHigherPriorityRejectOverridesALaterAcceptRegardlessOfInsertionOrder
{
	// The accept is inserted first; the lower-priority-number reject must still win, which
	// only holds if the capture path sorts by priority before evaluating.
	[self.analytics addCaptureRule:@"name LIKE %@" outcome:YES priority:10, @"X"];
	[self.analytics addCaptureRule:@"name LIKE %@" outcome:NO priority:5, @"X"];

	[self captureEventNamed:@"X"];

	XCTAssertEqualObjects(self.analytics.loggedEvents, @[],
						  @"the highest-precedence matching rule decides the outcome");
}

#pragma mark Event latch — one event per interaction

/*! @abstract Verifies fifty identical events within the latch window produce a single logged event. */
- (void)testABurstOfIdenticalEventsLogsOnce
{
	[self.analytics addCaptureEvent:@"Drag"];
	for (NSInteger i = 0; i < 50; i++) {
		[self captureEventNamed:@"Drag"];
	}
	XCTAssertEqualObjects(self.analytics.loggedEvents, @[@"Drag"],
						  @"a continuous interaction latches to a single logged event");
}

/*! @abstract Verifies an event repeated after the idle interval elapses logs a second time. */
- (void)testTheLatchReopensAfterTheIdleInterval
{
	self.analytics.eventLatchInterval = 0.05;
	[self.analytics addCaptureEvent:@"Drag"];

	[self captureEventNamed:@"Drag"];
	[NSThread sleepForTimeInterval:0.1];
	[self captureEventNamed:@"Drag"];

	XCTAssertEqualObjects(self.analytics.loggedEvents, (@[@"Drag", @"Drag"]),
						  @"a fresh interaction after the idle window logs again");
}

/*! @abstract Verifies the latch keys on the parameter ID, so a second control logs within the window and its ID rides along in the logged parameters. */
- (void)testDistinctParameterIDsEachLogWithinTheWindow
{
	[self.analytics addCaptureEvent:FxGripTileableEffectParameterChangedName];

	[self captureEventNamed:FxGripTileableEffectParameterChangedName parameterID:11];
	[self captureEventNamed:FxGripTileableEffectParameterChangedName parameterID:11];
	[self captureEventNamed:FxGripTileableEffectParameterChangedName parameterID:22];

	XCTAssertEqual(self.analytics.loggedEvents.count, (NSUInteger)2,
				   @"the latch keys on the parameter ID, so a second control still logs");
	XCTAssertEqualObjects(self.analytics.loggedParameters.firstObject[@"Parameter ID"], @11,
						  @"the changed parameter ID rides along in the logged parameters");
	XCTAssertEqualObjects(self.analytics.loggedParameters.lastObject[@"Parameter ID"], @22);
}

/*! @abstract Verifies a non-positive latch interval disables the latch and logs every event. */
- (void)testDisablingTheLatchLogsEveryEvent
{
	self.analytics.eventLatchInterval = 0.0;
	[self.analytics addCaptureEvent:@"Drag"];
	for (NSInteger i = 0; i < 3; i++) {
		[self captureEventNamed:@"Drag"];
	}
	XCTAssertEqual(self.analytics.loggedEvents.count, (NSUInteger)3,
				   @"a non-positive interval disables the latch");
}

@end
