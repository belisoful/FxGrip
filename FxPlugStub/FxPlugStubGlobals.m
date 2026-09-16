/*!
	@file       FxPlugStubGlobals.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-10
	@header     FxPlugStubGlobals
	@abstract   Test-only definitions of the data symbols FxPlug.framework exports.
	@discussion Introduced in FxGrip 0.1.0. The SDK's text stub lists these globals alongside the
	            three classes; FxGrip imports FxPlugErrorDomain and kFxRect_Empty weakly, and they
	            resolve to NULL without a binary. The key character values follow the comments in
	            FxCommandAPI.h.
*/

#import "FxPlugStub.h"
#import <FxPlug/FxCommandAPI.h>

NSString *FxPlugErrorDomain = @"FxPlugErrorDomain";

FxRect kFxRect_Infinite = { INT32_MIN, INT32_MIN, INT32_MAX, INT32_MAX };
FxRect kFxRect_Empty = { 0, 0, 0, 0 };

NSString *kKey_Command = @"kKey_Command";
NSString *kKey_Character = @"kKey_Character";
NSString *kKey_Modifiers = @"kKey_Modifiers";

unichar kKeyChar_UpArrow = 0x21de;
unichar kKeyChar_LeftArrow = 0x21e0;
unichar kKeyChar_DownArrow = 0x21df;
unichar kKeyChar_RightArrow = 0x21e2;

bool FxRectsAreEqual(FxRect thisRect, FxRect thatRect)
{
	return thisRect.left == thatRect.left
		&& thisRect.bottom == thatRect.bottom
		&& thisRect.right == thatRect.right
		&& thisRect.top == thatRect.top;
}
