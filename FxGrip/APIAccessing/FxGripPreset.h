/*!
	@file       FxGripPreset.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripPreset
	@abstract   The preset model and its FxFactory-compatible file form.
	@discussion Introduced in FxGrip 0.1.0. The model holds a preset's parameter values, tags, and
	            meta, plus the identity of the plugin that produced them. The on-disk form is an
	            XML property list in FxFactory's .fxpreset format, extended with flat FxGripPreset*
	            keys. The class also converts between encoded preset values and live parameters
	            through a setting API.
*/

#ifndef FxGripPreset_h
#define FxGripPreset_h

#import <FxPlug/FxPlugSDK.h>
#import "FxGripTypes.h"

/*! The system-key names for a preset's fields. Written to and read from the file form. */
#define kFxPresetProperty_CreatedByParameterId @"createdByParameterId"
#define kFxPresetProperty_ParameterValues @"parameterValues"
#define kFxPresetProperty_Framework		@"framework"
#define kFxPresetProperty_PresetUuid	@"presetUuid"
#define kFxPresetProperty_DisplayName	@"displayName"
#define kFxPresetProperty_Tag			@"tag"
#define kFxPresetProperty_CreatedTime	@"createdTime"
#define kFxPresetProperty_PluginAuthor	@"pluginAuthor"
#define kFxPresetProperty_LocalizedName	@"localizedName"
#define kFxPresetProperty_PluginUuid	@"pluginUuid"
#define kFxPresetProperty_PluginVersion	@"pluginVersion"
#define kFxPresetProperty_ProductId		@"productId"
#define kFxPreset_Extension				@"fxpreset"

#define kFxPresetProperty_ParameterMeta @"parameterMeta"
#define kFxPresetProperty_ParameterTags @"parameterTags"

// FxFactory file keys, pinned by the repository sample "FxFactory Circle Preset.fxpreset".
// A written file carries these seven under their exact names so FxFactory reads FxGrip
// files and FxGrip reads FxFactory files.
#define kFxFactoryPresetKey_CreatedByParameterId	@"FxFactoryPresetCreatedByParameterID"
#define kFxFactoryPresetKey_ParameterValues			@"FxFactoryPresetParameterValues"
#define kFxFactoryPresetKey_PluginAuthor			@"FxFactoryPresetPlugInAuthor"
#define kFxFactoryPresetKey_LocalizedName			@"FxFactoryPresetPlugInLocalizedName"
#define kFxFactoryPresetKey_PluginUuid				@"FxFactoryPresetPlugInUUID"
#define kFxFactoryPresetKey_PluginVersion			@"FxFactoryPresetPlugInVersion"
#define kFxFactoryPresetKey_ProductId				@"FxFactoryPresetProductID"

// FxGrip file keys. The seven additions have no FxFactory equivalent and ride alongside
// the FxFactory keys as flat siblings; a reader ignores keys it does not know, so both
// directions degrade to the shared subset.
#define kFxGripPresetKey_Framework		@"FxGripPresetFramework"
#define kFxGripPresetKey_Uuid			@"FxGripPresetUUID"
#define kFxGripPresetKey_DisplayName	@"FxGripPresetDisplayName"
#define kFxGripPresetKey_Tag			@"FxGripPresetTag"
#define kFxGripPresetKey_CreatedTime	@"FxGripPresetCreatedTime"
#define kFxGripPresetKey_ParameterMeta	@"FxGripPresetParameterMeta"
#define kFxGripPresetKey_ParameterTags	@"FxGripPresetParameterTags"

/*!
	@class      FxGripPreset
	@abstract   The preset model: parameter values, tags, and meta plus the identity of
				the plugin that produced them.
	@discussion Introduced in FxGrip 0.1.0. The on-disk form is an XML property list in
				FxFactory's `.fxpreset` format, extended with flat `FxGripPreset*` keys.
				`presetDictionary` and `initWithPresetDictionary:` are the canonical
				round-trip; `savePresetToURL:` and `loadPresetFromURL:` add the file I/O.
				Parameter-keyed dictionaries use string parameter-ID keys on disk,
				matching FxFactory.
 */
@interface FxGripPreset : NSObject

	/*! The ID of the parameter that created the preset, or 0 when none. */
	@property (assign) FxParameterId createdByParameterId;

	/*! The captured parameter values, keyed by parameter ID. */
	@property (copy, nullable) NSDictionary *parameterValues; // key=paramId, value= [int, float, string, bool, dict]
	/*! The captured parameter meta, keyed by parameter ID. */
	@property (copy, nullable) NSDictionary *parameterMeta;
	/*! The captured parameter tags, keyed by parameter ID. */
	@property (copy, nullable) NSDictionary *parameterTags;

	/*! The framework that produced the preset, such as FxGrip or FxFactory. */
	@property (copy, nullable) NSString *framework; // FxGrip, FxFactory, etc
	/*! The preset's own UUID. */
	@property (copy, nullable) NSString *uuid; //preset uuid
	/*! The preset's display name. */
	@property (copy, nullable) NSString *name; //display name
	/*! The tag the preset applies under. */
	@property (copy, nullable) NSString *tag;
	/*! The preset's creation timestamp, in ISO 8601. */
	@property (copy, nullable) NSString *createdTime;

	/*! The plugin author. */
	@property (copy, nullable) NSString *pluginAuthor;
	/*! The plugin's localized name; a string or FxFactory's per-language dictionary. */
	// NSString, or the per-language NSDictionary FxFactory writes; round-trips verbatim.
	@property (copy, nullable) id pluginLocalizedName;
	/*! The plugin's UUID; drives preset compatibility. */
	@property (copy, nullable) NSString *pluginUuid;
	/*! The plugin's version string. */
	@property (copy, nullable) NSString *pluginVersion;
	/*! The plugin's product ID. */
	@property (copy, nullable) NSString *productId;

/*!
	@method     initWithPresetDictionary:
	@abstract   Builds a preset from a file-form dictionary.
	@discussion Introduced in FxGrip 0.1.0. Reads the FxFactory keys and the FxGripPreset*
				keys; unknown keys are ignored. Returns nil when the argument is not a
				dictionary.
*/
- (nullable instancetype)initWithPresetDictionary:(nullable NSDictionary*)dictionary;

/*!
	@method     presetDictionary
	@abstract   The file-form dictionary: FxFactory keys plus FxGripPreset* keys.
	@discussion Introduced in FxGrip 0.1.0. Nil properties are omitted. Parameter-keyed
				dictionaries are written with string keys.
*/
- (nonnull NSDictionary*)presetDictionary;

/*!
	@method     presetSections
	@abstract   The values/tags/meta sections in the shape applyPreset: consumes.
	@discussion Introduced in FxGrip 0.1.0. Sections a preset does not carry are omitted.
*/
- (nonnull NSDictionary*)presetSections;

/*!
	@method     savePresetToURL:
	@abstract   Writes the preset as an XML property list.
	@discussion Introduced in FxGrip 0.1.0. Returns NO when a carried value is not a
				property-list type or the write fails.
*/
- (BOOL)savePresetToURL:(nonnull NSURL*)url;

/*!
	@method     loadPresetFromURL:
	@abstract   Reads a preset written by savePresetToURL: or by FxFactory.
	@discussion Introduced in FxGrip 0.1.0. Returns nil when the file is missing or is not
				a property-list dictionary.
*/
+ (nullable FxGripPreset*)loadPresetFromURL:(nonnull NSURL*)url;

/*!
	@method     setParameterValue:toParameter:atTime:withAPI:
	@abstract   Writes one encoded preset value to a parameter.
	@discussion Introduced in FxGrip 0.1.0. Dispatches on the parameter's type, resolved
				through the FxGrip setting wrapper's dynamic API; when no type source is
				available the encoded value's own shape selects the setter.

				Encodings: RGBA and RGB are dictionaries of `red`/`green`/`blue` with an
				optional `alpha`; Point is `x`/`y`; String and FontMenu are strings;
				Toggle, Int, and Menu are numbers; Custom is a dictionary that merges
				recursively into the parameter's current value so a preset may carry a
				subset; every other type takes a number as a float.
	@result     YES when the value is written.
*/
+ (BOOL)setParameterValue:(nonnull id)value toParameter:(FxParameterId)parameterID atTime:(CMTime)time withAPI:(nonnull id<FxParameterSettingAPI_v5>)setterAPI;

/*!
	@method     getParameterValue:toParameter:atTime:withAPI:
	@abstract   Reads a parameter into the encoded preset representation.
	@discussion The inverse of setParameterValue:toParameter:atTime:withAPI:, producing
				the same encodings. Requires the FxGrip setting wrapper, which exposes
				the retrieval API.
*/
+ (BOOL)getParameterValue:(id _Nullable * _Nonnull)value toParameter:(FxParameterId)parameterID atTime:(CMTime)time withAPI:(nonnull id<FxParameterSettingAPI_v5>)setterAPI;

@end


#endif /* FxGripPreset_h */
