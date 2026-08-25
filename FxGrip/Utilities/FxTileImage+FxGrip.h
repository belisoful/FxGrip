//
//  FxTileImage+FxGrip.h
//  XPC Service
//
//  Created by ~ ~ on 3/19/24.
//

#ifndef FxTileImage_FxGrip_h
#define FxTileImage_FxGrip_h

#import <FxPlug/FxPlugSDK.h>

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

NS_ASSUME_NONNULL_END

#endif	//	NSCoder_AtIndex_AtTime
