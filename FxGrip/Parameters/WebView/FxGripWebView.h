//
//  FxGripWebView.h
//  FxGrip
//

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
