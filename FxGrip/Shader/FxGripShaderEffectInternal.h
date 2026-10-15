/*!
	@file       FxGripShaderEffectInternal.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-14
	@header     FxGripShaderEffectInternal
	@abstract   The hooks FxGripKernelEffect overrides and the plugin-state decoders it shares with FxGripShaderEffect.
	@discussion Introduced in FxGrip 0.1.0. This header is private to the framework.
*/

#ifndef FxGripShaderEffectInternal_h
#define FxGripShaderEffectInternal_h

#import "FxGripShaderEffect.h"

NS_ASSUME_NONNULL_BEGIN

@interface FxGripShaderEffect (FxGripShaderEffectInternal)

/*!
	The pipeline for a scanned source, called once under the metadata lock when the scan succeeds.
	The base returns the shared fragment pipeline. A subclass that renders another way returns nil,
	and must not read shaderMetadata or shaderPipeline from inside the call.
*/
- (nullable FxGripShaderPipeline *)shaderPipelineForSource:(NSString *)source metadata:(FxGripShaderMetadata *)metadata;

/*! The values snapshot the plugin state holds; an empty snapshot when it holds none. */
- (FxGripShaderValues *)shaderValuesInCoder:(NSCoder *)pluginCoder;

/*! The texture of each keyed gradient, decoded from the plugin state the gradient parameter encodes itself into. */
- (NSDictionary<NSString *, id<MTLTexture>> *)shaderGradientTexturesInCoder:(NSCoder *)pluginCoder
														   destinationImage:(FxImageTile *)destinationImage;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripShaderEffectInternal_h */
