//
//  FxGripPointListData.m
//  FxGrip
//

#import "FxGripPointListData.h"
#import "FxGrip_ARC.h"

static const NSInteger kFxGripPointListDataCoderVersion = 1;
static NSString *const kFxGripPointListDataKey_Version = @"version";
static NSString *const kFxGripPointListDataKey_Points = @"points";
static NSString *const kFxGripPointListDataKey_Closed = @"closed";

@implementation FxGripPointListData
{
	NSArray<NSNumber *> *_interleaved;	// x0, y0, x1, y1, ... in list order
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

- (nullable instancetype)initWithInterleaved:(NSArray<NSNumber *> *)interleaved closed:(BOOL)closed
{
	self = [super init];
	if (self != nil) {
		_closed = closed;
		_interleaved = [interleaved copy];
	}
	return self;
}

- (nullable instancetype)initWithPoints:(const CGPoint *)points count:(NSUInteger)count closed:(BOOL)closed
{
	if (points == NULL && count > 0) {
		NARC_RELEASE_RAW(self);
		return nil;
	}
	NSMutableArray<NSNumber *> *interleaved = [NSMutableArray arrayWithCapacity:count * 2];
	for (NSUInteger index = 0; index < count; index++) {
		[interleaved addObject:@(points[index].x)];
		[interleaved addObject:@(points[index].y)];
	}
	return [self initWithInterleaved:interleaved closed:closed];
}

+ (instancetype)emptyPointListClosed:(BOOL)closed
{
	return [self pointListWithPoints:NULL count:0 closed:closed];
}

+ (instancetype)pointListWithPoints:(nullable const CGPoint *)points
							  count:(NSUInteger)count
							 closed:(BOOL)closed
{
	return NARC_AUTORELEASE([[self alloc] initWithPoints:points count:count closed:closed]);
}

- (NSUInteger)count
{
	return _interleaved.count / 2;
}

- (CGPoint)pointAtIndex:(NSUInteger)index
{
	if (index >= self.count) {
		return CGPointZero;
	}
	return CGPointMake(_interleaved[index * 2].doubleValue, _interleaved[index * 2 + 1].doubleValue);
}

- (instancetype)byInsertingPoint:(CGPoint)point atIndex:(NSUInteger)index
{
	NSUInteger clamped = MIN(index, self.count);
	NSMutableArray<NSNumber *> *edited = [_interleaved mutableCopy];
	[edited insertObject:@(point.y) atIndex:clamped * 2];
	[edited insertObject:@(point.x) atIndex:clamped * 2];
	FxGripPointListData *result = [[FxGripPointListData alloc] initWithInterleaved:edited closed:_closed];
	NARC_RELEASE(edited);
	return NARC_AUTORELEASE(result);
}

- (instancetype)byRemovingPointAtIndex:(NSUInteger)index
{
	if (index >= self.count) {
		return self;
	}
	NSMutableArray<NSNumber *> *edited = [_interleaved mutableCopy];
	[edited removeObjectsInRange:NSMakeRange(index * 2, 2)];
	FxGripPointListData *result = [[FxGripPointListData alloc] initWithInterleaved:edited closed:_closed];
	NARC_RELEASE(edited);
	return NARC_AUTORELEASE(result);
}

- (instancetype)byReplacingPointAtIndex:(NSUInteger)index withPoint:(CGPoint)point
{
	if (index >= self.count) {
		return self;
	}
	NSMutableArray<NSNumber *> *edited = [_interleaved mutableCopy];
	edited[index * 2] = @(point.x);
	edited[index * 2 + 1] = @(point.y);
	FxGripPointListData *result = [[FxGripPointListData alloc] initWithInterleaved:edited closed:_closed];
	NARC_RELEASE(edited);
	return NARC_AUTORELEASE(result);
}

- (instancetype)byTranslatingBy:(CGPoint)delta
{
	NSMutableArray<NSNumber *> *edited = [NSMutableArray arrayWithCapacity:_interleaved.count];
	NSUInteger pointCount = self.count;
	for (NSUInteger index = 0; index < pointCount; index++) {
		[edited addObject:@(_interleaved[index * 2].doubleValue + delta.x)];
		[edited addObject:@(_interleaved[index * 2 + 1].doubleValue + delta.y)];
	}
	FxGripPointListData *result = [[FxGripPointListData alloc] initWithInterleaved:edited closed:_closed];
	return NARC_AUTORELEASE(result);
}

- (NSUInteger)copyPointsToBuffer:(CGPoint *)buffer capacity:(NSUInteger)capacity
{
	NSUInteger written = MIN(capacity, self.count);
	for (NSUInteger index = 0; index < written; index++) {
		buffer[index] = [self pointAtIndex:index];
	}
	return written;
}

- (BOOL)isEqual:(id)object
{
	if (self == object) {
		return YES;
	}
	if (![object isKindOfClass:FxGripPointListData.class]) {
		return NO;
	}
	FxGripPointListData *other = object;
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
	[coder encodeInteger:kFxGripPointListDataCoderVersion forKey:kFxGripPointListDataKey_Version];
	[coder encodeBool:_closed forKey:kFxGripPointListDataKey_Closed];
	[coder encodeObject:_interleaved forKey:kFxGripPointListDataKey_Points];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder
{
	self = [super init];
	if (self != nil) {
		_closed = [coder decodeBoolForKey:kFxGripPointListDataKey_Closed];
		NSSet *classes = [NSSet setWithObjects:NSArray.class, NSNumber.class, nil];
		_interleaved = NARC_RETAIN([coder decodeObjectOfClasses:classes
														 forKey:kFxGripPointListDataKey_Points]);
		if (![_interleaved isKindOfClass:NSArray.class] || _interleaved.count % 2 != 0) {
			NARC_RELEASE_RAW(self);
			return nil;
		}
	}
	return self;
}

@end
