/*!
	@file       FxGripToggleExtension.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripToggleExtension
	@abstract   The parameter extension that models a toggle parameter.
	@discussion Introduced in FxGrip 0.1.0. The class is an FxGripParameterExtension that conforms to
	            FxGripToggleParameter, so the extension attaches to the effect and behaves as a boolean
	            toggle. The toggle behavior comes from the included toggle parameter library.
*/

#ifndef FxGripToggleExtension_h
#define FxGripToggleExtension_h

#import "FxGripParameterExtension.h"
#import "FxGripToggleParameter.h"


/*!
	@class		FxGripToggleExtension
	@abstract	The extension that represents a toggle effect parameter.
	@discussion	Introduced in FxGrip 0.1.0. The extension replicates FxGripToggleParameter behavior
				through the included toggle parameter library.
*/
@interface FxGripToggleExtension : FxGripParameterExtension <FxGripToggleParameter>


@end


#endif
