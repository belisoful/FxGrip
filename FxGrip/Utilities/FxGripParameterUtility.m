//
//  FxGripParameterUtility.m
//  XPC Service
//
//  Created by ~ ~ on 2/29/24.
//

#import "FxGripParameterUtility.h"
#import "FxGripPluginInfo.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import <BEFoundation/NSArray+BExtension.h>
#import <BEFoundation/NSDictionary+BExtension.h>
#import <BEFoundation/BEMutable.h>

@implementation FxGripParameterUtility


+ (NSDictionary<NSString*, NSNumber*>*_Nonnull)parameterTypes
{
	static NSDictionary<NSString*, NSNumber*> *typeMap = @{
		kFxParameterType_Angle: @(FxParameterType_Angle),
		kFxParameterType_RGBA: @(FxParameterType_RGBA),
		kFxParameterType_RGB: @(FxParameterType_RGB),
		kFxParameterType_Custom: @(FxParameterType_Custom),
		kFxParameterType_Float: @(FxParameterType_Float),
		kFxParameterType_FontMenu: @(FxParameterType_FontMenu),
		kFxParameterType_Gradient: @(FxParameterType_Gradient),
		kFxParameterType_Help: @(FxParameterType_Help),
		kFxParameterType_Histogram: @(FxParameterType_Histogram),
		kFxParameterType_Integer: @(FxParameterType_Int),
		kFxParameterType_ImageRef: @(FxParameterType_ImageRef),
		kFxParameterType_PathID: @(FxParameterType_PathID),
		kFxParameterType_Percent: @(FxParameterType_Percent),
		kFxParameterType_Point: @(FxParameterType_Point),
		kFxParameterType_Menu: @(FxParameterType_Menu),
		kFxParameterType_PushButton: @(FxParameterType_PushButton),
		kFxParameterType_String: @(FxParameterType_String),
		kFxParameterType_Toggle: @(FxParameterType_Toggle),
		kFxParameterType_Group: @(FxParameterType_Group),
		
		//Custom Types
		kFxParameterType_Section: @(FxParameterType_Section),
		kFxParameterType_Random: @(FxParameterType_Random),
		kFxParameterType_Capsule: @(FxParameterType_Capsule),
		kFxParameterType_Banner: @(FxParameterType_Banner),
		kFxParameterType_Presets: @(FxParameterType_Presets),
		kFxParameterType_Status: @(FxParameterType_Status),
		kFxParameterType_Progress: @(FxParameterType_Progress),
		kFxParameterType_Switch: @(FxParameterType_Switch),
		kFxParameterType_Divider: @(FxParameterType_Divider),
		kFxParameterType_WebView: @(FxParameterType_WebView),
		kFxParameterType_VideoView: @(FxParameterType_VideoView),
		kFxParameterType_LiveImage: @(FxParameterType_LiveImage),

	};
	return typeMap;
}
+ (const NSDictionary<NSNumber*, NSString*>*)typeParameters
{
	static NSDictionary* parameterTypes = nil;
	if(parameterTypes == nil){
		parameterTypes = self.parameterTypes;
		parameterTypes = [NSDictionary dictionaryWithObjects:[parameterTypes allKeys] forKeys:[parameterTypes allValues]];
	}
	return parameterTypes;
}


+ (FxParameterType)parameterTypeFromString:(NSString* _Nullable)type
{
	if (type != nil) {
		NSNumber *result = self.parameterTypes[type.lowercaseString];
		if (result != nil) {
			return result.intValue;
		}
		if (type.length == 4) {
			return (FxParameterType)CFSwapInt32BigToHost(*(UInt32 *)[type cStringUsingEncoding:NSASCIIStringEncoding]);
		}
	}
	return FxParameterType_None;
}


+ (NSString* _Nullable)parameterTypeString:(FxParameterType)type
{
	return self.typeParameters[@(type)];
}





+ (NSDictionary<NSString*, NSNumber*>*)flagValues
{
	static NSDictionary *flagValues = @{
		kParameterFlagString_NOT_ANIMATABLE:@(kFxParameterFlag_NOT_ANIMATABLE),
		kParameterFlagString_HIDDEN: @(kFxParameterFlag_HIDDEN),
		kParameterFlagString_DISABLED: @(kFxParameterFlag_DISABLED),
		kParameterFlagString_COLLAPSED: @(kFxParameterFlag_COLLAPSED),
		kParameterFlagString_DONT_SAVE: @(kFxParameterFlag_DONT_SAVE),
		kParameterFlagString_DONT_DISPLAY: @(kFxParameterFlag_DONT_DISPLAY_IN_DASHBOARD),
		kParameterFlagString_CUSTOM_UI: @(kFxParameterFlag_CUSTOM_UI),
		kParameterFlagString_IGNORE_MIN_MAX: @(kFxParameterFlag_IGNORE_MINMAX),
		kParameterFlagString_CURVE_EDITOR_HIDDEN: @(kFxParameterFlag_CURVE_EDITOR_HIDDEN),
		kParameterFlagString_DONT_REMAP_COLORS: @(kFxParameterFlag_DONT_REMAP_COLORS),
		kParameterFlagString_FULL_VIEW_WIDTH: @(kFxParameterFlag_USE_FULL_VIEW_WIDTH),
			
		kParameterFlagString_PRESETNOMETA: @(kFxParameterFlag_PRESETNOMETA),
		kParameterFlagString_PRESETNOTAGS: @(kFxParameterFlag_PRESETNOTAGS),
		kParameterFlagString_PRESETNOVALUE: @(kFxParameterFlag_PRESETNOVALUE),
		kParameterFlagString_NO_STATE: @(kFxParameterFlag_NOSTATE),
			
		kParameterFlagString_NO_DEBUG: @(kFxParameterFlag_NO_DEBUG),
		kParameterFlagString_IN_DEBUG_MODE: @(kFxParameterFlag_IN_DEBUG_MODE),
		kParameterFlagString_HIDDEN_PROXY: @(kFxParameterFlag_HIDDEN_PROXY),
		};
	return flagValues;
}

+ (NSDictionary<NSNumber*, NSString*>*)valueFlags
{
	static NSDictionary* valueFlags = 0;
	if(valueFlags == 0){
		valueFlags = self.flagValues;
		valueFlags = [NSDictionary dictionaryWithObjects:[valueFlags allKeys] forKeys:[valueFlags allValues]];
	}
	return valueFlags;
}

+ (NSString* _Nullable) convertToFlag:(FxParameterFlags)flag
{
	//__builtin_popcountl for long
	int count = __builtin_popcount(flag);
	if (count == 1) {
		return self.valueFlags[@(flag)];
	} else if (count) {
		return nil;
	}
	return nil;
}
+ (NSArray<NSString*>*) convertToFlags:(FxParameterFlags)flag
{
	//__builtin_popcountl for long
	int count = __builtin_popcount(flag);
	NSMutableArray *arr = [NSMutableArray.alloc initWithCapacity:count];
	while (flag != 0) {
		FxParameterFlags f = flag;
		flag &= (flag - 1);
		f ^= flag;
		[arr addObject:[self convertToFlag:f]];
	}
	return [arr copy];
}

+ (FxParameterFlags) convertFlag:(nullable NSString*)flag
{
	NSDictionary *flagValues = self.flagValues;
	if (flag != nil) {
		NSNumber *intFlag = [flagValues objectForKey:flag];
		if (intFlag != nil) {
			return [intFlag unsignedIntValue];
		}
	}
	return kFxParameterFlag_DEFAULT;
}

+ (FxParameterFlags)convertFlags:(nullable id)flags
{
	FxParameterFlags result = kFxParameterFlag_DEFAULT;
	
	if (flags) {
		if ([flags isKindOfClass:[NSString class]]) {
			flags = [flags componentsSeparatedByCharactersInSet:[FxGripPluginInfo separatorSet]];
		} else if ([flags isKindOfClass:[NSDictionary class]]) {
			flags = ((NSDictionary*)flags).allValues;
		}
		if ([flags isKindOfClass:[NSArray class]]) {
			for(NSString *flag in flags) {
				result |= [self convertFlag:flag];
			}
		}
	}
	return result;
}


+ (void)flattenDictionaryParameters:(nullable NSMutableArray<NSMutableDictionary*> *)parameters
{
	if (!parameters) {
		return;
	}
	//NSMutableArray<NSMutableDictionary*> *flat = [parameters mutableCopyRecursive];
	
	//convert parameters to NSMutableDictionaries
	// flatten group parameters, recurse until all nested are flattened.
	for(int i = 0; i < parameters.count; i++) {
		NSMutableDictionary *param = parameters[i];
		
		if (param.parameterType == FxParameterType_Group) {
			// Groups unfold their inner parameters setting their parentId
			if (param[kFxParameterProperty_GroupParameters]) {
				id _group = param[kFxParameterProperty_GroupParameters];
				if ([_group isKindOfClass:NSDictionary.class]) {
					_group = ((NSDictionary*)_group).allValues;
				} else if (![_group isKindOfClass:NSArray.class]) {
					continue;
				}
				
				[param removeObjectForKey:kFxParameterProperty_GroupParameters];
				
				int j = 1;
				for(NSMutableDictionary *groupParam in (NSArray*)_group) {
					if (!groupParam[kFxParameterProperty_ParentId])
						groupParam[kFxParameterProperty_ParentId] = @(param.parameterID);
					// Added at the next i so they also get processed.
					[parameters insertObject:groupParam atIndex:i + j];
					j++;
				}
			}
		}
	}
}


#pragma mark Target Preset Defaults

// Configurations carry the type as a name or a number.
static FxParameterType FxGripConfigParameterType(NSDictionary *config)
{
	id value = config[kFxParameterProperty_Type];
	if ([value isKindOfClass:NSNumber.class]) {
		return ((NSNumber*)value).intValue;
	}
	if ([value isKindOfClass:NSString.class]) {
		return [FxGripParameterUtility parameterTypeFromString:value];
	}
	return FxParameterType_None;
}

// Section dictionaries key by parameter ID as either a string or a number.
static id FxGripPresetSectionEntry(NSDictionary *section, NSNumber *pid)
{
	id entry = section[pid];
	if (!entry) {
		entry = section[pid.stringValue];
	}
	return entry;
}

static NSArray<NSNumber*> *FxGripPresetSectionIDs(NSDictionary *section)
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

/*!
	Applies `+`/`-` entries to a configuration's string array. Creation time works on the
	declared names rather than flag bits, so the configuration stays readable.
*/
static void FxGripApplyStringSpec(NSMutableDictionary *config, NSString *key, id spec)
{
	NSArray *entries = nil;
	if ([spec isKindOfClass:NSString.class]) {
		entries = [(NSString*)spec splitByHumanDividers];
	} else if ([spec isKindOfClass:NSArray.class]) {
		entries = spec;
	} else {
		return;
	}

	id existing = config[key];
	NSMutableArray<NSString*> *names = nil;
	if ([existing isKindOfClass:NSArray.class]) {
		names = [existing mutableCopy];
	} else if ([existing isKindOfClass:NSString.class]) {
		names = [[(NSString*)existing splitByHumanDividers] mutableCopy];
	} else {
		names = NSMutableArray.new;
	}

	for (NSString *entry in entries) {
		if (![entry isKindOfClass:NSString.class] || !entry.length) {
			continue;
		}
		BOOL remove = [entry hasPrefix:@"-"];
		NSString *bare = (remove || [entry hasPrefix:@"+"]) ? [entry substringFromIndex:1] : entry;
		if (!bare.length) {
			continue;
		}
		[names removeObject:bare];
		if (!remove) {
			[names addObject:bare];
		}
	}
	config[key] = names;
}

/*!
	Writes one preset value into a target configuration's default, dispatching on the
	target's own type.
*/
static void FxGripApplyDefaultValue(NSMutableDictionary *target, id value)
{
	NSDictionary *components = [value isKindOfClass:NSDictionary.class] ? value : nil;

	switch (FxGripConfigParameterType(target)) {
		case FxParameterType_RGBA:
			if (components[kFxParameterProperty_Alpha]) {
				target[kFxParameterProperty_Alpha] = components[kFxParameterProperty_Alpha];
			}
			// falls through to the color channels
		case FxParameterType_RGB:
			if (!components) {
				return;
			}
			for (NSString *channel in @[kFxParameterProperty_Red, kFxParameterProperty_Green, kFxParameterProperty_Blue]) {
				if (components[channel]) {
					target[channel] = components[channel];
				}
			}
			return;
		case FxParameterType_Point:
			if (!components) {
				return;
			}
			for (NSString *axis in @[kFxParameterProperty_X, kFxParameterProperty_Y]) {
				if (components[axis]) {
					target[axis] = components[axis];
				}
			}
			return;
		case FxParameterType_Custom: {
			id existing = target[kFxParameterProperty_Default];
			if (components && [existing isKindOfClass:NSDictionary.class]) {
				NSMutableDictionary *merged = [(NSDictionary*)existing mutableCopyRecursive];
				// The preset wins over the declared default, as at runtime.
				[merged addEntriesFromDictionaryRecursive:components];
				target[kFxParameterProperty_Default] = merged;
				return;
			}
			target[kFxParameterProperty_Default] = value;
			return;
		}
		default:
			target[kFxParameterProperty_Default] = value;
			return;
	}
}

+ (void)applyTargetPresetDefaults:(nullable NSMutableArray<NSMutableDictionary*> *)parameters
					pluginPresets:(nullable NSDictionary *)pluginPresets
{
	if (!parameters.count) {
		return;
	}

	NSMutableDictionary<NSNumber*, NSMutableDictionary*> *dispatch =
		[NSMutableDictionary.alloc initWithCapacity:parameters.count];
	for (NSMutableDictionary *config in parameters) {
		if (![config isKindOfClass:NSMutableDictionary.class]) {
			continue;
		}
		NSNumber *pid = config[kFxParameterProperty_Id];
		if ([pid isKindOfClass:NSNumber.class]) {
			dispatch[pid] = config;
		} else if ([pid isKindOfClass:NSString.class]) {
			dispatch[@(((NSString*)pid).intValue)] = config;
		}
	}

	for (NSMutableDictionary *config in parameters) {
		if (![config isKindOfClass:NSMutableDictionary.class]) {
			continue;
		}
		FxParameterType type = FxGripConfigParameterType(config);
		if (type != FxParameterType_Menu && type != FxParameterType_Toggle) {
			continue;
		}

		id definition = config[kFxParameterProperty_TargetPreset];
		if ([definition isKindOfClass:NSString.class]) {
			definition = pluginPresets[definition];
		}
		if (!definition) {
			continue;
		}

		// The declared default selects the entry. This path has no "default" fallback.
		int index = ((NSNumber*)config[kFxParameterProperty_Default]).intValue;
		id preset = nil;
		if ([definition isKindOfClass:NSArray.class]) {
			NSArray *entries = definition;
			if (index >= 0 && (NSUInteger)index < entries.count) {
				preset = entries[index];
			}
		} else if ([definition isKindOfClass:NSDictionary.class]) {
			preset = FxGripPresetSectionEntry(definition, @(index));
		}
		if (![preset isKindOfClass:NSDictionary.class]) {
			continue;
		}

		[self applyPresetDefaults:preset toDispatch:dispatch];
	}
}

// Callers hold the flattened dispatch table.
+ (void)applyPresetDefaults:(NSDictionary *)preset toDispatch:(NSDictionary<NSNumber*, NSMutableDictionary*> *)dispatch
{
	NSDictionary *sections = @{
		kFxParameterProperty_TargetPresetNames: kFxParameterProperty_Name,
		kFxParameterProperty_TargetPresetFlags: kFxParameterProperty_Flags,
		kFxParameterProperty_TargetPresetTags: kFxParameterProperty_Tags
	};

	for (NSString *sectionKey in sections) {
		NSDictionary *section = preset[sectionKey];
		if (![section isKindOfClass:NSDictionary.class]) {
			continue;
		}
		NSString *configKey = sections[sectionKey];
		for (NSNumber *pid in FxGripPresetSectionIDs(section)) {
			NSMutableDictionary *target = dispatch[pid];
			if (!target) {
				NSLog(@"%s Error: target preset names parameter %@, which does not exist.", __func__, pid);
				continue;
			}
			id entry = FxGripPresetSectionEntry(section, pid);
			if ([configKey isEqualToString:kFxParameterProperty_Name]) {
				if ([entry isKindOfClass:NSString.class]) {
					target[kFxParameterProperty_Name] = entry;
				}
			} else {
				FxGripApplyStringSpec(target, configKey, entry);
			}
		}
	}

	NSDictionary *values = preset[kFxParameterProperty_TargetPresetValues];
	if ([values isKindOfClass:NSDictionary.class]) {
		for (NSNumber *pid in FxGripPresetSectionIDs(values)) {
			NSMutableDictionary *target = dispatch[pid];
			if (!target) {
				NSLog(@"%s Error: target preset names parameter %@, which does not exist.", __func__, pid);
				continue;
			}
			FxGripApplyDefaultValue(target, FxGripPresetSectionEntry(values, pid));
		}
	}
}


#pragma mark Click Selectors

+ (nonnull NSString *)clickSelectorNameForParameter:(FxParameterId)parameterID
{
	return [NSString stringWithFormat:@"%@%u", kFxGripClickSelectorPrefix, parameterID];
}

+ (BOOL)getParameterID:(nonnull FxParameterId *)parameterID fromClickSelector:(nullable SEL)selector
{
	if (!selector || !parameterID) {
		return NO;
	}
	NSString *name = NSStringFromSelector(selector);
	if (![name hasPrefix:kFxGripClickSelectorPrefix] || name.length == kFxGripClickSelectorPrefix.length) {
		return NO;
	}
	NSString *digits = [name substringFromIndex:kFxGripClickSelectorPrefix.length];
	// Strict form: decimal digits only, within FxParameterId range. Anything else is a
	// plugin's own selector and must not resolve through the trampoline.
	if ([digits rangeOfCharacterFromSet:NSCharacterSet.decimalDigitCharacterSet.invertedSet].location != NSNotFound) {
		return NO;
	}
	unsigned long long value = strtoull(digits.UTF8String, NULL, 10);
	if (value > UINT32_MAX) {
		return NO;
	}
	*parameterID = (FxParameterId)value;
	return YES;
}


@end
