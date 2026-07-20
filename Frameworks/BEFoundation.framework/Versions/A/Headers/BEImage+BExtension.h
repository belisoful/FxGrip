/*!
 @header     BEImage+BExtension.h
 @copyright  -© 2025 Delicense - @belisoful. All rights released.
 @author     belisoful@icloud.com
 @abstract   CGImage/CIImage/data round-trips and resizing for @c BEImage
             (@c NSImage on macOS, @c UIImage on iOS).
 @discussion @c UIImage exposes @c CGImage, @c CIImage, @c +imageWithCGImage:,
             @c +imageWithCIImage:, @c pngData, and JPEG encoding; @c NSImage does not, and
             getting bytes out of an @c NSImage (via @c TIFFRepresentation and
             @c NSBitmapImageRep) and resizing it are both awkward. This category provides one
             API for those operations, plus pixel size and resizing, on both platforms, so the
             same call sites compile and behave on each.

             The round-trip and data members use representation-style names
             (@c imageFromCGImage:, @c pngRepresentation, following the @c TIFFRepresentation
             idiom) rather than UIImage's spellings, renamed in 1.1 from the 1.0 UIImage-parity
             names. Apple frameworks attach private same-named category methods to these
             classes at runtime (PencilKit, when loaded, adds @c +[NSImage imageWithCGImage:]
             and @c -CGImage), and which duplicate method wins is undefined, so a category on a
             framework class must not reuse Apple's method names. The factories return @c nil
             for a @c NULL / @c nil input on both platforms.

             @code
             CIImage *ci = source.CIImageRepresentation;
             BEImage *rebuilt = [BEImage imageFromCIImage:ci];
             BEImage *thumb = [rebuilt resizedToFitSize:CGSizeMake(128, 128)];
             NSData *png = thumb.pngRepresentation;
             @endcode
 */

#ifndef BEImage_BExtension_h
#define BEImage_BExtension_h

#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>
#import <BEFoundation/BEPlatformTypes.h>

NS_ASSUME_NONNULL_BEGIN

@interface BEImage (BExtension)

#pragma mark - CGImage / CIImage round-trips

/*! @property CGImageRepresentation The image rendered as a @c CGImage, or @c NULL if it
    cannot be represented. On iOS this is the underlying @c CGImage; a @c CIImage -backed
    @c UIImage returns @c NULL. */
@property (nonatomic, readonly, nullable) CGImageRef CGImageRepresentation;

/*! @property CIImageRepresentation The image as a @c CIImage, or @c nil if it cannot be
    represented. On iOS a bitmap-backed image is wrapped via its @c CGImage. */
@property (nonatomic, readonly, nullable) CIImage *CIImageRepresentation;

/*! @method imageFromCGImage: Creates an image from a @c CGImage at its pixel dimensions.
    Returns @c nil for a @c NULL image, on both platforms. */
+ (nullable BEImage *)imageFromCGImage:(nullable CGImageRef)cgImage;

/*! @method imageFromCIImage: Creates an image backed by a @c CIImage.
    Returns @c nil for a @c nil image, on both platforms. */
+ (nullable BEImage *)imageFromCIImage:(nullable CIImage *)ciImage;

#pragma mark - Data

/*! @property pngRepresentation PNG-encoded data for the image, or @c nil on failure. */
@property (nonatomic, readonly, nullable) NSData *pngRepresentation;

/*!
 @method     jpegRepresentationWithCompressionQuality:
 @abstract   JPEG-encoded data for the image.
 @param      quality 0.0 (smallest) to 1.0 (best). Values outside the range are clamped.
 @return     JPEG data, or @c nil on failure.
 */
- (nullable NSData *)jpegRepresentationWithCompressionQuality:(CGFloat)quality;

#pragma mark - Size & resizing

/*! @property pixelSize The image's size in pixels (the backing @c CGImage dimensions on macOS, or point size times scale on iOS), as opposed to its
    logical point @c size. */
@property (nonatomic, readonly) CGSize pixelSize;

/*!
 @method     resizedToSize:
 @abstract   A new image drawn at exactly @c size (logical points), ignoring aspect ratio.
 @return     The resized image, or @c nil if @c size is empty or rendering fails.
 */
- (nullable BEImage *)resizedToSize:(CGSize)size;

/*!
 @method     resizedToFitSize:
 @abstract   A new image scaled to fit within @c boundingSize, preserving aspect ratio
             (the whole image fits; letterboxing is the caller's concern).
 */
- (nullable BEImage *)resizedToFitSize:(CGSize)boundingSize;

/*!
 @method     resizedToFillSize:
 @abstract   A new image scaled to fill @c boundingSize, preserving aspect ratio
             (the image covers the box; overflow extends past it).
 */
- (nullable BEImage *)resizedToFillSize:(CGSize)boundingSize;

@end

NS_ASSUME_NONNULL_END

#endif // !BEImage_BExtension_h
