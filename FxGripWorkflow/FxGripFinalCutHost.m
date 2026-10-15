/*!
	@file       FxGripFinalCutHost.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripFinalCutHost
	@abstract   The running Final Cut Pro as a workflow extension sees it.
	@discussion Introduced in FxGrip 0.1.0. See FxGripFinalCutHost.h.
*/

#import <FxGripWorkflow/FxGripFinalCutHost.h>
#import <FxGrip/FxGripFinalCutPro.h>
#import <FxGrip/FxGripErrors.h>
#import <ProExtensionHost/FCPXHost.h>
#import <ProExtension/ProExtension.h>
#import <Security/Security.h>
#import <dlfcn.h>

NSNotificationName const FxGripFinalCutTimelineNotification = @"com.apple.finalcut.timelineNotification";

// The four-character codes of the `media time` record in Final Cut Pro's scripting dictionary.
static const AEKeyword FxGripFinalCutMediaTimeValue = 'cmtv';
static const AEKeyword FxGripFinalCutMediaTimeTimescale = 'cmts';
static const AEKeyword FxGripFinalCutMediaTimeEpoch = 'cmte';
static const AEKeyword FxGripFinalCutMediaTimeFlags = 'cmtf';
static const OSType FxGripFinalCutTimecodeDrop = 'drop';
static const OSType FxGripFinalCutTimecodeNonDrop = 'ndrp';

static NSError *FxGripFinalCutError(NSInteger code, NSString *description)
{
	return [NSError errorWithDomain:FxGripPlugErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey: description}];
}

#pragma mark - Model

@implementation FxGripFinalCutSequence

- (instancetype)init
{
	self = [super init];
	if (self) {
		_startTime = kCMTimeInvalid;
		_duration = kCMTimeInvalid;
		_frameDuration = kCMTimeInvalid;
	}
	return self;
}

- (double)frameRate
{
	if (!CMTIME_IS_NUMERIC(self.frameDuration) || self.frameDuration.value == 0) {
		return 0;
	}
	return (double)self.frameDuration.timescale / (double)self.frameDuration.value;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ %@ %@>", self.className, self.name, self.identifier];
}

@end

@implementation FxGripFinalCutProject
- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ %@ %@>", self.className, self.name, self.identifier];
}
@end

@implementation FxGripFinalCutEvent
- (instancetype)init
{
	self = [super init];
	if (self) {
		_projects = @[];
	}
	return self;
}
- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ %@ projects=%lu>", self.className, self.name, (unsigned long)self.projects.count];
}
@end

@implementation FxGripFinalCutLibrary
- (instancetype)init
{
	self = [super init];
	if (self) {
		_events = @[];
	}
	return self;
}
- (NSArray<FxGripFinalCutProject *> *)projects
{
	NSMutableArray *projects = [NSMutableArray array];
	for (FxGripFinalCutEvent *event in self.events) {
		[projects addObjectsFromArray:event.projects];
	}
	return projects;
}
- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ %@ events=%lu>", self.className, self.name, (unsigned long)self.events.count];
}
@end

#pragma mark - ProExtensionHost bridge

/*! The `FCPXTimeline` observer. Each callback carries no argument, so the bridge reads the new
	value from the timeline and hands it to the host client. */
@interface FxGripFinalCutTimelineBridge : NSObject <FCPXTimelineObserver>
@property (weak) FxGripFinalCutHost *host;
@property (strong) FCPXTimeline *timeline;
@end

@interface FxGripFinalCutHost ()
@property (strong) NSHashTable<id<FxGripFinalCutTimelineObserving>> *observers;
@property (strong, nullable) id distributedToken;
@property (strong, nullable) FxGripFinalCutTimelineBridge *bridge;
@property (readwrite, nullable, strong, nonatomic) id<NSObject> proExtensionHost;
@property (strong, nullable) FCPXTimeline *proTimeline;
@property (readwrite) CMTime playheadTime;
@property (readwrite, nullable, strong) FxGripFinalCutSequence *activeSequence;
@property (readwrite) CMTimeRange sequenceTimeRange;
- (void)bridgePlayheadTime:(CMTime)time;
- (void)bridgeActiveSequence:(nullable FCPXSequence *)sequence;
- (void)bridgeSequenceTimeRange:(CMTimeRange)range;
@end

@implementation FxGripFinalCutTimelineBridge
- (void)playheadTimeChanged { [self.host bridgePlayheadTime:self.timeline.playheadTime]; }
- (void)activeSequenceChanged { [self.host bridgeActiveSequence:self.timeline.activeSequence]; }
- (void)sequenceTimeRangeChanged { [self.host bridgeSequenceTimeRange:self.timeline.sequenceTimeRange]; }
@end

#pragma mark - Host

@implementation FxGripFinalCutHost

+ (instancetype)sharedHost
{
	static FxGripFinalCutHost *shared = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		shared = [[self alloc] init];
	});
	return shared;
}

- (instancetype)init
{
	self = [super init];
	if (self) {
		_observers = [NSHashTable weakObjectsHashTable];
		_playheadTime = kCMTimeInvalid;
		_sequenceTimeRange = kCMTimeRangeInvalid;
	}
	return self;
}

- (void)dealloc
{
	if (_distributedToken != nil) {
		[NSDistributedNotificationCenter.defaultCenter removeObserver:_distributedToken];
	}
	if (_bridge != nil) {
		[_proTimeline removeTimelineObserver:_bridge];
	}
}

#pragma mark Identity

- (NSRunningApplication *)runningApplication
{
	return FxGripFinalCutPro.runningApplication;
}

- (BOOL)isRunning
{
	return FxGripFinalCutPro.isRunning;
}

- (NSString *)bundleIdentifier
{
	return self.runningApplication.bundleIdentifier;
}

- (NSString *)version
{
	return FxGripFinalCutPro.installedVersion;
}

#pragma mark Entitlements

+ (nullable id)entitlementValue:(NSString *)name
{
	SecTaskRef task = SecTaskCreateFromSelf(kCFAllocatorDefault);
	if (task == NULL) {
		return nil;
	}
	CFTypeRef value = SecTaskCopyValueForEntitlement(task, (__bridge CFStringRef)name, NULL);
	CFRelease(task);
	return value ? (__bridge_transfer id)value : nil;
}

- (BOOL)canInspectLibraries
{
	id sandboxed = [self.class entitlementValue:@"com.apple.security.app-sandbox"];
	if (![sandboxed isKindOfClass:NSNumber.class] || ![sandboxed boolValue]) {
		return YES;
	}
	id automation = [self.class entitlementValue:@"com.apple.security.automation.apple-events"];
	id targets = [self.class entitlementValue:@"com.apple.security.scripting-targets"];
	if (![targets isKindOfClass:NSDictionary.class]) {
		return [automation isKindOfClass:NSNumber.class] && [automation boolValue];
	}
	for (NSString *bundleIdentifier in FxGripFinalCutPro.bundleIdentifiers) {
		id groups = targets[bundleIdentifier];
		if ([groups isKindOfClass:NSArray.class] && [groups containsObject:FxGripFinalCutProLibraryInspectionAccessGroup]) {
			return YES;
		}
	}
	return NO;
}

#pragma mark Library inspection

+ (NSString *)libraryInspectionScript
{
	return @"tell application id \"com.apple.FinalCut\"\n"
	@"	set libraryList to {}\n"
	@"	repeat with aLibrary in libraries\n"
	@"		set eventList to {}\n"
	@"		repeat with anEvent in events of aLibrary\n"
	@"			set projectList to {}\n"
	@"			repeat with aProject in projects of anEvent\n"
	@"				set aSequence to sequence of aProject\n"
	@"				set end of projectList to {name of aProject, id of aProject, name of aSequence, id of aSequence, start time of aSequence, duration of aSequence, frame duration of aSequence, timecode format of aSequence}\n"
	@"			end repeat\n"
	@"			set end of eventList to {name of anEvent, id of anEvent, projectList}\n"
	@"		end repeat\n"
	@"		set end of libraryList to {name of aLibrary, id of aLibrary, file of aLibrary, eventList}\n"
	@"	end repeat\n"
	@"	return libraryList\n"
	@"end tell\n";
}

- (NSAppleEventDescriptor *)runScript:(NSString *)source error:(NSError **)error
{
	NSAppleScript *script = [[NSAppleScript alloc] initWithSource:source];
	NSDictionary *errorInfo = nil;
	NSAppleEventDescriptor *result = [script executeAndReturnError:&errorInfo];
	if (result == nil && error) {
		NSString *message = errorInfo[NSAppleScriptErrorMessage] ?: @"The script failed.";
		NSInteger code = [errorInfo[NSAppleScriptErrorNumber] integerValue];
		*error = [NSError errorWithDomain:NSOSStatusErrorDomain code:code
								 userInfo:@{NSLocalizedDescriptionKey: message}];
	}
	return result;
}

- (NSArray<FxGripFinalCutLibrary *> *)librariesWithError:(NSError **)error
{
	if (!self.isRunning) {
		if (error) {
			*error = FxGripFinalCutError(kFxGripError_FCPXML, @"Final Cut Pro is not running.");
		}
		return nil;
	}
	if (!self.canInspectLibraries) {
		if (error) {
			*error = FxGripFinalCutError(kFxGripError_FCPXML,
										 @"The process lacks the Apple Events entitlements for the library inspection access group.");
		}
		return nil;
	}
	NSAppleEventDescriptor *result = [self runScript:[self.class libraryInspectionScript] error:error];
	if (result == nil) {
		return nil;
	}
	return [self.class librariesFromDescriptor:result];
}

- (FxGripFinalCutLibrary *)frontLibraryWithError:(NSError **)error
{
	return [self librariesWithError:error].firstObject;
}

+ (NSString *)stringFromDescriptor:(NSAppleEventDescriptor *)descriptor
{
	NSString *string = descriptor.stringValue;
	return string.length > 0 ? string : nil;
}

+ (CMTime)timeFromDescriptor:(NSAppleEventDescriptor *)descriptor
{
	if (descriptor == nil) {
		return kCMTimeInvalid;
	}
	NSAppleEventDescriptor *record = descriptor;
	if (descriptor.descriptorType != typeAERecord) {
		record = [descriptor coerceToDescriptorType:typeAERecord] ?: descriptor;
	}
	NSAppleEventDescriptor *value = [record descriptorForKeyword:FxGripFinalCutMediaTimeValue];
	NSAppleEventDescriptor *timescale = [record descriptorForKeyword:FxGripFinalCutMediaTimeTimescale];
	if (value == nil || timescale == nil) {
		return kCMTimeInvalid;
	}
	NSAppleEventDescriptor *epoch = [record descriptorForKeyword:FxGripFinalCutMediaTimeEpoch];
	NSAppleEventDescriptor *flags = [record descriptorForKeyword:FxGripFinalCutMediaTimeFlags];
	CMTime time;
	time.value = (CMTimeValue)llround(value.doubleValue);
	time.timescale = (CMTimeScale)timescale.int32Value;
	time.epoch = epoch ? (CMTimeEpoch)llround(epoch.doubleValue) : 0;
	time.flags = flags ? (CMTimeFlags)flags.int32Value : kCMTimeFlags_Valid;
	if (time.timescale <= 0) {
		return kCMTimeInvalid;
	}
	return time;
}

+ (FxGripFinalCutTimecodeFormat)timecodeFormatFromDescriptor:(NSAppleEventDescriptor *)descriptor
{
	if (descriptor.descriptorType == typeEnumerated || descriptor.descriptorType == typeType) {
		OSType code = descriptor.enumCodeValue;
		if (code == FxGripFinalCutTimecodeDrop) {
			return FxGripFinalCutTimecodeFormatDropFrame;
		}
		if (code == FxGripFinalCutTimecodeNonDrop) {
			return FxGripFinalCutTimecodeFormatNonDropFrame;
		}
		return FxGripFinalCutTimecodeFormatUnspecified;
	}
	NSString *string = descriptor.stringValue;
	if ([string isEqualToString:@"drop frame"] || [string isEqualToString:@"drop"]) {
		return FxGripFinalCutTimecodeFormatDropFrame;
	}
	if ([string isEqualToString:@"non drop frame"] || [string isEqualToString:@"ndrp"]) {
		return FxGripFinalCutTimecodeFormatNonDropFrame;
	}
	return FxGripFinalCutTimecodeFormatUnspecified;
}

+ (NSArray<FxGripFinalCutLibrary *> *)librariesFromDescriptor:(NSAppleEventDescriptor *)descriptor
{
	NSMutableArray *libraries = [NSMutableArray array];
	for (NSInteger libraryIndex = 1; libraryIndex <= descriptor.numberOfItems; libraryIndex++) {
		NSAppleEventDescriptor *libraryItem = [descriptor descriptorAtIndex:libraryIndex];
		if (libraryItem.numberOfItems < 4) {
			continue;
		}
		FxGripFinalCutLibrary *library = [[FxGripFinalCutLibrary alloc] init];
		library.name = [self stringFromDescriptor:[libraryItem descriptorAtIndex:1]];
		library.identifier = [self stringFromDescriptor:[libraryItem descriptorAtIndex:2]];
		library.fileURL = [libraryItem descriptorAtIndex:3].fileURLValue;
		NSAppleEventDescriptor *eventList = [libraryItem descriptorAtIndex:4];
		NSMutableArray *events = [NSMutableArray array];
		for (NSInteger eventIndex = 1; eventIndex <= eventList.numberOfItems; eventIndex++) {
			NSAppleEventDescriptor *eventItem = [eventList descriptorAtIndex:eventIndex];
			if (eventItem.numberOfItems < 3) {
				continue;
			}
			FxGripFinalCutEvent *event = [[FxGripFinalCutEvent alloc] init];
			event.name = [self stringFromDescriptor:[eventItem descriptorAtIndex:1]];
			event.identifier = [self stringFromDescriptor:[eventItem descriptorAtIndex:2]];
			NSAppleEventDescriptor *projectList = [eventItem descriptorAtIndex:3];
			NSMutableArray *projects = [NSMutableArray array];
			for (NSInteger projectIndex = 1; projectIndex <= projectList.numberOfItems; projectIndex++) {
				NSAppleEventDescriptor *projectItem = [projectList descriptorAtIndex:projectIndex];
				if (projectItem.numberOfItems < 8) {
					continue;
				}
				FxGripFinalCutProject *project = [[FxGripFinalCutProject alloc] init];
				project.name = [self stringFromDescriptor:[projectItem descriptorAtIndex:1]];
				project.identifier = [self stringFromDescriptor:[projectItem descriptorAtIndex:2]];
				FxGripFinalCutSequence *sequence = [[FxGripFinalCutSequence alloc] init];
				sequence.name = [self stringFromDescriptor:[projectItem descriptorAtIndex:3]];
				sequence.identifier = [self stringFromDescriptor:[projectItem descriptorAtIndex:4]];
				sequence.startTime = [self timeFromDescriptor:[projectItem descriptorAtIndex:5]];
				sequence.duration = [self timeFromDescriptor:[projectItem descriptorAtIndex:6]];
				sequence.frameDuration = [self timeFromDescriptor:[projectItem descriptorAtIndex:7]];
				sequence.timecodeFormat = [self timecodeFormatFromDescriptor:[projectItem descriptorAtIndex:8]];
				project.sequence = sequence;
				[projects addObject:project];
			}
			event.projects = projects;
			[events addObject:event];
		}
		library.events = events;
		[libraries addObject:library];
	}
	return libraries;
}

#pragma mark Timeline

+ (nullable id<NSObject>)proExtensionHostFromSingleton
{
	__typeof__(&ProExtensionHostSingleton) singleton = (__typeof__(&ProExtensionHostSingleton))dlsym(RTLD_DEFAULT, "ProExtensionHostSingleton");
	if (singleton == NULL) {
		return nil;
	}
	id<NSObject> host = singleton();
	return [host conformsToProtocol:@protocol(FCPXHost)] ? host : nil;
}

- (id<NSObject>)proExtensionHost
{
	@synchronized (self) {
		if (_proExtensionHost == nil) {
			_proExtensionHost = [self.class proExtensionHostFromSingleton];
		}
		return _proExtensionHost;
	}
}

- (BOOL)hasProExtensionHost
{
	return self.proExtensionHost != nil;
}

- (BOOL)attachProExtensionHost:(id<NSObject>)host
{
	if (![host conformsToProtocol:@protocol(FCPXHost)]) {
		return NO;
	}
	[self detachProExtensionTimeline];
	self.proExtensionHost = host;
	FCPXTimeline *timeline = ((id<FCPXHost>)host).timeline;
	if (timeline == nil) {
		return YES;
	}
	FxGripFinalCutTimelineBridge *bridge = [[FxGripFinalCutTimelineBridge alloc] init];
	bridge.host = self;
	bridge.timeline = timeline;
	self.bridge = bridge;
	self.proTimeline = timeline;
	self.playheadTime = timeline.playheadTime;
	self.activeSequence = [self.class sequenceFromProSequence:timeline.activeSequence];
	self.sequenceTimeRange = timeline.sequenceTimeRange;
	[timeline addTimelineObserver:bridge];
	return YES;
}

- (void)detachProExtensionTimeline
{
	if (self.bridge != nil) {
		[self.proTimeline removeTimelineObserver:self.bridge];
	}
	self.bridge = nil;
	self.proTimeline = nil;
}

- (void)addTimelineObserver:(id<FxGripFinalCutTimelineObserving>)observer
{
	if (observer == nil) {
		return;
	}
	@synchronized (self.observers) {
		[self.observers addObject:observer];
	}
	[self startObservingHost];
}

- (void)removeTimelineObserver:(id<FxGripFinalCutTimelineObserving>)observer
{
	@synchronized (self.observers) {
		[self.observers removeObject:observer];
	}
}

- (NSArray<id<FxGripFinalCutTimelineObserving>> *)currentObservers
{
	@synchronized (self.observers) {
		return self.observers.allObjects;
	}
}

- (void)startObservingHost
{
	if (self.distributedToken == nil) {
		__weak FxGripFinalCutHost *weakSelf = self;
		self.distributedToken = [NSDistributedNotificationCenter.defaultCenter
								 addObserverForName:FxGripFinalCutTimelineNotification object:nil
								 queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *notification) {
			FxGripFinalCutHost *host = weakSelf;
			for (id<FxGripFinalCutTimelineObserving> observer in host.currentObservers) {
				if ([observer respondsToSelector:@selector(finalCutHost:didReceiveTimelineNotification:)]) {
					[observer finalCutHost:host didReceiveTimelineNotification:notification];
				}
			}
		}];
	}
	if (self.bridge == nil) {
		[self attachProExtensionHost:self.proExtensionHost];
	}
}

+ (FxGripFinalCutTimecodeFormat)timecodeFormatFromProFormat:(FCPXSequenceTimecodeFormat)format
{
	switch (format) {
		case kFCPXSequenceTimecodeFormat_DropFrame:
			return FxGripFinalCutTimecodeFormatDropFrame;
		case kFCPXSequenceTimecodeFormat_NonDropFrame:
			return FxGripFinalCutTimecodeFormatNonDropFrame;
		default:
			return FxGripFinalCutTimecodeFormatUnspecified;
	}
}

+ (nullable FxGripFinalCutSequence *)sequenceFromProSequence:(nullable FCPXSequence *)proSequence
{
	if (proSequence == nil) {
		return nil;
	}
	FxGripFinalCutSequence *sequence = [[FxGripFinalCutSequence alloc] init];
	sequence.name = proSequence.name;
	sequence.startTime = proSequence.startTime;
	sequence.duration = proSequence.duration;
	sequence.frameDuration = proSequence.frameDuration;
	sequence.timecodeFormat = [self timecodeFormatFromProFormat:proSequence.timecodeFormat];
	FCPXObject *container = proSequence.container;
	if (container.objectType == kFCPXObjectType_Project) {
		sequence.identifier = ((FCPXProject *)container).UID;
	}
	return sequence;
}

- (void)bridgePlayheadTime:(CMTime)time
{
	self.playheadTime = time;
	for (id<FxGripFinalCutTimelineObserving> observer in self.currentObservers) {
		if ([observer respondsToSelector:@selector(finalCutHost:playheadDidMoveTo:)]) {
			[observer finalCutHost:self playheadDidMoveTo:time];
		}
	}
}

- (void)bridgeActiveSequence:(FCPXSequence *)proSequence
{
	FxGripFinalCutSequence *sequence = [self.class sequenceFromProSequence:proSequence];
	self.activeSequence = sequence;
	for (id<FxGripFinalCutTimelineObserving> observer in self.currentObservers) {
		if ([observer respondsToSelector:@selector(finalCutHost:activeSequenceDidChange:)]) {
			[observer finalCutHost:self activeSequenceDidChange:sequence];
		}
	}
}

- (void)bridgeSequenceTimeRange:(CMTimeRange)range
{
	self.sequenceTimeRange = range;
	for (id<FxGripFinalCutTimelineObserving> observer in self.currentObservers) {
		if ([observer respondsToSelector:@selector(finalCutHost:sequenceTimeRangeDidChange:)]) {
			[observer finalCutHost:self sequenceTimeRangeDidChange:range];
		}
	}
}

- (BOOL)movePlayheadToTime:(CMTime)time error:(NSError **)error
{
	if (self.proTimeline == nil) {
		[self attachProExtensionHost:self.proExtensionHost];
	}
	if (self.proTimeline == nil) {
		if (error) {
			*error = FxGripFinalCutError(kFxGripError_FCPXML,
										 @"Moving the playhead needs the ProExtensionHost timeline; the extension links libProExtension.");
		}
		return NO;
	}
	CMTime moved = [self.proTimeline movePlayheadTo:time];
	if (CMTIME_IS_VALID(moved)) {
		self.playheadTime = moved;
	}
	return YES;
}

#pragma mark Documents

- (void)importDocument:(FxGripFCPXMLDocument *)document named:(NSString *)name completion:(void (^)(NSError *))completion
{
	[FxGripFinalCutPro openDocument:document named:name completion:^(NSRunningApplication *application, NSError *error) {
		if (completion) {
			completion(error);
		}
	}];
}

- (BOOL)activate
{
	return FxGripFinalCutPro.activate;
}

@end
