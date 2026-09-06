/*!
	@file       FxGripTileableGenerator.m
	@copyright  Copyright © 2020-2023 Apple, Inc. All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripTileableGenerator
	@abstract   Implements the destination-bounds and source-tile behavior of a tileable generator.
	@discussion Introduced in FxGrip 0.1.0. The generator reports the destination image's pixel
	            bounds as its output rect and reports an empty source-tile rect, because a
	            generator draws its output without sampling a source image. Both the pluginState
	            and pluginCoder render paths are handled.
*/

#import "FxGripTileableGenerator.h"


#pragma mark -
#pragma mark FxGripTileableGenerator Implementation


/*!
	@abstract	The FxGrip base class for tileable generator plugins.
	@discussion	Introduced in FxGrip 0.1.0. The output rect covers the destination image's pixel
				bounds and the source-tile rect is empty for every source index.
*/
@implementation FxGripTileableGenerator

//---------------------------------------------------------
// destinationImageRect:sourceImages:destinationImage:pluginState:atTime:error
//
// This method will calculate the rectangular bounds of the output
// image given the various inputs and plug-in state
// at the given render time.
// It will pass in an array of images, the plug-in state
// returned from your plug-in's -pluginStateAtTime:error: method,
// and the render time.
//---------------------------------------------------------

/*!
	@method		destinationImageRect:sourceImages:destinationImage:pluginState:atTime:error:
	@abstract	Reports the destination image's pixel bounds as the generator's output rect.
	@discussion	Introduced in FxGrip 0.1.0. A generator produces output for the whole destination
				image, so the output rect is the destination image's pixel bounds.
	@return		YES. */
- (BOOL)destinationImageRect:(FxRect *)destinationImageRect
				sourceImages:(NSArray<FxImageTile *> *)sourceImages
			destinationImage:(nonnull FxImageTile *)destinationImage
				 pluginState:(NSData *)pluginState
					  atTime:(CMTime)renderTime
					   error:(NSError * _Nullable *)outError
{
	// This is a generator so always use the output image's pixel bounds
	*destinationImageRect = destinationImage.imagePixelBounds;
	
	return YES;
	
}


//---------------------------------------------------------
// sourceTileRect:sourceImageIndex:sourceImages:destinationTileRect:destinationImage:pluginState:atTime:error
//
// Calculate tile of the source image we need
// to render the given output tile.
//---------------------------------------------------------

/*!
	@method		sourceTileRect:sourceImageIndex:sourceImages:destinationTileRect:destinationImage:pluginState:atTime:error:
	@abstract	Reports an empty source-tile rect because a generator has no source image.
	@return		YES. */
- (BOOL)sourceTileRect:(FxRect *)sourceTileRect
	  sourceImageIndex:(NSUInteger)sourceImageIndex
		  sourceImages:(NSArray<FxImageTile *> *)sourceImages
   destinationTileRect:(FxRect)destinationTileRect
	  destinationImage:(FxImageTile *)destinationImage
		   pluginState:(NSData *)pluginState
				atTime:(CMTime)renderTime
				 error:(NSError * _Nullable *)outError
{
	// Since this is a generator, there is no source tile
	*sourceTileRect = kFxRect_Empty;
	
	return YES;
}



//---------------------------------------------------------
// destinationImageRect:sourceImages:destinationImage:pluginState:atTime:error
//
// This method will calculate the rectangular bounds of the output
// image given the various inputs and plug-in state
// at the given render time.
// It will pass in an array of images, the plug-in state
// returned from your plug-in's -pluginStateAtTime:error: method,
// and the render time.
//---------------------------------------------------------

/*!
	@method		destinationImageRect:sourceImages:destinationImage:pluginCoder:atTime:error:
	@abstract	Reports the destination image's pixel bounds as the generator's output rect.
	@discussion	Introduced in FxGrip 0.1.0. This is the pluginCoder render path of the same
				destination-bounds behavior.
	@return		YES. */
- (BOOL)destinationImageRect:(FxRect *)destinationImageRect
				sourceImages:(NSArray<FxImageTile *> *)sourceImages
			destinationImage:(nonnull FxImageTile *)destinationImage
				 pluginCoder:(NSCoder * _Nonnull)pluginCoder
					  atTime:(CMTime)renderTime
					   error:(NSError * _Nullable *)outError
{
	// This is a generator so always use the output image's pixel bounds
	*destinationImageRect = destinationImage.imagePixelBounds;
	
	return YES;
	
}


//---------------------------------------------------------
// sourceTileRect:sourceImageIndex:sourceImages:destinationTileRect:destinationImage:pluginState:atTime:error
//
// Calculate tile of the source image we need
// to render the given output tile.
//---------------------------------------------------------

/*!
	@method		sourceTileRect:sourceImageIndex:sourceImages:destinationTileRect:destinationImage:pluginCoder:atTime:error:
	@abstract	Reports an empty source-tile rect because a generator has no source image.
	@return		YES. */
- (BOOL)sourceTileRect:(FxRect *)sourceTileRect
	  sourceImageIndex:(NSUInteger)sourceImageIndex
		  sourceImages:(NSArray<FxImageTile *> *)sourceImages
   destinationTileRect:(FxRect)destinationTileRect
	  destinationImage:(FxImageTile *)destinationImage
		   pluginCoder:(NSCoder * _Nonnull)pluginCoder
				atTime:(CMTime)renderTime
				 error:(NSError * _Nullable *)outError
{
	// Since this is a generator, there is no source tile
	*sourceTileRect = kFxRect_Empty;
	
	return YES;
}

@end
