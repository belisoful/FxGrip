//
//
//  MasterFXAPIManager.m
//  XPC Service
//
//  Created by ~ ~ on 2/29/24.
//

#import "FxGripPreset.h"


@implementation FxGripPreset

//---------------------------------------------------------
// initWithAPIManager:
//
// This method is called when a plug-in is first loaded, and
// is a good point to conduct any checks for anti-piracy or
// system compatibility. Returning NULL means that a plug-in
// chooses not to be accessible for some reason.
//---------------------------------------------------------

- (nullable instancetype)initWithAPIManager:(id<PROAPIAccessing>)newApiManager;
{
	self = [super init];
	
	if (self != nil)
	{
	}
	return self;
}


- (NSError *)getMeta:(id<NSSecureCoding,NSCopying> *)value forKey:(NSString *)key fromParameter:(FxParameterId)parameterID 
{
	return nil;
}

- (NSError *)getMeta:(NSDictionary **)meta fromParameter:(FxParameterId)parameterID 
{
	return nil;
}

- (NSError *)getMetaKeys:(NSArray **)keys forPreset:(NSString *)tag fromParameter:(FxParameterId)parameterID 
{
	return nil;
}

- (NSError *)getMetaKeys:(NSArray **)keys fromParameter:(FxParameterId)parameterID 
{
	return nil;
}

- (NSError *)getParameters:(NSArray **)parameterIDs withTag:(NSString *)label 
{
	return nil;
}

- (NSError *)getTags:(NSSet **)labels fromParameter:(FxParameterId)parameterID 
{
	return nil;
}

- (NSError *)parameter:(FxParameterId)parameterID exists:(BOOL *)exists 
{
	return nil;
}

- (BOOL *)parameter:(FxParameterId)parameterID hasMetaKey:(NSString *)key error:(NSError *)error 
{
	return nil;
}

- (BOOL)parameter:(FxParameterId)parameterID hasTag:(NSString *)label error:(NSError *)error 
{
	return nil;
}

- (SInt32)parameterMetaCount:(FxParameterId)parameterID 
{
	return -1;
}

- (UInt32)parameterTagCount:(FxParameterId)parameterID 
{
	return -1;
}

- (NSError *)removeAllMeta:(FxParameterId)parameterID 
{
	return nil;
}

- (NSError *)removeAllTags:(FxParameterId)parameterID 
{
	return nil;
}

- (NSError *)removeMetaFromPreset:(NSString *)tag metaKey:(NSString *)key fromParameter:(FxParameterId)parameterID 
{
	return nil;
}

- (NSError *)removeMetaKey:(NSString *)key fromParameter:(FxParameterId)parameterID 
{
	return nil;
}

- (NSError *)removeTag:(NSString *)label fromParameter:(FxParameterId)parameterID 
{
	return nil;
}

- (NSError *)saveMetaToPreset:(NSString *)tag metaKey:(NSString *)key fromParameter:(FxParameterId)parameterID 
{
	return nil;
}

- (NSError *)setMeta:(id<NSSecureCoding,NSCopying> *)value forKey:(NSString *)key toParameter:(FxParameterId)parameterID 
{
	return nil;
}

- (NSError *)setMeta:(NSDictionary *)meta toParameter:(FxParameterId)parameterID 
{
	return nil;
}

- (NSError *)setMetaKeys:(NSString *)keys forPreset:(NSString *)tag toParameter:(FxParameterId)parameterID 
{
	return nil;
}

- (UInt32)tagCount:(FxParameterId)parameterID 
{
	return -1;
}

- (NSError *)tags:(NSSet **)labels 
{
	return nil;
}

- (NSError *)addTag:(NSString *)label toParameter:(FxParameterId)parameterID 
{
	return nil;
}

- (BOOL)loadPresetFromFile:(FxGripPreset **)preset 
{
	return nil;
}

- (BOOL)openPresetFolder:(NSString *)tag 
{
	return nil;
}

- (NSArray *)presetsForTag:(NSString *)tag 
{
	return nil;
}

- (BOOL)savePresetToFile:(FxGripPreset *)preset
{
	return nil;
}

- (BOOL)compatiblePreset:(FxGripPreset *)preset
{
	return nil;
}

+ (DirectoryWatcher *)observeTag:(NSString *)tag observer:(void (^)(void))handler
{
	return nil;
}

+ (BOOL)openPresetFolder:(NSString *)tag
{
	return nil;
}

+ (NSArray *)pluginPresetsForTag:(NSString *)tag
{
	return nil;
}

+ (NSArray *)presetsForTag:(NSString *)tag
{
	return nil;
}

- (BOOL)savePresetToURL:(NSURL *)url
{
	return nil;
}

+ (NSArray *)userPresetsForTag:(NSString *)tag
{
	return nil;
}

+ (FxGripPreset *)loadPresetFromURL:(NSURL *)url
{
	return nil;
}


+ (BOOL)getParameterValue:(id*)value toParameter:(FxParameterId)parameterID atTime:(CMTime)time withAPI:(id<FxParameterSettingAPI_v5>)setterAPI {
	//get parameter type
	//based on the type, gets the parameter value and sets the NSNumber, NSString, NSArray or NSDictionary to represent the values
	//	 follow FxFactory data format. find the pathid, image ref?, and histogram data structures.
	return NO;
}

+ (BOOL)setParameterValue:(id)value toParameter:(FxParameterId)parameterID atTime:(CMTime)time withAPI:(id<FxParameterSettingAPI_v5>)setterAPI {
	//get parameter type
	//based on the type, set value from input value, as formatted
	return NO;
}

@end
