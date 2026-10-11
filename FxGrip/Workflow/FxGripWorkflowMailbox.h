/*!
	@file       FxGripWorkflowMailbox.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripWorkflowMailbox
	@abstract   The shared mailbox between a plug-in and its Final Cut Pro workflow extension.
	@discussion Introduced in FxGrip 0.1.0. An FxPlug plug-in and a workflow extension run in
	            separate sandboxed processes. A sandboxed process can neither register a Mach
	            service nor attach a userInfo to a distributed notification, so the two sides
	            talk through files in the App Group container they share, and nudge each other
	            with a name-only distributed notification. The mailbox holds three things:

	- instance records, one per live plug-in instance, which tell the extension what it can
	  address;
	- an inbox per plug-in, where the extension drops FCPXML documents for the plug-in's
	  instances to apply;
	- an outbox, where a plug-in publishes documents it captured for the extension.

	A message is one property-list file written atomically, so a reader never sees a
	partial write. Both sides find the container from their own code-signing entitlements,
	so nothing names the App Group in code.
*/

#ifndef FxGripWorkflowMailbox_h
#define FxGripWorkflowMailbox_h

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <FxGrip/FxGripFCPXMLDocument.h>

NS_ASSUME_NONNULL_BEGIN

/*! The name-only distributed notification either side posts after a mailbox change. */
FOUNDATION_EXPORT NSNotificationName const FxGripWorkflowMailboxDidChangeNotification;
/*! The sandbox entitlement that lists the process's App Groups. */
FOUNDATION_EXPORT NSString *const FxGripWorkflowApplicationGroupsEntitlement;
/*! The message kind for a document the extension asks a plug-in to apply. */
FOUNDATION_EXPORT NSString *const FxGripWorkflowMessageKindApply;
/*! The message kind for a document a plug-in published for the extension. */
FOUNDATION_EXPORT NSString *const FxGripWorkflowMessageKindExport;

/*!
	@class      FxGripWorkflowInstanceRecord
	@abstract   One live plug-in instance, as the extension sees it.
	@discussion Introduced in FxGrip 0.1.0. The record is a property list; `lastSeen` is refreshed
				by the plug-in's heartbeat, and a stale record belongs to an instance that went
				away without removing it.
*/
@interface FxGripWorkflowInstanceRecord : NSObject <NSCopying>

/*! The plug-in UUID. */
@property (readwrite, copy) NSString *pluginUUID;
/*! The plug-in's display name. */
@property (readwrite, copy, nullable) NSString *pluginDisplayName;
/*! The plug-in's version string. */
@property (readwrite, copy, nullable) NSString *pluginVersion;
/*! The instance's render session identifier, which addresses it within the plug-in. */
@property (readwrite) UInt64 sessionID;
/*! The host document identifier the instance belongs to; 0 in Motion. */
@property (readwrite) NSUInteger documentID;
/*! The host application's bundle identifier. */
@property (readwrite, copy, nullable) NSString *hostBundleIdentifier;
/*! The plug-in process identifier. */
@property (readwrite) int processIdentifier;
/*! The instance's in point on the timeline, or `kCMTimeInvalid`. */
@property (readwrite) CMTime timelineInPoint;
/*! The instance's out point on the timeline, or `kCMTimeInvalid`. */
@property (readwrite) CMTime timelineOutPoint;
/*! When the plug-in last refreshed the record. */
@property (readwrite, strong) NSDate *lastSeen;

/*! A record for a plug-in UUID and session. */
- (instancetype)initWithPluginUUID:(NSString *)pluginUUID sessionID:(UInt64)sessionID;
/*! A record from its property-list form, or nil when the form lacks a plug-in UUID. */
- (nullable instancetype)initWithDictionary:(NSDictionary<NSString *, id> *)dictionary;
/*! The property-list form. */
- (NSDictionary<NSString *, id> *)dictionaryRepresentation;
/*! The file name the record is stored under: the process and session identifiers. */
@property (readonly, copy) NSString *recordName;
/*! YES when `lastSeen` is older than an age in seconds. */
- (BOOL)isStaleAfter:(NSTimeInterval)age;

@end

/*!
	@class      FxGripWorkflowMessage
	@abstract   One queued document: a message file in an inbox or the outbox.
	@discussion Introduced in FxGrip 0.1.0.
*/
@interface FxGripWorkflowMessage : NSObject

/*! The message identifier, a UUID string. */
@property (readonly, copy) NSString *identifier;
/*! `FxGripWorkflowMessageKindApply` or `FxGripWorkflowMessageKindExport`. */
@property (readonly, copy) NSString *kind;
/*! The plug-in UUID the message is for or from. */
@property (readonly, copy) NSString *pluginUUID;
/*! The session the message is for or from; 0 addresses every instance of the plug-in. */
@property (readonly) UInt64 sessionID;
/*! Who wrote the message, such as the extension's bundle identifier. */
@property (readonly, copy, nullable) NSString *sender;
/*! A display name for the document. */
@property (readonly, copy, nullable) NSString *name;
/*! When the message was written. */
@property (readonly, strong) NSDate *date;
/*! The message file. */
@property (readonly, strong) NSURL *fileURL;
/*! The document the message carries, parsed on first access; nil when it does not parse. */
@property (readonly, nullable) FxGripFCPXMLDocument *document;
/*! The document's XML. */
@property (readonly, copy) NSString *XMLString;

@end

/*!
	@class      FxGripWorkflowMailbox
	@abstract   The files and notifications a plug-in and a workflow extension share.
	@discussion Introduced in FxGrip 0.1.0. Every method is safe to call from any thread; file
				writes are atomic. A mailbox over an explicit folder serves tests and tools.
*/
@interface FxGripWorkflowMailbox : NSObject

/*! The App Groups in the running process's code-signing entitlements. */
+ (NSArray<NSString *> *)applicationGroupIdentifiers;

/*! The mailbox in the first App Group the process is entitled to, or nil when it has none. */
+ (nullable instancetype)sharedMailbox;

/*! A mailbox in an App Group's container, or nil when the container is unavailable. */
- (nullable instancetype)initWithApplicationGroup:(NSString *)group;

/*! A mailbox over an explicit root folder, created on first write. */
- (instancetype)initWithRootURL:(NSURL *)rootURL NS_DESIGNATED_INITIALIZER;

/*! The root folder: `Library/Application Support/FxGripWorkflow` in the container. */
@property (readonly, strong) NSURL *rootURL;

#pragma mark Instances

/*! Writes a record, creating the folders as needed. */
- (BOOL)writeInstanceRecord:(FxGripWorkflowInstanceRecord *)record error:(NSError * _Nullable * _Nullable)error;
/*! Removes a record; YES when it is gone. */
- (BOOL)removeInstanceRecord:(FxGripWorkflowInstanceRecord *)record error:(NSError * _Nullable * _Nullable)error;
/*! Every record, newest first. */
- (NSArray<FxGripWorkflowInstanceRecord *> *)instanceRecords;
/*! The records of one plug-in, newest first. */
- (NSArray<FxGripWorkflowInstanceRecord *> *)instanceRecordsForPluginUUID:(NSString *)pluginUUID;
/*! Removes records not refreshed within an age in seconds; returns the count removed. */
- (NSUInteger)removeInstanceRecordsStaleAfter:(NSTimeInterval)age;

#pragma mark Extension presence

/*! Writes the extension's presence: its bundle identifier, version, and the time. */
- (BOOL)writeExtensionPresenceWithBundleIdentifier:(NSString *)bundleIdentifier
										   version:(nullable NSString *)version
											 error:(NSError * _Nullable * _Nullable)error;
/*! The extension's presence record, or nil when none was written. */
- (nullable NSDictionary<NSString *, id> *)extensionPresence;
/*! YES when the extension refreshed its presence within an age in seconds. */
- (BOOL)isExtensionPresentWithin:(NSTimeInterval)age;

#pragma mark Messages

/*!
	@method     enqueueDocument:forPluginUUID:sessionID:sender:name:error:
	@abstract   Drops a document in a plug-in's inbox.
	@param      document	The document to apply.
	@param      pluginUUID	The plug-in whose instances apply it.
	@param      sessionID	The instance to apply it, or 0 for every instance.
	@param      sender		The writer's identifier, or nil.
	@param      name		A display name, or nil.
	@param      error		On return, the reason the write failed.
	@return     The message, or nil.
*/
- (nullable FxGripWorkflowMessage *)enqueueDocument:(FxGripFCPXMLDocument *)document
									  forPluginUUID:(NSString *)pluginUUID
										  sessionID:(UInt64)sessionID
											 sender:(nullable NSString *)sender
											   name:(nullable NSString *)name
											  error:(NSError * _Nullable * _Nullable)error;

/*! The inbox messages for an instance: those addressed to its session and those addressed to
	every instance of the plug-in, oldest first. */
- (NSArray<FxGripWorkflowMessage *> *)inboxMessagesForPluginUUID:(NSString *)pluginUUID sessionID:(UInt64)sessionID;

/*! Every inbox message for a plug-in, oldest first. */
- (NSArray<FxGripWorkflowMessage *> *)inboxMessagesForPluginUUID:(NSString *)pluginUUID;

/*! Publishes a document from an instance to the outbox. */
- (nullable FxGripWorkflowMessage *)publishDocument:(FxGripFCPXMLDocument *)document
									   fromPluginUUID:(NSString *)pluginUUID
										   sessionID:(UInt64)sessionID
												name:(nullable NSString *)name
											   error:(NSError * _Nullable * _Nullable)error;

/*! The outbox messages, oldest first. */
- (NSArray<FxGripWorkflowMessage *> *)outboxMessages;

/*! Removes a message file. */
- (BOOL)removeMessage:(FxGripWorkflowMessage *)message error:(NSError * _Nullable * _Nullable)error;

/*! Removes every message; returns the count removed. */
- (NSUInteger)removeAllMessages;

#pragma mark Change notification

/*! Posts the change notification to every process. */
- (void)postChangeNotification;

/*!
	@method     observeChangesWithHandler:
	@abstract   Runs a handler after the mailbox changes.
	@discussion The handler runs on the main queue, on the distributed change notification and
				on file-system events under the root folder, coalesced. Release the returned
				token to stop observing.
*/
- (id)observeChangesWithHandler:(void (^)(void))handler;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripWorkflowMailbox_h */
