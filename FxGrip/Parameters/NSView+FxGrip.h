/*!
	@file       NSView+FxGrip.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     NSView+FxGrip
	@abstract   The category that tags an NSView with the parameter ID it presents.
	@discussion Introduced in FxGrip 0.1.0. A custom parameter view carries the ID of the
	            parameter it renders. The category stores that ID in an associated object, so
	            any NSView reports which parameter it belongs to without a subclass.
*/

#ifndef NSView_FxGrip_h
#define NSView_FxGrip_h

#import <Foundation/Foundation.h>
#import <AppKit//NSView.h>
#import "FxGripTypes.h"

/*!
	@abstract	The category that associates a parameter ID with an NSView.
	@discussion	Introduced in FxGrip 0.1.0. The category adds one associated-object property that
				links a view to the parameter it presents.
*/
@interface NSView (FxGrip)

/*!
	@property	parameterID
	@abstract	The ID of the parameter the view presents.
	@discussion	Introduced in FxGrip 0.1.0. The value is held in an associated object. A view with
				no assigned ID reads kFxParameterId_None. */
@property (readwrite, assign, nonatomic) FxParameterId parameterID;

@end

#endif
