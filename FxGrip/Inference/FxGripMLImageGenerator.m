//
//  FxGripMLImageGenerator.m
//  FxGrip
//

#import "FxGripMLImageGenerator.h"
#import "FxGripInferenceRequest.h"
#import "FxGripInferenceResult.h"
#import "FxGripErrors.h"
#import "FxGrip_ARC.h"

@implementation FxGripMLImageGenerator

#pragma mark Generator geometry

- (BOOL)destinationImageRect:(FxRect *)destinationImageRect
				sourceImages:(NSArray<FxImageTile *> *)sourceImages
			destinationImage:(nonnull FxImageTile *)destinationImage
				 pluginCoder:(NSCoder * _Nonnull)pluginCoder
					  atTime:(CMTime)renderTime
					   error:(NSError * _Nullable *)outError
{
	*destinationImageRect = destinationImage.imagePixelBounds;
	return YES;
}

- (BOOL)sourceTileRect:(FxRect *)sourceTileRect
	  sourceImageIndex:(NSUInteger)sourceImageIndex
		  sourceImages:(NSArray<FxImageTile *> *)sourceImages
   destinationTileRect:(FxRect)destinationTileRect
	  destinationImage:(FxImageTile *)destinationImage
		   pluginCoder:(NSCoder * _Nonnull)pluginCoder
				atTime:(CMTime)renderTime
				 error:(NSError * _Nullable *)outError
{
	*sourceTileRect = kFxRect_Empty;
	return YES;
}

#pragma mark Declarations

- (NSDictionary<NSString *, id> *)generatorInputsAtTime:(CMTime)time
{
	return @{};
}

- (BOOL)writePlaceholderToDestinationTile:(nullable FxImageTile *)destinationTile
								   atTime:(CMTime)time
									error:(NSError * _Nullable *)outError
{
	return YES;
}

#pragma mark Render

/*! The effect's orchestration without a source: cache, then the backend over the generator
	inputs, then the output write; the placeholder covers not-ready and nothing else. */
- (BOOL)renderMLFromSourceTile:(nullable FxImageTile *)sourceTile
			 toDestinationTile:(nullable FxImageTile *)destinationTile
						atTime:(CMTime)time
						 error:(NSError * _Nullable *)outError
{
	NSInteger frameIndex = 0;
	if (self.cacheEnabled) {
		frameIndex = [self cacheFrameIndexForTime:time];
		[self invalidateCacheIfSignatureChanged:[self cacheSignatureForParametersAtTime:time]];
		id<MTLDevice> device = [self renderDeviceForTile:destinationTile imageInput:nil];
		id cached = [self cachedOutputForFrameIndex:frameIndex device:device];
		if (cached != nil) {
			return [self writeImageOutput:cached toDestinationTile:destinationTile atTime:time error:outError];
		}
	}

	if (!self.inferenceBackend.isReady) {
		return [self writePlaceholderToDestinationTile:destinationTile atTime:time error:outError];
	}

	FxGripInferenceRequest *request =
		[FxGripInferenceRequest requestWithInputs:[self generatorInputsAtTime:time]
									   parameters:[self inferenceParametersAtTime:time]];
	FxGripInferenceResult *result = [self.inferenceBackend runInferenceForRequest:request error:outError];
	if (result == nil) {
		return NO;
	}
	id output = [result outputForKey:self.outputImageName];
	if (output == nil) {
		NSString *reason = [NSString stringWithFormat:@"the backend produced no '%@' output",
							self.outputImageName];
		[self setError:outError code:kFxGripError_InferenceBackendFailure reason:reason];
		return NO;
	}

	if (self.cacheEnabled) {
		[self storeOutput:output forFrameIndex:frameIndex];
	}
	return [self writeImageOutput:output toDestinationTile:destinationTile atTime:time error:outError];
}

@end
