/*!
	@file       FxGripShaderPipelineInternal.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-14
	@header     FxGripShaderPipelineInternal
	@abstract   The tile struct, value conversion, build cache, and primaries converter the shader and kernel pipelines share.
	@discussion Introduced in FxGrip 0.1.0. FxGripShaderPipeline renders a Metal fragment function and
	            FxGripKernelPipeline dispatches a Slang compute kernel. Both bind the same tile
	            struct, pack values with the same conversion rules, key their caches by the same
	            constant signature, and convert primaries with the same render passes. This header
	            is private to the framework.
*/

#ifndef FxGripShaderPipelineInternal_h
#define FxGripShaderPipelineInternal_h

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <simd/simd.h>
#import <FxPlug/FxPlugSDK.h>
#import "FxGripShaderPipeline.h"

NS_ASSUME_NONNULL_BEGIN

/*! The largest uniform struct bound with setBytes; a larger one goes in a buffer. */
#define kFxGripShaderInlineUniformLimit		(4096)

/*! The affine map from a destination pixel to a normalized texture coordinate; matches FxGripShaderTextureMap in the prelude and GripTileMap in GripKernel.slang. */
typedef struct {
	simd_float4 u;
	simd_float4 v;
} FxGripShaderTextureMap;

/*! The tile description bound to every render; matches FxGripShaderTile in the prelude and GripTile in GripKernel.slang. */
typedef struct {
	simd_float4 destinationBounds;
	simd_float2 pixelScale;
	uint32_t textureCount;
	uint32_t reserved;
	FxGripShaderTextureMap textures[kFxGripShaderTextureMapLimit];
} FxGripShaderTile;

/*! An error in the FxGrip domain with the reason as its description and failure reason. */
NSError *FxGripShaderPipelineError(NSInteger code, NSString *reason, NSError *_Nullable underlying);

/*! Fills error with FxGripShaderPipelineError and returns NO. */
BOOL FxGripShaderFail(NSError *_Nullable *_Nullable error, NSInteger code, NSString *reason, NSError *_Nullable underlying);

/*! Resolves a Metal scalar or vector type to its scalar type and component count; NO for any other type. */
BOOL FxGripShaderScalarType(MTLDataType type, MTLDataType *scalar, NSUInteger *count);

/*! Writes up to count components of a Metal scalar or vector type; components with no value stay as they are. */
void FxGripShaderWriteComponents(MTLDataType scalar, NSUInteger count, NSArray<NSNumber *> *_Nullable components, uint8_t *destination);

/*! The FxPlug primaries a declared rec709 or rec2020 maps to; NO for host primaries. */
BOOL FxGripShaderFxColorPrimaries(FxGripShaderPrimaries primaries, FxColorPrimaries *colorPrimaries);

/*! The destination pixels per image-space unit along x and y. */
simd_float2 FxGripShaderPixelScale(FxMatrix44 *_Nullable pixelTransform);

/*!
	The tile for a destination image. boundTiles maps each texture index with a source tile to that
	tile; every other index below kFxGripShaderTextureMapLimit maps the destination onto 0 through 1.
*/
FxGripShaderTile FxGripShaderMakeTile(FxImageTile *destinationImage,
									  NSDictionary<NSNumber *, FxImageTile *> *boundTiles,
									  NSUInteger textureCount,
									  simd_float2 pixelScale);

/*! The keys of the metadata's constant parameters, sorted. */
NSArray<NSString *> *FxGripShaderConstantKeys(FxGripShaderMetadata *metadata);

/*! The keys of the metadata's parameters that set pixelUnits. */
NSSet<NSString *> *FxGripShaderPixelUnitKeys(FxGripShaderMetadata *metadata);

/*! The canonical text of the constant keys' values, which keys a pipeline cache. */
NSString *FxGripShaderConstantSignature(NSArray<NSString *> *constantKeys, FxGripShaderValues *values);

/*! A copy of the values with each pixel-unit key multiplied by pixelScale; the values themselves when nothing scales. */
FxGripShaderValues *FxGripShaderValuesScaledToPixels(FxGripShaderValues *values, NSSet<NSString *> *pixelUnitKeys, float pixelScale);

/*! A transparent black 1×1 texture, for a texture argument whose parameter supplies no image. */
id<MTLTexture> _Nullable FxGripShaderEmptyTexture(id<MTLDevice> device);

/*! A private texture of the same format and size, with the usage. */
id<MTLTexture> _Nullable FxGripShaderIntermediateTexture(id<MTLTexture> texture, MTLTextureUsage usage, id<MTLDevice> device);

/*! A render encoder that clears target to transparent black and draws into its full extent. */
id<MTLRenderCommandEncoder> FxGripShaderRenderEncoder(id<MTLTexture> target, id<MTLCommandBuffer> commandBuffer);

/*! The entry unless it is an error, which goes to error. */
id _Nullable FxGripShaderEntryOrError(id entry, NSError *_Nullable *_Nullable error);

/*!
	@class		FxGripShaderBuildCache
	@abstract	A cache whose entries build outside its lock, with one build per key.
	@discussion	Introduced in FxGrip 0.1.0. A caller that asks for a key under construction waits
				for that build and shares its result. A caller that asks for any other key proceeds.
				An entry may be an NSError, so a failed build is cached with the key it belongs to. A
				cache with a limit keeps that many entries and evicts the least recently built.
*/
@interface FxGripShaderBuildCache : NSObject

/*! A cache that keeps limit entries; 0 keeps every entry. */
- (instancetype)initWithLimit:(NSUInteger)limit NS_DESIGNATED_INITIALIZER;

/*! The cached entry for a key, building it on a miss. */
- (id)entryForKey:(NSString *)key build:(id (^)(void))build;

@end

/*!
	@class		FxGripShaderConverter
	@abstract	The primaries conversion passes, built from the prelude alone.
	@discussion	Introduced in FxGrip 0.1.0. One converter serves the process. It compiles the prelude
				once per device and keeps one conversion pipeline per device and pixel format.
*/
@interface FxGripShaderConverter : NSObject

/*! The process-wide converter. */
+ (instancetype)sharedConverter;

/*!
	Encodes a pass that converts source into destination through matrix. A gamma image is
	unpremultiplied, decoded with the sRGB transfer, converted, encoded, and premultiplied again.
	A failure to build the pass returns NO with kFxGripError_ShaderCompileFailed.
*/
- (BOOL)encodeConversionFrom:(id<MTLTexture>)source
						  to:(id<MTLTexture>)destination
					  matrix:(simd_float3x3)matrix
					   gamma:(BOOL)gamma
			   commandBuffer:(id<MTLCommandBuffer>)commandBuffer
					   error:(NSError *_Nullable *_Nullable)error;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripShaderPipelineInternal_h */
