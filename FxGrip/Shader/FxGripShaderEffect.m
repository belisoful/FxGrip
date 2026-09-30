/*!
	@file       FxGripShaderEffect.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-29
	@header     FxGripShaderEffect
	@abstract   Implements the bridge from shader metadata to the effect's parameters and color space.
	@discussion Introduced in FxGrip 0.1.0. The effect scans its shader source lazily under a lock.
	            parametersConfiguration appends the shader's parameter records to the inherited
	            configuration, and addParametersWithError: refuses a configuration whose shader
	            records fail to scan, collide by ID, or name an unregistered type.
*/

#import "FxGripShaderEffect.h"
#import "FxGripTileableEffect+Parameters.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "FxGripErrors.h"
#import "FxGrip_ARC.h"
#import <os/lock.h>

/*!
	@abstract	A tileable effect whose parameters and color space come from a shader's metadata.
	@discussion	Introduced in FxGrip 0.1.0. The metadata is scanned once and cached with its error.
*/
@implementation FxGripShaderEffect
{
	os_unfair_lock _shaderMetadataLock;
	BOOL _shaderMetadataScanned;
	FxGripShaderMetadata *_shaderMetadata;
	NSError *_shaderMetadataError;
}

- (instancetype)initWithAPIManager:(id<PROAPIAccessing>)apiManager
{
	self = [super initWithAPIManager:apiManager];
	if (self != nil) {
		_shaderMetadataLock = OS_UNFAIR_LOCK_INIT;
	}
	return self;
}

- (void)dealloc
{
	NARC_RELEASE(_shaderMetadata);
	NARC_RELEASE(_shaderMetadataError);
	SUPER_DEALLOC();
}

- (nullable NSString *)shaderSource
{
	return nil;
}

#pragma mark Metadata

- (nullable FxGripShaderMetadata *)shaderMetadata
{
	[self scanShaderMetadataIfNeeded];
	return _shaderMetadata;
}

- (nullable NSError *)shaderMetadataError
{
	[self scanShaderMetadataIfNeeded];
	return _shaderMetadataError;
}

- (void)scanShaderMetadataIfNeeded
{
	os_unfair_lock_lock(&_shaderMetadataLock);
	if (!_shaderMetadataScanned) {
		_shaderMetadataScanned = YES;
		NSString *source = [self shaderSource];
		if (source != nil) {
			NSError *error = nil;
			_shaderMetadata = NARC_RETAIN([FxGripShaderMetadata metadataWithSource:source error:&error]);
			_shaderMetadataError = NARC_RETAIN(error);
		}
	}
	os_unfair_lock_unlock(&_shaderMetadataLock);
}

- (nullable id<FxGripParameter>)shaderParameterForKey:(NSString *)key
{
	NSDictionary *record = [self.shaderMetadata parameterForKey:key];
	if (record == nil) {
		return nil;
	}
	return [self objectAtIndexedSubscript:record.parameterID];
}

#pragma mark Effect overrides

- (BOOL)properties:(NSDictionary * _Nullable *)properties error:(NSError * _Nullable *)error
{
	FxGripShaderMetadata *metadata = self.shaderMetadata;
	if (metadata != nil) {
		self.desiredProcessingColorInfo = metadata.processingColorInfo;
	}
	return [super properties:properties error:error];
}

- (NSMutableArray<NSDictionary *> *)parametersConfiguration
{
	NSMutableArray<NSDictionary *> *configuration = [super parametersConfiguration];
	FxGripShaderMetadata *metadata = self.shaderMetadata;
	if (metadata != nil) {
		[configuration addObjectsFromArray:metadata.parameters];
	}
	return configuration;
}

- (BOOL)addParametersWithError:(NSError * _Nullable *)error
{
	NSError *failure = [self shaderConfigurationError];
	if (failure != nil) {
		if (error != NULL) {
			*error = failure;
		}
		return NO;
	}
	return [super addParametersWithError:error];
}

#pragma mark Configuration checks

- (nullable NSError *)shaderConfigurationError
{
	if (self.shaderMetadataError != nil) {
		return self.shaderMetadataError;
	}
	FxGripShaderMetadata *metadata = self.shaderMetadata;
	if (metadata == nil) {
		return nil;
	}

	NSCountedSet<NSNumber *> *declaredIDs = [NSCountedSet set];
	[self countParameterIDsInRecords:[self parametersConfiguration] into:declaredIDs];

	for (NSDictionary *record in metadata.allParameters) {
		FxParameterId parameterID = record.parameterID;
		if ([declaredIDs countForObject:@(parameterID)] > 1) {
			return [self shaderInvalidError:[NSString stringWithFormat:
				@"Shader parameter %d has the ID of another parameter the plugin declares.", parameterID]];
		}
		if ([self parameterClassWithType:record.parameterType] == Nil) {
			return [self shaderInvalidError:[NSString stringWithFormat:
				@"Shader parameter %d has a type with no registered parameter class.", parameterID]];
		}
	}
	return nil;
}

- (void)countParameterIDsInRecords:(id)records into:(NSCountedSet<NSNumber *> *)declaredIDs
{
	if ([records isKindOfClass:NSDictionary.class]) {
		records = [(NSDictionary *)records allValues];
	}
	if (![records isKindOfClass:NSArray.class]) {
		return;
	}
	for (id record in (NSArray *)records) {
		if (![record isKindOfClass:NSDictionary.class]) {
			continue;
		}
		id parameterID = record[kFxParameterProperty_Id];
		if ([parameterID isKindOfClass:NSNumber.class]) {
			[declaredIDs addObject:@([(NSNumber *)parameterID intValue])];
		}
		[self countParameterIDsInRecords:record[kFxParameterProperty_GroupParameters] into:declaredIDs];
	}
}

- (NSError *)shaderInvalidError:(NSString *)reason
{
	return [NSError errorWithDomain:FxGripPlugErrorDomain
							   code:kFxGripError_ShaderMetadataInvalid
						   userInfo:@{ NSLocalizedDescriptionKey: reason, NSLocalizedFailureReasonErrorKey: reason }];
}

@end
