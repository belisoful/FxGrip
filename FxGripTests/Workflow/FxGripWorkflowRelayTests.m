/*!
	@file       FxGripWorkflowRelayTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripWorkflowRelayTests
	@abstract   Tests the workflow relay extension over a temporary mailbox and a stub effect.
	@discussion Introduced in FxGrip 0.1.0. A stub effect answers the identity, timing, and out-of-band
	            members the relay reads, and a spy FCPXML API records each apply. The tests cover the
	            plugin-property gate and settings, registration, the status pipeline, inbox processing
	            with broadcast and addressed messages, the document handler veto, publishing, and
	            the record removal on dealloc.
*/

#import <XCTest/XCTest.h>
#import <CoreMedia/CoreMedia.h>
#import <AVFoundation/AVTime.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripExtension.h>
#import <FxGrip/FxGripWorkflowRelay.h>
#import <FxGrip/FxGripFCPXMLStoryElement.h>
#import <FxGrip/FxGripErrors.h>

static NSString *const kRelayTestPlugin = @"BBBBBBBB-1111-2222-3333-444444444444";

#pragma mark - Doubles

@interface FxGripRelayTestAccessor : NSObject
@property (nonatomic, assign) CMTime currentTime;
@property (nonatomic, assign) BOOL active;
@end
@implementation FxGripRelayTestAccessor
@end

/*! Records each apply and capture instead of touching parameters. */
@interface FxGripRelayTestFCPXMLAPI : NSObject
@property (nonatomic, strong) NSMutableArray<FxGripFCPXMLDocument *> *applied;
@property (nonatomic, strong) NSMutableArray<NSValue *> *applyTimes;
@property (nonatomic, assign) FxGripFCPXMLApplyOptions lastOptions;
@property (nonatomic, strong) NSError *applyError;
@property (nonatomic, assign) NSUInteger captureCount;
@end
@implementation FxGripRelayTestFCPXMLAPI
- (instancetype)init { self = [super init]; if (self) { _applied = NSMutableArray.new; _applyTimes = NSMutableArray.new; } return self; }
- (NSError *)applyDocument:(FxGripFCPXMLDocument *)document atTime:(CMTime)time options:(FxGripFCPXMLApplyOptions)options
{
	[self.applied addObject:document];
	[self.applyTimes addObject:[NSValue valueWithCMTime:time]];
	self.lastOptions = options;
	return self.applyError;
}
- (NSError *)captureDocument:(FxGripFCPXMLDocument **)document atTime:(CMTime)time options:(FxGripFCPXMLCaptureOptions)options
{
	self.captureCount += 1;
	FxGripFCPXMLDocument *captured = [[FxGripFCPXMLDocument alloc] init];
	[captured.resources effectForFxPlugUUID:kRelayTestPlugin name:@"Grip"];
	*document = captured;
	return nil;
}
@end

@interface FxGripRelayTestAPIManager : NSObject
@property (nonatomic, strong) FxGripRelayTestFCPXMLAPI *fcpxmlAPIv1;
@end
@implementation FxGripRelayTestAPIManager
@end

@interface FxGripRelayTestEffect : NSObject
@property (nonatomic, strong) NSDictionary<NSString *, id> *pluginProperties;
@property (nonatomic, strong) FxGripRelayTestAPIManager *apiManager;
@property (nonatomic, copy) NSString *pluginUUID;
@property (nonatomic, assign) UInt64 sessionID;
@property (nonatomic, copy) NSString *pluginDisplayName;
@property (nonatomic, copy) NSString *pluginStringVersion;
@property (nonatomic, assign) NSUInteger projectDocumentID;
@property (nonatomic, assign) CMTime effectInPointOfTimeLine;
@property (nonatomic, assign) CMTime effectOutPointOfTimeLine;
@property (nonatomic, strong) FxGripRelayTestAccessor *accessor;
@property (nonatomic, assign) NSUInteger contextCount;
@end
@implementation FxGripRelayTestEffect {
	NSNotificationCenter *_notifier;
}
- (instancetype)init
{
	self = [super init];
	if (self) {
		_notifier = [[NSClassFromString(@"NSPriorityNotificationCenter") alloc] init];
		_pluginUUID = kRelayTestPlugin;
		_sessionID = 11;
		_pluginDisplayName = @"Grip";
		_pluginStringVersion = @"1.2";
		_projectDocumentID = 5;
		_effectInPointOfTimeLine = CMTimeMake(1, 1);
		_effectOutPointOfTimeLine = CMTimeMake(3, 1);
		_accessor = [[FxGripRelayTestAccessor alloc] init];
		_accessor.currentTime = CMTimeMake(2, 1);
		_apiManager = [[FxGripRelayTestAPIManager alloc] init];
		_apiManager.fcpxmlAPIv1 = [[FxGripRelayTestFCPXMLAPI alloc] init];
		_pluginProperties = @{
			kProPlugPlugIn_UuidProperty: kRelayTestPlugin,
			kProPlugPlugIn_ClassNameProperty: @"Grip",
			kProPlugPlugIn_GroupUUIDProperty: @"GROUP",
			kProPlugPlugInX_WorkflowProperty: @YES,
		};
	}
	return self;
}
- (id)effectBase { return self; }
- (NSNotificationCenter *)notifier { return _notifier; }
- (id)startContextFlush { self.contextCount += 1; return self.accessor; }
- (id)startContext { self.contextCount += 1; return self.accessor; }
@end

#pragma mark - Tests

@interface FxGripWorkflowRelayTests : XCTestCase
@property (nonatomic, strong) NSURL *rootURL;
@property (nonatomic, strong) FxGripWorkflowMailbox *mailbox;
@property (nonatomic, strong) FxGripRelayTestEffect *effect;
@property (nonatomic, strong) FxGripWorkflowRelay *relay;
@end

@implementation FxGripWorkflowRelayTests

- (void)setUp
{
	[super setUp];
	self.rootURL = [[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES]
					URLByAppendingPathComponent:NSUUID.UUID.UUIDString isDirectory:YES];
	self.mailbox = [[FxGripWorkflowMailbox alloc] initWithRootURL:self.rootURL];
	self.effect = [[FxGripRelayTestEffect alloc] init];
	self.relay = [[FxGripWorkflowRelay alloc] initWithMailbox:self.mailbox];
	self.relay.heartbeatInterval = 3600;
}

- (void)tearDown
{
	self.relay = nil;
	[NSFileManager.defaultManager removeItemAtURL:self.rootURL error:NULL];
	[super tearDown];
}

- (void)loadAndAdd
{
	XCTAssertTrue([self.relay extLoadWithEffect:(id)self.effect]);
	[self.relay extAddedToDocument:[NSNotification notificationWithName:@"added" object:self.effect]];
}

- (FxGripFCPXMLDocument *)document
{
	FxGripFCPXMLDocument *document = [[FxGripFCPXMLDocument alloc] init];
	[document.resources effectForFxPlugUUID:kRelayTestPlugin name:@"Grip"];
	[[document.libraryCreatingIfNeeded firstEventCreatingIfNeeded] addItem:[FxGripFCPXMLStoryElement clipWithName:@"C" duration:CMTimeMake(1, 1)]];
	return document;
}

#pragma mark Gate and settings

- (void)testDefaultsAndStatusWithoutMailbox
{
	FxGripWorkflowRelay *bare = [[FxGripWorkflowRelay alloc] initWithMailbox:nil];
	XCTAssertEqual(bare.status, FxGripWorkflowLinkStatusUnavailable);
	XCTAssertTrue([bare.statusDescription containsString:@"unavailable"]);
	XCTAssertEqual(bare.heartbeatInterval, 15);
	XCTAssertEqual(bare.presenceWindow, 45);
	XCTAssertTrue(bare.appliesOnReceive);
	XCTAssertEqual(bare.applyOptions, FxGripFCPXMLApplyMatchNames | FxGripFCPXMLApplyUndoGroup);
	XCTAssertEqual(self.relay.status, FxGripWorkflowLinkStatusIdle);
	XCTAssertEqualObjects(FxGripWorkflowRelayExtensionKey, @"FxGripWorkflowRelay");
	[bare extLoadWithEffect:(id)self.effect];
	[bare extAddedToDocument:[NSNotification notificationWithName:@"added" object:self.effect]];
	XCTAssertNil(bare.instanceRecord);
	XCTAssertEqual([bare processInbox], (NSUInteger)0);
	NSError *error = nil;
	XCTAssertNil([bare publishCaptureNamed:nil options:0 error:&error]);
	XCTAssertEqual(error.code, kFxGripError_WorkflowUnavailable);
}

- (void)testSettingsDictionaryShapesTheRelay
{
	self.effect.pluginProperties = @{
		kProPlugPlugIn_UuidProperty: kRelayTestPlugin,
		kProPlugPlugIn_ClassNameProperty: @"Grip",
		kProPlugPlugIn_GroupUUIDProperty: @"GROUP",
		kProPlugPlugInX_WorkflowProperty: @{
			kFxGripWorkflowProperty_ApplyOnReceive: @NO,
			kFxGripWorkflowProperty_HeartbeatInterval: @20,
			kFxGripWorkflowProperty_MatchNames: @NO,
			kFxGripWorkflowProperty_Undo: @NO,
			kFxGripWorkflowProperty_Keyframes: @NO,
		},
	};
	[self loadAndAdd];
	XCTAssertFalse(self.relay.appliesOnReceive);
	XCTAssertEqual(self.relay.heartbeatInterval, 20);
	XCTAssertEqual(self.relay.presenceWindow, 60);
	XCTAssertEqual(self.relay.applyOptions, FxGripFCPXMLApplyIgnoreKeyframes);
}

#pragma mark Registration and status

- (void)testRegistersTheInstanceAndRefreshesOnParameterChange
{
	[self loadAndAdd];
	FxGripWorkflowInstanceRecord *record = self.relay.instanceRecord;
	XCTAssertEqualObjects(record.pluginUUID, kRelayTestPlugin);
	XCTAssertEqual(record.sessionID, (UInt64)11);
	XCTAssertEqualObjects(record.pluginDisplayName, @"Grip");
	XCTAssertEqualObjects(record.pluginVersion, @"1.2");
	XCTAssertEqual(record.documentID, (NSUInteger)5);
	XCTAssertEqual(CMTimeCompare(record.timelineInPoint, CMTimeMake(1, 1)), 0);
	NSArray *stored = [self.mailbox instanceRecordsForPluginUUID:kRelayTestPlugin];
	XCTAssertEqual(stored.count, (NSUInteger)1);
	XCTAssertEqualObjects(stored.firstObject, record);

	self.effect.effectOutPointOfTimeLine = CMTimeMake(9, 1);
	[self.relay extParameterChanged:[NSNotification notificationWithName:@"changed" object:self.effect]];
	FxGripWorkflowInstanceRecord *refreshed = [self.mailbox instanceRecordsForPluginUUID:kRelayTestPlugin].firstObject;
	XCTAssertEqual(CMTimeCompare(refreshed.timelineOutPoint, CMTimeMake(9, 1)), 0);
	[self.relay heartbeat];
	XCTAssertEqual([self.mailbox instanceRecordsForPluginUUID:kRelayTestPlugin].count, (NSUInteger)1);
}

- (void)testStatusFollowsExtensionPresence
{
	[self loadAndAdd];
	__block NSNumber *posted = nil;
	id token = [self.effect.notifier addObserverForName:FxGripWorkflowRelayStatusChangedName object:nil queue:nil
											 usingBlock:^(NSNotification *note) {
		posted = note.userInfo[FxGripWorkflowRelayStatusKey];
	}];
	XCTAssertEqual(self.relay.status, FxGripWorkflowLinkStatusIdle);
	XCTAssertTrue([self.relay.statusDescription containsString:@"no workflow extension"]);
	[self.mailbox writeExtensionPresenceWithBundleIdentifier:@"com.example.ext" version:@"1" error:NULL];
	XCTAssertEqual([self.relay refreshStatus], FxGripWorkflowLinkStatusConnected);
	XCTAssertEqualObjects(posted, @(FxGripWorkflowLinkStatusConnected));
	XCTAssertTrue([self.relay.statusDescription containsString:@"connected"]);
	self.relay.presenceWindow = -1;
	XCTAssertEqual([self.relay refreshStatus], FxGripWorkflowLinkStatusIdle);
	[self.effect.notifier removeObserver:token];
}

#pragma mark Inbox

- (void)testProcessInboxAppliesAddressedAndBroadcastMessages
{
	[self loadAndAdd];
	FxGripWorkflowMessage *broadcast = [self.mailbox enqueueDocument:self.document forPluginUUID:kRelayTestPlugin sessionID:0 sender:nil name:nil error:NULL];
	FxGripWorkflowMessage *addressed = [self.mailbox enqueueDocument:self.document forPluginUUID:kRelayTestPlugin sessionID:11 sender:nil name:nil error:NULL];
	[self.mailbox enqueueDocument:self.document forPluginUUID:kRelayTestPlugin sessionID:12 sender:nil name:nil error:NULL];
	NSMutableArray<NSString *> *appliedIdentifiers = NSMutableArray.new;
	id token = [self.effect.notifier addObserverForName:FxGripWorkflowRelayDidApplyDocumentName object:nil queue:nil
											 usingBlock:^(NSNotification *note) {
		[appliedIdentifiers addObject:note.userInfo[FxGripWorkflowRelayMessageIdentifierKey]];
	}];
	XCTAssertEqual([self.relay processInbox], (NSUInteger)2);
	FxGripRelayTestFCPXMLAPI *api = self.effect.apiManager.fcpxmlAPIv1;
	XCTAssertEqual(api.applied.count, (NSUInteger)2);
	XCTAssertEqual(CMTimeCompare(api.applyTimes.firstObject.CMTimeValue, CMTimeMake(2, 1)), 0, @"the host's current time");
	XCTAssertEqual(api.lastOptions, self.relay.applyOptions);
	XCTAssertEqual(self.effect.contextCount, (NSUInteger)2);
	XCTAssertFalse(self.effect.accessor.active, @"the access closes after each apply");
	XCTAssertEqualObjects(appliedIdentifiers, (@[broadcast.identifier, addressed.identifier]));
	NSArray<FxGripWorkflowMessage *> *remaining = [self.mailbox inboxMessagesForPluginUUID:kRelayTestPlugin];
	XCTAssertEqual(remaining.count, (NSUInteger)2, @"the broadcast stays for other instances; the message for session 12 is not ours");
	XCTAssertEqualObjects(remaining.firstObject.identifier, broadcast.identifier);
	[self.effect.notifier removeObserver:token];
}

- (void)testDocumentHandlerVetoAndApplyErrors
{
	[self loadAndAdd];
	[self.mailbox enqueueDocument:self.document forPluginUUID:kRelayTestPlugin sessionID:11 sender:@"s" name:@"n" error:NULL];
	__block FxGripWorkflowMessage *seen = nil;
	self.relay.documentHandler = ^BOOL(FxGripFCPXMLDocument *document, FxGripWorkflowMessage *message) {
		seen = message;
		return NO;
	};
	XCTAssertEqual([self.relay processInbox], (NSUInteger)0);
	XCTAssertEqualObjects(seen.sender, @"s");
	XCTAssertEqual([self.mailbox inboxMessagesForPluginUUID:kRelayTestPlugin].count, (NSUInteger)1, @"a vetoed message stays");

	self.relay.documentHandler = nil;
	FxGripRelayTestFCPXMLAPI *api = self.effect.apiManager.fcpxmlAPIv1;
	api.applyError = [NSError errorWithDomain:@"test" code:1 userInfo:nil];
	XCTAssertEqual([self.relay processInbox], (NSUInteger)0);
	XCTAssertEqual(api.applied.count, (NSUInteger)1);
	XCTAssertEqual([self.mailbox inboxMessagesForPluginUUID:kRelayTestPlugin].count, (NSUInteger)0, @"a failed addressed message is consumed");

	self.effect.apiManager.fcpxmlAPIv1 = nil;
	[self.mailbox enqueueDocument:self.document forPluginUUID:kRelayTestPlugin sessionID:11 sender:nil name:nil error:NULL];
	XCTAssertEqual([self.relay processInbox], (NSUInteger)0, @"no API, no apply");
}

- (void)testMalformedMessageIsDiscarded
{
	[self loadAndAdd];
	FxGripWorkflowMessage *message = [self.mailbox enqueueDocument:self.document forPluginUUID:kRelayTestPlugin sessionID:11 sender:nil name:nil error:NULL];
	NSMutableDictionary *broken = [[NSDictionary dictionaryWithContentsOfURL:message.fileURL error:NULL] mutableCopy];
	broken[@"fcpxml"] = @"<plist/>";
	[broken writeToURL:message.fileURL error:NULL];
	XCTAssertEqual([self.relay processInbox], (NSUInteger)0);
	XCTAssertEqual([self.mailbox inboxMessagesForPluginUUID:kRelayTestPlugin].count, (NSUInteger)0);
}

- (void)testMailboxChangeAppliesOnArrivalOnTheMainQueue
{
	[self loadAndAdd];
	[self.mailbox enqueueDocument:self.document forPluginUUID:kRelayTestPlugin sessionID:11 sender:nil name:nil error:NULL];
	[self.mailbox postChangeNotification];
	FxGripRelayTestFCPXMLAPI *api = self.effect.apiManager.fcpxmlAPIv1;
	XCTestExpectation *applied = [self expectationWithDescription:@"applied on arrival"];
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		XCTAssertEqual(api.applied.count, (NSUInteger)1);
		[applied fulfill];
	});
	[self waitForExpectations:@[applied] timeout:5];
}

#pragma mark Outbox

- (void)testPublishCaptureWritesTheOutbox
{
	[self loadAndAdd];
	NSError *error = nil;
	FxGripWorkflowMessage *message = [self.relay publishCaptureNamed:nil options:FxGripFCPXMLCaptureKeyframes error:&error];
	XCTAssertNotNil(message, @"%@", error);
	XCTAssertEqualObjects(message.kind, FxGripWorkflowMessageKindExport);
	XCTAssertEqualObjects(message.name, @"Grip");
	XCTAssertEqual(message.sessionID, (UInt64)11);
	XCTAssertEqual(self.mailbox.outboxMessages.count, (NSUInteger)1);
	XCTAssertEqual(((FxGripRelayTestFCPXMLAPI *)self.effect.apiManager.fcpxmlAPIv1).captureCount, (NSUInteger)1);
	XCTAssertFalse(self.effect.accessor.active);
	XCTAssertEqualObjects([self.relay publishCaptureNamed:@"Named" options:0 error:NULL].name, @"Named");
}

#pragma mark Teardown

- (void)testDeallocRemovesTheRecord
{
	[self loadAndAdd];
	XCTAssertEqual([self.mailbox instanceRecordsForPluginUUID:kRelayTestPlugin].count, (NSUInteger)1);
	self.relay = nil;
	XCTAssertEqual([self.mailbox instanceRecordsForPluginUUID:kRelayTestPlugin].count, (NSUInteger)0);
}

@end
