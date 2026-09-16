/*!
	@file       FxGripExtensionSystemTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-10
	@header     FxGripExtensionSystemTests
	@abstract   Unit tests for the standalone extension dispatcher's lifecycle posts and lookup.
	@discussion Introduced in FxGrip 0.1.0. A minimal host stands in for a plug-in that does not use
	            the effect base. The tests confirm the init, finish-setup, added-to-document,
	            parameter-clicked, and plugin-state dispatches reach a loaded extension with the
	            payloads FxGripTileableEffect posts, and that lookup reports the host and misses
	            cleanly for an absent class.
*/

#import <XCTest/XCTest.h>
#import <CoreMedia/CoreMedia.h>
#import <FxGrip/FxGripEffectHost.h>
#import <FxGrip/FxGripExtension.h>
#import <FxGrip/FxGripExtensionSystem.h>
#import <FxGrip/FxGripTileableEffect.h>
#import <FxGrip/FxGripTileableEffect+Notifications.h>
#import "FxGripParameterClassTestSupport.h"

/*! A plug-in host with the two required FxGripEffectHost members and no effect base. */
@interface FxGripSystemTestHost : NSObject <FxGripEffectHost>
@property (nonatomic, strong) FxGripParamClassTestAPIManager *manager;
@property (nonatomic, strong) NSNotificationCenter *center;
@end

@implementation FxGripSystemTestHost

- (instancetype)init
{
	self = [super init];
	if (self) {
		_manager = [FxGripParamClassTestAPIManager new];
		// The parameter dispatch uses the priority center's postBlock: variant.
		Class cls = NSClassFromString(@"NSPriorityNotificationCenter");
		_center = [[cls alloc] init];
	}
	return self;
}

- (id<FxGripAPIAccessing>)apiManager { return (id<FxGripAPIAccessing>)self.manager; }
- (NSPriorityNotificationCenter *)notifier { return (NSPriorityNotificationCenter *)self.center; }
- (nullable FxGripTileableEffect *)effectBase { return nil; }

@end

/*! Records the lifecycle dispatches it observes and the payloads they carry. */
@interface FxGripSystemTestRecorder : FxGripExtensionBase
@property (nonatomic, strong) NSMutableArray<NSString *> *calls;
@property (nonatomic, strong) id recordedAPIManager;
@property (nonatomic, strong) NSNumber *clickedParameterID;
@property (nonatomic, strong) NSCoder *recordedCoder;
@end

@implementation FxGripSystemTestRecorder

- (instancetype)init
{
	self = [super init];
	if (self) {
		_calls = NSMutableArray.new;
	}
	return self;
}

- (void)extInit:(NSNotification *)notification
{
	[self.calls addObject:@"init"];
	self.recordedAPIManager = notification.userInfo[FxGripTileableEffectInitAPIManagerKey];
}

- (void)extFinishInitialSetup:(NSNotification *)notification
{
	[self.calls addObject:@"finishInitialSetup"];
}

- (void)extAddedToDocument:(NSNotification *)notification
{
	[self.calls addObject:@"addedToDocument"];
}

- (void)extParameterClicked:(NSNotification *)notification
{
	[self.calls addObject:@"parameterClicked"];
	self.clickedParameterID = notification.userInfo[FxGripTileableEffectParameterClickedIDKey];
}

- (void)extPluginState:(NSNotification *)notification
{
	[self.calls addObject:@"pluginState"];
	self.recordedCoder = notification.userInfo[FxGripTileableEffectPluginStateCoderKey];
}

@end

/*! A second extension class, so a lookup for a class that was never loaded misses. */
@interface FxGripSystemTestAbsentExtension : FxGripExtensionBase
@end

@implementation FxGripSystemTestAbsentExtension
@end

@interface FxGripExtensionSystemDispatchTests : XCTestCase
@property (nonatomic, strong) FxGripSystemTestHost *host;
@property (nonatomic, strong) FxGripExtensionSystem *system;
@property (nonatomic, strong) FxGripSystemTestRecorder *extension;
@end

@implementation FxGripExtensionSystemDispatchTests

- (void)setUp
{
	[super setUp];
	self.host = [FxGripSystemTestHost new];
	self.system = [[FxGripExtensionSystem alloc] initWithHost:self.host];
	self.extension = [FxGripSystemTestRecorder new];
	XCTAssertTrue([self.system loadExtension:self.extension]);
}

- (void)tearDown
{
	self.extension = nil;
	self.system = nil;
	self.host = nil;
	[super tearDown];
}

#pragma mark Lookup

/*! @abstract The system reports the host it dispatches over. */
- (void)testTheSystemReportsItsHost
{
	XCTAssertEqual((id)self.system.host, (id)self.host);
}

/*! @abstract A lookup for a class that was never loaded reports none. */
- (void)testALookupForAnUnloadedClassReportsNone
{
	XCTAssertNil([self.system extensionForClass:FxGripSystemTestAbsentExtension.class]);
	XCTAssertEqual((id)[self.system extensionForClass:FxGripSystemTestRecorder.class], (id)self.extension);
}

/*! @abstract A system that deallocates releases its extensions without disturbing the host. */
- (void)testASystemThatDeallocatesReleasesItsExtensions
{
	@autoreleasepool {
		FxGripExtensionSystem *transient = [[FxGripExtensionSystem alloc] initWithHost:self.host];
		XCTAssertTrue([transient loadExtension:[FxGripSystemTestRecorder new]]);
		XCTAssertEqual(transient.extensions.count, (NSUInteger)1);
	}
	XCTAssertEqual(self.system.extensions.count, (NSUInteger)1, @"the surviving system keeps its own");
}

#pragma mark Lifecycle dispatch

/*! @abstract The init dispatch announces the host's API manager to the loaded extensions. */
- (void)testTheInitDispatchAnnouncesTheAPIManager
{
	[self.system dispatchInit];

	XCTAssertEqualObjects(self.extension.calls, (@[@"init"]));
	XCTAssertEqual((id)self.extension.recordedAPIManager, (id)self.host.manager);
}

/*! @abstract The finish-setup and added-to-document dispatches reach the extension in order. */
- (void)testTheSetupAndDocumentDispatchesReachTheExtension
{
	[self.system dispatchFinishInitialSetup];
	[self.system dispatchAddedToDocument];

	XCTAssertEqualObjects(self.extension.calls, (@[@"finishInitialSetup", @"addedToDocument"]));
}

/*! @abstract The parameter-clicked dispatch delivers the clicked parameter ID. */
- (void)testTheParameterClickedDispatchDeliversTheParameterID
{
	[self.system dispatchParameterClicked:314];

	XCTAssertEqualObjects(self.extension.calls, (@[@"parameterClicked"]));
	XCTAssertEqualObjects(self.extension.clickedParameterID, @314);
}

/*! @abstract The plugin-state dispatch delivers the coder the plug-in is writing into. */
- (void)testThePluginStateDispatchDeliversTheCoder
{
	NSKeyedArchiver *coder = [NSKeyedArchiver.alloc initRequiringSecureCoding:YES];

	[self.system dispatchPluginStateWithCoder:coder];

	XCTAssertEqualObjects(self.extension.calls, (@[@"pluginState"]));
	XCTAssertEqual((id)self.extension.recordedCoder, (id)coder);
}

@end
