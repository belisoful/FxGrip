/*!
	@file       FxGripSpaceEffect.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-09
	@header     FxGripSpaceEffect
	@abstract   Implements the engine-neutral base of a 3D Space effect.
	@discussion Introduced in FxGrip 0.1.0. The capture pass encodes the host camera, lights, view-matrix
	            samples one frame on each side of the render time, and the inter-particle force
	            configuration into the per-frame coder, then runs the engine and plugin hooks. The
	            render pass resolves the destination texture and hands the frame to the engine hook,
	            whose default copies the source unchanged. Host FxMatrix44 values are converted into
	            the simd column-vector convention here.
*/

#import "FxGripSpaceEffect.h"
#import "NSCoder+FxPlug.h"
#import "FxGripMTLDeviceCache.h"
#import "FxTileImage+FxGrip.h"
#import "FxGripErrors.h"
#import "FxGrip_ARC.h"
#import <FxPlug/Fx3DAPI.h>
#import <FxPlug/FxLightingAPI.h>

// Distinct coder key prefixes for the view-matrix samples one frame on each side of the render time.
static NSString * const FxGripSpaceCoderPrevKey = @"_fxspace_prev";
static NSString * const FxGripSpaceCoderNextKey = @"_fxspace_next";

static NSString * const FxGripSpaceCoderInteractionKey = @"_fxspace_interaction";
static NSString * const FxGripSpaceCoderInteractionFieldsKey = @"_fxspace_interaction_fields";

/*! Converts a host double, row-major Matrix44Data into a simd column-vector matrix. */
static simd_float4x4 FxGripMatrixFromCoderData(Matrix44Data *data)
{
	matrix_float4x4 m;
	[NSCoder floatMatrix:&m fromDoubleMatrix:data];
	return m;
}

@implementation FxGripSpaceEffect

- (instancetype)initWithAPIManager:(id<PROAPIAccessing>)apiManager
{
	self = [super initWithAPIManager:apiManager];
	if (self != nil) {
		_rendersSourceLayerPlane = YES;
		self.needsFullBuffer = YES; // a 3D render projects the whole frame, not a sub-tile
	}
	return self;
}

#pragma mark Capture (state pass)

/*!
	@method		pluginCoder:atTime:quality:error:
	@abstract	Encodes the host camera, lights, velocity samples, interactions, and engine state into plugin state.
	@discussion	Introduced in FxGrip 0.1.0. Runs in the capture pass, where the Fx3DAPI_v5 and
				FxLightingAPI_v3 APIs are valid. The prev and next view-matrix samples are encoded only
				when the frame duration is valid and positive. The engine hook runs next, and the plugin
				hook encodeSceneParametersIntoCoder:atTime:error: runs last and its result is returned. */
- (BOOL)pluginCoder:(NSCoder *)coder
			 atTime:(CMTime)renderTime
			quality:(FxQuality)qualityLevel
			  error:(NSError * _Nullable *)outError
{
	id<Fx3DAPI_v5> space = self.apiManager.spaceAPIv5;
	if (space != nil) {
		[coder encodeFx3DAPI:space];

		CMTime frameDuration = self.frameDuration;
		if (CMTIME_IS_VALID(frameDuration) && CMTimeGetSeconds(frameDuration) > 0.0) {
			[coder encodeFx3DAPI:space atTime:CMTimeSubtract(renderTime, frameDuration) forKey:FxGripSpaceCoderPrevKey];
			[coder encodeFx3DAPI:space atTime:CMTimeAdd(renderTime, frameDuration) forKey:FxGripSpaceCoderNextKey];
		}
	}

	id<FxLightingAPI_v3> lighting = self.apiManager.lightingAPIv3;
	if (lighting != nil) {
		[coder encodeFxLightingAPI:lighting];
	}

	FxGripParticleInteraction *interaction = self.particleInteraction;
	if (interaction != nil) {
		[coder encodeObject:interaction forKey:FxGripSpaceCoderInteractionKey];
	}
	NSDictionary<NSString *, FxGripParticleInteraction *> *interactionFields = self.particleInteractionFields;
	if (interactionFields.count > 0) {
		[coder encodeObject:interactionFields forKey:FxGripSpaceCoderInteractionFieldsKey];
	}

	if (![self encodeEngineStateIntoCoder:coder atTime:renderTime error:outError]) {
		return NO;
	}
	return [self encodeSceneParametersIntoCoder:coder atTime:renderTime error:outError];
}

/*! @abstract The default per-frame parameter capture hook, a no-op returning YES; a plugin overrides it. */
- (BOOL)encodeSceneParametersIntoCoder:(NSCoder *)coder
								atTime:(CMTime)renderTime
								 error:(NSError * _Nullable *)error
{
	return YES;
}

/*! @abstract The default engine capture hook, a no-op returning YES; an engine subclass overrides it. */
- (BOOL)encodeEngineStateIntoCoder:(NSCoder *)coder
							atTime:(CMTime)renderTime
							 error:(NSError * _Nullable *)error
{
	return YES;
}

#pragma mark Geometry callbacks

/*! @abstract Reports the whole destination image bounds, because a 3D render projects the full frame. */
- (BOOL)destinationImageRect:(FxRect *)destinationImageRect
				sourceImages:(NSArray<FxImageTile *> *)sourceImages
			destinationImage:(FxImageTile *)destinationImage
				 pluginCoder:(NSCoder *)pluginCoder
					  atTime:(CMTime)renderTime
					   error:(NSError * _Nullable *)outError
{
	*destinationImageRect = destinationImage.imagePixelBounds;
	return YES;
}

/*! @abstract Requests the full source image bounds so the whole layer is available to the projection. */
- (BOOL)sourceTileRect:(FxRect *)sourceTileRect
	  sourceImageIndex:(NSUInteger)sourceImageIndex
		  sourceImages:(NSArray<FxImageTile *> *)sourceImages
   destinationTileRect:(FxRect)destinationTileRect
	  destinationImage:(FxImageTile *)destinationImage
		   pluginCoder:(NSCoder *)pluginCoder
				atTime:(CMTime)renderTime
				 error:(NSError * _Nullable *)outError
{
	if (sourceImageIndex < sourceImages.count) {
		*sourceTileRect = sourceImages[sourceImageIndex].imagePixelBounds;
	} else {
		*sourceTileRect = destinationTileRect;
	}
	return YES;
}

#pragma mark Render

/*! @abstract Resolves the destination texture and hands the frame to the engine render hook. */
- (BOOL)renderDestinationImage:(FxImageTile *)destinationImage
				  sourceImages:(NSArray<FxImageTile *> *)sourceImages
				   pluginCoder:(NSCoder *)pluginCoder
						atTime:(CMTime)renderTime
						 error:(NSError * _Nullable *)outError
{
	id<MTLTexture> destinationTexture = [destinationImage metalTextureForDevice:destinationImage.device];
	if (destinationTexture == nil) {
		if (outError != NULL) {
			*outError = [self spaceErrorWithReason:@"the destination tile has no Metal texture"];
		}
		return NO;
	}

	return [self renderSceneFromCoder:pluginCoder
						   sourceTile:sourceImages.firstObject
							toTexture:destinationTexture
							   atTime:renderTime
								error:outError];
}

/*! @abstract The base owns no render engine, so no store is installed. */
- (BOOL)installPhysicsSimulationStore:(id<FxGripPhysicsSimulationStore>)store
{
	return NO;
}

/*! @abstract The passthrough render: the source copied unchanged, or success with no source. */
- (BOOL)renderSceneFromCoder:(NSCoder *)coder
				  sourceTile:(nullable FxImageTile *)sourceTile
				   toTexture:(id<MTLTexture>)texture
					  atTime:(CMTime)renderTime
					   error:(NSError * _Nullable *)error
{
	if (sourceTile == nil) {
		return YES;
	}
	return [self blitTile:sourceTile toTexture:texture error:error];
}

#pragma mark Decoding the host state

- (BOOL)decodeCameraTransform:(simd_float4x4 *)transform fromCoder:(NSCoder *)coder
{
	Matrix44Data *viewData = [coder decodeFx3DViewMatrixData];
	if (viewData == NULL) {
		return NO;
	}
	// The host view matrix maps world to camera; the camera transform is its inverse.
	*transform = simd_inverse(FxGripMatrixFromCoderData(viewData));
	return YES;
}

- (BOOL)decodeLayerTransform:(simd_float4x4 *)transform fromCoder:(NSCoder *)coder
{
	Matrix44Data *modelData = [coder decodeFx3DModelMatrixData];
	if (modelData == NULL) {
		return NO;
	}
	*transform = FxGripMatrixFromCoderData(modelData);
	return YES;
}

- (BOOL)decodeProjectionMatrix:(simd_float4x4 *)matrix fromCoder:(NSCoder *)coder
{
	Matrix44Data *projectionData = [coder decodeFx3DProjectionMatrixData];
	if (projectionData == NULL) {
		return NO;
	}
	*matrix = FxGripMatrixFromCoderData(projectionData);
	return YES;
}

- (FxGripCameraMotion)cameraMotionFromCoder:(NSCoder *)coder
{
	Matrix44Data *prevData = [coder decodeFx3DViewMatrixData:FxGripSpaceCoderPrevKey];
	Matrix44Data *nextData = [coder decodeFx3DViewMatrixData:FxGripSpaceCoderNextKey];
	if (prevData == NULL || nextData == NULL) {
		return FxGripCameraMotionZero();
	}

	simd_float4x4 previous = simd_inverse(FxGripMatrixFromCoderData(prevData));
	simd_float4x4 next = simd_inverse(FxGripMatrixFromCoderData(nextData));
	CMTime frameDuration = self.frameDuration;
	float dt = CMTIME_IS_VALID(frameDuration) ? (float)CMTimeGetSeconds(frameDuration) : 0.0f;

	return FxGripCameraMotionCentral(previous, next, dt);
}

- (nullable FxGripParticleInteraction *)decodeParticleInteractionFromCoder:(NSCoder *)coder
{
	@try {
		return [coder decodeObjectOfClass:FxGripParticleInteraction.class forKey:FxGripSpaceCoderInteractionKey];
	} @catch (NSException *exception) {
		return nil;
	}
}

- (nullable NSDictionary<NSString *, FxGripParticleInteraction *> *)decodeParticleInteractionFieldsFromCoder:(NSCoder *)coder
{
	NSDictionary<NSString *, FxGripParticleInteraction *> *configurations = nil;
	@try {
		configurations = [coder decodeObjectOfClasses:
						  [NSSet setWithObjects:NSDictionary.class, NSString.class, FxGripParticleInteraction.class, nil]
											   forKey:FxGripSpaceCoderInteractionFieldsKey];
	} @catch (NSException *exception) {
		configurations = nil;
	}
	return configurations.count > 0 ? configurations : nil;
}

#pragma mark Render utilities

- (BOOL)blitTile:(FxImageTile *)sourceTile toTexture:(id<MTLTexture>)destinationTexture error:(NSError * _Nullable *)outError
{
	id<MTLTexture> sourceTexture = [sourceTile metalTextureForDevice:sourceTile.device];
	if (sourceTexture == nil) {
		return YES;
	}

	FxGripMTLDeviceCache *deviceCache = FxGripMTLDeviceCache.deviceCache;
	FxGripMTLDeviceCacheItem *item = [deviceCache deviceWithRegistryID:destinationTexture.device.registryID];
	id<MTLCommandQueue> commandQueue = item != nil ? [item getNextFreeCommandQueue] : [destinationTexture.device newCommandQueue];
	if (commandQueue == nil) {
		if (outError != NULL) {
			*outError = [self spaceErrorWithReason:@"no command queue for the passthrough copy"];
		}
		return NO;
	}

	id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
	id<MTLBlitCommandEncoder> blit = [commandBuffer blitCommandEncoder];
	MTLSize size = MTLSizeMake(MIN(sourceTexture.width, destinationTexture.width),
							   MIN(sourceTexture.height, destinationTexture.height),
							   1);
	[blit copyFromTexture:sourceTexture
			  sourceSlice:0
			  sourceLevel:0
			 sourceOrigin:MTLOriginMake(0, 0, 0)
			   sourceSize:size
				toTexture:destinationTexture
		 destinationSlice:0
		 destinationLevel:0
		destinationOrigin:MTLOriginMake(0, 0, 0)];
	[blit endEncoding];
	[commandBuffer commit];
	[commandBuffer waitUntilCompleted];

	if (item != nil) {
		[deviceCache returnCommandQueueToCache:commandQueue];
	}
	return YES;
}

- (NSError *)spaceErrorWithReason:(NSString *)reason
{
	return [NSError errorWithDomain:FxGripPlugErrorDomain
							   code:kFxGripError_SpaceRenderFailure
						   userInfo:@{ NSLocalizedDescriptionKey: reason }];
}

@end
