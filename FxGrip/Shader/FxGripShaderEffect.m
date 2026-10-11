/*!
	@file       FxGripShaderEffect.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-29
	@header     FxGripShaderEffect
	@abstract   Implements the bridge from shader metadata to the effect's parameters, color space, and render.
	@discussion Introduced in FxGrip 0.1.0. The effect scans its shader source lazily under a lock.
	            parametersConfiguration appends the shader's parameter records to the inherited
	            configuration, and addParametersWithError: refuses a configuration whose shader
	            records fail to scan, collide by ID, or name an unregistered type. The coder-state
	            callbacks carry the bound values through the plugin state to the shader pipeline.
*/

#import "FxGripShaderEffect.h"
#import "FxGripTileableEffect+Parameters.h"
#import "FxGripTileableEffect+ColorGamut.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "FxGripFloatParameter.h"
#import "FxGripIntParameter.h"
#import "FxGripToggleParameter.h"
#import "FxGripPointParameter.h"
#import "FxGripColorParameter.h"
#import "FxGripRGBParameter.h"
#import "FxGripSwitchParameter.h"
#import "FxGripDictionary.h"
#import "FxGripErrors.h"
#import "FxGrip_ARC.h"
#import <os/lock.h>

/*! The base's private filter render, which blits the first source image into the destination. */
@interface FxGripTileableEffect (FxGripShaderEffectPassthrough)
- (BOOL)renderPassthroughDestinationImage:(FxImageTile *)destinationImage
							 sourceImages:(NSArray<FxImageTile *> *)sourceImages
									error:(NSError * _Nullable *)error;
@end

/*!
	@abstract	A tileable effect whose parameters, color space, and render come from a shader.
	@discussion	Introduced in FxGrip 0.1.0. The metadata is scanned once and cached with its error, and
				the pipeline is resolved once from the scanned metadata, under the same lock.
*/
@implementation FxGripShaderEffect
{
	os_unfair_lock _shaderMetadataLock;
	BOOL _shaderMetadataScanned;
	FxGripShaderMetadata *_shaderMetadata;
	NSError *_shaderMetadataError;
	FxGripShaderPipeline *_shaderPipeline;
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
	NARC_RELEASE(_shaderPipeline);
	SUPER_DEALLOC();
}

- (nullable NSString *)shaderSource
{
	return nil;
}

- (NSString *)shaderFragmentFunctionName
{
	return kFxGripShaderFragmentFunctionName;
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
		if (_shaderMetadata != nil) {
			_shaderPipeline = NARC_RETAIN([FxGripShaderPipeline sharedPipelineWithSource:source
																			  metadata:_shaderMetadata
																  fragmentFunctionName:[self shaderFragmentFunctionName]]);
		}
	}
	os_unfair_lock_unlock(&_shaderMetadataLock);
}

- (nullable FxGripShaderPipeline *)shaderPipeline
{
	[self scanShaderMetadataIfNeeded];
	return _shaderPipeline;
}

- (nullable id<FxGripParameter>)shaderParameterForKey:(NSString *)key
{
	NSDictionary *record = [self.shaderMetadata parameterForKey:key];
	if (record == nil) {
		return nil;
	}
	return [self objectAtIndexedSubscript:record.parameterID];
}

#pragma mark Values

- (FxGripShaderValues *)shaderValuesAtTime:(CMTime)renderTime
{
	FxGripShaderValues *values = NARC_AUTORELEASE([FxGripShaderValues new]);
	for (NSDictionary *record in self.shaderMetadata.allParameters) {
		NSString *key = record[kFxGripShaderProperty_Key];
		if (key == nil) {
			continue;
		}
		id<FxGripParameter> parameter = [self objectAtIndexedSubscript:record.parameterID];
		[values setComponents:[self shaderComponentsOfParameter:parameter atTime:renderTime] forKey:key];
	}
	return values;
}

- (nullable NSArray<NSNumber *> *)shaderComponentsOfParameter:(nullable id<FxGripParameter>)parameter atTime:(CMTime)renderTime
{
	if ([parameter isKindOfClass:FxGripFloatParameter.class]) {
		return @[@([(FxGripFloatParameter *)parameter valueAtTime:renderTime])];
	}
	if ([parameter isKindOfClass:FxGripIntParameter.class]) {
		return @[@([(FxGripIntParameter *)parameter valueAtTime:renderTime])];
	}
	if ([parameter isKindOfClass:FxGripToggleParameter.class]) {
		return @[[(FxGripToggleParameter *)parameter valueAtTime:renderTime] ? @1 : @0];
	}
	if ([parameter isKindOfClass:FxGripPointParameter.class]) {
		FxGripPoint point = [(FxGripPointParameter *)parameter valueAtTime:renderTime];
		return @[@(point.x), @(point.y)];
	}
	if ([parameter isKindOfClass:FxGripRGBParameter.class]) {
		FxGripColor color = [(FxGripRGBParameter *)parameter valueAtTime:renderTime];
		return @[@(color.r), @(color.g), @(color.b)];
	}
	if ([parameter isKindOfClass:FxGripColorParameter.class]) {
		FxGripColor color = [(FxGripColorParameter *)parameter valueAtTime:renderTime];
		return @[@(color.r), @(color.g), @(color.b), @(color.a)];
	}
	if ([parameter isKindOfClass:FxGripSwitchParameter.class]) {
		id value = [(FxGripSwitchParameter *)parameter valueAtTime:renderTime];
		BOOL on = NO;
		if ([value isKindOfClass:FxGripDictionary.class] && [(FxGripDictionary *)value getBoolValue:&on]) {
			return @[on ? @1 : @0];
		}
	}
	return nil;
}

#pragma mark Coder-state render

- (BOOL)pluginCoder:(NSCoder *)coder
			 atTime:(CMTime)renderTime
			quality:(FxQuality)qualityLevel
			  error:(NSError * _Nullable *)error
{
	if (self.shaderPipeline == nil) {
		return YES;
	}
	[coder encodeObject:[self shaderValuesAtTime:renderTime] forKey:kFxGripShaderValuesCoderKey];
	[coder encodeInteger:self.colorPrimaries forKey:kFxGripShaderHostPrimariesCoderKey];
	[coder encodeInteger:self.desiredProcessingColorInfo forKey:kFxGripShaderColorInfoCoderKey];
	return YES;
}

- (BOOL)destinationImageRect:(FxRect *)destinationImageRect
				sourceImages:(NSArray<FxImageTile *> *)sourceImages
			destinationImage:(FxImageTile *)destinationImage
				 pluginCoder:(NSCoder *)pluginCoder
					  atTime:(CMTime)renderTime
					   error:(NSError * _Nullable *)outError
{
	return YES;
}

- (BOOL)sourceTileRect:(FxRect *)sourceTileRect
	  sourceImageIndex:(NSUInteger)sourceImageIndex
		  sourceImages:(NSArray<FxImageTile *> *)sourceImages
   destinationTileRect:(FxRect)destinationTileRect
	  destinationImage:(FxImageTile *)destinationImage
		   pluginCoder:(NSCoder *)pluginCoder
				atTime:(CMTime)renderTime
				 error:(NSError * _Nullable *)outError
{
	return YES;
}

- (BOOL)renderDestinationImage:(FxImageTile *)destinationImage
				  sourceImages:(nullable NSArray<FxImageTile *> *)sourceImages
				   pluginCoder:(NSCoder *)pluginCoder
						atTime:(CMTime)renderTime
						 error:(NSError * _Nullable *)outError
{
	FxGripShaderPipeline *pipeline = self.shaderPipeline;
	if (pipeline == nil) {
		return [self renderPassthroughDestinationImage:destinationImage sourceImages:sourceImages error:outError];
	}
	FxGripShaderValues *values = [pluginCoder decodeObjectOfClass:FxGripShaderValues.class forKey:kFxGripShaderValuesCoderKey];
	if (values == nil) {
		values = NARC_AUTORELEASE([FxGripShaderValues new]);
	}
	FxColorPrimaries hostPrimaries = (FxColorPrimaries)[pluginCoder decodeIntegerForKey:kFxGripShaderHostPrimariesCoderKey];
	FxImageColorInfo colorInfo = (FxImageColorInfo)[pluginCoder decodeIntegerForKey:kFxGripShaderColorInfoCoderKey];
	return [pipeline renderDestinationImage:destinationImage
							   sourceImages:sourceImages
									 values:values
							  hostPrimaries:hostPrimaries
								  colorInfo:colorInfo
									  error:outError];
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
