//
//  FxGripWindowTests.m
//  FxGripTests
//
//  Covers the window extension's lifecycle against stubbed FxRemoteWindowAPI versions: the
//  host reply, content-view installation and swapping, version fallback, and close. AppKit
//  classes are reached by name; the stub reply runs synchronously so no waiting is needed.
//

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripWindow.h>
#import <FxGrip/FxGripErrors.h>

static NSView *FxWindowTestView(void)
{
	return [[NSClassFromString(@"NSView") alloc] initWithFrame:NSMakeRect(0, 0, 320, 200)];
}

#pragma mark - Stubs

/*! A remote-window API stub: replies synchronously with a staged parent view or error, and
	counts calls. Which protocol versions it admits to is configured per test. */
@interface FxWindowStubAPI : NSObject
@property (nonatomic, strong, nullable) NSView *stagedParentView;
@property (nonatomic, strong, nullable) NSError *stagedError;
@property (nonatomic, assign) NSUInteger fixedRequests;
@property (nonatomic, assign) NSUInteger rangedRequests;
@property (nonatomic, assign) NSUInteger closeRequests;
@property (nonatomic, assign) CGSize lastMinSize;
@property (nonatomic, assign) CGSize lastMaxSize;
@end

@implementation FxWindowStubAPI

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
@interface FxWindowStubAPIManager : NSObject
@property (nonatomic, strong, nullable) FxWindowStubAPI *windowAPI;
@property (nonatomic, assign) BOOL vendsV2;
@property (nonatomic, assign) BOOL vendsV3;
@end

@implementation FxWindowStubAPIManager
- (id)remoteWindowAPIv1 { return self.windowAPI; }
- (id)remoteWindowAPIv2 { return self.vendsV2 ? self.windowAPI : nil; }
- (id)remoteWindowAPIv3 { return self.vendsV3 ? self.windowAPI : nil; }
@end

/*! The effect stub: only the apiManager the extension reaches. */
@interface FxWindowStubEffect : NSObject
@property (nonatomic, strong) FxWindowStubAPIManager *manager;
@end

@implementation FxWindowStubEffect

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
@property (nonatomic, strong) FxWindowStubEffect *effect;
@property (nonatomic, strong) FxWindowStubAPI *api;
@end

@implementation FxGripWindowTests

- (void)setUp
{
	[super setUp];
	self.api = [FxWindowStubAPI new];
	self.effect = [FxWindowStubEffect new];
	self.effect.manager = [FxWindowStubAPIManager new];
	self.effect.manager.windowAPI = self.api;
	self.window = [FxGripWindow new];
	[self.window extLoadWithEffect:(id)self.effect];
}

- (void)tearDown
{
	self.window = nil;
	[super tearDown];
}

- (void)testTheExtensionKeyIsStable
{
	XCTAssertEqualObjects(self.window.extKey, FxGripWindowExtensionKey);
	XCTAssertEqualObjects(FxGripWindowExtensionKey, @"FxGripWindow");
}

- (void)testPresentingStoresTheParentAndInstallsTheContent
{
	NSView *parent = FxWindowTestView();
	NSView *content = FxWindowTestView();
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

- (void)testARangedPresentUsesV2WhenVended
{
	self.effect.manager.vendsV2 = YES;
	self.api.stagedParentView = FxWindowTestView();

	[self.window presentWindowWithMinimumSize:CGSizeMake(200, 100)
								  maximumSize:CGSizeMake(800, 600)
								   completion:nil];

	XCTAssertEqual(self.api.rangedRequests, 1u);
	XCTAssertEqual(self.api.fixedRequests, 0u);
	XCTAssertEqualWithAccuracy(self.api.lastMaxSize.width, 800, 1e-9);
	XCTAssertTrue(self.window.isWindowPresented);
}

- (void)testARangedPresentFallsBackToAFixedV1Window
{
	self.effect.manager.vendsV2 = NO;
	self.api.stagedParentView = FxWindowTestView();

	[self.window presentWindowWithMinimumSize:CGSizeMake(200, 100)
								  maximumSize:CGSizeMake(800, 600)
								   completion:nil];

	XCTAssertEqual(self.api.rangedRequests, 0u);
	XCTAssertEqual(self.api.fixedRequests, 1u, @"v1 fallback at the minimum size");
	XCTAssertEqualWithAccuracy(self.api.lastMinSize.width, 200, 1e-9);
}

- (void)testSettingTheContentViewWhilePresentedSwapsIt
{
	NSView *parent = FxWindowTestView();
	self.api.stagedParentView = parent;
	NSView *first = FxWindowTestView();
	self.window.contentView = first;
	[self.window presentWindowOfSize:CGSizeMake(320, 200) completion:nil];
	XCTAssertEqual(first.superview, parent);

	NSView *second = FxWindowTestView();
	self.window.contentView = second;
	XCTAssertNil(first.superview, @"the old content leaves the window");
	XCTAssertEqual(second.superview, parent, @"the new content installs in place");
}

- (void)testCloseUsesV3AndClearsState
{
	self.effect.manager.vendsV3 = YES;
	self.api.stagedParentView = FxWindowTestView();
	NSView *content = FxWindowTestView();
	self.window.contentView = content;
	[self.window presentWindowOfSize:CGSizeMake(320, 200) completion:nil];

	XCTAssertTrue([self.window closeWindow]);
	XCTAssertEqual(self.api.closeRequests, 1u);
	XCTAssertFalse(self.window.isWindowPresented);
	XCTAssertNil(self.window.windowParentView);
	XCTAssertNil(content.superview);
}

- (void)testCloseWithoutV3ClearsStateAndReturnsNO
{
	self.effect.manager.vendsV3 = NO;
	self.api.stagedParentView = FxWindowTestView();
	[self.window presentWindowOfSize:CGSizeMake(320, 200) completion:nil];

	XCTAssertFalse([self.window closeWindow]);
	XCTAssertEqual(self.api.closeRequests, 0u);
	XCTAssertFalse(self.window.isWindowPresented, @"state clears even when the host cannot close");
}

- (void)testNoteWindowClosedResetsForTheNextPresent
{
	self.api.stagedParentView = FxWindowTestView();
	[self.window presentWindowOfSize:CGSizeMake(320, 200) completion:nil];
	XCTAssertTrue(self.window.isWindowPresented);

	[self.window noteWindowClosed];
	XCTAssertFalse(self.window.isWindowPresented);
	XCTAssertNil(self.window.windowParentView);
}

@end
