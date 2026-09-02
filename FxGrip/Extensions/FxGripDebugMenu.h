//
//  FxGripDebugMenu.h
//  FxGrip
//
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef FxGripDebugMenu_h
#define FxGripDebugMenu_h

#import "FxGripExtension.h"
#import "FxGripTileableEffect.h"

extern NSString*	const _Nonnull FxGripDebugMenuExtensionKey;

@interface FxGripDebugMenu : FxGripExtension


@end


@interface FxGripTileableEffect (DebugMenu)

@property (readonly, nullable) FxGripDebugMenu *debugMenu;

/*! YES when the plugin declares a debug menu or debug activator; the loader gates on this. */
@property (readonly) BOOL hasDebugMenu;

- (nonnull FxGripDebugMenu *)newDebugMenuExtension;

@end

#endif
