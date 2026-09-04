//
//  FxGripOSCPathPart.m
//  FxGrip
//

#import "FxGripOSCPathPart.h"
#import "FxGripEventModifiers.h"
#import "FxGrip_ARC.h"

// The stock handle drawing, implemented on FxGripOSCPart.
@interface FxGripOSCPart (FxGripHandleDrawing)
- (void)fxDrawHandleAtCanvasPoint:(CGPoint)center
						 halfSide:(double)halfSide
						 selected:(BOOL)selected
					   canvasSize:(CGSize)canvasSize
				   commandEncoder:(nonnull id<MTLRenderCommandEncoder>)commandEncoder;
@end

typedef NS_ENUM(NSInteger, FxGripOSCPathActiveKind) {
	FxGripOSCPathActiveNone = 0,
	FxGripOSCPathActiveVertex,
	FxGripOSCPathActiveInTangent,
	FxGripOSCPathActiveOutTangent,
	FxGripOSCPathActiveSegment,
};

// Flattening steps per cubic segment, for drawing and segment hit-testing.
static const NSUInteger kFxGripOSCPathFlattening = 16;

// A tangent within this object-space distance of its vertex counts as retracted, so the side is
// linear; matches the Bézier vertex handle's epsilon.
static const double kFxGripOSCPathTangentRetractedEpsilon = 1e-6;

static NSSize FxGripOSCPathInputSize(FxGripOnScreenControl *control)
{
	NSRect bounds = [control.apiManager.onScreenControlAPIv4 inputBounds];
	if (bounds.size.width <= 0.0 || bounds.size.height <= 0.0) {
		return NSMakeSize(1.0, 1.0);
	}
	return bounds.size;
}

static CGPoint FxGripOSCPathToPixels(CGPoint objectVector, NSSize inputSize)
{
	return CGPointMake(objectVector.x * inputSize.width, objectVector.y * inputSize.height);
}

static CGPoint FxGripOSCPathToObject(CGPoint pixelVector, NSSize inputSize)
{
	return CGPointMake(pixelVector.x / inputSize.width, pixelVector.y / inputSize.height);
}

@implementation FxGripOSCPathPart
{
	NSInteger _selectedVertexIndex;
	FxGripOSCPathActiveKind _activeKind;
	NSInteger _activeIndex;
	FxGripOSCPathActiveKind _lastHitKind;
	NSInteger _lastHitIndex;
	NSInteger _lastHitSegmentIndex;
	NSMutableArray<NSNumber *> *_mutableStyles;	// per-parameter backing's live styles
}

+ (nonnull instancetype)pathPartWithID:(NSInteger)partID
					   pathParameterID:(FxParameterId)pathParameterID
							   options:(FxGripOSCPathOptions)options
{
	FxGripOSCPathPart *part = [[self alloc] initWithPartID:partID];
	part.pathParameterID = pathParameterID;
	part.options = options;
	return NARC_AUTORELEASE(part);
}

+ (nonnull instancetype)pathPartWithID:(NSInteger)partID
				  locationParameterIDs:(nonnull NSArray<NSNumber *> *)locationParameterIDs
								closed:(BOOL)closed
							   options:(FxGripOSCPathOptions)options
{
	FxGripOSCPathPart *part = [[self alloc] initWithPartID:partID];
	part.locationParameterIDs = locationParameterIDs;
	part.closed = closed;
	part.options = options;
	return NARC_AUTORELEASE(part);
}

- (nonnull instancetype)initWithPartID:(NSInteger)partID
{
	self = [super initWithPartID:partID];
	if (self != nil) {
		_selectedVertexIndex = -1;
		_activeKind = FxGripOSCPathActiveNone;
		_activeIndex = -1;
		_lastHitKind = FxGripOSCPathActiveNone;
		_lastHitIndex = -1;
		_lastHitSegmentIndex = -1;
		_options = FxGripOSCPathOptionVertexHandles;
		_color = kFxGripOSCOutlineColor;
		_hitRadius = 6.0;
		_vertexHitRadius = 10.0;
		_handleRadius = 4.0;
		_minimumVertexCount = 2;
	}
	return self;
}

- (void)dealloc
{
	NARC_RELEASE(_locationParameterIDs);
	NARC_RELEASE(_inTangentParameterIDs);
	NARC_RELEASE(_outTangentParameterIDs);
	NARC_RELEASE(_xSplineWeightParameterIDs);
	NARC_RELEASE(_interpStyles);
	NARC_RELEASE(_mutableStyles);
	SUPER_DEALLOC();
}

- (NSInteger)selectedVertexIndex
{
	return _selectedVertexIndex;
}

- (BOOL)usesCustomData
{
	return self.pathParameterID != 0;
}


#pragma mark Backing reads

- (nullable FxGripPathData *)pathDataAtTime:(CMTime)time
{
	NSObject *value = [self.control getCustomValueFromParameter:self.pathParameterID atTime:time];
	return [value isKindOfClass:FxGripPathData.class] ? (FxGripPathData *)value : nil;
}

/*! The per-vertex style for the per-parameter backing at an index. */
- (FxPathStyle)perParameterStyleAtIndex:(NSUInteger)index
{
	NSArray<NSNumber *> *styles = _mutableStyles != nil ? _mutableStyles : self.interpStyles;
	if (index < styles.count) {
		return (FxPathStyle)styles[index].unsignedIntegerValue;
	}
	BOOL hasTangents = self.inTangentParameterIDs.count > index || self.outTangentParameterIDs.count > index;
	return hasTangents ? kFxPathStyle_Bezier : kFxPathStyle_Linear;
}

/*! Reads a point parameter as a vector, or the zero vector when it is absent. */
- (CGPoint)vectorFromParameters:(NSArray<NSNumber *> *)parameterIDs index:(NSUInteger)index atTime:(CMTime)time
{
	if (index >= parameterIDs.count) {
		return CGPointZero;
	}
	CGPoint vector = CGPointZero;
	[self.control getObjectPoint:&vector
				  fromParameter:(FxParameterId)parameterIDs[index].unsignedIntValue
						 atTime:time];
	return vector;
}

/*! Reads the whole path into a malloc'd FxVertex array; the caller frees it. */
- (nullable FxVertex *)readVertices:(nonnull NSUInteger *)outCount
							 closed:(nonnull BOOL *)outClosed
							 atTime:(CMTime)time
{
	if (self.usesCustomData) {
		FxGripPathData *data = [self pathDataAtTime:time];
		NSUInteger count = data.vertexCount;
		*outCount = count;
		*outClosed = data.closed;
		if (count == 0) {
			return NULL;
		}
		FxVertex *vertices = malloc(count * sizeof(FxVertex));
		if (vertices != NULL) {
			[data copyVerticesToBuffer:vertices capacity:count];
		}
		return vertices;
	}

	NSUInteger count = self.locationParameterIDs.count;
	*outCount = count;
	*outClosed = self.closed;
	if (count == 0) {
		return NULL;
	}
	FxVertex *vertices = malloc(count * sizeof(FxVertex));
	if (vertices == NULL) {
		return NULL;
	}
	for (NSUInteger index = 0; index < count; index++) {
		FxVertex vertex = { 0 };
		CGPoint location = CGPointZero;
		[self.control getObjectPoint:&location
					  fromParameter:(FxParameterId)self.locationParameterIDs[index].unsignedIntValue
							 atTime:time];
		vertex.location = location;
		vertex.inTangent = [self vectorFromParameters:self.inTangentParameterIDs index:index atTime:time];
		vertex.outTangent = [self vectorFromParameters:self.outTangentParameterIDs index:index atTime:time];
		if (index < self.xSplineWeightParameterIDs.count) {
			double weight = 0.0;
			[self.control getFloatValue:&weight
						  fromParameter:(FxParameterId)self.xSplineWeightParameterIDs[index].unsignedIntValue
								 atTime:time];
			vertex.xSplineWeight = weight;
		}
		vertex.interpStyle = [self perParameterStyleAtIndex:index];
		vertices[index] = vertex;
	}
	return vertices;
}


#pragma mark Backing writes

- (BOOL)writeLocationAtIndex:(NSUInteger)index toObjectPoint:(CGPoint)location atTime:(CMTime)time
{
	if (self.usesCustomData) {
		FxGripPathData *data = [self pathDataAtTime:time];
		if (index >= data.vertexCount) {
			return NO;
		}
		return [self.control setCustomValue:[data byReplacingLocationAtIndex:index withLocation:location]
							   toParameter:self.pathParameterID
									atTime:time];
	}
	if (index >= self.locationParameterIDs.count) {
		return NO;
	}
	return [self.control setObjectPoint:location
						   toParameter:(FxParameterId)self.locationParameterIDs[index].unsignedIntValue
								atTime:time];
}

- (BOOL)writeTangentAtIndex:(NSUInteger)index
					isOutgoing:(BOOL)isOutgoing
				 objectVector:(CGPoint)vector
					   atTime:(CMTime)time
{
	if (self.usesCustomData) {
		FxGripPathData *data = [self pathDataAtTime:time];
		if (index >= data.vertexCount) {
			return NO;
		}
		FxVertex vertex = [data vertexAtIndex:index];
		if (isOutgoing) {
			vertex.outTangent = vector;
		} else {
			vertex.inTangent = vector;
		}
		return [self.control setCustomValue:[data byReplacingVertexAtIndex:index withVertex:vertex]
							   toParameter:self.pathParameterID
									atTime:time];
	}
	NSArray<NSNumber *> *parameterIDs = isOutgoing ? self.outTangentParameterIDs : self.inTangentParameterIDs;
	if (index >= parameterIDs.count) {
		return NO;
	}
	return [self.control setObjectPoint:vector
						   toParameter:(FxParameterId)parameterIDs[index].unsignedIntValue
								atTime:time];
}

- (BOOL)writeStyleAtIndex:(NSUInteger)index toStyle:(FxPathStyle)style atTime:(CMTime)time
{
	if (self.usesCustomData) {
		FxGripPathData *data = [self pathDataAtTime:time];
		if (index >= data.vertexCount) {
			return NO;
		}
		FxVertex vertex = [data vertexAtIndex:index];
		vertex.interpStyle = style;
		return [self.control setCustomValue:[data byReplacingVertexAtIndex:index withVertex:vertex]
							   toParameter:self.pathParameterID
									atTime:time];
	}
	if (_mutableStyles == nil) {
		_mutableStyles = self.interpStyles != nil ? [self.interpStyles mutableCopy] : [NSMutableArray array];
	}
	while (_mutableStyles.count <= index) {
		[_mutableStyles addObject:@(kFxPathStyle_Bezier)];
	}
	_mutableStyles[index] = @(style);
	return YES;
}


#pragma mark Geometry

/*! The flattened canvas polyline of the whole path; malloc'd, freed by the caller. */
- (nullable CGPoint *)flattenedCanvasPointsWithCount:(nonnull NSUInteger *)outCount atTime:(CMTime)time
{
	NSUInteger vertexCount = 0;
	BOOL closed = NO;
	FxVertex *vertices = [self readVertices:&vertexCount closed:&closed atTime:time];
	NSUInteger segmentCount = FxGripPathSegmentCount(vertexCount, closed);
	if (vertices == NULL || segmentCount == 0) {
		free(vertices);
		return NULL;
	}
	FxGripCubicSegment *segments = malloc(segmentCount * sizeof(FxGripCubicSegment));
	CGPoint *flattened = malloc((segmentCount * kFxGripOSCPathFlattening + 1) * sizeof(CGPoint));
	if (segments == NULL || flattened == NULL) {
		free(vertices);
		free(segments);
		free(flattened);
		return NULL;
	}
	FxGripPathCubicSegments(vertices, vertexCount, closed, segments, segmentCount);
	NSUInteger flatIndex = 0;
	flattened[flatIndex++] = [self.control canvasPointFromObjectPoint:segments[0].p0];
	for (NSUInteger segment = 0; segment < segmentCount; segment++) {
		for (NSUInteger step = 1; step <= kFxGripOSCPathFlattening; step++) {
			double t = (double)step / (double)kFxGripOSCPathFlattening;
			CGPoint objectPoint = FxGripCubicSegmentPoint(segments[segment], t);
			flattened[flatIndex++] = [self.control canvasPointFromObjectPoint:objectPoint];
		}
	}
	*outCount = flatIndex;
	free(vertices);
	free(segments);
	return flattened;
}

static CGFloat FxGripOSCPathDistanceSquaredToSegment(CGPoint p, CGPoint a, CGPoint b)
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

/*! YES when the style exposes editable tangent handles. */
static BOOL FxGripOSCPathStyleHasTangents(FxPathStyle style)
{
	return style == kFxPathStyle_Bezier || style == kFxPathStyle_SuperEllipse;
}


#pragma mark Hit testing

- (BOOL)hitTestObjectPoint:(CGPoint)objectPoint canvasPoint:(CGPoint)canvasPoint atTime:(CMTime)time
{
	_lastHitKind = FxGripOSCPathActiveNone;
	_lastHitIndex = -1;
	_lastHitSegmentIndex = -1;

	NSUInteger vertexCount = 0;
	BOOL closed = NO;
	FxVertex *vertices = [self readVertices:&vertexCount closed:&closed atTime:time];
	if (vertices == NULL || vertexCount == 0) {
		free(vertices);
		return NO;
	}

	// Vertices win over tangents win over the body.
	if (self.options & FxGripOSCPathOptionVertexHandles) {
		double best = self.vertexHitRadius * self.vertexHitRadius;
		for (NSUInteger index = 0; index < vertexCount; index++) {
			CGPoint canvasVertex = [self.control canvasPointFromObjectPoint:vertices[index].location];
			CGFloat dx = canvasPoint.x - canvasVertex.x, dy = canvasPoint.y - canvasVertex.y;
			if (dx * dx + dy * dy <= best) {
				best = dx * dx + dy * dy;
				_lastHitKind = FxGripOSCPathActiveVertex;
				_lastHitIndex = (NSInteger)index;
			}
		}
		if (_lastHitKind == FxGripOSCPathActiveVertex) {
			free(vertices);
			return YES;
		}
	}

	if (self.options & FxGripOSCPathOptionTangentHandles) {
		double best = self.vertexHitRadius * self.vertexHitRadius;
		for (NSUInteger index = 0; index < vertexCount; index++) {
			if (!FxGripOSCPathStyleHasTangents(vertices[index].interpStyle)) {
				continue;
			}
			CGPoint inTip = CGPointMake(vertices[index].location.x + vertices[index].inTangent.x,
										vertices[index].location.y + vertices[index].inTangent.y);
			CGPoint outTip = CGPointMake(vertices[index].location.x + vertices[index].outTangent.x,
										 vertices[index].location.y + vertices[index].outTangent.y);
			CGPoint canvasIn = [self.control canvasPointFromObjectPoint:inTip];
			CGPoint canvasOut = [self.control canvasPointFromObjectPoint:outTip];
			CGFloat inDX = canvasPoint.x - canvasIn.x, inDY = canvasPoint.y - canvasIn.y;
			CGFloat outDX = canvasPoint.x - canvasOut.x, outDY = canvasPoint.y - canvasOut.y;
			if (inDX * inDX + inDY * inDY <= best) {
				best = inDX * inDX + inDY * inDY;
				_lastHitKind = FxGripOSCPathActiveInTangent;
				_lastHitIndex = (NSInteger)index;
			}
			if (outDX * outDX + outDY * outDY <= best) {
				best = outDX * outDX + outDY * outDY;
				_lastHitKind = FxGripOSCPathActiveOutTangent;
				_lastHitIndex = (NSInteger)index;
			}
		}
		if (_lastHitKind == FxGripOSCPathActiveInTangent || _lastHitKind == FxGripOSCPathActiveOutTangent) {
			free(vertices);
			return YES;
		}
	}
	free(vertices);

	if (self.options & (FxGripOSCPathOptionBodyDrag | FxGripOSCPathOptionEditable)) {
		NSUInteger flatCount = 0;
		CGPoint *points = [self flattenedCanvasPointsWithCount:&flatCount atTime:time];
		if (points != NULL) {
			double radiusSquared = self.hitRadius * self.hitRadius;
			BOOL hit = NO;
			for (NSUInteger index = 0; index + 1 < flatCount && !hit; index++) {
				if (FxGripOSCPathDistanceSquaredToSegment(canvasPoint, points[index], points[index + 1]) <= radiusSquared) {
					hit = YES;
				}
			}
			free(points);
			if (hit) {
				_lastHitKind = FxGripOSCPathActiveSegment;
				return YES;
			}
		}
	}
	return NO;
}


#pragma mark Mouse and key

- (BOOL)mouseDownAtObjectPoint:(CGPoint)objectPoint
				   canvasPoint:(CGPoint)canvasPoint
					 modifiers:(FxModifierKeys)modifiers
						atTime:(CMTime)time
{
	_activeKind = _lastHitKind;
	_activeIndex = _lastHitIndex;
	if (_lastHitKind == FxGripOSCPathActiveVertex) {
		_selectedVertexIndex = _lastHitIndex;
		if ((self.options & FxGripOSCPathOptionEditable) && [FxGripEventModifiers isDeleteClickForFxModifiers:modifiers]) {
			return [self removeSelectedVertexAtTime:time];
		}
		return NO;
	}
	if ((self.options & FxGripOSCPathOptionEditable) && _lastHitKind == FxGripOSCPathActiveSegment) {
		return [self insertVertexAtObjectPoint:objectPoint atTime:time];
	}
	return NO;
}

- (BOOL)keyDownWithKey:(unsigned short)asciiKey modifiers:(FxModifierKeys)modifiers atTime:(CMTime)time
{
	if (!(self.options & FxGripOSCPathOptionEditable)) {
		return NO;
	}
	// Delete (127) or Backspace (8) removes the selected vertex.
	if (asciiKey != 127 && asciiKey != 8) {
		return NO;
	}
	return [self removeSelectedVertexAtTime:time];
}

- (BOOL)mouseDoubleClickAtObjectPoint:(CGPoint)objectPoint
						  canvasPoint:(CGPoint)canvasPoint
							modifiers:(FxModifierKeys)modifiers
							   atTime:(CMTime)time
{
	if (!(self.options & FxGripOSCPathOptionEditable) || _lastHitKind != FxGripOSCPathActiveVertex) {
		return NO;
	}
	return [self toggleVertexStyleAtIndex:(NSUInteger)_lastHitIndex atTime:time];
}

- (BOOL)handlesOptionDrag
{
	return _activeKind == FxGripOSCPathActiveInTangent || _activeKind == FxGripOSCPathActiveOutTangent;
}

- (BOOL)handlesConstrainDrag
{
	return _activeKind == FxGripOSCPathActiveInTangent || _activeKind == FxGripOSCPathActiveOutTangent;
}


#pragma mark Drag

- (BOOL)dragToObjectPoint:(CGPoint)objectPoint
			  objectDelta:(CGPoint)objectDelta
				modifiers:(FxModifierKeys)modifiers
				   atTime:(CMTime)time
{
	switch (_activeKind) {
		case FxGripOSCPathActiveVertex:
			return [self writeLocationAtIndex:(NSUInteger)_activeIndex toObjectPoint:objectPoint atTime:time];
		case FxGripOSCPathActiveInTangent:
			return [self dragTangentAtIndex:(NSUInteger)_activeIndex isOutgoing:NO
							 toObjectPoint:objectPoint modifiers:modifiers atTime:time];
		case FxGripOSCPathActiveOutTangent:
			return [self dragTangentAtIndex:(NSUInteger)_activeIndex isOutgoing:YES
							 toObjectPoint:objectPoint modifiers:modifiers atTime:time];
		case FxGripOSCPathActiveSegment:
			return [self translateBy:objectDelta atTime:time];
		case FxGripOSCPathActiveNone:
		default:
			return NO;
	}
}

- (BOOL)translateBy:(CGPoint)objectDelta atTime:(CMTime)time
{
	if (self.usesCustomData) {
		FxGripPathData *data = [self pathDataAtTime:time];
		if (data == nil) {
			return NO;
		}
		return [self.control setCustomValue:[data byTranslatingBy:objectDelta]
							   toParameter:self.pathParameterID
									atTime:time];
	}
	NSUInteger count = self.locationParameterIDs.count;
	BOOL moved = count > 0;
	for (NSUInteger index = 0; index < count; index++) {
		CGPoint location = CGPointZero;
		FxParameterId parameterID = (FxParameterId)self.locationParameterIDs[index].unsignedIntValue;
		if (![self.control getObjectPoint:&location fromParameter:parameterID atTime:time]) {
			return NO;
		}
		location.x += objectDelta.x;
		location.y += objectDelta.y;
		moved = [self.control setObjectPoint:location toParameter:parameterID atTime:time] && moved;
	}
	return moved;
}

- (CGPoint)locationAtIndex:(NSUInteger)index atTime:(CMTime)time
{
	if (self.usesCustomData) {
		return [[self pathDataAtTime:time] locationAtIndex:index];
	}
	CGPoint location = CGPointZero;
	if (index < self.locationParameterIDs.count) {
		[self.control getObjectPoint:&location
					  fromParameter:(FxParameterId)self.locationParameterIDs[index].unsignedIntValue
							 atTime:time];
	}
	return location;
}

- (CGPoint)tangentVectorAtIndex:(NSUInteger)index isOutgoing:(BOOL)isOutgoing atTime:(CMTime)time
{
	if (self.usesCustomData) {
		FxVertex vertex = [[self pathDataAtTime:time] vertexAtIndex:index];
		return isOutgoing ? vertex.outTangent : vertex.inTangent;
	}
	return [self vectorFromParameters:(isOutgoing ? self.outTangentParameterIDs : self.inTangentParameterIDs)
							   index:index
							  atTime:time];
}

- (BOOL)dragTangentAtIndex:(NSUInteger)index
				isOutgoing:(BOOL)isOutgoing
			 toObjectPoint:(CGPoint)objectPoint
				 modifiers:(FxModifierKeys)modifiers
					atTime:(CMTime)time
{
	CGPoint location = [self locationAtIndex:index atTime:time];
	NSSize inputSize = FxGripOSCPathInputSize(self.control);

	// Command holds the tangent retracted on its vertex, making that side linear.
	if ([FxGripEventModifiers isDeleteClickForFxModifiers:modifiers]) {
		return [self writeTangentAtIndex:index isOutgoing:isOutgoing objectVector:CGPointZero atTime:time];
	}

	CGPoint vector = CGPointMake(objectPoint.x - location.x, objectPoint.y - location.y);

	// Shift snaps the handle's angle about the vertex to 45° increments, keeping its length.
	if ([FxGripEventModifiers isConstrainForFxModifiers:modifiers]) {
		CGPoint pixel = FxGripOSCPathToPixels(vector, inputSize);
		double length = hypot(pixel.x, pixel.y);
		if (length >= 1e-9) {
			double snapped = round(atan2(pixel.y, pixel.x) / M_PI_4) * M_PI_4;
			vector = FxGripOSCPathToObject(CGPointMake(cos(snapped) * length, sin(snapped) * length), inputSize);
		}
	}

	BOOL wrote = [self writeTangentAtIndex:index isOutgoing:isOutgoing objectVector:vector atTime:time];
	// Option breaks the pair; otherwise the opposite tangent rotates to stay collinear, keeping
	// its own length (aligned mirroring, in the input-pixel frame).
	if (!wrote || (modifiers & kFxModifierKey_OPTION)) {
		return wrote;
	}
	CGPoint dragged = FxGripOSCPathToPixels(vector, inputSize);
	double draggedLength = hypot(dragged.x, dragged.y);
	if (draggedLength < 1e-9) {
		return wrote;
	}
	CGPoint opposite = FxGripOSCPathToPixels([self tangentVectorAtIndex:index isOutgoing:!isOutgoing atTime:time], inputSize);
	double oppositeLength = hypot(opposite.x, opposite.y);
	if (oppositeLength < 1e-9) {
		return wrote;
	}
	CGPoint mirrored = FxGripOSCPathToObject(CGPointMake(-dragged.x / draggedLength * oppositeLength,
														 -dragged.y / draggedLength * oppositeLength), inputSize);
	return [self writeTangentAtIndex:index isOutgoing:!isOutgoing objectVector:mirrored atTime:time] && wrote;
}


#pragma mark Editing

- (BOOL)insertVertexAtObjectPoint:(CGPoint)objectPoint atTime:(CMTime)time
{
	FxGripPathData *data = [self pathDataAtTime:time];
	NSUInteger count = data.vertexCount;
	if (count < 2) {
		return NO;
	}
	// Insert at the nearest segment's projection, so the vertex lands on the path.
	NSUInteger bestSegment = 0;
	double bestDistance = INFINITY;
	CGPoint bestPoint = objectPoint;
	NSUInteger segmentCount = data.closed ? count : count - 1;
	for (NSUInteger segment = 0; segment < segmentCount; segment++) {
		CGPoint a = [data locationAtIndex:segment];
		CGPoint b = [data locationAtIndex:(segment + 1) % count];
		CGPoint ab = CGPointMake(b.x - a.x, b.y - a.y);
		double lengthSquared = ab.x * ab.x + ab.y * ab.y;
		double t = 0.5;
		if (lengthSquared > 0.0) {
			t = ((objectPoint.x - a.x) * ab.x + (objectPoint.y - a.y) * ab.y) / lengthSquared;
			t = t < 0.0 ? 0.0 : (t > 1.0 ? 1.0 : t);
		}
		CGPoint projected = CGPointMake(a.x + t * ab.x, a.y + t * ab.y);
		double distance = hypot(objectPoint.x - projected.x, objectPoint.y - projected.y);
		if (distance < bestDistance) {
			bestDistance = distance;
			bestSegment = segment;
			bestPoint = projected;
		}
	}
	FxVertex vertex = { 0 };
	vertex.location = bestPoint;
	vertex.interpStyle = kFxPathStyle_Linear;
	NSUInteger insertIndex = bestSegment + 1;
	if (![self.control setCustomValue:[data byInsertingVertex:vertex atIndex:insertIndex]
						  toParameter:self.pathParameterID
							   atTime:time]) {
		return NO;
	}
	_selectedVertexIndex = (NSInteger)insertIndex;
	return YES;
}

- (BOOL)removeSelectedVertexAtTime:(CMTime)time
{
	if (_selectedVertexIndex < 0 || !self.usesCustomData) {
		return NO;
	}
	FxGripPathData *data = [self pathDataAtTime:time];
	if (data == nil || (NSUInteger)_selectedVertexIndex >= data.vertexCount
		|| data.vertexCount <= self.minimumVertexCount) {
		return NO;
	}
	FxGripPathData *edited = [data byRemovingVertexAtIndex:(NSUInteger)_selectedVertexIndex];
	_selectedVertexIndex = -1;
	return [self.control setCustomValue:edited toParameter:self.pathParameterID atTime:time];
}

/*! Toggles a vertex between corner (linear, retracted tangents) and smooth (Bézier). */
- (BOOL)toggleVertexStyleAtIndex:(NSUInteger)index atTime:(CMTime)time
{
	NSUInteger vertexCount = 0;
	BOOL closed = NO;
	FxVertex *vertices = [self readVertices:&vertexCount closed:&closed atTime:time];
	if (vertices == NULL || index >= vertexCount) {
		free(vertices);
		return NO;
	}
	FxVertex vertex = vertices[index];
	BOOL corner = vertex.interpStyle != kFxPathStyle_Bezier
		|| (hypot(vertex.inTangent.x, vertex.inTangent.y) <= kFxGripOSCPathTangentRetractedEpsilon
			&& hypot(vertex.outTangent.x, vertex.outTangent.y) <= kFxGripOSCPathTangentRetractedEpsilon);

	BOOL result = NO;
	if (corner) {
		// Regenerate smooth tangents along the neighbor axis, a sixth of that span.
		NSSize inputSize = FxGripOSCPathInputSize(self.control);
		CGPoint previous = closed ? vertices[(index + vertexCount - 1) % vertexCount].location
								  : (index > 0 ? vertices[index - 1].location : vertex.location);
		CGPoint next = closed ? vertices[(index + 1) % vertexCount].location
							  : (index + 1 < vertexCount ? vertices[index + 1].location : vertex.location);
		CGPoint axis = FxGripOSCPathToPixels(CGPointMake(next.x - previous.x, next.y - previous.y), inputSize);
		double length = hypot(axis.x, axis.y);
		result = [self writeStyleAtIndex:index toStyle:kFxPathStyle_Bezier atTime:time];
		if (length >= 1e-9) {
			CGPoint offset = FxGripOSCPathToObject(CGPointMake(axis.x / 6.0, axis.y / 6.0), inputSize);
			result = [self writeTangentAtIndex:index isOutgoing:YES objectVector:offset atTime:time] && result;
			result = [self writeTangentAtIndex:index isOutgoing:NO
								  objectVector:CGPointMake(-offset.x, -offset.y) atTime:time] && result;
		}
	} else {
		result = [self writeStyleAtIndex:index toStyle:kFxPathStyle_Linear atTime:time];
		result = [self writeTangentAtIndex:index isOutgoing:YES objectVector:CGPointZero atTime:time] && result;
		result = [self writeTangentAtIndex:index isOutgoing:NO objectVector:CGPointZero atTime:time] && result;
	}
	free(vertices);
	return result;
}


#pragma mark Drawing

- (void)strokeCanvasPoints:(const CGPoint *)points
					 count:(NSUInteger)count
					closed:(BOOL)closed
				canvasSize:(CGSize)canvasSize
			commandEncoder:(id<MTLRenderCommandEncoder>)commandEncoder
{
	[self.control strokeCanvasPoints:points
							   count:count
							  closed:closed
							   color:self.color
						  withShadow:YES
						  canvasSize:canvasSize
					  commandEncoder:commandEncoder];
}

- (void)drawSelected:(BOOL)selected
		  canvasSize:(CGSize)canvasSize
	  commandEncoder:(nonnull id<MTLRenderCommandEncoder>)commandEncoder
			  atTime:(CMTime)time
{
	NSUInteger flatCount = 0;
	CGPoint *stroke = [self flattenedCanvasPointsWithCount:&flatCount atTime:time];
	if (stroke != NULL) {
		[self strokeCanvasPoints:stroke count:flatCount closed:NO canvasSize:canvasSize commandEncoder:commandEncoder];
		free(stroke);
	}

	NSUInteger vertexCount = 0;
	BOOL closed = NO;
	FxVertex *vertices = [self readVertices:&vertexCount closed:&closed atTime:time];
	if (vertices == NULL) {
		return;
	}

	if (self.options & FxGripOSCPathOptionTangentHandles) {
		for (NSUInteger index = 0; index < vertexCount; index++) {
			if (!FxGripOSCPathStyleHasTangents(vertices[index].interpStyle)) {
				continue;
			}
			CGPoint canvasVertex = [self.control canvasPointFromObjectPoint:vertices[index].location];
			[self drawTangentTip:vertices[index].inTangent fromVertex:vertices[index].location
					 canvasVertex:canvasVertex canvasSize:canvasSize commandEncoder:commandEncoder];
			[self drawTangentTip:vertices[index].outTangent fromVertex:vertices[index].location
					 canvasVertex:canvasVertex canvasSize:canvasSize commandEncoder:commandEncoder];
		}
	}

	if (self.options & FxGripOSCPathOptionVertexHandles) {
		for (NSUInteger index = 0; index < vertexCount; index++) {
			CGPoint canvasVertex = [self.control canvasPointFromObjectPoint:vertices[index].location];
			[self fxDrawHandleAtCanvasPoint:canvasVertex
								   halfSide:self.handleRadius
								   selected:((NSInteger)index == _selectedVertexIndex)
								 canvasSize:canvasSize
							 commandEncoder:commandEncoder];
		}
	}
	free(vertices);
}

- (void)drawTangentTip:(CGPoint)tangentVector
			fromVertex:(CGPoint)location
		  canvasVertex:(CGPoint)canvasVertex
			canvasSize:(CGSize)canvasSize
		commandEncoder:(id<MTLRenderCommandEncoder>)commandEncoder
{
	if (hypot(tangentVector.x, tangentVector.y) <= kFxGripOSCPathTangentRetractedEpsilon) {
		return;
	}
	CGPoint tip = [self.control canvasPointFromObjectPoint:CGPointMake(location.x + tangentVector.x,
																	   location.y + tangentVector.y)];
	CGPoint stem[2] = { canvasVertex, tip };
	[self strokeCanvasPoints:stem count:2 closed:NO canvasSize:canvasSize commandEncoder:commandEncoder];
	[self fxDrawHandleAtCanvasPoint:tip halfSide:self.handleRadius selected:NO
						 canvasSize:canvasSize commandEncoder:commandEncoder];
}

@end
