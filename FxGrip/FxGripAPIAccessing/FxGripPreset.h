//
//  FxGripParameterCreationAPI_v5.h
//  MetalFx ML Upscale
//
//  Created by ~ ~ on 2/29/24.
//

#ifndef FxGripPreset_h
#define FxGripPreset_h

#import <FxPlug/FxPlugSDK.h>
#import "FxGripTypes.h"

@class DirectoryWatcher;

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

/*!
	@interface  FxGripDynamicParameterAPI_v4:
	@abstract   Initializes the API manager for your plug-in.
	@discussion Accesses the apis with error checking.

 */

@interface FxGripPreset : NSObject

	@property (assign) FxParameterId createdByParameterId;

	@property (assign) NSDictionary *parameterValues; // key=paramId, value= [int, float, string, bool, dict]
	@property (assign) NSDictionary *parameterMeta;
	@property (assign) NSDictionary *parameterTags;

	@property (assign) NSString *framework; // Guru, FxFactory, Apple, etc
	@property (assign) NSString *uuid; //preset uuid
	@property (assign) NSString *name; //display name
	@property (assign) NSString *tag;
	@property (assign) NSString *createdTime;

	@property (assign) NSString *pluginAuthor;
	@property (assign) NSString *pluginLocalizedName;
	@property (assign) NSString *pluginUuid;
	@property (assign) NSString *pluginVersion;
	@property (assign) NSString *productId;

- (BOOL)savePresetToURL:(NSURL*)url;
+ (FxGripPreset*)loadPresetFromURL:(NSURL*)url;

+ (BOOL)setParameterValue:(id)value toParameter:(FxParameterId)parameterID atTime:(CMTime)time withAPI:(id<FxParameterSettingAPI_v5>)setterAPI;

@end


#endif /* FxGripPreset_h */

