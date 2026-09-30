/*!
	@file       FxGripShaderEffect.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-29
	@header     FxGripShaderEffect
	@abstract   The tileable effect that builds its parameters and color space from a shader's metadata.
	@discussion Introduced in FxGrip 0.1.0. A subclass supplies a shader source. The effect scans the
	            source's metadata blocks, appends the declared parameters to its parameter
	            configuration, and adopts the declared transfer function as its processing color
	            info. Rendering is inherited from FxGripTileableEffect.
*/

#ifndef FxGripShaderEffect_h
#define FxGripShaderEffect_h

#import <FxGrip/FxGripTileableEffect.h>
#import <FxGrip/FxGripShaderMetadata.h>

NS_ASSUME_NONNULL_BEGIN

/*!
	@class		FxGripShaderEffect
	@abstract	A tileable effect whose parameters and color space come from a shader's metadata.
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
*/
@interface FxGripShaderEffect : FxGripTileableEffect

/*!
	@method		shaderSource
	@abstract	The shader source whose metadata defines the effect's parameters. Defaults to nil.
	@discussion	Introduced in FxGrip 0.1.0. A subclass overrides this to return its shader text. A nil
				source gives the effect no shader parameters.
*/
- (nullable NSString *)shaderSource;

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
	@method		shaderParameterForKey:
	@abstract	The created parameter whose metadata key matches; nil when none does.
	@discussion	Introduced in FxGrip 0.1.0. The key is the shader symbol the metadata binds the
				parameter to. The result is nil until the host has created the parameters.
*/
- (nullable id<FxGripParameter>)shaderParameterForKey:(NSString *)key;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripShaderEffect_h */
