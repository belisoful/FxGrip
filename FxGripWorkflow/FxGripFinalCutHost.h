/*!
	@file       FxGripFinalCutHost.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripFinalCutHost
	@abstract   The running Final Cut Pro as a workflow extension sees it.
	@discussion Introduced in FxGrip 0.1.0. A workflow extension has three routes into the host.
	            Final Cut Pro's scripting dictionary publishes the library model (libraries,
	            events, projects, sequences) read-only behind the
	            `com.apple.FinalCut.library.inspection` access group; the host client reads it
	            through Apple Events. Final Cut Pro imports an FCPXML file the extension opens, and
	            accepts FCPXML drags. Apple's Workflow Extensions SDK gives the extension executable
	            `ProExtensionHostSingleton()`, an `FCPXHost` whose `FCPXTimeline` reports the
	            playhead, the active sequence, and the sequence time range, and moves the playhead;
	            the client attaches that host when the extension links the SDK's library. Without it
	            the client observes the host's distributed timeline notification and forwards it
	            unparsed.
*/

#ifndef FxGripFinalCutHost_h
#define FxGripFinalCutHost_h

#import <AppKit/AppKit.h>
#import <CoreMedia/CoreMedia.h>
#import <FxGrip/FxGripFCPXMLDocument.h>

NS_ASSUME_NONNULL_BEGIN

/*! The distributed notification Final Cut Pro posts about its timeline. Its payload is
	undocumented; the client forwards it unparsed. */
FOUNDATION_EXPORT NSNotificationName const FxGripFinalCutTimelineNotification;

/*!
	@enum       FxGripFinalCutTimecodeFormat
	@abstract   A sequence's timecode display format.
	@discussion Introduced in FxGrip 0.1.0.
*/
typedef NS_ENUM(NSInteger, FxGripFinalCutTimecodeFormat) {
	/*! The sequence declares no format. */
	FxGripFinalCutTimecodeFormatUnspecified = 0,
	/*! Drop-frame timecode. */
	FxGripFinalCutTimecodeFormatDropFrame,
	/*! Non-drop-frame timecode. */
	FxGripFinalCutTimecodeFormatNonDropFrame,
};

/*!
	@class      FxGripFinalCutSequence
	@abstract   A sequence in a Final Cut Pro library.
	@discussion Introduced in FxGrip 0.1.0. Library inspection fills every property from the
	            scripting dictionary. The ProExtensionHost timeline reports its active sequence
	            without an identifier of its own, so `identifier` then carries the containing
	            project's UID.
*/
@interface FxGripFinalCutSequence : NSObject
/*! The display name. */
@property (readwrite, copy, nullable) NSString *name;
/*! The media identifier. */
@property (readwrite, copy, nullable) NSString *identifier;
/*! The start time, or `kCMTimeInvalid`. */
@property (readwrite) CMTime startTime;
/*! The duration, or `kCMTimeInvalid`. */
@property (readwrite) CMTime duration;
/*! The frame duration, or `kCMTimeInvalid`. */
@property (readwrite) CMTime frameDuration;
/*! The timecode display format. */
@property (readwrite) FxGripFinalCutTimecodeFormat timecodeFormat;
/*! The frame rate the frame duration implies, or 0. */
@property (readonly) double frameRate;
@end

/*!
	@class      FxGripFinalCutProject
	@abstract   A project: a named sequence in an event.
	@discussion Introduced in FxGrip 0.1.0.
*/
@interface FxGripFinalCutProject : NSObject
/*! The display name. */
@property (readwrite, copy, nullable) NSString *name;
/*! The unique identifier. */
@property (readwrite, copy, nullable) NSString *identifier;
/*! The project's sequence. */
@property (readwrite, strong, nullable) FxGripFinalCutSequence *sequence;
@end

/*!
	@class      FxGripFinalCutEvent
	@abstract   An event: the projects it holds.
	@discussion Introduced in FxGrip 0.1.0.
*/
@interface FxGripFinalCutEvent : NSObject
/*! The display name. */
@property (readwrite, copy, nullable) NSString *name;
/*! The unique identifier. */
@property (readwrite, copy, nullable) NSString *identifier;
/*! The projects. */
@property (readwrite, copy) NSArray<FxGripFinalCutProject *> *projects;
@end

/*!
	@class      FxGripFinalCutLibrary
	@abstract   An open library: its file and events.
	@discussion Introduced in FxGrip 0.1.0.
*/
@interface FxGripFinalCutLibrary : NSObject
/*! The display name. */
@property (readwrite, copy, nullable) NSString *name;
/*! The unique identifier. */
@property (readwrite, copy, nullable) NSString *identifier;
/*! The library bundle's file URL. */
@property (readwrite, strong, nullable) NSURL *fileURL;
/*! The events. */
@property (readwrite, copy) NSArray<FxGripFinalCutEvent *> *events;
/*! Every project in every event. */
@property (readonly, copy) NSArray<FxGripFinalCutProject *> *projects;
@end

@class FxGripFinalCutHost;

/*!
	@protocol   FxGripFinalCutTimelineObserving
	@abstract   Receives timeline changes from the host.
	@discussion Introduced in FxGrip 0.1.0. The three typed callbacks arrive from the
				ProExtensionHost timeline, so they need an attached host. The raw callback
				arrives from the distributed notification in every configuration.
*/
@protocol FxGripFinalCutTimelineObserving <NSObject>
@optional
/*! The playhead moved. */
- (void)finalCutHost:(FxGripFinalCutHost *)host playheadDidMoveTo:(CMTime)time;
/*! The active sequence changed. */
- (void)finalCutHost:(FxGripFinalCutHost *)host activeSequenceDidChange:(nullable FxGripFinalCutSequence *)sequence;
/*! The sequence's time range changed. */
- (void)finalCutHost:(FxGripFinalCutHost *)host sequenceTimeRangeDidChange:(CMTimeRange)range;
/*! The host posted its timeline notification; the payload is as the host sent it. */
- (void)finalCutHost:(FxGripFinalCutHost *)host didReceiveTimelineNotification:(NSNotification *)notification;
@end

/*!
	@class      FxGripFinalCutHost
	@abstract   The running Final Cut Pro, read through Apple Events and the ProExtensionHost of the
	            Workflow Extensions SDK.
	@discussion Introduced in FxGrip 0.1.0. Library inspection needs the sandbox entitlements
				`com.apple.security.automation.apple-events` and
				`com.apple.security.scripting-targets` with the
				`com.apple.FinalCut.library.inspection` group for `com.apple.FinalCut` and
				`com.apple.FinalCutTrial`, plus `NSAppleEventsUsageDescription` in the wrapper app's
				Info.plist; `canInspectLibraries` reports whether the process carries them. Each
				inspection is one Apple Event script, so it blocks the calling thread for the
				host's round trip; call it off the main thread or on user action.

				The timeline route needs the host object the SDK's `ProExtensionHostSingleton()`
				returns. The function is defined in `libProExtension.a`, which the extension
				executable links, so the framework resolves it with `dlsym` on first use;
				`attachProExtensionHost:` takes the object from an extension that calls the function
				itself. The `FCPXHost` protocol publishes only the timeline and the host's name,
				version, and bundle identifier, so library listing stays on the Apple Events route.
*/
@interface FxGripFinalCutHost : NSObject

/*! The shared host client. */
+ (instancetype)sharedHost;

/*! The running Final Cut Pro, or nil. */
@property (readonly, nullable) NSRunningApplication *runningApplication;
/*! YES when Final Cut Pro is running. */
@property (readonly) BOOL isRunning;
/*! The running application's bundle identifier, or nil. */
@property (readonly, nullable) NSString *bundleIdentifier;
/*! The installed Final Cut Pro's version, or nil. */
@property (readonly, nullable) NSString *version;

/*! YES when the process is outside the sandbox or carries the Apple Events entitlements for the
	library inspection access group. */
@property (readonly) BOOL canInspectLibraries;

/*!
	@method     librariesWithError:
	@abstract   The open libraries with their events, projects, and sequences.
	@discussion Runs one Apple Event script against the running host. Fails when Final Cut Pro
				is not running, the process lacks the entitlements, or the user declined the
				automation prompt.
*/
- (nullable NSArray<FxGripFinalCutLibrary *> *)librariesWithError:(NSError * _Nullable * _Nullable)error;

/*! The first open library, or nil. */
- (nullable FxGripFinalCutLibrary *)frontLibraryWithError:(NSError * _Nullable * _Nullable)error;

/*!
	@method     runScript:error:
	@abstract   Runs an AppleScript source and returns its result descriptor.
	@discussion The seam every inspection goes through; a subclass overrides it to answer
				without a host.
*/
- (nullable NSAppleEventDescriptor *)runScript:(NSString *)source error:(NSError * _Nullable * _Nullable)error;

/*! The AppleScript source `librariesWithError:` runs. */
+ (NSString *)libraryInspectionScript;

/*! Parses the descriptor `libraryInspectionScript` returns into libraries. */
+ (NSArray<FxGripFinalCutLibrary *> *)librariesFromDescriptor:(nullable NSAppleEventDescriptor *)descriptor;

/*! The time a `media time` record descriptor carries, or `kCMTimeInvalid`. */
+ (CMTime)timeFromDescriptor:(nullable NSAppleEventDescriptor *)descriptor;

#pragma mark Timeline

/*!
	@property   proExtensionHost
	@abstract   The `FCPXHost` object of the Workflow Extensions SDK, or nil.
	@discussion Introduced in FxGrip 0.1.0. On first access the client resolves
				`ProExtensionHostSingleton` with `dlsym` and keeps the object it returns when it
				conforms to `FCPXHost`. The function is defined in the SDK's `libProExtension.a`,
				which the extension executable links, so a process that does not link the library
				reads nil. `attachProExtensionHost:` sets it directly.
*/
@property (readonly, nullable, strong, nonatomic) id<NSObject> proExtensionHost;

/*! YES when `proExtensionHost` resolves. */
@property (readonly) BOOL hasProExtensionHost;

/*!
	@method     attachProExtensionHost:
	@abstract   Attaches an `FCPXHost` object: the singleton's, or one a test supplies.
	@discussion Introduced in FxGrip 0.1.0. The client observes the host's timeline, reads the
				current playhead time, active sequence, and sequence time range, and delivers each
				later change to its timeline observers. Returns NO, attaching nothing, when the
				object does not conform to `FCPXHost`; a host whose timeline is nil attaches with
				no timeline, and `movePlayheadToTime:error:` then fails.
*/
- (BOOL)attachProExtensionHost:(nullable id<NSObject>)host;

/*! Starts delivering timeline changes to an observer, held weakly. Attaches the SDK host on
	the first call when it resolves. */
- (void)addTimelineObserver:(nullable id<FxGripFinalCutTimelineObserving>)observer;
/*! Stops delivering timeline changes to an observer. */
- (void)removeTimelineObserver:(id<FxGripFinalCutTimelineObserving>)observer;

/*! The playhead time the attached host's timeline last reported, or `kCMTimeInvalid`. */
@property (readonly) CMTime playheadTime;
/*! The active sequence the attached host's timeline last reported, or nil. */
@property (readonly, nullable, strong) FxGripFinalCutSequence *activeSequence;
/*! The sequence time range the attached host's timeline last reported, or `kCMTimeRangeInvalid`. */
@property (readonly) CMTimeRange sequenceTimeRange;

/*!
	@method     movePlayheadToTime:error:
	@abstract   Moves the host's playhead through the attached host's timeline.
	@discussion Updates `playheadTime` with the time the host reports back.
	@return     NO with an error when no host with a timeline is attached.
*/
- (BOOL)movePlayheadToTime:(CMTime)time error:(NSError * _Nullable * _Nullable)error;

#pragma mark Documents

/*! Opens a document in Final Cut Pro, which imports it; see `FxGripFinalCutPro`. */
- (void)importDocument:(FxGripFCPXMLDocument *)document named:(nullable NSString *)name
			completion:(nullable void (^)(NSError * _Nullable error))completion;

/*! Brings Final Cut Pro to the front; YES when it is running. */
- (BOOL)activate;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripFinalCutHost_h */
