//
//  FxGripRandomParameter.h
//  FxGrip
//

#ifndef FxGripRandomParameter_h
#define FxGripRandomParameter_h

#import <AppKit/AppKit.h>
#import "FxGripCustomParameter.h"
#import "FxGripCustomViewDataDelegate.h"

/*!
	@class      FxGripRandomView
	@abstract   The integer field, stepper, and reload button backing a random parameter.
	@discussion Introduced in FxGrip 1.0. Left to right: an editable integer field, an
				up-down stepper, and a reload button. Editing the field or the stepper writes
				the integer into the parameter value; reload draws a new integer in the
				configured range and writes it. Each write goes through an out-of-band access
				context. updateFromCustomData: sets the field and stepper from the value.
*/
@interface FxGripRandomView : NSView <FxGripCustomViewDataDelegate>

@property (nonatomic, assign, nullable) id<FxGripEffectHost> parameterEffect;
@property (nonatomic, assign) FxParameterId parameterID;

@end

/*!
	@class      FxGripRandomParameter
	@abstract   An integer custom parameter with a reload button that randomizes it.
	@discussion Introduced in FxGrip 1.0. The value is an FxGripDictionary carrying the
				integer under the int key; the configuration may declare the min, max, and
				step keys from FxGripRandom.h. The value defaults to 0, and reload draws a
				uniform integer in [min, max]. Creation adds the custom-UI and no-state flags.
*/
@interface FxGripRandomParameter : FxGripCustomParameter

@end

#endif
