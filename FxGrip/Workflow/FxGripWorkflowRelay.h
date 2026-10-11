/*!
	@file       FxGripWorkflowRelay.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripWorkflowRelay
	@abstract   The extension that links a plug-in instance with a Final Cut Pro workflow extension.
	@discussion Introduced in FxGrip 0.1.0. The relay registers the instance in the shared
	            ``FxGripWorkflowMailbox`` when the effect joins a document, refreshes the record
	            on a heartbeat, watches the plug-in's inbox, and applies each document it finds
	            through ``FxGripFCPXMLAPI_v1`` out of band on the main thread. It also publishes a
	            capture of the effect to the outbox on request. Its link status is the capability
	            indicator a Status control shows: whether the mailbox exists and whether a
	            workflow extension is present. The relay never runs on a render path.
*/

#ifndef FxGripWorkflowRelay_h
#define FxGripWorkflowRelay_h

#import <FxGrip/FxGripExtension.h>
#import <FxGrip/FxGripTileableEffect.h>
#import <FxGrip/FxGripWorkflowMailbox.h>
#import <FxGrip/FxGripFCPXMLAPI_v1.h>

NS_ASSUME_NONNULL_BEGIN

// Settings keys, read from the `workflow` plugin property when it is a dictionary.

/*! Boolean: the relay applies inbox documents on arrival. Default YES. */
#define kFxGripWorkflowProperty_ApplyOnReceive		@"applyOnReceive"
/*! Number: seconds between heartbeats. Default 15. */
#define kFxGripWorkflowProperty_HeartbeatInterval	@"heartbeatInterval"
/*! Boolean: match a param by name when its key names no parameter. Default YES. */
#define kFxGripWorkflowProperty_MatchNames			@"matchNames"
/*! Boolean: bracket each applied document in an undo group. Default YES. */
#define kFxGripWorkflowProperty_Undo				@"undo"
/*! Boolean: apply the keyframes a document carries. Default YES. */
#define kFxGripWorkflowProperty_Keyframes			@"keyframes"

/*!
	@enum       FxGripWorkflowLinkStatus
	@abstract   How far the link to a workflow extension reaches.
	@discussion Introduced in FxGrip 0.1.0.
*/
typedef NS_ENUM(NSInteger, FxGripWorkflowLinkStatus) {
	/*! The process has no App Group container, so there is no mailbox. */
	FxGripWorkflowLinkStatusUnavailable = 0,
	/*! The mailbox exists; no workflow extension has reported itself recently. */
	FxGripWorkflowLinkStatusIdle,
	/*! A workflow extension refreshed its presence within the presence window. */
	FxGripWorkflowLinkStatusConnected,
};

/*! The extension key under which the effect stores the relay. */
FOUNDATION_EXPORT NSString *const FxGripWorkflowRelayExtensionKey;
/*! Posted on the effect's notifier after the relay applies a document. The userInfo carries the
	message identifier under `FxGripWorkflowRelayMessageIdentifierKey`. */
FOUNDATION_EXPORT NSNotificationName const FxGripWorkflowRelayDidApplyDocumentName;
/*! Posted on the effect's notifier when the link status changes. The userInfo carries the status
	under `FxGripWorkflowRelayStatusKey`. */
FOUNDATION_EXPORT NSNotificationName const FxGripWorkflowRelayStatusChangedName;
/*! userInfo key: the applied message's identifier. */
FOUNDATION_EXPORT NSString *const FxGripWorkflowRelayMessageIdentifierKey;
/*! userInfo key: the `FxGripWorkflowLinkStatus`, as an `NSNumber`. */
FOUNDATION_EXPORT NSString *const FxGripWorkflowRelayStatusKey;

/*! Decides whether the relay applies an inbox document; NO leaves the message in place. */
typedef BOOL (^FxGripWorkflowDocumentHandler)(FxGripFCPXMLDocument *document, FxGripWorkflowMessage *message);

/*!
	@class      FxGripWorkflowRelay
	@abstract   The extension that links a plug-in instance with a workflow extension.
	@discussion Introduced in FxGrip 0.1.0. The loader installs it when the `workflow` plugin
				property is `YES` or a settings dictionary.
*/
@interface FxGripWorkflowRelay : FxGripExtension

/*! Creates a relay over the shared mailbox; the mailbox is nil without an App Group. */
- (instancetype)init;
/*! Creates a relay over an explicit mailbox, for tests and tools. */
- (instancetype)initWithMailbox:(nullable FxGripWorkflowMailbox *)mailbox;

/*! The mailbox, or nil when the process has no App Group container. */
@property (readonly, nullable, strong) FxGripWorkflowMailbox *mailbox;
/*! The instance record the relay maintains; nil before the effect joins a document. */
@property (readonly, nullable, strong) FxGripWorkflowInstanceRecord *instanceRecord;
/*! The link status. */
@property (readonly) FxGripWorkflowLinkStatus status;
/*! The link status as a sentence for a Status control. */
@property (readonly, copy) NSString *statusDescription;

/*! Seconds between heartbeats; the plugin property sets it, default 15. */
@property (readwrite) NSTimeInterval heartbeatInterval;
/*! Seconds within which an extension presence counts as connected; default three heartbeats. */
@property (readwrite) NSTimeInterval presenceWindow;
/*! YES when inbox documents apply on arrival; the plugin property sets it, default YES. */
@property (readwrite) BOOL appliesOnReceive;
/*! The options each apply uses; the plugin property sets them. */
@property (readwrite) FxGripFCPXMLApplyOptions applyOptions;
/*! A handler that vets each inbox document before it applies, or nil to apply every one. */
@property (readwrite, copy, nullable) FxGripWorkflowDocumentHandler documentHandler;

/*! Registers the instance, starts the heartbeat, and watches the inbox. */
- (void)extAddedToDocument:(NSNotification *)notification;
/*! Refreshes the record's timeline range. */
- (void)extParameterChanged:(NSNotification *)notification;

/*!
	@method     processInbox
	@abstract   Applies the pending inbox documents for this instance.
	@discussion Runs the apply out of band on the main thread; call it from the main thread. Each
				applied message is removed. Returns the number applied.
*/
- (NSUInteger)processInbox;

/*!
	@method     publishCaptureNamed:options:error:
	@abstract   Captures the effect and publishes the document to the outbox.
	@return     The message, or nil with an error.
*/
- (nullable FxGripWorkflowMessage *)publishCaptureNamed:(nullable NSString *)name
												options:(FxGripFCPXMLCaptureOptions)options
												  error:(NSError * _Nullable * _Nullable)error;

/*! Refreshes the instance record now. */
- (void)heartbeat;

/*! Recomputes the status, posting the change notification when it moved. */
- (FxGripWorkflowLinkStatus)refreshStatus;

@end

/*!
	@abstract   The effect-side accessors for the workflow relay.
	@discussion Introduced in FxGrip 0.1.0.
*/
@interface FxGripTileableEffect (Workflow)

/*! The installed relay, or nil when none is installed. */
@property (readonly, nullable, nonatomic) FxGripWorkflowRelay *workflowRelay;
/*! YES when the plug-in opts into the relay through the `workflow` plugin property. */
@property (readonly, nonatomic) BOOL isWorkflowEnabled;
/*! Creates the relay for the loader to install. */
- (FxGripWorkflowRelay *)newWorkflowRelay;
/*! The FCPXML API, vended by the API manager. */
@property (readonly, nullable, nonatomic) id<FxGripFCPXMLAPI_v1> fcpxmlAPI;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripWorkflowRelay_h */
