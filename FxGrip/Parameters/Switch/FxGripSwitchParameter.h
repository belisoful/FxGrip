/*!
	@file       FxGripSwitchParameter.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripSwitchParameter
	@abstract   A boolean custom parameter presented as an NSSwitch.
	@discussion Introduced in FxGrip 0.1.0. The parameter value is an FxGripDictionary carrying the
	            boolean under the default bool key. Toggling the switch writes the boolean back
	            through an out-of-band access context, and the view reads its state from the value.
	            Creation adds the custom-UI and no-state flags.
*/

#ifndef FxGripSwitchParameter_h
#define FxGripSwitchParameter_h

#import <AppKit/AppKit.h>
#import "FxGripCustomParameter.h"
#import "FxGripCustomViewDataDelegate.h"

/*!
	@class      FxGripSwitchView
	@abstract   The NSSwitch backing a switch parameter.
	@discussion Introduced in FxGrip 0.1.0. Toggling writes the boolean into the
				parameter's FxGripDictionary value through an out-of-band access
				context; updateFromCustomData: sets the switch state from the value.
*/
@interface FxGripSwitchView : NSSwitch <FxGripCustomViewDataDelegate>

/*! @abstract The effect host the toggle writes the boolean value back to. */
@property (nonatomic, assign, nullable) id<FxGripEffectHost> parameterEffect;

/*! @abstract The identifier of the parameter the toggle updates. */
@property (nonatomic, assign) FxParameterId parameterID;

@end

/*!
	@class      FxGripSwitchParameter
	@abstract   A boolean custom parameter presented as a switch.
	@discussion Introduced in FxGrip 0.1.0. The value is an FxGripDictionary carrying the
				boolean under the default bool key; creation adds the custom-UI and
				no-state flags.
*/
@interface FxGripSwitchParameter : FxGripCustomParameter

@end

#endif
