/*!
	@file       FxGripObjectTrackerView.h
	@copyright  Copyright © 2026 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripObjectTrackerView
	@abstract   The inspector control that edits an object tracker's options.
	@discussion Introduced in FxGrip 0.1.0. The view presents the tracker's shape, behavior,
	            resolution, and smoothing, and a status line reporting the analyzed frame count.
	            An edit changes one option in the current value and writes it back, leaving the
	            placed region and the tracked samples untouched.
*/

#ifndef FxGripObjectTrackerView_h
#define FxGripObjectTrackerView_h

#import <AppKit/AppKit.h>
#import "FxGripCustomViewDataDelegate.h"
#import "FxGripTileableEffect.h"

NS_ASSUME_NONNULL_BEGIN

/*!
	@class      FxGripObjectTrackerView
	@abstract   The inspector control that edits an object tracker's options.
	@discussion Introduced in FxGrip 0.1.0. Presents the shape, behavior, resolution, and
				smoothing of the tracker as popups and a stepper, and a status line reporting
				the analyzed frame count. An edit reads the current FxGripObjectTrackerData,
				changes the one option, and writes the value back through an out-of-band access
				context, leaving the placed region and the tracked samples untouched.
				updateFromCustomData: sets the controls from the value the host pushes.
*/
@interface FxGripObjectTrackerView : NSView <FxGripCustomViewDataDelegate>

/*! The effect that owns the parameter, through which an edit reaches the value. */
@property (nonatomic, assign, nullable) id<FxGripEffectHost> parameterEffect;
/*! The ID of the object tracker parameter the view edits. */
@property (nonatomic, assign) FxParameterId parameterID;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripObjectTrackerView_h */
