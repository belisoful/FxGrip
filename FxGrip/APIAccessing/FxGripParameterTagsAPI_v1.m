//
//  MasterFXAPIManager.m
//  XPC Service
//
//  Created by ~ ~ on 2/29/24.
//

#import "FxGripParameterTagsAPI_v1.h"
#import "FxGripTileableEffect.h"
#import "FxGripMeta.h"
#import "FxGripErrors.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "FxGripAPIAccessing.h"
#import "FxGripPreset.h"
#import "FxGripPresetsAPI_v1.h"
#import "FxGripParameterData.h"
#import "FxGripParameterFlags.h"

@implementation FxGripParameterTagsAPI_v1

#define hasMeta(returnValue) { if (!self.hostHasMeta) return (returnValue); }
#define noMetaError(parameterID) ([NSError errorWithDomain:FxGripPlugErrorDomain \
	code:kFxError_ThirdPartyDeveloperStart + (parameterID) \
	userInfo:@{ NSLocalizedDescriptionKey : [NSString stringWithFormat:@"No meta manager for parameter (%u).", (parameterID)] }])

//---------------------------------------------------------
// initWithAPIManager:
//
// This method is called when a plug-in is first loaded, and
// is a good point to conduct any checks for anti-piracy or
// system compatibility. Returning NULL means that a plug-in
// chooses not to be accessible for some reason.
//---------------------------------------------------------

- (nullable instancetype)initWithAPI:(id<FxGripParameterTagsAPI_v1> _Nullable)api
							  effect:(id<FxGripEffectHost>)effect
{
	self = [super initWithEffect:effect];
	
	if (self != nil)
	{
		_api = api;
	}
	return self;
}

- (NSArray* _Nullable)tags
{
	hasMeta(nil);
	return self.hostMeta.tags;
}

- (SInt32)tagCount
{
	hasMeta(0);
	return [self.hostMeta tagCount];
}

- (SInt32)tagCount:(FxParameterId)parameterID
{
	hasMeta(-1);
	return [self.hostMeta tagCount:parameterID];
}

- (NSArray<NSString*>* _Nullable)parameterTags:(FxParameterId)parameterID
{
	hasMeta(nil);
	return [self.hostMeta parameterTags:parameterID];
}

- (BOOL)parameter:(FxParameterId)parameterID hasTag:(NSString* _Nullable)tag error:(NSError* _Nullable * _Nullable)error
{
	if (!self.hostHasMeta) {
		if (error) {
			*error = noMetaError(parameterID);
		}
		return NO;
	}
	return [self.hostMeta parameter:parameterID hasTag:tag error:error];
}

- (NSError* _Nullable)setTags:(NSArray<NSString*>*_Nonnull)tags toParameter:(FxParameterId)parameterID
{
	hasMeta(noMetaError(parameterID));
	return [self.hostMeta setTags:tags toParameter:parameterID];
}

- (NSError* _Nullable)addTag:(NSString*_Nullable)tag toParameter:(FxParameterId)parameterID
{
	hasMeta(noMetaError(parameterID));
	return [self.hostMeta addTag:tag toParameter:parameterID];
}

- (NSError* _Nullable)removeTag:(NSString*_Nullable)tag fromParameter:(FxParameterId)parameterID
{
	hasMeta(noMetaError(parameterID));
	return [self.hostMeta removeTag:tag fromParameter:parameterID];
}

- (NSError* _Nullable)removeAllTags:(FxParameterId)parameterID
{
	hasMeta(noMetaError(parameterID));
	return [self.hostMeta removeAllTags:parameterID];
}

- (NSArray* _Nullable)parametersWithTag:(NSString*_Nullable)tag
{
	hasMeta(nil);
	return [self.hostMeta parametersWithTag:tag];
}


#pragma mark Presets

- (id _Nullable)presetDefinitionForTag:(NSString *_Nonnull)tag
{
	if (!tag) {
		return nil;
	}
	return FxGripHostPluginProperties(self.effect).pluginPresets[tag];
}

- (id _Nullable)targetPresetForParameter:(FxParameterId)parameterID
								  record:(NSDictionary *_Nullable *_Nullable)record
{
	id<FxGripEffectHost> effect = self.effect;

	// The instance record wins so per-instance customizations override the configuration.
	NSDictionary *source = self.hostHasMeta ? [self.hostMeta parameterData:parameterID] : nil;
	if (!source) {
		source = FxGripHostConfigurationForParameter(effect, parameterID);
	}
	if (!source) {
		return nil;
	}
	if (record) {
		*record = source;
	}

	// Read directly: records carry no "name", so the guarded accessors reject them.
	id definition = source[kFxParameterProperty_TargetPreset];
	if ([definition isKindOfClass:NSString.class]) {
		definition = [self presetDefinitionForTag:definition];
		if (!definition) {
			NSLog(@"%s Error: no preset definition for tag \"%@\" (parameter %u).", __func__,
				  source[kFxParameterProperty_TargetPreset], parameterID);
		}
	}
	return definition;
}


#pragma mark Preset Application

+ (NSError *)errorForParameter:(FxParameterId)parameterID description:(NSString *)description
{
	return [NSError errorWithDomain:FxGripPlugErrorDomain
							   code:kFxError_ThirdPartyDeveloperStart + parameterID
						   userInfo:@{NSLocalizedDescriptionKey:
										  [NSString stringWithFormat:@"%@ (parameter %u).", description, parameterID]}];
}

/*!
	Section dictionaries key by parameter ID. Definitions authored in a plist carry string
	keys; definitions built in code carry numbers. Both resolve.
*/
static NSArray<NSNumber*> *FxGripSectionParameterIDs(NSDictionary *section)
{
	NSMutableArray<NSNumber*> *ids = [NSMutableArray.alloc initWithCapacity:section.count];
	for (id key in section) {
		if ([key isKindOfClass:NSNumber.class]) {
			[ids addObject:key];
		} else if ([key isKindOfClass:NSString.class]) {
			[ids addObject:@(((NSString*)key).intValue)];
		}
	}
	return ids;
}

// Callers resolve the entry through whichever key form the definition used.
static id FxGripSectionEntry(NSDictionary *section, NSNumber *pid)
{
	id entry = section[pid];
	if (!entry) {
		entry = section[pid.stringValue];
	}
	return entry;
}

/*!
	Splits a flag specification into the bits to add and the bits to remove. A bare or
	`+`-prefixed name adds; a `-`-prefixed name removes. Unknown names convert to zero and
	drop out.
*/
static void FxGripParseFlagSpec(id spec, FxParameterFlags *add, FxParameterFlags *remove)
{
	*add = kFxParameterFlag_DEFAULT;
	*remove = kFxParameterFlag_DEFAULT;

	NSArray *names = nil;
	if ([spec isKindOfClass:NSString.class]) {
		names = [(NSString*)spec splitByHumanDividers];
	} else if ([spec isKindOfClass:NSArray.class]) {
		names = spec;
	} else if ([spec isKindOfClass:NSDictionary.class]) {
		names = ((NSDictionary*)spec).allValues;
	} else {
		return;
	}

	*add = names.fxParameterFlags;
	*remove = names.negativeFxParameterFlags;
}

- (NSError *_Nullable)applyPreset:(NSDictionary *_Nonnull)preset
						   atTime:(CMTime)time
						  options:(FxGripPresetOptions)options
					  presetFlags:(FxGripParameterPresetFlags)presetFlags
						   source:(FxGripPresetSource)source
							  tag:(NSString *_Nullable)tag
{
	if (![preset isKindOfClass:NSDictionary.class]) {
		return nil;
	}
	id<FxGripEffectHost> effect = self.effect;
	__block NSError *firstError = nil;

	// The boundary filters only definitions whose ID list may have drifted. Definitions
	// that ship with the plugin name IDs that are current by construction.
	BOOL bounded = (source == FxGripPresetSourceFile)
		&& tag != nil
		&& !(presetFlags & kFxParameterPreset_IgnoreTagBoundary);
	NSSet *boundary = bounded ? [NSSet setWithArray:([self parametersWithTag:tag] ?: @[])] : nil;

	BOOL (^passesBoundary)(NSNumber *) = ^BOOL(NSNumber *pid) {
		return !boundary || [boundary containsObject:pid];
	};
	void (^record)(NSError *) = ^(NSError *error) {
		if (error && !firstError) {
			firstError = error;
		}
	};

	// Values first and names last: the host misreports string parameters when a name
	// changes earlier in the same pass.
	NSDictionary *values = preset[kFxParameterProperty_TargetPresetValues];
	if ((options & FxGripPresetValues) && [values isKindOfClass:NSDictionary.class]) {
		id<FxParameterSettingAPI_v5> setterAPI = effect.apiManager.paramSetAPIv5;
		for (NSNumber *pid in FxGripSectionParameterIDs(values)) {
			if (!passesBoundary(pid)) {
				continue;
			}
			if (![FxGripPreset setParameterValue:FxGripSectionEntry(values, pid)
									 toParameter:pid.unsignedIntValue
										  atTime:time
										 withAPI:setterAPI]) {
				NSLog(@"%s Error: could not set the preset value for parameter %@.", __func__, pid);
				record([self.class errorForParameter:pid.unsignedIntValue
										 description:@"Preset value not set."]);
			}
		}
	}

	NSDictionary *flagSpecs = preset[kFxParameterProperty_TargetPresetFlags];
	if ((options & FxGripPresetFlags) && [flagSpecs isKindOfClass:NSDictionary.class]) {
		id<FxParameterSettingAPI_v6> flagAPI = effect.apiManager.paramSetAPIv6;
		for (NSNumber *pid in FxGripSectionParameterIDs(flagSpecs)) {
			if (!passesBoundary(pid)) {
				continue;
			}
			FxParameterFlags add = 0, remove = 0;
			FxGripParseFlagSpec(FxGripSectionEntry(flagSpecs, pid), &add, &remove);

			FxParameterFlags current = [self.hostParameterData storedFlags:pid.unsignedIntValue];
			FxParameterFlags updated = (current | add) & ~remove;
			if (updated == current) {
				continue;
			}
			if (![flagAPI setParameterFlags:updated toParameter:pid.unsignedIntValue]) {
				NSLog(@"%s Error: could not set the preset flags for parameter %@.", __func__, pid);
				record([self.class errorForParameter:pid.unsignedIntValue
										 description:@"Preset flags not set."]);
			}
		}
	}

	NSDictionary *tagSpecs = preset[kFxParameterProperty_TargetPresetTags];
	if ((options & FxGripPresetTags) && [tagSpecs isKindOfClass:NSDictionary.class]) {
		for (NSNumber *pid in FxGripSectionParameterIDs(tagSpecs)) {
			if (!passesBoundary(pid)) {
				continue;
			}
			if (flagNoTags([self.hostParameterData storedFlags:pid.unsignedIntValue])) {
				continue;
			}
			id spec = FxGripSectionEntry(tagSpecs, pid);
			NSArray *names = [spec isKindOfClass:NSString.class] ? [(NSString*)spec splitByHumanDividers] : spec;
			if (![names isKindOfClass:NSArray.class]) {
				continue;
			}
			for (NSString *name in names) {
				if (![name isKindOfClass:NSString.class] || !name.length) {
					continue;
				}
				if ([name hasPrefix:@"-"]) {
					record([self removeTag:[name substringFromIndex:1] fromParameter:pid.unsignedIntValue]);
				} else {
					NSString *bare = [name hasPrefix:@"+"] ? [name substringFromIndex:1] : name;
					record([self addTag:bare toParameter:pid.unsignedIntValue]);
				}
			}
		}
	}

	NSDictionary *metaSpecs = preset[kFxParameterProperty_TargetPresetMeta];
	if ((options & FxGripPresetMeta) && [metaSpecs isKindOfClass:NSDictionary.class]) {
		for (NSNumber *pid in FxGripSectionParameterIDs(metaSpecs)) {
			if (!passesBoundary(pid)) {
				continue;
			}
			if (flagNoMeta([self.hostParameterData storedFlags:pid.unsignedIntValue])) {
				continue;
			}
			NSDictionary *entries = FxGripSectionEntry(metaSpecs, pid);
			if (![entries isKindOfClass:NSDictionary.class]) {
				continue;
			}
			for (NSString *key in entries) {
				if (![self.hostMeta setMeta:entries[key] forKey:key toParameter:pid.unsignedIntValue]) {
					NSLog(@"%s Error: could not set preset meta \"%@\" on parameter %@.", __func__, key, pid);
					record([self.class errorForParameter:pid.unsignedIntValue
											 description:@"Preset meta not set."]);
				}
			}
		}
	}

	NSDictionary *names = preset[kFxParameterProperty_TargetPresetNames];
	if ((options & FxGripPresetNames) && [names isKindOfClass:NSDictionary.class]) {
		id<FxDynamicParameterAPI_v3> dynamicAPI = effect.apiManager.dynamicParamAPIv3;
		for (NSNumber *pid in FxGripSectionParameterIDs(names)) {
			if (!passesBoundary(pid)) {
				continue;
			}
			NSString *name = FxGripSectionEntry(names, pid);
			if (![name isKindOfClass:NSString.class]) {
				continue;
			}
			record([dynamicAPI setParameter:pid.unsignedIntValue name:name]);
		}
	}

	return firstError;
}

/*!
	Returns the Menu entry name at an index, preferring the live menu recorded by
	FxGripParameterData over the declared configuration, so entries appended at run time
	resolve. Toggle parameters carry no entries and return nil.
*/
- (NSString *_Nullable)menuEntryNameForParameter:(FxParameterId)parameterID
								   configuration:(NSDictionary *_Nullable)configuration
										   index:(int)index
{
	if (index < 0) {
		return nil;
	}
	id<FxGripEffectHost> effect = self.effect;
	NSArray *entries = [self.hostParameterData storedMenus:parameterID];
	if (![entries isKindOfClass:NSArray.class]) {
		entries = configuration[kFxParameterProperty_MenuItems];
	}
	if (![entries isKindOfClass:NSArray.class] || (NSUInteger)index >= entries.count) {
		return nil;
	}
	NSString *name = entries[index];
	return [name isKindOfClass:NSString.class] ? name : nil;
}

- (BOOL)applyTargetPresetForParameter:(FxParameterId)parameterID
							   atTime:(CMTime)time
							  options:(FxGripPresetOptions)options
{
	NSDictionary *record = nil;
	id definition = [self targetPresetForParameter:parameterID record:&record];
	if (!record) {
		return NO;
	}

	id<FxGripEffectHost> effect = self.effect;
	NSDictionary *configuration = FxGripHostConfigurationForParameter(effect, parameterID);
	FxParameterType type = configuration.parameterType;
	if (type != FxParameterType_Menu && type != FxParameterType_Toggle) {
		return YES;
	}

	// The parameter's current value indexes the definition.
	id<FxParameterRetrievalAPI_v6> getterAPI = effect.apiManager.paramGetAPIv6;
	int index = 0;
	if (type == FxParameterType_Menu) {
		if (![getterAPI getIntValue:&index fromParameter:parameterID atTime:time]) {
			return NO;
		}
	} else {
		BOOL flag = NO;
		if (![getterAPI getBoolValue:&flag fromParameter:parameterID atTime:time]) {
			return NO;
		}
		index = flag ? 1 : 0;
	}

	if (!definition) {
		return YES;
	}

	id preset = nil;

	// Name first: a definition keyed by menu entry name survives entries being appended,
	// removed, or reordered, because the reference does not depend on position.
	NSString *entryName = [self menuEntryNameForParameter:parameterID
											configuration:configuration
													index:index];
	if (entryName && [definition isKindOfClass:NSDictionary.class]) {
		preset = ((NSDictionary*)definition)[entryName];
	}

	if (!preset) {
		if ([definition isKindOfClass:NSArray.class]) {
			// Bounds-checked: a raw subscript raises NSRangeException for a menu value
			// that outruns the definition.
			NSArray *entries = definition;
			if (index >= 0 && (NSUInteger)index < entries.count) {
				preset = entries[index];
			}
		} else if ([definition isKindOfClass:NSDictionary.class]) {
			NSDictionary *entries = definition;
			preset = entries[@(index)];
			if (!preset) {
				preset = entries[[NSString stringWithFormat:@"%d", index]];
			}
			if (!preset) {
				preset = entries[kFxParameterProperty_Default];
			}
		}
	}
	if (![preset isKindOfClass:NSDictionary.class]) {
		return YES;
	}

	// Only a tag-resolved definition carries a boundary tag; inline definitions have none.
	id declared = record[kFxParameterProperty_TargetPreset];
	NSString *resolvedTag = [declared isKindOfClass:NSString.class] ? declared : nil;

	return [self applyPreset:preset
					  atTime:time
					 options:options
				 presetFlags:kFxParameterPreset_Default
					  source:FxGripPresetSourcePlugin
						 tag:resolvedTag] == nil;
}

- (NSError *_Nullable)getMetaKeys:(NSArray<NSString*> *_Nullable *_Nonnull)keys
						forPreset:(NSString *_Nonnull)tag
					fromParameter:(FxParameterId)parameterID
{
	if (!keys) {
		return [self.class errorForParameter:parameterID description:@"No keys out-parameter supplied."];
	}
	id definition = [self presetDefinitionForTag:tag];
	if (![definition isKindOfClass:NSDictionary.class]) {
		return [self.class errorForParameter:parameterID
								 description:[NSString stringWithFormat:@"No preset definition for tag \"%@\".", tag]];
	}
	NSDictionary *metaSpecs = ((NSDictionary*)definition)[kFxParameterProperty_TargetPresetMeta];
	if (![metaSpecs isKindOfClass:NSDictionary.class]) {
		*keys = @[];
		return nil;
	}
	NSDictionary *entries = FxGripSectionEntry(metaSpecs, @(parameterID));
	*keys = [entries isKindOfClass:NSDictionary.class] ? entries.allKeys : @[];
	return nil;
}


@end
