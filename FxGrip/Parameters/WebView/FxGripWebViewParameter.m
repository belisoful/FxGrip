/*!
	@file       FxGripWebViewParameter.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripWebViewParameter
	@abstract   Implements the web page view and its custom parameter.
	@discussion Introduced in FxGrip 0.1.0. The view loads a whitelisted URL in a WKWebView and
	            blocks any navigation off the whitelist. The web view is created only when the
	            control enters a window. The parameter seeds a default all-sites whitelist and
	            sets the row's parameter flags.
*/

#import "FxGripWebViewParameter.h"
#import "FxGripWebView.h"
#import "FxGripURLWhitelist.h"
#import "FxGripTileableEffect.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "FxGripDictionary.h"
#import "FxGrip_ARC.h"
#import <WebKit/WebKit.h>

@interface FxGripWebPageView () <WKNavigationDelegate>
@end

/*!
	@abstract	The web page display backing a web-view parameter.
	@discussion	Introduced in FxGrip 0.1.0. A WKWebView gated by a URL whitelist. A blocked URL
				shows a placeholder.
*/
@implementation FxGripWebPageView
{
	WKWebView *_webView;
	NSTextField *_placeholder;
	FxGripURLWhitelist *_whitelist;
	NSString *_urlString;
	CGFloat _height;
}

- (nonnull instancetype)initWithFrame:(NSRect)frameRect
{
	self = [super initWithFrame:frameRect];
	if (self != nil) {
		_whitelist = [FxGripURLWhitelist allowAllWhitelist];
		_height = kFxGripWebViewDefaultHeight;

		_placeholder = [NSTextField labelWithString:@""];
		_placeholder.font = [NSFont systemFontOfSize:NSFont.smallSystemFontSize];
		_placeholder.textColor = NSColor.secondaryLabelColor;
		_placeholder.alignment = NSTextAlignmentCenter;
		_placeholder.hidden = YES;
		_placeholder.autoresizingMask = NSViewWidthSizable | NSViewMaxYMargin | NSViewMinYMargin;
		[self addSubview:_placeholder];
	}
	return self;
}

- (BOOL)isFlipped
{
	return YES;
}

- (NSSize)intrinsicContentSize
{
	return NSMakeSize(NSViewNoIntrinsicMetric, _height);
}

/*! The WKWebView is created only once the control is on screen, so no web content process
	starts for a control the user never reveals. */
- (WKWebView *)ensureWebView
{
	if (_webView == nil) {
		WKWebViewConfiguration *config = [WKWebViewConfiguration.alloc init];
		config.defaultWebpagePreferences.allowsContentJavaScript = YES;
		_webView = [WKWebView.alloc initWithFrame:self.bounds configuration:config];
		_webView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
		_webView.navigationDelegate = self;
		[self addSubview:_webView positioned:NSWindowBelow relativeTo:_placeholder];
	}
	return _webView;
}

- (void)viewDidMoveToWindow
{
	[super viewDidMoveToWindow];
	if (self.window != nil) {
		[self applyContent];
	}
}

/*!
	@method		applyContent
	@abstract	Loads the current URL when the whitelist allows it, or shows the blocked placeholder.
	@discussion	Introduced in FxGrip 0.1.0. A missing URL or one off the whitelist shows the
				placeholder instead of loading. */
- (void)applyContent
{
	NSURL *url = _urlString.length ? [NSURL URLWithString:_urlString] : nil;
	if (url != nil && [_whitelist matchesURL:url]) {
		_placeholder.hidden = YES;
		[[self ensureWebView] loadRequest:[NSURLRequest requestWithURL:url]];
	} else {
		[self showBlockedPlaceholderForURL:_urlString];
	}
}

- (void)showBlockedPlaceholderForURL:(nullable NSString *)urlString
{
	_placeholder.frame = self.bounds;
	_placeholder.stringValue = urlString.length
		? [NSString stringWithFormat:@"URL blocked by the whitelist:\n%@", urlString]
		: @"";
	_placeholder.hidden = urlString.length == 0;
	[_webView stopLoading];
	[_webView removeFromSuperview];
	_webView = nil;
}

/*!
	@method		updateFromCustomData:
	@abstract	Reads the whitelist, height, and URL from the value the host pushes.
	@discussion	Introduced in FxGrip 0.1.0. A value that is not an FxGripDictionary is ignored.
				The content reapplies when the view is in a window. */
- (void)updateFromCustomData:(NSObject<NSSecureCoding,NSCopying> * _Nullable)value
{
	if (![value isKindOfClass:FxGripDictionary.class]) {
		return;
	}
	FxGripDictionary *data = (FxGripDictionary*)value;

	NSObject *whitelistPatterns = [data objectForKey:kFxGripWebViewKey_Whitelist];
	if ([whitelistPatterns isKindOfClass:NSArray.class]) {
		_whitelist = [FxGripURLWhitelist.alloc initWithPatterns:(NSArray*)whitelistPatterns];
	}
	double height = 0.0;
	if ([data getFloatValue:&height forKey:kFxGripWebViewKey_Height] && height > 0.0) {
		_height = height;
		[self invalidateIntrinsicContentSize];
	}
	NSString *urlString = nil;
	if ([data getStringParameterValue:&urlString forKey:kFxGripWebViewKey_URL]) {
		_urlString = [urlString copy];
	}

	if (self.window != nil) {
		[self applyContent];
	}
}

#pragma mark WKNavigationDelegate

/*! Every navigation, including one started by page script, passes the whitelist before it
	is allowed. */
- (void)webView:(WKWebView *)webView
	decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
				decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
	NSURL *url = navigationAction.request.URL;
	if (url != nil && ![_whitelist matchesURL:url]) {
		decisionHandler(WKNavigationActionPolicyCancel);
		return;
	}
	decisionHandler(WKNavigationActionPolicyAllow);
}

@end


/*!
	@abstract	The custom parameter that hosts a whitelisted web page view.
	@discussion	Introduced in FxGrip 0.1.0. The value is an FxGripDictionary. Creation seeds an
				all-sites whitelist and sets the custom-UI, not-animatable, full-view-width, and
				no-state flags.
*/
@implementation FxGripWebViewParameter

+ (nullable NSString*)parameterTypeString
{
	return kFxParameterType_WebView;
}

+ (FxParameterType)parameterType
{
	return FxParameterType_WebView;
}

+ (NSSet<Class> *_Nullable)customValueClasses
{
	NSMutableSet *classes = [NSMutableSet setWithObject:FxGripDictionary.class];
	[classes unionSet:FxGripDictionary.classesForParameter.set];
	return classes;
}

/*!
	@method		addParameter:toEffect:
	@abstract	Adds the web page view as a custom parameter to the effect.
	@return		YES when the host creates the parameter.
	@discussion	Introduced in FxGrip 0.1.0. A declared value without a whitelist defaults to all
				sites. Creation sets the custom-UI, not-animatable, full-view-width, and no-state
				flags. */
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect
{
	id declared = parameter.parameterDefaultValue;
	NSDictionary *config = [declared isKindOfClass:NSDictionary.class] ? declared : @{};
	FxGripDictionary *defaultValue = [FxGripDictionary dictionaryWithDictionary:config];

	// A configuration without a whitelist defaults to `*` (all sites); document the
	// security note in the header so a shipped plugin locks it down.
	if (![[defaultValue objectForKey:kFxGripWebViewKey_Whitelist] isKindOfClass:NSArray.class]) {
		[defaultValue setObject:@[@"*"] forKey:kFxGripWebViewKey_Whitelist];
	}

	return [effect.apiManager.paramCreateAPIv5
		addCustomParameterWithName: @""
					   parameterID: parameter.parameterID
					  defaultValue: defaultValue
					parameterFlags: parameter.parameterFlags | kFxParameterFlag_CUSTOM_UI
									| kFxParameterFlag_NOT_ANIMATABLE
									| kFxParameterFlag_USE_FULL_VIEW_WIDTH
									| kFxParameterFlag_NOSTATE];
}

- (NSView *_Nullable)newParameterView
{
	FxGripWebPageView *view = [FxGripWebPageView.alloc initWithFrame:NSMakeRect(0, 0, 200, kFxGripWebViewDefaultHeight)];
	id declared = _data.parameterDefaultValue;
	if ([declared isKindOfClass:NSDictionary.class]) {
		[view updateFromCustomData:[FxGripDictionary dictionaryWithDictionary:declared]];
	}
	return view;
}

@end
