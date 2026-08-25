//
//  FxGripProgressParameter.h
//  FxGrip
//

#ifndef FxGripProgressParameter_h
#define FxGripProgressParameter_h

#import <AppKit/AppKit.h>
#import "FxGripCustomParameter.h"
#import "FxGripCustomViewDataDelegate.h"

/*!
	@class      FxGripProgressView
	@abstract   The progress display backing a progress parameter: a bar, a status dot, and a label.
	@discussion Introduced in FxGrip 1.0. A read-only display for a long operation: the
				effect reports progress by setting the parameter's FxGripDictionary value, and
				updateFromCustomData: drives the bar (the float value, 0…1, or a negative
				value for an indeterminate/spinning bar), the dot's BEDotState (the integer
				value), and the label (the string value). The dot is a BEFoundation BEDotView.
*/
@interface FxGripProgressView : NSView <FxGripCustomViewDataDelegate>

@end

/*!
	@class      FxGripProgressParameter
	@abstract   A read-only progress display: a bar with a status dot and text.
	@discussion Introduced in FxGrip 1.0. The value is an FxGripDictionary carrying the
				fraction under the float key (negative means indeterminate), the dot state
				under the integer key, and the label under the string key. Creation adds the
				custom-UI and no-state flags; the effect updates it by setting the value.
*/
@interface FxGripProgressParameter : FxGripCustomParameter

@end

#endif
