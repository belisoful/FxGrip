//
//  FxGripMLVideoGenerator.h
//  FxGrip
//

#ifndef FxGripMLVideoGenerator_h
#define FxGripMLVideoGenerator_h

#import "FxGripMLVideoEffect.h"

NS_ASSUME_NONNULL_BEGIN

/*!
	@class      FxGripMLVideoGenerator
	@abstract   A generator template whose model produces a whole clip from no source.
	@discussion Introduced in FxGrip 1.0. The generator counterpart of ``FxGripMLVideoEffect``:
				the generation lifecycle, the clip handling, and the state hooks are inherited
				unchanged; the generator supplies its inputs through the inherited
				generationInputsAtTime:. There is no source clip, so until the generated clip is
				ready — and when a frame of it fails — rendering calls
				writePlaceholderToDestinationTile:atTime:error:, whose default leaves the
				destination as the host provided it.
*/
@interface FxGripMLVideoGenerator : FxGripMLVideoEffect

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

#endif /* FxGripMLVideoGenerator_h */
