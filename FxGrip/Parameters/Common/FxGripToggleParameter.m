/*!
	@file       FxGripToggleParameter.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripToggleParameter
	@abstract   Implements the parameter model for a host toggle button.
	@discussion Introduced in FxGrip 0.1.0. The class registers a toggle button through the parameter-creation API and reads and writes its boolean value at a render time. The shared method bodies come from FxGripToggleParameterLibrary.m through a textual include.
*/

#import "FxGripToggleParameter.h"
#import "FxGripTileableEffect.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "NSCoder+FxPlug.h"

/*!
	@abstract	The parameter model for a host toggle button.
	@discussion	Introduced in FxGrip 0.1.0. The class registers a toggle button, reads and writes its boolean value at a render time, and encodes the value into the plugin-state coder.
*/
@implementation FxGripToggleParameter


#include "FxGripToggleParameterLibrary.m"


@end
