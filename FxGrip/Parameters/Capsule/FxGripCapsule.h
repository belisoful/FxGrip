//
//  FxGripCapsule.h
//  FxGrip
//

#ifndef FxGripCapsule_h
#define FxGripCapsule_h

#import <Foundation/Foundation.h>
#import "FxGripDictionary.h"

// A capsule badge carries its text under the string key, its point size under the float
// key, and its fill color under the RGBA key. The text color and corner radius carry
// dedicated keys. A corner radius below zero (the default) draws a full pill.
#define kFxGripCapsuleKey_Title			kCustomAPI_StringKey
#define kFxGripCapsuleKey_FontSize		kCustomAPI_FloatKey
#define kFxGripCapsuleKey_FillColor		kCustomAPI_RGBAKey
#define kFxGripCapsuleKey_TextColor		@"textColor"
#define kFxGripCapsuleKey_CornerRadius	@"cornerRadius"

#define kFxGripCapsuleDefaultFontSize	(11.0)
#define kFxGripCapsulePillRadius		(-1.0)

#endif
