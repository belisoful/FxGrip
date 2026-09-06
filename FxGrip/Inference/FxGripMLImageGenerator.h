/*!
	@file       FxGripMLImageGenerator.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripMLImageGenerator
	@abstract   The generator template whose model produces each frame's image from no source.
	@discussion Introduced in FxGrip 0.1.0. The generator is the counterpart of FxGripMLImageEffect.
	            There is no source clip, so the request carries only the generator inputs and the
	            inherited parameters. The per-frame cache applies unchanged. A generator has no
	            source to fall back to, so until the backend is ready rendering draws a placeholder.
*/

#ifndef FxGripMLImageGenerator_h
#define FxGripMLImageGenerator_h

#import "FxGripMLImageEffect.h"

NS_ASSUME_NONNULL_BEGIN

/*!
	@class      FxGripMLImageGenerator
	@abstract   A generator template whose model produces each frame's image from no source.
	@discussion Introduced in FxGrip 0.1.0. The generator counterpart of ``FxGripMLImageEffect``:
				there is no source clip, so the request carries only generatorInputsAtTime: (a
				prompt, conditioning data) and the inherited inferenceParametersAtTime:. The
				per-frame cache applies unchanged, so a slow model still runs once per frame.

				A generator has no source to fall back to. Until the backend is ready, and when it
				fails, rendering calls writePlaceholderToDestinationTile:atTime:error:, whose
				default leaves the destination as the host provided it; override it to clear or
				draw a placeholder.

				The generator tile geometry is inherited from FxGripTileableGenerator's convention:
				the destination rect is the output's pixel bounds and there is no source tile.
*/
@interface FxGripMLImageGenerator : FxGripMLImageEffect

/*! The named inputs of a frame's generation request (a prompt, conditioning). Defaults to empty. */
- (NSDictionary<NSString *, id> *)generatorInputsAtTime:(CMTime)time;

/*!
	@method     writePlaceholderToDestinationTile:atTime:error:
	@abstract   Renders the not-ready placeholder; returns YES when the tile is presentable.
	@discussion The default returns YES without drawing. Override to clear the tile or draw a
				waiting state.
*/
- (BOOL)writePlaceholderToDestinationTile:(nullable FxImageTile *)destinationTile
								   atTime:(CMTime)time
									error:(NSError * _Nullable *)outError;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripMLImageGenerator_h */
