/*!
	@file       FxGripMLVideoGenerator.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripMLVideoGenerator
	@abstract   Implements the generator template whose model produces a whole clip from no source.
	@discussion Introduced in FxGrip 0.1.0. The generator geometry reports the full output bounds as
	            the destination rect and an empty source tile rect. The render path samples the ready
	            clip and otherwise draws the placeholder, since a generator has no source to fall
	            back to. The generation lifecycle is inherited from FxGripMLVideoEffect.
*/

#import "FxGripMLVideoGenerator.h"
#import "FxGrip_ARC.h"

/*!
	@abstract	The generator template whose model produces a whole clip from no source.
	@discussion	Introduced in FxGrip 0.1.0. The generation lifecycle, the clip handling, and the
				state hooks are inherited unchanged.
*/
@implementation FxGripMLVideoGenerator

#pragma mark Generator geometry

/*! The destination rect is the output's full pixel bounds. */
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

/*! There is no source, so the source tile rect is empty. */
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

- (BOOL)writePlaceholderToDestinationTile:(nullable FxImageTile *)destinationTile
								   atTime:(CMTime)time
									error:(NSError * _Nullable *)outError
{
	return YES;
}

#pragma mark Render

/*! Renders from the generated clip when ready; otherwise the placeholder. A generator has no
	source to fall back to, and the backend never runs on the render path. */
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
	return [self writePlaceholderToDestinationTile:destinationTile atTime:time error:outError];
}

@end
