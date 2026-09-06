/*!
	@file       FxGripCustomViewDataDelegate.h
	@copyright  Copyright © 2019-2023 Apple Inc. All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripCustomViewDataDelegate
	@abstract   Protocol a custom parameter view adopts to receive new custom-data values.
	@discussion Introduced in FxGrip 0.1.0. When a custom parameter's stored value changes, the owner
	            pushes the new value to the presenting view through this protocol so the view redraws
	            to match.
*/

#ifndef FxGripCustomViewDataDelegate_h
#define FxGripCustomViewDataDelegate_h

#import <Foundation/Foundation.h>
#import <FxPlug/FxPlugSDK.h>


/*!
	@protocol	FxGripCustomViewDataDelegate
	@abstract	Receives a custom parameter's new value so the view can update.
	@discussion	Introduced in FxGrip 0.1.0. A custom parameter view conforms to this protocol.
*/
// This is the protocol for Custom Data to hijack the standard api get/set bool, int, float, string, etc.
@protocol FxGripCustomViewDataDelegate

/*!
	@method		updateFromCustomData:
	@abstract	Updates the view from a new custom-data value.
	@param		value	The new custom-data value, or nil to clear.
*/
- (void)updateFromCustomData:(NSObject<NSSecureCoding,NSCopying> * _Nullable)value;

@end

#endif
