/*!
	@file       FxGripFMMExpansionTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-08
	@header     FxGripFMMExpansionTests
	@abstract   Tests for the Cartesian multipole machinery.
	@discussion Introduced in FxGrip 0.1.0. The symbolic derivatives of 1/r are checked against their
	            closed forms. A single source at the expansion center reproduces the exact field. A
	            clustered source set expanded and evaluated at a distance matches direct summation, with
	            the error falling as the order rises and as the target moves away. The module is a
	            private core component, so its header is imported by path.
*/

#import <XCTest/XCTest.h>
#import "../../FxGrip/Space/FxGripFMMExpansion.h"
#import <math.h>

@interface FxGripFMMExpansionTests : XCTestCase
@end

@implementation FxGripFMMExpansionTests

// Direct field at targets from sources, no softening: the reference for the multipole.
- (void)directFieldTx:(const float *)tx ty:(const float *)ty tz:(const float *)tz count:(uint32_t)nt
				   sx:(const float *)sx sy:(const float *)sy sz:(const float *)sz ss:(const float *)ss sn:(uint32_t)ns
				   ex:(float *)ex ey:(float *)ey ez:(float *)ez
{
	for (uint32_t i = 0; i < nt; i++) {
		double fx = 0, fy = 0, fz = 0;
		for (uint32_t j = 0; j < ns; j++) {
			double dx = sx[j]-tx[i], dy = sy[j]-ty[i], dz = sz[j]-tz[i];
			double r2 = dx*dx+dy*dy+dz*dz;
			double w = ss[j] / (r2 * sqrt(r2));
			fx += w*dx; fy += w*dy; fz += w*dz;
		}
		ex[i] = (float)fx; ey[i] = (float)fy; ez[i] = (float)fz;
	}
}

/*! @abstract The symbolic derivatives of 1/r match their closed forms. */
- (void)testDerivativesMatchClosedForm
{
	FxGripFMMExpansionTables *t = FxGripFMMExpansionTablesCreate(4);
	const float x = 0.7f, y = -1.3f, z = 0.5f;
	const double r2 = (double)x*x + (double)y*y + (double)z*z;
	const double r = sqrt(r2);
	float *d = malloc(sizeof(float) * FxGripFMMExpansionDerivativeCount(t));
	FxGripFMMEvalDerivatives(t, x, y, z, d);

	// g = 1/r
	XCTAssertEqualWithAccuracy(d[FxGripFMMDerivativeIndex(t,0,0,0)], (float)(1.0/r), 1e-5f);
	// d/dx = -x/r^3
	XCTAssertEqualWithAccuracy(d[FxGripFMMDerivativeIndex(t,1,0,0)], (float)(-x/(r2*r)), 1e-5f);
	XCTAssertEqualWithAccuracy(d[FxGripFMMDerivativeIndex(t,0,1,0)], (float)(-y/(r2*r)), 1e-5f);
	// d2/dx2 = (3x^2 - r^2)/r^5
	double r5 = r2*r2*r;
	XCTAssertEqualWithAccuracy(d[FxGripFMMDerivativeIndex(t,2,0,0)], (float)((3.0*x*x - r2)/r5), 1e-5f);
	// d2/dxdy = 3xy/r^5
	XCTAssertEqualWithAccuracy(d[FxGripFMMDerivativeIndex(t,1,1,0)], (float)(3.0*x*y/r5), 1e-5f);
	XCTAssertEqualWithAccuracy(d[FxGripFMMDerivativeIndex(t,0,1,1)], (float)(3.0*y*z/r5), 1e-5f);

	// Laplacian of 1/r is zero away from the origin: d2/dx2 + d2/dy2 + d2/dz2 = 0.
	float lap = d[FxGripFMMDerivativeIndex(t,2,0,0)] + d[FxGripFMMDerivativeIndex(t,0,2,0)] + d[FxGripFMMDerivativeIndex(t,0,0,2)];
	XCTAssertEqualWithAccuracy(lap, 0.0f, 1e-4f);

	free(d);
	FxGripFMMExpansionTablesDestroy(t);
}

/*! @abstract A single source at the expansion center reproduces the exact field, since only the monopole survives. */
- (void)testMonopoleAtCenterIsExact
{
	FxGripFMMExpansionTables *t = FxGripFMMExpansionTablesCreate(4);
	const float cx = 1.0f, cy = 2.0f, cz = -0.5f;
	float sx = cx, sy = cy, sz = cz, ss = 3.0f; // source exactly at center

	float *m = calloc(FxGripFMMExpansionMomentCount(t), sizeof(float));
	FxGripFMMP2M(t, cx, cy, cz, &sx, &sy, &sz, &ss, 1, m);

	float tx = 5.0f, ty = -3.0f, tz = 4.0f;
	float ex = 0, ey = 0, ez = 0;
	FxGripFMMM2PField(t, cx, cy, cz, m, &tx, &ty, &tz, &ex, &ey, &ez, 1);

	float dx = 0, dy = 0, dz = 0;
	[self directFieldTx:&tx ty:&ty tz:&tz count:1 sx:&sx sy:&sy sz:&sz ss:&ss sn:1 ex:&dx ey:&dy ez:&dz];

	XCTAssertEqualWithAccuracy(ex, dx, 1e-4f);
	XCTAssertEqualWithAccuracy(ey, dy, 1e-4f);
	XCTAssertEqualWithAccuracy(ez, dz, 1e-4f);
	free(m);
	FxGripFMMExpansionTablesDestroy(t);
}

- (float)clusterErrorAtOrder:(uint32_t)order separation:(float)sep
{
	const uint32_t ns = 60;
	float sx[60], sy[60], sz[60], ss[60];
	uint32_t state = 4242u;
	const float cx = 0, cy = 0, cz = 0, rc = 1.0f;
	for (uint32_t j = 0; j < ns; j++) {
		state = state*1664525u+1013904223u; sx[j] = ((float)(state>>8)/16777216.0f-0.5f)*2.0f*rc;
		state = state*1664525u+1013904223u; sy[j] = ((float)(state>>8)/16777216.0f-0.5f)*2.0f*rc;
		state = state*1664525u+1013904223u; sz[j] = ((float)(state>>8)/16777216.0f-0.5f)*2.0f*rc;
		ss[j] = 1.0f;
	}
	// Targets on a shell at distance `sep` from the cluster center.
	const uint32_t nt = 8;
	float tx[8], ty[8], tz[8];
	for (uint32_t i = 0; i < nt; i++) {
		float th = (float)i * 0.9f, ph = (float)i * 1.7f;
		tx[i] = cx + sep * cosf(th) * sinf(ph);
		ty[i] = cy + sep * sinf(th) * sinf(ph);
		tz[i] = cz + sep * cosf(ph);
	}

	FxGripFMMExpansionTables *t = FxGripFMMExpansionTablesCreate(order);
	float *m = calloc(FxGripFMMExpansionMomentCount(t), sizeof(float));
	FxGripFMMP2M(t, cx, cy, cz, sx, sy, sz, ss, ns, m);

	float ex[8] = {0}, ey[8] = {0}, ez[8] = {0};
	FxGripFMMM2PField(t, cx, cy, cz, m, tx, ty, tz, ex, ey, ez, nt);

	float dx[8], dy[8], dz[8];
	[self directFieldTx:tx ty:ty tz:tz count:nt sx:sx sy:sy sz:sz ss:ss sn:ns ex:dx ey:dy ez:dz];

	float worst = 0;
	for (uint32_t i = 0; i < nt; i++) {
		float diff = sqrtf((ex[i]-dx[i])*(ex[i]-dx[i])+(ey[i]-dy[i])*(ey[i]-dy[i])+(ez[i]-dz[i])*(ez[i]-dz[i]));
		float mag = sqrtf(dx[i]*dx[i]+dy[i]*dy[i]+dz[i]*dz[i])+1e-20f;
		worst = fmaxf(worst, diff/mag);
	}
	free(m);
	FxGripFMMExpansionTablesDestroy(t);
	return worst;
}

/*! @abstract The multipole field matches direct summation, and the error falls as the order rises. */
- (void)testMultipoleAccuracyImprovesWithOrder
{
	// Cluster radius 1, targets at distance 4: acceptance ratio 0.25.
	float e2 = [self clusterErrorAtOrder:2 separation:4.0f];
	float e4 = [self clusterErrorAtOrder:4 separation:4.0f];
	float e6 = [self clusterErrorAtOrder:6 separation:4.0f];

	XCTAssertLessThan(e2, 1e-2f, @"order 2 within 1e-2 at ratio 0.25");
	XCTAssertLessThan(e4, 1e-3f, @"order 4 within 1e-3 at ratio 0.25");
	XCTAssertLessThan(e4, e2, @"order 4 beats order 2");
	XCTAssertLessThan(e6, e4, @"order 6 beats order 4");
}

/*! @abstract The error falls as the target moves away from the cluster. */
- (void)testMultipoleAccuracyImprovesWithDistance
{
	float near = [self clusterErrorAtOrder:4 separation:3.0f];
	float far = [self clusterErrorAtOrder:4 separation:8.0f];
	XCTAssertLessThan(far, near, @"a more distant target is more accurate");
}

/*! @abstract Term counts follow the closed form. */
- (void)testTermCount
{
	XCTAssertEqual(FxGripFMMTermCount(0), 1u);
	XCTAssertEqual(FxGripFMMTermCount(2), 10u);
	XCTAssertEqual(FxGripFMMTermCount(4), 35u);
	XCTAssertEqual(FxGripFMMTermCount(6), 84u);
}

@end
