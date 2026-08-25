//
//  FxGripMLImageEffect.m
//  FxGrip
//

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

- (NSMutableArray<id<FxExtension>> *)loadExtensions
{
	NSMutableArray<id<FxExtension>> *extensions = [super loadExtensions];
	[extensions addObject:(id<FxExtension>)[self newMLCacheExtension]];
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

- (NSInteger)cacheFrameIndexForTime:(CMTime)time
{
	if (!CMTIME_IS_VALID(time)) {
		return 0;
	}
	CMTime canonical = CMTimeConvertScale(time, 600, kCMTimeRoundingMethod_Default);
	return (NSInteger)canonical.value;
}

- (NSString *)cacheSignatureForParametersAtTime:(CMTime)time
{
	NSDictionary<NSString *, id> *parameters = [self inferenceParametersAtTime:time] ?: @{};
	return [NSString stringWithFormat:@"%@|%@", self.inferenceBackend.backendIdentifier, parameters];
}

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

- (void)setError:(NSError * _Nullable *)outError code:(NSInteger)code reason:(NSString *)reason
{
	if (outError != NULL) {
		*outError = [NSError errorWithDomain:FxGripPlugErrorDomain
										code:code
									userInfo:@{ NSLocalizedDescriptionKey: reason }];
	}
}

@end
