//
//  FxGripParameterConverter.m
//  XPC Service
//
//  Created by ~ ~ on 2/29/24.
//

#import "FxGripParameterUtility.h"
#import "FxGripPluginInfo.h"
#import "NSDictionary+FxTileableEffect.h"
#import <BEFoundation/NSArray+BExtension.h>

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
			
		//kParameterFlagString_PRESETNOMETA: @(kFxParameterFlag_PRESETNOMETA),
		//kParameterFlagString_PRESETNOTAGS: @(kFxParameterFlag_PRESETNOTAGS),
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


@end
