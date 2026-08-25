//
//  FxGripInferenceBackend.h
//  FxGrip
//

#ifndef FxGripInferenceBackend_h
#define FxGripInferenceBackend_h

#import <Foundation/Foundation.h>
#import "FxGripInferenceRequest.h"
#import "FxGripInferenceResult.h"

NS_ASSUME_NONNULL_BEGIN

/*!
	@protocol   FxGripInferenceBackend
	@abstract   A swappable inference engine that turns a request into a result.
	@discussion Introduced in FxGrip 1.0. The backend is the seam between an FxGrip ML effect
				and whatever runs the model. FxGrip ships engines that depend only on Apple
				frameworks (a Core ML runner, a remote OpenAI-compatible client, and a
				passthrough mock); a plugin adopts this protocol to bring a heavier runtime
				(MLX, a C or Rust engine) without FxGrip linking it.

				runInferenceForRequest:error: is synchronous by contract. Inference often
				takes seconds, too long for a render call, so a caller runs it off the render
				thread and caches the result by frame. A backend reports readiness through
				isReady; a caller checks it before a run and falls back or defers when a model
				is not yet loaded.
*/
@protocol FxGripInferenceBackend <NSObject>

@required

/*! YES when the backend can serve a run now: its model and resources are loaded. */
@property (nonatomic, readonly) BOOL isReady;

/*! A short stable identifier for the engine, for logging and selection (for example
	"passthrough", "coreml", "remote"). */
@property (nonatomic, readonly, copy) NSString *backendIdentifier;

/*!
	@method     runInferenceForRequest:error:
	@abstract   Runs the model synchronously and returns its outputs, or nil with an error.
	@discussion The backend reads the request's inputs and parameters, runs the model, and
				returns a result. It returns nil and sets error when it is not ready, a
				required input is missing, or the run fails. Do not call on the render thread
				for a multi-second model; run it off-thread and cache the result.
*/
- (nullable FxGripInferenceResult *)runInferenceForRequest:(FxGripInferenceRequest *)request
													error:(NSError **)error;

@optional

/*!
	@method     prepareWithError:
	@abstract   Loads the model and resources so a later run is ready; returns YES on success.
	@discussion A caller invokes this once, off the render thread, before the first run. A
				backend with nothing to load (the passthrough mock) does not implement it or
				returns YES immediately.
*/
- (BOOL)prepareWithError:(NSError **)error;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripInferenceBackend_h */
