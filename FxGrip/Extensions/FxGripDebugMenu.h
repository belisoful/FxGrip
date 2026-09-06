/*!
	@file       FxGripDebugMenu.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripDebugMenu
	@abstract   The extension that exposes a hidden debug menu and its activator on an effect.
	@discussion Introduced in FxGrip 0.1.0. The extension registers a debug popup parameter and an
	            optional activator toggle. The menu commands reveal hidden parameters, toggle the
	            activator's value and visibility, and remove the debug controls. The debug channels
	            are gated by allowsDebugFeatures together with the Info.plist keys, so a compiled
	            override can force them off. In debug mode the extension transfers a parameter's
	            HIDDEN bit to and from a hidden-proxy bit on flags reads and writes.
*/

#ifndef FxGripDebugMenu_h
#define FxGripDebugMenu_h

#import "FxGripExtension.h"
#import "FxGripTileableEffect.h"

/*! The registry key under which the effect stores the debug menu extension. */
extern NSString*	const _Nonnull FxGripDebugMenuExtensionKey;

/*!
	@class		FxGripDebugMenu
	@abstract	The extension that presents the effect's debug menu and activator.
	@discussion	Introduced in FxGrip 0.1.0. The extension registers the debug parameters, drives the
				debug-mode flag transforms, and dispatches the menu commands.
*/
@interface FxGripDebugMenu : FxGripExtension


@end


/*!
	@abstract	The effect-side gate and accessors for the debug menu extension.
	@discussion	Introduced in FxGrip 0.1.0. The debug channels resolve through allowsDebugFeatures and
				the Info.plist keys; the loader installs the extension when hasDebugMenu is YES.
*/
@interface FxGripTileableEffect (DebugMenu)

/*! The installed debug menu extension, or nil when none is installed. */
@property (readonly, nullable) FxGripDebugMenu *debugMenu;

/*!
	@property   allowsDebugFeatures
	@abstract   Master gate for every debug feature this effect exposes.
	@discussion Introduced in FxGrip 0.1.0. Returns YES. A plugin overrides this getter to
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
	@discussion Introduced in FxGrip 0.1.0. Default is `allowsDebugFeatures` and the Info.plist
				`debugMenu` key together. A plugin overrides this getter to control the menu
				channel independently of the activator channel.
*/
@property (readonly) BOOL pluginDebugMenuEnabled;

/*!
	@property   pluginDebugActivatorEnabled
	@abstract   YES when the debug activator channel is permitted.
	@discussion Introduced in FxGrip 0.1.0. Default is `allowsDebugFeatures` and the Info.plist
				`debugActivator` key together. A plugin overrides this getter to control the
				activator channel independently of the menu channel.
*/
@property (readonly) BOOL pluginDebugActivatorEnabled;

/*! YES when either debug channel is permitted; the loader gates on this. */
@property (readonly) BOOL hasDebugMenu;

/*! Creates the debug menu extension instance for the loader to install. */
- (nonnull FxGripDebugMenu *)newDebugMenuExtension;

@end

#endif
