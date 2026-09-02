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

// Image mode. A resolvable image name switches the banner from a text strip to a graphic
// (the title and subtitle still draw beneath it when present). A template image is drawn
// tinted by the text color so a black-with-alpha graphic adapts to a light or dark UI. A
// link URL makes the banner clickable; an action button shows a companion control that
// opens the same link. This mirrors the FxFactory image banner.
#define kFxGripBannerKey_ImageName		@"imageName"
#define kFxGripBannerKey_TemplateImage	@"templateImage"
#define kFxGripBannerKey_LinkURL		@"linkURL"
#define kFxGripBannerKey_ActionButton	@"actionButton"

#define kFxGripBannerDefaultFontSize	(12.0)
#define kFxGripBannerSquareCorners		(-1.0)

// FxFactory constrains banner graphics to this width, in view points.
#define kFxGripBannerMaxImageWidth		(148.0)

#endif
