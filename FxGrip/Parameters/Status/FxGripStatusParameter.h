/*!
	@file       FxGripStatusParameter.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripStatusParameter
	@abstract   A read-only status indicator parameter drawn as a colored dot with a label.
	@discussion Introduced in FxGrip 0.1.0. The parameter value is an FxGripDictionary carrying the
	            dot state under the integer key and the label under the string key. The effect
	            reports status by setting the value, and the backing view redraws from it. Creation
	            adds the custom-UI and no-state flags because the control is not user-editable.
*/

#ifndef FxGripStatusParameter_h
#define FxGripStatusParameter_h

#import <AppKit/AppKit.h>
#import "FxGripCustomParameter.h"
#import "FxGripCustomViewDataDelegate.h"

/*!
	@class      FxGripStatusView
	@abstract   The status indicator backing a status parameter: a colored dot and a label.
	@discussion Introduced in FxGrip 0.1.0. A read-only display: the effect reports status by
				setting the parameter's FxGripDictionary value, and updateFromCustomData:
				drives the dot's BEDotState (the integer value) and the label (the string
				value). The dot is a BEFoundation BEDotView, so the light matches Prado's
				TDot palette (Off gray, Ok green, Warning yellow, Error red, Active blue).
*/
@interface FxGripStatusView : NSView <FxGripCustomViewDataDelegate>

@end

/*!
	@class      FxGripStatusParameter
	@abstract   A read-only status indicator: a colored dot with text.
	@discussion Introduced in FxGrip 0.1.0. The value is an FxGripDictionary carrying the dot
				state under the integer key and the label under the string key. Creation
				adds the custom-UI and no-state flags; the control is not user-editable, so
				the effect updates it by setting the value.
*/
@interface FxGripStatusParameter : FxGripCustomParameter

@end

#endif
