//
//  FxGripBannerParameter.h
//  FxGrip
//

#ifndef FxGripBannerParameter_h
#define FxGripBannerParameter_h

#import <AppKit/AppKit.h>
#import "FxGripCustomParameter.h"
#import "FxGripCustomViewDataDelegate.h"

/*!
	@class      FxGripBannerView
	@abstract   The full-width message strip backing a banner parameter.
	@discussion Introduced in FxGrip 1.0. A read-only strip: a colored background with a
				bold title and an optional subtitle, left-aligned with padding.
				updateFromCustomData: reads an FxGripDictionary and applies the title
				(string key), title point size (float key), background color (RGBA key),
				subtitle, text color, and corner radius. The strip sizes its height to the
				text plus padding.
*/
@interface FxGripBannerView : NSView <FxGripCustomViewDataDelegate>

@end

/*!
	@class      FxGripBannerParameter
	@abstract   A read-only, full-width message banner in the inspector.
	@discussion Introduced in FxGrip 1.0. The value is an FxGripDictionary carrying the
				title, subtitle, point size, background color, text color, and corner radius
				keys from FxGripBanner.h. When the configuration omits the title, the
				parameter name is used. Creation adds the custom-UI, not-animatable,
				full-view-width, and no-state flags.
*/
@interface FxGripBannerParameter : FxGripCustomParameter

@end

#endif
