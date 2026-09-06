//
//  FxGripAboutMenu.m
//  FxGrip
//
//  Copyright © 2024 Belisoful All rights reserved.
//

#import <AppKit/AppKit.h>
#import "FxGripAboutMenu.h"
#import "FxGripTileableEffect.h"
#import "FxGripTileableEffect+Extensions.h"
#import "FxGripTileableEffect+Notifications.h"
#import "FxGripParameterFlags.h"
#import "FxGripPluginInfo.h"
#import "NSDictionary+FxGripTileableEffect.h"

NSString*	const _Nonnull FxGripAboutMenuExtensionKey = @"FxGripAboutMenu";

NSNotificationName const _Nonnull FxGripAboutMenuLinkName = @"FxGripAboutMenuLink";
NSString* const _Nonnull FxGripAboutMenuLinkURLKey = @"FxGripAboutMenuLinkURL";

NSString* const _Nonnull FxGripAboutMenuItemsKey = @"items";
NSString* const _Nonnull FxGripAboutMenuMainTextKey = @"mainText";
NSString* const _Nonnull FxGripAboutMenuNameKey = @"name";
NSString* const _Nonnull FxGripAboutMenuAgreementIdKey = @"agreementId";
NSString* const _Nonnull FxGripAboutMenuAgreementAcceptedValueKey = @"agreementAcceptedValue";
NSString* const _Nonnull FxGripAboutMenuWarningKey = @"warning";
NSString* const _Nonnull FxGripAboutMenuWarningDialogTextKey = @"warningDialogText";
NSString* const _Nonnull FxGripAboutMenuFallbackUrlKey = @"fallbackUrl";

NSString* const _Nonnull FxGripAboutEntryLabelKey = @"label";
NSString* const _Nonnull FxGripAboutEntryKindKey = @"kind";
NSString* const _Nonnull FxGripAboutEntryUrlKey = @"url";
NSString* const _Nonnull FxGripAboutEntryFallbacksKey = @"fallbacks";
NSString* const _Nonnull FxGripAboutEntryDisplayIdKey = @"displayId";

NSString* const _Nonnull FxGripAboutEntryKindLink = @"link";
NSString* const _Nonnull FxGripAboutEntryKindSeparator = @"separator";
NSString* const _Nonnull FxGripAboutEntryKindText = @"text";
NSString* const _Nonnull FxGripAboutEntryKindDialog = @"dialog";

// The action a resolved menu row performs when chosen. The layout pairs each displayed row
// with its action and, for a link, the ordered URLs to try; dispatch resolves the host's
// selection index against that same layout.
typedef NS_ENUM(NSUInteger, FxGripAboutAction) {
	FxGripAboutActionNone = 0,
	FxGripAboutActionLink,
	FxGripAboutActionDialog,
};

static NSString *const FxGripAboutLayoutLabelKey = @"label";
static NSString *const FxGripAboutLayoutActionKey = @"action";
static NSString *const FxGripAboutLayoutURLsKey = @"urls";

static NSString *const FxGripAboutMenuDefaultName = @"FxGrip::AboutMenu::Name";


@implementation FxGripAboutMenu

- (NSString*)extKey
{
	return FxGripAboutMenuExtensionKey;
}

- (BOOL)hasAboutMenu
{
	return self.effect.effectBase.hasAboutMenu;
}


#pragma mark Configuration reads

- (NSArray<NSDictionary*>*)configuredItems:(NSDictionary*)config
{
	id items = config[FxGripAboutMenuItemsKey];
	if (![items isKindOfClass:NSArray.class]) {
		return @[];
	}
	NSMutableArray<NSDictionary*> *out = [NSMutableArray arrayWithCapacity:((NSArray*)items).count];
	for (id item in (NSArray*)items) {
		if ([item isKindOfClass:NSDictionary.class]) {
			[out addObject:item];
		}
	}
	return out.copy;
}

- (NSArray<NSString*>*)stringArrayFrom:(id)value
{
	if (![value isKindOfClass:NSArray.class]) {
		return @[];
	}
	NSMutableArray<NSString*> *out = [NSMutableArray array];
	for (id string in (NSArray*)value) {
		if ([string isKindOfClass:NSString.class]) {
			[out addObject:string];
		}
	}
	return out.copy;
}

// A missing gate means accepted. A host read that fails is treated as accepted so a plugin is
// not locked out of its own About menu by a transient API failure.
- (BOOL)agreementAcceptedInConfig:(NSDictionary*)config atTime:(CMTime)time
{
	NSNumber *agreementId = config[FxGripAboutMenuAgreementIdKey];
	if (![agreementId isKindOfClass:NSNumber.class]) {
		return YES;
	}
	int value = 0;
	if (![self.effect.apiManager.paramGetAPIv6 getIntValue:&value fromParameter:agreementId.unsignedIntValue atTime:time]) {
		return YES;
	}
	NSNumber *accepted = config[FxGripAboutMenuAgreementAcceptedValueKey];
	int threshold = [accepted isKindOfClass:NSNumber.class] ? accepted.intValue : 1;
	return value >= threshold;
}

- (BOOL)entryDisplayed:(NSDictionary*)item atTime:(CMTime)time
{
	NSNumber *displayId = item[FxGripAboutEntryDisplayIdKey];
	if (![displayId isKindOfClass:NSNumber.class]) {
		return YES;
	}
	BOOL shown = NO;
	if (![self.effect.apiManager.paramGetAPIv6 getBoolValue:&shown fromParameter:displayId.unsignedIntValue atTime:time]) {
		return YES;
	}
	return shown;
}

- (NSString*)aboutWarningDialogText
{
	NSString *text = self.effect.effectBase.aboutMenuConfiguration[FxGripAboutMenuWarningDialogTextKey];
	return [text isKindOfClass:NSString.class] ? text : @"";
}


#pragma mark Layout

// readValues NO builds the baseline shown at parameter-add time, before parameter values
// exist: every gated entry is included and the agreement is treated as accepted. readValues
// YES consults the display gates and the agreement parameter for the live menu.
- (NSArray<NSDictionary*>*)aboutMenuLayoutReadingValues:(BOOL)readValues atTime:(CMTime)time
{
	NSMutableArray<NSDictionary*> *layout = [NSMutableArray array];
	NSDictionary *config = self.effect.effectBase.aboutMenuConfiguration;
	if (![config isKindOfClass:NSDictionary.class]) {
		return layout.copy;
	}

	void (^addRow)(NSString*, FxGripAboutAction, NSArray*) = ^(NSString *label, FxGripAboutAction action, NSArray *urls) {
		NSMutableDictionary *entry = [@{FxGripAboutLayoutLabelKey: label ?: @"-",
										FxGripAboutLayoutActionKey: @(action)} mutableCopy];
		if (urls) {
			entry[FxGripAboutLayoutURLsKey] = urls;
		}
		[layout addObject:entry.copy];
	};

	NSArray<NSString*> *warning = [self stringArrayFrom:config[FxGripAboutMenuWarningKey]];
	if (readValues && warning.count && ![self agreementAcceptedInConfig:config atTime:time]) {
		for (NSString *line in warning) {
			addRow(line, FxGripAboutActionDialog, nil);
		}
		addRow(@"-", FxGripAboutActionNone, nil);
	}

	NSString *mainText = config[FxGripAboutMenuMainTextKey];
	if ([mainText isKindOfClass:NSString.class] && mainText.length) {
		addRow(mainText, FxGripAboutActionNone, nil);
	}

	NSString *globalFallback = config[FxGripAboutMenuFallbackUrlKey];
	NSArray<NSDictionary*> *items = [self.effect.effectBase aboutMenuItems:[self configuredItems:config]];
	for (NSDictionary *item in items) {
		if (![item isKindOfClass:NSDictionary.class]) {
			continue;
		}
		if (readValues && ![self entryDisplayed:item atTime:time]) {
			continue;
		}
		NSString *kind = [item[FxGripAboutEntryKindKey] isKindOfClass:NSString.class] ? item[FxGripAboutEntryKindKey] : FxGripAboutEntryKindLink;
		NSString *label = item[FxGripAboutEntryLabelKey];
		if ([kind isEqualToString:FxGripAboutEntryKindSeparator]) {
			addRow(@"-", FxGripAboutActionNone, nil);
		} else if ([kind isEqualToString:FxGripAboutEntryKindText]) {
			addRow(label, FxGripAboutActionNone, nil);
		} else if ([kind isEqualToString:FxGripAboutEntryKindDialog]) {
			addRow(label, FxGripAboutActionDialog, nil);
		} else {
			NSMutableArray<NSString*> *urls = [NSMutableArray array];
			if ([item[FxGripAboutEntryUrlKey] isKindOfClass:NSString.class] && [item[FxGripAboutEntryUrlKey] length]) {
				[urls addObject:item[FxGripAboutEntryUrlKey]];
			}
			[urls addObjectsFromArray:[self stringArrayFrom:item[FxGripAboutEntryFallbacksKey]]];
			if ([globalFallback isKindOfClass:NSString.class] && [globalFallback length]) {
				[urls addObject:globalFallback];
			}
			addRow(label, FxGripAboutActionLink, urls.copy);
		}
	}
	return layout.copy;
}

- (NSArray<NSString*>*)aboutMenuItemsReadingValues:(BOOL)readValues atTime:(CMTime)time
{
	NSArray<NSDictionary*> *layout = [self aboutMenuLayoutReadingValues:readValues atTime:time];
	NSMutableArray<NSString*> *labels = [NSMutableArray arrayWithCapacity:layout.count];
	for (NSDictionary *entry in layout) {
		[labels addObject:entry[FxGripAboutLayoutLabelKey]];
	}
	return labels.copy;
}


#pragma mark Parameter registration

- (void)extAddParameters:(nonnull NSNotification*)notification
{
	if (!self.hasAboutMenu) {
		return;
	}
	NSMutableArray<NSMutableDictionary *> *parameters = notification.userInfo.fxEffectParameters;
	NSString *name = self.effect.effectBase.aboutMenuConfiguration[FxGripAboutMenuNameKey];
	if (![name isKindOfClass:NSString.class] || !name.length) {
		name = FxGripAboutMenuDefaultName;
	}
	NSDictionary *aboutMenuParameter = @{
		kFxParameterProperty_Factory: self,
		kFxParameterProperty_Id: @(kFxParameterId_AboutMenu),
		kFxParameterProperty_Type: kFxParameterType_Menu,
		kFxParameterProperty_Name: name,
		kFxParameterProperty_ResetValue: @0,
		kFxParameterProperty_MenuItems: [self aboutMenuItemsReadingValues:NO atTime:kCMTimeZero],
		kFxParameterProperty_Selector: @"manageAboutMenu",
		kFxParameterProperty_Flags: @[kParameterFlagString_NOT_ANIMATABLE, kParameterFlagString_NO_STATE]
	};
	[parameters addObject:[aboutMenuParameter mutableCopy]];
}

// The display gates and the agreement parameter change what the menu shows, so a change to any
// of them rebuilds the popup. Independent of FxGripMeta.
- (void)extParameterChanged:(nonnull NSNotification*)notification
{
	NSNumber *pidNumber = notification.userInfo[FxGripTileableEffectParameterChangedIDKey];
	if (![pidNumber isKindOfClass:NSNumber.class] || ![[self aboutMenuGatingParameterIDs] containsObject:pidNumber]) {
		return;
	}
	CMTime time = kCMTimeZero;
	NSDictionary *timeDict = notification.userInfo[FxGripTileableEffectParameterChangedAtTimeKey];
	if ([timeDict isKindOfClass:NSDictionary.class]) {
		time = CMTimeMakeFromDictionary((__bridge CFDictionaryRef)timeDict);
	}
	[self refreshAboutMenuAtTime:time];
}

- (NSSet<NSNumber*>*)aboutMenuGatingParameterIDs
{
	NSMutableSet<NSNumber*> *ids = [NSMutableSet set];
	NSDictionary *config = self.effect.effectBase.aboutMenuConfiguration;
	if ([config[FxGripAboutMenuAgreementIdKey] isKindOfClass:NSNumber.class]) {
		[ids addObject:config[FxGripAboutMenuAgreementIdKey]];
	}
	for (NSDictionary *item in [self configuredItems:config]) {
		if ([item[FxGripAboutEntryDisplayIdKey] isKindOfClass:NSNumber.class]) {
			[ids addObject:item[FxGripAboutEntryDisplayIdKey]];
		}
	}
	return ids.copy;
}

- (void)refreshAboutMenuAtTime:(CMTime)time
{
	NSArray<NSString*> *labels = [self aboutMenuItemsReadingValues:YES atTime:time];
	[self.effect.apiManager.dynamicParamAPIv3 setPopupMenuParameter:kFxParameterId_AboutMenu
															entries:[FxGripPluginInfo localizeObject:labels.localize]
													   defaultValue:0];
}


#pragma mark Selection

- (BOOL)manageAboutMenu:(FxParameterId)paramID
				 atTime:(CMTime)time
				  error:(NSError * _Nullable * _Nullable)error
{
	int selection = -1;
	if (![self.effect.apiManager.paramGetAPIv6 getIntValue:&selection fromParameter:paramID atTime:time]) {
		return NO;
	}

	NSArray<NSDictionary*> *layout = [self aboutMenuLayoutReadingValues:YES atTime:time];
	if (selection < 0 || (NSUInteger)selection >= layout.count) {
		return YES;
	}

	NSDictionary *entry = layout[selection];
	switch ((FxGripAboutAction)((NSNumber*)entry[FxGripAboutLayoutActionKey]).unsignedIntegerValue) {
		case FxGripAboutActionNone:
			break;
		case FxGripAboutActionLink:
			[self openAboutURLStrings:entry[FxGripAboutLayoutURLsKey]];
			break;
		case FxGripAboutActionDialog:
			[self showAboutDialogWithText:self.aboutWarningDialogText];
			break;
	}
	return YES;
}


#pragma mark Link and dialog primitives

// Overridable. Opens the first URL that succeeds, falling through the ordered list. The host
// completion handler runs off the main thread, so the recursion and the broadcast hop back.
- (void)openAboutURLStrings:(NSArray<NSString*>*)urlStrings
{
	NSMutableArray<NSURL*> *urls = [NSMutableArray array];
	for (NSString *string in urlStrings) {
		if ([string isKindOfClass:NSString.class] && string.length) {
			NSURL *url = [NSURL URLWithString:string];
			if (url) {
				[urls addObject:url];
			}
		}
	}
	if (urls.count == 0) {
		return;
	}
	[self openURLQueue:urls.copy atIndex:0];
}

- (void)openURLQueue:(NSArray<NSURL*>*)urls atIndex:(NSUInteger)index
{
	if (index >= urls.count) {
		return;
	}
	NSURL *url = urls[index];
	NSWorkspaceOpenConfiguration *config = [NSWorkspaceOpenConfiguration configuration];
	config.promptsUserIfNeeded = NO;
	__weak typeof(self) weakSelf = self;
	[[NSWorkspace sharedWorkspace] openURL:url configuration:config completionHandler:^(NSRunningApplication *app, NSError *openError) {
		if (openError) {
			[weakSelf openURLQueue:urls atIndex:index + 1];
		} else {
			[weakSelf broadcastAboutLink:url];
		}
	}];
}

- (void)broadcastAboutLink:(NSURL*)url
{
	FxGripTileableEffect *effect = self.effect.effectBase;
	NSString *urlString = url.absoluteString ?: @"";
	dispatch_async(dispatch_get_main_queue(), ^{
		[effect.notifier postNotificationName:FxGripAboutMenuLinkName
									   object:effect
									 userInfo:@{FxGripAboutMenuLinkURLKey: urlString}];
	});
}

// Overridable. Shows the warning presented until the agreement is accepted.
- (void)showAboutDialogWithText:(NSString*)text
{
	NSAlert *alert = [NSAlert.alloc init];
	alert.informativeText = text ?: @"";
	[alert addButtonWithTitle:NSLocalizedString(@"OK", nil)];
	[alert runModal];
}

@end



@implementation FxGripTileableEffect (AboutMenu)

- (FxGripAboutMenu *)aboutMenu
{
	return (FxGripAboutMenu*)[self extensionForClass:FxGripAboutMenu.class];
}

- (NSDictionary *)aboutMenuConfiguration
{
	return self.pluginProperties.pluginAboutMenu;
}

- (BOOL)hasAboutMenu
{
	return self.aboutMenuConfiguration != nil;
}

- (NSArray<NSDictionary*> *)aboutMenuItems:(NSArray<NSDictionary*> *)items
{
	return items;
}

- (FxGripAboutMenu *)newAboutMenuExtension
{
	return [FxGripAboutMenu.alloc init];
}

@end
