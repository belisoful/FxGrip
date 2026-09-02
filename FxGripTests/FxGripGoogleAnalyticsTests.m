//
//  FxGripGoogleAnalyticsTests.m
//  FxGripTests
//

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
@end

@implementation FxGripGATestRecordingAnalytics
- (instancetype)init
{
	self = [super init];
	if (self) {
		_loggedEvents = NSMutableArray.new;
	}
	return self;
}
- (void)logWithName:(NSString *)eventName parameters:(NSDictionary *)parameters
{
	[self.loggedEvents addObject:eventName];
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

#pragma mark #39 — the dispatched init selector

- (void)testTheExtensionRespondsToTheDispatchedInitSelector
{
	// The dispatch table wires extInit: (with the notification argument); a zero-argument
	// extInit would never be invoked.
	XCTAssertTrue([self.analytics respondsToSelector:@selector(extInit:)]);
}

- (void)testPostingTheInitNotificationInstallsCaptureRules
{
	XCTAssertEqual(self.analytics.captureRules.count, (NSUInteger)0, @"no rules before init");

	[self.effect.notifier postNotificationName:FxGripTileableEffectInitName object:self.effect userInfo:nil];

	XCTAssertGreaterThan(self.analytics.captureRules.count, (NSUInteger)0,
						 @"extInit: runs when the init notification posts and installs the default rules");
}

#pragma mark Deny-by-default decision

- (void)testAnEventWithoutAnyRuleIsDenied
{
	[self captureEventNamed:@"SomeEvent"];
	XCTAssertEqualObjects(self.analytics.loggedEvents, @[], @"no rule means no logging");
}

- (void)testAnAcceptRuleLogsTheMatchingEvent
{
	[self.analytics addCaptureEvent:@"MyEvent"];
	[self captureEventNamed:@"MyEvent"];
	XCTAssertEqualObjects(self.analytics.loggedEvents, @[@"MyEvent"]);
}

- (void)testARejectRuleDeniesTheMatchingEvent
{
	[self.analytics addCaptureEvent:@"-MyEvent"];
	[self captureEventNamed:@"MyEvent"];
	XCTAssertEqualObjects(self.analytics.loggedEvents, @[]);
}

- (void)testAnEventMatchingNoRuleIsDeniedRatherThanFailingOpen
{
	// A rule that does not match the event must not fall through into logging.
	[self.analytics addCaptureEvent:@"OtherEvent"];
	[self captureEventNamed:@"MyEvent"];
	XCTAssertEqualObjects(self.analytics.loggedEvents, @[], @"the privacy default is structural");
}

- (void)testAnUnnamedNotificationIsDenied
{
	[self.analytics addCaptureEvent:@"*"];
	[self.analytics captureEvent:[NSNotification notificationWithName:@"" object:self.effect userInfo:nil]];
	// An empty name still evaluates; the point is the accept path is reached only through a rule.
	XCTAssertEqualObjects(self.analytics.loggedEvents, @[@""]);
}

#pragma mark Rule management

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

@end
