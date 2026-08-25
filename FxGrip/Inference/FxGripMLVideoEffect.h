//
//  FxGripMLVideoEffect.h
//  FxGrip
//

#ifndef FxGripMLVideoEffect_h
#define FxGripMLVideoEffect_h

#import "FxGripMLImageEffect.h"

NS_ASSUME_NONNULL_BEGIN

/*!
	@enum       FxGripMLVideoState
	@abstract   The lifecycle of a generated clip.
*/
typedef NS_ENUM(NSInteger, FxGripMLVideoState) {
	FxGripMLVideoStateIdle			= 0,
	FxGripMLVideoStateGenerating	= 1,
	FxGripMLVideoStateReady			= 2,
	FxGripMLVideoStateFailed		= 3,
};

/*!
	@class      FxGripMLVideoEffect
	@abstract   A tileable-effect template whose model generates a whole clip rather than a frame.
	@discussion Introduced in FxGrip 1.0. A generated clip is not a per-frame pure function: the
				model runs once, for seconds to minutes, and produces a movie file. This template
				owns that lifecycle. beginGenerationAtTime: assembles the request and runs the
				backend on the generation queue; the state moves Idle → Generating → Ready or
				Failed, and generationStateDidChange fires on each move so a subclass can mirror
				the state into a status or progress parameter, or run the generation behind the
				host's analysis pass.

				While the clip is not ready, rendering falls back to the inherited path, which
				draws the source unchanged, so the timeline stays responsive during a generation.
				Once ready, rendering delegates each frame to
				renderFrameFromGeneratedClip:toDestinationTile:atTime:error:, which a subclass
				implements by sampling the clip (AVFoundation frame extraction is host-side work).

				The backend seam is inherited: hand an InferKit backend to useInferKitBackend:.
				The generated clip is read from the result's videoOutputName output as an NSURL,
				a file-path or URL string, or any object with a fileURL, which admits an InferKit
				video asset without naming its class. The per-frame cache is disabled; the clip
				file is the cache.
*/
@interface FxGripMLVideoEffect : FxGripMLImageEffect

/*! The clip lifecycle state. Thread-safe. */
@property (readonly, nonatomic) FxGripMLVideoState generationState;

/*! Progress in 0…1, or -1 while indeterminate. A backend without progress stays at -1. */
@property (readonly, nonatomic) double generationProgress;

/*! The generated movie file once the state is ready; nil otherwise. */
@property (readonly, nullable, nonatomic) NSURL *generatedClipURL;

/*! The failure once the state is failed; nil otherwise. */
@property (readonly, nullable, nonatomic) NSError *generationError;

/*! The queue the generation runs on. Defaults to a global utility queue. */
@property (readwrite, strong, nonatomic) dispatch_queue_t generationQueue;

/*! The result output name the clip is read from. Defaults to "video". */
- (NSString *)videoOutputName;

/*! The named inputs of a generation request (a prompt, a reference image). Defaults to empty. */
- (NSDictionary<NSString *, id> *)generationInputsAtTime:(CMTime)time;

/*!
	@method     beginGenerationAtTime:
	@abstract   Starts a generation on the generation queue; no-op while one is running.
	@discussion Builds the request from generationInputsAtTime: and the inherited
				inferenceParametersAtTime:, moves to Generating, runs the backend, and finishes
				Ready with the clip URL or Failed with the error. A not-ready backend fails
				without running.
*/
- (void)beginGenerationAtTime:(CMTime)time;

/*! Discards the running generation's result and returns to idle. The backend run itself is not
	interrupted; its late result is ignored. */
- (void)cancelGeneration;

/*! Clears a ready or failed state (and the stored clip URL) back to idle. */
- (void)resetGeneration;

/*!
	@method     generationStateDidChange
	@abstract   Fires after every state move, on the queue that moved it.
	@discussion The default does nothing. A subclass updates its status or progress parameter
				here (through an out-of-band access context when off a host call) and invalidates
				the render so the host repaints.
*/
- (void)generationStateDidChange;

/*!
	@method     renderFrameFromGeneratedClip:toDestinationTile:atTime:error:
	@abstract   Writes one frame of the generated clip into the destination tile.
	@discussion The default returns NO, which falls back to rendering the source unchanged. A
				subclass samples the clip for the frame's time and writes the destination tile.
*/
- (BOOL)renderFrameFromGeneratedClip:(NSURL *)clipURL
				   toDestinationTile:(nullable FxImageTile *)destinationTile
							  atTime:(CMTime)time
							   error:(NSError * _Nullable *)outError;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripMLVideoEffect_h */
