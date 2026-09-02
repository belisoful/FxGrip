//
//  FxGripWebViewParameter.m
//  FxGrip
//

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
