/*!
	@file       FxGripKernelPipeline.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-14
	@header     FxGripKernelPipeline
	@abstract   The Metal compute pipeline that compiles a Slang kernel's emitted source, binds its globals from the reflection JSON, and dispatches a tile.
	@discussion Introduced in FxGrip 0.1.0. A kernel written against GripKernel.slang compiles at build
	            time to Metal source and a reflection JSON. FxGripKernelPipeline compiles that source
	            once per device, specializes the entry point per distinct set of function-constant
	            values, packs the uniforms struct by the JSON's offsets, binds the tile, the source
	            and keyed textures, and the samplers by the JSON's indexes, and dispatches one
	            threadgroup grid over the destination tile. FxGripKernelPipelineState holds one built
	            compute pipeline.
*/

#ifndef FxGripKernelPipeline_h
#define FxGripKernelPipeline_h

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <FxPlug/FxPlugSDK.h>
#import <FxGrip/FxGripShaderMetadata.h>
#import <FxGrip/FxGripShaderPipeline.h>
#import <FxGrip/FxGripKernelLayout.h>

NS_ASSUME_NONNULL_BEGIN

/*!
	@class		FxGripKernelPipelineState
	@abstract	One built compute pipeline for a device and a set of function-constant values.
	@discussion	Introduced in FxGrip 0.1.0. A compute pipeline is independent of the destination's
				pixel format, so a state serves every format the host renders.
*/
@interface FxGripKernelPipelineState : NSObject

- (instancetype)init NS_UNAVAILABLE;

/*! The compiled compute pipeline. */
@property (readonly) id<MTLComputePipelineState> computePipelineState;

/*! The constant signature the pipeline was built for; an empty string when the kernel binds no constants. */
@property (readonly, copy) NSString *constantSignature;

@end

/*!
	@class		FxGripKernelPipeline
	@abstract	Compiles a kernel's Metal source, caches its pipelines per constant set, and dispatches a tile.
	@discussion	Introduced in FxGrip 0.1.0. The pipeline compiles the emitted Metal source as its own
				library, with no prelude, once per device. Every method is safe to call from
				concurrent render threads. The kernel's globals bind by their role in the layout:

	- The uniforms buffer → packed by uniformDataForValues:. A member whose name matches a
	  non-constant parameter's key receives that parameter's value at the member's offset,
	  converted to the member's scalar type.
	- The GripTile buffer → the destination bounds, the pixel scale, and a coordinate map for
	  each texture index below kFxGripShaderTextureMapLimit, filled as the fragment path fills
	  FxGripShaderTile.
	- A texture named by an image parameter's key → the source tile whose parameterID matches.
	  A texture named by a gradient parameter's key → the gradient's texture from keyedTextures.
	  A keyed texture whose parameter supplies no image binds transparent black.
	- Every other read texture → the source images in declaration order. A texture past the
	  last source image binds transparent black.
	- The read-write texture → the destination tile.
	- A sampler → bilinear filtering with clamp-to-edge addressing.
	- A specialization constant named by a constant parameter's key → that parameter's value,
	  set as the Metal function constant at the constant's index.

	A record that sets `pixelUnits` holds a length in image-space units. The render multiplies
	its value by the destination's horizontal pixel scale before it builds the constant
	signature and packs the uniforms.

	A pipeline state is cached per device and constant signature. The cache keeps
	kFxGripShaderPipelineStateCacheLimit states and evicts the least recently built. A build
	runs outside the cache lock. A render that needs a state under construction waits for that
	build, and a render that needs any other state proceeds. Compiler and binding failures are
	cached with the library or state they belong to.

	The dispatch covers the destination with ceil(width / w) by ceil(height / h) threadgroups
	of the layout's threadGroupSize (w, h, 1). The kernel returns early outside the tile
	through gripInsideTile. When the destination texture's usage excludes shader writes, the
	kernel writes an intermediate texture that a blit copies into the destination.

	Primaries conversion runs when the metadata declares rec709 or rec2020 and the host's
	working primaries differ, with the same passes the fragment path runs: each bound texture
	converts into the kernel's primaries, the kernel writes an intermediate texture, and a
	final pass converts it into the destination.
*/
@interface FxGripKernelPipeline : NSObject

/*!
	@method		sharedPipelineWithMetalSource:layout:metadata:
	@abstract	The process-wide pipeline for a Metal source and its metadata.
	@discussion	Introduced in FxGrip 0.1.0. Every effect instance that renders the same Metal source
				with the same metadata shares one pipeline, so each device compiles the source once
				per process.
*/
+ (instancetype)sharedPipelineWithMetalSource:(NSString *)metalSource
									   layout:(FxGripKernelLayout *)layout
									 metadata:(FxGripShaderMetadata *)metadata;

/*! A pipeline of its own for a Metal source, the layout slangc emitted beside it, and the metadata scanned from the kernel. */
- (instancetype)initWithMetalSource:(NSString *)metalSource
							 layout:(FxGripKernelLayout *)layout
						   metadata:(FxGripShaderMetadata *)metadata NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

/*! The Metal source slangc emitted. */
@property (readonly, copy) NSString *metalSource;

/*! The layout read from the reflection JSON. */
@property (readonly) FxGripKernelLayout *layout;

/*! The metadata scanned from the kernel's Slang source. */
@property (readonly) FxGripShaderMetadata *metadata;

/*!
	@method		constantSignatureForValues:
	@abstract	The canonical text of the constant parameters' values, which keys the pipeline cache.
	@discussion	Introduced in FxGrip 0.1.0. The signature lists each constant key in sorted order with
				its components, as FxGripShaderPipeline/constantSignatureForValues: does.
*/
- (NSString *)constantSignatureForValues:(FxGripShaderValues *)values;

/*!
	@method		libraryForDevice:error:
	@abstract	The compiled library of the Metal source on a device.
	@discussion	Introduced in FxGrip 0.1.0. A failure returns nil with kFxGripError_ShaderCompileFailed
				and the compiler error under NSUnderlyingErrorKey. The source's `#line` directives
				name the Slang lines.
*/
- (nullable id<MTLLibrary>)libraryForDevice:(id<MTLDevice>)device error:(NSError * _Nullable *)error;

/*!
	@method		stateForDevice:values:error:
	@abstract	The pipeline state for a device and the constant values.
	@discussion	Introduced in FxGrip 0.1.0. A cache miss specializes the entry point with
				MTLFunctionConstantValues built from the constant parameters' values and builds the
				compute pipeline. The failures are as follows:

	- The source fails to compile → kFxGripError_ShaderCompileFailed.
	- The library has no function named by the layout's entryPointName →
	  kFxGripError_ShaderCompileFailed.
	- The pipeline fails to build, or the layout's threadgroup exceeds the pipeline's maximum →
	  kFxGripError_ShaderCompileFailed.
	- A uniforms member bound by key is an array, a struct, or a scalar or vector of a different
	  component count than its parameter → kFxGripError_ShaderBindingInvalid.
	- A texture bound by key has a parameter that is neither an image nor a gradient, or is the
	  destination → kFxGripError_ShaderBindingInvalid.
	- A constant parameter binds a specialization constant whose type in the JSON differs from
	  the compiled function's, or whose parameter type is not a scalar →
	  kFxGripError_ShaderBindingInvalid.
	- A required function constant has no value, or no constant parameter binds it →
	  kFxGripError_ShaderBindingInvalid.
*/
- (nullable FxGripKernelPipelineState *)stateForDevice:(id<MTLDevice>)device
												values:(FxGripShaderValues *)values
												 error:(NSError * _Nullable *)error;

/*!
	@method		uniformDataForValues:
	@abstract	Packs the values into the uniforms struct; nil when the kernel declares no uniforms buffer.
	@discussion	Introduced in FxGrip 0.1.0. Each member bound by key receives its key's components
				converted to the member's scalar type, with the conversion rules of
				FxGripShaderPipelineState/uniformDataForValues:. A member with no matching parameter,
				a key with no value, and a missing component stay zero.
*/
- (nullable NSData *)uniformDataForValues:(FxGripShaderValues *)values;

/*!
	@method		renderDestinationImage:sourceImages:keyedTextures:values:hostPrimaries:colorInfo:error:
	@abstract	Dispatches the kernel over the destination tile with the sources, keyed textures, and values bound.
	@discussion	Introduced in FxGrip 0.1.0. The render runs on the destination tile's device with a
				command queue pooled by FxGripMTLDeviceCache, and waits for the GPU before it returns.
				keyedTextures supplies the texture for each gradient key. hostPrimaries and colorInfo
				describe the images the host delivers, and decide whether the primaries conversion
				runs. A missing device, texture, or command queue, or a failed command buffer,
				returns NO with kFxGripError_ShaderRenderFailed. A pipeline failure returns NO with
				the error from stateForDevice:values:error:.
*/
- (BOOL)renderDestinationImage:(FxImageTile *)destinationImage
				  sourceImages:(nullable NSArray<FxImageTile *> *)sourceImages
				 keyedTextures:(nullable NSDictionary<NSString *, id<MTLTexture>> *)keyedTextures
						values:(FxGripShaderValues *)values
				 hostPrimaries:(FxColorPrimaries)hostPrimaries
					 colorInfo:(FxImageColorInfo)colorInfo
						 error:(NSError * _Nullable *)error;

/*! Renders as renderDestinationImage:sourceImages:keyedTextures:values:hostPrimaries:colorInfo:error: does, with no keyed textures. */
- (BOOL)renderDestinationImage:(FxImageTile *)destinationImage
				  sourceImages:(nullable NSArray<FxImageTile *> *)sourceImages
						values:(FxGripShaderValues *)values
				 hostPrimaries:(FxColorPrimaries)hostPrimaries
					 colorInfo:(FxImageColorInfo)colorInfo
						 error:(NSError * _Nullable *)error;

/*!
	@method		convertsFromHostPrimaries:
	@abstract	YES when a render against the host primaries runs the primaries conversion.
	@discussion	Introduced in FxGrip 0.1.0. The metadata's primaries are rec709 or rec2020 and
				differ from hostPrimaries → YES. host primaries, or equal primaries → NO.
*/
- (BOOL)convertsFromHostPrimaries:(FxColorPrimaries)hostPrimaries;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripKernelPipeline_h */
