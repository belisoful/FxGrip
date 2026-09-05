//
//  FxGripParameterTagsAPI_v1.h
//  MetalFx ML Upscale
//
//  Created by ~ ~ on 2/29/24.
//

#ifndef FxGripParameterTagsAPI_v1_h
#define FxGripParameterTagsAPI_v1_h

#import <FxPlug/FxPlugSDK.h>
#import <FxGrip/FxGripTypes.h>
#import "FxGripCommonAPI.h"

/*!
	@protocol   FxGripParameterTagsAPI_v1
	@abstract   Parameter tag storage and tag-addressed preset resolution.
	@discussion Introduced in FxGrip 1.0. FxGrip's own API; no host vends it.
				FxGripParameterTagsAPI_v1 (the class) is the implementation.
*/
@protocol FxGripParameterTagsAPI_v1 <NSObject>

// Parameter Tags

- (NSArray* _Nullable)tags;
- (SInt32)tagCount;
- (SInt32)tagCount:(FxParameterId)parameterID;

- (NSArray* _Nullable)parameterTags:(FxParameterId)parameterID;

- (BOOL)parameter:(FxParameterId)parameterID hasTag:(NSString* _Nullable)tag error:(NSError* _Nullable * _Nullable)error;
- (NSError* _Nullable)setTags:(NSArray*_Nonnull)tags toParameter:(FxParameterId)parameterID;
- (NSError* _Nullable)addTag:(NSString*_Nullable)tag toParameter:(FxParameterId)parameterID;
- (NSError* _Nullable)removeTag:(NSString*_Nullable)tag fromParameter:(FxParameterId)parameterID;
- (NSError* _Nullable)removeAllTags:(FxParameterId)parameterID;
- (NSArray* _Nullable)parametersWithTag:(NSString*_Nullable)tag;


#pragma mark Presets

/*!
	@method     presetDefinitionForTag:
	@abstract   Resolves a tag to a preset definition.
	@discussion Introduced in FxGrip 1.0. Reads the plugin's plist `presets` table.
				Automatic rigging resolves from the plugin and the instance record only,
				so a saved preset file never alters a plugin's rigging; browsing and
				user-initiated apply use the merged listing in FxGripPresetsAPI_v1.
*/
- (id _Nullable)presetDefinitionForTag:(NSString *_Nonnull)tag;

/*!
	@method     targetPresetForParameter:record:
	@abstract   Resolves the target-preset definition driving one parameter.
	@discussion Reads the instance meta record first and falls back to the parameter's
				configuration, so per-instance customizations win. A string definition
				resolves through presetDefinitionForTag:.
	@param      parameterID  The parameter whose target-preset definition to resolve.
	@param      record  On return, the record the definition came from.
*/
- (id _Nullable)targetPresetForParameter:(FxParameterId)parameterID
								  record:(NSDictionary *_Nullable *_Nullable)record;

/*!
	@method     applyPreset:atTime:options:presetFlags:source:tag:
	@abstract   Applies a preset definition to the effect's parameters.
	@discussion Sections apply in a fixed order: values, flags, tags, meta, names. Names
				run last because the host misreports string parameters when a name
				changes earlier in the same pass. Each section runs only when its option
				bit is set and the section is present.

				The tag boundary follows `source`:
				- FxGripPresetSourcePlugin → every section applies to the IDs the
				  definition names.
				- FxGripPresetSourceFile → every section applies to an ID only when
				  `parametersWithTag:` contains it, unless `presetFlags` carries
				  `kFxParameterPreset_IgnoreTagBoundary`.

				Parameters flagged PRESETNOTAGS or PRESETNOMETA opt out of the tags and
				meta sections. A per-entry failure logs and continues.
	@result     The first error encountered, or nil when every entry succeeds.
*/
- (NSError *_Nullable)applyPreset:(NSDictionary *_Nonnull)preset
						   atTime:(CMTime)time
						  options:(FxGripPresetOptions)options
					  presetFlags:(FxGripParameterPresetFlags)presetFlags
						   source:(FxGripPresetSource)source
							  tag:(NSString *_Nullable)tag;

/*!
	@method     getMetaKeys:forPreset:fromParameter:
	@abstract   Returns the meta keys a tag-addressed definition carries for one parameter.
*/
- (NSError *_Nullable)getMetaKeys:(NSArray<NSString*> *_Nullable *_Nonnull)keys
						forPreset:(NSString *_Nonnull)tag
					fromParameter:(FxParameterId)parameterID;

/*!
	@method     applyTargetPresetForParameter:atTime:options:
	@abstract   Applies the preset a Menu or Toggle parameter selects.
	@discussion The parameter's current value indexes its target-preset definition.
				Non-Menu and non-Toggle parameters return YES without acting.
*/
- (BOOL)applyTargetPresetForParameter:(FxParameterId)parameterID
							   atTime:(CMTime)time
							  options:(FxGripPresetOptions)options;

@end


/*!
	@interface  FxGripParameterTagsAPI_v1
	@abstract   Allows your plugin to create parameters on-the-fly
	@discussion With this API your plugin can create and remove parameters outside of its
				-addParameters method. It can also get and set various properties of parameters
				during run-time, as well, such as the minimum and maximum allowable values.
				NOTE: You should only implement this protocol in plug-ins that use FxPlug 4
				or later. It will not be called in plug-ins that are written with FxPlug 2 or 3.
*/
@interface FxGripParameterTagsAPI_v1 : FxGripCommonAPI<FxGripParameterTagsAPI_v1>

	@property (assign, readonly) id<FxGripParameterTagsAPI_v1> _Nonnull api;

- (nullable instancetype)initWithAPI:(id<FxGripParameterTagsAPI_v1> _Nullable)api effect:(nonnull id<FxGripEffectHost>)effect;

// Parameter Tags

- (NSArray* _Nullable)tags;
- (SInt32)tagCount;
- (SInt32)tagCount:(FxParameterId)parameterID;

- (NSArray<NSString*>* _Nullable)parameterTags:(FxParameterId)parameterID;

- (BOOL)parameter:(FxParameterId)parameterID hasTag:(NSString* _Nullable)tag error:(NSError* _Nullable * _Nullable)error;
- (NSError* _Nullable)setTags:(NSArray*_Nonnull)tags toParameter:(FxParameterId)parameterID;
- (NSError* _Nullable)addTag:(NSString*_Nullable)label toParameter:(FxParameterId)parameterID;
- (NSError* _Nullable)removeTag:(NSString*_Nullable)label fromParameter:(FxParameterId)parameterID;
- (NSError* _Nullable)removeAllTags:(FxParameterId)parameterID;
- (NSArray* _Nullable)parametersWithTag:(NSString*_Nullable)label;

@end


#endif /* FxGripParameterTagsAPI_v1_h */
