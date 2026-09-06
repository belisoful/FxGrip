/*!
	@file       FxGripCustomViewData.h
	@copyright  Copyright © 2019-2023 Apple Inc. All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripCustomViewData
	@abstract   Protocol linking a custom parameter's data to the view and effect that present it.
	@discussion Introduced in FxGrip 0.1.0. A custom data value that drives its own parameter view
	            conforms to this protocol. The value holds a back reference to the presenting view
	            and to the owning effect host, so it can read host state while responding to view edits.
*/

#ifndef FxGripCustomViewData_h
#define FxGripCustomViewData_h

#import <Foundation/Foundation.h>
#import <FxPlug/FxPlugSDK.h>
#import "FxGripCustomViewDataDelegate.h"
#import "FxGripEffectHost.h"

@protocol FxGripTileableEffect;


/*!
	@protocol	FxGripCustomViewData
	@abstract	Links a custom parameter's data to the view and effect host that present it.
	@discussion	Introduced in FxGrip 0.1.0. A conforming value keeps back references to the presenting
				view and the owning effect host.
*/
// This is the protocol for Custom Data to hijack the standard api get/set bool, int, float, string, etc.
@protocol FxGripCustomViewData


/*! The view that presents the custom parameter's data. */
@property (assign) NSView*_Nullable parameterView;
/*! The effect host that owns the custom parameter. */
@property (assign) id<FxGripEffectHost>_Nullable parameterEffect;

@end

#endif
