//
//
//  MasterFXAPIManager.m
//  XPC Service
//
//  Created by ~ ~ on 2/29/24.
//

#import "FxGripPresetsAPI_v1.h"


@implementation FxGripPresetsAPI_v1

//---------------------------------------------------------
// initWithAPIManager:
//
// This method is called when a plug-in is first loaded, and
// is a good point to conduct any checks for anti-piracy or
// system compatibility. Returning NULL means that a plug-in
// chooses not to be accessible for some reason.
//---------------------------------------------------------

- (nullable instancetype)initWithAPI:(id<FxPresetsAPI_v1>_Nonnull)api
							  effect:(id<FxTileableEffectBase>_Nonnull)effect
{
	self = [super initWithEffect:effect];
	
	if (self != nil)
	{
		_api = api;
	}
	return self;
}



- (NSError * _Nullable)generatePreset:(FxGripPreset * _Nullable * _Nonnull)preset fromLabel:(NSString * _Nonnull)label
{
	return nil;
}

- (BOOL)loadPreset:(FxGripPreset * _Nullable * _Nonnull)preset remap:(NSDictionary * _Nullable)keyMap
{
	return NO;
}

+ (DirectoryWatcher * _Nullable)observeTag:(NSString * _Nonnull)tag observer:(void (^ _Nonnull)(void))handler
{
	return nil;
}

+ (BOOL)openMediaPresetFolder:(NSString * _Nonnull)tag
{
	return NO;
}

+ (BOOL)openMediaPresetFolder
{
	return NO;
}

+ (NSArray * _Nonnull)pluginPresetsForTag:(NSString * _Nonnull)tag
{
	return @[];
}

- (NSURL * _Nullable)pluginPresetURL:(NSString * _Nonnull)tag
{
	return nil;
}

- (NSURL * _Nullable)pluginPresetURL
{
	return nil;
}

+ (NSArray * _Nonnull)presetsForTag:(NSString * _Nonnull)tag
{
	return @[];
}

- (BOOL)savePreset:(FxGripPreset * _Nonnull)preset remap:(NSDictionary * _Nullable)keyMap
{
	return NO;
}

- (NSError * _Nullable)setPreset:(FxGripPreset * _Nonnull)preset options:(FxParameterPresetFlags)flags
{
	return nil;
}

+ (NSArray * _Nonnull)userPresetsForTag:(NSString * _Nonnull)tag
{
	return @[];
}

- (BOOL)compatiblePreset:(FxGripPreset * _Nullable)preset
{
	return NO;
}

@end
