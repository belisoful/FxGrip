/*!
	@file       FxGripPresetsAPI_v1.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripPresetsAPI_v1
	@abstract   The preset file and discovery API in the style of Apple's FxPlug APIs.
	@discussion Introduced in FxGrip 0.1.0. The API captures the effect's parameters as a preset,
	            applies presets through the tag API core, browses the merged plugin and user
	            listings, and watches the managed user folder. FxGrip owns this API; no host vends
	            it. Preset application funnels into the tag API's
	            applyPreset:atTime:options:presetFlags:source:tag:, which owns the tag boundary and
	            section ordering.
*/

#ifndef FxGripPresetsAPI_v1_h
#define FxGripPresetsAPI_v1_h

#import <FxPlug/FxPlugSDK.h>
#import <FxGrip/FxGripPreset.h>
#import <FxGrip/FxGripCommonAPI.h>

@class BEPathWatcher;

/*! @enum FxGripParameterPresetFlagOptions
	Flags that relax preset application: compatibility, the tag boundary, and meta data. */
typedef enum FxGripParameterPresetFlagOptions {
	kFxParameterPreset_Default				= (0 << 0),

	// ignores check for compatibility with the preset plugin Uuid agains the current Uuid and uuid alternatives
	kFxParameterPreset_IgnoreCompatibility	= (1 << 0),

	// ignores if a parameter doesn't need the preset tag to set its value.
	kFxParameterPreset_IgnoreTagBoundary	= (1 << 1),

	// ignores preset meta data.
	kFxParameterPreset_IgnoreMetaData		= (1 << 2)
} FxGripParameterPresetFlagOptions;


/*!
	@protocol   FxGripPresetsAPI_v1
	@abstract   The preset file and discovery layer, in the style of Apple's FxPlug APIs.
	@discussion Introduced in FxGrip 0.1.0. FxGrip's own API; no host vends it. Captures and applies
				presets, browses the merged plugin and user listings, and watches the managed user
				folder. FxGripPresetsAPI_v1 is the implementation.
*/
@protocol FxGripPresetsAPI_v1 <NSObject>

/*!
	@method		generatePreset:fromLabel:
	@abstract	Captures the effect's current parameter state as a preset.
	@discussion	Captures every runtime parameter's value at time zero, plus its tags and meta,
				and fills the plug-in identity from the effect. A parameter flagged PRESETNOTAGS
				or PRESETNOMETA opts out of that section.
	@param		preset	On return, the captured preset.
	@param		label	The preset's display name.
	@return		The error that stopped the capture, or nil.
*/
- (NSError* _Nullable)generatePreset:(FxGripPreset* _Nullable * _Nonnull)preset fromLabel:(NSString* _Nonnull)label;

/*!
	@method		setPreset:options:atTime:
	@abstract	Applies a preset at a time, through the tag API core.
	@discussion	Verifies compatibility, then applies the values, tags, and meta sections under the
				preset's tag, so the tag boundary governs which parameters change.
	@param		preset	The preset to apply.
	@param		flags	Options that relax the apply. See ``FxGripParameterPresetFlagOptions``.
	@param		time	The time the values apply at.
	@return		The error that stopped the apply, or nil.
*/
- (NSError* _Nullable)setPreset:(FxGripPreset* _Nonnull)preset options:(FxGripParameterPresetFlags)flags atTime:(CMTime)time;
/*!
	@method		setPreset:options:
	@abstract	Applies a preset at time zero.
	@param		preset	The preset to apply.
	@param		flags	Options that relax the apply. See ``FxGripParameterPresetFlagOptions``.
	@return		The error that stopped the apply, or nil.
*/
- (NSError* _Nullable)setPreset:(FxGripPreset* _Nonnull)preset options:(FxGripParameterPresetFlags)flags;

/*!
	@method		savePreset:remap:
	@abstract	Saves a preset to a user-chosen file through the save panel.
	@param		preset	The preset to write.
	@param		keyMap	A mapping applied to the preset's keys on the way out, or nil.
	@return		YES when the file was written.
*/
- (BOOL)savePreset:(FxGripPreset* _Nonnull)preset remap:(NSDictionary* _Nullable)keyMap;
/*!
	@method		loadPreset:remap:
	@abstract	Loads a preset from a user-chosen file through the open panel.
	@discussion	Reads a file written by FxGrip or by FxFactory.
	@param		preset	On return, the loaded preset.
	@param		keyMap	A mapping applied to the file's keys on the way in, or nil.
	@return		YES when a preset was read.
*/
- (BOOL)loadPreset:(FxGripPreset* _Nullable * _Nonnull)preset remap:(NSDictionary* _Nullable)keyMap;

/*! The plug-in's bundled `Presets` resource folder; nil when the bundle carries none. */
- (NSURL* _Nullable)pluginPresetURL;
/*! The bundled preset folder for one tag; nil when the bundle carries none. */
- (NSURL* _Nullable)pluginPresetURL:(NSString* _Nonnull)tag;
/*! The managed user preset folder, `~/Library/Application Support/<company>/<plugin name>`. */
- (NSURL* _Nullable)userPresetURL;
/*! The managed user preset folder for one tag, a `<tag>` subfolder of ``userPresetURL``. */
- (NSURL* _Nullable)userPresetURL:(NSString* _Nonnull)tag;

/*! Every preset carrying a tag, the plug-in's and the user's merged into one listing. */
- (NSArray<FxGripPreset*>* _Nonnull)presetsForTag:(NSString* _Nonnull)tag;
/*! The presets the plug-in bundle carries for a tag. */
- (NSArray<FxGripPreset*>* _Nonnull)pluginPresetsForTag:(NSString* _Nonnull)tag;
/*! The presets the managed user folder carries for a tag. */
- (NSArray<FxGripPreset*>* _Nonnull)userPresetsForTag:(NSString* _Nonnull)tag;

/*!
	@method		observeTag:observer:
	@abstract	Watches the managed per-tag user preset folder.
	@discussion	The handler runs when a preset file is added, changed, or removed, so a preset
				menu refreshes itself. Releasing the returned watcher ends the watch.
	@param		tag			The tag whose folder to watch.
	@param		handler		The block to run on each change.
	@return		The watcher, or nil when the folder cannot be watched.
*/
- (BEPathWatcher* _Nullable)observeTag:(NSString* _Nonnull)tag observer:(void(^ _Nonnull)(void))handler;

/*!
	@method		compatiblePreset:
	@abstract	Answers whether a preset's plug-in identity matches this effect.
	@param		preset	The preset to test, or nil.
	@return		YES when the preset's plug-in UUID matches the effect's, or appears among the
				plug-in's `supportedPlugins` alternatives.
*/
- (BOOL)compatiblePreset:(FxGripPreset* _Nullable)preset;

@end


/*! The remap sub-key naming a color-space value mapping. */
#define kFxPresetProperty_ColorSpace	@"colorSpace"
/*! The key-map entry holding per-key value remappings. */
#define kFxPresetProperty_RemapValues	@"remapValues"
/*! The key-map entry holding the preset file extension. */
#define kFxPresetProperty_Extension		@"extension"

/*! FxFactory's color-space code for sRGB color. */
#define kFxFactorPresetColorSpace_sRGB_Color 1

/*! The canonical system-key → FxFactory-file-key mapping, with the value-remap and
	extension metadata entries. presetDictionary already writes these file keys, so
	passing this map to savePreset:remap: is the identity mapping. */
#define kFxFactoryPresetKeyMap (@{ \
	kFxPresetProperty_CreatedByParameterId : kFxFactoryPresetKey_CreatedByParameterId, \
	kFxPresetProperty_ParameterValues : kFxFactoryPresetKey_ParameterValues, \
	kFxPresetProperty_PluginAuthor : kFxFactoryPresetKey_PluginAuthor, \
	kFxPresetProperty_LocalizedName : kFxFactoryPresetKey_LocalizedName, \
	kFxPresetProperty_PluginUuid : kFxFactoryPresetKey_PluginUuid, \
	kFxPresetProperty_PluginVersion : kFxFactoryPresetKey_PluginVersion, \
	kFxPresetProperty_ProductId : kFxFactoryPresetKey_ProductId, \
	kFxPresetProperty_RemapValues : @{kFxPresetProperty_ColorSpace : @{@(kFxImageColorInfo_RGB_GAMMA_VIDEO) : @(kFxFactorPresetColorSpace_sRGB_Color)}}, \
	kFxPresetProperty_Extension : kFxPreset_Extension \
	})

/*!
	@interface  FxGripPresetsAPI_v1
	@abstract   The preset file and discovery layer.
	@discussion Introduced in FxGrip 0.1.0. FxGrip implements this API itself; no host
				vends it, so the wrapper is constructed without a host API. Preset
				application funnels into the tag API core
				(applyPreset:atTime:options:presetFlags:source:tag:), which owns the tag
				boundary and section ordering.

				Two preset sources feed the merged listing:
				- premade, shipped with the plugin: the Info.plist `presets` table and
				  `.fxpreset` files bundled under the plugin's `Presets` resource folder;
				- user presets in the managed folder
				  `~/Library/Application Support/<company>/<plugin name>/<tag>/`, plus
				  arbitrary files through the save and open panels.

				Plist-table presets carry their values, tags, and meta sections in the
				listing; their flags and names sections apply through automatic rigging
				only.
 */
@interface FxGripPresetsAPI_v1 : FxGripCommonAPI <FxGripPresetsAPI_v1>

/*! The wrapped API, which stays nil because FxGrip implements the presets API itself. */
@property (assign, readonly) id<FxGripPresetsAPI_v1> _Nullable api;

/*!
	@method		initWithAPI:effect:
	@abstract	Creates the presets API for an effect.
	@param		api		Unused; no host vends a presets API, so callers pass nil.
	@param		effect	The effect whose parameters the presets capture and apply.
	@return		The presets API, or nil when it cannot be built.
*/
- (nullable instancetype)initWithAPI:(id<FxGripPresetsAPI_v1>_Nullable)api
							  effect:(id<FxGripEffectHost>_Nonnull)effect;

/*!
	@method     generatePreset:fromLabel:
	@abstract   Captures the effect's current parameter state as a preset.
	@discussion Introduced in FxGrip 0.1.0. Captures every runtime parameter's value at
				time zero, plus its tags and meta. Parameters flagged PRESETNOTAGS or
				PRESETNOMETA opt out of the tags and meta capture. The plugin identity
				fields are filled from the effect.
*/
- (NSError* _Nullable)generatePreset:(FxGripPreset*_Nullable*_Nonnull)preset fromLabel:(NSString*_Nonnull)label;

/*!
	@method     setPreset:options:atTime:
	@abstract   Applies a preset through the tag API core.
	@discussion Introduced in FxGrip 0.1.0. Verifies compatibility unless
				kFxParameterPreset_IgnoreCompatibility, then applies the preset's
				values, tags, and meta sections (meta withheld under
				kFxParameterPreset_IgnoreMetaData) with FxGripPresetSourceFile and the
				preset's tag, so the tag boundary governs which parameters change.
*/
- (NSError* _Nullable)setPreset:(FxGripPreset*_Nonnull)preset options:(FxGripParameterPresetFlags)flags atTime:(CMTime)time;

/*! Applies at time zero. */
- (NSError* _Nullable)setPreset:(FxGripPreset*_Nonnull)preset options:(FxGripParameterPresetFlags)flags;

/*!
	@method     savePreset:remap:
	@abstract   Saves a preset to a user-chosen file through the save panel.
	@discussion Introduced in FxGrip 0.1.0. The panel starts in the managed user preset
				folder (created on demand). `keyMap` maps system keys to file keys;
				presetDictionary already writes the FxFactory file keys, so
				kFxFactoryPresetKeyMap and nil are equivalent.
	@result     YES when the user confirms and the file is written.
*/
- (BOOL)savePreset:(FxGripPreset*_Nonnull)preset remap:(NSDictionary* _Nullable)keyMap;

/*!
	@method     loadPreset:remap:
	@abstract   Loads a preset from a user-chosen file through the open panel.
	@result     YES when the user confirms and the file parses.
*/
- (BOOL)loadPreset:(FxGripPreset*_Nullable*_Nonnull)preset  remap:(NSDictionary* _Nullable)keyMap;

/*! The plugin bundle's `Presets` resource folder; nil when the bundle has none. */
- (NSURL*_Nullable)pluginPresetURL;
/*! The per-tag subfolder of the bundled preset folder. */
- (NSURL*_Nullable)pluginPresetURL:(NSString*_Nonnull)tag;

/*!
	@method     userPresetURL
	@abstract   The managed user preset folder:
				`~/Library/Application Support/<company>/<plugin name>`.
	@discussion Introduced in FxGrip 0.1.0. `<company>` is the plugin group's display name
				and `<plugin name>` the plugin's display name; both are version
				agnostic, so presets survive plugin updates. The folder is not created
				by this accessor.
*/
- (NSURL*_Nullable)userPresetURL;
/*! The per-tag subfolder of the managed user preset folder. */
- (NSURL*_Nullable)userPresetURL:(NSString*_Nonnull)tag;

/*! The merged listing: pluginPresetsForTag: then userPresetsForTag:. */
- (NSArray<FxGripPreset*>*_Nonnull)presetsForTag:(NSString*_Nonnull)tag;

/*! Premade presets: the plist `presets` table entries for the tag, then bundled
	`.fxpreset` files from the per-tag bundle subfolder. */
- (NSArray<FxGripPreset*>*_Nonnull)pluginPresetsForTag:(NSString*_Nonnull)tag;

/*! User presets: `.fxpreset` files in the managed per-tag folder. A file that names no
	tag applies under the folder's tag. */
- (NSArray<FxGripPreset*>*_Nonnull)userPresetsForTag:(NSString*_Nonnull)tag;

/*!
	@method     observeTag:observer:
	@abstract   Watches the managed per-tag user preset folder.
	@discussion Introduced in FxGrip 0.1.0. The handler runs on each change to the folder.
				The caller keeps the returned watcher alive; deallocating it ends the
				watch. Returns nil when the folder does not exist.
*/
- (BEPathWatcher*_Nullable)observeTag:(NSString*_Nonnull)tag observer:(void(^_Nonnull)(void))handler;

/*!
	@method     compatiblePreset:
	@abstract   Answers whether a preset's plugin identity matches this effect.
	@discussion Introduced in FxGrip 0.1.0. The preset's plugin UUID must equal the
				effect's, or appear in the plugin's `supportedPlugins` alternatives.
*/
- (BOOL)compatiblePreset:(FxGripPreset*_Nullable)preset;

@end


#endif /* FxGripPresetsAPI_v1_h */
