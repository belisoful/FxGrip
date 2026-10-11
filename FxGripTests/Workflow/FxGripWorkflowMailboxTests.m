/*!
	@file       FxGripWorkflowMailboxTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripWorkflowMailboxTests
	@abstract   Tests the workflow mailbox: instance records, extension presence, queues, and observation.
	@discussion Introduced in FxGrip 0.1.0. Every test runs over a mailbox rooted in a per-test temporary
	            folder, so no App Group is needed. The tests cover the record round trip, staleness, the
	            inbox addressing by session, the outbox, message parsing, and the change observer.
*/

#import <XCTest/XCTest.h>
#import <CoreMedia/CoreMedia.h>
#import <FxGrip/FxGripWorkflowMailbox.h>
#import <FxGrip/FxGripFCPXMLStoryElement.h>
#import <FxGrip/FxGripErrors.h>

static NSString *const kMailboxTestPlugin = @"aaaaaaaa-1111-2222-3333-444444444444";

@interface FxGripWorkflowMailboxTests : XCTestCase
@property (nonatomic, strong) NSURL *rootURL;
@property (nonatomic, strong) FxGripWorkflowMailbox *mailbox;
@end

@implementation FxGripWorkflowMailboxTests

- (void)setUp
{
	[super setUp];
	self.rootURL = [[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES]
					URLByAppendingPathComponent:NSUUID.UUID.UUIDString isDirectory:YES];
	self.mailbox = [[FxGripWorkflowMailbox alloc] initWithRootURL:self.rootURL];
}

- (void)tearDown
{
	[NSFileManager.defaultManager removeItemAtURL:self.rootURL error:NULL];
	[super tearDown];
}

- (FxGripFCPXMLDocument *)document
{
	FxGripFCPXMLDocument *document = [[FxGripFCPXMLDocument alloc] init];
	[document.resources effectForFxPlugUUID:kMailboxTestPlugin name:@"Grip"];
	[[document.libraryCreatingIfNeeded firstEventCreatingIfNeeded] addItem:[FxGripFCPXMLStoryElement clipWithName:@"C" duration:CMTimeMake(1, 1)]];
	return document;
}

#pragma mark - Records

- (void)testInstanceRecordRoundTrip
{
	FxGripWorkflowInstanceRecord *record = [[FxGripWorkflowInstanceRecord alloc] initWithPluginUUID:kMailboxTestPlugin sessionID:42];
	record.pluginDisplayName = @"Grip";
	record.pluginVersion = @"1.0";
	record.documentID = 7;
	record.hostBundleIdentifier = @"com.apple.FinalCut";
	record.timelineInPoint = CMTimeMake(1001, 30000);
	record.timelineOutPoint = CMTimeMake(2002, 30000);
	XCTAssertEqual(record.processIdentifier, (int)NSProcessInfo.processInfo.processIdentifier);
	XCTAssertEqualObjects(record.recordName, ([NSString stringWithFormat:@"%d-42.plist", record.processIdentifier]));
	XCTAssertFalse([record isStaleAfter:60]);

	FxGripWorkflowInstanceRecord *again = [[FxGripWorkflowInstanceRecord alloc] initWithDictionary:record.dictionaryRepresentation];
	XCTAssertEqualObjects(again, record);
	XCTAssertEqual(again.hash, record.hash);
	XCTAssertEqualObjects(again.pluginDisplayName, @"Grip");
	XCTAssertEqualObjects(again.pluginVersion, @"1.0");
	XCTAssertEqual(again.documentID, (NSUInteger)7);
	XCTAssertEqualObjects(again.hostBundleIdentifier, @"com.apple.FinalCut");
	XCTAssertEqual(CMTimeCompare(again.timelineInPoint, record.timelineInPoint), 0);
	XCTAssertEqual(CMTimeCompare(again.timelineOutPoint, record.timelineOutPoint), 0);
	XCTAssertEqualObjects([record copy], record);
	XCTAssertNil([[FxGripWorkflowInstanceRecord alloc] initWithDictionary:@{@"sessionID": @1}]);
	XCTAssertFalse(CMTIME_IS_VALID([[FxGripWorkflowInstanceRecord alloc] initWithPluginUUID:@"x" sessionID:1].timelineInPoint));
	XCTAssertTrue([record.description containsString:@"session=42"]);
}

- (void)testWritesListsAndRemovesRecords
{
	XCTAssertEqualObjects(self.mailbox.instanceRecords, @[]);
	FxGripWorkflowInstanceRecord *one = [[FxGripWorkflowInstanceRecord alloc] initWithPluginUUID:kMailboxTestPlugin sessionID:1];
	one.lastSeen = [NSDate dateWithTimeIntervalSinceNow:-100];
	FxGripWorkflowInstanceRecord *two = [[FxGripWorkflowInstanceRecord alloc] initWithPluginUUID:kMailboxTestPlugin sessionID:2];
	FxGripWorkflowInstanceRecord *other = [[FxGripWorkflowInstanceRecord alloc] initWithPluginUUID:@"OTHER-PLUGIN" sessionID:3];
	NSError *error = nil;
	XCTAssertTrue([self.mailbox writeInstanceRecord:one error:&error], @"%@", error);
	XCTAssertTrue([self.mailbox writeInstanceRecord:two error:&error], @"%@", error);
	XCTAssertTrue([self.mailbox writeInstanceRecord:other error:&error], @"%@", error);
	XCTAssertEqual(self.mailbox.instanceRecords.count, (NSUInteger)3);
	NSArray *mine = [self.mailbox instanceRecordsForPluginUUID:kMailboxTestPlugin.uppercaseString];
	XCTAssertEqual(mine.count, (NSUInteger)2, @"the lookup ignores case");
	XCTAssertEqualObjects(mine.firstObject, two, @"newest first");
	XCTAssertEqual([self.mailbox removeInstanceRecordsStaleAfter:50], (NSUInteger)1);
	XCTAssertEqual([self.mailbox instanceRecordsForPluginUUID:kMailboxTestPlugin].count, (NSUInteger)1);
	XCTAssertTrue([self.mailbox removeInstanceRecord:two error:&error]);
	XCTAssertTrue([self.mailbox removeInstanceRecord:two error:&error], @"removing a gone record is fine");
	XCTAssertEqual(self.mailbox.instanceRecords.count, (NSUInteger)1);
	FxGripWorkflowInstanceRecord *blank = [[FxGripWorkflowInstanceRecord alloc] initWithPluginUUID:@"" sessionID:9];
	XCTAssertFalse([self.mailbox writeInstanceRecord:blank error:&error]);
	XCTAssertEqual(error.code, kFxGripError_WorkflowMailbox);
}

#pragma mark - Presence

- (void)testExtensionPresence
{
	XCTAssertNil(self.mailbox.extensionPresence);
	XCTAssertFalse([self.mailbox isExtensionPresentWithin:60]);
	NSError *error = nil;
	XCTAssertTrue([self.mailbox writeExtensionPresenceWithBundleIdentifier:@"com.example.ext" version:@"2.0" error:&error], @"%@", error);
	XCTAssertEqualObjects(self.mailbox.extensionPresence[@"bundleIdentifier"], @"com.example.ext");
	XCTAssertEqualObjects(self.mailbox.extensionPresence[@"version"], @"2.0");
	XCTAssertTrue([self.mailbox isExtensionPresentWithin:60]);
	XCTAssertFalse([self.mailbox isExtensionPresentWithin:-1]);
}

#pragma mark - Messages

- (void)testInboxAddressingBySession
{
	NSError *error = nil;
	FxGripWorkflowMessage *broadcast = [self.mailbox enqueueDocument:self.document forPluginUUID:kMailboxTestPlugin sessionID:0
															  sender:@"com.example.ext" name:@"All" error:&error];
	XCTAssertNotNil(broadcast, @"%@", error);
	FxGripWorkflowMessage *addressed = [self.mailbox enqueueDocument:self.document forPluginUUID:kMailboxTestPlugin sessionID:7
															  sender:nil name:nil error:&error];
	FxGripWorkflowMessage *elsewhere = [self.mailbox enqueueDocument:self.document forPluginUUID:kMailboxTestPlugin sessionID:8
															  sender:nil name:nil error:&error];
	XCTAssertNotNil(elsewhere);
	XCTAssertEqualObjects(broadcast.kind, FxGripWorkflowMessageKindApply);
	XCTAssertEqualObjects(broadcast.pluginUUID, kMailboxTestPlugin.uppercaseString);
	XCTAssertEqualObjects(broadcast.sender, @"com.example.ext");
	XCTAssertEqualObjects(broadcast.name, @"All");
	XCTAssertNil(addressed.sender);
	XCTAssertEqual(addressed.sessionID, (UInt64)7);
	XCTAssertNotNil(broadcast.document);
	XCTAssertEqualObjects(broadcast.document.resources.effects.firstObject.fxPlugUUID, kMailboxTestPlugin);
	XCTAssertTrue([broadcast.XMLString containsString:@"<fcpxml"]);
	XCTAssertTrue([broadcast.description containsString:@"apply"]);

	XCTAssertEqual([self.mailbox inboxMessagesForPluginUUID:kMailboxTestPlugin].count, (NSUInteger)3);
	NSArray<FxGripWorkflowMessage *> *forSeven = [self.mailbox inboxMessagesForPluginUUID:kMailboxTestPlugin sessionID:7];
	XCTAssertEqual(forSeven.count, (NSUInteger)2);
	XCTAssertEqualObjects(forSeven[0].identifier, broadcast.identifier, @"oldest first");
	XCTAssertEqualObjects(forSeven[1].identifier, addressed.identifier);
	XCTAssertEqual([self.mailbox inboxMessagesForPluginUUID:@"NOBODY"].count, (NSUInteger)0);
	XCTAssertTrue([self.mailbox removeMessage:addressed error:&error]);
	XCTAssertEqual([self.mailbox inboxMessagesForPluginUUID:kMailboxTestPlugin sessionID:7].count, (NSUInteger)1);
	XCTAssertTrue([self.mailbox removeMessage:addressed error:&error], @"removing twice is fine");
}

- (void)testOutboxAndRemoveAll
{
	NSError *error = nil;
	FxGripWorkflowMessage *published = [self.mailbox publishDocument:self.document fromPluginUUID:kMailboxTestPlugin sessionID:3
															   name:@"Capture" error:&error];
	XCTAssertNotNil(published, @"%@", error);
	XCTAssertEqualObjects(published.kind, FxGripWorkflowMessageKindExport);
	XCTAssertEqual(self.mailbox.outboxMessages.count, (NSUInteger)1);
	XCTAssertEqualObjects(self.mailbox.outboxMessages.firstObject.name, @"Capture");
	[self.mailbox enqueueDocument:self.document forPluginUUID:kMailboxTestPlugin sessionID:0 sender:nil name:nil error:&error];
	XCTAssertEqual([self.mailbox removeAllMessages], (NSUInteger)2);
	XCTAssertEqual(self.mailbox.outboxMessages.count, (NSUInteger)0);
	XCTAssertEqual([self.mailbox inboxMessagesForPluginUUID:kMailboxTestPlugin].count, (NSUInteger)0);
}

- (void)testRefusesAnEmptyMessage
{
	NSError *error = nil;
	XCTAssertNil([self.mailbox enqueueDocument:(id _Nonnull)nil forPluginUUID:kMailboxTestPlugin sessionID:0 sender:nil name:nil error:&error]);
	XCTAssertEqual(error.code, kFxGripError_WorkflowMailbox);
	XCTAssertNil([self.mailbox publishDocument:self.document fromPluginUUID:@"" sessionID:0 name:nil error:&error]);
}

- (void)testMalformedMessageFilesAreSkipped
{
	[self.mailbox enqueueDocument:self.document forPluginUUID:kMailboxTestPlugin sessionID:0 sender:nil name:nil error:NULL];
	NSURL *folder = [self.mailbox inboxMessagesForPluginUUID:kMailboxTestPlugin].firstObject.fileURL.URLByDeletingLastPathComponent;
	[@{@"kind": @"apply"} writeToURL:[folder URLByAppendingPathComponent:@"0-junk.fxgripmsg"] error:NULL];
	[[@"garbage" dataUsingEncoding:NSUTF8StringEncoding] writeToURL:[folder URLByAppendingPathComponent:@"1-junk.fxgripmsg"] atomically:YES];
	XCTAssertEqual([self.mailbox inboxMessagesForPluginUUID:kMailboxTestPlugin].count, (NSUInteger)1);
}

#pragma mark - Observation

- (void)testObserverRunsOnChange
{
	XCTestExpectation *changed = [self expectationWithDescription:@"handler runs"];
	changed.assertForOverFulfill = NO;
	id token = [self.mailbox observeChangesWithHandler:^{
		[changed fulfill];
	}];
	XCTAssertNotNil(token);
	[self.mailbox writeExtensionPresenceWithBundleIdentifier:@"x" version:nil error:NULL];
	[self.mailbox postChangeNotification];
	[self waitForExpectations:@[changed] timeout:5];
	token = nil;
}

- (void)testSharedMailboxNeedsAnAppGroup
{
	// The test process carries no App Group entitlement, so the shared mailbox is absent.
	XCTAssertEqualObjects(FxGripWorkflowMailbox.applicationGroupIdentifiers, @[]);
	XCTAssertNil(FxGripWorkflowMailbox.sharedMailbox);
	// macOS answers a Group Containers folder for any group a non-sandboxed process names.
	FxGripWorkflowMailbox *named = [[FxGripWorkflowMailbox alloc] initWithApplicationGroup:@"group.com.example.nope"];
	XCTAssertTrue(named == nil || [named.rootURL.path containsString:@"Group Containers"]);
	XCTAssertEqualObjects(FxGripWorkflowMailboxDidChangeNotification, @"com.belisoful.FxGrip.workflow.changed");
}

@end
