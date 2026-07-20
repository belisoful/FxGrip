//
//  FxGripI18N.m
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#import "FxGripI18N.h"
#import "FxTileableEffectBase.h"
#import "FxTileableEffectBase+Extensions.h"
#import "NSDictionary+FxTileableEffect.h"
#import "FxGrip_ARC.h"
#import <BEFoundation/NSArray+BExtension.h>

@implementation FxGripI18N


- (id)init
{
	self = [super init];
	if (self) {
		_isLocalizingNames = YES;
		_isLocalizingValues = YES;
		_isLocalizingMenus = YES;
		
		_isDelocalizingNames = YES;
		
		NSNumber *value = self.effect.pluginProperties[kProPlugPlugInX_DelocalizeNamesProperty];
		if (value) {
			_isDelocalizingNames = [value boolValue];
		}
		
		value = self.effect.pluginProperties[kProPlugPlugInX_DelocalizeValuesProperty];
		if (value) {
			_isDelocalizingValues = [value boolValue];
		} else {
			_isDelocalizingValues = _isDelocalizingNames;
		}
		
		value = self.effect.pluginProperties[kProPlugPlugInX_DelocalizeMenusProperty];
		if (value) {
			_isDelocalizingMenus = [value boolValue];
		} else {
			_isDelocalizingMenus = _isDelocalizingValues;
		}
	}
	return self;
}


- (void)dealloc
{
	NARC_RELEASE(localizeDictionary);
	NARC_RELEASE(reverseLocalizeDictionary);
	
	SUPER_DEALLOC();
}




/*
	delocalize the parameter names where requested
 */
- (void)extAPIParameterGetName:(nonnull NSNotification *)notification
{
	if (_isDelocalizingNames && notification.userInfo[kFxParameterProperty_Name]) {
		((NSMutableDictionary*)notification.userInfo)[kFxParameterProperty_Name] = [self delocalize:notification.userInfo[kFxParameterProperty_Name]];
	}
}

/*
 	Localize the parameter names
 */
- (void)extAPIParameterSetNamePre:(nonnull NSNotification *)notification
{
	NSMutableDictionary *userInfo = (NSMutableDictionary*) notification.userInfo;
	if(_isLocalizingNames && userInfo.parameterName) {
		((NSMutableDictionary*)userInfo)[kFxParameterProperty_Name] = NSLocalizedString(userInfo.parameterName, userInfo.parameterName);
	}
}


- (void)extAPIParameterAdd:(nonnull NSNotification *)notification
{
	NSMutableDictionary *userInfo = (NSMutableDictionary*) notification.userInfo;
	if(_isLocalizingNames && userInfo.parameterName) {
		((NSMutableDictionary*)userInfo)[kFxParameterProperty_Name] = NSLocalizedString(userInfo.parameterName, userInfo.parameterName);
	}
	if (_isLocalizingValues && userInfo.parameterType == FxParameterType_String) {
		((NSMutableDictionary*)userInfo)[kFxParameterProperty_Default] = NSLocalizedString(userInfo.parameterDefaultValue, userInfo.parameterDefaultValue);
	}
	if (_isLocalizingMenus && userInfo.parameterType == FxParameterType_Menu) {
		NSArray<NSString*> *entries = userInfo.parameterMenuItems;
		entries = [entries mapUsingBlock:^BOOL(id  _Nullable __autoreleasing * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
			*obj = NSLocalizedString(*obj, *obj);
			return YES;
		}];
		((NSMutableDictionary*)userInfo)[kFxParameterProperty_MenuItems] = entries;
	}
}



/*
	delocalize the parameter string values where requested
 */
- (void)extAPIParameterGetStringValue:(nonnull NSNotification *)notification
{
	NSMutableDictionary *userInfo = (NSMutableDictionary*) notification.userInfo;
	if (_isDelocalizingValues && userInfo.parameterDefaultValue) {
		((NSMutableDictionary*)notification.userInfo)[kFxParameterProperty_Default] = [self delocalize:userInfo.parameterDefaultValue];
	}
}

/*
	Localize the parameter string values
 */
- (void)extAPIParameterSetStringValuePre:(nonnull NSNotification *)notification
{
	NSMutableDictionary *userInfo = (NSMutableDictionary*) notification.userInfo;
	if (_isLocalizingValues && userInfo.parameterType == FxParameterType_String) {
		((NSMutableDictionary*)userInfo)[kFxParameterProperty_Default] = NSLocalizedString(userInfo.parameterDefaultValue, userInfo.parameterDefaultValue);
	}
}



/*
	Localize the parameter menu items
 */
- (void)extAPIParameterSetMenuPre:(nonnull NSNotification *)notification
{
	if (_isLocalizingMenus) {
		NSMutableDictionary *userInfo = (NSMutableDictionary*) notification.userInfo;
		NSArray<NSString*> *entries = userInfo.parameterMenuItems;
		entries = [entries mapUsingBlock:^BOOL(id *obj, NSUInteger idx, BOOL *stop) {
			*obj = NSLocalizedString(*obj, *obj);
			return YES;
		}];
		((NSMutableDictionary*)userInfo)[kFxParameterProperty_MenuItems] = entries;
	}
}

/*
	delocalize the parameter menu items where requested
 */
- (void)extAPIParameterGetMenu:(nonnull NSNotification *)notification
{
	if (_isDelocalizingMenus) {
		NSMutableDictionary *userInfo = (NSMutableDictionary*) notification.userInfo;
		NSArray<NSString*> *entries = userInfo.parameterMenuItems;
		entries = [entries mapUsingBlock:^BOOL(id *obj, NSUInteger idx, BOOL *stop) {
			*obj = [self delocalize:*obj];
			return YES;
		}];
		((NSMutableDictionary*)userInfo)[kFxParameterProperty_MenuItems] = entries;
	}
}


// delocalized replacement to dynamic parameters api v3 - (void)parameter:name:
- (void)parameter:(FxParameterId)parameterID name:(NSString**)parameterName
{
	if (!parameterName) {
		return;
	}
	[self.effect.apiManager.dynamicParamAPIv3_Raw parameter:parameterID name:parameterName];
	
	*parameterName = [self delocalize:*parameterName];
}




- (nullable NSString*)delocalize:(nullable NSString*)string
{
	if (!string) {
		return string;
	}
	
	NSBundle *mainBundle = [NSBundle mainBundle];
	if (!mainBundle) {
		return string;
	}
	NSDictionary<NSString *,id> *localized = [mainBundle localizedInfoDictionary];
	if (!localized) {
		return string;
	}
	if (localizeDictionary != localized) {
		localizeDictionary = localized;
		reverseLocalizeDictionary = [NSDictionary dictionaryWithObjects:localized.allValues forKeys:localized.allKeys];
	}
	id element = reverseLocalizeDictionary[string];
	if (element)
		return element;
	return string;
}

@end




@implementation FxTileableEffectBase (I18N)

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


