//
//  FxGripDividerParameter.h
//  FxGrip
//

#ifndef FxGripDividerParameter_h
#define FxGripDividerParameter_h

#import "FxGripCustomParameter.h"

/*!
	@class      FxGripDividerParameter
	@abstract   A horizontal divider line in the inspector.
	@discussion Introduced in FxGrip 1.0. The value is an FxGripDividerData carrying the
				line's width fraction and margins; the view is an FXBox inside a sizing
				container. Creation adds the custom-UI, not-animatable, full-view-width,
				and no-state flags.
*/
@interface FxGripDividerParameter : FxGripCustomParameter

@end

#endif
