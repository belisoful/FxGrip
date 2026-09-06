/*!
	@file       FxGripPresetsParameter.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripPresetsParameter
	@abstract   A popup menu parameter that lists and applies the presets for one tag.
	@discussion Introduced in FxGrip 0.1.0. The menu lists Default, the user presets, the plugin
	            presets, and the Reveal and Save action entries. Selecting a preset name applies
	            it through the presets API and records the name in the instance record. The managed
	            per-tag user preset folder is watched, so a file change there rebuilds the menu and
	            remaps the recorded selection to its new index.
*/

#ifndef FxGripPresetsParameter_h
#define FxGripPresetsParameter_h

#import "FxGripMenuParameter.h"

/*! The menu entry that records the default state and applies no preset. */
#define kFxPresetsMenuEntry_Default		@"Default"
/*! The menu separator entry between preset sections. */
#define kFxPresetsMenuEntry_Separator	@"-"
/*! The action entry that opens the managed user preset folder in Finder. */
#define kFxPresetsMenuEntry_Reveal		@"Reveal User Presets in Finder..."
/*! The action entry that captures the current state and runs the save panel. */
#define kFxPresetsMenuEntry_Save		@"Save Preset"

/*! The instance-record meta key carrying the selected preset's NAME. The host persists
	a menu as an int; the name keeps the selection stable when entries are appended,
	removed, or reordered across plugin versions. */
#define kFxMetaProperty_SelectedPreset	@"selectedPreset"

/*!
	@class      FxGripPresetsParameter
	@abstract   A popup menu that lists and applies the presets for one tag.
	@discussion Introduced in FxGrip 0.1.0. The menu is built at creation time as
				`Default, -, <user presets>, -, <plugin presets>, -,
				Reveal User Presets in Finder..., Save Preset`; an empty preset section
				is omitted together with its separator. The tag is the parameter
				configuration's first entry under `tags`.

				Selecting a preset name applies it through the presets API and records
				the name under kFxMetaProperty_SelectedPreset in the instance record;
				user presets shadow plugin presets of the same name, matching the menu
				order. Selecting Default records the default state and applies nothing.
				The two action entries run their action and restore the previous
				selection: Reveal opens the managed user preset folder in Finder
				(creating it on demand), and Save Preset captures the current state and
				runs the save panel.

				The managed per-tag folder is watched (BEPathWatcher): a file added,
				removed, or renamed there rebuilds the menu on the host through
				setPopupMenuParameter:entries:defaultValue: and remaps the recorded
				selection name to its new index. The watcher attaches when the folder
				exists; the reveal and save actions attach it after creating the folder,
				and a save refreshes explicitly.
 */
@interface FxGripPresetsParameter : FxGripMenuParameter

/*! The menu entry list for a configuration, in the documented order. */
+ (nonnull NSArray<NSString*>*)menuEntriesForParameter:(nonnull NSDictionary*)parameter
											    effect:(nonnull id<FxGripEffectHost>)effect;

/*! The configuration's preset tag: the first entry under `tags`. */
+ (nullable NSString*)presetTagForParameter:(nonnull NSDictionary*)parameter;

@end

#endif /* FxGripPresetsParameter_h */
