/*!
	@file       FxGripPreset.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripPreset
	@abstract   Implements the preset model, its file form, and typed value conversion.
	@discussion Introduced in FxGrip 0.1.0. A file dictionary is untrusted input, so each field is
	            read only when its value is the expected class. The file form writes the FxFactory
	            keys and the flat FxGripPreset* keys together, with parameter-keyed dictionaries
	            written under string keys. Typed conversion dispatches on the parameter's type,
	            resolved through the setting wrapper, falling back to the encoded value's own
	            shape when no type source is available.
*/

#import "FxGripPreset.h"
#import "FxGripParameterSettingAPI_v5.h"
#import "FxGripParameterInfoAPI_v1.h"
#import <BEFoundation/BEMutable.h>
#import <BEFoundation/NSDictionary+BExtension.h>
#import "FxGrip_ARC.h"


/*! A file dictionary is untrusted input; a value of the wrong class is dropped rather
	than assigned into a typed property. */
static id FxGripPresetValueOfClass(NSDictionary *dictionary, NSString *key, Class valueClass)
{
	id value = dictionary[key];
	return [value isKindOfClass:valueClass] ? value : nil;
}

/*! Parameter-keyed dictionaries are written with string keys, matching FxFactory. */
static NSDictionary *FxGripStringKeyedDictionary(NSDictionary *dictionary)
{
	NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:dictionary.count];
	for (id key in dictionary) {
		id stringKey = [key isKindOfClass:NSString.class] ? key : [key stringValue];
		result[stringKey] = dictionary[key];
	}
	return result;
}


/*!
	@abstract	The preset model with FxFactory-compatible file I/O and typed value conversion.
	@discussion	Introduced in FxGrip 0.1.0. The file form round-trips through
				initWithPresetDictionary: and presetDictionary; savePresetToURL: and
				loadPresetFromURL: add the disk I/O; setParameterValue: and getParameterValue:
				convert between encoded values and live parameters.
*/
@implementation FxGripPreset

- (void)dealloc
{
	NARC_RELEASE(_parameterValues);
	NARC_RELEASE(_parameterMeta);
	NARC_RELEASE(_parameterTags);
	NARC_RELEASE(_framework);
	NARC_RELEASE(_uuid);
	NARC_RELEASE(_name);
	NARC_RELEASE(_tag);
	NARC_RELEASE(_createdTime);
	NARC_RELEASE(_pluginAuthor);
	NARC_RELEASE(_pluginLocalizedName);
	NARC_RELEASE(_pluginUuid);
	NARC_RELEASE(_pluginVersion);
	NARC_RELEASE(_productId);
	SUPER_DEALLOC();
}


#pragma mark File Form

/*! @abstract Builds a preset from a file-form dictionary, reading the FxFactory and FxGripPreset* keys and ignoring unknown keys. */
- (nullable instancetype)initWithPresetDictionary:(nullable NSDictionary*)dictionary
{
	if (![dictionary isKindOfClass:NSDictionary.class]) {
		NARC_RELEASE_RAW(self);
		return nil;
	}
	self = [super init];
	if (self != nil) {
		self.createdByParameterId = ((NSNumber*)FxGripPresetValueOfClass(dictionary, kFxFactoryPresetKey_CreatedByParameterId, NSNumber.class)).unsignedIntValue;
		self.parameterValues = FxGripPresetValueOfClass(dictionary, kFxFactoryPresetKey_ParameterValues, NSDictionary.class);
		self.pluginAuthor = FxGripPresetValueOfClass(dictionary, kFxFactoryPresetKey_PluginAuthor, NSString.class);
		// The localized name is a string or FxFactory's per-language dictionary.
		id localizedName = FxGripPresetValueOfClass(dictionary, kFxFactoryPresetKey_LocalizedName, NSString.class);
		self.pluginLocalizedName = localizedName ?: FxGripPresetValueOfClass(dictionary, kFxFactoryPresetKey_LocalizedName, NSDictionary.class);
		self.pluginUuid = FxGripPresetValueOfClass(dictionary, kFxFactoryPresetKey_PluginUuid, NSString.class);
		self.pluginVersion = FxGripPresetValueOfClass(dictionary, kFxFactoryPresetKey_PluginVersion, NSString.class);
		self.productId = FxGripPresetValueOfClass(dictionary, kFxFactoryPresetKey_ProductId, NSString.class);

		self.framework = FxGripPresetValueOfClass(dictionary, kFxGripPresetKey_Framework, NSString.class);
		self.uuid = FxGripPresetValueOfClass(dictionary, kFxGripPresetKey_Uuid, NSString.class);
		self.name = FxGripPresetValueOfClass(dictionary, kFxGripPresetKey_DisplayName, NSString.class);
		self.tag = FxGripPresetValueOfClass(dictionary, kFxGripPresetKey_Tag, NSString.class);
		self.createdTime = FxGripPresetValueOfClass(dictionary, kFxGripPresetKey_CreatedTime, NSString.class);
		self.parameterMeta = FxGripPresetValueOfClass(dictionary, kFxGripPresetKey_ParameterMeta, NSDictionary.class);
		self.parameterTags = FxGripPresetValueOfClass(dictionary, kFxGripPresetKey_ParameterTags, NSDictionary.class);
	}
	return self;
}

/*! @abstract The file-form dictionary: the FxFactory keys plus the FxGripPreset* keys, with nil fields omitted and parameter-keyed dictionaries written under string keys. */
- (nonnull NSDictionary*)presetDictionary
{
	NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithCapacity:14];

	if (self.createdByParameterId != 0) {
		dictionary[kFxFactoryPresetKey_CreatedByParameterId] = @(self.createdByParameterId);
	}
	if (self.parameterValues != nil) {
		dictionary[kFxFactoryPresetKey_ParameterValues] = FxGripStringKeyedDictionary(self.parameterValues);
	}
	dictionary[kFxFactoryPresetKey_PluginAuthor] = self.pluginAuthor;
	dictionary[kFxFactoryPresetKey_LocalizedName] = self.pluginLocalizedName;
	dictionary[kFxFactoryPresetKey_PluginUuid] = self.pluginUuid;
	dictionary[kFxFactoryPresetKey_PluginVersion] = self.pluginVersion;
	dictionary[kFxFactoryPresetKey_ProductId] = self.productId;

	dictionary[kFxGripPresetKey_Framework] = self.framework;
	dictionary[kFxGripPresetKey_Uuid] = self.uuid;
	dictionary[kFxGripPresetKey_DisplayName] = self.name;
	dictionary[kFxGripPresetKey_Tag] = self.tag;
	dictionary[kFxGripPresetKey_CreatedTime] = self.createdTime;
	if (self.parameterMeta != nil) {
		dictionary[kFxGripPresetKey_ParameterMeta] = FxGripStringKeyedDictionary(self.parameterMeta);
	}
	if (self.parameterTags != nil) {
		dictionary[kFxGripPresetKey_ParameterTags] = FxGripStringKeyedDictionary(self.parameterTags);
	}

	return dictionary;
}

/*! @abstract The values, tags, and meta sections in the shape applyPreset: consumes. */
- (nonnull NSDictionary*)presetSections
{
	NSMutableDictionary *sections = [NSMutableDictionary dictionaryWithCapacity:3];
	sections[kFxParameterProperty_TargetPresetValues] = self.parameterValues;
	sections[kFxParameterProperty_TargetPresetTags] = self.parameterTags;
	sections[kFxParameterProperty_TargetPresetMeta] = self.parameterMeta;
	return sections;
}

/*! @abstract Writes the preset as an XML property list; returns NO when a carried value is not a property-list type or the write fails. */
- (BOOL)savePresetToURL:(nonnull NSURL*)url
{
	if (url == nil) {
		return NO;
	}
	NSError *error = nil;
	NSData *data = [NSPropertyListSerialization dataWithPropertyList:self.presetDictionary
															   format:NSPropertyListXMLFormat_v1_0
															  options:0
																error:&error];
	if (data == nil) {
		NSLog(@"%s Error: the preset does not serialize as a property list: %@", __func__, error);
		return NO;
	}
	return [data writeToURL:url atomically:YES];
}

/*! @abstract Reads a preset from an XML property list written by savePresetToURL: or by FxFactory; returns nil when the file is missing or is not a property-list dictionary. */
+ (nullable FxGripPreset*)loadPresetFromURL:(nonnull NSURL*)url
{
	if (url == nil) {
		return nil;
	}
	NSData *data = [NSData dataWithContentsOfURL:url];
	if (data == nil) {
		return nil;
	}
	id plist = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:NULL];
	if (![plist isKindOfClass:NSDictionary.class]) {
		return nil;
	}
	return NARC_AUTORELEASE([[self alloc] initWithPresetDictionary:plist]);
}


#pragma mark Typed Value Primitives

/*!
	Resolves the parameter's type through the FxGrip setting wrapper, which exposes the
	dynamic API. A raw host API carries no type source, so the caller gets None and the
	primitives fall back to dispatching on the value's own shape.
*/
+ (FxParameterType)parameterTypeFor:(FxParameterId)parameterID withAPI:(id<FxParameterSettingAPI_v5>)setterAPI
{
	if (![setterAPI respondsToSelector:@selector(parameterInfoAPIv1)]) {
		return FxParameterType_None;
	}
	id<FxGripParameterInfoAPI_v1> dynamicAPI = [(id)setterAPI parameterInfoAPIv1];
	if (!dynamicAPI) {
		return FxParameterType_None;
	}
	return [dynamicAPI parameterType:parameterID];
}

/*!
	Infers a type from the encoded value when the dynamic API is unavailable. The on-disk
	encodings are distinct: a color carries the RGB component keys, a point carries x/y,
	any other dictionary is custom data.
*/
+ (FxParameterType)inferredTypeForValue:(id)value
{
	if ([value isKindOfClass:NSString.class]) {
		return FxParameterType_String;
	}
	if ([value isKindOfClass:NSDictionary.class]) {
		NSDictionary *dict = value;
		if (dict[kFxParameterProperty_Red] || dict[kFxParameterProperty_Green] || dict[kFxParameterProperty_Blue]) {
			return dict[kFxParameterProperty_Alpha] ? FxParameterType_RGBA : FxParameterType_RGB;
		}
		if (dict[kFxParameterProperty_X] || dict[kFxParameterProperty_Y]) {
			return FxParameterType_Point;
		}
		return FxParameterType_Custom;
	}
	if ([value isKindOfClass:NSNumber.class]) {
		return FxParameterType_Float;
	}
	return FxParameterType_None;
}

/*!
	@method		getParameterValue:toParameter:atTime:withAPI:
	@abstract	Reads a parameter into the encoded preset representation.
	@discussion	Introduced in FxGrip 0.1.0. The inverse of setParameterValue:toParameter:atTime:withAPI:.
				Dispatches on the parameter's type and reads through the setting wrapper's retrieval
				API. Requires the FxGrip setting wrapper, which exposes that API.
	@return		YES when the value is read.
*/
+ (BOOL)getParameterValue:(id*)value toParameter:(FxParameterId)parameterID atTime:(CMTime)time withAPI:(id<FxParameterSettingAPI_v5>)setterAPI
{
	if (!value || !setterAPI || ![setterAPI respondsToSelector:@selector(paramGetAPIv6)]) {
		return NO;
	}
	id<FxParameterRetrievalAPI_v6> getterAPI = [(id)setterAPI paramGetAPIv6];
	if (!getterAPI) {
		return NO;
	}

	switch ([self parameterTypeFor:parameterID withAPI:setterAPI]) {
		case FxParameterType_RGBA: {
			double red = 0, green = 0, blue = 0, alpha = 0;
			if (![getterAPI getRedValue:&red greenValue:&green blueValue:&blue alphaValue:&alpha
						  fromParameter:parameterID atTime:time]) {
				return NO;
			}
			*value = @{kFxParameterProperty_Red: @(red), kFxParameterProperty_Green: @(green),
					   kFxParameterProperty_Blue: @(blue), kFxParameterProperty_Alpha: @(alpha)};
			return YES;
		}
		case FxParameterType_RGB: {
			double red = 0, green = 0, blue = 0;
			if (![getterAPI getRedValue:&red greenValue:&green blueValue:&blue
						  fromParameter:parameterID atTime:time]) {
				return NO;
			}
			*value = @{kFxParameterProperty_Red: @(red), kFxParameterProperty_Green: @(green),
					   kFxParameterProperty_Blue: @(blue)};
			return YES;
		}
		case FxParameterType_Point: {
			double x = 0, y = 0;
			if (![getterAPI getXValue:&x YValue:&y fromParameter:parameterID atTime:time]) {
				return NO;
			}
			*value = @{kFxParameterProperty_X: @(x), kFxParameterProperty_Y: @(y)};
			return YES;
		}
		case FxParameterType_String:
		case FxParameterType_FontMenu: {
			NSString *string = nil;
			if (![getterAPI getStringParameterValue:&string fromParameter:parameterID]) {
				return NO;
			}
			*value = string;
			return YES;
		}
		case FxParameterType_Toggle: {
			BOOL flag = NO;
			if (![getterAPI getBoolValue:&flag fromParameter:parameterID atTime:time]) {
				return NO;
			}
			*value = @(flag);
			return YES;
		}
		case FxParameterType_Int:
		case FxParameterType_Menu: {
			int intValue = 0;
			if (![getterAPI getIntValue:&intValue fromParameter:parameterID atTime:time]) {
				return NO;
			}
			*value = @(intValue);
			return YES;
		}
		case FxParameterType_Custom: {
			NSObject<NSSecureCoding, NSCopying> *custom = nil;
			if (![getterAPI getCustomParameterValue:&custom fromParameter:parameterID atTime:time]) {
				return NO;
			}
			*value = custom;
			return YES;
		}
		case FxParameterType_None:
			return NO;
		default: {
			double doubleValue = 0;
			if (![getterAPI getFloatValue:&doubleValue fromParameter:parameterID atTime:time]) {
				return NO;
			}
			*value = @(doubleValue);
			return YES;
		}
	}
}

/*!
	@method		setParameterValue:toParameter:atTime:withAPI:
	@abstract	Writes one encoded preset value to a parameter.
	@discussion	Introduced in FxGrip 0.1.0. Dispatches on the parameter's type, resolved through
				the setting wrapper's dynamic API; when no type source is available the encoded
				value's own shape selects the setter. A Custom value merges recursively into the
				parameter's current value, so a preset may carry a subset.
	@return		YES when the value is written.
*/
+ (BOOL)setParameterValue:(id)value toParameter:(FxParameterId)parameterID atTime:(CMTime)time withAPI:(id<FxParameterSettingAPI_v5>)setterAPI
{
	if (!value || value == NSNull.null || !setterAPI) {
		return NO;
	}

	FxParameterType type = [self parameterTypeFor:parameterID withAPI:setterAPI];
	if (type == FxParameterType_None) {
		type = [self inferredTypeForValue:value];
	}

	NSDictionary *components = [value isKindOfClass:NSDictionary.class] ? value : nil;

	switch (type) {
		case FxParameterType_RGBA: {
			// Alpha is optional; a definition may carry only the color channels.
			if (!components) {
				return NO;
			}
			NSNumber *alpha = components[kFxParameterProperty_Alpha];
			if (!alpha) {
				return [setterAPI setRedValue:((NSNumber*)components[kFxParameterProperty_Red]).doubleValue
								   greenValue:((NSNumber*)components[kFxParameterProperty_Green]).doubleValue
									blueValue:((NSNumber*)components[kFxParameterProperty_Blue]).doubleValue
								  toParameter:parameterID atTime:time];
			}
			return [setterAPI setRedValue:((NSNumber*)components[kFxParameterProperty_Red]).doubleValue
							   greenValue:((NSNumber*)components[kFxParameterProperty_Green]).doubleValue
								blueValue:((NSNumber*)components[kFxParameterProperty_Blue]).doubleValue
							   alphaValue:alpha.doubleValue
							  toParameter:parameterID atTime:time];
		}
		case FxParameterType_RGB: {
			if (!components) {
				return NO;
			}
			return [setterAPI setRedValue:((NSNumber*)components[kFxParameterProperty_Red]).doubleValue
							   greenValue:((NSNumber*)components[kFxParameterProperty_Green]).doubleValue
								blueValue:((NSNumber*)components[kFxParameterProperty_Blue]).doubleValue
							  toParameter:parameterID atTime:time];
		}
		case FxParameterType_Point: {
			if (!components) {
				return NO;
			}
			return [setterAPI setXValue:((NSNumber*)components[kFxParameterProperty_X]).doubleValue
								 YValue:((NSNumber*)components[kFxParameterProperty_Y]).doubleValue
							toParameter:parameterID atTime:time];
		}
		case FxParameterType_String:
		case FxParameterType_FontMenu: {
			if (![value isKindOfClass:NSString.class]) {
				return NO;
			}
			return [setterAPI setStringParameterValue:value toParameter:parameterID];
		}
		case FxParameterType_Toggle: {
			if (![value isKindOfClass:NSNumber.class]) {
				return NO;
			}
			return [setterAPI setBoolValue:((NSNumber*)value).boolValue toParameter:parameterID atTime:time];
		}
		case FxParameterType_Int:
		case FxParameterType_Menu: {
			if (![value isKindOfClass:NSNumber.class]) {
				return NO;
			}
			return [setterAPI setIntValue:((NSNumber*)value).intValue toParameter:parameterID atTime:time];
		}
		case FxParameterType_Custom: {
			// Custom values merge into the existing data so a preset can carry a subset.
			if (components && [setterAPI respondsToSelector:@selector(paramGetAPIv6)]) {
				id<FxParameterRetrievalAPI_v6> getterAPI = [(id)setterAPI paramGetAPIv6];
				NSObject<NSSecureCoding, NSCopying> *current = nil;
				if (getterAPI && [getterAPI getCustomParameterValue:&current fromParameter:parameterID atTime:time]
					&& [current isKindOfClass:NSDictionary.class]) {
					NSMutableDictionary *merged = [(NSDictionary*)current mutableCopyRecursive];
					// addEntries… overwrites at every level: the preset's entries win over
					// the current value. mergeEntries… preserves existing keys, which would
					// silently discard the preset.
					[merged addEntriesFromDictionaryRecursive:components];
					return [setterAPI setCustomParameterValue:merged toParameter:parameterID atTime:time];
				}
			}
			if (![value conformsToProtocol:@protocol(NSSecureCoding)] || ![value conformsToProtocol:@protocol(NSCopying)]) {
				return NO;
			}
			return [setterAPI setCustomParameterValue:value toParameter:parameterID atTime:time];
		}
		case FxParameterType_None:
			return NO;
		default: {
			if (![value isKindOfClass:NSNumber.class]) {
				return NO;
			}
			return [setterAPI setFloatValue:((NSNumber*)value).doubleValue toParameter:parameterID atTime:time];
		}
	}
}

@end
