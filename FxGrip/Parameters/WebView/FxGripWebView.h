/*!
	@file       FxGripWebView.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripWebView
	@abstract   The configuration keys of a web-view parameter's value dictionary.
	@discussion Introduced in FxGrip 0.1.0. The kFxGripWebViewKey_* constants name the entries a
	            web-view control reads from its value: the URL, the access whitelist, and the row
	            height. An absent whitelist defaults to the single pattern that allows all sites.
	            kFxGripWebViewDefaultHeight is the fallback row height.
*/

#ifndef FxGripWebView_h
#define FxGripWebView_h

#import <Foundation/Foundation.h>
#import "FxGripDictionary.h"

// A web-view control carries the URL to load under the string key. The access whitelist
// is an array of glob patterns under a dedicated key; a nil or absent whitelist defaults
// to the single pattern `*` (all sites). The row height in points carries a dedicated key.
#define kFxGripWebViewKey_URL			kCustomAPI_StringKey
#define kFxGripWebViewKey_Whitelist		@"whitelist"
#define kFxGripWebViewKey_Height		@"height"

#define kFxGripWebViewDefaultHeight		(200.0)

#endif
