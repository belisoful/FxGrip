/*!
	@file       FxGripTextImage.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripTextImage
	@abstract   Implements text-to-Metal-texture rasterization.
	@discussion Introduced in FxGrip 0.1.0. The primary method draws into a CoreGraphics sRGB
	            bitmap, allocates a matching texture, and uploads the rows flipped so the texture
	            reads top-first. The convenience methods build an attributed string and defer to
	            it.
*/

#import "FxGripTextImage.h"

/*!
	@abstract	Rasterizes text into a Metal texture.
	@discussion	Introduced in FxGrip 0.1.0. Each call allocates an independent premultiplied
				RGBA8 sRGB texture sized to the text plus padding.
*/
@implementation FxGripTextImage

/*!
	@method		textureForAttributedString:padding:device:
	@abstract	Rasterizes an attributed string into a new texture sized to fit it.
	@param		text	The attributed string to draw, carrying its own font and color runs.
	@param		padding	The transparent border in pixels added on every side.
	@param		device	The Metal device that allocates the texture.
	@return		A new texture, or nil when text is empty, device is nil, or allocation fails.
	@discussion	Introduced in FxGrip 0.1.0. The bitmap rows are flipped on upload so the texture
				reads row 0 as the visual top. */
+ (nullable id<MTLTexture>)textureForAttributedString:(NSAttributedString *)text
											  padding:(NSUInteger)padding
											   device:(id<MTLDevice>)device
{
	if (text.length == 0 || device == nil) {
		return nil;
	}

	CGRect bounds = [text boundingRectWithSize:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)
									   options:NSStringDrawingUsesLineFragmentOrigin
									   context:nil];
	NSUInteger pixelWidth = (NSUInteger)ceil(bounds.size.width) + padding * 2;
	NSUInteger pixelHeight = (NSUInteger)ceil(bounds.size.height) + padding * 2;
	if (pixelWidth == 0 || pixelHeight == 0) {
		return nil;
	}

	NSUInteger bytesPerRow = pixelWidth * 4;
	void *pixels = calloc(pixelHeight, bytesPerRow);
	if (pixels == NULL) {
		return nil;
	}
	CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
	CGContextRef context = CGBitmapContextCreate(pixels, pixelWidth, pixelHeight, 8, bytesPerRow,
												 colorSpace,
												 (CGBitmapInfo)(kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big));
	CGColorSpaceRelease(colorSpace);
	if (context == NULL) {
		free(pixels);
		return nil;
	}

	NSGraphicsContext *previous = [NSGraphicsContext currentContext];
	NSGraphicsContext *drawing = [NSGraphicsContext graphicsContextWithCGContext:context flipped:NO];
	[NSGraphicsContext setCurrentContext:drawing];
	[text drawAtPoint:NSMakePoint(padding, padding)];
	[NSGraphicsContext setCurrentContext:previous];
	CGContextRelease(context);

	MTLTextureDescriptor *descriptor =
		[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm_sRGB
														   width:pixelWidth
														  height:pixelHeight
													   mipmapped:NO];
	descriptor.usage = MTLTextureUsageShaderRead;
	id<MTLTexture> texture = [device newTextureWithDescriptor:descriptor];
	if (texture == nil) {
		free(pixels);
		return nil;
	}
	// The bitmap context stores row 0 at the CG bottom; a Metal texture reads row 0 as its
	// top. Flip the rows on upload so the texture carries the natural top-first orientation.
	uint8_t *flipped = malloc(pixelHeight * bytesPerRow);
	if (flipped == NULL) {
		free(pixels);
		return nil;
	}
	for (NSUInteger row = 0; row < pixelHeight; row++) {
		memcpy(flipped + row * bytesPerRow,
			   (uint8_t *)pixels + (pixelHeight - 1 - row) * bytesPerRow,
			   bytesPerRow);
	}
	[texture replaceRegion:MTLRegionMake2D(0, 0, pixelWidth, pixelHeight)
			   mipmapLevel:0
				 withBytes:flipped
			   bytesPerRow:bytesPerRow];
	free(flipped);
	free(pixels);
	return texture;
}

/*! @abstract Rasterizes a string in one font and color, using four-pixel padding. */
+ (nullable id<MTLTexture>)textureForText:(NSString *)text
									 font:(NSFont *)font
									color:(NSColor *)color
								   device:(id<MTLDevice>)device
{
	if (text.length == 0) {
		return nil;
	}
	NSDictionary *attributes = @{
		NSFontAttributeName				: font,
		NSForegroundColorAttributeName	: color,
	};
	NSAttributedString *attributed = [[NSAttributedString alloc] initWithString:text attributes:attributes];
	return [self textureForAttributedString:attributed padding:4 device:device];
}

/*! @abstract Rasterizes a string in Helvetica at a size, reading the simd color as sRGB. */
+ (nullable id<MTLTexture>)textureForText:(NSString *)text
								 fontSize:(CGFloat)fontSize
									color:(simd_float4)color
								   device:(id<MTLDevice>)device
{
	CGFloat clampedSize = MAX(fontSize, 1.0);
	NSFont *font = [NSFont fontWithName:@"Helvetica" size:clampedSize];
	NSColor *textColor = [NSColor colorWithSRGBRed:color.x green:color.y blue:color.z alpha:color.w];
	return [self textureForText:text font:font color:textColor device:device];
}

@end
