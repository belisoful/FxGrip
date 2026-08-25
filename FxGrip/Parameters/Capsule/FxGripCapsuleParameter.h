//
//  FxGripCapsuleParameter.h
//  FxGrip
//

#ifndef FxGripCapsuleParameter_h
#define FxGripCapsuleParameter_h

#import <AppKit/AppKit.h>
#import "FxGripCustomParameter.h"
#import "FxGripCustomViewDataDelegate.h"

/*!
	@class      FxGripCapsuleView
	@abstract   The pill-shaped badge backing a capsule parameter.
	@discussion Introduced in FxGrip 1.0. A read-only badge: rounded-rectangle fill with a
				centered label. updateFromCustomData: reads an FxGripDictionary and applies
				the text (string key), point size (float key), fill color (RGBA key), text
				color, and corner radius. The badge sizes itself to the text plus padding.
*/
@interface FxGripCapsuleView : NSView <FxGripCustomViewDataDelegate>

@end

/*!
	@class      FxGripCapsuleParameter
	@abstract   A read-only pill badge shown as a parameter's control.
	@discussion Introduced in FxGrip 1.0. The value is an FxGripDictionary carrying the text,
				point size, fill color, text color, and corner radius keys from
				FxGripCapsule.h. Creation adds the custom-UI, not-animatable, and no-state
				flags; the row keeps the parameter name as its label.
*/
@interface FxGripCapsuleParameter : FxGripCustomParameter

@end

#endif
