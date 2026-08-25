//
//  FxGripMLVideoGenerator.m
//  FxGrip
//

#import "FxGripMLVideoGenerator.h"
#import "FxGrip_ARC.h"

@implementation FxGripMLVideoGenerator

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
