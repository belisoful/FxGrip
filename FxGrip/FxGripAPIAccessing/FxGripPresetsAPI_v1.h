//
//  FxGripPresetsAPI_v1.h
//  MetalFx ML Upscale
//
//  Created by ~ ~ on 2/29/24.
//

#ifndef FxGripPresetsAPI_v1_h
#define FxGripPresetsAPI_v1_h

#import <FxPlug/FxPlugSDK.h>
#import "FxGripPreset.h"
#import "FxGripCommonAPI.h"

typedef enum FxParameterPresetFlagOptions {
	kFxParameterPreset_Default				= (0 << 0),
	
	// ignores check for compatibility with the preset plugin Uuid agains the current Uuid and uuid alternatives
	kFxParameterPreset_IgnoreCompatibility	= (1 << 0),
	
	// ignores if a parameter doesn't need the preset tag to set its value.
	kFxParameterPreset_IgnoreTagBoundary	= (1 << 1),
	
	// ignores preset meta data.
	kFxParameterPreset_IgnoreMetaData		= (1 << 2)
} FxParameterPresetFlagOptions;


@protocol FxPresetsAPI_v1
@end


/*!
	@interface  FxGripDynamicParameterAPI_v4:
	@abstract   Initializes the API manager for your plug-in.
	@discussion Accesses the apis with error checking.

 */

#define kFxPresetProperty_ColorSpace	@"colorSpace"
#define kFxPresetProperty_RemapValues	@"remapValues"
#define kFxPresetProperty_Extension		@"extension"
#define kFxPreset_Extension				@"fxpreset"

#define kFxFactorPresetColorSpace_sRGB_Color 1

#define kFxFactoryPresetKeyMap (@{ \
	kFxPresetProperty_CreatedByParameterId : @"FxFactoryPresetCreatedByParameterID", \
	kFxPresetProperty_ParameterValues : @"FxFactoryPresetParameterValues", \
	kFxPresetProperty_PluginAuthor : @"FxFactoryPresetPlugInAuthor" \
	kFxPresetProperty_LocalizedName : @"FxFactoryPresetPlugInLocalizedName" \
	kFxPresetProperty_PluginUuid : @"FxFactoryPresetPlugInUUID" \
	kFxPresetProperty_PluginVersion : @"FxFactoryPresetPlugInVersion" \
	kFxPresetProperty_ProductId : @"FxFactoryPresetProductID" \
	kFxPresetProperty_RemapValues : @{kFxPresetProperty_ColorSpace : @{kFxImageColorInfo_RGB_GAMMA_VIDEO: @kFxFactorPresetColorSpace_sRGB_Color}} \
	kFxPresetProperty_Extension : @"fxpreset"} \
	})

@interface FxGripPresetsAPI_v1 : FxGripCommonAPI <FxPresetsAPI_v1>

@property (assign, readonly) id<FxPresetsAPI_v1> _Nonnull api;

- (nullable instancetype)initWithAPI:(id<FxPresetsAPI_v1>_Nonnull)api
							  effect:(id<FxTileableEffectBase>_Nonnull)effect;
// NSDictionary
// -uuid of plugin
// -uuid of preset
// -preset name
// -preset tag
// -preset time
// -parameters: key is ID
//	-value
//	-meta (optional)
- (NSError* _Nullable)generatePreset:(FxGripPreset*_Nullable*_Nonnull)preset fromLabel:(NSString*_Nonnull)label;
- (NSError* _Nullable)setPreset:(FxGripPreset*_Nonnull)preset options:(FxParameterPresetFlags)flags;

- (BOOL)savePreset:(FxGripPreset*_Nonnull)preset remap:(NSDictionary* _Nullable)keyMap; // remap- key is system keys, value is file keys
- (BOOL)loadPreset:(FxGripPreset*_Nullable*_Nonnull)preset  remap:(NSDictionary* _Nullable)keyMap;

- (NSURL*_Nullable)pluginPresetURL;
- (NSURL*_Nullable)pluginPresetURL:(NSString*_Nonnull)tag; // the tag preset folder inside the preset folder.


+ (BOOL)openMediaPresetFolder;
+ (BOOL)openMediaPresetFolder:(NSString* _Nonnull)tag;

// get plist presets and user presets
+ (NSArray*_Nonnull)presetsForTag:(NSString*_Nonnull)tag;

// get plist presets
+ (NSArray*_Nonnull)pluginPresetsForTag:(NSString*_Nonnull)tag;

// get user presets
+ (NSArray*_Nonnull)userPresetsForTag:(NSString*_Nonnull)tag;

// observes a specific tag preset folder
+ (DirectoryWatcher*_Nullable)observeTag:(NSString*_Nonnull)tag observer:(void(^_Nonnull)(void))handler;

- (BOOL)compatiblePreset:(FxGripPreset*_Nullable)preset;

@end


#endif /* FxGripPresetsAPI_v1_h */

