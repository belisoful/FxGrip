/*!
	@file       FxGripMLImageEffect.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripMLImageEffect
	@abstract   The tileable-effect template that renders a source image through an inference backend.
	@discussion Introduced in FxGrip 0.1.0. The template owns the render-thread orchestration for an
	            image-to-image model. It turns the source tile into the backend's image input, runs
	            the backend, and writes the backend's image output to the destination tile. The
	            backend defaults to an FxGripPassthroughBackend, so the effect renders its source
	            unchanged with no model present. A per-frame cache stores each result so a slow model
	            runs once per frame. A subclass declares the model's specifics and inherits the
	            plumbing.
*/

#ifndef FxGripMLImageEffect_h
#define FxGripMLImageEffect_h

#import <Metal/Metal.h>
#import "FxGripTileableEffect.h"
#import "FxGripInferenceBackend.h"

NS_ASSUME_NONNULL_BEGIN

/*!
	@class      FxGripMLImageEffect
	@abstract   A tileable-effect template that renders one source image through an inference
				backend.
	@discussion Introduced in FxGrip 0.1.0. Owns the render-thread orchestration for an
				image-to-image model: it turns the source tile into the backend's image input,
				runs the backend, and writes the backend's image output to the destination tile.
				A subclass declares the model's specifics and inherits the plumbing.

				The image representation that flows through the backend is an id<MTLTexture> by
				default, so the backend owns any conversion to a tensor. A subclass overrides
				imageInputForSourceTile:atTime:error: and writeImageOutput:toDestinationTile:atTime:error:
				to change the representation.

				inferenceBackend defaults to an FxGripPassthroughBackend, so the effect renders
				its source unchanged with no model present and stays green in tests. When the
				backend is not ready, the template renders the source unchanged rather than
				failing, so a timeline stays usable while a model loads.

				runInferenceForRequest: is synchronous, and inference is often seconds long. A
				later layer caches the result by frame; a subclass should not treat this template
				as safe to run per frame with a heavy model until that caching is in place.
 @todo this should support one or multiple prior frames, or have that feature in a separate class (or sub class)
*/
@interface FxGripMLImageEffect : FxGripTileableEffect

/*! The engine that runs the model. Defaults to defaultInferenceBackend; setting nil restores that
	default. */
@property (nonatomic, strong, null_resettable) id<FxGripInferenceBackend> inferenceBackend;

/*!
	@method     defaultInferenceBackend
	@abstract   The backend the effect uses when none is set. Defaults to an FxGripPassthroughBackend.
	@discussion The lazy inferenceBackend getter calls this when the backend has not been set and
				after it is reset to nil. A subclass overrides it to make another engine the default,
				for example an InferKit backend bridged with FxGripInferenceBridge.
*/
- (id<FxGripInferenceBackend>)defaultInferenceBackend;

/*!
	@method     useInferKitBackend:
	@abstract   Bridges an InferKit backend and installs it as inferenceBackend; returns YES on success.
	@discussion Wraps inferKitBackend with FxGripInferenceBridge and sets it as the effect's backend.
				Returns NO and keeps the current backend when InferKit is not present in the runtime,
				or inferKitBackend does not honor the InferKit backend contract. A host that links
				InferKit creates a backend (a Core ML or MLX engine) and hands it here. The effect
				does not link InferKit.
*/
- (BOOL)useInferKitBackend:(id)inferKitBackend;

/*!
	@property   cacheEnabled
	@abstract   Caches an inference output by frame so a multi-second model runs once per frame.
	@discussion Defaults to YES. Inference is too slow to run per frame, and a model's output is
				a pure function of the frame and parameters, so the template stores each result
				and reuses it on the next render of the same frame. The FxGripMLCache extension
				persists the cache and spills it to the project media folder, so an expensive
				result survives a reopen. Switching the backend or changing a parameter changes
				the cache signature and clears the cache.
*/
@property (nonatomic, assign) BOOL cacheEnabled;

/*! The request input name the source image is placed under. Defaults to "image". */
- (NSString *)inputImageName;

/*! The result output name the destination image is read from. Defaults to "image". */
- (NSString *)outputImageName;

/*! The scalar controls passed to the backend for a frame. Defaults to an empty dictionary;
	a subclass reads its parameters and returns seed, strength, and similar. */
- (NSDictionary<NSString *, id> *)inferenceParametersAtTime:(CMTime)time;

/*!
	@method     imageInputForSourceTile:atTime:error:
	@abstract   Produces the backend's image input from the source tile; nil on failure.
	@discussion The default returns the source tile's Metal texture. Override to pass another
				representation, such as a CVPixelBuffer or an already-preprocessed tensor.
*/
- (nullable id)imageInputForSourceTile:(nullable FxImageTile *)sourceTile
								atTime:(CMTime)time
								 error:(NSError * _Nullable *)outError;

/*!
	@method     writeImageOutput:toDestinationTile:atTime:error:
	@abstract   Writes the backend's image output into the destination tile; NO on failure.
	@discussion The default expects an id<MTLTexture> and blits it into the destination tile's
				texture. Override to accept the representation imageInputForSourceTile: produces.
*/
- (BOOL)writeImageOutput:(id)output
	   toDestinationTile:(nullable FxImageTile *)destinationTile
				  atTime:(CMTime)time
				   error:(NSError * _Nullable *)outError;

/*! Assembles the request from the image input and parameters, runs the backend, and returns
	its result, or nil with an error. */
- (nullable FxGripInferenceResult *)runInferenceForImageInput:(id)imageInput
													  atTime:(CMTime)time
													   error:(NSError * _Nullable *)outError;

/*! The full pass: source tile → image input → backend → image output → destination tile.
	Applies the frame cache when cacheEnabled. Not usually overridden. */
- (BOOL)renderMLFromSourceTile:(nullable FxImageTile *)sourceTile
			 toDestinationTile:(nullable FxImageTile *)destinationTile
						atTime:(CMTime)time
						 error:(NSError * _Nullable *)outError;

#pragma mark Subclass helpers

/*! The Metal device a cached output is reconstructed for: the destination tile's, else the
	input texture's. */
- (nullable id<MTLDevice>)renderDeviceForTile:(nullable FxImageTile *)tile imageInput:(nullable id)imageInput;

/*! Fills outError with an FxGrip-domain error. */
- (void)setError:(NSError * _Nullable *)outError code:(NSInteger)code reason:(nonnull NSString *)reason;

#pragma mark Cache seams

/*! The cache key for a frame. Defaults to the render time normalized to a canonical timescale. */
- (NSInteger)cacheFrameIndexForTime:(CMTime)time;

/*! The cache-validity signature. Defaults to the backend identifier and the frame's parameters;
	a change clears the cache. */
- (NSString *)cacheSignatureForParametersAtTime:(CMTime)time;

/*! The cached output for a frame, reconstructed for device, or nil on a miss. The default reads
	the FxGripMLCache frame data and rebuilds a texture from the stored FxGripImageBuffer. */
- (nullable id)cachedOutputForFrameIndex:(NSInteger)index device:(nullable id<MTLDevice>)device;

/*! Stores an output for a frame. The default writes an FxGripImageBuffer copy of the output
	texture to the FxGripMLCache frame data. */
- (void)storeOutput:(id)output forFrameIndex:(NSInteger)index;

/*! Clears the cache when signature differs from the stored one, then records signature. */
- (void)invalidateCacheIfSignatureChanged:(NSString *)signature;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripMLImageEffect_h */
