/*!
	@file       FxGripMLImageEffect.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripMLImageEffect
	@abstract   Implements the image-to-image template: source tile through a backend to destination tile.
	@discussion Introduced in FxGrip 0.1.0. renderMLFromSourceTile:toDestinationTile:atTime:error:
	            drives the pass. It reads the frame cache when enabled, runs the backend when it is
	            ready, and writes the output to the destination tile. When the backend is not ready,
	            the source is written unchanged. The default image representation is an id<MTLTexture>,
	            and the write seam blits it into the destination texture. An FxGripMLCache extension
	            loaded in loadExtensions holds the per-frame results.
*/

#import "FxGripMLImageEffect.h"
#import "FxGripInferenceBridge.h"
#import "FxGripPassthroughBackend.h"
#import "FxGripInferenceRequest.h"
#import "FxGripInferenceResult.h"
#import "FxGripMTLDeviceCache.h"
#import "FxGripImageBuffer.h"
#import "FxGripFrameData.h"
#import "FxGripMLCache.h"
#import "FxGripErrors.h"
#import "FxGrip_ARC.h"

static NSString * const FxGripMLCacheSignatureKey = @"__mlCacheSignature";

/*!
	@abstract	The tileable-effect template that renders one source image through an inference backend.
	@discussion	Introduced in FxGrip 0.1.0. The backend defaults to an FxGripPassthroughBackend. The
				per-frame cache stores each result so a slow model runs once per frame.
*/
@implementation FxGripMLImageEffect
{
	id<FxGripInferenceBackend> _inferenceBackend;
}

- (instancetype)initWithAPIManager:(id<PROAPIAccessing>)apiManager
{
	self = [super initWithAPIManager:apiManager];
	if (self != nil) {
		_cacheEnabled = YES;
	}
	return self;
}

- (void)dealloc
{
	NARC_RELEASE(_inferenceBackend);
	SUPER_DEALLOC();
}

/*! Adds the FxGripMLCache extension to the inherited extensions so per-frame results persist. */
- (NSMutableArray<id<FxGripExtension>> *)loadExtensions
{
	NSMutableArray<id<FxGripExtension>> *extensions = [super loadExtensions];
	[extensions addObject:(id<FxGripExtension>)[self newMLCacheExtension]];
	return extensions;
}

#pragma mark Backend

- (id<FxGripInferenceBackend>)inferenceBackend
{
	if (_inferenceBackend == nil) {
		_inferenceBackend = NARC_RETAIN([self defaultInferenceBackend]);
	}
	return _inferenceBackend;
}

/*! The backend used when none is set: an FxGripPassthroughBackend. A subclass overrides this. */
- (id<FxGripInferenceBackend>)defaultInferenceBackend
{
	return [FxGripPassthroughBackend backend];
}

- (void)setInferenceBackend:(nullable id<FxGripInferenceBackend>)inferenceBackend
{
	if (_inferenceBackend != inferenceBackend) {
		NARC_RELEASE(_inferenceBackend);
		_inferenceBackend = NARC_RETAIN(inferenceBackend);
	}
}

/*! Bridges an InferKit backend and installs it as inferenceBackend; NO leaves the backend unchanged. */
- (BOOL)useInferKitBackend:(id)inferKitBackend
{
	id<FxGripInferenceBackend> bridged = [FxGripInferenceBridge backendBridgingInferKitBackend:inferKitBackend];
	if (bridged == nil) {
		return NO;
	}
	self.inferenceBackend = bridged;
	return YES;
}

#pragma mark Overridable declarations

- (NSString *)inputImageName
{
	return @"image";
}

- (NSString *)outputImageName
{
	return @"image";
}

- (NSDictionary<NSString *, id> *)inferenceParametersAtTime:(CMTime)time
{
	return @{};
}

#pragma mark Orchestration

/*!
	@method		runInferenceForImageInput:atTime:error:
	@abstract	Builds the request from the image input and parameters, runs the backend, returns its result.
	@discussion	Introduced in FxGrip 0.1.0. Returns nil with an error when the backend is not ready. */
- (nullable FxGripInferenceResult *)runInferenceForImageInput:(id)imageInput
													  atTime:(CMTime)time
													   error:(NSError * _Nullable *)outError
{
	id<FxGripInferenceBackend> backend = self.inferenceBackend;
	if (!backend.isReady) {
		[self setError:outError code:kFxGripError_InferenceNotReady reason:@"the inference backend is not ready"];
		return nil;
	}
	NSDictionary<NSString *, id> *inputs = @{ self.inputImageName: imageInput };
	NSDictionary<NSString *, id> *parameters = [self inferenceParametersAtTime:time] ?: @{};
	FxGripInferenceRequest *request = [FxGripInferenceRequest requestWithInputs:inputs parameters:parameters];
	return [backend runInferenceForRequest:request error:outError];
}

/*!
	@method		renderMLFromSourceTile:toDestinationTile:atTime:error:
	@abstract	The full pass: source tile to image input to backend to image output to destination tile.
	@discussion	Introduced in FxGrip 0.1.0. When cacheEnabled, a cache hit writes the stored output and
				returns. When the backend is ready, its output is written and cached. When the backend
				is not ready, the source image is written unchanged. */
- (BOOL)renderMLFromSourceTile:(nullable FxImageTile *)sourceTile
			 toDestinationTile:(nullable FxImageTile *)destinationTile
						atTime:(CMTime)time
						 error:(NSError * _Nullable *)outError
{
	id imageInput = [self imageInputForSourceTile:sourceTile atTime:time error:outError];
	if (imageInput == nil) {
		return NO;
	}

	NSInteger frameIndex = 0;
	if (self.cacheEnabled) {
		frameIndex = [self cacheFrameIndexForTime:time];
		[self invalidateCacheIfSignatureChanged:[self cacheSignatureForParametersAtTime:time]];
		id<MTLDevice> device = [self renderDeviceForTile:destinationTile imageInput:imageInput];
		id cached = [self cachedOutputForFrameIndex:frameIndex device:device];
		if (cached != nil) {
			return [self writeImageOutput:cached toDestinationTile:destinationTile atTime:time error:outError];
		}
	}

	id output = nil;
	BOOL ranInference = NO;
	if (self.inferenceBackend.isReady) {
		FxGripInferenceResult *result = [self runInferenceForImageInput:imageInput atTime:time error:outError];
		if (result == nil) {
			return NO;
		}
		output = [result outputForKey:self.outputImageName];
		if (output == nil) {
			NSString *reason = [NSString stringWithFormat:@"the backend produced no '%@' output", self.outputImageName];
			[self setError:outError code:kFxGripError_InferenceBackendFailure reason:reason];
			return NO;
		}
		ranInference = YES;
	} else {
		// The model is not ready; show the source unchanged rather than failing the render.
		output = imageInput;
	}

	if (self.cacheEnabled && ranInference) {
		[self storeOutput:output forFrameIndex:frameIndex];
	}
	return [self writeImageOutput:output toDestinationTile:destinationTile atTime:time error:outError];
}

/*! The device a cached output is reconstructed for: the tile's device, else the input texture's. */
- (nullable id<MTLDevice>)renderDeviceForTile:(nullable FxImageTile *)tile imageInput:(id)imageInput
{
	if (tile != nil && tile.device != nil) {
		return tile.device;
	}
	if ([imageInput conformsToProtocol:@protocol(MTLTexture)]) {
		return [(id<MTLTexture>)imageInput device];
	}
	return nil;
}

#pragma mark Cache seams

/*! The cache key for a frame: the render time normalized to a 600 timescale. Invalid time maps to 0. */
- (NSInteger)cacheFrameIndexForTime:(CMTime)time
{
	if (!CMTIME_IS_VALID(time)) {
		return 0;
	}
	CMTime canonical = CMTimeConvertScale(time, 600, kCMTimeRoundingMethod_Default);
	return (NSInteger)canonical.value;
}

/*! The cache-validity signature: the backend identifier and the frame's parameters. */
- (NSString *)cacheSignatureForParametersAtTime:(CMTime)time
{
	NSDictionary<NSString *, id> *parameters = [self inferenceParametersAtTime:time] ?: @{};
	return [NSString stringWithFormat:@"%@|%@", self.inferenceBackend.backendIdentifier, parameters];
}

/*! The cached output for a frame rebuilt as a texture for device, or nil on a miss. */
- (nullable id)cachedOutputForFrameIndex:(NSInteger)index device:(nullable id<MTLDevice>)device
{
	if (device == nil) {
		return nil;
	}
	NSObject<NSSecureCoding, NSCopying> *record = [self.mlCacheData recordAtIndex:index];
	if (![record isKindOfClass:FxGripImageBuffer.class]) {
		return nil;
	}
	return [(FxGripImageBuffer *)record newTextureWithDevice:device];
}

/*! Stores an output texture for a frame as an FxGripImageBuffer copy in the cache. */
- (void)storeOutput:(id)output forFrameIndex:(NSInteger)index
{
	if (![output conformsToProtocol:@protocol(MTLTexture)]) {
		return;
	}
	FxGripFrameData *cache = self.mlCacheData;
	if (cache == nil) {
		return;
	}
	FxGripImageBuffer *buffer = [FxGripImageBuffer bufferWithTexture:(id<MTLTexture>)output
														compression:FxGripCompressionNone];
	if (buffer != nil) {
		[cache setRecord:buffer atIndex:index];
	}
}

/*! Clears every cached frame when signature differs from the stored one, then records signature. */
- (void)invalidateCacheIfSignatureChanged:(NSString *)signature
{
	FxGripFrameData *cache = self.mlCacheData;
	if (cache == nil) {
		return;
	}
	NSString *stored = [cache objectForKey:FxGripMLCacheSignatureKey];
	if (stored != nil && [stored isEqualToString:signature]) {
		return;
	}
	for (NSNumber *frameIndex in [cache.frameIndexes copy]) {
		[cache removeRecordAtIndex:frameIndex.integerValue];
	}
	[cache setObject:signature forKey:FxGripMLCacheSignatureKey];
}

/*! The FxGrip render entry point. Runs the ML pass on the first source tile. */
- (BOOL)renderDestinationImage:(FxImageTile *)destinationImage
				  sourceImages:(NSArray<FxImageTile *> *)sourceImages
				   pluginCoder:(NSCoder *)pluginCoder
						atTime:(CMTime)renderTime
						 error:(NSError * _Nullable *)outError
{
	return [self renderMLFromSourceTile:sourceImages.firstObject
					 toDestinationTile:destinationImage
								atTime:renderTime
								 error:outError];
}

#pragma mark Metal pre/post seams

/*! The backend's image input from the source tile: the tile's Metal texture. nil on failure. */
- (nullable id)imageInputForSourceTile:(nullable FxImageTile *)sourceTile
								atTime:(CMTime)time
								 error:(NSError * _Nullable *)outError
{
	if (sourceTile == nil) {
		[self setError:outError code:kFxGripError_InferenceMissingInput reason:@"no source tile to read"];
		return nil;
	}
	id<MTLTexture> texture = [sourceTile metalTextureForDevice:sourceTile.device];
	if (texture == nil) {
		[self setError:outError code:kFxGripError_InferenceBackendFailure reason:@"the source tile has no Metal texture"];
		return nil;
	}
	return texture;
}

/*!
	@method		writeImageOutput:toDestinationTile:atTime:error:
	@abstract	Blits the output Metal texture into the destination tile's texture.
	@discussion	Introduced in FxGrip 0.1.0. Returns NO with an error when the output is not a Metal
				texture, the destination tile is missing, or no command queue is available. When the
				output and destination textures are the same, the write is a no-op. */
- (BOOL)writeImageOutput:(id)output
	   toDestinationTile:(nullable FxImageTile *)destinationTile
				  atTime:(CMTime)time
				   error:(NSError * _Nullable *)outError
{
	if (![output conformsToProtocol:@protocol(MTLTexture)]) {
		[self setError:outError code:kFxGripError_InferenceBackendFailure reason:@"the output is not a Metal texture"];
		return NO;
	}
	if (destinationTile == nil) {
		[self setError:outError code:kFxGripError_InferenceMissingInput reason:@"no destination tile to write"];
		return NO;
	}
	id<MTLTexture> outputTexture = (id<MTLTexture>)output;
	id<MTLTexture> destinationTexture = [destinationTile metalTextureForDevice:destinationTile.device];
	if (destinationTexture == nil) {
		[self setError:outError code:kFxGripError_InferenceBackendFailure reason:@"the destination tile has no Metal texture"];
		return NO;
	}
	if (outputTexture == destinationTexture) {
		return YES;
	}

	FxGripMTLDeviceCache *deviceCache = FxGripMTLDeviceCache.deviceCache;
	id<MTLCommandQueue> commandQueue = [FxGripMTLDeviceCache commandQueueForImageTile:destinationTile
																			 pluginID:self.pluginUUID];
	if (commandQueue == nil) {
		[self setError:outError code:kFxGripError_InferenceBackendFailure reason:@"no command queue for the destination tile"];
		return NO;
	}
	id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
	id<MTLBlitCommandEncoder> blit = [commandBuffer blitCommandEncoder];
	MTLSize size = MTLSizeMake(MIN(outputTexture.width, destinationTexture.width),
							   MIN(outputTexture.height, destinationTexture.height),
							   1);
	[blit copyFromTexture:outputTexture
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
	[deviceCache returnCommandQueueToCache:commandQueue];
	return YES;
}

#pragma mark Helpers

/*! Fills outError with an FxGrip-domain error carrying code and reason. */
- (void)setError:(NSError * _Nullable *)outError code:(NSInteger)code reason:(NSString *)reason
{
	if (outError != NULL) {
		*outError = [NSError errorWithDomain:FxGripPlugErrorDomain
										code:code
									userInfo:@{ NSLocalizedDescriptionKey: reason }];
	}
}

@end
