/*!
	@file       FxGripPresetsAPI_v1.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripPresetsAPI_v1
	@abstract   Implements preset capture, application, file I/O, discovery, and folder watching.
	@discussion Introduced in FxGrip 0.1.0. Capture reads every runtime parameter's value, tags,
	            and meta, honoring the per-parameter opt-out flags. Application checks compatibility
	            and hands the preset's sections to the tag API core. Discovery merges the plugin's
	            plist presets table and bundled files with the managed user folder. Folder and file
	            names derive from version-agnostic display names, so presets survive plugin updates.
*/

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


/*!
	@abstract	FxGrip's implementation of the preset file and discovery API.
	@discussion	Introduced in FxGrip 0.1.0. No host vends this API, so the wrapper carries no host
				API. Application delegates to the tag API core; discovery merges plugin and user
				sources; the save and open panels start in the managed user folder.
*/
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

/*! @abstract Builds a preset error in the FxGrip plugin domain from a failure description. */
- (NSError*)errorWithDescription:(NSString*)description
{
	return [NSError errorWithDomain:FxGripPlugErrorDomain
							   code:kFxGripError_Preset
						   userInfo:@{NSLocalizedFailureReasonErrorKey: description}];
}


#pragma mark Compatibility

/*!
	@method		compatiblePreset:
	@abstract	Answers whether a preset's plugin identity matches this effect.
	@discussion	Introduced in FxGrip 0.1.0. The preset's plugin UUID must equal the effect's, or
				appear in the plugin's supportedPlugins alternatives. The comparison is
				case-insensitive.
	@return		YES when the preset belongs to this plugin.
*/
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

/*! @abstract Applies a preset at time zero. */
- (NSError * _Nullable)setPreset:(FxGripPreset * _Nonnull)preset options:(FxGripParameterPresetFlags)flags
{
	return [self setPreset:preset options:flags atTime:kCMTimeZero];
}

/*!
	@method		setPreset:options:atTime:
	@abstract	Applies a preset through the tag API core.
	@discussion	Introduced in FxGrip 0.1.0. Verifies compatibility unless
				kFxParameterPreset_IgnoreCompatibility. Applies the values, tags, and meta
				sections, withholding meta under kFxParameterPreset_IgnoreMetaData, with
				FxGripPresetSourceFile and the preset's tag so the tag boundary governs which
				parameters change.
	@return		An error when the preset is nil, incompatible, or the tag API is unavailable;
				otherwise the first application error, or nil.
*/
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

/*!
	@method		generatePreset:fromLabel:
	@abstract	Captures the effect's current parameter state as a preset.
	@discussion	Introduced in FxGrip 0.1.0. Captures every runtime parameter's value at time zero,
				plus its tags and meta. A parameter flagged NoValue, PRESETNOTAGS, or PRESETNOMETA
				opts out of the matching capture. The plugin identity fields are filled from the
				effect.
	@return		An error when the out-parameter or the parameter APIs are unavailable; otherwise nil.
*/
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

/*! @abstract The plugin's display name for use as a folder name, falling back to its class name. */
- (nullable NSString*)pluginFolderName
{
	id<FxGripEffectHost> effect = self.effect;
	NSString *name = FxGripDisplayNameString(FxGripHostPluginProperties(effect)[kProPlugPlugIn_DisplayNameProperty]);
	if (name.length == 0) {
		name = FxGripHostPluginProperties(effect)[kProPlugPlugIn_ClassNameProperty];
	}
	return [name isKindOfClass:NSString.class] ? name : nil;
}

/*! @abstract The managed user preset folder under Application Support, keyed by company and plugin display names. The folder is not created here. */
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

/*! @abstract The per-tag subfolder of the managed user preset folder. */
- (NSURL * _Nullable)userPresetURL:(NSString * _Nonnull)tag
{
	if (tag.length == 0) {
		return nil;
	}
	return [[self userPresetURL] URLByAppendingPathComponent:FxGripFolderNameString(tag) isDirectory:YES];
}

/*! @abstract The plugin bundle's Presets resource folder, or nil when the bundle has none. */
- (NSURL * _Nullable)pluginPresetURL
{
	NSBundle *bundle = [NSBundle bundleForClass:self.effect.class];
	NSURL *presets = [bundle.resourceURL URLByAppendingPathComponent:@"Presets" isDirectory:YES];
	if (presets == nil || ![NSFileManager.defaultManager fileExistsAtPath:presets.path]) {
		return nil;
	}
	return presets;
}

/*! @abstract The per-tag subfolder of the bundled preset folder. */
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

/*!
	@method		pluginPresetsForTag:
	@abstract	The premade presets for a tag: the plist presets table entries, then bundled files.
	@discussion	Introduced in FxGrip 0.1.0. A plist table entry is a single definition or a
				name-keyed table of definitions; string entries alias other tags and do not list.
				Bundled .fxpreset files from the per-tag subfolder follow.
*/
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

/*! @abstract The user presets for a tag: .fxpreset files in the managed per-tag folder. */
- (NSArray<FxGripPreset*> * _Nonnull)userPresetsForTag:(NSString * _Nonnull)tag
{
	if (tag.length == 0) {
		return @[];
	}
	return [self presetFilesAtURL:[self userPresetURL:tag] tag:tag];
}

/*! @abstract The merged listing for a tag: the plugin presets followed by the user presets. */
- (NSArray<FxGripPreset*> * _Nonnull)presetsForTag:(NSString * _Nonnull)tag
{
	NSMutableArray *presets = [NSMutableArray arrayWithArray:[self pluginPresetsForTag:tag]];
	[presets addObjectsFromArray:[self userPresetsForTag:tag]];
	return presets;
}

/*!
	@method		observeTag:observer:
	@abstract	Watches the managed per-tag user preset folder.
	@discussion	Introduced in FxGrip 0.1.0. The handler runs on each change to the folder. The
				caller keeps the returned watcher alive; deallocating it ends the watch.
	@return		The watcher, or nil when the folder does not exist or no handler is supplied.
*/
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

/*!
	@method		savePreset:remap:
	@abstract	Saves a preset to a user-chosen file through the save panel.
	@discussion	Introduced in FxGrip 0.1.0. The panel starts in the managed user preset folder,
				created on demand. presetDictionary already writes the FxFactory file keys, so
				keyMap is unused by the write.
	@return		YES when the user confirms and the file is written.
*/
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

/*!
	@method		loadPreset:remap:
	@abstract	Loads a preset from a user-chosen file through the open panel.
	@discussion	Introduced in FxGrip 0.1.0. The panel starts in the managed user preset folder when
				it exists.
	@return		YES when the user confirms and the file parses.
*/
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
