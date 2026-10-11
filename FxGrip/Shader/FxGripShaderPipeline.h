/*!
	@file       FxGripShaderPipeline.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripShaderPipeline
	@abstract   The Metal pipeline that compiles a shader source, binds its parameter values, and renders a tile.
	@discussion Introduced in FxGrip 0.1.0. FxGripShaderValues snapshots the bound parameter values
	            into the plugin state. FxGripShaderPipeline compiles the source once per device, builds
	            one render pipeline per distinct set of function-constant values, and renders a
	            destination tile from its source tiles. FxGripShaderPipelineState holds one built
	            pipeline and the uniform layout that Metal reflection reports for it.
*/

#ifndef FxGripShaderPipeline_h
#define FxGripShaderPipeline_h

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <FxPlug/FxPlugSDK.h>
#import <FxGrip/FxGripShaderMetadata.h>

NS_ASSUME_NONNULL_BEGIN

/*! The fragment function a shader effect renders with unless the subclass names another. */
#define kFxGripShaderFragmentFunctionName		@"fxGripShaderFragment"

/*! The vertex function the prelude supplies to every shader pipeline. */
#define kFxGripShaderVertexFunctionName			@"fxGripShaderVertex"

/*! The fragment buffer index of the uniform struct. */
#define kFxGripShaderUniformBufferIndex			(0)

/*! The fragment buffer index of the FxGripShaderTile description the pipeline binds to every render. */
#define kFxGripShaderTileBufferIndex			(1)

/*! The number of texture indexes FxGripShaderTile carries a coordinate map for. */
#define kFxGripShaderTextureMapLimit			(16)

/*! The number of built pipeline states a pipeline keeps before it evicts the least recently built. */
#define kFxGripShaderPipelineStateCacheLimit	(64)

/*! The plugin-state key of the FxGripShaderValues snapshot. */
#define kFxGripShaderValuesCoderKey				@"FxGripShaderValues"

/*! The plugin-state key of the host's working primaries, as an FxColorPrimaries integer. */
#define kFxGripShaderHostPrimariesCoderKey		@"FxGripShaderHostPrimaries"

/*! The plugin-state key of the processing color info the host delivers, as an FxImageColorInfo integer. */
#define kFxGripShaderColorInfoCoderKey			@"FxGripShaderColorInfo"

/*!
	@function	FxGripShaderComponentCountForType
	@abstract	The number of value components a parameter type binds to a shader symbol.
	@discussion	Introduced in FxGrip 0.1.0. The counts are as follows:

	- float, percent, angle, integer, menu, toggle, switch → 1.
	- point → 2.
	- rgb → 3.
	- rgba → 4.
	- Any other type → 0, which binds to no uniform member or function constant. An image or a
	  gradient binds to a texture argument instead.
*/
FOUNDATION_EXPORT NSUInteger FxGripShaderComponentCountForType(FxParameterType type);

/*!
	@class		FxGripShaderValues
	@abstract	The values of a shader's bound parameters at one render time, keyed by shader symbol.
	@discussion	Introduced in FxGrip 0.1.0. Each key holds one to four components as doubles. The
				shader effect builds a snapshot during pluginState:atTime:quality:error: and encodes it
				under kFxGripShaderValuesCoderKey, because the render thread cannot use the retrieval
				API. The render side decodes the snapshot and packs it into the pipeline. The class
				supports secure coding, and a copy holds the same keys and components.
*/
@interface FxGripShaderValues : NSObject <NSSecureCoding, NSCopying>

/*! The keys that hold a value, sorted. */
@property (readonly, copy) NSArray<NSString *> *keys;

/*!
	@method		setComponents:forKey:
	@abstract	Sets the value components for a key; an empty or nil array removes the key.
	@discussion	Introduced in FxGrip 0.1.0. Components past the fourth are ignored.
*/
- (void)setComponents:(nullable NSArray<NSNumber *> *)components forKey:(NSString *)key;

/*! Sets a single-component value for a key. */
- (void)setDouble:(double)value forKey:(NSString *)key;

/*! The value components for a key; nil when the key holds no value. */
- (nullable NSArray<NSNumber *> *)componentsForKey:(NSString *)key;

@end

/*!
	@class		FxGripShaderPipelineState
	@abstract	One built render pipeline and the uniform and texture layout Metal reflection reports for it.
	@discussion	Introduced in FxGrip 0.1.0. A state belongs to one device, one destination pixel
				format, and one set of function-constant values. The uniform layout comes from the
				reflected struct at fragment buffer kFxGripShaderUniformBufferIndex. Each struct member
				whose name matches the key of a non-constant parameter binds that parameter at the
				member's reflected offset. Every other member stays zero. Each fragment texture argument
				whose name matches the key of an image or gradient parameter binds that parameter's
				image at the argument's reflected index.
*/
@interface FxGripShaderPipelineState : NSObject

- (instancetype)init NS_UNAVAILABLE;

/*! The compiled render pipeline. */
@property (readonly) id<MTLRenderPipelineState> renderPipelineState;

/*! The constant signature the pipeline was built for; an empty string when the shader declares no constants. */
@property (readonly, copy) NSString *constantSignature;

/*! The byte length of the uniform struct; 0 when the fragment function reads no uniform buffer. */
@property (readonly) NSUInteger uniformLength;

/*! The reflected byte offset of each bound uniform member, keyed by parameter key. */
@property (readonly, copy) NSDictionary<NSString *, NSNumber *> *uniformOffsets;

/*! The reflected texture index of each texture argument bound to an image or gradient parameter, keyed by parameter key. */
@property (readonly, copy) NSDictionary<NSString *, NSNumber *> *textureIndexes;

/*!
	@method		uniformDataForValues:
	@abstract	Packs the values into the uniform struct; nil when the state has no uniform buffer.
	@discussion	Introduced in FxGrip 0.1.0. Each bound member receives its key's components converted
				to the member's reflected scalar type. A floating-point member stores the value. An
				integer member stores the value rounded to the nearest integer and clamped to the
				type's range. A bool member stores YES for any nonzero value. A key with no value, or
				with fewer components than the member, leaves the missing components zero.
*/
- (nullable NSData *)uniformDataForValues:(FxGripShaderValues *)values;

@end

/*!
	@class		FxGripShaderPipeline
	@abstract	Compiles a shader source, caches its pipelines per constant set, and renders a tile.
	@discussion	Introduced in FxGrip 0.1.0. The pipeline prepends a Metal prelude to the source and
				compiles the result once per device. The prelude declares FxGripShaderVertexOut,
				FxGripShaderTile, the fxGripShaderTexCoord function, and the vertex function, and a
				#line directive restores the source's own line numbers in compiler errors. Every
				method is safe to call from concurrent render threads.

	The fragment function the pipeline renders receives these bindings:

	- `[[stage_in]]` FxGripShaderVertexOut → `position`, the destination pixel;
	  `texCoord`, the normalized coordinate of that pixel in texture 0; `imagePixel`, the
	  pixel's center in the destination's pixel space, the space of its tilePixelBounds,
	  with y increasing upward.
	- `[[texture(n)]]` → source image n.
	- A texture argument named by an image parameter's key → the source tile whose
	  parameterID matches. A texture argument named by a gradient parameter's key → the
	  gradient's texture. A keyed argument replaces the positional source at its index.
	- `[[buffer(0)]]` → the uniform struct, packed by reflection.
	- `[[buffer(1)]]` FxGripShaderTile → the destination bounds, the pixel scale, and a
	  coordinate map for each texture index below kFxGripShaderTextureMapLimit.
	- A `[[function_constant]]` named by a constant parameter's key → that parameter's value.

	`fxGripShaderTexCoord(tile, n, in.imagePixel)` returns the normalized coordinate in
	texture n of the destination pixel. Each map carries the destination pixel through the
	destination's inverse pixel transform into image space, then through the texture tile's
	pixel transform into its pixel space, so a texture of another resolution or tile lines up
	with the destination. A texture with no tile, such as a gradient or an empty image, maps
	the destination tile onto 0 through 1. `tile.pixelScale` is the destination's pixels per
	image-space unit along x and y, which is below 1 at a proxy resolution.

	A record that sets `pixelUnits` holds a length in image-space units. The render
	multiplies its value by `tile.pixelScale.x` before it builds the constant signature and
	packs the uniforms.

	A pipeline state is cached per device, destination pixel format, and constant signature.
	The cache keeps kFxGripShaderPipelineStateCacheLimit states and evicts the least recently
	built. A build runs outside the cache lock. A render that needs a state under
	construction waits for that build, and a render that needs any other state proceeds.
	Compiler and binding failures are cached with the library or state they belong to, so
	a broken shader reports its error on every render without recompiling.

	Primaries conversion runs when the metadata declares rec709 or rec2020 and the host's
	working primaries differ. A conversion pass then converts each source texture into the
	shader's primaries, the fragment function renders into an intermediate texture, and a
	final pass converts that texture back into the destination. Every bound texture converts,
	keyed images and gradients included. A gamma-encoded image is unpremultiplied, decoded
	with the sRGB transfer, converted, and encoded again.
*/
@interface FxGripShaderPipeline : NSObject

/*!
	@method		sharedPipelineWithSource:metadata:fragmentFunctionName:
	@abstract	The process-wide pipeline for a source and fragment function name.
	@discussion	Introduced in FxGrip 0.1.0. Every effect instance that renders the same source with
				the same fragment function shares one pipeline, so each device compiles the source
				once per process.
*/
+ (instancetype)sharedPipelineWithSource:(NSString *)source
								metadata:(FxGripShaderMetadata *)metadata
					fragmentFunctionName:(NSString *)fragmentFunctionName;

/*! A pipeline of its own for a source, its scanned metadata, and the fragment function to render. */
- (instancetype)initWithSource:(NSString *)source
					  metadata:(FxGripShaderMetadata *)metadata
		  fragmentFunctionName:(NSString *)fragmentFunctionName NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

/*! The Metal prelude the pipeline prepends to every source. */
@property (class, readonly, copy) NSString *preludeSource;

/*! The shader source, without the prelude. */
@property (readonly, copy) NSString *source;

/*! The metadata scanned from the source. */
@property (readonly) FxGripShaderMetadata *metadata;

/*! The name of the fragment function the pipeline renders. */
@property (readonly, copy) NSString *fragmentFunctionName;

/*!
	@method		constantSignatureForValues:
	@abstract	The canonical text of the constant parameters' values, which keys the pipeline cache.
	@discussion	Introduced in FxGrip 0.1.0. The signature lists each constant key in sorted order with
				its components. A constant key with no value appears with no components. The
				signature is an empty string when the metadata declares no constants.
*/
- (NSString *)constantSignatureForValues:(FxGripShaderValues *)values;

/*!
	@method		libraryForDevice:error:
	@abstract	The compiled library of the prelude and the source on a device.
	@discussion	Introduced in FxGrip 0.1.0. A failure returns nil with kFxGripError_ShaderCompileFailed
				and the compiler error under NSUnderlyingErrorKey.
*/
- (nullable id<MTLLibrary>)libraryForDevice:(id<MTLDevice>)device error:(NSError * _Nullable *)error;

/*!
	@method		stateForDevice:pixelFormat:values:error:
	@abstract	The pipeline state for a device, a destination pixel format, and the constant values.
	@discussion	Introduced in FxGrip 0.1.0. A cache miss specializes the fragment function with
				MTLFunctionConstantValues built from the constant parameters' values, builds the
				pipeline with binding reflection, and validates the uniform layout. The failures are
				as follows:

	- The source fails to compile → kFxGripError_ShaderCompileFailed.
	- The library has no function named fragmentFunctionName → kFxGripError_ShaderCompileFailed.
	- The pipeline fails to build → kFxGripError_ShaderCompileFailed.
	- A required function constant has no value, or no constant parameter binds it →
	  kFxGripError_ShaderBindingInvalid.
	- A constant's type or component count does not match the shader's function constant →
	  kFxGripError_ShaderBindingInvalid.
	- Buffer 0 is not a struct, or a member bound by key is an array, a struct, or a vector of a
	  different component count → kFxGripError_ShaderBindingInvalid.
	- A texture argument bound by key is not a texture2d, or its parameter is neither an image
	  nor a gradient → kFxGripError_ShaderBindingInvalid.
*/
- (nullable FxGripShaderPipelineState *)stateForDevice:(id<MTLDevice>)device
										   pixelFormat:(MTLPixelFormat)pixelFormat
												values:(FxGripShaderValues *)values
												 error:(NSError * _Nullable *)error;

/*!
	@method		renderDestinationImage:sourceImages:keyedTextures:values:hostPrimaries:colorInfo:error:
	@abstract	Renders the destination tile from the source tiles and keyed textures with the values bound.
	@discussion	Introduced in FxGrip 0.1.0. The render runs on the destination tile's device with a
				command queue pooled by FxGripMTLDeviceCache, and waits for the GPU before it returns.
				keyedTextures supplies the texture for each gradient key. hostPrimaries and colorInfo
				describe the images the host delivers, and decide whether the primaries conversion
				runs. A keyed texture argument whose parameter supplies no image binds a transparent
				black texture. A missing device, texture, or command queue, or a failed command
				buffer, returns NO with kFxGripError_ShaderRenderFailed. A pipeline failure returns NO
				with the error from stateForDevice:pixelFormat:values:error:.
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

#endif /* FxGripShaderPipeline_h */
