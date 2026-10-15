/*!
	@file       FxGripFinalCutHostTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripFinalCutHostTests
	@abstract   Tests the Final Cut Pro host client without a running host.
	@discussion Introduced in FxGrip 0.1.0. The tests build the Apple Event descriptors the library
	            inspection script returns and check the parsed model, the media time record decoding,
	            the script seam, the entitlement gate, the timeline observer registry, the
	            ProExtensionHost bridge over a fake `FCPXHost`, and the paths without one.
*/

#import <XCTest/XCTest.h>
#import <CoreMedia/CoreMedia.h>
#import <FxGripWorkflow/FxGripWorkflow.h>
#import <FxGrip/FxGripFinalCutPro.h>
#import <FxGrip/FxGripErrors.h>
#import <ProExtensionHost/FCPXHost.h>

#pragma mark - Doubles

/*! Answers the inspection script with a staged descriptor and reports as running and entitled. */
@interface FxGripFinalCutTestHost : FxGripFinalCutHost
@property (nonatomic, strong) NSAppleEventDescriptor *result;
@property (nonatomic, strong) NSError *scriptError;
@property (nonatomic, copy) NSString *lastSource;
@property (nonatomic, assign) BOOL running;
@property (nonatomic, assign) BOOL entitled;
@end

@implementation FxGripFinalCutTestHost
- (BOOL)isRunning { return self.running; }
- (BOOL)canInspectLibraries { return self.entitled; }
- (NSAppleEventDescriptor *)runScript:(NSString *)source error:(NSError **)error
{
	self.lastSource = source;
	if (self.result == nil && error) {
		*error = self.scriptError;
	}
	return self.result;
}
@end

@interface FxGripFinalCutTestObserver : NSObject <FxGripFinalCutTimelineObserving>
@property (nonatomic, strong) NSMutableArray<NSNotification *> *notifications;
@property (nonatomic, assign) CMTime playhead;
@property (nonatomic, strong) FxGripFinalCutSequence *sequence;
@property (nonatomic, assign) NSUInteger sequenceChanges;
@property (nonatomic, assign) CMTimeRange range;
@end
@implementation FxGripFinalCutTestObserver
- (instancetype)init
{
	self = [super init];
	if (self) {
		_notifications = NSMutableArray.new;
		_playhead = kCMTimeInvalid;
		_range = kCMTimeRangeInvalid;
	}
	return self;
}
- (void)finalCutHost:(FxGripFinalCutHost *)host didReceiveTimelineNotification:(NSNotification *)notification
{
	[self.notifications addObject:notification];
}
- (void)finalCutHost:(FxGripFinalCutHost *)host playheadDidMoveTo:(CMTime)time { self.playhead = time; }
- (void)finalCutHost:(FxGripFinalCutHost *)host activeSequenceDidChange:(FxGripFinalCutSequence *)sequence
{
	self.sequence = sequence;
	self.sequenceChanges += 1;
}
- (void)finalCutHost:(FxGripFinalCutHost *)host sequenceTimeRangeDidChange:(CMTimeRange)range { self.range = range; }
@end

#pragma mark - ProExtensionHost doubles

/*! The project that contains the fake sequence; the bridge reads its UID and object type. */
@interface FxGripFinalCutFakeProject : NSObject
@property (nonatomic, copy) NSString *UID;
@end
@implementation FxGripFinalCutFakeProject
- (FCPXObjectType)objectType { return kFCPXObjectType_Project; }
@end

@interface FxGripFinalCutFakeSequence : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) CMTime startTime;
@property (nonatomic, assign) CMTime duration;
@property (nonatomic, assign) CMTime frameDuration;
@property (nonatomic, assign) FCPXSequenceTimecodeFormat timecodeFormat;
@property (nonatomic, strong) FxGripFinalCutFakeProject *container;
@end
@implementation FxGripFinalCutFakeSequence
@end

/*! Stands in for `FCPXTimeline`: the observer list and the values the bridge reads. */
@interface FxGripFinalCutFakeTimeline : NSObject
@property (nonatomic, assign) CMTime playheadTime;
@property (nonatomic, strong) FxGripFinalCutFakeSequence *activeSequence;
@property (nonatomic, assign) CMTimeRange sequenceTimeRange;
@property (nonatomic, strong) NSMutableArray<NSObject<FCPXTimelineObserver> *> *observers;
@property (nonatomic, assign) CMTime movedTo;
@end
@implementation FxGripFinalCutFakeTimeline
- (instancetype)init
{
	self = [super init];
	if (self) {
		_observers = NSMutableArray.new;
		_playheadTime = kCMTimeInvalid;
		_sequenceTimeRange = kCMTimeRangeInvalid;
		_movedTo = kCMTimeInvalid;
	}
	return self;
}
- (void)addTimelineObserver:(NSObject<FCPXTimelineObserver> *)observer { [self.observers addObject:observer]; }
- (void)removeTimelineObserver:(NSObject<FCPXTimelineObserver> *)observer { [self.observers removeObject:observer]; }
- (CMTime)movePlayheadTo:(CMTime)newTime
{
	self.movedTo = newTime;
	self.playheadTime = newTime;
	return newTime;
}
@end

/*! Conforms to `FCPXHost` over the fake timeline. */
@interface FxGripFinalCutFakeHost : NSObject <FCPXHost>
@property (nonatomic, strong) FxGripFinalCutFakeTimeline *fakeTimeline;
@end
@implementation FxGripFinalCutFakeHost
- (FCPXTimeline *)timeline { return (FCPXTimeline *)self.fakeTimeline; }
- (NSString *)versionString { return @"12.4"; }
- (NSString *)bundleIdentifier { return FxGripFinalCutProBundleIdentifier; }
- (NSString *)name { return @"Final Cut Pro"; }
@end

#pragma mark - Descriptor builders

static NSAppleEventDescriptor *FxGripTestList(NSArray<NSAppleEventDescriptor *> *items)
{
	NSAppleEventDescriptor *list = [NSAppleEventDescriptor listDescriptor];
	for (NSAppleEventDescriptor *item in items) {
		[list insertDescriptor:item atIndex:0];
	}
	return list;
}

static NSAppleEventDescriptor *FxGripTestString(NSString *string)
{
	return [NSAppleEventDescriptor descriptorWithString:string];
}

static NSAppleEventDescriptor *FxGripTestMediaTime(long long value, int32_t timescale)
{
	NSAppleEventDescriptor *record = [NSAppleEventDescriptor recordDescriptor];
	[record setDescriptor:[NSAppleEventDescriptor descriptorWithDouble:(double)value] forKeyword:'cmtv'];
	[record setDescriptor:[NSAppleEventDescriptor descriptorWithInt32:timescale] forKeyword:'cmts'];
	[record setDescriptor:[NSAppleEventDescriptor descriptorWithDouble:0] forKeyword:'cmte'];
	[record setDescriptor:[NSAppleEventDescriptor descriptorWithInt32:kCMTimeFlags_Valid] forKeyword:'cmtf'];
	return record;
}

static NSAppleEventDescriptor *FxGripTestLibraries(void)
{
	NSAppleEventDescriptor *project = FxGripTestList(@[
		FxGripTestString(@"Cut"), FxGripTestString(@"P1"), FxGripTestString(@"Cut Sequence"), FxGripTestString(@"S1"),
		FxGripTestMediaTime(3600, 1), FxGripTestMediaTime(600600, 30000), FxGripTestMediaTime(1001, 30000),
		[NSAppleEventDescriptor descriptorWithEnumCode:'ndrp'],
	]);
	NSAppleEventDescriptor *event = FxGripTestList(@[FxGripTestString(@"Day 1"), FxGripTestString(@"E1"), FxGripTestList(@[project])]);
	NSAppleEventDescriptor *emptyEvent = FxGripTestList(@[FxGripTestString(@"Empty"), FxGripTestString(@"E2"), FxGripTestList(@[])]);
	NSAppleEventDescriptor *library = FxGripTestList(@[
		FxGripTestString(@"Lib"), FxGripTestString(@"L1"),
		[NSAppleEventDescriptor descriptorWithFileURL:[NSURL fileURLWithPath:@"/Users/me/Movies/Lib.fcpbundle"]],
		FxGripTestList(@[event, emptyEvent]),
	]);
	NSAppleEventDescriptor *malformed = FxGripTestList(@[FxGripTestString(@"Short")]);
	return FxGripTestList(@[library, malformed]);
}

#pragma mark - Tests

@interface FxGripFinalCutHostTests : XCTestCase
@end

@implementation FxGripFinalCutHostTests

- (void)testParsesTheInspectionResult
{
	NSArray<FxGripFinalCutLibrary *> *libraries = [FxGripFinalCutHost librariesFromDescriptor:FxGripTestLibraries()];
	XCTAssertEqual(libraries.count, (NSUInteger)1, @"the malformed entry is skipped");
	FxGripFinalCutLibrary *library = libraries.firstObject;
	XCTAssertEqualObjects(library.name, @"Lib");
	XCTAssertEqualObjects(library.identifier, @"L1");
	XCTAssertEqualObjects(library.fileURL.path, @"/Users/me/Movies/Lib.fcpbundle");
	XCTAssertEqual(library.events.count, (NSUInteger)2);
	XCTAssertEqual(library.projects.count, (NSUInteger)1);
	FxGripFinalCutEvent *event = library.events.firstObject;
	XCTAssertEqualObjects(event.name, @"Day 1");
	XCTAssertEqualObjects(event.identifier, @"E1");
	FxGripFinalCutProject *project = event.projects.firstObject;
	XCTAssertEqualObjects(project.name, @"Cut");
	XCTAssertEqualObjects(project.identifier, @"P1");
	FxGripFinalCutSequence *sequence = project.sequence;
	XCTAssertEqualObjects(sequence.name, @"Cut Sequence");
	XCTAssertEqualObjects(sequence.identifier, @"S1");
	XCTAssertEqual(CMTimeCompare(sequence.startTime, CMTimeMake(3600, 1)), 0);
	XCTAssertEqual(CMTimeCompare(sequence.duration, CMTimeMake(600600, 30000)), 0);
	XCTAssertEqual(CMTimeCompare(sequence.frameDuration, CMTimeMake(1001, 30000)), 0);
	XCTAssertEqualWithAccuracy(sequence.frameRate, 29.97, 0.001);
	XCTAssertEqual(sequence.timecodeFormat, FxGripFinalCutTimecodeFormatNonDropFrame);
	XCTAssertEqual(library.events.lastObject.projects.count, (NSUInteger)0);
	XCTAssertTrue([library.description containsString:@"Lib"]);
	XCTAssertTrue([project.description containsString:@"P1"]);
	XCTAssertEqualObjects([FxGripFinalCutHost librariesFromDescriptor:nil], @[]);
}

- (void)testMediaTimeDecoding
{
	CMTime time = [FxGripFinalCutHost timeFromDescriptor:FxGripTestMediaTime(1001, 30000)];
	XCTAssertEqual(time.value, 1001);
	XCTAssertEqual(time.timescale, 30000);
	XCTAssertTrue(CMTIME_IS_VALID(time));
	XCTAssertFalse(CMTIME_IS_VALID([FxGripFinalCutHost timeFromDescriptor:nil]));
	XCTAssertFalse(CMTIME_IS_VALID([FxGripFinalCutHost timeFromDescriptor:FxGripTestString(@"x")]));
	XCTAssertFalse(CMTIME_IS_VALID([FxGripFinalCutHost timeFromDescriptor:FxGripTestMediaTime(1, 0)]));
	FxGripFinalCutSequence *sequence = [[FxGripFinalCutSequence alloc] init];
	XCTAssertEqual(sequence.frameRate, 0);
	XCTAssertFalse(CMTIME_IS_VALID(sequence.duration));
}

- (void)testTimecodeFormatsFromStrings
{
	NSAppleEventDescriptor *project = FxGripTestList(@[
		FxGripTestString(@"P"), FxGripTestString(@"P"), FxGripTestString(@"S"), FxGripTestString(@"S"),
		FxGripTestMediaTime(0, 1), FxGripTestMediaTime(1, 1), FxGripTestMediaTime(1, 25), FxGripTestString(@"drop frame"),
	]);
	NSAppleEventDescriptor *event = FxGripTestList(@[FxGripTestString(@"E"), FxGripTestString(@"E"), FxGripTestList(@[project])]);
	NSAppleEventDescriptor *library = FxGripTestList(@[FxGripTestString(@"L"), FxGripTestString(@"L"), FxGripTestString(@""), FxGripTestList(@[event])]);
	FxGripFinalCutLibrary *parsed = [FxGripFinalCutHost librariesFromDescriptor:FxGripTestList(@[library])].firstObject;
	XCTAssertEqual(parsed.projects.firstObject.sequence.timecodeFormat, FxGripFinalCutTimecodeFormatDropFrame);
	XCTAssertNil(parsed.fileURL);
}

- (void)testInspectionGoesThroughTheScriptSeam
{
	FxGripFinalCutTestHost *host = [[FxGripFinalCutTestHost alloc] init];
	host.running = YES;
	host.entitled = YES;
	host.result = FxGripTestLibraries();
	NSError *error = nil;
	NSArray *libraries = [host librariesWithError:&error];
	XCTAssertEqual(libraries.count, (NSUInteger)1, @"%@", error);
	XCTAssertEqualObjects(host.lastSource, FxGripFinalCutHost.libraryInspectionScript);
	XCTAssertTrue([host.lastSource containsString:@"com.apple.FinalCut"]);
	XCTAssertEqualObjects([host frontLibraryWithError:NULL].name, @"Lib");

	host.result = nil;
	host.scriptError = [NSError errorWithDomain:NSOSStatusErrorDomain code:-1743 userInfo:nil];
	XCTAssertNil([host librariesWithError:&error]);
	XCTAssertEqual(error.code, -1743);

	host.entitled = NO;
	XCTAssertNil([host librariesWithError:&error]);
	XCTAssertTrue([error.localizedDescription containsString:@"entitlements"]);
	host.running = NO;
	XCTAssertNil([host librariesWithError:&error]);
	XCTAssertTrue([error.localizedDescription containsString:@"not running"]);
}

- (void)testEntitlementGateInAnUnsandboxedProcess
{
	// The test process is not sandboxed, so inspection is allowed without scripting targets.
	XCTAssertTrue(FxGripFinalCutHost.sharedHost.canInspectLibraries);
	XCTAssertEqual(FxGripFinalCutHost.sharedHost, FxGripFinalCutHost.sharedHost);
	XCTAssertEqual(FxGripFinalCutHost.sharedHost.isRunning, FxGripFinalCutPro.isRunning);
	XCTAssertEqualObjects(FxGripFinalCutHost.sharedHost.version, FxGripFinalCutPro.installedVersion);
}

- (void)testTimelineObserversAndNotificationForwarding
{
	FxGripFinalCutHost *host = [[FxGripFinalCutHost alloc] init];
	XCTAssertFalse(host.hasProExtensionHost, @"the test process does not link libProExtension");
	XCTAssertFalse(CMTIME_IS_VALID(host.playheadTime));
	FxGripFinalCutTestObserver *observer = [[FxGripFinalCutTestObserver alloc] init];
	[host addTimelineObserver:observer];
	[host addTimelineObserver:nil];
	XCTestExpectation *forwarded = [self expectationWithDescription:@"the distributed notification is forwarded"];
	forwarded.assertForOverFulfill = NO;
	[NSDistributedNotificationCenter.defaultCenter postNotificationName:FxGripFinalCutTimelineNotification object:nil
															  userInfo:nil deliverImmediately:YES];
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		if (observer.notifications.count > 0) {
			[forwarded fulfill];
		}
	});
	[self waitForExpectations:@[forwarded] timeout:5];
	XCTAssertEqualObjects(observer.notifications.firstObject.name, FxGripFinalCutTimelineNotification);
	[host removeTimelineObserver:observer];
	NSError *error = nil;
	XCTAssertFalse([host movePlayheadToTime:CMTimeMake(1, 1) error:&error]);
	XCTAssertEqual(error.code, kFxGripError_FCPXML);
	XCTAssertTrue([error.localizedDescription containsString:@"ProExtensionHost"]);
}

- (void)testProExtensionHostBridgeReadsTheTimeline
{
	FxGripFinalCutFakeProject *project = [[FxGripFinalCutFakeProject alloc] init];
	project.UID = @"P-UID";
	FxGripFinalCutFakeSequence *proSequence = [[FxGripFinalCutFakeSequence alloc] init];
	proSequence.name = @"Cut";
	proSequence.startTime = CMTimeMake(3600, 1);
	proSequence.duration = CMTimeMake(600600, 30000);
	proSequence.frameDuration = CMTimeMake(1001, 30000);
	proSequence.timecodeFormat = kFCPXSequenceTimecodeFormat_DropFrame;
	proSequence.container = project;
	FxGripFinalCutFakeTimeline *timeline = [[FxGripFinalCutFakeTimeline alloc] init];
	timeline.playheadTime = CMTimeMake(48, 24);
	timeline.activeSequence = proSequence;
	timeline.sequenceTimeRange = CMTimeRangeMake(CMTimeMake(3600, 1), CMTimeMake(20, 1));
	FxGripFinalCutFakeHost *proHost = [[FxGripFinalCutFakeHost alloc] init];
	proHost.fakeTimeline = timeline;

	FxGripFinalCutHost *host = [[FxGripFinalCutHost alloc] init];
	XCTAssertFalse([host attachProExtensionHost:nil]);
	XCTAssertFalse([host attachProExtensionHost:[[NSObject alloc] init]]);
	XCTAssertFalse(host.hasProExtensionHost);
	XCTAssertTrue([host attachProExtensionHost:proHost]);
	XCTAssertTrue(host.hasProExtensionHost);
	XCTAssertEqual(host.proExtensionHost, proHost);
	XCTAssertEqual(timeline.observers.count, (NSUInteger)1);
	XCTAssertEqual(CMTimeCompare(host.playheadTime, CMTimeMake(48, 24)), 0);
	XCTAssertEqualObjects(host.activeSequence.name, @"Cut");
	XCTAssertEqualObjects(host.activeSequence.identifier, @"P-UID");
	XCTAssertEqual(host.activeSequence.timecodeFormat, FxGripFinalCutTimecodeFormatDropFrame);
	XCTAssertEqualWithAccuracy(host.activeSequence.frameRate, 29.97, 0.001);
	XCTAssertEqual(CMTimeCompare(host.activeSequence.startTime, CMTimeMake(3600, 1)), 0);
	XCTAssertTrue(CMTimeRangeEqual(host.sequenceTimeRange, timeline.sequenceTimeRange));

	NSObject<FCPXTimelineObserver> *bridge = timeline.observers.firstObject;
	XCTAssertTrue([bridge respondsToSelector:@selector(playheadTimeChanged)]);
	XCTAssertTrue([bridge respondsToSelector:@selector(activeSequenceChanged)]);
	XCTAssertTrue([bridge respondsToSelector:@selector(sequenceTimeRangeChanged)]);
	XCTAssertFalse([bridge respondsToSelector:NSSelectorFromString(@"playheadTimeChanged:")]);

	FxGripFinalCutTestObserver *observer = [[FxGripFinalCutTestObserver alloc] init];
	[host addTimelineObserver:observer];
	XCTAssertEqual(timeline.observers.count, (NSUInteger)1, @"an attached host is not attached again");
	timeline.playheadTime = CMTimeMake(96, 24);
	[bridge playheadTimeChanged];
	XCTAssertEqual(CMTimeCompare(observer.playhead, CMTimeMake(96, 24)), 0);
	XCTAssertEqual(CMTimeCompare(host.playheadTime, CMTimeMake(96, 24)), 0);
	timeline.activeSequence = nil;
	[bridge activeSequenceChanged];
	XCTAssertEqual(observer.sequenceChanges, (NSUInteger)1);
	XCTAssertNil(observer.sequence);
	XCTAssertNil(host.activeSequence);
	CMTimeRange range = CMTimeRangeMake(CMTimeMake(0, 1), CMTimeMake(5, 1));
	timeline.sequenceTimeRange = range;
	[bridge sequenceTimeRangeChanged];
	XCTAssertTrue(CMTimeRangeEqual(observer.range, range));
	XCTAssertTrue(CMTimeRangeEqual(host.sequenceTimeRange, range));

	NSError *error = nil;
	XCTAssertTrue([host movePlayheadToTime:CMTimeMake(10, 1) error:&error]);
	XCTAssertNil(error);
	XCTAssertEqual(CMTimeCompare(timeline.movedTo, CMTimeMake(10, 1)), 0);
	XCTAssertEqual(CMTimeCompare(host.playheadTime, CMTimeMake(10, 1)), 0);
}

- (void)testProExtensionHostDetachesOnDeallocationAndNeedsATimelineToMoveThePlayhead
{
	FxGripFinalCutFakeTimeline *timeline = [[FxGripFinalCutFakeTimeline alloc] init];
	FxGripFinalCutFakeHost *proHost = [[FxGripFinalCutFakeHost alloc] init];
	proHost.fakeTimeline = timeline;
	@autoreleasepool {
		FxGripFinalCutHost *host = [[FxGripFinalCutHost alloc] init];
		XCTAssertTrue([host attachProExtensionHost:proHost]);
		XCTAssertEqual(timeline.observers.count, (NSUInteger)1);
		XCTAssertTrue([host attachProExtensionHost:proHost], @"attaching again replaces the bridge");
		XCTAssertEqual(timeline.observers.count, (NSUInteger)1);
	}
	XCTAssertEqual(timeline.observers.count, (NSUInteger)0);

	FxGripFinalCutFakeHost *hostWithoutTimeline = [[FxGripFinalCutFakeHost alloc] init];
	FxGripFinalCutHost *host = [[FxGripFinalCutHost alloc] init];
	XCTAssertTrue([host attachProExtensionHost:hostWithoutTimeline]);
	XCTAssertTrue(host.hasProExtensionHost);
	XCTAssertFalse(CMTIME_IS_VALID(host.playheadTime));
	NSError *error = nil;
	XCTAssertFalse([host movePlayheadToTime:CMTimeMake(1, 1) error:&error]);
	XCTAssertEqual(error.code, kFxGripError_FCPXML);
	XCTAssertTrue([error.localizedDescription containsString:@"ProExtensionHost"]);
}

- (void)testImportWithoutFinalCutProReportsAnError
{
	if (FxGripFinalCutPro.isInstalled) {
		return;
	}
	XCTestExpectation *done = [self expectationWithDescription:@"import fails"];
	FxGripFCPXMLDocument *document = [[FxGripFCPXMLDocument alloc] init];
	[FxGripFinalCutHost.sharedHost importDocument:document named:@"X" completion:^(NSError *error) {
		XCTAssertNotNil(error);
		[done fulfill];
	}];
	[self waitForExpectations:@[done] timeout:5];
}

@end
