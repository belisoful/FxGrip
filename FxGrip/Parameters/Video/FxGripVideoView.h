//
//  FxGripVideoView.h
//  FxGrip
//

#ifndef FxGripVideoView_h
#define FxGripVideoView_h

#import <Foundation/Foundation.h>
#import "FxGripDictionary.h"

// A video control carries the URL to play under the string key. The access whitelist is an
// array of glob patterns under a dedicated key; a nil or absent whitelist defaults to the
// common video-hosting domains. Row height, autoplay, and loop carry dedicated keys.
#define kFxGripVideoKey_URL				kCustomAPI_StringKey
#define kFxGripVideoKey_Whitelist		@"whitelist"
#define kFxGripVideoKey_Height			@"height"
#define kFxGripVideoKey_Autoplay		@"autoplay"
#define kFxGripVideoKey_Loop			@"loop"

#define kFxGripVideoDefaultHeight		(180.0)

#endif
