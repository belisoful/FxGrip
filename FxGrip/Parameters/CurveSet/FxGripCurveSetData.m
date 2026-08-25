//
//  FxGripCurveSetData.m
//  FxGrip
//

#import "FxGripCurveSetData.h"
#import "FxGrip_ARC.h"

// The grid the mismatched-curve blend samples on; odd, so x = 0.5 is a sample.
#define kFxGripCurveBlendSampleCount	33

@implementation FxGripCurveSetData

+ (NSOrderedSet<Class>*)classesForParameter
{
	NSMutableOrderedSet *classes = [[super classesForParameter] mutableCopy];
	[classes addObject:FxGripCurveData.class];
	return NARC_AUTORELEASE(classes);
}

// The secure unarchiver requires every concrete class to answer classForCoder itself;
// an inherited override fails the possibly-altered-archive check.
- (Class)classForCoder
{
	return self.class;
}


#pragma mark Curves

- (nullable FxGripCurveData *)curveForKey:(nonnull NSString *)key
{
	id stored = [self objectForKey:key];
	return [stored isKindOfClass:FxGripCurveData.class] ? stored : nil;
}

- (void)setCurve:(nullable FxGripCurveData *)curve forKey:(nonnull NSString *)key
{
	if (key == nil) {
		return;
	}
	if (curve == nil || curve.isIdentity) {
		[self removeObjectForKey:key];
		return;
	}
	[self setObject:curve forKey:key];
}

- (void)removeCurveForKey:(nonnull NSString *)key
{
	if (key != nil) {
		[self removeObjectForKey:key];
	}
}

- (nonnull NSArray<NSString *> *)curveKeys
{
	NSMutableArray *keys = [NSMutableArray array];
	for (id key in self.allKeys) {
		if ([key isKindOfClass:NSString.class]
			&& [[self objectForKey:key] isKindOfClass:FxGripCurveData.class]) {
			[keys addObject:key];
		}
	}
	[keys sortUsingSelector:@selector(compare:)];
	return keys;
}


#pragma mark Keyframe interpolation

/*! An absent key means neutral, so a curve stored on only one side blends toward the
	role's identity instead of dropping (the base blends left keys against right values
	and discards a class mismatch, which a nil right is). */
- (NSObject<NSSecureCoding, NSCopying>*)interpolateBetween:(NSObject<NSSecureCoding, NSCopying>*)rightValue
												withWeight:(float)weight
{
	NSObject<NSSecureCoding, NSCopying> *blended = [super interpolateBetween:rightValue withWeight:weight];
	if (![rightValue isKindOfClass:FxGripCurveSetData.class]
		|| ![blended isKindOfClass:FxGripCurveSetData.class]) {
		return blended;
	}
	FxGripCurveSetData *result = (FxGripCurveSetData*)blended;
	FxGripCurveSetData *right = (FxGripCurveSetData*)rightValue;

	NSMutableSet<NSString*> *keys = [NSMutableSet setWithArray:self.curveKeys];
	[keys addObjectsFromArray:right.curveKeys];
	for (NSString *key in keys) {
		FxGripCurveData *leftCurve = [self curveForKey:key];
		FxGripCurveData *rightCurve = [right curveForKey:key];
		if (leftCurve != nil && rightCurve != nil) {
			continue;
		}
		FxGripCurveData *present = leftCurve ?: rightCurve;
		FxGripCurveData *identity = [FxGripCurveData identityCurveWithRole:present.role
																	domain:present.domain];
		id interpolated = [self customInterpolateValue:(leftCurve ?: identity)
											rightValue:(rightCurve ?: identity)
												  path:key
											withWeight:weight];
		if ([interpolated isKindOfClass:FxGripCurveData.class]) {
			[result setCurve:interpolated forKey:key];
		}
	}
	return result;
}

/*! Blends two curves through their evaluated shapes: both build a LUT on the sample
	grid, the samples lerp, and the samples become the blended curve's points. Exact
	when the shapes agree; well-defined for any point-count mismatch. */
static FxGripCurveData *FxGripCurveGridBlend(FxGripCurveData *left, FxGripCurveData *right, float weight)
{
	float leftLUT[kFxGripCurveBlendSampleCount];
	float rightLUT[kFxGripCurveBlendSampleCount];
	[left buildLUT:leftLUT count:kFxGripCurveBlendSampleCount];
	[right buildLUT:rightLUT count:kFxGripCurveBlendSampleCount];

	CGPoint points[kFxGripCurveBlendSampleCount];
	for (NSUInteger index = 0; index < kFxGripCurveBlendSampleCount; index++) {
		double x = (double)index / (double)(kFxGripCurveBlendSampleCount - 1);
		double y = (1.0 - weight) * leftLUT[index] + weight * rightLUT[index];
		points[index] = CGPointMake(x, y);
	}
	return [FxGripCurveData curveWithPoints:points
									  count:kFxGripCurveBlendSampleCount
									   role:left.role
									 domain:left.domain];
}

- (id)customInterpolateValue:(id)left rightValue:(id)right path:(NSString*)path withWeight:(float)weight
{
	if (![left isKindOfClass:FxGripCurveData.class] || ![right isKindOfClass:FxGripCurveData.class]) {
		return [super customInterpolateValue:left rightValue:right path:path withWeight:weight];
	}
	FxGripCurveData *leftCurve = left;
	FxGripCurveData *rightCurve = right;

	if (leftCurve.pointCount == rightCurve.pointCount
		&& leftCurve.role == rightCurve.role
		&& leftCurve.domain == rightCurve.domain) {
		NSUInteger count = leftCurve.pointCount;
		CGPoint *points = malloc(count * sizeof(CGPoint));
		for (NSUInteger index = 0; index < count; index++) {
			CGPoint a = [leftCurve pointAtIndex:index];
			CGPoint b = [rightCurve pointAtIndex:index];
			points[index] = CGPointMake((1.0 - weight) * a.x + weight * b.x,
										(1.0 - weight) * a.y + weight * b.y);
		}
		FxGripCurveData *blended = [FxGripCurveData curveWithPoints:points
															  count:count
															   role:leftCurve.role
															 domain:leftCurve.domain];
		free(points);
		return blended;
	}

	return FxGripCurveGridBlend(leftCurve, rightCurve, weight);
}

@end
