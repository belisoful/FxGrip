/*!
	@file       FxGripVideoViewParameter.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripVideoViewParameter
	@abstract   The custom parameter that plays a whitelisted video in the inspector.
	@discussion Introduced in FxGrip 0.1.0. FxGripVideoView is the player view, and
	            FxGripVideoViewParameter is the parameter that hosts it. The value is an
	            FxGripDictionary carrying the URL, the whitelist, the row height, and the
	            autoplay and loop flags. Playback is gated by a URL whitelist.
*/

#ifndef FxGripVideoViewParameter_h
#define FxGripVideoViewParameter_h

#import <AppKit/AppKit.h>
#import "FxGripCustomParameter.h"
#import "FxGripCustomViewDataDelegate.h"

/*!
	@class      FxGripVideoView
	@abstract   The video player backing a video parameter.
	@discussion Introduced in FxGrip 0.1.0. Plays a URL gated by an FxGripURLWhitelist. A local
				file URL or a direct media URL (mp4, m4v, mov, m3u8, webm) plays through an
				AVPlayerView; any other whitelisted remote URL loads in a WKWebView so a
				hosted player page embeds. A remote URL that is off the whitelist is blocked
				with a placeholder.

				The player is created only when the view enters a window, so no media session
				or web content process starts until the control is shown.

				Remote content needs the host plugin's XPC service to carry the
				com.apple.security.network.client entitlement, and non-TLS URLs need an App
				Transport Security exception. FxGrip provides the control; the plugin declares
				the entitlements.
*/
@interface FxGripVideoView : NSView <FxGripCustomViewDataDelegate>

@end

/*!
	@class      FxGripVideoViewParameter
	@abstract   A video player in the inspector, gated by a URL whitelist.
	@discussion Introduced in FxGrip 0.1.0. The value is an FxGripDictionary carrying the URL
				(string key), the whitelist (an array of glob patterns), the row height, and
				the autoplay and loop flags. An absent whitelist defaults to the common
				video-hosting domains from FxGripURLWhitelist defaultVideoWhitelist; lock it
				down further for security. Creation adds the custom-UI, not-animatable,
				full-view-width, and no-state flags.
*/
@interface FxGripVideoViewParameter : FxGripCustomParameter

@end

#endif
