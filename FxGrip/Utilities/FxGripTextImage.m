//
//  FxGripTextImage.m
//  FxGrip
//

#import "FxGripTextImage.h"

@implementation FxGripTextImage

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
