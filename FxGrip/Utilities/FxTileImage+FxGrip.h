//
//  FxTileImage+FxGrip.h
//  XPC Service
//
//  Created by ~ ~ on 3/19/24.
//

#ifndef FxTileImage_FxGrip_h
#define FxTileImage_FxGrip_h

#import <FxPlug/FxPlugSDK.h>
#import <Metal/Metal.h>
#import <CoreImage/CoreImage.h>

NS_ASSUME_NONNULL_BEGIN

/*!
	@function   FxGripImageRectForPixelBounds
	@abstract   Maps a pixel-space rectangle to image space through an inverse pixel transform.
	@discussion Introduced in FxGrip 1.0. Transforms the four corners of pixelBounds by
				inverseTransform and returns their bounding box, so a rotated or skewed transform
				still yields the covering image-space rectangle. Returns CGRectZero when
				inverseTransform is nil.
*/
CGRect FxGripImageRectForPixelBounds(FxRect pixelBounds, FxMatrix44 *_Nullable inverseTransform);

/*!
	@function   FxGripPixelBoundsForImageRect
	@abstract   Maps an image-space rectangle to pixel bounds through a pixel transform.
	@discussion Introduced in FxGrip 1.0. Transforms the four corners of imageRect by transform,
				takes their bounding box, and rounds it outward to whole pixels so the result
				covers the region. Returns the empty rectangle when transform is nil.
*/
FxRect FxGripPixelBoundsForImageRect(CGRect imageRect, FxMatrix44 *_Nullable transform);


@interface FxImageTile (FxGrip)

@property (readonly, nonatomic) id<MTLDevice>   device;

@property (readonly) OSType pixelFormat;

//@property (readonly) MTLPixelFormat glPixelFormat;

@property (readonly) MTLPixelFormat metalPixelFormat;

- (id<MTLTexture>)metalTexture;

/*! A pixel-space point converted to image space through the tile's inverse pixel transform. */
- (CGPoint)imagePointFromPixelPoint:(CGPoint)pixelPoint;

/*! An image-space point converted to pixel space through the tile's pixel transform. */
- (CGPoint)pixelPointFromImagePoint:(CGPoint)imagePoint;

/*! The tile's pixel bounds expressed in image space. */
- (CGRect)imageSpaceBounds;

/*! The pixel bounds covering an image-space rectangle, for cropping or sampling this tile. */
- (FxRect)pixelBoundsForImageRect:(CGRect)imageRect;

/*! An image-space rectangle covering a pixel-space region of this tile. */
- (CGRect)imageRectForPixelBounds:(FxRect)pixelBounds;

@end


@interface FxImageTile (FxGripText)

/*!
	@method     fxg_compositeCIImage:opacity:error:
	@abstract   Composites a Core Image overlay over this tile's output texture.
	@param      overlay A CIImage positioned in the tile texture's pixel space, where the
					origin is the texture's bottom-left corner and one unit is one pixel.
	@param      opacity The overlay's composite alpha, from 0.0 to 1.0. The overlay's own
					per-pixel alpha is scaled by this value, so transparent regions stay
					transparent.
	@discussion Introduced in FxGrip 1.0. Reads the tile's output texture as the background,
				source-over composites overlay onto it, and writes the result back to the
				same texture. Returns NO and sets outError when the tile has no backing
				Metal device or the composite fails. The workhorse for both text drawing and
				watermarking. This method has no dependency on FxGrip's extension,
				notification, or FxFactory subsystems.
*/
- (BOOL)fxg_compositeCIImage:(CIImage *)overlay
					 opacity:(CGFloat)opacity
					   error:(NSError *_Nullable *_Nullable)outError;

/*!
	@method     fxg_drawText:attributes:atPixelPoint:error:
	@abstract   Rasterizes text and composites it onto this tile at native resolution.
	@param      text The string to draw.
	@param      attributes The attributed-string attributes carrying font and color.
	@param      pixelPoint The bottom-left placement of the text in the tile's pixel space.
	@discussion Introduced in FxGrip 1.0. Draws the text opaque. Returns NO and sets outError
				when rasterization or compositing fails.
*/
- (BOOL)fxg_drawText:(NSString *)text
		 attributes:(NSDictionary<NSAttributedStringKey, id> *)attributes
	   atPixelPoint:(CGPoint)pixelPoint
			  error:(NSError *_Nullable *_Nullable)outError;

@end

NS_ASSUME_NONNULL_END

#endif	//	NSCoder_AtIndex_AtTime
