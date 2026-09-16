/*!
	@file       FxGripWebViewParameterTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-10
	@header     FxGripWebViewParameterTests
	@abstract   Tests the web page view and its custom parameter.
	@discussion Introduced in FxGrip 0.1.0. The tests cover the parameter's type identity, the custom
	            control it registers and the flags it forces on, the all-sites whitelist it seeds, and
	            the view it vends. The view tests cover the deferred web view, the blocked placeholder,
	            the height and whitelist keys, and the navigation policy the whitelist drives.
*/

#import <XCTest/XCTest.h>
#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>
#import "FxGripParameterClassTestSupport.h"
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripDictionary.h>
#import <FxGrip/FxGripURLWhitelist.h>
#import <FxGrip/FxGripWebView.h>
#import <FxGrip/FxGripWebViewParameter.h>

static const FxParameterId kWebViewTestParameter = 78;

#pragma mark - Probes

/*! Carries a request to the navigation-policy delegate method, which reads nothing else. */
@interface FxGripWebViewTestNavigationAction : NSObject
@property (nonatomic, strong) NSURLRequest *request;
@end

@implementation FxGripWebViewTestNavigationAction
@end

#pragma mark - Tests

@interface FxGripWebViewParameterTests : XCTestCase
@property (nonatomic, strong) FxGripParamClassTestEffect *effect;
@property (nonatomic, strong) NSMutableArray<NSWindow *> *windows;
@end

@implementation FxGripWebViewParameterTests

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
	return FxGripParamClassTestConfig(kWebViewTestParameter, kFxParameterType_WebView, @"Help Page", extra);
}

- (FxGripWebViewParameter *)parameterWithDefault:(nullable NSDictionary *)declared
{
	return [FxGripWebViewParameter.alloc initWithDictionary:[self configWithDefault:declared]
													 effect:(id)self.effect];
}

/*! Hosts a view in an off-screen window, which is what makes the control apply its content. */
- (void)hostView:(NSView *)view
{
	Class windowClass = NSClassFromString(@"NSWindow");
	NSWindow *window = [[windowClass alloc] initWithContentRect:NSMakeRect(0, 0, 320, 240)
													 styleMask:NSWindowStyleMaskBorderless
													   backing:NSBackingStoreBuffered
														 defer:NO];
	[window.contentView addSubview:view];
	[self.windows addObject:window];
}

- (FxGripWebPageView *)hostedView
{
	FxGripWebPageView *view = [FxGripWebPageView.alloc initWithFrame:NSMakeRect(0, 0, 320, kFxGripWebViewDefaultHeight)];
	[self hostView:view];
	return view;
}

- (FxGripDictionary *)valueWithURL:(nullable NSString *)urlString extra:(nullable NSDictionary *)extra
{
	NSMutableDictionary *contents = [NSMutableDictionary dictionaryWithDictionary:extra ?: @{}];
	if (urlString != nil) {
		contents[kFxGripWebViewKey_URL] = urlString;
	}
	return [FxGripDictionary dictionaryWithDictionary:contents];
}

- (nullable NSView *)webViewIn:(NSView *)view
{
	Class wanted = NSClassFromString(@"WKWebView");
	for (NSView *subview in view.subviews) {
		if ([subview isKindOfClass:wanted]) {
			return subview;
		}
	}
	return nil;
}

- (nullable NSTextField *)placeholderIn:(NSView *)view
{
	for (NSView *subview in view.subviews) {
		if ([subview isKindOfClass:NSTextField.class]) {
			return (NSTextField *)subview;
		}
	}
	return nil;
}

- (WKNavigationActionPolicy)policyFor:(NSString *)urlString on:(FxGripWebPageView *)view
{
	FxGripWebViewTestNavigationAction *action = [FxGripWebViewTestNavigationAction.alloc init];
	action.request = urlString.length ? [NSURLRequest requestWithURL:[NSURL URLWithString:urlString]]
									  : [NSURLRequest.alloc init];
	__block WKNavigationActionPolicy policy = (WKNavigationActionPolicy)NSNotFound;
	WKWebView *noWebView = nil;
	[(id<WKNavigationDelegate>)view webView:noWebView
			decidePolicyForNavigationAction:(id)action
							decisionHandler:^(WKNavigationActionPolicy decision) { policy = decision; }];
	return policy;
}

#pragma mark Type identity

/*! @abstract The web view parameter reports the web-view FxPlug type and the matching type string. */
- (void)testTheWebViewParameterReportsItsFxPlugTypeAndTypeString
{
	XCTAssertEqual(FxGripWebViewParameter.parameterType, FxParameterType_WebView);
	XCTAssertEqualObjects(FxGripWebViewParameter.parameterTypeString, kFxParameterType_WebView);
}

/*! @abstract The decodable value classes cover the parameter dictionary and every class it may carry. */
- (void)testTheWebViewParameterDecodesTheDictionaryAndItsElementClasses
{
	NSSet<Class> *classes = FxGripWebViewParameter.customValueClasses;

	XCTAssertTrue([classes containsObject:FxGripDictionary.class]);
	for (Class element in FxGripDictionary.classesForParameter) {
		XCTAssertTrue([classes containsObject:element], @"%@ is decodable", element);
	}
}

#pragma mark Creation

/*! @abstract Creation registers a custom control with an empty host name and adds the custom-control flags. */
- (void)testCreationRegistersACustomControlWithNoHostNameAndTheControlFlags
{
	NSMutableDictionary *config = [self configWithDefault:nil];
	config[kFxParameterProperty_Flags] = @(kFxParameterFlag_DISABLED);

	XCTAssertTrue([FxGripWebViewParameter addParameter:config toEffect:(id)self.effect]);

	FxParameterFlags expected = kFxParameterFlag_DISABLED | kFxParameterFlag_CUSTOM_UI
		| kFxParameterFlag_NOT_ANIMATABLE | kFxParameterFlag_USE_FULL_VIEW_WIDTH | kFxParameterFlag_NOSTATE;
	XCTAssertEqualObjects(self.call[@"method"], @"custom");
	XCTAssertEqualObjects(self.call[@"name"], @"");
	XCTAssertEqualObjects(self.call[@"id"], @(kWebViewTestParameter));
	XCTAssertEqualObjects(self.call[@"flags"], @(expected));
}

/*! @abstract A configuration naming no whitelist is seeded with the all-sites pattern. */
- (void)testCreationSeedsTheAllSitesWhitelist
{
	XCTAssertTrue([FxGripWebViewParameter addParameter:[self configWithDefault:nil] toEffect:(id)self.effect]);

	FxGripDictionary *value = self.call[@"default"];
	XCTAssertEqualObjects([value objectForKey:kFxGripWebViewKey_Whitelist], (@[@"*"]));
}

/*! @abstract A declared whitelist is carried through untouched. */
- (void)testCreationKeepsADeclaredWhitelist
{
	NSArray *patterns = @[@"docs.example.com"];

	XCTAssertTrue([FxGripWebViewParameter addParameter:[self configWithDefault:@{kFxGripWebViewKey_Whitelist: patterns}]
											  toEffect:(id)self.effect]);

	XCTAssertEqualObjects([(FxGripDictionary *)self.call[@"default"] objectForKey:kFxGripWebViewKey_Whitelist],
						  patterns);
}

/*! @abstract A declared default that is not a dictionary still creates a parameter with the seeded whitelist. */
- (void)testCreationToleratesADeclaredDefaultOfAnotherClass
{
	NSMutableDictionary *config = [self configWithDefault:nil];
	config[kFxParameterProperty_Default] = @(42);

	XCTAssertTrue([FxGripWebViewParameter addParameter:config toEffect:(id)self.effect]);

	XCTAssertEqualObjects([(FxGripDictionary *)self.call[@"default"] objectForKey:kFxGripWebViewKey_Whitelist],
						  (@[@"*"]));
}

/*! @abstract A host that refuses the creation is reported. */
- (void)testAHostRefusalIsReported
{
	self.effect.apiManager.paramCreateAPIv5.succeeds = NO;

	XCTAssertFalse([FxGripWebViewParameter addParameter:[self configWithDefault:nil] toEffect:(id)self.effect]);
}

#pragma mark The vended view

/*! @abstract The parameter vends a web page view seeded with the declared row height. */
- (void)testTheVendedViewTakesItsHeightFromTheDeclaredConfiguration
{
	FxGripWebViewParameter *parameter = [self parameterWithDefault:@{kFxGripWebViewKey_Height: @(320.0)}];

	NSView *view = [parameter newParameterView];

	XCTAssertTrue([view isKindOfClass:FxGripWebPageView.class]);
	XCTAssertEqualWithAccuracy(view.intrinsicContentSize.height, 320.0, 1e-9);
	XCTAssertEqualWithAccuracy(view.intrinsicContentSize.width, NSViewNoIntrinsicMetric, 1e-9);
}

/*! @abstract Without a declared configuration the vended view keeps the default row height. */
- (void)testTheVendedViewKeepsTheDefaultHeightWithoutAConfiguration
{
	NSView *view = [[self parameterWithDefault:nil] newParameterView];

	XCTAssertEqualWithAccuracy(view.intrinsicContentSize.height, kFxGripWebViewDefaultHeight, 1e-9);
}

#pragma mark View data

/*! @abstract The web page view lays out top-down, as the inspector rows do. */
- (void)testTheWebPageViewIsFlipped
{
	XCTAssertTrue([FxGripWebPageView.alloc initWithFrame:NSZeroRect].isFlipped);
}

/*! @abstract A value of another class leaves the view's configuration untouched. */
- (void)testAValueOfAnotherClassIsIgnored
{
	FxGripWebPageView *view = [FxGripWebPageView.alloc initWithFrame:NSMakeRect(0, 0, 320, 200)];

	[view updateFromCustomData:(id)@[@"not a dictionary"]];

	XCTAssertEqualWithAccuracy(view.intrinsicContentSize.height, kFxGripWebViewDefaultHeight, 1e-9);
}

/*! @abstract A height of zero or less is refused, so the row never collapses. */
- (void)testANonPositiveHeightIsRefused
{
	FxGripWebPageView *view = [FxGripWebPageView.alloc initWithFrame:NSMakeRect(0, 0, 320, 200)];

	[view updateFromCustomData:[self valueWithURL:nil extra:@{kFxGripWebViewKey_Height: @(-4.0)}]];

	XCTAssertEqualWithAccuracy(view.intrinsicContentSize.height, kFxGripWebViewDefaultHeight, 1e-9);
}

#pragma mark Loading

/*! @abstract No web content process starts for a control the user never reveals. */
- (void)testAValuePushedOffScreenStartsNoWebView
{
	FxGripWebPageView *view = [FxGripWebPageView.alloc initWithFrame:NSMakeRect(0, 0, 320, 200)];

	[view updateFromCustomData:[self valueWithURL:@"about:blank" extra:nil]];

	XCTAssertNil([self webViewIn:view]);
}

/*! @abstract A URL the whitelist allows loads in the web view and hides the placeholder. */
- (void)testAnAllowedURLLoadsInTheWebView
{
	FxGripWebPageView *view = [self hostedView];

	[view updateFromCustomData:[self valueWithURL:@"about:blank" extra:nil]];

	XCTAssertNotNil([self webViewIn:view]);
	XCTAssertTrue([self placeholderIn:view].hidden);
}

/*! @abstract Entering a window applies the value the control was given while it was off screen. */
- (void)testEnteringAWindowAppliesTheStoredValue
{
	FxGripWebPageView *view = [FxGripWebPageView.alloc initWithFrame:NSMakeRect(0, 0, 320, 200)];
	[view updateFromCustomData:[self valueWithURL:@"about:blank" extra:nil]];
	XCTAssertNil([self webViewIn:view]);

	[self hostView:view];

	XCTAssertNotNil([self webViewIn:view]);
}

/*! @abstract A URL off the whitelist shows the blocked placeholder and tears down any live web view. */
- (void)testABlockedURLShowsThePlaceholderAndTearsTheWebViewDown
{
	FxGripWebPageView *view = [self hostedView];
	[view updateFromCustomData:[self valueWithURL:@"about:blank" extra:nil]];
	XCTAssertNotNil([self webViewIn:view]);

	[view updateFromCustomData:[self valueWithURL:@"https://elsewhere.test/page"
										    extra:@{kFxGripWebViewKey_Whitelist: @[@"docs.allowed.test"]}]];

	XCTAssertNil([self webViewIn:view]);
	NSTextField *placeholder = [self placeholderIn:view];
	XCTAssertFalse(placeholder.hidden);
	XCTAssertTrue([placeholder.stringValue containsString:@"blocked by the whitelist"]);
	XCTAssertTrue([placeholder.stringValue containsString:@"elsewhere.test"]);
}

/*! @abstract With no URL at all the placeholder is empty and hidden. */
- (void)testNoURLShowsAnEmptyHiddenPlaceholder
{
	FxGripWebPageView *view = [self hostedView];

	[view updateFromCustomData:[self valueWithURL:@"" extra:nil]];

	NSTextField *placeholder = [self placeholderIn:view];
	XCTAssertTrue(placeholder.hidden);
	XCTAssertEqualObjects(placeholder.stringValue, @"");
	XCTAssertNil([self webViewIn:view]);
}

#pragma mark Navigation policy

/*! @abstract A navigation the whitelist allows is permitted, and one off the whitelist is cancelled. */
- (void)testTheWhitelistGatesEveryNavigation
{
	FxGripWebPageView *view = [self hostedView];
	[view updateFromCustomData:[self valueWithURL:@"about:blank"
										    extra:@{kFxGripWebViewKey_Whitelist: @[@"*.allowed.test"]}]];

	XCTAssertEqual([self policyFor:@"https://docs.allowed.test/guide" on:view], WKNavigationActionPolicyAllow);
	XCTAssertEqual([self policyFor:@"https://tracker.test/pixel" on:view], WKNavigationActionPolicyCancel);
}

/*! @abstract A navigation action carrying no URL is allowed, because there is nothing to match. */
- (void)testANavigationWithoutAURLIsAllowed
{
	FxGripWebPageView *view = [self hostedView];
	[view updateFromCustomData:[self valueWithURL:@"about:blank"
										    extra:@{kFxGripWebViewKey_Whitelist: @[@"*.allowed.test"]}]];

	XCTAssertEqual([self policyFor:nil on:view], WKNavigationActionPolicyAllow);
}

/*! @abstract The default whitelist allows every site, so an untouched control cancels nothing. */
- (void)testTheDefaultWhitelistAllowsEverySite
{
	FxGripWebPageView *view = [self hostedView];

	XCTAssertEqual([self policyFor:@"https://anywhere.test/page" on:view], WKNavigationActionPolicyAllow);
}

@end
