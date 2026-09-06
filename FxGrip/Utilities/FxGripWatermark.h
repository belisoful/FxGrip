/*!
	@file       FxGripWatermark.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripWatermark
	@abstract   Renders a text watermark onto a render tile.
	@discussion Introduced in FxGrip 0.1.0. FxGripWatermarkConfiguration describes the text,
	            typography, and layout. FxGripWatermark renders that configuration in one of four
	            styles: single, diagonal tiled, banner, or corner. The class depends only on the
	            base FxGrip tile and the Metal layer, so a plug-in can drive its own licensing or
	            activation logic and reuse the watermarking here.
*/

#ifndef FxGripWatermark_h
#define FxGripWatermark_h

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <Metal/Metal.h>
#import <CoreImage/CoreImage.h>
#import <FxPlug/FxPlugSDK.h>

NS_ASSUME_NONNULL_BEGIN

/*!
	@enum       FxGripWatermarkStyle
	@abstract   The layout a watermark uses to cover a frame.
	@constant   FxGripWatermarkStyleSingle One text placement centered on the frame, rotated
					by the configuration's angle.
	@constant   FxGripWatermarkStyleDiagonalTiled The text repeated across the whole frame on
					a grid, rotated 45 degrees.
	@constant   FxGripWatermarkStyleBanner One text placement scaled to span the frame width,
					centered vertically, rotated by the configuration's angle.
	@constant   FxGripWatermarkStyleCorner One text placement pinned to a corner with an inset.
*/
typedef NS_ENUM(NSInteger, FxGripWatermarkStyle) {
	FxGripWatermarkStyleSingle = 0,
	FxGripWatermarkStyleDiagonalTiled,
	FxGripWatermarkStyleBanner,
	FxGripWatermarkStyleCorner,
};

/*!
	@enum       FxGripWatermarkCorner
	@abstract   The corner a corner-style watermark anchors to.
*/
typedef NS_ENUM(NSInteger, FxGripWatermarkCorner) {
	FxGripWatermarkCornerBottomLeft = 0,
	FxGripWatermarkCornerBottomRight,
	FxGripWatermarkCornerTopLeft,
	FxGripWatermarkCornerTopRight,
};

/*!
	@class      FxGripWatermarkConfiguration
	@abstract   A declarative description of a watermark.
	@discussion Introduced in FxGrip 0.1.0. Carries the text, typography, and layout that
				`FxGripWatermark` renders. A default instance draws a diagonally tiled,
				semi-transparent watermark.
*/
@interface FxGripWatermarkConfiguration : NSObject <NSCopying>

/*! The text to render. An empty string renders nothing. */
@property (copy, nonatomic) NSString *text;

/*! The font name. Defaults to Helvetica. An unrecognized name falls back to the system font. */
@property (copy, nonatomic) NSString *fontName;

/*! The font point size. Defaults to 48. */
@property (nonatomic) CGFloat fontSize;

/*! The text color. Defaults to white. */
@property (strong, nonatomic) NSColor *color;

/*! The rotation in degrees for the Single and Banner styles. Ignored by DiagonalTiled,
	which is fixed at 45 degrees, and by Corner, which does not rotate. */
@property (nonatomic) CGFloat angleDegrees;

/*! The composite opacity, from 0.0 to 1.0. Defaults to 0.5. */
@property (nonatomic) CGFloat opacity;

/*! The shadow blur radius in pixels. Applies only when shadowColor is set. */
@property (nonatomic) CGFloat blur;

/*! The drop-shadow color drawn under the text. nil draws no shadow. */
@property (strong, nonatomic, nullable) NSColor *shadowColor;

/*! The layout style. Defaults to DiagonalTiled. */
@property (nonatomic) FxGripWatermarkStyle style;

/*! The gap in pixels between repeats for DiagonalTiled. Defaults to 80 by 80. */
@property (nonatomic) CGSize tileSpacing;

/*! The anchor corner for the Corner style. Defaults to BottomRight. */
@property (nonatomic) FxGripWatermarkCorner corner;

/*! The edge inset in pixels for the Corner style. Defaults to 24. */
@property (nonatomic) CGFloat inset;

/*! A configuration with the given text and every other field at its default. */
+ (instancetype)configurationWithText:(NSString *)text;

/*! A diagonally tiled, semi-transparent trial watermark. The common unlicensed look. */
+ (instancetype)trialConfigurationWithText:(NSString *)text;

/*! A single centered watermark at 50% opacity. */
+ (instancetype)centeredConfigurationWithText:(NSString *)text;

@end

/*!
	@class      FxGripWatermark
	@abstract   Renders a watermark onto a render tile.
	@discussion Introduced in FxGrip 0.1.0. A subclass of `FxGripTileableEffect`, a licensing
				system, or any other caller composites a watermark by building a
				configuration and calling `renderOntoImageTile:error:`. The class depends only
				on the base FxGrip tile and Metal layer. It has no dependency on FxGrip's
				extension, notification, or FxFactory subsystems, so a plugin can drive its
				own registration or activation logic and reuse the watermarking here.
*/
@interface FxGripWatermark : NSObject

/*! The configuration this watermark renders. A copy of the value passed at initialization. */
@property (readonly, copy, nonatomic) FxGripWatermarkConfiguration *configuration;

+ (instancetype)watermarkWithConfiguration:(FxGripWatermarkConfiguration *)configuration;

- (instancetype)initWithConfiguration:(FxGripWatermarkConfiguration *)configuration NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

/*!
	@method     watermarkImageForSize:device:
	@abstract   Builds the watermark as a Core Image positioned in a frame of the given size.
	@param      pixelSize The frame size in pixels. The result is cropped to this rectangle.
	@param      device The Metal device that backs text rasterization.
	@discussion The image is opaque; the configuration's opacity is applied when the image is
				composited. Returns nil when the text is empty or text generation fails.
				Exposed so the generated image can be inspected without a render tile.
*/
- (nullable CIImage *)watermarkImageForSize:(CGSize)pixelSize device:(id<MTLDevice>)device;

/*!
	@method     renderOntoImageTile:error:
	@abstract   Composites the configured watermark onto the destination tile.
	@discussion Returns NO and sets outError when the tile has no backing device or the Metal
				work fails. Returns YES with no change when the text is empty.
*/
- (BOOL)renderOntoImageTile:(FxImageTile *)destinationImage
					  error:(NSError *_Nullable *_Nullable)outError;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripWatermark_h */
