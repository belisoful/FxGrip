//
//  FxGripPointOSC.m
//  FxGrip
//

#import "FxGripPointOSC.h"
#import "FxGripEventModifiers.h"
#import "FxGrip_ARC.h"
#import <MetalKit/MetalKit.h>

// The stock handle drawing, implemented on FxGripOSCPart.
@interface FxGripOSCPart (FxGripHandleDrawing)
- (void)fxDrawHandleAtCanvasPoint:(CGPoint)center
						 halfSide:(double)halfSide
						 selected:(BOOL)selected
					   canvasSize:(CGSize)canvasSize
				   commandEncoder:(nonnull id<MTLRenderCommandEncoder>)commandEncoder;
@end

static const double kFxGripPointThickDividerHalfWidth = 2.0;

/*! The input size when usable; (1, 1) otherwise, so pixel math degrades to object units. */
static NSSize FxGripPointInputSize(FxGripOnScreenControl *control)
{
	NSRect bounds = [control.apiManager.onScreenControlAPIv4 inputBounds];
	if (bounds.size.width <= 0.0 || bounds.size.height <= 0.0) {
		return NSMakeSize(1.0, 1.0);
	}
	return bounds.size;
}

static simd_float4 FxGripPointColorVector(NSColor *color, float alpha)
{
	NSColor *srgb = [color colorUsingColorSpace:NSColorSpace.sRGBColorSpace] ?: color;
	return (simd_float4){ (float)srgb.redComponent, (float)srgb.greenComponent, (float)srgb.blueComponent, alpha };
}

/*!
	Applies the options' constraint and range to a target position. The anchor is the
	parameter's position when the drag began; distance math runs in input pixels so the
	clamp is circular on a non-square image.
*/
static CGPoint FxGripPointConstrain(FxGripPointOptions *options, CGPoint anchor, CGPoint target,
									BOOL shift, NSSize inputSize)
{
	switch (options.constraint) {
		case FxGripPointConstraintHorizontal:
			target.y = anchor.y;
			break;
		case FxGripPointConstraintVertical:
			target.x = anchor.x;
			break;
		case FxGripPointConstraintDistance: {
			CGPoint center = CGPointMake(options.distanceFromX, options.distanceFromY);
			CGPoint pixel = CGPointMake((target.x - center.x) * inputSize.width,
										(target.y - center.y) * inputSize.height);
			if (shift && options.distanceShiftOneAxis) {
				if (fabs(pixel.x) >= fabs(pixel.y)) {
					pixel.y = 0.0;
				} else {
					pixel.x = 0.0;
				}
			}
			double radius = options.maxDistance * inputSize.width;
			double length = hypot(pixel.x, pixel.y);
			if (length > radius && length > 0.0) {
				pixel.x *= radius / length;
				pixel.y *= radius / length;
			}
			target = CGPointMake(center.x + pixel.x / inputSize.width,
								 center.y + pixel.y / inputSize.height);
			break;
		}
		case FxGripPointConstraintAnyDirection:
		default:
			break;
	}
	target.x = MIN(MAX(target.x, options.rangeMinX), options.rangeMaxX);
	target.y = MIN(MAX(target.y, options.rangeMinY), options.rangeMaxY);
	return target;
}


#pragma mark - Rich point handle

@implementation FxGripOSCRichPointHandlePart
{
	CGPoint _dragAnchor;
	CGPoint _virtualPosition;
	BOOL _dragging;
}

+ (nonnull instancetype)partWithID:(NSInteger)partID
					   parameterID:(FxParameterId)parameterID
						   options:(nonnull FxGripPointOptions *)options
{
	FxGripOSCRichPointHandlePart *part = [[self alloc] initWithPartID:partID];
	part.parameterID = parameterID;
	part.options = options;
	return NARC_AUTORELEASE(part);
}

- (nonnull instancetype)initWithPartID:(NSInteger)partID
{
	self = [super initWithPartID:partID];
	if (self != nil) {
		_options = [FxGripPointOptions.alloc initWithConfiguration:nil];
	}
	return self;
}

- (double)effectiveHandleRadius
{
	return self.options.controlSize > 0.0 ? self.options.controlSize / 2.0 : self.handleRadius;
}

- (CGPoint)pinOffset
{
	if (!self.options.displayAsPin) {
		return CGPointZero;
	}
	double radians = self.options.pinAngle * M_PI / 180.0;
	// Canvas y increases upward, so a positive angle lifts the pin on screen.
	return CGPointMake(self.options.pinDistance * cos(radians), self.options.pinDistance * sin(radians));
}

- (BOOL)handleCanvasPoint:(nonnull CGPoint *)canvasPoint atTime:(CMTime)time
{
	CGPoint objectPoint = CGPointZero;
	if (![self.control getObjectPoint:&objectPoint fromParameter:self.parameterID atTime:time]) {
		return NO;
	}
	CGPoint anchor = [self.control canvasPointFromObjectPoint:objectPoint];
	CGPoint offset = [self pinOffset];
	*canvasPoint = CGPointMake(anchor.x + offset.x, anchor.y + offset.y);
	return YES;
}

- (BOOL)hitTestObjectPoint:(CGPoint)objectPoint canvasPoint:(CGPoint)canvasPoint atTime:(CMTime)time
{
	CGPoint handle = CGPointZero;
	if (![self handleCanvasPoint:&handle atTime:time]) {
		return NO;
	}
	CGFloat dx = canvasPoint.x - handle.x, dy = canvasPoint.y - handle.y;
	return dx * dx + dy * dy <= self.hitRadius * self.hitRadius;
}

- (BOOL)handlesConstrainDrag
{
	return self.options.mouseSpeedShiftOnly
		|| (self.options.constraint == FxGripPointConstraintDistance && self.options.distanceShiftOneAxis);
}

- (BOOL)mouseDownAtObjectPoint:(CGPoint)objectPoint
				   canvasPoint:(CGPoint)canvasPoint
					 modifiers:(FxModifierKeys)modifiers
						atTime:(CMTime)time
{
	[self beginDragAtTime:time];
	return NO;
}

- (void)beginDragAtTime:(CMTime)time
{
	CGPoint current = CGPointZero;
	if ([self.control getObjectPoint:&current fromParameter:self.parameterID atTime:time]) {
		_dragAnchor = current;
		_virtualPosition = current;
		_dragging = YES;
	}
}

- (BOOL)dragToObjectPoint:(CGPoint)objectPoint
			  objectDelta:(CGPoint)objectDelta
				modifiers:(FxModifierKeys)modifiers
				   atTime:(CMTime)time
{
	if (!_dragging) {
		[self beginDragAtTime:time];
		if (!_dragging) {
			return NO;
		}
	}
	BOOL shift = [FxGripEventModifiers isConstrainForFxModifiers:modifiers];
	double speed = (!self.options.mouseSpeedShiftOnly || shift) ? self.options.mouseSpeed : 1.0;
	_virtualPosition.x += objectDelta.x * speed;
	_virtualPosition.y += objectDelta.y * speed;

	CGPoint target = FxGripPointConstrain(self.options, _dragAnchor, _virtualPosition, shift,
										  FxGripPointInputSize(self.control));
	return [self.control setObjectPoint:target toParameter:self.parameterID atTime:time];
}

- (void)drawSelected:(BOOL)selected
		  canvasSize:(CGSize)canvasSize
	  commandEncoder:(nonnull id<MTLRenderCommandEncoder>)commandEncoder
			  atTime:(CMTime)time
{
	CGPoint handle = CGPointZero;
	if (![self handleCanvasPoint:&handle atTime:time]) {
		return;
	}
	if (self.options.displayAsPin) {
		CGPoint offset = [self pinOffset];
		CGPoint stem[2] = { CGPointMake(handle.x - offset.x, handle.y - offset.y), handle };
		[self.control strokeCanvasPoints:stem count:2 closed:NO color:kFxGripOSCOutlineColor
							  withShadow:YES canvasSize:canvasSize commandEncoder:commandEncoder];
	}
	double halfSide = [self effectiveHandleRadius];
	if (self.options.controlColor == nil) {
		[self fxDrawHandleAtCanvasPoint:handle halfSide:halfSide selected:selected
							 canvasSize:canvasSize commandEncoder:commandEncoder];
		return;
	}
	CGPoint ll = CGPointMake(handle.x - halfSide, handle.y - halfSide);
	CGPoint lr = CGPointMake(handle.x + halfSide, handle.y - halfSide);
	CGPoint ur = CGPointMake(handle.x + halfSide, handle.y + halfSide);
	CGPoint ul = CGPointMake(handle.x - halfSide, handle.y + halfSide);
	[self.control fillCanvasQuadLL:ll lr:lr ur:ur ul:ul
							 color:FxGripPointColorVector(self.options.controlColor, selected ? 0.5f : 0.25f)
						canvasSize:canvasSize commandEncoder:commandEncoder];
	CGPoint outline[4] = { ll, lr, ur, ul };
	[self.control strokeCanvasPoints:outline count:4 closed:YES
							   color:FxGripPointColorVector(self.options.controlColor, 1.0f)
						  withShadow:YES canvasSize:canvasSize commandEncoder:commandEncoder];
}

@end


#pragma mark - Divider

@implementation FxGripOSCPointDividerPart

- (nonnull instancetype)initWithPartID:(NSInteger)partID
{
	self = [super initWithPartID:partID];
	if (self != nil) {
		_lineHitRadius = 6.0;
	}
	return self;
}

- (BOOL)isVerticalLine
{
	// A horizontally moving point carries a vertical divider, and the reverse.
	return self.options.constraint == FxGripPointConstraintHorizontal;
}

- (BOOL)hitTestObjectPoint:(CGPoint)objectPoint canvasPoint:(CGPoint)canvasPoint atTime:(CMTime)time
{
	if (!self.draggable) {
		return NO;
	}
	CGPoint handle = CGPointZero;
	if (![self handleCanvasPoint:&handle atTime:time]) {
		return NO;
	}
	double distance = [self isVerticalLine] ? fabs(canvasPoint.x - handle.x) : fabs(canvasPoint.y - handle.y);
	return distance <= self.lineHitRadius;
}

- (void)drawSelected:(BOOL)selected
		  canvasSize:(CGSize)canvasSize
	  commandEncoder:(nonnull id<MTLRenderCommandEncoder>)commandEncoder
			  atTime:(CMTime)time
{
	CGPoint handle = CGPointZero;
	if (![self handleCanvasPoint:&handle atTime:time]) {
		return;
	}
	BOOL vertical = [self isVerticalLine];
	CGPoint start = vertical ? CGPointMake(handle.x, 0.0) : CGPointMake(0.0, handle.y);
	CGPoint end = vertical ? CGPointMake(handle.x, canvasSize.height) : CGPointMake(canvasSize.width, handle.y);
	simd_float4 color = self.options.controlColor != nil
		? FxGripPointColorVector(self.options.controlColor, 1.0f) : kFxGripOSCOutlineColor;

	if (self.draggable) {
		double half = kFxGripPointThickDividerHalfWidth;
		CGPoint ll = vertical ? CGPointMake(start.x - half, start.y) : CGPointMake(start.x, start.y - half);
		CGPoint lr = vertical ? CGPointMake(start.x + half, start.y) : CGPointMake(end.x, end.y - half);
		CGPoint ur = vertical ? CGPointMake(end.x + half, end.y) : CGPointMake(end.x, end.y + half);
		CGPoint ul = vertical ? CGPointMake(end.x - half, end.y) : CGPointMake(start.x, start.y + half);
		[self.control fillCanvasQuadLL:ll lr:lr ur:ur ul:ul
								 color:(selected ? kFxGripOSCSelectedFillColor : kFxGripOSCUnselectedFillColor)
							canvasSize:canvasSize commandEncoder:commandEncoder];
	}
	CGPoint line[2] = { start, end };
	[self.control strokeCanvasPoints:line count:2 closed:NO color:color
						  withShadow:YES canvasSize:canvasSize commandEncoder:commandEncoder];
}

@end


#pragma mark - Background image

@implementation FxGripOSCPointBackgroundPart
{
	id<MTLTexture> _texture;
	NSSize _imageSize;
}

+ (nonnull instancetype)partWithID:(NSInteger)partID options:(nonnull FxGripPointOptions *)options
{
	FxGripOSCPointBackgroundPart *part = [[self alloc] initWithPartID:partID];
	part.options = options;
	return NARC_AUTORELEASE(part);
}

- (nonnull instancetype)initWithPartID:(NSInteger)partID
{
	self = [super initWithPartID:partID];
	if (self != nil) {
		_options = [FxGripPointOptions.alloc initWithConfiguration:nil];
	}
	return self;
}

- (nullable NSImage *)image
{
	NSString *name = self.options.backgroundImageName;
	if (name.length == 0) {
		return nil;
	}
	NSImage *image = [NSImage imageNamed:name];
	if (image == nil && [NSFileManager.defaultManager fileExistsAtPath:name]) {
		image = [NSImage.alloc initWithContentsOfFile:name];
	}
	return image;
}

- (nullable id<MTLTexture>)textureForDevice:(nonnull id<MTLDevice>)device
{
	if (_texture != nil && _texture.device == device) {
		return _texture;
	}
	NSImage *image = [self image];
	CGImageRef cgImage = [image CGImageForProposedRect:NULL context:nil hints:nil];
	if (cgImage == NULL) {
		return nil;
	}
	MTKTextureLoader *loader = [MTKTextureLoader.alloc initWithDevice:device];
	// The OSC textured quad maps the texture's top-left to the quad's upper-left corner.
	_texture = [loader newTextureWithCGImage:cgImage
									 options:@{ MTKTextureLoaderOptionSRGB: @YES,
												MTKTextureLoaderOptionOrigin: MTKTextureLoaderOriginTopLeft }
									   error:NULL];
	_imageSize = NSMakeSize(CGImageGetWidth(cgImage), CGImageGetHeight(cgImage));
	NARC_RELEASE(loader);
	return _texture;
}

- (void)drawSelected:(BOOL)selected
		  canvasSize:(CGSize)canvasSize
	  commandEncoder:(nonnull id<MTLRenderCommandEncoder>)commandEncoder
			  atTime:(CMTime)time
{
	id<MTLTexture> texture = [self textureForDevice:commandEncoder.device];
	if (texture == nil || _imageSize.width <= 0.0 || _imageSize.height <= 0.0) {
		return;
	}
	// Width is a fraction of the input width; the height keeps the image aspect in input pixels.
	NSSize input = FxGripPointInputSize(self.control);
	double halfWidth = self.options.backgroundImageSize / 2.0;
	double halfHeight = halfWidth * (_imageSize.height / _imageSize.width) * (input.width / input.height);
	CGPoint center = CGPointMake(self.options.backgroundImageX, self.options.backgroundImageY);

	CGPoint ll = [self.control canvasPointFromObjectPoint:CGPointMake(center.x - halfWidth, center.y - halfHeight)];
	CGPoint lr = [self.control canvasPointFromObjectPoint:CGPointMake(center.x + halfWidth, center.y - halfHeight)];
	CGPoint ur = [self.control canvasPointFromObjectPoint:CGPointMake(center.x + halfWidth, center.y + halfHeight)];
	CGPoint ul = [self.control canvasPointFromObjectPoint:CGPointMake(center.x - halfWidth, center.y + halfHeight)];
	[self.control encodeTexturedQuadLL:ll lr:lr ur:ur ul:ul
							   texture:texture
								 color:(simd_float4){ 1.0f, 1.0f, 1.0f, 1.0f }
							canvasSize:canvasSize commandEncoder:commandEncoder];
}

@end


#pragma mark - Name label

@implementation FxGripOSCPointLabelPart

- (BOOL)visible
{
	return !self.nameOnlyWhenAbove || self.hovered;
}

- (void)drawSelected:(BOOL)selected
		  canvasSize:(CGSize)canvasSize
	  commandEncoder:(nonnull id<MTLRenderCommandEncoder>)commandEncoder
			  atTime:(CMTime)time
{
	if (!self.visible) {
		return;
	}
	[super drawSelected:selected canvasSize:canvasSize commandEncoder:commandEncoder atTime:time];
}

@end


#pragma mark - Control

@implementation FxGripPointOSC

+ (nonnull NSArray<FxGripOSCPart *> *)pointPartsWithOptions:(nonnull FxGripPointOptions *)options
												firstPartID:(NSInteger)firstPartID
												parameterID:(FxParameterId)parameterID
													   name:(nullable NSString *)name
{
	NSMutableArray<FxGripOSCPart *> *parts = NSMutableArray.array;
	NSInteger nextID = firstPartID;

	if (options.backgroundImageName.length > 0) {
		[parts addObject:[FxGripOSCPointBackgroundPart partWithID:nextID++ options:options]];
	}

	BOOL axisConstrained = options.constraint == FxGripPointConstraintHorizontal
		|| options.constraint == FxGripPointConstraintVertical;
	BOOL thickDivider = axisConstrained && options.divider == FxGripPointDividerThickWithoutControl;
	if (axisConstrained && options.divider != FxGripPointDividerNone) {
		FxGripOSCPointDividerPart *divider = [FxGripOSCPointDividerPart partWithID:nextID++
																	  parameterID:parameterID
																		  options:options];
		divider.draggable = thickDivider;
		[parts addObject:divider];
	}

	NSInteger handleID = 0;
	double halfSide = 4.0;
	if (!thickDivider) {
		FxGripOSCRichPointHandlePart *handle = [FxGripOSCRichPointHandlePart partWithID:nextID
																		   parameterID:parameterID
																			   options:options];
		handleID = nextID++;
		halfSide = [handle effectiveHandleRadius];
		[parts addObject:handle];
	}

	if (options.displayName && name.length > 0) {
		FxGripOSCPointLabelPart *label = [[FxGripOSCPointLabelPart alloc] initWithPartID:nextID++];
		label.text = name;
		label.anchorParameterID = parameterID;
		label.handlePartID = handleID;
		label.nameOnlyWhenAbove = options.nameOnlyWhenAbove;
		// Sit the readout above and to the right of the handle, clear of the pin offset. Canvas y
		// increases upward, so "above" adds to y and the readout's top-left clears its own height.
		double radians = options.pinAngle * M_PI / 180.0;
		CGPoint pin = options.displayAsPin
			? CGPointMake(options.pinDistance * cos(radians), options.pinDistance * sin(radians)) : CGPointZero;
		label.canvasOffset = CGPointMake(pin.x + halfSide + 6.0, pin.y + halfSide + label.fontSize + 8.0);
		[parts addObject:NARC_AUTORELEASE(label)];
	}
	return parts;
}

- (void)addPointParameter:(FxParameterId)parameterID
					 name:(nullable NSString *)name
				  options:(nonnull FxGripPointOptions *)options
{
	[self addParts:[self.class pointPartsWithOptions:options
										 firstPartID:(NSInteger)self.parts.count + 1
										 parameterID:parameterID
												name:name]];
}

/*! Sets each label's hovered state from the active part; YES when any label changed. */
- (BOOL)updateHoverForActivePart:(NSInteger)activePart
{
	BOOL changed = NO;
	for (FxGripOSCPart *part in self.parts) {
		if (![part isKindOfClass:FxGripOSCPointLabelPart.class]) {
			continue;
		}
		FxGripOSCPointLabelPart *label = (FxGripOSCPointLabelPart *)part;
		BOOL hovered = label.handlePartID != 0 && activePart == label.handlePartID;
		if (hovered != label.hovered) {
			label.hovered = hovered;
			changed |= label.nameOnlyWhenAbove;
		}
	}
	return changed;
}

- (void)mouseMovedAtPositionX:(double)mousePositionX
					positionY:(double)mousePositionY
				   activePart:(NSInteger)activePart
					modifiers:(FxModifierKeys)modifiers
				  forceUpdate:(BOOL *)forceUpdate
					   atTime:(CMTime)time
{
	[super mouseMovedAtPositionX:mousePositionX positionY:mousePositionY activePart:activePart
					   modifiers:modifiers forceUpdate:forceUpdate atTime:time];
	*forceUpdate = [self updateHoverForActivePart:activePart];
}

- (void)mouseExitedAtPositionX:(double)mousePositionX
					 positionY:(double)mousePositionY
					 modifiers:(FxModifierKeys)modifiers
				   forceUpdate:(BOOL *)forceUpdate
						atTime:(CMTime)time
{
	[super mouseExitedAtPositionX:mousePositionX positionY:mousePositionY modifiers:modifiers
					  forceUpdate:forceUpdate atTime:time];
	*forceUpdate = [self updateHoverForActivePart:0];
}

@end
