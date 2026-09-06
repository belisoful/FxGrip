/*!
	@file       FxGripRandom.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripRandom
	@abstract   The value dictionary keys and defaults for the random integer parameter.
	@discussion Introduced in FxGrip 0.1.0. A random control carries its integer value under the
	            int key. The randomization range and the stepper increment carry dedicated keys.
	            Reload draws a new value in the closed range from min to max.
*/

#ifndef FxGripRandom_h
#define FxGripRandom_h

#import <Foundation/Foundation.h>
#import "FxGripDictionary.h"

/*! The value dictionary key carrying the current integer. */
#define kFxGripRandomKey_Value		kCustomAPI_IntKey
/*! The value dictionary key carrying the randomization range minimum. */
#define kFxGripRandomKey_Min		@"min"
/*! The value dictionary key carrying the randomization range maximum. */
#define kFxGripRandomKey_Max		@"max"
/*! The value dictionary key carrying the stepper increment. */
#define kFxGripRandomKey_Step		@"step"

/*! The default integer value. */
#define kFxGripRandomDefaultValue	(0)
/*! The default range minimum. */
#define kFxGripRandomDefaultMin		(0)
/*! The default range maximum, INT32_MAX. */
#define kFxGripRandomDefaultMax		(2147483647)	// INT32_MAX
/*! The default stepper increment. */
#define kFxGripRandomDefaultStep	(1)

#endif
