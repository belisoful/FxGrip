//
//  FxGripCurveDataTests.m
//  FxGripTests
//
//  Unit tests for the curve value layer: the monotone-cubic LUT builders, the immutable
//  curve model, and the keyed curve set with its keyframe blending.
//
//  The builder tests mirror Metal Forge's testBuildCurveLUTClosedForm and
//  testBuildCurveLUTPeriodicClosedForm case for case, with the same control points, the
//  same expected values, and the same tolerances, so the CPU port is proven numerically
//  identical to the builder the render uses.
//

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripCurveLUT.h>
#import <FxGrip/FxGripCurveData.h>
#import <FxGrip/FxGripCurveSetData.h>

// The oracle's LUT size and its linear LUT sampler.
#define kCurveN 256

// The archive keys FxGripCurveData.m writes.
static NSString *const kCurveKey_Version	= @"version";
static NSString *const kCurveKey_Domain		= @"domain";
static NSString *const kCurveKey_Role		= @"role";
static NSString *const kCurveKey_Points		= @"points";

// The sample count FxGripCurveSetData blends mismatched curves on.
#define kCurveBlendSampleCount 33

static float FxGripTestSampleLUT(const float *lut, int n, float x)
{
	float c = (x < 0 ? 0 : (x > 1 ? 1 : x)) * (n - 1);
	int i0 = (int)floorf(c);
	int i1 = (i0 + 1 < n) ? (i0 + 1) : (n - 1);
	float f = c - i0;
	return lut[i0] + (lut[i1] - lut[i0]) * f;
}


#pragma mark - Builders

@interface FxGripCurveLUTTests : XCTestCase
@end

@implementation FxGripCurveLUTTests

/*! Mirrors Metal Forge's testBuildCurveLUTClosedForm: same control sets, same expected
	values, same tolerances. */
- (void)testTheClampedBuilderMatchesTheClosedFormOracle
{
	const int n = kCurveN;
	float *lut = calloc(n, sizeof(float));

	// (1) NULL control set is the identity ramp: lut[i] == i/(n-1).
	FxGripBuildCurveLUT(NULL, 0, lut, n);
	for (int i = 0; i < n; i++) {
		XCTAssertEqualWithAccuracy(lut[i], (float)i / (float)(n - 1), 1e-6f, @"NULL -> identity at %d", i);
	}

	// (2) Two endpoints (0,0)->(1,1) reproduce the exact linear ramp.
	const float line[2][2] = {{0, 0}, {1, 1}};
	FxGripBuildCurveLUT(line, 2, lut, n);
	for (int i = 0; i < n; i++) {
		XCTAssertEqualWithAccuracy(lut[i], (float)i / (float)(n - 1), 1e-5f, @"linear ramp at %d", i);
	}

	// (3) Control points that collapse to one distinct x yield a constant field.
	const float dup[2][2] = {{0.5f, 0.3f}, {0.5f, 0.3f}};
	FxGripBuildCurveLUT(dup, 2, lut, n);
	for (int i = 0; i < n; i++) {
		XCTAssertEqualWithAccuracy(lut[i], 0.3f, 1e-5f, @"single distinct node -> constant at %d", i);
	}

	// (4) A monotone non-linear control set stays monotone and in range.
	const float mono[4][2] = {{0, 0.0f}, {0.3f, 0.1f}, {0.6f, 0.15f}, {1, 1.0f}};
	FxGripBuildCurveLUT(mono, 4, lut, n);
	for (int i = 1; i < n; i++) {
		XCTAssertGreaterThanOrEqual(lut[i], lut[i - 1] - 1e-6f, @"PCHIP monotone (no overshoot) at %d", i);
		XCTAssertGreaterThanOrEqual(lut[i], -1e-6f, @"PCHIP in-range lo at %d", i);
		XCTAssertLessThanOrEqual(lut[i], 1.0f + 1e-6f, @"PCHIP in-range hi at %d", i);
	}
	XCTAssertEqualWithAccuracy(lut[0], 0.0f, 1e-5f, @"PCHIP hits first control value");
	XCTAssertEqualWithAccuracy(lut[n - 1], 1.0f, 1e-5f, @"PCHIP hits last control value");

	free(lut);
}

/*! Mirrors Metal Forge's testBuildCurveLUTPeriodicClosedForm. */
- (void)testThePeriodicBuilderMatchesTheClosedFormOracle
{
	const int n = kCurveN;
	float *lut = calloc(n, sizeof(float));
	float *np = calloc(n, sizeof(float));

	// (1) NULL -> identity ramp; a flat pair -> constant.
	FxGripBuildCurveLUTPeriodic(NULL, 0, lut, n);
	for (int i = 0; i < n; i++) {
		XCTAssertEqualWithAccuracy(lut[i], (float)i / (float)(n - 1), 1e-6f, @"periodic NULL -> identity at %d", i);
	}
	const float flat[2][2] = {{0.0f, 0.5f}, {1.0f, 0.5f}};
	FxGripBuildCurveLUTPeriodic(flat, 2, lut, n);
	for (int i = 0; i < n; i++) {
		XCTAssertEqualWithAccuracy(lut[i], 0.5f, 1e-5f, @"periodic flat -> constant at %d", i);
	}

	// (2) A hue curve with unequal endpoints: the clamped builder seams, the periodic one closes.
	const float hue[3][2] = {{0.05f, 0.2f}, {0.5f, 0.9f}, {0.95f, 0.4f}};
	FxGripBuildCurveLUT(hue, 3, np, n);
	FxGripBuildCurveLUTPeriodic(hue, 3, lut, n);
	XCTAssertGreaterThan(fabsf(np[n - 1] - np[0]), 0.15f,
						 @"clamped builder DOES seam (endpoints held at 0.4 vs 0.2)");
	XCTAssertEqualWithAccuracy(lut[0], lut[n - 1], 1e-5f,
							   @"periodic builder closes the loop: no seam at red");

	// (3) C¹ across the seam.
	float fwd0 = lut[1] - lut[0];
	float bwd1 = lut[n - 1] - lut[n - 2];
	XCTAssertEqualWithAccuracy(fwd0, bwd1, 2e-3f, @"C1 continuity of the hue curve across the red seam");

	// (4) The curve passes through its control values.
	XCTAssertEqualWithAccuracy(FxGripTestSampleLUT(lut, n, 0.5f), 0.9f, 3e-3f, @"periodic hits interior control");

	// (5) Everything stays finite and in a sane range.
	for (int i = 0; i < n; i++) {
		XCTAssertTrue(isfinite(lut[i]), @"periodic finite at %d", i);
		XCTAssertGreaterThanOrEqual(lut[i], -0.1f, @"periodic lo at %d", i);
		XCTAssertLessThanOrEqual(lut[i], 1.1f, @"periodic hi at %d", i);
	}

	free(lut);
	free(np);
}

- (void)testFewerThanTwoControlPointsBuildTheIdentityRamp
{
	const int n = 64;
	float lut[64];
	const float single[1][2] = {{0.5f, 0.25f}};

	FxGripBuildCurveLUT(single, 1, lut, n);
	for (int i = 0; i < n; i++) {
		XCTAssertEqualWithAccuracy(lut[i], (float)i / (float)(n - 1), 1e-6f, @"one point -> identity at %d", i);
	}

	FxGripBuildCurveLUT(single, 0, lut, n);
	for (int i = 0; i < n; i++) {
		XCTAssertEqualWithAccuracy(lut[i], (float)i / (float)(n - 1), 1e-6f, @"zero count -> identity at %d", i);
	}
}

- (void)testANonPositiveEntryCountLeavesTheBufferUntouched
{
	float lut[4] = {-7.0f, -7.0f, -7.0f, -7.0f};
	const float line[2][2] = {{0, 0}, {1, 1}};

	FxGripBuildCurveLUT(line, 2, lut, 0);
	FxGripBuildCurveLUT(line, 2, lut, -3);
	FxGripBuildCurveLUTPeriodic(line, 2, lut, 0);
	FxGripBuildCurveLUTPeriodic(NULL, 0, lut, -1);

	for (int i = 0; i < 4; i++) {
		XCTAssertEqualWithAccuracy(lut[i], -7.0f, 0.0f, @"untouched at %d", i);
	}
}

- (void)testASingleEntryLUTTakesTheValueAtZero
{
	float lut[1] = {-7.0f};
	const float points[2][2] = {{0.25f, 0.7f}, {0.75f, 0.2f}};

	FxGripBuildCurveLUT(points, 2, lut, 1);
	XCTAssertEqualWithAccuracy(lut[0], 0.7f, 1e-6f, @"held first value at x = 0");

	FxGripBuildCurveLUT(NULL, 0, lut, 1);
	XCTAssertEqualWithAccuracy(lut[0], 0.0f, 1e-6f, @"identity ramp of one entry is 0");
}

- (void)testTheEndValuesHoldOutsideThePointRange
{
	const int n = kCurveN;
	float lut[kCurveN];
	const float points[2][2] = {{0.25f, 0.7f}, {0.75f, 0.2f}};

	FxGripBuildCurveLUT(points, 2, lut, n);
	for (int i = 0; i < n; i++) {
		float x = (float)i / (float)(n - 1);
		if (x <= 0.25f) {
			XCTAssertEqualWithAccuracy(lut[i], 0.7f, 1e-6f, @"low end holds at %d", i);
		}
		if (x >= 0.75f) {
			XCTAssertEqualWithAccuracy(lut[i], 0.2f, 1e-6f, @"high end holds at %d", i);
		}
	}
}

- (void)testASteepStepStaysBoundedByItsNeighborValues
{
	const int n = kCurveN;
	float lut[kCurveN];
	const float step[4][2] = {{0.0f, 0.0f}, {0.49f, 0.02f}, {0.51f, 0.98f}, {1.0f, 1.0f}};

	FxGripBuildCurveLUT(step, 4, lut, n);
	for (int i = 1; i < n; i++) {
		XCTAssertGreaterThanOrEqual(lut[i], lut[i - 1] - 1e-6f, @"non-decreasing at %d", i);
	}
	for (int i = 0; i < n; i++) {
		float x = (float)i / (float)(n - 1);
		if (x > 0.49f && x < 0.51f) {
			XCTAssertGreaterThanOrEqual(lut[i], 0.02f - 1e-6f, @"no undershoot inside the step at %d", i);
			XCTAssertLessThanOrEqual(lut[i], 0.98f + 1e-6f, @"no overshoot inside the step at %d", i);
		}
	}
}

- (void)testUnsortedPointsBuildTheSameLUTAsSortedPoints
{
	const int n = kCurveN;
	float sortedLUT[kCurveN];
	float shuffledLUT[kCurveN];
	const float sorted[4][2] = {{0.0f, 0.1f}, {0.3f, 0.2f}, {0.6f, 0.7f}, {1.0f, 0.9f}};
	const float shuffled[4][2] = {{0.6f, 0.7f}, {0.0f, 0.1f}, {1.0f, 0.9f}, {0.3f, 0.2f}};

	FxGripBuildCurveLUT(sorted, 4, sortedLUT, n);
	FxGripBuildCurveLUT(shuffled, 4, shuffledLUT, n);

	for (int i = 0; i < n; i++) {
		XCTAssertEqualWithAccuracy(shuffledLUT[i], sortedLUT[i], 0.0f, @"order independent at %d", i);
	}
}

- (void)testADuplicateXKeepsTheFirstPoint
{
	const int n = kCurveN;
	float lut[kCurveN];
	const float duplicate[2][2] = {{0.25f, 0.3f}, {0.25f, 0.9f}};

	FxGripBuildCurveLUT(duplicate, 2, lut, n);
	for (int i = 0; i < n; i++) {
		XCTAssertEqualWithAccuracy(lut[i], 0.3f, 1e-5f, @"first duplicate wins at %d", i);
	}

	const float interior[4][2] = {{0.0f, 0.0f}, {0.5f, 0.25f}, {0.5f, 0.75f}, {1.0f, 1.0f}};
	FxGripBuildCurveLUT(interior, 4, lut, n);
	XCTAssertEqualWithAccuracy(FxGripTestSampleLUT(lut, n, 0.5f), 0.25f, 3e-3f,
							   @"first duplicate wins at an interior node");
}

- (void)testThePeriodicLUTClosesTheLoopForUnequalEndpointValues
{
	const int n = kCurveN;
	float lut[kCurveN];
	const float points[2][2] = {{0.0f, 0.3f}, {0.75f, 0.8f}};

	FxGripBuildCurveLUTPeriodic(points, 2, lut, n);
	XCTAssertEqualWithAccuracy(lut[0], lut[n - 1], 1e-5f, @"first and last entry are the same circle point");
}

- (void)testThePeriodicSeamSlopeMatchesTheSlopeJustInside
{
	const int n = 1024;
	float *lut = calloc(n, sizeof(float));
	const float hue[3][2] = {{0.05f, 0.2f}, {0.5f, 0.9f}, {0.95f, 0.4f}};

	FxGripBuildCurveLUTPeriodic(hue, 3, lut, n);
	float acrossSeam = lut[n - 1] - lut[n - 2];
	float justInside = lut[1] - lut[0];
	XCTAssertEqualWithAccuracy(acrossSeam, justInside, 5e-4f, @"C1 seam on a fine LUT");

	free(lut);
}

- (void)testAPointOutsideTheUnitRangeFoldsIntoTheDomain
{
	const int n = kCurveN;
	float folded[kCurveN];
	float direct[kCurveN];
	const float outside[2][2] = {{1.25f, 0.8f}, {0.6f, 0.2f}};
	const float inside[2][2] = {{0.25f, 0.8f}, {0.6f, 0.2f}};

	FxGripBuildCurveLUTPeriodic(outside, 2, folded, n);
	FxGripBuildCurveLUTPeriodic(inside, 2, direct, n);

	for (int i = 0; i < n; i++) {
		XCTAssertEqualWithAccuracy(folded[i], direct[i], 0.0f, @"x = 1.25 folds to x = 0.25 at %d", i);
	}
}

- (void)testThePeriodicBuilderMatchesTheClampedBuilderForDegenerateInput
{
	const int n = 64;
	float periodic[64];
	float clamped[64];
	const float single[1][2] = {{0.4f, 0.6f}};
	const float duplicate[2][2] = {{0.5f, 0.3f}, {0.5f, 0.3f}};

	FxGripBuildCurveLUTPeriodic(NULL, 0, periodic, n);
	FxGripBuildCurveLUT(NULL, 0, clamped, n);
	for (int i = 0; i < n; i++) {
		XCTAssertEqualWithAccuracy(periodic[i], clamped[i], 0.0f, @"NULL agrees at %d", i);
	}

	FxGripBuildCurveLUTPeriodic(single, 1, periodic, n);
	FxGripBuildCurveLUT(single, 1, clamped, n);
	for (int i = 0; i < n; i++) {
		XCTAssertEqualWithAccuracy(periodic[i], clamped[i], 0.0f, @"one point agrees at %d", i);
	}

	FxGripBuildCurveLUTPeriodic(duplicate, 2, periodic, n);
	FxGripBuildCurveLUT(duplicate, 2, clamped, n);
	for (int i = 0; i < n; i++) {
		XCTAssertEqualWithAccuracy(periodic[i], clamped[i], 0.0f, @"one distinct x agrees at %d", i);
	}
}

- (void)testAHueShiftCurveHasNoHardStepAnywhere
{
	const int n = kCurveN;
	float lut[kCurveN];
	const float shift[2][2] = {{0.0f, 0.3f}, {0.5f, 0.7f}};

	FxGripBuildCurveLUTPeriodic(shift, 2, lut, n);
	float largest = 0.0f;
	for (int i = 1; i < n; i++) {
		largest = MAX(largest, fabsf(lut[i] - lut[i - 1]));
	}
	XCTAssertLessThan(largest, 0.02f, @"no hard step inside the range");
	XCTAssertEqualWithAccuracy(lut[0], lut[n - 1], 1e-5f, @"no hard step across the seam");
}

@end


#pragma mark - Curve model

@interface FxGripCurveDataTests : XCTestCase
@end

@implementation FxGripCurveDataTests

- (FxGripCurveData *)linearRemapWithPoints:(const CGPoint *)points count:(NSUInteger)count
{
	return [FxGripCurveData curveWithPoints:points
									  count:count
									   role:FxGripCurveRoleRemap
									 domain:FxGripCurveDomainLinear];
}


#pragma mark Sanitization

- (void)testTheYValuesClampToTheUnitRange
{
	CGPoint points[2] = {CGPointMake(0.25, -0.3), CGPointMake(0.75, 1.7)};
	FxGripCurveData *curve = [self linearRemapWithPoints:points count:2];

	XCTAssertEqual(curve.pointCount, (NSUInteger)2);
	XCTAssertEqualWithAccuracy([curve pointAtIndex:0].y, 0.0, 1e-9);
	XCTAssertEqualWithAccuracy([curve pointAtIndex:1].y, 1.0, 1e-9);
}

- (void)testLinearXValuesClampToTheUnitRange
{
	CGPoint points[2] = {CGPointMake(-0.5, 0.3), CGPointMake(1.5, 0.4)};
	FxGripCurveData *curve = [self linearRemapWithPoints:points count:2];

	XCTAssertEqualWithAccuracy([curve pointAtIndex:0].x, 0.0, 1e-9);
	XCTAssertEqualWithAccuracy([curve pointAtIndex:1].x, 1.0, 1e-9);
}

- (void)testCircularXValuesFoldIntoTheUnitRange
{
	CGPoint points[2] = {CGPointMake(1.25, 0.3), CGPointMake(-0.25, 0.4)};
	FxGripCurveData *curve = [FxGripCurveData curveWithPoints:points
													   count:2
														role:FxGripCurveRoleShift
													  domain:FxGripCurveDomainCircular];

	XCTAssertEqual(curve.pointCount, (NSUInteger)2);
	XCTAssertEqualWithAccuracy([curve pointAtIndex:0].x, 0.25, 1e-9);
	XCTAssertEqualWithAccuracy([curve pointAtIndex:0].y, 0.3, 1e-9);
	XCTAssertEqualWithAccuracy([curve pointAtIndex:1].x, 0.75, 1e-9);
	XCTAssertEqualWithAccuracy([curve pointAtIndex:1].y, 0.4, 1e-9);
}

- (void)testThePointsSortByAscendingX
{
	CGPoint points[3] = {CGPointMake(0.8, 0.1), CGPointMake(0.2, 0.9), CGPointMake(0.5, 0.5)};
	FxGripCurveData *curve = [self linearRemapWithPoints:points count:3];

	XCTAssertEqual(curve.pointCount, (NSUInteger)3);
	XCTAssertEqualWithAccuracy([curve pointAtIndex:0].x, 0.2, 1e-9);
	XCTAssertEqualWithAccuracy([curve pointAtIndex:1].x, 0.5, 1e-9);
	XCTAssertEqualWithAccuracy([curve pointAtIndex:2].x, 0.8, 1e-9);
	XCTAssertEqualWithAccuracy([curve pointAtIndex:0].y, 0.9, 1e-9);
}

- (void)testADuplicateXDropsAndTheFirstPointWins
{
	CGPoint points[3] = {CGPointMake(0.0, 0.0), CGPointMake(0.5, 0.25), CGPointMake(0.5, 0.75)};
	FxGripCurveData *curve = [self linearRemapWithPoints:points count:3];

	XCTAssertEqual(curve.pointCount, (NSUInteger)2);
	XCTAssertEqualWithAccuracy([curve pointAtIndex:1].x, 0.5, 1e-9);
	XCTAssertEqualWithAccuracy([curve pointAtIndex:1].y, 0.25, 1e-9);
}

- (void)testNilPointsWithANonZeroCountYieldNoCurve
{
	XCTAssertNil([self linearRemapWithPoints:NULL count:3]);

	FxGripCurveData *empty = [self linearRemapWithPoints:NULL count:0];
	XCTAssertNotNil(empty);
	XCTAssertEqual(empty.pointCount, (NSUInteger)0);
}


#pragma mark Identity

- (void)testTheRemapIdentityIsTheDiagonal
{
	FxGripCurveData *identity = [FxGripCurveData identityCurveWithRole:FxGripCurveRoleRemap
																domain:FxGripCurveDomainLinear];

	XCTAssertEqual(identity.pointCount, (NSUInteger)2);
	XCTAssertEqualWithAccuracy([identity pointAtIndex:0].x, 0.0, 1e-9);
	XCTAssertEqualWithAccuracy([identity pointAtIndex:0].y, 0.0, 1e-9);
	XCTAssertEqualWithAccuracy([identity pointAtIndex:1].x, 1.0, 1e-9);
	XCTAssertEqualWithAccuracy([identity pointAtIndex:1].y, 1.0, 1e-9);
	XCTAssertTrue(identity.isIdentity);
}

- (void)testTheShiftIdentityIsFlatAtAHalf
{
	FxGripCurveData *identity = [FxGripCurveData identityCurveWithRole:FxGripCurveRoleShift
																domain:FxGripCurveDomainLinear];

	XCTAssertEqual(identity.pointCount, (NSUInteger)2);
	XCTAssertEqualWithAccuracy([identity pointAtIndex:0].y, 0.5, 1e-9);
	XCTAssertEqualWithAccuracy([identity pointAtIndex:1].y, 0.5, 1e-9);
	XCTAssertTrue(identity.isIdentity);

	float lut[kCurveBlendSampleCount];
	[identity buildLUT:lut count:kCurveBlendSampleCount];
	for (NSUInteger index = 0; index < kCurveBlendSampleCount; index++) {
		XCTAssertEqualWithAccuracy(lut[index], 0.5f, 1e-6f, @"flat neutral at %lu", (unsigned long)index);
	}
}

- (void)testTheMultiplierIdentitiesAreFlatAtTheirNeutral
{
	FxGripCurveData *half = [FxGripCurveData identityCurveWithRole:FxGripCurveRoleMultiplierHalf
															domain:FxGripCurveDomainLinear];
	FxGripCurveData *one = [FxGripCurveData identityCurveWithRole:FxGripCurveRoleMultiplierOne
														   domain:FxGripCurveDomainLinear];

	XCTAssertEqualWithAccuracy([half pointAtIndex:0].y, 0.5, 1e-9);
	XCTAssertEqualWithAccuracy([half pointAtIndex:1].y, 0.5, 1e-9);
	XCTAssertEqualWithAccuracy([one pointAtIndex:0].y, 1.0, 1e-9);
	XCTAssertEqualWithAccuracy([one pointAtIndex:1].y, 1.0, 1e-9);
	XCTAssertTrue(half.isIdentity);
	XCTAssertTrue(one.isIdentity);
}

- (void)testTheCircularRemapIdentityEvaluatesAsTheDiagonal
{
	FxGripCurveData *identity = [FxGripCurveData identityCurveWithRole:FxGripCurveRoleRemap
																domain:FxGripCurveDomainCircular];
	const int n = kCurveN;
	float lut[kCurveN];

	[identity buildLUT:lut count:n];
	for (int index = 0; index < n; index++) {
		XCTAssertEqualWithAccuracy(lut[index], (float)index / (float)(n - 1), 1e-6f,
								   @"diagonal at %d", index);
	}
}

- (void)testAMovedPointIsNotTheIdentity
{
	CGPoint points[3] = {CGPointMake(0.0, 0.0), CGPointMake(0.5, 0.8), CGPointMake(1.0, 1.0)};
	FxGripCurveData *curve = [self linearRemapWithPoints:points count:3];

	XCTAssertFalse(curve.isIdentity);
}

- (void)testAFlatNeutralShapeIsNotTheIdentityOfTheRemapRole
{
	CGPoint points[2] = {CGPointMake(0.0, 0.5), CGPointMake(1.0, 0.5)};
	FxGripCurveData *flatRemap = [self linearRemapWithPoints:points count:2];
	FxGripCurveData *flatShift = [FxGripCurveData curveWithPoints:points
														   count:2
															role:FxGripCurveRoleShift
														  domain:FxGripCurveDomainLinear];

	XCTAssertFalse(flatRemap.isIdentity);
	XCTAssertTrue(flatShift.isIdentity);
}


#pragma mark Accessors

- (void)testPointAtIndexBeyondTheCountIsZero
{
	CGPoint points[2] = {CGPointMake(0.0, 0.2), CGPointMake(1.0, 0.8)};
	FxGripCurveData *curve = [self linearRemapWithPoints:points count:2];

	XCTAssertEqualWithAccuracy([curve pointAtIndex:2].x, 0.0, 0.0);
	XCTAssertEqualWithAccuracy([curve pointAtIndex:2].y, 0.0, 0.0);
	XCTAssertEqualWithAccuracy([curve pointAtIndex:99].x, 0.0, 0.0);
	XCTAssertEqualWithAccuracy([curve pointAtIndex:99].y, 0.0, 0.0);
}

- (void)testCopyCurvePointsWritesAtMostTheCapacity
{
	CGPoint points[3] = {CGPointMake(0.0, 0.2), CGPointMake(0.5, 0.4), CGPointMake(1.0, 0.8)};
	FxGripCurveData *curve = [self linearRemapWithPoints:points count:3];
	float buffer[4] = {0};

	XCTAssertEqual([curve copyCurvePointsFloat2:(float (*)[2])buffer capacity:1], (NSUInteger)1);
	XCTAssertEqualWithAccuracy(buffer[0], 0.0f, 1e-6f);
	XCTAssertEqualWithAccuracy(buffer[1], 0.2f, 1e-6f);

	float wide[8] = {0};
	XCTAssertEqual([curve copyCurvePointsFloat2:(float (*)[2])wide capacity:4], (NSUInteger)3);
	for (NSUInteger index = 0; index < 3; index++) {
		CGPoint point = [curve pointAtIndex:index];
		XCTAssertEqualWithAccuracy(wide[index * 2], (float)point.x, 1e-6f, @"x at %lu", (unsigned long)index);
		XCTAssertEqualWithAccuracy(wide[index * 2 + 1], (float)point.y, 1e-6f, @"y at %lu", (unsigned long)index);
	}

	float (*noBuffer)[2] = NULL;
	XCTAssertEqual([curve copyCurvePointsFloat2:noBuffer capacity:4], (NSUInteger)0);
}

- (void)testBuildLUTMatchesTheClampedBuilderForALinearCurve
{
	const int n = kCurveN;
	CGPoint points[3] = {CGPointMake(0.0, 0.0), CGPointMake(0.5, 0.6), CGPointMake(1.0, 1.0)};
	FxGripCurveData *curve = [self linearRemapWithPoints:points count:3];
	const float raw[3][2] = {{0.0f, 0.0f}, {0.5f, 0.6f}, {1.0f, 1.0f}};
	float fromCurve[kCurveN];
	float fromBuilder[kCurveN];

	[curve buildLUT:fromCurve count:n];
	FxGripBuildCurveLUT(raw, 3, fromBuilder, n);

	for (int index = 0; index < n; index++) {
		XCTAssertEqualWithAccuracy(fromCurve[index], fromBuilder[index], 0.0f, @"entry %d", index);
	}
}

- (void)testBuildLUTMatchesThePeriodicBuilderForACircularCurve
{
	const int n = kCurveN;
	CGPoint points[3] = {CGPointMake(0.05, 0.2), CGPointMake(0.5, 0.9), CGPointMake(0.95, 0.4)};
	FxGripCurveData *curve = [FxGripCurveData curveWithPoints:points
													   count:3
														role:FxGripCurveRoleShift
													  domain:FxGripCurveDomainCircular];
	const float raw[3][2] = {{0.05f, 0.2f}, {0.5f, 0.9f}, {0.95f, 0.4f}};
	float fromCurve[kCurveN];
	float fromBuilder[kCurveN];

	[curve buildLUT:fromCurve count:n];
	FxGripBuildCurveLUTPeriodic(raw, 3, fromBuilder, n);

	for (int index = 0; index < n; index++) {
		XCTAssertEqualWithAccuracy(fromCurve[index], fromBuilder[index], 0.0f, @"entry %d", index);
	}
}

- (void)testBuildLUTIgnoresAnEmptyRequest
{
	CGPoint points[2] = {CGPointMake(0.0, 0.2), CGPointMake(1.0, 0.8)};
	FxGripCurveData *curve = [self linearRemapWithPoints:points count:2];
	float lut[2] = {-7.0f, -7.0f};
	float *noLUT = NULL;

	[curve buildLUT:noLUT count:16];
	[curve buildLUT:lut count:0];

	XCTAssertEqualWithAccuracy(lut[0], -7.0f, 0.0f);
	XCTAssertEqualWithAccuracy(lut[1], -7.0f, 0.0f);
}


#pragma mark Coding and equality

- (void)testACurveSurvivesTheSecureArchiveRoundTrip
{
	CGPoint points[3] = {CGPointMake(0.1, 0.2), CGPointMake(0.5, 0.9), CGPointMake(0.95, 0.4)};
	FxGripCurveData *curve = [FxGripCurveData curveWithPoints:points
													   count:3
														role:FxGripCurveRoleMultiplierHalf
													  domain:FxGripCurveDomainCircular];
	NSError *error = nil;
	NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:curve requiringSecureCoding:YES error:&error];
	XCTAssertNotNil(archive, @"%@", error);

	FxGripCurveData *decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:FxGripCurveData.class
																fromData:archive
																   error:&error];
	XCTAssertNotNil(decoded, @"%@", error);
	XCTAssertEqual(decoded.role, FxGripCurveRoleMultiplierHalf);
	XCTAssertEqual(decoded.domain, FxGripCurveDomainCircular);
	XCTAssertEqual(decoded.pointCount, curve.pointCount);
	for (NSUInteger index = 0; index < curve.pointCount; index++) {
		XCTAssertEqualWithAccuracy([decoded pointAtIndex:index].x, [curve pointAtIndex:index].x, 0.0,
								   @"x at %lu", (unsigned long)index);
		XCTAssertEqualWithAccuracy([decoded pointAtIndex:index].y, [curve pointAtIndex:index].y, 0.0,
								   @"y at %lu", (unsigned long)index);
	}
	XCTAssertEqualObjects(decoded, curve);
}

/*! Writes the coder payload FxGripCurveData.m reads, so a malformed points array can be
	presented to -initWithCoder: directly. */
- (NSData *)archiveWithPointsPayload:(nullable id)payload
{
	NSKeyedArchiver *archiver = [NSKeyedArchiver.alloc initRequiringSecureCoding:YES];
	[archiver encodeInteger:1 forKey:kCurveKey_Version];
	[archiver encodeInteger:FxGripCurveDomainLinear forKey:kCurveKey_Domain];
	[archiver encodeInteger:FxGripCurveRoleRemap forKey:kCurveKey_Role];
	if (payload != nil) {
		[archiver encodeObject:payload forKey:kCurveKey_Points];
	}
	[archiver finishEncoding];
	return archiver.encodedData;
}

- (FxGripCurveData *)decodeCurveFromArchive:(NSData *)archive
{
	NSKeyedUnarchiver *unarchiver = [NSKeyedUnarchiver.alloc initForReadingFromData:archive error:NULL];
	return [FxGripCurveData.alloc initWithCoder:unarchiver];
}

- (void)testAMalformedPointsArrayDecodesToNoCurve
{
	XCTAssertNil([self decodeCurveFromArchive:[self archiveWithPointsPayload:(@[@0.0, @0.0, @1.0])]],
				 @"odd entry count is not a whole point list");
	XCTAssertNil([self decodeCurveFromArchive:[self archiveWithPointsPayload:nil]],
				 @"a missing points array is not a curve");

	FxGripCurveData *decoded = [self decodeCurveFromArchive:[self archiveWithPointsPayload:(@[@0.25, @0.75])]];
	XCTAssertNotNil(decoded);
	XCTAssertEqual(decoded.pointCount, (NSUInteger)1);
}

- (void)testEqualCurvesMatchAndDifferingCurvesDoNot
{
	CGPoint points[2] = {CGPointMake(0.0, 0.2), CGPointMake(1.0, 0.8)};
	CGPoint moved[2] = {CGPointMake(0.0, 0.3), CGPointMake(1.0, 0.8)};
	FxGripCurveData *curve = [self linearRemapWithPoints:points count:2];
	FxGripCurveData *same = [self linearRemapWithPoints:points count:2];
	FxGripCurveData *otherPoints = [self linearRemapWithPoints:moved count:2];
	FxGripCurveData *otherRole = [FxGripCurveData curveWithPoints:points
														   count:2
															role:FxGripCurveRoleShift
														  domain:FxGripCurveDomainLinear];
	FxGripCurveData *otherDomain = [FxGripCurveData curveWithPoints:points
															 count:2
															  role:FxGripCurveRoleRemap
															domain:FxGripCurveDomainCircular];

	XCTAssertEqualObjects(curve, same);
	XCTAssertEqual(curve.hash, same.hash);
	XCTAssertNotEqualObjects(curve, otherPoints);
	XCTAssertNotEqualObjects(curve, otherRole);
	XCTAssertNotEqualObjects(curve, otherDomain);
	XCTAssertNotEqualObjects(curve, @"not a curve");
}

- (void)testCopyReturnsTheSameImmutableInstance
{
	CGPoint points[2] = {CGPointMake(0.0, 0.2), CGPointMake(1.0, 0.8)};
	FxGripCurveData *curve = [self linearRemapWithPoints:points count:2];

	XCTAssertEqual([curve copy], curve);
}


#pragma mark Defects

/*! Sanitization keeps an exact x = 1.0 as the closed-loop endpoint, so a circular flat
	neutral stays two points and the builder reaches its constant branch. */
- (void)testTheCircularFlatIdentitiesBuildTheirFlatNeutralLUT
{
	FxGripCurveData *shift = [FxGripCurveData identityCurveWithRole:FxGripCurveRoleShift
															 domain:FxGripCurveDomainCircular];
	FxGripCurveData *multiplier = [FxGripCurveData identityCurveWithRole:FxGripCurveRoleMultiplierOne
																  domain:FxGripCurveDomainCircular];
	float lut[kCurveBlendSampleCount];

	[shift buildLUT:lut count:kCurveBlendSampleCount];
	for (NSUInteger index = 0; index < kCurveBlendSampleCount; index++) {
		XCTAssertEqualWithAccuracy(lut[index], 0.5f, 1e-5f, @"shift neutral at %lu", (unsigned long)index);
	}

	[multiplier buildLUT:lut count:kCurveBlendSampleCount];
	for (NSUInteger index = 0; index < kCurveBlendSampleCount; index++) {
		XCTAssertEqualWithAccuracy(lut[index], 1.0f, 1e-5f, @"multiplier neutral at %lu", (unsigned long)index);
	}
}

@end


#pragma mark - Curve set

@interface FxGripCurveSetDataTests : XCTestCase
@property (nonatomic, strong) FxGripCurveSetData *set;
@end

@implementation FxGripCurveSetDataTests

- (void)setUp
{
	[super setUp];
	self.set = [FxGripCurveSetData.alloc init];
}

- (void)tearDown
{
	self.set = nil;
	[super tearDown];
}

- (FxGripCurveData *)remapCurveWithMidY:(CGFloat)midY
{
	CGPoint points[3] = {CGPointMake(0.0, 0.0), CGPointMake(0.5, midY), CGPointMake(1.0, 1.0)};
	return [FxGripCurveData curveWithPoints:points
									  count:3
									   role:FxGripCurveRoleRemap
									 domain:FxGripCurveDomainLinear];
}

/*! A two-point remap curve, so a blend against the two-point diagonal takes the pairwise
	path and the midpoints are exact. */
- (FxGripCurveData *)liftedRemapCurve
{
	CGPoint points[2] = {CGPointMake(0.0, 0.4), CGPointMake(1.0, 1.0)};
	return [FxGripCurveData curveWithPoints:points
									  count:2
									   role:FxGripCurveRoleRemap
									 domain:FxGripCurveDomainLinear];
}


#pragma mark Storage

- (void)testACurveRoundTripsThroughTheKeyedStore
{
	FxGripCurveData *curve = [self remapCurveWithMidY:0.7];

	[self.set setCurve:curve forKey:@"luma"];

	XCTAssertEqualObjects([self.set curveForKey:@"luma"], curve);
	XCTAssertNil([self.set curveForKey:@"red"]);
}

- (void)testStoringAnIdentityCurveRemovesTheKey
{
	FxGripCurveData *identity = [FxGripCurveData identityCurveWithRole:FxGripCurveRoleRemap
																domain:FxGripCurveDomainLinear];
	[self.set setCurve:[self remapCurveWithMidY:0.7] forKey:@"luma"];

	[self.set setCurve:identity forKey:@"luma"];

	XCTAssertNil([self.set curveForKey:@"luma"]);
	XCTAssertEqual(self.set.count, (NSUInteger)0);
}

- (void)testStoringNilOrRemovingClearsTheKey
{
	[self.set setCurve:[self remapCurveWithMidY:0.7] forKey:@"luma"];
	[self.set setCurve:nil forKey:@"luma"];
	XCTAssertNil([self.set curveForKey:@"luma"]);

	[self.set setCurve:[self remapCurveWithMidY:0.7] forKey:@"red"];
	[self.set removeCurveForKey:@"red"];
	XCTAssertNil([self.set curveForKey:@"red"]);
}

- (void)testCurveKeysAreSortedAndExcludeNonCurveEntries
{
	[self.set setCurve:[self remapCurveWithMidY:0.7] forKey:@"red"];
	[self.set setCurve:[self remapCurveWithMidY:0.3] forKey:@"blue"];
	[self.set setCurve:[self remapCurveWithMidY:0.6] forKey:@"luma"];
	[self.set setObject:@"a label" forKey:@"note"];
	[self.set setObject:@(0.5) forKey:@"mix"];

	XCTAssertEqualObjects(self.set.curveKeys, (@[@"blue", @"luma", @"red"]));
	XCTAssertNil([self.set curveForKey:@"note"]);
}

- (void)testTheParameterClassListIncludesTheCurveClass
{
	XCTAssertTrue([FxGripCurveSetData.classesForParameter containsObject:FxGripCurveData.class]);
	XCTAssertTrue([FxGripCurveSetData.classesForParameter containsObject:NSNumber.class]);
}

- (void)testACurveSetSurvivesTheSecureArchiveRoundTrip
{
	FxGripCurveData *luma = [self remapCurveWithMidY:0.7];
	FxGripCurveData *hue = [FxGripCurveData curveWithPoints:(CGPoint[3]){CGPointMake(0.05, 0.2),
																		 CGPointMake(0.5, 0.9),
																		 CGPointMake(0.95, 0.4)}
													  count:3
													   role:FxGripCurveRoleShift
													 domain:FxGripCurveDomainCircular];
	[self.set setCurve:luma forKey:@"luma"];
	[self.set setCurve:hue forKey:@"hueVsHue"];
	[self.set setObject:@(0.25) forKey:@"mix"];

	NSError *error = nil;
	NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:self.set requiringSecureCoding:YES error:&error];
	XCTAssertNotNil(archive, @"%@", error);

	FxGripCurveSetData *decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:FxGripCurveSetData.class
																   fromData:archive
																	  error:&error];
	XCTAssertNotNil(decoded, @"%@", error);
	XCTAssertTrue([decoded isKindOfClass:FxGripCurveSetData.class]);
	XCTAssertEqualObjects(decoded.curveKeys, (@[@"hueVsHue", @"luma"]));
	XCTAssertEqualObjects([decoded curveForKey:@"luma"], luma);
	XCTAssertEqualObjects([decoded curveForKey:@"hueVsHue"], hue);
	XCTAssertEqualObjects([decoded objectForKey:@"mix"], @(0.25));
}


#pragma mark Keyframe interpolation

- (FxGripCurveSetData *)setWithCurve:(FxGripCurveData *)curve forKey:(NSString *)key
{
	FxGripCurveSetData *set = [FxGripCurveSetData.alloc init];
	if (curve != nil) {
		[set setCurve:curve forKey:key];
	}
	return set;
}

- (void)testTheInterpolatedValueIsACurveSet
{
	FxGripCurveSetData *right = [self setWithCurve:[self remapCurveWithMidY:0.7] forKey:@"luma"];
	[self.set setCurve:[self remapCurveWithMidY:0.3] forKey:@"luma"];

	id blended = [self.set interpolateBetween:right withWeight:0.5f];

	XCTAssertTrue([blended isKindOfClass:FxGripCurveSetData.class]);
}

- (void)testMatchedCurvesInterpolatePairwise
{
	FxGripCurveData *left = [self remapCurveWithMidY:0.2];
	FxGripCurveData *right = [self remapCurveWithMidY:0.8];
	[self.set setCurve:left forKey:@"luma"];
	FxGripCurveSetData *rightSet = [self setWithCurve:right forKey:@"luma"];

	FxGripCurveSetData *atLeft = (FxGripCurveSetData *)[self.set interpolateBetween:rightSet withWeight:0.0f];
	FxGripCurveSetData *atRight = (FxGripCurveSetData *)[self.set interpolateBetween:rightSet withWeight:1.0f];
	FxGripCurveSetData *middle = (FxGripCurveSetData *)[self.set interpolateBetween:rightSet withWeight:0.5f];

	XCTAssertEqualObjects([atLeft curveForKey:@"luma"], left);
	XCTAssertEqualObjects([atRight curveForKey:@"luma"], right);

	FxGripCurveData *blended = [middle curveForKey:@"luma"];
	XCTAssertEqual(blended.pointCount, (NSUInteger)3);
	XCTAssertEqualWithAccuracy([blended pointAtIndex:1].x, 0.5, 1e-9);
	XCTAssertEqualWithAccuracy([blended pointAtIndex:1].y, 0.5, 1e-9);
	XCTAssertEqualWithAccuracy([blended pointAtIndex:0].y, 0.0, 1e-9);
	XCTAssertEqualWithAccuracy([blended pointAtIndex:2].y, 1.0, 1e-9);
}

- (void)testMismatchedPointCountsBlendOnTheSampleGrid
{
	CGPoint leftPoints[2] = {CGPointMake(0.0, 0.0), CGPointMake(1.0, 0.5)};
	FxGripCurveData *left = [FxGripCurveData curveWithPoints:leftPoints
													   count:2
														role:FxGripCurveRoleRemap
													  domain:FxGripCurveDomainLinear];
	FxGripCurveData *right = [self remapCurveWithMidY:0.9];
	[self.set setCurve:left forKey:@"luma"];
	FxGripCurveSetData *rightSet = [self setWithCurve:right forKey:@"luma"];
	const float weight = 0.25f;

	FxGripCurveSetData *result = (FxGripCurveSetData *)[self.set interpolateBetween:rightSet withWeight:weight];
	FxGripCurveData *blended = [result curveForKey:@"luma"];

	XCTAssertEqual(blended.pointCount, (NSUInteger)kCurveBlendSampleCount);

	float leftLUT[kCurveBlendSampleCount];
	float rightLUT[kCurveBlendSampleCount];
	float blendedLUT[kCurveBlendSampleCount];
	[left buildLUT:leftLUT count:kCurveBlendSampleCount];
	[right buildLUT:rightLUT count:kCurveBlendSampleCount];
	[blended buildLUT:blendedLUT count:kCurveBlendSampleCount];
	for (NSUInteger index = 0; index < kCurveBlendSampleCount; index += 8) {
		float expected = (1.0f - weight) * leftLUT[index] + weight * rightLUT[index];
		XCTAssertEqualWithAccuracy(blendedLUT[index], expected, 1e-5f, @"sample %lu", (unsigned long)index);
	}
}

- (void)testTheGridBlendTakesTheRoleAndDomainOfTheLeftCurve
{
	FxGripCurveData *leftRole = [self remapCurveWithMidY:0.2];
	CGPoint shiftPoints[3] = {CGPointMake(0.0, 0.5), CGPointMake(0.5, 0.8), CGPointMake(1.0, 0.5)};
	FxGripCurveData *rightRole = [FxGripCurveData curveWithPoints:shiftPoints
															count:3
															 role:FxGripCurveRoleShift
														   domain:FxGripCurveDomainLinear];
	[self.set setCurve:leftRole forKey:@"luma"];
	FxGripCurveSetData *rightSet = [self setWithCurve:rightRole forKey:@"luma"];

	FxGripCurveSetData *result = (FxGripCurveSetData *)[self.set interpolateBetween:rightSet withWeight:0.5f];
	XCTAssertEqual([result curveForKey:@"luma"].role, FxGripCurveRoleRemap);
	XCTAssertEqual([result curveForKey:@"luma"].domain, FxGripCurveDomainLinear);

	CGPoint circularPoints[3] = {CGPointMake(0.1, 0.5), CGPointMake(0.5, 0.8), CGPointMake(0.9, 0.5)};
	FxGripCurveData *leftDomain = [FxGripCurveData curveWithPoints:circularPoints
															 count:3
															  role:FxGripCurveRoleShift
															domain:FxGripCurveDomainCircular];
	FxGripCurveSetData *circularSet = [self setWithCurve:leftDomain forKey:@"hueVsHue"];
	FxGripCurveSetData *linearSet = [self setWithCurve:rightRole forKey:@"hueVsHue"];

	FxGripCurveData *circularFirst = [(FxGripCurveSetData *)[circularSet interpolateBetween:linearSet
																				 withWeight:0.5f] curveForKey:@"hueVsHue"];
	XCTAssertEqual(circularFirst.domain, FxGripCurveDomainCircular);
	XCTAssertEqual(circularFirst.role, FxGripCurveRoleShift);
}

- (void)testACurveOnlyOnTheLeftBlendsTowardItsRoleIdentity
{
	FxGripCurveData *lifted = [self liftedRemapCurve];
	[self.set setCurve:lifted forKey:@"luma"];
	FxGripCurveSetData *empty = [FxGripCurveSetData.alloc init];

	FxGripCurveSetData *result = (FxGripCurveSetData *)[self.set interpolateBetween:empty withWeight:0.5f];
	FxGripCurveData *blended = [result curveForKey:@"luma"];

	XCTAssertNotNil(blended);
	XCTAssertEqual(blended.pointCount, (NSUInteger)2);
	XCTAssertEqualWithAccuracy([blended pointAtIndex:0].y, 0.2, 1e-9, @"halfway to the diagonal");
	XCTAssertEqualWithAccuracy([blended pointAtIndex:1].y, 1.0, 1e-9);
	XCTAssertEqual(blended.role, FxGripCurveRoleRemap);
}

- (void)testACurveOnlyOnTheRightBlendsTowardItsRoleIdentity
{
	FxGripCurveSetData *rightSet = [self setWithCurve:[self liftedRemapCurve] forKey:@"luma"];

	FxGripCurveSetData *result = (FxGripCurveSetData *)[self.set interpolateBetween:rightSet withWeight:0.5f];
	FxGripCurveData *blended = [result curveForKey:@"luma"];

	XCTAssertNotNil(blended);
	XCTAssertEqual(blended.pointCount, (NSUInteger)2);
	XCTAssertEqualWithAccuracy([blended pointAtIndex:0].y, 0.2, 1e-9, @"halfway from the diagonal");
	XCTAssertEqualWithAccuracy([blended pointAtIndex:1].y, 1.0, 1e-9);
}

- (void)testAOneSidedCurveReachesTheNeutralAtTheFarEndpoint
{
	FxGripCurveSetData *empty = [FxGripCurveSetData.alloc init];
	[self.set setCurve:[self liftedRemapCurve] forKey:@"luma"];

	FxGripCurveSetData *fromLeft = (FxGripCurveSetData *)[self.set interpolateBetween:empty withWeight:1.0f];
	XCTAssertNil([fromLeft curveForKey:@"luma"], @"the neutral curve is stored as an absent key");

	FxGripCurveSetData *rightSet = [self setWithCurve:[self liftedRemapCurve] forKey:@"luma"];
	FxGripCurveSetData *fromRight = (FxGripCurveSetData *)[empty interpolateBetween:rightSet withWeight:0.0f];
	XCTAssertNil([fromRight curveForKey:@"luma"]);
}

- (void)testANonCurveValueStillInterpolatesThroughTheBase
{
	FxGripCurveSetData *rightSet = [FxGripCurveSetData.alloc init];
	[self.set setObject:@(0.25) forKey:@"mix"];
	[self.set setObject:@"keep" forKey:@"note"];
	[rightSet setObject:@(0.75) forKey:@"mix"];
	[rightSet setObject:@"other" forKey:@"note"];

	FxGripCurveSetData *result = (FxGripCurveSetData *)[self.set interpolateBetween:rightSet withWeight:0.5f];

	XCTAssertEqualWithAccuracy([[result objectForKey:@"mix"] doubleValue], 0.5, 1e-9);
	XCTAssertEqualObjects([result objectForKey:@"note"], @"keep");
}


#pragma mark Defects

/*! DEFECT (consequence of the circular identity folding to one point): a hue curve stored
	on only one keyframe blends against a neutral that evaluates as an identity ramp, so at
	the far endpoint the mapping is a full-range ramp instead of the flat neutral. */
- (void)testAOneSidedCircularShiftCurveReachesTheFlatNeutral
{
	CGPoint points[3] = {CGPointMake(0.1, 0.3), CGPointMake(0.5, 0.8), CGPointMake(0.9, 0.4)};
	FxGripCurveData *hue = [FxGripCurveData curveWithPoints:points
													  count:3
													   role:FxGripCurveRoleShift
													 domain:FxGripCurveDomainCircular];
	[self.set setCurve:hue forKey:@"hueVsHue"];
	FxGripCurveSetData *empty = [FxGripCurveSetData.alloc init];

	FxGripCurveSetData *result = (FxGripCurveSetData *)[self.set interpolateBetween:empty withWeight:1.0f];
	FxGripCurveData *blended = [result curveForKey:@"hueVsHue"];

	XCTAssertNotNil(blended);
	float lut[kCurveBlendSampleCount];
	[blended buildLUT:lut count:kCurveBlendSampleCount];
	for (NSUInteger index = 0; index < kCurveBlendSampleCount; index++) {
		XCTAssertEqualWithAccuracy(lut[index], 0.5f, 1e-4f, @"flat neutral at %lu", (unsigned long)index);
	}
}

@end
