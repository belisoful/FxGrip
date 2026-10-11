/*!
	@file       FxGripShaderEffect.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-29
	@header     FxGripShaderEffect
	@abstract   The tileable effect that builds its parameters, color space, and render from a shader.
	@discussion Introduced in FxGrip 0.1.0. A subclass supplies a shader source. The effect scans the
	            source's metadata blocks, appends the declared parameters to its parameter
	            configuration, and adopts the declared transfer function as its processing color
	            info. It encodes the bound parameter values into the plugin state, compiles the
	            source through FxGripShaderPipeline, and renders each tile with the values bound.
*/

#ifndef FxGripShaderEffect_h
#define FxGripShaderEffect_h

#import <FxGrip/FxGripTileableEffect.h>
#import <FxGrip/FxGripShaderMetadata.h>
#import <FxGrip/FxGripShaderPipeline.h>

NS_ASSUME_NONNULL_BEGIN

/*!
	@class		FxGripShaderEffect
	@abstract	A tileable effect whose parameters, color space, and render come from a shader.
	@discussion	Introduced in FxGrip 0.1.0. The effect reads shaderSource once, on the first access
				to shaderMetadata. properties:error: sets desiredProcessingColorInfo to the
				metadata's processingColorInfo, and an effect property in the registration record
				still takes precedence. Parameter creation proceeds as follows:

	- The metadata fails to scan → addParametersWithError: returns NO with the scan error.
	- A shader parameter ID matches a parameter the plugin declares elsewhere → NO with
	  kFxGripError_ShaderMetadataInvalid.
	- A shader parameter type has no registered parameter class → NO with
	  kFxGripError_ShaderMetadataInvalid.
	- Otherwise → the shader parameters follow the declared plugin parameters in creation order.

	The effect conforms to FxGripTileableEffectCoderState. pluginCoder:atTime:quality:error:
	encodes shaderValuesAtTime:, the host's working primaries, and the processing color info,
	because the render thread cannot use the retrieval API.
	renderDestinationImage:sourceImages:pluginCoder:atTime:error: decodes them, decodes the
	texture of each keyed gradient from the state the gradient parameter encodes, and renders
	through shaderPipeline. The pipeline sets each constant parameter as a Metal function
	constant, packs the other bound parameters into the uniform struct by key, and converts
	the primaries when the metadata declares rec709 or rec2020. An effect with no shader
	pipeline passes its first source image through. The geometry callbacks keep the inherited
	same-size defaults.
*/
@interface FxGripShaderEffect : FxGripTileableEffect <FxGripTileableEffectCoderState>

/*!
	@method		shaderSource
	@abstract	The shader source whose metadata defines the effect's parameters. Defaults to nil.
	@discussion	Introduced in FxGrip 0.1.0. A subclass overrides this to return its shader text. A nil
				source gives the effect no shader parameters and no shader pipeline.
*/
- (nullable NSString *)shaderSource;

/*!
	@method		shaderFragmentFunctionName
	@abstract	The fragment function the effect renders. Defaults to kFxGripShaderFragmentFunctionName.
	@discussion	Introduced in FxGrip 0.1.0. A subclass overrides this to render a function of another
				name. The effect reads the name once, when it scans shaderSource.
*/
- (NSString *)shaderFragmentFunctionName;

/*!
	@property	shaderMetadata
	@abstract	The scanned metadata of shaderSource; nil when the source is nil or fails to scan.
	@discussion	Introduced in FxGrip 0.1.0. The first access scans the source. Later accesses return
				the same object.
*/
@property (readonly, nullable) FxGripShaderMetadata *shaderMetadata;

/*! The error from scanning shaderSource; nil when the scan succeeds or the source is nil. */
@property (readonly, nullable) NSError *shaderMetadataError;

/*!
	@property	shaderPipeline
	@abstract	The pipeline that compiles and renders shaderSource; nil when shaderMetadata is nil.
	@discussion	Introduced in FxGrip 0.1.0. The pipeline is the process-wide one for the source and
				shaderFragmentFunctionName, so every instance of the effect shares its compiled
				libraries and pipeline states.
*/
@property (readonly, nullable) FxGripShaderPipeline *shaderPipeline;

/*!
	@method		shaderParameterForKey:
	@abstract	The created parameter whose metadata key matches; nil when none does.
	@discussion	Introduced in FxGrip 0.1.0. The key is the shader symbol the metadata binds the
				parameter to. The result is nil until the host has created the parameters.
*/
- (nullable id<FxGripParameter>)shaderParameterForKey:(NSString *)key;

/*!
	@method		shaderValuesAtTime:
	@abstract	The values of the keyed parameters at a render time.
	@discussion	Introduced in FxGrip 0.1.0. The effect calls this during pluginCoder:atTime:quality:error:,
				while the retrieval API is valid. Each keyed record whose parameter exists and has a
				scalar value contributes its components:

	- float, percent, angle → the value.
	- integer, menu → the value.
	- toggle, switch → 1 for on and 0 for off.
	- point → x and y.
	- rgb → red, green, and blue.
	- rgba → red, green, blue, and alpha.
	- A parameter the host has not created, or any other type → no value.

	A subclass overrides this to adjust or add values, and calls super for the bound
	parameters.
*/
- (FxGripShaderValues *)shaderValuesAtTime:(CMTime)renderTime;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripShaderEffect_h */
