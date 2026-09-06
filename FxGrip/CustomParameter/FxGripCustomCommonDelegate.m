/*!
	@file       FxGripCustomCommonDelegate.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripCustomCommonDelegate
	@abstract   Implements the shared base for custom-parameter view delegates.
	@discussion Introduced in FxGrip 0.1.0. The class is the foundation for delegates that observe
	            AppKit control callbacks from a custom parameter view and forward the changed value
	            to the host parameter.
*/

#import "FxGripCustomCommonDelegate.h"


/*
 
 Custom controls
 */


/*!
	@abstract	The shared base for custom-parameter view delegates.
	@discussion	Introduced in FxGrip 0.1.0. Subclasses forward AppKit control callbacks to the host
				parameter through the out-of-band parameter access API.
*/
@implementation FxGripCustomCommonDelegate
/*
 
 registerCustomControl
 	-Sets NSControl Delegate to self [optional]
 		- sets app number uid to parameter id
 		
 
 -other options
 -on Click [buttons]
 -on menu selector change?
 -on Change
 	get parameter ID from NSControl.[applicationNumber Unique ID]
 
 	make an OOB param accessor
 
 	set the changed data with the FxPlug Parameter Set API v5/6
 	
 	call the effect parameterChanged
 
 	end OOB accessor
 
 */


@end
