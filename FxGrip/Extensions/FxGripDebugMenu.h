//
//  FxGripToggle.h
//  PlugIn
//
//  Created by Apple on 2/12/20.
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

@end

#endif
