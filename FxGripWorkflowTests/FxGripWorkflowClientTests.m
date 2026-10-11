/*!
	@file       FxGripWorkflowClientTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripWorkflowClientTests
	@abstract   Tests the extension-side mailbox client over a temporary mailbox.
	@discussion Introduced in FxGrip 0.1.0. The tests cover presence, the live-instance filter, sending to
	            one instance and to a plug-in, clearing old broadcasts, the exports, and the change handler.
*/

#import <XCTest/XCTest.h>
#import <CoreMedia/CoreMedia.h>
#import <FxGripWorkflow/FxGripWorkflow.h>
#import <FxGrip/FxGripFCPXMLStoryElement.h>

static NSString *const kClientTestPlugin = @"CCCCCCCC-1111-2222-3333-444444444444";

@interface FxGripWorkflowClientTests : XCTestCase
@property (nonatomic, strong) NSURL *rootURL;
@property (nonatomic, strong) FxGripWorkflowMailbox *mailbox;
@property (nonatomic, strong) FxGripWorkflowClient *client;
@end

@implementation FxGripWorkflowClientTests

- (void)setUp
{
	[super setUp];
	self.rootURL = [[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES]
					URLByAppendingPathComponent:NSUUID.UUID.UUIDString isDirectory:YES];
	self.mailbox = [[FxGripWorkflowMailbox alloc] initWithRootURL:self.rootURL];
	self.client = [[FxGripWorkflowClient alloc] initWithMailbox:self.mailbox];
	self.client.bundleIdentifier = @"com.example.ext";
	self.client.version = @"3.1";
}

- (void)tearDown
{
	[self.client stop];
	[NSFileManager.defaultManager removeItemAtURL:self.rootURL error:NULL];
	[super tearDown];
}

- (FxGripFCPXMLDocument *)document
{
	FxGripFCPXMLDocument *document = [[FxGripFCPXMLDocument alloc] init];
	[document.resources effectForFxPlugUUID:kClientTestPlugin name:@"Grip"];
	return document;
}

- (FxGripWorkflowInstanceRecord *)recordWithSession:(UInt64)session age:(NSTimeInterval)age
{
	FxGripWorkflowInstanceRecord *record = [[FxGripWorkflowInstanceRecord alloc] initWithPluginUUID:kClientTestPlugin sessionID:session];
	record.lastSeen = [NSDate dateWithTimeIntervalSinceNow:-age];
	[self.mailbox writeInstanceRecord:record error:NULL];
	return record;
}

- (void)testDefaults
{
	XCTAssertEqual(self.client.heartbeatInterval, 10);
	XCTAssertEqual(self.client.instanceWindow, 60);
	XCTAssertFalse(self.client.isStarted);
	XCTAssertEqualObjects(self.client.mailbox, self.mailbox);
	XCTAssertNil(FxGripWorkflowClient.sharedClient, @"the test process has no App Group");
}

- (void)testStartWritesPresenceAndObserves
{
	XCTestExpectation *changed = [self expectationWithDescription:@"change handler"];
	changed.assertForOverFulfill = NO;
	self.client.changeHandler = ^(FxGripWorkflowClient *client) {
		[changed fulfill];
	};
	[self.client start];
	XCTAssertTrue(self.client.isStarted);
	XCTAssertEqualObjects(self.mailbox.extensionPresence[@"bundleIdentifier"], @"com.example.ext");
	XCTAssertEqualObjects(self.mailbox.extensionPresence[@"version"], @"3.1");
	XCTAssertTrue([self.mailbox isExtensionPresentWithin:5]);
	[self.client start];
	[self waitForExpectations:@[changed] timeout:5];
	[self.client stop];
	XCTAssertFalse(self.client.isStarted);
}

- (void)testInstancesFilterStaleRecords
{
	FxGripWorkflowInstanceRecord *live = [self recordWithSession:1 age:5];
	[self recordWithSession:2 age:500];
	FxGripWorkflowInstanceRecord *other = [[FxGripWorkflowInstanceRecord alloc] initWithPluginUUID:@"OTHER" sessionID:3];
	[self.mailbox writeInstanceRecord:other error:NULL];
	XCTAssertEqual(self.client.instances.count, (NSUInteger)2);
	XCTAssertEqualObjects([self.client instancesOfPluginUUID:kClientTestPlugin], @[live]);
	XCTAssertEqualObjects(self.client.pluginUUIDs, (@[kClientTestPlugin, @"OTHER"]));
	self.client.instanceWindow = 1000;
	XCTAssertEqual([self.client instancesOfPluginUUID:kClientTestPlugin].count, (NSUInteger)2);
}

- (void)testSendingAndBroadcastCleanup
{
	FxGripWorkflowInstanceRecord *instance = [self recordWithSession:7 age:0];
	NSError *error = nil;
	FxGripWorkflowMessage *addressed = [self.client sendDocument:self.document toInstance:instance name:@"One" error:&error];
	XCTAssertNotNil(addressed, @"%@", error);
	XCTAssertEqual(addressed.sessionID, (UInt64)7);
	XCTAssertEqualObjects(addressed.sender, @"com.example.ext");
	FxGripWorkflowMessage *broadcast = [self.client sendDocument:self.document toPluginUUID:kClientTestPlugin name:@"All" error:&error];
	XCTAssertEqual(broadcast.sessionID, (UInt64)0);
	XCTAssertEqual([self.mailbox inboxMessagesForPluginUUID:kClientTestPlugin].count, (NSUInteger)2);
	XCTAssertEqual([self.client removeBroadcastsOlderThan:3600], (NSUInteger)0);
	XCTAssertEqual([self.client removeBroadcastsOlderThan:-1], (NSUInteger)1);
	XCTAssertEqual([self.mailbox inboxMessagesForPluginUUID:kClientTestPlugin].count, (NSUInteger)1);
	XCTAssertNil([self.client sendDocument:(id _Nonnull)nil toInstance:instance name:nil error:&error]);
	XCTAssertNotNil(error);
}

- (void)testExports
{
	[self.mailbox publishDocument:self.document fromPluginUUID:kClientTestPlugin sessionID:1 name:@"Capture" error:NULL];
	XCTAssertEqual(self.client.exports.count, (NSUInteger)1);
	XCTAssertEqualObjects(self.client.exports.firstObject.name, @"Capture");
	XCTAssertTrue([self.client removeExport:self.client.exports.firstObject error:NULL]);
	XCTAssertEqual(self.client.exports.count, (NSUInteger)0);
}

@end
