//
//  FxGripSwitchParameter.h
//  FxGrip
//

#ifndef FxGripSwitchParameter_h
#define FxGripSwitchParameter_h

#import <AppKit/AppKit.h>
#import "FxGripCustomParameter.h"
#import "FxGripCustomViewDataDelegate.h"

/*!
	@class      FxGripSwitchView
	@abstract   The NSSwitch backing a switch parameter.
	@discussion Introduced in FxGrip 1.0. Toggling writes the boolean into the
				parameter's FxGripDictionary value through an out-of-band access
				context; updateFromCustomData: sets the switch state from the value.
*/
@interface FxGripSwitchView : NSSwitch <FxGripCustomViewDataDelegate>

@property (nonatomic, assign, nullable) id<FxGripEffectHost> parameterEffect;
@property (nonatomic, assign) FxParameterId parameterID;

@end

/*!
	@class      FxGripSwitchParameter
	@abstract   A boolean custom parameter presented as a switch.
	@discussion Introduced in FxGrip 1.0. The value is an FxGripDictionary carrying the
				boolean under the default bool key; creation adds the custom-UI and
				no-state flags.
*/
@interface FxGripSwitchParameter : FxGripCustomParameter

@end

#endif
