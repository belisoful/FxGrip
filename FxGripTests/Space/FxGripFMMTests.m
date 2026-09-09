/*!
	@file       FxGripFMMTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-08
	@header     FxGripFMMTests
	@abstract   Tests for the inter-particle field core, FxGripFMM.
	@discussion Introduced in FxGrip 0.1.0. These tests pin the direct references against hand-computed
	            two-body cases and symmetry properties, and confirm the public evaluators reproduce the
	            reference. As the adaptive method replaces the direct far field, the accuracy suite
	            compares it to these references at the plan's tolerances.
*/

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripFMM.h>
#import <math.h>

@interface FxGripFMMTests : XCTestCase
@end

@implementation FxGripFMMTests

#pragma mark Scalar field reference

/*! @abstract Two unit sources one unit apart pull toward each other with magnitude near 1/(1+ε²)^{3/2}. */
- (void)testFieldTwoBodyMatchesClosedForm
{
	const float x[2] = {0.0f, 1.0f};
	const float y[2] = {0.0f, 0.0f};
	const float z[2] = {0.0f, 0.0f};
	const float s[2] = {1.0f, 1.0f};
	float ex[2], ey[2], ez[2];

	const float eps = 1e-3f;
	FxGripFMMEvaluateFieldDirect(2, eps, x, y, z, s, ex, ey, ez);

	const float r2 = 1.0f + eps * eps;
	const float expected = 1.0f / (r2 * sqrtf(r2));
	// Particle 0 is pulled toward +x by particle 1; particle 1 toward −x by particle 0.
	XCTAssertEqualWithAccuracy(ex[0], expected, 1e-5f);
	XCTAssertEqualWithAccuracy(ex[1], -expected, 1e-5f);
	XCTAssertEqualWithAccuracy(ey[0], 0.0f, 1e-6f);
	XCTAssertEqualWithAccuracy(ez[0], 0.0f, 1e-6f);
}

/*! @abstract The field sums to zero across sources of equal strength, since every pair cancels. */
- (void)testFieldMomentumConservation
{
	const uint32_t n = 64;
	float x[64], y[64], z[64], s[64], ex[64], ey[64], ez[64];
	uint32_t state = 12345u;
	for (uint32_t i = 0; i < n; i++) {
		state = state * 1664525u + 1013904223u;
		x[i] = (float)((state >> 8) & 0xffff) / 6553.6f - 5.0f;
		state = state * 1664525u + 1013904223u;
		y[i] = (float)((state >> 8) & 0xffff) / 6553.6f - 5.0f;
		state = state * 1664525u + 1013904223u;
		z[i] = (float)((state >> 8) & 0xffff) / 6553.6f - 5.0f;
		s[i] = 1.0f;
	}
	FxGripFMMEvaluateFieldDirect(n, 1e-2f, x, y, z, s, ex, ey, ez);

	float sx = 0.0f, sy = 0.0f, sz = 0.0f;
	for (uint32_t i = 0; i < n; i++) {
		sx += ex[i]; sy += ey[i]; sz += ez[i];
	}
	// Newton's third law: equal strengths make the total field cancel.
	XCTAssertEqualWithAccuracy(sx, 0.0f, 1e-3f);
	XCTAssertEqualWithAccuracy(sy, 0.0f, 1e-3f);
	XCTAssertEqualWithAccuracy(sz, 0.0f, 1e-3f);
}

/*! @abstract The public scalar evaluator reproduces the direct reference exactly on the current path. */
- (void)testPublicFieldMatchesDirect
{
	const uint32_t n = 200;
	float x[200], y[200], z[200], s[200];
	float ea[200], eb[200], ec[200], da[200], db[200], dc[200];
	uint32_t state = 999u;
	for (uint32_t i = 0; i < n; i++) {
		state = state * 1664525u + 1013904223u; x[i] = (float)(state >> 9) / 4194304.0f - 1.0f;
		state = state * 1664525u + 1013904223u; y[i] = (float)(state >> 9) / 4194304.0f - 1.0f;
		state = state * 1664525u + 1013904223u; z[i] = (float)(state >> 9) / 4194304.0f - 1.0f;
		s[i] = (i % 3 == 0) ? 2.0f : 1.0f;
	}
	FxGripFMMParameters parameters = FxGripFMMDefaultParameters();
	FxGripFMMContext *context = FxGripFMMContextCreate();

	FxGripFMMEvaluateField(context, &parameters, n, x, y, z, s, ea, eb, ec);
	FxGripFMMEvaluateFieldDirect(n, parameters.softening, x, y, z, s, da, db, dc);

	for (uint32_t i = 0; i < n; i++) {
		XCTAssertEqual(ea[i], da[i]);
		XCTAssertEqual(eb[i], db[i]);
		XCTAssertEqual(ec[i], dc[i]);
	}
	FxGripFMMContextDestroy(context);
}

#pragma mark Biot-Savart reference

/*! @abstract A source moving along +x, offset along +y, makes a magnetic field along −z at the target. */
- (void)testBiotSavartTwoBodyDirection
{
	// Source at origin moving +x; target at +y. r = target − source = +y. v × r = x̂ × ŷ = ẑ,
	// so B points along +z at the target.
	const float x[2] = {0.0f, 0.0f};
	const float y[2] = {0.0f, 1.0f};
	const float z[2] = {0.0f, 0.0f};
	const float s[2] = {1.0f, 0.0f};
	const float vx[2] = {1.0f, 0.0f};
	const float vy[2] = {0.0f, 0.0f};
	const float vz[2] = {0.0f, 0.0f};
	float bx[2], by[2], bz[2];

	FxGripFMMEvaluateBiotSavartDirect(2, 1e-3f, x, y, z, s, vx, vy, vz, bx, by, bz);

	// The target at +y (index 1) is the one with a nonzero source (index 0, strength 1).
	XCTAssertGreaterThan(bz[1], 0.1f, @"the moving source drives a +z field at the target");
	XCTAssertEqualWithAccuracy(bx[1], 0.0f, 1e-6f);
	XCTAssertEqualWithAccuracy(by[1], 0.0f, 1e-6f);
}

/*! @abstract The adaptive Biot-Savart field matches its direct reference at scale, and is deterministic. */
- (void)testAdaptiveBiotSavartMatchesDirect
{
	const uint32_t n = 3000;
	float *x = malloc(4*n), *y = malloc(4*n), *z = malloc(4*n), *s = malloc(4*n);
	float *vx = malloc(4*n), *vy = malloc(4*n), *vz = malloc(4*n);
	[self fillCloud:x count:n seed:1 span:20.0f];
	[self fillCloud:y count:n seed:2 span:20.0f];
	[self fillCloud:z count:n seed:3 span:20.0f];
	[self fillCloud:vx count:n seed:4 span:2.0f];
	[self fillCloud:vy count:n seed:5 span:2.0f];
	[self fillCloud:vz count:n seed:6 span:2.0f];
	for (uint32_t i = 0; i < n; i++) { s[i] = 1.0f; }

	FxGripFMMParameters p = FxGripFMMDefaultParameters();
	p.directThreshold = 256;
	FxGripFMMContext *ctx = FxGripFMMContextCreate();

	float *bx = malloc(4*n), *by = malloc(4*n), *bz = malloc(4*n);
	float *dx = malloc(4*n), *dy = malloc(4*n), *dz = malloc(4*n);
	float *ex = malloc(4*n), *ey = malloc(4*n), *ez = malloc(4*n);
	FxGripFMMEvaluateBiotSavart(ctx, &p, n, x, y, z, s, vx, vy, vz, bx, by, bz);
	FxGripFMMEvaluateBiotSavartDirect(n, p.softening, x, y, z, s, vx, vy, vz, dx, dy, dz);

	double num = 0, den = 0;
	for (uint32_t i = 0; i < n; i++) {
		double ax = bx[i]-dx[i], ay = by[i]-dy[i], az = bz[i]-dz[i];
		num += ax*ax+ay*ay+az*az;
		den += (double)dx[i]*dx[i]+(double)dy[i]*dy[i]+(double)dz[i]*dz[i];
	}
	XCTAssertLessThan(sqrt(num/(den+1e-30)), 5e-3f, @"adaptive Biot-Savart relative L2 error");

	// Deterministic and byte-identical to a repeat.
	FxGripFMMEvaluateBiotSavart(ctx, &p, n, x, y, z, s, vx, vy, vz, ex, ey, ez);
	XCTAssertEqual(0, memcmp(bx, ex, 4*n));
	XCTAssertEqual(0, memcmp(by, ey, 4*n));
	XCTAssertEqual(0, memcmp(bz, ez, 4*n));

	FxGripFMMContextDestroy(ctx);
	free(x); free(y); free(z); free(s); free(vx); free(vy); free(vz);
	free(bx); free(by); free(bz); free(dx); free(dy); free(dz); free(ex); free(ey); free(ez);
}

/*! @abstract The public Biot-Savart evaluator reproduces its direct reference exactly on the current path. */
- (void)testPublicBiotSavartMatchesDirect
{
	const uint32_t n = 128;
	float x[128], y[128], z[128], s[128], vx[128], vy[128], vz[128];
	float ba[128], bb[128], bc[128], da[128], db[128], dc[128];
	uint32_t state = 4242u;
	for (uint32_t i = 0; i < n; i++) {
		state = state * 1664525u + 1013904223u; x[i] = (float)(state >> 9) / 4194304.0f - 1.0f;
		state = state * 1664525u + 1013904223u; y[i] = (float)(state >> 9) / 4194304.0f - 1.0f;
		state = state * 1664525u + 1013904223u; z[i] = (float)(state >> 9) / 4194304.0f - 1.0f;
		state = state * 1664525u + 1013904223u; vx[i] = (float)(state >> 9) / 4194304.0f - 1.0f;
		state = state * 1664525u + 1013904223u; vy[i] = (float)(state >> 9) / 4194304.0f - 1.0f;
		state = state * 1664525u + 1013904223u; vz[i] = (float)(state >> 9) / 4194304.0f - 1.0f;
		s[i] = 1.0f;
	}
	FxGripFMMParameters parameters = FxGripFMMDefaultParameters();
	FxGripFMMContext *context = FxGripFMMContextCreate();

	FxGripFMMEvaluateBiotSavart(context, &parameters, n, x, y, z, s, vx, vy, vz, ba, bb, bc);
	FxGripFMMEvaluateBiotSavartDirect(n, parameters.softening, x, y, z, s, vx, vy, vz, da, db, dc);

	for (uint32_t i = 0; i < n; i++) {
		XCTAssertEqual(ba[i], da[i]);
		XCTAssertEqual(bb[i], db[i]);
		XCTAssertEqual(bc[i], dc[i]);
	}
	FxGripFMMContextDestroy(context);
}

#pragma mark Context and defaults

/*! @abstract The default parameters are the plan's values. */
- (void)testDefaultParameters
{
	FxGripFMMParameters parameters = FxGripFMMDefaultParameters();
	XCTAssertEqual(parameters.expansionOrder, 4u);
	XCTAssertEqualWithAccuracy(parameters.theta, 0.5f, 1e-6f);
	XCTAssertEqual(parameters.leafCapacity, 64u);
	XCTAssertEqual(parameters.directThreshold, 2048u);
}

/*! @abstract A context is created and destroyed cleanly, and NULL is tolerated. */
- (void)testContextLifecycle
{
	FxGripFMMContext *context = FxGripFMMContextCreate();
	XCTAssertTrue(context != NULL);
	XCTAssertEqual(FxGripFMMContextArenaHighWaterMark(context), 0u);
	FxGripFMMContextDestroy(context);
	FxGripFMMContextDestroy(NULL);
	XCTAssertEqual(FxGripFMMContextArenaHighWaterMark(NULL), 0u);
}

/*! @abstract Zero particles and NULL arrays are no-ops, not crashes. */
- (void)testEmptyAndNullAreNoOps
{
	float out[1] = {7.0f};
	FxGripFMMEvaluateFieldDirect(0, 1e-3f, NULL, NULL, NULL, NULL, out, out, out);
	XCTAssertEqual(out[0], 7.0f);
}

#pragma mark Adaptive field vs direct

- (void)fillCloud:(float *)a count:(uint32_t)n seed:(uint32_t)seed span:(float)span
{
	uint32_t state = seed;
	for (uint32_t i = 0; i < n; i++) {
		state = state * 1664525u + 1013904223u;
		a[i] = ((float)(state >> 8) / 16777216.0f - 0.5f) * span;
	}
}

- (float)relL2FMMOrder:(uint32_t)order n:(uint32_t)n clustered:(BOOL)clustered
{
	float *x = malloc(4*n), *y = malloc(4*n), *z = malloc(4*n), *s = malloc(4*n);
	[self fillCloud:x count:n seed:1u span:20.0f];
	[self fillCloud:y count:n seed:2u span:20.0f];
	[self fillCloud:z count:n seed:3u span:20.0f];
	for (uint32_t i = 0; i < n; i++) { s[i] = 1.0f; }
	if (clustered) {
		// Pull a portion into a tight knot to exercise depth and adaptivity.
		for (uint32_t i = 0; i < n/2; i++) { x[i] *= 0.02f; y[i] *= 0.02f; z[i] *= 0.02f; }
	}

	FxGripFMMParameters p = FxGripFMMDefaultParameters();
	p.expansionOrder = order;
	p.directThreshold = 256; // force the adaptive path
	FxGripFMMContext *ctx = FxGripFMMContextCreate();

	float *fx = malloc(4*n), *fy = malloc(4*n), *fz = malloc(4*n);
	float *dx = malloc(4*n), *dy = malloc(4*n), *dz = malloc(4*n);
	FxGripFMMEvaluateField(ctx, &p, n, x, y, z, s, fx, fy, fz);
	FxGripFMMEvaluateFieldDirect(n, p.softening, x, y, z, s, dx, dy, dz);

	double num = 0, den = 0;
	for (uint32_t i = 0; i < n; i++) {
		double ax = fx[i]-dx[i], ay = fy[i]-dy[i], az = fz[i]-dz[i];
		num += ax*ax+ay*ay+az*az;
		den += (double)dx[i]*dx[i]+(double)dy[i]*dy[i]+(double)dz[i]*dz[i];
	}
	FxGripFMMContextDestroy(ctx);
	free(x); free(y); free(z); free(s);
	free(fx); free(fy); free(fz); free(dx); free(dy); free(dz);
	return (float)sqrt(num / (den + 1e-30));
}

/*! @abstract The adaptive field matches direct summation, more closely as the order rises. */
- (void)testAdaptiveFieldMatchesDirect
{
	float e2 = [self relL2FMMOrder:2 n:3000 clustered:NO];
	float e4 = [self relL2FMMOrder:4 n:3000 clustered:NO];
	XCTAssertLessThan(e2, 3e-2f, @"order 2 relative L2 error");
	XCTAssertLessThan(e4, 3e-3f, @"order 4 relative L2 error");
	XCTAssertLessThan(e4, e2, @"order 4 is more accurate than order 2");
}

/*! @abstract The adaptive field stays accurate on a clustered distribution, where the tree runs deep. */
- (void)testAdaptiveFieldMatchesDirectClustered
{
	float e4 = [self relL2FMMOrder:4 n:4000 clustered:YES];
	XCTAssertLessThan(e4, 5e-3f, @"order 4 relative L2 error, clustered");
}

/*! @abstract The per-point field query matches direct summation at the source points and at fresh points. */
- (void)testPerPointFieldQueryMatchesDirect
{
	const uint32_t n = 3000;
	float *x = malloc(4*n), *y = malloc(4*n), *z = malloc(4*n), *s = malloc(4*n);
	[self fillCloud:x count:n seed:41 span:20.0f];
	[self fillCloud:y count:n seed:42 span:20.0f];
	[self fillCloud:z count:n seed:43 span:20.0f];
	for (uint32_t i = 0; i < n; i++) { s[i] = 1.0f; }

	FxGripFMMParameters p = FxGripFMMDefaultParameters();
	p.expansionOrder = 4;
	FxGripFMMContext *ctx = FxGripFMMContextCreate();
	FxGripFMMField *field = FxGripFMMFieldBuild(ctx, &p, n, x, y, z, s);
	XCTAssertTrue(field != NULL);

	// Reference: the self-field via the direct sum (self term excluded by the softened zero).
	float *dx = malloc(4*n), *dy = malloc(4*n), *dz = malloc(4*n);
	FxGripFMMEvaluateFieldDirect(n, p.softening, x, y, z, s, dx, dy, dz);

	// Query at each source point and compare.
	double num = 0, den = 0;
	for (uint32_t i = 0; i < n; i++) {
		float ex, ey, ez;
		FxGripFMMFieldEvaluateAt(field, x[i], y[i], z[i], &ex, &ey, &ez);
		double ax = ex-dx[i], ay = ey-dy[i], az = ez-dz[i];
		num += ax*ax+ay*ay+az*az;
		den += (double)dx[i]*dx[i]+(double)dy[i]*dy[i]+(double)dz[i]*dz[i];
	}
	XCTAssertLessThan(sqrt(num/(den+1e-30)), 1e-2, @"per-point query vs direct at source points");

	// Query at a fresh point and compare to a hand sum.
	float tx = 3.3f, ty = -2.1f, tz = 4.7f, ex, ey, ez;
	FxGripFMMFieldEvaluateAt(field, tx, ty, tz, &ex, &ey, &ez);
	double rx=0, ry=0, rz=0; const double eps2 = (double)p.softening*p.softening;
	for (uint32_t j = 0; j < n; j++) {
		double ddx=x[j]-tx, ddy=y[j]-ty, ddz=z[j]-tz, r2=ddx*ddx+ddy*ddy+ddz*ddz+eps2;
		double w=s[j]/(r2*sqrt(r2)); rx+=w*ddx; ry+=w*ddy; rz+=w*ddz;
	}
	double diff = sqrt((ex-rx)*(ex-rx)+(ey-ry)*(ey-ry)+(ez-rz)*(ez-rz));
	double mag = sqrt(rx*rx+ry*ry+rz*rz)+1e-20;
	// One sample rather than an aggregate, and inside a cloud the net field is a small residue of
	// large opposed terms, so a single point's relative error runs wider than the L2 above.
	XCTAssertLessThan(diff/mag, 2e-2, @"per-point query vs direct at a fresh point");

	FxGripFMMFieldDestroy(field);
	FxGripFMMContextDestroy(ctx);
	free(x); free(y); free(z); free(s); free(dx); free(dy); free(dz);
}

/*! @abstract At or below the direct threshold the adaptive entry point equals the direct sum bitwise. */
- (void)testBelowThresholdMatchesDirectExactly
{
	const uint32_t n = 200;
	float *x = malloc(4*n), *y = malloc(4*n), *z = malloc(4*n), *s = malloc(4*n);
	[self fillCloud:x count:n seed:5 span:8.0f];
	[self fillCloud:y count:n seed:6 span:8.0f];
	[self fillCloud:z count:n seed:7 span:8.0f];
	for (uint32_t i = 0; i < n; i++) { s[i] = 1.0f; }
	FxGripFMMParameters p = FxGripFMMDefaultParameters(); // directThreshold 2048 > n
	FxGripFMMContext *ctx = FxGripFMMContextCreate();
	float *fx = malloc(4*n), *fy = malloc(4*n), *fz = malloc(4*n);
	float *dx = malloc(4*n), *dy = malloc(4*n), *dz = malloc(4*n);
	FxGripFMMEvaluateField(ctx, &p, n, x, y, z, s, fx, fy, fz);
	FxGripFMMEvaluateFieldDirect(n, p.softening, x, y, z, s, dx, dy, dz);
	XCTAssertEqual(0, memcmp(fx, dx, 4*n));
	XCTAssertEqual(0, memcmp(fy, dy, 4*n));
	XCTAssertEqual(0, memcmp(fz, dz, 4*n));
	FxGripFMMContextDestroy(ctx);
	free(x); free(y); free(z); free(s);
	free(fx); free(fy); free(fz); free(dx); free(dy); free(dz);
}

/*! @abstract The adaptive field is deterministic: two evaluations are byte-identical. */
- (void)testAdaptiveFieldDeterministic
{
	const uint32_t n = 3000;
	float *x = malloc(4*n), *y = malloc(4*n), *z = malloc(4*n), *s = malloc(4*n);
	[self fillCloud:x count:n seed:11 span:15.0f];
	[self fillCloud:y count:n seed:12 span:15.0f];
	[self fillCloud:z count:n seed:13 span:15.0f];
	for (uint32_t i = 0; i < n; i++) { s[i] = 1.0f; }
	FxGripFMMParameters p = FxGripFMMDefaultParameters();
	p.directThreshold = 256;
	FxGripFMMContext *ctx = FxGripFMMContextCreate();
	float *a = malloc(4*n), *b = malloc(4*n), *c = malloc(4*n);
	float *d = malloc(4*n), *e = malloc(4*n), *f = malloc(4*n);
	FxGripFMMEvaluateField(ctx, &p, n, x, y, z, s, a, b, c);
	FxGripFMMEvaluateField(ctx, &p, n, x, y, z, s, d, e, f);
	XCTAssertEqual(0, memcmp(a, d, 4*n));
	XCTAssertEqual(0, memcmp(b, e, 4*n));
	XCTAssertEqual(0, memcmp(c, f, 4*n));
	FxGripFMMContextDestroy(ctx);
	free(x); free(y); free(z); free(s);
	free(a); free(b); free(c); free(d); free(e); free(f);
}

/*! @abstract A warm evaluation at the same size allocates nothing: the context reuses its arena and buffers. */
- (void)testWarmEvaluationDoesNotAllocate
{
	const uint32_t n = 4000;
	float *x = malloc(4*n), *y = malloc(4*n), *z = malloc(4*n), *s = malloc(4*n);
	[self fillCloud:x count:n seed:31 span:16.0f];
	[self fillCloud:y count:n seed:32 span:16.0f];
	[self fillCloud:z count:n seed:33 span:16.0f];
	for (uint32_t i = 0; i < n; i++) { s[i] = 1.0f; }
	FxGripFMMParameters p = FxGripFMMDefaultParameters();
	p.directThreshold = 256;
	FxGripFMMContext *ctx = FxGripFMMContextCreate();
	float *ex = malloc(4*n), *ey = malloc(4*n), *ez = malloc(4*n);

	FxGripFMMEvaluateField(ctx, &p, n, x, y, z, s, ex, ey, ez); // warm: builds tables, grows buffers
	uint64_t afterWarm = FxGripFMMContextAllocationCount(ctx);
	for (int i = 0; i < 5; i++) {
		FxGripFMMEvaluateField(ctx, &p, n, x, y, z, s, ex, ey, ez);
	}
	XCTAssertEqual(FxGripFMMContextAllocationCount(ctx), afterWarm, @"warm same-sized calls allocate nothing");

	FxGripFMMContextDestroy(ctx);
	free(x); free(y); free(z); free(s); free(ex); free(ey); free(ez);
}

/*! @abstract The parallel and single-threaded evaluations are byte-identical, so the result does not depend on thread count. */
- (void)testThreadCountDoesNotChangeResult
{
	const uint32_t n = 5000;
	float *x = malloc(4*n), *y = malloc(4*n), *z = malloc(4*n), *s = malloc(4*n);
	[self fillCloud:x count:n seed:21 span:18.0f];
	[self fillCloud:y count:n seed:22 span:18.0f];
	[self fillCloud:z count:n seed:23 span:18.0f];
	for (uint32_t i = 0; i < n; i++) { s[i] = (i % 4 == 0) ? 2.0f : 1.0f; }
	FxGripFMMContext *ctx = FxGripFMMContextCreate();

	FxGripFMMParameters one = FxGripFMMDefaultParameters();
	one.directThreshold = 256; one.maxThreads = 1;
	FxGripFMMParameters many = one; many.maxThreads = 0; // all cores

	float *a = malloc(4*n), *b = malloc(4*n), *c = malloc(4*n);
	float *d = malloc(4*n), *e = malloc(4*n), *f = malloc(4*n);
	FxGripFMMEvaluateField(ctx, &one, n, x, y, z, s, a, b, c);
	FxGripFMMEvaluateField(ctx, &many, n, x, y, z, s, d, e, f);
	XCTAssertEqual(0, memcmp(a, d, 4*n), @"parallel equals sequential in x");
	XCTAssertEqual(0, memcmp(b, e, 4*n), @"parallel equals sequential in y");
	XCTAssertEqual(0, memcmp(c, f, 4*n), @"parallel equals sequential in z");
	FxGripFMMContextDestroy(ctx);
	free(x); free(y); free(z); free(s);
	free(a); free(b); free(c); free(d); free(e); free(f);
}

@end
