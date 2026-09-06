/*!
	@file       FxGripMetaAPI_v1.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripMetaAPI_v1
	@abstract   Implements per-parameter metadata storage over the host's meta manager.
	@discussion Introduced in FxGrip 0.1.0. Each method checks for a host meta manager and forwards
	            to it. When the host has no meta manager, the method answers the type's not-found
	            result: a count of -1, NO, or an error in the FxGrip plugin error domain.
*/

#import "FxGripMetaAPI_v1.h"
#import "FxGripMeta.h"
#import "FxGripErrors.h"

/*!
	@abstract	FxGrip's per-parameter metadata API over the host meta manager.
	@discussion	Introduced in FxGrip 0.1.0. Forwards every call to hostMeta and returns a not-found
				result when the host has no meta manager.
*/
@implementation FxGripMetaAPI_v1

// Returns the not-found value early when the host has no meta manager.
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
