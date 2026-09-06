/*!
	@file       FxGripWindowTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripWindowTests
	@abstract   Unit tests for the FxGripWindow remote-window extension lifecycle.
	@discussion Introduced in FxGrip 0.1.0. Stubbed FxRemoteWindowAPI versions reply synchronously with a staged parent view or error, so no waiting is needed. The tests cover the host reply, content-view installation and swapping, the v2 ranged-size present with its v1 fixed-size fallback, the v3 close with its no-v3 behavior, and the closed-window reset.
*/

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripWindow.h>
#import <FxGrip/FxGripErrors.h>

static NSView *FxGripWindowTestView(void)
{
	return [[NSClassFromString(@"NSView") alloc] initWithFrame:NSMakeRect(0, 0, 320, 200)];
}

#pragma mark - Stubs

/*! A remote-window API stub: replies synchronously with a staged parent view or error, and
	counts calls. Which protocol versions it admits to is configured per test. */
@interface FxGripWindowStubAPI : NSObject
@property (nonatomic, strong, nullable) NSView *stagedParentView;
@property (nonatomic, strong, nullable) NSError *stagedError;
@property (nonatomic, assign) NSUInteger fixedRequests;
@property (nonatomic, assign) NSUInteger rangedRequests;
@property (nonatomic, assign) NSUInteger closeRequests;
@property (nonatomic, assign) CGSize lastMinSize;
@property (nonatomic, assign) CGSize lastMaxSize;
@end

@implementation FxGripWindowStubAPI

- (void)remoteWindowOfSize:(CGSize)contentSize reply:(void (^)(NSView *, NSError *))reply
{
	self.fixedRequests += 1;
	self.lastMinSize = contentSize;
	reply(self.stagedParentView, self.stagedError);
}

- (void)remoteWindowWithMinimumSize:(CGSize)minContentSize
						maximumSize:(CGSize)maxContentSize
							  reply:(void (^)(NSView *, NSError *))reply
{
	self.rangedRequests += 1;
	self.lastMinSize = minContentSize;
	self.lastMaxSize = maxContentSize;
	reply(self.stagedParentView, self.stagedError);
}

- (void)closeRemoteWindow
{
	self.closeRequests += 1;
}

@end

/*! The API-manager stub: vends the window stub at the versions a test enables. */
@interface FxGripWindowStubAPIManager : NSObject
@property (nonatomic, strong, nullable) FxGripWindowStubAPI *windowAPI;
@property (nonatomic, assign) BOOL vendsV2;
@property (nonatomic, assign) BOOL vendsV3;
@end

@implementation FxGripWindowStubAPIManager
- (id)remoteWindowAPIv1 { return self.windowAPI; }
- (id)remoteWindowAPIv2 { return self.vendsV2 ? self.windowAPI : nil; }
- (id)remoteWindowAPIv3 { return self.vendsV3 ? self.windowAPI : nil; }
@end

/*! The effect stub: only the apiManager the extension reaches. */
@interface FxGripWindowStubEffect : NSObject
@property (nonatomic, strong) FxGripWindowStubAPIManager *manager;
@end

@implementation FxGripWindowStubEffect

- (id)effectBase
{
	// The stub plays the full effect; rich reads route back to it, as the old cast did.
	return self;
}

- (id)apiManager { return self.manager; }
@end

#pragma mark - Tests

@interface FxGripWindowTests : XCTestCase
@property (nonatomic, strong) FxGripWindow *window;
@property (nonatomic, strong) FxGripWindowStubEffect *effect;
@property (nonatomic, strong) FxGripWindowStubAPI *api;
@end

@implementation FxGripWindowTests

- (void)setUp
{
	[super setUp];
	self.api = [FxGripWindowStubAPI new];
	self.effect = [FxGripWindowStubEffect new];
	self.effect.manager = [FxGripWindowStubAPIManager new];
	self.effect.manager.windowAPI = self.api;
	self.window = [FxGripWindow new];
	[self.window extLoadWithEffect:(id)self.effect];
}

- (void)tearDown
{
	self.window = nil;
	[super tearDown];
}

/*! @abstract The extension key equals the shared FxGripWindow extension key constant. */
- (void)testTheExtensionKeyIsStable
{
	XCTAssertEqualObjects(self.window.extKey, FxGripWindowExtensionKey);
	XCTAssertEqualObjects(FxGripWindowExtensionKey, @"FxGripWindow");
}

/*! @abstract Presenting stores the host parent view, installs the content view in it, and reports presented. */
- (void)testPresentingStoresTheParentAndInstallsTheContent
{
	NSView *parent = FxGripWindowTestView();
	NSView *content = FxGripWindowTestView();
	self.api.stagedParentView = parent;
	self.window.contentView = content;

	__block NSView *repliedParent = nil;
	[self.window presentWindowOfSize:CGSizeMake(320, 200)
						  completion:^(NSView *parentView, NSError *error) {
		repliedParent = parentView;
	}];

	XCTAssertTrue(self.window.isWindowPresented);
	XCTAssertEqual(self.window.windowParentView, parent);
	XCTAssertEqual(repliedParent, parent);
	XCTAssertEqual(content.superview, parent, @"the content view fills the host parent");
	XCTAssertEqual(self.api.fixedRequests, 1u);
}

/*! @abstract A failed presentation reports the host error and leaves the window closed with no parent view. */
- (void)testAFailedPresentationReportsTheErrorAndStaysClosed
{
	self.api.stagedError = [NSError errorWithDomain:@"test" code:7 userInfo:nil];

	__block NSError *replied = nil;
	[self.window presentWindowOfSize:CGSizeMake(320, 200)
						  completion:^(NSView *parentView, NSError *error) {
		replied = error;
	}];

	XCTAssertFalse(self.window.isWindowPresented);
	XCTAssertNil(self.window.windowParentView);
	XCTAssertEqual(replied.code, 7);
}

/*! @abstract Presenting with no remote-window API fails with the window-API-unavailable error and stays closed. */
- (void)testPresentingWithoutTheAPIFailsWithTheWindowError
{
	self.effect.manager.windowAPI = nil;

	__block NSError *replied = nil;
	[self.window presentWindowOfSize:CGSizeMake(320, 200)
						  completion:^(NSView *parentView, NSError *error) {
		replied = error;
	}];

	XCTAssertFalse(self.window.isWindowPresented);
	XCTAssertEqual(replied.code, kFxGripError_WindowAPIUnavailable);
}

/*! @abstract A ranged present uses the v2 minimum/maximum-size API when the host vends v2. */
- (void)testARangedPresentUsesV2WhenVended
{
	self.effect.manager.vendsV2 = YES;
	self.api.stagedParentView = FxGripWindowTestView();

	[self.window presentWindowWithMinimumSize:CGSizeMake(200, 100)
								  maximumSize:CGSizeMake(800, 600)
								   completion:nil];

	XCTAssertEqual(self.api.rangedRequests, 1u);
	XCTAssertEqual(self.api.fixedRequests, 0u);
	XCTAssertEqualWithAccuracy(self.api.lastMaxSize.width, 800, 1e-9);
	XCTAssertTrue(self.window.isWindowPresented);
}

/*! @abstract A ranged present falls back to a fixed v1 window at the minimum size when the host does not vend v2. */
- (void)testARangedPresentFallsBackToAFixedV1Window
{
	self.effect.manager.vendsV2 = NO;
	self.api.stagedParentView = FxGripWindowTestView();

	[self.window presentWindowWithMinimumSize:CGSizeMake(200, 100)
								  maximumSize:CGSizeMake(800, 600)
								   completion:nil];

	XCTAssertEqual(self.api.rangedRequests, 0u);
	XCTAssertEqual(self.api.fixedRequests, 1u, @"v1 fallback at the minimum size");
	XCTAssertEqualWithAccuracy(self.api.lastMinSize.width, 200, 1e-9);
}

/*! @abstract Setting the content view while presented removes the old content and installs the new one in the parent. */
- (void)testSettingTheContentViewWhilePresentedSwapsIt
{
	NSView *parent = FxGripWindowTestView();
	self.api.stagedParentView = parent;
	NSView *first = FxGripWindowTestView();
	self.window.contentView = first;
	[self.window presentWindowOfSize:CGSizeMake(320, 200) completion:nil];
	XCTAssertEqual(first.superview, parent);

	NSView *second = FxGripWindowTestView();
	self.window.contentView = second;
	XCTAssertNil(first.superview, @"the old content leaves the window");
	XCTAssertEqual(second.superview, parent, @"the new content installs in place");
}

/*! @abstract Closing calls the v3 close API, clears the presented state and parent, and removes the content view. */
- (void)testCloseUsesV3AndClearsState
{
	self.effect.manager.vendsV3 = YES;
	self.api.stagedParentView = FxGripWindowTestView();
	NSView *content = FxGripWindowTestView();
	self.window.contentView = content;
	[self.window presentWindowOfSize:CGSizeMake(320, 200) completion:nil];

	XCTAssertTrue([self.window closeWindow]);
	XCTAssertEqual(self.api.closeRequests, 1u);
	XCTAssertFalse(self.window.isWindowPresented);
	XCTAssertNil(self.window.windowParentView);
	XCTAssertNil(content.superview);
}

/*! @abstract Closing without a v3 API clears the presented state and returns NO without calling the host. */
- (void)testCloseWithoutV3ClearsStateAndReturnsNO
{
	self.effect.manager.vendsV3 = NO;
	self.api.stagedParentView = FxGripWindowTestView();
	[self.window presentWindowOfSize:CGSizeMake(320, 200) completion:nil];

	XCTAssertFalse([self.window closeWindow]);
	XCTAssertEqual(self.api.closeRequests, 0u);
	XCTAssertFalse(self.window.isWindowPresented, @"state clears even when the host cannot close");
}

/*! @abstract noteWindowClosed clears the presented state and parent view so a later present starts fresh. */
- (void)testNoteWindowClosedResetsForTheNextPresent
{
	self.api.stagedParentView = FxGripWindowTestView();
	[self.window presentWindowOfSize:CGSizeMake(320, 200) completion:nil];
	XCTAssertTrue(self.window.isWindowPresented);

	[self.window noteWindowClosed];
	XCTAssertFalse(self.window.isWindowPresented);
	XCTAssertNil(self.window.windowParentView);
}

@end
