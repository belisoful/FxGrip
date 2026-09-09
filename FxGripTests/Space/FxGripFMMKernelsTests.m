/*!
	@file       FxGripFMMKernelsTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-08
	@header     FxGripFMMKernelsTests
	@abstract   Tests for the FMM particle kernels.
	@discussion Introduced in FxGrip 0.1.0. The P2P kernel is checked against the accurate direct
	            reference across block-aligned and partial target counts, for self-interaction where a
	            range is its own source, and for its accumulation contract. The kernels are private core
	            components, so their header is imported by path.
*/

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripFMM.h>
#import "../../FxGrip/Space/FxGripFMMKernels.h"
#import <math.h>

@interface FxGripFMMKernelsTests : XCTestCase
@end

@implementation FxGripFMMKernelsTests

- (void)fillRandom:(float *)a count:(uint32_t)n seed:(uint32_t)seed span:(float)span
{
	uint32_t state = seed;
	for (uint32_t i = 0; i < n; i++) {
		state = state * 1664525u + 1013904223u;
		a[i] = ((float)(state >> 8) / 16777216.0f - 0.5f) * span;
	}
}

// The largest relative difference between two field vectors over all targets.
- (float)maxRelErrorA:(const float *)ax ay:(const float *)ay az:(const float *)az
					 bx:(const float *)bx by:(const float *)by bz:(const float *)bz count:(uint32_t)n
{
	float worst = 0.0f;
	for (uint32_t i = 0; i < n; i++) {
		float dx = ax[i] - bx[i], dy = ay[i] - by[i], dz = az[i] - bz[i];
		float diff = sqrtf(dx * dx + dy * dy + dz * dz);
		float mag = sqrtf(bx[i] * bx[i] + by[i] * by[i] + bz[i] * bz[i]) + 1e-20f;
		float rel = diff / mag;
		worst = rel > worst ? rel : worst;
	}
	return worst;
}

/*! @abstract Self-interaction over one set matches the accurate direct reference. */
- (void)testSelfInteractionMatchesDirect
{
	for (uint32_t n = 1; n <= 300; n = (n < 16 ? n + 1 : n + 37)) {
		float *x = malloc(4 * n), *y = malloc(4 * n), *z = malloc(4 * n), *s = malloc(4 * n);
		[self fillRandom:x count:n seed:11u + n span:4.0f];
		[self fillRandom:y count:n seed:22u + n span:4.0f];
		[self fillRandom:z count:n seed:33u + n span:4.0f];
		for (uint32_t i = 0; i < n; i++) { s[i] = 1.0f; }

		const float eps = 1e-2f;
		float *ex = calloc(n, 4), *ey = calloc(n, 4), *ez = calloc(n, 4);
		float *dx = malloc(4 * n), *dy = malloc(4 * n), *dz = malloc(4 * n);

		FxGripFMMFieldP2P(x, y, z, ex, ey, ez, n, x, y, z, s, n, eps * eps);
		FxGripFMMEvaluateFieldDirect(n, eps, x, y, z, s, dx, dy, dz);

		float rel = [self maxRelErrorA:ex ay:ey az:ez bx:dx by:dy bz:dz count:n];
		XCTAssertLessThan(rel, 5e-5f, @"n=%u self P2P vs direct", n);

		free(x); free(y); free(z); free(s);
		free(ex); free(ey); free(ez); free(dx); free(dy); free(dz);
	}
}

/*! @abstract Two disjoint sets: the target field from the sources matches a hand-summed reference. */
- (void)testDisjointSetsMatchReference
{
	const uint32_t nt = 50, ns = 70;
	float *tx = malloc(4*nt), *ty = malloc(4*nt), *tz = malloc(4*nt);
	float *sx = malloc(4*ns), *sy = malloc(4*ns), *sz = malloc(4*ns), *ss = malloc(4*ns);
	[self fillRandom:tx count:nt seed:1 span:2.0f];
	[self fillRandom:ty count:nt seed:2 span:2.0f];
	[self fillRandom:tz count:nt seed:3 span:2.0f];
	[self fillRandom:sx count:ns seed:4 span:2.0f];
	[self fillRandom:sy count:ns seed:5 span:2.0f];
	[self fillRandom:sz count:ns seed:6 span:2.0f];
	for (uint32_t j = 0; j < ns; j++) { ss[j] = (j % 2) ? 1.0f : 2.0f; }

	const float eps2 = 1e-4f;
	float *ex = calloc(nt,4), *ey = calloc(nt,4), *ez = calloc(nt,4);
	FxGripFMMFieldP2P(tx, ty, tz, ex, ey, ez, nt, sx, sy, sz, ss, ns, eps2);

	for (uint32_t i = 0; i < nt; i++) {
		float rx = 0, ry = 0, rz = 0;
		for (uint32_t j = 0; j < ns; j++) {
			float dx = sx[j]-tx[i], dy = sy[j]-ty[i], dz = sz[j]-tz[i];
			float r2 = dx*dx+dy*dy+dz*dz+eps2;
			float w = ss[j] / (r2 * sqrtf(r2));
			rx += w*dx; ry += w*dy; rz += w*dz;
		}
		float mag = sqrtf(rx*rx+ry*ry+rz*rz)+1e-20f;
		float diff = sqrtf((ex[i]-rx)*(ex[i]-rx)+(ey[i]-ry)*(ey[i]-ry)+(ez[i]-rz)*(ez[i]-rz));
		XCTAssertLessThan(diff/mag, 5e-5f, @"target %u", i);
	}
	free(tx); free(ty); free(tz); free(sx); free(sy); free(sz); free(ss);
	free(ex); free(ey); free(ez);
}

/*! @abstract The kernel accumulates: two half-source calls equal one whole-source call. */
- (void)testAccumulatesAcrossCalls
{
	const uint32_t nt = 24, ns = 40;
	float *tx = malloc(4*nt), *ty = malloc(4*nt), *tz = malloc(4*nt);
	float *sx = malloc(4*ns), *sy = malloc(4*ns), *sz = malloc(4*ns), *ss = malloc(4*ns);
	[self fillRandom:tx count:nt seed:7 span:3.0f];
	[self fillRandom:ty count:nt seed:8 span:3.0f];
	[self fillRandom:tz count:nt seed:9 span:3.0f];
	[self fillRandom:sx count:ns seed:10 span:3.0f];
	[self fillRandom:sy count:ns seed:11 span:3.0f];
	[self fillRandom:sz count:ns seed:12 span:3.0f];
	for (uint32_t j = 0; j < ns; j++) { ss[j] = 1.0f; }
	const float eps2 = 1e-3f;

	float *wx = calloc(nt,4), *wy = calloc(nt,4), *wz = calloc(nt,4);
	FxGripFMMFieldP2P(tx,ty,tz, wx,wy,wz, nt, sx,sy,sz,ss, ns, eps2);

	float *px = calloc(nt,4), *py = calloc(nt,4), *pz = calloc(nt,4);
	uint32_t half = ns / 2;
	FxGripFMMFieldP2P(tx,ty,tz, px,py,pz, nt, sx,sy,sz,ss, half, eps2);
	FxGripFMMFieldP2P(tx,ty,tz, px,py,pz, nt, sx+half,sy+half,sz+half,ss+half, ns-half, eps2);

	// Splitting the sources across two calls sums the same terms, but float addition is not
	// associative, so the grouping differs in the last bits. The contract is additive accumulation,
	// checked to a relative tolerance rather than bit equality.
	for (uint32_t i = 0; i < nt; i++) {
		float diff = sqrtf((px[i]-wx[i])*(px[i]-wx[i]) + (py[i]-wy[i])*(py[i]-wy[i]) + (pz[i]-wz[i])*(pz[i]-wz[i]));
		float mag = sqrtf(wx[i]*wx[i] + wy[i]*wy[i] + wz[i]*wz[i]) + 1e-20f;
		XCTAssertLessThan(diff / mag, 1e-4f, @"target %u accumulates additively", i);
	}
	free(tx); free(ty); free(tz); free(sx); free(sy); free(sz); free(ss);
	free(wx); free(wy); free(wz); free(px); free(py); free(pz);
}

/*! @abstract The kernel is deterministic: the same inputs give byte-identical output twice. */
- (void)testDeterministic
{
	const uint32_t n = 133;
	float *x = malloc(4*n), *y = malloc(4*n), *z = malloc(4*n), *s = malloc(4*n);
	[self fillRandom:x count:n seed:101 span:5.0f];
	[self fillRandom:y count:n seed:102 span:5.0f];
	[self fillRandom:z count:n seed:103 span:5.0f];
	for (uint32_t i = 0; i < n; i++) { s[i] = 1.0f; }
	const float eps2 = 1e-3f;

	float *a1 = calloc(n,4), *a2 = calloc(n,4), *a3 = calloc(n,4);
	float *b1 = calloc(n,4), *b2 = calloc(n,4), *b3 = calloc(n,4);
	FxGripFMMFieldP2P(x,y,z, a1,a2,a3, n, x,y,z,s, n, eps2);
	FxGripFMMFieldP2P(x,y,z, b1,b2,b3, n, x,y,z,s, n, eps2);
	XCTAssertEqual(0, memcmp(a1, b1, 4*n));
	XCTAssertEqual(0, memcmp(a2, b2, 4*n));
	XCTAssertEqual(0, memcmp(a3, b3, 4*n));
	free(x); free(y); free(z); free(s);
	free(a1); free(a2); free(a3); free(b1); free(b2); free(b3);
}

@end
