//
//  FxGripPresetsParameter.m
//  FxGrip
//

#import <AppKit/AppKit.h>
#import "FxGripPresetsParameter.h"
#import "FxGripTileableEffect.h"
#import "FxGripTileableEffect+Notifications.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "FxGripAPIAccessing.h"
#import "FxGripPresetsAPI_v1.h"
#import "FxGripParameterData.h"
#import "FxGripMeta.h"
#import "FxGripMetaManager.h"
#import "FxGripOOBParameterAccess.h"
#import <BEFoundation/NSNotification+MutableUserInfo.h>
#import <BEFoundation/BEPathWatcher.h>
#import "FxGrip_ARC.h"

@interface FxGripPresetsParameter ()
{
	BEPathWatcher *_userPresetWatcher;
}

- (void)notifyPresetsParameterChanged:(nonnull NSNotification *)notification;
- (void)userPresetFolderChanged:(nonnull BEPathWatcher *)watcher;

@end


@implementation FxGripPresetsParameter

#pragma mark Host guards

/*! The meta extension is an optional host member; a minimal host records no selection. */
- (BOOL)hostHasMeta:(id<FxGripEffectHost>)effect
{
	return FxGripHostHasMeta(effect);
}

/*! The parameter-data stored menus, or nil for a host without the extension. */
- (nullable NSArray *)hostParameterDataMenusOf:(id<FxGripEffectHost>)effect
{
	return [FxGripHostParameterData(effect) storedMenus:self.parameterID];
}

+ (nullable NSString*)parameterTypeString
{
	return kFxParameterType_Presets;
}

+ (FxParameterType)parameterType
{
	return FxParameterType_Presets;
}

+ (nullable NSString*)presetTagForParameter:(nonnull NSDictionary*)parameter
{
	NSArray *tags = parameter.parameterTags;
	NSString *tag = tags.firstObject;
	return [tag isKindOfClass:NSString.class] ? tag : nil;
}

+ (NSArray<NSString*>*)presetNames:(NSArray<FxGripPreset*>*)presets
{
	NSMutableArray *names = [NSMutableArray arrayWithCapacity:presets.count];
	for (FxGripPreset *preset in presets) {
		if ([preset.name isKindOfClass:NSString.class] && preset.name.length > 0) {
			[names addObject:preset.name];
		}
	}
	return names;
}

+ (nonnull NSArray<NSString*>*)menuEntriesForParameter:(nonnull NSDictionary*)parameter
											    effect:(nonnull id<FxGripEffectHost>)effect
{
	NSString *tag = [self presetTagForParameter:parameter];
	id<FxGripPresetsAPI_v1> presetsAPI = effect.apiManager.presetsAPIv1;

	NSMutableArray *entries = [NSMutableArray arrayWithObject:NSLocalizedString(kFxPresetsMenuEntry_Default, kFxPresetsMenuEntry_Default)];
	if (tag != nil && presetsAPI != nil) {
		NSArray *userNames = [self presetNames:[presetsAPI userPresetsForTag:tag]];
		if (userNames.count > 0) {
			[entries addObject:kFxPresetsMenuEntry_Separator];
			[entries addObjectsFromArray:userNames];
		}
		NSArray *pluginNames = [self presetNames:[presetsAPI pluginPresetsForTag:tag]];
		if (pluginNames.count > 0) {
			[entries addObject:kFxPresetsMenuEntry_Separator];
			[entries addObjectsFromArray:pluginNames];
		}
	}
	[entries addObject:kFxPresetsMenuEntry_Separator];
	[entries addObject:NSLocalizedString(kFxPresetsMenuEntry_Reveal, kFxPresetsMenuEntry_Reveal)];
	[entries addObject:NSLocalizedString(kFxPresetsMenuEntry_Save, kFxPresetsMenuEntry_Save)];
	return entries;
}

+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect
{
	return [effect.apiManager.paramCreateAPIv5 addPopupMenuWithName: parameter.parameterName
														parameterID: parameter.parameterID
													   defaultValue: 0
														menuEntries: [self menuEntriesForParameter:parameter effect:effect]
													 parameterFlags: parameter.parameterFlags];
}


#pragma mark Selection Handling

- (void)installNotifications
{
	[super installNotifications];
	[self.effect.notifier addObserver:self
							 selector:@selector(notifyPresetsParameterChanged:)
								 name:FxGripTileableEffectParameterChangedName
							   object:self.effect];
	[self attachUserPresetWatcher];
}

- (void)removeObservers
{
	if (_userPresetWatcher != nil) {
		_userPresetWatcher.isActive = NO;
		NARC_RELEASE(_userPresetWatcher);
	}
	[super removeObservers];
}


#pragma mark Live Menu Refresh

/*!
	Watches the managed per-tag user preset folder; the watcher holds its target weakly
	and this parameter retains the watcher, so no cycle forms. The folder may not exist
	yet; the reveal and save actions re-attach after creating it.
*/
- (void)attachUserPresetWatcher
{
	// A watcher stops for good when its folder is deleted or renamed; a stopped watcher
	// is discarded so a fresh one can attach to the recreated folder.
	if (_userPresetWatcher != nil && !_userPresetWatcher.isActive) {
		NARC_RELEASE(_userPresetWatcher);
	}
	if (_userPresetWatcher != nil) {
		return;
	}
	NSString *tag = [self.class presetTagForParameter:_data];
	if (tag == nil) {
		return;
	}
	id<FxGripPresetsAPI_v1> presetsAPI = self.effect.apiManager.presetsAPIv1;
	NSURL *folderURL = [presetsAPI userPresetURL:tag];
	if (folderURL == nil || ![NSFileManager.defaultManager fileExistsAtPath:folderURL.path]) {
		return;
	}
	BEPathWatcher *watcher = [BEPathWatcher.alloc init];
	if ([watcher watchPath:folderURL.path target:self selector:@selector(userPresetFolderChanged:)]) {
		_userPresetWatcher = watcher;
	} else {
		NARC_RELEASE_RAW(watcher);
	}
}

// Filesystem events arrive off the host's threads; the refresh runs on the main queue
// inside an out-of-band access context.
- (void)userPresetFolderChanged:(nonnull BEPathWatcher *)watcher
{
	dispatch_async(dispatch_get_main_queue(), ^{
		[self refreshMenuEntriesAtTime:kCMTimeZero];
	});
}

/*! Rebuilds the menu on the host and remaps the recorded selection name to its new
	index, so a changed entry list cannot corrupt the selection. */
- (void)refreshMenuEntriesAtTime:(CMTime)time
{
	id<FxGripEffectHost> effect = self.effect;
	FxGripOOBParameterAccess *__attribute__((unused)) accessor = [FxGripOOBParameterAccess access:effect];

	NSArray *entries = [self.class menuEntriesForParameter:_data effect:effect];
	NSError *error = [effect.apiManager.dynamicParamAPIv3 setPopupMenuParameter:self.parameterID
																		 entries:entries
																	defaultValue:0];
	if (error != nil) {
		NSLog(@"%s Error: could not refresh the preset menu for parameter %d: %@", __func__, self.parameterID, error);
		return;
	}
	[self restoreSelectionAtTime:time];
}

// After the meta trigger (-10) has run its target-preset pass.
- (NSInteger)ncPriority:(nullable NSNotificationName)aName
{
	if ([FxGripTileableEffectParameterChangedName isEqualToString:aName]) {
		return -8;
	}
	return [super ncPriority:aName];
}

/*! The live menu recorded by FxGripParameterData wins over a rebuild, so entries that
	drifted since creation resolve by their recorded position. */
- (nullable NSString*)menuEntryNameAtIndex:(int)index
{
	if (index < 0) {
		return nil;
	}
	id<FxGripEffectHost> effect = self.effect;
	NSArray *entries = [self hostParameterDataMenusOf:effect];
	if (![entries isKindOfClass:NSArray.class]) {
		entries = [self.class menuEntriesForParameter:_data effect:effect];
	}
	if ((NSUInteger)index >= entries.count) {
		return nil;
	}
	NSString *name = entries[index];
	return [name isKindOfClass:NSString.class] ? name : nil;
}

/*! User presets shadow plugin presets of the same name, matching the menu order. */
- (nullable FxGripPreset*)presetNamed:(NSString*)name
{
	NSString *tag = [self.class presetTagForParameter:_data];
	if (tag == nil) {
		return nil;
	}
	id<FxGripPresetsAPI_v1> presetsAPI = self.effect.apiManager.presetsAPIv1;
	for (FxGripPreset *preset in [presetsAPI userPresetsForTag:tag]) {
		if ([preset.name isEqualToString:name]) {
			return preset;
		}
	}
	for (FxGripPreset *preset in [presetsAPI pluginPresetsForTag:tag]) {
		if ([preset.name isEqualToString:name]) {
			return preset;
		}
	}
	return nil;
}

- (void)recordSelectedPresetName:(NSString*)name
{
	id<FxGripEffectHost> effect = self.effect;
	if (![self hostHasMeta:effect]) {
		return;
	}
	[FxGripHostMeta(effect) setMeta:name forKey:kFxMetaProperty_SelectedPreset toParameter:self.parameterID];
}

/*! Restores the recorded selection after an action entry, falling back to Default. */
- (void)restoreSelectionAtTime:(CMTime)time
{
	int index = 0;
	id<FxGripEffectHost> effect = self.effect;
	if ([self hostHasMeta:effect]) {
		NSObject<NSSecureCoding, NSCopying> *recorded = nil;
		[FxGripHostMeta(effect) getMeta:&recorded forKey:kFxMetaProperty_SelectedPreset fromParameter:self.parameterID];
		if ([recorded isKindOfClass:NSString.class]) {
			NSArray *entries = [self hostParameterDataMenusOf:effect];
			if (![entries isKindOfClass:NSArray.class]) {
				entries = [self.class menuEntriesForParameter:_data effect:effect];
			}
			NSUInteger recordedIndex = [entries indexOfObject:recorded];
			if (recordedIndex != NSNotFound) {
				index = (int)recordedIndex;
			}
		}
	}
	[effect.apiManager.paramSetAPIv5 setIntValue:index toParameter:self.parameterID atTime:time];
}

- (void)revealUserPresetsAtTime:(CMTime)time
{
	id<FxGripPresetsAPI_v1> presetsAPI = self.effect.apiManager.presetsAPIv1;
	NSString *tag = [self.class presetTagForParameter:_data];
	NSURL *folderURL = tag != nil ? [presetsAPI userPresetURL:tag] : [presetsAPI userPresetURL];
	if (folderURL != nil) {
		[NSFileManager.defaultManager createDirectoryAtURL:folderURL
							   withIntermediateDirectories:YES
												attributes:nil
													 error:NULL];
		[NSWorkspace.sharedWorkspace activateFileViewerSelectingURLs:@[folderURL]];
	}
	[self attachUserPresetWatcher];
	[self restoreSelectionAtTime:time];
}

- (void)saveCurrentStateAsPresetAtTime:(CMTime)time
{
	id<FxGripPresetsAPI_v1> presetsAPI = self.effect.apiManager.presetsAPIv1;
	FxGripPreset *preset = nil;
	NSError *error = [presetsAPI generatePreset:&preset fromLabel:self.parameterName ?: @"Preset"];
	if (error == nil && preset != nil) {
		preset.tag = [self.class presetTagForParameter:_data];
		if ([presetsAPI savePreset:preset remap:nil]) {
			// A watcher attached only now missed the write event; refresh explicitly.
			// refreshMenuEntriesAtTime: also restores the selection.
			[self attachUserPresetWatcher];
			[self refreshMenuEntriesAtTime:time];
			return;
		}
	} else {
		NSLog(@"%s Error: could not capture the preset: %@", __func__, error);
	}
	[self restoreSelectionAtTime:time];
}

- (void)notifyPresetsParameterChanged:(nonnull NSNotification *)notification
{
	NSNumber *pid = notification.userInfo[FxGripTileableEffectParameterChangedIDKey];
	if (![pid isKindOfClass:NSNumber.class] || pid.unsignedIntValue != self.parameterID) {
		return;
	}
	CMTime time = kCMTimeZero;
	NSDictionary *timeDict = notification.userInfo[FxGripTileableEffectParameterChangedAtTimeKey];
	if ([timeDict isKindOfClass:NSDictionary.class]) {
		time = CMTimeMakeFromDictionary((__bridge CFDictionaryRef)timeDict);
	}

	id<FxGripEffectHost> effect = self.effect;
	int index = 0;
	if (![effect.apiManager.paramGetAPIv6 getIntValue:&index fromParameter:self.parameterID atTime:time]) {
		return;
	}

	NSString *entry = [self menuEntryNameAtIndex:index];
	if (entry == nil || [entry isEqualToString:kFxPresetsMenuEntry_Separator]) {
		return;
	}
	if ([entry isEqualToString:NSLocalizedString(kFxPresetsMenuEntry_Reveal, kFxPresetsMenuEntry_Reveal)]) {
		[self revealUserPresetsAtTime:time];
		return;
	}
	if ([entry isEqualToString:NSLocalizedString(kFxPresetsMenuEntry_Save, kFxPresetsMenuEntry_Save)]) {
		[self saveCurrentStateAsPresetAtTime:time];
		return;
	}
	if ([entry isEqualToString:NSLocalizedString(kFxPresetsMenuEntry_Default, kFxPresetsMenuEntry_Default)]) {
		[self recordSelectedPresetName:entry];
		return;
	}

	FxGripPreset *preset = [self presetNamed:entry];
	if (preset == nil) {
		NSLog(@"%s Error: no preset named %@ for parameter %d.", __func__, entry, self.parameterID);
		return;
	}
	id<FxGripPresetsAPI_v1> presetsAPI = effect.apiManager.presetsAPIv1;
	NSError *error = [presetsAPI setPreset:preset options:kFxParameterPreset_Default atTime:time];
	if (error != nil) {
		NSLog(@"%s Error: could not apply the preset %@: %@", __func__, entry, error);
		return;
	}
	[self recordSelectedPresetName:entry];
}

@end
