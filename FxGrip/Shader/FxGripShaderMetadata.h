/*!
	@file       FxGripShaderMetadata.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-29
	@header     FxGripShaderMetadata
	@abstract   The scanner and validator for the parameter metadata a shader declares in its source.
	@discussion Introduced in FxGrip 0.1.0. A shader declares its controls and its color space in a
	            block comment that opens with the FxGripShader sentinel and holds JSON5. The scanner
	            finds every such block, parses it, validates it, and exposes the parameter
	            configuration records the effect's parameter factory consumes. The class needs no
	            host and no Metal device.
*/

#ifndef FxGripShaderMetadata_h
#define FxGripShaderMetadata_h

#import <Foundation/Foundation.h>
#import <FxPlug/FxTypes.h>
#import <FxGrip/FxGripTypes.h>

NS_ASSUME_NONNULL_BEGIN

/*! The word that marks a block comment as shader metadata. It follows the comment opener. */
#define kFxGripShaderBlockSentinel				@"FxGripShader"

/*! The highest metadata version this release reads. */
#define kFxGripShaderMetadataVersion			(1)

/*! The highest parameter ID a shader may declare. FxGrip and the host reserve the IDs above it. */
#define kFxGripShaderParameterIdMaximum			(9979)

/*! The top-level metadata key for the metadata version number. */
#define kFxGripShaderProperty_Version			@"version"
/*! The top-level metadata key for the array of parameter configuration records. */
#define kFxGripShaderProperty_Parameters		@"parameters"
/*! The top-level metadata key for the color space the shader expects. */
#define kFxGripShaderProperty_ColorSpace		@"colorSpace"
/*! The color-space key for the transfer function: "linear" or "gamma". */
#define kFxGripShaderProperty_Transfer			@"transfer"
/*! The color-space key for the primaries: "host", "rec709", or "rec2020". */
#define kFxGripShaderProperty_Primaries			@"primaries"

/*! The parameter key naming the shader symbol the parameter's value binds to. */
#define kFxGripShaderProperty_Key				@"key"
/*! The parameter key that binds the value as a Metal function constant. */
#define kFxGripShaderProperty_Constant			@"constant"
/*! The parameter key that permits a continuous parameter type as a function constant. */
#define kFxGripShaderProperty_AllowContinuousConstant	@"allowContinuousConstant"

/*! The transfer value for linear-light processing. */
#define kFxGripShaderTransfer_Linear			@"linear"
/*! The transfer value for video-gamma processing. */
#define kFxGripShaderTransfer_Gamma				@"gamma"

/*! The primaries value for a shader that accepts the host's primaries. */
#define kFxGripShaderPrimaries_Host				@"host"
/*! The primaries value for a shader authored against Rec. 709 primaries. */
#define kFxGripShaderPrimaries_Rec709			@"rec709"
/*! The primaries value for a shader authored against Rec. 2020 primaries. */
#define kFxGripShaderPrimaries_Rec2020			@"rec2020"

/*! The error userInfo key holding the 1-based source line of the block that failed, as an NSNumber. */
FOUNDATION_EXPORT NSString * const FxGripShaderMetadataErrorLineKey;

/*!
	@enum		FxGripShaderPrimaries
	@abstract	The color primaries a shader expects its input and output in.
*/
typedef NS_ENUM(NSInteger, FxGripShaderPrimaries) {
	/*! The shader accepts the host's primaries unconverted. */
	FxGripShaderPrimariesHost = 0,
	/*! The shader expects Rec. 709 primaries. */
	FxGripShaderPrimariesRec709,
	/*! The shader expects Rec. 2020 primaries. */
	FxGripShaderPrimariesRec2020,
};

/*!
	@class		FxGripShaderMetadata
	@abstract	The parsed and validated metadata blocks of one shader source.
	@discussion	Introduced in FxGrip 0.1.0. A metadata block is a block comment whose opener starts a
				line and is followed by the sentinel word. The block ends at the comment close, the
				same place the Metal compiler ends it. The body is JSON5, so it accepts trailing
				commas and line comments. A parameter record uses the parameter configuration
				vocabulary the rest of FxGrip uses, so every parameter type FxGrip creates is available
				to a shader. A source may hold several blocks. Their parameter arrays concatenate in source order.
				Any other top-level key may appear in one block only. Top-level keys the scanner does
				not recognize pass through in properties. Validation applies these rules:

	- `id` → required; an integer from 1 through kFxGripShaderParameterIdMaximum; unique.
	- `type` → required; a type name or number that resolves to a parameter type.
	- `name` → required; a string.
	- `key` → optional; a C identifier naming the shader symbol; unique.
	- `constant` → optional boolean; requires `key`.
	- A discrete type (integer, toggle, menu, switch) → allowed as a constant.
	- A continuous type (float, percent, angle, rgb, rgba, point) → allowed as a constant only
	  with `allowContinuousConstant`, because each distinct value compiles a pipeline.
	- Any other type → never a constant.
	- A group's nested parameters → an array whose children follow the same rules.
	- `colorSpace` → an object holding only `transfer` and `primaries`.
	- `version` → optional; an integer from 1 through kFxGripShaderMetadataVersion.
*/
@interface FxGripShaderMetadata : NSObject

/*!
	@method		metadataWithSource:error:
	@abstract	Scans and validates the metadata blocks of a shader source; nil with an error on failure.
	@discussion	Introduced in FxGrip 0.1.0. A source with no metadata block yields metadata with no
				parameters and the default color space. A failure fills error with
				kFxGripError_ShaderMetadataMalformed or kFxGripError_ShaderMetadataInvalid and the
				failing block's line under FxGripShaderMetadataErrorLineKey.
*/
+ (nullable instancetype)metadataWithSource:(NSString *)source error:(NSError * _Nullable *)error;

/*! Reads a UTF-8 shader source file and scans it as metadataWithSource:error: does. */
+ (nullable instancetype)metadataWithContentsOfURL:(NSURL *)url error:(NSError * _Nullable *)error;

- (instancetype)init NS_UNAVAILABLE;

/*! The top-level parameter records in source order, with group children still nested. */
@property (readonly, copy) NSArray<NSDictionary<NSString *, id> *> *parameters;

/*! Every parameter record in source order, each group's children following the group. */
@property (readonly, copy) NSArray<NSDictionary<NSString *, id> *> *allParameters;

/*! The merged top-level keys of every block, with parameters concatenated. */
@property (readonly, copy) NSDictionary<NSString *, id> *properties;

/*! The number of metadata blocks in the source. */
@property (readonly) NSUInteger blockCount;

/*! The processing color info the shader expects. Defaults to kFxImageColorInfo_RGB_LINEAR. */
@property (readonly) FxImageColorInfo processingColorInfo;

/*! The primaries the shader expects. Defaults to FxGripShaderPrimariesHost. */
@property (readonly) FxGripShaderPrimaries primaries;

/*! The parameter record whose key matches, at any nesting depth; nil when none does. */
- (nullable NSDictionary<NSString *, id> *)parameterForKey:(NSString *)key;

/*! The parameter record with the ID, at any nesting depth; nil when none has it. */
- (nullable NSDictionary<NSString *, id> *)parameterWithID:(FxParameterId)parameterID;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripShaderMetadata_h */
