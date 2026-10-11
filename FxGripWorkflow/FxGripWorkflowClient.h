/*!
	@file       FxGripWorkflowClient.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripWorkflowClient
	@abstract   The workflow extension's side of the mailbox to the plug-in instances.
	@discussion Introduced in FxGrip 0.1.0. The client announces the extension's presence, which the
	            plug-ins' relays report as a connected link, lists the live plug-in instances, sends
	            FCPXML documents to one instance or to every instance of a plug-in, and collects the
	            documents the plug-ins published. It wraps ``FxGripWorkflowMailbox`` and shares its
	            App Group discovery.
*/

#ifndef FxGripWorkflowClient_h
#define FxGripWorkflowClient_h

#import <Foundation/Foundation.h>
#import <FxGrip/FxGripWorkflowMailbox.h>

NS_ASSUME_NONNULL_BEGIN

@class FxGripWorkflowClient;

/*! Runs on the main queue after the mailbox changes. */
typedef void (^FxGripWorkflowClientChangeHandler)(FxGripWorkflowClient *client);

/*!
	@class      FxGripWorkflowClient
	@abstract   The extension's mailbox client.
	@discussion Introduced in FxGrip 0.1.0. `start` writes the presence record, refreshes it on a
				timer, and begins observing; `stop` ends both. An instance whose record is older
				than `instanceWindow` is left out of `instances`.
*/
@interface FxGripWorkflowClient : NSObject

/*! The client over the shared mailbox, or nil when the process has no App Group. */
+ (nullable instancetype)sharedClient;

/*! A client over an explicit mailbox. */
- (instancetype)initWithMailbox:(FxGripWorkflowMailbox *)mailbox NS_DESIGNATED_INITIALIZER;

/*! The mailbox. */
@property (readonly, strong) FxGripWorkflowMailbox *mailbox;
/*! The identifier written in the presence record; the main bundle's by default. */
@property (readwrite, copy) NSString *bundleIdentifier;
/*! The version written in the presence record; the main bundle's short version by default. */
@property (readwrite, copy, nullable) NSString *version;
/*! Seconds between presence refreshes; default 10. */
@property (readwrite) NSTimeInterval heartbeatInterval;
/*! Seconds within which an instance record counts as live; default 60. */
@property (readwrite) NSTimeInterval instanceWindow;
/*! YES between `start` and `stop`. */
@property (readonly) BOOL isStarted;
/*! Runs after the mailbox changes, on the main queue. */
@property (readwrite, copy, nullable) FxGripWorkflowClientChangeHandler changeHandler;

/*! Writes the presence record, starts the heartbeat, and observes the mailbox. */
- (void)start;
/*! Stops the heartbeat and the observation. */
- (void)stop;
/*! Writes the presence record now. */
- (void)heartbeat;

#pragma mark Instances

/*! The live plug-in instances, newest first. */
@property (readonly, copy) NSArray<FxGripWorkflowInstanceRecord *> *instances;
/*! The live instances of one plug-in, newest first. */
- (NSArray<FxGripWorkflowInstanceRecord *> *)instancesOfPluginUUID:(NSString *)pluginUUID;
/*! The plug-in UUIDs with a live instance, sorted. */
@property (readonly, copy) NSArray<NSString *> *pluginUUIDs;

#pragma mark Sending

/*! Queues a document for one instance. */
- (nullable FxGripWorkflowMessage *)sendDocument:(FxGripFCPXMLDocument *)document
									  toInstance:(FxGripWorkflowInstanceRecord *)instance
											name:(nullable NSString *)name
										   error:(NSError * _Nullable * _Nullable)error;

/*! Queues a document for every instance of a plug-in. */
- (nullable FxGripWorkflowMessage *)sendDocument:(FxGripFCPXMLDocument *)document
									toPluginUUID:(NSString *)pluginUUID
											name:(nullable NSString *)name
										   error:(NSError * _Nullable * _Nullable)error;

/*! Removes broadcast messages older than an age in seconds; returns the count removed. A
	broadcast stays for every instance, so the sender clears it. */
- (NSUInteger)removeBroadcastsOlderThan:(NSTimeInterval)age;

#pragma mark Receiving

/*! The documents plug-ins published, oldest first. */
@property (readonly, copy) NSArray<FxGripWorkflowMessage *> *exports;
/*! Removes a published document once it has been taken. */
- (BOOL)removeExport:(FxGripWorkflowMessage *)message error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripWorkflowClient_h */
