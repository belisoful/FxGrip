/*!
	@file       FxGripTileableEffect+CustomUI.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripTileableEffect+CustomUI
	@abstract   Implements custom parameter view creation for the effect.
	@discussion Introduced in FxGrip 0.1.0. The host calls createViewForParameterID: for each
	            parameter flagged for custom UI. The view comes from the parameter's
	            newParameterView and is attached to an unattached parameter.
*/

#import "FxGripTileableEffect+CustomUI.h"
#import "FxGripTileableEffect+Parameters.h"
#import "FxGripParameter.h"
#import "FxGrip_ARC.h"

/*!
	@abstract	The category that creates and attaches custom parameter views.
	@discussion	Introduced in FxGrip 0.1.0.
*/
@implementation FxGripTileableEffect (CustomUI)

/*!
	@method		createViewForParameterID:
	@abstract	Creates the custom view for a parameter and attaches it to the parameter.
	@param		parameterID	The parameter flagged for custom UI.
	@return		The parameter's custom view, or nil when its class provides none.
	@discussion	Introduced in FxGrip 0.1.0. The view comes from the parameter's newParameterView.
				A parameter that has not yet attached a custom view receives the created one. */
- (NSView *_Nullable)createViewForParameterID:(UInt32)parameterID
{
	id parameter = self[(NSInteger)parameterID];
	if (![parameter respondsToSelector:@selector(newParameterView)]) {
		return nil;
	}
	NSView *view = [parameter newParameterView];
	if (view == nil) {
		NSLog(@"%s Error: parameter %u is flagged for custom UI and provides no view.", __func__, parameterID);
		return nil;
	}
	// A parameter that wraps its delegate view (the divider's box inside its container)
	// attaches the wrapped view itself; only an unattached parameter gets the returned one.
	if ([parameter respondsToSelector:@selector(attachCustomView:)]
		&& [parameter respondsToSelector:@selector(customView)]
		&& [parameter customView] == nil) {
		[parameter attachCustomView:view];
	}
	return view;
}

@end
