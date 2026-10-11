/*!
	@file       FxGripWorkflowClient.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripWorkflowClient
	@abstract   The workflow extension's side of the mailbox to the plug-in instances.
	@discussion Introduced in FxGrip 0.1.0. See FxGripWorkflowClient.h.
*/

#import <FxGripWorkflow/FxGripWorkflowClient.h>

@interface FxGripWorkflowClient ()
@property (strong, nullable) id changeToken;
@property (strong, nullable) dispatch_source_t timer;
@property (readwrite) BOOL isStarted;
@end

@implementation FxGripWorkflowClient

+ (instancetype)sharedClient
{
	FxGripWorkflowMailbox *mailbox = FxGripWorkflowMailbox.sharedMailbox;
	return mailbox ? [[self alloc] initWithMailbox:mailbox] : nil;
}

- (instancetype)initWithMailbox:(FxGripWorkflowMailbox *)mailbox
{
	self = [super init];
	if (self) {
		_mailbox = mailbox;
		_bundleIdentifier = NSBundle.mainBundle.bundleIdentifier ?: @"FxGripWorkflow";
		id version = NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"];
		_version = [version isKindOfClass:NSString.class] ? version : nil;
		_heartbeatInterval = 10;
		_instanceWindow = 60;
	}
	return self;
}

- (instancetype)init
{
	return [self initWithMailbox:[[FxGripWorkflowMailbox alloc] init]];
}

- (void)dealloc
{
	[self stop];
}

#pragma mark - Lifecycle

- (void)start
{
	if (self.isStarted) {
		return;
	}
	self.isStarted = YES;
	[self heartbeat];
	dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
	uint64_t interval = (uint64_t)(MAX(self.heartbeatInterval, 1.0) * NSEC_PER_SEC);
	dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, interval), interval, NSEC_PER_SEC / 2);
	__weak FxGripWorkflowClient *weakSelf = self;
	dispatch_source_set_event_handler(timer, ^{
		[weakSelf heartbeat];
	});
	dispatch_resume(timer);
	self.timer = timer;
	self.changeToken = [self.mailbox observeChangesWithHandler:^{
		FxGripWorkflowClient *client = weakSelf;
		if (client.changeHandler) {
			client.changeHandler(client);
		}
	}];
	[self.mailbox postChangeNotification];
}

- (void)stop
{
	if (_timer != nil) {
		dispatch_source_cancel(_timer);
		_timer = nil;
	}
	_changeToken = nil;
	_isStarted = NO;
}

- (void)heartbeat
{
	NSError *error = nil;
	if (![self.mailbox writeExtensionPresenceWithBundleIdentifier:self.bundleIdentifier version:self.version error:&error]) {
		NSLog(@"%s Error: could not write the workflow extension presence: %@", __func__, error);
	}
}

#pragma mark - Instances

- (NSArray<FxGripWorkflowInstanceRecord *> *)liveRecords:(NSArray<FxGripWorkflowInstanceRecord *> *)records
{
	NSMutableArray *live = [NSMutableArray array];
	for (FxGripWorkflowInstanceRecord *record in records) {
		if (![record isStaleAfter:self.instanceWindow]) {
			[live addObject:record];
		}
	}
	return live;
}

- (NSArray<FxGripWorkflowInstanceRecord *> *)instances
{
	return [self liveRecords:self.mailbox.instanceRecords];
}

- (NSArray<FxGripWorkflowInstanceRecord *> *)instancesOfPluginUUID:(NSString *)pluginUUID
{
	return [self liveRecords:[self.mailbox instanceRecordsForPluginUUID:pluginUUID]];
}

- (NSArray<NSString *> *)pluginUUIDs
{
	NSMutableSet *uuids = [NSMutableSet set];
	for (FxGripWorkflowInstanceRecord *record in self.instances) {
		[uuids addObject:record.pluginUUID];
	}
	return [uuids.allObjects sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
}

#pragma mark - Sending

- (FxGripWorkflowMessage *)sendDocument:(FxGripFCPXMLDocument *)document toInstance:(FxGripWorkflowInstanceRecord *)instance
								   name:(NSString *)name error:(NSError **)error
{
	FxGripWorkflowMessage *message = [self.mailbox enqueueDocument:document forPluginUUID:instance.pluginUUID
														sessionID:instance.sessionID sender:self.bundleIdentifier name:name error:error];
	if (message != nil) {
		[self.mailbox postChangeNotification];
	}
	return message;
}

- (FxGripWorkflowMessage *)sendDocument:(FxGripFCPXMLDocument *)document toPluginUUID:(NSString *)pluginUUID
								   name:(NSString *)name error:(NSError **)error
{
	FxGripWorkflowMessage *message = [self.mailbox enqueueDocument:document forPluginUUID:pluginUUID sessionID:0
														   sender:self.bundleIdentifier name:name error:error];
	if (message != nil) {
		[self.mailbox postChangeNotification];
	}
	return message;
}

- (NSUInteger)removeBroadcastsOlderThan:(NSTimeInterval)age
{
	NSUInteger removed = 0;
	for (NSString *pluginUUID in [self.mailbox.instanceRecords valueForKeyPath:@"@distinctUnionOfObjects.pluginUUID"]) {
		for (FxGripWorkflowMessage *message in [self.mailbox inboxMessagesForPluginUUID:pluginUUID]) {
			if (message.sessionID == 0 && -[message.date timeIntervalSinceNow] > age
				&& [self.mailbox removeMessage:message error:NULL]) {
				removed += 1;
			}
		}
	}
	return removed;
}

#pragma mark - Receiving

- (NSArray<FxGripWorkflowMessage *> *)exports
{
	return self.mailbox.outboxMessages;
}

- (BOOL)removeExport:(FxGripWorkflowMessage *)message error:(NSError **)error
{
	return [self.mailbox removeMessage:message error:error];
}

@end
