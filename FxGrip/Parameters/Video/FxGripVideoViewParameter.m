//
//  FxGripVideoViewParameter.m
//  FxGrip
//

#import "FxGripVideoViewParameter.h"
#import "FxGripVideoView.h"
#import "FxGripURLWhitelist.h"
#import "FxGripTileableEffect.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "FxGripDictionary.h"
#import "FxGrip_ARC.h"
#import <WebKit/WebKit.h>
#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>

static NSSet<NSString *> *FxGripDirectMediaExtensions(void)
{
	static NSSet<NSString *> *extensions = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		extensions = [NSSet setWithArray:@[@"mp4", @"m4v", @"mov", @"m3u8", @"webm"]];
	});
	return extensions;
}

@interface FxGripVideoView () <WKNavigationDelegate>
@end

@implementation FxGripVideoView
{
	WKWebView *_webView;
	AVPlayerView *_playerView;
	NSTextField *_placeholder;
	FxGripURLWhitelist *_whitelist;
	NSString *_urlString;
	CGFloat _height;
	BOOL _autoplay;
	BOOL _loop;
	id _loopObserver;
}

- (nonnull instancetype)initWithFrame:(NSRect)frameRect
{
	self = [super initWithFrame:frameRect];
	if (self != nil) {
		_whitelist = [FxGripURLWhitelist defaultVideoWhitelist];
		_height = kFxGripVideoDefaultHeight;

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

- (void)dealloc
{
	[self removeLoopObserver];
}

- (BOOL)isFlipped
{
	return YES;
}

- (NSSize)intrinsicContentSize
{
	return NSMakeSize(NSViewNoIntrinsicMetric, _height);
}

- (void)viewDidMoveToWindow
{
	[super viewDidMoveToWindow];
	if (self.window != nil) {
		[self applyContent];
	}
}

- (BOOL)isDirectMediaURL:(NSURL *)url
{
	return [FxGripDirectMediaExtensions() containsObject:url.pathExtension.lowercaseString];
}

- (void)applyContent
{
	NSURL *url = _urlString.length ? [NSURL URLWithString:_urlString] : nil;
	if (url == nil) {
		[self showPlaceholder:@""];
		return;
	}
	NSString *scheme = url.scheme.lowercaseString;
	BOOL isRemote = [scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"];
	if (isRemote && ![_whitelist matchesURL:url]) {
		[self showPlaceholder:[NSString stringWithFormat:@"URL blocked by the whitelist:\n%@", _urlString]];
		return;
	}

	if (url.isFileURL || [self isDirectMediaURL:url]) {
		[self playMediaURL:url];
	} else {
		[self loadWebURL:url];
	}
}

#pragma mark AV playback

- (void)playMediaURL:(NSURL *)url
{
	[self teardownWebView];
	_placeholder.hidden = YES;

	if (_playerView == nil) {
		_playerView = [AVPlayerView.alloc initWithFrame:self.bounds];
		_playerView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
		_playerView.controlsStyle = AVPlayerViewControlsStyleInline;
		[self addSubview:_playerView positioned:NSWindowBelow relativeTo:_placeholder];
	}
	[self removeLoopObserver];
	AVPlayer *player = [AVPlayer playerWithURL:url];
	_playerView.player = player;

	if (_loop) {
		__weak AVPlayer *weakPlayer = player;
		_loopObserver = [NSNotificationCenter.defaultCenter
			addObserverForName:AVPlayerItemDidPlayToEndTimeNotification
					   object:player.currentItem
						queue:NSOperationQueue.mainQueue
				   usingBlock:^(NSNotification * _Nonnull note) {
			[weakPlayer seekToTime:kCMTimeZero];
			[weakPlayer play];
		}];
	}
	if (_autoplay) {
		[player play];
	}
}

- (void)removeLoopObserver
{
	if (_loopObserver != nil) {
		[NSNotificationCenter.defaultCenter removeObserver:_loopObserver];
		_loopObserver = nil;
	}
}

- (void)teardownPlayer
{
	[self removeLoopObserver];
	[_playerView.player pause];
	_playerView.player = nil;
	[_playerView removeFromSuperview];
	_playerView = nil;
}

#pragma mark Web playback

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

- (void)loadWebURL:(NSURL *)url
{
	[self teardownPlayer];
	_placeholder.hidden = YES;
	[[self ensureWebView] loadRequest:[NSURLRequest requestWithURL:url]];
}

- (void)teardownWebView
{
	[_webView stopLoading];
	[_webView removeFromSuperview];
	_webView = nil;
}

#pragma mark Placeholder

- (void)showPlaceholder:(NSString *)message
{
	[self teardownPlayer];
	[self teardownWebView];
	_placeholder.frame = self.bounds;
	_placeholder.stringValue = message ?: @"";
	_placeholder.hidden = message.length == 0;
}

#pragma mark Data

- (void)updateFromCustomData:(NSObject<NSSecureCoding,NSCopying> * _Nullable)value
{
	if (![value isKindOfClass:FxGripDictionary.class]) {
		return;
	}
	FxGripDictionary *data = (FxGripDictionary*)value;

	NSObject *whitelistPatterns = [data objectForKey:kFxGripVideoKey_Whitelist];
	if ([whitelistPatterns isKindOfClass:NSArray.class]) {
		_whitelist = [FxGripURLWhitelist.alloc initWithPatterns:(NSArray*)whitelistPatterns];
	}
	double height = 0.0;
	if ([data getFloatValue:&height forKey:kFxGripVideoKey_Height] && height > 0.0) {
		_height = height;
		[self invalidateIntrinsicContentSize];
	}
	BOOL flag = NO;
	if ([data getBoolValue:&flag forKey:kFxGripVideoKey_Autoplay]) {
		_autoplay = flag;
	}
	if ([data getBoolValue:&flag forKey:kFxGripVideoKey_Loop]) {
		_loop = flag;
	}
	NSString *urlString = nil;
	if ([data getStringParameterValue:&urlString forKey:kFxGripVideoKey_URL]) {
		_urlString = [urlString copy];
	}

	if (self.window != nil) {
		[self applyContent];
	}
}

#pragma mark WKNavigationDelegate

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


@implementation FxGripVideoViewParameter

+ (nullable NSString*)parameterTypeString
{
	return kFxParameterType_VideoView;
}

+ (FxParameterType)parameterType
{
	return FxParameterType_VideoView;
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

	// A configuration without a whitelist defaults to the common video-hosting domains.
	if (![[defaultValue objectForKey:kFxGripVideoKey_Whitelist] isKindOfClass:NSArray.class]) {
		[defaultValue setObject:[FxGripURLWhitelist defaultVideoWhitelist].patterns
						 forKey:kFxGripVideoKey_Whitelist];
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
	FxGripVideoView *view = [FxGripVideoView.alloc initWithFrame:NSMakeRect(0, 0, 200, kFxGripVideoDefaultHeight)];
	id declared = _data.parameterDefaultValue;
	if ([declared isKindOfClass:NSDictionary.class]) {
		[view updateFromCustomData:[FxGripDictionary dictionaryWithDictionary:declared]];
	}
	return view;
}

@end
