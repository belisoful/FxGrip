//
//  FxGripMetaAPI_v1.m
//  FxGrip
//

#import "FxGripMetaAPI_v1.h"
#import "FxGripMeta.h"
#import "FxGripErrors.h"

@implementation FxGripMetaAPI_v1

#define hasMeta(returnValue) { if (!self.hostHasMeta) return (returnValue); }
#define noMetaError(parameterID) ([NSError errorWithDomain:FxGripPlugErrorDomain \
	code:kFxError_ThirdPartyDeveloperStart + (parameterID) \
	userInfo:@{ NSLocalizedDescriptionKey : [NSString stringWithFormat:@"No meta manager for parameter (%u).", (parameterID)] }])

- (nullable instancetype)initWithEffect:(nonnull id<FxGripEffectHost>)effect
{
	return [super initWithEffect:effect];
}

- (SInt32)metaCountFromParameter:(FxParameterId)parameterID
{
	hasMeta(-1);
	return [self.hostMeta metaCountFromParameter:parameterID];
}

- (NSError *)getMeta:(NSDictionary **)meta fromParameter:(FxParameterId)parameterID
{
	hasMeta(noMetaError(parameterID));
	return [self.hostMeta getMeta:meta fromParameter:parameterID];
}

- (NSError *)setMeta:(NSDictionary *)meta toParameter:(FxParameterId)parameterID
{
	hasMeta(noMetaError(parameterID));
	return [self.hostMeta setMeta:meta toParameter:parameterID];
}

- (NSError *)getMetaKeys:(NSArray **)keys fromParameter:(FxParameterId)parameterID
{
	hasMeta(noMetaError(parameterID));
	return [self.hostMeta getMetaKeys:keys fromParameter:parameterID];
}

- (NSError *)removeAllMeta:(FxParameterId)parameterID
{
	hasMeta(noMetaError(parameterID));
	return [self.hostMeta removeAllMeta:parameterID];
}

- (BOOL)parameter:(FxParameterId)parameterID hasMetaKey:(NSString *)key error:(NSError **)error
{
	if (!self.hostHasMeta) {
		if (error) {
			*error = noMetaError(parameterID);
		}
		return NO;
	}
	return [self.hostMeta parameter:parameterID hasMetaKey:key error:error];
}

- (BOOL)getMeta:(id<NSSecureCoding,NSCopying> *)value forKey:(NSString *)key fromParameter:(FxParameterId)parameterID
{
	hasMeta(NO);
	return [self.hostMeta getMeta:(NSObject<NSSecureCoding,NSCopying>**)value
						   forKey:key fromParameter:parameterID];
}

- (BOOL)setMeta:(id<NSSecureCoding,NSCopying>)value forKey:(NSString *)key toParameter:(FxParameterId)parameterID
{
	hasMeta(NO);
	return [self.hostMeta setMeta:(NSObject<NSSecureCoding,NSCopying>*)value
						   forKey:key toParameter:parameterID];
}

- (BOOL)removeMetaKey:(NSString *)key fromParameter:(FxParameterId)parameterID
{
	hasMeta(NO);
	return [self.hostMeta removeMetaKey:key fromParameter:parameterID];
}

@end
