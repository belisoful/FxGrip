/*!
@header BEMetalHelper.h
@copyright -© 2025 Delicense - @belisoful. All rights released.
@date 2025-06-10
@author		belisoful@icloud.com
@abstract Utilities for Metal texture processing and image conversion operations.
@discussion The BEMetalHelper class provides efficient methods for converting Metal textures to BEImage objects and performing grayscale to RGB color space conversions using Apple's vImage framework for optimal performance.
*/

#ifndef BEMetalHelper_h
#define BEMetalHelper_h

#import <Foundation/Foundation.h>
#import <Accelerate/Accelerate.h>
#import <Metal/Metal.h>
#import <BEFoundation/BEPlatformTypes.h>

NS_ASSUME_NONNULL_BEGIN

/*!
@class BEMetalHelper
@abstract A utility class for Metal texture processing and image conversion operations.
@discussion BEMetalHelper provides static methods for converting Metal textures to BEImage objects and performing efficient grayscale to RGB color space conversions using Apple's vImage framework. The class supports various pixel formats including 8-bit, 16-bit float, and 32-bit float textures.

@code
// After all GPU work writing to `texture` has completed, convert a CPU-readable
// (MTLStorageModeShared) texture to a BEImage.
id<MTLTexture> texture = renderTarget; // e.g. MTLPixelFormatRGBA8Unorm, Shared
BEImage *image = [BEMetalHelper imageFromTexture:texture];
if (image) {
    [imageView setImage:image];
}
@endcode
*/
@interface BEMetalHelper : NSObject

/*!
@method imageFromTexture:
@abstract Converts a Metal texture to a BEImage object.
@discussion This method extracts pixel data from a Metal texture and converts it to a BEImage. It supports multiple pixel formats including BGRA8Unorm, RGBA8Unorm, RGBA32Float, R8Unorm, R16Float, and R32Float. For grayscale formats (R8Unorm, R16Float, R32Float), the method automatically converts to RGB format by duplicating the grayscale values across all color channels.
@param texture The Metal texture to convert. Must be a valid MTLTexture object.
@return An BEImage object containing the converted texture data, or nil if the conversion fails, the texture format is unsupported, an allocation fails, or the dimensions would overflow.
@note The method reads pixel data with -[MTLTexture getBytes:...], which requires the texture to be CPU-readable: MTLStorageModeShared (the default on Apple Silicon), or MTLStorageModeManaged after a blit-synchronize. Calling it on a MTLStorageModePrivate texture (possible for render targets on discrete-GPU Macs) is undefined; blit such a texture to a Shared/Managed staging texture first. The caller is also responsible for ensuring all GPU work writing to the texture has completed before calling.
@note The produced image is interpreted in the kCGColorSpaceGenericRGBLinear color space. If your texture holds sRGB-/gamma-encoded *Unorm content, the result will look incorrect; convert or reinterpret accordingly.
@warning This method allocates memory for pixel data conversion. Ensure sufficient memory is available for large textures.
*/
+ (nullable BEImage *)imageFromTexture:(id<MTLTexture>)texture;

/*!
@method convertGray8toXRGB8888WithVImage:width:height:rowBytes:alpha:intoARGB:argbRowBytes:
@abstract Converts 8-bit grayscale image data to XRGB8888 format using vImage.
@discussion This method efficiently converts single-channel 8-bit grayscale data to 4-channel XRGB format by duplicating the grayscale values across the red, green, and blue channels. The conversion uses Apple's vImage framework for optimal performance.
@param grayData Pointer to the source 8-bit grayscale pixel data. Must not be NULL.
@param width The width of the image in pixels. Must be greater than 0.
@param height The height of the image in pixels. Must be greater than 0.
@param grayRowBytes The number of bytes per row in the source grayscale data. Must be greater than 0.
@param alpha The alpha value to use for all pixels (0-255).
@param argbData Pointer to the destination ARGB pixel data buffer. Must not be NULL and must be large enough to hold the converted data.
@param argbRowBytes The number of bytes per row in the destination ARGB data. Must be greater than 0.
@return YES if the conversion was successful, NO if an error occurred or invalid parameters were provided.
@note The destination buffer must be allocated by the caller and must be large enough to hold width * height * 4 bytes.
*/
+ (BOOL)convertGray8toXRGB8888WithVImage:(const uint8_t *)grayData
								   width:(size_t)width
								  height:(size_t)height
								rowBytes:(size_t)grayRowBytes
								   alpha:(uint8_t)alpha
								intoARGB:(uint8_t *)argbData
							argbRowBytes:(size_t)argbRowBytes;

/*!
@method convertGray16FtoRGBXFFFFWithVImage:width:height:rowBytes:alpha:intoRGBA:rgbaRowBytes:
@abstract Converts 16-bit half-precision float grayscale data to RGBXFFFF format using vImage.
@discussion This method converts single-channel 16-bit half-precision float grayscale data to 4-channel 32-bit float RGB format. The conversion process involves two steps: first converting 16-bit half-precision floats to 32-bit floats, then duplicating the grayscale values across RGB channels. Uses Apple's vImage framework for optimal performance.
@param grayData Pointer to the source 16-bit half-precision float grayscale pixel data. Must not be NULL.
@param width The width of the image in pixels. Must be greater than 0.
@param height The height of the image in pixels. Must be greater than 0.
@param grayRowBytes The number of bytes per row in the source grayscale data. Must be greater than 0.
@param alpha The alpha value to use for all pixels (0.0-1.0).
@param rgbaData Pointer to the destination 32-bit float RGBA pixel data buffer. Must not be NULL and must be large enough to hold the converted data.
@param rgbaRowBytes The number of bytes per row in the destination RGBA data. Must be greater than 0.
@return YES if the conversion was successful, NO if an error occurred, invalid parameters were provided, or memory allocation failed.
@note The method allocates temporary memory for the 16F to 32F conversion. The destination buffer must be allocated by the caller and must be large enough to hold width * height * 16 bytes.
*/
+ (BOOL)convertGray16FtoRGBXFFFFWithVImage:(const void *)grayData
									 width:(size_t)width
									height:(size_t)height
								  rowBytes:(size_t)grayRowBytes
									 alpha:(float)alpha
								  intoRGBA:(float *)rgbaData
							  rgbaRowBytes:(size_t)rgbaRowBytes;

/*!
@method convertGray32FtoRGBXFFFFWithVImage:width:height:rowBytes:alpha:intoRGBA:rgbaRowBytes:
@abstract Converts 32-bit float grayscale data to RGBXFFFF format using vImage.
@discussion This method efficiently converts single-channel 32-bit float grayscale data to 4-channel 32-bit float RGB format by duplicating the grayscale values across the red, green, and blue channels. Uses Apple's vImage framework for optimal performance.
@param grayData Pointer to the source 32-bit float grayscale pixel data. Must not be NULL.
@param width The width of the image in pixels. Must be greater than 0.
@param height The height of the image in pixels. Must be greater than 0.
@param grayRowBytes The number of bytes per row in the source grayscale data. Must be greater than 0.
@param alpha The alpha value to use for all pixels (0.0-1.0).
@param rgbaData Pointer to the destination 32-bit float RGBA pixel data buffer. Must not be NULL and must be large enough to hold the converted data.
@param rgbaRowBytes The number of bytes per row in the destination RGBA data. Must be greater than 0.
@return YES if the conversion was successful, NO if an error occurred or invalid parameters were provided.
@note The destination buffer must be allocated by the caller and must be large enough to hold width * height * 16 bytes.
*/
+ (BOOL)convertGray32FtoRGBXFFFFWithVImage:(const void *)grayData
									 width:(size_t)width
									height:(size_t)height
								  rowBytes:(size_t)grayRowBytes
									 alpha:(float)alpha
								  intoRGBA:(float *)rgbaData
							  rgbaRowBytes:(size_t)rgbaRowBytes;

@end

NS_ASSUME_NONNULL_END

#endif
