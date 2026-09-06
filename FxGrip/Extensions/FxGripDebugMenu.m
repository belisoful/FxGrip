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

// Logical debug-menu commands. The values are identity tags, not menu positions: the menu
// layout pairs each displayed row with its command in one pass (see debugMenuLayout:), and
// dispatch resolves the host's selection index against that same layout. Reordering or
// inserting rows needs no index bookkeeping.
typedef NS_ENUM(NSUInteger, FxGripDebugCommand) {
	FxGripDebugCommand_None = 0,
	FxGripDebugCommand_Main,
	FxGripDebugCommand_ToggleUnhide,
	FxGripDebugCommand_ToggleActivatorVisibility,
	FxGripDebugCommand_ToggleAll,
	FxGripDebugCommand_ToggleActivatorValue,
	FxGripDebugCommand_RemoveDebug,
};

static NSString *const FxGripDebugLayoutLabelKey = @"label";
static NSString *const FxGripDebugLayoutCommandKey = @"command";

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

// The effect owns the debug gate so a plugin's compiled override, not just the Info.plist,
// decides whether the menu and activator appear.
- (BOOL)hasDebugMenu
{
	return self.effect.effectBase.hasDebugMenu;
}

- (BOOL)hasDebugActivator
{
	return self.effect.effectBase.pluginDebugActivatorEnabled;
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


// The activator reveals the menu here, not through the activator's target preset. The target
// preset is applied by FxGripMeta, which a plugin may not load, so a rigged activator would
// otherwise do nothing. This handler runs for every value change independent of manageMeta.
- (void)extParameterChanged:(nonnull NSNotification*)notification
{
	NSNumber *pidNumber = notification.userInfo[FxGripTileableEffectParameterChangedIDKey];
	if (pidNumber.unsignedIntValue != kFxParameterId_DebugActivator || !self.hasDebugActivator) {
		return;
	}

	CMTime time = kCMTimeZero;
	NSDictionary *timeDict = notification.userInfo[FxGripTileableEffectParameterChangedAtTimeKey];
	if ([timeDict isKindOfClass:NSDictionary.class]) {
		time = CMTimeMakeFromDictionary((__bridge CFDictionaryRef)timeDict);
	}

	BOOL activator = NO;
	if (![self.effect.apiManager.paramGetAPIv6 getBoolValue:&activator fromParameter:kFxParameterId_DebugActivator atTime:time]) {
		return;
	}
	[self setDebugMenuShown:activator atTime:time];
}

// Sets the debug menu's HIDDEN bit to match `show`. The caller passes the activator value it
// already knows, so the reveal never depends on reading a value back through a second API.
- (BOOL)setDebugMenuShown:(BOOL)show atTime:(CMTime)time
{
	FxParameterFlags flags = 0;
	if (![self.effect.apiManager.paramGetAPIv6 getParameterFlags:&flags fromParameter:kFxParameterId_DebugMenu]) {
		return NO;
	}
	if (show) {
		flags &= ~kFxParameterFlag_HIDDEN;
	} else {
		flags |= kFxParameterFlag_HIDDEN;
	}
	return [self.effect.apiManager.paramSetAPIv5 setParameterFlags:flags toParameter:kFxParameterId_DebugMenu];
}


- (BOOL)manageDebuggerController:(FxParameterId)paramID
						  atTime:(CMTime)time
						   error:(NSError * _Nullable * _Nullable)error
{
	int selection = -1;

	if (![self.effect.apiManager.paramGetAPIv6 getIntValue:&selection fromParameter:paramID atTime:time])
		return NO;

	switch([self commandForSelection:selection]) {
		case FxGripDebugCommand_None:
		case FxGripDebugCommand_Main:
			break;
		case FxGripDebugCommand_ToggleUnhide:
			if (![self debugUnhide:!self.isDebugUnhiding]) {
				return NO;
			}
			break;
		case FxGripDebugCommand_ToggleActivatorVisibility:
			{
				FxParameterFlags activatorFlags = 0;

				[self.effect.apiManager.paramGetAPIv6 getParameterFlags:&activatorFlags fromParameter:kFxParameterId_DebugActivator];
				activatorFlags ^= kFxParameterFlag_HIDDEN;
				[self.effect.apiManager.paramSetAPIv6 setParameterFlags:activatorFlags toParameter:kFxParameterId_DebugActivator];
			}
			break;
		case FxGripDebugCommand_ToggleActivatorValue:
			{
				BOOL activator = NO;
				if (![self.effect.apiManager.paramGetAPIv6 getBoolValue:&activator fromParameter:kFxParameterId_DebugActivator atTime:time])
					return NO;
				activator = !activator;
				if (![self.effect.apiManager.paramSetAPIv5 setBoolValue:activator toParameter:kFxParameterId_DebugActivator atTime:time])
					return NO;
				if (![self setDebugMenuShown:activator atTime:time])
					return NO;
			}
			break;
		case FxGripDebugCommand_ToggleAll:
			{
				// Go dark without deleting: hide the activator control and the menu, leaving the
				// activator as a Motion-riggable switch that still drives the menu's visibility.
				FxParameterFlags activatorFlags = 0;
				if (![self.effect.apiManager.paramGetAPIv6 getParameterFlags:&activatorFlags fromParameter:kFxParameterId_DebugActivator])
					return NO;
				BOOL goingDark = (activatorFlags & kFxParameterFlag_HIDDEN) == 0;
				if (goingDark) {
					activatorFlags |= kFxParameterFlag_HIDDEN;
				} else {
					activatorFlags &= ~kFxParameterFlag_HIDDEN;
				}
				if (![self.effect.apiManager.paramSetAPIv6 setParameterFlags:activatorFlags toParameter:kFxParameterId_DebugActivator])
					return NO;
				BOOL activatorOn = !goingDark;
				if (![self.effect.apiManager.paramSetAPIv5 setBoolValue:activatorOn toParameter:kFxParameterId_DebugActivator atTime:time])
					return NO;
				if (![self setDebugMenuShown:activatorOn atTime:time])
					return NO;
			}
			break;
		case FxGripDebugCommand_RemoveDebug:
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
	}

	return YES;
}


// The single source for the menu: each row's label paired with the command it invokes.
// debugMenuItems: renders the labels the host displays; commandForSelection: maps the host's
// selection index back through the same rows. Separators carry FxGripDebugCommand_None.
- (NSArray<NSDictionary*>*)debugMenuLayout:(BOOL)unhide
{
	NSMutableArray<NSDictionary*> *layout = [NSMutableArray arrayWithCapacity:20];
	void (^row)(NSString*, FxGripDebugCommand) = ^(NSString *label, FxGripDebugCommand command) {
		[layout addObject:@{FxGripDebugLayoutLabelKey: label, FxGripDebugLayoutCommandKey: @(command)}];
	};

	row(@"FxGrip::DebugMenu::MainItem", FxGripDebugCommand_Main);
	row(@"-", FxGripDebugCommand_None);
	row(unhide ? @"FxGrip::DebugMenu::ToggleUnhideOn" : @"FxGrip::DebugMenu::ToggleUnhideOff", FxGripDebugCommand_ToggleUnhide);

	if (self.hasDebugActivator) {
		row(@"FxGrip::DebugMenu::ToggleDebugToggle", FxGripDebugCommand_ToggleActivatorVisibility);
		row(@"FxGrip::DebugMenu::ToggleAllDebug", FxGripDebugCommand_ToggleAll);
	}
	row(@"-", FxGripDebugCommand_None);
	row(@"FxGrip::DebugMenu::ToggleDebugMenu", FxGripDebugCommand_ToggleActivatorValue);
	row(@"-", FxGripDebugCommand_None);
	row(@"FxGrip::DebugMenu::RemoveDebugMenu", FxGripDebugCommand_RemoveDebug);

	return [layout copy];
}

- (NSArray<NSString*>*)debugMenuItems:(BOOL)unhide
{
	NSArray<NSDictionary*> *layout = [self debugMenuLayout:unhide];
	NSMutableArray<NSString*> *menuItems = [NSMutableArray arrayWithCapacity:layout.count];
	for (NSDictionary *entry in layout) {
		[menuItems addObject:entry[FxGripDebugLayoutLabelKey]];
	}
	return [menuItems copy];
}

// The command set does not depend on the unhide label, so a single layout resolves the index.
- (FxGripDebugCommand)commandForSelection:(NSInteger)selection
{
	NSArray<NSDictionary*> *layout = [self debugMenuLayout:NO];
	if (selection < 0 || (NSUInteger)selection >= layout.count) {
		return FxGripDebugCommand_None;
	}
	return (FxGripDebugCommand)((NSNumber*)layout[selection][FxGripDebugLayoutCommandKey]).unsignedIntegerValue;
}

@end



@implementation FxGripTileableEffect (DebugMenu)

- (FxGripDebugMenu *)debugMenu
{
	return [self extensionForClass:FxGripDebugMenu.class];
}

- (BOOL)allowsDebugFeatures
{
	return YES;
}

- (BOOL)pluginDebugMenuEnabled
{
	return self.allowsDebugFeatures && self.pluginProperties.pluginDebugMenu;
}

- (BOOL)pluginDebugActivatorEnabled
{
	return self.allowsDebugFeatures && self.pluginProperties.pluginDebugActivator;
}

- (BOOL)hasDebugMenu
{
	return self.pluginDebugMenuEnabled || self.pluginDebugActivatorEnabled;
}

- (nonnull FxGripDebugMenu *)newDebugMenuExtension
{
	return [FxGripDebugMenu.alloc init];
}

@end
