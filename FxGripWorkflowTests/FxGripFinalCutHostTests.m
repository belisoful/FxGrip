/*!
	@file       FxGripFinalCutHostTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripFinalCutHostTests
	@abstract   Tests the Final Cut Pro host client without a running host.
	@discussion Introduced in FxGrip 0.1.0. The tests build the Apple Event descriptors the library
	            inspection script returns and check the parsed model, the media time record decoding,
	            the script seam, the entitlement gate, the timeline observer registry, and the
	            ProExtensionHost absence paths.
*/

#import <XCTest/XCTest.h>
#import <CoreMedia/CoreMedia.h>
#import <FxGripWorkflow/FxGripWorkflow.h>
#import <FxGrip/FxGripFinalCutPro.h>
#import <FxGrip/FxGripErrors.h>

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
@end
@implementation FxGripFinalCutTestObserver
- (instancetype)init { self = [super init]; if (self) { _notifications = NSMutableArray.new; _playhead = kCMTimeInvalid; } return self; }
- (void)finalCutHost:(FxGripFinalCutHost *)host didReceiveTimelineNotification:(NSNotification *)notification
{
	[self.notifications addObject:notification];
}
- (void)finalCutHost:(FxGripFinalCutHost *)host playheadDidMoveTo:(CMTime)time { self.playhead = time; }
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
	XCTAssertFalse(host.hasProExtensionHost, @"the SDK is not linked by the tests");
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
