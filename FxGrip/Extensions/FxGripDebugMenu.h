//
//  FxGripDebugMenu.h
//  FxGrip
//
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef FxGripDebugMenu_h
#define FxGripDebugMenu_h

#import "FxExtension.h"
#import "FxTileableEffectBase.h"

extern NSString*	const _Nonnull FxGripDebugMenuExtensionKey;

@interface FxGripDebugMenu : FxExtension


@end


@interface FxTileableEffectBase (DebugMenu)

@property (readonly, nullable) FxGripDebugMenu *debugMenu;

/*! YES when the plugin declares a debug menu or debug activator; the loader gates on this. */
@property (readonly) BOOL hasDebugMenu;

- (nonnull FxGripDebugMenu *)newDebugMenuExtension;

@end

#endif
