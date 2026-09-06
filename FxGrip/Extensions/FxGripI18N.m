/*!
	@file       FxGripI18N.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripI18N
	@abstract   Implements the parameter text localization extension.
	@discussion Introduced in FxGrip 0.1.0. The forward table is loaded from the plugin bundle's
	            Localizable.strings and cached; the reverse table is built on first delocalization.
	            The parameter API handlers localize on writes and delocalize on reads for names,
	            string values, and menu items.
*/

#import "FxGripI18N.h"
#import "FxGripTileableEffect.h"
#import "FxGripTileableEffect+Extensions.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "FxGripAPINotifications.h"
#import "FxGrip_ARC.h"
#import <BEFoundation/NSArray+BExtension.h>

/*!
	@abstract	The internationalization extension for effect parameter text.
	@discussion	Introduced in FxGrip 0.1.0. Localization and delocalization are independently switched
				per text kind and applied in the parameter API notification handlers.
*/
@implementation FxGripI18N


- (id)init
{
	self = [super init];
	if (self) {
		_isLocalizingNames = YES;
		_isLocalizingValues = YES;
		_isLocalizingMenus = YES;

		_isDelocalizingNames = YES;
		_isDelocalizingValues = YES;
		_isDelocalizingMenus = YES;
	}
	return self;
}

/*!
	@method		extLoadWithEffect:
	@abstract	Binds the extension and reads the delocalization switches from the plugin properties.
	@discussion	Introduced in FxGrip 0.1.0. An unset values switch defaults to the names switch, and an
				unset menus switch defaults to the values switch. */
// The plist properties are read here: the effect is nil until load.
- (BOOL)extLoadWithEffect:(nonnull id<FxGripTileableEffect>)effect
{
	BOOL success = [super extLoadWithEffect:effect];
	if (!success) {
		return success;
	}

	NSDictionary *properties = ((FxGripTileableEffect*)effect).pluginProperties;

	NSNumber *value = properties[kProPlugPlugInX_DelocalizeNamesProperty];
	if (value) {
		_isDelocalizingNames = [value boolValue];
	}

	value = properties[kProPlugPlugInX_DelocalizeValuesProperty];
	if (value) {
		_isDelocalizingValues = [value boolValue];
	} else {
		_isDelocalizingValues = _isDelocalizingNames;
	}

	value = properties[kProPlugPlugInX_DelocalizeMenusProperty];
	if (value) {
		_isDelocalizingMenus = [value boolValue];
	} else {
		_isDelocalizingMenus = _isDelocalizingValues;
	}

	return success;
}


- (void)dealloc
{
	NARC_RELEASE(localizeDictionary);
	NARC_RELEASE(reverseLocalizeDictionary);
	
	SUPER_DEALLOC();
}




// The handlers operate on the nested FxGripNotifyAPI_ParameterKey dictionary with direct key
// access: the payloads are thin (no type/name for every key), so the guarded
// NSDictionary accessors cannot read them.

/*! @abstract Delocalizes a parameter's name on a name read when name delocalization is enabled. */
- (void)extAPIParameterGetName:(nonnull NSNotification *)notification
{
	NSMutableDictionary *parameter = notification.userInfo.mutableFxParameter;
	if (_isDelocalizingNames && [parameter[kFxParameterProperty_Name] isKindOfClass:NSString.class]) {
		parameter[kFxParameterProperty_Name] = [self delocalize:parameter[kFxParameterProperty_Name]];
	}
}

/*! @abstract Localizes a parameter's name on a name write when name localization is enabled. */
- (void)extAPIParameterSetNamePre:(nonnull NSNotification *)notification
{
	NSMutableDictionary *parameter = notification.userInfo.mutableFxParameter;
	NSString *name = parameter[kFxParameterProperty_Name];
	if (_isLocalizingNames && [name isKindOfClass:NSString.class]) {
		parameter[kFxParameterProperty_Name] = [self localize:name];
	}
}


/*! @abstract Localizes the name, and for a String or Menu the value or items, as a parameter is added. */
- (void)extAPIParameterAdd:(nonnull NSNotification *)notification
{
	NSMutableDictionary *parameter = notification.userInfo.mutableFxParameter;
	if (!parameter) {
		return;
	}
	FxParameterType type = ((NSNumber*)parameter[kFxParameterProperty_Type]).intValue;

	NSString *name = parameter[kFxParameterProperty_Name];
	if (_isLocalizingNames && [name isKindOfClass:NSString.class]) {
		parameter[kFxParameterProperty_Name] = [self localize:name];
	}
	NSString *defaultValue = parameter[kFxParameterProperty_Default];
	if (_isLocalizingValues && type == FxParameterType_String && [defaultValue isKindOfClass:NSString.class]) {
		parameter[kFxParameterProperty_Default] = [self localize:defaultValue];
	}
	NSArray<NSString*> *entries = parameter[kFxParameterProperty_MenuItems];
	if (_isLocalizingMenus && type == FxParameterType_Menu && [entries isKindOfClass:NSArray.class]) {
		entries = [entries mapUsingBlock:^BOOL(id  _Nullable __autoreleasing * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
			*obj = [self localize:*obj];
			return YES;
		}];
		parameter[kFxParameterProperty_MenuItems] = entries;
	}
}



/*! @abstract Delocalizes a string parameter's value on a value read when value delocalization is enabled. */
- (void)extAPIParameterGetStringValue:(nonnull NSNotification *)notification
{
	NSMutableDictionary *parameter = notification.userInfo.mutableFxParameter;
	if (_isDelocalizingValues && [parameter[kFxParameterProperty_Default] isKindOfClass:NSString.class]) {
		parameter[kFxParameterProperty_Default] = [self delocalize:parameter[kFxParameterProperty_Default]];
	}
}

/*! @abstract Localizes a string parameter's value on a value write when value localization is enabled. */
- (void)extAPIParameterSetStringValuePre:(nonnull NSNotification *)notification
{
	NSMutableDictionary *parameter = notification.userInfo.mutableFxParameter;
	NSString *defaultValue = parameter[kFxParameterProperty_Default];
	if (_isLocalizingValues && [defaultValue isKindOfClass:NSString.class]) {
		parameter[kFxParameterProperty_Default] = [self localize:defaultValue];
	}
}



/*! @abstract Localizes a menu parameter's items on a menu write when menu localization is enabled. */
- (void)extAPIParameterSetMenuPre:(nonnull NSNotification *)notification
{
	NSMutableDictionary *parameter = notification.userInfo.mutableFxParameter;
	NSArray<NSString*> *entries = parameter[kFxParameterProperty_MenuItems];
	if (_isLocalizingMenus && [entries isKindOfClass:NSArray.class]) {
		entries = [entries mapUsingBlock:^BOOL(id *obj, NSUInteger idx, BOOL *stop) {
			*obj = [self localize:*obj];
			return YES;
		}];
		parameter[kFxParameterProperty_MenuItems] = entries;
	}
}

/*! @abstract Delocalizes a menu parameter's items on a menu read when menu delocalization is enabled. */
- (void)extAPIParameterGetMenu:(nonnull NSNotification *)notification
{
	NSMutableDictionary *parameter = notification.userInfo.mutableFxParameter;
	NSArray<NSString*> *entries = parameter[kFxParameterProperty_MenuItems];
	if (_isDelocalizingMenus && [entries isKindOfClass:NSArray.class]) {
		entries = [entries mapUsingBlock:^BOOL(id *obj, NSUInteger idx, BOOL *stop) {
			*obj = [self delocalize:*obj];
			return YES;
		}];
		parameter[kFxParameterProperty_MenuItems] = entries;
	}
}


// delocalized replacement to dynamic parameters api v3 - (void)parameter:name:
- (void)parameter:(FxParameterId)parameterID name:(NSString**)parameterName
{
	if (!parameterName) {
		return;
	}
	[self.effect.apiManager.dynamicParamAPIv3_Raw parameter:parameterID name:parameterName];

	if (_isDelocalizingNames) {
		*parameterName = [self delocalize:*parameterName];
	}
}




- (nonnull NSBundle*)localizationBundle
{
	NSBundle *bundle = self.effect ? [NSBundle bundleForClass:[(NSObject*)self.effect class]] : nil;
	return bundle ?: NSBundle.mainBundle;
}

- (nonnull NSDictionary<NSString*, NSString*>*)localizationTable
{
	// Cached in localizeDictionary; a plugin's strings do not change at run time. A subclass
	// that overrides this bypasses the cache and supplies its own table.
	if (localizeDictionary == nil) {
		NSURL *tableURL = [self.localizationBundle URLForResource:@"Localizable" withExtension:@"strings"];
		NSDictionary *table = tableURL ? [NSDictionary dictionaryWithContentsOfURL:tableURL] : nil;
		localizeDictionary = [table isKindOfClass:NSDictionary.class] ? [table copy] : @{};
	}
	return (NSDictionary<NSString*, NSString*>*)localizeDictionary;
}

- (nonnull NSString*)localize:(nonnull NSString*)key
{
	if (![key isKindOfClass:NSString.class]) {
		return key;
	}
	id value = self.localizationTable[key];
	return [value isKindOfClass:NSString.class] ? value : key;
}

// Delocalization inverts the same table the forward path localizes through, so a round-trip
// closes: the map is keyed by the localized value and returns the original key.
- (nullable NSString*)delocalize:(nullable NSString*)string
{
	if (![string isKindOfClass:NSString.class]) {
		return string;
	}
	NSDictionary<NSString*, NSString*> *table = self.localizationTable;
	if (reverseLocalizeDictionary == nil) {
		NSMutableDictionary<NSString *,NSString *> *reverse = [NSMutableDictionary dictionaryWithCapacity:table.count];
		[table enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
			if ([value isKindOfClass:NSString.class]) {
				reverse[(NSString *)value] = key;
			}
		}];
		reverseLocalizeDictionary = reverse;
	}
	id element = reverseLocalizeDictionary[string];
	if ([element isKindOfClass:NSString.class]) {
		return element;
	}
	return string;
}

@end




/*!
	@abstract	The effect-side accessors for the internationalization extension.
	@discussion	Introduced in FxGrip 0.1.0. isInternationalized reads the plugin property that gates
				the extension.
*/
@implementation FxGripTileableEffect (I18N)

- (FxGripI18N*)i18n
{
	return [self extensionForClass:FxGripI18N.class];
}


- (nonnull FxGripI18N*)newI18NExtension
{
	return [FxGripI18N.alloc init];
}

- (BOOL)isInternationalized
{
	NSNumber *value = self.pluginProperties[kProPlugPlugInX_InternationalizeProperty];
	if (!value) {
		return NO;
	}
	return [value boolValue];
}

@end


