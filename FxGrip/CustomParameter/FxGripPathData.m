/*!
	@file       FxGripPathData.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripPathData
	@abstract   Implements the immutable FxVertex path list.
	@discussion Introduced in FxGrip 0.1.0. The vertices store as one flat array of NSNumber, eight
	            interleaved values per vertex. Edit methods copy the array, apply one change, and return
	            a new instance. The archive carries a version, the closed flag, and the interleaved array.
*/

#import "FxGripPathData.h"
#import "FxGrip_ARC.h"

// One vertex occupies this many interleaved slots: location.x/y, inTangent.x/y,
// outTangent.x/y, xSplineWeight, interpStyle.
static const NSUInteger kFxGripPathVertexStride = 8;

static const NSInteger kFxGripPathDataCoderVersion = 1;
static NSString *const kFxGripPathDataKey_Version = @"version";
static NSString *const kFxGripPathDataKey_Vertices = @"vertices";
static NSString *const kFxGripPathDataKey_Closed = @"closed";

/*! Appends one vertex's eight interleaved values, in field order. */
static void FxGripPathAppendVertex(NSMutableArray<NSNumber *> *slots, FxVertex vertex)
{
	[slots addObject:@(vertex.location.x)];
	[slots addObject:@(vertex.location.y)];
	[slots addObject:@(vertex.inTangent.x)];
	[slots addObject:@(vertex.inTangent.y)];
	[slots addObject:@(vertex.outTangent.x)];
	[slots addObject:@(vertex.outTangent.y)];
	[slots addObject:@(vertex.xSplineWeight)];
	[slots addObject:@(vertex.interpStyle)];
}

/*!
	@abstract	The immutable FxVertex path list.
	@discussion	Introduced in FxGrip 0.1.0. Vertices store as a flat interleaved NSNumber array, eight
				values per vertex. Edits return new instances.
*/
@implementation FxGripPathData
{
	NSArray<NSNumber *> *_interleaved;	// eight values per vertex, in list order
}

@synthesize closed = _closed;

+ (BOOL)supportsSecureCoding
{
	return YES;
}

- (void)dealloc
{
	NARC_RELEASE(_interleaved);
	SUPER_DEALLOC();
}

/*! @abstract The designated initializer; keeps a copy of the interleaved value array. */
- (nullable instancetype)initWithInterleaved:(NSArray<NSNumber *> *)interleaved closed:(BOOL)closed
{
	self = [super init];
	if (self != nil) {
		_closed = closed;
		_interleaved = [interleaved copy];
	}
	return self;
}

- (nullable instancetype)initWithVertices:(const FxVertex *)vertices count:(NSUInteger)count closed:(BOOL)closed
{
	if (vertices == NULL && count > 0) {
		NARC_RELEASE_RAW(self);
		return nil;
	}
	NSMutableArray<NSNumber *> *interleaved = [NSMutableArray arrayWithCapacity:count * kFxGripPathVertexStride];
	for (NSUInteger index = 0; index < count; index++) {
		FxGripPathAppendVertex(interleaved, vertices[index]);
	}
	return [self initWithInterleaved:interleaved closed:closed];
}

+ (instancetype)emptyPathClosed:(BOOL)closed
{
	return [self pathWithVertices:NULL count:0 closed:closed];
}

+ (instancetype)pathWithVertices:(nullable const FxVertex *)vertices
						   count:(NSUInteger)count
						  closed:(BOOL)closed
{
	return NARC_AUTORELEASE([[self alloc] initWithVertices:vertices count:count closed:closed]);
}

+ (instancetype)pathWithLocations:(nullable const CGPoint *)locations
							count:(NSUInteger)count
						   closed:(BOOL)closed
{
	if (locations == NULL && count > 0) {
		return nil;
	}
	NSMutableArray<NSNumber *> *interleaved = [NSMutableArray arrayWithCapacity:count * kFxGripPathVertexStride];
	for (NSUInteger index = 0; index < count; index++) {
		FxVertex vertex = { 0 };
		vertex.location = locations[index];
		vertex.interpStyle = kFxPathStyle_Linear;
		FxGripPathAppendVertex(interleaved, vertex);
	}
	return NARC_AUTORELEASE([[self alloc] initWithInterleaved:interleaved closed:closed]);
}

- (NSUInteger)vertexCount
{
	return _interleaved.count / kFxGripPathVertexStride;
}

/*! @abstract Reads back the vertex at an index, or a zeroed linear vertex when out of range. */
- (FxVertex)vertexAtIndex:(NSUInteger)index
{
	FxVertex vertex = { 0 };
	vertex.interpStyle = kFxPathStyle_Linear;
	if (index >= self.vertexCount) {
		return vertex;
	}
	NSUInteger base = index * kFxGripPathVertexStride;
	vertex.location = CGPointMake(_interleaved[base + 0].doubleValue, _interleaved[base + 1].doubleValue);
	vertex.inTangent = CGPointMake(_interleaved[base + 2].doubleValue, _interleaved[base + 3].doubleValue);
	vertex.outTangent = CGPointMake(_interleaved[base + 4].doubleValue, _interleaved[base + 5].doubleValue);
	vertex.xSplineWeight = _interleaved[base + 6].doubleValue;
	vertex.interpStyle = (FxPathStyle)_interleaved[base + 7].unsignedIntegerValue;
	return vertex;
}

- (CGPoint)locationAtIndex:(NSUInteger)index
{
	if (index >= self.vertexCount) {
		return CGPointZero;
	}
	NSUInteger base = index * kFxGripPathVertexStride;
	return CGPointMake(_interleaved[base + 0].doubleValue, _interleaved[base + 1].doubleValue);
}

- (instancetype)byInsertingVertex:(FxVertex)vertex atIndex:(NSUInteger)index
{
	NSUInteger clamped = MIN(index, self.vertexCount);
	NSMutableArray<NSNumber *> *edited = [_interleaved mutableCopy];
	NSMutableArray<NSNumber *> *inserted = [NSMutableArray arrayWithCapacity:kFxGripPathVertexStride];
	FxGripPathAppendVertex(inserted, vertex);
	NSIndexSet *positions = [NSIndexSet indexSetWithIndexesInRange:
							 NSMakeRange(clamped * kFxGripPathVertexStride, kFxGripPathVertexStride)];
	[edited insertObjects:inserted atIndexes:positions];
	FxGripPathData *result = [[FxGripPathData alloc] initWithInterleaved:edited closed:_closed];
	NARC_RELEASE(edited);
	return NARC_AUTORELEASE(result);
}

- (instancetype)byRemovingVertexAtIndex:(NSUInteger)index
{
	if (index >= self.vertexCount) {
		return self;
	}
	NSMutableArray<NSNumber *> *edited = [_interleaved mutableCopy];
	[edited removeObjectsInRange:NSMakeRange(index * kFxGripPathVertexStride, kFxGripPathVertexStride)];
	FxGripPathData *result = [[FxGripPathData alloc] initWithInterleaved:edited closed:_closed];
	NARC_RELEASE(edited);
	return NARC_AUTORELEASE(result);
}

- (instancetype)byReplacingVertexAtIndex:(NSUInteger)index withVertex:(FxVertex)vertex
{
	if (index >= self.vertexCount) {
		return self;
	}
	NSMutableArray<NSNumber *> *replacement = [NSMutableArray arrayWithCapacity:kFxGripPathVertexStride];
	FxGripPathAppendVertex(replacement, vertex);
	NSMutableArray<NSNumber *> *edited = [_interleaved mutableCopy];
	[edited replaceObjectsInRange:NSMakeRange(index * kFxGripPathVertexStride, kFxGripPathVertexStride)
			 withObjectsFromArray:replacement];
	FxGripPathData *result = [[FxGripPathData alloc] initWithInterleaved:edited closed:_closed];
	NARC_RELEASE(edited);
	return NARC_AUTORELEASE(result);
}

- (instancetype)byReplacingLocationAtIndex:(NSUInteger)index withLocation:(CGPoint)location
{
	if (index >= self.vertexCount) {
		return self;
	}
	NSUInteger base = index * kFxGripPathVertexStride;
	NSMutableArray<NSNumber *> *edited = [_interleaved mutableCopy];
	edited[base + 0] = @(location.x);
	edited[base + 1] = @(location.y);
	FxGripPathData *result = [[FxGripPathData alloc] initWithInterleaved:edited closed:_closed];
	NARC_RELEASE(edited);
	return NARC_AUTORELEASE(result);
}

- (instancetype)byTranslatingBy:(CGPoint)delta
{
	NSMutableArray<NSNumber *> *edited = [_interleaved mutableCopy];
	NSUInteger count = self.vertexCount;
	for (NSUInteger index = 0; index < count; index++) {
		NSUInteger base = index * kFxGripPathVertexStride;
		edited[base + 0] = @(_interleaved[base + 0].doubleValue + delta.x);
		edited[base + 1] = @(_interleaved[base + 1].doubleValue + delta.y);
	}
	FxGripPathData *result = [[FxGripPathData alloc] initWithInterleaved:edited closed:_closed];
	NARC_RELEASE(edited);
	return NARC_AUTORELEASE(result);
}

/*! @abstract Writes the vertices into a buffer, at most capacity, and returns the number written. */
- (NSUInteger)copyVerticesToBuffer:(FxVertex *)buffer capacity:(NSUInteger)capacity
{
	NSUInteger written = MIN(capacity, self.vertexCount);
	for (NSUInteger index = 0; index < written; index++) {
		buffer[index] = [self vertexAtIndex:index];
	}
	return written;
}

- (BOOL)isEqual:(id)object
{
	if (self == object) {
		return YES;
	}
	if (![object isKindOfClass:FxGripPathData.class]) {
		return NO;
	}
	FxGripPathData *other = object;
	return other->_closed == _closed && [other->_interleaved isEqualToArray:_interleaved];
}

- (NSUInteger)hash
{
	return ((NSUInteger)_closed) ^ _interleaved.hash;
}

- (id)copyWithZone:(NSZone *)zone
{
	// Immutable.
	return NARC_RETAIN(self);
}


#pragma mark NSSecureCoding

- (void)encodeWithCoder:(nonnull NSCoder *)coder
{
	[coder encodeInteger:kFxGripPathDataCoderVersion forKey:kFxGripPathDataKey_Version];
	[coder encodeBool:_closed forKey:kFxGripPathDataKey_Closed];
	[coder encodeObject:_interleaved forKey:kFxGripPathDataKey_Vertices];
}

/*! @abstract Decodes the closed flag and interleaved array, rejecting a length not a multiple of the stride. */
- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder
{
	self = [super init];
	if (self != nil) {
		_closed = [coder decodeBoolForKey:kFxGripPathDataKey_Closed];
		NSSet *classes = [NSSet setWithObjects:NSArray.class, NSNumber.class, nil];
		_interleaved = NARC_RETAIN([coder decodeObjectOfClasses:classes
														 forKey:kFxGripPathDataKey_Vertices]);
		if (![_interleaved isKindOfClass:NSArray.class] || _interleaved.count % kFxGripPathVertexStride != 0) {
			NARC_RELEASE_RAW(self);
			return nil;
		}
	}
	return self;
}

@end
