//
//  FxGripTextImage.h
//  FxGrip
//

#ifndef FxGripTextImage_h
#define FxGripTextImage_h

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <Metal/Metal.h>
#import <simd/simd.h>

NS_ASSUME_NONNULL_BEGIN

/*!
	@class      FxGripTextImage
	@abstract   Rasterizes text into a Metal texture.
	@discussion Introduced in FxGrip 1.0. Each method draws an attributed string into a
				premultiplied RGBA8 sRGB bitmap and uploads it to a new `MTLTexture` sized to
				the text plus padding. The texture carries top-first row order, so a sampler
				reads row 0 as the visual top. The class holds no state; every method is a
				class method that allocates and returns an independent texture.
*/
@interface FxGripTextImage : NSObject

/*!
	@method     textureForAttributedString:padding:device:
	@abstract   Rasterizes an attributed string into a new texture sized to fit it.
	@param      text The attributed string to draw. Carries its own font and color runs.
	@param      padding Transparent border in pixels added on every side.
	@param      device The Metal device that allocates the texture.
	@discussion The primary rasterizer. Returns nil when text is empty, device is nil, or
				texture allocation fails. The pixel size is available from the returned
				texture's width and height.
*/
+ (nullable id<MTLTexture>)textureForAttributedString:(NSAttributedString *)text
											  padding:(NSUInteger)padding
											   device:(id<MTLDevice>)device;

/*!
	@method     textureForText:font:color:device:
	@abstract   Rasterizes a string in one font and color.
	@discussion Convenience over the attributed form using a four-pixel padding.
*/
+ (nullable id<MTLTexture>)textureForText:(NSString *)text
									 font:(NSFont *)font
									color:(NSColor *)color
								   device:(id<MTLDevice>)device;

/*!
	@method     textureForText:fontSize:color:device:
	@abstract   Rasterizes a string in Helvetica at a size and simd color.
	@discussion Convenience retained for on-screen controls that carry color as a
				`simd_float4`. The color components are read as sRGB.
*/
+ (nullable id<MTLTexture>)textureForText:(NSString *)text
								 fontSize:(CGFloat)fontSize
									color:(simd_float4)color
								   device:(id<MTLDevice>)device;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripTextImage_h */
