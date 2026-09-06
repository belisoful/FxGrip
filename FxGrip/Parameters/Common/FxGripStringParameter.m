/*!
	@file       FxGripStringParameter.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripStringParameter
	@abstract   Implements the parameter models for a host string parameter.
	@discussion Introduced in FxGrip 0.1.0. FxGripStringParameterBase reads, writes, and encodes the string value through the shared bodies in FxGripStringParameterBaseLibrary.m. FxGripStringParameter adds host registration through the shared body in FxGripStringParameterLibrary.m.
*/

#import "FxGripStringParameter.h"
#import "FxGripTileableEffect.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "NSCoder+FxPlug.h"

/*!
	@abstract	The base string parameter model that reads, writes, and encodes a string value.
	@discussion	Introduced in FxGrip 0.1.0. The class draws its method bodies from FxGripStringParameterBaseLibrary.m through a textual include.
*/
@implementation FxGripStringParameterBase

#include "FxGripStringParameterBaseLibrary.m"


@end



/*!
	@abstract	The parameter model for a host string field.
	@discussion	Introduced in FxGrip 0.1.0. The class draws its registration body from FxGripStringParameterLibrary.m through a textual include.
*/
@implementation FxGripStringParameter

#include "FxGripStringParameterLibrary.m"

@end
