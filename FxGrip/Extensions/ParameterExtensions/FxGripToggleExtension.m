/*!
	@file       FxGripToggleExtension.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripToggleExtension
	@abstract   Implements the parameter extension that models a toggle parameter.
	@discussion Introduced in FxGrip 0.1.0. The extension draws its toggle behavior from the included
	            toggle parameter library, replicating FxGripIntParameter for the boolean case.
*/

#import "FxGripToggleExtension.h"
#import "FxGripTileableEffect.h"
#import "FxGripTileableEffect+Notifications.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "NSCoder+FxPlug.h"



#pragma mark -
#pragma mark FxGripExtensionIntParameter Implementation
// replicate FxGripIntParameter in this class

/*!
	@abstract	The extension that represents a toggle effect parameter.
	@discussion	Introduced in FxGrip 0.1.0. The toggle behavior comes from the included toggle parameter
				library.
*/
@implementation FxGripToggleExtension

#include "../../Parameters/Common/FxGripToggleParameterLibrary.m"

@end


 
