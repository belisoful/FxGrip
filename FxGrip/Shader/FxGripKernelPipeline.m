/*!
	@file       FxGripKernelPipeline.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-14
	@header     FxGripKernelPipeline
	@abstract   Implements the kernel binding table, the compute pipeline cache, and the dispatch.
	@discussion Introduced in FxGrip 0.1.0. The pipeline resolves the layout's members, textures,
	            and constants against the metadata's keys once, at init, and keeps the first
	            binding failure to report from every state build. The library and state caches,
	            the value conversion, the tile, and the primaries conversion are the ones the
	            fragment pipeline uses, shared through FxGripShaderPipelineInternal.h.
*/

#import "FxGripKernelPipeline.h"
#import "FxGripShaderPipelineInternal.h"
#import "FxGripMTLDeviceCache.h"
#import "FxGripColorGamut.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "FxGripErrors.h"
#import "FxGrip_ARC.h"
#import <os/lock.h>

#pragma mark - Bound member

/*! One uniforms member bound to a parameter key, with its Metal scalar type. */
@interface FxGripKernelBoundMember : NSObject
@property (nonatomic, copy) NSString *key;
@property (nonatomic, assign) NSUInteger offset;
@property (nonatomic, assign) MTLDataType scalarType;
@property (nonatomic, assign) NSUInteger componentCount;
@end

@implementation FxGripKernelBoundMember

- (void)dealloc
{
	NARC_RELEASE(_key);
	SUPER_DEALLOC();
}

@end

#pragma mark - Pipeline state

@interface FxGripKernelPipelineState ()
- (instancetype)initWithComputePipelineState:(id<MTLComputePipelineState>)computePipelineState
						   constantSignature:(NSString *)constantSignature;
@end

/*!
	@abstract	One built compute pipeline for a device and a set of function-constant values.
	@discussion	Introduced in FxGrip 0.1.0. The state is immutable once built.
*/
@implementation FxGripKernelPipelineState

- (instancetype)initWithComputePipelineState:(id<MTLComputePipelineState>)computePipelineState
						   constantSignature:(NSString *)constantSignature
{
	self = [super init];
	if (self != nil) {
		_computePipelineState = NARC_RETAIN(computePipelineState);
		_constantSignature = [constantSignature copy];
	}
	return self;
}

- (void)dealloc
{
	NARC_RELEASE(_computePipelineState);
	NARC_RELEASE(_constantSignature);
	SUPER_DEALLOC();
}

@end

#pragma mark - Pipeline

/*!
	@abstract	Compiles a kernel's Metal source, caches its pipelines per constant set, and dispatches a tile.
	@discussion	Introduced in FxGrip 0.1.0. The binding table resolves at init from the layout and
				the metadata, which need no device. A device-specific check, that the reflection
				JSON and the compiled function agree on each constant, runs at state build.
*/
@implementation FxGripKernelPipeline
{
	NSArray<NSString *> *_constantKeys;
	NSSet<NSString *> *_pixelUnitKeys;
	NSArray<FxGripKernelBoundMember *> *_boundMembers;
	NSDictionary<NSString *, NSDictionary *> *_keyedTextureRecords;
	NSError *_bindingError;
	FxGripShaderBuildCache *_libraries;
	FxGripShaderBuildCache *_states;
	FxGripShaderBuildCache *_samplers;
}

+ (instancetype)sharedPipelineWithMetalSource:(NSString *)metalSource
									   layout:(FxGripKernelLayout *)layout
									 metadata:(FxGripShaderMetadata *)metadata
{
	static NSMutableDictionary<NSArray *, FxGripKernelPipeline *> *pipelines = nil;
	static os_unfair_lock pipelinesLock = OS_UNFAIR_LOCK_INIT;
	NSArray *key = @[metalSource, metadata.properties];

	os_unfair_lock_lock(&pipelinesLock);
	if (pipelines == nil) {
		pipelines = [NSMutableDictionary new];
	}
	FxGripKernelPipeline *pipeline = pipelines[key];
	if (pipeline == nil) {
		pipeline = NARC_AUTORELEASE([[self alloc] initWithMetalSource:metalSource layout:layout metadata:metadata]);
		pipelines[key] = pipeline;
	}
	os_unfair_lock_unlock(&pipelinesLock);
	return pipeline;
}

- (instancetype)initWithMetalSource:(NSString *)metalSource
							 layout:(FxGripKernelLayout *)layout
						   metadata:(FxGripShaderMetadata *)metadata
{
	self = [super init];
	if (self != nil) {
		_metalSource = [metalSource copy];
		_layout = NARC_RETAIN(layout);
		_metadata = NARC_RETAIN(metadata);
		_libraries = [[FxGripShaderBuildCache alloc] initWithLimit:0];
		_states = [[FxGripShaderBuildCache alloc] initWithLimit:kFxGripShaderPipelineStateCacheLimit];
		_samplers = [[FxGripShaderBuildCache alloc] initWithLimit:0];
		_constantKeys = [FxGripShaderConstantKeys(metadata) copy];
		_pixelUnitKeys = [FxGripShaderPixelUnitKeys(metadata) copy];
		[self resolveBindings];
	}
	return self;
}

- (void)dealloc
{
	NARC_RELEASE(_metalSource);
	NARC_RELEASE(_layout);
	NARC_RELEASE(_metadata);
	NARC_RELEASE(_constantKeys);
	NARC_RELEASE(_pixelUnitKeys);
	NARC_RELEASE(_boundMembers);
	NARC_RELEASE(_keyedTextureRecords);
	NARC_RELEASE(_bindingError);
	NARC_RELEASE(_libraries);
	NARC_RELEASE(_states);
	NARC_RELEASE(_samplers);
	SUPER_DEALLOC();
}

#pragma mark Binding table

/*! Resolves the members, textures, and constants the metadata keys bind, keeping the first failure. */
- (void)resolveBindings
{
	NSError *failure = nil;
	_boundMembers = [[self boundMembersWithError:&failure] copy];
	if (failure == nil) {
		_keyedTextureRecords = [[self keyedTextureRecordsWithError:&failure] copy];
	}
	if (failure == nil) {
		[self checkConstantParametersWithError:&failure];
	}
	_bindingError = NARC_RETAIN(failure);
}

- (NSArray<FxGripKernelBoundMember *> *)boundMembersWithError:(NSError **)error
{
	NSMutableArray<FxGripKernelBoundMember *> *members = [NSMutableArray array];
	for (FxGripKernelMember *member in self.layout.uniformsMembers) {
		NSDictionary *record = [self.metadata parameterForKey:member.name];
		if (record == nil || [record[kFxGripShaderProperty_Constant] boolValue]) {
			continue;
		}
		NSUInteger expected = FxGripShaderComponentCountForType(record.parameterType);
		if (expected == 0) {
			FxGripShaderFail(error, kFxGripError_ShaderBindingInvalid, [NSString stringWithFormat:
				@"Parameter %d has a type that binds to no uniform member.", record.parameterID], nil);
			return members;
		}
		MTLDataType scalar = FxGripKernelMetalDataType(member.scalarType, 1);
		if (scalar == MTLDataTypeNone || member.componentCount != expected) {
			FxGripShaderFail(error, kFxGripError_ShaderBindingInvalid, [NSString stringWithFormat:
				@"The uniform member \"%@\" needs a scalar or vector of %lu components for parameter %d.",
				member.name, (unsigned long)expected, record.parameterID], nil);
			return members;
		}
		FxGripKernelBoundMember *bound = NARC_AUTORELEASE([FxGripKernelBoundMember new]);
		bound.key = member.name;
		bound.offset = member.offset;
		bound.scalarType = scalar;
		bound.componentCount = member.componentCount;
		[members addObject:bound];
	}
	return members;
}

/*! The parameter record of each texture named by an image or gradient key, keyed by the texture's name. */
- (NSDictionary<NSString *, NSDictionary *> *)keyedTextureRecordsWithError:(NSError **)error
{
	NSMutableDictionary<NSString *, NSDictionary *> *records = [NSMutableDictionary dictionary];
	for (FxGripKernelTexture *texture in self.layout.textures) {
		NSDictionary *record = [self.metadata parameterForKey:texture.name];
		if (record == nil) {
			continue;
		}
		if (texture.access == FxGripKernelTextureAccessReadWrite) {
			FxGripShaderFail(error, kFxGripError_ShaderBindingInvalid, [NSString stringWithFormat:
				@"The destination \"%@\" cannot bind parameter %d.", texture.name, record.parameterID], nil);
			return records;
		}
		FxParameterType type = record.parameterType;
		if (type != FxParameterType_ImageRef && type != FxParameterType_Gradient) {
			FxGripShaderFail(error, kFxGripError_ShaderBindingInvalid, [NSString stringWithFormat:
				@"Parameter %d has a type that binds to no texture.", record.parameterID], nil);
			return records;
		}
		records[texture.name] = record;
	}
	return records;
}

- (BOOL)checkConstantParametersWithError:(NSError **)error
{
	for (NSString *key in _constantKeys) {
		FxGripKernelConstant *constant = [self.layout constantNamed:key];
		if (constant == nil) {
			continue;
		}
		NSDictionary *record = [self.metadata parameterForKey:key];
		NSUInteger expected = FxGripShaderComponentCountForType(record.parameterType);
		if (expected != 1) {
			return FxGripShaderFail(error, kFxGripError_ShaderBindingInvalid, [NSString stringWithFormat:
				@"The specialization constant \"%@\" is a scalar and parameter %d binds %lu components.",
				key, record.parameterID, (unsigned long)expected], nil);
		}
	}
	return YES;
}

#pragma mark Constants

- (NSString *)constantSignatureForValues:(FxGripShaderValues *)values
{
	return FxGripShaderConstantSignature(_constantKeys, values);
}

/*! The compiled function's constants by index; the dictionary Metal reports is keyed by mangled name. */
- (NSDictionary<NSNumber *, MTLFunctionConstant *> *)constantsByIndexOfFunction:(id<MTLFunction>)function
{
	NSMutableDictionary<NSNumber *, MTLFunctionConstant *> *byIndex = [NSMutableDictionary dictionary];
	for (MTLFunctionConstant *constant in function.functionConstantsDictionary.allValues) {
		byIndex[@(constant.index)] = constant;
	}
	return byIndex;
}

- (nullable MTLFunctionConstantValues *)constantValuesForFunction:(id<MTLFunction>)function
														   values:(FxGripShaderValues *)values
															error:(NSError **)error
{
	MTLFunctionConstantValues *constantValues = NARC_AUTORELEASE([MTLFunctionConstantValues new]);
	NSDictionary<NSNumber *, MTLFunctionConstant *> *compiled = [self constantsByIndexOfFunction:function];
	NSMutableDictionary<NSNumber *, FxGripKernelConstant *> *declared = [NSMutableDictionary dictionary];
	for (FxGripKernelConstant *constant in self.layout.specializationConstants) {
		declared[@(constant.index)] = constant;
	}
	// Metal specializes a function with an unset required constant without an error, so the pipeline refuses it.
	for (NSNumber *index in compiled) {
		FxGripKernelConstant *constant = declared[index];
		if (compiled[index].required && (constant == nil || ![_constantKeys containsObject:constant.name])) {
			FxGripShaderFail(error, kFxGripError_ShaderBindingInvalid, [NSString stringWithFormat:
				@"The function constant at index %@ (\"%@\") is bound by no constant parameter.", index, constant.name ?: compiled[index].name], nil);
			return nil;
		}
	}
	for (NSString *key in _constantKeys) {
		FxGripKernelConstant *constant = [self.layout constantNamed:key];
		MTLFunctionConstant *function_constant = constant != nil ? compiled[@(constant.index)] : nil;
		if (function_constant == nil) {
			continue;
		}
		MTLDataType type = FxGripKernelMetalDataType(constant.scalarType, 1);
		if (type != function_constant.type) {
			FxGripShaderFail(error, kFxGripError_ShaderBindingInvalid, [NSString stringWithFormat:
				@"The specialization constant \"%@\" has one type in the reflection JSON and another in the compiled library; rebuild the kernel.", key], nil);
			return nil;
		}
		NSArray<NSNumber *> *components = [values componentsForKey:key];
		if (components == nil) {
			if (function_constant.required) {
				FxGripShaderFail(error, kFxGripError_ShaderBindingInvalid, [NSString stringWithFormat:
					@"The function constant \"%@\" has no value.", key], nil);
				return nil;
			}
			continue;
		}
		uint8_t bytes[16] = { 0 };
		FxGripShaderWriteComponents(type, 1, components, bytes);
		[constantValues setConstantValue:bytes type:type atIndex:constant.index];
	}
	return constantValues;
}

#pragma mark Library

- (nullable id<MTLLibrary>)libraryForDevice:(id<MTLDevice>)device error:(NSError * _Nullable *)error
{
	NSString *key = [NSString stringWithFormat:@"library|%llu", device.registryID];
	id entry = [_libraries entryForKey:key build:^id {
		NSError *compileError = nil;
		id<MTLLibrary> library = [device newLibraryWithSource:self.metalSource options:nil error:&compileError];
		if (library != nil) {
			return NARC_AUTORELEASE(library);
		}
		return FxGripShaderPipelineError(kFxGripError_ShaderCompileFailed, [NSString stringWithFormat:
			@"The kernel's Metal source fails to compile: %@", compileError.localizedDescription], compileError);
	}];
	return FxGripShaderEntryOrError(entry, error);
}

#pragma mark Pipeline states

- (nullable FxGripKernelPipelineState *)stateForDevice:(id<MTLDevice>)device
												values:(FxGripShaderValues *)values
												 error:(NSError * _Nullable *)error
{
	NSString *signature = [self constantSignatureForValues:values];
	NSString *key = [NSString stringWithFormat:@"state|%llu|%@", device.registryID, signature];
	id entry = [_states entryForKey:key build:^id {
		NSError *failure = nil;
		FxGripKernelPipelineState *state = [self buildStateForDevice:device values:values signature:signature error:&failure];
		return state ?: failure;
	}];
	return FxGripShaderEntryOrError(entry, error);
}

- (nullable FxGripKernelPipelineState *)buildStateForDevice:(id<MTLDevice>)device
													 values:(FxGripShaderValues *)values
												  signature:(NSString *)signature
													  error:(NSError **)error
{
	id<MTLLibrary> library = [self libraryForDevice:device error:error];
	if (library == nil) {
		return nil;
	}
	if (_bindingError != nil) {
		if (error != NULL) {
			*error = _bindingError;
		}
		return nil;
	}
	id<MTLFunction> function = [self entryFunctionInLibrary:library values:values error:error];
	if (function == nil) {
		return nil;
	}
	NSError *buildError = nil;
	id<MTLComputePipelineState> computePipelineState = NARC_AUTORELEASE([device newComputePipelineStateWithFunction:function error:&buildError]);
	if (computePipelineState == nil) {
		FxGripShaderFail(error, kFxGripError_ShaderCompileFailed, [NSString stringWithFormat:
			@"The kernel pipeline fails to build: %@", buildError.localizedDescription], buildError);
		return nil;
	}
	MTLSize threadGroupSize = self.layout.threadGroupSize;
	NSUInteger threads = threadGroupSize.width * threadGroupSize.height * threadGroupSize.depth;
	if (threads > computePipelineState.maxTotalThreadsPerThreadgroup) {
		FxGripShaderFail(error, kFxGripError_ShaderCompileFailed, [NSString stringWithFormat:
			@"The kernel's threadgroup of %lu threads exceeds the pipeline's maximum of %lu.",
			(unsigned long)threads, (unsigned long)computePipelineState.maxTotalThreadsPerThreadgroup], nil);
		return nil;
	}
	return NARC_AUTORELEASE([[FxGripKernelPipelineState alloc] initWithComputePipelineState:computePipelineState constantSignature:signature]);
}

- (nullable id<MTLFunction>)entryFunctionInLibrary:(id<MTLLibrary>)library
											values:(FxGripShaderValues *)values
											 error:(NSError **)error
{
	NSString *name = self.layout.entryPointName;
	id<MTLFunction> generic = NARC_AUTORELEASE([library newFunctionWithName:name]);
	if (generic == nil) {
		FxGripShaderFail(error, kFxGripError_ShaderCompileFailed, [NSString stringWithFormat:
			@"The kernel's Metal source has no function named \"%@\".", name], nil);
		return nil;
	}
	if (generic.functionConstantsDictionary.count == 0) {
		return generic;
	}
	MTLFunctionConstantValues *constantValues = [self constantValuesForFunction:generic values:values error:error];
	if (constantValues == nil) {
		return nil;
	}
	NSError *specializeError = nil;
	id<MTLFunction> specialized = [library newFunctionWithName:name constantValues:constantValues error:&specializeError];
	if (specialized == nil) {
		FxGripShaderFail(error, kFxGripError_ShaderCompileFailed, [NSString stringWithFormat:
			@"The kernel \"%@\" fails to specialize: %@", name, specializeError.localizedDescription], specializeError);
		return nil;
	}
	return NARC_AUTORELEASE(specialized);
}

#pragma mark Uniforms

- (nullable NSData *)uniformDataForValues:(FxGripShaderValues *)values
{
	if (self.layout.uniformsBufferIndex == NSNotFound) {
		return nil;
	}
	NSMutableData *data = [NSMutableData dataWithLength:self.layout.uniformsLength];
	uint8_t *bytes = data.mutableBytes;
	for (FxGripKernelBoundMember *member in _boundMembers) {
		FxGripShaderWriteComponents(member.scalarType, member.componentCount, [values componentsForKey:member.key], bytes + member.offset);
	}
	return data;
}

#pragma mark Samplers

- (nullable id<MTLSamplerState>)samplerForDevice:(id<MTLDevice>)device
{
	NSString *key = [NSString stringWithFormat:@"sampler|%llu", device.registryID];
	id entry = [_samplers entryForKey:key build:^id {
		MTLSamplerDescriptor *descriptor = NARC_AUTORELEASE([MTLSamplerDescriptor new]);
		descriptor.minFilter = MTLSamplerMinMagFilterLinear;
		descriptor.magFilter = MTLSamplerMinMagFilterLinear;
		descriptor.mipFilter = MTLSamplerMipFilterNotMipmapped;
		descriptor.sAddressMode = MTLSamplerAddressModeClampToEdge;
		descriptor.tAddressMode = MTLSamplerAddressModeClampToEdge;
		descriptor.normalizedCoordinates = YES;
		descriptor.label = @"FxGripKernel bilinear";
		id<MTLSamplerState> sampler = NARC_AUTORELEASE([device newSamplerStateWithDescriptor:descriptor]);
		if (sampler != nil) {
			return sampler;
		}
		return FxGripShaderPipelineError(kFxGripError_ShaderRenderFailed, @"The kernel sampler fails to build.", nil);
	}];
	return FxGripShaderEntryOrError(entry, NULL);
}

#pragma mark Primaries conversion

- (BOOL)convertsFromHostPrimaries:(FxColorPrimaries)hostPrimaries
{
	FxColorPrimaries kernelPrimaries = kFxColorPrimaries_Rec709;
	if (!FxGripShaderFxColorPrimaries(self.metadata.primaries, &kernelPrimaries)) {
		return NO;
	}
	return kernelPrimaries != hostPrimaries;
}

#pragma mark Rendering

- (BOOL)renderDestinationImage:(FxImageTile *)destinationImage
				  sourceImages:(nullable NSArray<FxImageTile *> *)sourceImages
						values:(FxGripShaderValues *)values
				 hostPrimaries:(FxColorPrimaries)hostPrimaries
					 colorInfo:(FxImageColorInfo)colorInfo
						 error:(NSError * _Nullable *)error
{
	return [self renderDestinationImage:destinationImage
						   sourceImages:sourceImages
						  keyedTextures:nil
								 values:values
						  hostPrimaries:hostPrimaries
							  colorInfo:colorInfo
								  error:error];
}

/*! The source tile whose parameterID matches the record's; nil when none does. */
static FxImageTile *_Nullable FxGripKernelSourceTileForRecord(NSArray<FxImageTile *> *sourceImages, NSDictionary *record)
{
	for (FxImageTile *sourceImage in sourceImages) {
		if (sourceImage.parameterID == record.parameterID) {
			return sourceImage;
		}
	}
	return nil;
}

- (BOOL)renderDestinationImage:(FxImageTile *)destinationImage
				  sourceImages:(nullable NSArray<FxImageTile *> *)sourceImages
				 keyedTextures:(nullable NSDictionary<NSString *, id<MTLTexture>> *)keyedTextures
						values:(FxGripShaderValues *)values
				 hostPrimaries:(FxColorPrimaries)hostPrimaries
					 colorInfo:(FxImageColorInfo)colorInfo
						 error:(NSError * _Nullable *)error
{
	id<MTLDevice> device = [FxGripMTLDeviceCache metalDeviceFromID:destinationImage.deviceRegistryID];
	if (device == nil) {
		return FxGripShaderFail(error, kFxGripError_ShaderRenderFailed, @"The destination tile's Metal device is unavailable.", nil);
	}
	id<MTLTexture> outputTexture = [destinationImage metalTextureForDevice:device];
	if (outputTexture == nil) {
		return FxGripShaderFail(error, kFxGripError_ShaderRenderFailed, @"The destination tile has no Metal texture.", nil);
	}
	simd_float2 pixelScale = FxGripShaderPixelScale(destinationImage.pixelTransform);
	FxGripShaderValues *boundValues = FxGripShaderValuesScaledToPixels(values, _pixelUnitKeys, pixelScale.x);
	FxGripKernelPipelineState *state = [self stateForDevice:device values:boundValues error:error];
	if (state == nil) {
		return NO;
	}

	NSMutableArray<id<MTLTexture>> *sourceTextures = [NSMutableArray arrayWithCapacity:sourceImages.count];
	for (FxImageTile *sourceImage in sourceImages) {
		id<MTLTexture> texture = [sourceImage metalTextureForDevice:device];
		if (texture == nil) {
			return FxGripShaderFail(error, kFxGripError_ShaderRenderFailed, [NSString stringWithFormat:
				@"Source image %lu has no Metal texture.", (unsigned long)sourceTextures.count], nil);
		}
		[sourceTextures addObject:texture];
	}

	// Keyed textures bind by name; the other read textures take the source images in declaration order.
	NSMutableDictionary<NSNumber *, id<MTLTexture>> *boundTextures = [NSMutableDictionary dictionary];
	NSMutableDictionary<NSNumber *, FxImageTile *> *boundTiles = [NSMutableDictionary dictionary];
	id<MTLTexture> emptyTexture = nil;
	NSUInteger positional = 0;
	for (FxGripKernelTexture *kernelTexture in self.layout.textures) {
		if (kernelTexture.access == FxGripKernelTextureAccessReadWrite) {
			continue;
		}
		NSDictionary *record = _keyedTextureRecords[kernelTexture.name];
		id<MTLTexture> texture = nil;
		FxImageTile *tile = nil;
		if (record == nil) {
			if (positional < sourceImages.count) {
				tile = sourceImages[positional];
				texture = sourceTextures[positional];
			}
			positional += 1;
		} else if (record.parameterType == FxParameterType_ImageRef) {
			tile = FxGripKernelSourceTileForRecord(sourceImages, record);
			texture = tile != nil ? sourceTextures[[sourceImages indexOfObjectIdenticalTo:tile]] : nil;
		} else {
			texture = keyedTextures[kernelTexture.name];
		}
		if (texture == nil) {
			if (emptyTexture == nil) {
				emptyTexture = FxGripShaderEmptyTexture(device);
			}
			texture = emptyTexture;
			tile = nil;
		}
		boundTextures[@(kernelTexture.index)] = texture;
		if (tile != nil) {
			boundTiles[@(kernelTexture.index)] = tile;
		}
	}

	FxGripMTLCommandQueue *commandQueue = [FxGripMTLDeviceCache scopedCommandQueueForImageTile:destinationImage];
	id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
	if (commandBuffer == nil) {
		return FxGripShaderFail(error, kFxGripError_ShaderRenderFailed, @"No Metal command queue is available for the destination tile.", nil);
	}
	commandBuffer.label = self.layout.entryPointName;

	BOOL converts = [self convertsFromHostPrimaries:hostPrimaries];
	BOOL gamma = (colorInfo == kFxImageColorInfo_RGB_GAMMA_VIDEO);
	FxColorPrimaries kernelPrimaries = hostPrimaries;
	FxGripShaderFxColorPrimaries(self.metadata.primaries, &kernelPrimaries);
	FxGripShaderConverter *converter = FxGripShaderConverter.sharedConverter;

	if (converts) {
		simd_float3x3 toKernel = FxGripGamutConversionMatrix(hostPrimaries, kernelPrimaries);
		NSMapTable<id<MTLTexture>, id<MTLTexture>> *converted = [NSMapTable strongToStrongObjectsMapTable];
		for (NSNumber *index in boundTextures.allKeys) {
			id<MTLTexture> texture = boundTextures[index];
			if (texture == emptyTexture) {
				continue;
			}
			id<MTLTexture> conversion = [converted objectForKey:texture];
			if (conversion == nil) {
				conversion = FxGripShaderIntermediateTexture(texture, MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead, device);
				if (conversion == nil) {
					return FxGripShaderFail(error, kFxGripError_ShaderRenderFailed, @"The primaries conversion texture fails to allocate.", nil);
				}
				if (![converter encodeConversionFrom:texture to:conversion matrix:toKernel gamma:gamma commandBuffer:commandBuffer error:error]) {
					return NO;
				}
				[converted setObject:conversion forKey:texture];
			}
			boundTextures[index] = conversion;
		}
	}

	// The kernel writes the destination directly when its texture allows shader writes; a conversion or a
	// read-only destination routes the kernel through an intermediate texture.
	id<MTLTexture> target = outputTexture;
	if (converts || (outputTexture.usage & MTLTextureUsageShaderWrite) == 0) {
		target = FxGripShaderIntermediateTexture(outputTexture, MTLTextureUsageShaderWrite | MTLTextureUsageShaderRead, device);
		if (target == nil) {
			return FxGripShaderFail(error, kFxGripError_ShaderRenderFailed, @"The kernel's destination texture fails to allocate.", nil);
		}
	}
	NSUInteger destinationIndex = self.layout.destinationTexture.index;
	boundTextures[@(destinationIndex)] = target;

	NSUInteger textureCount = 0;
	for (NSNumber *index in boundTextures) {
		textureCount = MAX(textureCount, index.unsignedIntegerValue + 1);
	}
	FxGripShaderTile tile = FxGripShaderMakeTile(destinationImage, boundTiles, textureCount, pixelScale);

	id<MTLComputeCommandEncoder> encoder = [commandBuffer computeCommandEncoder];
	encoder.label = self.layout.entryPointName;
	[encoder setComputePipelineState:state.computePipelineState];
	for (NSNumber *index in boundTextures) {
		[encoder setTexture:boundTextures[index] atIndex:index.unsignedIntegerValue];
	}
	if (self.layout.samplers.count > 0) {
		id<MTLSamplerState> sampler = [self samplerForDevice:device];
		for (FxGripKernelSampler *kernelSampler in self.layout.samplers) {
			[encoder setSamplerState:sampler atIndex:kernelSampler.index];
		}
	}
	if (self.layout.tileBufferIndex != NSNotFound) {
		[encoder setBytes:&tile length:sizeof(tile) atIndex:self.layout.tileBufferIndex];
	}
	NSData *uniforms = [self uniformDataForValues:boundValues];
	if (uniforms.length > kFxGripShaderInlineUniformLimit) {
		id<MTLBuffer> buffer = NARC_AUTORELEASE([device newBufferWithBytes:uniforms.bytes length:uniforms.length options:MTLResourceStorageModeShared]);
		[encoder setBuffer:buffer offset:0 atIndex:self.layout.uniformsBufferIndex];
	} else if (uniforms != nil) {
		[encoder setBytes:uniforms.bytes length:uniforms.length atIndex:self.layout.uniformsBufferIndex];
	}
	MTLSize threadGroupSize = self.layout.threadGroupSize;
	MTLSize threadgroups = MTLSizeMake((target.width + threadGroupSize.width - 1) / threadGroupSize.width,
									   (target.height + threadGroupSize.height - 1) / threadGroupSize.height,
									   1);
	[encoder dispatchThreadgroups:threadgroups threadsPerThreadgroup:threadGroupSize];
	[encoder endEncoding];

	if (converts) {
		simd_float3x3 toHost = FxGripGamutConversionMatrix(kernelPrimaries, hostPrimaries);
		if (![converter encodeConversionFrom:target to:outputTexture matrix:toHost gamma:gamma commandBuffer:commandBuffer error:error]) {
			return NO;
		}
	} else if (target != outputTexture) {
		id<MTLBlitCommandEncoder> blit = [commandBuffer blitCommandEncoder];
		[blit copyFromTexture:target toTexture:outputTexture];
		[blit endEncoding];
	}

	[commandBuffer commit];
	[commandBuffer waitUntilCompleted];
	if (commandBuffer.status == MTLCommandBufferStatusError) {
		return FxGripShaderFail(error, kFxGripError_ShaderRenderFailed, [NSString stringWithFormat:
			@"The kernel command buffer fails: %@", commandBuffer.error.localizedDescription], commandBuffer.error);
	}
	return YES;
}

@end
