/*!
	@file       FxGripParameterTagsAPI_v1.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripParameterTagsAPI_v1
	@abstract   The parameter tag storage and tag-addressed preset resolution API.
	@discussion Introduced in FxGrip 0.1.0. The API stores tags on parameters, queries parameters
	            by tag, resolves tags to preset definitions from the plugin plist, and applies
	            preset definitions to the effect's parameters. FxGrip owns this API; no host vends
	            it. Preset application from every entry point funnels into
	            applyPreset:atTime:options:presetFlags:source:tag:, which owns the section
	            ordering and the tag boundary.
*/

#ifndef FxGripParameterTagsAPI_v1_h
#define FxGripParameterTagsAPI_v1_h

#import <FxPlug/FxPlugSDK.h>
#import <FxGrip/FxGripTypes.h>
#import "FxGripCommonAPI.h"

/*!
	@protocol   FxGripParameterTagsAPI_v1
	@abstract   Parameter tag storage and tag-addressed preset resolution.
	@discussion Introduced in FxGrip 0.1.0. FxGrip's own API; no host vends it.
				FxGripParameterTagsAPI_v1 (the class) is the implementation.
*/
@protocol FxGripParameterTagsAPI_v1 <NSObject>

// Parameter Tags

/*! Every tag in use across the effect's parameters. */
- (NSArray* _Nullable)tags;
/*! The count of distinct tags in use across the effect. */
- (SInt32)tagCount;
/*! The count of tags on one parameter, or -1 when no meta manager is present. */
- (SInt32)tagCount:(FxParameterId)parameterID;

/*! The tags on one parameter. */
- (NSArray* _Nullable)parameterTags:(FxParameterId)parameterID;

/*! Answers whether a parameter carries a tag; sets `error` when no meta manager is present. */
- (BOOL)parameter:(FxParameterId)parameterID hasTag:(NSString* _Nullable)tag error:(NSError* _Nullable * _Nullable)error;
/*! Replaces a parameter's tags with `tags`. */
- (NSError* _Nullable)setTags:(NSArray*_Nonnull)tags toParameter:(FxParameterId)parameterID;
/*! Adds one tag to a parameter. */
- (NSError* _Nullable)addTag:(NSString*_Nullable)tag toParameter:(FxParameterId)parameterID;
/*! Removes one tag from a parameter. */
- (NSError* _Nullable)removeTag:(NSString*_Nullable)tag fromParameter:(FxParameterId)parameterID;
/*! Removes every tag from a parameter. */
- (NSError* _Nullable)removeAllTags:(FxParameterId)parameterID;
/*! The parameters that carry a tag. */
- (NSArray* _Nullable)parametersWithTag:(NSString*_Nullable)tag;


#pragma mark Presets

/*!
	@method     presetDefinitionForTag:
	@abstract   Resolves a tag to a preset definition.
	@discussion Introduced in FxGrip 0.1.0. Reads the plugin's plist `presets` table.
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
	@class		FxGripParameterTagsAPI_v1
	@abstract	FxGrip's implementation of the tag storage and preset resolution API.
	@discussion	Introduced in FxGrip 0.1.0. Tag storage forwards to the effect's meta manager and
				returns a no-meta error when the host carries none. Preset resolution reads the
				plugin plist, and preset application funnels through the tag API core so the tag
				boundary and section ordering hold for every caller.
*/
@interface FxGripParameterTagsAPI_v1 : FxGripCommonAPI<FxGripParameterTagsAPI_v1>

	/*! The wrapped host tags API, nil because no host vends one. */
	@property (assign, readonly) id<FxGripParameterTagsAPI_v1> _Nonnull api;

/*!
	@method		initWithAPI:effect:
	@abstract	Initializes the tags API wrapper.
	@param		api	The wrapped host tags API, or nil.
	@param		effect	The effect host whose meta manager stores the tags.
*/
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
