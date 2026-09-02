//
//  FxGripWatermark.m
//  FxGrip
//

#import "FxGripWatermark.h"
#import "FxGripErrors.h"
#import "FxTileImage+FxGrip.h"
#import <BEFoundation/CIImage+BExtension.h>

@implementation FxGripWatermarkConfiguration

- (instancetype)init
{
	self = [super init];
	if (self) {
		_text = @"";
		_fontName = @"Helvetica";
		_fontSize = 48.0;
		_color = NSColor.whiteColor;
		_angleDegrees = 0.0;
		_opacity = 0.5;
		_blur = 0.0;
		_shadowColor = nil;
		_style = FxGripWatermarkStyleDiagonalTiled;
		_tileSpacing = CGSizeMake(80.0, 80.0);
		_corner = FxGripWatermarkCornerBottomRight;
		_inset = 24.0;
	}
	return self;
}

+ (instancetype)configurationWithText:(NSString *)text
{
	FxGripWatermarkConfiguration *configuration = [[self alloc] init];
	configuration.text = text;
	return configuration;
}

+ (instancetype)trialConfigurationWithText:(NSString *)text
{
	FxGripWatermarkConfiguration *configuration = [self configurationWithText:text];
	configuration.style = FxGripWatermarkStyleDiagonalTiled;
	configuration.opacity = 0.35;
	return configuration;
}

+ (instancetype)centeredConfigurationWithText:(NSString *)text
{
	FxGripWatermarkConfiguration *configuration = [self configurationWithText:text];
	configuration.style = FxGripWatermarkStyleSingle;
	configuration.fontSize = 96.0;
	configuration.angleDegrees = -30.0;
	configuration.opacity = 0.5;
	return configuration;
}

- (id)copyWithZone:(NSZone *)zone
{
	FxGripWatermarkConfiguration *copy = [[FxGripWatermarkConfiguration allocWithZone:zone] init];
	copy.text = self.text;
	copy.fontName = self.fontName;
	copy.fontSize = self.fontSize;
	copy.color = self.color;
	copy.angleDegrees = self.angleDegrees;
	copy.opacity = self.opacity;
	copy.blur = self.blur;
	copy.shadowColor = self.shadowColor;
	copy.style = self.style;
	copy.tileSpacing = self.tileSpacing;
	copy.corner = self.corner;
	copy.inset = self.inset;
	return copy;
}

@end


@implementation FxGripWatermark

+ (instancetype)watermarkWithConfiguration:(FxGripWatermarkConfiguration *)configuration
{
	return [[self alloc] initWithConfiguration:configuration];
}

- (instancetype)initWithConfiguration:(FxGripWatermarkConfiguration *)configuration
{
	self = [super init];
	if (self) {
		_configuration = [configuration copy];
	}
	return self;
}

- (nullable CIImage *)textLayer
{
	FxGripWatermarkConfiguration *configuration = self.configuration;
	CIImage *textImage = [CIImage createImageText:configuration.text
										 fontName:configuration.fontName
										 fontSize:configuration.fontSize
											angle:0.0
											color:configuration.color
											 blur:0.0
										 position:CGPointZero];
	if (textImage == nil) {
		return nil;
	}
	if (configuration.shadowColor != nil) {
		CIImage *shadowImage = [CIImage createImageText:configuration.text
											   fontName:configuration.fontName
											   fontSize:configuration.fontSize
												  angle:0.0
												  color:configuration.shadowColor
												   blur:MAX(configuration.blur, 0.0)
											   position:CGPointZero];
		if (shadowImage != nil) {
			textImage = [CIImage combineImage:textImage alpha:1.0 withImage:shadowImage];
		}
	}
	return textImage;
}

- (CIImage *)centeredImageFromText:(CIImage *)text frame:(CGRect)frame angle:(CGFloat)angleDegrees
{
	CGRect extent = text.extent;
	CGFloat radians = angleDegrees * M_PI / 180.0;
	CGAffineTransform transform = CGAffineTransformIdentity;
	transform = CGAffineTransformTranslate(transform, CGRectGetMidX(frame), CGRectGetMidY(frame));
	transform = CGAffineTransformRotate(transform, radians);
	transform = CGAffineTransformTranslate(transform, -CGRectGetMidX(extent), -CGRectGetMidY(extent));
	return [text imageByApplyingTransform:transform];
}

- (nullable CIImage *)bannerImageFromText:(CIImage *)text frame:(CGRect)frame angle:(CGFloat)angleDegrees
{
	CGRect extent = text.extent;
	if (extent.size.width <= 0.0) {
		return nil;
	}
	CGFloat scale = (frame.size.width * 0.9) / extent.size.width;
	CGFloat radians = angleDegrees * M_PI / 180.0;
	CGAffineTransform transform = CGAffineTransformIdentity;
	transform = CGAffineTransformTranslate(transform, CGRectGetMidX(frame), CGRectGetMidY(frame));
	transform = CGAffineTransformRotate(transform, radians);
	transform = CGAffineTransformScale(transform, scale, scale);
	transform = CGAffineTransformTranslate(transform, -CGRectGetMidX(extent), -CGRectGetMidY(extent));
	return [text imageByApplyingTransform:transform];
}

- (CIImage *)cornerImageFromText:(CIImage *)text frame:(CGRect)frame corner:(FxGripWatermarkCorner)corner inset:(CGFloat)inset
{
	CGRect extent = text.extent;
	CGFloat x = 0.0;
	CGFloat y = 0.0;
	switch (corner) {
		case FxGripWatermarkCornerBottomRight:
			x = CGRectGetMaxX(frame) - inset - CGRectGetMaxX(extent);
			y = inset - CGRectGetMinY(extent);
			break;
		case FxGripWatermarkCornerTopLeft:
			x = inset - CGRectGetMinX(extent);
			y = CGRectGetMaxY(frame) - inset - CGRectGetMaxY(extent);
			break;
		case FxGripWatermarkCornerTopRight:
			x = CGRectGetMaxX(frame) - inset - CGRectGetMaxX(extent);
			y = CGRectGetMaxY(frame) - inset - CGRectGetMaxY(extent);
			break;
		case FxGripWatermarkCornerBottomLeft:
		default:
			x = inset - CGRectGetMinX(extent);
			y = inset - CGRectGetMinY(extent);
			break;
	}
	return [text imageByApplyingTransform:CGAffineTransformMakeTranslation(x, y)];
}

- (nullable CIImage *)diagonalTiledImageFromText:(CIImage *)text frame:(CGRect)frame
{
	FxGripWatermarkConfiguration *configuration = self.configuration;
	CGRect extent = text.extent;
	if (CGRectIsEmpty(extent) || CGRectIsInfinite(extent)) {
		return nil;
	}
	CGFloat spacingX = MAX(configuration.tileSpacing.width, 0.0);
	CGFloat spacingY = MAX(configuration.tileSpacing.height, 0.0);
	CGFloat cellWidth = extent.size.width + spacingX;
	CGFloat cellHeight = extent.size.height + spacingY;

	// Seat the text inside a transparent cell anchored at the origin so CIAffineTile repeats
	// a cell that carries the spacing as its own margin.
	CGFloat dx = spacingX / 2.0 - CGRectGetMinX(extent);
	CGFloat dy = spacingY / 2.0 - CGRectGetMinY(extent);
	CIImage *cell = [text imageByApplyingTransform:CGAffineTransformMakeTranslation(dx, dy)];
	cell = [cell imageByCroppingToRect:CGRectMake(0.0, 0.0, cellWidth, cellHeight)];

	NSAffineTransform *identity = [NSAffineTransform transform];
	CIImage *tiled = [cell imageByApplyingFilter:@"CIAffineTile"
							 withInputParameters:@{ kCIInputTransformKey: identity }];

	CGFloat radians = -45.0 * M_PI / 180.0;
	CGAffineTransform rotation = CGAffineTransformIdentity;
	rotation = CGAffineTransformTranslate(rotation, CGRectGetMidX(frame), CGRectGetMidY(frame));
	rotation = CGAffineTransformRotate(rotation, radians);
	rotation = CGAffineTransformTranslate(rotation, -CGRectGetMidX(frame), -CGRectGetMidY(frame));
	return [tiled imageByApplyingTransform:rotation];
}

- (nullable CIImage *)watermarkImageForSize:(CGSize)pixelSize device:(id<MTLDevice>)device
{
	FxGripWatermarkConfiguration *configuration = self.configuration;
	if (configuration.text.length == 0 || pixelSize.width <= 0.0 || pixelSize.height <= 0.0) {
		return nil;
	}
	CIImage *text = [self textLayer];
	if (text == nil) {
		return nil;
	}

	CGRect frame = CGRectMake(0.0, 0.0, pixelSize.width, pixelSize.height);
	CIImage *placed = nil;
	switch (configuration.style) {
		case FxGripWatermarkStyleDiagonalTiled:
			placed = [self diagonalTiledImageFromText:text frame:frame];
			break;
		case FxGripWatermarkStyleBanner:
			placed = [self bannerImageFromText:text frame:frame angle:configuration.angleDegrees];
			break;
		case FxGripWatermarkStyleCorner:
			placed = [self cornerImageFromText:text frame:frame corner:configuration.corner inset:configuration.inset];
			break;
		case FxGripWatermarkStyleSingle:
		default:
			placed = [self centeredImageFromText:text frame:frame angle:configuration.angleDegrees];
			break;
	}
	if (placed == nil) {
		return nil;
	}
	return [placed imageByCroppingToRect:frame];
}

- (BOOL)renderOntoImageTile:(FxImageTile *)destinationImage
					  error:(NSError *_Nullable *_Nullable)outError
{
	if (self.configuration.text.length == 0) {
		return YES;
	}
	id<MTLDevice> device = destinationImage.device;
	id<MTLTexture> outputTexture = device ? [destinationImage metalTextureForDevice:device] : nil;
	if (device == nil || outputTexture == nil) {
		if (outError != NULL) {
			*outError = [NSError errorWithDomain:FxGripPlugErrorDomain
											code:kFxGripError_WatermarkNoDevice
										userInfo:@{ NSLocalizedDescriptionKey:
														@"the tile has no backing Metal device" }];
		}
		return NO;
	}

	CGSize pixelSize = CGSizeMake(outputTexture.width, outputTexture.height);
	CIImage *watermark = [self watermarkImageForSize:pixelSize device:device];
	if (watermark == nil) {
		return YES;
	}
	return [destinationImage fxg_compositeCIImage:watermark opacity:self.configuration.opacity error:outError];
}

@end
