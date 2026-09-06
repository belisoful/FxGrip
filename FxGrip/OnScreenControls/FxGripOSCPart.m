/*!
	@file       FxGripOSCPart.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripOSCPart
	@abstract   Implements the part base and the shape parts an on-screen control composes.
	@discussion Introduced in FxGrip 0.1.0. Each part reads its parameters, hit-tests in canvas pixels,
	            draws through the control's draw kit, and writes parameter changes on a drag. Rotation
	            is rigid in the input-pixel frame, so a rotated shape keeps its angles on a non-square
	            image. Composite constructors assemble a body with its handles into one part list.
*/

#import "FxGripOSCPart.h"
#import "FxGripEventModifiers.h"
#import "FxGrip_ARC.h"

@interface FxGripOSCPart (FxGripHandleDrawing)
- (void)fxDrawHandleAtCanvasPoint:(CGPoint)center
						 halfSide:(double)halfSide
						 selected:(BOOL)selected
					   canvasSize:(CGSize)canvasSize
				   commandEncoder:(nonnull id<MTLRenderCommandEncoder>)commandEncoder;
@end

// Rotation is rigid in the input-pixel frame: object offsets scale per axis into
// pixels, rotate there, and scale back, so a rotated shape keeps its angles on a
// non-square image.

static CGPoint FxGripOSCPixelVector(CGPoint objectOffset, NSSize inputSize)
{
	return CGPointMake(objectOffset.x * inputSize.width, objectOffset.y * inputSize.height);
}

static CGPoint FxGripOSCObjectVector(CGPoint pixelOffset, NSSize inputSize)
{
	return CGPointMake(pixelOffset.x / inputSize.width, pixelOffset.y / inputSize.height);
}

static CGPoint FxGripOSCRotateVector(CGPoint vector, double radians)
{
	double sine = sin(radians), cosine = cos(radians);
	return CGPointMake(vector.x * cosine - vector.y * sine,
					   vector.x * sine + vector.y * cosine);
}

/*! Reads an angle parameter scaled by radiansPerUnit; parameterID 0 means angle 0. */
static BOOL FxGripOSCReadAngle(FxGripOnScreenControl *control,
							   FxParameterId parameterID,
							   double radiansPerUnit,
							   CMTime time,
							   double *radians)
{
	*radians = 0.0;
	if (parameterID == 0) {
		return YES;
	}
	double value = 0.0;
	if (![control getFloatValue:&value fromParameter:parameterID atTime:time]) {
		return NO;
	}
	*radians = value * radiansPerUnit;
	return YES;
}

/*! The input bounds when they are usable, else NO. */
static BOOL FxGripOSCReadInputSize(FxGripOnScreenControl *control, NSSize *inputSize)
{
	NSRect inputBounds = [control.apiManager.onScreenControlAPIv4 inputBounds];
	if (inputBounds.size.width <= 0.0 || inputBounds.size.height <= 0.0) {
		return NO;
	}
	*inputSize = inputBounds.size;
	return YES;
}

/*! Snaps a screen angle to the nearest 45° increment while the constrain modifier is held. */
static double FxGripOSCConstrainedAngle(double radians, FxModifierKeys modifiers)
{
	if (![FxGripEventModifiers isConstrainForFxModifiers:modifiers]) {
		return radians;
	}
	return round(radians / M_PI_4) * M_PI_4;
}

/*!
	@abstract	One interactive piece of an on-screen control.
	@discussion	Introduced in FxGrip 0.1.0. The base owns the part number and shadow appearance, answers
				no hit, ignores drags, and draws nothing. Subclasses override the hit-test, drag, and
				draw hooks.
*/
@implementation FxGripOSCPart

- (nonnull instancetype)initWithPartID:(NSInteger)partID
{
	self = [super init];
	if (self != nil) {
		_partID = partID;
		_shadowColor = kFxGripOSCShadowColor;
		_shadowDistance = 1.0;
		_shadowBlur = 0.0;
	}
	return self;
}

- (BOOL)castsShadow
{
	return _shadowColor.w > 0.0 && (_shadowDistance != 0.0 || _shadowBlur > 0.0);
}

- (BOOL)hitTestObjectPoint:(CGPoint)objectPoint canvasPoint:(CGPoint)canvasPoint atTime:(CMTime)time
{
	return NO;
}

- (BOOL)dragToObjectPoint:(CGPoint)objectPoint
			  objectDelta:(CGPoint)objectDelta
				modifiers:(FxModifierKeys)modifiers
				   atTime:(CMTime)time
{
	return NO;
}

- (void)drawSelected:(BOOL)selected
		  canvasSize:(CGSize)canvasSize
	  commandEncoder:(nonnull id<MTLRenderCommandEncoder>)commandEncoder
			  atTime:(CMTime)time
{
}

- (BOOL)mouseDownAtObjectPoint:(CGPoint)objectPoint
				   canvasPoint:(CGPoint)canvasPoint
					 modifiers:(FxModifierKeys)modifiers
						atTime:(CMTime)time
{
	return NO;
}

- (BOOL)keyDownWithKey:(unsigned short)asciiKey
			 modifiers:(FxModifierKeys)modifiers
				atTime:(CMTime)time
{
	return NO;
}

- (BOOL)handlesOptionDrag
{
	return NO;
}

- (BOOL)handlesConstrainDrag
{
	return NO;
}

- (BOOL)mouseDoubleClickAtObjectPoint:(CGPoint)objectPoint
						  canvasPoint:(CGPoint)canvasPoint
							modifiers:(FxModifierKeys)modifiers
							   atTime:(CMTime)time
{
	return NO;
}

/*! Draws the standard square handle around a canvas point. */
- (void)fxDrawHandleAtCanvasPoint:(CGPoint)center
						 halfSide:(double)halfSide
						 selected:(BOOL)selected
					   canvasSize:(CGSize)canvasSize
				   commandEncoder:(nonnull id<MTLRenderCommandEncoder>)commandEncoder
{
	CGPoint ll = CGPointMake(center.x - halfSide, center.y - halfSide);
	CGPoint lr = CGPointMake(center.x + halfSide, center.y - halfSide);
	CGPoint ur = CGPointMake(center.x + halfSide, center.y + halfSide);
	CGPoint ul = CGPointMake(center.x - halfSide, center.y + halfSide);

	[self.control fillCanvasQuadLL:ll lr:lr ur:ur ul:ul
							 color:(selected ? kFxGripOSCSelectedFillColor : kFxGripOSCUnselectedFillColor)
						canvasSize:canvasSize
					commandEncoder:commandEncoder];
	CGPoint outline[4] = { ll, lr, ur, ul };
	[self.control strokeCanvasPoints:outline
							   count:4
							  closed:YES
							   color:kFxGripOSCOutlineColor
						  withShadow:YES
						  canvasSize:canvasSize
					  commandEncoder:commandEncoder];
}

@end


#pragma mark - Point handle

/*!
	@abstract	A square handle bound to a point parameter.
	@discussion	Introduced in FxGrip 0.1.0. A drag writes the pointer's object position to the parameter.
				Hit testing measures canvas-pixel distance, so the grab target is the same size at
				every zoom.
*/
@implementation FxGripOSCPointHandlePart

/*! @abstract Creates a handle bound to a point parameter. */
+ (nonnull instancetype)partWithID:(NSInteger)partID parameterID:(FxParameterId)parameterID
{
	FxGripOSCPointHandlePart *part = [[self alloc] initWithPartID:partID];
	part.parameterID = parameterID;
	return NARC_AUTORELEASE(part);
}

- (nonnull instancetype)initWithPartID:(NSInteger)partID
{
	self = [super initWithPartID:partID];
	if (self != nil) {
		_hitRadius = 10.0;
		_handleRadius = 4.0;
	}
	return self;
}

- (BOOL)hitTestObjectPoint:(CGPoint)objectPoint canvasPoint:(CGPoint)canvasPoint atTime:(CMTime)time
{
	CGPoint handleObjectPoint = CGPointZero;
	if (![self.control getObjectPoint:&handleObjectPoint fromParameter:self.parameterID atTime:time]) {
		return NO;
	}
	CGPoint handleCanvasPoint = [self.control canvasPointFromObjectPoint:handleObjectPoint];
	CGFloat dx = canvasPoint.x - handleCanvasPoint.x;
	CGFloat dy = canvasPoint.y - handleCanvasPoint.y;
	return dx * dx + dy * dy <= self.hitRadius * self.hitRadius;
}

- (BOOL)dragToObjectPoint:(CGPoint)objectPoint
			  objectDelta:(CGPoint)objectDelta
				modifiers:(FxModifierKeys)modifiers
				   atTime:(CMTime)time
{
	return [self.control setObjectPoint:objectPoint toParameter:self.parameterID atTime:time];
}

- (void)drawSelected:(BOOL)selected
		  canvasSize:(CGSize)canvasSize
	  commandEncoder:(nonnull id<MTLRenderCommandEncoder>)commandEncoder
			  atTime:(CMTime)time
{
	CGPoint handleObjectPoint = CGPointZero;
	if (![self.control getObjectPoint:&handleObjectPoint fromParameter:self.parameterID atTime:time]) {
		return;
	}
	[self fxDrawHandleAtCanvasPoint:[self.control canvasPointFromObjectPoint:handleObjectPoint]
						   halfSide:self.handleRadius
						   selected:selected
						 canvasSize:canvasSize
					 commandEncoder:commandEncoder];
}

@end


#pragma mark - Line

/*!
	@abstract	A line segment bound to start and end point parameters.
	@discussion	Introduced in FxGrip 0.1.0. A hit is any point within hitRadius canvas pixels of the
				segment; a drag moves both endpoints by the object-space delta.
*/
@implementation FxGripOSCLinePart

/*! @abstract Creates a line bound to start and end point parameters. */
+ (nonnull instancetype)partWithID:(NSInteger)partID
				  startParameterID:(FxParameterId)startParameterID
					endParameterID:(FxParameterId)endParameterID
{
	FxGripOSCLinePart *part = [[self alloc] initWithPartID:partID];
	part.startParameterID = startParameterID;
	part.endParameterID = endParameterID;
	return NARC_AUTORELEASE(part);
}

/*! @abstract The line body plus a point handle on each endpoint. */
+ (nonnull NSArray<FxGripOSCPart *> *)gradientPartsWithLineID:(NSInteger)lineID
												startHandleID:(NSInteger)startHandleID
												  endHandleID:(NSInteger)endHandleID
											 startParameterID:(FxParameterId)startParameterID
											   endParameterID:(FxParameterId)endParameterID
{
	return @[
		[self partWithID:lineID startParameterID:startParameterID endParameterID:endParameterID],
		[FxGripOSCPointHandlePart partWithID:startHandleID parameterID:startParameterID],
		[FxGripOSCPointHandlePart partWithID:endHandleID parameterID:endParameterID],
	];
}

/*! @abstract The flag-form line composite: Body, then VertexHandles for start and end. */
+ (nonnull NSArray<FxGripOSCPart *> *)linePartsWithOptions:(FxGripOSCShapeOptions)options
											   firstPartID:(NSInteger)firstPartID
										  startParameterID:(FxParameterId)startParameterID
											endParameterID:(FxParameterId)endParameterID
{
	NSMutableArray<FxGripOSCPart *> *parts = [NSMutableArray arrayWithCapacity:3];
	NSInteger partID = firstPartID;
	if (options & FxGripOSCShapeOptionBody) {
		[parts addObject:[self partWithID:partID++ startParameterID:startParameterID endParameterID:endParameterID]];
	}
	if (options & FxGripOSCShapeOptionVertexHandles) {
		[parts addObject:[FxGripOSCPointHandlePart partWithID:partID++ parameterID:startParameterID]];
		[parts addObject:[FxGripOSCPointHandlePart partWithID:partID++ parameterID:endParameterID]];
	}
	return parts;
}

- (nonnull instancetype)initWithPartID:(NSInteger)partID
{
	self = [super initWithPartID:partID];
	if (self != nil) {
		_hitRadius = 6.0;
	}
	return self;
}

- (BOOL)readStart:(nonnull CGPoint *)start end:(nonnull CGPoint *)end atTime:(CMTime)time
{
	return [self.control getObjectPoint:start fromParameter:self.startParameterID atTime:time]
		&& [self.control getObjectPoint:end fromParameter:self.endParameterID atTime:time];
}

- (BOOL)hitTestObjectPoint:(CGPoint)objectPoint canvasPoint:(CGPoint)canvasPoint atTime:(CMTime)time
{
	CGPoint start = CGPointZero, end = CGPointZero;
	if (![self readStart:&start end:&end atTime:time]) {
		return NO;
	}
	CGPoint a = [self.control canvasPointFromObjectPoint:start];
	CGPoint b = [self.control canvasPointFromObjectPoint:end];

	CGFloat abX = b.x - a.x, abY = b.y - a.y;
	CGFloat lengthSquared = abX * abX + abY * abY;
	CGFloat t = 0.0;
	if (lengthSquared > 0.0) {
		t = ((canvasPoint.x - a.x) * abX + (canvasPoint.y - a.y) * abY) / lengthSquared;
		t = t < 0.0 ? 0.0 : (t > 1.0 ? 1.0 : t);
	}
	CGFloat dx = canvasPoint.x - (a.x + t * abX);
	CGFloat dy = canvasPoint.y - (a.y + t * abY);
	return dx * dx + dy * dy <= self.hitRadius * self.hitRadius;
}

- (BOOL)dragToObjectPoint:(CGPoint)objectPoint
			  objectDelta:(CGPoint)objectDelta
				modifiers:(FxModifierKeys)modifiers
				   atTime:(CMTime)time
{
	CGPoint start = CGPointZero, end = CGPointZero;
	if (![self readStart:&start end:&end atTime:time]) {
		return NO;
	}
	start.x += objectDelta.x;
	start.y += objectDelta.y;
	end.x += objectDelta.x;
	end.y += objectDelta.y;
	BOOL movedStart = [self.control setObjectPoint:start toParameter:self.startParameterID atTime:time];
	BOOL movedEnd = [self.control setObjectPoint:end toParameter:self.endParameterID atTime:time];
	return movedStart && movedEnd;
}

- (void)drawSelected:(BOOL)selected
		  canvasSize:(CGSize)canvasSize
	  commandEncoder:(nonnull id<MTLRenderCommandEncoder>)commandEncoder
			  atTime:(CMTime)time
{
	CGPoint start = CGPointZero, end = CGPointZero;
	if (![self readStart:&start end:&end atTime:time]) {
		return;
	}
	CGPoint line[2] = {
		[self.control canvasPointFromObjectPoint:start],
		[self.control canvasPointFromObjectPoint:end],
	};
	[self.control strokeCanvasPoints:line
							   count:2
							  closed:NO
							   color:(selected ? kFxGripOSCSelectedFillColor : kFxGripOSCOutlineColor)
						  withShadow:YES
						  canvasSize:canvasSize
					  commandEncoder:commandEncoder];
}

@end


#pragma mark - Angle dial

/*!
	@abstract	A rotation spoke bound to a center point parameter and an angle parameter.
	@discussion	Introduced in FxGrip 0.1.0. Dragging the tip writes the pointer's angle around the
				center, measured counterclockwise from +x. Shift snaps the written angle to 45°
				increments.
*/
@implementation FxGripOSCAngleDialPart

// Shift snaps the written angle to 45° increments, so this part reads Shift itself instead of
// letting the base constrain the pointer to an axis.
- (BOOL)handlesConstrainDrag
{
	return YES;
}

+ (nonnull instancetype)partWithID:(NSInteger)partID
				 centerParameterID:(FxParameterId)centerParameterID
				  angleParameterID:(FxParameterId)angleParameterID
{
	FxGripOSCAngleDialPart *part = [[self alloc] initWithPartID:partID];
	part.centerParameterID = centerParameterID;
	part.angleParameterID = angleParameterID;
	return NARC_AUTORELEASE(part);
}

- (nonnull instancetype)initWithPartID:(NSInteger)partID
{
	self = [super initWithPartID:partID];
	if (self != nil) {
		_radiansPerUnit = 1.0;
		_spokeRadius = 40.0;
		_hitRadius = 10.0;
		_handleRadius = 4.0;
	}
	return self;
}

/*! The spoke tip in canvas space, from the center and angle parameters. */
- (BOOL)readCanvasCenter:(nonnull CGPoint *)canvasCenter tip:(nonnull CGPoint *)tip atTime:(CMTime)time
{
	CGPoint center = CGPointZero;
	if (![self.control getObjectPoint:&center fromParameter:self.centerParameterID atTime:time]) {
		return NO;
	}
	double value = 0.0;
	if (![self.control getFloatValue:&value fromParameter:self.angleParameterID atTime:time]) {
		return NO;
	}
	double radians = value * self.radiansPerUnit;
	*canvasCenter = [self.control canvasPointFromObjectPoint:center];
	*tip = CGPointMake(canvasCenter->x + cos(radians) * self.spokeRadius,
					   canvasCenter->y + sin(radians) * self.spokeRadius);
	return YES;
}

- (BOOL)hitTestObjectPoint:(CGPoint)objectPoint canvasPoint:(CGPoint)canvasPoint atTime:(CMTime)time
{
	CGPoint canvasCenter = CGPointZero, tip = CGPointZero;
	if (![self readCanvasCenter:&canvasCenter tip:&tip atTime:time]) {
		return NO;
	}
	CGFloat dx = canvasPoint.x - tip.x;
	CGFloat dy = canvasPoint.y - tip.y;
	return dx * dx + dy * dy <= self.hitRadius * self.hitRadius;
}

- (BOOL)dragToObjectPoint:(CGPoint)objectPoint
			  objectDelta:(CGPoint)objectDelta
				modifiers:(FxModifierKeys)modifiers
				   atTime:(CMTime)time
{
	CGPoint center = CGPointZero;
	if (![self.control getObjectPoint:&center fromParameter:self.centerParameterID atTime:time]) {
		return NO;
	}
	CGPoint canvasCenter = [self.control canvasPointFromObjectPoint:center];
	CGPoint canvasPointer = [self.control canvasPointFromObjectPoint:objectPoint];
	CGFloat dx = canvasPointer.x - canvasCenter.x;
	CGFloat dy = canvasPointer.y - canvasCenter.y;
	if (dx == 0.0 && dy == 0.0) {
		return NO;
	}
	double radians = FxGripOSCConstrainedAngle(atan2(dy, dx), modifiers);
	return [self.control setFloatValue:radians / self.radiansPerUnit
						   toParameter:self.angleParameterID
								atTime:time];
}

- (void)drawSelected:(BOOL)selected
		  canvasSize:(CGSize)canvasSize
	  commandEncoder:(nonnull id<MTLRenderCommandEncoder>)commandEncoder
			  atTime:(CMTime)time
{
	CGPoint canvasCenter = CGPointZero, tip = CGPointZero;
	if (![self readCanvasCenter:&canvasCenter tip:&tip atTime:time]) {
		return;
	}
	CGPoint spoke[2] = { canvasCenter, tip };
	[self.control strokeCanvasPoints:spoke
							   count:2
							  closed:NO
							   color:kFxGripOSCOutlineColor
						  withShadow:YES
						  canvasSize:canvasSize
					  commandEncoder:commandEncoder];
	[self fxDrawHandleAtCanvasPoint:tip
						   halfSide:self.handleRadius
						   selected:selected
						 canvasSize:canvasSize
					 commandEncoder:commandEncoder];
}

@end


#pragma mark - Rectangle corner

/*!
	@abstract	A resize handle on one corner of a two-corner rectangle.
	@discussion	Introduced in FxGrip 0.1.0. Dragging writes the pointer into the corner's components.
				Shift locks the resize to the aspect ratio; Option anchors the center, resizing
				symmetrically.
*/
@implementation FxGripOSCRectCornerPart

// Shift locks the resize to the aspect ratio, so this part reads Shift itself instead of letting
// the base constrain the pointer to an axis.
- (BOOL)handlesConstrainDrag
{
	return YES;
}

// Option anchors the resize to the center, so this part reads Option itself instead of the base's
// fine-drag.
- (BOOL)handlesOptionDrag
{
	return YES;
}

/*! The fixed anchor, per-axis signs, and the anchor-to-corner extents for the dragged corner.
	atCenter picks the rectangle center (Option: symmetric resize) over the opposite corner (the
	default); the extents are the half diagonal from the center, or the full span from the opposite
	corner. */
- (void)fxResizeAnchor:(nonnull CGPoint *)anchor
				 signX:(nonnull double *)signX
				 signY:(nonnull double *)signY
				 width:(nonnull double *)width
				height:(nonnull double *)height
			 lowerLeft:(CGPoint)ll
			upperRight:(CGPoint)ur
			  atCenter:(BOOL)atCenter
{
	CGPoint center = CGPointMake((ll.x + ur.x) / 2.0, (ll.y + ur.y) / 2.0);
	double fullWidth = fabs(ur.x - ll.x), fullHeight = fabs(ur.y - ll.y);
	switch (self.corner) {
		case FxGripOSCRectCornerLowerLeft:
			*anchor = atCenter ? center : ur; *signX = -1.0; *signY = -1.0;
			break;
		case FxGripOSCRectCornerLowerRight:
			*anchor = atCenter ? center : CGPointMake(ll.x, ur.y); *signX = 1.0; *signY = -1.0;
			break;
		case FxGripOSCRectCornerUpperRight:
			*anchor = atCenter ? center : ll; *signX = 1.0; *signY = 1.0;
			break;
		case FxGripOSCRectCornerUpperLeft:
			*anchor = atCenter ? center : CGPointMake(ur.x, ll.y); *signX = -1.0; *signY = 1.0;
			break;
	}
	*width = atCenter ? fullWidth / 2.0 : fullWidth;
	*height = atCenter ? fullHeight / 2.0 : fullHeight;
}

+ (nonnull instancetype)partWithID:(NSInteger)partID
							corner:(FxGripOSCRectCorner)corner
			  lowerLeftParameterID:(FxParameterId)lowerLeftParameterID
			 upperRightParameterID:(FxParameterId)upperRightParameterID
{
	FxGripOSCRectCornerPart *part = [[self alloc] initWithPartID:partID];
	part.corner = corner;
	part.lowerLeftParameterID = lowerLeftParameterID;
	part.upperRightParameterID = upperRightParameterID;
	return NARC_AUTORELEASE(part);
}

- (nonnull instancetype)initWithPartID:(NSInteger)partID
{
	self = [super initWithPartID:partID];
	if (self != nil) {
		_radiansPerUnit = 1.0;
		_hitRadius = 10.0;
		_handleRadius = 4.0;
	}
	return self;
}

/*! The corner's on-screen object position: the pre-rotation corner, rotated about
	the corners' midpoint when the angle overlay is active. */
- (BOOL)readCornerObjectPoint:(nonnull CGPoint *)cornerPoint
					lowerLeft:(nonnull CGPoint *)lowerLeft
				   upperRight:(nonnull CGPoint *)upperRight
					   atTime:(CMTime)time
{
	double radians = 0.0;
	if (![self.control getObjectPoint:lowerLeft fromParameter:self.lowerLeftParameterID atTime:time]
		|| ![self.control getObjectPoint:upperRight fromParameter:self.upperRightParameterID atTime:time]
		|| !FxGripOSCReadAngle(self.control, self.angleParameterID, self.radiansPerUnit, time, &radians)) {
		return NO;
	}
	switch (self.corner) {
		case FxGripOSCRectCornerLowerLeft:
			*cornerPoint = *lowerLeft;
			break;
		case FxGripOSCRectCornerLowerRight:
			*cornerPoint = CGPointMake(upperRight->x, lowerLeft->y);
			break;
		case FxGripOSCRectCornerUpperRight:
			*cornerPoint = *upperRight;
			break;
		case FxGripOSCRectCornerUpperLeft:
			*cornerPoint = CGPointMake(lowerLeft->x, upperRight->y);
			break;
	}
	if (radians != 0.0) {
		NSSize inputSize = NSZeroSize;
		if (!FxGripOSCReadInputSize(self.control, &inputSize)) {
			return NO;
		}
		CGPoint center = CGPointMake((lowerLeft->x + upperRight->x) / 2.0,
									 (lowerLeft->y + upperRight->y) / 2.0);
		CGPoint offset = CGPointMake(cornerPoint->x - center.x, cornerPoint->y - center.y);
		offset = FxGripOSCObjectVector(FxGripOSCRotateVector(FxGripOSCPixelVector(offset, inputSize), radians), inputSize);
		*cornerPoint = CGPointMake(center.x + offset.x, center.y + offset.y);
	}
	return YES;
}

- (BOOL)hitTestObjectPoint:(CGPoint)objectPoint canvasPoint:(CGPoint)canvasPoint atTime:(CMTime)time
{
	CGPoint corner = CGPointZero, ll = CGPointZero, ur = CGPointZero;
	if (![self readCornerObjectPoint:&corner lowerLeft:&ll upperRight:&ur atTime:time]) {
		return NO;
	}
	CGPoint canvasCorner = [self.control canvasPointFromObjectPoint:corner];
	CGFloat dx = canvasPoint.x - canvasCorner.x;
	CGFloat dy = canvasPoint.y - canvasCorner.y;
	return dx * dx + dy * dy <= self.hitRadius * self.hitRadius;
}

/*!
	@method		dragToObjectPoint:objectDelta:modifiers:atTime:
	@abstract	Writes the dragged corner into the parameter components, honoring Shift and Option.
	@discussion	Introduced in FxGrip 0.1.0. The pointer unrotates into pre-rotation space when the angle
				overlay is active. Shift locks the aspect ratio; Option resizes symmetrically about the
				center. */
- (BOOL)dragToObjectPoint:(CGPoint)objectPoint
			  objectDelta:(CGPoint)objectDelta
				modifiers:(FxModifierKeys)modifiers
				   atTime:(CMTime)time
{
	CGPoint corner = CGPointZero, ll = CGPointZero, ur = CGPointZero;
	double radians = 0.0;
	if (![self readCornerObjectPoint:&corner lowerLeft:&ll upperRight:&ur atTime:time]
		|| !FxGripOSCReadAngle(self.control, self.angleParameterID, self.radiansPerUnit, time, &radians)) {
		return NO;
	}
	if (radians != 0.0) {
		// The parameters store pre-rotation coordinates: unrotate the pointer
		// about the midpoint before writing components.
		NSSize inputSize = NSZeroSize;
		if (!FxGripOSCReadInputSize(self.control, &inputSize)) {
			return NO;
		}
		CGPoint center = CGPointMake((ll.x + ur.x) / 2.0, (ll.y + ur.y) / 2.0);
		CGPoint offset = CGPointMake(objectPoint.x - center.x, objectPoint.y - center.y);
		offset = FxGripOSCObjectVector(FxGripOSCRotateVector(FxGripOSCPixelVector(offset, inputSize), -radians), inputSize);
		objectPoint = CGPointMake(center.x + offset.x, center.y + offset.y);
	}
	BOOL anchorCenter = (modifiers & kFxModifierKey_OPTION) != 0;
	CGPoint anchor = CGPointZero;
	double signX = 1.0, signY = 1.0, width = 0.0, height = 0.0;
	[self fxResizeAnchor:&anchor signX:&signX signY:&signY width:&width height:&height
			   lowerLeft:ll upperRight:ur atCenter:anchorCenter];
	if ([FxGripEventModifiers isConstrainForFxModifiers:modifiers] && width > 0.0 && height > 0.0) {
		double scale = fmax(fabs(objectPoint.x - anchor.x) / width, fabs(objectPoint.y - anchor.y) / height);
		objectPoint = CGPointMake(anchor.x + signX * scale * width, anchor.y + signY * scale * height);
	}
	// Option resizes symmetrically: the opposite corner mirrors the dragged one through the center.
	CGPoint center = CGPointMake((ll.x + ur.x) / 2.0, (ll.y + ur.y) / 2.0);
	CGPoint opposite = CGPointMake(2.0 * center.x - objectPoint.x, 2.0 * center.y - objectPoint.y);
	switch (self.corner) {
		case FxGripOSCRectCornerLowerLeft:
			ll = objectPoint;
			if (anchorCenter) {
				ur = opposite;
			}
			break;
		case FxGripOSCRectCornerLowerRight:
			ur.x = objectPoint.x;
			ll.y = objectPoint.y;
			if (anchorCenter) {
				ll.x = opposite.x;
				ur.y = opposite.y;
			}
			break;
		case FxGripOSCRectCornerUpperRight:
			ur = objectPoint;
			if (anchorCenter) {
				ll = opposite;
			}
			break;
		case FxGripOSCRectCornerUpperLeft:
			ll.x = objectPoint.x;
			ur.y = objectPoint.y;
			if (anchorCenter) {
				ur.x = opposite.x;
				ll.y = opposite.y;
			}
			break;
	}
	BOOL movedLL = [self.control setObjectPoint:ll toParameter:self.lowerLeftParameterID atTime:time];
	BOOL movedUR = [self.control setObjectPoint:ur toParameter:self.upperRightParameterID atTime:time];
	return movedLL && movedUR;
}

- (void)drawSelected:(BOOL)selected
		  canvasSize:(CGSize)canvasSize
	  commandEncoder:(nonnull id<MTLRenderCommandEncoder>)commandEncoder
			  atTime:(CMTime)time
{
	CGPoint corner = CGPointZero, ll = CGPointZero, ur = CGPointZero;
	if (![self readCornerObjectPoint:&corner lowerLeft:&ll upperRight:&ur atTime:time]) {
		return;
	}
	[self fxDrawHandleAtCanvasPoint:[self.control canvasPointFromObjectPoint:corner]
						   halfSide:self.handleRadius
						   selected:selected
						 canvasSize:canvasSize
					 commandEncoder:commandEncoder];
}

@end


#pragma mark - Rectangle

/*!
	@abstract	A rectangle bound to lower-left and upper-right point parameters.
	@discussion	Introduced in FxGrip 0.1.0. A hit is any object point inside the rectangle; a drag moves
				both corner parameters. An angle overlay rotates the rectangle about the corners'
				midpoint.
*/
@implementation FxGripOSCRectPart

/*! @abstract Creates a rectangle bound to lower-left and upper-right point parameters. */
+ (nonnull instancetype)partWithID:(NSInteger)partID
			  lowerLeftParameterID:(FxParameterId)lowerLeftParameterID
			 upperRightParameterID:(FxParameterId)upperRightParameterID
{
	FxGripOSCRectPart *part = [[self alloc] initWithPartID:partID];
	part.lowerLeftParameterID = lowerLeftParameterID;
	part.upperRightParameterID = upperRightParameterID;
	return NARC_AUTORELEASE(part);
}

- (nonnull instancetype)initWithPartID:(NSInteger)partID
{
	self = [super initWithPartID:partID];
	if (self != nil) {
		_radiansPerUnit = 1.0;
	}
	return self;
}

- (BOOL)readLowerLeft:(nonnull CGPoint *)lowerLeft upperRight:(nonnull CGPoint *)upperRight atTime:(CMTime)time
{
	return [self.control getObjectPoint:lowerLeft fromParameter:self.lowerLeftParameterID atTime:time]
		&& [self.control getObjectPoint:upperRight fromParameter:self.upperRightParameterID atTime:time];
}

- (BOOL)hitTestObjectPoint:(CGPoint)objectPoint canvasPoint:(CGPoint)canvasPoint atTime:(CMTime)time
{
	CGPoint ll = CGPointZero, ur = CGPointZero;
	double radians = 0.0;
	if (![self readLowerLeft:&ll upperRight:&ur atTime:time]
		|| !FxGripOSCReadAngle(self.control, self.angleParameterID, self.radiansPerUnit, time, &radians)) {
		return NO;
	}
	if (radians != 0.0) {
		// Unrotate the pointer about the corners' midpoint into pre-rotation space.
		NSSize inputSize = NSZeroSize;
		if (!FxGripOSCReadInputSize(self.control, &inputSize)) {
			return NO;
		}
		CGPoint center = CGPointMake((ll.x + ur.x) / 2.0, (ll.y + ur.y) / 2.0);
		CGPoint offset = CGPointMake(objectPoint.x - center.x, objectPoint.y - center.y);
		CGPoint local = FxGripOSCRotateVector(FxGripOSCPixelVector(offset, inputSize), -radians);
		offset = FxGripOSCObjectVector(local, inputSize);
		objectPoint = CGPointMake(center.x + offset.x, center.y + offset.y);
	}
	// The corner parameters are not normalized: a corner dragged past its opposite inverts the
	// rectangle, so test against the min/max span rather than assuming lower-left < upper-right.
	return fmin(ll.x, ur.x) <= objectPoint.x && objectPoint.x <= fmax(ll.x, ur.x)
		&& fmin(ll.y, ur.y) <= objectPoint.y && objectPoint.y <= fmax(ll.y, ur.y);
}

- (BOOL)dragToObjectPoint:(CGPoint)objectPoint
			  objectDelta:(CGPoint)objectDelta
				modifiers:(FxModifierKeys)modifiers
				   atTime:(CMTime)time
{
	CGPoint ll = CGPointZero, ur = CGPointZero;
	if (![self readLowerLeft:&ll upperRight:&ur atTime:time]) {
		return NO;
	}
	ll.x += objectDelta.x;
	ll.y += objectDelta.y;
	ur.x += objectDelta.x;
	ur.y += objectDelta.y;
	BOOL movedLL = [self.control setObjectPoint:ll toParameter:self.lowerLeftParameterID atTime:time];
	BOOL movedUR = [self.control setObjectPoint:ur toParameter:self.upperRightParameterID atTime:time];
	return movedLL && movedUR;
}

- (void)drawSelected:(BOOL)selected
		  canvasSize:(CGSize)canvasSize
	  commandEncoder:(nonnull id<MTLRenderCommandEncoder>)commandEncoder
			  atTime:(CMTime)time
{
	CGPoint ll = CGPointZero, ur = CGPointZero;
	double radians = 0.0;
	if (![self readLowerLeft:&ll upperRight:&ur atTime:time]
		|| !FxGripOSCReadAngle(self.control, self.angleParameterID, self.radiansPerUnit, time, &radians)) {
		return;
	}
	CGPoint corners[4] = { ll, CGPointMake(ur.x, ll.y), ur, CGPointMake(ll.x, ur.y) };
	if (radians != 0.0) {
		NSSize inputSize = NSZeroSize;
		if (!FxGripOSCReadInputSize(self.control, &inputSize)) {
			return;
		}
		CGPoint center = CGPointMake((ll.x + ur.x) / 2.0, (ll.y + ur.y) / 2.0);
		for (NSUInteger index = 0; index < 4; index++) {
			CGPoint offset = CGPointMake(corners[index].x - center.x, corners[index].y - center.y);
			offset = FxGripOSCObjectVector(FxGripOSCRotateVector(FxGripOSCPixelVector(offset, inputSize), radians), inputSize);
			corners[index] = CGPointMake(center.x + offset.x, center.y + offset.y);
		}
	}
	CGPoint canvasLL = [self.control canvasPointFromObjectPoint:corners[0]];
	CGPoint canvasLR = [self.control canvasPointFromObjectPoint:corners[1]];
	CGPoint canvasUR = [self.control canvasPointFromObjectPoint:corners[2]];
	CGPoint canvasUL = [self.control canvasPointFromObjectPoint:corners[3]];

	[self.control fillCanvasQuadLL:canvasLL lr:canvasLR ur:canvasUR ul:canvasUL
							 color:(selected ? kFxGripOSCSelectedFillColor : kFxGripOSCUnselectedFillColor)
						canvasSize:canvasSize
					commandEncoder:commandEncoder];
	CGPoint outline[4] = { canvasLL, canvasLR, canvasUR, canvasUL };
	[self.control strokeCanvasPoints:outline
							   count:4
							  closed:YES
							   color:kFxGripOSCOutlineColor
						  withShadow:YES
						  canvasSize:canvasSize
					  commandEncoder:commandEncoder];
}

@end


#pragma mark - Circle

/*!
	@abstract	A circle bound to a center point parameter and a pixel-radius parameter.
	@discussion	Introduced in FxGrip 0.1.0. The radius is in input-image pixels; hit testing and drawing
				normalize it against the input bounds, correcting for aspect ratio. A drag moves the
				center.
*/
@implementation FxGripOSCCirclePart

/*! @abstract Creates a circle bound to a center point and a pixel-radius parameter. */
+ (nonnull instancetype)partWithID:(NSInteger)partID
				 centerParameterID:(FxParameterId)centerParameterID
				 radiusParameterID:(FxParameterId)radiusParameterID
{
	FxGripOSCCirclePart *part = [[self alloc] initWithPartID:partID];
	part.centerParameterID = centerParameterID;
	part.radiusParameterID = radiusParameterID;
	return NARC_AUTORELEASE(part);
}

- (nonnull instancetype)initWithPartID:(NSInteger)partID
{
	self = [super initWithPartID:partID];
	if (self != nil) {
		_segmentCount = 24;
	}
	return self;
}

/*! The circle's pixel radius normalized against the input bounds per axis. */
- (BOOL)readCenter:(nonnull CGPoint *)center normalizedRadius:(nonnull CGPoint *)normalizedRadius atTime:(CMTime)time
{
	if (![self.control getObjectPoint:center fromParameter:self.centerParameterID atTime:time]) {
		return NO;
	}
	double radius = 0.0;
	if (![self.control getFloatValue:&radius fromParameter:self.radiusParameterID atTime:time]) {
		return NO;
	}
	NSRect inputBounds = [self.control.apiManager.onScreenControlAPIv4 inputBounds];
	if (inputBounds.size.width <= 0.0 || inputBounds.size.height <= 0.0) {
		return NO;
	}
	*normalizedRadius = CGPointMake(radius / inputBounds.size.width,
									radius / inputBounds.size.height);
	return YES;
}

- (BOOL)hitTestObjectPoint:(CGPoint)objectPoint canvasPoint:(CGPoint)canvasPoint atTime:(CMTime)time
{
	CGPoint center = CGPointZero, normalizedRadius = CGPointZero;
	if (![self readCenter:&center normalizedRadius:&normalizedRadius atTime:time]) {
		return NO;
	}
	NSRect inputBounds = [self.control.apiManager.onScreenControlAPIv4 inputBounds];
	CGPoint delta = CGPointMake(objectPoint.x - center.x,
								(objectPoint.y - center.y) * inputBounds.size.height / inputBounds.size.width);
	double distance = sqrt(delta.x * delta.x + delta.y * delta.y);
	return distance < normalizedRadius.x;
}

- (BOOL)dragToObjectPoint:(CGPoint)objectPoint
			  objectDelta:(CGPoint)objectDelta
				modifiers:(FxModifierKeys)modifiers
				   atTime:(CMTime)time
{
	CGPoint center = CGPointZero;
	if (![self.control getObjectPoint:&center fromParameter:self.centerParameterID atTime:time]) {
		return NO;
	}
	center.x += objectDelta.x;
	center.y += objectDelta.y;
	return [self.control setObjectPoint:center toParameter:self.centerParameterID atTime:time];
}

- (void)drawSelected:(BOOL)selected
		  canvasSize:(CGSize)canvasSize
	  commandEncoder:(nonnull id<MTLRenderCommandEncoder>)commandEncoder
			  atTime:(CMTime)time
{
	CGPoint center = CGPointZero, normalizedRadius = CGPointZero;
	if (![self readCenter:&center normalizedRadius:&normalizedRadius atTime:time]) {
		return;
	}
	NSUInteger segments = MAX(self.segmentCount, (NSUInteger)3);
	CGPoint *rim = malloc(segments * sizeof(CGPoint));
	if (rim == NULL) {
		return;
	}
	for (NSUInteger index = 0; index < segments; index++) {
		double radians = (double)index * 2.0 * M_PI / (double)segments;
		CGPoint objectRim = CGPointMake(center.x + cos(radians) * normalizedRadius.x,
										center.y + sin(radians) * normalizedRadius.y);
		rim[index] = [self.control canvasPointFromObjectPoint:objectRim];
	}
	CGPoint canvasCenter = [self.control canvasPointFromObjectPoint:center];

	[self.control fillCanvasFanAroundCenter:canvasCenter
								  rimPoints:rim
									  count:segments
									  color:(selected ? kFxGripOSCSelectedFillColor : kFxGripOSCUnselectedFillColor)
								 canvasSize:canvasSize
							 commandEncoder:commandEncoder];
	[self.control strokeCanvasPoints:rim
							   count:segments
							  closed:YES
							   color:kFxGripOSCOutlineColor
						  withShadow:YES
						  canvasSize:canvasSize
					  commandEncoder:commandEncoder];
	free(rim);
}

/*! @abstract The circle body plus a radius handle on its rim. */
+ (nonnull NSArray<FxGripOSCPart *> *)circlePartsWithBodyID:(NSInteger)bodyID
											 radiusHandleID:(NSInteger)radiusHandleID
										  centerParameterID:(FxParameterId)centerParameterID
										  radiusParameterID:(FxParameterId)radiusParameterID
{
	return @[
		[self partWithID:bodyID centerParameterID:centerParameterID radiusParameterID:radiusParameterID],
		[FxGripOSCCircleRadiusHandlePart partWithID:radiusHandleID
								  centerParameterID:centerParameterID
								  radiusParameterID:radiusParameterID],
	];
}

/*! @abstract The circle body, radius handle, and a rotation handle riding the rim. */
+ (nonnull NSArray<FxGripOSCPart *> *)circlePartsWithBodyID:(NSInteger)bodyID
											 radiusHandleID:(NSInteger)radiusHandleID
										   rotationHandleID:(NSInteger)rotationHandleID
										  centerParameterID:(FxParameterId)centerParameterID
										  radiusParameterID:(FxParameterId)radiusParameterID
										   angleParameterID:(FxParameterId)angleParameterID
{
	NSArray<FxGripOSCPart *> *base = [self circlePartsWithBodyID:bodyID
												  radiusHandleID:radiusHandleID
											   centerParameterID:centerParameterID
											   radiusParameterID:radiusParameterID];
	return [base arrayByAddingObject:[FxGripOSCRotationHandlePart partWithID:rotationHandleID
														   centerParameterID:centerParameterID
														   radiusParameterID:radiusParameterID
															angleParameterID:angleParameterID]];
}

/*! @abstract The flag-form circle composite: Body, RadiusHandle, RotationHandle. */
+ (nonnull NSArray<FxGripOSCPart *> *)circlePartsWithOptions:(FxGripOSCShapeOptions)options
												 firstPartID:(NSInteger)firstPartID
										   centerParameterID:(FxParameterId)centerParameterID
										   radiusParameterID:(FxParameterId)radiusParameterID
											angleParameterID:(FxParameterId)angleParameterID
{
	NSMutableArray<FxGripOSCPart *> *parts = [NSMutableArray arrayWithCapacity:3];
	NSInteger partID = firstPartID;
	if (options & FxGripOSCShapeOptionBody) {
		[parts addObject:[self partWithID:partID++
						centerParameterID:centerParameterID
						radiusParameterID:radiusParameterID]];
	}
	if (options & FxGripOSCShapeOptionRadiusHandle) {
		[parts addObject:[FxGripOSCCircleRadiusHandlePart partWithID:partID++
												   centerParameterID:centerParameterID
												   radiusParameterID:radiusParameterID]];
	}
	if ((options & FxGripOSCShapeOptionRotationHandle) && angleParameterID != 0) {
		[parts addObject:[FxGripOSCRotationHandlePart partWithID:partID++
											   centerParameterID:centerParameterID
											   radiusParameterID:radiusParameterID
												angleParameterID:angleParameterID]];
	}
	return parts;
}

@end


#pragma mark - Circle radius handle

/*!
	@abstract	A handle on a circle's rim that resizes the radius parameter.
	@discussion	Introduced in FxGrip 0.1.0. Dragging writes the aspect-corrected object distance from
				the center, scaled to input pixels, into the radius parameter.
*/
@implementation FxGripOSCCircleRadiusHandlePart

/*! @abstract Creates a radius handle on a circle's rim. */
+ (nonnull instancetype)partWithID:(NSInteger)partID
				 centerParameterID:(FxParameterId)centerParameterID
				 radiusParameterID:(FxParameterId)radiusParameterID
{
	FxGripOSCCircleRadiusHandlePart *part = [[self alloc] initWithPartID:partID];
	part.centerParameterID = centerParameterID;
	part.radiusParameterID = radiusParameterID;
	return NARC_AUTORELEASE(part);
}

- (nonnull instancetype)initWithPartID:(NSInteger)partID
{
	self = [super initWithPartID:partID];
	if (self != nil) {
		_hitRadius = 10.0;
		_handleRadius = 4.0;
	}
	return self;
}

/*! The handle's object-space position on the rim at rimAngle. */
- (BOOL)readHandleObjectPoint:(nonnull CGPoint *)handlePoint center:(nonnull CGPoint *)center atTime:(CMTime)time
{
	if (![self.control getObjectPoint:center fromParameter:self.centerParameterID atTime:time]) {
		return NO;
	}
	double radius = 0.0;
	if (![self.control getFloatValue:&radius fromParameter:self.radiusParameterID atTime:time]) {
		return NO;
	}
	NSRect inputBounds = [self.control.apiManager.onScreenControlAPIv4 inputBounds];
	if (inputBounds.size.width <= 0.0 || inputBounds.size.height <= 0.0) {
		return NO;
	}
	*handlePoint = CGPointMake(center->x + cos(self.rimAngle) * radius / inputBounds.size.width,
							   center->y + sin(self.rimAngle) * radius / inputBounds.size.height);
	return YES;
}

- (BOOL)hitTestObjectPoint:(CGPoint)objectPoint canvasPoint:(CGPoint)canvasPoint atTime:(CMTime)time
{
	CGPoint handlePoint = CGPointZero, center = CGPointZero;
	if (![self readHandleObjectPoint:&handlePoint center:&center atTime:time]) {
		return NO;
	}
	CGPoint canvasHandle = [self.control canvasPointFromObjectPoint:handlePoint];
	CGFloat dx = canvasPoint.x - canvasHandle.x;
	CGFloat dy = canvasPoint.y - canvasHandle.y;
	return dx * dx + dy * dy <= self.hitRadius * self.hitRadius;
}

- (BOOL)dragToObjectPoint:(CGPoint)objectPoint
			  objectDelta:(CGPoint)objectDelta
				modifiers:(FxModifierKeys)modifiers
				   atTime:(CMTime)time
{
	CGPoint center = CGPointZero;
	if (![self.control getObjectPoint:&center fromParameter:self.centerParameterID atTime:time]) {
		return NO;
	}
	NSRect inputBounds = [self.control.apiManager.onScreenControlAPIv4 inputBounds];
	if (inputBounds.size.width <= 0.0 || inputBounds.size.height <= 0.0) {
		return NO;
	}
	// The inverse of the circle's normalization: aspect-corrected object distance
	// scaled back to input pixels.
	double dx = objectPoint.x - center.x;
	double dy = (objectPoint.y - center.y) * inputBounds.size.height / inputBounds.size.width;
	double radius = sqrt(dx * dx + dy * dy) * inputBounds.size.width;
	return [self.control setFloatValue:radius toParameter:self.radiusParameterID atTime:time];
}

- (void)drawSelected:(BOOL)selected
		  canvasSize:(CGSize)canvasSize
	  commandEncoder:(nonnull id<MTLRenderCommandEncoder>)commandEncoder
			  atTime:(CMTime)time
{
	CGPoint handlePoint = CGPointZero, center = CGPointZero;
	if (![self readHandleObjectPoint:&handlePoint center:&center atTime:time]) {
		return;
	}
	[self fxDrawHandleAtCanvasPoint:[self.control canvasPointFromObjectPoint:handlePoint]
						   halfSide:self.handleRadius
						   selected:selected
						 canvasSize:canvasSize
					 commandEncoder:commandEncoder];
}

@end


#pragma mark - Rotation handle

/*!
	@abstract	A rotation handle on a circle's rim, bound to center, radius, and angle parameters.
	@discussion	Introduced in FxGrip 0.1.0. The handle sits on the rim at the angle parameter's
				direction. Dragging writes the pointer's angle around the center; Shift snaps to 45°
				increments.
*/
@implementation FxGripOSCRotationHandlePart

// Shift snaps the written angle to 45° increments, so this part reads Shift itself instead of
// letting the base constrain the pointer to an axis.
- (BOOL)handlesConstrainDrag
{
	return YES;
}

+ (nonnull instancetype)partWithID:(NSInteger)partID
				 centerParameterID:(FxParameterId)centerParameterID
				 radiusParameterID:(FxParameterId)radiusParameterID
				  angleParameterID:(FxParameterId)angleParameterID
{
	FxGripOSCRotationHandlePart *part = [[self alloc] initWithPartID:partID];
	part.centerParameterID = centerParameterID;
	part.radiusParameterID = radiusParameterID;
	part.angleParameterID = angleParameterID;
	return NARC_AUTORELEASE(part);
}

- (nonnull instancetype)initWithPartID:(NSInteger)partID
{
	self = [super initWithPartID:partID];
	if (self != nil) {
		_radiansPerUnit = 1.0;
		_hitRadius = 10.0;
		_handleRadius = 4.0;
	}
	return self;
}

/*! The handle's object-space position: the rim point at the angle parameter's
	direction, radius-normalized per axis like the circle body. */
- (BOOL)readHandleObjectPoint:(nonnull CGPoint *)handlePoint center:(nonnull CGPoint *)center atTime:(CMTime)time
{
	if (![self.control getObjectPoint:center fromParameter:self.centerParameterID atTime:time]) {
		return NO;
	}
	double radius = 0.0;
	if (![self.control getFloatValue:&radius fromParameter:self.radiusParameterID atTime:time]) {
		return NO;
	}
	double value = 0.0;
	if (![self.control getFloatValue:&value fromParameter:self.angleParameterID atTime:time]) {
		return NO;
	}
	NSRect inputBounds = [self.control.apiManager.onScreenControlAPIv4 inputBounds];
	if (inputBounds.size.width <= 0.0 || inputBounds.size.height <= 0.0) {
		return NO;
	}
	double radians = value * self.radiansPerUnit;
	*handlePoint = CGPointMake(center->x + cos(radians) * radius / inputBounds.size.width,
							   center->y + sin(radians) * radius / inputBounds.size.height);
	return YES;
}

- (BOOL)hitTestObjectPoint:(CGPoint)objectPoint canvasPoint:(CGPoint)canvasPoint atTime:(CMTime)time
{
	CGPoint handlePoint = CGPointZero, center = CGPointZero;
	if (![self readHandleObjectPoint:&handlePoint center:&center atTime:time]) {
		return NO;
	}
	CGPoint canvasHandle = [self.control canvasPointFromObjectPoint:handlePoint];
	CGFloat dx = canvasPoint.x - canvasHandle.x;
	CGFloat dy = canvasPoint.y - canvasHandle.y;
	return dx * dx + dy * dy <= self.hitRadius * self.hitRadius;
}

- (BOOL)dragToObjectPoint:(CGPoint)objectPoint
			  objectDelta:(CGPoint)objectDelta
				modifiers:(FxModifierKeys)modifiers
				   atTime:(CMTime)time
{
	CGPoint center = CGPointZero;
	if (![self.control getObjectPoint:&center fromParameter:self.centerParameterID atTime:time]) {
		return NO;
	}
	CGPoint canvasCenter = [self.control canvasPointFromObjectPoint:center];
	CGPoint canvasPointer = [self.control canvasPointFromObjectPoint:objectPoint];
	CGFloat dx = canvasPointer.x - canvasCenter.x;
	CGFloat dy = canvasPointer.y - canvasCenter.y;
	if (dx == 0.0 && dy == 0.0) {
		return NO;
	}
	double radians = FxGripOSCConstrainedAngle(atan2(dy, dx), modifiers);
	return [self.control setFloatValue:radians / self.radiansPerUnit
						   toParameter:self.angleParameterID
								atTime:time];
}

- (void)drawSelected:(BOOL)selected
		  canvasSize:(CGSize)canvasSize
	  commandEncoder:(nonnull id<MTLRenderCommandEncoder>)commandEncoder
			  atTime:(CMTime)time
{
	CGPoint handlePoint = CGPointZero, center = CGPointZero;
	if (![self readHandleObjectPoint:&handlePoint center:&center atTime:time]) {
		return;
	}
	CGPoint spoke[2] = {
		[self.control canvasPointFromObjectPoint:center],
		[self.control canvasPointFromObjectPoint:handlePoint],
	};
	[self.control strokeCanvasPoints:spoke
							   count:2
							  closed:NO
							   color:kFxGripOSCOutlineColor
						  withShadow:YES
						  canvasSize:canvasSize
					  commandEncoder:commandEncoder];
	[self fxDrawHandleAtCanvasPoint:spoke[1]
						   halfSide:self.handleRadius
						   selected:selected
						 canvasSize:canvasSize
					 commandEncoder:commandEncoder];
}

@end


#pragma mark - Polyline

/*!
	@abstract	A chain of point parameters drawn as connected segments.
	@discussion	Introduced in FxGrip 0.1.0. A hit is any point within hitRadius canvas pixels of a
				segment; a drag moves every point parameter by the object-space delta. A closed chain
				connects the last point to the first.
*/
@implementation FxGripOSCPolylinePart

/*! @abstract Creates a polyline through the given point parameters. */
+ (nonnull instancetype)partWithID:(NSInteger)partID
				 pointParameterIDs:(nonnull NSArray<NSNumber *> *)pointParameterIDs
							closed:(BOOL)closed
{
	FxGripOSCPolylinePart *part = [[self alloc] initWithPartID:partID];
	part.pointParameterIDs = pointParameterIDs;
	part.closed = closed;
	return NARC_AUTORELEASE(part);
}

/*! @abstract The body plus a point handle per vertex, numbered firstHandleID upward. */
+ (nonnull NSArray<FxGripOSCPart *> *)polylinePartsWithBodyID:(NSInteger)bodyID
												firstHandleID:(NSInteger)firstHandleID
											pointParameterIDs:(nonnull NSArray<NSNumber *> *)pointParameterIDs
													   closed:(BOOL)closed
{
	NSMutableArray<FxGripOSCPart *> *parts = [NSMutableArray arrayWithCapacity:pointParameterIDs.count + 1];
	[parts addObject:[self partWithID:bodyID pointParameterIDs:pointParameterIDs closed:closed]];
	NSInteger handleID = firstHandleID;
	for (NSNumber *parameterID in pointParameterIDs) {
		[parts addObject:[FxGripOSCPointHandlePart partWithID:handleID++
												  parameterID:(FxParameterId)parameterID.unsignedIntValue]];
	}
	return parts;
}

/*! @abstract The flag-form polyline composite: Body, then VertexHandles in chain order. */
+ (nonnull NSArray<FxGripOSCPart *> *)polylinePartsWithOptions:(FxGripOSCShapeOptions)options
												   firstPartID:(NSInteger)firstPartID
											 pointParameterIDs:(nonnull NSArray<NSNumber *> *)pointParameterIDs
														closed:(BOOL)closed
{
	NSMutableArray<FxGripOSCPart *> *parts = [NSMutableArray arrayWithCapacity:pointParameterIDs.count + 1];
	NSInteger partID = firstPartID;
	if (options & FxGripOSCShapeOptionBody) {
		[parts addObject:[self partWithID:partID++ pointParameterIDs:pointParameterIDs closed:closed]];
	}
	if (options & FxGripOSCShapeOptionVertexHandles) {
		for (NSNumber *parameterID in pointParameterIDs) {
			[parts addObject:[FxGripOSCPointHandlePart partWithID:partID++
													  parameterID:(FxParameterId)parameterID.unsignedIntValue]];
		}
	}
	return parts;
}

- (nonnull instancetype)initWithPartID:(NSInteger)partID
{
	self = [super initWithPartID:partID];
	if (self != nil) {
		_pointParameterIDs = NARC_RETAIN(@[]);
		_hitRadius = 6.0;
	}
	return self;
}

- (void)dealloc
{
	NARC_RELEASE(_pointParameterIDs);
	SUPER_DEALLOC();
}

- (BOOL)readCanvasPoints:(nonnull CGPoint *)canvasPoints atTime:(CMTime)time
{
	NSUInteger index = 0;
	for (NSNumber *parameterID in self.pointParameterIDs) {
		CGPoint objectPoint = CGPointZero;
		if (![self.control getObjectPoint:&objectPoint
							fromParameter:(FxParameterId)parameterID.unsignedIntValue
								   atTime:time]) {
			return NO;
		}
		canvasPoints[index++] = [self.control canvasPointFromObjectPoint:objectPoint];
	}
	return YES;
}

static CGFloat FxGripOSCDistanceSquaredToSegment(CGPoint p, CGPoint a, CGPoint b)
{
	CGFloat abX = b.x - a.x, abY = b.y - a.y;
	CGFloat lengthSquared = abX * abX + abY * abY;
	CGFloat t = 0.0;
	if (lengthSquared > 0.0) {
		t = ((p.x - a.x) * abX + (p.y - a.y) * abY) / lengthSquared;
		t = t < 0.0 ? 0.0 : (t > 1.0 ? 1.0 : t);
	}
	CGFloat dx = p.x - (a.x + t * abX);
	CGFloat dy = p.y - (a.y + t * abY);
	return dx * dx + dy * dy;
}

- (BOOL)hitTestObjectPoint:(CGPoint)objectPoint canvasPoint:(CGPoint)canvasPoint atTime:(CMTime)time
{
	NSUInteger count = self.pointParameterIDs.count;
	if (count < 2) {
		return NO;
	}
	CGPoint *points = malloc(count * sizeof(CGPoint));
	if (points == NULL) {
		return NO;
	}
	if (![self readCanvasPoints:points atTime:time]) {
		free(points);
		return NO;
	}
	BOOL hit = NO;
	CGFloat radiusSquared = self.hitRadius * self.hitRadius;
	NSUInteger segments = self.closed ? count : count - 1;
	for (NSUInteger index = 0; index < segments && !hit; index++) {
		hit = FxGripOSCDistanceSquaredToSegment(canvasPoint,
												points[index],
												points[(index + 1) % count]) <= radiusSquared;
	}
	free(points);
	return hit;
}

- (BOOL)dragToObjectPoint:(CGPoint)objectPoint
			  objectDelta:(CGPoint)objectDelta
				modifiers:(FxModifierKeys)modifiers
				   atTime:(CMTime)time
{
	BOOL moved = self.pointParameterIDs.count > 0;
	for (NSNumber *parameterID in self.pointParameterIDs) {
		FxParameterId pid = (FxParameterId)parameterID.unsignedIntValue;
		CGPoint point = CGPointZero;
		if (![self.control getObjectPoint:&point fromParameter:pid atTime:time]) {
			return NO;
		}
		point.x += objectDelta.x;
		point.y += objectDelta.y;
		moved = [self.control setObjectPoint:point toParameter:pid atTime:time] && moved;
	}
	return moved;
}

- (void)drawSelected:(BOOL)selected
		  canvasSize:(CGSize)canvasSize
	  commandEncoder:(nonnull id<MTLRenderCommandEncoder>)commandEncoder
			  atTime:(CMTime)time
{
	NSUInteger count = self.pointParameterIDs.count;
	if (count < 2) {
		return;
	}
	CGPoint *points = malloc(count * sizeof(CGPoint));
	if (points == NULL) {
		return;
	}
	if (![self readCanvasPoints:points atTime:time]) {
		free(points);
		return;
	}
	[self.control strokeCanvasPoints:points
							   count:count
							  closed:self.closed
							   color:(selected ? kFxGripOSCSelectedFillColor : kFxGripOSCOutlineColor)
						  withShadow:YES
						  canvasSize:canvasSize
					  commandEncoder:commandEncoder];
	free(points);
}

@end


#pragma mark - Rectangle rotation handle

/*!
	@abstract	A rotation spoke for the two-corner rectangle's angle overlay.
	@discussion	Introduced in FxGrip 0.1.0. The spoke runs from the corners' midpoint to a tip at a
				fixed canvas radius. Dragging writes the pointer's angle around the midpoint; Shift
				snaps to 45° increments.
*/
@implementation FxGripOSCRectRotationHandlePart

// Shift snaps the written angle to 45° increments, so this part reads Shift itself instead of
// letting the base constrain the pointer to an axis.
- (BOOL)handlesConstrainDrag
{
	return YES;
}

+ (nonnull instancetype)partWithID:(NSInteger)partID
			  lowerLeftParameterID:(FxParameterId)lowerLeftParameterID
			 upperRightParameterID:(FxParameterId)upperRightParameterID
				  angleParameterID:(FxParameterId)angleParameterID
{
	FxGripOSCRectRotationHandlePart *part = [[self alloc] initWithPartID:partID];
	part.lowerLeftParameterID = lowerLeftParameterID;
	part.upperRightParameterID = upperRightParameterID;
	part.angleParameterID = angleParameterID;
	return NARC_AUTORELEASE(part);
}

- (nonnull instancetype)initWithPartID:(NSInteger)partID
{
	self = [super initWithPartID:partID];
	if (self != nil) {
		_radiansPerUnit = 1.0;
		_spokeRadius = 40.0;
		_hitRadius = 10.0;
		_handleRadius = 4.0;
	}
	return self;
}

/*! The spoke from the corners' midpoint to the tip, in canvas space. */
- (BOOL)readCanvasCenter:(nonnull CGPoint *)canvasCenter tip:(nonnull CGPoint *)tip atTime:(CMTime)time
{
	CGPoint ll = CGPointZero, ur = CGPointZero;
	double radians = 0.0;
	if (![self.control getObjectPoint:&ll fromParameter:self.lowerLeftParameterID atTime:time]
		|| ![self.control getObjectPoint:&ur fromParameter:self.upperRightParameterID atTime:time]
		|| !FxGripOSCReadAngle(self.control, self.angleParameterID, self.radiansPerUnit, time, &radians)) {
		return NO;
	}
	CGPoint center = CGPointMake((ll.x + ur.x) / 2.0, (ll.y + ur.y) / 2.0);
	*canvasCenter = [self.control canvasPointFromObjectPoint:center];
	*tip = CGPointMake(canvasCenter->x + cos(radians) * self.spokeRadius,
					   canvasCenter->y + sin(radians) * self.spokeRadius);
	return YES;
}

- (BOOL)hitTestObjectPoint:(CGPoint)objectPoint canvasPoint:(CGPoint)canvasPoint atTime:(CMTime)time
{
	CGPoint canvasCenter = CGPointZero, tip = CGPointZero;
	if (![self readCanvasCenter:&canvasCenter tip:&tip atTime:time]) {
		return NO;
	}
	CGFloat dx = canvasPoint.x - tip.x;
	CGFloat dy = canvasPoint.y - tip.y;
	return dx * dx + dy * dy <= self.hitRadius * self.hitRadius;
}

- (BOOL)dragToObjectPoint:(CGPoint)objectPoint
			  objectDelta:(CGPoint)objectDelta
				modifiers:(FxModifierKeys)modifiers
				   atTime:(CMTime)time
{
	CGPoint ll = CGPointZero, ur = CGPointZero;
	if (![self.control getObjectPoint:&ll fromParameter:self.lowerLeftParameterID atTime:time]
		|| ![self.control getObjectPoint:&ur fromParameter:self.upperRightParameterID atTime:time]) {
		return NO;
	}
	CGPoint center = CGPointMake((ll.x + ur.x) / 2.0, (ll.y + ur.y) / 2.0);
	CGPoint canvasCenter = [self.control canvasPointFromObjectPoint:center];
	CGPoint canvasPointer = [self.control canvasPointFromObjectPoint:objectPoint];
	CGFloat dx = canvasPointer.x - canvasCenter.x;
	CGFloat dy = canvasPointer.y - canvasCenter.y;
	if (dx == 0.0 && dy == 0.0) {
		return NO;
	}
	double radians = FxGripOSCConstrainedAngle(atan2(dy, dx), modifiers);
	return [self.control setFloatValue:radians / self.radiansPerUnit
						   toParameter:self.angleParameterID
								atTime:time];
}

- (void)drawSelected:(BOOL)selected
		  canvasSize:(CGSize)canvasSize
	  commandEncoder:(nonnull id<MTLRenderCommandEncoder>)commandEncoder
			  atTime:(CMTime)time
{
	CGPoint canvasCenter = CGPointZero, tip = CGPointZero;
	if (![self readCanvasCenter:&canvasCenter tip:&tip atTime:time]) {
		return;
	}
	CGPoint spoke[2] = { canvasCenter, tip };
	[self.control strokeCanvasPoints:spoke
							   count:2
							  closed:NO
							   color:kFxGripOSCOutlineColor
						  withShadow:YES
						  canvasSize:canvasSize
					  commandEncoder:commandEncoder];
	[self fxDrawHandleAtCanvasPoint:tip
						   halfSide:self.handleRadius
						   selected:selected
						 canvasSize:canvasSize
					 commandEncoder:commandEncoder];
}

@end


#pragma mark - Box

/*! The box parts' shared geometry: center, half sizes in input pixels, and angle. */
typedef struct FxGripOSCBoxGeometry {
	CGPoint	center;
	double	halfWidth;
	double	halfHeight;
	double	radians;
	NSSize	inputSize;
} FxGripOSCBoxGeometry;

static BOOL FxGripOSCReadBoxGeometry(FxGripOnScreenControl *control,
									 FxParameterId centerID,
									 FxParameterId widthID,
									 FxParameterId heightID,
									 FxParameterId angleID,
									 double radiansPerUnit,
									 CMTime time,
									 FxGripOSCBoxGeometry *geometry)
{
	double width = 0.0, height = 0.0;
	if (![control getObjectPoint:&geometry->center fromParameter:centerID atTime:time]
		|| ![control getFloatValue:&width fromParameter:widthID atTime:time]
		|| ![control getFloatValue:&height fromParameter:heightID atTime:time]
		|| !FxGripOSCReadAngle(control, angleID, radiansPerUnit, time, &geometry->radians)
		|| !FxGripOSCReadInputSize(control, &geometry->inputSize)) {
		return NO;
	}
	geometry->halfWidth = width / 2.0;
	geometry->halfHeight = height / 2.0;
	return YES;
}

/*! The pointer's position in the box's local pixel frame. */
static CGPoint FxGripOSCBoxLocalPoint(CGPoint objectPoint, const FxGripOSCBoxGeometry *geometry)
{
	CGPoint offset = CGPointMake(objectPoint.x - geometry->center.x, objectPoint.y - geometry->center.y);
	return FxGripOSCRotateVector(FxGripOSCPixelVector(offset, geometry->inputSize), -geometry->radians);
}

/*! A local pixel-frame point back in object space. */
static CGPoint FxGripOSCBoxObjectPoint(CGPoint localPoint, const FxGripOSCBoxGeometry *geometry)
{
	CGPoint offset = FxGripOSCObjectVector(FxGripOSCRotateVector(localPoint, geometry->radians), geometry->inputSize);
	return CGPointMake(geometry->center.x + offset.x, geometry->center.y + offset.y);
}

/*! The corner's local pixel-frame position. */
static CGPoint FxGripOSCBoxLocalCorner(FxGripOSCRectCorner corner, const FxGripOSCBoxGeometry *geometry)
{
	double x = (corner == FxGripOSCRectCornerLowerRight || corner == FxGripOSCRectCornerUpperRight)
		? geometry->halfWidth : -geometry->halfWidth;
	double y = (corner == FxGripOSCRectCornerUpperRight || corner == FxGripOSCRectCornerUpperLeft)
		? geometry->halfHeight : -geometry->halfHeight;
	return CGPointMake(x, y);
}

/*!
	@abstract	A rotatable box bound to center, pixel width, pixel height, and angle parameters.
	@discussion	Introduced in FxGrip 0.1.0. Width and height are in input-image pixels; the box rotates
				rigidly about its center. A hit is any pointer inside the rotated box; a drag moves the
				center.
*/
@implementation FxGripOSCBoxPart

/*! @abstract Creates a box bound to center, width, height, and angle parameters. */
+ (nonnull instancetype)partWithID:(NSInteger)partID
				 centerParameterID:(FxParameterId)centerParameterID
				  widthParameterID:(FxParameterId)widthParameterID
				 heightParameterID:(FxParameterId)heightParameterID
				  angleParameterID:(FxParameterId)angleParameterID
{
	FxGripOSCBoxPart *part = [[self alloc] initWithPartID:partID];
	part.centerParameterID = centerParameterID;
	part.widthParameterID = widthParameterID;
	part.heightParameterID = heightParameterID;
	part.angleParameterID = angleParameterID;
	return NARC_AUTORELEASE(part);
}

/*! @abstract The box body, four corner resize handles, and a rotation dial on the center. */
+ (nonnull NSArray<FxGripOSCPart *> *)boxPartsWithBodyID:(NSInteger)bodyID
										   firstCornerID:(NSInteger)firstCornerID
										rotationHandleID:(NSInteger)rotationHandleID
									   centerParameterID:(FxParameterId)centerParameterID
										widthParameterID:(FxParameterId)widthParameterID
									   heightParameterID:(FxParameterId)heightParameterID
										angleParameterID:(FxParameterId)angleParameterID
{
	NSMutableArray<FxGripOSCPart *> *parts = [NSMutableArray arrayWithCapacity:6];
	[parts addObject:[self partWithID:bodyID
					centerParameterID:centerParameterID
					 widthParameterID:widthParameterID
					heightParameterID:heightParameterID
					 angleParameterID:angleParameterID]];
	for (NSInteger corner = FxGripOSCRectCornerLowerLeft; corner <= FxGripOSCRectCornerUpperLeft; corner++) {
		[parts addObject:[FxGripOSCBoxCornerPart partWithID:firstCornerID + corner
													 corner:(FxGripOSCRectCorner)corner
										  centerParameterID:centerParameterID
										   widthParameterID:widthParameterID
										  heightParameterID:heightParameterID
										   angleParameterID:angleParameterID]];
	}
	// A box with no angle parameter is axis-aligned; the dial would never read a value, so omit
	// it, matching the flag-form constructor.
	if (angleParameterID != 0) {
		[parts addObject:[FxGripOSCAngleDialPart partWithID:rotationHandleID
										  centerParameterID:centerParameterID
										   angleParameterID:angleParameterID]];
	}
	return parts;
}

/*! @abstract The flag-form box composite: Body, CornerHandles, RotationHandle. */
+ (nonnull NSArray<FxGripOSCPart *> *)boxPartsWithOptions:(FxGripOSCShapeOptions)options
											  firstPartID:(NSInteger)firstPartID
										centerParameterID:(FxParameterId)centerParameterID
										 widthParameterID:(FxParameterId)widthParameterID
										heightParameterID:(FxParameterId)heightParameterID
										 angleParameterID:(FxParameterId)angleParameterID
{
	NSMutableArray<FxGripOSCPart *> *parts = [NSMutableArray arrayWithCapacity:6];
	NSInteger partID = firstPartID;
	if (options & FxGripOSCShapeOptionBody) {
		[parts addObject:[self partWithID:partID++
						centerParameterID:centerParameterID
						 widthParameterID:widthParameterID
						heightParameterID:heightParameterID
						 angleParameterID:angleParameterID]];
	}
	if (options & FxGripOSCShapeOptionCornerHandles) {
		for (NSInteger corner = FxGripOSCRectCornerLowerLeft; corner <= FxGripOSCRectCornerUpperLeft; corner++) {
			[parts addObject:[FxGripOSCBoxCornerPart partWithID:partID++
														 corner:(FxGripOSCRectCorner)corner
											  centerParameterID:centerParameterID
											   widthParameterID:widthParameterID
											  heightParameterID:heightParameterID
											   angleParameterID:angleParameterID]];
		}
	}
	if ((options & FxGripOSCShapeOptionRotationHandle) && angleParameterID != 0) {
		[parts addObject:[FxGripOSCAngleDialPart partWithID:partID++
										  centerParameterID:centerParameterID
										   angleParameterID:angleParameterID]];
	}
	return parts;
}

- (nonnull instancetype)initWithPartID:(NSInteger)partID
{
	self = [super initWithPartID:partID];
	if (self != nil) {
		_radiansPerUnit = 1.0;
	}
	return self;
}

- (BOOL)hitTestObjectPoint:(CGPoint)objectPoint canvasPoint:(CGPoint)canvasPoint atTime:(CMTime)time
{
	FxGripOSCBoxGeometry geometry;
	if (!FxGripOSCReadBoxGeometry(self.control, self.centerParameterID, self.widthParameterID,
								  self.heightParameterID, self.angleParameterID,
								  self.radiansPerUnit, time, &geometry)) {
		return NO;
	}
	CGPoint local = FxGripOSCBoxLocalPoint(objectPoint, &geometry);
	return fabs(local.x) <= geometry.halfWidth && fabs(local.y) <= geometry.halfHeight;
}

- (BOOL)dragToObjectPoint:(CGPoint)objectPoint
			  objectDelta:(CGPoint)objectDelta
				modifiers:(FxModifierKeys)modifiers
				   atTime:(CMTime)time
{
	CGPoint center = CGPointZero;
	if (![self.control getObjectPoint:&center fromParameter:self.centerParameterID atTime:time]) {
		return NO;
	}
	center.x += objectDelta.x;
	center.y += objectDelta.y;
	return [self.control setObjectPoint:center toParameter:self.centerParameterID atTime:time];
}

- (void)drawSelected:(BOOL)selected
		  canvasSize:(CGSize)canvasSize
	  commandEncoder:(nonnull id<MTLRenderCommandEncoder>)commandEncoder
			  atTime:(CMTime)time
{
	FxGripOSCBoxGeometry geometry;
	if (!FxGripOSCReadBoxGeometry(self.control, self.centerParameterID, self.widthParameterID,
								  self.heightParameterID, self.angleParameterID,
								  self.radiansPerUnit, time, &geometry)) {
		return;
	}
	static const FxGripOSCRectCorner order[4] = {
		FxGripOSCRectCornerLowerLeft, FxGripOSCRectCornerLowerRight,
		FxGripOSCRectCornerUpperRight, FxGripOSCRectCornerUpperLeft,
	};
	CGPoint corners[4];
	for (NSUInteger index = 0; index < 4; index++) {
		CGPoint objectCorner = FxGripOSCBoxObjectPoint(FxGripOSCBoxLocalCorner(order[index], &geometry), &geometry);
		corners[index] = [self.control canvasPointFromObjectPoint:objectCorner];
	}
	[self.control fillCanvasQuadLL:corners[0] lr:corners[1] ur:corners[2] ul:corners[3]
							 color:(selected ? kFxGripOSCSelectedFillColor : kFxGripOSCUnselectedFillColor)
						canvasSize:canvasSize
					commandEncoder:commandEncoder];
	[self.control strokeCanvasPoints:corners
							   count:4
							  closed:YES
							   color:kFxGripOSCOutlineColor
						  withShadow:YES
						  canvasSize:canvasSize
					  commandEncoder:commandEncoder];
}

@end


#pragma mark - Box corner

/*!
	@abstract	A resize handle on one corner of a box.
	@discussion	Introduced in FxGrip 0.1.0. Dragging resizes the box in its local frame, writing the
				width and height parameters. The default anchors the opposite corner; Option anchors
				the center; Shift locks the aspect ratio. The angle never changes.
*/
@implementation FxGripOSCBoxCornerPart

// Shift locks the resize to the box's aspect ratio, so this part reads Shift itself instead of
// letting the base constrain the pointer to an axis.
- (BOOL)handlesConstrainDrag
{
	return YES;
}

// Option anchors the resize to the center, so this part reads Option itself instead of the base's
// fine-drag.
- (BOOL)handlesOptionDrag
{
	return YES;
}

/*! @abstract Creates a resize handle on one corner of a box. */
+ (nonnull instancetype)partWithID:(NSInteger)partID
							corner:(FxGripOSCRectCorner)corner
				 centerParameterID:(FxParameterId)centerParameterID
				  widthParameterID:(FxParameterId)widthParameterID
				 heightParameterID:(FxParameterId)heightParameterID
				  angleParameterID:(FxParameterId)angleParameterID
{
	FxGripOSCBoxCornerPart *part = [[self alloc] initWithPartID:partID];
	part.corner = corner;
	part.centerParameterID = centerParameterID;
	part.widthParameterID = widthParameterID;
	part.heightParameterID = heightParameterID;
	part.angleParameterID = angleParameterID;
	return NARC_AUTORELEASE(part);
}

- (nonnull instancetype)initWithPartID:(NSInteger)partID
{
	self = [super initWithPartID:partID];
	if (self != nil) {
		_radiansPerUnit = 1.0;
		_hitRadius = 10.0;
		_handleRadius = 4.0;
	}
	return self;
}

- (BOOL)readGeometry:(nonnull FxGripOSCBoxGeometry *)geometry atTime:(CMTime)time
{
	return FxGripOSCReadBoxGeometry(self.control, self.centerParameterID, self.widthParameterID,
									self.heightParameterID, self.angleParameterID,
									self.radiansPerUnit, time, geometry);
}

- (BOOL)hitTestObjectPoint:(CGPoint)objectPoint canvasPoint:(CGPoint)canvasPoint atTime:(CMTime)time
{
	FxGripOSCBoxGeometry geometry;
	if (![self readGeometry:&geometry atTime:time]) {
		return NO;
	}
	CGPoint objectCorner = FxGripOSCBoxObjectPoint(FxGripOSCBoxLocalCorner(self.corner, &geometry), &geometry);
	CGPoint canvasCorner = [self.control canvasPointFromObjectPoint:objectCorner];
	CGFloat dx = canvasPoint.x - canvasCorner.x;
	CGFloat dy = canvasPoint.y - canvasCorner.y;
	return dx * dx + dy * dy <= self.hitRadius * self.hitRadius;
}

/*!
	@method		dragToObjectPoint:objectDelta:modifiers:atTime:
	@abstract	Resizes the box in its local frame, writing width and height and, by default, the center.
	@discussion	Introduced in FxGrip 0.1.0. Option resizes symmetrically about the fixed center; the
				default anchors the opposite corner and shifts the center. Shift locks the aspect ratio. */
- (BOOL)dragToObjectPoint:(CGPoint)objectPoint
			  objectDelta:(CGPoint)objectDelta
				modifiers:(FxModifierKeys)modifiers
				   atTime:(CMTime)time
{
	FxGripOSCBoxGeometry geometry;
	if (![self readGeometry:&geometry atTime:time]) {
		return NO;
	}
	// The pointer and the corner signs live in the box's local pixel frame.
	CGPoint local = FxGripOSCBoxLocalPoint(objectPoint, &geometry);
	double signX = (self.corner == FxGripOSCRectCornerLowerRight
					|| self.corner == FxGripOSCRectCornerUpperRight) ? 1.0 : -1.0;
	double signY = (self.corner == FxGripOSCRectCornerUpperRight
					|| self.corner == FxGripOSCRectCornerUpperLeft) ? 1.0 : -1.0;
	BOOL aspectLock = [FxGripEventModifiers isConstrainForFxModifiers:modifiers]
		&& geometry.halfWidth > 0.0 && geometry.halfHeight > 0.0;
	BOOL anchorCenter = (modifiers & kFxModifierKey_OPTION) != 0;

	double halfWidth = 0.0, halfHeight = 0.0;
	CGPoint newCenter = geometry.center;
	if (anchorCenter) {
		// Option resizes symmetrically about the fixed center; the half sizes are the pointer's
		// local extent.
		halfWidth = fabs(local.x);
		halfHeight = fabs(local.y);
		if (aspectLock) {
			double scale = fmax(halfWidth / geometry.halfWidth, halfHeight / geometry.halfHeight);
			halfWidth = scale * geometry.halfWidth;
			halfHeight = scale * geometry.halfHeight;
		}
	} else {
		// The default anchors the diagonally opposite corner in object space; the center shifts.
		CGPoint opposite = CGPointMake(-signX * geometry.halfWidth, -signY * geometry.halfHeight);
		CGPoint dragged = local;
		if (aspectLock) {
			double scale = fmax(fabs(local.x - opposite.x) / (2.0 * geometry.halfWidth),
								fabs(local.y - opposite.y) / (2.0 * geometry.halfHeight));
			halfWidth = scale * geometry.halfWidth;
			halfHeight = scale * geometry.halfHeight;
			dragged = CGPointMake(opposite.x + signX * 2.0 * halfWidth,
								  opposite.y + signY * 2.0 * halfHeight);
		} else {
			halfWidth = fabs(local.x - opposite.x) / 2.0;
			halfHeight = fabs(local.y - opposite.y) / 2.0;
		}
		CGPoint localCenter = CGPointMake((dragged.x + opposite.x) / 2.0, (dragged.y + opposite.y) / 2.0);
		newCenter = FxGripOSCBoxObjectPoint(localCenter, &geometry);
	}

	BOOL setWidth = [self.control setFloatValue:2.0 * halfWidth
									toParameter:self.widthParameterID
										 atTime:time];
	BOOL setHeight = [self.control setFloatValue:2.0 * halfHeight
									 toParameter:self.heightParameterID
										  atTime:time];
	BOOL setCenter = anchorCenter
		|| [self.control setObjectPoint:newCenter toParameter:self.centerParameterID atTime:time];
	return setWidth && setHeight && setCenter;
}

- (void)drawSelected:(BOOL)selected
		  canvasSize:(CGSize)canvasSize
	  commandEncoder:(nonnull id<MTLRenderCommandEncoder>)commandEncoder
			  atTime:(CMTime)time
{
	FxGripOSCBoxGeometry geometry;
	if (![self readGeometry:&geometry atTime:time]) {
		return;
	}
	CGPoint objectCorner = FxGripOSCBoxObjectPoint(FxGripOSCBoxLocalCorner(self.corner, &geometry), &geometry);
	[self fxDrawHandleAtCanvasPoint:[self.control canvasPointFromObjectPoint:objectCorner]
						   halfSide:self.handleRadius
						   selected:selected
						 canvasSize:canvasSize
					 commandEncoder:commandEncoder];
}

@end


#pragma mark - Composites

/*!
	@abstract	The rectangle body with corner resize handles and an optional rotation handle.
	@discussion	Introduced in FxGrip 0.1.0. The composite constructors number the body and handles from
				a first ID and, when an angle parameter is supplied, wire the angle overlay onto every
				part.
*/
@implementation FxGripOSCRectPart (Composites)

/*! @abstract The rectangle body plus four corner resize handles. */
+ (nonnull NSArray<FxGripOSCPart *> *)rectPartsWithBodyID:(NSInteger)bodyID
											firstCornerID:(NSInteger)firstCornerID
									 lowerLeftParameterID:(FxParameterId)lowerLeftParameterID
									upperRightParameterID:(FxParameterId)upperRightParameterID
{
	NSMutableArray<FxGripOSCPart *> *parts = [NSMutableArray arrayWithCapacity:5];
	[parts addObject:[self partWithID:bodyID
				 lowerLeftParameterID:lowerLeftParameterID
				upperRightParameterID:upperRightParameterID]];
	for (NSInteger corner = FxGripOSCRectCornerLowerLeft; corner <= FxGripOSCRectCornerUpperLeft; corner++) {
		[parts addObject:[FxGripOSCRectCornerPart partWithID:firstCornerID + corner
													  corner:(FxGripOSCRectCorner)corner
										lowerLeftParameterID:lowerLeftParameterID
									   upperRightParameterID:upperRightParameterID]];
	}
	return parts;
}

/*! @abstract The rotated rectangle family: the body and corners carry the angle overlay, plus a rotation handle. */
+ (nonnull NSArray<FxGripOSCPart *> *)rectPartsWithBodyID:(NSInteger)bodyID
											firstCornerID:(NSInteger)firstCornerID
										 rotationHandleID:(NSInteger)rotationHandleID
									 lowerLeftParameterID:(FxParameterId)lowerLeftParameterID
									upperRightParameterID:(FxParameterId)upperRightParameterID
										 angleParameterID:(FxParameterId)angleParameterID
{
	NSMutableArray<FxGripOSCPart *> *parts =
		[[self rectPartsWithBodyID:bodyID
					 firstCornerID:firstCornerID
			  lowerLeftParameterID:lowerLeftParameterID
			 upperRightParameterID:upperRightParameterID] mutableCopy];
	for (FxGripOSCPart *part in parts) {
		if ([part isKindOfClass:FxGripOSCRectPart.class]) {
			((FxGripOSCRectPart *)part).angleParameterID = angleParameterID;
		} else if ([part isKindOfClass:FxGripOSCRectCornerPart.class]) {
			((FxGripOSCRectCornerPart *)part).angleParameterID = angleParameterID;
		}
	}
	[parts addObject:[FxGripOSCRectRotationHandlePart partWithID:rotationHandleID
											lowerLeftParameterID:lowerLeftParameterID
										   upperRightParameterID:upperRightParameterID
												angleParameterID:angleParameterID]];
	return NARC_AUTORELEASE(parts);
}

/*! @abstract The flag-form rectangle composite: Body, CornerHandles, RotationHandle. */
+ (nonnull NSArray<FxGripOSCPart *> *)rectPartsWithOptions:(FxGripOSCShapeOptions)options
											   firstPartID:(NSInteger)firstPartID
									  lowerLeftParameterID:(FxParameterId)lowerLeftParameterID
									 upperRightParameterID:(FxParameterId)upperRightParameterID
										  angleParameterID:(FxParameterId)angleParameterID
{
	NSMutableArray<FxGripOSCPart *> *parts = [NSMutableArray arrayWithCapacity:6];
	NSInteger partID = firstPartID;
	if (options & FxGripOSCShapeOptionBody) {
		FxGripOSCRectPart *body = [self partWithID:partID++
							  lowerLeftParameterID:lowerLeftParameterID
							 upperRightParameterID:upperRightParameterID];
		body.angleParameterID = angleParameterID;
		[parts addObject:body];
	}
	if (options & FxGripOSCShapeOptionCornerHandles) {
		for (NSInteger corner = FxGripOSCRectCornerLowerLeft; corner <= FxGripOSCRectCornerUpperLeft; corner++) {
			FxGripOSCRectCornerPart *handle = [FxGripOSCRectCornerPart partWithID:partID++
																		   corner:(FxGripOSCRectCorner)corner
															 lowerLeftParameterID:lowerLeftParameterID
															upperRightParameterID:upperRightParameterID];
			handle.angleParameterID = angleParameterID;
			[parts addObject:handle];
		}
	}
	if ((options & FxGripOSCShapeOptionRotationHandle) && angleParameterID != 0) {
		[parts addObject:[FxGripOSCRectRotationHandlePart partWithID:partID++
												lowerLeftParameterID:lowerLeftParameterID
											   upperRightParameterID:upperRightParameterID
													angleParameterID:angleParameterID]];
	}
	return parts;
}

@end


#pragma mark - Curve (display)

static const NSUInteger kFxGripOSCCurveFlattening = 16;

// Uniform Catmull-Rom: the curve passes through p1 and p2, shaped by neighbors p0 and p3.
static CGPoint FxGripOSCCatmullRomPoint(CGPoint p0, CGPoint p1, CGPoint p2, CGPoint p3, double t)
{
	double t2 = t * t;
	double t3 = t2 * t;
	double x = 0.5 * ((2.0 * p1.x) + (-p0.x + p2.x) * t
					  + (2.0 * p0.x - 5.0 * p1.x + 4.0 * p2.x - p3.x) * t2
					  + (-p0.x + 3.0 * p1.x - 3.0 * p2.x + p3.x) * t3);
	double y = 0.5 * ((2.0 * p1.y) + (-p0.y + p2.y) * t
					  + (2.0 * p0.y - 5.0 * p1.y + 4.0 * p2.y - p3.y) * t2
					  + (-p0.y + 3.0 * p1.y - 3.0 * p2.y + p3.y) * t3);
	return CGPointMake(x, y);
}

/*!
	@abstract	A display-only smooth curve through point parameters.
	@discussion	Introduced in FxGrip 0.1.0. Strokes a Catmull-Rom spline through every control point. The
				part answers no hit and ignores drags.
*/
@implementation FxGripOSCCurvePart

/*! @abstract Creates a display-only curve through the given point parameters. */
+ (nonnull instancetype)partWithID:(NSInteger)partID
				 pointParameterIDs:(nonnull NSArray<NSNumber *> *)pointParameterIDs
							closed:(BOOL)closed
{
	FxGripOSCCurvePart *part = [[self alloc] initWithPartID:partID];
	part.pointParameterIDs = pointParameterIDs;
	part.closed = closed;
	return NARC_AUTORELEASE(part);
}

- (nonnull instancetype)initWithPartID:(NSInteger)partID
{
	self = [super initWithPartID:partID];
	if (self != nil) {
		_pointParameterIDs = @[];
		_color = kFxGripOSCOutlineColor;
	}
	return self;
}

- (BOOL)readCanvasPoints:(nonnull CGPoint *)canvasPoints atTime:(CMTime)time
{
	NSUInteger index = 0;
	for (NSNumber *parameterID in self.pointParameterIDs) {
		CGPoint objectPoint = CGPointZero;
		if (![self.control getObjectPoint:&objectPoint fromParameter:parameterID.unsignedIntValue atTime:time]) {
			return NO;
		}
		canvasPoints[index++] = [self.control canvasPointFromObjectPoint:objectPoint];
	}
	return YES;
}

- (void)drawSelected:(BOOL)selected
		  canvasSize:(CGSize)canvasSize
	  commandEncoder:(nonnull id<MTLRenderCommandEncoder>)commandEncoder
			  atTime:(CMTime)time
{
	NSUInteger count = self.pointParameterIDs.count;
	if (count < 2) {
		return;
	}
	CGPoint *points = malloc(count * sizeof(CGPoint));
	if (points == NULL) {
		return;
	}
	if (![self readCanvasPoints:points atTime:time]) {
		free(points);
		return;
	}

	NSUInteger segments = self.closed ? count : count - 1;
	NSUInteger flatCount = segments * kFxGripOSCCurveFlattening + 1;
	CGPoint *flattened = malloc(flatCount * sizeof(CGPoint));
	if (flattened == NULL) {
		free(points);
		return;
	}
	NSInteger last = (NSInteger)count - 1;
	NSUInteger flatIndex = 0;
	flattened[flatIndex++] = points[0];
	for (NSUInteger segment = 0; segment < segments; segment++) {
		// The two neighbors shape the segment; open ends clamp to the endpoints so the curve
		// stays anchored, closed chains wrap.
		NSInteger i0 = self.closed ? ((NSInteger)segment - 1 + (NSInteger)count) % (NSInteger)count
								   : MAX((NSInteger)0, (NSInteger)segment - 1);
		NSInteger i1 = (NSInteger)segment;
		NSInteger i2 = self.closed ? ((NSInteger)segment + 1) % (NSInteger)count : MIN(last, (NSInteger)segment + 1);
		NSInteger i3 = self.closed ? ((NSInteger)segment + 2) % (NSInteger)count : MIN(last, (NSInteger)segment + 2);
		for (NSUInteger step = 1; step <= kFxGripOSCCurveFlattening; step++) {
			double t = (double)step / (double)kFxGripOSCCurveFlattening;
			flattened[flatIndex++] = FxGripOSCCatmullRomPoint(points[i0], points[i1], points[i2], points[i3], t);
		}
	}

	[self.control strokeCanvasPoints:flattened
							   count:flatIndex
							  closed:NO
							   color:self.color
						  withShadow:YES
						  canvasSize:canvasSize
					  commandEncoder:commandEncoder];
	free(flattened);
	free(points);
}

@end

@interface FxGripOSCHUDPart ()
@property (nonatomic, strong, nullable) id<MTLTexture> cachedTexture;
@property (nonatomic, copy, nullable) NSString *cachedKey;
@end

/*!
	@abstract	A display-only text readout drawn at a fixed pixel size.
	@discussion	Introduced in FxGrip 0.1.0. Rasterizes text to a texture, cached per content and device,
				and draws it over an optional background panel. The part answers no hit and ignores
				drags.
*/
@implementation FxGripOSCHUDPart

/*! @abstract Creates a HUD readout with static text. */
+ (nonnull instancetype)partWithID:(NSInteger)partID text:(nonnull NSString *)text
{
	FxGripOSCHUDPart *part = [[self alloc] initWithPartID:partID];
	part.text = text;
	return NARC_AUTORELEASE(part);
}

/*! @abstract Creates a HUD readout whose text is evaluated at draw time. */
+ (nonnull instancetype)partWithID:(NSInteger)partID textBlock:(nonnull NSString * _Nullable (^)(CMTime time))textBlock
{
	FxGripOSCHUDPart *part = [[self alloc] initWithPartID:partID];
	part.textBlock = textBlock;
	return NARC_AUTORELEASE(part);
}

- (nonnull instancetype)initWithPartID:(NSInteger)partID
{
	self = [super initWithPartID:partID];
	if (self != nil) {
		_text = @"";
		_canvasAnchor = CGPointMake(20.0, 20.0);
		_canvasOffset = CGPointZero;
		_fontSize = 12.0;
		_textColor = kFxGripOSCOutlineColor;
		_backgroundColor = (simd_float4){ 0.0, 0.0, 0.0, 0.6 };
	}
	return self;
}

- (nullable NSString *)resolvedTextAtTime:(CMTime)time
{
	NSString *string = self.textBlock != nil ? self.textBlock(time) : self.text;
	return string.length > 0 ? string : nil;
}

- (BOOL)resolveAnchorCanvasPoint:(nonnull CGPoint *)outPoint atTime:(CMTime)time
{
	CGPoint anchor = self.canvasAnchor;
	if (self.anchorParameterID != 0) {
		CGPoint objectPoint = CGPointZero;
		if (![self.control getObjectPoint:&objectPoint fromParameter:self.anchorParameterID atTime:time]) {
			return NO;
		}
		anchor = [self.control canvasPointFromObjectPoint:objectPoint];
	}
	*outPoint = CGPointMake(anchor.x + self.canvasOffset.x, anchor.y + self.canvasOffset.y);
	return YES;
}

- (nullable id<MTLTexture>)textureForString:(nonnull NSString *)string
									 device:(nonnull id<MTLDevice>)device
{
	simd_float4 color = self.textColor;
	NSString *key = [NSString stringWithFormat:@"%@|%g|%g,%g,%g,%g",
					 string, self.fontSize, color.x, color.y, color.z, color.w];
	if (self.cachedTexture != nil && self.cachedTexture.device == device && [key isEqualToString:self.cachedKey]) {
		return self.cachedTexture;
	}
	id<MTLTexture> texture = [self.control textureForText:string
												fontSize:self.fontSize
												   color:color
												  device:device];
	self.cachedTexture = texture;
	self.cachedKey = texture != nil ? key : nil;
	return texture;
}

/*! @abstract Draws the readout: the optional background panel, then the text texture, at the anchor. */
- (void)drawSelected:(BOOL)selected
		  canvasSize:(CGSize)canvasSize
	  commandEncoder:(nonnull id<MTLRenderCommandEncoder>)commandEncoder
			  atTime:(CMTime)time
{
	NSString *string = [self resolvedTextAtTime:time];
	if (string == nil) {
		return;
	}
	CGPoint anchor = CGPointZero;
	if (![self resolveAnchorCanvasPoint:&anchor atTime:time]) {
		return;
	}
	id<MTLTexture> texture = [self textureForString:string device:commandEncoder.device];
	if (texture == nil) {
		return;
	}

	CGFloat width = (CGFloat)texture.width;
	CGFloat height = (CGFloat)texture.height;
	// Canvas y increases upward (the FxPlug convention): the anchor is the panel's upper-left
	// corner, and the text extends downward to lower y.
	CGPoint ul = anchor;
	CGPoint ur = CGPointMake(anchor.x + width, anchor.y);
	CGPoint lr = CGPointMake(anchor.x + width, anchor.y - height);
	CGPoint ll = CGPointMake(anchor.x, anchor.y - height);

	if (self.backgroundColor.w > 0.0) {
		[self.control fillCanvasQuadLL:ll lr:lr ur:ur ul:ul
								color:self.backgroundColor
						   canvasSize:canvasSize
					   commandEncoder:commandEncoder];
	}
	[self.control encodeTexturedQuadLL:ll lr:lr ur:ur ul:ul
							  texture:texture
								color:(simd_float4){ 1.0, 1.0, 1.0, 1.0 }
						   canvasSize:canvasSize
					   commandEncoder:commandEncoder];
}

@end
