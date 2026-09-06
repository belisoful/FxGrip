/*!
	@file       FxGripDividerParameter.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripDividerParameter
	@abstract   A custom parameter that draws a horizontal divider line in the inspector.
	@discussion Introduced in FxGrip 0.1.0. The parameter value is an FxGripDividerData carrying the
	            line's width fraction and margins. The view is an FxGripDividerBox inside a sizing
	            container. Creation adds the custom-UI, not-animatable, full-view-width, and no-state
	            flags because the control is decorative and not user-editable.
*/

#ifndef FxGripDividerParameter_h
#define FxGripDividerParameter_h

#import "FxGripCustomParameter.h"

/*! The drawn height of the divider line, in view points. */
#define kFxGripBoxDividerHeight (1)
/*! The line width fraction type, 0 to 1. */
typedef double FxGripDividerSize;

/*!
	@class      FxGripDividerParameter
	@abstract   A horizontal divider line in the inspector.
	@discussion Introduced in FxGrip 0.1.0. The value is an FxGripDividerData carrying the
				line's width fraction and margins; the view is an FxGripDividerBox inside a sizing
				container. Creation adds the custom-UI, not-animatable, full-view-width,
				and no-state flags.
*/
@interface FxGripDividerParameter : FxGripCustomParameter

@end

#endif
