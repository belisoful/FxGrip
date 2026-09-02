//
//  FxGripDebugMenu.m
//  FxGrip
//
//  Copyright © 2024 Belisoful All rights reserved.
//

#import "FxGripDebugMenu.h"
#import "FxGripTileableEffect.h"
#import "FxGripTileableEffect+Extensions.h"
#import "FxGripTileableEffect+Notifications.h"
#import "FxGripAPINotifications.h"
#import "FxGripParameterFlags.h"
#import "FxGripPluginInfo.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import <BEFoundation/NSNotification+MutableUserInfo.h>

typedef NS_ENUM(NSUInteger, FxGripDebugMenuItem) {
	DebugItem_Main = 0,
	DebugItem_ToggleUnhide = 2,
	DebugItem_ToggleShow = 3,
	DebugItem_ToggleMenu = 5,
	DebugItem_RemoveDebug = 7,
	DebugItem_AddParam = 8,
	DebugItem_RemoveParam = 9,
};

NSString*	const _Nonnull FxGripDebugMenuExtensionKey = @"FxGripDebugMenu";


@implementation FxGripDebugMenu

-(NSString*) extKey
{
	return FxGripDebugMenuExtensionKey;
}


-(int) extPostProcessPriority
{
	return 19;
}

// The debug-mode flags transform reads the HIDDEN_PROXY / IN_DEBUG_MODE bits that
// FxGripParameterData restores at the default priority on a flags read, so it runs after.
- (NSInteger)ncPriority:(nullable NSNotificationName)aName
{
	if ([FxGripNotifyAPI_ParameterGetFlagsName isEqualToString:aName]) {
		return FxGripExtensionDefaultPriority + 2;
	}
	return [super ncPriority:aName];
}

// Default NO, Looks at the plugin class Info.plist for @"debugMenu" BOOL equals @YES
- (BOOL)hasDebugMenu
{
	return self.effect.pluginProperties.pluginDebugActivator || self.effect.pluginProperties.pluginDebugMenu;
}

- (BOOL)hasDebugActivator
{
	return self.effect.pluginProperties.pluginDebugActivator;
}

/*
 *
 *
 *
 *
 */
- (void)extAddParameters:(nonnull NSNotification*)notification
{
	if (!self.hasDebugMenu) {
		return;
	}
	NSMutableArray<NSMutableDictionary *> *parameters = notification.userInfo.fxEffectParameters;
	if (self.hasDebugActivator) {
		NSDictionary *debugActivatorParameter = @{
			kFxParameterProperty_Id: @(kFxParameterId_DebugActivator),
			kFxParameterProperty_Type: kFxParameterType_Toggle,
			kFxParameterProperty_Name: @"FxGrip::DebugMenu::DebugMenuVisibilityToggle",
			kFxParameterProperty_Default: @(NO),
			kFxParameterProperty_Flags: @[kParameterFlagString_NOT_ANIMATABLE], //kParameterFlagString_HIDDEN,
			kFxParameterProperty_TargetPreset: @[
				@{kFxParameterProperty_TargetPresetFlags: @{@kFxParameterId_DebugMenu: @"+hidden"}},
				@{kFxParameterProperty_TargetPresetFlags: @{@kFxParameterId_DebugMenu: @"-hidden"}},
			]

		};
		[parameters addObject:[debugActivatorParameter mutableCopy]];
	}
	NSDictionary *debugMenuParameter = @{
		kFxParameterProperty_Factory: self,
		kFxParameterProperty_Id: @(kFxParameterId_DebugMenu),
		kFxParameterProperty_Type: kFxParameterType_Menu,
		kFxParameterProperty_Name: @"FxGrip::DebugMenu::Name",
		kFxParameterProperty_ResetValue: @0,
		kFxParameterProperty_MenuItems: [self debugMenuItems:false],
		kFxParameterProperty_Selector: @"manageDebuggerController",//:atTime:error:",
		kFxParameterProperty_Flags: @[kParameterFlagString_NOT_ANIMATABLE,
									  (self.hasDebugActivator) ? kParameterFlagString_HIDDEN : @"",
									  kParameterFlagString_DONT_DISPLAY]
	};
	[parameters addObject:[debugMenuParameter mutableCopy]];
}




// In debug mode, hidden parameters remain shown but the hidden bit is transferred from hidden proxy
// In debug mode, transfer hidden proxy to hidden.
- (void)extAPIParameterGetFlags:(nonnull NSNotification*)notification
{
	NSMutableDictionary *parameter = notification.userInfo.mutableFxParameter;
	if (![parameter[kFxParameterProperty_Flags] isKindOfClass:NSNumber.class]) {
		return;
	}
	FxParameterFlags f = ((NSNumber*)parameter[kFxParameterProperty_Flags]).unsignedIntValue;
	if (f & kFxParameterFlag_IN_DEBUG_MODE) {
		f &= ~kFxParameterFlag_HIDDEN;
		if (f & kFxParameterFlag_HIDDEN_PROXY) {
			f |= kFxParameterFlag_HIDDEN;
			f &= ~kFxParameterFlag_HIDDEN_PROXY;
		}
	}
	parameter[kFxParameterProperty_Flags] = @(f);
}

// In debug mode, hidden parameters remain shown but the bit is retained as hidden proxy
// In debug mode, transfer hidden to hidden proxy.
- (void)extAPIParameterSetFlagsPre:(nonnull NSNotification*)notification
{
	NSMutableDictionary *parameter = notification.userInfo.mutableFxParameter;
	if (![parameter[kFxParameterProperty_Flags] isKindOfClass:NSNumber.class]) {
		return;
	}
	FxParameterFlags f = ((NSNumber*)parameter[kFxParameterProperty_Flags]).unsignedIntValue;
	//When saving, if in debug mode,
	if (f & kFxParameterFlag_IN_DEBUG_MODE) {
		f &= ~kFxParameterFlag_HIDDEN_PROXY;
		if (f & kFxParameterFlag_HIDDEN) {
			f &= ~kFxParameterFlag_HIDDEN;
			f |= kFxParameterFlag_HIDDEN_PROXY;
		}
	}
	parameter[kFxParameterProperty_Flags] = @(f);
}








- (BOOL)debugUnhide:(BOOL)active
{
	id<FxDynamicParameterAPI_v3> dynamicAPIv3 = self.effect.apiManager.dynamicParamAPIv3;
	id<FxParameterRetrievalAPI_v6> paramGetAPIv6 = self.effect.apiManager.paramGetAPIv6;
	id<FxParameterSettingAPI_v5> paramSetAPIv5 = self.effect.apiManager.paramSetAPIv5;
	
	
	int numParams = dynamicAPIv3.parameterCount;
	
	for(int i = 0; i < numParams; i++) {
		FxParameterId pid = [dynamicAPIv3 parameterIDAtIndex:i];
		FxParameterFlags pflags = 0;
		
		if (![paramGetAPIv6 getParameterFlags:&pflags fromParameter:pid])
			return NO;
		
		if (pflags & kFxParameterFlag_NO_DEBUG)
			continue;
		
		BOOL changed = NO;
		if (active && !(pflags & kFxParameterFlag_IN_DEBUG_MODE)) {
			pflags |= kFxParameterFlag_IN_DEBUG_MODE;
			changed = YES;
		} else if (!active && (pflags & kFxParameterFlag_IN_DEBUG_MODE)) {
			pflags &= ~kFxParameterFlag_IN_DEBUG_MODE;
			changed = YES;
		}
		
		if (changed && ![paramSetAPIv5 setParameterFlags:pflags toParameter:pid])
			return NO;
	}
		
	[self.effect.apiManager.dynamicParamAPIv3 setPopupMenuParameter:kFxParameterId_DebugMenu entries: [FxGripPluginInfo localizeObject:[self debugMenuItems:active].localize] defaultValue:0];
	
	return YES;
}

- (BOOL)isDebugUnhiding
{
	FxParameterFlags unhideFlags = 0;
	
	if (![self.effect.apiManager.paramGetAPIv6 getParameterFlags:&unhideFlags fromParameter:kFxParameterId_DebugMenu])
		return NO;
	return (unhideFlags & kFxParameterFlag_DEBUG_UNHIDE) != 0;
}


- (BOOL)manageDebuggerController:(FxParameterId)paramID
						  atTime:(CMTime)time
						   error:(NSError * _Nullable * _Nullable)error
{
	int selection = -1;
	
	if (![self.effect.apiManager.paramGetAPIv6 getIntValue:&selection fromParameter:paramID atTime:time])
		return NO;
	
	if (!self.hasDebugActivator && selection >= DebugItem_ToggleShow) {
		selection += 1;
	}
	
	switch(selection) {
		case DebugItem_Main: // Main Item
			break;
		case DebugItem_ToggleUnhide:
			if (![self debugUnhide:!self.isDebugUnhiding]) {
				return NO;
			}
			break;
		case DebugItem_ToggleShow:
			{
				FxParameterFlags activatorFlags = 0;
				
				[self.effect.apiManager.paramGetAPIv6 getParameterFlags:&activatorFlags fromParameter:kFxParameterId_DebugActivator];
				activatorFlags ^= kFxParameterFlag_HIDDEN;
				[self.effect.apiManager.paramSetAPIv6 setParameterFlags:activatorFlags toParameter:kFxParameterId_DebugActivator];
			}
			break;
		case DebugItem_ToggleMenu:
			{
				BOOL activator = NO;
				if (![self.effect.apiManager.paramGetAPIv6 getBoolValue:&activator fromParameter:kFxParameterId_DebugActivator atTime:time])
					return NO;
				activator = !activator;
				if (![self.effect.apiManager.paramSetAPIv5 setBoolValue:activator toParameter:kFxParameterId_DebugActivator atTime:time])
					return NO;
				//[self.effect setParameterTargetPreset:kFxParameterId_DebugActivator
				//							   atTime:time
				//							  options:PresetFlags];
			}
			break;
		case DebugItem_RemoveDebug:
			if (self.hasDebugMenu) {
				if (self.isDebugUnhiding && ![self debugUnhide:NO]) {
					return NO;
				}
				if (self.hasDebugActivator) {
					[self.effect.apiManager.dynamicParamAPIv3 removeParameter:kFxParameterId_DebugActivator];
				}
				NSError *err = [self.effect.apiManager.dynamicParamAPIv3 removeParameter:kFxParameterId_DebugMenu];
				if (err) {
					NSLog(@"ERROR - error removing debug meno %@", err);
					return NO;
				}
			}
			break;
		
		case DebugItem_AddParam:
			{
#define kTempParamId 888
				BOOL success = [self.effect.apiManager.paramCreateAPIv5 addStringParameterWithName:@"Temp Param" parameterID:kTempParamId defaultValue:@"xyz" parameterFlags:kFxParameterFlag_DEFAULT];
				if (!success) {
					NSLog(@"ERROR - could not add temp param");
					return NO;
				}
				FxParameterFlags flags = 0;
				[self.effect.apiManager.paramGetAPIv6 getParameterFlags:&flags fromParameter:kTempParamId];
				flags |= 0;
				[self.effect.apiManager.paramSetAPIv5 setParameterFlags:flags toParameter:kTempParamId];
			}
			break;
		case DebugItem_RemoveParam:
			{
				NSError *err = [self.effect.apiManager.dynamicParamAPIv3 removeParameter:kTempParamId];
				if (err) {
					NSLog(@"ERROR - could not remove param %@", err);
					return NO;
				}
			}
			break;
	}
	
	return YES;
}


- (NSArray<NSString*>*)debugMenuItems:(BOOL)unhide
{
	NSMutableArray *menuItems = [NSMutableArray arrayWithCapacity:20];
	
	[menuItems addObject:@"FxGrip::DebugMenu::MainItem"];
	[menuItems addObject:@"-"];
	[menuItems addObject:unhide ? @"FxGrip::DebugMenu::ToggleUnhideOn": @"FxGrip::DebugMenu::ToggleUnhideOff"]; // map to debug menu unused flag?  like collapsed or ...
	
	if (self.hasDebugActivator) {
		[menuItems addObject:@"FxGrip::DebugMenu::ToggleDebugToggle"];
	}
	[menuItems addObject:@"-"];
	[menuItems addObject:@"FxGrip::DebugMenu::ToggleDebugMenu"];
	[menuItems addObject:@"-"];
	[menuItems addObject:@"FxGrip::DebugMenu::RemoveDebugMenu"];
	[menuItems addObject:@"Add Param"];
	[menuItems addObject:@"Remove Param"];
	
	return [menuItems copy];
}

@end



@implementation FxGripTileableEffect (DebugMenu)

- (FxGripDebugMenu *)debugMenu
{
	return [self extensionForClass:FxGripDebugMenu.class];
}

- (BOOL)hasDebugMenu
{
	return self.pluginProperties.pluginDebugMenu || self.pluginProperties.pluginDebugActivator;
}

- (nonnull FxGripDebugMenu *)newDebugMenuExtension
{
	return [FxGripDebugMenu.alloc init];
}

@end
