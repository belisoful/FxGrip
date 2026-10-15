/*!
	@file       FxGripKernelEffect.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-14
	@header     FxGripKernelEffect
	@abstract   The tileable effect that builds its parameters, color space, and render from a Slang compute kernel.
	@discussion Introduced in FxGrip 0.1.0. A subclass names its kernel. The effect scans the metadata
	            block from the kernel's Slang source, as FxGripShaderEffect does, and renders the
	            Metal source and reflection JSON slangc emitted beside it through
	            FxGripKernelPipeline.
*/

#ifndef FxGripKernelEffect_h
#define FxGripKernelEffect_h

#import <FxGrip/FxGripShaderEffect.h>
#import <FxGrip/FxGripKernelLayout.h>
#import <FxGrip/FxGripKernelPipeline.h>

NS_ASSUME_NONNULL_BEGIN

/*!
	@class		FxGripKernelEffect
	@abstract	A tileable effect whose parameters, color space, and render come from a Slang compute kernel.
	@discussion	Introduced in FxGrip 0.1.0. The kernel is written against GripKernel.slang and built
				with Scripts/fxgrip-slang.sh, which emits `<kernel>.metal` and `<kernel>.json` beside
				`<kernel>.slang`. The effect inherits parameter creation, the processing color info,
				the keyed parameter lookup, the value snapshot, and the plugin state from
				FxGripShaderEffect; shaderSource is the kernel's Slang source, so the metadata
				block is scanned from it. shaderPipeline is nil, because the kernel renders through
				kernelPipeline, and shaderFragmentFunctionName is unused.

	A subclass overrides kernelURL to name the `.slang` file, and the effect reads the three
	files beside each other. A subclass that keeps the files elsewhere overrides kernelSource,
	kernelMetalSource, and kernelLayoutData instead. The effect reads them once, on the first
	access to shaderMetadata.

	The render proceeds as follows:

	- The Slang source fails to scan → parameter creation fails with the scan error, and a
	  render passes the first source image through.
	- The Metal source or the reflection JSON is missing or invalid → kernelError holds the
	  failure, parameter creation succeeds, and every render fails with kernelError.
	- Otherwise → the render decodes the values, the host primaries, and the color info from
	  the plugin state, decodes each keyed gradient's texture, and dispatches the kernel.
*/
@interface FxGripKernelEffect : FxGripShaderEffect

/*!
	@method		kernelURL
	@abstract	The URL of the kernel's Slang source. Defaults to nil.
	@discussion	Introduced in FxGrip 0.1.0. A subclass overrides this to name its `.slang` resource. The
				default kernelSource, kernelMetalSource, and kernelLayoutData read this file and the
				`.metal` and `.json` files of the same name beside it.
*/
- (nullable NSURL *)kernelURL;

/*!
	@method		kernelSource
	@abstract	The kernel's Slang source, whose metadata block defines the effect's parameters.
	@discussion	Introduced in FxGrip 0.1.0. Defaults to the UTF-8 contents of kernelURL. A nil source
				gives the effect no parameters and no pipeline.
*/
- (nullable NSString *)kernelSource;

/*!
	@method		kernelMetalSource
	@abstract	The Metal source slangc emitted for the kernel.
	@discussion	Introduced in FxGrip 0.1.0. Defaults to the UTF-8 contents of the `.metal` file beside
				kernelURL.
*/
- (nullable NSString *)kernelMetalSource;

/*!
	@method		kernelLayoutData
	@abstract	The reflection JSON slangc emitted for the kernel.
	@discussion	Introduced in FxGrip 0.1.0. Defaults to the contents of the `.json` file beside
				kernelURL.
*/
- (nullable NSData *)kernelLayoutData;

/*!
	@property	kernelLayout
	@abstract	The layout read from kernelLayoutData; nil when the JSON fails to read.
	@discussion	Introduced in FxGrip 0.1.0. The first access scans the kernel, as shaderMetadata does.
				The layout is kernelPipeline's, so every instance that shares the pipeline shares it.
*/
@property (readonly, nullable) FxGripKernelLayout *kernelLayout;

/*!
	@property	kernelPipeline
	@abstract	The pipeline that compiles and dispatches the kernel; nil when the scan fails or kernelError is set.
	@discussion	Introduced in FxGrip 0.1.0. The pipeline is the process-wide one for the Metal source
				and the metadata, so every instance of the effect shares its compiled libraries and
				pipeline states.
*/
@property (readonly, nullable) FxGripKernelPipeline *kernelPipeline;

/*!
	@property	kernelError
	@abstract	The error from reading the Metal source or the reflection JSON; nil when both read.
	@discussion	Introduced in FxGrip 0.1.0. A missing Metal source gives
				kFxGripError_ShaderCompileFailed. A missing, malformed, or invalid reflection JSON
				gives kFxGripError_KernelLayoutMalformed or kFxGripError_KernelLayoutInvalid. The
				error is nil while the Slang source itself fails to scan; shaderMetadataError holds
				that failure.
*/
@property (readonly, nullable) NSError *kernelError;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripKernelEffect_h */
