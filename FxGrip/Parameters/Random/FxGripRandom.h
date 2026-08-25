//
//  FxGripRandom.h
//  FxGrip
//

#ifndef FxGripRandom_h
#define FxGripRandom_h

#import <Foundation/Foundation.h>
#import "FxGripDictionary.h"

// A random control carries its integer value under the int key. The randomization range
// and the stepper increment carry dedicated keys. Reload draws a new value in [min, max].
#define kFxGripRandomKey_Value		kCustomAPI_IntKey
#define kFxGripRandomKey_Min		@"min"
#define kFxGripRandomKey_Max		@"max"
#define kFxGripRandomKey_Step		@"step"

#define kFxGripRandomDefaultValue	(0)
#define kFxGripRandomDefaultMin		(0)
#define kFxGripRandomDefaultMax		(2147483647)	// INT32_MAX
#define kFxGripRandomDefaultStep	(1)

#endif
