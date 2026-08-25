//
//  FxGripCurveData.m
//  FxGrip
//

#import "FxGripCurveData.h"
#import "FxGrip_ARC.h"

#define kFxGripCurveDataCoderVersion	1

static NSString *const kFxGripCurveDataKey_Version	= @"version";
static NSString *const kFxGripCurveDataKey_Domain	= @"domain";
static NSString *const kFxGripCurveDataKey_Role		= @"role";
static NSString *const kFxGripCurveDataKey_Points	= @"points";

/*! The flat neutral output for a role; the remap role has none (its neutral is the
	diagonal). */
static double FxGripCurveRoleNeutralY(FxGripCurveRole role)
{
	switch (role) {
		case FxGripCurveRoleShift:
		case FxGripCurveRoleMultiplierHalf:
			return 0.5;
		case FxGripCurveRoleMultiplierOne:
			return 1.0;
		default:
			return 0.0;
	}
}

static double FxGripCurveClamp01(double value)
{
	return value < 0.0 ? 0.0 : (value > 1.0 ? 1.0 : value);
}


@implementation FxGripCurveData
{
	NSArray<NSNumber*> *_interleaved;	// x0, y0, x1, y1, ... sorted by x
}

+ (BOOL)supportsSecureCoding
{
	return YES;
}

- (void)dealloc
{
	NARC_RELEASE(_interleaved);
	SUPER_DEALLOC();
}

/*! Sanitizes, sorts, and dedupes into the interleaved storage. */
- (nullable instancetype)initWithPoints:(const CGPoint *)points
								  count:(NSUInteger)count
								   role:(FxGripCurveRole)role
								 domain:(FxGripCurveDomain)domain
{
	if (points == NULL && count > 0) {
		NARC_RELEASE_RAW(self);
		return nil;
	}
	self = [super init];
	if (self != nil) {
		_role = role;
		_domain = domain;

		NSMutableArray<NSValue*> *sanitized = [NSMutableArray arrayWithCapacity:count];
		for (NSUInteger index = 0; index < count; index++) {
			double x = points[index].x;
			if (domain == FxGripCurveDomainCircular) {
				// x = 1.0 stays: it is the closed-loop endpoint, and folding it onto
				// x = 0 would collapse a flat two-point neutral to one point, which the
				// builder reads as "no curve" (identity ramp) instead of a constant.
				if (x != 1.0) {
					x -= floor(x);
				}
			} else {
				x = FxGripCurveClamp01(x);
			}
			double y = FxGripCurveClamp01(points[index].y);
			[sanitized addObject:[NSValue valueWithPoint:NSMakePoint(x, y)]];
		}
		[sanitized sortUsingComparator:^NSComparisonResult(NSValue *a, NSValue *b) {
			double xa = a.pointValue.x, xb = b.pointValue.x;
			if (xa < xb) {
				return NSOrderedAscending;
			}
			return xa > xb ? NSOrderedDescending : NSOrderedSame;
		}];

		NSMutableArray<NSNumber*> *interleaved = [NSMutableArray arrayWithCapacity:count * 2];
		double previousX = -1.0;
		for (NSValue *value in sanitized) {
			NSPoint point = value.pointValue;
			// Duplicate x drops, first wins, matching the LUT builder.
			if (interleaved.count > 0 && point.x <= previousX + 1e-9) {
				continue;
			}
			[interleaved addObject:@(point.x)];
			[interleaved addObject:@(point.y)];
			previousX = point.x;
		}
		_interleaved = [interleaved copy];
	}
	return self;
}

+ (nullable instancetype)curveWithPoints:(const CGPoint *)points
								   count:(NSUInteger)count
									role:(FxGripCurveRole)role
								  domain:(FxGripCurveDomain)domain
{
	return NARC_AUTORELEASE([[self alloc] initWithPoints:points count:count role:role domain:domain]);
}

+ (nonnull instancetype)identityCurveWithRole:(FxGripCurveRole)role
									   domain:(FxGripCurveDomain)domain
{
	if (role == FxGripCurveRoleRemap) {
		if (domain == FxGripCurveDomainCircular) {
			// The diagonal cannot close on the circle (the builder folds (1,1) onto
			// (0,0), a constant). The builder's no-points identity ramp is the circular
			// remap neutral, matching Metal Forge's reset-channel semantics.
			return [self curveWithPoints:NULL count:0 role:role domain:domain];
		}
		CGPoint diagonal[2] = {CGPointMake(0.0, 0.0), CGPointMake(1.0, 1.0)};
		return [self curveWithPoints:diagonal count:2 role:role domain:domain];
	}
	double neutralY = FxGripCurveRoleNeutralY(role);
	CGPoint flat[2] = {CGPointMake(0.0, neutralY), CGPointMake(1.0, neutralY)};
	return [self curveWithPoints:flat count:2 role:role domain:domain];
}

- (NSUInteger)pointCount
{
	return _interleaved.count / 2;
}

- (CGPoint)pointAtIndex:(NSUInteger)index
{
	if (index >= self.pointCount) {
		return CGPointZero;
	}
	return CGPointMake(_interleaved[index * 2].doubleValue,
					   _interleaved[index * 2 + 1].doubleValue);
}

- (BOOL)isIdentity
{
	FxGripCurveData *identity = [FxGripCurveData identityCurveWithRole:_role domain:_domain];
	if (self.pointCount != identity.pointCount) {
		return NO;
	}
	for (NSUInteger index = 0; index < self.pointCount; index++) {
		CGPoint mine = [self pointAtIndex:index];
		CGPoint theirs = [identity pointAtIndex:index];
		if (fabs(mine.x - theirs.x) > 1e-9 || fabs(mine.y - theirs.y) > 1e-9) {
			return NO;
		}
	}
	return YES;
}

- (NSUInteger)copyCurvePointsFloat2:(float (*)[2])buffer capacity:(NSUInteger)capacity
{
	if (buffer == NULL) {
		return 0;
	}
	NSUInteger written = MIN(self.pointCount, capacity);
	for (NSUInteger index = 0; index < written; index++) {
		buffer[index][0] = (float)_interleaved[index * 2].doubleValue;
		buffer[index][1] = (float)_interleaved[index * 2 + 1].doubleValue;
	}
	return written;
}

- (void)buildLUT:(float *)outLUT count:(NSUInteger)n
{
	if (outLUT == NULL || n == 0) {
		return;
	}
	NSUInteger count = self.pointCount;
	float (*points)[2] = count > 0 ? malloc(count * sizeof(*points)) : NULL;
	count = [self copyCurvePointsFloat2:points capacity:count];
	if (_domain == FxGripCurveDomainCircular) {
		FxGripBuildCurveLUTPeriodic(points, count, outLUT, (int)n);
	} else {
		FxGripBuildCurveLUT(points, count, outLUT, (int)n);
	}
	free(points);
}


#pragma mark Identity

- (BOOL)isEqual:(id)object
{
	if (self == object) {
		return YES;
	}
	if (![object isKindOfClass:FxGripCurveData.class]) {
		return NO;
	}
	FxGripCurveData *rhs = object;
	return _domain == rhs.domain && _role == rhs.role
		&& [_interleaved isEqualToArray:rhs->_interleaved];
}

- (NSUInteger)hash
{
	return ((NSUInteger)_domain << 8) ^ ((NSUInteger)_role << 12) ^ _interleaved.hash;
}

- (id)copyWithZone:(NSZone *)zone
{
	// Immutable.
	return NARC_RETAIN(self);
}


#pragma mark NSSecureCoding

- (void)encodeWithCoder:(nonnull NSCoder *)coder
{
	[coder encodeInteger:kFxGripCurveDataCoderVersion forKey:kFxGripCurveDataKey_Version];
	[coder encodeInteger:_domain forKey:kFxGripCurveDataKey_Domain];
	[coder encodeInteger:_role forKey:kFxGripCurveDataKey_Role];
	[coder encodeObject:_interleaved forKey:kFxGripCurveDataKey_Points];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder
{
	self = [super init];
	if (self != nil) {
		_domain = [coder decodeIntegerForKey:kFxGripCurveDataKey_Domain];
		_role = [coder decodeIntegerForKey:kFxGripCurveDataKey_Role];
		NSSet *classes = [NSSet setWithObjects:NSArray.class, NSNumber.class, nil];
		_interleaved = NARC_RETAIN([coder decodeObjectOfClasses:classes
														 forKey:kFxGripCurveDataKey_Points]);
		if (![_interleaved isKindOfClass:NSArray.class] || _interleaved.count % 2 != 0) {
			NARC_RELEASE_RAW(self);
			return nil;
		}
	}
	return self;
}

@end
