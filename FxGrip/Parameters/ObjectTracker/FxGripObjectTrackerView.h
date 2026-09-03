//
//  FxGripObjectTrackerView.h
//  FxGrip
//
//  Copyright © 2026 Belisoful All rights reserved.
//

#ifndef FxGripObjectTrackerView_h
#define FxGripObjectTrackerView_h

#import <AppKit/AppKit.h>
#import "FxGripCustomViewDataDelegate.h"
#import "FxGripTileableEffect.h"

NS_ASSUME_NONNULL_BEGIN

/*!
	@class      FxGripObjectTrackerView
	@abstract   The inspector control that edits an object tracker's options.
	@discussion Introduced in FxGrip 1.0. Presents the shape, behavior, resolution, and
				smoothing of the tracker as popups and a stepper, and a status line reporting
				the analyzed frame count. An edit reads the current FxGripObjectTrackerData,
				changes the one option, and writes the value back through an out-of-band access
				context, leaving the placed region and the tracked samples untouched.
				updateFromCustomData: sets the controls from the value the host pushes.
*/
@interface FxGripObjectTrackerView : NSView <FxGripCustomViewDataDelegate>

@property (nonatomic, assign, nullable) id<FxGripEffectHost> parameterEffect;
@property (nonatomic, assign) FxParameterId parameterID;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripObjectTrackerView_h */
