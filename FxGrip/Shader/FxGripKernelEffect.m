/*!
	@file       FxGripKernelEffect.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-14
	@header     FxGripKernelEffect
	@abstract   Implements the bridge from a Slang kernel to the effect's parameters and render.
	@discussion Introduced in FxGrip 0.1.0. The effect supplies the kernel's Slang source as the
	            shader source, and reads the Metal source and the reflection JSON inside the base's
	            pipeline hook, which runs once under the metadata lock. The render override decodes
	            the plugin state through the base's decoders and dispatches the kernel pipeline.
*/

#import "FxGripKernelEffect.h"
#import "FxGripShaderEffectInternal.h"
#import "FxGripErrors.h"
#import "FxGrip_ARC.h"

/*!
	@abstract	A tileable effect whose parameters, color space, and render come from a Slang compute kernel.
	@discussion	Introduced in FxGrip 0.1.0. The kernel ivars are written inside the base's metadata lock
				and read after the scan, which the accessors force through shaderMetadata.
*/
@implementation FxGripKernelEffect
{
	FxGripKernelLayout *_kernelLayout;
	FxGripKernelPipeline *_kernelPipeline;
	NSError *_kernelError;
}

- (void)dealloc
{
	NARC_RELEASE(_kernelLayout);
	NARC_RELEASE(_kernelPipeline);
	NARC_RELEASE(_kernelError);
	SUPER_DEALLOC();
}

#pragma mark Sources

- (nullable NSURL *)kernelURL
{
	return nil;
}

- (nullable NSURL *)kernelURLWithExtension:(NSString *)extension
{
	NSURL *url = [self kernelURL];
	if (url == nil) {
		return nil;
	}
	return [[url URLByDeletingPathExtension] URLByAppendingPathExtension:extension];
}

- (nullable NSString *)kernelSource
{
	NSURL *url = [self kernelURL];
	if (url == nil) {
		return nil;
	}
	return [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:NULL];
}

- (nullable NSString *)kernelMetalSource
{
	NSURL *url = [self kernelURLWithExtension:@"metal"];
	if (url == nil) {
		return nil;
	}
	return [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:NULL];
}

- (nullable NSData *)kernelLayoutData
{
	NSURL *url = [self kernelURLWithExtension:@"json"];
	if (url == nil) {
		return nil;
	}
	return [NSData dataWithContentsOfURL:url];
}

- (nullable NSString *)shaderSource
{
	return [self kernelSource];
}

#pragma mark Pipeline

- (nullable FxGripShaderPipeline *)shaderPipelineForSource:(NSString *)source metadata:(FxGripShaderMetadata *)metadata
{
	NSError *failure = nil;
	NSString *metalSource = [self kernelMetalSource];
	NSData *layoutData = [self kernelLayoutData];
	FxGripKernelLayout *layout = nil;
	if (metalSource == nil) {
		failure = [self kernelErrorWithCode:kFxGripError_ShaderCompileFailed reason:@"The kernel has no Metal source; build it with Scripts/fxgrip-slang.sh."];
	} else if (layoutData == nil) {
		failure = [self kernelErrorWithCode:kFxGripError_KernelLayoutMalformed reason:@"The kernel has no reflection JSON; build it with Scripts/fxgrip-slang.sh."];
	} else {
		layout = [FxGripKernelLayout layoutWithJSONData:layoutData error:&failure];
	}
	_kernelError = NARC_RETAIN(failure);
	if (layout != nil) {
		_kernelPipeline = NARC_RETAIN([FxGripKernelPipeline sharedPipelineWithMetalSource:metalSource layout:layout metadata:metadata]);
		layout = _kernelPipeline.layout;
	}
	_kernelLayout = NARC_RETAIN(layout);
	return nil;
}

- (NSError *)kernelErrorWithCode:(NSInteger)code reason:(NSString *)reason
{
	return [NSError errorWithDomain:FxGripPlugErrorDomain
							   code:code
						   userInfo:@{ NSLocalizedDescriptionKey: reason, NSLocalizedFailureReasonErrorKey: reason }];
}

- (nullable FxGripKernelLayout *)kernelLayout
{
	[self shaderMetadata];
	return _kernelLayout;
}

- (nullable FxGripKernelPipeline *)kernelPipeline
{
	[self shaderMetadata];
	return _kernelPipeline;
}

- (nullable NSError *)kernelError
{
	[self shaderMetadata];
	return _kernelError;
}

#pragma mark Render

- (BOOL)renderDestinationImage:(FxImageTile *)destinationImage
				  sourceImages:(nullable NSArray<FxImageTile *> *)sourceImages
				   pluginCoder:(NSCoder *)pluginCoder
						atTime:(CMTime)renderTime
						 error:(NSError * _Nullable *)outError
{
	FxGripKernelPipeline *pipeline = self.kernelPipeline;
	if (pipeline == nil) {
		NSError *failure = self.kernelError;
		if (failure == nil) {
			return [super renderDestinationImage:destinationImage sourceImages:sourceImages pluginCoder:pluginCoder atTime:renderTime error:outError];
		}
		if (outError != NULL) {
			*outError = failure;
		}
		return NO;
	}
	FxColorPrimaries hostPrimaries = (FxColorPrimaries)[pluginCoder decodeIntegerForKey:kFxGripShaderHostPrimariesCoderKey];
	FxImageColorInfo colorInfo = (FxImageColorInfo)[pluginCoder decodeIntegerForKey:kFxGripShaderColorInfoCoderKey];
	return [pipeline renderDestinationImage:destinationImage
							   sourceImages:sourceImages
							  keyedTextures:[self shaderGradientTexturesInCoder:pluginCoder destinationImage:destinationImage]
									 values:[self shaderValuesInCoder:pluginCoder]
							  hostPrimaries:hostPrimaries
								  colorInfo:colorInfo
									  error:outError];
}

@end
