/*!
	@file       FxGripWorkflowRelay.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripWorkflowRelay
	@abstract   The extension that links a plug-in instance with a Final Cut Pro workflow extension.
	@discussion Introduced in FxGrip 0.1.0. See FxGripWorkflowRelay.h.
*/

#import <FxGrip/FxGripWorkflowRelay.h>
#import <FxGrip/FxGripTileableEffect+Extensions.h>
#import <FxGrip/FxGripTileableEffect+ProjectProperties.h>
#import <FxGrip/FxGripTileableEffect+Versioning.h>
#import <FxGrip/FxGripTileableEffect+OOBParameterAccess.h>
#import <FxGrip/FxGripTileableEffect+Timing.h>
#import <FxGrip/FxGripOOBParameterAccess.h>
#import <FxGrip/FxGripAPIAccessing.h>
#import <FxGrip/FxGripPluginInfo.h>
#import <FxGrip/NSDictionary+FxGripTileableEffect.h>
#import <FxGrip/FxGripErrors.h>
#import "FxGrip_ARC.h"

NSString *const FxGripWorkflowRelayExtensionKey = @"FxGripWorkflowRelay";
NSNotificationName const FxGripWorkflowRelayDidApplyDocumentName = @"FxGripWorkflowRelayDidApplyDocument";
NSNotificationName const FxGripWorkflowRelayStatusChangedName = @"FxGripWorkflowRelayStatusChanged";
NSString *const FxGripWorkflowRelayMessageIdentifierKey = @"messageIdentifier";
NSString *const FxGripWorkflowRelayStatusKey = @"status";

static const NSTimeInterval FxGripWorkflowDefaultHeartbeat = 15;

@interface FxGripWorkflowRelay ()
@property (readwrite, nullable, strong) FxGripWorkflowMailbox *mailbox;
@property (readwrite, nullable, strong) FxGripWorkflowInstanceRecord *instanceRecord;
@property (readwrite) FxGripWorkflowLinkStatus status;
@property (strong) id changeToken;
@property (strong) dispatch_source_t heartbeatTimer;
@property (assign) BOOL processing;
@end

@implementation FxGripWorkflowRelay

- (instancetype)init
{
	return [self initWithMailbox:FxGripWorkflowMailbox.sharedMailbox];
}

- (instancetype)initWithMailbox:(FxGripWorkflowMailbox *)mailbox
{
	self = [super init];
	if (self) {
		_mailbox = mailbox;
		_heartbeatInterval = FxGripWorkflowDefaultHeartbeat;
		_presenceWindow = FxGripWorkflowDefaultHeartbeat * 3;
		_appliesOnReceive = YES;
		_applyOptions = FxGripFCPXMLApplyMatchNames | FxGripFCPXMLApplyUndoGroup;
		_status = mailbox ? FxGripWorkflowLinkStatusIdle : FxGripWorkflowLinkStatusUnavailable;
	}
	return self;
}

- (void)dealloc
{
	[self stopHeartbeat];
	_changeToken = nil;
	if (_instanceRecord != nil) {
		[_mailbox removeInstanceRecord:_instanceRecord error:NULL];
		[_mailbox postChangeNotification];
	}
	SUPER_DEALLOC();
}

- (FxGripTileableEffect *)fxEffect
{
	return self.effect.effectBase;
}

#pragma mark - Settings

/*! The `workflow` plugin property when it is a dictionary, else nil. */
- (NSDictionary *)settings
{
	id workflow = self.fxEffect.pluginProperties.pluginWorkflow;
	return [workflow isKindOfClass:NSDictionary.class] ? workflow : nil;
}

- (void)applySettings
{
	NSDictionary *settings = self.settings;
	if (settings == nil) {
		return;
	}
	id apply = settings[kFxGripWorkflowProperty_ApplyOnReceive];
	if ([apply isKindOfClass:NSNumber.class]) {
		self.appliesOnReceive = [apply boolValue];
	}
	id interval = settings[kFxGripWorkflowProperty_HeartbeatInterval];
	if ([interval isKindOfClass:NSNumber.class] && [interval doubleValue] > 0) {
		self.heartbeatInterval = [interval doubleValue];
		self.presenceWindow = self.heartbeatInterval * 3;
	}
	FxGripFCPXMLApplyOptions options = self.applyOptions;
	id matchNames = settings[kFxGripWorkflowProperty_MatchNames];
	if ([matchNames isKindOfClass:NSNumber.class]) {
		options = [matchNames boolValue] ? (options | FxGripFCPXMLApplyMatchNames) : (options & ~FxGripFCPXMLApplyMatchNames);
	}
	id undo = settings[kFxGripWorkflowProperty_Undo];
	if ([undo isKindOfClass:NSNumber.class]) {
		options = [undo boolValue] ? (options | FxGripFCPXMLApplyUndoGroup) : (options & ~FxGripFCPXMLApplyUndoGroup);
	}
	id keyframes = settings[kFxGripWorkflowProperty_Keyframes];
	if ([keyframes isKindOfClass:NSNumber.class]) {
		options = [keyframes boolValue] ? (options & ~FxGripFCPXMLApplyIgnoreKeyframes) : (options | FxGripFCPXMLApplyIgnoreKeyframes);
	}
	self.applyOptions = options;
}

#pragma mark - Lifecycle

- (void)extAddedToDocument:(NSNotification *)notification
{
	FxGripTileableEffect *effect = self.fxEffect;
	if (effect == nil || self.mailbox == nil || effect.pluginUUID.length == 0) {
		[self refreshStatus];
		return;
	}
	[self applySettings];
	FxGripWorkflowInstanceRecord *record = [[FxGripWorkflowInstanceRecord alloc] initWithPluginUUID:effect.pluginUUID
																						 sessionID:effect.sessionID];
	record.pluginDisplayName = effect.pluginDisplayName;
	record.pluginVersion = effect.pluginStringVersion;
	record.documentID = effect.projectDocumentID;
	record.hostBundleIdentifier = ((FxGripPluginInfo *)[FxGripPluginInfo sharedInstance]).hostBundleIdentifier;
	self.instanceRecord = record;
	[self refreshTimelineRange];
	[self writeRecord];
	[self startHeartbeat];
	__weak FxGripWorkflowRelay *weakSelf = self;
	self.changeToken = [self.mailbox observeChangesWithHandler:^{
		[weakSelf mailboxDidChange];
	}];
	[self refreshStatus];
	dispatch_async(dispatch_get_main_queue(), ^{
		[weakSelf mailboxDidChange];
	});
}

- (void)extParameterChanged:(NSNotification *)notification
{
	if (self.instanceRecord == nil) {
		return;
	}
	[self refreshTimelineRange];
	[self writeRecord];
}

- (void)refreshTimelineRange
{
	FxGripTileableEffect *effect = self.fxEffect;
	if (effect == nil || ![effect respondsToSelector:@selector(effectInPointOfTimeLine)]) {
		return;
	}
	self.instanceRecord.timelineInPoint = effect.effectInPointOfTimeLine;
	self.instanceRecord.timelineOutPoint = effect.effectOutPointOfTimeLine;
}

- (void)writeRecord
{
	FxGripWorkflowInstanceRecord *record = self.instanceRecord;
	if (record == nil) {
		return;
	}
	record.lastSeen = NSDate.date;
	NSError *error = nil;
	if (![self.mailbox writeInstanceRecord:record error:&error]) {
		NSLog(@"%s Error: could not write the workflow instance record: %@", __func__, error);
	}
}

#pragma mark - Heartbeat

- (void)startHeartbeat
{
	[self stopHeartbeat];
	dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
	uint64_t interval = (uint64_t)(MAX(self.heartbeatInterval, 1.0) * NSEC_PER_SEC);
	dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, interval), interval, NSEC_PER_SEC / 2);
	__weak FxGripWorkflowRelay *weakSelf = self;
	dispatch_source_set_event_handler(timer, ^{
		[weakSelf heartbeat];
	});
	dispatch_resume(timer);
	self.heartbeatTimer = timer;
}

- (void)stopHeartbeat
{
	if (_heartbeatTimer != nil) {
		dispatch_source_cancel(_heartbeatTimer);
		_heartbeatTimer = nil;
	}
}

- (void)heartbeat
{
	[self writeRecord];
	[self.mailbox removeInstanceRecordsStaleAfter:self.presenceWindow * 4];
	[self refreshStatus];
}

#pragma mark - Status

- (FxGripWorkflowLinkStatus)refreshStatus
{
	FxGripWorkflowLinkStatus status = FxGripWorkflowLinkStatusUnavailable;
	if (self.mailbox != nil) {
		status = [self.mailbox isExtensionPresentWithin:self.presenceWindow]
			? FxGripWorkflowLinkStatusConnected : FxGripWorkflowLinkStatusIdle;
	}
	if (status != self.status) {
		self.status = status;
		[self.effect.notifier postNotificationName:FxGripWorkflowRelayStatusChangedName object:self.effect
										  userInfo:@{FxGripWorkflowRelayStatusKey: @(status)}];
	}
	return status;
}

- (NSString *)statusDescription
{
	switch (self.status) {
		case FxGripWorkflowLinkStatusUnavailable:
			return @"Workflow link: unavailable (no App Group)";
		case FxGripWorkflowLinkStatusIdle:
			return @"Workflow link: ready; no workflow extension present";
		case FxGripWorkflowLinkStatusConnected:
			return @"Workflow link: connected";
	}
	return @"Workflow link: unknown";
}

#pragma mark - Inbox

- (void)mailboxDidChange
{
	[self refreshStatus];
	if (self.appliesOnReceive) {
		[self processInbox];
	}
}

- (NSUInteger)processInbox
{
	FxGripWorkflowInstanceRecord *record = self.instanceRecord;
	if (record == nil || self.mailbox == nil || self.processing) {
		return 0;
	}
	self.processing = YES;
	NSUInteger applied = 0;
	NSArray<FxGripWorkflowMessage *> *messages = [self.mailbox inboxMessagesForPluginUUID:record.pluginUUID sessionID:record.sessionID];
	for (FxGripWorkflowMessage *message in messages) {
		FxGripFCPXMLDocument *document = message.document;
		if (document == nil) {
			[self.mailbox removeMessage:message error:NULL];
			continue;
		}
		if (self.documentHandler != nil && !self.documentHandler(document, message)) {
			continue;
		}
		NSError *error = [self applyDocument:document];
		if (error != nil) {
			NSLog(@"%s Error: could not apply workflow document %@: %@", __func__, message.identifier, error);
		} else {
			applied += 1;
			[self.effect.notifier postNotificationName:FxGripWorkflowRelayDidApplyDocumentName object:self.effect
											  userInfo:@{FxGripWorkflowRelayMessageIdentifierKey: message.identifier}];
		}
		// A broadcast message is for every instance; the sender clears it. An addressed one is
		// consumed here.
		if (message.sessionID != 0) {
			[self.mailbox removeMessage:message error:NULL];
		}
	}
	self.processing = NO;
	return applied;
}

- (NSError *)applyDocument:(FxGripFCPXMLDocument *)document
{
	FxGripTileableEffect *effect = self.fxEffect;
	id<FxGripFCPXMLAPI_v1> api = effect.apiManager.fcpxmlAPIv1;
	if (api == nil) {
		return [NSError errorWithDomain:FxGripPlugErrorDomain code:kFxGripError_FCPXML
							   userInfo:@{NSLocalizedDescriptionKey: @"The FCPXML API is unavailable."}];
	}
	FxGripOOBParameterAccess *accessor = [effect startContextFlush];
	CMTime time = accessor.currentTime;
	if (!CMTIME_IS_NUMERIC(time)) {
		time = kCMTimeZero;
	}
	NSError *error = [api applyDocument:document atTime:time options:self.applyOptions];
	accessor.active = NO;
	return error;
}

#pragma mark - Outbox

- (FxGripWorkflowMessage *)publishCaptureNamed:(NSString *)name options:(FxGripFCPXMLCaptureOptions)options error:(NSError **)error
{
	FxGripTileableEffect *effect = self.fxEffect;
	FxGripWorkflowInstanceRecord *record = self.instanceRecord;
	if (self.mailbox == nil || record == nil) {
		if (error) {
			*error = [NSError errorWithDomain:FxGripPlugErrorDomain code:kFxGripError_WorkflowUnavailable
									 userInfo:@{NSLocalizedDescriptionKey: @"The workflow mailbox is unavailable."}];
		}
		return nil;
	}
	id<FxGripFCPXMLAPI_v1> api = effect.apiManager.fcpxmlAPIv1;
	FxGripOOBParameterAccess *accessor = [effect startContext];
	CMTime time = accessor.currentTime;
	if (!CMTIME_IS_NUMERIC(time)) {
		time = kCMTimeZero;
	}
	FxGripFCPXMLDocument *document = nil;
	NSError *captureError = [api captureDocument:&document atTime:time options:options];
	accessor.active = NO;
	if (captureError != nil || document == nil) {
		if (error) {
			*error = captureError;
		}
		return nil;
	}
	FxGripWorkflowMessage *message = [self.mailbox publishDocument:document fromPluginUUID:record.pluginUUID
														sessionID:record.sessionID name:name ?: effect.pluginDisplayName error:error];
	if (message != nil) {
		[self.mailbox postChangeNotification];
	}
	return message;
}

@end

#pragma mark - Effect category

@implementation FxGripTileableEffect (Workflow)

- (FxGripWorkflowRelay *)workflowRelay
{
	return (FxGripWorkflowRelay *)[self extensionForClass:FxGripWorkflowRelay.class];
}

- (BOOL)isWorkflowEnabled
{
	id workflow = self.pluginProperties.pluginWorkflow;
	if ([workflow isKindOfClass:NSDictionary.class]) {
		return YES;
	}
	return [workflow isKindOfClass:NSNumber.class] && [workflow boolValue];
}

- (FxGripWorkflowRelay *)newWorkflowRelay
{
	return [[FxGripWorkflowRelay alloc] init];
}

- (id<FxGripFCPXMLAPI_v1>)fcpxmlAPI
{
	return self.apiManager.fcpxmlAPIv1;
}

@end
