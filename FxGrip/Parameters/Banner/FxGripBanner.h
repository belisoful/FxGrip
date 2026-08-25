//
//  FxGripBanner.h
//  FxGrip
//

#ifndef FxGripBanner_h
#define FxGripBanner_h

#import <Foundation/Foundation.h>
#import "FxGripDictionary.h"

// A banner carries its title under the string key, its title point size under the float
// key, and its background color under the RGBA key. The subtitle, text color, and corner
// radius carry dedicated keys. A corner radius below zero (the default) draws square
// corners spanning the full width.
#define kFxGripBannerKey_Title			kCustomAPI_StringKey
#define kFxGripBannerKey_FontSize		kCustomAPI_FloatKey
#define kFxGripBannerKey_FillColor		kCustomAPI_RGBAKey
#define kFxGripBannerKey_Subtitle		@"subtitle"
#define kFxGripBannerKey_TextColor		@"textColor"
#define kFxGripBannerKey_CornerRadius	@"cornerRadius"

#define kFxGripBannerDefaultFontSize	(12.0)
#define kFxGripBannerSquareCorners		(-1.0)

#endif
