/*!
	@file       FxGripCapsule.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripCapsule
	@abstract   The configuration keys and defaults of a capsule badge parameter.
	@discussion Introduced in FxGrip 0.1.0. The kFxGripCapsuleKey_* constants name the entries a
	            capsule badge reads from its value: the text, point size, and fill color reuse
	            the standard custom-value keys, and the text color and corner radius carry
	            dedicated keys. kFxGripCapsulePillRadius is the default corner radius that draws a
	            full pill.
*/

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
