//
//
//  FxGripPresetsAPI_v1.m
//  FxGrip
//

#import <AppKit/AppKit.h>
#import "FxGripPresetsAPI_v1.h"
#import "FxGripAPIAccessing.h"
#import "FxGripTileableEffect.h"
#import "FxGripParameterTagsAPI_v1.h"
#import "FxGripParameterTagsAPI_v1.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "FxGripPluginInfo.h"
#import "FxGripParameterFlags.h"
#import "FxGripMetaManager.h"
#import "FxGripMeta.h"
#import "FxGripErrors.h"
#import <BEFoundation/BEPathWatcher.h>
#import "FxGrip_ARC.h"


/*! A display name from the plist is a string or a per-language dictionary; take the
	string, or the "English" entry, or any entry. */
static NSString *FxGripDisplayNameString(id displayName)
{
	if ([displayName isKindOfClass:NSString.class]) {
		return displayName;
	}
	if ([displayName isKindOfClass:NSDictionary.class]) {
		NSDictionary *names = displayName;
		NSString *english = names[@"English"];
		if ([english isKindOfClass:NSString.class]) {
			return english;
		}
		for (id value in names.allValues) {
			if ([value isKindOfClass:NSString.class]) {
				return value;
			}
		}
	}
	return nil;
}

/*! Folder names derive from display names; path separators cannot survive. */
static NSString *FxGripFolderNameString(NSString *name)
{
	NSString *cleaned = [name stringByReplacingOccurrencesOfString:@"/" withString:@"-"];
	return [cleaned stringByReplacingOccurrencesOfString:@":" withString:@"-"];
}


@implementation FxGripPresetsAPI_v1

- (nullable instancetype)initWithAPI:(id<FxGripPresetsAPI_v1>_Nullable)api
							  effect:(id<FxGripEffectHost>_Nonnull)effect
{
	self = [super initWithEffect:effect];

	if (self != nil)
	{
		_api = api;
	}
	return self;
}

- (NSError*)errorWithDescription:(NSString*)description
{
	return [NSError errorWithDomain:FxGripPlugErrorDomain
							   code:kFxGripError_Preset
						   userInfo:@{NSLocalizedFailureReasonErrorKey: description}];
}


#pragma mark Compatibility

- (BOOL)compatiblePreset:(FxGripPreset * _Nullable)preset
{
	NSString *presetUuid = preset.pluginUuid;
	if (![presetUuid isKindOfClass:NSString.class] || presetUuid.length == 0) {
		return NO;
	}
	id<FxGripEffectHost> effect = self.effect;
	if ([presetUuid caseInsensitiveCompare:FxGripHostPluginUUID(effect)] == NSOrderedSame) {
		return YES;
	}
	NSArray *alternatives = FxGripHostPluginProperties(effect)[kProPlugPlugIn_SupportedPluginsProperty];
	if (![alternatives isKindOfClass:NSArray.class]) {
		return NO;
	}
	for (id alternative in alternatives) {
		if ([alternative isKindOfClass:NSString.class]
			&& [presetUuid caseInsensitiveCompare:alternative] == NSOrderedSame) {
			return YES;
		}
	}
	return NO;
}


#pragma mark Apply

- (NSError * _Nullable)setPreset:(FxGripPreset * _Nonnull)preset options:(FxGripParameterPresetFlags)flags
{
	return [self setPreset:preset options:flags atTime:kCMTimeZero];
}

- (NSError * _Nullable)setPreset:(FxGripPreset * _Nonnull)preset options:(FxGripParameterPresetFlags)flags atTime:(CMTime)time
{
	if (preset == nil) {
		return [self errorWithDescription:@"No preset to apply."];
	}
	if (!(flags & kFxParameterPreset_IgnoreCompatibility) && ![self compatiblePreset:preset]) {
		return [self errorWithDescription:@"The preset belongs to another plugin."];
	}

	id<FxGripEffectHost> effect = self.effect;
	id<FxGripParameterTagsAPI_v1> tagsAPI = effect.apiManager.paramTagsAPIv1;
	if (tagsAPI == nil) {
		return [self errorWithDescription:@"The tag API is unavailable."];
	}

	FxGripPresetOptions options = FxGripPresetValues | FxGripPresetTags | FxGripPresetMeta;
	if (flags & kFxParameterPreset_IgnoreMetaData) {
		options &= ~FxGripPresetMeta;
	}

	return [(FxGripParameterTagsAPI_v1*)tagsAPI applyPreset:preset.presetSections
													  atTime:time
													 options:options
												 presetFlags:flags
													  source:FxGripPresetSourceFile
														 tag:preset.tag];
}


#pragma mark Capture

- (NSError * _Nullable)generatePreset:(FxGripPreset * _Nullable * _Nonnull)preset fromLabel:(NSString * _Nonnull)label
{
	if (preset == NULL) {
		return [self errorWithDescription:@"No preset out-parameter."];
	}
	*preset = nil;

	id<FxGripEffectHost> effect = self.effect;
	id<FxParameterSettingAPI_v5> setterAPI = effect.apiManager.paramSetAPIv5;
	id<FxParameterRetrievalAPI_v6> getterAPI = effect.apiManager.paramGetAPIv6;
	if (setterAPI == nil || getterAPI == nil) {
		return [self errorWithDescription:@"The parameter APIs are unavailable."];
	}
	id<FxGripParameterTagsAPI_v1> tagsAPI = effect.apiManager.paramTagsAPIv1;

	NSMutableDictionary *values = [NSMutableDictionary dictionary];
	NSMutableDictionary *tags = [NSMutableDictionary dictionary];
	NSMutableDictionary *meta = [NSMutableDictionary dictionary];

	for (NSNumber *pid in [effect.effectBase.parameters.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
		FxParameterId parameterID = pid.unsignedIntValue;

		FxParameterFlags parameterFlags = 0;
		[getterAPI getParameterFlags:&parameterFlags fromParameter:parameterID];

		id value = nil;
		if (!flagNoValue(parameterFlags)
			&& [FxGripPreset getParameterValue:&value toParameter:parameterID atTime:kCMTimeZero withAPI:setterAPI] && value != nil) {
			values[pid.stringValue] = value;
		}

		if (!flagNoTags(parameterFlags)) {
			NSArray *parameterTags = [tagsAPI parameterTags:parameterID];
			if (parameterTags.count > 0) {
				tags[pid.stringValue] = parameterTags;
			}
		}
		if (!flagNoMeta(parameterFlags) && self.hostHasMeta) {
			NSDictionary *parameterMeta = nil;
			if ([self.hostMeta getMeta:&parameterMeta fromParameter:parameterID] == nil && parameterMeta.count > 0) {
				meta[pid.stringValue] = parameterMeta;
			}
		}
	}

	FxGripPreset *generated = NARC_AUTORELEASE([FxGripPreset.alloc init]);
	generated.name = label;
	generated.uuid = NSUUID.UUID.UUIDString;
	generated.framework = @"FxGrip";
	NSISO8601DateFormatter *formatter = NARC_AUTORELEASE([NSISO8601DateFormatter.alloc init]);
	generated.createdTime = [formatter stringFromDate:NSDate.date];
	generated.parameterValues = values;
	generated.parameterTags = tags.count > 0 ? tags : nil;
	generated.parameterMeta = meta.count > 0 ? meta : nil;

	generated.pluginUuid = FxGripHostPluginUUID(effect);
	generated.pluginLocalizedName = FxGripHostPluginProperties(effect)[kProPlugPlugIn_DisplayNameProperty];
	generated.pluginVersion = [FxGripHostPluginProperties(effect)[kProPlugPlugIn_VersionProperty] description];
	generated.pluginAuthor = [self pluginCompanyName];

	*preset = generated;
	return nil;
}


#pragma mark Locations

/*! The plugin group's display name, resolved from the plugin info group list. */
- (nullable NSString*)pluginCompanyName
{
	id<FxGripEffectHost> effect = self.effect;
	NSString *groupUUID = FxGripHostPluginProperties(effect)[kProPlugPlugIn_GroupUUIDProperty];
	if ([groupUUID isKindOfClass:NSString.class]) {
		for (NSDictionary *group in FxGripPluginInfo.plugInGroups) {
			if (![group isKindOfClass:NSDictionary.class]) {
				continue;
			}
			NSString *uuid = group[kProPlugPlugIn_UuidProperty];
			if ([uuid isKindOfClass:NSString.class]
				&& [uuid caseInsensitiveCompare:groupUUID] == NSOrderedSame) {
				NSString *name = FxGripDisplayNameString(group[kProPlugPlugIn_DisplayNameProperty]);
				if (name.length > 0) {
					return name;
				}
			}
		}
		return groupUUID;
	}
	return nil;
}

- (nullable NSString*)pluginFolderName
{
	id<FxGripEffectHost> effect = self.effect;
	NSString *name = FxGripDisplayNameString(FxGripHostPluginProperties(effect)[kProPlugPlugIn_DisplayNameProperty]);
	if (name.length == 0) {
		name = FxGripHostPluginProperties(effect)[kProPlugPlugIn_ClassNameProperty];
	}
	return [name isKindOfClass:NSString.class] ? name : nil;
}

- (NSURL * _Nullable)userPresetURL
{
	NSString *company = [self pluginCompanyName] ?: @"FxGrip";
	NSString *pluginName = [self pluginFolderName];
	if (pluginName == nil) {
		return nil;
	}
	NSURL *support = [NSFileManager.defaultManager URLForDirectory:NSApplicationSupportDirectory
														  inDomain:NSUserDomainMask
												 appropriateForURL:nil
															create:NO
															 error:NULL];
	if (support == nil) {
		return nil;
	}
	return [[support URLByAppendingPathComponent:FxGripFolderNameString(company) isDirectory:YES]
			URLByAppendingPathComponent:FxGripFolderNameString(pluginName) isDirectory:YES];
}

- (NSURL * _Nullable)userPresetURL:(NSString * _Nonnull)tag
{
	if (tag.length == 0) {
		return nil;
	}
	return [[self userPresetURL] URLByAppendingPathComponent:FxGripFolderNameString(tag) isDirectory:YES];
}

- (NSURL * _Nullable)pluginPresetURL
{
	NSBundle *bundle = [NSBundle bundleForClass:self.effect.class];
	NSURL *presets = [bundle.resourceURL URLByAppendingPathComponent:@"Presets" isDirectory:YES];
	if (presets == nil || ![NSFileManager.defaultManager fileExistsAtPath:presets.path]) {
		return nil;
	}
	return presets;
}

- (NSURL * _Nullable)pluginPresetURL:(NSString * _Nonnull)tag
{
	if (tag.length == 0) {
		return nil;
	}
	return [[self pluginPresetURL] URLByAppendingPathComponent:FxGripFolderNameString(tag) isDirectory:YES];
}


#pragma mark Listings

/*! Loads every .fxpreset in a folder, sorted by file name for a stable listing. A file
	that names no tag applies under the folder's tag. */
- (NSArray<FxGripPreset*>*)presetFilesAtURL:(NSURL*)folderURL tag:(NSString*)tag
{
	if (folderURL == nil) {
		return @[];
	}
	NSArray<NSURL*> *contents = [NSFileManager.defaultManager contentsOfDirectoryAtURL:folderURL
															includingPropertiesForKeys:nil
																			   options:NSDirectoryEnumerationSkipsHiddenFiles
																				 error:NULL];
	NSArray<NSURL*> *sorted = [contents sortedArrayUsingComparator:^NSComparisonResult(NSURL *a, NSURL *b) {
		return [a.lastPathComponent localizedStandardCompare:b.lastPathComponent];
	}];

	NSMutableArray *presets = [NSMutableArray array];
	for (NSURL *fileURL in sorted) {
		if ([fileURL.pathExtension caseInsensitiveCompare:kFxPreset_Extension] != NSOrderedSame) {
			continue;
		}
		FxGripPreset *preset = [FxGripPreset loadPresetFromURL:fileURL];
		if (preset == nil) {
			continue;
		}
		if (preset.tag == nil) {
			preset.tag = tag;
		}
		if (preset.name == nil) {
			preset.name = fileURL.lastPathComponent.stringByDeletingPathExtension;
		}
		[presets addObject:preset];
	}
	return presets;
}

/*! Converts one plist preset definition to the model. Flags and names sections apply
	through automatic rigging only and are not carried. */
- (nullable FxGripPreset*)presetFromDefinition:(NSDictionary*)definition name:(NSString*)name tag:(NSString*)tag
{
	if (![definition isKindOfClass:NSDictionary.class]) {
		return nil;
	}
	id<FxGripEffectHost> effect = self.effect;
	FxGripPreset *preset = NARC_AUTORELEASE([FxGripPreset.alloc init]);
	preset.name = name;
	preset.tag = tag;
	preset.framework = @"FxGrip";
	preset.pluginUuid = FxGripHostPluginUUID(effect);
	preset.parameterValues = definition[kFxParameterProperty_TargetPresetValues];
	preset.parameterTags = definition[kFxParameterProperty_TargetPresetTags];
	preset.parameterMeta = definition[kFxParameterProperty_TargetPresetMeta];
	return preset;
}

/*! A definition dictionary carries section keys; a name-keyed table carries definitions. */
- (BOOL)isPresetDefinition:(NSDictionary*)dictionary
{
	return dictionary[kFxParameterProperty_TargetPresetValues] != nil
		|| dictionary[kFxParameterProperty_TargetPresetFlags] != nil
		|| dictionary[kFxParameterProperty_TargetPresetTags] != nil
		|| dictionary[kFxParameterProperty_TargetPresetMeta] != nil
		|| dictionary[kFxParameterProperty_TargetPresetNames] != nil;
}

- (NSArray<FxGripPreset*> * _Nonnull)pluginPresetsForTag:(NSString * _Nonnull)tag
{
	if (tag.length == 0) {
		return @[];
	}
	NSMutableArray *presets = [NSMutableArray array];

	id<FxGripEffectHost> effect = self.effect;
	NSDictionary *table = FxGripHostPluginProperties(effect)[kProPlugPlugInX_PresetsProperty];
	id entry = [table isKindOfClass:NSDictionary.class] ? table[tag] : nil;
	if ([entry isKindOfClass:NSDictionary.class]) {
		if ([self isPresetDefinition:entry]) {
			FxGripPreset *preset = [self presetFromDefinition:entry name:tag tag:tag];
			if (preset != nil) {
				[presets addObject:preset];
			}
		} else {
			// Name-keyed additive table: each entry is a named definition. String
			// entries alias other tags and do not list.
			for (NSString *name in [[entry allKeys] sortedArrayUsingSelector:@selector(localizedStandardCompare:)]) {
				FxGripPreset *preset = [self presetFromDefinition:entry[name] name:name tag:tag];
				if (preset != nil) {
					[presets addObject:preset];
				}
			}
		}
	}

	[presets addObjectsFromArray:[self presetFilesAtURL:[self pluginPresetURL:tag] tag:tag]];
	return presets;
}

- (NSArray<FxGripPreset*> * _Nonnull)userPresetsForTag:(NSString * _Nonnull)tag
{
	if (tag.length == 0) {
		return @[];
	}
	return [self presetFilesAtURL:[self userPresetURL:tag] tag:tag];
}

- (NSArray<FxGripPreset*> * _Nonnull)presetsForTag:(NSString * _Nonnull)tag
{
	NSMutableArray *presets = [NSMutableArray arrayWithArray:[self pluginPresetsForTag:tag]];
	[presets addObjectsFromArray:[self userPresetsForTag:tag]];
	return presets;
}

- (BEPathWatcher * _Nullable)observeTag:(NSString * _Nonnull)tag observer:(void (^ _Nonnull)(void))handler
{
	NSURL *folderURL = [self userPresetURL:tag];
	if (folderURL == nil || handler == nil
		|| ![NSFileManager.defaultManager fileExistsAtPath:folderURL.path]) {
		return nil;
	}
	BEPathWatcher *watcher = NARC_AUTORELEASE([BEPathWatcher.alloc initWithBlock:^(BEPathWatcher *unused, unsigned long event) {
		handler();
	}]);
	if (![watcher watchPath:folderURL.path]) {
		return nil;
	}
	return watcher;
}


#pragma mark Panels

- (BOOL)savePreset:(FxGripPreset * _Nonnull)preset remap:(NSDictionary * _Nullable)keyMap
{
	if (preset == nil) {
		return NO;
	}
	NSURL *folderURL = [self userPresetURL];
	if (folderURL != nil) {
		[NSFileManager.defaultManager createDirectoryAtURL:folderURL
							   withIntermediateDirectories:YES
												attributes:nil
													 error:NULL];
	}

	NSSavePanel *panel = [NSSavePanel savePanel];
// allowedContentTypes needs the UniformTypeIdentifiers framework, which the target does
	// not link; the deprecated string form is retained deliberately.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
	panel.allowedFileTypes = @[kFxPreset_Extension];
#pragma clang diagnostic pop
	panel.canCreateDirectories = YES;
	if (folderURL != nil) {
		panel.directoryURL = folderURL;
	}
	if (preset.name.length > 0) {
		panel.nameFieldStringValue = preset.name;
	}
	if ([panel runModal] != NSModalResponseOK || panel.URL == nil) {
		return NO;
	}
	return [preset savePresetToURL:panel.URL];
}

- (BOOL)loadPreset:(FxGripPreset * _Nullable * _Nonnull)preset remap:(NSDictionary * _Nullable)keyMap
{
	if (preset == NULL) {
		return NO;
	}
	*preset = nil;

	NSOpenPanel *panel = [NSOpenPanel openPanel];
// allowedContentTypes needs the UniformTypeIdentifiers framework, which the target does
	// not link; the deprecated string form is retained deliberately.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
	panel.allowedFileTypes = @[kFxPreset_Extension];
#pragma clang diagnostic pop
	panel.allowsMultipleSelection = NO;
	panel.canChooseDirectories = NO;
	NSURL *folderURL = [self userPresetURL];
	if (folderURL != nil && [NSFileManager.defaultManager fileExistsAtPath:folderURL.path]) {
		panel.directoryURL = folderURL;
	}
	if ([panel runModal] != NSModalResponseOK || panel.URL == nil) {
		return NO;
	}
	*preset = [FxGripPreset loadPresetFromURL:panel.URL];
	return *preset != nil;
}

@end
