//
//  MasterFXAPIManager.m
//  XPC Service
//
//  Created by ~ ~ on 2/29/24.
//

#import "FxGripParameterTagsAPI_v1.h"
#import "FxTileableEffectBase.h"

@implementation FxGripParameterTagsAPI_v1

#define hasMeta(returnValue) { if (!self.effect) return (returnValue); }

//---------------------------------------------------------
// initWithAPIManager:
//
// This method is called when a plug-in is first loaded, and
// is a good point to conduct any checks for anti-piracy or
// system compatibility. Returning NULL means that a plug-in
// chooses not to be accessible for some reason.
//---------------------------------------------------------

- (nullable instancetype)initWithAPI:(id<FxParameterTagsAPI_v1> _Nullable)api
							  effect:(id<FxTileableEffectBase>)effect
{
	self = [super initWithEffect:effect];
	
	if (self != nil)
	{
		_api = api;
	}
	return self;
}

- (NSArray* _Nullable)tags
{
	hasMeta(nil);
	return nil;
	//return self.effect.meta.tags;
}

- (SInt32)tagCount
{
	hasMeta(0);
	return 0;
	//	return [self.effect.meta tagCount];
}

- (SInt32)tagCount:(FxParameterId)parameterID
{
	hasMeta(-1);
	return 0;
//	return [self.effect.meta tagCount:parameterID];
}

- (NSArray<NSString*>* _Nullable)parameterTags:(FxParameterId)parameterID
{
	hasMeta(nil);
	return nil;
	//return [self.effect.meta parameterTags:parameterID];
}

- (BOOL)parameter:(FxParameterId)parameterID hasTag:(NSString* _Nullable)tag error:(NSError* _Nullable * _Nullable)error
{
	//hasMeta((^(){if (error) *error = [NSError errorWithDomain:FxPlugErrorDomain code:kFxError_ThirdPartyDeveloperStart + parameterID userInfo:@{ NSLocalizedDescriptionKey : [NSString stringWithFormat:@"%@%d%@", @"No Meta for parameter (", parameterID, @")."] }]; return NO;}()));
	return nil;
	//return [self.effect.meta parameter:parameterID hasTag:tag error:error];
}
- (NSError* _Nullable)setTags:(NSArray<NSString*>*_Nonnull)tags toParameter:(FxParameterId)parameterID
{
	hasMeta(([NSError errorWithDomain:FxPlugErrorDomain code:kFxError_ThirdPartyDeveloperStart + parameterID userInfo:@{ NSLocalizedDescriptionKey : [NSString stringWithFormat:@"%@%d%@", @"No Mutable Array for parameter (", parameterID, @") tags."] }]));
	return nil;
	//return [self.effect.meta setTags:tags toParameter:parameterID];
}

- (NSError* _Nullable)addTag:(NSString*_Nullable)tag toParameter:(FxParameterId)parameterID
{
	hasMeta(([NSError errorWithDomain:FxPlugErrorDomain code:kFxError_ThirdPartyDeveloperStart + parameterID userInfo:@{ NSLocalizedDescriptionKey : [NSString stringWithFormat:@"%@%d%@", @"No Mutable Array for parameter (", parameterID, @") tags."] }]));
	return nil;
	//return [self.effect.meta addTag:tag toParameter:parameterID];
}

- (NSError* _Nullable)removeTag:(NSString*_Nullable)tag fromParameter:(FxParameterId)parameterID
{
	hasMeta(([NSError errorWithDomain:FxPlugErrorDomain code:kFxError_ThirdPartyDeveloperStart + parameterID userInfo:@{ NSLocalizedDescriptionKey : [NSString stringWithFormat:@"%@%d%@", @"No Mutable Array for parameter (", parameterID, @") tags."] }]));
	return nil;
	//return [self.effect.meta removeTag:tag fromParameter:parameterID];
}

- (NSError* _Nullable)removeAllTags:(FxParameterId)parameterID
{
	hasMeta(([NSError errorWithDomain:FxPlugErrorDomain code:kFxError_ThirdPartyDeveloperStart + parameterID userInfo:@{ NSLocalizedDescriptionKey : [NSString stringWithFormat:@"%@%d%@", @"No Mutable Array for parameter (", parameterID, @") tags."] }]));
	return nil;
	//return [self.effect.meta removeAllTags:parameterID];
}

- (NSArray* _Nullable)parametersWithTag:(NSString*_Nullable)tag
{
	hasMeta(@[]);
	return nil;
	//return [self.effect.meta parametersWithTag:tag];
}


@end
