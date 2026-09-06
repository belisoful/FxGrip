/*!
	@file       FxGripCustomCommonDelegate.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripCustomCommonDelegate
	@abstract   Shared base class for delegates that connect custom-parameter view callbacks to host parameters.
	@discussion Introduced in FxGrip 0.1.0. A custom parameter view receives AppKit control callbacks
	            outside the host's managed plugin call stack. A delegate built on this class routes
	            those callbacks back to the host parameter through the out-of-band parameter access API.
*/

#ifndef FxGripCustomCommonDelegate_h
#define FxGripCustomCommonDelegate_h

#import <Foundation/Foundation.h>


/*!
	@class		FxGripCustomCommonDelegate
	@abstract	Shared base class for delegates that connect custom-parameter view callbacks to host parameters.
	@discussion	Introduced in FxGrip 0.1.0. A custom parameter view receives AppKit control callbacks
				outside the host's managed plugin call stack. A delegate built on this class routes those
				callbacks back to the host parameter through the out-of-band parameter access API.
				See NSControlTextEditingDelegate for the AppKit callbacks a subclass observes.
*/
@interface FxGripCustomCommonDelegate : NSObject


@end

#endif /* FxGripOOBParameterAccess */
