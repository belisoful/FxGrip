/*!
	@file       FxGripVideoViewParameterTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-10
	@header     FxGripVideoViewParameterTests
	@abstract   Tests the video player view and its custom parameter.
	@discussion Introduced in FxGrip 0.1.0. The tests cover the parameter's type identity, the custom
	            control it registers and the flags it forces on, the whitelist it seeds, and the view it
	            vends. The view tests cover the routing of a URL to AV playback, to the web view, or to
	            the blocked placeholder, the height and flag keys, the teardown between routes, the loop
	            and autoplay flags against a real local media file, and the navigation policy the
	            whitelist drives.
*/

#import <XCTest/XCTest.h>
#import <AppKit/AppKit.h>
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import <WebKit/WebKit.h>
#import "FxGripParameterClassTestSupport.h"
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripDictionary.h>
#import <FxGrip/FxGripURLWhitelist.h>
#import <FxGrip/FxGripVideoView.h>
#import <FxGrip/FxGripVideoViewParameter.h>

static const FxParameterId kVideoTestParameter = 77;

/*! A local media file every macOS install carries, so AV playback is testable without the network. */
static NSString *const kVideoTestLocalMedia = @"/System/Library/Sounds/Ping.aiff";

#pragma mark - Probes

/*! The routing entry point the window-entry hook calls. */
@interface FxGripVideoView (FxGripVideoViewParameterTests)
- (void)applyContent;
- (BOOL)isDirectMediaURL:(NSURL *)url;
@end

/*! Carries a request to the navigation-policy delegate method, which reads nothing else. */
@interface FxGripVideoTestNavigationAction : NSObject
@property (nonatomic, strong) NSURLRequest *request;
@end

@implementation FxGripVideoTestNavigationAction
@end

#pragma mark - Tests

@interface FxGripVideoViewParameterTests : XCTestCase
@property (nonatomic, strong) FxGripParamClassTestEffect *effect;
@property (nonatomic, strong) NSMutableArray<NSWindow *> *windows;
@end

@implementation FxGripVideoViewParameterTests

- (void)setUp
{
	[super setUp];
	self.effect = [FxGripParamClassTestEffect.alloc init];
	self.windows = [NSMutableArray array];
}

- (void)tearDown
{
	self.effect = nil;
	self.windows = nil;
	[super tearDown];
}

#pragma mark Helpers

- (NSDictionary *)call
{
	return self.effect.creationCall;
}

- (NSMutableDictionary *)configWithDefault:(nullable NSDictionary *)declared
{
	NSDictionary *extra = declared ? @{kFxParameterProperty_Default: declared} : nil;
	return FxGripParamClassTestConfig(kVideoTestParameter, kFxParameterType_VideoView, @"Tutorial", extra);
}

- (FxGripVideoViewParameter *)parameterWithDefault:(nullable NSDictionary *)declared
{
	return [FxGripVideoViewParameter.alloc initWithDictionary:[self configWithDefault:declared]
													   effect:(id)self.effect];
}

/*! Hosts a view in an off-screen window, which is what makes the control apply its content. */
- (void)hostView:(NSView *)view
{
	Class windowClass = NSClassFromString(@"NSWindow");
	NSWindow *window = [[windowClass alloc] initWithContentRect:NSMakeRect(0, 0, 320, 200)
													 styleMask:NSWindowStyleMaskBorderless
													   backing:NSBackingStoreBuffered
														 defer:NO];
	[window.contentView addSubview:view];
	[self.windows addObject:window];
}

- (FxGripVideoView *)hostedView
{
	FxGripVideoView *view = [FxGripVideoView.alloc initWithFrame:NSMakeRect(0, 0, 320, kFxGripVideoDefaultHeight)];
	[self hostView:view];
	return view;
}

- (FxGripDictionary *)valueWithURL:(nullable NSString *)urlString extra:(nullable NSDictionary *)extra
{
	NSMutableDictionary *contents = [NSMutableDictionary dictionaryWithDictionary:extra ?: @{}];
	if (urlString != nil) {
		contents[kFxGripVideoKey_URL] = urlString;
	}
	return [FxGripDictionary dictionaryWithDictionary:contents];
}

- (nullable NSView *)subviewOfClassNamed:(NSString *)name in:(NSView *)view
{
	Class wanted = NSClassFromString(name);
	for (NSView *subview in view.subviews) {
		if ([subview isKindOfClass:wanted]) {
			return subview;
		}
	}
	return nil;
}

- (nullable NSTextField *)placeholderIn:(NSView *)view
{
	return (NSTextField *)[self subviewOfClassNamed:@"NSTextField" in:view];
}

/*! Runs the main run loop until the condition holds or the timeout passes. */
- (BOOL)pumpUntil:(BOOL (^)(void))condition timeout:(NSTimeInterval)timeout
{
	NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
	while (!condition()) {
		if (deadline.timeIntervalSinceNow < 0) {
			return NO;
		}
		[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
	}
	return YES;
}

- (AVPlayer *)playerIn:(FxGripVideoView *)view
{
	AVPlayerView *playerView = (AVPlayerView *)[self subviewOfClassNamed:@"AVPlayerView" in:view];
	return playerView.player;
}

#pragma mark Type identity

/*! @abstract The video parameter reports the video-view FxPlug type and the matching type string. */
- (void)testTheVideoParameterReportsItsFxPlugTypeAndTypeString
{
	XCTAssertEqual(FxGripVideoViewParameter.parameterType, FxParameterType_VideoView);
	XCTAssertEqualObjects(FxGripVideoViewParameter.parameterTypeString, kFxParameterType_VideoView);
}

/*! @abstract The decodable value classes cover the parameter dictionary and every class it may carry. */
- (void)testTheVideoParameterDecodesTheDictionaryAndItsElementClasses
{
	NSSet<Class> *classes = FxGripVideoViewParameter.customValueClasses;

	XCTAssertTrue([classes containsObject:FxGripDictionary.class]);
	for (Class element in FxGripDictionary.classesForParameter) {
		XCTAssertTrue([classes containsObject:element], @"%@ is decodable", element);
	}
}

#pragma mark Creation

/*! @abstract Creation registers a custom control with an empty host name, because the player draws its own frame. */
- (void)testCreationRegistersACustomControlWithNoHostName
{
	XCTAssertTrue([FxGripVideoViewParameter addParameter:[self configWithDefault:nil] toEffect:(id)self.effect]);

	XCTAssertEqualObjects(self.call[@"method"], @"custom");
	XCTAssertEqualObjects(self.call[@"name"], @"");
	XCTAssertEqualObjects(self.call[@"id"], @(kVideoTestParameter));
}

/*! @abstract Creation adds the custom-UI, not-animatable, full-width, and no-state flags to the declared flags. */
- (void)testCreationAddsTheCustomControlFlagsToTheDeclaredFlags
{
	NSMutableDictionary *config = [self configWithDefault:nil];
	config[kFxParameterProperty_Flags] = @(kFxParameterFlag_HIDDEN);

	XCTAssertTrue([FxGripVideoViewParameter addParameter:config toEffect:(id)self.effect]);

	FxParameterFlags expected = kFxParameterFlag_HIDDEN | kFxParameterFlag_CUSTOM_UI
		| kFxParameterFlag_NOT_ANIMATABLE | kFxParameterFlag_USE_FULL_VIEW_WIDTH | kFxParameterFlag_NOSTATE;
	XCTAssertEqualObjects(self.call[@"flags"], @(expected));
}

/*! @abstract A configuration naming no whitelist is seeded with the common video-hosting domains. */
- (void)testCreationSeedsTheDefaultVideoWhitelist
{
	XCTAssertTrue([FxGripVideoViewParameter addParameter:[self configWithDefault:@{kFxGripVideoKey_URL: @"about:blank"}]
												toEffect:(id)self.effect]);

	FxGripDictionary *value = self.call[@"default"];
	XCTAssertEqualObjects([value objectForKey:kFxGripVideoKey_Whitelist],
						  [FxGripURLWhitelist defaultVideoWhitelist].patterns);
	XCTAssertEqualObjects([value objectForKey:kFxGripVideoKey_URL], @"about:blank");
}

/*! @abstract A declared whitelist is carried through untouched. */
- (void)testCreationKeepsADeclaredWhitelist
{
	NSArray *patterns = @[@"*.example.com"];

	XCTAssertTrue([FxGripVideoViewParameter addParameter:[self configWithDefault:@{kFxGripVideoKey_Whitelist: patterns}]
												toEffect:(id)self.effect]);

	FxGripDictionary *value = self.call[@"default"];
	XCTAssertEqualObjects([value objectForKey:kFxGripVideoKey_Whitelist], patterns);
}

/*! @abstract A declared default that is not a dictionary still creates a parameter with the seeded whitelist. */
- (void)testCreationToleratesADeclaredDefaultOfAnotherClass
{
	NSMutableDictionary *config = [self configWithDefault:nil];
	config[kFxParameterProperty_Default] = @"not a configuration";

	XCTAssertTrue([FxGripVideoViewParameter addParameter:config toEffect:(id)self.effect]);

	FxGripDictionary *value = self.call[@"default"];
	XCTAssertEqualObjects([value objectForKey:kFxGripVideoKey_Whitelist],
						  [FxGripURLWhitelist defaultVideoWhitelist].patterns);
}

/*! @abstract A host that refuses the creation is reported. */
- (void)testAHostRefusalIsReported
{
	self.effect.apiManager.paramCreateAPIv5.succeeds = NO;

	XCTAssertFalse([FxGripVideoViewParameter addParameter:[self configWithDefault:nil] toEffect:(id)self.effect]);
}

#pragma mark The vended view

/*! @abstract The parameter vends a video view seeded with the declared row height. */
- (void)testTheVendedViewTakesItsHeightFromTheDeclaredConfiguration
{
	FxGripVideoViewParameter *parameter = [self parameterWithDefault:@{kFxGripVideoKey_Height: @(96.0)}];

	NSView *view = [parameter newParameterView];

	XCTAssertTrue([view isKindOfClass:FxGripVideoView.class]);
	XCTAssertEqualWithAccuracy(view.intrinsicContentSize.height, 96.0, 1e-9);
}

/*! @abstract Without a declared configuration the vended view keeps the default row height. */
- (void)testTheVendedViewKeepsTheDefaultHeightWithoutAConfiguration
{
	FxGripVideoViewParameter *parameter = [self parameterWithDefault:nil];

	NSView *view = [parameter newParameterView];

	XCTAssertEqualWithAccuracy(view.intrinsicContentSize.height, kFxGripVideoDefaultHeight, 1e-9);
	XCTAssertEqualWithAccuracy(view.intrinsicContentSize.width, NSViewNoIntrinsicMetric, 1e-9);
}

#pragma mark View geometry and data

/*! @abstract The player view lays out top-down, as the inspector rows do. */
- (void)testThePlayerViewIsFlipped
{
	XCTAssertTrue([FxGripVideoView.alloc initWithFrame:NSZeroRect].isFlipped);
}

/*! @abstract A value of another class leaves the view's configuration untouched. */
- (void)testAValueOfAnotherClassIsIgnored
{
	FxGripVideoView *view = [FxGripVideoView.alloc initWithFrame:NSMakeRect(0, 0, 320, 180)];

	[view updateFromCustomData:(id)@"not a dictionary"];

	XCTAssertEqualWithAccuracy(view.intrinsicContentSize.height, kFxGripVideoDefaultHeight, 1e-9);
}

/*! @abstract A height of zero or less is refused, so the row never collapses. */
- (void)testANonPositiveHeightIsRefused
{
	FxGripVideoView *view = [FxGripVideoView.alloc initWithFrame:NSMakeRect(0, 0, 320, 180)];

	[view updateFromCustomData:[self valueWithURL:nil extra:@{kFxGripVideoKey_Height: @(0.0)}]];

	XCTAssertEqualWithAccuracy(view.intrinsicContentSize.height, kFxGripVideoDefaultHeight, 1e-9);
}

/*! @abstract The direct-media test recognizes the streaming and container extensions, whatever their case. */
- (void)testTheDirectMediaExtensionsAreRecognized
{
	FxGripVideoView *view = [FxGripVideoView.alloc initWithFrame:NSZeroRect];

	for (NSString *extension in @[@"mp4", @"m4v", @"MOV", @"m3u8", @"webm"]) {
		NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://media.test/clip.%@", extension]];
		XCTAssertTrue([view isDirectMediaURL:url], @"%@ is direct media", extension);
	}
	XCTAssertFalse([view isDirectMediaURL:[NSURL URLWithString:@"https://media.test/watch"]]);
}

#pragma mark Routing

/*! @abstract A value pushed before the control is on screen starts no player and no web view. */
- (void)testAValuePushedOffScreenStartsNothing
{
	FxGripVideoView *view = [FxGripVideoView.alloc initWithFrame:NSMakeRect(0, 0, 320, 180)];

	[view updateFromCustomData:[self valueWithURL:@"about:blank" extra:nil]];

	XCTAssertNil([self subviewOfClassNamed:@"WKWebView" in:view]);
	XCTAssertNil([self subviewOfClassNamed:@"AVPlayerView" in:view]);
}

/*! @abstract A remote URL off the whitelist shows the blocked placeholder and loads nothing. */
- (void)testARemoteURLOffTheWhitelistIsBlocked
{
	FxGripVideoView *view = [self hostedView];

	[view updateFromCustomData:[self valueWithURL:@"https://blocked.test/clip.mp4"
										    extra:@{kFxGripVideoKey_Whitelist: @[@"*.allowed.test"]}]];

	NSTextField *placeholder = [self placeholderIn:view];
	XCTAssertFalse(placeholder.hidden);
	XCTAssertTrue([placeholder.stringValue containsString:@"blocked by the whitelist"]);
	XCTAssertNil([self subviewOfClassNamed:@"AVPlayerView" in:view]);
	XCTAssertNil([self subviewOfClassNamed:@"WKWebView" in:view]);
}

/*! @abstract An empty URL shows an empty, hidden placeholder rather than a blocked message. */
- (void)testAnEmptyURLShowsAHiddenPlaceholder
{
	FxGripVideoView *view = [self hostedView];

	[view updateFromCustomData:[self valueWithURL:@"" extra:nil]];

	NSTextField *placeholder = [self placeholderIn:view];
	XCTAssertTrue(placeholder.hidden);
	XCTAssertEqualObjects(placeholder.stringValue, @"");
}

/*! @abstract A non-media, non-file URL loads in the embedded web view. */
- (void)testANonMediaURLLoadsInTheWebView
{
	FxGripVideoView *view = [self hostedView];

	[view updateFromCustomData:[self valueWithURL:@"about:blank" extra:nil]];

	XCTAssertNotNil([self subviewOfClassNamed:@"WKWebView" in:view]);
	XCTAssertTrue([self placeholderIn:view].hidden);
}

/*! @abstract A local file URL plays through the inline AV player. */
- (void)testAFileURLPlaysThroughTheAVPlayer
{
	if (![NSFileManager.defaultManager fileExistsAtPath:kVideoTestLocalMedia]) {
		XCTSkip(@"the system media file this test plays is absent");
	}
	FxGripVideoView *view = [self hostedView];

	[view updateFromCustomData:[self valueWithURL:[NSURL fileURLWithPath:kVideoTestLocalMedia].absoluteString
										    extra:nil]];

	AVPlayerView *playerView = (AVPlayerView *)[self subviewOfClassNamed:@"AVPlayerView" in:view];
	XCTAssertNotNil(playerView);
	XCTAssertNotNil(playerView.player);
	XCTAssertEqual(playerView.controlsStyle, AVPlayerViewControlsStyleInline);
	XCTAssertTrue([self placeholderIn:view].hidden);
}

/*! @abstract Switching from the web view to media playback tears the web view down, and back again tears the player down. */
- (void)testSwitchingRoutesTearsTheOtherRouteDown
{
	if (![NSFileManager.defaultManager fileExistsAtPath:kVideoTestLocalMedia]) {
		XCTSkip(@"the system media file this test plays is absent");
	}
	FxGripVideoView *view = [self hostedView];
	NSString *fileURL = [NSURL fileURLWithPath:kVideoTestLocalMedia].absoluteString;

	[view updateFromCustomData:[self valueWithURL:@"about:blank" extra:nil]];
	XCTAssertNotNil([self subviewOfClassNamed:@"WKWebView" in:view]);

	[view updateFromCustomData:[self valueWithURL:fileURL extra:nil]];
	XCTAssertNil([self subviewOfClassNamed:@"WKWebView" in:view], @"the web view is torn down");
	XCTAssertNotNil([self subviewOfClassNamed:@"AVPlayerView" in:view]);

	[view updateFromCustomData:[self valueWithURL:@"about:blank" extra:nil]];
	XCTAssertNil([self subviewOfClassNamed:@"AVPlayerView" in:view], @"the player is torn down");
	XCTAssertNotNil([self subviewOfClassNamed:@"WKWebView" in:view]);
}

/*! @abstract Blocking a URL after a route was live tears both the player and the web view down. */
- (void)testABlockedURLTearsEveryRouteDown
{
	FxGripVideoView *view = [self hostedView];
	[view updateFromCustomData:[self valueWithURL:@"about:blank" extra:nil]];
	XCTAssertNotNil([self subviewOfClassNamed:@"WKWebView" in:view]);

	[view updateFromCustomData:[self valueWithURL:@"https://blocked.test/watch"
										    extra:@{kFxGripVideoKey_Whitelist: @[@"*.allowed.test"]}]];

	XCTAssertNil([self subviewOfClassNamed:@"WKWebView" in:view]);
	XCTAssertNil([self subviewOfClassNamed:@"AVPlayerView" in:view]);
	XCTAssertFalse([self placeholderIn:view].hidden);
}

/*! @abstract Entering a window applies the value the control was given while it was off screen. */
- (void)testEnteringAWindowAppliesTheStoredValue
{
	FxGripVideoView *view = [FxGripVideoView.alloc initWithFrame:NSMakeRect(0, 0, 320, 180)];
	[view updateFromCustomData:[self valueWithURL:@"about:blank" extra:nil]];
	XCTAssertNil([self subviewOfClassNamed:@"WKWebView" in:view]);

	[self hostView:view];

	XCTAssertNotNil([self subviewOfClassNamed:@"WKWebView" in:view], @"the window entry applies the content");
}

#pragma mark Playback flags

/*! @abstract The autoplay flag starts the player, and the loop flag restarts it at the end of the item. */
- (void)testTheAutoplayAndLoopFlagsDriveThePlayer
{
	if (![NSFileManager.defaultManager fileExistsAtPath:kVideoTestLocalMedia]) {
		XCTSkip(@"the system media file this test plays is absent");
	}
	FxGripVideoView *view = [self hostedView];
	NSString *fileURL = [NSURL fileURLWithPath:kVideoTestLocalMedia].absoluteString;

	[view updateFromCustomData:[self valueWithURL:fileURL
											extra:@{kFxGripVideoKey_Autoplay: @YES, kFxGripVideoKey_Loop: @YES}]];

	AVPlayer *player = [self playerIn:view];
	XCTAssertNotNil(player);
	XCTAssertTrue([self pumpUntil:^BOOL{ return player.rate > 0.0; } timeout:5.0], @"autoplay starts playback");

	[player pause];
	XCTAssertEqualWithAccuracy(player.rate, 0.0, 1e-9);

	[NSNotificationCenter.defaultCenter postNotificationName:AVPlayerItemDidPlayToEndTimeNotification
													 object:player.currentItem];

	XCTAssertTrue([self pumpUntil:^BOOL{ return player.rate > 0.0; } timeout:5.0], @"the loop restarts playback");
}

/*! @abstract Without the loop flag the end of the item restarts nothing. */
- (void)testWithoutTheLoopFlagTheEndOfTheItemRestartsNothing
{
	if (![NSFileManager.defaultManager fileExistsAtPath:kVideoTestLocalMedia]) {
		XCTSkip(@"the system media file this test plays is absent");
	}
	FxGripVideoView *view = [self hostedView];
	NSString *fileURL = [NSURL fileURLWithPath:kVideoTestLocalMedia].absoluteString;

	[view updateFromCustomData:[self valueWithURL:fileURL extra:@{kFxGripVideoKey_Loop: @NO}]];
	AVPlayer *player = [self playerIn:view];
	XCTAssertNotNil(player);

	[NSNotificationCenter.defaultCenter postNotificationName:AVPlayerItemDidPlayToEndTimeNotification
													 object:player.currentItem];
	[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];

	XCTAssertEqualWithAccuracy(player.rate, 0.0, 1e-9);
}

#pragma mark Navigation policy

/*! @abstract A navigation the whitelist allows is permitted. */
- (void)testANavigationOnTheWhitelistIsAllowed
{
	FxGripVideoView *view = [self hostedView];
	[view updateFromCustomData:[self valueWithURL:@"about:blank"
										    extra:@{kFxGripVideoKey_Whitelist: @[@"*.allowed.test"]}]];

	FxGripVideoTestNavigationAction *action = [FxGripVideoTestNavigationAction.alloc init];
	action.request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://player.allowed.test/embed"]];

	__block WKNavigationActionPolicy policy = WKNavigationActionPolicyCancel;
	WKWebView *noWebView = nil;
	[(id<WKNavigationDelegate>)view webView:noWebView
			decidePolicyForNavigationAction:(id)action
							decisionHandler:^(WKNavigationActionPolicy decision) { policy = decision; }];

	XCTAssertEqual(policy, WKNavigationActionPolicyAllow);
}

/*! @abstract A navigation the page starts to a URL off the whitelist is cancelled. */
- (void)testANavigationOffTheWhitelistIsCancelled
{
	FxGripVideoView *view = [self hostedView];
	[view updateFromCustomData:[self valueWithURL:@"about:blank"
										    extra:@{kFxGripVideoKey_Whitelist: @[@"*.allowed.test"]}]];

	FxGripVideoTestNavigationAction *action = [FxGripVideoTestNavigationAction.alloc init];
	action.request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://elsewhere.test/track"]];

	__block WKNavigationActionPolicy policy = WKNavigationActionPolicyAllow;
	WKWebView *noWebView = nil;
	[(id<WKNavigationDelegate>)view webView:noWebView
			decidePolicyForNavigationAction:(id)action
							decisionHandler:^(WKNavigationActionPolicy decision) { policy = decision; }];

	XCTAssertEqual(policy, WKNavigationActionPolicyCancel);
}

/*! @abstract A navigation action carrying no URL is allowed, because there is nothing to match. */
- (void)testANavigationWithoutAURLIsAllowed
{
	FxGripVideoView *view = [self hostedView];
	[view updateFromCustomData:[self valueWithURL:@"about:blank"
										    extra:@{kFxGripVideoKey_Whitelist: @[@"*.allowed.test"]}]];

	FxGripVideoTestNavigationAction *action = [FxGripVideoTestNavigationAction.alloc init];
	action.request = [NSURLRequest.alloc init];

	__block WKNavigationActionPolicy policy = WKNavigationActionPolicyCancel;
	WKWebView *noWebView = nil;
	[(id<WKNavigationDelegate>)view webView:noWebView
			decidePolicyForNavigationAction:(id)action
							decisionHandler:^(WKNavigationActionPolicy decision) { policy = decision; }];

	XCTAssertEqual(policy, WKNavigationActionPolicyAllow);
}

@end
