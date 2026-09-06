/*!
	@file       FxGripMLVideoEffect.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripMLVideoEffect
	@abstract   Implements the clip-generation lifecycle for a model that produces a whole movie file.
	@discussion Introduced in FxGrip 0.1.0. A lock guards the state, progress, clip URL, and error. A
	            generation token invalidates a cancelled run's late result. beginGenerationAtTime:
	            runs the backend on the generation queue and finishes Ready with the clip URL or
	            Failed with the error. The render path samples the ready clip and otherwise draws the
	            source unchanged.
*/

#import "FxGripMLVideoEffect.h"
#import "FxGripInferenceRequest.h"
#import "FxGripInferenceResult.h"
#import "FxGripErrors.h"
#import "FxGrip_ARC.h"

/*!
	@abstract	The tileable-effect template whose model generates a whole clip rather than a frame.
	@discussion	Introduced in FxGrip 0.1.0. The state moves Idle to Generating to Ready or Failed. The
				per-frame cache is disabled because the clip file is the cache.
*/
@implementation FxGripMLVideoEffect
{
	NSLock *_stateLock;
	FxGripMLVideoState _state;
	double _progress;
	NSURL *_clipURL;
	NSError *_generationError;
	NSUInteger _generationToken;		// invalidates a cancelled run's late result
	dispatch_queue_t _generationQueue;
}

- (instancetype)initWithAPIManager:(id<PROAPIAccessing>)apiManager
{
	self = [super initWithAPIManager:apiManager];
	if (self != nil) {
		_stateLock = [[NSLock alloc] init];
		_state = FxGripMLVideoStateIdle;
		_progress = -1.0;
		// The clip file is the cache; the per-frame cache would only duplicate it.
		self.cacheEnabled = NO;
	}
	return self;
}

- (void)dealloc
{
	NARC_RELEASE(_stateLock);
	NARC_RELEASE(_clipURL);
	NARC_RELEASE(_generationError);
	NARC_RELEASE(_generationQueue);
	SUPER_DEALLOC();
}

#pragma mark State

- (FxGripMLVideoState)generationState
{
	[_stateLock lock];
	FxGripMLVideoState state = _state;
	[_stateLock unlock];
	return state;
}

- (double)generationProgress
{
	[_stateLock lock];
	double progress = _progress;
	[_stateLock unlock];
	return progress;
}

- (nullable NSURL *)generatedClipURL
{
	[_stateLock lock];
	NSURL *url = NARC_RETAIN_AUTORELEASE(_clipURL);
	[_stateLock unlock];
	return url;
}

- (nullable NSError *)generationError
{
	[_stateLock lock];
	NSError *error = NARC_RETAIN_AUTORELEASE(_generationError);
	[_stateLock unlock];
	return error;
}

- (dispatch_queue_t)generationQueue
{
	if (_generationQueue == nil) {
		_generationQueue = dispatch_get_global_queue(QOS_CLASS_UTILITY, 0);
	}
	return _generationQueue;
}

- (void)setGenerationQueue:(dispatch_queue_t)generationQueue
{
	if (_generationQueue != generationQueue) {
		NARC_RELEASE(_generationQueue);
		_generationQueue = NARC_RETAIN(generationQueue);
	}
}

/*! Moves the state under the lock and fires the change hook outside it. */
- (void)moveToState:(FxGripMLVideoState)state
		   progress:(double)progress
			clipURL:(nullable NSURL *)clipURL
			  error:(nullable NSError *)error
{
	[_stateLock lock];
	_state = state;
	_progress = progress;
	NSURL *retainedURL = [clipURL copy];
	NARC_RELEASE(_clipURL);
	_clipURL = retainedURL;
	NSError *retainedError = NARC_RETAIN(error);
	NARC_RELEASE(_generationError);
	_generationError = retainedError;
	[_stateLock unlock];
	[self generationStateDidChange];
}

/*! The state-change hook. The default does nothing; a subclass mirrors the state and invalidates. */
- (void)generationStateDidChange
{
}

#pragma mark Declarations

- (NSString *)videoOutputName
{
	return @"video";
}

- (NSDictionary<NSString *, id> *)generationInputsAtTime:(CMTime)time
{
	return @{};
}

#pragma mark Generation

/*!
	@method		beginGenerationAtTime:
	@abstract	Starts a generation on the generation queue; no-op while one is running.
	@discussion	Introduced in FxGrip 0.1.0. The method captures a new token, moves to Generating, and
				dispatches the backend run. A not-ready backend finishes Failed. The finish applies
				only when the token still matches. */
- (void)beginGenerationAtTime:(CMTime)time
{
	[_stateLock lock];
	if (_state == FxGripMLVideoStateGenerating) {
		[_stateLock unlock];
		return;
	}
	_generationToken += 1;
	NSUInteger token = _generationToken;
	[_stateLock unlock];

	[self moveToState:FxGripMLVideoStateGenerating progress:-1.0 clipURL:nil error:nil];

	NSDictionary *inputs = [self generationInputsAtTime:time];
	NSDictionary *parameters = [self inferenceParametersAtTime:time];
	id<FxGripInferenceBackend> backend = self.inferenceBackend;

	dispatch_async(self.generationQueue, ^{
		NSError *error = nil;
		NSURL *clipURL = nil;
		if (!backend.isReady) {
			error = [NSError errorWithDomain:FxGripPlugErrorDomain
										code:kFxGripError_InferenceNotReady
									userInfo:@{ NSLocalizedDescriptionKey: @"the backend is not ready" }];
		} else {
			FxGripInferenceRequest *request = [FxGripInferenceRequest requestWithInputs:inputs
																			 parameters:parameters];
			FxGripInferenceResult *result = [backend runInferenceForRequest:request error:&error];
			if (result != nil) {
				clipURL = [self clipURLFromOutput:[result outputForKey:self.videoOutputName]];
				if (clipURL == nil) {
					NSString *reason = [NSString stringWithFormat:
										@"the backend produced no '%@' clip output", self.videoOutputName];
					error = [NSError errorWithDomain:FxGripPlugErrorDomain
												code:kFxGripError_InferenceBackendFailure
											userInfo:@{ NSLocalizedDescriptionKey: reason }];
				}
			}
		}
		[self finishGenerationWithToken:token clipURL:clipURL error:error];
	});
}

/*! Applies a finished run's result unless a newer begin or a cancel invalidated its token. */
- (void)finishGenerationWithToken:(NSUInteger)token
						  clipURL:(nullable NSURL *)clipURL
							error:(nullable NSError *)error
{
	[_stateLock lock];
	BOOL current = (token == _generationToken) && (_state == FxGripMLVideoStateGenerating);
	[_stateLock unlock];
	if (!current) {
		return;
	}
	if (clipURL != nil) {
		[self moveToState:FxGripMLVideoStateReady progress:1.0 clipURL:clipURL error:nil];
	} else {
		[self moveToState:FxGripMLVideoStateFailed progress:-1.0 clipURL:nil error:error];
	}
}

/*! The clip URL from a result output: an NSURL, a path or URL string, or an object with a
	fileURL (an InferKit video asset, matched by shape rather than by class). */
- (nullable NSURL *)clipURLFromOutput:(nullable id)output
{
	if ([output isKindOfClass:NSURL.class]) {
		return output;
	}
	if ([output isKindOfClass:NSString.class]) {
		NSString *string = output;
		if ([string hasPrefix:@"/"]) {
			return [NSURL fileURLWithPath:string];
		}
		return [NSURL URLWithString:string];
	}
	if ([output respondsToSelector:@selector(fileURL)]) {
		id url = [output performSelector:@selector(fileURL)];
		return [url isKindOfClass:NSURL.class] ? url : nil;
	}
	return nil;
}

/*! Invalidates the running run's token and returns to idle. The late result is ignored. */
- (void)cancelGeneration
{
	[_stateLock lock];
	_generationToken += 1;
	BOOL wasGenerating = (_state == FxGripMLVideoStateGenerating);
	[_stateLock unlock];
	if (wasGenerating) {
		[self moveToState:FxGripMLVideoStateIdle progress:-1.0 clipURL:nil error:nil];
	}
}

/*! Clears a ready or failed state and the stored clip URL back to idle. */
- (void)resetGeneration
{
	[_stateLock lock];
	_generationToken += 1;
	[_stateLock unlock];
	[self moveToState:FxGripMLVideoStateIdle progress:-1.0 clipURL:nil error:nil];
}

#pragma mark Render

/*! Renders from the generated clip when ready; otherwise the source unchanged. The backend never
	runs on the render path: a clip generation is started explicitly, not per frame. */
- (BOOL)renderMLFromSourceTile:(nullable FxImageTile *)sourceTile
			 toDestinationTile:(nullable FxImageTile *)destinationTile
						atTime:(CMTime)time
						 error:(NSError * _Nullable *)outError
{
	NSURL *clipURL = self.generatedClipURL;
	if (self.generationState == FxGripMLVideoStateReady && clipURL != nil) {
		NSError *frameError = nil;
		if ([self renderFrameFromGeneratedClip:clipURL
							 toDestinationTile:destinationTile
										atTime:time
										 error:&frameError]) {
			return YES;
		}
	}

	id imageInput = [self imageInputForSourceTile:sourceTile atTime:time error:outError];
	if (imageInput == nil) {
		return NO;
	}
	return [self writeImageOutput:imageInput toDestinationTile:destinationTile atTime:time error:outError];
}

/*! The clip-sampling seam. The default returns NO, which falls back to the source unchanged. */
- (BOOL)renderFrameFromGeneratedClip:(NSURL *)clipURL
				   toDestinationTile:(nullable FxImageTile *)destinationTile
							  atTime:(CMTime)time
							   error:(NSError * _Nullable *)outError
{
	return NO;
}

@end
