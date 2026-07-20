//
//  YouTubePlayerView.m
//  XPC Service
//
//  Created by ~ ~ on 3/18/24.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import "FxGrip_ARC.h"

@interface YouTubePlayerView : NSView

@property (nonatomic, copy) NSString *videoID;
@property (nonatomic, assign) BOOL autoplay;
@property (nonatomic, assign) BOOL loop;
@property (nonatomic, assign) BOOL controls;
@property (nonatomic, assign) BOOL showinfo;
@property (nonatomic, assign) BOOL playsinline;
@property (nonatomic, copy) NSArray<NSString *> *playerParameters;

@end

@implementation YouTubePlayerView {
	WKWebView	*webView;
	NSLock		*updateLock, *delayLock;
}

- (id)initWithFrame:(NSRect)frame {
	self = [super initWithFrame:frame];
	if (self) {
		updateLock = [NSLock.alloc init];
		delayLock = [NSLock.alloc init];
		
		// setup the initial properties of the
		// draggable item
		WKWebViewConfiguration *config = NARC_AUTORELEASE([[WKWebViewConfiguration alloc] init]);
		webView = [[WKWebView alloc] initWithFrame:frame configuration:config];
		webView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
		[self addSubview:webView];
	}
	return self;
}

- (void)dealloc
{
	NARC_RELEASE(_videoID);
	NARC_RELEASE(_playerParameters);
	
	SUPER_DEALLOC();
}


- (void)setVideoID:(NSString *)videoID
{
	[updateLock lock];
	_videoID = [videoID copy];
	[self triggerUpdate];
	[updateLock unlock];
}

- (void)setAutoplay:(BOOL)autoplay
{
	[updateLock lock];
	_autoplay = autoplay;
	[self triggerUpdate];
	[updateLock unlock];
}

- (void)setLoop:(BOOL)loop
{
	[updateLock lock];
	_loop = loop;
	[self triggerUpdate];
	[updateLock unlock];
}

- (void)setControls:(BOOL)controls
{
	[updateLock lock];
	_controls = controls;
	[self triggerUpdate];
	[updateLock unlock];
}

- (void)setShowinfo:(BOOL)showinfo
{
	[updateLock lock];
	_showinfo = showinfo;
	[self triggerUpdate];
	[updateLock unlock];
}

- (void)setPlaysinline:(BOOL)playsinline
{
	[updateLock lock];
	_playsinline = playsinline;
	[self triggerUpdate];
	[updateLock unlock];
}

- (void)setPlayerParameters:(NSArray<NSString *> *)playerParameters
{
	[updateLock lock];
	_playerParameters = [playerParameters copy];
	[self triggerUpdate];
	[updateLock unlock];
}

// internal function: must be wrapped by [updateLock lock]
- (void)triggerUpdate
{
	BOOL innerLocked = [updateLock tryLock];
	if ([delayLock tryLock]) {
		[self performSelector:@selector(loadVideo)
				   withObject:nil
				   afterDelay:0.005];
	} else {
		[NSObject cancelPreviousPerformRequestsWithTarget:self];
		[self performSelector:@selector(loadVideo)
				   withObject:nil
				   afterDelay:0.005];
	}
	if (innerLocked) {
		[updateLock unlock];
	}
}

- (void)loadVideo
{
	[updateLock lock];
	
	[delayLock unlock];
	 
	NSMutableString *embedURLString = [NSMutableString stringWithFormat:@"https://www.youtube.com/embed/%@", self.videoID];
	
	BOOL questionAdded = NO;
	
	if (self.autoplay) {
		[embedURLString appendString:@"?autoplay=1"];
		questionAdded = YES;
	}
	
	if (self.loop) {
		[embedURLString appendString:questionAdded ? @"?" : @"&"];
		[embedURLString appendString:@"loop=1"];
		questionAdded = YES;
	}
	
	if (!self.controls) {
		[embedURLString appendString:questionAdded ? @"?" : @"&"];
		[embedURLString appendString:@"controls=0"];
		questionAdded = YES;
	}
	
	if (!self.showinfo) {
		[embedURLString appendString:questionAdded ? @"?" : @"&"];
		[embedURLString appendString:@"showinfo=0"];
		questionAdded = YES;
	}
	
	if (self.playsinline) {
		[embedURLString appendString:questionAdded ? @"?" : @"&"];
		[embedURLString appendString:@"playsinline=1"];
		questionAdded = YES;
	}
	
	if (self.playerParameters) {
		[embedURLString appendString:questionAdded ? @"?" : @"&"];
		[embedURLString appendString:[self.playerParameters componentsJoinedByString:@"&"]];
	}
	
	NSURL *embedURL = [NSURL URLWithString:embedURLString];
	NSURLRequest *request = [NSURLRequest requestWithURL:embedURL];
	[webView loadRequest:request];
	 
	[updateLock unlock];
}


@end
