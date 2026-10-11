/*!
	@file       FxGripWorkflowMailbox.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripWorkflowMailbox
	@abstract   The shared mailbox between a plug-in and its Final Cut Pro workflow extension.
	@discussion Introduced in FxGrip 0.1.0. See FxGripWorkflowMailbox.h.
*/

#import <FxGrip/FxGripWorkflowMailbox.h>
#import <FxGrip/FxGripFCPXMLTime.h>
#import <FxGrip/FxGripErrors.h>
#import <Security/Security.h>
#import <unistd.h>
#import <fcntl.h>

NSNotificationName const FxGripWorkflowMailboxDidChangeNotification = @"com.belisoful.FxGrip.workflow.changed";
NSString *const FxGripWorkflowApplicationGroupsEntitlement = @"com.apple.security.application-groups";
NSString *const FxGripWorkflowMessageKindApply = @"apply";
NSString *const FxGripWorkflowMessageKindExport = @"export";

static NSString *const FxGripWorkflowRootFolder = @"Library/Application Support/FxGripWorkflow";
static NSString *const FxGripWorkflowInstancesFolder = @"instances";
static NSString *const FxGripWorkflowInboxFolder = @"inbox";
static NSString *const FxGripWorkflowOutboxFolder = @"outbox";
static NSString *const FxGripWorkflowExtensionFile = @"extension.plist";
static NSString *const FxGripWorkflowMessageExtension = @"fxgripmsg";

static NSError *FxGripWorkflowError(NSInteger code, NSString *description)
{
	return [NSError errorWithDomain:FxGripPlugErrorDomain code:code
						   userInfo:@{NSLocalizedDescriptionKey: description}];
}

static NSDictionary *FxGripWorkflowTimeDictionary(CMTime time)
{
	if (!CMTIME_IS_NUMERIC(time)) {
		return nil;
	}
	return (__bridge_transfer NSDictionary *)CMTimeCopyAsDictionary(time, kCFAllocatorDefault);
}

static CMTime FxGripWorkflowTimeFromDictionary(id dictionary)
{
	if (![dictionary isKindOfClass:NSDictionary.class]) {
		return kCMTimeInvalid;
	}
	return CMTimeMakeFromDictionary((__bridge CFDictionaryRef)dictionary);
}

#pragma mark - Instance record

@implementation FxGripWorkflowInstanceRecord

- (instancetype)initWithPluginUUID:(NSString *)pluginUUID sessionID:(UInt64)sessionID
{
	self = [super init];
	if (self) {
		_pluginUUID = [pluginUUID copy] ?: @"";
		_sessionID = sessionID;
		_processIdentifier = getpid();
		_timelineInPoint = kCMTimeInvalid;
		_timelineOutPoint = kCMTimeInvalid;
		_lastSeen = NSDate.date;
	}
	return self;
}

- (instancetype)initWithDictionary:(NSDictionary<NSString *, id> *)dictionary
{
	NSString *uuid = dictionary[@"pluginUUID"];
	if (![uuid isKindOfClass:NSString.class] || uuid.length == 0) {
		return nil;
	}
	self = [self initWithPluginUUID:uuid sessionID:[dictionary[@"sessionID"] unsignedLongLongValue]];
	if (self) {
		id name = dictionary[@"pluginDisplayName"];
		_pluginDisplayName = [name isKindOfClass:NSString.class] ? name : nil;
		id version = dictionary[@"pluginVersion"];
		_pluginVersion = [version isKindOfClass:NSString.class] ? version : nil;
		_documentID = [dictionary[@"documentID"] unsignedIntegerValue];
		id host = dictionary[@"hostBundleIdentifier"];
		_hostBundleIdentifier = [host isKindOfClass:NSString.class] ? host : nil;
		_processIdentifier = [dictionary[@"processIdentifier"] intValue];
		_timelineInPoint = FxGripWorkflowTimeFromDictionary(dictionary[@"timelineInPoint"]);
		_timelineOutPoint = FxGripWorkflowTimeFromDictionary(dictionary[@"timelineOutPoint"]);
		id lastSeen = dictionary[@"lastSeen"];
		_lastSeen = [lastSeen isKindOfClass:NSDate.class] ? lastSeen : NSDate.date;
	}
	return self;
}

- (NSDictionary<NSString *, id> *)dictionaryRepresentation
{
	NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
	dictionary[@"pluginUUID"] = self.pluginUUID;
	dictionary[@"sessionID"] = @(self.sessionID);
	dictionary[@"documentID"] = @(self.documentID);
	dictionary[@"processIdentifier"] = @(self.processIdentifier);
	dictionary[@"lastSeen"] = self.lastSeen ?: NSDate.date;
	if (self.pluginDisplayName != nil) {
		dictionary[@"pluginDisplayName"] = self.pluginDisplayName;
	}
	if (self.pluginVersion != nil) {
		dictionary[@"pluginVersion"] = self.pluginVersion;
	}
	if (self.hostBundleIdentifier != nil) {
		dictionary[@"hostBundleIdentifier"] = self.hostBundleIdentifier;
	}
	NSDictionary *inPoint = FxGripWorkflowTimeDictionary(self.timelineInPoint);
	if (inPoint != nil) {
		dictionary[@"timelineInPoint"] = inPoint;
	}
	NSDictionary *outPoint = FxGripWorkflowTimeDictionary(self.timelineOutPoint);
	if (outPoint != nil) {
		dictionary[@"timelineOutPoint"] = outPoint;
	}
	return dictionary;
}

- (NSString *)recordName
{
	return [NSString stringWithFormat:@"%d-%llu.plist", self.processIdentifier, self.sessionID];
}

- (BOOL)isStaleAfter:(NSTimeInterval)age
{
	return -[self.lastSeen timeIntervalSinceNow] > age;
}

- (id)copyWithZone:(NSZone *)zone
{
	return [[FxGripWorkflowInstanceRecord alloc] initWithDictionary:self.dictionaryRepresentation];
}

- (BOOL)isEqual:(id)object
{
	if (![object isKindOfClass:FxGripWorkflowInstanceRecord.class]) {
		return NO;
	}
	FxGripWorkflowInstanceRecord *other = object;
	return [other.pluginUUID isEqualToString:self.pluginUUID] && other.sessionID == self.sessionID
		&& other.processIdentifier == self.processIdentifier;
}

- (NSUInteger)hash
{
	return self.pluginUUID.hash ^ (NSUInteger)self.sessionID ^ (NSUInteger)self.processIdentifier;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ %@ session=%llu pid=%d>", self.className, self.pluginUUID,
			self.sessionID, self.processIdentifier];
}

@end

#pragma mark - Message

@interface FxGripWorkflowMessage ()
@property (readwrite, copy) NSString *identifier;
@property (readwrite, copy) NSString *kind;
@property (readwrite, copy) NSString *pluginUUID;
@property (readwrite) UInt64 sessionID;
@property (readwrite, copy, nullable) NSString *sender;
@property (readwrite, copy, nullable) NSString *name;
@property (readwrite, strong) NSDate *date;
@property (readwrite, strong) NSURL *fileURL;
@property (readwrite, copy) NSString *XMLString;
@property (strong) FxGripFCPXMLDocument *parsedDocument;
- (nullable instancetype)initWithFileURL:(NSURL *)fileURL;
+ (NSDictionary *)dictionaryForDocument:(FxGripFCPXMLDocument *)document kind:(NSString *)kind pluginUUID:(NSString *)pluginUUID
							  sessionID:(UInt64)sessionID sender:(NSString *)sender name:(NSString *)name identifier:(NSString *)identifier;
@end

@implementation FxGripWorkflowMessage

+ (NSDictionary *)dictionaryForDocument:(FxGripFCPXMLDocument *)document kind:(NSString *)kind pluginUUID:(NSString *)pluginUUID
							  sessionID:(UInt64)sessionID sender:(NSString *)sender name:(NSString *)name identifier:(NSString *)identifier
{
	NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
	dictionary[@"identifier"] = identifier;
	dictionary[@"kind"] = kind;
	dictionary[@"pluginUUID"] = pluginUUID;
	dictionary[@"sessionID"] = @(sessionID);
	dictionary[@"date"] = NSDate.date;
	dictionary[@"fcpxml"] = document.XMLString;
	if (sender != nil) {
		dictionary[@"sender"] = sender;
	}
	if (name != nil) {
		dictionary[@"name"] = name;
	}
	return dictionary;
}

- (instancetype)initWithFileURL:(NSURL *)fileURL
{
	NSDictionary *dictionary = [NSDictionary dictionaryWithContentsOfURL:fileURL error:NULL];
	NSString *xml = dictionary[@"fcpxml"];
	NSString *pluginUUID = dictionary[@"pluginUUID"];
	if (![xml isKindOfClass:NSString.class] || ![pluginUUID isKindOfClass:NSString.class]) {
		return nil;
	}
	self = [super init];
	if (self) {
		id identifier = dictionary[@"identifier"];
		_identifier = [identifier isKindOfClass:NSString.class] ? identifier : fileURL.lastPathComponent.stringByDeletingPathExtension;
		id kind = dictionary[@"kind"];
		_kind = [kind isKindOfClass:NSString.class] ? kind : FxGripWorkflowMessageKindApply;
		_pluginUUID = pluginUUID;
		_sessionID = [dictionary[@"sessionID"] unsignedLongLongValue];
		id sender = dictionary[@"sender"];
		_sender = [sender isKindOfClass:NSString.class] ? sender : nil;
		id name = dictionary[@"name"];
		_name = [name isKindOfClass:NSString.class] ? name : nil;
		id date = dictionary[@"date"];
		_date = [date isKindOfClass:NSDate.class] ? date : NSDate.date;
		_fileURL = fileURL;
		_XMLString = xml;
	}
	return self;
}

- (FxGripFCPXMLDocument *)document
{
	if (self.parsedDocument == nil) {
		self.parsedDocument = [[FxGripFCPXMLDocument alloc] initWithXMLString:self.XMLString error:NULL];
	}
	return self.parsedDocument;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ %@ %@ plugin=%@ session=%llu>", self.className, self.kind,
			self.identifier, self.pluginUUID, self.sessionID];
}

@end

#pragma mark - Mailbox

@interface FxGripWorkflowChangeObserver : NSObject
@property (copy) void (^handler)(void);
@property (strong) dispatch_source_t source;
@property (assign) int descriptor;
@property (strong) id distributedToken;
@property (assign) BOOL pending;
@end

@implementation FxGripWorkflowChangeObserver

- (void)fire
{
	if (self.pending) {
		return;
	}
	self.pending = YES;
	// Coalesce bursts: a message write touches the folder several times.
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		self.pending = NO;
		if (self.handler) {
			self.handler();
		}
	});
}

- (void)dealloc
{
	if (_distributedToken != nil) {
		[NSDistributedNotificationCenter.defaultCenter removeObserver:_distributedToken];
	}
	if (_source != nil) {
		dispatch_source_cancel(_source);
	}
}

@end

@implementation FxGripWorkflowMailbox

+ (NSArray<NSString *> *)applicationGroupIdentifiers
{
	SecTaskRef task = SecTaskCreateFromSelf(kCFAllocatorDefault);
	if (task == NULL) {
		return @[];
	}
	CFTypeRef value = SecTaskCopyValueForEntitlement(task, (__bridge CFStringRef)FxGripWorkflowApplicationGroupsEntitlement, NULL);
	CFRelease(task);
	if (value == NULL) {
		return @[];
	}
	NSArray *groups = (__bridge_transfer id)value;
	if (![groups isKindOfClass:NSArray.class]) {
		return @[];
	}
	NSMutableArray *strings = [NSMutableArray array];
	for (id group in groups) {
		if ([group isKindOfClass:NSString.class]) {
			[strings addObject:group];
		}
	}
	return strings;
}

+ (instancetype)sharedMailbox
{
	NSString *group = self.applicationGroupIdentifiers.firstObject;
	return group ? [[self alloc] initWithApplicationGroup:group] : nil;
}

- (instancetype)initWithApplicationGroup:(NSString *)group
{
	NSURL *container = [NSFileManager.defaultManager containerURLForSecurityApplicationGroupIdentifier:group];
	if (container == nil) {
		return nil;
	}
	return [self initWithRootURL:[container URLByAppendingPathComponent:FxGripWorkflowRootFolder isDirectory:YES]];
}

- (instancetype)initWithRootURL:(NSURL *)rootURL
{
	self = [super init];
	if (self) {
		_rootURL = rootURL;
	}
	return self;
}

- (instancetype)init
{
	return [self initWithRootURL:[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES]];
}

#pragma mark Folders

- (NSURL *)instancesURL
{
	return [self.rootURL URLByAppendingPathComponent:FxGripWorkflowInstancesFolder isDirectory:YES];
}

- (NSURL *)inboxURLForPluginUUID:(NSString *)pluginUUID
{
	return [[self.rootURL URLByAppendingPathComponent:FxGripWorkflowInboxFolder isDirectory:YES]
			URLByAppendingPathComponent:pluginUUID.uppercaseString isDirectory:YES];
}

- (NSURL *)outboxURL
{
	return [self.rootURL URLByAppendingPathComponent:FxGripWorkflowOutboxFolder isDirectory:YES];
}

- (BOOL)ensureFolder:(NSURL *)url error:(NSError **)error
{
	return [NSFileManager.defaultManager createDirectoryAtURL:url withIntermediateDirectories:YES attributes:nil error:error];
}

- (NSArray<NSURL *> *)filesInFolder:(NSURL *)folder withExtension:(NSString *)extension
{
	NSArray<NSURL *> *contents = [NSFileManager.defaultManager contentsOfDirectoryAtURL:folder
															 includingPropertiesForKeys:@[NSURLContentModificationDateKey]
																				options:NSDirectoryEnumerationSkipsHiddenFiles
																				  error:NULL];
	NSMutableArray *files = [NSMutableArray array];
	for (NSURL *url in contents) {
		if ([url.pathExtension caseInsensitiveCompare:extension] == NSOrderedSame) {
			[files addObject:url];
		}
	}
	return files;
}

#pragma mark Instances

- (BOOL)writeInstanceRecord:(FxGripWorkflowInstanceRecord *)record error:(NSError **)error
{
	if (record.pluginUUID.length == 0) {
		if (error) {
			*error = FxGripWorkflowError(kFxGripError_WorkflowMailbox, @"The instance record has no plug-in UUID.");
		}
		return NO;
	}
	NSURL *folder = [self.instancesURL URLByAppendingPathComponent:record.pluginUUID.uppercaseString isDirectory:YES];
	if (![self ensureFolder:folder error:error]) {
		return NO;
	}
	NSURL *file = [folder URLByAppendingPathComponent:record.recordName];
	return [record.dictionaryRepresentation writeToURL:file error:error];
}

- (BOOL)removeInstanceRecord:(FxGripWorkflowInstanceRecord *)record error:(NSError **)error
{
	NSURL *file = [[self.instancesURL URLByAppendingPathComponent:record.pluginUUID.uppercaseString isDirectory:YES]
				   URLByAppendingPathComponent:record.recordName];
	if (![NSFileManager.defaultManager fileExistsAtPath:file.path]) {
		return YES;
	}
	return [NSFileManager.defaultManager removeItemAtURL:file error:error];
}

- (NSArray<FxGripWorkflowInstanceRecord *> *)instanceRecords
{
	NSMutableArray *records = [NSMutableArray array];
	NSArray<NSURL *> *folders = [NSFileManager.defaultManager contentsOfDirectoryAtURL:self.instancesURL
															includingPropertiesForKeys:nil
																			   options:NSDirectoryEnumerationSkipsHiddenFiles
																				 error:NULL];
	for (NSURL *folder in folders) {
		[records addObjectsFromArray:[self instanceRecordsInFolder:folder]];
	}
	return [self sortedRecords:records];
}

- (NSArray<FxGripWorkflowInstanceRecord *> *)instanceRecordsInFolder:(NSURL *)folder
{
	NSMutableArray *records = [NSMutableArray array];
	for (NSURL *file in [self filesInFolder:folder withExtension:@"plist"]) {
		NSDictionary *dictionary = [NSDictionary dictionaryWithContentsOfURL:file error:NULL];
		FxGripWorkflowInstanceRecord *record = dictionary ? [[FxGripWorkflowInstanceRecord alloc] initWithDictionary:dictionary] : nil;
		if (record != nil) {
			[records addObject:record];
		}
	}
	return records;
}

- (NSArray<FxGripWorkflowInstanceRecord *> *)sortedRecords:(NSArray<FxGripWorkflowInstanceRecord *> *)records
{
	return [records sortedArrayUsingComparator:^NSComparisonResult(FxGripWorkflowInstanceRecord *lhs, FxGripWorkflowInstanceRecord *rhs) {
		return [rhs.lastSeen compare:lhs.lastSeen];
	}];
}

- (NSArray<FxGripWorkflowInstanceRecord *> *)instanceRecordsForPluginUUID:(NSString *)pluginUUID
{
	NSURL *folder = [self.instancesURL URLByAppendingPathComponent:pluginUUID.uppercaseString isDirectory:YES];
	return [self sortedRecords:[self instanceRecordsInFolder:folder]];
}

- (NSUInteger)removeInstanceRecordsStaleAfter:(NSTimeInterval)age
{
	NSUInteger removed = 0;
	for (FxGripWorkflowInstanceRecord *record in self.instanceRecords) {
		if ([record isStaleAfter:age] && [self removeInstanceRecord:record error:NULL]) {
			removed += 1;
		}
	}
	return removed;
}

#pragma mark Extension presence

- (BOOL)writeExtensionPresenceWithBundleIdentifier:(NSString *)bundleIdentifier version:(NSString *)version error:(NSError **)error
{
	if (![self ensureFolder:self.rootURL error:error]) {
		return NO;
	}
	NSMutableDictionary *presence = [NSMutableDictionary dictionary];
	presence[@"bundleIdentifier"] = bundleIdentifier ?: @"";
	presence[@"lastSeen"] = NSDate.date;
	presence[@"processIdentifier"] = @(getpid());
	if (version != nil) {
		presence[@"version"] = version;
	}
	return [presence writeToURL:[self.rootURL URLByAppendingPathComponent:FxGripWorkflowExtensionFile] error:error];
}

- (NSDictionary<NSString *, id> *)extensionPresence
{
	return [NSDictionary dictionaryWithContentsOfURL:[self.rootURL URLByAppendingPathComponent:FxGripWorkflowExtensionFile] error:NULL];
}

- (BOOL)isExtensionPresentWithin:(NSTimeInterval)age
{
	id lastSeen = self.extensionPresence[@"lastSeen"];
	return [lastSeen isKindOfClass:NSDate.class] && -[lastSeen timeIntervalSinceNow] <= age;
}

#pragma mark Messages

- (FxGripWorkflowMessage *)writeMessageForDocument:(FxGripFCPXMLDocument *)document
											  kind:(NSString *)kind
											folder:(NSURL *)folder
										pluginUUID:(NSString *)pluginUUID
										 sessionID:(UInt64)sessionID
											sender:(NSString *)sender
											  name:(NSString *)name
											 error:(NSError **)error
{
	if (document == nil || pluginUUID.length == 0) {
		if (error) {
			*error = FxGripWorkflowError(kFxGripError_WorkflowMailbox, @"A message needs a document and a plug-in UUID.");
		}
		return nil;
	}
	if (![self ensureFolder:folder error:error]) {
		return nil;
	}
	NSString *identifier = NSUUID.UUID.UUIDString;
	// The file name sorts by time, then by a per-process sequence, so a reader processes messages in
	// the order written even when two land in the same microsecond.
	static int64_t sequence = 0;
	int64_t ordinal = __atomic_add_fetch(&sequence, 1, __ATOMIC_RELAXED);
	NSString *fileName = [NSString stringWithFormat:@"%017.6f-%06lld-%@.%@", NSDate.date.timeIntervalSinceReferenceDate,
						  ordinal, identifier, FxGripWorkflowMessageExtension];
	NSURL *file = [folder URLByAppendingPathComponent:fileName];
	NSDictionary *dictionary = [FxGripWorkflowMessage dictionaryForDocument:document kind:kind pluginUUID:pluginUUID.uppercaseString
																 sessionID:sessionID sender:sender name:name identifier:identifier];
	if (![dictionary writeToURL:file error:error]) {
		return nil;
	}
	return [[FxGripWorkflowMessage alloc] initWithFileURL:file];
}

- (FxGripWorkflowMessage *)enqueueDocument:(FxGripFCPXMLDocument *)document forPluginUUID:(NSString *)pluginUUID
								 sessionID:(UInt64)sessionID sender:(NSString *)sender name:(NSString *)name error:(NSError **)error
{
	return [self writeMessageForDocument:document kind:FxGripWorkflowMessageKindApply
								  folder:[self inboxURLForPluginUUID:pluginUUID] pluginUUID:pluginUUID
							   sessionID:sessionID sender:sender name:name error:error];
}

- (NSArray<FxGripWorkflowMessage *> *)messagesInFolder:(NSURL *)folder
{
	NSMutableArray *messages = [NSMutableArray array];
	NSArray<NSURL *> *files = [[self filesInFolder:folder withExtension:FxGripWorkflowMessageExtension]
							   sortedArrayUsingComparator:^NSComparisonResult(NSURL *lhs, NSURL *rhs) {
		return [lhs.lastPathComponent compare:rhs.lastPathComponent];
	}];
	for (NSURL *file in files) {
		FxGripWorkflowMessage *message = [[FxGripWorkflowMessage alloc] initWithFileURL:file];
		if (message != nil) {
			[messages addObject:message];
		}
	}
	return messages;
}

- (NSArray<FxGripWorkflowMessage *> *)inboxMessagesForPluginUUID:(NSString *)pluginUUID
{
	return [self messagesInFolder:[self inboxURLForPluginUUID:pluginUUID]];
}

- (NSArray<FxGripWorkflowMessage *> *)inboxMessagesForPluginUUID:(NSString *)pluginUUID sessionID:(UInt64)sessionID
{
	NSMutableArray *messages = [NSMutableArray array];
	for (FxGripWorkflowMessage *message in [self inboxMessagesForPluginUUID:pluginUUID]) {
		if (message.sessionID == 0 || message.sessionID == sessionID) {
			[messages addObject:message];
		}
	}
	return messages;
}

- (FxGripWorkflowMessage *)publishDocument:(FxGripFCPXMLDocument *)document fromPluginUUID:(NSString *)pluginUUID
								 sessionID:(UInt64)sessionID name:(NSString *)name error:(NSError **)error
{
	return [self writeMessageForDocument:document kind:FxGripWorkflowMessageKindExport folder:self.outboxURL
							  pluginUUID:pluginUUID sessionID:sessionID sender:nil name:name error:error];
}

- (NSArray<FxGripWorkflowMessage *> *)outboxMessages
{
	return [self messagesInFolder:self.outboxURL];
}

- (BOOL)removeMessage:(FxGripWorkflowMessage *)message error:(NSError **)error
{
	if (message.fileURL == nil || ![NSFileManager.defaultManager fileExistsAtPath:message.fileURL.path]) {
		return YES;
	}
	return [NSFileManager.defaultManager removeItemAtURL:message.fileURL error:error];
}

- (NSUInteger)removeAllMessages
{
	NSUInteger removed = 0;
	NSMutableArray<FxGripWorkflowMessage *> *messages = [self.outboxMessages mutableCopy];
	NSURL *inboxRoot = [self.rootURL URLByAppendingPathComponent:FxGripWorkflowInboxFolder isDirectory:YES];
	NSArray<NSURL *> *folders = [NSFileManager.defaultManager contentsOfDirectoryAtURL:inboxRoot includingPropertiesForKeys:nil
																			   options:NSDirectoryEnumerationSkipsHiddenFiles error:NULL];
	for (NSURL *folder in folders) {
		[messages addObjectsFromArray:[self messagesInFolder:folder]];
	}
	for (FxGripWorkflowMessage *message in messages) {
		if ([self removeMessage:message error:NULL]) {
			removed += 1;
		}
	}
	return removed;
}

#pragma mark Change notification

- (void)postChangeNotification
{
	// A sandboxed process may post a distributed notification but not attach a userInfo; the
	// receiver re-reads the mailbox.
	[NSDistributedNotificationCenter.defaultCenter postNotificationName:FxGripWorkflowMailboxDidChangeNotification
																 object:nil userInfo:nil
													 deliverImmediately:YES];
}

- (id)observeChangesWithHandler:(void (^)(void))handler
{
	FxGripWorkflowChangeObserver *observer = [[FxGripWorkflowChangeObserver alloc] init];
	observer.handler = handler;
	__weak FxGripWorkflowChangeObserver *weakObserver = observer;
	observer.distributedToken = [NSDistributedNotificationCenter.defaultCenter
								 addObserverForName:FxGripWorkflowMailboxDidChangeNotification object:nil
								 queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
		[weakObserver fire];
	}];
	[self ensureFolder:self.rootURL error:NULL];
	int descriptor = open(self.rootURL.fileSystemRepresentation, O_EVTONLY);
	if (descriptor >= 0) {
		dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE, (uintptr_t)descriptor,
														  DISPATCH_VNODE_WRITE | DISPATCH_VNODE_EXTEND | DISPATCH_VNODE_RENAME | DISPATCH_VNODE_DELETE,
														  dispatch_get_main_queue());
		dispatch_source_set_event_handler(source, ^{
			[weakObserver fire];
		});
		dispatch_source_set_cancel_handler(source, ^{
			close(descriptor);
		});
		dispatch_resume(source);
		observer.source = source;
		observer.descriptor = descriptor;
	}
	return observer;
}

@end
