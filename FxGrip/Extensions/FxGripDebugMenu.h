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

/*!
	@property   allowsDebugFeatures
	@abstract   Master gate for every debug feature this effect exposes.
	@discussion Introduced in FxGrip 1.0. Returns YES. A plugin overrides this getter to
				return NO in compiled code, which forces both debug channels off regardless
				of the Info.plist. The Info.plist keys `debugMenu` and `debugActivator` reach
				the framework only through `pluginDebugMenuEnabled` and
				`pluginDebugActivatorEnabled`, both of which consult this gate first, so an
				override here blocks a plist edit from re-enabling the debug menu.
*/
@property (readonly) BOOL allowsDebugFeatures;

/*!
	@property   pluginDebugMenuEnabled
	@abstract   YES when the debug menu channel is permitted.
	@discussion Introduced in FxGrip 1.0. Default is `allowsDebugFeatures` and the Info.plist
				`debugMenu` key together. A plugin overrides this getter to control the menu
				channel independently of the activator channel.
*/
@property (readonly) BOOL pluginDebugMenuEnabled;

/*!
	@property   pluginDebugActivatorEnabled
	@abstract   YES when the debug activator channel is permitted.
	@discussion Introduced in FxGrip 1.0. Default is `allowsDebugFeatures` and the Info.plist
				`debugActivator` key together. A plugin overrides this getter to control the
				activator channel independently of the menu channel.
*/
@property (readonly) BOOL pluginDebugActivatorEnabled;

/*! YES when either debug channel is permitted; the loader gates on this. */
@property (readonly) BOOL hasDebugMenu;

- (nonnull FxGripDebugMenu *)newDebugMenuExtension;

@end

#endif
