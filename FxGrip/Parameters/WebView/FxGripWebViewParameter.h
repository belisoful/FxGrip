//
//  FxGripWebViewParameter.h
//  FxGrip
//

#ifndef FxGripWebViewParameter_h
#define FxGripWebViewParameter_h

#import <AppKit/AppKit.h>
#import "FxGripCustomParameter.h"
#import "FxGripCustomViewDataDelegate.h"

/*!
	@class      FxGripWebPageView
	@abstract   The web page display backing a web-view parameter.
	@discussion Introduced in FxGrip 1.0. A WKWebView gated by an FxGripURLWhitelist. Web
				content runs with JavaScript enabled and no bridge back to the plugin; the
				whitelist restricts which URLs the view may navigate to. A navigation to a
				URL that is off the whitelist is blocked, and a placeholder is shown when the
				requested URL is blocked.

				The WKWebView is created only when the view enters a window, so no web
				content process starts until the control is shown.

				Remote content needs the host plugin's XPC service to carry the
				com.apple.security.network.client entitlement, and non-TLS URLs need an App
				Transport Security exception. FxGrip provides the control; the plugin
				declares the entitlements.
*/
@interface FxGripWebPageView : NSView <FxGripCustomViewDataDelegate>

@end

/*!
	@class      FxGripWebViewParameter
	@abstract   A web page view in the inspector, gated by a URL whitelist.
	@discussion Introduced in FxGrip 1.0. The value is an FxGripDictionary carrying the URL
				(string key), the whitelist (an array of glob patterns under the whitelist
				key), and the row height. An absent whitelist defaults to `*`, which allows
				every site; lock it down to specific domains for security. Creation adds the
				custom-UI, not-animatable, full-view-width, and no-state flags.
*/
@interface FxGripWebViewParameter : FxGripCustomParameter

@end

#endif
