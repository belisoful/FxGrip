//
//  FxGripOSCPart.m
//  FxGrip
//

#import "FxGripOSCPart.h"
#import "FxGripPointListData.h"
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

@implementation FxGripOSCPart

- (nonnull instancetype)initWithPartID:(NSInteger)partID
{
	self = [super init];
	if (self != nil) {
		_partID = partID;
	}
	return self;
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

@implementation FxGripOSCPointHandlePart

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

@implementation FxGripOSCLinePart

+ (nonnull instancetype)partWithID:(NSInteger)partID
				  startParameterID:(FxParameterId)startParameterID
					endParameterID:(FxParameterId)endParameterID
{
	FxGripOSCLinePart *part = [[self alloc] initWithPartID:partID];
	part.startParameterID = startParameterID;
	part.endParameterID = endParameterID;
	return NARC_AUTORELEASE(part);
}

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

@implementation FxGripOSCRectPart

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
	return ll.x <= objectPoint.x && objectPoint.x <= ur.x
		&& ll.y <= objectPoint.y && objectPoint.y <= ur.y;
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

@implementation FxGripOSCCirclePart

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

@implementation FxGripOSCCircleRadiusHandlePart

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

@implementation FxGripOSCPolylinePart

+ (nonnull instancetype)partWithID:(NSInteger)partID
				 pointParameterIDs:(nonnull NSArray<NSNumber *> *)pointParameterIDs
							closed:(BOOL)closed
{
	FxGripOSCPolylinePart *part = [[self alloc] initWithPartID:partID];
	part.pointParameterIDs = pointParameterIDs;
	part.closed = closed;
	return NARC_AUTORELEASE(part);
}

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

+ (nonnull NSArray<FxGripOSCPart *> *)bezierPartsWithOptions:(FxGripOSCShapeOptions)options
												 firstPartID:(NSInteger)firstPartID
										   pointParameterIDs:(nonnull NSArray<NSNumber *> *)pointParameterIDs
									   inTangentParameterIDs:(nonnull NSArray<NSNumber *> *)inTangentParameterIDs
									  outTangentParameterIDs:(nonnull NSArray<NSNumber *> *)outTangentParameterIDs
													  closed:(BOOL)closed
{
	NSUInteger count = pointParameterIDs.count;
	NSMutableArray<FxGripOSCPart *> *parts = [NSMutableArray arrayWithCapacity:1 + 3 * count];
	NSInteger partID = firstPartID;
	if (options & FxGripOSCShapeOptionBody) {
		FxGripOSCPolylinePart *body = [self partWithID:partID++ pointParameterIDs:pointParameterIDs closed:closed];
		body.inTangentParameterIDs = inTangentParameterIDs;
		body.outTangentParameterIDs = outTangentParameterIDs;
		[parts addObject:body];
	}
	if (options & FxGripOSCShapeOptionVertexHandles) {
		for (NSUInteger index = 0; index < count; index++) {
			FxGripOSCBezierVertexHandlePart *handle =
				[FxGripOSCBezierVertexHandlePart partWithID:partID++
										  vertexParameterID:(FxParameterId)pointParameterIDs[index].unsignedIntValue
									   inTangentParameterID:(FxParameterId)inTangentParameterIDs[index].unsignedIntValue
									  outTangentParameterID:(FxParameterId)outTangentParameterIDs[index].unsignedIntValue];
			// The neighbors let a double-click regenerate a smooth tangent; endpoints of an
			// open chain keep a 0 on the missing side.
			if (closed || index > 0) {
				NSUInteger prev = (index == 0) ? count - 1 : index - 1;
				handle.previousVertexParameterID = (FxParameterId)pointParameterIDs[prev].unsignedIntValue;
			}
			if (closed || index + 1 < count) {
				NSUInteger next = (index + 1) % count;
				handle.nextVertexParameterID = (FxParameterId)pointParameterIDs[next].unsignedIntValue;
			}
			[parts addObject:handle];
		}
	}
	if (options & FxGripOSCShapeOptionTangentHandles) {
		for (NSUInteger index = 0; index < count; index++) {
			FxParameterId vertexID = (FxParameterId)pointParameterIDs[index].unsignedIntValue;
			FxParameterId inID = (FxParameterId)inTangentParameterIDs[index].unsignedIntValue;
			FxParameterId outID = (FxParameterId)outTangentParameterIDs[index].unsignedIntValue;
			// An open chain's first in tangent and last out tangent shape no segment.
			BOOL includeIn = closed || index > 0;
			BOOL includeOut = closed || index + 1 < count;
			if (includeIn) {
				FxGripOSCTangentHandlePart *handle = [FxGripOSCTangentHandlePart partWithID:partID++
																		  vertexParameterID:vertexID
																		 tangentParameterID:inID];
				handle.oppositeTangentParameterID = outID;
				[parts addObject:handle];
			}
			if (includeOut) {
				FxGripOSCTangentHandlePart *handle = [FxGripOSCTangentHandlePart partWithID:partID++
																		  vertexParameterID:vertexID
																		 tangentParameterID:outID];
				handle.oppositeTangentParameterID = inID;
				[parts addObject:handle];
			}
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
	NARC_RELEASE(_inTangentParameterIDs);
	NARC_RELEASE(_outTangentParameterIDs);
	SUPER_DEALLOC();
}

/*! Reads a parameter array's points into canvasPoints; NO when any refuses. */
- (BOOL)fxReadCanvasPoints:(nonnull CGPoint *)canvasPoints
			 forParameters:(nonnull NSArray<NSNumber *> *)parameterIDs
					atTime:(CMTime)time
{
	NSUInteger index = 0;
	for (NSNumber *parameterID in parameterIDs) {
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

- (BOOL)readCanvasPoints:(nonnull CGPoint *)canvasPoints atTime:(CMTime)time
{
	return [self fxReadCanvasPoints:canvasPoints forParameters:self.pointParameterIDs atTime:time];
}

/*! The chain curves when both tangent arrays pair one parameter per vertex. */
- (BOOL)fxIsBezier
{
	NSUInteger count = self.pointParameterIDs.count;
	return count > 0
		&& self.inTangentParameterIDs.count == count
		&& self.outTangentParameterIDs.count == count;
}

// Bézier segments flatten into line subdivisions for hit testing and drawing;
// conversion to canvas space is affine, so the cubic evaluates on canvas points.
static const NSUInteger kFxGripOSCBezierFlattening = 16;

static CGPoint FxGripOSCCubicPoint(CGPoint p0, CGPoint c1, CGPoint c2, CGPoint p1, double t)
{
	double u = 1.0 - t;
	double b0 = u * u * u, b1 = 3.0 * u * u * t, b2 = 3.0 * u * t * t, b3 = t * t * t;
	return CGPointMake(b0 * p0.x + b1 * c1.x + b2 * c2.x + b3 * p1.x,
					   b0 * p0.y + b1 * c1.y + b2 * c2.y + b3 * p1.y);
}

/*! The curved chain flattened to canvas points; malloc'd, freed by the caller.
	A closed chain's flattening ends back at its first point. */
- (nullable CGPoint *)fxFlattenedCanvasPointsWithCount:(nonnull NSUInteger *)outCount atTime:(CMTime)time
{
	NSUInteger count = self.pointParameterIDs.count;
	NSUInteger segments = self.closed ? count : count - 1;
	NSUInteger flatCount = segments * kFxGripOSCBezierFlattening + 1;

	CGPoint *vertices = malloc(count * sizeof(CGPoint));
	CGPoint *inTangents = malloc(count * sizeof(CGPoint));
	CGPoint *outTangents = malloc(count * sizeof(CGPoint));
	CGPoint *flattened = malloc(flatCount * sizeof(CGPoint));
	BOOL ready = vertices != NULL && inTangents != NULL && outTangents != NULL && flattened != NULL
		&& [self fxReadCanvasPoints:vertices forParameters:self.pointParameterIDs atTime:time]
		&& [self fxReadCanvasPoints:inTangents forParameters:self.inTangentParameterIDs atTime:time]
		&& [self fxReadCanvasPoints:outTangents forParameters:self.outTangentParameterIDs atTime:time];
	if (ready) {
		NSUInteger flatIndex = 0;
		flattened[flatIndex++] = vertices[0];
		for (NSUInteger segment = 0; segment < segments; segment++) {
			NSUInteger next = (segment + 1) % count;
			for (NSUInteger step = 1; step <= kFxGripOSCBezierFlattening; step++) {
				double t = (double)step / (double)kFxGripOSCBezierFlattening;
				flattened[flatIndex++] = FxGripOSCCubicPoint(vertices[segment], outTangents[segment],
															 inTangents[next], vertices[next], t);
			}
		}
		*outCount = flatCount;
	}
	free(vertices);
	free(inTangents);
	free(outTangents);
	if (!ready) {
		free(flattened);
		return NULL;
	}
	return flattened;
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
	CGPoint *points = NULL;
	BOOL closedChain = self.closed;
	if (self.fxIsBezier) {
		// The flattening already walks the wrap segment of a closed chain.
		if ((points = [self fxFlattenedCanvasPointsWithCount:&count atTime:time]) == NULL) {
			return NO;
		}
		closedChain = NO;
	} else {
		if ((points = malloc(count * sizeof(CGPoint))) == NULL) {
			return NO;
		}
		if (![self readCanvasPoints:points atTime:time]) {
			free(points);
			return NO;
		}
	}
	BOOL hit = NO;
	CGFloat radiusSquared = self.hitRadius * self.hitRadius;
	NSUInteger segments = closedChain ? count : count - 1;
	for (NSUInteger index = 0; index < segments && !hit; index++) {
		hit = FxGripOSCDistanceSquaredToSegment(canvasPoint,
												points[index],
												points[(index + 1) % count]) <= radiusSquared;
	}
	free(points);
	return hit;
}

/*! Moves every parameter in the array by the delta; NO on any refused access. */
- (BOOL)fxMoveParameters:(nonnull NSArray<NSNumber *> *)parameterIDs
				 byDelta:(CGPoint)objectDelta
				  atTime:(CMTime)time
{
	BOOL moved = parameterIDs.count > 0;
	for (NSNumber *parameterID in parameterIDs) {
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

- (BOOL)dragToObjectPoint:(CGPoint)objectPoint
			  objectDelta:(CGPoint)objectDelta
				modifiers:(FxModifierKeys)modifiers
				   atTime:(CMTime)time
{
	BOOL moved = [self fxMoveParameters:self.pointParameterIDs byDelta:objectDelta atTime:time];
	if (moved && self.fxIsBezier) {
		moved = [self fxMoveParameters:self.inTangentParameterIDs byDelta:objectDelta atTime:time]
			&& [self fxMoveParameters:self.outTangentParameterIDs byDelta:objectDelta atTime:time];
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
	CGPoint *points = NULL;
	BOOL closedChain = self.closed;
	if (self.fxIsBezier) {
		if ((points = [self fxFlattenedCanvasPointsWithCount:&count atTime:time]) == NULL) {
			return;
		}
		closedChain = NO;
	} else {
		if ((points = malloc(count * sizeof(CGPoint))) == NULL) {
			return;
		}
		if (![self readCanvasPoints:points atTime:time]) {
			free(points);
			return;
		}
	}
	[self.control strokeCanvasPoints:points
							   count:count
							  closed:closedChain
							   color:(selected ? kFxGripOSCSelectedFillColor : kFxGripOSCOutlineColor)
						  withShadow:YES
						  canvasSize:canvasSize
					  commandEncoder:commandEncoder];
	free(points);
}

@end


#pragma mark - Bézier vertex handle

@implementation FxGripOSCBezierVertexHandlePart

+ (nonnull instancetype)partWithID:(NSInteger)partID
				 vertexParameterID:(FxParameterId)vertexParameterID
			  inTangentParameterID:(FxParameterId)inTangentParameterID
			 outTangentParameterID:(FxParameterId)outTangentParameterID
{
	FxGripOSCBezierVertexHandlePart *part = [[self alloc] initWithPartID:partID];
	part.vertexParameterID = vertexParameterID;
	part.inTangentParameterID = inTangentParameterID;
	part.outTangentParameterID = outTangentParameterID;
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
	CGPoint vertex = CGPointZero;
	if (![self.control getObjectPoint:&vertex fromParameter:self.vertexParameterID atTime:time]) {
		return NO;
	}
	CGPoint canvasVertex = [self.control canvasPointFromObjectPoint:vertex];
	CGFloat dx = canvasPoint.x - canvasVertex.x;
	CGFloat dy = canvasPoint.y - canvasVertex.y;
	return dx * dx + dy * dy <= self.hitRadius * self.hitRadius;
}

/*! Moves a tangent by the vertex's delta; a parameter ID of 0 is no tangent. */
- (BOOL)fxCarryTangent:(FxParameterId)tangentParameterID byDelta:(CGPoint)delta atTime:(CMTime)time
{
	if (tangentParameterID == 0) {
		return YES;
	}
	CGPoint tangent = CGPointZero;
	if (![self.control getObjectPoint:&tangent fromParameter:tangentParameterID atTime:time]) {
		return NO;
	}
	tangent.x += delta.x;
	tangent.y += delta.y;
	return [self.control setObjectPoint:tangent toParameter:tangentParameterID atTime:time];
}

- (BOOL)dragToObjectPoint:(CGPoint)objectPoint
			  objectDelta:(CGPoint)objectDelta
				modifiers:(FxModifierKeys)modifiers
				   atTime:(CMTime)time
{
	CGPoint vertex = CGPointZero;
	if (![self.control getObjectPoint:&vertex fromParameter:self.vertexParameterID atTime:time]) {
		return NO;
	}
	CGPoint delta = CGPointMake(objectPoint.x - vertex.x, objectPoint.y - vertex.y);
	BOOL moved = [self.control setObjectPoint:objectPoint toParameter:self.vertexParameterID atTime:time];
	moved = [self fxCarryTangent:self.inTangentParameterID byDelta:delta atTime:time] && moved;
	moved = [self fxCarryTangent:self.outTangentParameterID byDelta:delta atTime:time] && moved;
	return moved;
}

// A tangent within this object-space distance of its vertex counts as retracted, so the
// side is linear.
static const double kFxGripOSCTangentRetractedEpsilon = 1e-6;

/*! YES when the tangent sits on the vertex, or the side has no tangent parameter. */
- (BOOL)fxTangent:(FxParameterId)tangentParameterID isRetractedFromVertex:(CGPoint)vertex atTime:(CMTime)time
{
	if (tangentParameterID == 0) {
		return YES;
	}
	CGPoint tangent = CGPointZero;
	if (![self.control getObjectPoint:&tangent fromParameter:tangentParameterID atTime:time]) {
		return YES;
	}
	return fabs(tangent.x - vertex.x) <= kFxGripOSCTangentRetractedEpsilon
		&& fabs(tangent.y - vertex.y) <= kFxGripOSCTangentRetractedEpsilon;
}

/*! Writes a tangent parameter, treating an ID of 0 as a side that is absent. */
- (BOOL)fxSetTangent:(FxParameterId)tangentParameterID toObjectPoint:(CGPoint)point atTime:(CMTime)time
{
	if (tangentParameterID == 0) {
		return YES;
	}
	return [self.control setObjectPoint:point toParameter:tangentParameterID atTime:time];
}

/*! Retracts both tangents onto the vertex, so its segments run straight. */
- (BOOL)fxMakeCornerAtVertex:(CGPoint)vertex atTime:(CMTime)time
{
	BOOL in = [self fxSetTangent:self.inTangentParameterID toObjectPoint:vertex atTime:time];
	BOOL out = [self fxSetTangent:self.outTangentParameterID toObjectPoint:vertex atTime:time];
	return in && out;
}

/*! Regenerates smooth tangents along the neighbor axis; NO when no neighbor gives a direction. */
- (BOOL)fxMakeSmoothAroundVertex:(CGPoint)vertex atTime:(CMTime)time
{
	CGPoint previous = vertex, next = vertex;
	BOOL havePrevious = self.previousVertexParameterID != 0
		&& [self.control getObjectPoint:&previous fromParameter:self.previousVertexParameterID atTime:time];
	BOOL haveNext = self.nextVertexParameterID != 0
		&& [self.control getObjectPoint:&next fromParameter:self.nextVertexParameterID atTime:time];
	NSSize inputSize = NSZeroSize;
	if ((!havePrevious && !haveNext) || !FxGripOSCReadInputSize(self.control, &inputSize)) {
		return NO;
	}
	// The smooth axis runs from the previous vertex to the next; an endpoint falls back to the
	// vertex on its missing side.
	CGPoint from = havePrevious ? previous : vertex;
	CGPoint to = haveNext ? next : vertex;
	CGPoint axis = FxGripOSCPixelVector(CGPointMake(to.x - from.x, to.y - from.y), inputSize);
	double axisLength = sqrt(axis.x * axis.x + axis.y * axis.y);
	if (axisLength < 1e-9) {
		return NO;
	}
	// A sixth of the neighbor span is the Catmull-Rom smooth default.
	CGPoint offset = FxGripOSCObjectVector(CGPointMake(axis.x / 6.0, axis.y / 6.0), inputSize);
	BOOL out = [self fxSetTangent:self.outTangentParameterID
					toObjectPoint:CGPointMake(vertex.x + offset.x, vertex.y + offset.y)
						   atTime:time];
	BOOL in = [self fxSetTangent:self.inTangentParameterID
				  toObjectPoint:CGPointMake(vertex.x - offset.x, vertex.y - offset.y)
						 atTime:time];
	return out && in;
}

- (BOOL)mouseDoubleClickAtObjectPoint:(CGPoint)objectPoint
						  canvasPoint:(CGPoint)canvasPoint
							modifiers:(FxModifierKeys)modifiers
							   atTime:(CMTime)time
{
	CGPoint vertex = CGPointZero;
	if (![self.control getObjectPoint:&vertex fromParameter:self.vertexParameterID atTime:time]) {
		return NO;
	}
	BOOL corner = [self fxTangent:self.inTangentParameterID isRetractedFromVertex:vertex atTime:time]
		&& [self fxTangent:self.outTangentParameterID isRetractedFromVertex:vertex atTime:time];
	if (corner) {
		return [self fxMakeSmoothAroundVertex:vertex atTime:time];
	}
	return [self fxMakeCornerAtVertex:vertex atTime:time];
}

- (void)drawSelected:(BOOL)selected
		  canvasSize:(CGSize)canvasSize
	  commandEncoder:(nonnull id<MTLRenderCommandEncoder>)commandEncoder
			  atTime:(CMTime)time
{
	CGPoint vertex = CGPointZero;
	if (![self.control getObjectPoint:&vertex fromParameter:self.vertexParameterID atTime:time]) {
		return;
	}
	[self fxDrawHandleAtCanvasPoint:[self.control canvasPointFromObjectPoint:vertex]
						   halfSide:self.handleRadius
						   selected:selected
						 canvasSize:canvasSize
					 commandEncoder:commandEncoder];
}

@end


#pragma mark - Tangent handle

@implementation FxGripOSCTangentHandlePart

+ (nonnull instancetype)partWithID:(NSInteger)partID
				 vertexParameterID:(FxParameterId)vertexParameterID
				tangentParameterID:(FxParameterId)tangentParameterID
{
	FxGripOSCTangentHandlePart *part = [[self alloc] initWithPartID:partID];
	part.vertexParameterID = vertexParameterID;
	part.tangentParameterID = tangentParameterID;
	return NARC_AUTORELEASE(part);
}

- (nonnull instancetype)initWithPartID:(NSInteger)partID
{
	self = [super initWithPartID:partID];
	if (self != nil) {
		_hitRadius = 8.0;
		_handleRadius = 3.0;
	}
	return self;
}

- (BOOL)hitTestObjectPoint:(CGPoint)objectPoint canvasPoint:(CGPoint)canvasPoint atTime:(CMTime)time
{
	CGPoint tangent = CGPointZero;
	if (![self.control getObjectPoint:&tangent fromParameter:self.tangentParameterID atTime:time]) {
		return NO;
	}
	CGPoint canvasTangent = [self.control canvasPointFromObjectPoint:tangent];
	CGFloat dx = canvasPoint.x - canvasTangent.x;
	CGFloat dy = canvasPoint.y - canvasTangent.y;
	return dx * dx + dy * dy <= self.hitRadius * self.hitRadius;
}

// Option breaks the mirror and Shift snaps the angle here, so the base leaves both to this part.
- (BOOL)handlesOptionDrag
{
	return YES;
}

- (BOOL)handlesConstrainDrag
{
	return YES;
}

- (BOOL)mouseDownAtObjectPoint:(CGPoint)objectPoint
				   canvasPoint:(CGPoint)canvasPoint
					 modifiers:(FxModifierKeys)modifiers
						atTime:(CMTime)time
{
	// Command-click retracts the tangent onto its vertex, making that side linear.
	if (![FxGripEventModifiers isDeleteClickForFxModifiers:modifiers]) {
		return NO;
	}
	CGPoint vertex = CGPointZero;
	if (![self.control getObjectPoint:&vertex fromParameter:self.vertexParameterID atTime:time]) {
		return NO;
	}
	return [self.control setObjectPoint:vertex toParameter:self.tangentParameterID atTime:time];
}

- (BOOL)dragToObjectPoint:(CGPoint)objectPoint
			  objectDelta:(CGPoint)objectDelta
				modifiers:(FxModifierKeys)modifiers
				   atTime:(CMTime)time
{
	CGPoint vertex = CGPointZero;
	NSSize inputSize = NSZeroSize;
	BOOL haveFrame = [self.control getObjectPoint:&vertex fromParameter:self.vertexParameterID atTime:time]
		&& FxGripOSCReadInputSize(self.control, &inputSize);

	// Command holds the tangent retracted on its vertex for the whole gesture.
	if (haveFrame && [FxGripEventModifiers isDeleteClickForFxModifiers:modifiers]) {
		return [self.control setObjectPoint:vertex toParameter:self.tangentParameterID atTime:time];
	}

	// Shift snaps the handle's angle about the vertex to 45° increments, keeping its length.
	CGPoint tangentPoint = objectPoint;
	if (haveFrame && [FxGripEventModifiers isConstrainForFxModifiers:modifiers]) {
		CGPoint offset = FxGripOSCPixelVector(CGPointMake(objectPoint.x - vertex.x, objectPoint.y - vertex.y), inputSize);
		double length = sqrt(offset.x * offset.x + offset.y * offset.y);
		if (length >= 1e-9) {
			double snapped = round(atan2(offset.y, offset.x) / (M_PI_4)) * M_PI_4;
			CGPoint snappedOffset = FxGripOSCObjectVector(CGPointMake(cos(snapped) * length, sin(snapped) * length), inputSize);
			tangentPoint = CGPointMake(vertex.x + snappedOffset.x, vertex.y + snappedOffset.y);
		}
	}

	BOOL moved = [self.control setObjectPoint:tangentPoint toParameter:self.tangentParameterID atTime:time];
	// Option gives this part its own gesture (break the mirror), declared via handlesOptionDrag.
	if (!moved || !haveFrame || self.oppositeTangentParameterID == 0 || (modifiers & kFxModifierKey_OPTION)) {
		return moved;
	}

	// The opposite tangent rotates to stay collinear through the vertex. Aligned mirroring keeps
	// its own length; symmetric mirroring matches the dragged length. Measured in the pixel frame.
	CGPoint opposite = CGPointZero;
	if (![self.control getObjectPoint:&opposite fromParameter:self.oppositeTangentParameterID atTime:time]) {
		return moved;
	}
	CGPoint dragged = FxGripOSCPixelVector(CGPointMake(tangentPoint.x - vertex.x, tangentPoint.y - vertex.y), inputSize);
	double draggedLength = sqrt(dragged.x * dragged.x + dragged.y * dragged.y);
	if (draggedLength < 1e-9) {
		return moved;
	}
	CGPoint oppositeOffset = FxGripOSCPixelVector(CGPointMake(opposite.x - vertex.x, opposite.y - vertex.y), inputSize);
	double oppositeLength = sqrt(oppositeOffset.x * oppositeOffset.x + oppositeOffset.y * oppositeOffset.y);
	double magnitude = (self.mirroring == FxGripOSCTangentMirroringSymmetric) ? draggedLength : oppositeLength;
	CGPoint mirrored = FxGripOSCObjectVector(CGPointMake(-dragged.x / draggedLength * magnitude,
														 -dragged.y / draggedLength * magnitude), inputSize);
	return [self.control setObjectPoint:CGPointMake(vertex.x + mirrored.x, vertex.y + mirrored.y)
							toParameter:self.oppositeTangentParameterID
								 atTime:time] && moved;
}

- (void)drawSelected:(BOOL)selected
		  canvasSize:(CGSize)canvasSize
	  commandEncoder:(nonnull id<MTLRenderCommandEncoder>)commandEncoder
			  atTime:(CMTime)time
{
	CGPoint vertex = CGPointZero, tangent = CGPointZero;
	if (![self.control getObjectPoint:&vertex fromParameter:self.vertexParameterID atTime:time]
		|| ![self.control getObjectPoint:&tangent fromParameter:self.tangentParameterID atTime:time]) {
		return;
	}
	CGPoint stem[2] = {
		[self.control canvasPointFromObjectPoint:vertex],
		[self.control canvasPointFromObjectPoint:tangent],
	};
	[self.control strokeCanvasPoints:stem
							   count:2
							  closed:NO
							   color:kFxGripOSCOutlineColor
						  withShadow:YES
						  canvasSize:canvasSize
					  commandEncoder:commandEncoder];
	[self fxDrawHandleAtCanvasPoint:stem[1]
						   halfSide:self.handleRadius
						   selected:selected
						 canvasSize:canvasSize
					 commandEncoder:commandEncoder];
}

@end


#pragma mark - Rectangle rotation handle

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

@implementation FxGripOSCBoxPart

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
	[parts addObject:[FxGripOSCAngleDialPart partWithID:rotationHandleID
									  centerParameterID:centerParameterID
									   angleParameterID:angleParameterID]];
	return parts;
}

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

@implementation FxGripOSCRectPart (Composites)

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

// Uniform Catmull-Rom: the curve passes through p1 and p2, shaped by neighbours p0 and p3.
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

@implementation FxGripOSCCurvePart

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
		_shadowed = YES;
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
		// The two neighbours shape the segment; open ends clamp to the endpoints so the curve
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
						  withShadow:self.shadowed
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

@implementation FxGripOSCHUDPart

+ (nonnull instancetype)partWithID:(NSInteger)partID text:(nonnull NSString *)text
{
	FxGripOSCHUDPart *part = [[self alloc] initWithPartID:partID];
	part.text = text;
	return NARC_AUTORELEASE(part);
}

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
	// Canvas space is top-left origin, y down: the anchor is the panel's upper-left corner.
	CGPoint ul = anchor;
	CGPoint ur = CGPointMake(anchor.x + width, anchor.y);
	CGPoint lr = CGPointMake(anchor.x + width, anchor.y + height);
	CGPoint ll = CGPointMake(anchor.x, anchor.y + height);

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

@implementation FxGripOSCEditablePolygonPart
{
	NSInteger _selectedVertexIndex;
	NSInteger _lastHitVertexIndex;
	NSInteger _lastHitSegmentIndex;
}

+ (nonnull instancetype)partWithID:(NSInteger)partID pointListParameterID:(FxParameterId)pointListParameterID
{
	FxGripOSCEditablePolygonPart *part = [[self alloc] initWithPartID:partID];
	part.pointListParameterID = pointListParameterID;
	return NARC_AUTORELEASE(part);
}

- (nonnull instancetype)initWithPartID:(NSInteger)partID
{
	self = [super initWithPartID:partID];
	if (self != nil) {
		_selectedVertexIndex = -1;
		_lastHitVertexIndex = -1;
		_lastHitSegmentIndex = -1;
		_requiresModifierToInsert = YES;
		_minimumVertexCount = 2;
		_hitRadius = 6.0;
		_vertexHitRadius = 10.0;
		_handleRadius = 4.0;
		_color = kFxGripOSCOutlineColor;
	}
	return self;
}

- (NSInteger)selectedVertexIndex
{
	return _selectedVertexIndex;
}

- (nullable FxGripPointListData *)pointListAtTime:(CMTime)time
{
	NSObject *value = [self.control getCustomValueFromParameter:self.pointListParameterID atTime:time];
	return [value isKindOfClass:FxGripPointListData.class] ? (FxGripPointListData *)value : nil;
}

- (BOOL)writeList:(FxGripPointListData *)list atTime:(CMTime)time
{
	return [self.control setCustomValue:list toParameter:self.pointListParameterID atTime:time];
}

- (BOOL)hitTestObjectPoint:(CGPoint)objectPoint canvasPoint:(CGPoint)canvasPoint atTime:(CMTime)time
{
	_lastHitVertexIndex = -1;
	_lastHitSegmentIndex = -1;
	FxGripPointListData *list = [self pointListAtTime:time];
	NSUInteger count = list.count;
	if (count == 0) {
		return NO;
	}

	double bestVertexDistanceSquared = _vertexHitRadius * _vertexHitRadius;
	for (NSUInteger index = 0; index < count; index++) {
		CGPoint vertex = [self.control canvasPointFromObjectPoint:[list pointAtIndex:index]];
		double dx = canvasPoint.x - vertex.x;
		double dy = canvasPoint.y - vertex.y;
		double distanceSquared = dx * dx + dy * dy;
		if (distanceSquared <= bestVertexDistanceSquared) {
			bestVertexDistanceSquared = distanceSquared;
			_lastHitVertexIndex = (NSInteger)index;
		}
	}
	if (_lastHitVertexIndex >= 0) {
		return YES;
	}

	NSUInteger segmentCount = list.closed ? count : (count > 0 ? count - 1 : 0);
	double hitRadiusSquared = _hitRadius * _hitRadius;
	for (NSUInteger segment = 0; segment < segmentCount; segment++) {
		CGPoint a = [self.control canvasPointFromObjectPoint:[list pointAtIndex:segment]];
		CGPoint b = [self.control canvasPointFromObjectPoint:[list pointAtIndex:(segment + 1) % count]];
		if (FxGripOSCDistanceSquaredToSegment(canvasPoint, a, b) <= hitRadiusSquared) {
			_lastHitSegmentIndex = (NSInteger)segment;
			return YES;
		}
	}
	return NO;
}

- (BOOL)mouseDownAtObjectPoint:(CGPoint)objectPoint
				   canvasPoint:(CGPoint)canvasPoint
					 modifiers:(FxModifierKeys)modifiers
						atTime:(CMTime)time
{
	_selectedVertexIndex = _lastHitVertexIndex;
	// Command-click on a vertex deletes it, matching the Delete key on the selected vertex.
	if (_lastHitVertexIndex >= 0 && [FxGripEventModifiers isDeleteClickForFxModifiers:modifiers]) {
		return [self removeSelectedVertexAtTime:time];
	}
	if (_lastHitVertexIndex < 0 && _lastHitSegmentIndex >= 0) {
		BOOL modifierSatisfied = !_requiresModifierToInsert || (modifiers & kFxModifierKey_OPTION) != 0;
		if (modifierSatisfied) {
			return [self insertVertexOnSegment:(NSUInteger)_lastHitSegmentIndex
								 atObjectPoint:objectPoint
										atTime:time];
		}
	}
	return NO;
}

- (BOOL)insertVertexOnSegment:(NSUInteger)segment atObjectPoint:(CGPoint)objectPoint atTime:(CMTime)time
{
	FxGripPointListData *list = [self pointListAtTime:time];
	NSUInteger count = list.count;
	if (count < 2 || segment >= count) {
		return NO;
	}
	CGPoint a = [list pointAtIndex:segment];
	CGPoint b = [list pointAtIndex:(segment + 1) % count];
	CGPoint ab = CGPointMake(b.x - a.x, b.y - a.y);
	double lengthSquared = ab.x * ab.x + ab.y * ab.y;
	double t = 0.5;
	if (lengthSquared > 0.0) {
		t = ((objectPoint.x - a.x) * ab.x + (objectPoint.y - a.y) * ab.y) / lengthSquared;
		t = t < 0.0 ? 0.0 : (t > 1.0 ? 1.0 : t);
	}
	CGPoint inserted = CGPointMake(a.x + t * ab.x, a.y + t * ab.y);
	NSUInteger insertIndex = segment + 1;
	FxGripPointListData *updated = [list byInsertingPoint:inserted atIndex:insertIndex];
	if (![self writeList:updated atTime:time]) {
		return NO;
	}
	_selectedVertexIndex = (NSInteger)insertIndex;
	return YES;
}

- (BOOL)dragToObjectPoint:(CGPoint)objectPoint
			  objectDelta:(CGPoint)objectDelta
				modifiers:(FxModifierKeys)modifiers
				   atTime:(CMTime)time
{
	FxGripPointListData *list = [self pointListAtTime:time];
	if (list == nil || list.count == 0) {
		return NO;
	}
	FxGripPointListData *updated = nil;
	if (_selectedVertexIndex >= 0 && (NSUInteger)_selectedVertexIndex < list.count) {
		updated = [list byReplacingPointAtIndex:(NSUInteger)_selectedVertexIndex withPoint:objectPoint];
	} else {
		updated = [list byTranslatingBy:objectDelta];
	}
	return [self writeList:updated atTime:time];
}

- (BOOL)keyDownWithKey:(unsigned short)asciiKey
			 modifiers:(FxModifierKeys)modifiers
				atTime:(CMTime)time
{
	// Delete (127) or Backspace (8) removes the selected vertex.
	if (asciiKey != 127 && asciiKey != 8) {
		return NO;
	}
	return [self removeSelectedVertexAtTime:time];
}

/*! Removes the selected vertex, unless it would drop below the minimum count. */
- (BOOL)removeSelectedVertexAtTime:(CMTime)time
{
	if (_selectedVertexIndex < 0) {
		return NO;
	}
	FxGripPointListData *list = [self pointListAtTime:time];
	if (list == nil || (NSUInteger)_selectedVertexIndex >= list.count || list.count <= self.minimumVertexCount) {
		return NO;
	}
	FxGripPointListData *updated = [list byRemovingPointAtIndex:(NSUInteger)_selectedVertexIndex];
	_selectedVertexIndex = -1;
	return [self writeList:updated atTime:time];
}

- (void)drawSelected:(BOOL)selected
		  canvasSize:(CGSize)canvasSize
	  commandEncoder:(nonnull id<MTLRenderCommandEncoder>)commandEncoder
			  atTime:(CMTime)time
{
	FxGripPointListData *list = [self pointListAtTime:time];
	NSUInteger count = list.count;
	if (count == 0) {
		return;
	}
	CGPoint *points = malloc(count * sizeof(CGPoint));
	if (points == NULL) {
		return;
	}
	for (NSUInteger index = 0; index < count; index++) {
		points[index] = [self.control canvasPointFromObjectPoint:[list pointAtIndex:index]];
	}
	if (count >= 2) {
		[self.control strokeCanvasPoints:points
								   count:count
								  closed:list.closed
								   color:self.color
							  withShadow:YES
							  canvasSize:canvasSize
						  commandEncoder:commandEncoder];
	}
	for (NSUInteger index = 0; index < count; index++) {
		[self fxDrawHandleAtCanvasPoint:points[index]
							   halfSide:self.handleRadius
							   selected:((NSInteger)index == _selectedVertexIndex)
							 canvasSize:canvasSize
						 commandEncoder:commandEncoder];
	}
	free(points);
}

@end
